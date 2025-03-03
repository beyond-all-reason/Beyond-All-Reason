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
	local spGetUnitTeam = Spring.GetUnitTeam
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
	local playerAllyTeamsWatch = {}
	local hordeAlliesTeamsWatch = {}
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
		playerAllyTeamsWatch = {}  -- Clear existing watch list
		allyTeamIDs = {}    -- Clear ally team IDs list
		teams = Spring.GetTeamList()
		
		-- Rebuild list with living teams and count allies
		for _, teamID in ipairs(teams) do
			local _, _, isDead, _, _, allyTeam = Spring.GetTeamInfo(teamID)
			if isDead then
				teams[teamID] = nil
			elseif not exemptTeams[teamID] then
				playerAllyTeamsWatch[allyTeam] = playerAllyTeamsWatch[allyTeam] or {}
				playerAllyTeamsWatch[allyTeam][teamID] = true
				
				-- Store the first team ID for each ally team
				if not allyTeamIDs[allyTeam] then
					allyTeamIDs[allyTeam] = teamID
				end
			elseif teamID ~= gaiaTeamID then
				hordeAlliesTeamsWatch[allyTeam] = hordeAlliesTeamsWatch[allyTeam] or {}
				hordeAlliesTeamsWatch[allyTeam][teamID] = true
			end
		end
		for allyTeamID, teamIDs in pairs(playerAllyTeamsWatch) do
			allyTeamsCount = allyTeamsCount + 1
		end
		for allyTeamID, teamIDs in pairs(hordeAlliesTeamsWatch) do
			allyTeamsCount = allyTeamsCount + 1
		end
		allyTeamsCount = math.max(allyTeamsCount, 1)
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

	local function lastTwoAlliesAreTied()
		lastAllyScore = 0
		for allyID, score in pairs(allyScores) do
			if score == lastAllyScore then
				return true
			end
			lastAllyScore = score
		end
		return false
	end

	local function updateCurrentDefeatThreshold()
		local seconds = spGetGameSeconds()
		local totalMinutes = seconds / 60  -- Convert seconds to minutes
		if totalMinutes < MINUTES_TO_START or allyTeamsCount == 1 or lastTwoAlliesAreTied() then return end

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
		for teamID, _ in pairs(playerAllyTeamsWatch[allyID]) do
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
				
				if unitData and unitData.power and alyTeam ~= gaiaAllyTeamID then
					data.hasUnits = true
					local power = unitData.power
					if unitWatchDefs[unitDefID].isStatic then
						power = power * 3
					end
					if hordeAlliesTeamsWatch[allyTeam] then
						allyTeam = gaiaAllyTeamID -- horde cannot own land, but can take it away from players
					end
					allyPowers[allyTeam] = (allyPowers[allyTeam] or 0) + power
				end
			end
		end
		if data.hasUnits then
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
		if playerAllyTeamsWatch[data.allyOwnerID] then -- don't return a score for invalid or dead allyTeams
			return data.allyOwnerID
		end
	end

	local function getClearedAllyTallies()
		local allies = {}
		for allyID, teamIDs in pairs(playerAllyTeamsWatch) do
			allies[allyID] = 0
		end
		return allies
	end


	local function getSquareContiguityProgress(gridID)
		local data = captureGrid[gridID]
		
		if data.hasUnits then
			return
		end
		local neighborAllyCounts = {}
		local allyHasUnits = {} -- Track which allies have units in neighboring squares
		local topAllyCount = 0
		local totalCount = 0
		local allyIDToSet
		local HALF = 0.5
		local x = data.gridX
		local z = data.gridZ

		for dx = -1, 1 do
			for dz = -1, 1 do
				if not (dx == 0 and dz == 0) then
					local nx, nz = x + dx, z + dz
					if nx >= 0 and nx < numberOfSquaresX and nz >= 0 and nz < numberOfSquaresZ then
						local neighborID = nx * numberOfSquaresZ + nz + 1
						local neighborData = captureGrid[neighborID]
						
						if neighborData and playerAllyTeamsWatch[neighborData.allyOwnerID] then
							neighborAllyCounts[neighborData.allyOwnerID] = (neighborAllyCounts[neighborData.allyOwnerID] or 0) + 1
							-- Track if this ally has any units in their squares
							if neighborData.hasUnits then
								allyHasUnits[neighborData.allyOwnerID] = true
							end
						end
					end
				end
			end
		end

		for allyID, count in pairs(neighborAllyCounts) do
			if count > topAllyCount and allyHasUnits[allyIDToSet] then
				allyIDToSet = allyID
				topAllyCount = count
			end
			totalCount = totalCount + count
		end

		-- Only proceed if the dominant ally has units in at least one of their squares
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
		for gridID in pairs(grid) do
			table.insert(randomizedIDs, gridID)
		end
		for i = #randomizedIDs, 2, -1 do
			local j = math.random(i)
			randomizedIDs[i], randomizedIDs[j] = randomizedIDs[j], randomizedIDs[i]
		end
		
		return randomizedIDs
	end

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
		
		SendToUnsynced("UpdateGridData", numberOfSquaresX, numberOfSquaresZ, GRID_SIZE)
		
		for gridID, data in pairs(gridData) do
			SendToUnsynced("UpdateGridSquare", gridID, data.gridX, data.gridZ, data.allyOwnerID, data.progress)
		end
		
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

	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if commandersDefs[unitDefID] then
			livingCommanders[unitID] = unitTeam
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		livingCommanders[unitID] = nil
	end

	function gadget:GameFrame(frame)
		if frame % 30 == 0 then
			updateLivingTeamsData()
			local allyTallies = getClearedAllyTallies()

			for gridID, data in pairs(captureGrid) do
				local allyPowers = getAllyPowersInSquare(gridID)
				local winningAllyID, progressChange = getCaptureProgress(gridID, allyPowers)
				if winningAllyID then
					data.ownerAllyID = applyAndGetSquareOwnership(gridID, progressChange, winningAllyID)
				end
				if playerAllyTeamsWatch[data.allyOwnerID] then
					allyTallies[data.allyOwnerID] = allyTallies[data.allyOwnerID] + 1
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
				if playerAllyTeamsWatch[allyID] and score < defeatThreshold then
					triggerAllyDefeat(allyID)
					setAllyGridToGaia(allyID)
				end
			end
			updateCurrentDefeatThreshold()
			
			sendGridToUnsynced()
			
			-- Send all ally scores to unsynced
			for allyID, score in pairs(allyScores) do
				if playerAllyTeamsWatch[allyID] then
					SendToUnsynced("UpdateScore", allyID, score, defeatThreshold)
				end
			end
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

else
	-- UNSYNCED CODE

	local glColor = gl.Color
	local glRect = gl.Rect
	local glPushMatrix = gl.PushMatrix
	local glPopMatrix = gl.PopMatrix
	local glTranslate = gl.Translate
	local glBeginEnd = gl.BeginEnd
	local glText = gl.Text
	local GL_QUADS = GL.QUADS

	local spGetTeamColor = Spring.GetTeamColor
	local spGetGameFrame = Spring.GetGameFrame
	local spGetMyAllyTeamID = Spring.GetMyAllyTeamID

	local minimapDrawEnabled = true
	local blinkFrame = false  -- Toggle for blinking effect
	local LOW_PROGRESS_THRESHOLD = 50  -- Progress threshold for blinking
	local BLINK_OPACITY = 0.75 --how much opacity to multiply by when blinking
	local BLINK_INTERVAL = Game.gameSpeed * 4
	local MAX_OPACITY = 0.15
	local MIN_OPACITY = 0.075

	local WARNING_THRESHOLD = 5 -- points within threshold to trigger warning
	local DARK_RED = {0.7, 0, 0, 1}
	local LIGHT_RED = {0.9, 0, 0, 1}
	local NORMAL_COLOR = {1, 1, 1, 1}

	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ
	local GRID_SIZE = 1024 -- must be same as in synced code

	local gridData = {}
	local allyTeamIDs = {}
	local allyTeamColors = {}
	local numberOfSquaresX = 0
	local numberOfSquaresZ = 0
	local currentScore = 0
	local currentThreshold = 0
	local allyScores = {} -- Table to store scores for each ally team

	local function DrawScoreDisplay()
		local minimapPosX, minimapPosY, minimapSizeX, minimapSizeY = Spring.GetMiniMapGeometry()
		local myAllyTeamID = spGetMyAllyTeamID()
		local score = allyScores[myAllyTeamID] or 0
		
		local baseX = minimapPosX + 2
		local baseY = minimapPosY - 16
		
		local scoreText = string.format("Territories: %d", score)
		local thresholdText = string.format("Required: %d", currentThreshold)
		
		local isWarning = math.abs(score - currentThreshold) <= WARNING_THRESHOLD
		local color = isWarning and (blinkFrame and LIGHT_RED or DARK_RED) or NORMAL_COLOR
		
		glColor(color)
		glText(scoreText, baseX, baseY, 16, "o")
		
		glColor(NORMAL_COLOR)
		glText(thresholdText, baseX + 150, baseY, 16, "o")
	end

	local function getOpacityFromProgress(progress)
		return math.max(MIN_OPACITY, (progress / 100) * MAX_OPACITY)
	end

	local function DrawGridSquares()
		
		local minimapPosX, minimapPosY, minimapSizeX, minimapSizeY = Spring.GetMiniMapGeometry()
		
		local gridSquareWidth = (GRID_SIZE / mapSizeX) * minimapSizeX
		local gridSquareHeight = (GRID_SIZE / mapSizeZ) * minimapSizeY
		
		for gridID, data in pairs(gridData) do
			local allyOwnerID = data.allyOwnerID
			local progress = data.progress
			local gridX = data.gridX
			local gridZ = data.gridZ
			
			if allyTeamColors[allyOwnerID] then
				local r = allyTeamColors[allyOwnerID].r
				local g = allyTeamColors[allyOwnerID].g
				local b = allyTeamColors[allyOwnerID].b
				
				local opacity = getOpacityFromProgress(progress)
				
				if progress < LOW_PROGRESS_THRESHOLD and blinkFrame then
					opacity = opacity * BLINK_OPACITY
				end
				
				glColor(r, g, b, opacity)
				
				local left = minimapPosX + (gridX * GRID_SIZE / mapSizeX) * minimapSizeX
				local top = minimapPosY + minimapSizeY - (gridZ * GRID_SIZE / mapSizeZ) * minimapSizeY
				local right = left + gridSquareWidth
				local bottom = top - gridSquareHeight
				
				glRect(left, top, right, bottom)
			end
		end
		
		glColor(1, 1, 1, 1)
	end

	function gadget:RecvFromSynced(cmd, ...)
		local args = {...}
		
		if cmd == "UpdateGridData" then
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
			
			local r, g, b = spGetTeamColor(teamID)
			allyTeamColors[allyTeamID] = {r = r, g = g, b = b}
		elseif cmd == "UpdateScore" then
			local allyID = args[1]
			local score = args[2]
			local threshold = args[3]
			allyScores[allyID] = score
			currentThreshold = threshold
		end
	end

	local updateFrame = 0
	function gadget:Update()
		updateFrame = updateFrame + 1
		if updateFrame % BLINK_INTERVAL == 0 then
			blinkFrame = not blinkFrame
		end
	end

	function gadget:DrawScreen()
		DrawScoreDisplay()
	end

	function gadget:DrawInMiniMap(mmsx, mmsy)
		if minimapDrawEnabled and next(gridData) then
			glPushMatrix()
			DrawGridSquares()
			glPopMatrix()
		end
	end

	function gadget:ToggleMinimapDraw()
		minimapDrawEnabled = not minimapDrawEnabled
	end
end