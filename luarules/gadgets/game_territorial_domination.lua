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

-- if top allyID is defeated through conventional means, it fucks up the ranking and the declaring of victors in both overtime and elimination scenarios
local modOptions = Spring.GetModOptions()
local isSynced = gadgetHandler:IsSyncedCode()
if (modOptions.deathmode ~= "territorial_domination" and not modOptions.temp_enable_territorial_domination) or not isSynced then return false end

local territorialDominationConfig = {
	short = {
		maxRounds = 3,
		minutesPerRound = 5,
	},
	default = {
		maxRounds = 10,
		minutesPerRound = 3,
	},
	long = {
		maxRounds = 3,
		minutesPerRound = 12,
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

local MAX_EMPTY_IMPEDANCE_POWER = 25
local MIN_EMPTY_IMPEDANCE_MULTIPLIER = 0.80
local FLYING_UNIT_POWER_MULTIPLIER = 0.01
local CLOAKED_UNIT_POWER_MULTIPLIER = 0
local STATIC_UNIT_POWER_MULTIPLIER = 3
local COMMANDER_POWER_MULTIPLIER = 1000

local MAX_PROGRESS = 1.0
local STARTING_PROGRESS = 0
local CORNER_MULTIPLIER = math.sqrt(2)
local OWNERSHIP_THRESHOLD = MAX_PROGRESS / CORNER_MULTIPLIER

local floor = math.floor
local max = math.max
local min = math.min
local random = math.random

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
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local spDestroyUnit = Spring.DestroyUnit
local spSpawnCEG = Spring.SpawnCEG
local spPlaySoundFile = Spring.PlaySoundFile
local spGetUnitIsDead = Spring.GetUnitIsDead
local SendToUnsynced = SendToUnsynced

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local gaiaTeamID = spGetGaiaTeamID()
local gaiaAllyTeamID = select(6, spGetTeamInfo(gaiaTeamID))
local allTeams = spGetTeamList()

local numberOfSquaresX = 0
local numberOfSquaresZ = 0
local gameFrame = 0
local sentGridStructure = false
local roundTimestamp = 0
local currentRound = 0
local gameOver = false
local allyTeamsCount = 0
local previousRoundHighestScore = 0

local allyTeamsWatch = {}
local unitWatchDefs = {}
local captureGrid = {}
local livingCommanders = {}
local killQueue = {}
local commandersDefs = {}
local allyScores = {}
local flyingUnits = {}
 
local projectedAllyTeamPoints = {}
local sortedTeams = {}

for defID, def in pairs(UnitDefs) do
	local defData
	if def.power then
		defData = { power = def.power }
		if def.speed == 0 then
			defData.power = defData.power * STATIC_UNIT_POWER_MULTIPLIER
		end
		if def.customParams and def.customParams.objectify then
			defData.power = 0
		end
	end
	unitWatchDefs[defID] = defData

	if def.customParams and def.customParams.iscommander then
		commandersDefs[defID] = true
	end
end

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

local function createVisibilityArray(squareData)
	local maxAllyID = 0
	for allyTeamID in pairs(allyTeamsWatch) do
		maxAllyID = max(maxAllyID, allyTeamID)
	end

	local visibilityArray = {}
	for i = 0, maxAllyID do
		visibilityArray[i + 1] = "0"
	end

	for allyTeamID in pairs(allyTeamsWatch) do
		local isVisible = false

		if allyTeamID == squareData.allyOwnerID then
			isVisible = true
		else
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
			initVisibilityArray
		)
	end

	sentGridStructure = true
end

local function setAllyTeamRanks(allyScores)
	local rankedAllyScores = {}
	for allyID, scoreData in pairs(allyScores) do
		local rankingScore = scoreData.score
		if currentRound > MAX_ROUNDS then
			local projectedPoints = projectedAllyTeamPoints[allyID] or 0
			rankingScore = rankingScore + projectedPoints
		end
		table.insert(rankedAllyScores, { allyID = allyID, rankingScore = rankingScore })
	end

	table.sort(rankedAllyScores, function(a, b)
		return a.rankingScore > b.rankingScore
	end)

	local currentRank = 1
	local previousScore = -1
	for i, allyData in ipairs(rankedAllyScores) do
		if i <= 1 or allyData.rankingScore ~= previousScore then
			currentRank = i
			previousScore = allyData.rankingScore
		end
		allyScores[allyData.allyID].rank = currentRank
		for teamID in pairs(allyTeamsWatch[allyData.allyID] or {}) do
			Spring.SetTeamRulesParam(teamID, "territorialDominationRank", currentRank, {public = true})
		end
	end
end

local function processLivingTeams()
	allyTeamsCount = 0
	allyTeamsWatch = {}

	allTeams = Spring.GetTeamList()
	for _, teamID in ipairs(allTeams) do
		local _, _, isDead, _, _, allyID = spGetTeamInfo(teamID)
		if not isDead then
			if allyID and allyID ~= gaiaAllyTeamID then
				if not allyTeamsWatch[allyID] then
					allyTeamsCount = allyTeamsCount + 1
				end
				allyTeamsWatch[allyID] = allyTeamsWatch[allyID] or {}
				allyTeamsWatch[allyID][teamID] = true
			end
		end
	end

	if allyTeamsCount <= 1 then
		gameOver = true
	end
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
	data.neighborAllyTeamCounts = {}
	data.totalNeighborCount = 0
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

local function defeatAlly(allyID)
	if DEBUGMODE or not allyTeamsWatch[allyID] then return end
	for unitID, commanderAllyID in pairs(livingCommanders) do
		if commanderAllyID == allyID then
			local killDelayFrames = floor(Game.gameSpeed * 0.5)
			local killFrame = spGetGameFrame() + killDelayFrames
			killQueue[killFrame] = killQueue[killFrame] or {}
			killQueue[killFrame][unitID] = true

			local x, y, z = spGetUnitPosition(unitID)
			spSpawnCEG("commander-spawn", x, y, z, 0, 0, 0)
			spPlaySoundFile("commanderspawn-mono", 1.0, x, y, z, 0, 0, 0, "sfx")
			GG.ComSpawnDefoliate(x, y, z)
		end
	end
	for teamID in pairs(allyTeamsWatch[allyID] or {}) do
		local isDead = select(3, spGetTeamInfo(teamID))
		if not isDead then
			Spring.SetTeamRulesParam(teamID, "territorialDominationProjectedPoints", 0, {public = true})
		end
	end
end

local function addProgress(gridID, progressChange, winningAllyID, delayDecay)
	local data = captureGrid[gridID]
	local newProgress = data.progress + progressChange

	if newProgress < 0 then
		data.allyOwnerID = winningAllyID
		data.progress = math.abs(newProgress)
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

	for i = 1, #units do
		local unitID = units[i]

		if not spGetUnitIsBeingBuilt(unitID) then
			local unitDefID = spGetUnitDefID(unitID)
			local unitData = unitWatchDefs[unitDefID]
			local allyTeam = spGetUnitAllyTeam(unitID)

			if unitData and unitData.power and allyTeamsWatch[allyTeam] then
				hasUnits = true
				local power = unitData.power
				if flyingUnits[unitID] then
					power = power * FLYING_UNIT_POWER_MULTIPLIER
				end
				if commandersDefs[unitDefID] then
					power = power * COMMANDER_POWER_MULTIPLIER
				end
				if spGetUnitIsCloaked(unitID) then
					power = power * CLOAKED_UNIT_POWER_MULTIPLIER
				end

				allyPowers[allyTeam] = (allyPowers[allyTeam] or 0) + power
			end
		end
	end

	for allyID, power in pairs(allyPowers) do
		if allyPowers[allyID] > 0 then
			allyPowers[allyID] = power + random()
			if allyID ~= data.allyOwnerID then
				data.contested = true
			end
		else
			allyPowers[allyID] = nil
		end
	end

	if not hasUnits then
		return
	end

	local currentOwnerID = data.allyOwnerID
	local teamCount = sortAllyPowersByStrength(allyPowers)

	if teamCount == 0 then
		return
	end

	local winningAllyID = sortedTeams[1].team
	local powerRatio = calculatePowerRatio(winningAllyID, currentOwnerID, allyPowers)

	local progressChange = 0
	if currentOwnerID == winningAllyID then
		progressChange = PROGRESS_INCREMENT * powerRatio
	else
		progressChange = -(powerRatio * PROGRESS_INCREMENT)
	end

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
	processLivingTeams()

	for gridID, data in pairs(captureGrid) do
		processGridSquareCapture(gridID)
	end
end

local function processNeighborsAndDecay()
	for gridID, data in pairs(captureGrid) do
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
				if dominantAllyTeamID ~= data.allyOwnerID then
					progressChange = -CONTIGUOUS_PROGRESS_INCREMENT
				else
					progressChange = CONTIGUOUS_PROGRESS_INCREMENT
				end
				addProgress(gridID, progressChange, dominantAllyTeamID, true)
			end
		end
	end

	for gridID, squareData in pairs(captureGrid) do
		processDecay(gridID)
		local visibilityArray = createVisibilityArray(squareData)
		SendToUnsynced("UpdateGridSquare", gridID, squareData.allyOwnerID, squareData.progress, visibilityArray)
	end
end

local function updateProjectedPoints()
	for allyID in pairs(allyTeamsWatch) do
		local projectedScore = 0
		if not gameOver then
			for gridID, data in pairs(captureGrid) do
				if data.progress > OWNERSHIP_THRESHOLD and data.allyOwnerID == allyID then
					projectedScore = projectedScore + currentRound
				end
			end
		end
		projectedAllyTeamPoints[allyID] = projectedScore
	end
	for allyID, projectedScore in pairs(projectedAllyTeamPoints) do
		for teamID, _ in pairs(allyTeamsWatch[allyID] or {}) do
			Spring.SetTeamRulesParam(teamID, "territorialDominationProjectedPoints", projectedScore, {public = true})
		end
	end
end

local function calculateMaximumPossiblePoints()
	local totalTerritories = numberOfSquaresX * numberOfSquaresZ
	local roundSum = 0
	for round = 1, MAX_ROUNDS do
		roundSum = roundSum + round
	end
	local maxPossiblePoints = totalTerritories * roundSum
	local pointsCap = math.ceil(maxPossiblePoints / allyTeamsCount + 1)
	
	return pointsCap
end

local function resolveOvertimeIfLeaderExists()
	if currentRound <= MAX_ROUNDS then return end
	local topAllyID
	local topCombined = -1
	local secondCombined = -1
	for allyID in pairs(allyTeamsWatch) do
		local baseScore = (allyScores[allyID] and allyScores[allyID].score) or 0
		local projected = projectedAllyTeamPoints[allyID] or 0
		local combined = baseScore + projected
		if combined > topCombined then
			secondCombined = topCombined
			topCombined = combined
			topAllyID = allyID
		elseif combined > secondCombined then
			secondCombined = combined
		end
	end
	if topAllyID and topCombined > secondCombined then
		for allyID in pairs(allyTeamsWatch) do
			if allyID ~= topAllyID then
				defeatAlly(allyID)
			end
		end
		gameOver = true
	end
end

function gadget:GameFrame(frame)
	if not sentGridStructure then
		initializeUnsyncedGrid()
	end

	gameFrame = frame
	local frameModulo = frame % GRID_CHECK_INTERVAL

	if frameModulo == 0 then
		processMainCaptureLogic()
	elseif frameModulo == 1 then
		processNeighborsAndDecay()
	elseif frameModulo == 2 then
		updateProjectedPoints()
		setAllyTeamRanks(allyScores)
		local seconds = spGetGameSeconds()
		if seconds >= roundTimestamp or currentRound > MAX_ROUNDS then
			local newHighestScore = 0
			if currentRound <= MAX_ROUNDS then
				for allyID in pairs(allyTeamsWatch) do
					local addPoints = projectedAllyTeamPoints[allyID] or 0
					allyScores[allyID].score = allyScores[allyID].score + addPoints
					newHighestScore = math.max(newHighestScore, allyScores[allyID].score)
				end
				currentRound = currentRound + 1
				if currentRound <= MAX_ROUNDS then
					for allyID, scoreData in pairs(allyScores) do
						if scoreData.score < previousRoundHighestScore and allyTeamsWatch[allyID] then
							defeatAlly(allyID)
						end
					end
				end
			else
				resolveOvertimeIfLeaderExists()
			end
			if currentRound <= MAX_ROUNDS then
				previousRoundHighestScore = newHighestScore
				Spring.SetGameRulesParam("territorialDominationPrevHighestScore", previousRoundHighestScore)
				roundTimestamp = seconds + ROUND_SECONDS
			end
		end

		Spring.SetGameRulesParam("territorialDominationRoundEndTimestamp", currentRound > MAX_ROUNDS and 0 or roundTimestamp)
		Spring.SetGameRulesParam("territorialDominationCurrentRound", currentRound)
		Spring.SetGameRulesParam("territorialDominationMaxRounds", MAX_ROUNDS)
		
		for allyID, scoreData in pairs(allyScores) do
			for teamID, _ in pairs(allyTeamsWatch[allyID] or {}) do
				Spring.SetTeamRulesParam(teamID, "territorialDominationScore", scoreData.score, {public = true})
				Spring.SetTeamRulesParam(teamID, "territorialDominationProjectedPoints", projectedAllyTeamPoints[allyID] or 0, {public = true})
			end
		end
	end

	local currentKillQueue = killQueue[gameFrame]
	if currentKillQueue then
		for unitID in pairs(currentKillQueue) do
			if not spGetUnitIsDead(unitID) then
				currentKillQueue[unitID] = nil
				spDestroyUnit(unitID, false, true)
			end
		end
		killQueue[gameFrame] = nil
	end
end

function gadget:Initialize()
	numberOfSquaresX = math.ceil(mapSizeX / GRID_SIZE)
	numberOfSquaresZ = math.ceil(mapSizeZ / GRID_SIZE)
	SendToUnsynced("InitializeConfigs", GRID_SIZE, GRID_CHECK_INTERVAL)
	captureGrid = generateCaptureGrid()

	processLivingTeams()
	for allyID in pairs(allyTeamsWatch) do
		if not allyScores[allyID] then
			allyScores[allyID] = { score = 0, rank = 1 }
		end
	end
	local initialPointsCap = calculateMaximumPossiblePoints()
	Spring.SetGameRulesParam("territorialDominationPointsCap", initialPointsCap)

	local units = Spring.GetAllUnits()
	for i = 1, #units do
		local unitID = units[i]
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end

	allTeams = Spring.GetTeamList()
	for _, teamID in pairs(allTeams) do
		Spring.SetTeamRulesParam(teamID, "territorialDominationRank", 1, {public = true})
	end
	
	updateProjectedPoints()
	
	Spring.SetGameRulesParam("territorialDominationCurrentRound", currentRound)
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
	local allyID = select(6, spGetTeamInfo(teamID))
	setAllyGridToGaia(allyID)
	
	for _, teamIDInAlly in pairs(Spring.GetTeamList(allyID) or {}) do
		Spring.SetTeamRulesParam(teamIDInAlly, "territorialDominationProjectedPoints", 0, {public = true})
	end
end