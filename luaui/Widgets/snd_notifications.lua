--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:GetInfo()
    return {
        name      = "Notifications",
        desc      = "Does various voice/text notifications",
        author    = "Doo, Floris",
        date      = "2018",
        version   = 1,
        layer     = 5,
        enabled   = true  --  loaded by default?
    }
end

--------------------------------------------------------------------------------

local silentTime = 0.7	-- silent time between queued notifications
local globalVolume = 0.7
local playTrackedPlayerNotifs = false
local muteWhenIdle = true
local idleTime = 6		-- after this much sec: mark user as idle
local displayMessages = true
local spoken = true
local idleBuilderNotificationDelay = 10 * 30	-- (in gameframes)
local lowpowerThreshold = 6		-- if there is X secs a low power situation
local tutorialPlayLimit = 3		-- display the same tutorial message only this many times in total (max is always 1 play per game)

--------------------------------------------------------------------------------

local LastPlay = {}
local soundFolder = "Sounds/voice/"
local Sound = {}
local soundList = {}
local SoundOrder = {}
local spGetGameFrame = Spring.GetGameFrame
local gameframe = spGetGameFrame()

local lockPlayerID
local gaiaTeamID = Spring.GetGaiaTeamID()

function addSound(name, file, minDelay, duration, message, unlisted)
	Sound[name] = {file, minDelay, duration, message}
	soundList[name] = true
	if not unlisted then
		SoundOrder[#SoundOrder+1] = name
	end
end

-- commanders
addSound('EnemyCommanderDied', 'EnemyCommanderDied.wav', 1, 1.7, Spring.I18N('tips.notifications.enemyCommanderDied'))
addSound('FriendlyCommanderDied', 'FriendlyCommanderDied.wav', 1, 1.75, Spring.I18N('tips.notifications.friendlyCommanderDied'))
addSound('ComHeavyDamage', 'ComHeavyDamage.wav', 12, 2.25, Spring.I18N('tips.notifications.commanderDamage'))

-- game status
addSound('ChooseStartLoc', 'ChooseStartLoc.wav', 90, 2.2, Spring.I18N('tips.notifications.startingLocation'))
addSound('GameStarted', 'GameStarted.wav', 1, 2, Spring.I18N('tips.notifications.gameStarted'))
addSound('GamePause', 'GamePause.wav', 5, 1, Spring.I18N('tips.notifications.gamePaused'))
addSound('PlayerLeft', 'PlayerDisconnected.wav', 1, 1.65, Spring.I18N('tips.notifications.playerLeft'))
addSound('PlayerAdded', 'PlayerAdded.wav', 1, 2.36,  Spring.I18N('tips.notifications.playerAdded'))

-- awareness
--addSound('IdleBuilder', 'IdleBuilder.wav', 30, 1.9, 'A builder has finished building')
addSound('UnitsReceived', 'UnitReceived.wav', 4, 1.75, Spring.I18N('tips.notifications.unitsReceived'))
addSound('RadarLost', 'RadarLost.wav', 8, 1, Spring.I18N('tips.notifications.radarLost'))
addSound('AdvRadarLost', 'AdvRadarLost.wav', 8, 1.32, Spring.I18N('tips.notifications.advancedRadarLost'))
addSound('MexLost', 'MexLost.wav', 8, 1.53, Spring.I18N('tips.notifications.metalExtractorLost'))

-- resources
addSound('YouAreOverflowingMetal', 'YouAreOverflowingMetal.wav', 35, 1.63, Spring.I18N('tips.notifications.overflowingMetal'))
--addSound('YouAreOverflowingEnergy', 'YouAreOverflowingEnergy.wav', 100, 1.7, 'Your are overflowing energy')
--addSound('YouAreWastingMetal', 'YouAreWastingMetal.wav', 25, 1.5, 'Your are wasting metal')
--addSound('YouAreWastingEnergy', 'YouAreWastingEnergy.wav', 35, 1.3, 'Your are wasting energy')
addSound('WholeTeamWastingMetal', 'WholeTeamWastingMetal.wav', 22, 1.82, Spring.I18N('tips.notifications.teamWastingMetal'))
addSound('WholeTeamWastingEnergy', 'WholeTeamWastingEnergy.wav', 100, 2.14, Spring.I18N('tips.notifications.teamWastingEnergy'))
--addSound('MetalStorageFull', 'metalstorefull.wav', 40, 1.62, 'Metal storage is full')
--addSound('EnergyStorageFull', 'energystorefull.wav', 40, 1.65, 'Energy storage is full')
addSound('LowPower', 'LowPower.wav', 20, 0.95, Spring.I18N('tips.notifications.lowPower'))
addSound('WindNotGood', 'WindNotGood.wav', 9999999, 3.76, Spring.I18N('tips.notifications.lowWind'))

-- added this so they wont get immediately triggered after gamestart
LastPlay['YouAreOverflowingMetal'] = spGetGameFrame()+300
--LastPlay['YouAreOverflowingEnergy'] = spGetGameFrame()+300
--LastPlay['YouAreWastingMetal'] = spGetGameFrame()+300
--LastPlay['YouAreWastingEnergy'] = spGetGameFrame()+300
LastPlay['WholeTeamWastingMetal'] = spGetGameFrame()+300
LastPlay['WholeTeamWastingEnergy'] = spGetGameFrame()+300

-- alerts
addSound('NukeLaunched', 'NukeLaunched.wav', 3, 2, Spring.I18N('tips.notifications.nukeLaunched'))
addSound('LrpcTargetUnits', 'LrpcTargetUnits.wav', 9999999, 3.8, Spring.I18N('tips.notifications.lrpcAttacking'))

-- unit ready
addSound('VulcanIsReady', 'VulcanIsReady.wav', 30, 1.16, Spring.I18N('tips.notifications.vulcanReady'))
addSound('BuzzsawIsReady', 'BuzzsawIsReady.wav', 30, 1.31, Spring.I18N('tips.notifications.buzzsawReady'))
addSound('Tech3UnitReady', 'Tech3UnitReady.wav', 9999999, 1.78, Spring.I18N('tips.notifications.t3Ready'))

-- detections
addSound('T2Detected', 'T2UnitDetected.wav', 9999999, 1.5, Spring.I18N('tips.notifications.t2Detected'))	-- top bar widget calls this
addSound('T3Detected', 'T3UnitDetected.wav', 9999999, 1.94, Spring.I18N('tips.notifications.t3Detected'))	-- top bar widget calls this

addSound('AircraftSpotted', 'AircraftSpotted.wav', 9999999, 1.25, Spring.I18N('tips.notifications.aircraftSpotted'))	-- top bar widget calls this
addSound('MinesDetected', 'MinesDetected.wav', 200, 2.6, Spring.I18N('tips.notifications.minesDetected'))
addSound('IntrusionCountermeasure', 'StealthyUnitsInRange.wav', 30, 4.8, Spring.I18N('tips.notifications.stealthDetected'))

-- unit detections
addSound('LrpcDetected', 'LrpcDetected.wav', 25, 2.3, Spring.I18N('tips.notifications.lrpcDetected'))
addSound('EMPmissilesiloDetected', 'EmpSiloDetected.wav', 4, 2.1, Spring.I18N('tips.notifications.empSiloDetected'))
addSound('TacticalNukeSiloDetected', 'TacticalNukeDetected.wav', 4, 2, Spring.I18N('tips.notifications.tacticalSiloDetected'))
addSound('NuclearSiloDetected', 'NuclearSiloDetected.wav', 4, 1.7, Spring.I18N('tips.notifications.nukeSiloDetected'))
addSound('NuclearBomberDetected', 'NuclearBomberDetected.wav', 60, 1.6, Spring.I18N('tips.notifications.nukeBomberDetected'))
addSound('JuggernautDetected', 'JuggernautDetected.wav', 9999999, 1.4, Spring.I18N('tips.notifications.t3MobileTurretDetected'))
addSound('KorgothDetected', 'KorgothDetected.wav', 9999999, 1.25, Spring.I18N('tips.notifications.t3AssaultBotDetected'))
addSound('BanthaDetected', 'BanthaDetected.wav', 9999999, 1.25, Spring.I18N('tips.notifications.t3AssaultMechDetected'))
addSound('FlagshipDetected', 'FlagshipDetected.wav', 9999999, 1.4, Spring.I18N('tips.notifications.flagshipDetected'))
addSound('CommandoDetected', 'CommandoDetected.wav', 9999999, 1.28, Spring.I18N('tips.notifications.commandoDetected'))
addSound('TransportDetected', 'TransportDetected.wav', 9999999, 1.5, Spring.I18N('tips.notifications.transportDetected'))
addSound('AirTransportDetected', 'AirTransportDetected.wav', 9999999, 1.38, Spring.I18N('tips.notifications.airTransportDetected'))
addSound('SeaTransportDetected', 'SeaTransportDetected.wav', 9999999, 1.95, Spring.I18N('tips.notifications.seaTransportDetected'))

-- tutorial explanations (unlisted)
local td = 'tutorial/'
addSound('t_welcome', td..'welcome.wav', 9999999, 9.19, Spring.I18N('tips.notifications.tutorialWelcome'), true)
addSound('t_buildmex', td..'buildmex.wav', 9999999, 6.31, Spring.I18N('tips.notifications.tutorialBuildMetal'), true)
addSound('t_buildenergy', td..'buildenergy.wav', 9999999, 6.47, Spring.I18N('tips.notifications.tutorialBuildenergy'), true)
addSound('t_makefactory', td..'makefactory.wav', 9999999, 8.87, Spring.I18N('tips.notifications.tutorialBuildFactory'), true)
addSound('t_factoryair', td..'factoryair.wav', 9999999, 8.2, Spring.I18N('tips.notifications.tutorialFactoryAir'), true)
addSound('t_factoryairsea', td..'factoryairsea.wav', 9999999, 7.39, Spring.I18N('tips.notifications.tutorialFactorySeaplanes'), true)
addSound('t_factorybots', td..'factorybots.wav', 9999999, 8.54, Spring.I18N('tips.notifications.tutorialFactoryBots'), true)
addSound('t_factoryhovercraft', td..'factoryhovercraft.wav', 9999999, 6.91, Spring.I18N('tips.notifications.tutorialFactoryHovercraft'), true)
addSound('t_factoryvehicles', td..'factoryvehicles.wav', 9999999, 11.92, Spring.I18N('tips.notifications.tutorialFactoryVehicles'), true)
addSound('t_factoryships', td..'factoryships.wav', 9999999, 15.82, Spring.I18N('tips.notifications.tutorialFactoryShips'), true)
addSound('t_readyfortech2', td..'readyfortecht2.wav', 9999999, 9.4, Spring.I18N('tips.notifications.tutorialT2Ready'), true)
addSound('t_duplicatefactory', td..'duplicatefactory.wav', 9999999, 6.1, Spring.I18N('tips.notifications.tutorialDuplicateFactory'), true)
addSound('t_paralyzer', td..'paralyzer.wav', 9999999, 9.66, Spring.I18N('tips.notifications.tutorialParalyzer'), true)


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
unitsOfInterest[UnitDefNames['corkorg'].id] = 'KorgothDetected'
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


local soundQueue = {}
local nextSoundQueued = 0
local hasBuildMex = false
local hasBuildEnergy = false
local taggedUnitsOfInterest = {}
local lowpowerDuration = 0
local idleBuilder = {}
local commanders = {}
local commandersDamages = {}
local passedTime = 0
local sec = 0
local lastUnitCommand = Spring.GetGameFrame()

local windNotGood = ((Game.windMin + Game.windMax) / 2) < 5.5

local spIsUnitAllied = Spring.IsUnitAllied
local spGetUnitDefID = Spring.GetUnitDefID
local spIsUnitInView = Spring.IsUnitInView
local spGetUnitHealth = Spring.GetUnitHealth

local isIdle = false
local lastUserInputTime = os.clock()
local lastMouseX, lastMouseY = Spring.GetMouseState()

local isSpec = Spring.GetSpectatingState()
local isReplay = Spring.IsReplay()
local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local myRank = select(9,Spring.GetPlayerInfo(myPlayerID))

local spGetTeamResources = Spring.GetTeamResources
local e_currentLevel, e_storage, e_pull, e_income, e_expense, e_share, e_sent, e_received = spGetTeamResources(myTeamID,'energy')
local m_currentLevel, m_storage, m_pull, m_income, m_expense, m_share, m_sent, m_received = spGetTeamResources(myTeamID,'metal')

local tutorialMode = (myRank == 0)
local doTutorialMode = tutorialMode
local tutorialPlayed = {}		-- store the number of times a tutorial event has played across games
local tutorialPlayedThisGame = {}	-- log that a tutorial event has played this game

local vulcanDefID = UnitDefNames['armvulc'].id
local buzzsawDefID = UnitDefNames['corbuzz'].id

local isFactoryAir = {[UnitDefNames['armap'].id] = true, [UnitDefNames['corap'].id] = true}
local isFactoryAirSea = {[UnitDefNames['armplat'].id] = true, [UnitDefNames['corplat'].id] = true}
local isFactoryVeh = {[UnitDefNames['armvp'].id] = true, [UnitDefNames['corvp'].id] = true}
local isFactoryBot = {[UnitDefNames['armlab'].id] = true, [UnitDefNames['corlab'].id] = true}
local isFactoryHover = {[UnitDefNames['armhp'].id] = true, [UnitDefNames['corhp'].id] = true}
local isFactoryShip = {[UnitDefNames['armsy'].id] = true, [UnitDefNames['corsy'].id] = true}
local numFactoryAir = 0
local numFactoryAirSea = 0
local numFactoryVeh = 0
local numFactoryBot = 0
local numFactoryHover = 0
local numFactoryShip = 0

local hasMadeT2 = false

local isCommander = {}
local isBuilder = {}
local isMex = {}
local isEnergyProducer = {}
local isWind = {}
local isAircraft = {}
local isT2 = {}
local isT3mobile = {}
local isMine = {}
for udefID,def in ipairs(UnitDefs) do
	-- not critter/chicken/object
	if not string.find(def.name, 'critter') and not string.find(def.name, 'chicken') and (not def.modCategories or not def.modCategories.object) then
		if def.canFly then
			isAircraft[udefID] = true
		end
		if def.customParams and def.customParams.techlevel then
			if def.customParams.techlevel == '2' and not def.customParams.iscommander then
				isT2[udefID] = true
			end
			if def.customParams.techlevel == '3' and not def.isBuilding then
				isT3mobile[udefID] = true
			end
		end
		if def.modCategories.mine then
			isMine[udefID] = true
		end
		if def.customParams.iscommander then
			isCommander[udefID] = true
		end
		if def.isBuilder and def.canAssist then
			isBuilder[udefID] = true
		end
		if def.windGenerator  and def.windGenerator  > 0 then
			isWind[udefID] = true
		end
		if def.extractsMetal > 0 then
			isMex[udefID] = true
		end
		if def.energyMake > 10 then
			isEnergyProducer[udefID] = def.energyMake
		end
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

function widget:PlayerChanged(playerID)
	isSpec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
	myPlayerID = Spring.GetMyPlayerID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	doTutorialMode = (not isReplay and not isSpec and tutorialMode)
	updateCommanders()
end


function widget:Initialize()
	if isReplay or spGetGameFrame() > 0 then
		widget:PlayerChanged()
	end

	widgetHandler:RegisterGlobal('EventBroadcast', EventBroadcast)
	widgetHandler:RegisterGlobal('AddNotification', addSound)

	WG['notifications'] = {}
	for sound, params in pairs(Sound) do
		WG['notifications']['getSound'..sound] = function()
			return soundList[sound] or false
		end
		WG['notifications']['setSound'..sound] = function(value)
			soundList[sound] = value
		end
	end
	WG['notifications'].getSoundList = function()
		local soundInfo = {}
		for i, v in pairs(SoundOrder) do
			soundInfo[i] = {v, soundList[v], Sound[v][4]}
		end
		return soundInfo
	end
	WG['notifications'].getTutorial = function()
		return tutorialMode
	end
	WG['notifications'].setTutorial = function(value)
		tutorialMode = value
		if tutorialMode then
			tutorialPlayed = {}
			--for i,v in pairs(LastPlay) do
			--	if string.sub(i, 1, 2) == 't_' then
			--		LastPlay[i] = nil
			--	end
			--end
			Spring.Echo('Tutorial notifications enabled. (and wiped the already played messages memory)')
		end
		widget:PlayerChanged()
	end
	WG['notifications'].getVolume = function()
		return globalVolume
	end
	WG['notifications'].setVolume = function(value)
		globalVolume = value
	end
	WG['notifications'].getSpoken = function()
		return spoken
	end
	WG['notifications'].setSpoken = function(value)
		spoken = value
	end
	WG['notifications'].getMessages = function()
		return displayMessages
	end
	WG['notifications'].setMessages = function(value)
		displayMessages = value
	end
    WG['notifications'].getPlayTrackedPlayerNotifs = function()
        return playTrackedPlayerNotifs
    end
	WG['notifications'].setPlayTrackedPlayerNotifs = function(value)
		playTrackedPlayerNotifs = value
	end
	WG['notifications'].addSound = function(name, file, minDelay, duration, message, unlisted)
		addSound(name, file, minDelay, duration, message, unlisted)
	end
	WG['notifications'].addEvent = function(value)
		if Sound[value] then
			QueueNotification(value)
		end
	end
end

function widget:Shutdown()
	WG['notifications'] = nil
	widgetHandler:DeregisterGlobal('EventBroadcast')
	widgetHandler:DeregisterGlobal('AddNotification')
end

function widget:GameFrame(gf)

	gameframe = gf

	if not displayMessages and not spoken then return end

	if gameframe < 60 then return end	-- dont alert stuff for first 2 secs so gadgets can still spawn stuff without it triggering notifications

	if gameframe == 70 and doTutorialMode then
		QueueTutorialNotification('t_welcome')
	end
	if gameframe % 30 == 15 then
		e_currentLevel, e_storage, e_pull, e_income, e_expense, e_share, e_sent, e_received = spGetTeamResources(myTeamID,'energy')
		m_currentLevel, m_storage, m_pull, m_income, m_expense, m_share, m_sent, m_received = spGetTeamResources(myTeamID,'metal')

		-- tutorial
		if doTutorialMode then
			if gameframe > 300 and not hasBuildMex then
				QueueTutorialNotification('t_buildmex')
			end
			if not hasBuildEnergy and hasBuildMex then
				QueueTutorialNotification('t_buildenergy')
			end
			if e_income >= 50 and m_income >= 4 then
				QueueTutorialNotification('t_nowproduce')
			end
			if not hasMadeT2 and e_income >= 600 and m_income >= 12 then
				QueueTutorialNotification('t_readyfortech2')
			end
		end

		-- low power check
		if (e_currentLevel / e_storage) < 0.025 and e_currentLevel < 3000 then
			lowpowerDuration = lowpowerDuration + 1
			if lowpowerDuration >= lowpowerThreshold then
				QueueNotification('LowPower')
				lowpowerDuration = 0
			end
		end

		-- idle builder check
		for unitID, frame in pairs(idleBuilder) do
			if spIsUnitInView(unitID) then
				idleBuilder[unitID] = nil
			elseif frame < gf then
				--QueueNotification('IdleBuilder')
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
	if not displayMessages and not spoken then return end

	if unitTeam == myTeamID then

		if not isCommander[unitDefID] then
			if isMex[unitDefID] then
				hasBuildMex = true
			end
			if isEnergyProducer[unitDefID] then
				hasBuildEnergy = true
			end
		end

		if unitDefID == vulcanDefID then
			QueueNotification('VulcanIsReady')
		elseif unitDefID == buzzsawDefID then
			QueueNotification('BuzzsawIsReady')
		elseif isT3mobile[unitDefID] then
			QueueNotification('Tech3UnitReady')

		elseif doTutorialMode then
			if isFactoryAir[unitDefID] then
				QueueTutorialNotification('t_factoryair')
			elseif isFactoryAirSea[unitDefID] then
				QueueTutorialNotification('t_factoryairsea')
			elseif isFactoryBot[unitDefID] then
				QueueTutorialNotification('t_factorybots')
			elseif isFactoryHover[unitDefID] then
				QueueTutorialNotification('t_factoryhovercraft')
			elseif isFactoryVeh[unitDefID] then
				QueueTutorialNotification('t_factoryvehicles')
			elseif isFactoryShip[unitDefID] then
				QueueTutorialNotification('t_factoryships')
			end
		end
	end
end


function widget:UnitEnteredLos(unitID, unitTeam)
	if not displayMessages and not spoken then return end

	if spIsUnitAllied(unitID) or unitTeam ~= gaiaTeamID then return end

	local udefID = spGetUnitDefID(unitID)

	-- single detection events below
	if isAircraft[udefID] then
		QueueNotification('AircraftSpotted')
	end
	if isT2[udefID] then
		QueueNotification('T2Detected')
	end
	if isT3mobile[udefID] then
		QueueNotification('T3Detected')
	end
	if isMine[udefID] then
		local x,_,z = Spring.GetUnitPosition(unitID)
		local units = Spring.GetUnitsInCylinder(x,z,1700, myTeamID)
		if #units > 0 then		-- ignore when far away
			QueueNotification('MinesDetected')
		end
	end

	-- notify about units of interest
	if udefID and unitsOfInterest[udefID] and not taggedUnitsOfInterest[unitID] then
		taggedUnitsOfInterest[unitID] = true
		QueueNotification(unitsOfInterest[udefID])
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

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if not displayMessages and not spoken then return end

    if unitTeam == myTeamID then
		if not hasMadeT2 and isT2[unitDefID] then
			hasMadeT2 = true
		end

		if isCommander[unitDefID] then
			commanders[unitID] = select(2, spGetUnitHealth(unitID))
		end
		if windNotGood and isWind[unitDefID] then
			QueueNotification('WindNotGood')
		end

		if tutorialMode then
			if e_income < 2000 and m_income < 50 then
				if isFactoryAir[unitDefID] then
					numFactoryAir = numFactoryAir + 1
					if numFactoryAir > 1 then
						QueueNotification('t_duplicatefactory')
					end
				end
				if isFactoryAirSea[unitDefID] then
					numFactoryAirSea = numFactoryAirSea + 1
					if numFactoryAirSea > 1 then
						QueueNotification('t_duplicatefactory')
					end
				end
				if isFactoryVeh[unitDefID] then
					numFactoryVeh = numFactoryVeh + 1
					if numFactoryVeh > 1 then
						QueueNotification('t_duplicatefactory')
					end
				end
				if isFactoryBot[unitDefID] then
					numFactoryBot = numFactoryBot + 1
					if numFactoryBot > 1 then
						QueueNotification('t_duplicatefactory')
					end
				end
				if isFactoryHover[unitDefID] then
					numFactoryHover = numFactoryHover + 1
					if numFactoryHover > 1 then
						QueueNotification('t_duplicatefactory')
					end
				end
				if isFactoryShip[unitDefID] then
					numFactoryShip = numFactoryShip + 1
					if numFactoryShip > 1 then
						QueueNotification('t_duplicatefactory')
					end
				end
			end
		end
    end
end


function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if not displayMessages and not spoken then return end

	if unitTeam == myTeamID then

		if paralyzer then
			QueueTutorialNotification('t_paralyzer')
		end

		-- notify when commander gets heavy damage
		if commanders[unitID] and not spIsUnitInView(unitID) then
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
				QueueNotification('ComHeavyDamage')
			end
		end
	end
end

function widget:UnitDestroyed(unitID, unitDefID, teamID)
	taggedUnitsOfInterest[unitID] = nil
    commandersDamages[unitID] = nil

	if tutorialMode then
		if isFactoryAir[unitDefID] then
			numFactoryAir = numFactoryAir - 1
		end
		if isFactoryAirSea[unitDefID] then
			numFactoryAirSea = numFactoryAirSea - 1
		end
		if isFactoryVeh[unitDefID] then
			numFactoryVeh = numFactoryVeh - 1
		end
		if isFactoryBot[unitDefID] then
			numFactoryBot = numFactoryBot - 1
		end
		if isFactoryHover[unitDefID] then
			numFactoryHover = numFactoryHover - 1
		end
		if isFactoryShip[unitDefID] then
			numFactoryShip = numFactoryShip - 1
		end
	end
end

function playNextSound()
	if #soundQueue > 0 then
		local event = soundQueue[1]
		local isTutorialNotification = (string.sub(event, 1, 2) == 't_')
		nextSoundQueued = sec + Sound[event][3] + silentTime
		if not muteWhenIdle or not isIdle or isTutorialNotification then
			if spoken and Sound[event][1] ~= '' then
				Spring.PlaySoundFile(soundFolder..Sound[event][1], globalVolume, 'ui')
			end
			if displayMessages and WG['messages'] and Sound[event][4] then
				WG['messages'].addMessage(Sound[event][4])
			end
		end
		LastPlay[event] = spGetGameFrame()

		-- for tutorial event: log number of plays
		if isTutorialNotification then
			tutorialPlayed[event] = tutorialPlayed[event] and tutorialPlayed[event] + 1 or 1
			tutorialPlayedThisGame[event] = true
		end

		-- drop current played notification from the table
		local newQueue = {}
		local newQueuecount = 0
		for i,v in pairs(soundQueue) do
			if i ~= 1 then
				newQueuecount = newQueuecount + 1
				newQueue[newQueuecount] = v
			end
		end
		soundQueue = newQueue
	end
end

function widget:Update(dt)

	if not displayMessages and not spoken then return end

	if gameframe < 60 then return end	-- dont alert stuff for first 2 secs so gadgets can still spawn stuff without it triggering notifications

	sec = sec + dt

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
		if WG['topbar'] and WG['topbar'].showingRejoining and WG['topbar'].showingRejoining() then
			isIdle = true
		end
    end
end

-- function that gadgets can call
function EventBroadcast(msg)

	if gameframe < 60 then return end	-- dont alert stuff for first 2 secs so gadgets can still spawn stuff without it triggering notifications

	if string.find(msg, "SoundEvents", nil, true) then
		msg = string.sub(msg, 13)
		local forceplay = string.sub(msg, string.find(msg, " ", nil, true)+2, string.len(msg))
		forceplay = (forceplay ~= nil and forceplay ~= '')
		if not isSpec or (isSpec and playTrackedPlayerNotifs and lockPlayerID ~= nil) or forceplay then
            local event = string.sub(msg, 1, string.find(msg, " ", nil, true)-1)
            local player = string.sub(msg, string.find(msg, " ", nil, true)+1, string.len(msg))
            if forceplay or (tonumber(player) and (tonumber(player) == Spring.GetMyPlayerID())) or (isSpec and tonumber(player) == lockPlayerID) then
				QueueNotification(event, forceplay)
            end
        end
	end
end


function QueueTutorialNotification(event)
	if doTutorialMode and (not tutorialPlayed[event] or tutorialPlayed[event] < tutorialPlayLimit) then
		QueueNotification(event)
	end
end

function isInQueue(event)
	for i,v in pairs(soundQueue) do
		if v == event  then
			return true
		end
	end
	return false
end

function QueueNotification(event, forceplay)
	if not isSpec or (isSpec and playTrackedPlayerNotifs and lockPlayerID ~= nil) or forceplay then
		if soundList[event] and Sound[event] then
			if not LastPlay[event] or (spGetGameFrame() >= LastPlay[event] + (Sound[event][2] * 30)) then
				if not isInQueue(event) then
					soundQueue[#soundQueue+1] = event
				end
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
		Sound = Sound,
		soundList = soundList,
		globalVolume = globalVolume,
		spoken = spoken,
		displayMessages = displayMessages,
		playTrackedPlayerNotifs = playTrackedPlayerNotifs,
		LastPlay = LastPlay,
		tutorialMode = tutorialMode,
		tutorialPlayed = tutorialPlayed,
		tutorialPlayedThisGame = tutorialPlayedThisGame,
	}
end

function widget:SetConfigData(data)
	if data.Sound ~= nil and Spring.GetGameFrame() > 0 then
		Sound = data.Sound
	end
	if data.soundList ~= nil then
		for sound, enabled in pairs(data.soundList) do
			if Sound[sound] then
				soundList[sound] = enabled
			end
		end
	end
	if data.globalVolume ~= nil then
		globalVolume = data.globalVolume
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
	if data.tutorialPlayed ~= nil then
		tutorialPlayed = data.tutorialPlayed
	end
	if data.tutorialMode ~= nil then
		tutorialMode = data.tutorialMode
	end
	if spGetGameFrame() > 0 then
		if data.LastPlay then
			LastPlay = data.LastPlay
		end
		if data.tutorialPlayedThisGame ~= nil then
			tutorialPlayedThisGame = data.tutorialPlayedThisGame
		end
	end
end

-- maybe draw events on minimap
--function widget:DrawInMiniMap(sx, sy)
--
--end
