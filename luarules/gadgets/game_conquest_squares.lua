function gadget:GetInfo()
	return {
		name = "Unit In Square Tracker",
		desc = "Cuts the map into squares and tracks which squares units are in",
		author = "SethDGamre",
		date = "2025.02.08",
		license = "GNU GPL, v2 or later",
		layer = -10,
		enabled = true,
	}
end

-- Split the gadget into synced and unsynced parts
local SYNCED = gadgetHandler:IsSyncedCode()

if SYNCED then
-- SYNCED CODE

	--configs
	local DEBUGMODE = true -- Changed to uppercase as it's a constant
	local MINUTES_TO_MAX = 20
	local MINUTES_TO_START = 5
	local MAX_TERRITORY_PERCENTAGE = 100
	local MAX_PROGRESS = 100
	local PROGRESS_INCREMENT = 3
	local CONTIGUOUS_PROGRESS_INCREMENT = 1
	local DECAY_PROGRESS_INCREMENT = 0.5
	local STATIC_POWER_MULTIPLIER = 3
	local SQUARE_CHECK_INTERVAL = Game.gameSpeed
	local DECAY_DELAY_FRAMES = Game.gameSpeed * 10
	local SQUARE_BOUNDARY = 128
	local GRID_SIZE = 1024
	local FINISHED_BUILDING = 1
	local FRAME_MODULO = Game.gameSpeed * 3
	local STARTING_PROGRESS = 0
	local OWNERSHIP_THRESHOLD = 33
	local MAJORITY_THRESHOLD = 0.5 -- Moved from function to constants

	--localized functions
	local sqrt = math.sqrt
	local floor = math.floor
	local max = math.max
	local min = math.min
	local random = math.random
	local spGetGroundHeight = Spring.GetGroundHeight
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
	local SendToUnsynced = SendToUnsynced

	--variables
	local initialized = false
	local scavengerTeamID = 999
	local raptorsTeamID = 999
	local gaiaTeamID = spGetGaiaTeamID()
	local gaiaAllyTeamID = select(6, spGetTeamInfo(gaiaTeamID))
	local teams = spGetTeamList()
	local allyTeamsCount = 0
	local defeatThreshold = 0
	local numberOfSquaresX = 0
	local numberOfSquaresZ = 0
	local gameFrame = 0
	local sentGridStructure = false
	local sentAllyTeams = {}
	local cachedGridData = {}

	--tables
	local allyTeamsWatch = {}
	local exemptTeams = {}
	local unitWatchDefs = {}
	local captureGrid = {}
	local allyScores = {}
	local squaresToRaze = {}
	local allyTeamIDs = {} -- Store ally team IDs for unsynced to get colors
	local livingCommanders = {}
	local killQueue = {}
	local commandersDefs = {}
	local allyTallies = {}
	local randomizedGridIDs = {} -- Pre-allocate for reuse

	local debugOwnershipCegs = {
		[0] = "corpsedestroyed",
		[1] = "botrailspawn",
		[2] = "wallexplosion-water"
	}

	exemptTeams[gaiaTeamID] = true

	--start-up
	for _, teamID in ipairs(teams) do --first figure out which teams are exempt
		local luaAI = spGetTeamLuaAI(teamID)
		if luaAI and luaAI ~= "" then
			if string.sub(luaAI, 1, 12) == 'ScavengersAI' then
				scavengerTeamID = teamID
				exemptTeams[teamID] = true
			elseif string.sub(luaAI, 1, 12) == 'RaptorsAI' then
				raptorsTeamID = teamID
				exemptTeams[teamID] = true
			end
		end
		if teamID == gaiaTeamID then
			exemptTeams[teamID] = true
		end
	end

	local function updateLivingTeamsData()
		allyTeamsCount = 0  -- Reset count first
		allyTeamsWatch = {}  -- Clear existing watch list
		allyTeamIDs = {}    -- Clear ally team IDs list
		
		-- Rebuild list with living teams and count allies
		for _, teamID in ipairs(teams) do
			if not exemptTeams[teamID] then
				local _, _, isDead, _, _, allyTeam = spGetTeamInfo(teamID)
				if not isDead and allyTeam then
					allyTeamsWatch[allyTeam] = allyTeamsWatch[allyTeam] or {}
					allyTeamsWatch[allyTeam][teamID] = true
					
					-- Store the first team ID for each ally team
					if not allyTeamIDs[allyTeam] then
						allyTeamIDs[allyTeam] = teamID
					end
				end
			end
		end
		
		-- Count ally teams more efficiently
		for _ in pairs(allyTeamsWatch) do
			allyTeamsCount = allyTeamsCount + 1
		end
	end

	-- Process unit definitions once during initialization
	for defID, def in pairs(UnitDefs) do
		local defData

		if def.power then
			defData = {power = def.power}
			if def.speed == 0 then
				defData.power = defData.power * STATIC_POWER_MULTIPLIER
				defData.isStatic = true -- Cache this value
			end
		end
		unitWatchDefs[defID] = defData

		if def.customParams and def.customParams.iscommander then
			commandersDefs[defID] = true
		end
	end

	--custom functions
	local function generateCaptureGrid()
		local points = {}
		local totalSquares = numberOfSquaresX * numberOfSquaresZ
		
		-- Pre-allocate table size for better performance
		for i = 1, totalSquares do
			points[i] = {}
		end
		
		for x = 0, numberOfSquaresX - 1 do
			for z = 0, numberOfSquaresZ - 1 do
				local originX = x * GRID_SIZE
				local originZ = z * GRID_SIZE
				local index = x * numberOfSquaresZ + z + 1
				local point = points[index]
				point.x = originX
				point.z = originZ
				point.middleX = originX + GRID_SIZE / 2
				point.middleZ = originZ + GRID_SIZE / 2
				point.allyOwnerID = gaiaAllyTeamID
				point.progress = STARTING_PROGRESS
				point.hasUnits = false
				point.decayDelay = 0
				point.gridX = x
				point.gridZ = z
			end
		end
		return points
	end

	local function updateCurrentDefeatThreshold()
		local seconds = spGetGameSeconds()
		local totalMinutes = seconds / 60  -- Convert seconds to minutes
		if totalMinutes < MINUTES_TO_START then return end

		local progressRatio = min((totalMinutes - MINUTES_TO_START) / MINUTES_TO_MAX, 1)
		local wantedThreshold = floor((progressRatio * MAX_TERRITORY_PERCENTAGE) / allyTeamsCount)
		if wantedThreshold > defeatThreshold then
			defeatThreshold = defeatThreshold + 1
		end
	end

	local function convertTalliesToScores(tallies)
		local totalSquares = #captureGrid
		if totalSquares == 0 then return {} end
		local allyScoreTable = {}

		for allyID, tally in pairs(tallies) do
			local percentage = floor((tally / totalSquares) * 100)
			allyScoreTable[allyID] = percentage
		end
		return allyScoreTable
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
		for teamID in pairs(allyTeamsWatch[allyID]) do
			for unitID, unitTeam in pairs(livingCommanders) do
				if unitTeam == teamID then
					queueCommanderTeleportRetreat(unitID)
				end
			end
		end
	end

	-- Optimized to avoid recreating tables each call
	local function getAllyPowersInSquare(gridID)
		local data = captureGrid[gridID]
		local units = spGetUnitsInRectangle(data.x, data.z, data.x + GRID_SIZE, data.z + GRID_SIZE)
		
		-- Reuse the same table for ally powers
		local allyPowers = {}
		data.hasUnits = false
		
		for i = 1, #units do
			local unitID = units[i]
			local buildProgress = select(5, spGetUnitHealth(unitID))
			
			if buildProgress == FINISHED_BUILDING then
				local unitDefID = spGetUnitDefID(unitID)
				local unitData = unitWatchDefs[unitDefID]
				local allyTeam = spGetUnitAllyTeam(unitID)
				
				if unitData and unitData.power and allyTeamsWatch[allyTeam] then
					data.hasUnits = true
					local power = unitData.power
					if unitData.isStatic then
						power = power * 3
					end
					allyPowers[allyTeam] = (allyPowers[allyTeam] or 0) + power
				end
			end
		end
		
		if data.hasUnits then
			return allyPowers
		end
		return nil
	end

	-- Pre-allocate sortedTeams table for reuse
	local sortedTeams = {}
	
	local function getCaptureProgress(gridID, allyPowers)
		if not allyPowers then return nil, 0 end
		local data = captureGrid[gridID]
		local currentOwnerID = data.allyOwnerID
		
		-- Clear and reuse sortedTeams table
		for i = 1, #sortedTeams do
			sortedTeams[i] = nil
		end
		
		local teamCount = 0
		for team, power in pairs(allyPowers) do
			teamCount = teamCount + 1
			sortedTeams[teamCount] = {team = team, power = power}
		end
		
		-- Sort only if we have teams to sort
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
			comparedPower = allyPowers[currentOwnerID]
		elseif secondPlaceAllyID then
			comparedPower = allyPowers[secondPlaceAllyID]
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

	local function applyProgress(gridID, progressChange, winningAllyID)
		local data = captureGrid[gridID]
		data.progress = data.progress + progressChange
		
		if data.progress < 0 then
			data.allyOwnerID = winningAllyID
			data.progress = math.abs(data.progress)
		elseif data.progress > MAX_PROGRESS then
			data.progress = MAX_PROGRESS
		end

		data.decayDelay = gameFrame + DECAY_DELAY_FRAMES
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
		
		-- Skip if this square has units or is owned by Gaia
		if currentSquareData.hasUnits then
			return nil, 0
		end
		
		local neighborAllyTeamCounts = {}
		local dominantAllyTeamCount = 0
		local totalNeighborCount = 0
		local dominantAllyTeamID
		
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
							if neighborSquareData.progress == MAX_PROGRESS then
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
			-- If dominant ally is different from current owner, return negative progress (capture)
			if dominantAllyTeamID ~= currentSquareData.allyOwnerID then
				return dominantAllyTeamID, -CONTIGUOUS_PROGRESS_INCREMENT
			else
				-- If dominant ally is same as current owner, return positive progress (reinforce)
				return dominantAllyTeamID, CONTIGUOUS_PROGRESS_INCREMENT
			end
		end
		
		return nil, 0
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

	-- Function to send grid data to unsynced
	local function sendGridToUnsynced()
		-- Only send static grid structure data once during initialization
		if not sentGridStructure then
			SendToUnsynced("InitGridStructure", numberOfSquaresX, numberOfSquaresZ)
			
			for gridID, data in pairs(captureGrid) do
				SendToUnsynced("InitGridSquare", gridID, data.gridX, data.gridZ, data.x, data.z)
			end
			
			sentGridStructure = true
		end
		
		-- Only send ally team colors when they change
		for allyTeamID, teamID in pairs(allyTeamIDs) do
			if not sentAllyTeams[allyTeamID] or sentAllyTeams[allyTeamID] ~= teamID then
				SendToUnsynced("UpdateAllyTeamID", allyTeamID, teamID)
				sentAllyTeams[allyTeamID] = teamID
			end
		end
		
		-- Only send ownership and progress data which changes frequently
		for gridID, data in pairs(captureGrid) do
			local cachedData = cachedGridData[gridID]
			
			-- Initialize cache entry if it doesn't exist
			if not cachedData then
				cachedData = {allyOwnerID = -1, progress = -1}
				cachedGridData[gridID] = cachedData
			end
			
			-- Only send if data has changed
			if data.allyOwnerID ~= cachedData.allyOwnerID or data.progress ~= cachedData.progress then
				SendToUnsynced("UpdateGridState", gridID, data.allyOwnerID, data.progress)
				
				-- Update cache
				cachedData.allyOwnerID = data.allyOwnerID
				cachedData.progress = data.progress
			end
		end
	end

	local function setAllyGridToGaia(allyID)
		for gridID, data in pairs(captureGrid) do
			if data.allyOwnerID == allyID then
				data.allyOwnerID = gaiaAllyTeamID
				data.progress = min(data.progress, STARTING_PROGRESS)
			end
		end
	end

	local function decayProgress(gridID)
		local data = captureGrid[gridID]
		if data.progress > OWNERSHIP_THRESHOLD then
			applyProgress(gridID, -DECAY_PROGRESS_INCREMENT, data.allyOwnerID)
		else
			applyProgress(gridID, -DECAY_PROGRESS_INCREMENT, gaiaAllyTeamID)
		end
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if commandersDefs[unitDefID] then
			livingCommanders[unitID] = unitTeam
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		livingCommanders[unitID] = nil
	end

	function gadget:GameFrame(frame)
		gameFrame = frame
		local frameModulo = frame % SQUARE_CHECK_INTERVAL

		if frameModulo == 0 then
			updateLivingTeamsData()
			updateCurrentDefeatThreshold()
			allyTallies = getClearedAllyTallies()

			for gridID, data in pairs(captureGrid) do
				local allyPowers = getAllyPowersInSquare(gridID)
				local winningAllyID, progressChange = getCaptureProgress(gridID, allyPowers)
				if winningAllyID then
					applyProgress(gridID, progressChange, winningAllyID)
				end
				if allyTeamsWatch[data.allyOwnerID] and data.progress > OWNERSHIP_THRESHOLD then
					allyTallies[data.allyOwnerID] = allyTallies[data.allyOwnerID] + 1
				end

				if DEBUGMODE and false then -- Simplified debug condition
					spSpawnCEG("scaspawn-trail", data.x, spGetGroundHeight(data.x, data.z), data.z, 0,0,0)
					spSpawnCEG("scav-spawnexplo", data.x, spGetGroundHeight(data.x, data.z), data.z, 0,0,0)
					if allyTeamsWatch[data.allyOwnerID] then
						spSpawnCEG(debugOwnershipCegs[data.allyOwnerID], data.middleX, spGetGroundHeight(data.middleX, data.middleZ), data.middleZ, 0,0,0)
					end
				end
			end
		elseif frameModulo == 1 then
			local randomizedIDs = getRandomizedGridIDs()
			for i = 1, #randomizedIDs do
				local gridID = randomizedIDs[i]
				local contiguousAllyID, progressChange = getSquareContiguityProgress(gridID)
				if contiguousAllyID and progressChange ~= 0 then
					applyProgress(gridID, progressChange, contiguousAllyID)
				end
			end

			for gridID, data in pairs(captureGrid) do
				if data.decayDelay < frame and data.progress < MAX_PROGRESS then
					decayProgress(gridID)
				end
			end
		elseif frameModulo == 2 then
			allyScores = convertTalliesToScores(allyTallies)
			for allyID, score in pairs(allyScores) do
				if allyTeamsWatch[allyID] and score < defeatThreshold and not DEBUGMODE then
					triggerAllyDefeat(allyID)
					setAllyGridToGaia(allyID)
				end
			end
			
			-- Send updated grid data to unsynced
			sendGridToUnsynced()
		end

		-- Process kill queue
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
		captureGrid = generateCaptureGrid()
		updateLivingTeamsData()
		
		-- Initialize caching variables
		sentGridStructure = false
		sentAllyTeams = {}
		cachedGridData = {}

		local units = Spring.GetAllUnits()
		for i = 1, #units do
			local unitID = units[i]
			gadget:UnitCreated(unitID, spGetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
		end
	end

else
-- UNSYNCED CODE

-- Localize GL functions for better performance
local glColor = gl.Color
local glRect = gl.Rect
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glBeginEnd = gl.BeginEnd
local GL_QUADS = GL.QUADS

-- Spring functions
local spGetTeamColor = Spring.GetTeamColor
local spGetGameFrame = Spring.GetGameFrame

-- Variables for the squares
local SQUARE_OPACITY = 0.7
local MINIMAP_DRAW_ENABLED = true
local blinkFrame = false  -- Toggle for blinking effect
local LOW_PROGRESS_THRESHOLD = 50  -- Progress threshold for blinking
local BLINK_INTERVAL = Game.gameSpeed * 4
local MINIMAP_SQUARE_OPACITY = 0.15
local OWNERSHIP_THRESHOLD = 33
local MAX_PROGRESS = 100

-- Get map dimensions
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local GRID_SIZE = 1024 -- Same as in synced code

-- Tables to store grid data from synced
local gridData = {}
local gridStateData = {}  -- Only stores dynamic state (ownership and progress)
local allyTeamIDs = {}
local allyTeamColors = {}
local numberOfSquaresX = 0
local numberOfSquaresZ = 0
local gridInitialized = false

-- Cache for minimap dimensions and calculated square sizes
local minimapCache = {
	posX = 0,
	posY = 0,
	sizeX = 0,
	sizeY = 0,
	gridSquareWidth = 0,
	gridSquareHeight = 0,
	needsUpdate = true
}

-- Cache for square positions (only recalculated when minimap changes)
local squarePositions = {}

-- Function to check if minimap dimensions have changed and update cache
local function UpdateMinimapCache()
	local minimapPosX, minimapPosY, minimapSizeX, minimapSizeY = Spring.GetMiniMapGeometry()
	
	if minimapPosX ~= minimapCache.posX or 
	   minimapPosY ~= minimapCache.posY or
	   minimapSizeX ~= minimapCache.sizeX or
	   minimapSizeY ~= minimapCache.sizeY then
		
		-- Update cache with new values
		minimapCache.posX = minimapPosX
		minimapCache.posY = minimapPosY
		minimapCache.sizeX = minimapSizeX
		minimapCache.sizeY = minimapSizeY
		
		-- Recalculate grid square dimensions
		minimapCache.gridSquareWidth = (GRID_SIZE / mapSizeX) * minimapSizeX
		minimapCache.gridSquareHeight = (GRID_SIZE / mapSizeZ) * minimapSizeY
		
		-- Clear square positions cache to force recalculation
		squarePositions = {}
		
		minimapCache.needsUpdate = false
		return true
	end
	
	return false
end

-- Initialize the grid structure (called once from synced)
local function InitializeGridStructure(numberOfSquaresX, numberOfSquaresZ)
	-- Clear existing data if any
	gridData = {}
	
	-- Create the grid structure
	for x = 0, numberOfSquaresX - 1 do
		for z = 0, numberOfSquaresZ - 1 do
			local gridID = x * numberOfSquaresZ + z + 1
			local originX = x * GRID_SIZE
			local originZ = z * GRID_SIZE
			
			gridData[gridID] = {
				gridX = x,
				gridZ = z,
				x = originX,
				z = originZ,
				middleX = originX + GRID_SIZE / 2,
				middleZ = originZ + GRID_SIZE / 2
			}
			
			-- Initialize state data
			gridStateData[gridID] = {
				allyOwnerID = 0,  -- Default to Gaia
				progress = 0      -- Default progress
			}
		end
	end
	
	gridInitialized = true
	return true
end

-- Function to draw all grid squares on the minimap
local function DrawGridSquares()
	-- Update minimap cache if needed
	local minimapChanged = UpdateMinimapCache()
	
	-- Use cached values
	local minimapPosX = minimapCache.posX
	local minimapPosY = minimapCache.posY
	local minimapSizeY = minimapCache.sizeY
	local gridSquareWidth = minimapCache.gridSquareWidth
	local gridSquareHeight = minimapCache.gridSquareHeight
	
	-- Only recalculate square positions if minimap changed or they haven't been calculated yet
	if minimapChanged or next(squarePositions) == nil then
		for gridID, staticData in pairs(gridData) do
			squarePositions[gridID] = {
				left = minimapPosX + (staticData.gridX * GRID_SIZE / mapSizeX) * minimapCache.sizeX,
				top = minimapPosY + minimapSizeY - (staticData.gridZ * GRID_SIZE / mapSizeZ) * minimapCache.sizeY,
				width = gridSquareWidth,
				height = gridSquareHeight
			}
		end
	end
	
	-- Group squares by ally team and blink state to minimize color changes
	local normalSquares = {}
	local blinkingSquares = {}
	
	-- First pass: organize squares by ally team and blink state
	for gridID, staticData in pairs(gridData) do
		local stateData = gridStateData[gridID]
		if stateData then
			local allyOwnerID = stateData.allyOwnerID
			local progress = stateData.progress
			local shouldBlink = progress < MAX_PROGRESS and progress >= OWNERSHIP_THRESHOLD
			
			-- Skip squares with no color data
			if allyTeamColors[allyOwnerID] then
				local squarePos = squarePositions[gridID]
				
				if shouldBlink and blinkFrame then
					blinkingSquares[allyOwnerID] = blinkingSquares[allyOwnerID] or {}
					table.insert(blinkingSquares[allyOwnerID], squarePos)
				else
					normalSquares[allyOwnerID] = normalSquares[allyOwnerID] or {}
					table.insert(normalSquares[allyOwnerID], squarePos)
				end
			end
		end
	end
	
	-- Draw normal squares by ally team
	for allyOwnerID, squares in pairs(normalSquares) do
		local color = allyTeamColors[allyOwnerID]
		glColor(color.r, color.g, color.b, MINIMAP_SQUARE_OPACITY)
		
		for _, square in ipairs(squares) do
			glRect(
				square.left, 
				square.top, 
				square.left + square.width, 
				square.top - square.height
			)
		end
	end
	
	-- Draw blinking squares by ally team
	for allyOwnerID, squares in pairs(blinkingSquares) do
		local color = allyTeamColors[allyOwnerID]
		local r = color.r + 0.3 * (1 - color.r)
		local g = color.g + 0.3 * (1 - color.g)
		local b = color.b + 0.3 * (1 - color.b)
		
		glColor(r, g, b, MINIMAP_SQUARE_OPACITY)
		
		for _, square in ipairs(squares) do
			glRect(
				square.left, 
				square.top, 
				square.left + square.width, 
				square.top - square.height
			)
		end
	end
	
	-- Reset color to white
	glColor(1, 1, 1, 1)
end

local args = {...}
-- Receive grid data from synced
function gadget:RecvFromSynced(cmd, ...)
	args = {...}
	
	if cmd == "InitGridStructure" then
		-- Initialize the entire grid structure (once)
		local numSquaresX = args[1]
		local numSquaresZ = args[2]
		numberOfSquaresX = numSquaresX
		numberOfSquaresZ = numSquaresZ
		InitializeGridStructure(numSquaresX, numSquaresZ)
	elseif cmd == "InitGridSquare" then
		-- Initialize a single grid square (part of initialization)
		local gridID = args[1]
		local gridX = args[2]
		local gridZ = args[3]
		local x = args[4]
		local z = args[5]
		
		gridData[gridID] = {
			gridX = gridX,
			gridZ = gridZ,
			x = x,
			z = z,
			middleX = x + GRID_SIZE / 2,
			middleZ = z + GRID_SIZE / 2
		}
		
		-- Initialize state data if not already present
		if not gridStateData[gridID] then
			gridStateData[gridID] = {
				allyOwnerID = 0,
				progress = 0
			}
		end
	elseif cmd == "UpdateGridState" then
		-- Update only the changing state of a grid square (frequent)
		local gridID = args[1]
		local allyOwnerID = args[2]
		local progress = args[3]
		
		-- Only update if the grid square exists
		if gridStateData[gridID] then
			gridStateData[gridID].allyOwnerID = allyOwnerID
			gridStateData[gridID].progress = progress
		end
	elseif cmd == "UpdateAllyTeamID" then
		local allyTeamID = args[1]
		local teamID = args[2]
		allyTeamIDs[allyTeamID] = teamID
		
		-- Update colors when receiving new team IDs
		local r, g, b = spGetTeamColor(teamID)
		allyTeamColors[allyTeamID] = {r = r, g = g, b = b}
	end
end

-- Update function to toggle the blink state
local updateFrame = 0
function gadget:Update()
	updateFrame = updateFrame + 1
	if updateFrame % BLINK_INTERVAL == 0 then
		blinkFrame = not blinkFrame
	end
	
	-- Mark minimap cache for update occasionally to catch resize events
	if updateFrame % 30 == 0 then
		minimapCache.needsUpdate = true
	end
end

-- Hook into DrawInMiniMap to draw our grid squares on the minimap
function gadget:DrawInMiniMap(mmsx, mmsy)
	if MINIMAP_DRAW_ENABLED and gridInitialized and next(gridData) then

		-- Save the current matrix
		glPushMatrix()
		
		-- Draw all grid squares
		DrawGridSquares()
		
		-- Restore the matrix
		glPopMatrix()
	end
end

-- Toggle function that can be called from elsewhere if needed
function gadget:ToggleMinimapDraw()
	MINIMAP_DRAW_ENABLED = not MINIMAP_DRAW_ENABLED
end

end