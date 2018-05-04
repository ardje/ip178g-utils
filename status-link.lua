#!/usr/bin/lua5.3
local MDIO=require"mdio"
local mdio=MDIO.new{_debug=false}
local portname = { [2]="P1", [3]="P2", [4]="P3" }
for i = 2,4 do
	local state=mdio:read{phy=i,reg=1}
	--print(i,state)
	if state&(2^2) ~= 0 then
		text="link"
	else
		text="no link"
	end
	print(portname[i],text,
		("%04x"):format(mdio:read{phy=i,reg=1}),
		("%04x"):format(mdio:read{phy=i,reg=15}),
		("%04x"):format(mdio:read_mmd{phy=i,devad=7,prtad=60}),
		("%04x"):format(mdio:read_mmd{phy=i,devad=7,prtad=61}))
end
