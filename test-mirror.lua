#!/usr/bin/lua5.3
--[[
	Example of how to use ip178g as a lib
]]
local MDIO=require"mdio"
local mdio=MDIO.new{_debug=false}
local switch=require"ip178g"
local sw=switch.new{model="ip175g", mdio=mdio}

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
	sw:mirror_set{
		enabled=false,
		mode="RX",
		src_rx={"P0","P1"},
		src_tx={},
		dst="P2"
	}
end
