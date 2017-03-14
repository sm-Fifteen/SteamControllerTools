print( (require 'debug').getinfo(1).source )

require("bit")

-- Dissector Table for steam controller control packets
scPacketTable = DissectorTable.new("sc_packet.msgType", "Steam Controller Packet", ftypes.UINT8, base.HEX)
scConfigTable = DissectorTable.new("sc_config.configType", "Steam Controller Config", ftypes.UINT8, base.HEX) -- 0x87
scUpdateTable = DissectorTable.new("sc_update.stateType", "Steam Controller state update", ftypes.UINT8, base.HEX) --0x01
