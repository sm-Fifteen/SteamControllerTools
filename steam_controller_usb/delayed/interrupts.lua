print( (require 'debug').getinfo(1).source )

require("bit")
require("sc-shared")

scPacketTable = DissectorTable.get("sc_packet.msgType")
scUpdateTable = DissectorTable.get("sc_update.stateType")

------------------------------------------------------
-- Update 0x01 : Input
------------------------------------------------------

do
	local updateId = 0x01
	local protocol = Proto("UPDATE_INPUT",  "Input update")

	local sequenceField = ProtoField.uint32("sc_update.input.sequence", "Sequence number", base.DEC)
	
	local buttonFields = {
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
	
	local lTriggerField = ProtoField.uint8("sc_update.input.LT.value8", "Left Trigger 8-bit value", base.DEC)
	local rTriggerField = ProtoField.uint8("sc_update.input.RT.value8", "Right Trigger 8-bit value", base.DEC)
	local lAnalogXField = ProtoField.int16("sc_update.input.Lanalog.x", "Left joystick/trackpad X", base.DEC)
	local lAnalogYField = ProtoField.int16("sc_update.input.Lanalog.y", "Left joystick/trackpad Y", base.DEC)
	local rAnalogXField = ProtoField.int16("sc_update.input.Rpad.x", "Right trackpad X", base.DEC)
	local rAnalogYField = ProtoField.int16("sc_update.input.Rpad.y", "Right trackpad Y", base.DEC)
	local lTrigger16Field = ProtoField.uint16("sc_update.input.LT.value16", "Left Trigger 16-bit value", base.DEC)
	local rTrigger16Field = ProtoField.uint16("sc_update.input.RT.value16", "Right Trigger 16-bit value", base.DEC)
	
	local accelXField = ProtoField.float("sc_update.input.accel.x", "X acceleration", base.DEC)
	local accelYField = ProtoField.float("sc_update.input.accel.y", "Y acceleration", base.DEC)
	local accelZField = ProtoField.float("sc_update.input.accel.z", "Z acceleration", base.DEC)
	
	local gyroPitchField = ProtoField.float("sc_update.input.gyro.velocity.pitch", "Pitch velocity", base.DEC)
	local gyroYawField = ProtoField.float("sc_update.input.gyro.velocity.yaw", "Yaw velocity", base.DEC)
	local gyroRollField = ProtoField.float("sc_update.input.gyro.velocity.roll", "Roll velocity", base.DEC)
	local gyroQuatWField = ProtoField.float("sc_update.input.gyro.orientation.w", "Orientation quaternion w", base.DEC)
	local gyroQuatXField = ProtoField.float("sc_update.input.gyro.orientation.x", "Orientation quaternion x", base.DEC)
	local gyroQuatYField = ProtoField.float("sc_update.input.gyro.orientation.y", "Orientation quaternion y", base.DEC)
	local gyroQuatZField = ProtoField.float("sc_update.input.gyro.orientation.z", "Orientation quaternion z", base.DEC)
	-- Angles generated from the quat
	local gyroQuatPitchField = ProtoField.float("sc_update.input.gyro.orientation.pitch", "Orientation pitch", base.DEC)
	local gyroQuatYawField = ProtoField.float("sc_update.input.gyro.orientation.yaw", "Orientation yaw", base.DEC)
	local gyroQuatRollField = ProtoField.float("sc_update.input.gyro.orientation.roll", "Orientation roll", base.DEC)
	
	local lPadXField = ProtoField.int16("sc_update.input.Lpad.x", "Left trackpad X", base.DEC)
	local lPadYField = ProtoField.int16("sc_update.input.Lpad.y", "Left trackpad Y", base.DEC)
	local lJoystickAbsXField = ProtoField.int16("sc_update.input.Lstick.absX", "Left joystick absolute X", base.DEC)
	local lJoystickAbsYField = ProtoField.int16("sc_update.input.Lstick.absY", "Left joystick absolute Y", base.DEC)
	local lTriggerRawField = ProtoField.uint16("sc_update.input.LT.valueRaw", "Left Trigger analog value")
	local rTriggerRawField = ProtoField.uint16("sc_update.input.RT.valueRaw", "Right Trigger analog value")
	
	protocol.fields = {
		sequenceField, lTriggerField, rTriggerField,
		lAnalogXField, lAnalogYField, rAnalogXField, rAnalogYField,
		lTrigger16Field, rTrigger16Field, gyroPitchField,
		gyroYawField, gyroRollField, gyroQuatWField, gyroQuatXField,
		gyroQuatYField, gyroQuatZField, lPadXField, lPadYField,
		lJoystickAbsXField, lJoystickAbsYField, lTriggerRawField, rTriggerRawField,
		accelXField, accelYField, accelZField, gyroQuatPitchField,
		gyroQuatYawField, gyroQuatRollField, unpack(buttonFields)
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
		
		-- Invensense MPU-6500 : 16384 LSB per G
		local accelXBuf = updateBuffer(24,2)
		local accelX = accelXBuf:le_int() / 16384.0
		local accelYBuf = updateBuffer(26,2)
		local accelY = accelYBuf:le_int() / 16384.0
		local accelZBuf = updateBuffer(28,2)
		local accelZ = accelZBuf:le_int() / 16384.0
		subtree:add_le(accelXField, accelXBuf, accelX)
		subtree:add_le(accelYField, accelYBuf, accelY)
		subtree:add_le(accelZField, accelZBuf, accelZ)
		
		-- Invensense MPU-6500 : 131 LSB per degree per second
		local gyroPitchBuf = updateBuffer(30,2)
		local gyroPitch = gyroPitchBuf:le_int() / 131.0
		local gyroYawBuf = updateBuffer(32,2)
		local gyroYaw = gyroYawBuf:le_int() / 131.0
		local gyroRollBuf = updateBuffer(34,2)
		local gyroRoll = gyroRollBuf:le_int() / 131.0
		subtree:add_le(gyroPitchField, gyroPitchBuf, gyroPitch)
		subtree:add_le(gyroYawField, gyroYawBuf, gyroRoll)
		subtree:add_le(gyroRollField, gyroRollBuf, gyroYaw)
		
		-- The doc doesn't provide the scaling value for quaternion components (since it's calculated by the DMP though sensor fusion).
		-- I'ver seen some sources use 2^14 as a scaling factor for the chip, but the actual scale is 2^(16-1)
		-- I guess that makes sense for a unit-value stored in a signed int16.
		-- Also, the controller returns XYZW even though the DMP clearly returns WXYZ, JFC!
		local gyroQuatXBuf = updateBuffer(36,2)
		local gyroQuatYBuf = updateBuffer(38,2)
		local gyroQuatZBuf = updateBuffer(40,2)
		local gyroQuatWBuf = updateBuffer(42,2)
		local gyroQuatX = gyroQuatXBuf:le_int() / 32768.0
		local gyroQuatY = gyroQuatYBuf:le_int() / 32768.0
		local gyroQuatZ = gyroQuatZBuf:le_int() / 32768.0
		local gyroQuatW = gyroQuatWBuf:le_int() / 32768.0
		
		local gyroQuatNorm = math.sqrt(gyroQuatX^2+gyroQuatY^2+gyroQuatZ^2+gyroQuatW^2)
		local gyroQuatNormEntry = subtree:add(gyroQuatNorm, "Orientation norm (should be ~1)")
		gyroQuatNormEntry:set_generated(true)
		
		subtree:add_le(gyroQuatXField, gyroQuatXBuf, gyroQuatX)
		subtree:add_le(gyroQuatYField, gyroQuatYBuf, gyroQuatY)
		subtree:add_le(gyroQuatZField, gyroQuatZBuf, gyroQuatZ)
		subtree:add_le(gyroQuatWField, gyroQuatWBuf, gyroQuatW)
		
		local gyroQuatPitch = math.atan2(2*gyroQuatX*gyroQuatY - 2*gyroQuatW*gyroQuatZ, 2*gyroQuatW*gyroQuatW + 2*gyroQuatX*gyroQuatX - 1)
		local gyroQuatRoll = -math.asin(2*gyroQuatX*gyroQuatZ + 2*gyroQuatW*gyroQuatY)
		local gyroQuatYaw = math.atan2(2*gyroQuatY*gyroQuatZ - 2*gyroQuatW*gyroQuatX, 2*gyroQuatW*gyroQuatW + 2*gyroQuatZ*gyroQuatZ - 1)
		local gyroQuatPitchEntry = subtree:add(gyroQuatPitchField, math.deg(gyroQuatPitch))
		gyroQuatPitchEntry:set_generated(true)
		local gyroQuatYawEntry = subtree:add(gyroQuatYawField, math.deg(gyroQuatYaw))
		gyroQuatYawEntry:set_generated(true)
		local gyroQuatRollEntry = subtree:add(gyroQuatRollField, math.deg(gyroQuatRoll))
		gyroQuatRollEntry:set_generated(true)

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

------------------------------------------------------
-- Update 0x04 : Power level
------------------------------------------------------

do
	local updateId = 0x04
	local protocol = Proto("UPDATE_ENERGY",  "Battery update")

	local sequenceField = ProtoField.uint8("sc_update.energy.sequence", "Sequence number", base.DEC)
	local voltageField = ProtoField.uint8("sc_update.energy.voltage", "Voltage", base.DEC)
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
