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

local volume = 1
local isSpec = Spring.GetSpectatingState()
local playTrackedPlayerNotifs = true

local Sound = {
	eCommDestroyed = {
		"LuaUI/Sounds/VoiceNotifs/eCommDestroyed.wav",
		1, 		-- min delay
		1,		-- relative volume
		1.7,	-- duration (optional, but define for sounds longer than 2 seconds)
	},
	aCommLost = {"LuaUI/Sounds/VoiceNotifs/aCommLost.wav", 1, 0.8, 1.75},
	NukeLaunched = {"LuaUI/Sounds/VoiceNotifs/NukeLaunched.wav", 3, 0.8, 2},
	IdleBuilder = {"LuaUI/Sounds/VoiceNotifs/IdleBuilder.wav", 30, 0.6, 1.9},
	UnitLost = {"LuaUI/Sounds/VoiceNotifs/UnitLost.wav", 20, 0.6, 1.2},
	GameStarted = {"LuaUI/Sounds/VoiceNotifs/GameStarted.wav", 1, 0.6, 1},
	GamePause = {"LuaUI/Sounds/VoiceNotifs/GamePause.wav", 5, 0.6, 1},
	PlayerLeft = {"LuaUI/Sounds/VoiceNotifs/PlayerLeft.wav", 1, 0.6, 1.65},
	UnitsReceived = {"LuaUI/Sounds/VoiceNotifs/UnitReceived.wav", 10, 0.8, 1.75},
	LowPower = {"LuaUI/Sounds/VoiceNotifs/LowPower.wav", 20, 0.6, 3.2},
	IntrusionCountermeasure = {"LuaUI/Sounds/VoiceNotifs/StealthyUnitsInRange.wav", 15, 0.6, 4.8},
}
-- adding duration
local silenceDuration = 0.7
for i,v in pairs(Sound) do
	if not Sound[i][4] then
		Sound[i][4] = 2 + silenceDuration
	else
		Sound[i][4] = Sound[i][4] + silenceDuration
	end
end

local soundQueue = {}
local nextSoundQueued = 0

local passedTime = 0
local sec = 0

local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local isSpec = Spring.GetSpectatingState()

local LastPlay = {}
local soundList = {UnitLost=false}	-- stores if sound is enabled/disabled
for sound, params in pairs(Sound) do
	soundList[sound] = true
end

function widget:PlayerChanged(playerID)
	isSpec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
	myPlayerID = Spring.GetMyPlayerID()
end

function widget:Initialize()
	if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
		widget:PlayerChanged()
	end
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
    WG['voicenotifs'].getVolume = function()
        return volume
    end
    WG['voicenotifs'].setVolume = function(value)
        volume = value
    end
    WG['voicenotifs'].getPlayTrackedPlayerNotifs = function()
        return playTrackedPlayerNotifs
    end
    WG['voicenotifs'].setPlayTrackedPlayerNotifs = function(value)
        playTrackedPlayerNotifs = value
    end
end

function widget:Shutdown()
	WG['voicenotifs'] = nil
	widgetHandler:DeregisterGlobal('EventBroadcast')
end


local lowpowerThreshold = 6		-- if there is X secs a low power situation
local lowpowerDuration = 0
function widget:GameFrame(gf)
	if gf % 30 == 15 then
		-- low power check
		local currentLevel, storage, pull, income, expense, share, sent, received = Spring.GetTeamResources(myTeamID,'energy')
		if (currentLevel / storage) < 0.025 and currentLevel < 3000 then
			lowpowerDuration = lowpowerDuration + 1
			if lowpowerDuration >= lowpowerThreshold then
				Sd('LowPower')
				lowpowerDuration = 0
			end
		end
	end
end


function playNextSound()
	if #soundQueue > 0 then
		local event = soundQueue[1]
		nextSoundQueued = sec + Sound[event][4]
		Spring.PlaySoundFile(Sound[event][1], volume * Sound[event][3], 'ui')
		LastPlay[event] = Spring.GetGameFrame()

		local newQueue = {}
		for i,v in pairs(soundQueue) do
			if i ~= 1 then
				newQueue[#newQueue+1] = v
			end
		end
		soundQueue = newQueue
	end
end


function widget:Update(dt)
	sec = sec + dt

    myTeamID = Spring.GetMyTeamID()
    myPlayerID = Spring.GetMyPlayerID()
    isSpec = Spring.GetSpectatingState()

    passedTime = passedTime + dt
    if passedTime > 0.2 then
        passedTime = passedTime - 0.2
        if WG['advplayerlist_api'] and WG['advplayerlist_api'].GetLockPlayerID ~= nil then
            lockPlayerID = WG['advplayerlist_api'].GetLockPlayerID()
        end

		-- process sound soundQueue
		if sec >= nextSoundQueued then
			playNextSound()
		end
    end
end

function EventBroadcast(msg)
	if not isSpec or (isSpec and playTrackedPlayerNotifs and lockPlayerID ~= nil) then
        if string.find(msg, "SoundEvents") then
            msg = string.sub(msg, 13)
            event = string.sub(msg, 1, string.find(msg, " ")-1)
            player = string.sub(msg, string.find(msg, " ")+1, string.len(msg))
            if (tonumber(player) and (tonumber(player) == Spring.GetMyPlayerID())) or (isSpec and tonumber(player) == lockPlayerID) then
                Sd(event)
            end
        end
	end
end

function Sd(event)
	if not isSpec or (isSpec and playTrackedPlayerNotifs and lockPlayerID ~= nil) then
		if soundList[event] and Sound[event] then
			if not LastPlay[event] then
				soundQueue[#soundQueue+1] = event
			elseif LastPlay[event] and (Spring.GetGameFrame() >= (LastPlay[event] + Sound[event][2] * 30)) then
				soundQueue[#soundQueue+1] = event
			end
		end
	end
end


function widget:GetConfigData(data)
	return {soundList = soundList, volume = volume, playTrackedPlayerNotifs = playTrackedPlayerNotifs}
end

function widget:SetConfigData(data)
	if data.soundList ~= nil then
		for sound, enabled in pairs(data.soundList) do
			if Sound[sound] then
				soundList[sound] = enabled
			end
		end
	end
    if data.volume ~= nil then
        volume = data.volume
    end
    if data.playTrackedPlayerNotifs ~= nil then
        playTrackedPlayerNotifs = data.playTrackedPlayerNotifs
    end
end