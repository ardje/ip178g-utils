utils

mdio.lua - abstraction layer for mdio access.
ip178g.lua - switch configuration lib
dump.lua - dumps current config as a script
undump.lua - reads and execute the script
status.lua - generic human dump of the switch status

test-mirror.lua - demo on how to use the lib, or how to use the script generated by dump.

Anyway, this should always result in the same dump:

dump.lua > config
undump.lua - < config
dump.lua > config2
diff config config2
