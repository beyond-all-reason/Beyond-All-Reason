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
	local debugmode = false
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
	local spGetUnitPosition = Spring.GetUnitPosition
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
	local allyTeamIDs = {} -- Store ally team IDs for unsynced to get colors
	local livingCommanders = {}
	local killQueue = {}
	local commandersDefs = {}

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
		allyTeamIDs = {}    -- Clear ally team IDs list
		
		-- Rebuild list with living teams and count allies
		for _, teamID in ipairs(teams) do
			if not exemptTeams[teamID] then
				local _, _, isDead, _, _, allyTeam = Spring.GetTeamInfo(teamID)
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

		if def.customParams and def.customParams.iscommander then
			commandersDefs[defID] = true
		end
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

		local progressRatio = math.min((totalMinutes - MINUTES_TO_START) / MINUTES_TO_MAX, 1)
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

	local function queueCommanderTeleportRetreat(unitID)
		local killDelayFrames = math.floor(Game.gameSpeed * 0.5)
		local killFrame = spGetGameFrame() + killDelayFrames
		killQueue[killFrame] = killQueue[killFrame] or {}
		killQueue[killFrame][unitID] = true

		local x,y,z = spGetUnitPosition(unitID)
		Spring.SpawnCEG("commander-spawn", x, y, z, 0, 0, 0)
		Spring.PlaySoundFile("commanderspawn-mono", 1.0, x, y, z, 0, 0, 0, "sfx")
		GG.ComSpawnDefoliate(x, y, z)
	end

	local function triggerAllyDefeat(allyID)
		for teamID, _ in pairs(allyTeamsWatch[allyID]) do
			Spring.Echo("Triggering ally defeat for teamID: ", teamID)
			for unitID, unitTeam in pairs(livingCommanders) do
				Spring.Echo("Checking unitID: ", unitID, "unitTeam: ", unitTeam)
				if unitTeam == teamID then
					Spring.Echo("Queueing commander teleport retreat for unitID: ", unitID)
					queueCommanderTeleportRetreat(unitID)
				end
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
		if commandersDefs[unitDefID] then
			livingCommanders[unitID] = unitTeam
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		livingCommanders[unitID] = nil
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

	-- Function to send grid data to unsynced
	local function sendGridToUnsynced()
		local gridData = {}
		for gridID, data in pairs(captureGrid) do
			gridData[gridID] = {
				x = data.x,
				z = data.z,
				gridX = data.gridX,
				gridZ = data.gridZ,
				allyOwnerID = data.allyOwnerID,
				progress = data.progress
			}
		end
		
		-- Send the grid data and ally team IDs to unsynced
		-- Convert tables to strings for SendToUnsynced
		SendToUnsynced("UpdateGridData", numberOfSquaresX, numberOfSquaresZ, GRID_SIZE)
		
		-- Send grid data in smaller chunks to avoid data type issues
		for gridID, data in pairs(gridData) do
			SendToUnsynced("UpdateGridSquare", gridID, data.gridX, data.gridZ, data.allyOwnerID, data.progress)
		end
		
		-- Send ally team IDs
		for allyTeamID, teamID in pairs(allyTeamIDs) do
			SendToUnsynced("UpdateAllyTeamID", allyTeamID, teamID)
		end
	end

	local function setAllyGridToGaia(allyID)
		for gridID, _ in pairs(captureGrid) do
			local data = captureGrid[gridID]
			if data.allyOwnerID == allyID then
				data.allyOwnerID = gaiaAllyTeamID
				data.progress = math.min(data.progress, STARTING_PROGRESS)
			end
		end
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
				Spring.Echo("allyID: ", allyID, "score: ", score, "defeatThreshold: ", defeatThreshold)
				if allyTeamsWatch[allyID] and score < defeatThreshold then
					triggerAllyDefeat(allyID)
					setAllyGridToGaia(allyID)
					Spring.Echo("Triggering ally defeat for ", allyID, "score: ", score, "defeatThreshold: ", defeatThreshold)
				end
			end
			
			-- Send updated grid data to unsynced
			sendGridToUnsynced()
		end

		if killQueue[frame] then
			for unitID, _ in pairs(killQueue[frame]) do
				Spring.DestroyUnit(unitID, false, true)
			end
			killQueue[frame] = nil
		end
	end

	function gadget:Initialize()
		numberOfSquaresX = math.ceil(mapSizeX / GRID_SIZE)
		numberOfSquaresZ = math.ceil(mapSizeZ / GRID_SIZE)
		captureGrid = generateCaptureGrid()
		updateLivingTeamsData()

		local units = Spring.GetAllUnits()
		for _, unitID in ipairs(units) do
			gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
		end
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
local glBeginEnd = gl.BeginEnd
local GL_QUADS = GL.QUADS

-- Spring functions
local spGetTeamColor = Spring.GetTeamColor
local spGetGameFrame = Spring.GetGameFrame

-- Variables for the squares
local squareOpacity = 0.7
local minimapDrawEnabled = true
local blinkFrame = false  -- Toggle for blinking effect
local LOW_PROGRESS_THRESHOLD = 50  -- Progress threshold for blinking
local BLINK_OPACITY = 0.75 --how much opacity to multiply by when blinking
local BLINK_INTERVAL = Game.gameSpeed * 4
local MAX_OPACITY = 0.15
local MIN_OPACITY = 0.075

-- Get map dimensions
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local GRID_SIZE = 1024 -- Same as in synced code

-- Tables to store grid data from synced
local gridData = {}
local allyTeamIDs = {}
local allyTeamColors = {}
local numberOfSquaresX = 0
local numberOfSquaresZ = 0

-- Function to calculate opacity based on progress
local function getOpacityFromProgress(progress)
    -- Map progress (0-100) to opacity (0.2-0.8)
    return math.max(MIN_OPACITY, (progress / 100) * MAX_OPACITY)
end

-- Function to draw all grid squares on the minimap
local function DrawGridSquares()
	
    -- Get minimap dimensions and position
    local minimapPosX, minimapPosY, minimapSizeX, minimapSizeY = Spring.GetMiniMapGeometry()
    
    -- Calculate the size of one grid square on the minimap
    local gridSquareWidth = (GRID_SIZE / mapSizeX) * minimapSizeX
    local gridSquareHeight = (GRID_SIZE / mapSizeZ) * minimapSizeY
    
    -- Draw each grid square
    for gridID, data in pairs(gridData) do
        local allyOwnerID = data.allyOwnerID
        local progress = data.progress
        local gridX = data.gridX
        local gridZ = data.gridZ
        
        -- Only draw if there's a valid ally team color
        if allyTeamColors[allyOwnerID] then
            -- Get the color for this ally team
            local r = allyTeamColors[allyOwnerID].r
            local g = allyTeamColors[allyOwnerID].g
            local b = allyTeamColors[allyOwnerID].b
            
            -- Calculate opacity based on progress
            local opacity = getOpacityFromProgress(progress)
            
            -- Apply blinking effect for low progress squares by reducing opacity
            if progress < LOW_PROGRESS_THRESHOLD and blinkFrame then
                opacity = opacity * BLINK_OPACITY
            end
            
            -- Set color with opacity
            glColor(r, g, b, opacity)
            
            -- Calculate position on minimap
            local left = minimapPosX + (gridX * GRID_SIZE / mapSizeX) * minimapSizeX
            local top = minimapPosY + minimapSizeY - (gridZ * GRID_SIZE / mapSizeZ) * minimapSizeY
            local right = left + gridSquareWidth
            local bottom = top - gridSquareHeight
            
            -- Draw the rectangle
            glRect(left, top, right, bottom)
        end
    end
    
    -- Reset color to white
    glColor(1, 1, 1, 1)
end

-- Receive grid data from synced
function gadget:RecvFromSynced(cmd, ...)
    local args = {...}
    
    if cmd == "UpdateGridData" then
        -- Reset data structures when receiving new grid data
        gridData = {}
        numberOfSquaresX = args[1]
        numberOfSquaresZ = args[2]
        GRID_SIZE = args[3]
    elseif cmd == "UpdateGridSquare" then
        local gridID = args[1]
        local gridX = args[2]
        local gridZ = args[3]
        local allyOwnerID = args[4]
        local progress = args[5]
        
        gridData[gridID] = {
            gridX = gridX,
            gridZ = gridZ,
            allyOwnerID = allyOwnerID,
            progress = progress
        }
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
end

-- Hook into DrawInMiniMap to draw our grid squares on the minimap
function gadget:DrawInMiniMap(mmsx, mmsy)
    if minimapDrawEnabled and next(gridData) then
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
    minimapDrawEnabled = not minimapDrawEnabled
end

end -- end of UNSYNCED/SYNCED split