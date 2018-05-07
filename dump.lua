#!/usr/bin/lua5.3
local MDIO=require"mdio"
local mdio=MDIO.new{_debug=false}
local switch=require"ip178g"
local sw=switch.new{model="ip175g", mdio=mdio}
local output=io.stdout
local function count(n)
	local c=0
	for _ in pairs(n) do c=c+1 end
	return c
end
local function ports_to_list(n)
	local list={}
	if sw and #n == #sw.model.name then
		return "allports"
	end
	for k,_ in pairs(n) do
		list[#list+1]=("%q"):format(sw:port_to_name(k))
	end
	return(table.concat(list,","))
end
local function ports_to_table(n)
	local list={}
	if sw and count(n) == #sw.model.name then
		return "allports"
	end
	for k,_ in pairs(n) do
		list[#list+1]=("%q"):format(sw:port_to_name(k))
	end
	return("{"..table.concat(list,",").."}")
end
local function dump(output,n,t)
	output:write(("sw:%s_set{%s}\n"):format(n,table.concat(t,",")))
end
local function df(output,n,t)
	assert(#t&1 == 0,"Not a pair")
	local items={}
	for i=1,#t,2 do
		local f=t[i]
		local d=t[i+1]
		if type(d) == "table" then
			items[#items+1]=string.format(f,table.unpack(d))
		else
			items[#items+1]=string.format(f,d)
		end
	end
	return dump(output,n,items)
end
-- Leaky vlan config
do
	local list={}
	local leaky=sw:leaky_get()
	for k,_ in pairs(leaky) do list[#list+1]=("%q"):format(k) end
	dump(output,"leaky",list)
end

-- Port mirror config

do
	local mirror=sw:mirror_get()
	df(output,"mirror",{
		"enabled=%q",mirror.enabled and "true" or "false",
		"mode=%q",mirror.mode,
		"dst=%s",sw:port_to_name(mirror.dst) or "invalid",
		"src_rx={%s}",ports_to_list(mirror.src_rx),
		"src_tx={%s}",ports_to_list(mirror.src_tx),
	})
end
-- VID config
do
	local vlan=sw:vlans_get()
	local items={}
	local last=0
	--[[
		Cut the list at the valid=0 no members.
	--]]
	for i,v in ipairs(vlan) do
		if count(v.members) > 0 then last=i end
		print(i,#v.members,v.vid)
		if v.valid then last=i end
	end
	print(last)
	if last > 0 then
		for i=1,last do
			local v=vlan[i]
			local valid=""
			if #v.members>0 and not v.valid then
				valid="valid=false,"
			end
			if #v.members==0 and not v.valid and v.vid==0 then
				items[#items+1]="{ }"
			else
				items[#items+1]=("{ %svid=%d, members=%s }"):format(
					valid,v.vid,ports_to_table(v.members)
				)
			end
		end
	end
	dump(output,"vlans",items)
end
