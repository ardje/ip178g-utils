#!/usr/bin/lua5.3
local MDIO=require"mdio"
local mdio=MDIO.new{_debug=false}
local switch=require"ip178g"
local sw=switch.new{model="ip175g", mdio=mdio}

local env={sw=sw,print=print,allports=sw.model.name}
for i,v in ipairs(arg) do
	if v == "-" then
		v=io.stdin:read"*a"
	end	
	print(v)
	local f=assert(load(v,v,"t",env))
	if f then f() end
end
