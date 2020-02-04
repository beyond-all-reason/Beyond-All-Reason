--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:GetInfo()
    return {
        name      = "Voice Notifs",
        desc      = "Plays various voice notifications",
        author    = "Doo, Floris",
        date      = "2018",
        license   = "GNU GPL, v2 or later",
        version   = 1,
        layer     = 5,
        enabled   = true  --  loaded by default?
    }
end

local volume = 1
local playTrackedPlayerNotifs = true
local muteWhenIdle = true
local idleTime = 6		-- after this much sec: mark user as idle
local displayMessages = true
local spoken = true


local soundFolder = "LuaUI/Sounds/VoiceNotifs/"
local Sound = {
	eCommDestroyed = {
		'LuaUI/Sounds/VoiceNotifs/eCommDestroyed.wav',
		1, 		-- min delay
		1,		-- relative volume
		1.7,	-- duration (optional, but define for sounds longer than 2 seconds)
		'An enemy commander has died',		-- text passed to the messages widget
	},
	aCommLost = {soundFolder..'aCommLost.wav', 1, 0.8, 1.75, 'A friendly commander has died'},
	ComHeavyDamage = {soundFolder..'ComHeavyDamage.wav', 12, 0.6, 2.25, 'Your commander is receiving heavy damage'},

	NukeLaunched = {soundFolder..'NukeLaunched.wav', 3, 0.8, 2, 'Nuclear missile launch detected'},
	IdleBuilder = {soundFolder..'IdleBuilder.wav', 30, 0.6, 1.9, 'A builder has finished building'},
	GameStarted = {soundFolder..'GameStarted.wav', 1, 0.6, 1, 'Battle started'},
	GamePause = {soundFolder..'GamePause.wav', 5, 0.6, 1, 'Battle paused'},
	PlayerLeft = {soundFolder..'PlayerDisconnected.wav', 1, 0.6, 1.65, 'A player has disconnected'},
	UnitsReceived = {soundFolder..'UnitReceived.wav', 4, 0.8, 1.75, "You've received new units"},
	ChooseStartLoc = {soundFolder..'ChooseStartLoc.wav', 90, 0.8, 2.2, "Choose your starting location"},

	--UnitLost = {soundFolder..'UnitLost.wav', 20, 0.6, 1.2, 'Unit lost'},
	RadarLost = {soundFolder..'RadarLost.wav', 8, 0.6, 1, 'Radar lost'},
	AdvRadarLost = {soundFolder..'AdvRadarLost.wav', 8, 0.6, 1.32, 'Advanced radar lost'},
	MexLost = {soundFolder..'MexLost.wav', 8, 0.6, 1.53, 'Metal extractor lost'},
	--T2MexLost = {soundFolder..'T2MexLost.wav', 8, 0.6, 2.34, 'Tech 2 metal extractor lost'},

	LowPower = {soundFolder..'LowPower.wav', 20, 0.6, 0.95, 'Low power'},
	TeamWastingMetal = {soundFolder..'teamwastemetal.wav', 22, 0.6, 1.7, 'Your team is wasting metal'},		-- top bar widget calls this
	TeamWastingEnergy = {soundFolder..'teamwasteenergy.wav', 30, 0.6, 1.76, 'Your team is wasting energy'},		-- top bar widget calls this
	MetalStorageFull = {soundFolder..'metalstorefull.wav', 40, 0.6, 1.62, 'Metal storage is full'},		-- top bar widget calls this
	EnergyStorageFull = {soundFolder..'energystorefull.wav', 40, 0.6, 1.65, 'Energy storage is full'},	-- top bar widget calls this

	AircraftSpotted = {soundFolder..'AircraftSpotted.wav', 9999999, 0.6, 1.25, 'Aircraft spotted'},	-- top bar widget calls this
	T2Detected = {soundFolder..'T2UnitDetected.wav', 9999999, 0.6, 1.5, 'Tech 2 unit detected'},	-- top bar widget calls this
	T3Detected = {soundFolder..'T3UnitDetected.wav', 9999999, 0.6, 1.94, 'Tech 3 unit detected'},	-- top bar widget calls this
	LrpcTargetUnits = {soundFolder..'LrpcTargetUnits.wav', 9999999, 0.6, 3.8, 'Enemy "Long Range Plasma Cannon(s)" (LRPC) are targeting your units '},

	MinesDetected = {soundFolder..'MinesDetected.wav', 200, 0.6, 2.6, 'Warning: mines have been detected'},
	IntrusionCountermeasure = {soundFolder..'StealthyUnitsInRange.wav', 30, 0.6, 4.8, 'Stealthy units detected within the "Intrusion countermeasure" range'},
	EMPmissilesiloDetected = {soundFolder..'EmpSiloDetected.wav', 4, 0.6, 2.1, 'EMP missile silo detected'},
	TacticalNukeSiloDetected = {soundFolder..'TacticalNukeDetected.wav', 4, 0.6, 2, 'Tactical nuke silo detected'},
	NuclearSiloDetected = {soundFolder..'NuclearSiloDetected.wav', 4, 0.6, 1.7, 'Nuclear silo detected'},
	LrpcDetected = {soundFolder..'LrpcDetected.wav', 25, 0.6, 2.3, '"Long Range Plasma Cannon(s)" (LRPC) detected'},
	NuclearBomberDetected = {soundFolder..'NuclearBomberDetected.wav', 60, 0.6, 1.6, 'Nuclear bomber detected'},
	JuggernautDetected = {soundFolder..'JuggernautDetected.wav', 9999999, 0.6, 1.4, 'Juggernaut detected'},
	KrogothDetected = {soundFolder..'KrogothDetected.wav', 9999999, 0.6, 1.25, 'Krogoth detected'},
	BanthaDetected = {soundFolder..'BanthaDetected.wav', 9999999, 0.6, 1.25, 'Bantha detected'},
	FlagshipDetected = {soundFolder..'FlagshipDetected.wav', 9999999, 0.6, 1.4, 'Flagship detected'},
	CommandoDetected = {soundFolder..'CommandoDetected.wav', 9999999, 0.6, 1.28, 'Commando detected'},
	TransportDetected = {soundFolder..'TransportDetected.wav', 9999999, 0.6, 1.5, 'Transport located'},
	AirTrainsportDetected = {soundFolder..'AirTransportDetected.wav', 9999999, 0.6, 1.38, 'Air transport spotted'},
	SeaTrainsportDetected = {soundFolder..'SeaTransportDetected.wav', 9999999, 0.6, 1.95, 'Sea transport located'},

}
local unitsOfInterest = {}
unitsOfInterest[UnitDefNames['armemp'].id] = 'EMPmissilesiloDetected'
unitsOfInterest[UnitDefNames['cortron'].id] = 'TacticalNukeSiloDetected'
unitsOfInterest[UnitDefNames['armsilo'].id] = 'NuclearSiloDetected'
unitsOfInterest[UnitDefNames['corsilo'].id] = 'NuclearSiloDetected'
unitsOfInterest[UnitDefNames['corint'].id] = 'LrpcDetected'
unitsOfInterest[UnitDefNames['armbrtha'].id] = 'LrpcDetected'
unitsOfInterest[UnitDefNames['corbuzz'].id] = 'LrpcDetected'
unitsOfInterest[UnitDefNames['armvulc'].id] = 'LrpcDetected'
unitsOfInterest[UnitDefNames['armliche'].id] = 'NuclearBomberDetected'
unitsOfInterest[UnitDefNames['corjugg'].id] = 'JuggernautDetected'
unitsOfInterest[UnitDefNames['corkrog'].id] = 'KrogothDetected'
unitsOfInterest[UnitDefNames['armbanth'].id] = 'BanthaDetected'
unitsOfInterest[UnitDefNames['armepoch'].id] = 'FlagshipDetected'
unitsOfInterest[UnitDefNames['corblackhy'].id] = 'FlagshipDetected'
unitsOfInterest[UnitDefNames['cormando'].id] = 'CommandoDetected'
unitsOfInterest[UnitDefNames['armthovr'].id] = 'TransportDetected'
unitsOfInterest[UnitDefNames['corthovr'].id] = 'TransportDetected'
unitsOfInterest[UnitDefNames['corintr'].id] = 'TransportDetected'
unitsOfInterest[UnitDefNames['armatlas'].id] = 'AirTrainsportDetected'
unitsOfInterest[UnitDefNames['corvalk'].id] = 'AirTrainsportDetected'
unitsOfInterest[UnitDefNames['armdfly'].id] = 'AirTrainsportDetected'
unitsOfInterest[UnitDefNames['corseah'].id] = 'AirTrainsportDetected'
unitsOfInterest[UnitDefNames['armtship'].id] = 'SeaTrainsportDetected'
unitsOfInterest[UnitDefNames['cortship'].id] = 'SeaTrainsportDetected'

-- adding duration
local silenceDuration = 0.6
for i,v in pairs(Sound) do
	if not Sound[i][4] then
		Sound[i][4] = 2 + silenceDuration
	else
		Sound[i][4] = Sound[i][4] + silenceDuration
	end
end

local LastPlay = {}
-- adding so they wont get immediately triggered after gamestart
LastPlay['TeamWastingMetal'] = Spring.GetGameFrame()+300
LastPlay['TeamWastingEnergy'] = Spring.GetGameFrame()+300
LastPlay['MetalStorageFull'] = Spring.GetGameFrame()+300
LastPlay['EnergyStorageFull'] = Spring.GetGameFrame()+300


local soundQueue = {}
local nextSoundQueued = 0
local taggedUnitsOfInterest = {}

local soundList = {}
for k, v in pairs(Sound) do
	soundList[k] = true
end

local passedTime = 0
local sec = 0
local spIsUnitAllied = Spring.IsUnitAllied
local spGetUnitDefID = Spring.GetUnitDefID
local spIsUnitInView = Spring.IsUnitInView
local spGetUnitHealth = Spring.GetUnitHealth

local isIdle = false
local lastUserInputTime = os.clock()
local lastMouseX, lastMouseY = Spring.GetMouseState()

local isSpec = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local myAllyTeamID = Spring.GetMyAllyTeamID()


local isCommander = {}
for udefID,def in ipairs(UnitDefs) do
	if def.customParams.iscommander then
		isCommander[udefID] = true
	end
end

local commanders = {}
local commandersDamages = {}
function updateCommanders()
	local units = Spring.GetTeamUnits(myTeamID)
	for i=1,#units do
		local unitID    = units[i]
		local unitDefID = spGetUnitDefID(unitID)
		if isCommander[unitDefID] then
			local health,maxHealth,paralyzeDamage,captureProgress,buildProgress = spGetUnitHealth(unitID)
			commanders[unitID] = maxHealth
		end
	end
end

local isAircraft = {}
local isT2 = {}
local isT3 = {}
local isMine = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canFly then
		isAircraft[unitDefID] = true
	end
	if unitDef.customParams and unitDef.customParams.techlevel then
		if unitDef.customParams.techlevel == '2' and not unitDef.customParams.iscommander then
			isT2[unitDefID] = true
		end
		if unitDef.customParams.techlevel == '3' then
			isT3[unitDefID] = true
		end
	end
	if unitDef.modCategories.mine then
		isMine[unitDefID] = true
	end
end

function widget:PlayerChanged(playerID)
	isSpec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
	myPlayerID = Spring.GetMyPlayerID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	updateCommanders()
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
	WG['voicenotifs'].getSpoken = function()
		return spoken
	end
	WG['voicenotifs'].setSpoken = function(value)
		spoken = value
	end
	WG['voicenotifs'].getMessages = function()
		return displayMessages
	end
	WG['voicenotifs'].setMessages = function(value)
		displayMessages = value
	end
    WG['voicenotifs'].getPlayTrackedPlayerNotifs = function()
        return playTrackedPlayerNotifs
    end
	WG['voicenotifs'].setPlayTrackedPlayerNotifs = function(value)
		playTrackedPlayerNotifs = value
	end
	WG['voicenotifs'].addEvent = function(value)
		if Sound[value] then
			Sd(value)
		end
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

function widget:UnitEnteredLos(unitID, allyTeam)
	if spIsUnitAllied(unitID) then return end

	local udefID = spGetUnitDefID(unitID)

	-- single detection events below
	if isAircraft[udefID] then
		Sd('AircraftSpotted')
	end
	if isT2[udefID] then
		Sd('T2Detected')
	end
	if isT3[udefID] then
		Sd('T3Detected')
	end
	if isMine[udefID] then
		local x,_,z = Spring.GetUnitPosition(unitID)
		local units = Spring.GetUnitsInCylinder(x,z,1700, myTeamID)
		if #units > 0 then		-- ignore when far away
			Sd('MinesDetected')
		end
	end

	-- notify about units of interest
	if udefID and unitsOfInterest[udefID] and not taggedUnitsOfInterest[unitID] then
		taggedUnitsOfInterest[unitID] = true
		Sd(unitsOfInterest[udefID])
	end
end


function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
    if unitTeam == myTeamID and isCommander[unitDefID] then
        commanders[unitID] = select(2, spGetUnitHealth(unitID))
    end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
    if unitTeam == myTeamID and isCommander[unitDefID] then
        commanders[unitID] = select(2, spGetUnitHealth(unitID))
    end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, damage, paralyzer)
    if unitTeam == myTeamID and isCommander[unitDefID] then
        commanders[unitID] = select(2, spGetUnitHealth(unitID))
    end
end


function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)

	-- notify when commander gets heavy damage
	if unitTeam == myTeamID and commanders[unitID] and not spIsUnitInView(unitID) then
		if not commandersDamages[unitID] then
			commandersDamages[unitID] = {}
		end
		local gameframe = Spring.GetGameFrame()
		commandersDamages[unitID][gameframe] = damage		-- if widget:UnitDamaged can be called multiple times during 1 gameframe then you need to add those up, i dont know

		-- count total damage of last few secs
        local totalDamage = 0
        local startGameframe = gameframe - (5.5 * 30)
        for gf,damage in pairs(commandersDamages[unitID]) do
            if gf > startGameframe then
                totalDamage = totalDamage + damage
            else
                commandersDamages[unitID][gf] = nil
            end
        end
        if totalDamage >= commanders[unitID] * 0.12 then
            Sd('ComHeavyDamage')
        end
	end
end

function widget:UnitDestroyed(unitID, unitDefID, teamID)
	taggedUnitsOfInterest[unitID] = nil
    commanders[unitID] = nil
    commandersDamages[unitID] = nil
end

function playNextSound()
	if #soundQueue > 0 then
		local event = soundQueue[1]
		nextSoundQueued = sec + Sound[event][4]
		if not muteWhenIdle or not isIdle then
			if spoken then
				Spring.PlaySoundFile(Sound[event][1], volume * Sound[event][3], 'ui')
			end
			if displayMessages and WG['messages'] and Sound[event][5] then
				WG['messages'].addMessage(Sound[event][5])
			end
		end
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

		-- process sound queue
		if sec >= nextSoundQueued then
			playNextSound()
		end

		-- check idle status
		local mouseX, mouseY = Spring.GetMouseState()
		if mouseX ~= lastMouseX or mouseY ~= lastMouseY then
			lastUserInputTime = os.clock()
		end
		lastMouseX, lastMouseY = mouseX, mouseY
		if lastUserInputTime < os.clock() - idleTime then
			isIdle = true
		else
			isIdle = false
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
				LastPlay[event] = Spring.GetGameFrame()
			elseif LastPlay[event] and Spring.GetGameFrame() >= LastPlay[event] + (Sound[event][2] * 30) then
				soundQueue[#soundQueue+1] = event
                LastPlay[event] = Spring.GetGameFrame()
			end
		end
	end
end

function widget:MousePress()
	lastUserInputTime = os.clock()
end

function widget:MouseWheel()
	lastUserInputTime = os.clock()
end

function widget:KeyPress()
	lastUserInputTime = os.clock()
end


function widget:GetConfigData(data)
	return {
		soundList = soundList,
		volume = volume,
		spoken = spoken,
		displayMessages = displayMessages,
		playTrackedPlayerNotifs = playTrackedPlayerNotifs,
		LastPlay = LastPlay,
	}
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
	if data.spoken ~= nil then
		spoken = data.spoken
	end
	if data.displayMessages ~= nil then
		displayMessages = data.displayMessages
	end
	if data.playTrackedPlayerNotifs ~= nil then
		playTrackedPlayerNotifs = data.playTrackedPlayerNotifs
	end
	if Spring.GetGameFrame() > 0 then
		if data.LastPlay then
			LastPlay = data.LastPlay
		end
	end
end