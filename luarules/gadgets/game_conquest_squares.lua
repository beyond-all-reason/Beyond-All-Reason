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
				data.x = originX
				data.z = originZ
				data.middleX = originX + GRID_SIZE / 2
				data.middleZ = originZ + GRID_SIZE / 2
				data.allyOwnerID = gaiaAllyTeamID
				data.progress = STARTING_PROGRESS
				data.hasUnits = false
				data.decayDelay = 0
				data.gridX = x
				data.gridZ = z
				data.sentAllyID = gaiaAllyTeamID
				data.sentBlinkingState = true
			end
		end
		return gridData
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

	local function initializeUnsyncedGrid()
		for gridID, data in pairs(captureGrid) do
			SendToUnsynced("InitializeGridSquare", gridID, data.allyOwnerID, data.sentBlinkingState, data.gridX, data.gridZ)
		end
	end

	local function updateUnsyncedSquare(gridID)
		local data = captureGrid[gridID]
		local blinking = false
		local allyIDtoSend = gaiaAllyTeamID
		
		if data.progress > OWNERSHIP_THRESHOLD then
			allyIDtoSend = data.allyOwnerID
		end
		if data.progress < MAX_PROGRESS then
			blinking = true
		end
		if data.sentAllyID == allyIDtoSend and data.sentBlinkingState == blinking then
			return -- data is the same as last time
		end
		data.sentAllyID = allyIDtoSend
		data.sentBlinkingState = blinking
		SendToUnsynced("UpdateGridSquare", gridID, allyIDtoSend, blinking)
	end

	local function updateUnsyncedScore(allyID, score)
		SendToUnsynced("UpdateAllyScore", allyID, score)
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
					updateUnsyncedSquare(gridID)
				end
				if allyTeamsWatch[data.allyOwnerID] and data.progress > OWNERSHIP_THRESHOLD then
					allyTallies[data.allyOwnerID] = allyTallies[data.allyOwnerID] + 1
				end

				-- if DEBUGMODE then -- Simplified debug condition
				-- 	spSpawnCEG("scaspawn-trail", data.x, spGetGroundHeight(data.x, data.z), data.z, 0,0,0)
				-- 	spSpawnCEG("scav-spawnexplo", data.x, spGetGroundHeight(data.x, data.z), data.z, 0,0,0)
				-- 	if allyTeamsWatch[data.allyOwnerID] then
				-- 		spSpawnCEG(debugOwnershipCegs[data.allyOwnerID], data.middleX, spGetGroundHeight(data.middleX, data.middleZ), data.middleZ, 0,0,0)
				-- 	end
				-- end
			end
		elseif frameModulo == 1 then
			local randomizedIDs = getRandomizedGridIDs()
			for i = 1, #randomizedIDs do
				local gridID = randomizedIDs[i]
				local contiguousAllyID, progressChange = getSquareContiguityProgress(gridID)
				if contiguousAllyID and progressChange ~= 0 then
					applyProgress(gridID, progressChange, contiguousAllyID)
					updateUnsyncedSquare(gridID)
				end
			end

			for gridID, data in pairs(captureGrid) do
				if data.decayDelay < frame and data.progress < MAX_PROGRESS then
					decayProgress(gridID)
					updateUnsyncedSquare(gridID)
				end
			end
		elseif frameModulo == 2 then
			allyScores = convertTalliesToScores(allyTallies)
			for allyID, score in pairs(allyScores) do
				updateUnsyncedScore(allyID, score)
				if allyTeamsWatch[allyID] and score < defeatThreshold and not DEBUGMODE then
					triggerAllyDefeat(allyID)
					setAllyGridToGaia(allyID)
				end
			end
			
			-- Send updated grid data to unsynced
			if not sentGridStructure then
				initializeUnsyncedGrid()
				sentGridStructure = true
			end
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

--zzz need to prevent defeat in the case that all remaining teams are tied, or there is only one team left

else

VFS.Include("luaui/Widgets/Include/instancevbotable.lua")
-- UNSYNCED CODE

-- Localize GL functions for better performance
local glColor = gl.Color
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glShape = gl.Shape
local glRect = gl.Rect
local GL_QUADS = GL.QUADS

-- Spring functions
local spGetTeamColor = Spring.GetTeamColor
local spGetMiniMapGeometry = Spring.GetMiniMapGeometry

-- Variables for the squares
local MINIMAP_DRAW_ENABLED = true
local blinkFrame = false  -- Toggle for blinking effect
local BLINK_INTERVAL = 30 -- Frames between blinks (reduced from gameSpeed*4)
local MINIMAP_SQUARE_OPACITY = 0.3 -- Increased from 0.15 for better visibility

-- Get map dimensions
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local GRID_SIZE = 1024 -- Same as in synced code

-- Tables to store grid data from synced
local gridData = {}
local allyTeamColors = {}
local allyScores = {}

-- Minimap cache
local minimapCache = {
	posX = 0,
	posY = 0,
	sizeX = 0,
	sizeY = 0,
	needsUpdate = true
}

-- Function to check if minimap dimensions have changed and update cache
local function updateMinimapCache()
	local minimapPosX, minimapPosY, minimapSizeX, minimapSizeY = spGetMiniMapGeometry()
	
	if minimapPosX ~= minimapCache.posX or 
	   minimapPosY ~= minimapCache.posY or
	   minimapSizeX ~= minimapCache.sizeX or
	   minimapSizeY ~= minimapCache.sizeY then
		
		-- Update cache with new values
		minimapCache.posX = minimapPosX
		minimapCache.posY = minimapPosY
		minimapCache.sizeX = minimapSizeX
		minimapCache.sizeY = minimapSizeY
		
		minimapCache.needsUpdate = false
		return true
	end
	
	return false
end

-- Function to draw all grid squares directly
local function drawGridSquares()
	-- Update minimap cache if needed
	if minimapCache.needsUpdate then
		updateMinimapCache()
	end
	
	-- Calculate grid square dimensions on minimap
	local gridSquareWidth = (GRID_SIZE / mapSizeX) * minimapCache.sizeX
	local gridSquareHeight = (GRID_SIZE / mapSizeZ) * minimapCache.sizeY
	
	-- Draw each grid square
	for gridID, data in pairs(gridData) do
		local allyOwnerID = data.allyOwnerID
		local color = allyTeamColors[allyOwnerID]
		
		if color then
			-- Skip drawing if we should be blinking and blink is off
			if data.blinking and not blinkFrame then
				-- Skip this square during off-blink frames
			else
				-- Calculate square position on minimap
				local left = minimapCache.posX + (data.gridX * GRID_SIZE / mapSizeX) * minimapCache.sizeX
				
				-- Fix for vertical mirroring - calculate from the top of the minimap instead of bottom
				local bottom = minimapCache.posY + minimapCache.sizeY - ((data.gridZ + 1) * GRID_SIZE / mapSizeZ) * minimapCache.sizeY
				local right = left + gridSquareWidth
				local top = bottom + gridSquareHeight
				
				-- Adjust color for blinking squares
				if data.blinking and blinkFrame then
					-- Brighter color for blinking
					glColor(
						math.min(1.0, color.r * 1.5),
						math.min(1.0, color.g * 1.5),
						math.min(1.0, color.b * 1.5),
						MINIMAP_SQUARE_OPACITY
					)
				else
					glColor(color.r, color.g, color.b, MINIMAP_SQUARE_OPACITY)
				end
				
				-- Draw the rectangle
				glRect(left, bottom, right, top)
			end
		end
	end
	
	-- Reset color to white
	glColor(1, 1, 1, 1)
end

-- Receive grid data from synced
function gadget:RecvFromSynced(cmd, ...)
	local args = {...}
	
	if cmd == "InitializeGridSquare" then
		-- Initialize a single grid square
		local gridID = args[1]
		local allyOwnerID = args[2]
		local blinking = args[3]
		local gridX = args[4]
		local gridZ = args[5]
		
		-- Store the grid square data
		gridData[gridID] = {
			gridX = gridX,
			gridZ = gridZ,
			allyOwnerID = allyOwnerID,
			blinking = blinking
		}
		
		-- Mark minimap cache for update
		minimapCache.needsUpdate = true
		
	elseif cmd == "UpdateGridSquare" then
		-- Update a grid square's ownership and blinking state
		local gridID = args[1]
		local allyOwnerID = args[2]
		local blinking = args[3]
		
		-- Only update if the grid square exists
		if gridData[gridID] then
			gridData[gridID].allyOwnerID = allyOwnerID
			gridData[gridID].blinking = blinking
		end
		
	elseif cmd == "UpdateAllyScore" then
		-- Update an ally team's score
		local allyID = args[1]
		local score = args[2]
		allyScores[allyID] = score
	end
end

-- Initialize team colors
function gadget:Initialize()
	-- Get all teams
	local teams = Spring.GetTeamList()
	
	-- For each team, get its ally team and color
	for _, teamID in ipairs(teams) do
		local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID)
		
		-- Only store the first team's color for each ally team
		if not allyTeamColors[allyTeamID] then
			local r, g, b = spGetTeamColor(teamID)
			allyTeamColors[allyTeamID] = {r = r, g = g, b = b}
		end
	end
	
	-- Also add Gaia team color (usually gray)
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID))
	local r, g, b = spGetTeamColor(gaiaTeamID)
	allyTeamColors[gaiaAllyTeamID] = {r = r, g = g, b = b}
	
	-- Initialize minimap cache
	updateMinimapCache()
end

-- Update function to toggle the blink state and check for minimap resizing
local updateFrame = 0
function gadget:Update()
	updateFrame = updateFrame + 1
	
	-- Toggle blink state
	if updateFrame % BLINK_INTERVAL == 0 then
		blinkFrame = not blinkFrame
	end
	
	-- Check for minimap resize occasionally
	if updateFrame % 30 == 0 then
		if updateMinimapCache() then
			-- Mark for update if minimap dimensions changed
			minimapCache.needsUpdate = true
		end
	end
end

-- Hook into DrawInMiniMap to draw our grid squares on the minimap
function gadget:DrawInMiniMap()
	if MINIMAP_DRAW_ENABLED and next(gridData) then
		-- Save the current matrix
		glPushMatrix()
		
		-- Draw all grid squares
		drawGridSquares()
		
		-- Restore the matrix
		glPopMatrix()
	end
end

-- Clean up when gadget is removed
function gadget:Shutdown()
	-- No explicit cleanup needed
end

-- Toggle function that can be called from elsewhere if needed
function gadget:ToggleMinimapDraw()
	MINIMAP_DRAW_ENABLED = not MINIMAP_DRAW_ENABLED
end

end