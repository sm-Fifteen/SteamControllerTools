require("bit")

-- Dissector Table for steam controller control packets
scPacketTable = DissectorTable.new("sc_packet.msgType", "Steam Controller Packet", ftypes.UINT8, base.HEX)
scConfigTable = DissectorTable.new("sc_config.configType", "Steam Controller Config", ftypes.UINT8, base.HEX) -- 0x87
scUpdateTable = DissectorTable.new("sc_update.stateType", "Steam Controller state update", ftypes.UINT8, base.HEX) --0x01

------------------------------------------------------
-- Wrapper (Control)
------------------------------------------------------

function sc_packet()
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

sc_packet()

------------------------------------------------------
-- Wrapper (Interrupt)
------------------------------------------------------

function sc_update()
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

sc_update()

------------------------------------------------------
-- Lookup table for built-in sound IDs
------------------------------------------------------

builtinSounds = {
	[0x00] = "Warm and happy",
	[0x01] = "Invader",
	[0x02] = "Controller confirmed",
	[0x03] = "Victory",
	[0x04] = "Rise and Shine",
	[0x05] = "Shorty",
	[0x06] = "Warm boot",
	[0x07] = "Next level",
	[0x08] = "Shake it off",
	[0x09] = "Access denied",
	[0x0a] = "Deactivate",
	[0x0b] = "Discovery",
	[0x0c] = "Triumph",
	[0x0d] = "The Mann"
}

function updatePinfo(pinfo, msgId)
	if (pinfo.curr_proto == "SC_MSG") then
		pinfo.cols.info = string.format("%s 0x%x", pinfo.curr_proto, msgId)
	else 
		pinfo.cols.info = string.format("%s (0x%x)", pinfo.curr_proto, msgId)
	end
end

------------------------------------------------------
-- Type 0x8f : Feedback
------------------------------------------------------

function sc_feedback(msgId)
	local protocol = Proto("feedback",  "Steam Controller feedback")

	local hapticId = ProtoField.uint8("sc_msg_feedback.hapticId", "Selected acuator")
	local hiPulseLength = ProtoField.uint16("sc_msg_feedback.hiPulseLength", "High pulse duration")
	local loPulseLength = ProtoField.uint16("sc_msg_feedback.loPulseLength", "Low pulse duration")
	local repeatCount = ProtoField.uint16("sc_msg_feedback.repeatCount", "Repetitions")

	protocol.fields = {
		hapticId,
		hiPulseLength,
		loPulseLength,
		repeatCount
	}

	function protocol.dissector(msgBuffer, pinfo, subtree)
		local hapticIdBuf = msgBuffer(0,1);
		local hiPulseLengthBuf = msgBuffer(1,2);
		local loPulseLengthBuf = msgBuffer(3,2);
		local repeatCountBuf = msgBuffer(5,2);
		
		if hapticIdBuf:uint() == 0 then hapticName = "LEFT"
		else hapticName = "RIGHT" end
		
		period = (hiPulseLengthBuf:uint() + loPulseLengthBuf:uint());
		if period ~= 0 then state = "AT " .. math.floor(1000000.0/period) .. " Hz"
		else state = "STOP" end
		
		updatePinfo(pinfo, msgId)
		pinfo.cols.info:append(": " .. hapticName .. " " .. state)
		
		subtree:add(hapticId, hapticIdBuf)
		subtree:add_le(hiPulseLength, hiPulseLengthBuf)
		subtree:add_le(loPulseLength, loPulseLengthBuf)
		subtree:add_le(repeatCount, repeatCountBuf)
		
		return 7
	end

	scPacketTable:add(msgId, protocol)
end

sc_feedback(0x8f)

------------------------------------------------------
-- Type 0x81 : Disable lizard mode
------------------------------------------------------

function sc_lizard_off(msgId)
	local protocol = Proto("lizard_off", "Steam Controller disable lizard mode")
					
	function protocol.dissector(msgBuffer, pinfo, subtree)
		updatePinfo(pinfo, msgId)

		return 0
	end
	
	scPacketTable:add(msgId, protocol)
end

sc_lizard_off(0x81)

------------------------------------------------------
-- Type 0x85 : Enable lizard mode
------------------------------------------------------

function sc_lizard_on(msgId)
	local protocol = Proto("lizard_on", "Steam Controller enable lizard mode")
					
	function protocol.dissector(msgBuffer, pinfo, subtree)
		updatePinfo(pinfo, msgId)

		return 0
	end

	scPacketTable:add(msgId, protocol)
end

sc_lizard_on(0x85)

------------------------------------------------------
-- Type 0xB6 : Play builtin sound
------------------------------------------------------

function sc_play_sound(msgId)
	local protocol = Proto("play_sound", "Steam Controller builtin sound")

	local soundIdField = ProtoField.uint8("sc_msg_feedback.soundId", "Sound Id")

	protocol.fields = { soundIdField }

	function protocol.dissector(msgBuffer, pinfo, subtree)
		local soundIdBuf = msgBuffer(0,1)
		local soundId = soundIdBuf:uint()
		
		subtree:add(soundIdField, soundIdBuf)

		local sound = builtinSounds[soundId] or "UNKNOWN";
		updatePinfo(pinfo, msgId)
		pinfo.cols.info:append(": " .. sound .. " (0x" .. tostring(soundIdBuf:bytes()) ..")")

		return 1
	end

	scPacketTable:add(msgId, protocol)
end

sc_play_sound(0xb6)

------------------------------------------------------
-- Type 0x87 : Configure
------------------------------------------------------

function sc_config(msgId)
	local protocol = Proto("config", "Steam controller configuration")

	local configTypeField = ProtoField.uint8("sc_msg_config.configType", "Configured field ID", base.HEX)

	protocol.fields = { configTypeField }

	function protocol.dissector(msgBuffer, pinfo, subtree)
		-- TODO : Actual error
		if msgBuffer:len() % 3 ~= 0 then return 0 end
		updatePinfo(pinfo, msgId)
		
		for i=0, msgBuffer:len()-3, 3 do
			local configBuffer = msgBuffer(i, 3)
			local configTypeBuf = configBuffer(0,1)
			local configType = configTypeBuf:uint()
			
			local configtree = subtree:add(protocol,configBuffer)
			configtree:add(configTypeField, configTypeBuf)
			
			local configDissector = scConfigTable:get_dissector(configType)
			
			if configDissector == nil then
				configtree:add_expert_info(PI_UNDECODED)
			else
				configDissector:call(configBuffer(1):tvb(), pinfo, configtree)
			end
		end
	end

	scPacketTable:add(msgId, protocol)
end

sc_config(0x87)

------------------------------------------------------
-- Configure 0x2d : LED control
------------------------------------------------------

function sc_config_led(confId)
	protocol = Proto("CONFIG_LED",  "Set led brightness")

	brightnessField = ProtoField.uint8("sc_config.led.brightness", "Led brightness", base.DEC)
	protocol.fields = {brightnessField}

	function protocol.dissector(configBuffer, pinfo, configtree)
		local brightnessBuf = configBuffer(0,1)
		configtree:add(brightnessField, brightnessBuf)	
		local brightness = brightnessBuf:uint()
		pinfo.cols.info:append(": " .. "LED TO " .. brightness .. "%")
	end
	
	scConfigTable:add(confId, protocol)
end

sc_config_led(0x2d)

------------------------------------------------------
-- Update 0x01 : Input
------------------------------------------------------

function sc_update_input(updateId)
	protocol = Proto("UPDATE_INPUT",  "Input update")

	sequenceField = ProtoField.uint32("sc_update.input.sequence", "Sequence number", base.DEC)
	
	buttonFields = {
		ProtoField.bool("sc_update.input.A", "A button", 24, {}, bit.lshift(1,23)),
		ProtoField.bool("sc_update.input.X", "X button", 24, {}, bit.lshift(1,22)),
		ProtoField.bool("sc_update.input.B", "B button", 24, {}, bit.lshift(1,21)),
		ProtoField.bool("sc_update.input.Y", "Y button", 24, {}, bit.lshift(1,20)),
		ProtoField.bool("sc_update.input.LB", "Left bumper", 24, {}, bit.lshift(1,19)),
		ProtoField.bool("sc_update.input.RB", "Right bumper", 24, {}, bit.lshift(1,18)),
		ProtoField.bool("sc_update.input.LT.click", "Left trigger click", 24, {}, bit.lshift(1,17)),
		ProtoField.bool("sc_update.input.RT.click", "Right trigger click", 24, {}, bit.lshift(1,16)),
		
		ProtoField.bool("sc_update.input.LG", "Left grip", 24, {}, bit.lshift(1,15)),
		ProtoField.bool("sc_update.input.start", "Start button", 24, {}, bit.lshift(1,14)),
		ProtoField.bool("sc_update.input.home", "Home button", 24, {}, bit.lshift(1,13)),
		ProtoField.bool("sc_update.input.select", "Select button", 24, {}, bit.lshift(1,12)),
		ProtoField.bool("sc_update.input.Lpad.down", "Left trackpad down", 24, {}, bit.lshift(1,11)),
		ProtoField.bool("sc_update.input.Lpad.left", "Left trackpad left", 24, {}, bit.lshift(1,10)),	
		ProtoField.bool("sc_update.input.Lpad.right", "Left trackpad right", 24, {}, bit.lshift(1,9)),
		ProtoField.bool("sc_update.input.Lpad.up", "Left trackpad up", 24, {}, bit.lshift(1,8)),
		
		-- 7 is "Lanalog is sent for both Ljoystick and Lpad" (use with bit 3)
		-- 6 is "Lclick is Ljoystick" (use with bit 1)
		-- 5 seems unused
		ProtoField.bool("sc_update.input.Rpad.touch", "Right trackpad touched", 24, {}, bit.lshift(1,4)),
		ProtoField.bool("sc_update.input.Lpad.touch", "Left trackpad touched", 24, {}, bit.lshift(1,3)),
		ProtoField.bool("sc_update.input.Rpad.click", "Right trackpad click", 24, {}, bit.lshift(1,2)),
		ProtoField.bool("sc_update.input.Lpad.click", "Left trackpad/joystick click", 24, {}, bit.lshift(1,1)),	
		ProtoField.bool("sc_update.input.RG", "Right grip", 24, {}, bit.lshift(1,0)),
	}
	
	lTriggerField = ProtoField.uint8("sc_update.input.LT.value8", "Left Trigger 8-bit value", base.DEC)
	rTriggerField = ProtoField.uint8("sc_update.input.RT.value8", "Right Trigger 8-bit value", base.DEC)
	lAnalogXField = ProtoField.int16("sc_update.input.Lanalog.x", "Left joystick/trackpad X", base.DEC)
	lAnalogYField = ProtoField.int16("sc_update.input.Lanalog.y", "Left joystick/trackpad Y", base.DEC)
	rAnalogXField = ProtoField.int16("sc_update.input.Rpad.x", "Right trackpad X", base.DEC)
	rAnalogYField = ProtoField.int16("sc_update.input.Rpad.y", "Right trackpad Y", base.DEC)
	lTrigger16Field = ProtoField.uint16("sc_update.input.LT.value16", "Left Trigger 16-bit value", base.DEC)
	rTrigger16Field = ProtoField.uint16("sc_update.input.RT.value16", "Right Trigger 16-bit value", base.DEC)
	
	accelXField = ProtoField.float("sc_update.input.accel.x", "X acceleration", base.DEC)
	accelYField = ProtoField.float("sc_update.input.accel.y", "Y acceleration", base.DEC)
	accelZField = ProtoField.float("sc_update.input.accel.z", "Z acceleration", base.DEC)
	
	gyroPitchField = ProtoField.int16("sc_update.input.gyro.velocity.pitch", "Pitch velocity", base.DEC)
	gyroYawField = ProtoField.int16("sc_update.input.gyro.velocity.yaw", "Yaw velocity", base.DEC)
	gyroRollField = ProtoField.int16("sc_update.input.gyro.velocity.roll", "Roll velocity", base.DEC)
	gyroQuatWField = ProtoField.int16("sc_update.input.gyro.orientation.w", "Orientation quaternion w", base.DEC)
	gyroQuatXField = ProtoField.int16("sc_update.input.gyro.orientation.x", "Orientation quaternion x", base.DEC)
	gyroQuatYField = ProtoField.int16("sc_update.input.gyro.orientation.y", "Orientation quaternion y", base.DEC)
	gyroQuatZField = ProtoField.int16("sc_update.input.gyro.orientation.z", "Orientation quaternion z", base.DEC)
	
	lPadXField = ProtoField.int16("sc_update.input.Lpad.x", "Left trackpad X", base.DEC)
	lPadYField = ProtoField.int16("sc_update.input.Lpad.y", "Left trackpad Y", base.DEC)
	lJoystickAbsXField = ProtoField.int16("sc_update.input.Lstick.absX", "Left joystick absolute X", base.DEC)
	lJoystickAbsYField = ProtoField.int16("sc_update.input.Lstick.absY", "Left joystick absolute Y", base.DEC)
	lTriggerRawField = ProtoField.uint16("sc_update.input.LT.valueRaw", "Left Trigger analog value")
	rTriggerRawField = ProtoField.uint16("sc_update.input.RT.valueRaw", "Right Trigger analog value")
	
	protocol.fields = {
		sequenceField, lTriggerField, rTriggerField,
		lAnalogXField, lAnalogYField, rAnalogXField, rAnalogYField,
		lTrigger16Field, rTrigger16Field, gyroPitchField,
		gyroYawField, gyroRollField, gyroQuatWField, gyroQuatXField,
		gyroQuatYField, gyroQuatZField, lPadXField, lPadYField,
		lJoystickAbsXField, lJoystickAbsYField, lTriggerRawField, rTriggerRawField,
		accelXField, accelYField, accelZField, unpack(buttonFields)
	}

	function protocol.dissector(updateBuffer, pinfo, subtree)
		local sequenceBuf = updateBuffer(0,2)
		subtree:add_le(sequenceField, sequenceBuf)
		
		
		local buttonBuf = updateBuffer(4,3)
		local buttontree = subtree:add(buttonBuf, "Buttons")
		
		for _, buttonField in ipairs(buttonFields) do
			-- Bitfields are always displayed as BE, so :/
			buttontree:add(buttonField, buttonBuf)
		end
		
		local lTriggerBuf = updateBuffer(7,1)
		local rTriggerBuf = updateBuffer(8,1)
		subtree:add_le(lTriggerField, lTriggerBuf)
		subtree:add_le(rTriggerField, rTriggerBuf)
		
		local lAnalogXBuf = updateBuffer(12,2)
		local lAnalogYBuf = updateBuffer(14,2)
		subtree:add_le(lAnalogXField, lAnalogXBuf)
		subtree:add_le(lAnalogYField, lAnalogYBuf)
		
		local rAnalogXBuf = updateBuffer(16,2)
		local rAnalogYBuf = updateBuffer(18,2)
		subtree:add_le(rAnalogXField, rAnalogXBuf)
		subtree:add_le(rAnalogYField, rAnalogYBuf)
		
		local lTrigger16Buf = updateBuffer(20,2)
		local rTrigger16Buf = updateBuffer(22,2)
		subtree:add_le(lTrigger16Field, lTrigger16Buf)
		subtree:add_le(rTrigger16Field, rTrigger16Buf)
		
		local accelXBuf = updateBuffer(24,2)
		local accelX = accelXBuf:le_int() / 16384.0
		local accelYBuf = updateBuffer(26,2)
		local accelY = accelYBuf:le_int() / 16384.0
		local accelZBuf = updateBuffer(28,2)
		local accelZ = accelZBuf:le_int() / 16384.0
		subtree:add_le(accelXField, accelXBuf, accelX)
		subtree:add_le(accelYField, accelYBuf, accelY)
		subtree:add_le(accelZField, accelZBuf, accelZ)
		
		local gyroPitchBuf = updateBuffer(30,2)
		local gyroRollBuf = updateBuffer(32,2)
		local gyroYawBuf = updateBuffer(34,2)
		subtree:add_le(gyroPitchField, gyroPitchBuf)
		subtree:add_le(gyroYawField, gyroYawBuf)
		subtree:add_le(gyroRollField, gyroRollBuf)
		
		local gyroQuatWBuf = updateBuffer(36,2)
		local gyroQuatXBuf = updateBuffer(38,2)
		local gyroQuatYBuf = updateBuffer(40,2)
		local gyroQuatZBuf = updateBuffer(42,2)
		subtree:add_le(gyroQuatWField, gyroQuatWBuf)
		subtree:add_le(gyroQuatXField, gyroQuatXBuf)
		subtree:add_le(gyroQuatYField, gyroQuatYBuf)
		subtree:add_le(gyroQuatZField, gyroQuatZBuf)

		local lTriggerRawBuf = updateBuffer(46,2)
		subtree:add_le(lTriggerRawField, lTriggerRawBuf)
		
		local rTriggerRawBuf = updateBuffer(48,2)
		subtree:add_le(rTriggerRawField, rTriggerRawBuf)
		
		local lJoystickAbsXBuf = updateBuffer(50,2)
		local lJoystickAbsYBuf = updateBuffer(52,2)
		subtree:add_le(lJoystickAbsXField, lJoystickAbsXBuf)
		subtree:add_le(lJoystickAbsYField, lJoystickAbsYBuf)
		
		local lPadXBuf = updateBuffer(54,2)
		local lPadYBuf = updateBuffer(56,2)
		subtree:add_le(lPadXField, lPadXBuf)
		subtree:add_le(lPadYField, lPadYBuf)
		
		updatePinfo(pinfo, updateId)
		
		return 58
	end
	
	scUpdateTable:add(updateId, protocol)
end

sc_update_input(0x01)

------------------------------------------------------
-- Update 0x04 : Power level
------------------------------------------------------

function sc_update_power(updateId)
	protocol = Proto("UPDATE_ENERGY",  "Battery update")

	sequenceField = ProtoField.uint8("sc_update.energy.sequence", "Sequence number", base.DEC)
	voltageField = ProtoField.uint8("sc_update.energy.voltage", "Voltage", base.DEC)
	protocol.fields = {sequenceField, voltageField}

	function protocol.dissector(updateBuffer, pinfo, subtree)
		local sequenceBuf = updateBuffer(0,2)
		subtree:add_le(sequenceField, sequenceBuf)
		
		local voltageBuf = updateBuffer(8,2)
		subtree:add_le(voltageField, voltageBuf)
		
		updatePinfo(pinfo, updateId)
		
		--pinfo.cols.info:append(": " .. "LED TO " .. brightness .. "%")
		return 10
	end
	
	scUpdateTable:add(updateId, protocol)
end

sc_update_power(0x04)

------------------------------------------------------
-- Configure 0x30 : ???
------------------------------------------------------

-- Known configure signal (by groupings) :
-- 0x2d
-- 0x3a, 0x37, 0x36
-- 0x32, 0x18, 0x31, 0x08, 0x07
-- 0x30, 0x2e, 0x35, 0x34, 0x3b

------------------------------------------------------
-- USB Control transfer dissector (for the setup header)
------------------------------------------------------

sc_usb_setup = Proto("SC_USB_SETUP",  "USB Setup header")

transferTypeField = Field.new("usb.transfer_type")
urbTypeField = Field.new("usb.urb_type")

function sc_usb_setup.dissector(tvb, pinfo, tree)
	if tvb:len() == 0 then return false end
	
	-- myField() returns a FieldInfo object
	local transferType = transferTypeField().value
	local urbType = urbTypeField().value
	
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
