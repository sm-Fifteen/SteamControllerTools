require("bit")
require("sc-shared")

scPacketTable = DissectorTable.get("sc_packet.msgType")
scConfigTable = DissectorTable.get("sc_config.configType")

------------------------------------------------------
-- Type 0x8f : Feedback
------------------------------------------------------

do
	local msgId = 0x8f
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

------------------------------------------------------
-- Type 0x81 : Disable lizard mode
------------------------------------------------------

do
	local msgId = 0x81
	local protocol = Proto("lizard_off", "Steam Controller disable lizard mode")
					
	function protocol.dissector(msgBuffer, pinfo, subtree)
		updatePinfo(pinfo, msgId)

		return 0
	end
	
	scPacketTable:add(msgId, protocol)
end

------------------------------------------------------
-- Type 0x85 : Enable lizard mode
------------------------------------------------------

do
	local msgId = 0x85
	local protocol = Proto("lizard_on", "Steam Controller enable lizard mode")
					
	function protocol.dissector(msgBuffer, pinfo, subtree)
		updatePinfo(pinfo, msgId)

		return 0
	end

	scPacketTable:add(msgId, protocol)
end

------------------------------------------------------
-- Type 0xB6 : Play builtin sound
------------------------------------------------------

do
	local msgId = 0xb6
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

------------------------------------------------------
-- Type 0x87 : Configure
------------------------------------------------------

do
	local msgId = 0x87
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

------------------------------------------------------
-- Configure 0x2d : LED control
------------------------------------------------------

do
	local confId = 0x2d
	local protocol = Proto("CONFIG_LED",  "Set led brightness")

	local brightnessField = ProtoField.uint8("sc_config.led.brightness", "Led brightness", base.DEC)
	protocol.fields = {brightnessField}

	function protocol.dissector(configBuffer, pinfo, configtree)
		local brightnessBuf = configBuffer(0,1)
		configtree:add(brightnessField, brightnessBuf)	
		local brightness = brightnessBuf:uint()
		pinfo.cols.info:append(": " .. "LED TO " .. brightness .. "%")
	end
	
	scConfigTable:add(confId, protocol)
end

------------------------------------------------------
-- Configure 0x30 : ???
------------------------------------------------------

-- Known configure signal (by groupings) :
-- 0x2d
-- 0x3a, 0x37, 0x36
-- 0x32, 0x18, 0x31, 0x08, 0x07
-- 0x30, 0x2e, 0x35, 0x34, 0x3b
