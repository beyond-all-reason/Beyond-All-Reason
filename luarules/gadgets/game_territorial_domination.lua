function gadget:GetInfo()
	return {
		name = "Territorial Domination",
		desc = "Implements territorial domination victory condition",
		author = "SethDGamre",
		date = "2025.02.08",
		license = "GNU GPL, v2",
		layer = -10,
		enabled = true,
		depends   = {'gl4'},
	}
end

-- TODO:
-- code cleanup
-- red text doesn't blink when spectating.
-- when an allyteam dies, perspective changes to one of the remaining allyteams but the score doesn't refresh until a different one is selected and then the original auto-chosen allyteam is re-selected
-- when a spectator zooms in, the border needs to completely disappear. this maybe should be configurable in settings.
-- check if defeatTime is interacting with freezeTime correctly
-- when globbal los is enabled, it appears that with high player counts enemy territories don't show up without los

local modOptions = Spring.GetModOptions()
if modOptions.deathmode ~= "territorial_domination" then return false end

local SYNCED = gadgetHandler:IsSyncedCode()

if SYNCED then

	local territorialDominationConfig = {
		short = {
			gracePeriod = 6 * 60,
			maxTime = 18 * 60,
		},
		default = {
			gracePeriod = 6 * 60,
			maxTime = 24 * 60,
		},
		long = {
			gracePeriod = 6 * 60,
			maxTime = 36 * 60,
		},
	}
	
	local SECONDS_TO_MAX = territorialDominationConfig[modOptions.territorial_domination_config].maxTime
	local SECONDS_TO_START = territorialDominationConfig[modOptions.territorial_domination_config].gracePeriod

	--configs
	local DEBUGMODE = false

	--to slow the capture rate of tiny units and aircraft on empty and mostly empty squares
	local maxEmptyImpedencePower = 25
	local minEmptyImpedenceMultiplier = 0.80

	local FLYING_UNIT_POWER_MULTIPLIER = 0.01 -- units capture territory super slowly while flying, so terrein only accessable via air can be captured
	local CLOAKED_UNIT_POWER_MULTIPLIER = 0 -- units cannot capture while cloaked
	local STATIC_UNIT_POWER_MULTIPLIER = 3
	local MAX_PROGRESS = 1.0
	local PROGRESS_INCREMENT = 0.06
	local CONTIGUOUS_PROGRESS_INCREMENT = 0.03
	local DECAY_PROGRESS_INCREMENT = 0.015
	local STATIC_POWER_MULTIPLIER = 3
	local GRID_CHECK_INTERVAL = Game.gameSpeed
	local DECAY_DELAY_FRAMES = Game.gameSpeed * 10
	local GRID_SIZE = 1024
	local FINISHED_BUILDING = 1
	local STARTING_PROGRESS = 0
	local CORNER_MULTIPLIER = 1.4142135623730951 -- a constant representing the diagonal of a square
	local OWNERSHIP_THRESHOLD = MAX_PROGRESS / CORNER_MULTIPLIER -- full progress is when the circle drawn within the square reaches the corner, ownership is achieved when it touches the edge.
	local MAJORITY_THRESHOLD = 0.5 -- Moved from function to constants
	local FREEZE_DELAY_SECONDS = 60
	local MAX_THRESHOLD_DELAY = SECONDS_TO_START * 2/3
	local MIN_THRESHOLD_DELAY = 1
	local DEFEAT_DELAY_SECONDS = 60
	local RESET_DEFEAT_FRAME = 0

	local SCORE_RULES_KEY = "territorialDominationScore"
	local THRESHOLD_RULES_KEY = "territorialDominationDefeatThreshold"
	local MAX_THRESHOLD_RULES_KEY = "territorialDominationMaxThreshold"
	local FREEZE_DELAY_KEY = "territorialDominationFreezeDelay"

	local floor = math.floor
	local max = math.max
	local min = math.min
	local random = math.random
	local clamp = math.clamp
	local spGetGameFrame = Spring.GetGameFrame
	local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
	local spGetUnitHealth = Spring.GetUnitHealth
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitPosition = Spring.GetUnitPosition
	local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spGetGameSeconds = Spring.GetGameSeconds
	local spGetTeamInfo = Spring.GetTeamInfo
	local spGetTeamList = Spring.GetTeamList
	local spGetTeamLuaAI = Spring.GetTeamLuaAI
	local spGetGaiaTeamID = Spring.GetGaiaTeamID
	local spDestroyUnit = Spring.DestroyUnit
	local spSpawnCEG = Spring.SpawnCEG
	local spPlaySoundFile = Spring.PlaySoundFile
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ
	local spGetPositionLosState = Spring.GetPositionLosState
	local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
	local SendToUnsynced = SendToUnsynced

	local gaiaTeamID = spGetGaiaTeamID()
	local gaiaAllyTeamID = select(6, spGetTeamInfo(gaiaTeamID))
	local teams = spGetTeamList()
	local allyCount = 0
	local allyHordesCount = 0
	local allyTeamsCount = 0
	local defeatThreshold = 0
	local numberOfSquaresX = 0
	local numberOfSquaresZ = 0
	local gameFrame = 0
	local sentGridStructure = false
	local thresholdSecondsDelay = 0
	local thresholdDelayTimestamp = 0
	local wantedDefeatThreshold = 0
	local freezeThresholdTimer = 0
	local currentSecond = 0

	local allyTeamsWatch = {}
	local hordeModeTeams = {}
	local hordeModeAllies = {}
	local unitWatchDefs = {}
	local captureGrid = {}
	local livingCommanders = {}
	local killQueue = {}
	local commandersDefs = {}
	local allyTallies = {}
	local randomizedGridIDs = {}
	local flyingUnits = {}
	local allyDefeatTime = {}

	for _, teamID in ipairs(teams) do
		local luaAI = spGetTeamLuaAI(teamID)
		if luaAI and luaAI ~= "" then
			if string.sub(luaAI, 1, 12) == 'ScavengersAI' then
				hordeModeTeams[teamID] = true
			elseif string.sub(luaAI, 1, 12) == 'RaptorsAI' then
				hordeModeTeams[teamID] = true
			end
		end

		Spring.SetTeamRulesParam(teamID, "defeatTime", RESET_DEFEAT_FRAME)
	end

	for defID, def in pairs(UnitDefs) do
		local defData

		if def.power then
			defData = {power = def.power}
			if def.speed == 0 then
				defData.power = defData.power * STATIC_POWER_MULTIPLIER
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

	local function getTargetThreshold()
		local seconds = spGetGameSeconds()
		local minFactor = 0.2
		local maxFactor = 1
		local thresholdExponentialFactor = min(minFactor + ((seconds - SECONDS_TO_START) / SECONDS_TO_MAX), maxFactor)
		local targetThreshold = #captureGrid * thresholdExponentialFactor
		return targetThreshold
	end

	local function setThresholdIncreaseRate()
		local seconds = spGetGameSeconds()
		if allyCount == 1 then
			thresholdSecondsDelay = 0
		else
			local startTime = max(Spring.GetGameSeconds(), SECONDS_TO_START)
			wantedDefeatThreshold = floor(min(getTargetThreshold() / allyCount, #captureGrid / 2)) -- because two teams must fight for half at most
			
			-- Fix the division by zero and ensure parameters are in correct order:
			-- min, value, max instead of min, max, value
			if wantedDefeatThreshold > 0 then
				local delayValue = (SECONDS_TO_MAX - startTime) / wantedDefeatThreshold
				thresholdSecondsDelay = clamp(delayValue, MIN_THRESHOLD_DELAY, MAX_THRESHOLD_DELAY)
			else
				thresholdSecondsDelay = MAX_THRESHOLD_DELAY
			end
		end
		thresholdDelayTimestamp = min(seconds + thresholdSecondsDelay, thresholdDelayTimestamp)
	end

	local function updateCurrentDefeatThreshold()
		local seconds = spGetGameSeconds()
		local totalDelay = max(SECONDS_TO_START, freezeThresholdTimer, thresholdDelayTimestamp)

		if totalDelay < seconds and thresholdSecondsDelay ~= 0 and allyCount > 1 or seconds > SECONDS_TO_MAX then
			defeatThreshold = min(defeatThreshold + 1, wantedDefeatThreshold)
			thresholdDelayTimestamp = seconds + thresholdSecondsDelay
		end
	end

	local function updateLivingTeamsData()
		local allyTeamCounts = {}
		local allyTeamIDs = {}
		local allyTeamsCount = 0
		local allyHordesCount = 0
		local teams = spGetTeamList()

		for allyID in pairs(allyTeamsWatch) do
			allyTeamsWatch[allyID] = nil
		end

		for _, teamID in ipairs(teams) do
			local _, _, isDead = spGetTeamInfo(teamID)
			if not isDead then
				local allyID = select(6, spGetTeamInfo(teamID))

				if allyID and allyID ~= gaiaAllyTeamID then
					if not hordeModeTeams[teamID] then
						allyTeamsWatch[allyID] = allyTeamsWatch[allyID] or {}
						allyTeamsWatch[allyID][teamID] = true
						allyTeamCounts[allyID] = (allyTeamCounts[allyID] or 0) + 1
						table.insert(allyTeamIDs, allyID)
					else
						hordeModeAllies[allyID] = true
						allyHordesCount = allyHordesCount + 1
					end
				end
			end
		end

		for allyID, count in pairs(allyTeamCounts) do
			allyTeamsCount = allyTeamsCount + 1
		end
		
		local oldAllyCount = allyCount
		allyCount = allyTeamsCount + allyHordesCount

		if allyCount ~= oldAllyCount then
			local oldFreezeTimer = freezeThresholdTimer
			freezeThresholdTimer = max(spGetGameSeconds() + FREEZE_DELAY_SECONDS, freezeThresholdTimer)
			Spring.SetGameRulesParam(FREEZE_DELAY_KEY, freezeThresholdTimer)
			
			-- Extend any existing defeat timers when freeze occurs to prevent instant defeats
			if freezeThresholdTimer > oldFreezeTimer then
				local freezeExtension = freezeThresholdTimer - spGetGameSeconds()
				for allyID, defeatTime in pairs(allyDefeatTime) do
					if defeatTime and defeatTime > 0 then
						allyDefeatTime[allyID] = defeatTime + freezeExtension
						-- Update the team rules param for UI display
						for teamID in pairs(allyTeamsWatch[allyID] or {}) do
							Spring.SetTeamRulesParam(teamID, "defeatTime", allyDefeatTime[allyID])
						end
					end
				end
			end
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

	--custom functions
	local function generateCaptureGrid()
		local gridData = {}
		local totalSquares = numberOfSquaresX * numberOfSquaresZ
		
		-- Pre-allocate table size for better performance
		for i = 1, totalSquares do
			gridData[i] = {}
		end
		
		for x = 0, numberOfSquaresX - 1 do
			for z = 0, numberOfSquaresZ - 1 do
				local originX = x * GRID_SIZE
				local originZ = z * GRID_SIZE
				local index = x * numberOfSquaresZ + z + 1
				local data = gridData[index]

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
				data.corners = {
					{x = data.mapOriginX, z = data.mapOriginZ},                           -- Bottom-left
					{x = data.mapOriginX + GRID_SIZE, z = data.mapOriginZ},               -- Bottom-right
					{x = data.mapOriginX, z = data.mapOriginZ + GRID_SIZE},               -- Top-left
					{x = data.mapOriginX + GRID_SIZE, z = data.mapOriginZ + GRID_SIZE}    -- Top-right
				}
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
		for unitID, commanderAllyID in pairs(livingCommanders) do
			if commanderAllyID == allyID then
				queueCommanderTeleportRetreat(unitID)
			end
		end
		for _, teamID in ipairs(teams) do
			Spring.SetTeamRulesParam(teamID, "defeatTime", RESET_DEFEAT_FRAME)
		end
	end

	local function setAndCheckAllyDefeatTime(allyID)
		if not allyDefeatTime[allyID] then
			allyDefeatTime[allyID] = spGetGameSeconds() + DEFEAT_DELAY_SECONDS
			for teamID in pairs(allyTeamsWatch[allyID]) do
				Spring.SetTeamRulesParam( teamID, "defeatTime", allyDefeatTime[allyID])
			end
		end
		local currentSecond = spGetGameSeconds()
		if allyDefeatTime[allyID] < currentSecond then
			return true
		end
		return false
	end

	local function getAllyPowersInSquare(gridID)
		local data = captureGrid[gridID]
		local units = spGetUnitsInRectangle(data.mapOriginX, data.mapOriginZ, data.mapOriginX + GRID_SIZE, data.mapOriginZ + GRID_SIZE)
		
		local allyPowers = {}
		local hasUnits = false
		data.contested = false
		
		for i = 1, #units do
			local unitID = units[i]
			local buildProgress = select(5, spGetUnitHealth(unitID))
			
			if buildProgress == FINISHED_BUILDING then
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
					if hordeModeTeams[allyTeam] then
						allyPowers[gaiaAllyTeamID] = (allyPowers[gaiaAllyTeamID] or 0) + power -- horde mode units cannot own territory, they give it back to gaia
					else
						allyPowers[allyTeam] = (allyPowers[allyTeam] or 0) + power
					end
				end
			end
		end

		for allyID, power in pairs(allyPowers) do
			if allyPowers[allyID] > 0 then
				power = power + random() -- randomize power to prevent ties where the last tied victor always wins
				if allyID ~= data.allyOwnerID then
					data.contested = true
				end
			else
				allyPowers[allyID] = nil -- not allowed to capture without power.
			end
		end
		
		if hasUnits then
			return allyPowers
		end
		return nil
	end

	local sortedTeams = {}
	
	local function getCaptureProgress(gridID, allyPowers)
		if not allyPowers then return nil, 0 end
		local data = captureGrid[gridID]
		local currentOwnerID = data.allyOwnerID

		for i = 1, #sortedTeams do
			sortedTeams[i] = nil
		end
		
		local teamCount = 0
		for team, power in pairs(allyPowers) do
			teamCount = teamCount + 1
			sortedTeams[teamCount] = {team = team, power = power}
		end
		
		if teamCount > 1 then
			table.sort(sortedTeams, function(a, b) return a.power > b.power end)
		end
		
		local winningAllyID = teamCount > 0 and sortedTeams[1].team or nil
		local secondPlaceAllyID = teamCount > 1 and sortedTeams[2].team or nil

		if not winningAllyID then
			return nil, 0
		end
		
		local topPower = allyPowers[winningAllyID]
		local comparedPower = 0
		
		if winningAllyID ~= currentOwnerID and allyPowers[currentOwnerID] then
			comparedPower = max(allyPowers[currentOwnerID], maxEmptyImpedencePower)
		elseif secondPlaceAllyID then
			comparedPower = max(allyPowers[secondPlaceAllyID], maxEmptyImpedencePower)
		else
			comparedPower = min(topPower * minEmptyImpedenceMultiplier, maxEmptyImpedencePower)
		end
		
		local powerRatio = 1
		if topPower ~= 0 and comparedPower ~= 0 then
			powerRatio = math.abs(comparedPower / topPower - 1)
		end
		
		local progressChange = 0
		if currentOwnerID == winningAllyID then
			progressChange = PROGRESS_INCREMENT * powerRatio
		else
			progressChange = -(powerRatio * PROGRESS_INCREMENT)
		end
		
		return winningAllyID, progressChange
	end

	local function addProgress(gridID, progressChange, winningAllyID, delayDecay)
		local data = captureGrid[gridID]
		local newProgress

		if hordeModeTeams[winningAllyID] then
			winningAllyID = gaiaAllyTeamID -- horde mode units cannot own territory, they give it back to gaia
			newProgress = data.progress - abs(progressChange)
		else
			newProgress = data.progress + progressChange
		end
		
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

	local function getClearedAllyTallies()
		local allies = {}
		for allyID in pairs(allyTeamsWatch) do
			allies[allyID] = 0
		end
		return allies
	end

	local function getSquareContiguityProgress(gridID)
		local currentSquareData = captureGrid[gridID]
		local neighborAllyTeamCounts = {}
		local dominantAllyTeamCount = 0
		local totalNeighborCount = 0
		local dominantAllyTeamID
		currentSquareData.contiguous = false
		
		local currentGridX = currentSquareData.gridX
		local currentGridZ = currentSquareData.gridZ

		-- Check all 8 surrounding neighbors
		for deltaX = -1, 1 do
			for deltaZ = -1, 1 do
				-- Skip the center cell (the current square itself)
				if not (deltaX == 0 and deltaZ == 0) then
					local neighborGridX = currentGridX + deltaX
					local neighborGridZ = currentGridZ + deltaZ
					
					-- Check if neighbor is within map boundaries
					if neighborGridX >= 0 and neighborGridX < numberOfSquaresX and 
					   neighborGridZ >= 0 and neighborGridZ < numberOfSquaresZ then
						local neighborGridID = neighborGridX * numberOfSquaresZ + neighborGridZ + 1
						local neighborSquareData = captureGrid[neighborGridID]
						
						-- Only count neighbors owned by active ally teams (not Gaia)
						if neighborSquareData then
							local neighborOwnerID
							if neighborSquareData.progress > OWNERSHIP_THRESHOLD then
								neighborOwnerID = neighborSquareData.allyOwnerID
							else
								neighborOwnerID = gaiaAllyTeamID
							end
							neighborAllyTeamCounts[neighborOwnerID] = (neighborAllyTeamCounts[neighborOwnerID] or 0) + 1
							totalNeighborCount = totalNeighborCount + 1
						end
					end
				end
			end
		end

		-- Find the ally team that owns the most neighboring squares
		for allyTeamID, neighborCount in pairs(neighborAllyTeamCounts) do
			if neighborCount > dominantAllyTeamCount and allyTeamsWatch[allyTeamID] then
				dominantAllyTeamID = allyTeamID
				dominantAllyTeamCount = neighborCount
			end
		end

		-- Only apply contiguity effect if the dominant ally team owns more than half of all neighbors
		if dominantAllyTeamID and dominantAllyTeamCount > totalNeighborCount * MAJORITY_THRESHOLD then
			currentSquareData.contiguous = true
			-- If dominant ally is different from current owner, return negative progress (capture)
			if dominantAllyTeamID ~= currentSquareData.allyOwnerID then
				return dominantAllyTeamID, -CONTIGUOUS_PROGRESS_INCREMENT
			else
				-- If dominant ally is same as current owner, return positive progress (reinforce)
				return dominantAllyTeamID, CONTIGUOUS_PROGRESS_INCREMENT
			end
		end
		
		return nil, nil
	end

	local function getRandomizedGridIDs()
		-- Clear the existing table
		for i = 1, #randomizedGridIDs do
			randomizedGridIDs[i] = nil
		end
		
		-- Create a list of all grid IDs
		local index = 0
		for gridID in pairs(captureGrid) do
			index = index + 1
			randomizedGridIDs[index] = gridID
		end
		
		-- Shuffle the grid IDs using Fisher-Yates algorithm
		for i = index, 2, -1 do
			local j = random(i)
			randomizedGridIDs[i], randomizedGridIDs[j] = randomizedGridIDs[j], randomizedGridIDs[i]
		end
		
		return randomizedGridIDs
	end

	-- Helper function to create a visibility bitmask for a grid square
	local function createVisibilityBitmask(squareData)
		local visibilityBitmask = 0
		
		for allyTeamID in pairs(allyTeamsWatch) do
			local isVisible = false
			
			if allyTeamID == squareData.allyOwnerID then
				isVisible = true
			else --check middle first, more likely to be visible
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
				visibilityBitmask = visibilityBitmask + (2 ^ allyTeamID)
			end
		end
		
		return visibilityBitmask
	end

	
	local function updateTeamRulesScores()
		Spring.SetGameRulesParam(THRESHOLD_RULES_KEY, defeatThreshold)

		local maxThreshold = floor(min(#captureGrid/allyCount, #captureGrid / 2)) -- because 1v1 is the smallest number of competitors
		Spring.SetGameRulesParam(MAX_THRESHOLD_RULES_KEY, maxThreshold)
		
		for allyID, tally in pairs(allyTallies) do
			for teamID, _ in pairs(allyTeamsWatch[allyID] or {}) do
				Spring.SetTeamRulesParam(teamID, SCORE_RULES_KEY, tally)
			end
		end
	end

	-- Remove old function since we're now using rules params
	local function updateUnsyncedScore(allyID, score)
		SendToUnsynced("UpdateAllyScore", allyID, score, defeatThreshold)
	end

	local function initializeUnsyncedGrid()
		-- All ally teams can see all squares initially
		local allVisibleBitmask = 0
		for allyTeamID in pairs(allyTeamsWatch) do
			allVisibleBitmask = allVisibleBitmask + (2 ^ allyTeamID)
		end
		for gridID, squareData in pairs(captureGrid) do
			-- For initialization, set all squares as visible to everyone
			SendToUnsynced("InitializeGridSquare", 
				gridID,
				gaiaAllyTeamID,
				squareData.progress,
				squareData.gridMidpointX,
				squareData.gridMidpointZ,
				allVisibleBitmask
			)
		end
		
		sentGridStructure = true
	end

	local function updateUnsyncedSquare(gridID)
		local squareData = captureGrid[gridID]
		local visibilityBitmask = createVisibilityBitmask(squareData)
		
		SendToUnsynced("UpdateGridSquare", gridID, squareData.allyOwnerID, squareData.progress, visibilityBitmask)
	end

	local function decayProgress(gridID)
		local data = captureGrid[gridID]
		if data.progress > OWNERSHIP_THRESHOLD then
			addProgress(gridID, DECAY_PROGRESS_INCREMENT, data.allyOwnerID, false)
		else
			addProgress(gridID, -DECAY_PROGRESS_INCREMENT, gaiaAllyTeamID, false)
		end
	end

	local function setAllyTeamRanks(allyTallies)
		-- Create array of ally teams with their tallies and defeat times
		local allyScores = {}
		for allyID, tally in pairs(allyTallies) do
			local defeatTimeRemaining = 0
			-- Calculate remaining defeat time (higher is better)
			if allyDefeatTime[allyID] and allyDefeatTime[allyID] > 0 then
				defeatTimeRemaining = math.max(0, allyDefeatTime[allyID] - spGetGameSeconds())
			else
				-- No defeat timer means safe (highest ranking for timer)
				defeatTimeRemaining = math.huge
			end
			table.insert(allyScores, {allyID = allyID, tally = tally, defeatTimeRemaining = defeatTimeRemaining})
		end
		
		-- Sort by tallies first (primary), then by defeat time remaining (secondary)
		-- Higher tally ranks better, higher defeat time remaining ranks better when tallies are equal
		table.sort(allyScores, function(a, b)
			if a.tally == b.tally then
				return a.defeatTimeRemaining > b.defeatTimeRemaining
			end
			return a.tally > b.tally
		end)
		
		-- Assign ranks with ties sharing the same rank
		local currentRank = 1
		local previousScore = -1
		local previousDefeatTime = -1
		
		for i, allyData in ipairs(allyScores) do
			-- If both score and defeat time are the same as previous, keep the same rank
			-- Otherwise, set rank to current position
			if i > 1 and allyData.tally == previousScore and allyData.defeatTimeRemaining == previousDefeatTime then
				-- keep the same rank as previous entry
			else
				currentRank = i
			end
			
			previousScore = allyData.tally
			previousDefeatTime = allyData.defeatTimeRemaining
			
			-- Set rank for each team in this ally team
			for teamID in pairs(allyTeamsWatch[allyData.allyID] or {}) do
				Spring.SetTeamRulesParam(teamID, "territorialDominationRank", currentRank)
			end
		end
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

	function gadget:GameFrame(frame)
		gameFrame = frame
		local frameModulo = frame % GRID_CHECK_INTERVAL

		if frameModulo == 0 then
			currentSecond = spGetGameSeconds()
			updateLivingTeamsData()
			setThresholdIncreaseRate()
			updateCurrentDefeatThreshold()
			allyTallies = getClearedAllyTallies()

			for gridID, data in pairs(captureGrid) do
				local allyPowers = getAllyPowersInSquare(gridID)
				local winningAllyID, progressChange = getCaptureProgress(gridID, allyPowers)
				if winningAllyID then
					addProgress(gridID, progressChange, winningAllyID, true)
				end
				if allyTeamsWatch[data.allyOwnerID] and data.progress > OWNERSHIP_THRESHOLD then
					allyTallies[data.allyOwnerID] = allyTallies[data.allyOwnerID] + 1
				end
			end
		elseif frameModulo == 1 then
			local randomizedIDs = getRandomizedGridIDs()
			for i = 1, #randomizedIDs do --shuffled to prevent contiguous ties from always being awarded to the same ally
				if not captureGrid[randomizedIDs[i]].contested then
					local gridID = randomizedIDs[i]
					local contiguousAllyID, progressChange = getSquareContiguityProgress(gridID)
					if contiguousAllyID then
						addProgress(gridID, progressChange, contiguousAllyID, true)
					end
				end
			end

			for gridID, data in pairs(captureGrid) do
				if not data.contested and not data.contiguous and data.decayDelay < frame then
					decayProgress(gridID)
				end
				updateUnsyncedSquare(gridID)
			end
		elseif frameModulo == 2 then
			updateTeamRulesScores()
			
			-- Set ally team ranks based on territory counts
			setAllyTeamRanks(allyTallies)
			
			local sortedAllies = {}
			local totalCount = 0
			for allyID, tally in pairs(allyTallies) do
				table.insert(sortedAllies, {allyID = allyID, tally = tally})
				updateUnsyncedScore(allyID, tally)
				totalCount = totalCount + 1
			end
			
			table.sort(sortedAllies, function(a, b) return a.tally < b.tally end)

			if allyCount > 1 and freezeThresholdTimer < currentSecond and not DEBUGMODE then
				local highestTally = sortedAllies[#sortedAllies].tally
				for i = 1, #sortedAllies do
					local allyData = sortedAllies[i]
					
					if allyData.tally < defeatThreshold and (allyData.tally < highestTally or allyHordesCount > 0) then
						local timerExpired = setAndCheckAllyDefeatTime(allyData.allyID)
						if timerExpired then
							triggerAllyDefeat(allyData.allyID)
							setAllyGridToGaia(allyData.allyID)
							allyDefeatTime[allyData.allyID] = nil
						end
					else
						allyDefeatTime[allyData.allyID] = nil
						for teamID in pairs(allyTeamsWatch[allyData.allyID]) do
							Spring.SetTeamRulesParam( teamID, "defeatTime", RESET_DEFEAT_FRAME)
						end
					end
				end
			else
				-- Clear all defeat timers when threshold is frozen
				if freezeThresholdTimer >= currentSecond then
					for allyID in pairs(allyDefeatTime) do
						allyDefeatTime[allyID] = nil
						for teamID in pairs(allyTeamsWatch[allyID] or {}) do
							Spring.SetTeamRulesParam(teamID, "defeatTime", RESET_DEFEAT_FRAME)
						end
					end
				end
			end	
			if not sentGridStructure then
				initializeUnsyncedGrid()
				sentGridStructure = true
			end
		end

		local currentKillQueue = killQueue[frame]
		if currentKillQueue then
			for unitID in pairs(currentKillQueue) do
				spDestroyUnit(unitID, false, true)
			end
			killQueue[frame] = nil
		end
	end

	function gadget:Initialize()
		numberOfSquaresX = math.ceil(mapSizeX / GRID_SIZE)
		numberOfSquaresZ = math.ceil(mapSizeZ / GRID_SIZE)
		SendToUnsynced("InitializeConfigs", GRID_SIZE, GRID_CHECK_INTERVAL)
		freezeThresholdTimer = SECONDS_TO_START
		Spring.SetGameRulesParam(FREEZE_DELAY_KEY, SECONDS_TO_START)
		captureGrid = generateCaptureGrid()
		updateLivingTeamsData()

		local units = Spring.GetAllUnits()
		for i = 1, #units do
			local unitID = units[i]
			gadget:UnitCreated(unitID, spGetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
		end

		setThresholdIncreaseRate()
		teams = Spring.GetTeamList()
		for _, teamID in pairs(teams) do
			Spring.SetTeamRulesParam(teamID, "defeatTime", RESET_DEFEAT_FRAME)
		end

		for i, teamID in pairs(teams) do
			Spring.SetTeamRulesParam(teamID, "territorialDominationRank", 1)
		end
	end

else

local luaShaderDir = "LuaUI/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local getMiniMapFlipped = VFS.Include("luaui/Include/minimap_utils.lua").getMiniMapFlipped

local UNSYNCED_DEBUG_MODE = false

local SQUARE_SIZE = 1024
local SQUARE_ALPHA = 0.2
local SQUARE_HEIGHT = 10
local UPDATE_FRAME_RATE_INTERVAL = Game.gameSpeed
local MAX_CAPTURE_CHANGE = 0.12
local CAPTURE_SOUND_VOLUME = 1.0
local OWNERSHIP_THRESHOLD = 1 / 1.4142135623730951 -- circle touching edge of the square
local CAPTURE_SOUND_RESET_THRESHOLD = OWNERSHIP_THRESHOLD * 0.5
local NOTIFY_DELAY = math.floor(Game.gameSpeed * 1)

local captureGrid = {}
local notifyFrames = {}

local myAllyID = Spring.GetMyAllyTeamID()
local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID()))
local teams = Spring.GetTeamList()

local blankColor = {0.5, 0.5, 0.5, 0.0}
local enemyColor = {1, 0, 0, SQUARE_ALPHA}
local alliedColor = {0, 1, 0, SQUARE_ALPHA}

local amSpectating = Spring.GetSpectatingState()
local spIsGUIHidden = Spring.IsGUIHidden

local allyColors = {}
for _, teamID in ipairs(teams) do
    local allyID = select(6, Spring.GetTeamInfo(teamID))
    if allyID and not allyColors[allyID] then
        if allyID ~= gaiaAllyTeamID then
            local r, g, b, a = Spring.GetTeamColor(teamID)
            allyColors[allyID] = {r, g, b, SQUARE_ALPHA}
        else
            allyColors[allyID] = blankColor
        end
    end
end

local planeLayout = {
	{id = 1, name = 'posscale', size = 4}, -- a vec4 for pos + scale
	{id = 2, name = 'ownercolor', size = 4}, --  vec4 the color of this new
	{id = 3, name = 'capturestate', size = 4}, -- vec4 speed, progress, startframe, showSquareTimestamp
}
local glDepthTest = gl.DepthTest
local glTexture = gl.Texture
local spPlaySoundFile = Spring.PlaySoundFile

local squareVBO = nil
local squareVAO = nil
local squareShader = nil
local instanceVBO = nil
local lastMoveFrame = 0
local currentFrame = 0

local vertexShaderSource = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

layout (location = 0) in vec4 vertexPosition;
layout (location = 1) in vec4 instancePositionScale; 
layout (location = 2) in vec4 instanceColor; 
layout (location = 3) in vec4 captureParameters; // captureSpeed, progressValue, startFrame, showSquareTimestamp

uniform sampler2D heightmapTexture;
uniform int isMinimapRendering;
uniform int flipMinimap;
uniform float mapSizeXAxis;
uniform float mapSizeZAxis;
uniform float minCameraDrawHeight;
uniform float maxCameraDrawHeight;
uniform float updateFrameRateInterval;

out VertexOutput {
	vec4 color;
	float progressValue;
	float progressSpeed;
	float startFrame;
	vec2 textureCoordinate;
	float cameraDistance;
	float isInMinimap;
	float currentGameFrame;
	float captureTimestamp;
};

void main() {
	color = instanceColor;
	progressSpeed = captureParameters.x;
	progressValue = captureParameters.y;
	startFrame = captureParameters.z;
	captureTimestamp = captureParameters.w;
	currentGameFrame = timeInfo.x;
	
	textureCoordinate = vertexPosition.xy * 0.5 + 0.5;
	
	vec3 cameraPosition = cameraViewInv[3].xyz;
	cameraDistance = cameraPosition.y;
	
	if (isMinimapRendering == 1) {
		vec2 minimapPosition = (instancePositionScale.xz / vec2(mapSizeXAxis, mapSizeZAxis));
		vec2 squareSize = vec2(instancePositionScale.w / mapSizeXAxis, instancePositionScale.w / mapSizeZAxis) * 0.5;
		
		vec2 vertexPositionMinimap = vertexPosition.xy * squareSize + minimapPosition;
		
		if (flipMinimap == 0) {
			vertexPositionMinimap.y = 1.0 - vertexPositionMinimap.y;
		}
		
		gl_Position = vec4(vertexPositionMinimap.x * 2.0 - 1.0, vertexPositionMinimap.y * 2.0 - 1.0, 0.0, 1.0);
		isInMinimap = 1.0;
	} else {
		vec4 worldPosition = vec4(vertexPosition.x * instancePositionScale.w * 0.5, 0.0, vertexPosition.y * instancePositionScale.w * 0.5, 1.0);
		worldPosition.xz += instancePositionScale.xz;
		
		vec2 heightmapUV = heightmapUVatWorldPos(worldPosition.xz);
		float terrainHeight = textureLod(heightmapTexture, heightmapUV, 0.0).x;
		
		worldPosition.y = terrainHeight + instancePositionScale.y;
		
		gl_Position = cameraViewProj * worldPosition;
		isInMinimap = 0.0;
	}
}
]]

local fragmentShaderSource = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

uniform float minCameraDrawHeight;
uniform float maxCameraDrawHeight;
uniform float updateFrameRateInterval;

in VertexOutput {
	vec4 color;
	float progressValue;
	float progressSpeed;
	float startFrame;
	vec2 textureCoordinate;
	float cameraDistance;
	float isInMinimap;
	float currentGameFrame;
	float captureTimestamp;
};

out vec4 fragmentColor;

void main() {
	vec2 centerPoint = vec2(0.5);
	vec2 distanceToEdges = min(textureCoordinate, 1.0 - textureCoordinate);
	float distanceToEdge = min(distanceToEdges.x, distanceToEdges.y);
	
	// Border handling - only for main view, not for minimap
	float borderOpacity = 0.0;
	
	// Only show borders in the main view, not in the minimap
	if (isInMinimap < 0.5) {
		// Make border sharper by reducing the fade distance
		float borderFadeDistance = 0.005; // Reduced from 8.0/1024.0 (~0.008) for sharper borders
		borderOpacity = smoothstep(borderFadeDistance, 0.0, distanceToEdge); // Inverted smoothstep for sharper edge
	}
	
	float distanceToCorner = 1.4142135623730951; // sqrt(2)
	float distanceToCenter = length(textureCoordinate - centerPoint) * 2.0;
	float animatedProgress = (progressValue + progressSpeed * (currentGameFrame - startFrame)) * distanceToCorner;
	float circleSoftness = 0.05;
	
	float circleFillAmount = 1.0 - clamp((distanceToCenter - animatedProgress) / circleSoftness, 0.0, 1.0);
	circleFillAmount = step(0.0, circleFillAmount) * circleFillAmount;
	
	// Create a local copy of the color for modification
	vec4 modifiedColor = color;
	
	// Apply fill alpha to the circle fill - make it depend on camera height
	float fillFadeAlpha = 1.0;
	if (isInMinimap < 0.5) {
		float fadeRange = maxCameraDrawHeight - minCameraDrawHeight;
		fillFadeAlpha = clamp((cameraDistance - minCameraDrawHeight) / fadeRange, 0.0, 1.0);
		
		// Apply pulsing effect for recently captured territories
		if (captureTimestamp > 0.0) {
			float timeSinceCapture = currentGameFrame - captureTimestamp;
			float pulseFrequency = 0.05;
			float pulseDuration = 120.0; // frames the pulse effect lasts
			
			if (timeSinceCapture < pulseDuration) {
				float pulseIntensity = (1.0 - timeSinceCapture / pulseDuration) * 0.8;
				float pulse = sin(timeSinceCapture * pulseFrequency) * 0.5 + 0.5;
				fillFadeAlpha = max(fillFadeAlpha, pulse * pulseIntensity);
				modifiedColor.rgb = mix(modifiedColor.rgb, vec3(1.0), pulse * pulseIntensity * 0.3);
			}
		}
	}
	
	vec4 fillColor = vec4(modifiedColor.rgb, modifiedColor.a * circleFillAmount * fillFadeAlpha);
	
	// Border color only for main view - make it more distinct for sharper lines
	vec4 borderColor = vec4(1.0, 1.0, 1.0, 0.8); // Increased alpha from 0.66 to 0.8 for more visibility
	
	// Border has its own independent alpha that doesn't fade with height
	float borderAlpha = borderOpacity;
	
	// Dynamic edge visibility based on camera height
	if (isInMinimap < 0.5) {
		// *** IMPORTANT: This is where we control edge visibility ***
		// At maxCameraDrawHeight: the full square edge is visible
		// At minCameraDrawHeight: only corners visible, rest is hidden
		
		// Calculate where we are between min and max camera height
		float heightRatio = clamp((cameraDistance - minCameraDrawHeight) / (maxCameraDrawHeight - minCameraDrawHeight), 0.0, 1.0);
		
		// As camera gets lower (heightRatio gets smaller), 
		// innerFadeRadius gets bigger (hiding more of the border)
		// 0.0 = hide nothing, 1.4 = hide everything except corners
		float innerFadeRadius = mix(1.41, 0.0, heightRatio);
		
		// Calculate border width based on camera height
		float baseWidth = 0.5;
		float maxWidthMultiplier = 1.0;
		float dynamicBorderWidth = baseWidth * (1.0 + (maxWidthMultiplier - 1.0) * heightRatio);
		
		// Use the dynamic border width instead of fixed width
		if (distanceToCenter < innerFadeRadius - dynamicBorderWidth) {
			// Hide interior borders completely
			borderAlpha = 0.0;
		} else if (distanceToCenter < innerFadeRadius) {
			// Create a sharper transition at the edge with dynamic width
			borderAlpha *= smoothstep(innerFadeRadius - dynamicBorderWidth, innerFadeRadius, distanceToCenter);
		}
		
		// Make border thickness increase with camera height
		float minBorderThickness = 0.005;
		float maxBorderThickness = 0.009;
		float borderThickness = mix(minBorderThickness, maxBorderThickness, heightRatio);
		
		// Apply border thickness to edge detection
		float edgeDistance = distanceToEdge / borderThickness;
		if (edgeDistance < 1.0) {
			// Increase border alpha where we're close to square edges
			// Use smoothstep for a gradual falloff
			borderAlpha = max(borderAlpha, (1.0 - smoothstep(0.0, 1.0, edgeDistance)) * heightRatio);
		}
		
		// Also scale border alpha with height for better visibility at high camera positions
		borderAlpha *= mix(0.66, 0.85, heightRatio);
	}
	
	// Only mix in border where we have border alpha with hard edge
	vec4 finalColor = fillColor;
	if (borderAlpha > 0.01) { // Reduced threshold from 0.1 to 0.05 to show more of the border
		finalColor = mix(fillColor, borderColor, borderAlpha);
	}
	
	fragmentColor = finalColor;
}
]]

local function GetMaxCameraHeight()
    local mapSizeX = Game.mapSizeX
    local mapSizeZ = Game.mapSizeZ
	local fallbackMaxFactor = 1.4 --to handle all camera modes
    local maxFactor = Spring.GetConfigFloat("OverheadMaxHeightFactor", fallbackMaxFactor)
	local absoluteMinimum = 500
	local minimumFactor = 0.8
	local reductionFactor = 0.8
	local minimumMaxHeight = 3000
	local maximumMaxHeight = 5000
    
    local maxDimension = math.max(mapSizeX, mapSizeZ)
    local maxHeight = UNSYNCED_DEBUG_MODE and 1 or math.min(math.max(maxDimension * maxFactor * reductionFactor, minimumMaxHeight), maximumMaxHeight)
	local minHeight = UNSYNCED_DEBUG_MODE and 0 or math.max(absoluteMinimum, maxHeight * minimumFactor * reductionFactor)

    return minHeight, maxHeight
end

local function createShader()
	local engineUniformBufferDefinitions = LuaShader.GetEngineUniformBufferDefs()
	local processedVertexShader = vertexShaderSource:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefinitions)
	local processedFragmentShader = fragmentShaderSource
	local minCameraHeight, maxCameraHeight = GetMaxCameraHeight()
	
	squareShader = LuaShader({
		vertex = processedVertexShader,
		fragment = processedFragmentShader,
		uniformInt = {
			heightmapTexture = 0,
			isMinimapRendering = 0,
			flipMinimap = 0,
		},
		uniformFloat = {
			mapSizeXAxis = Game.mapSizeX,
			mapSizeZAxis = Game.mapSizeZ,
			minCameraDrawHeight = minCameraHeight,
			maxCameraDrawHeight = maxCameraHeight,
			updateFrameInterval = UPDATE_FRAME_RATE_INTERVAL,
		},
	}, "territorySquareShader")
	
	local shaderCompiled = squareShader:Initialize()
	if not shaderCompiled then
		Spring.Echo("Failed to compile territory square shader")
		return false
	end
	return true
end

local function makeSquareVBO(xsize, ysize, xresolution, yresolution)
	if not xsize then xsize = 1 end
	if not ysize then ysize = xsize end
	if not xresolution then xresolution = 1 end
	if not yresolution then yresolution = xresolution end
	
	xresolution = math.floor(xresolution)
	yresolution = math.floor(yresolution)
	
	local squareVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	if squareVBO == nil then return nil end
	
	local VBOLayout = {
		{id = 0, name = "position", size = 4},
	}
	
	local vertexData = {}
	local vertexCount = 0
	
	for x = 0, xresolution do
		for y = 0, yresolution do
			local xPos = xsize * ((x / xresolution) - 0.5) * 2
			local yPos = ysize * ((y / yresolution) - 0.5) * 2
			
			vertexData[#vertexData + 1] = xPos  -- x
			vertexData[#vertexData + 1] = yPos  -- y (used as z in the shader)
			vertexData[#vertexData + 1] = 0     -- z (unused)
			vertexData[#vertexData + 1] = 1     -- w
			
			vertexCount = vertexCount + 1
		end
	end
	
	local indexData = {}
	local colSize = yresolution + 1
	
	for x = 0, xresolution - 1 do
		for y = 0, yresolution - 1 do
			local baseIndex = x * colSize + y
			
			-- First triangle (top-left)
			indexData[#indexData + 1] = baseIndex
			indexData[#indexData + 1] = baseIndex + 1
			indexData[#indexData + 1] = baseIndex + colSize
			
			-- Second triangle (bottom-right)
			indexData[#indexData + 1] = baseIndex + 1
			indexData[#indexData + 1] = baseIndex + colSize + 1
			indexData[#indexData + 1] = baseIndex + colSize
		end
	end
	
	squareVBO:Define((xresolution + 1) * (yresolution + 1), VBOLayout)
	squareVBO:Upload(vertexData)
	
	local squareIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	if squareIndexVBO == nil then 
		squareVBO:Delete()
		return nil 
	end
	
	squareIndexVBO:Define(#indexData)
	squareIndexVBO:Upload(indexData)
	
	return squareVBO, (xresolution + 1) * (yresolution + 1), squareIndexVBO, #indexData
end

local function updateGridSquareInstanceVBO(gridID, posScale, color1, captureState)
	local instanceData = {
		posScale[1], posScale[2], posScale[3], posScale[4],  -- posscale: x, y, z, scale
		color1[1], color1[2], color1[3], color1[4],         -- color1: r, g, b, a
		captureState[1], captureState[2], captureState[3], captureState[4]  -- capturestate: speed, progress, startframe, showSquareTimestamp
	}
	pushElementInstance(instanceVBO, instanceData, gridID, true, false)
end

local function initGL4()
	local planeResolution = 32
	local squareVBO, numVertices, squareIndexVBO, numIndices = makeSquareVBO(1, 1, planeResolution, planeResolution)
	if not squareVBO then return false end
	
	instanceVBO = makeInstanceVBOTable(planeLayout, 12, "territory_square_shader")
	instanceVBO.vertexVBO = squareVBO
	instanceVBO.indexVBO = squareIndexVBO
	instanceVBO.numVertices = numIndices
	instanceVBO.primitiveType = GL.TRIANGLES
	
	squareVAO = makeVAOandAttach(squareVBO, instanceVBO.instanceVBO, squareIndexVBO)
	instanceVBO.VAO = squareVAO
	uploadAllElements(instanceVBO)
	return createShader()
end

function gadget:Initialize()
	if initGL4() == false then
		gadgetHandler:RemoveGadget()
		return
	end
    
    amSpectating = Spring.GetSpectatingState()
    myAllyID = Spring.GetMyAllyTeamID()
end

local wasSpectating = false
local previousAllyID = nil

local function getSquareVisibility(newAllyOwnerID, oldAllyOwnerID, visibilityBitmask)
    if amSpectating or newAllyOwnerID == myAllyID then
        return true, false
    end

    local allyTeamBit = 2 ^ myAllyID
    local isCurrentlyVisible = (visibilityBitmask / allyTeamBit) % 2 >= 1
    
    local shouldResetColor = oldAllyOwnerID == myAllyID and newAllyOwnerID ~= myAllyID
    
    return isCurrentlyVisible, shouldResetColor
end

local function notifyCapture(gridID)
	local gridData = captureGrid[gridID]
	return not amSpectating and gridData.allyOwnerID == myAllyID and not gridData.playedCapturedSound and gridData.newProgress > OWNERSHIP_THRESHOLD
end

local function doCaptureEffects(gridID)
	local gridData = captureGrid[gridID]
	notifyFrames[currentFrame + NOTIFY_DELAY] = gridID
	gridData.showSquareTimestamp = currentFrame
end

function gadget:RecvFromSynced(messageName, ...)
    if messageName == "InitializeGridSquare" then
        local gridID, allyOwnerID, progress, gridMidpointX, gridMidpointZ, visibilityBitmask = ...
        local isVisible = getSquareVisibility(allyOwnerID, allyOwnerID, visibilityBitmask)
        captureGrid[gridID] = {
            visibilityBitmask = visibilityBitmask,
            allyOwnerID = allyOwnerID,
            oldProgress = progress,
            newProgress = progress,
            captureChange = 0,
            gridMidpointX = gridMidpointX,
            gridMidpointZ = gridMidpointZ,
            isVisible = isVisible,
            currentColor = blankColor,
			showSquareTimestamp = 0
        }
        
    elseif messageName == "InitializeConfigs" then
        SQUARE_SIZE, UPDATE_FRAME_RATE_INTERVAL = ...
        
    elseif messageName == "UpdateGridSquare" then
        local gridID, allyOwnerID, progress, visibilityBitmask = ...
        local gridData = captureGrid[gridID]
        if gridData then
            local oldAllyOwnerID = gridData.allyOwnerID
            gridData.visibilityBitmask = visibilityBitmask
            gridData.allyOwnerID = allyOwnerID

			gridData.isVisible = getSquareVisibility(allyOwnerID, oldAllyOwnerID, visibilityBitmask)
			if not gridData.isVisible then
				gridData.newProgress = gridData.oldProgress
				gridData.captureChange = 0
			else
				gridData.oldProgress = gridData.newProgress
				gridData.captureChange = progress - gridData.oldProgress

				if math.abs(gridData.captureChange) > MAX_CAPTURE_CHANGE then -- check absolute value
					gridData.oldProgress = progress -- Snap progress if change is too large
					gridData.captureChange = 0 -- No smooth animation needed if snapping
				end
				gridData.newProgress = progress

				if notifyCapture(gridID) then
					gridData.playedCapturedSound = true
					doCaptureEffects(gridID)
				end
			end
			if gridData.newProgress < CAPTURE_SOUND_RESET_THRESHOLD then
				gridData.playedCapturedSound = false
			end
        end
    end
end

function gadget:GameFrame(frame)
	currentFrame = frame

	if notifyFrames[frame] then
		local gridID = notifyFrames[frame]
		local gridData = captureGrid[gridID]
		spPlaySoundFile("scavdroplootspawn", CAPTURE_SOUND_VOLUME, gridData.gridMidpointX, 0, gridData.gridMidpointZ, 0, 0, 0, "sfx")
		notifyFrames[frame] = nil
	end
    if frame % UPDATE_FRAME_RATE_INTERVAL == 0 and frame ~= lastMoveFrame then
        local currentSpectating = Spring.GetSpectatingState()
        local currentAllyID = Spring.GetMyAllyTeamID()

        local playerStatusChanged = false
        if currentSpectating ~= amSpectating or (previousAllyID and currentAllyID ~= previousAllyID) then
            playerStatusChanged = true
            amSpectating = currentSpectating
            myAllyID = currentAllyID
            
            for gridID, gridSquareData in pairs(captureGrid) do
                local resetColor = false
                gridSquareData.isVisible, resetColor = getSquareVisibility(gridSquareData.allyOwnerID, gridSquareData.allyOwnerID, gridSquareData.visibilityBitmask)
                if resetColor then
                    gridSquareData.currentColor = blankColor
                end
            end
        end
        wasSpectating = amSpectating
        previousAllyID = myAllyID
        
        for gridID, _ in pairs(captureGrid) do
            local gridData = captureGrid[gridID]
            
            if gridData.isVisible then
                if gridData.allyOwnerID == gaiaAllyTeamID then
                    gridData.currentColor = blankColor
                elseif amSpectating then
                    allyColors[gaiaAllyTeamID] = blankColor
                    gridData.currentColor = allyColors[gridData.allyOwnerID] or blankColor
                else
                    if gridData.allyOwnerID == myAllyID then
                        gridData.currentColor = alliedColor
                    else
                        gridData.currentColor = enemyColor
                    end
                end
            end
            
            local captureChangePerFrame = 0
            if gridData.captureChange then
                captureChangePerFrame = gridData.captureChange / UPDATE_FRAME_RATE_INTERVAL
            end

            updateGridSquareInstanceVBO(
                gridID,
                {gridData.gridMidpointX, SQUARE_HEIGHT, gridData.gridMidpointZ, SQUARE_SIZE},
                gridData.currentColor,
                {captureChangePerFrame, gridData.oldProgress, frame, gridData.showSquareTimestamp}
            )
            gridData.captureChange = nil
        end
        
        uploadAllElements(instanceVBO)
        lastMoveFrame = frame
    end
end

function gadget:DrawWorldPreUnit()
	if not squareShader or not squareVAO or not instanceVBO then return end
	
	if spIsGUIHidden() then return end
	
	glTexture(0, "$heightmap")
	glDepthTest(true)
	
	squareShader:Activate()
	squareShader:SetUniformInt("isMinimapRendering", 0)
	squareShader:SetUniformInt("flipMinimap", getMiniMapFlipped() and 1 or 0)
	instanceVBO.VAO:DrawElements(GL.TRIANGLES, instanceVBO.numVertices, 0, instanceVBO.usedElements)
	
	squareShader:Deactivate()
	glTexture(0, false)
	glDepthTest(false)
end

function gadget:DrawInMiniMap()
	if not squareShader or not squareVAO or not instanceVBO then return end
	
	if spIsGUIHidden() then return end
	
	squareShader:Activate()
	squareShader:SetUniformInt("isMinimapRendering", 1)
	squareShader:SetUniformInt("flipMinimap", getMiniMapFlipped() and 1 or 0)

	instanceVBO.VAO:DrawElements(GL.TRIANGLES, instanceVBO.numVertices, 0, instanceVBO.usedElements)
	
	squareShader:Deactivate()
end

function gadget:Shutdown()
	if squareVBO then
		squareVBO:Delete()
	end
	if instanceVBO and instanceVBO.instanceVBO then
		instanceVBO.instanceVBO:Delete()
	end
	if squareShader then
		squareShader:Finalize()
	end
end

end