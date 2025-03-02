function gadget:GetInfo()
	return {
		name = "Unit In Square Tracker",
		desc = "Cuts the map into squares and tracks which squares units are in",
		author = "SethDGamre",
		date = "2025.02.08",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true,
	}
end

-- Split the gadget into synced and unsynced parts
local SYNCED = gadgetHandler:IsSyncedCode()

if SYNCED then
-- SYNCED CODE

	--configs
	local debugmode = true
	local MINUTES_TO_MAX = 20 --how many minutes until the threshold reaches max threshold from start time
	local MINUTES_TO_START = 5 --how many minutes until threshold can start to increment
	local MAX_TERRITORY_PERCENTAGE = 100 --how much territory/# of allies is factored in to bombardment threshold.
	local MAX_PROGRESS = 100 --how much progress a square can have
	local PROGRESS_INCREMENT = 3 --how much progress a square gains per frame
	local CONTIGUOUS_PROGRESS_INCREMENT = 0.5 --how much progress a square gains per calculation when it's contiguous
	local STATIC_POWER_MULTIPLIER = 3 --how much more conquest-power static units have over mobile units


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
	local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spGetGameSeconds = Spring.GetGameSeconds
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ



	-- constants
	local SQUARE_BOUNDARY = 128 -- how many elmos closer to the center of the scum than the actual edge of the scum the unit must be to be considered on the scum
	local GRID_SIZE = 1024 -- the size of the squares in elmos
	local FINISHED_BUILDING = 1
	local FRAME_MODULO = Game.gameSpeed * 3
	local STARTING_PROGRESS = 50


	--variables
	local initialized = false
	local scavengerTeamID = 999
	local raptorsTeamID = 999
	local gaiaTeamID = Spring.GetGaiaTeamID()
	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(gaiaTeamID))
	local teams = Spring.GetTeamList()
	local allyTeamsCount = 0
	local defeatThreshold = 0
	local numberOfSquaresX = 0
	local numberOfSquaresZ = 0

	--tables
	local allyTeamsWatch = {}
	local exemptTeams = {}
	local unitWatchDefs = {}
	local captureGrid = {}
	local allyScores = {}
	local squaresToRaze = {}

	local debugOwnershipCegs = {
		[0] = "corpsedestroyed",
		[1] = "botrailspawn",
		[2] = "wallexplosion-water"
	}

	exemptTeams[gaiaTeamID] = true

	--start-up
	for _, teamID in ipairs(teams) do --first figure out which teams are exempt

		local luaAI = Spring.GetTeamLuaAI(teamID)
		if luaAI and luaAI ~= "" then
			if string.sub(luaAI, 1, 12) == 'ScavengersAI' then
				scavengerTeamID = teamID
				exemptTeams[teamID] = true
			elseif  string.sub(luaAI, 1, 12) == 'RaptorsAI' then
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
		
		-- Rebuild list with living teams and count allies
		for _, teamID in ipairs(teams) do
			if not exemptTeams[teamID] then
				local _, _, isDead, _, _, allyTeam = Spring.GetTeamInfo(teamID)
				if not isDead and allyTeam then
					allyTeamsWatch[allyTeam] = allyTeamsWatch[allyTeam] or {}
					allyTeamsWatch[allyTeam][teamID] = true
				end
			end
		end
		for allyTeamID, teamIDs in pairs(allyTeamsWatch) do
			allyTeamsCount = allyTeamsCount + 1
		end
	end


	for defID, def in pairs(UnitDefs) do
		local defData

		if def.power then
			defData = {power = def.power}
			if def.speed == 0 then
				defData.power = defData.power * STATIC_POWER_MULTIPLIER
			end
		end
		unitWatchDefs[defID] = defData
	end

	--custom functions

	local function generateCaptureGrid()
		local points = {}
		
		for x = 0, numberOfSquaresX - 1 do
			for z = 0, numberOfSquaresZ - 1 do
				local originX = x * GRID_SIZE
				local originZ = z * GRID_SIZE
				local index = x * numberOfSquaresZ + z + 1
				points[index] = {
					x = originX, 
					z = originZ, 
					middleX = originX + GRID_SIZE / 2, 
					middleZ = originZ + GRID_SIZE / 2, 
					allyOwnerID = gaiaAllyTeamID, 
					progress = STARTING_PROGRESS, 
					hasUnits = false,
					gridX = x,
					gridZ = z
				}
			end
		end
		return points
	end

	local function updateCurrentDefeatThreshold()
		local seconds = spGetGameSeconds()
		local totalMinutes = seconds / 60  -- Convert seconds to minutes
		if totalMinutes < MINUTES_TO_START then return end

		local progressRatio = math.min(totalMinutes - MINUTES_TO_START / MINUTES_TO_MAX, 1)
		local wantedThreshold = math.floor((progressRatio * MAX_TERRITORY_PERCENTAGE) / allyTeamsCount) -- do not want the threshold to be unobtainable in an exaact tie situation
		if wantedThreshold > defeatThreshold then
			defeatThreshold = defeatThreshold + 1
		end
	end

	local function convertTalliesToScores(tallies)
		local totalSquares = #captureGrid
		if totalSquares == 0 then return {} end
		local allyScoreTable = {}

		for allyID, tally in pairs(tallies) do
			local percentage = math.floor((tally / totalSquares) * 100)
			allyScoreTable[allyID] = percentage
		end
		return allyScoreTable
	end

	local function triggerAllyDefeat(allyID)
		for i, data in ipairs(captureGrid) do
			if data.allyOwnerID == allyID then
				--squaresToRaze[i] = true
			end
		end
	end

	local function razeSquare(squareID, data)
		local attempts = 3
		local margin = GRID_SIZE * 0.1
		local chance = 0.5


		local data = captureGrid[squareID]
		local targetX, targetZ = random(data.x + margin, data.x + GRID_SIZE - margin), random(data.z + margin, data.z + GRID_SIZE - margin)
		for i = 1, attempts do
			if random() > chance then
				Spring.Echo("Razing square ", squareID, " at ", targetX, targetZ)
			end
		end
	end

	local function getAllyPowersInSquare(gridID)
		local data = captureGrid[gridID]
		local units = spGetUnitsInRectangle(data.x, data.z, data.x + GRID_SIZE, data.z + GRID_SIZE)
		local allyPowers = {}
		data.hasUnits = false
		for _, unitID in ipairs(units) do
			local isFinishedBuilding = select(5, spGetUnitHealth(unitID)) == FINISHED_BUILDING
			if isFinishedBuilding then
				local unitDefID = spGetUnitDefID(unitID)
				local unitData = unitWatchDefs[unitDefID]
				local allyTeam = spGetUnitAllyTeam(unitID)
				
				if unitData and unitData.power and allyTeamsWatch[allyTeam] then
					data.hasUnits = true
					local power = unitData.power
					if unitWatchDefs[unitDefID].isStatic then
						power = power * 3
					end
					allyPowers[allyTeam] = (allyPowers[allyTeam] or 0) + power
				end
			end
		end
		if 	data.hasUnits then
			return allyPowers
		end
	end

	local function getCaptureProgress(gridID, allyPowers)
		if not allyPowers then return nil, 0 end
		local data = captureGrid[gridID]
		local currentOwnerID = data.allyOwnerID
		
		local sortedTeams = {}
		
		for team, power in pairs(allyPowers) do
			table.insert(sortedTeams, {team = team, power = power})
		end
		table.sort(sortedTeams, function(a,b) return a.power > b.power end)
		
		local winningAllyID = sortedTeams[1] and sortedTeams[1].team
		local secondPlaceAllyID = sortedTeams[2] and sortedTeams[2].team

		local topPower = allyPowers[winningAllyID]
		local comparedPower = 0
		if winningAllyID ~= currentOwnerID and allyPowers[currentOwnerID] then
			comparedPower = allyPowers[currentOwnerID]
		elseif allyPowers[secondPlaceAllyID] then
			comparedPower = allyPowers[secondPlaceAllyID]
		else
			comparedPower = 0
		end
		
		local powerRatio = 1
		if topPower ~= 0 and comparedPower ~= 0 then
			powerRatio = math.abs(comparedPower / topPower - 1) --need a value between 0 and 1
		end
		
		local progressChange = 0
		if winningAllyID then
			if currentOwnerID == winningAllyID then
				progressChange = PROGRESS_INCREMENT * powerRatio
			else
				progressChange = -(powerRatio * PROGRESS_INCREMENT)
			end
		end
		return winningAllyID, progressChange
	end

	local function applyAndGetSquareOwnership(gridID, progressChange, winningAllyID)
		local data = captureGrid[gridID]
		data.progress = data.progress + progressChange
		
		if data.progress < 0 then
			data.allyOwnerID = winningAllyID
			data.progress = math.abs(data.progress)
		elseif data.progress > MAX_PROGRESS then
			data.progress = MAX_PROGRESS
		end
		if allyTeamsWatch[data.allyOwnerID] then -- don't return a score for invalid or dead allyTeams
			return data.allyOwnerID
		end
	end

	local function getClearedAllyTallies()
		local allies = {}
		for allyID, teamIDs in pairs(allyTeamsWatch) do
			allies[allyID] = 0
		end
		return allies
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	end



	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	end


	local function getSquareContiguityProgress(gridID)
		local data = captureGrid[gridID]
		
		-- Skip if this square has units or is owned by Gaia
		if data.hasUnits then
			return
		end
		
		local neighborAllyCounts = {}
		local topAllyCount = 0
		local totalCount = 0
		local NUMBER_OF_NEIGHBORS_TO_CHECK = 8
		local allyIDToSet
		local HALF = 0.5
		
		local x = data.gridX
		local z = data.gridZ

		for dx = -1, 1 do
			for dz = -1, 1 do
				if not (dx == 0 and dz == 0) then  -- Skip the center cell
					local nx, nz = x + dx, z + dz
					-- Check if neighbor is within bounds
					if nx >= 0 and nx < numberOfSquaresX and nz >= 0 and nz < numberOfSquaresZ then
						local neighborID = nx * numberOfSquaresZ + nz + 1
						local neighborData = captureGrid[neighborID]
						
						if neighborData and allyTeamsWatch[neighborData.allyOwnerID] then
							neighborAllyCounts[neighborData.allyOwnerID] = (neighborAllyCounts[neighborData.allyOwnerID] or 0) + 1
						end
					end
				end
			end
		end

		for allyID, count in pairs(neighborAllyCounts) do
			if count > topAllyCount then
				allyIDToSet = allyID
				topAllyCount = count
			end
			totalCount = totalCount + count
		end

		if allyIDToSet and topAllyCount > totalCount * HALF then
			if allyIDToSet ~= data.allyOwnerID then
				return allyIDToSet, -CONTIGUOUS_PROGRESS_INCREMENT
			else
				return allyIDToSet, CONTIGUOUS_PROGRESS_INCREMENT
			end
		end
	end

	local function getRandomizedGridIDs(grid)
		local randomizedIDs = {}
		
		-- Create a list of all grid IDs
		for gridID in pairs(grid) do
			table.insert(randomizedIDs, gridID)
		end
		
		-- Shuffle the grid IDs using Fisher-Yates algorithm
		for i = #randomizedIDs, 2, -1 do
			local j = math.random(i)
			randomizedIDs[i], randomizedIDs[j] = randomizedIDs[j], randomizedIDs[i]
		end
		
		return randomizedIDs
	end

	function gadget:GameFrame(frame)
		if frame % 30 == 0 then
			updateLivingTeamsData()
			updateCurrentDefeatThreshold()
			local allyTallies = getClearedAllyTallies()

			for gridID, data in pairs(captureGrid) do
				local allyPowers = getAllyPowersInSquare(gridID)
				local winningAllyID, progressChange = getCaptureProgress(gridID, allyPowers)
				if winningAllyID then
					data.ownerAllyID = applyAndGetSquareOwnership(gridID, progressChange, winningAllyID)
				end
				if allyTeamsWatch[data.allyOwnerID] then
					allyTallies[data.allyOwnerID] = allyTallies[data.allyOwnerID] + 1
				end

				if debugmode then --to show origins of each square
					Spring.SpawnCEG("scaspawn-trail", data.x, Spring.GetGroundHeight(data.x, data.z), data.z, 0,0,0)
					Spring.SpawnCEG("scav-spawnexplo", data.x, Spring.GetGroundHeight(data.x, data.z), data.z, 0,0,0)
					if allyTeamsWatch[data.allyOwnerID] then
						Spring.SpawnCEG(debugOwnershipCegs[data.allyOwnerID], data.middleX, Spring.GetGroundHeight(data.middleX, data.middleZ), data.middleZ, 0,0,0)
					end
				end
			end

			local randomizedGridIDs = getRandomizedGridIDs(captureGrid)
			for _, gridID in ipairs(randomizedGridIDs) do
				local contiguousAllyID, progressChange = getSquareContiguityProgress(gridID)
				if contiguousAllyID then
					applyAndGetSquareOwnership(gridID, progressChange, contiguousAllyID)
				end
			end
			
			allyScores = convertTalliesToScores(allyTallies)
			for allyID, score in pairs(allyScores) do
				if allyTeamsWatch[allyID] and score < defeatThreshold then
					triggerAllyDefeat(allyID)
				end
			end
		end
	end

	function gadget:Initialize()
		numberOfSquaresX = math.ceil(mapSizeX / GRID_SIZE)
		numberOfSquaresZ = math.ceil(mapSizeZ / GRID_SIZE)
		captureGrid = generateCaptureGrid()
		updateLivingTeamsData()
	end

	--zzz need to spawn projectiles in the raze function to fall from the sky and destroy squares, or some other method of razin

else
-- UNSYNCED CODE

-- Localize GL functions for better performance
local glColor = gl.Color
local glRect = gl.Rect
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate

-- Variables for the square
local squareOpacity = 0.7
local minimapDrawEnabled = true

-- Get map dimensions
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local GRID_SIZE = 1024 -- Same as in synced code

-- Function to draw a single grid square on the minimap
local function DrawGridSquare()
	-- Get minimap dimensions and position
	local minimapPosX, minimapPosY, minimapSizeX, minimapSizeY, _, _ = Spring.GetMiniMapGeometry()
	minimapPosY = minimapPosY
	
	-- Calculate the size of one grid square on the minimap
	-- This converts from map coordinates to minimap coordinates
	local gridSquareWidth = (GRID_SIZE / mapSizeX) * minimapSizeX
	local gridSquareHeight = (GRID_SIZE / mapSizeZ) * minimapSizeY
	
	-- Set color to red with opacity
	glColor(1, 0, 0, squareOpacity)
	
	-- Draw a rectangle in the upper left corner of the minimap
	glRect(
		minimapPosX,                      -- left
		minimapPosY + minimapSizeY,       -- top
		minimapPosX + gridSquareWidth,    -- right
		minimapPosY + minimapSizeY - gridSquareHeight  -- bottom
	)
	
	-- Reset color to white
	glColor(1, 1, 1, 1)
end

-- Hook into DrawScreenPost to draw our grid square AFTER the minimap
function gadget:DrawScreenPost()
	if minimapDrawEnabled then
		-- Save the current matrix
		glPushMatrix()
		
		-- Draw a grid square on the minimap
		DrawGridSquare()
		
		-- Restore the matrix
		glPopMatrix()
	end
end

-- Toggle function that can be called from elsewhere if needed
function gadget:ToggleMinimapDraw()
	minimapDrawEnabled = not minimapDrawEnabled
end

end -- end of UNSYNCED/SYNCED split