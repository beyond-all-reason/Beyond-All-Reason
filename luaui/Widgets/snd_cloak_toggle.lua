local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Cloak toggle sound",
		desc = "Plays a UI sound whenever cloak is turned on or off",
		author = "Zain M",
		date = "December 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

local CMD_WANT_CLOAK = GameCMD.WANT_CLOAK
--SFX modified from https://mixkit.co/free-sound-effects/click/
--free sound license, https://mixkit.co/terms/
local SOUND_CLOAK_ON = "LuaUI/Sounds/cloak_on.wav"
local SOUND_CLOAK_OFF = "LuaUI/Sounds/cloak_off.wav"
local SOUND_VOLUME = 0.1
local SOUND_CHANNEL = "ui"

function widget:CommandNotify(cmdID, cmdParams)
	if cmdID == CMD_WANT_CLOAK and cmdParams and cmdParams[1] ~= nil then
		if cmdParams[1] == 1 then
			Spring.PlaySoundFile(SOUND_CLOAK_ON, SOUND_VOLUME, SOUND_CHANNEL)
		else
			Spring.PlaySoundFile(SOUND_CLOAK_OFF, SOUND_VOLUME, SOUND_CHANNEL)
		end
	end
end
