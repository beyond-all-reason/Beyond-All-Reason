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
local spGetGameFrame = Spring.GetGameFrame
local lastPlayedFrame = -1

local function playSetTargetSound()
	local frame = spGetGameFrame()
	if frame ~= lastPlayedFrame then
		lastPlayedFrame = frame
		Spring.PlaySoundFile(SOUND_FILE, SOUND_VOLUME, SOUND_CHANNEL)
	end
end

function widget:CommandNotify(cmdID)
	if cmdID == CMD_SET_TARGET or cmdID == CMD_SET_TARGET_NO_GROUND then
		playSetTargetSound()
	end
end

function widget:UnitCommandNotify(unitID, cmdID)
	if cmdID == CMD_SET_TARGET or cmdID == CMD_SET_TARGET_NO_GROUND then
		playSetTargetSound()
	end
end
