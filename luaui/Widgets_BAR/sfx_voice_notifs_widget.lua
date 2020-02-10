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
local idleBuilderNotificationDelay = 10 * 30	-- (in gameframes)
local lowpowerThreshold = 6		-- if there is X secs a low power situation


local soundFolder = "Sounds/voice/"
local Sound = {}
local SoundOrder = {}

function addSound(name, file, minDelay, volume, duration, message)
	Sound[name] = {file, minDelay, volume, duration, message}
	SoundOrder[#SoundOrder+1] = name
end

addSound('EnemyCommanderDied', 'EnemyCommanderDied.wav', 1, 1, 1.7, 'An enemy commander has died')
addSound('FriendlyCommanderDied', 'FriendlyCommanderDied.wav', 1, 0.8, 1.75, 'A friendly commander has died')
addSound('ComHeavyDamage', 'ComHeavyDamage.wav', 12, 0.6, 2.25, 'Your commander is receiving heavy damage')

addSound('GameStarted', 'GameStarted.wav', 1, 0.6, 1, 'Battle started')
addSound('GamePause', 'GamePause.wav', 5, 0.6, 1, 'Battle paused')
addSound('IdleBuilder', 'IdleBuilder.wav', 30, 0.6, 1.9, 'A builder has finished building')
addSound('UnitsReceived', 'UnitReceived.wav', 4, 0.8, 1.75, "You've received new units")
addSound('ChooseStartLoc', 'ChooseStartLoc.wav', 90, 0.8, 2.2, "Choose your starting location")

addSound('PlayerLeft', 'PlayerDisconnected.wav', 1, 0.6, 1.65, 'A player has disconnected')
addSound('PlayerAdded', 'PlayerAdded.wav', 1, 0.6, 2.36, 'A player has been added to the game')

addSound('RadarLost', 'RadarLost.wav', 8, 0.6, 1, 'Radar lost')
addSound('AdvRadarLost', 'AdvRadarLost.wav', 8, 0.6, 1.32, 'Advanced radar lost')
addSound('MexLost', 'MexLost.wav', 8, 0.6, 1.53, 'Metal extractor lost')

addSound('YouAreOverflowingMetal', 'YouAreOverflowingMetal.wav', 35, 0.6, 1.63, 'Your are overflowing metal')
addSound('YouAreOverflowingEnergy', 'unused/energystorefull.wav', 40, 0.6, 1.7, 'Your are overflowing energy')
addSound('YouAreWastingMetal', 'YouAreWastingMetal.wav', 25, 0.6, 1.5, 'Your are wasting metal')
addSound('YouAreWastingEnergy', 'unused/energystorefull.wav', 35, 0.6, 1.57, 'Your are wasting energy')
addSound('WholeTeamWastingMetal', 'WholeTeamWastingMetal.wav', 22, 0.6, 1.82, 'The whole team is wasting metal')
addSound('WholeTeamWastingEnergy', 'unused/energystorefull.wav', 30, 0.6, 1.9, 'The whole team is wasting energy')
--addSound('MetalStorageFull', 'metalstorefull.wav', 40, 0.6, 1.62, 'Metal storage is full')
--addSound('EnergyStorageFull', 'energystorefull.wav', 40, 0.6, 1.65, 'Energy storage is full')
addSound('LowPower', 'LowPower.wav', 20, 0.6, 0.95, 'Low power')

addSound('NukeLaunched', 'NukeLaunched.wav', 3, 0.8, 2, 'Nuclear missile launch detected')
addSound('LrpcTargetUnits', 'LrpcTargetUnits.wav', 9999999, 0.6, 3.8, 'Enemy "Long Range Plasma Cannon(s)" (LRPC) are targeting your units')

addSound('VulcanIsReady', 'VulcanIsReady.wav', 30, 0.6, 1.16, 'Vulcan is ready')
addSound('BuzzsawIsReady', 'BuzzsawIsReady.wav', 30, 0.6, 1.31, 'Buzzsaw is ready')
addSound('Tech3UnitReady', 'Tech3UnitReady.wav', 9999999, 0.6, 1.78, 'Tech 3 unit is ready')

addSound('T2Detected', 'T2UnitDetected.wav', 9999999, 0.6, 1.5, 'Tech 2 unit detected')	-- top bar widget calls this
addSound('T3Detected', 'T3UnitDetected.wav', 9999999, 0.6, 1.94, 'Tech 3 unit detected')	-- top bar widget calls this

addSound('AircraftSpotted', 'AircraftSpotted.wav', 9999999, 0.6, 1.25, 'Aircraft spotted')	-- top bar widget calls this
addSound('MinesDetected', 'MinesDetected.wav', 200, 0.6, 2.6, 'Warning: mines have been detected')
addSound('IntrusionCountermeasure', 'StealthyUnitsInRange.wav', 30, 0.6, 4.8, 'Stealthy units detected within the "Intrusion countermeasure" range')

addSound('LrpcDetected', 'LrpcDetected.wav', 25, 0.6, 2.3, '"Long Range Plasma Cannon(s)" (LRPC) detected')
addSound('EMPmissilesiloDetected', 'EmpSiloDetected.wav', 4, 0.6, 2.1, 'EMP missile silo detected')
addSound('TacticalNukeSiloDetected', 'TacticalNukeDetected.wav', 4, 0.6, 2, 'Tactical nuke silo detected')
addSound('NuclearSiloDetected', 'NuclearSiloDetected.wav', 4, 0.6, 1.7, 'Nuclear silo detected')
addSound('NuclearBomberDetected', 'NuclearBomberDetected.wav', 60, 0.6, 1.6, 'Nuclear bomber detected')
addSound('JuggernautDetected', 'JuggernautDetected.wav', 9999999, 0.6, 1.4, 'Juggernaut detected')
addSound('KrogothDetected', 'KrogothDetected.wav', 9999999, 0.6, 1.25, 'Krogoth detected')
addSound('BanthaDetected', 'BanthaDetected.wav', 9999999, 0.6, 1.25, 'Bantha detected')
addSound('FlagshipDetected', 'FlagshipDetected.wav', 9999999, 0.6, 1.4, 'Flagship detected')
addSound('CommandoDetected', 'CommandoDetected.wav', 9999999, 0.6, 1.28, 'Commando detected')
addSound('TransportDetected', 'TransportDetected.wav', 9999999, 0.6, 1.5, 'Transport located')
addSound('AirTransportDetected', 'AirTransportDetected.wav', 9999999, 0.6, 1.38, 'Air transport spotted')
addSound('SeaTransportDetected', 'SeaTransportDetected.wav', 9999999, 0.6, 1.95, 'Sea transport located')


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
unitsOfInterest[UnitDefNames['armatlas'].id] = 'AirTransportDetected'
unitsOfInterest[UnitDefNames['corvalk'].id] = 'AirTransportDetected'
unitsOfInterest[UnitDefNames['armdfly'].id] = 'AirTransportDetected'
unitsOfInterest[UnitDefNames['corseah'].id] = 'AirTransportDetected'
unitsOfInterest[UnitDefNames['armtship'].id] = 'SeaTransportDetected'
unitsOfInterest[UnitDefNames['cortship'].id] = 'SeaTransportDetected'


local spGetGameFrame = Spring.GetGameFrame
local LastPlay = {}
-- adding so they wont get immediately triggered after gamestart
LastPlay['TeamWastingMetal'] = spGetGameFrame()+300
LastPlay['TeamWastingEnergy'] = spGetGameFrame()+300
LastPlay['MetalStorageFull'] = spGetGameFrame()+300
LastPlay['EnergyStorageFull'] = spGetGameFrame()+300


local soundList = {}
for k, v in pairs(Sound) do
	soundList[k] = true
end


local soundQueue = {}
local nextSoundQueued = 0
local taggedUnitsOfInterest = {}
local lowpowerDuration = 0
local idleBuilder = {}
local commanders = {}
local commandersDamages = {}
local passedTime = 0
local sec = 0
local lastUnitCommand = Spring.GetGameFrame()

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

local vulcanDefID = UnitDefNames['armvulc'].id
local buzzsawDefID = UnitDefNames['corbuzz'].id

local isCommander = {}
local isBuilder = {}
for udefID,def in ipairs(UnitDefs) do
	if def.customParams.iscommander then
		isCommander[udefID] = true
	end
	if def.isBuilder and def.canAssist then
		isBuilder[udefID] = true
	end
end

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
	if Spring.IsReplay() or spGetGameFrame() > 0 then
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
		local soundInfo = {}
		for i, v in pairs(SoundOrder) do
			soundInfo[i] = {v, soundList[v], Sound[v][5]}
		end
		return soundInfo
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
	WG['voicenotifs'].addSound = function(name, file, minDelay, volume, duration, message)
		addSound(name, file, minDelay, volume, duration, message)
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

		-- idle builder check
		for unitID, frame in pairs(idleBuilder) do
			if spIsUnitInView(unitID) then
				idleBuilder[unitID] = nil
			elseif frame < gf then
				Sd('IdleBuilder')
				idleBuilder[unitID] = nil	-- do not repeat
			end
		end
	end
end


function widget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag)
	idleBuilder[unitID] = nil
end


function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, playerID, fromSynced, fromLua)
	lastUnitCommand = spGetGameFrame()
end


function widget:UnitIdle(unitID)
	if isBuilder[spGetUnitDefID(unitID)] and not idleBuilder[unitID] and not spIsUnitInView(unitID) then
		idleBuilder[unitID] = spGetGameFrame() + idleBuilderNotificationDelay
	end
end


function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam == myTeamID then
		if unitDefID == vulcanDefID then
			Sd('VulcanIsReady')
		elseif unitDefID == buzzsawDefID then
			Sd('BuzzsawIsReady')
		elseif isT3[unitDefID] then
			Sd('Tech3UnitReady')
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
		local gameframe = spGetGameFrame()
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
			if spoken and Sound[event][1] ~= '' then
				Spring.PlaySoundFile(soundFolder..Sound[event][1], volume * Sound[event][3], 'ui')
			end
			if displayMessages and WG['messages'] and Sound[event][5] then
				WG['messages'].addMessage(Sound[event][5])
			end
		end
		LastPlay[event] = spGetGameFrame()

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
		-- set user idle when no mouse movement or no commands have been given
		if lastUserInputTime < os.clock() - idleTime  or  spGetGameFrame() - lastUnitCommand > (idleTime*40) then
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
				LastPlay[event] = spGetGameFrame()
			elseif LastPlay[event] and spGetGameFrame() >= LastPlay[event] + (Sound[event][2] * 30) then
				soundQueue[#soundQueue+1] = event
                LastPlay[event] = spGetGameFrame()
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
	if spGetGameFrame() > 0 then
		if data.LastPlay then
			LastPlay = data.LastPlay
		end
	end
end