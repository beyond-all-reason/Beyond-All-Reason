function gadget:GetInfo()
	return {
		name    = "Territorial Domination",
		desc    = "Implements territorial domination victory condition",
		author  = "SethDGamre",
		date    = "2025.02.08",
		license = "GNU GPL, v2",
		layer   = 0,
		enabled = true,
		depends = { 'gl4' },
	}
end

--[[
todo
need to check for tiebreaker code
]]


local modOptions = Spring.GetModOptions()
local isSynced = gadgetHandler:IsSyncedCode()
if (modOptions.deathmode ~= "territorial_domination" and not modOptions.temp_enable_territorial_domination) or not isSynced then return false end

local territorialDominationConfig = {
	short = {
		maxRounds = 3,
		minutesPerRound = 5,
	},
	default = {
		maxRounds = 3,
		minutesPerRound = 5,
	},
	long = {
		maxRounds = 7,
		minutesPerRound = 5,
	},
}

local config = territorialDominationConfig[modOptions.territorial_domination_config] or territorialDominationConfig.default
local MAX_ROUNDS = config.maxRounds
local ROUND_SECONDS = 60 * config.minutesPerRound
local DEBUGMODE = false

local GRID_SIZE = 1024
local GRID_CHECK_INTERVAL = Game.gameSpeed
local MAJORITY_THRESHOLD = 0.5

local PROGRESS_INCREMENT = 0.06
local CONTIGUOUS_PROGRESS_INCREMENT = 0.03
local DECAY_PROGRESS_INCREMENT = 0.015
local DECAY_DELAY_FRAMES = Game.gameSpeed * 10
-- Scavengers/Raptors (called horde mode in this code) has to be treated differently because in appropriately difficult matches, you can't hold 50% of the map.
-- Additionally, we must adjust the max territories required to hold according to map size and player counts so it isn't boringly easy or impossibly hard.
local HORDE_MODE_PLAYER_CAP = 16
local HORDE_MODE_MAX_THRESHOLD_PERCENTAGE_CAP = 0.50 -- the maximum percentage of territory needed to be owned by HORDE_MODE_PLAYER_CAP players to avoid defeat.
local HORDE_MODE_MIN_TERRITORY_PERCENTAGE = 0.10     -- the minimum percentage of territory needed to be owned by 16 players to avoid defeat.
local HORDE_MODE_MIN_TERRITORIES_PER_PLAYER = 1
local HORDE_MODE_MIN_PERCENTAGE_PER_PLAYER = (HORDE_MODE_MAX_THRESHOLD_PERCENTAGE_CAP - HORDE_MODE_MIN_TERRITORY_PERCENTAGE) / HORDE_MODE_PLAYER_CAP
local HORDE_MODE_ABSOLUTE_MINIMUM_TERRITORIES = 3

local BASE_TERRITORY_POINTS_VALUE = 1
local ATTACKER_POINTS_PER_ROUND_MULTIPLIER = 2

local MAX_EMPTY_IMPEDANCE_POWER = 25
local MIN_EMPTY_IMPEDANCE_MULTIPLIER = 0.80
local FLYING_UNIT_POWER_MULTIPLIER = 0.01
local CLOAKED_UNIT_POWER_MULTIPLIER = 0
local STATIC_UNIT_POWER_MULTIPLIER = 3

local RESET_DEFEAT_FRAME = 0

local MAX_PROGRESS = 1.0
local STARTING_PROGRESS = 0
local CORNER_MULTIPLIER = math.sqrt(2) -- for calculating how far from center to the corner of a square is, given the square's edge is 1 unit of distance away.
local OWNERSHIP_THRESHOLD = MAX_PROGRESS / CORNER_MULTIPLIER -- you own it when the circle color fill of the grid square touches the edge.
-- the ownership fill continues beyond touching the edge of the square, this gives you a little "buffer" before ownership is lost.

local SCORE_RULES_KEY = "territorialDominationScore"

local floor = math.floor
local max = math.max
local min = math.min
local random = math.random
local clamp = math.clamp

local spGetGameFrame = Spring.GetGameFrame
local spGetGameSeconds = Spring.GetGameSeconds
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
local spGetPositionLosState = Spring.GetPositionLosState
local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamList = Spring.GetTeamList
local spGetTeamLuaAI = Spring.GetTeamLuaAI
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local spDestroyUnit = Spring.DestroyUnit
local spSpawnCEG = Spring.SpawnCEG
local spPlaySoundFile = Spring.PlaySoundFile
local SendToUnsynced = SendToUnsynced

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local gaiaTeamID = spGetGaiaTeamID()
local gaiaAllyTeamID = select(6, spGetTeamInfo(gaiaTeamID))
local allTeams = spGetTeamList()

local allyCount = 0
local allyHordesCount = 0
local originalHighestTeamCount = nil
local numberOfSquaresX = 0
local numberOfSquaresZ = 0
local gameFrame = 0
local sentGridStructure = false
local currentSecond = 0
local roundTimestamp = 0
local currentRound = 1


local scavengerTeamID = Spring.Utilities.GetScavTeamID()
local raptorTeamID = Spring.Utilities.GetRaptorTeamID()

local allyTeamsWatch = {}
local hordeModeTeams = {}
local hordeModeAllies = {}
local unitWatchDefs = {}
local captureGrid = {}
local livingCommanders = {}
local killQueue = {}
local commandersDefs = {}
local allyScores = {}
local randomizedGridIDs = {}
local flyingUnits = {}
local allyDefeatTime = {}

local sortedTeams = {}

local function sortAllyPowersByStrength(allyPowers)
	for i = 1, #sortedTeams do
		sortedTeams[i] = nil
	end

	local teamCount = 0
	for team, power in pairs(allyPowers) do
		teamCount = teamCount + 1
		sortedTeams[teamCount] = { team = team, power = power }
	end

	if teamCount > 1 then
		table.sort(sortedTeams, function(a, b) return a.power > b.power end)
	end

	return teamCount
end

local function calculatePowerRatio(winningAllyID, currentOwnerID, allyPowers)
	local topPower = allyPowers[winningAllyID]
	local comparedPower = 0

	if winningAllyID ~= currentOwnerID and allyPowers[currentOwnerID] then
		comparedPower = max(allyPowers[currentOwnerID], MAX_EMPTY_IMPEDANCE_POWER)
	elseif #sortedTeams > 1 then
		local secondPlaceAllyID = sortedTeams[2].team
		comparedPower = max(allyPowers[secondPlaceAllyID], MAX_EMPTY_IMPEDANCE_POWER)
	else
		comparedPower = min(topPower * MIN_EMPTY_IMPEDANCE_MULTIPLIER, MAX_EMPTY_IMPEDANCE_POWER)
	end

	if topPower ~= 0 and comparedPower ~= 0 then
		return math.abs(comparedPower / topPower - 1)
	end
	return 1
end

local function processNeighborData(currentSquareData)
	local neighborAllyTeamCounts = {}
	local totalNeighborCount = 0
	local currentGridX = currentSquareData.gridX
	local currentGridZ = currentSquareData.gridZ

	-- Check all 8 surrounding neighbors
	for deltaX = -1, 1 do
		for deltaZ = -1, 1 do
			if not (deltaX == 0 and deltaZ == 0) then
				local neighborGridX = currentGridX + deltaX
				local neighborGridZ = currentGridZ + deltaZ

				if neighborGridX >= 0 and neighborGridX < numberOfSquaresX and
					neighborGridZ >= 0 and neighborGridZ < numberOfSquaresZ then
					local neighborGridID = neighborGridX * numberOfSquaresZ + neighborGridZ + 1
					local neighborSquareData = captureGrid[neighborGridID]

					if neighborSquareData then
						local neighborOwnerID = gaiaAllyTeamID
						if neighborSquareData.progress > OWNERSHIP_THRESHOLD then
							neighborOwnerID = neighborSquareData.allyOwnerID
						end
						neighborAllyTeamCounts[neighborOwnerID] = (neighborAllyTeamCounts[neighborOwnerID] or 0) + 1
						totalNeighborCount = totalNeighborCount + 1
					end
				end
			end
		end
	end

	return neighborAllyTeamCounts, totalNeighborCount
end

local function getRandomizedGridIDs()
	for i = 1, #randomizedGridIDs do
		randomizedGridIDs[i] = nil
	end

	local index = 0
	for gridID in pairs(captureGrid) do
		index = index + 1
		randomizedGridIDs[index] = gridID
	end

	for i = index, 2, -1 do
		local j = random(i)
		randomizedGridIDs[i], randomizedGridIDs[j] = randomizedGridIDs[j], randomizedGridIDs[i]
	end

	return randomizedGridIDs
end

local function createVisibilityArray(squareData)
	local maxAllyID = 0
	for allyTeamID in pairs(allyTeamsWatch) do
		maxAllyID = max(maxAllyID, allyTeamID)
	end

	local visibilityArray = {}
	-- we use strings instead because SendToUnsynced() doesn't support tables,
	-- bitmasks have floating point errors with team sizes > 22, and booleans for multiple states would require crazy numbers of SendToUnsynced() calls.
	for i = 0, maxAllyID do
		visibilityArray[i + 1] = "0"
	end

	for allyTeamID in pairs(allyTeamsWatch) do
		local isVisible = false

		if allyTeamID == squareData.allyOwnerID then
			isVisible = true
		else
			--check middle first, because it's most likely to be visible
			isVisible = spGetPositionLosState(squareData.gridMidpointX, 0, squareData.gridMidpointZ, allyTeamID)
		end

		if not isVisible then
			for _, corner in ipairs(squareData.corners) do
				isVisible = spGetPositionLosState(corner.x, 0, corner.z, allyTeamID)
				if isVisible then
					break
				end
			end
		end

		if isVisible then
			visibilityArray[allyTeamID + 1] = "1"
		end
	end

	return table.concat(visibilityArray)
end

local function initializeUnsyncedGrid()
	local maxAllyID = 0
	for allyTeamID in pairs(allyTeamsWatch) do
		maxAllyID = max(maxAllyID, allyTeamID)
	end

	local allVisibleArray = {}
	for i = 0, maxAllyID do
		allVisibleArray[i + 1] = "0"
	end
	for allyTeamID in pairs(allyTeamsWatch) do
		allVisibleArray[allyTeamID + 1] = "1"
	end
	local initVisibilityArray = table.concat(allVisibleArray)

	for gridID, squareData in pairs(captureGrid) do
		SendToUnsynced("InitializeGridSquare",
			gridID,
			gaiaAllyTeamID,
			squareData.progress,
			squareData.gridMidpointX,
			squareData.gridMidpointZ,
			initVisibilityArray,
			squareData.attackerPointsValue or 0, -- attackerCaptureValue  
			squareData.defensePointsValue or 0   -- ownerRoundEndValue
		)
	end

	sentGridStructure = true
end

local function setAllyTeamRanks(allyScores)
	local rankedAllyScores = {}
	for allyID, scoreData in pairs(allyScores) do
		local defeatTimeRemaining = math.huge
		if allyDefeatTime[allyID] and allyDefeatTime[allyID] > 0 then
			defeatTimeRemaining = max(0, allyDefeatTime[allyID] - spGetGameSeconds())
		end
		table.insert(rankedAllyScores, { allyID = allyID, score = scoreData.score, defeatTimeRemaining = defeatTimeRemaining })
	end

	table.sort(rankedAllyScores, function(a, b)
		if a.score == b.score then
			return a.defeatTimeRemaining > b.defeatTimeRemaining
		end
		return a.score > b.score
	end)

	local currentRank = 1
	local previousScore = -1
	local previousDefeatTime = -1

	for i, allyData in ipairs(rankedAllyScores) do
		if i <= 1 or allyData.score ~= previousScore or allyData.defeatTimeRemaining ~= previousDefeatTime then
			currentRank = i
		end

		previousScore = allyData.score
		previousDefeatTime = allyData.defeatTimeRemaining

		-- Update the rank directly in allyScores
		allyScores[allyData.allyID].rank = currentRank

		for teamID in pairs(allyTeamsWatch[allyData.allyID] or {}) do
			Spring.SetTeamRulesParam(teamID, "territorialDominationRank", currentRank)
		end
	end
end

local function initializeUnitDefs()
	for defID, def in pairs(UnitDefs) do
		local defData
		if def.power then
			defData = { power = def.power }
			if def.speed == 0 then
				defData.power = defData.power * STATIC_UNIT_POWER_MULTIPLIER
			end
			if def.customParams and def.customParams.objectify then
				defData.power = 0 -- dragonsteeth and other objectified units aren't targetable automatically, and so aren't counted towards capture for convenience purposes.
			end
		end
		unitWatchDefs[defID] = defData

		if def.customParams and def.customParams.iscommander then
			commandersDefs[defID] = true
		end
	end
end

local function processLivingTeams()
	local newAllyTeamsCount = 0
	local newAllyHordesCount = 0
	local playerTeamsCount = 0
	allyTeamsWatch = {}
	hordeModeAllies = {}

	allTeams = Spring.GetTeamList()
	for _, teamID in ipairs(allTeams) do
		local _, _, isDead = spGetTeamInfo(teamID)
		if not isDead then
			local allyID = select(6, spGetTeamInfo(teamID))

			if allyID and allyID ~= gaiaAllyTeamID then
				if not hordeModeTeams[teamID] then
					playerTeamsCount = playerTeamsCount + 1
					if not allyTeamsWatch[allyID] then
						newAllyTeamsCount = newAllyTeamsCount + 1
					end
					allyTeamsWatch[allyID] = allyTeamsWatch[allyID] or {}
					allyTeamsWatch[allyID][teamID] = true
				else
					if not hordeModeAllies[allyID] then
						newAllyHordesCount = newAllyHordesCount + 1
					end
					hordeModeAllies[allyID] = true
				end
			end
		end
	end

	return newAllyTeamsCount, newAllyHordesCount, playerTeamsCount
end

local function getHighestTeamCount()
	local highestTeamCount = 0
	for allyID, teams in pairs(allyTeamsWatch) do
		local teamCount = 0
		for teamID in pairs(teams) do
			teamCount = teamCount + 1
		end
		highestTeamCount = max(highestTeamCount, teamCount)
	end
	return highestTeamCount
end

local function initializeTeamData()
	for _, teamID in ipairs(allTeams) do
		if teamID == scavengerTeamID or teamID == raptorTeamID then
			hordeModeTeams[teamID] = true
		end
		Spring.SetTeamRulesParam(teamID, "defeatTime", RESET_DEFEAT_FRAME, {public = true})
	end
	processLivingTeams()
	originalHighestTeamCount = getHighestTeamCount()
	for allyID in pairs(allyTeamsWatch) do
		if not allyScores[allyID] then
			allyScores[allyID] = { score = 0, rank = 1 }
		end
	end
end



local function updateLivingTeamsData()
	local newAllyCount, newHordeAllyCount = processLivingTeams()
	allyHordesCount = newHordeAllyCount
	allyCount = newAllyCount
end

local function setAllyGridToGaia(allyID)
	for gridID, data in pairs(captureGrid) do
		if data.allyOwnerID == allyID then
			data.allyOwnerID = gaiaAllyTeamID
			data.progress = STARTING_PROGRESS
		end
	end
end

local function createGridSquareData(x, z)
	local originX = x * GRID_SIZE
	local originZ = z * GRID_SIZE
	local data = {}

	data.mapOriginX = originX
	data.mapOriginZ = originZ
	data.gridX = x
	data.gridZ = z
	data.gridMidpointX = originX + GRID_SIZE / 2
	data.gridMidpointZ = originZ + GRID_SIZE / 2
	data.allyOwnerID = gaiaAllyTeamID
	data.progress = STARTING_PROGRESS
	data.decayDelay = 0
	data.contested = false
	data.contiguous = false
	data.ownedNeighbors = 0
	data.roundsOwned = 0
	data.attackerPointsValue = 0
	data.defensePointsValue = 0
	data.attackerPointsTaken = {}
	data.neighborAllyTeamCounts = {}
	data.totalNeighborCount = 0
	data.wasCapturedThisRound = false
	data.corners = {
		{ x = data.mapOriginX,             z = data.mapOriginZ },
		{ x = data.mapOriginX + GRID_SIZE, z = data.mapOriginZ },
		{ x = data.mapOriginX,             z = data.mapOriginZ + GRID_SIZE },
		{ x = data.mapOriginX + GRID_SIZE, z = data.mapOriginZ + GRID_SIZE }
	}
	return data
end

local function generateCaptureGrid()
	local gridData = {}

	for x = 0, numberOfSquaresX - 1 do
		for z = 0, numberOfSquaresZ - 1 do
			local index = x * numberOfSquaresZ + z + 1
			gridData[index] = createGridSquareData(x, z)
		end
	end
	return gridData
end

local function queueCommanderTeleportRetreat(unitID)
	local killDelayFrames = floor(Game.gameSpeed * 0.5)
	local killFrame = spGetGameFrame() + killDelayFrames
	killQueue[killFrame] = killQueue[killFrame] or {}
	killQueue[killFrame][unitID] = true

	local x, y, z = spGetUnitPosition(unitID)
	spSpawnCEG("commander-spawn", x, y, z, 0, 0, 0)
	spPlaySoundFile("commanderspawn-mono", 1.0, x, y, z, 0, 0, 0, "sfx")
	GG.ComSpawnDefoliate(x, y, z)
end

local function triggerAllyDefeat(allyID)
	if DEBUGMODE then return end
	for unitID, commanderAllyID in pairs(livingCommanders) do
		if commanderAllyID == allyID then
			queueCommanderTeleportRetreat(unitID)
		end
	end
	for _, teamID in ipairs(allTeams) do
		Spring.SetTeamRulesParam(teamID, "defeatTime", RESET_DEFEAT_FRAME, {public = true})
	end
end

local function addProgress(gridID, progressChange, winningAllyID, delayDecay)
	local data = captureGrid[gridID]
	local newProgress

	if hordeModeAllies[winningAllyID] then -- horde mode units cannot own territory, they give it back to gaia
		winningAllyID = gaiaAllyTeamID
		newProgress = data.progress - math.abs(progressChange)
	else
		newProgress = data.progress + progressChange
	end

	if newProgress < 0 then
		data.allyOwnerID = winningAllyID
		data.progress = math.abs(newProgress)
		data.wasCapturedThisRound = true
	elseif newProgress > MAX_PROGRESS then
		data.progress = MAX_PROGRESS
	else
		data.progress = newProgress
	end

	if winningAllyID == gaiaAllyTeamID then
		data.decayDelay = 0
	end

	if delayDecay and (data.contested or data.contiguous) and data.allyOwnerID ~= winningAllyID then
		data.decayDelay = gameFrame + DECAY_DELAY_FRAMES
	end
end

local function processGridSquareCapture(gridID)
	local data = captureGrid[gridID]
	local units = spGetUnitsInRectangle(data.mapOriginX, data.mapOriginZ, data.mapOriginX + GRID_SIZE,
		data.mapOriginZ + GRID_SIZE)

	local allyPowers = {}
	local hasUnits = false
	data.contested = false

	-- Calculate ally powers in this square
	for i = 1, #units do
		local unitID = units[i]

		if not spGetUnitIsBeingBuilt(unitID) then
			local unitDefID = spGetUnitDefID(unitID)
			local unitData = unitWatchDefs[unitDefID]
			local allyTeam = spGetUnitAllyTeam(unitID)

			if unitData and unitData.power and (allyTeamsWatch[allyTeam] or hordeModeAllies[allyTeam]) then
				hasUnits = true
				local power = unitData.power
				if flyingUnits[unitID] then
					power = power * FLYING_UNIT_POWER_MULTIPLIER
				end
				if spGetUnitIsCloaked(unitID) then
					power = power * CLOAKED_UNIT_POWER_MULTIPLIER
				end

				if hordeModeAllies[allyTeam] then
					allyPowers[gaiaAllyTeamID] = (allyPowers[gaiaAllyTeamID] or 0) + power -- horde mode units cannot own territory, they give it back to gaia
				else
					allyPowers[allyTeam] = (allyPowers[allyTeam] or 0) + power
				end
			end
		end
	end

	-- Add randomization and filter out zero powers
	for allyID, power in pairs(allyPowers) do
		if allyPowers[allyID] > 0 then
			allyPowers[allyID] = power + random() -- randomize power to prevent ties where the last tied victor always wins
			if allyID ~= data.allyOwnerID then
				data.contested = true
			end
		else
			allyPowers[allyID] = nil -- not allowed to capture without power.
		end
	end

	if not hasUnits then
		return -- no units, no capture progress
	end

	local currentOwnerID = data.allyOwnerID
	local teamCount = sortAllyPowersByStrength(allyPowers)

	if teamCount == 0 then
		return -- no valid teams
	end

	local winningAllyID = sortedTeams[1].team
	local powerRatio = calculatePowerRatio(winningAllyID, currentOwnerID, allyPowers)

	local progressChange = 0
	if currentOwnerID == winningAllyID then
		progressChange = PROGRESS_INCREMENT * powerRatio
	else
		progressChange = -(powerRatio * PROGRESS_INCREMENT)
	end

	-- Apply progress change using helper function
	addProgress(gridID, progressChange, winningAllyID, true)
end

local function processDecay(gridID)
	local data = captureGrid[gridID]
	if not data.contested and not data.contiguous and data.decayDelay < gameFrame then
		local progressChange
		if data.progress > OWNERSHIP_THRESHOLD then
			progressChange = DECAY_PROGRESS_INCREMENT
		else
			progressChange = -DECAY_PROGRESS_INCREMENT
		end
		
		if data.progress > OWNERSHIP_THRESHOLD then
			addProgress(gridID, progressChange, data.allyOwnerID, false)
		else
			addProgress(gridID, progressChange, gaiaAllyTeamID, false)
		end
	end
end

local function processMainCaptureLogic()
	updateLivingTeamsData()

	for gridID, data in pairs(captureGrid) do
		processGridSquareCapture(gridID)
	end
end

local function processAttackScoresNeighborsAndDecay()
	local randomizedIDs = getRandomizedGridIDs()
	for i = 1, #randomizedIDs do --shuffled to prevent contiguous ties from always being awarded to the same ally
		local gridID = randomizedIDs[i]
		local data = captureGrid[gridID]

		if not data.contested then
			data.neighborAllyTeamCounts, data.totalNeighborCount = processNeighborData(data)
			local dominantAllyTeamCount = 0
			local dominantAllyTeamID
			data.contiguous = false

			for allyTeamID, neighborCount in pairs(data.neighborAllyTeamCounts) do
				if neighborCount > dominantAllyTeamCount and allyTeamsWatch[allyTeamID] then
					dominantAllyTeamID = allyTeamID
					dominantAllyTeamCount = neighborCount
				end
			end

			if dominantAllyTeamID and dominantAllyTeamCount > data.totalNeighborCount * MAJORITY_THRESHOLD then
				data.contiguous = true
				local progressChange
				-- If dominant ally is different from current owner, capture (negative progress)
				if dominantAllyTeamID ~= data.allyOwnerID then
					progressChange = -CONTIGUOUS_PROGRESS_INCREMENT
				else
					-- If dominant ally is same as current owner, reinforce (positive progress)
					progressChange = CONTIGUOUS_PROGRESS_INCREMENT
				end
				
				addProgress(gridID, progressChange, dominantAllyTeamID, true)
			end
		end
	end

	--decay logic
	for gridID, data in pairs(captureGrid) do
		processDecay(gridID)
		local squareData = captureGrid[gridID]
		local visibilityArray = createVisibilityArray(squareData)
		SendToUnsynced("UpdateGridSquare", gridID, squareData.allyOwnerID, squareData.progress, visibilityArray, squareData.attackerPointsValue or 0, squareData.defensePointsValue or 0)
	end
end

local function updateGridDefensePointRewards()
	for gridID, data in pairs(captureGrid) do
		if data.progress > OWNERSHIP_THRESHOLD and allyTeamsWatch[data.allyOwnerID] then
			data.defensePointsValue = data.ownedNeighbors and BASE_TERRITORY_POINTS_VALUE + data.ownedNeighbors or 0
		end
	end
end

local function calculateProjectedPointsForNextRound()
	local projectedPoints = {}
	
	for allyID in pairs(allyTeamsWatch) do
		local projectedScore = 0
		
		for gridID, data in pairs(captureGrid) do
			if data.progress > OWNERSHIP_THRESHOLD and data.allyOwnerID == allyID then
				projectedScore = projectedScore + currentRound
			end
		end
		
		projectedPoints[allyID] = projectedScore
	end
	
	return projectedPoints
end

local function calculateMaximumPossiblePoints()
	-- Calculate the maximum possible points at the end of the final round
	-- Each territory owned gives points equal to the round number
	-- Maximum points = total territories * sum of round numbers from 1 to MAX_ROUNDS
	
	local totalTerritories = numberOfSquaresX * numberOfSquaresZ
	local roundSum = 0
	for round = 1, MAX_ROUNDS do
		roundSum = roundSum + round
	end
	
	local maxPossiblePoints = totalTerritories * roundSum
	local pointsCap = math.floor(maxPossiblePoints / 2) -- Divide by 2 as requested
	
	return pointsCap
end

local function processDefenseScores()  
	for gridID, data in pairs(captureGrid) do
		if data.progress > OWNERSHIP_THRESHOLD and allyTeamsWatch[data.allyOwnerID] then
			local points = currentRound
			local allyScore = allyScores[data.allyOwnerID].score
			allyScore = allyScore or 0
			allyScores[data.allyOwnerID].score = allyScore + points
		end
	end
end

local function processRoundEnd()
	for gridID, data in pairs(captureGrid) do
		if data.progress > OWNERSHIP_THRESHOLD and allyTeamsWatch[data.allyOwnerID] then
			data.roundsOwned = data.roundsOwned + 1
			data.attackerPointsTaken = {}
			data.wasCapturedThisRound = false
		else
			data.roundsOwned = 0
			data.attackerPointsTaken = {}
		end
	end
end

function gadget:GameFrame(frame)
	if not sentGridStructure then
		initializeUnsyncedGrid()
	end

	gameFrame = frame
	local frameModulo = frame % GRID_CHECK_INTERVAL

	if frameModulo == 0 then
		currentSecond = spGetGameSeconds()
		processMainCaptureLogic()
	elseif frameModulo == 1 then
		processAttackScoresNeighborsAndDecay()
	elseif frameModulo == 2 then
		local seconds = spGetGameSeconds()
		updateGridDefensePointRewards()
		if seconds >= roundTimestamp or currentRound > MAX_ROUNDS then
			if currentRound <= MAX_ROUNDS then
				currentRound = currentRound + 1
				processDefenseScores()
				processRoundEnd()
			else
				Spring.Echo("kill them all", gameFrame)
				for allyID, scoreData in pairs(allyScores) do
					if scoreData.rank > 1 then
						triggerAllyDefeat(allyID)
					end
				end
			end
			roundTimestamp = seconds + ROUND_SECONDS
		end
		setAllyTeamRanks(allyScores)
		local highestScore = 0
		local secondHighestScore = 0
		for allyID, scoreData in pairs(allyScores) do
			if scoreData.score > highestScore then
				secondHighestScore = highestScore
				highestScore = scoreData.score
			elseif scoreData.score > secondHighestScore then
				secondHighestScore = scoreData.score
			end
		end
	Spring.SetGameRulesParam("territorialDominationHighestScore", highestScore)
	Spring.SetGameRulesParam("territorialDominationSecondHighestScore", secondHighestScore)
	Spring.SetGameRulesParam("territorialDominationRoundEndTimestamp", roundTimestamp)
	Spring.SetGameRulesParam("territorialDominationCurrentRound", currentRound)
	Spring.SetGameRulesParam("territorialDominationMaxRounds", MAX_ROUNDS)
		
		-- Calculate and send projected points for next round
		local projectedPoints = calculateProjectedPointsForNextRound()
		
		-- Send points cap via game rules parameter
		local pointsCap = calculateMaximumPossiblePoints()
		Spring.SetGameRulesParam("territorialDominationPointsCap", pointsCap)
		
		for allyID, scoreData in pairs(allyScores) do
			--send scores to clients via team rules parameters
			for teamID, _ in pairs(allyTeamsWatch[allyID] or {}) do
				Spring.SetTeamRulesParam(teamID, SCORE_RULES_KEY, scoreData.score, {public = true})
				Spring.SetTeamRulesParam(teamID, "territorialDominationProjectedPoints", projectedPoints[allyID] or 0, {public = true})
			end
			SendToUnsynced("UpdateAllyScore", allyID, scoreData.score, projectedPoints[allyID] or 0)
		end
	end

	local currentKillQueue = killQueue[gameFrame]
	if currentKillQueue then
		for unitID in pairs(currentKillQueue) do
			spDestroyUnit(unitID, false, true)
		end
		killQueue[gameFrame] = nil
	end
end

function gadget:Initialize()
	numberOfSquaresX = math.ceil(mapSizeX / GRID_SIZE)
	numberOfSquaresZ = math.ceil(mapSizeZ / GRID_SIZE)
	SendToUnsynced("InitializeConfigs", GRID_SIZE, GRID_CHECK_INTERVAL)
	Spring.SetGameRulesParam("territorialDominationGridSize", GRID_SIZE)
	Spring.SetGameRulesParam("territorialDominationGridCheckInterval", GRID_CHECK_INTERVAL)
	captureGrid = generateCaptureGrid()

	roundTimestamp = spGetGameSeconds() + ROUND_SECONDS
	initializeTeamData()
	initializeUnitDefs()
	updateLivingTeamsData()

	local units = Spring.GetAllUnits()
	for i = 1, #units do
		local unitID = units[i]
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end

	allTeams = Spring.GetTeamList()
	for _, teamID in pairs(allTeams) do
		Spring.SetTeamRulesParam(teamID, "defeatTime", RESET_DEFEAT_FRAME, {public = true})
		Spring.SetTeamRulesParam(teamID, "territorialDominationRank", 1, {public = true})
	end
	
	-- Send initial projected points
	local initialProjectedPoints = calculateProjectedPointsForNextRound()
	for allyID, projectedScore in pairs(initialProjectedPoints) do
		for teamID, _ in pairs(allyTeamsWatch[allyID] or {}) do
			Spring.SetTeamRulesParam(teamID, "territorialDominationProjectedPoints", projectedScore, {public = true})
		end
	end
	
	-- Send initial points cap via game rules parameter
	local initialPointsCap = calculateMaximumPossiblePoints()
	Spring.SetGameRulesParam("territorialDominationPointsCap", initialPointsCap)
	
	-- Send initial round information
	Spring.SetGameRulesParam("territorialDominationCurrentRound", currentRound)
	Spring.SetGameRulesParam("territorialDominationRoundDuration", ROUND_SECONDS)
	Spring.SetGameRulesParam("territorialDominationStartTime", spGetGameSeconds())
	Spring.SetGameRulesParam("territorialDominationMaxRounds", MAX_ROUNDS)
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if commandersDefs[unitDefID] then
		livingCommanders[unitID] = select(6, Spring.GetTeamInfo(unitTeam))
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	livingCommanders[unitID] = nil
	flyingUnits[unitID] = nil
end

function gadget:UnitEnteredAir(unitID, unitDefID, unitTeam)
	flyingUnits[unitID] = true
end

function gadget:UnitLeftAir(unitID, unitDefID, unitTeam)
	flyingUnits[unitID] = nil
end

function gadget:TeamDied(teamID)
	local allyID = select(6, Spring.GetTeamInfo(teamID))
	setAllyGridToGaia(allyID)
end