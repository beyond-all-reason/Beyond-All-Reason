--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:GetInfo()
    return {
        name      = "Voice Notifs",
        desc      = "Plays various voice notifications",
        author    = "Doo",
        date      = "2018",
        license   = "GNU GPL, v2 or later",
        version   = 1,
        layer     = 5,
        enabled   = true  --  loaded by default?
    }
end

local Sound = {
	eCommDestroyed = {
		"LuaUI/Sounds/VoiceNotifs/eCommDestroyed.wav",
		1, 		-- min delay
	},
	aCommLost = {"LuaUI/Sounds/VoiceNotifs/aCommLost.wav", 1},
	NukeLaunched = {"LuaUI/Sounds/VoiceNotifs/NukeLaunched.wav", 1},
	IdleBuilder = {"LuaUI/Sounds/VoiceNotifs/IdleBuilder.wav", 30},
	UnitLost = {"LuaUI/Sounds/VoiceNotifs/UnitLost.wav", 30},
	GameStarted = {"LuaUI/Sounds/VoiceNotifs/GameStarted.wav", 1},
	GamePause = {"LuaUI/Sounds/VoiceNotifs/GamePause.wav", 60},
	PlayerLeft = {"LuaUI/Sounds/VoiceNotifs/PlayerLeft.wav", 1},
	UnitsReceived = {"LuaUI/Sounds/VoiceNotifs/UnitReceived.wav", 30},
}

local LastPlay = {}
local soundList = {}	-- stores if sound is enabled/disabled
for sound, params in pairs(Sound) do
	soundList[sound] = true
end

function widget:Initialize()
	widgetHandler:RegisterGlobal('EventBroadcast', EventBroadcast)

	WG['voicenotifs'] = {}
	for sound, params in pairs(Sound) do
		WG['voicenotifs']['getSound'..sound] = function()
			return (SoundDisabled[sound] and false or true)
		end
		WG['voicenotifs']['setSound'..sound] = function(value)
			soundList[sound] = value
		end
	end
	WG['voicenotifs'].getSoundList = function()
		return soundList
	end
end

function widget:Shutdown()
	WG['voicenotifs'] = nil
end

function EventBroadcast(msg)
	if string.find(msg, "SoundEvents") then
		msg = string.sub(msg, 13)
		event = string.sub(msg, 1, string.find(msg, " ")-1)
		player = string.sub(msg, string.find(msg, " ")+1, string.len(msg))
		if tonumber(player) and (tonumber(player) == Spring.GetMyPlayerID()) then
			Sd(event)
		end
	end
end

function Sd(event)
	if soundList[event] and Sound[event] then
		if not LastPlay[event] then
			Spring.PlaySoundFile(Sound[event][1], 1.0, 'ui')
			LastPlay[event] = Spring.GetGameFrame()
		elseif LastPlay[event] and (Spring.GetGameFrame() >= (LastPlay[event] + Sound[event][2] * 30)) then
			Spring.PlaySoundFile(Sound[event][1], 1.0, 'ui')
			LastPlay[event] = Spring.GetGameFrame()
		end
	end
end


function widget:GetConfigData(data)
	return {soundList = soundList}
end

function widget:SetConfigData(data)
	if data.soundList ~= nil then
		for sound, enabled in pairs(data.soundList) do
			if Sound[sound] then
				soundList[sound] = enabled
			end
		end
	end
end