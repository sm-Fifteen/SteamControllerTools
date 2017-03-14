print( (require 'debug').getinfo(1).source )

scPacketTable = DissectorTable.get("sc_packet.msgType")
scUpdateTable = DissectorTable.get("sc_update.stateType")

------------------------------------------------------
-- Wrapper (Control)
------------------------------------------------------

do
	local protocol = Proto("SC_MSG",  "Steam Controller packet")
	local msgTypeField = ProtoField.uint8("sc_packet.msgType", "Message type", base.HEX)
	local msgLengthField = ProtoField.uint8("sc_packet.msgLength", "Message length")

	protocol.fields = {
		msgTypeField,
		msgLengthField
	}

	function protocol.dissector(dataBuffer, pinfo, tree)
		pinfo.cols.protocol = "sc_set_report";
		
		local msgTypeBuf = dataBuffer(0,1)
		local msgLengthBuf = dataBuffer(1,1)
		local msgType = msgTypeBuf:uint()
		local msgLength = msgLengthBuf:uint()
		
		local subtree = tree:add(protocol,dataBuffer(0, 2 + msgLength))
		
		subtree:add(msgTypeField, msgTypeBuf)
		subtree:add(msgLengthField, msgLengthBuf)
		
		local packetDissector = scPacketTable:get_dissector(msgType)
		local msgBuffer = dataBuffer(2, msgLength):tvb()
		
		if packetDissector == nil then
			updatePinfo(pinfo, msgType)
			local undecodedEntry = subtree:add(msgBuffer(), "Unknown Steam Controller message")
			undecodedEntry:add_expert_info(PI_UNDECODED)
			
			return msgLength
		end
		
		local consumedBytes = packetDissector:call(msgBuffer, pinfo, subtree)
		local remaining = msgBuffer(consumedBytes)
		
		if remaining:len() ~= 0 then
			local remainingEntry = subtree:add(remaining, "Unknown extra bytes:", tostring(remaining:bytes()))
			remainingEntry:add_expert_info(PI_UNDECODED, PI_NOTE)
		end
		
	end
	
	-- Set this up so the control dissector can use it
	sc_packet_dissector = protocol.dissector
end

------------------------------------------------------
-- Wrapper (Interrupt)
------------------------------------------------------

do
	local protocol = Proto("SC_UPDATE",  "Steam Controller state update")
	local msgTypeField = ProtoField.uint8("sc_packet.msgType", "Message type", base.HEX)
	local updateTypeField = ProtoField.uint8("sc_update.msgType", "Update type", base.HEX)
	local updateLengthField = ProtoField.uint8("sc_update.msgLength", "Update length")

	protocol.fields = {
		msgTypeField,
		updateTypeField,
		updateLengthField
	}

	function protocol.dissector(dataBuffer, pinfo, tree)
		pinfo.cols.protocol = "sc_state_update";
		
		local msgTypeBuf = dataBuffer(0,1)
		local msgType = msgTypeBuf:uint()
		local updateTypeBuf = dataBuffer(2,1)
		local updateType = updateTypeBuf:uint()
		local updateLengthBuf = dataBuffer(3,1)
		local updateLength = updateLengthBuf:uint()
		
		if msgType ~= 0x01 then return -1 end -- Only 0x01 should be an interrupt
		
		local subtree = tree:add(protocol,dataBuffer(0, 4 + updateLength))
		
		subtree:add(msgTypeField, msgTypeBuf)
		subtree:add(updateTypeField, updateTypeBuf)
		subtree:add(updateLengthField, updateLengthBuf)
		
		local packetDissector = scUpdateTable:get_dissector(updateType)
		local updateBuffer = dataBuffer(4, updateLength):tvb()
		
		if packetDissector == nil then
			updatePinfo(pinfo, updateType)
			local undecodedEntry = subtree:add(updateBuffer(), "Unknown Steam Controller update message")
			undecodedEntry:add_expert_info(PI_UNDECODED)
			
			return dataBuffer:len()
		end
		
		local consumedBytes = packetDissector:call(updateBuffer, pinfo, subtree)
		local remaining = updateBuffer(consumedBytes)
		
		if remaining:len() ~= 0 then
			local remainingEntry = subtree:add(remaining, "Unknown extra bytes:", tostring(remaining:bytes()))
			remainingEntry:add_expert_info(PI_UNDECODED, PI_NOTE)
		end
		
		return dataBuffer:len()
	end
	
	-- Set this up so the control dissector can use it
	sc_update_dissector = protocol.dissector
end

------------------------------------------------------
-- USB Control transfer dissector (for the setup header)
------------------------------------------------------

sc_usb_setup = Proto("SC_USB_SETUP",  "USB Setup header")

transferTypeField = Field.new("usb.transfer_type")
urbTypeField = Field.new("usb.urb_type")
usbDataFlag = Field.new("usb.data_flag")
usbDataLength = Field.new("usb.data_len")

function sc_usb_setup.dissector(tvb, pinfo, tree)
	if tvb:len() == 0 then return false end
	
	-- myField() returns a FieldInfo object
	local transferType = transferTypeField().value
	local urbType = urbTypeField().value
	local dataPresent = (usbDataFlag().value == "present (0)")
	local dataLength = usbDataLength().value
	
	-- All SC messages are 64 bytes in length, there are false positives without that condition
	if not dataPresent or dataLength ~= 64 then return false end
	
	if transferType == 2 and urbType == 83 then
		-- Must be a control transfer, not an interrupt
		-- Must be of type "Submit", not "Complete"
	
		--bmRequestTypeBuf = tvb(0,1)
		local bRequestBuf = tvb(0,1)
		local wValueBuf = tvb(1,2)
		local wIndexBuf = tvb(3,2)
		local wLengthBuf = tvb(5,2)
		local dataBuffer = tvb(7):tvb()
	
		sc_packet_dissector:call(dataBuffer, pinfo, tree)
		return 7 + dataBuffer:len();
	elseif transferType == 1 and urbType == 67 then
		dataBuffer = tvb():tvb()
		return sc_update_dissector:call(dataBuffer, pinfo, tree)
	end
	
	return 0
end

--Note that these only work if the device descriptors are present in the capture.
dTable = DissectorTable.get("usb.product")
dTable:add(0x28de1102,sc_usb_setup) --USB controller
dTable:add(0x28de1142,sc_usb_setup) --Dongle
