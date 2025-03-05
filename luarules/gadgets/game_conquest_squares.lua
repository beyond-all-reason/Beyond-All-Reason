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
	local debugmode = true
	local MINUTES_TO_MAX = 20 --how many minutes until the threshold reaches max threshold from start time
	local MINUTES_TO_START = 5 --how many minutes until threshold can start to increment
	local MAX_TERRITORY_PERCENTAGE = 100 --how much territory/# of allies is factored in to bombardment threshold.
	local MAX_PROGRESS = 100 --how much progress a square can have
	local PROGRESS_INCREMENT = 3 --how much progress a square gains per frame
	local CONTIGUOUS_PROGRESS_INCREMENT = 1 --how much progress a square gains per calculation when it's contiguous
	local DECAY_PROGRESS_INCREMENT = 0.5 --how much progress a square loses per calculation when it's not contiguous or has units
	local STATIC_POWER_MULTIPLIER = 3 --how much more conquest-power static units have over mobile units
	local SQUARE_CHECK_INTERVAL = Game.gameSpeed
	local DECAY_DELAY_FRAMES = Game.gameSpeed * 10 -- how long before progress gained begins to be lost


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
	local STARTING_PROGRESS = 0
	local OWNERSHIP_THRESHOLD = 33


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
					decayDelay = 0,
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
			for unitID, unitTeam in pairs(livingCommanders) do
				if unitTeam == teamID then
					queueCommanderTeleportRetreat(unitID)
				end
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
		for allyID, teamIDs in pairs(allyTeamsWatch) do
			allies[allyID] = 0
		end
		return allies
	end

	local function getSquareContiguityProgress(gridID)
		local currentSquareData = captureGrid[gridID]
		
		-- Skip if this square has units or is owned by Gaia
		if currentSquareData.hasUnits then
			return
		end
		
		local neighborAllyTeamCounts = {}
		local dominantAllyTeamCount = 0
		local totalNeighborCount = 0
		local MAJORITY_THRESHOLD = 0.5
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
		-- Only send static grid structure data once during initialization
		if not sentGridStructure then
			SendToUnsynced("UpdateGridStructure", numberOfSquaresX, numberOfSquaresZ, GRID_SIZE)
			
			-- Send static grid position data
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
			local cachedData = cachedGridData[gridID] or {allyOwnerID = -1, progress = -1}
			
			-- Only send if data has changed
			if data.allyOwnerID ~= cachedData.allyOwnerID or data.progress ~= cachedData.progress then
				SendToUnsynced("UpdateGridState", gridID, data.allyOwnerID, data.progress)
				
				-- Update cache
				cachedGridData[gridID] = {
					allyOwnerID = data.allyOwnerID,
					progress = data.progress
				}
			end
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

	local function decayProgress(gridID)
		local data = captureGrid[gridID]
		if data.progress > OWNERSHIP_THRESHOLD then
			applyProgress(gridID, DECAY_PROGRESS_INCREMENT, data.allyOwnerID)
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

		if frame % SQUARE_CHECK_INTERVAL == 0 then
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

				if debugmode and 1 == 2 then --to show origins of each square
					Spring.SpawnCEG("scaspawn-trail", data.x, Spring.GetGroundHeight(data.x, data.z), data.z, 0,0,0)
					Spring.SpawnCEG("scav-spawnexplo", data.x, Spring.GetGroundHeight(data.x, data.z), data.z, 0,0,0)
					if allyTeamsWatch[data.allyOwnerID] then
						Spring.SpawnCEG(debugOwnershipCegs[data.allyOwnerID], data.middleX, Spring.GetGroundHeight(data.middleX, data.middleZ), data.middleZ, 0,0,0)
					end
				end
			end
		end
		if frame % SQUARE_CHECK_INTERVAL == 1 then

			local randomizedGridIDs = getRandomizedGridIDs(captureGrid)
			for _, gridID in ipairs(randomizedGridIDs) do
				local contiguousAllyID, progressChange = getSquareContiguityProgress(gridID)
				if contiguousAllyID then
					applyProgress(gridID, progressChange, contiguousAllyID)
				end
			end

			for gridID, data in pairs(captureGrid) do
				if data.decayDelay < frame and data.progress < MAX_PROGRESS then
					decayProgress(gridID)
				end
			end
		end

		if frame % SQUARE_CHECK_INTERVAL == 2 then
			allyScores = convertTalliesToScores(allyTallies)
			for allyID, score in pairs(allyScores) do
				if allyTeamsWatch[allyID] and score < defeatThreshold and not debugmode then
					triggerAllyDefeat(allyID)
					setAllyGridToGaia(allyID)
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
		
		-- Initialize caching variables
		sentGridStructure = false
		sentAllyTeams = {}
		cachedGridData = {}

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
local allyTeamIDs = {}
local allyTeamColors = {}
local numberOfSquaresX = 0
local numberOfSquaresZ = 0

-- Function to calculate opacity based on progress

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
            
            -- Apply color shifting for blinking effect (shift towards white by 0.3)
            if progress < MAX_PROGRESS and progress >= OWNERSHIP_THRESHOLD and blinkFrame then
                r = r + 0.3 * (1 - r)
                g = g + 0.3 * (1 - g)
                b = b + 0.3 * (1 - b)
            end
            
            -- Set color with opacity
            glColor(r, g, b, MINIMAP_SQUARE_OPACITY)
            
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
    
    if cmd == "UpdateGridStructure" then
        -- Receive static grid structure data (once)
        numberOfSquaresX = args[1]
        numberOfSquaresZ = args[2]
        GRID_SIZE = args[3]
        
        -- Reset data structures when receiving new grid data
        gridData = {}
    elseif cmd == "InitGridSquare" then
        -- Initialize a grid square with static position data (once)
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
            allyOwnerID = 0,  -- Default values
            progress = 0      -- Default values
        }
    elseif cmd == "UpdateGridState" then
        -- Update only the changing state of a grid square (frequent)
        local gridID = args[1]
        local allyOwnerID = args[2]
        local progress = args[3]
        
        -- Only update if the grid square exists
        if gridData[gridID] then
            gridData[gridID].allyOwnerID = allyOwnerID
            gridData[gridID].progress = progress
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