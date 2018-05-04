#!/usr/bin/lua5.3
local MDIO=require"mdio"
local mdio=MDIO.new{_debug=false}
local switch=require"ip178g"
local sw=switch.new{model="ip175g", mdio=mdio}
for i = 1,#sw.model.phy do
	local text
	local state=mdio:read{phy=sw:port_to_phy(i),reg=1}
	--print(i,state)
	if state&(2^2) ~= 0 then
		text="link"
	else
		text="no link"
	end
	print(sw:port_to_name(i),text,
		("%04x"):format(mdio:read{phy=i,reg=15}),
		("%04x"):format(mdio:read_mmd{phy=i,devad=7,prtad=60}),
		("%04x"):format(mdio:read_mmd{phy=i,devad=7,prtad=61}))
end
--[[
for i = 0,31 do
	print(("%02d"):format(i),
		("%04x"):format(mdio:read{phy=20,reg=i}),
		("%04x"):format(mdio:read{phy=21,reg=i}),
		("%04x"):format(mdio:read{phy=22,reg=i}),
		("%04x"):format(mdio:read{phy=23,reg=i}),
		("%04x"):format(mdio:read{phy=24,reg=i}),
		("%04x"):format(mdio:read{phy=i,reg=2})
	)
end
-- ]]

-- Leaky vlan config
do
	local leaky=sw:leaky_get()
	for k,_ in pairs(leaky) do print("Leaky",k) end
end

-- Port mirror config

do
	local mirror=sw:mirror_get()
	local rx_ports={}
	local tx_ports={}
	for k,_ in pairs(mirror.src_rx) do
		rx_ports[#rx_ports+1]=sw:port_to_name(k)
	end
	for k,_ in pairs(mirror.src_tx) do
		tx_ports[#tx_ports+1]=sw:port_to_name(k)
	end
	print(("Mirror: %s, mode: %s, target port: %s, source rx: {%s}, source tx: {%s}\n"):format(
		mirror.enabled and "on" or "off",
		mirror.mode,
		sw:port_to_name(mirror.dst) or "invalid",
		table.concat(rx_ports,","),
		table.concat(tx_ports,",")
	))
end
