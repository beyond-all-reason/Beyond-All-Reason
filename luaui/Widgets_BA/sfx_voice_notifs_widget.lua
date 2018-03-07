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

minDelay = {}
LastPlay = {}
Sound = {}

	UnitsReceived = 'UnitsReceived'
	SdUnitsReceived = "LuaUI/Sounds/VoiceNotifs/UnitReceived.wav"
	Sound[UnitsReceived] = SdUnitsReceived
	minDelay[UnitsReceived] = 30
	
	PlayerLeft = "PlayerLeft"
	SdPlayerLeft = "LuaUI/Sounds/VoiceNotifs/PlayerLeft.wav"
	Sound[PlayerLeft] = SdPlayerLeft
	minDelay[PlayerLeft] = 1
	
	GamePause = "GamePause"
	SdGamePause = "LuaUI/Sounds/VoiceNotifs/GamePause.wav"
	Sound[GamePause] = SdGamePause
	minDelay[GamePause] = 60
	
	GameStarted = "GameStarted"
	SdGameStarted = "LuaUI/Sounds/VoiceNotifs/GameStarted.wav"
	Sound[GameStarted] = SdGameStarted
	minDelay[GameStarted] = 1

	UnitLost = "UnitLost"
	SdUnitLost = "LuaUI/Sounds/VoiceNotifs/UnitLost.wav"
	Sound[UnitLost] = SdUnitLost
	minDelay[UnitLost] = 30

	IdleBuilder = "IdleBuilder"
	SdIdleBuilder = "LuaUI/Sounds/VoiceNotifs/IdleBuilder.wav"
	Sound[IdleBuilder] = SdIdleBuilder
	minDelay[IdleBuilder] = 30
	
	NukeLaunched = "NukeLaunched"
	SdNukeLaunched = "LuaUI/Sounds/VoiceNotifs/NukeLaunched.wav"
	Sound[NukeLaunched] = SdNukeLaunched
	minDelay[NukeLaunched] = 1

function widget:Initialize()
	widgetHandler:RegisterGlobal('EventBroadcast', EventBroadcast)
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
	if Sound[event] then
		if not LastPlay[event] then
			Spring.PlaySoundFile(Sound[event], 1.0, 'ui')
			LastPlay[event] = Spring.GetGameFrame()
		elseif LastPlay[event] and (Spring.GetGameFrame() >= (LastPlay[event] + minDelay[event] * 30)) then
			Spring.PlaySoundFile(Sound[event], 1.0, 'ui')
			LastPlay[event] = Spring.GetGameFrame()
		end
	end
end
