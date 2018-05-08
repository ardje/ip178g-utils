local C={}
local O={}
C._meta={
	__index=O
}
--[[
	The IP175G is the same as the IP178G, except missing port 0, 1 and 5.
	There is no way per phy id that we can differentiate between the IP17[58][BCG].
	The switches are totally different
]]

local models={
	ip175g = {
		--[[
		name= { "P0","P1","P2","P3","P4" },
		phy={ 2 , 3, 4 , 6 , 7 },
		-- ]]
		name= { "NC0","NC1","P0","P1","P2","NC2","P3","P4" },
		phy={ 0,1,2 , 3, 4 ,5, 6 , 7 },
	},
	ip178g = {
		name={ "P0","P1","P2","P3", "P4","P5","P6","P7" },
		phy={0,1,2,3,4,5,6,7},
	},
}


function C.new(n)
	local model={}
	local o={model=model}
	local sw=models[n.model]
	if not sw then return nil end
	for k,v in pairs(sw) do model[k]=v end
	o.mdio=n.mdio
	setmetatable(o,C._meta)
	return o
end
local S_leaky={
	ARP=1, UNICAST=2, MULTICAST=4
}

function O:leaky_get()
	local leaky={}
	local d=self.mdio:read{phy=23,reg=19}
	for k,v in pairs(S_leaky) do
		if d&v ~= 0 then leaky[k]=true end
	end
	return leaky
end
function O:leaky_set(n)
	local d=0
	if #n > 0 then
		for _,v in ipairs(n) do
			d=d|S_leaky[v]
		end
	else
		for k,_ in pairs(n) do
			d=d|S_leaky[k]
		end
	end
	self.mdio:write{phy=23,reg=19,data=d}
end
function O:port_to_bit(n)
	return self:port_to_phy(n) and 1<<self:port_to_phy(n) or 0
end
function O:port_to_name(n)
	return self.model.name[n]
end
function O:name_to_port(n)
	for k,v in ipairs(self.model.name) do
		if v==n then return k end
	end
	return nil
end
function O:port_to_phy(n)
	return self.model.phy[n]
end
function O:phy_to_port(n)
	for i,v in ipairs(self.model.phy) do
		if v==n then return i end
	end
	return nil
end
function O:field_to_ports(n)
	local ports={}
	for i=1,#self.model.phy do
		if n&self:port_to_bit(i) ~= 0 then
			ports[i]=true
		end
	end
	return ports
end
function O:ports_to_field(n)
	local d=0
	for k,v in pairs(n) do
		local p
		if type(v) == "string" then
			p=self:name_to_port(v)
		elseif type(k)=="string" then
			p=self:name_to_port(k)
		else
			p=k
		end
		d=d|self:port_to_bit(p)
	end
	return d
end

local S_mirror_mode={ [0]="RX", [1]="TX",[2]="DUAL_RX_TX",[3]="SINGLE_RX_TX" }
function O:mirror_get()
	local mirror={}
	local d3, d4
	d3=self.mdio:read{phy=20,reg=3}
	if d3&32768 ~= 0 then mirror.enabled=true end
	mirror.mode=S_mirror_mode[(d3>>13)&3]
	--[[
		The bitifield can have an invalid configuration. Ignore for now
	]]
	mirror.src_rx=self:field_to_ports(d3&0xff)
	d4=self.mdio:read{phy=20,reg=4}
	mirror.dst=self:phy_to_port(d4>>13&7)
	mirror.src_tx=self:field_to_ports(d4&0xff)
	--[[
		Debug info
	-- ]]
	mirror.d3=d3 mirror.d4=d4
	return mirror
end

function O:mirror_set(mirror)
	local d3=0 -- self.mdio:read{phy=20,reg=3}
	local d4=0 -- self.mdio:read{phy=20,reg=4}
	local dstphy=self:port_to_phy(type(mirror.dst)=="string" and self:name_to_port(mirror.dst) or mirror.dst)
	local txports=self:ports_to_field(mirror.src_tx or {})
	local rxports=self:ports_to_field(mirror.src_rx or {})
	local mode=0
	for k,v in pairs(S_mirror_mode) do
		if v==mirror.mode then mode =k end
	end
	if mirror.enabled then
		d3=d3 | 32768
	end
	print(d3,mode,txports,rxports,dstphy)
	d3=d3|(mode <<13)|rxports
	d4=d4|(dstphy<<13)|txports
	print(d3,d4)
	--[[
		If we turn mirror on, first write destination port, before turning it on.
		If we turn mirror off, first turn it off before setting anything else.
	-- ]]
	if mirror.enabled then
		self.mdio:write{phy=20,reg=4,data=d4}
		self.mdio:write{phy=20,reg=3,data=d3}
	else
		self.mdio:write{phy=20,reg=4,data=d3}
		self.mdio:write{phy=20,reg=3,data=d4}
	end
end

function O.vlan_to_offset(_,n,j)
	local i=n-1
	return (i>>1)+j or 0, 8*(i&1)
end
function O:vlans_get()
	local vlan={}
	local valid=self.mdio:read{phy=24,reg=0}
	for i=1,16 do
		local reg,shift=self:vlan_to_offset(i,17)
		local field=(self.mdio:read{phy=24,reg=reg}>>shift)&0xff
		vlan[i]={
			valid=(valid & 1<<(i-1) ~= 0),
			vid=self.mdio:read{phy=24,reg=i},
			members=self:field_to_ports(field),
		}
	end
	return vlan
end
function O:vlans_set(vlan)
	local d = {}
	local bf={}
	for i = 1,8 do bf[i] =0 end
	for i = 1,16 do d[i] =0 end
	local d0 = 0
	for i,v in ipairs(vlan) do
		local valid=v.valid
		if type(v.valid) == "nil" and #(v.members or {} ) > 0 then valid = true end
		if valid then
			d0=d0|1<<(i-1)
		end
		local members=self:ports_to_field(v.members or {})
		local i_2=(i-1)//2+1
		d[i]=v.vid
		bf[i_2]=bf[i_2]| (members<<8*((i-1)&1))
	end
	self.mdio:write{phy=24,reg=0,data=0}
	for i=1,16 do self.mdio:write{phy=24,reg=i,data=d[i]} end
	for i=1,8 do self.mdio:write{phy=24,reg=i+16,data=bf[i]} end
	print(d0)
	self.mdio:write{phy=24,reg=0,data=d0}
end

function O:port_to_offset(n,i)
	local phy=self:port_to_phy(n)
	return (phy>>1)+i or 0, 8*(phy&1)
end
function O:pbv_get()
	local pbv={}
	for i,_ in ipairs(self.model.name) do
		local reg,shift=self:port_to_offset(i,15)
		local d=self.mdio:read{phy=23,reg=reg}
		pbv[i]=self:field_to_ports(d>>shift&0xff)
	end
	return pbv
end

function O:pbv_set(pbv)
	local d={}
	for i in ipairs(self.model.name) do
		d[i]=0
	end
	for p,v in pairs(pbv) do
		if type(p) == "string" then p=self:name_to_port(p) end		
		if p and p> 0 and p <= #self.model.name then 
			local members=self:ports_to_field(v) or 0
			local reg,shift=self:port_to_offset(p,1)
			d[reg]=d[reg]|(members<<shift)
		end
	end 
	for i,v in ipairs(d) do
		self.mdio:write{phy=23,reg=i+14,data=v}
	end
end

local print=print
function O.dummy()
	print"dummy"
end
return C
