local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Notifications",
		desc = "Does various voice/text notifications",
		author = "Doo, Floris",
		date = "2018",
		license = "GNU GPL, v2 or later",
		version = 1,
		layer = 5,
		enabled = true
	}
end

local defaultVoiceSet = 'en/allison'

local useDefaultVoiceFallback = false    -- when a voiceset has missing file, try to load the default voiceset file instead

local silentTime = 0.7    -- silent time between queued notifications
local globalVolume = 0.7
local playTrackedPlayerNotifs = false
local muteWhenIdle = true
local idleTime = 10        -- after this much sec: mark user as idle
local displayMessages = true
local spoken = true
local idleBuilderNotificationDelay = 10 * 30    -- (in gameframes)
local lowpowerThreshold = 7        -- if there is X secs a low power situation
local tutorialPlayLimit = 2        -- display the same tutorial message only this many times in total (max is always 1 play per game)
local updateCommandersFrames = Game.gameSpeed * 5

--------------------------------------------------------------------------------

local wavFileLengths = VFS.Include('sounds/sound_file_lengths.lua')
VFS.Include('common/wav.lua')

local language = Spring.GetConfigString('language', 'en')

local voiceSet = Spring.GetConfigString('voiceset', defaultVoiceSet)

-- fix old config
if not string.find(voiceSet, '/', nil, true)	then
	Spring.SetConfigString("voiceset", defaultVoiceSet)
	voiceSet = defaultVoiceSet
end

if string.sub(voiceSet, 1, 2) ~= language then
	local languageDirs = VFS.SubDirs('sounds/voice', '*')
	for k, f in ipairs(languageDirs) do
		local langDir = string.sub(f, 14, string.len(f)-1)
		local files = VFS.SubDirs('sounds/voice/'..langDir, '*')
		for k, file in ipairs(files) do
			local dirname = string.sub(file, 14, string.len(file)-1)
			voiceSet = langDir..'/'..dirname
			break
		end
	end
end


local LastPlay = {}
local notification = {}
local notificationList = {}
local notificationOrder = {}
local spGetGameFrame = Spring.GetGameFrame
local gameframe = spGetGameFrame()
local gameover = false

local lockPlayerID
local gaiaTeamID = Spring.GetGaiaTeamID()

local soundFolder = "sounds/voice/" .. voiceSet .. "/"
local defaultSoundFolder = "sounds/voice/" .. defaultVoiceSet .. "/"

local voiceSetFound = false
local files = VFS.SubDirs('sounds/voice/' .. language, '*')
for k, file in ipairs(files) do
	local dirname = string.sub(file, 14, string.len(file) - 1)
	if dirname == voiceSet then
		voiceSetFound = true
		break
	end
end
if not voiceSetFound then
	voiceSet = defaultVoiceSet
end

local function addNotification(name, soundFiles, minDelay, i18nTextID, tutorial)
	notification[name] = {
		delay = minDelay,
		textID = i18nTextID,
		voiceFiles = soundFiles,
		tutorial = tutorial
	}
	notificationList[name] = true
	if not tutorial then
		notificationOrder[#notificationOrder + 1] = name
	end
end

-- load and parse sound files/notifications
local notificationTable = VFS.Include('sounds/voice/config.lua')
if VFS.FileExists(soundFolder .. 'config.lua') then
	local voicesetNotificationTable = VFS.Include(soundFolder .. 'config.lua')
	notificationTable = table.merge(notificationTable, voicesetNotificationTable)
end
for notifID, notifDef in pairs(notificationTable) do
	local notifTexts = {}
	local notifSounds = {}
	local currentEntry = 1
	notifTexts[currentEntry] = 'tips.notifications.' .. string.sub(notifID, 1, 1):lower() .. string.sub(notifID, 2)
	if VFS.FileExists(soundFolder .. notifID .. '.wav') then
		notifSounds[currentEntry] = soundFolder .. notifID .. '.wav'
	end
	for i = 1, 20 do
		if VFS.FileExists(soundFolder .. notifID .. i .. '.wav') then
			currentEntry = currentEntry + 1
			notifSounds[currentEntry] = soundFolder .. notifID .. i .. '.wav'
		end
	end
	if useDefaultVoiceFallback and #notifSounds == 0 then
		if VFS.FileExists(defaultSoundFolder .. notifID .. '.wav') then
			notifSounds[currentEntry] = defaultSoundFolder .. notifID .. '.wav'
		end
	end
	addNotification(notifID, notifSounds, notifDef.delay or 2, notifTexts[1], notifDef.tutorial) -- bandaid, picking text from first variation always.
end

local unitsOfInterestNames = {
	armemp = 'EmpSiloDetected',
	cortron = 'TacticalNukeSiloDetected',
	armsilo = 'NuclearSiloDetected',
	corsilo = 'NuclearSiloDetected',
	corint = 'LrpcDetected',
	armbrtha = 'LrpcDetected',
	leglrpc = 'LrpcDetected',
	corbuzz = 'LrpcDetected',
	armvulc = 'LrpcDetected',
	legstarfall = 'LrpcDetected',
	armliche = 'NuclearBomberDetected',
	corjugg = 'BehemothDetected',
	corkorg = 'JuggernautDetected',
	armbanth = 'TitanDetected',
	legeheatraymech = 'SolinvictusDetected',
	armepoch = 'FlagshipDetected',
	corblackhy = 'FlagshipDetected',
	armthovr = 'TransportDetected',
	corthovr = 'TransportDetected',
	corintr = 'TransportDetected',
	armatlas = 'AirTransportDetected',
	corvalk = 'AirTransportDetected',
	leglts = 'AirTransportDetected',
	armhvytrans = 'AirTransportDetected',
	corhvytrans = 'AirTransportDetected',
	legatrans = 'AirTransportDetected',
	armdfly = 'AirTransportDetected',
	corseah = 'AirTransportDetected',
	legstronghold = 'AirTransportDetected',
	armtship = 'SeaTransportDetected',
	cortship = 'SeaTransportDetected',
}
-- convert unitname -> unitDefID
local unitsOfInterest = {}
for unitName, sound in pairs(unitsOfInterestNames) do
	if UnitDefNames[unitName] then
		unitsOfInterest[UnitDefNames[unitName].id] = sound
	end
end
unitsOfInterestNames = nil


-- added this so they wont get immediately triggered after gamestart
LastPlay['YouAreOverflowingMetal'] = spGetGameFrame() + 1200
--LastPlay['YouAreOverflowingEnergy'] = spGetGameFrame()+300
--LastPlay['YouAreWastingMetal'] = spGetGameFrame()+300
--LastPlay['YouAreWastingEnergy'] = spGetGameFrame()+300
LastPlay['WholeTeamWastingMetal'] = spGetGameFrame() + 1200
LastPlay['WholeTeamWastingEnergy'] = spGetGameFrame() + 2000

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
local myRank = select(9, Spring.GetPlayerInfo(myPlayerID))

local spGetTeamResources = Spring.GetTeamResources
local e_currentLevel, e_storage, e_pull, e_income, e_expense, e_share, e_sent, e_received = spGetTeamResources(myTeamID, 'energy')
local m_currentLevel, m_storage, m_pull, m_income, m_expense, m_share, m_sent, m_received = spGetTeamResources(myTeamID, 'metal')

local tutorialMode = (myRank == 0)
local doTutorialMode = tutorialMode
local tutorialPlayed = {}        -- store the number of times a tutorial event has played across games
local tutorialPlayedThisGame = {}    -- log that a tutorial event has played this game

local vulcanDefID = UnitDefNames['armvulc'].id
local titanDefID = UnitDefNames['armbanth'].id

local buzzsawDefID = UnitDefNames['corbuzz'].id
local juggernautDefID = UnitDefNames['corkorg'].id

local starfallDefID = UnitDefNames['legstarfall'] and UnitDefNames['legstarfall'].id
local astraeusDefID = UnitDefNames['legelrpcmech'] and UnitDefNames['legelrpcmech'].id
local solinvictusDefID = UnitDefNames['legeheatraymech'] and UnitDefNames['legeheatraymech'].id

local isFactoryAir = { [UnitDefNames['armap'].id] = true, [UnitDefNames['corap'].id] = true }
local isFactorySeaplanes = { [UnitDefNames['armplat'].id] = true, [UnitDefNames['corplat'].id] = true }
local isFactoryVeh = { [UnitDefNames['armvp'].id] = true, [UnitDefNames['corvp'].id] = true }
local isFactoryBot = { [UnitDefNames['armlab'].id] = true, [UnitDefNames['corlab'].id] = true }
local isFactoryHover = { [UnitDefNames['armhp'].id] = true, [UnitDefNames['corhp'].id] = true }
local isFactoryShip = { [UnitDefNames['armsy'].id] = true, [UnitDefNames['corsy'].id] = true }
local numFactoryAir = 0
local numFactorySeaplanes = 0
local numFactoryVeh = 0
local numFactoryBot = 0
local numFactoryHover = 0
local numFactoryShip = 0

local hasMadeT2 = false

local isCommander = {}
local isBuilder = {}
local isMex = {}
local isRadar = {}
local isEnergyProducer = {}
local isWind = {}
local isAircraft = {}
local isT2 = {}
local isT3mobile = {}
local isT4mobile = {}
local isMine = {}
for udefID, def in ipairs(UnitDefs) do
	if not string.find(def.name, 'critter') and not string.find(def.name, 'raptor') and (not def.modCategories or not def.modCategories.object) then
		if def.canFly then
			isAircraft[udefID] = true
		end
		if def.customParams.techlevel then
			if def.customParams.techlevel == '2' and not (def.customParams.iscommander or def.customParams.isscavcommander) then
				isT2[udefID] = true
			end
			if def.customParams.techlevel == '3' and not def.isBuilding then
				isT3mobile[udefID] = true
			end
			if def.customParams.techlevel == '4' and not def.isBuilding then
				isT4mobile[udefID] = true --there are no units with this techlevel assigned, need to see which ones
			end
		end
		if def.modCategories.mine then
			isMine[udefID] = true
		end
		if def.customParams.iscommander or def.customParams.isscavcommander then
			isCommander[udefID] = true
		end
		if def.isBuilder and def.canAssist then
			isBuilder[udefID] = true
		end
		if def.windGenerator and def.windGenerator > 0 then
			isWind[udefID] = true
		end
		if def.extractsMetal > 0 then
			isMex[udefID] = true
		end
		if def.isBuilding and def.radarDistance > 2000 then
			isRadar[udefID] = true
		end
		if def.energyMake > 10 then
			isEnergyProducer[udefID] = def.energyMake
		end
	end
end

local function updateCommanders()
	local units = Spring.GetTeamUnits(myTeamID)
	for i = 1, #units do
		local unitID = units[i]
		local unitDefID = spGetUnitDefID(unitID)
		if isCommander[unitDefID] then
			commanders[unitID] = select(2, spGetUnitHealth(unitID))	-- maxhealth
		end
	end
end

local function isInQueue(event)
	for i, v in pairs(soundQueue) do
		if v == event then
			return true
		end
	end
	return false
end

local function queueNotification(event, forceplay)
	if Spring.GetGameFrame() > 20 or forceplay then
		if not isSpec or (isSpec and playTrackedPlayerNotifs and lockPlayerID ~= nil) or forceplay then
			if notificationList[event] and notification[event] then
				if not LastPlay[event] or (spGetGameFrame() >= LastPlay[event] + (notification[event].delay * 30)) then
					if not isInQueue(event) then
						soundQueue[#soundQueue + 1] = event
					end
				end
			end
		end
	end
end

local function queueTutorialNotification(event)
	if doTutorialMode and (not tutorialPlayed[event] or tutorialPlayed[event] < tutorialPlayLimit) then
		queueNotification(event)
	end
end

function widget:PlayerChanged(playerID)
	isSpec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
	myPlayerID = Spring.GetMyPlayerID()
	doTutorialMode = (not isReplay and not isSpec and tutorialMode)
	updateCommanders()
end

local function gadgetNotificationEvent(msg)
	-- dont alert stuff for first 2 secs so gadgets can still spawn stuff without it triggering notifications
	if gameframe < 60 then
		return
	end

	local forceplay = (string.sub(msg, string.len(msg) - 1) == ' y')
	if not isSpec or (isSpec and playTrackedPlayerNotifs and lockPlayerID ~= nil) or forceplay then
		local event = string.sub(msg, 1, string.find(msg, " ", nil, true) - 1)
		local player = string.sub(msg, string.find(msg, " ", nil, true) + 1, string.len(msg))
		if forceplay or (tonumber(player) and (tonumber(player) == Spring.GetMyPlayerID())) or (isSpec and tonumber(player) == lockPlayerID) then
			queueNotification(event, forceplay)
		end
	end
end

function widget:Initialize()
	widget:PlayerChanged()

	widgetHandler:RegisterGlobal('NotificationEvent', gadgetNotificationEvent)

	WG['notifications'] = {}
	for sound, params in pairs(notification) do
		WG['notifications']['getNotification' .. sound] = function()
			return notificationList[sound] or false
		end
		WG['notifications']['setNotification' .. sound] = function(value)
			notificationList[sound] = value
		end
	end
	WG['notifications'].getNotificationList = function()
		local soundInfo = {}
		for i, event in pairs(notificationOrder) do
			soundInfo[i] = { event, notificationList[event], notification[event].textID, #notification[event].voiceFiles }
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
	WG['notifications'].addEvent = function(value, force)
		if notification[value] then
			queueNotification(value, force)
		end
	end
	WG['notifications'].playNotification = function(event)
		if notification[event] then
			if notification[event].voiceFiles and #notification[event].voiceFiles > 0 then
				local m = #notification[event].voiceFiles > 1 and math.random(1, #notification[event].voiceFiles) or 1
				if notification[event].voiceFiles[m] then
					Spring.PlaySoundFile(notification[event].voiceFiles[m], globalVolume, 'ui')
				else
					Spring.Echo('notification "'..event..'" missing sound file: #'..m)
				end
			end
			if displayMessages and WG['messages'] and notification[event].textID then
				WG['messages'].addMessage(Spring.I18N(notification[event].textID))
			end
		end
	end

	if Spring.Utilities.Gametype.IsRaptors() and Spring.Utilities.Gametype.IsScavengers() then
		queueNotification('RaptorsAndScavsMixed')
	end
end

function widget:Shutdown()
	WG['notifications'] = nil
	widgetHandler:DeregisterGlobal('NotificationEvent')
end

function widget:GameFrame(gf)
	gameframe = gf
	if isSpec or (not displayMessages and not spoken) or gameframe < 60 then	-- dont alert stuff for first 2 secs so gadgets can still spawn stuff without it triggering notifications
		return
	end

	if gameframe == 70 and doTutorialMode then
		queueTutorialNotification('Welcome')
	end
	if gameframe % 30 == 15 then
		e_currentLevel, e_storage, e_pull, e_income, e_expense, e_share, e_sent, e_received = spGetTeamResources(myTeamID, 'energy')
		m_currentLevel, m_storage, m_pull, m_income, m_expense, m_share, m_sent, m_received = spGetTeamResources(myTeamID, 'metal')

		-- tutorial
		if doTutorialMode then
			if gameframe > 300 and not hasBuildMex then
				queueTutorialNotification('BuildMetal')
			end
			if not hasBuildEnergy and hasBuildMex then
				queueTutorialNotification('BuildEnergy')
			end
			if e_income >= 50 and m_income >= 4 then
				queueTutorialNotification('BuildFactory')
			end
			if e_income >= 125 and m_income >= 8 and gameframe > 600 then
				queueTutorialNotification('BuildRadar')
			end
			if not hasMadeT2 and e_income >= 600 and m_income >= 12 then
				queueTutorialNotification('ReadyForTech2')
			end
			if hasMadeT2 then
				-- FIXME
				--local udefIDTemp = spGetUnitDefID(unitID)
				--if isT2[udefIDTemp] then
				--	queueNotification('BuildIntrusionCounterMeasure')
				--end
			end
		end

		-- raptors and scavs mixed check
		if Spring.Utilities.Gametype.IsRaptors() and Spring.Utilities.Gametype.IsScavengers() then
			queueNotification('RaptorsAndScavsMixed')
		end

		-- low power check
		if e_currentLevel and (e_currentLevel / e_storage) < 0.025 and e_currentLevel < 3000 then
			lowpowerDuration = lowpowerDuration + 1
			if lowpowerDuration >= lowpowerThreshold then
				queueNotification('LowPower')
				lowpowerDuration = 0

				-- increase next low power delay
				notification["LowPower"].delay = notification["LowPower"].delay + 15
			end
		end

		-- idle builder check
		for unitID, frame in pairs(idleBuilder) do
			if spIsUnitInView(unitID) then
				idleBuilder[unitID] = nil
			elseif frame < gf then
				--QueueNotification('IdleBuilder')
				idleBuilder[unitID] = nil    -- do not repeat
			end
		end
	end

	if gameframe % updateCommandersFrames == 0 then
		updateCommanders()
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag)
	idleBuilder[unitID] = nil
end

function widget:UnitIdle(unitID)
	if isBuilder[spGetUnitDefID(unitID)] and not idleBuilder[unitID] and not spIsUnitInView(unitID) then
		idleBuilder[unitID] = spGetGameFrame() + idleBuilderNotificationDelay
	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if not displayMessages and not spoken then
		return
	end

	if unitTeam == myTeamID then

		if not isCommander[unitDefID] then
			if isMex[unitDefID] then
				hasBuildMex = true
			end
			if isEnergyProducer[unitDefID] then
				hasBuildEnergy = true
			end
			if isRadar[unitDefID] and not tutorialPlayedThisGame['BuildRadar'] then
				tutorialPlayed['BuildRadar'] = tutorialPlayLimit
			end
		end

		if unitDefID == vulcanDefID then
			queueNotification('RagnarokIsReady')
		elseif unitDefID == buzzsawDefID then
			queueNotification('CalamityIsReady')
		elseif unitDefID == starfallDefID then
			queueNotification('StarfallIsReady')
		elseif unitDefID == astraeusDefID then
			queueNotification('AstraeusIsReady')
		elseif unitDefID == solinvictusDefID then
			queueNotification('SolinvictusIsReady')
		elseif unitDefID == juggernautDefID then
			queueNotification('JuggernautIsReady')
		-- elseif unitDefID == titanDefID then
		-- 	queueNotification('TitanIsReady')
		elseif isT3mobile[unitDefID] then
			queueNotification('Tech3UnitReady')

		elseif doTutorialMode then
			if isFactoryAir[unitDefID] then
				queueTutorialNotification('FactoryAir')
			elseif isFactorySeaplanes[unitDefID] then
				queueTutorialNotification('FactorySeaplanes')
			elseif isFactoryBot[unitDefID] then
				queueTutorialNotification('FactoryBots')
			elseif isFactoryHover[unitDefID] then
				queueTutorialNotification('FactoryHovercraft')
			elseif isFactoryVeh[unitDefID] then
				queueTutorialNotification('FactoryVehicles')
			elseif isFactoryShip[unitDefID] then
				queueTutorialNotification('FactoryShips')
			end
		end
	end
end

function widget:UnitEnteredLos(unitID, unitTeam)
	if not displayMessages and not spoken then
		return
	end
	if gameover then
		return
	end
	if spIsUnitAllied(unitID) or unitTeam == gaiaTeamID then
		return
	end

	local udefID = spGetUnitDefID(unitID)

	-- single detection events below
	if isAircraft[udefID] then
		queueNotification('AircraftSpotted')
	end
	if isT2[udefID] then
		queueNotification('T2Detected')
	end
	if isT3mobile[udefID] then
		queueNotification('T3Detected')
	end
	if isT4mobile[udefID] then
		queueNotification('T4UnitDetected')
	end
	if isMine[udefID] then
		-- ignore when far away
		local x, _, z = Spring.GetUnitPosition(unitID)
		if #Spring.GetUnitsInCylinder(x, z, 1700, myTeamID) > 0 then
			queueNotification('MinesDetected')
		end
	end

	-- notify about units of interest
	if udefID and unitsOfInterest[udefID] and not taggedUnitsOfInterest[unitID] then
		taggedUnitsOfInterest[unitID] = true
		queueNotification(unitsOfInterest[udefID])
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if unitTeam == myTeamID then
		if isCommander[unitDefID] then
			commanders[unitID] = select(2, spGetUnitHealth(unitID))
		end
		if Spring.GetTeamUnitCount(myTeamID) >= Spring.GetTeamMaxUnits(myTeamID) then
			queueNotification('MaxUnitsReached')
		end
	end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	if unitTeam == myTeamID then
		if isCommander[unitDefID] then
			commanders[unitID] = select(2, spGetUnitHealth(unitID))
		end
		if Spring.GetTeamUnitCount(myTeamID) >= Spring.GetTeamMaxUnits(myTeamID) then
			queueNotification('MaxUnitsReached')
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if not displayMessages and not spoken then
		return
	end
	if unitTeam == myTeamID then
		if Spring.GetTeamUnitCount(myTeamID) >= Spring.GetTeamMaxUnits(myTeamID) then
			queueNotification('MaxUnitsReached')
		end

		if not hasMadeT2 and isT2[unitDefID] then
			hasMadeT2 = true
		end

		if isCommander[unitDefID] then
			commanders[unitID] = select(2, spGetUnitHealth(unitID))
		end
		if windNotGood and isWind[unitDefID] then
			queueNotification('WindNotGood')
		end

		if tutorialMode then
			if e_income < 2000 and m_income < 50 then
				if isFactoryAir[unitDefID] then
					numFactoryAir = numFactoryAir + 1
					if numFactoryAir > 1 then
						queueNotification('DuplicateFactory')
					end
				end
				if isFactorySeaplanes[unitDefID] then
					numFactorySeaplanes = numFactorySeaplanes + 1
					if numFactorySeaplanes > 1 then
						queueNotification('DuplicateFactory')
					end
				end
				if isFactoryVeh[unitDefID] then
					numFactoryVeh = numFactoryVeh + 1
					if numFactoryVeh > 1 then
						queueNotification('DuplicateFactory')
					end
				end
				if isFactoryBot[unitDefID] then
					numFactoryBot = numFactoryBot + 1
					if numFactoryBot > 1 then
						queueNotification('DuplicateFactory')
					end
				end
				if isFactoryHover[unitDefID] then
					numFactoryHover = numFactoryHover + 1
					if numFactoryHover > 1 then
						queueNotification('DuplicateFactory')
					end
				end
				if isFactoryShip[unitDefID] then
					numFactoryShip = numFactoryShip + 1
					if numFactoryShip > 1 then
						queueNotification('DuplicateFactory')
					end
				end
			end
		end
	end
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if not displayMessages and not spoken then
		return
	end
	if unitTeam == myTeamID then
		if paralyzer then
			queueTutorialNotification('Paralyzer')
		end

		-- notify when commander gets damaged
		if commanders[unitID] then
			local x, y, z = Spring.GetUnitPosition(unitID)
			local camX, camY, camZ = Spring.GetCameraPosition()
			if not spIsUnitInView(unitID) or math.diag(camX - x, camY - y, camZ - z) > 3000 then
				if not commandersDamages[unitID] then
					commandersDamages[unitID] = {}
				end
				local gameframe = spGetGameFrame()
				commandersDamages[unitID][gameframe] = damage        -- if widget:UnitDamaged can be called multiple times during 1 gameframe then you need to add those up, i dont know

				-- count total damage of last few secs
				local totalDamage = 0
				local startGameframe = gameframe - (5.5 * 30)
				for gf, damage in pairs(commandersDamages[unitID]) do
					if gf > startGameframe then
						totalDamage = totalDamage + damage
					else
						commandersDamages[unitID][gf] = nil
					end
				end
				if totalDamage >= commanders[unitID] * 0.2 and spGetUnitHealth(unitID)/commanders[unitID] <= 0.85 then
					queueNotification('ComHeavyDamage')
				end
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
		if isFactorySeaplanes[unitDefID] then
			numFactorySeaplanes = numFactorySeaplanes - 1
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

local function playNextSound()
	if #soundQueue > 0 then
		local event = soundQueue[1]
		if not muteWhenIdle or not isIdle or notification[event].tutorial then
			local m = 1
			if spoken and #notification[event].voiceFiles > 0 then
				local m = #notification[event].voiceFiles > 1 and math.random(1, #notification[event].voiceFiles) or 1
				if notification[event].voiceFiles[m] then
					Spring.PlaySoundFile(notification[event].voiceFiles[m], globalVolume, 'ui')
					local duration = wavFileLengths[string.sub(notification[event].voiceFiles[m], 8)]
					if not duration then
						duration = ReadWAV(notification[event].voiceFiles[m])
						duration = duration.Length
					end
					nextSoundQueued = sec + (duration or 3) + silentTime
				else
					Spring.Echo('notification "'..event..'" missing sound file: #'..m)
				end
			end
			if displayMessages and WG['messages'] and notification[event].textID then
				WG['messages'].addMessage(Spring.I18N(notification[event].textID))
			end
		end
		LastPlay[event] = spGetGameFrame()

		-- for tutorial event: log number of plays
		if notification[event].tutorial then
			tutorialPlayed[event] = tutorialPlayed[event] and tutorialPlayed[event] + 1 or 1
			tutorialPlayedThisGame[event] = true
		end

		-- drop current played notification from the table
		local newQueue = {}
		local newQueuecount = 0
		for i, v in pairs(soundQueue) do
			if i ~= 1 then
				newQueuecount = newQueuecount + 1
				newQueue[newQueuecount] = v
			end
		end
		soundQueue = newQueue
	end
end

function widget:Update(dt)
	if not displayMessages and not spoken then
		return
	end
	sec = sec + dt
	passedTime = passedTime + dt
	if passedTime > 0.2 then
		passedTime = passedTime - 0.2
		if WG.lockcamera and WG.lockcamera.GetPlayerID ~= nil then
			lockPlayerID = WG.lockcamera.GetPlayerID()
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
		if lastUserInputTime < os.clock() - idleTime then
			isIdle = true
		else
			isIdle = false
		end
		if WG['rejoin'] and WG['rejoin'].showingRejoining() then
			isIdle = true
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

function widget:GameStart()
	queueNotification('GameStarted', true)
end

function widget:GameOver()
	gameover = true
	queueNotification('BattleEnded',true)
	--widgetHandler:RemoveWidget()
end

function widget:GamePaused(playerID, isGamePaused)
	if not gameover then
		if isGamePaused then
			queueNotification('GamePaused',true)
		else
			queueNotification('GameUnpaused', true)
		end
	end
end

function widget:GetConfigData(data)
	return {
		customNotifications = customNotifications,
		notificationList = notificationList,
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
	if data.notificationList ~= nil and type(data.notificationList) == 'table' then
		for sound, enabled in pairs(data.notificationList) do
			if notification[sound] then
				notificationList[sound] = enabled
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
		doTutorialMode = tutorialMode
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
