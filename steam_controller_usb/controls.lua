print( (require 'debug').getinfo(1).source )

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

	local hapticIdField = ProtoField.uint8("sc_msg_feedback.hapticId", "Selected acuator", base.UNIT_STRING, { [0] = "LEFT", [1] = "RIGHT" })
	local hiPulseLengthField = ProtoField.uint16("sc_msg_feedback.hiPulseLength", "High pulse duration")
	local loPulseLengthField = ProtoField.uint16("sc_msg_feedback.loPulseLength", "Low pulse duration")
	local frequencyField = ProtoField.float("sc_msg_feedback.frequency", "Frequency")
	local repeatCountField = ProtoField.uint16("sc_msg_feedback.repeatCount", "Repetitions")
	local priorityField = ProtoField.uint8("sc_msg_feedback.priority", "Haptic priority")

	protocol.fields = {
		hapticIdField,
		hiPulseLengthField,
		loPulseLengthField,
		repeatCountField,
		priorityField
	}

	function protocol.dissector(msgBuffer, pinfo, subtree)
		local hapticIdBuf = msgBuffer(0,1)
		local hapticId = hapticIdBuf:uint()
		local hiPulseLengthBuf = msgBuffer(1,2)
		local hiPulseLength = hiPulseLengthBuf:le_uint()
		local loPulseLengthBuf = msgBuffer(3,2)
		local loPulseLength = loPulseLengthBuf:le_uint()
		local repeatCountBuf = msgBuffer(5,2)
		local repeatCount = repeatCountBuf:le_uint()
		
		local period = (hiPulseLength + loPulseLength)
		local frequency = 0
		if period ~= 0 then frequency = (1000000.0/period) end
		
		local state = "STOP"
		if repeatCount == 1 then state = string.format("PULSE FOR %d µs", hiPulseLength)
		elseif frequency ~= 0 then state = string.format("%.2f Hz", frequency) end
		
		updatePinfo(pinfo, msgId)
		pinfo.cols.info:append(": " .. state)
		
		subtree:add(hapticIdField, hapticIdBuf)
		subtree:add_le(hiPulseLengthField, hiPulseLengthBuf, hiPulseLength, nil, "µs")
		subtree:add_le(loPulseLengthField, loPulseLengthBuf, loPulseLength, nil, "µs")
		
		if repeatCount > 1 then
			local frequencyEntry = subtree:add(frequencyField, frequency, nil, "Hz")
			frequencyEntry:set_generated(true)
		end
		
		subtree:add_le(repeatCountField, repeatCountBuf, repeatCount)
		
		-- SDK calls those nflags, but this is a priority index
		-- While playing an haptic wave of priority n, all feedback messages with a lower priority will be ignored.
		-- All feedback messages with an equal or greater priority will override the current one.
		local priorityBuf = msgBuffer(7,1)
		subtree:add_le(priorityField, priorityBuf)
		
		return 8
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

		local sound = builtinSounds[soundId] or "UNKNOWN";
		subtree:add(soundIdField, soundIdBuf, soundId, nil, string.format("(%s)", sound))
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
	local rawParamsField = ProtoField.bytes("sc_msg_config.rawParams", "Unknown Steam Controller config parameters", base.HEX)

	protocol.fields = { configTypeField, rawParamsField }

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
			
			local paramsBuffer = configBuffer(1)
			
			if configDissector == nil then
				local paramsEntry = configtree:add(rawParamsField, paramsBuffer)
				paramsEntry:add_expert_info(PI_UNDECODED)
			else
				configDissector:call(paramsBuffer:tvb(), pinfo, configtree)
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
		local brightness = brightnessBuf:uint()
		configtree:add(brightnessField, brightnessBuf, brightness, nil, "%")
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
