function gadget:GetInfo()
	return {
		name = "Unit In Square Tracker",
		desc = "Cuts the map into squares and tracks which squares units are in",
		author = "SethDGamre",
		date = "2025.02.08",
		license = "GNU GPL, v2 or later",
		layer = -10,
		enabled = true,
		depends   = {'gl4'},
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
--unsynced code

-- Include necessary files
local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

--testing variables
local TEST_SPEED = 1
local TEST_SQUARE_COUNT = 7
local TEST_PROGRESS_RATE = 0.03

--constants
local SQUARE_SIZE = 1024

local SQUARE_ALPHA = 0.4

--team stuff
local myAllyID = select(6, Spring.GetTeamInfo(Spring.GetMyTeamID()))
local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID()))
local teams = Spring.GetTeamList()

--colors
local blankColor = {0.5, 0.5, 0.5, 0.0} -- grey and transparent for gaia
local enemyColor = {1, 0, 0, SQUARE_ALPHA} -- red for enemy
local alliedColor = {0, 1, 0, SQUARE_ALPHA} -- green for ally

local allyColors = {}
for _, teamID in ipairs(teams) do
local allyID = select(6, Spring.GetTeamInfo(teamID))-- Store the first team color for each ally team
	if allyID then
		if not allyColors[allyID] and allyID ~= gaiaAllyTeamID then
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
	{id = 3, name = 'takercolor', size = 4}, -- vec4 the color of this new
	{id = 4, name = 'capturestate', size = 4}, -- vec4 progress, speed
}
local glDepthTest = gl.DepthTest
local glTexture = gl.Texture
local random = math.random
local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ

-- Constants
local SQUARE_HEIGHT = 20
local MOVE_INTERVAL = 60

local squareVBO = nil
local squareVAO = nil
local squareShader = nil
local instanceVBO = nil
local lastMoveFrame = 0

local vsSrc = [[
#version 420
#extension GL_ARB_shading_language_420pack: require

layout (location = 0) in vec4 position;
layout (location = 1) in vec4 posscale;
layout (location = 2) in vec4 color1;
layout (location = 3) in vec4 visibility;
layout (location = 4) in vec4 capturestate;

uniform sampler2D heightmapTex;
uniform float gameFrame;
uniform int isMinimapRendering;
uniform float mapSizeX;
uniform float mapSizeZ;

out DataVS {
	vec4 color;
	float progress;
	vec2 texCoord;
};

//__ENGINEUNIFORMBUFFERDEFS__

void main() {
	// Pass color without pulsing effect
	color = color1;
	
	// Pass progress for visualization
	progress = capturestate.y;
	
	// Generate texture coordinates for the circle effect
	texCoord = position.xy * 0.5 + 0.5; // Convert from [-1,1] to [0,1]
	
	if (isMinimapRendering == 1) {
		// Minimap rendering mode
		// Scale position to minimap coordinates (0-1)
		vec2 minimapPos = (posscale.xz / vec2(mapSizeX, mapSizeZ));
		vec2 squareSize = vec2(posscale.w / mapSizeX, posscale.w / mapSizeZ);
		
		// Calculate vertex position in minimap space
		vec2 vertexPos = position.xy * squareSize + minimapPos;
		
		// Keep full minimap coordinates (0-1)
		gl_Position = vec4(vertexPos.x * 2.0 - 1.0, 1.0 - vertexPos.y * 2.0, 0.0, 1.0);
	} else {
		// World rendering mode
		// Use position.y as Z coordinate since makePlaneVBO creates X-Y plane
		vec4 worldPos = vec4(position.x * posscale.w, 0.0, position.y * posscale.w, 1.0);
		worldPos.xz += posscale.xz;
		
		// Get height from heightmap
		vec2 uvhm = heightmapUVatWorldPos(worldPos.xz);
		float terrainHeight = textureLod(heightmapTex, uvhm, 0.0).x;
		
		// Set Y position to be terrain height plus offset
		worldPos.y = terrainHeight + posscale.y;
		
		// Transform to clip space
		gl_Position = cameraViewProj * worldPos;
	}
}
]]

-- Fragment shader source
local fsSrc = [[
#version 420
#extension GL_ARB_shading_language_420pack: require

in DataVS {
	vec4 color;
	float progress;
	vec2 texCoord;
};

out vec4 fragColor;

void main() {
	// Calculate center and corner distances
	vec2 center = vec2(0.5, 0.5);
	float distance = length(texCoord - center) * 2.0; // Distance from center, normalized
	
	// Maximum distance is to the corner which is sqrt(2) * 0.5 * 2 = sqrt(2)
	// So we scale our progress to reach 1.0 at the corner
	float cornerDistance = sqrt(2.0); // Distance from center to corner in our normalized space
	float scaledProgress = progress * cornerDistance; // Scale progress to reach corners at 100%
	
	// Parameters for square border fade
	float borderMaxWidth = 0.05; // Full width where border effect applies
	float borderFadeDistance = 16.0 / 1024.0; // Fade distance converted to texture space (16 units / square size)
	
	// Parameters for square edge glow
	float edgeWidth = 0.05; // Width of the edge glow
	
	// Calculate how close we are to any edge of the square
	float distToEdgeX = min(texCoord.x, 1.0 - texCoord.x);
	float distToEdgeY = min(texCoord.y, 1.0 - texCoord.y);
	float distToEdge = min(distToEdgeX, distToEdgeY);
	
	// Calculate border opacity with fade effect
	float borderOpacity = 0.0;
	if (distToEdge < borderFadeDistance) {
		// Linear fade from edge (1.0) to inner distance (0.0)
		borderOpacity = 1.0 - (distToEdge / borderFadeDistance);
	}
	
	// Determine base color
	vec4 baseColor;
	if (distance < scaledProgress) {
		// Inside progress circle - use team color with full opacity
		baseColor = color;
	} else if (borderOpacity > 0.0) {
		// In border area - apply calculated fade
		baseColor = vec4(color.rgb, color.a * 0.6 * borderOpacity);
	} else {
		// Outside progress circle and not in border - completely transparent
		baseColor = vec4(0.0, 0.0, 0.0, 0.0);
	}
	
	// Calculate edge glow intensity (only applied inside the progress circle)
	float edgeIntensity = 0.0;
	if (distToEdge < edgeWidth && distance < scaledProgress) {
		// Fade based on distance to edge
		edgeIntensity = 1.0 - (distToEdge / edgeWidth);
		
		// Scale edge intensity by progress to make it "grow" with capture
		edgeIntensity *= progress;
	}
	
	// Apply edge glow if needed
	if (edgeIntensity > 0.0) {
		vec3 glowColor = mix(color.rgb, vec3(1.0), 0.3); // Mix with white for glow
		fragColor = mix(baseColor, vec4(glowColor, color.a), edgeIntensity);
	} else {
		fragColor = baseColor;
	}
}
]]

local function makeShader()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	local vsShader = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	local fsShader = fsSrc
	
	squareShader = LuaShader({
		vertex = vsShader,
		fragment = fsShader,
		uniformInt = {
			heightmapTex = 0,
			isMinimapRendering = 0,
		},
		uniformFloat = {
			gameFrame = 0,
			mapSizeX = Game.mapSizeX,
			mapSizeZ = Game.mapSizeZ,
		},
	}, "testSquareShader")
	
	local shaderCompiled = squareShader:Initialize()
	if not shaderCompiled then
		Spring.Echo("Failed to compile testSquareShader")
		return false
	end
	return true
end

local function makeSquareVBO(xsize, ysize, xresolution, yresolution)
	-- Default parameter handling
	if not xsize then xsize = 1 end
	if not ysize then ysize = xsize end
	if not xresolution then xresolution = 1 end
	if not yresolution then yresolution = xresolution end
	
	xresolution = math.floor(xresolution)
	yresolution = math.floor(yresolution)
	
	-- Create vertex buffer
	local squareVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	if squareVBO == nil then return nil end
	
	-- Define the layout - using position only since that's what the shader expects
	local VBOLayout = {
		{id = 0, name = "position", size = 4},
	}
	
	local vertexData = {}
	
	-- Generate vertices for a grid of triangles
	-- We'll create 2 triangles per grid cell, forming 6 vertices total
	local vertexCount = 0
	
	for x = 0, xresolution do
		for y = 0, yresolution do
			-- Calculate normalized position [-1 to 1]
			local xPos = xsize * ((x / xresolution) - 0.5) * 2
			local yPos = ysize * ((y / yresolution) - 0.5) * 2
			
			-- Add vertex with position and placeholder values
			vertexData[#vertexData + 1] = xPos  -- x
			vertexData[#vertexData + 1] = yPos  -- y (used as z in the shader)
			vertexData[#vertexData + 1] = 0     -- z (unused)
			vertexData[#vertexData + 1] = 1     -- w
			
			vertexCount = vertexCount + 1
		end
	end
	
	-- Create index data for triangles
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
	
	-- Define and upload vertex data
	squareVBO:Define((xresolution + 1) * (yresolution + 1), VBOLayout)
	squareVBO:Upload(vertexData)
	
	-- Create index buffer
	local squareIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	if squareIndexVBO == nil then 
		squareVBO:Delete()
		return nil 
	end
	
	-- Define and upload index data
	squareIndexVBO:Define(#indexData)
	squareIndexVBO:Upload(indexData)
	
	return squareVBO, (xresolution + 1) * (yresolution + 1), squareIndexVBO, #indexData
end

local function initGL4()
	-- Create square VBO with index buffer - increased resolution to 10x10
	local squareVBO, numVertices, squareIndexVBO, numIndices = makeSquareVBO(1, 1, 32, 32)
	if not squareVBO then return false end
	
	instanceVBO = makeInstanceVBOTable(planeLayout, 16, "test_square_shader")
	instanceVBO.vertexVBO = squareVBO
	instanceVBO.indexVBO = squareIndexVBO
	instanceVBO.numVertices = numIndices
	instanceVBO.primitiveType = GL.TRIANGLES
	
	-- Attach both vertex and index buffers
	squareVAO = makeVAOandAttach(squareVBO, instanceVBO.instanceVBO, squareIndexVBO)
	instanceVBO.VAO = squareVAO
	
	for i = 1, TEST_SQUARE_COUNT do
		local randomX = random(SQUARE_SIZE, mapSizeX - SQUARE_SIZE)
		local randomZ = random(SQUARE_SIZE, mapSizeZ - SQUARE_SIZE)
		
		local instanceData = {
			randomX, SQUARE_HEIGHT, randomZ, SQUARE_SIZE,  -- posscale: x, y, z, scale
			random(), random(), random(), 0.8,             -- color1: r, g, b, a
			2000, 5000, 0.8, 0.2,                         -- visibility: fadeStart, fadeEnd, minAlpha, maxAlpha
			1.0, 0.0, 0.0, 0.0                            -- capturestate: blinking, progress, unused, unused
		}
		
		pushElementInstance(instanceVBO, instanceData, i, true, false)
	end
	uploadAllElements(instanceVBO)
	return makeShader()
end

-- Initialize the gadget
function gadget:Initialize()
	if initGL4() == false then
		gadgetHandler:RemoveGadget()
		return
	end
	
	Spring.Echo("Test Shader Square initialized successfully")
end

-- Update the shader parameters
function gadget:Update()
	local currentFrame = Spring.GetGameFrame()
	
	if currentFrame > 0 and currentFrame % MOVE_INTERVAL == 0 and currentFrame ~= lastMoveFrame then
		local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ
		
		for i = 1, TEST_SQUARE_COUNT do
			local instanceData = getElementInstanceData(instanceVBO, i)
			if instanceData then
				-- Randomize position
				local randomX = random(SQUARE_SIZE, mapSizeX - SQUARE_SIZE)
				local randomZ = random(SQUARE_SIZE, mapSizeZ - SQUARE_SIZE)
				
				-- Randomize color (r,g,b values at indices 5,6,7)
				local randomR = random(0, 1)
				local randomG = random(0, 1)
				local randomB = random(0, 1)
				
				-- Randomize progress (at index 14)
				local randomProgress = random()
				
				-- Update position (first 3 elements in posscale)
				instanceData[1] = randomX
				instanceData[3] = randomZ
				
				-- Update color (elements 5-7 in color1)
				instanceData[5] = randomR
				instanceData[6] = randomG
				instanceData[7] = randomB
				
				-- Keep alpha consistent
				instanceData[8] = SQUARE_ALPHA
				
				-- We don't need the visibility parameters for blinking anymore,
				-- but keep them in the structure to avoid breaking the data layout
				
				-- Update progress (2nd element in capturestate)
				instanceData[14] = randomProgress
				
				pushElementInstance(instanceVBO, instanceData, i, true)
			end
		end
		
		uploadAllElements(instanceVBO)
		lastMoveFrame = currentFrame
	end
end

-- Draw the square in world view
function gadget:DrawWorldPreUnit()
	if not squareShader or not squareVAO or not instanceVBO then return end
	
	glTexture(0, "$heightmap")
	glDepthTest(true)
	
	squareShader:Activate()
	squareShader:SetUniform("gameFrame", Spring.GetGameFrame())
	squareShader:SetUniformInt("isMinimapRendering", 0)
	
	-- Draw the square using indexed triangles
	instanceVBO.VAO:DrawElements(GL.TRIANGLES, instanceVBO.numVertices, 0, instanceVBO.usedElements)
	
	squareShader:Deactivate()
	glTexture(0, false)
	glDepthTest(false)
end

-- Draw on minimap using the same shader with a flag
function gadget:DrawInMiniMap()
	if not squareShader or not squareVAO or not instanceVBO then return end
	
	squareShader:Activate()
	squareShader:SetUniform("gameFrame", Spring.GetGameFrame())
	squareShader:SetUniformInt("isMinimapRendering", 1)
	
	-- Draw the square using indexed triangles
	instanceVBO.VAO:DrawElements(GL.TRIANGLES, instanceVBO.numVertices, 0, instanceVBO.usedElements)
	
	squareShader:Deactivate()
end

-- Clean up
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