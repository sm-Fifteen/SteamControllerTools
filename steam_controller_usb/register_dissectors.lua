if rawget(_G, "steam_controller_usb_dissector_table_check") == nil then
	rawset(_G, "steam_controller_usb_dissector_table_check", 1)
	-- Dissector Table for steam controller control packets
	scPacketTable = DissectorTable.new("sc_packet.msgType", "Steam Controller Packet", ftypes.UINT8, base.HEX)
	scConfigTable = DissectorTable.new("sc_config.configType", "Steam Controller Config", ftypes.UINT8, base.HEX) -- 0x87
	scUpdateTable = DissectorTable.new("sc_update.stateType", "Steam Controller state update", ftypes.UINT8, base.HEX) --0x01
end