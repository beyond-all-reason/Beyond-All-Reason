local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Set target click sound",
		desc = "Plays a UI click sound whenever the set target command is used",
		author = "Zain M",
		date = "December 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

local CMD_SET_TARGET = GameCMD.UNIT_SET_TARGET
local CMD_SET_TARGET_NO_GROUND = GameCMD.UNIT_SET_TARGET_NO_GROUND
--File "click3" used from https://mixkit.co/free-sound-effects/click/
--free sound license, https://mixkit.co/terms/

local SOUND_FILE = "luaui/sounds/click3.wav"
local SOUND_VOLUME = 0.15
local SOUND_CHANNEL = "ui"

function widget:CommandNotify(cmdID)
	if cmdID == CMD_SET_TARGET or cmdID == CMD_SET_TARGET_NO_GROUND then
		Spring.PlaySoundFile(SOUND_FILE, SOUND_VOLUME, SOUND_CHANNEL)
	end
end
