local CM={}
local OM={}
CM._meta={ __index=OM }

local defaults={
	file="/sys/bus/mdio_bus/devices/gpio-0:02/switch_conf",
}

function CM.new(something)
	local o
	if type(something) == "table" then
		o=something
		if o.file == nil then o.file=defaults.file end
	else
		o={ file=something or defaults.file }	
	end
	setmetatable(o,CM._meta)
	return o
end

function OM:write(n)
	local phy, reg
	phy=n.phy or self.phy
	reg=n.reg or self.reg
	data=n.data
	local string=("0x%02x%02x%04x"):format(phy,reg,data)
	local f=io.open(self.file,"wb")
	f:write(string)
	f:close()
	if self._debug then print("wrote:",phy,reg,string) end
end

function OM:read(n)
	local phy, reg
	phy=n.phy or self.phy
	reg=n.reg or self.reg
	local string=("0x%02x%02x"):format(phy,reg,data)
	local f=io.open(self.file,"wb")
	f:write(string)
	f:close()
	local f=io.open(self.file,"rb")
	s=f:read("*a")
	f:close()
	if self._debug then print("read:",phy,reg,s) end
	return tonumber(s,16)
end

function OM:write_mmd(n)
	local devad=n.devad
	local prtad=n.prtad
	local phy=n.phy or self.phy
	-- set mmd devad
	self:write{phy=phy, reg=13,data=devad}
	self:write{phy=phy, reg=14,data=prtad}
	self:write{phy=phy, reg=13,data=devad|2^14}
	return self:write{phy=phy, reg=14,data=data}
end
function OM:read_mmd(n)
	local devad=n.devad
	local prtad=n.prtad
	local phy=n.phy or self.phy
	-- set mmd devad
	self:write{phy=phy, reg=13,data=devad}
	self:write{phy=phy, reg=14,data=prtad}
	self:write{phy=phy, reg=13,data=devad|2^14}
	return self:read{phy=phy, reg=14}
end
return CM
