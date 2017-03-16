
require_once=require"require_once"
require_once"register_dissectors"

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
