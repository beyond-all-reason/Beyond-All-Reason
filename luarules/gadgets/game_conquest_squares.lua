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

-- TODO:
-- when there's one team left (including scavengers and raptors) then set the victory threshold to 0% and stop further increases
-- need the captured territory display to show at all times, by passing the values through initialize?
-- need to do the modoptions
-- code cleanup
--	try to improve efficiency of text drawing
-- improve time to max accuracy, seems to be a few minutes late every time
-- need minimum power to ratio power occupying a square to slow its capture rate
-- obfuscate ally color when not spectating
-- flip minimap needs to be implemented

local SYNCED = gadgetHandler:IsSyncedCode()

if SYNCED then
-- SYNCED CODE

	--configs
	local DEBUGMODE = false -- Changed to uppercase as it's a constant
	local FLYING_UNIT_POWER_MULTIPLIER = 0.33
	local STATIC_UNIT_POWER_MULTIPLIER = 3
	local MINUTES_TO_MAX = 20
	local MINUTES_TO_START = 5
	local MAX_TERRITORY_PERCENTAGE = 100
	local MAX_PROGRESS = 1.0
	local PROGRESS_INCREMENT = 0.06
	local CONTIGUOUS_PROGRESS_INCREMENT = 0.03
	local DECAY_PROGRESS_INCREMENT = 0.03
	local STATIC_POWER_MULTIPLIER = 3
	local GRID_CHECK_INTERVAL = Game.gameSpeed
	local DECAY_DELAY_FRAMES = Game.gameSpeed * 10
	local GRID_SIZE = 1024
	local FINISHED_BUILDING = 1
	local STARTING_PROGRESS = 0
	local CORNER_MULTIPLIER = 1.4142135623730951
	local OWNERSHIP_THRESHOLD = MAX_PROGRESS / CORNER_MULTIPLIER -- full progress is when the circle drawn within the square reaches the corner, ownership is achieved when it touches the edge.
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
	local flyingUnits = {}

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

				data.mapOriginX = originX
				data.mapOriginZ = originZ
				data.gridX = x
				data.gridZ = z
				data.gridMidpointX = originX + GRID_SIZE / 2
				data.gridMidpointZ = originZ + GRID_SIZE / 2
				data.allyOwnerID = gaiaAllyTeamID
				data.progress = STARTING_PROGRESS
				data.hasUnits = false
				data.decayDelay = 0
			end
		end
		return gridData
	end

	local function updateCurrentDefeatThreshold()
		local seconds = spGetGameSeconds()
		local totalMinutes = seconds / 60  -- Convert seconds to minutes
		local elapsedMinutes = totalMinutes - MINUTES_TO_START
		local wantFactor = elapsedMinutes / MINUTES_TO_MAX -- exponential defeat threshold to try to prolong the game closer to the max time
		if totalMinutes < MINUTES_TO_START then return end

		local progressRatio = min(elapsedMinutes / MINUTES_TO_MAX, 1)
		local wantedThreshold = ((progressRatio * MAX_TERRITORY_PERCENTAGE) / allyTeamsCount) * wantFactor
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

	local function getAllyPowersInSquare(gridID)
		local data = captureGrid[gridID]
		local units = spGetUnitsInRectangle(data.mapOriginX, data.mapOriginZ, data.mapOriginX + GRID_SIZE, data.mapOriginZ + GRID_SIZE)
		
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
						power = power * STATIC_UNIT_POWER_MULTIPLIER
					end
					if flyingUnits[unitID] then
						power = power * FLYING_UNIT_POWER_MULTIPLIER
					end
					allyPowers[allyTeam] = (allyPowers[allyTeam] or 0) + power
				end
			end
		end

		for allyID, power in pairs(allyPowers) do
			power = power + random() -- randomize power to prevent ties
		end
		
		if data.hasUnits then
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

	local function applyProgress(gridID, progressChange, winningAllyID, delayDecay)
		local data = captureGrid[gridID]
		local newProgress = data.progress + progressChange
		
		if newProgress < 0 then
			data.allyOwnerID = winningAllyID
			if winningAllyID == gaiaAllyTeamID then
				data.progress = 0
			else
				data.progress = math.abs(newProgress)
			end
		elseif newProgress > MAX_PROGRESS then
			data.progress = MAX_PROGRESS
		else
			data.progress = newProgress
		end

		if delayDecay then
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
			SendToUnsynced("InitializeGridSquare", gridID, data.allyOwnerID, data.progress, data.gridMidpointX, data.gridMidpointZ)
		end
	end

	local function updateUnsyncedSquare(gridID)
		local data = captureGrid[gridID]
		
		SendToUnsynced("UpdateGridSquare", gridID, data.allyOwnerID, data.progress)
	end

	local function updateUnsyncedScore(allyID, score)
		SendToUnsynced("UpdateAllyScore", allyID, score, defeatThreshold)
	end

	local function setAllyGridToGaia(allyID)
		for gridID, data in pairs(captureGrid) do
			if data.allyOwnerID == allyID then
				data.allyOwnerID = gaiaAllyTeamID
				data.progress = STARTING_PROGRESS
			end
		end
	end

	local function decayProgress(gridID)
		local data = captureGrid[gridID]
		if data.progress > OWNERSHIP_THRESHOLD then
			applyProgress(gridID, DECAY_PROGRESS_INCREMENT, data.allyOwnerID, false)
		else
			applyProgress(gridID, -DECAY_PROGRESS_INCREMENT, gaiaAllyTeamID, false)
		end
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if commandersDefs[unitDefID] then
			livingCommanders[unitID] = unitTeam
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

	function gadget:GameFrame(frame)
		gameFrame = frame
		local frameModulo = frame % GRID_CHECK_INTERVAL

		if frameModulo == 0 then
			updateLivingTeamsData()
			updateCurrentDefeatThreshold()
			allyTallies = getClearedAllyTallies()

			for gridID, data in pairs(captureGrid) do
				local allyPowers = getAllyPowersInSquare(gridID)
				local winningAllyID, progressChange = getCaptureProgress(gridID, allyPowers)
				if winningAllyID then
					applyProgress(gridID, progressChange, winningAllyID, true)
				end
				if allyTeamsWatch[data.allyOwnerID] and data.progress > OWNERSHIP_THRESHOLD then
					allyTallies[data.allyOwnerID] = allyTallies[data.allyOwnerID] + 1
				end
			end
		elseif frameModulo == 1 then
			local randomizedIDs = getRandomizedGridIDs()
			for i = 1, #randomizedIDs do
				local gridID = randomizedIDs[i]
				local contiguousAllyID, progressChange = getSquareContiguityProgress(gridID)
				if contiguousAllyID and progressChange ~= 0 then
					applyProgress(gridID, progressChange, contiguousAllyID, true)
				end
			end

			for gridID, data in pairs(captureGrid) do
				if data.decayDelay < frame then
					decayProgress(gridID)
				end
				updateUnsyncedSquare(gridID)
			end
		elseif frameModulo == 2 then
			allyScores = convertTalliesToScores(allyTallies)
			local averageScore = 0
			local count = 0
			for allyID, score in pairs(allyScores) do
				averageScore = averageScore + score
				count = count + 1
			end
			if count > 0 then
				averageScore = averageScore / count
				for allyID, score in pairs(allyScores) do
					updateUnsyncedScore(allyID, score)
					if allyTeamsWatch[allyID] and score < defeatThreshold and score < averageScore and not DEBUGMODE then
						--check if score is below average score to prevent defeat in case of a tie
						triggerAllyDefeat(allyID)
						setAllyGridToGaia(allyID)
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
		captureGrid = generateCaptureGrid()
		updateLivingTeamsData()

		local units = Spring.GetAllUnits()
		for i = 1, #units do
			local unitID = units[i]
			gadget:UnitCreated(unitID, spGetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
		end
	end

else
--unsynced code

-- Include necessary files
local luaShaderDir = "LuaUI/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

--testing variables
local TEST_SPEED = 0.25
local TEST_SQUARE_COUNT = 7
local UNSYNCED_DEBUG_MODE = false

--constants
local SQUARE_SIZE = 1024  -- Match GRID_SIZE from synced part
local SQUARE_ALPHA = 0.2
local SQUARE_HEIGHT = 20
local UPDATE_FRAME_RATE_INTERVAL = Game.gameSpeed

--tables
local captureGrid = {}
local allyScores = {}

--team stuff
local myAllyID = select(6, Spring.GetTeamInfo(Spring.GetMyTeamID()))
local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID()))
local teams = Spring.GetTeamList()
local defeatThreshold = 0

-- Add font rendering variables
local minimapSizeX, minimapSizeY = 0, 0
local minimapPosX, minimapPosY = 0, 0
local fontSizeMultiplier = 1
local fontSize = 14
local lastWarningBlinkTime = 0
local isWarningVisible = true
local BLINK_FREQUENCY = 0.5  -- seconds
local WARNING_THRESHOLD = 5  -- blink red if within 5 points of defeat

-- Font color constants
local COLOR_WHITE = {1, 1, 1, 1}
local COLOR_RED = {1, 0, 0, 1}
local COLOR_YELLOW = {1, 0.8, 0, 1}  -- Yellow for getting close to threshold
local COLOR_BG = {0, 0, 0, 0.6}  -- Semi-transparent black background

--colors
local blankColor = {0.5, 0.5, 0.5, 0.0} -- grey and transparent for gaia
local enemyColor = {1, 0, 0, SQUARE_ALPHA} -- red for enemy
local alliedColor = {0, 1, 0, SQUARE_ALPHA} -- green for ally

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
	{id = 3, name = 'capturestate', size = 4}, -- vec4 speed, progress, startframe, unused
}
local glDepthTest = gl.DepthTest
local glTexture = gl.Texture
local random = math.random
local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ

local squareVBO = nil
local squareVAO = nil
local squareShader = nil
local instanceVBO = nil
local lastMoveFrame = 0

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

layout (location = 0) in vec4 position;
layout (location = 1) in vec4 posscale; // x, y, z, scale
layout (location = 2) in vec4 color1; // r, g, b, a
layout (location = 3) in vec4 capturestate; // speed, progress, startframe, unused

uniform sampler2D heightmapTex;
uniform int isMinimapRendering;
uniform float mapSizeX;
uniform float mapSizeZ;
uniform float minCameraDrawHeight;
uniform float maxCameraDrawHeight;
uniform float updateFrameRateInterval;


out DataVS {
	vec4 color;
	float progress;
	float speed;
	float startframe;
	float gameFrame;
	vec2 texCoord;
	float cameraDist;  // Add camera distance to the output struct
	float inMinimap;
	float minCamHeight;
	float maxCamHeight;
	float updateFrameInterval;
};

void main() {
	// Pass color without pulsing effect
	color = color1;
	
	// Pass progress for visualization
	speed = capturestate.x;
	progress = capturestate.y;
	
	// Generate texture coordinates for the circle effect
	texCoord = position.xy * 0.5 + 0.5; // Convert from [-1,1] to [0,1]
	
	// Calculate camera distance
	vec3 cameraPos = cameraViewInv[3].xyz;
	cameraDist = length(cameraPos);
	
	if (isMinimapRendering == 1) {
		// Minimap rendering mode
		// Scale position to minimap coordinates (0-1)
		vec2 minimapPos = (posscale.xz / vec2(mapSizeX, mapSizeZ));
		vec2 squareSize = vec2(posscale.w / mapSizeX, posscale.w / mapSizeZ) * 0.5;  // Added 0.5 scaling factor
		
		// Calculate vertex position in minimap space
		vec2 vertexPos = position.xy * squareSize + minimapPos;
		
		// Keep full minimap coordinates (0-1)
		gl_Position = vec4(vertexPos.x * 2.0 - 1.0, 1.0 - vertexPos.y * 2.0, 0.0, 1.0);
		inMinimap = 1;
	} else {
		// World rendering mode
		// Use position.y as Z coordinate since makePlaneVBO creates X-Y plane
		vec4 worldPos = vec4(position.x * posscale.w * 0.5, 0.0, position.y * posscale.w * 0.5, 1.0);  // Multiply by 0.5 to fix scaling
		worldPos.xz += posscale.xz;
		
		// Get height from heightmap
		vec2 uvhm = heightmapUVatWorldPos(worldPos.xz);
		float terrainHeight = textureLod(heightmapTex, uvhm, 0.0).x;
		
		// Set Y position to be terrain height plus offset
		worldPos.y = terrainHeight + posscale.y;
		
		// Transform to clip space
		gl_Position = cameraViewProj * worldPos;
		inMinimap = 0;
	}
	
	startframe = capturestate.z;
	gameFrame = timeInfo.x;
	minCamHeight = minCameraDrawHeight;
	maxCamHeight = maxCameraDrawHeight;
	updateFrameInterval = updateFrameRateInterval;
}
]]

-- Fragment shader source
local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in DataVS {
	vec4 color;
	float progress;
	float speed;
	float startframe;
	float gameFrame;
	vec2 texCoord;
	float cameraDist;
	float inMinimap;
	float minCamHeight;
	float maxCamHeight;
	float updateFrameInterval;
};

out vec4 fragColor;

void main() {
	// Cache frequently used values
	vec2 center = vec2(0.5);
	vec2 distToEdges = min(texCoord, 1.0 - texCoord);
	float distToEdge = min(distToEdges.x, distToEdges.y);
	
	// Pre-calculate border parameters
	float borderFadeDistance = mix(16.0, 64.0, float(inMinimap)) / 1024.0;
	float borderOpacity = 1.0 - clamp(distToEdge / borderFadeDistance, 0.0, 1.0);
	
	// Calculate circle parameters
	float distanceToCorner = 1.4142135623730951;
	float pixelToCenterDistance = length(texCoord - center) * 2.0;
	float scaledProgress = (progress + speed * (gameFrame - startframe)) * distanceToCorner;
	float circleSoftness = 0.05;
	
	// Calculate circle fill with optimized soft edge
	float circleFill = 1.0 - clamp((pixelToCenterDistance - scaledProgress) / circleSoftness, 0.0, 1.0);
	circleFill = step(0.0, circleFill) * circleFill;
	
	// Calculate pulsing border with optimized math
	float pulseValue = sin(gameFrame * 0.2) * 0.5 + 0.5;
	vec4 borderColor = mix(vec4(0.9, 0.9, 0.9, 0.45), vec4(1.0, 1.0, 1.0, 0.45), pulseValue);
	
	// Calculate final color with optimized blending
	vec4 finalColor = vec4(color.rgb, color.a * circleFill);
	finalColor = mix(finalColor, borderColor, borderOpacity * step(0.0, borderOpacity));
	
	// Apply camera distance fade only in world view
	float fadeAlpha = 1.0;
	if (inMinimap == 0) {
		float fadeRange = maxCamHeight - minCamHeight;
		fadeAlpha = clamp((cameraDist - minCamHeight) / fadeRange, 0.0, 1.0);
	}
	
	fragColor = vec4(finalColor.rgb, finalColor.a * fadeAlpha);
}
]]

local function GetMaxCameraHeight()
    local mapSizeX = Game.mapSizeX
    local mapSizeZ = Game.mapSizeZ
	local fallbackMaxFactor = 1.4 --to handle all camera modes
    local maxFactor = Spring.GetConfigFloat("OverheadMaxHeightFactor", fallbackMaxFactor)
	local absoluteMinimum = 3800
	local minimumFactor = 0.80
    
    local maxDimension = math.max(mapSizeX, mapSizeZ)
    local maxHeight = UNSYNCED_DEBUG_MODE and 1 or maxDimension * maxFactor
	local minHeight = UNSYNCED_DEBUG_MODE and 0 or math.max(absoluteMinimum, maxHeight * minimumFactor)

    return minHeight, maxHeight
end

local function makeShader()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	local vsShader = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	local fsShader = fsSrc
	local minCameraDrawHeight, maxCameraDrawHeight = GetMaxCameraHeight()
	
	squareShader = LuaShader({
		vertex = vsShader,
		fragment = fsShader,
		uniformInt = {
			heightmapTex = 0,
			isMinimapRendering = 0,
		},
		uniformFloat = {
			mapSizeX = Game.mapSizeX,
			mapSizeZ = Game.mapSizeZ,
			minCameraDrawHeight = minCameraDrawHeight,
			maxCameraDrawHeight = maxCameraDrawHeight,
			updateFrameInterval = UPDATE_FRAME_RATE_INTERVAL,
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

local function updateGridSquareInstanceVBO(gridID, posScale, color1, captureState)
	local instanceData = {
		posScale[1], posScale[2], posScale[3], posScale[4],  -- posscale: x, y, z, scale
		color1[1], color1[2], color1[3], color1[4],         -- color1: r, g, b, a
		captureState[1], captureState[2], captureState[3], captureState[4]  -- capturestate: speed, progress, startframe, unused
	}
	pushElementInstance(instanceVBO, instanceData, gridID, true, false)
end

local function initGL4()
	local planeResolution = 32
	local squareVBO, numVertices, squareIndexVBO, numIndices = makeSquareVBO(1, 1, planeResolution, planeResolution)
	if not squareVBO then return false end
	
	instanceVBO = makeInstanceVBOTable(planeLayout, 12, "test_square_shader")
	instanceVBO.vertexVBO = squareVBO
	instanceVBO.indexVBO = squareIndexVBO
	instanceVBO.numVertices = numIndices
	instanceVBO.primitiveType = GL.TRIANGLES
	
	squareVAO = makeVAOandAttach(squareVBO, instanceVBO.instanceVBO, squareIndexVBO)
	instanceVBO.VAO = squareVAO
	uploadAllElements(instanceVBO)
	return makeShader()
end

function gadget:Initialize()
	if initGL4() == false then
		gadgetHandler:RemoveGadget()
		return
	end
end

function gadget:Update()
	local currentFrame = Spring.GetGameFrame()
	
	if currentFrame % UPDATE_FRAME_RATE_INTERVAL == 0 and currentFrame ~= lastMoveFrame then
		local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ
		
		for gridID, gridData in pairs(captureGrid) do
			local color = allyColors[gridData.allyOwnerID] or blankColor
			local captureChangePerFrame = 0
			if gridData.captureChange then
				captureChangePerFrame = gridData.captureChange / UPDATE_FRAME_RATE_INTERVAL
			end

			updateGridSquareInstanceVBO(
				gridID,
				{gridData.gridMidpointX, SQUARE_HEIGHT, gridData.gridMidpointZ, SQUARE_SIZE},
				color,
				{captureChangePerFrame, gridData.oldProgress, currentFrame, 0.0}
				)
			gridData.captureChange = nil
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
	squareShader:SetUniformInt("isMinimapRendering", 0)
	
	instanceVBO.VAO:DrawElements(GL.TRIANGLES, instanceVBO.numVertices, 0, instanceVBO.usedElements)
	
	squareShader:Deactivate()
	glTexture(0, false)
	glDepthTest(false)
end

function gadget:DrawInMiniMap()
	if not squareShader or not squareVAO or not instanceVBO then return end
	
	squareShader:Activate()
	squareShader:SetUniformInt("isMinimapRendering", 1)
	
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

function gadget:RecvFromSynced(messageName, ...)
    if messageName == "InitializeGridSquare" then
        local gridID, allyOwnerID, progress, gridMidpointX, gridMidpointZ = ...
        captureGrid[gridID] = {
            allyOwnerID = allyOwnerID,
            oldProgress = progress,
			newProgress = progress,
			captureChange = 0,
            gridMidpointX = gridMidpointX,
            gridMidpointZ = gridMidpointZ
        }
	elseif messageName == "InitializeConfigs" then
		SQUARE_SIZE, UPDATE_FRAME_RATE_INTERVAL = ...
    elseif messageName == "UpdateGridSquare" then
        local gridID, allyOwnerID, progress = ...
        if captureGrid[gridID] then
            captureGrid[gridID].allyOwnerID = allyOwnerID
			captureGrid[gridID].oldProgress = captureGrid[gridID].newProgress
            captureGrid[gridID].captureChange = progress - captureGrid[gridID].oldProgress
            captureGrid[gridID].newProgress = progress
        end

    elseif messageName == "UpdateAllyScore" then
        local allyID, score, threshold = ...
        allyScores[allyID] = score
        defeatThreshold = threshold
    end
end

local function drawScore()
    if not allyScores[myAllyID] then return end
    
    -- Get UI viewport data
    local vsx, vsy = Spring.GetViewGeometry()
    
    -- Get minimap position and size
    local posX, posY, sizeX, sizeY = Spring.GetMiniMapGeometry()
    minimapPosX, minimapPosY = posX, posY
    minimapSizeX, minimapSizeY = sizeX, sizeY
    
    -- Calculate font size based on resolution - make it 1.5x larger instead of 2x
    fontSizeMultiplier = math.max(1.2, math.min(2.25, vsy / 1080))
    fontSize = math.floor(14 * fontSizeMultiplier)
    
    -- Calculate score display position (below minimap)
    local displayX = minimapPosX + minimapSizeX/2
    local displayY = minimapPosY - fontSize - 5
    
    -- Get current score and threshold
    local score = allyScores[myAllyID] or 0
    local threshold = defeatThreshold or 0
    
    -- Skip rendering if no valid threshold yet
    if threshold <= 0 then return end
    
    -- Calculate danger level
    local difference = score - threshold
    local dangerLevel = 0  -- 0 = safe, 1 = warning, 2 = danger
    
    if difference < -2 then
        dangerLevel = 2  -- Critical danger
    elseif difference < -WARNING_THRESHOLD then
        dangerLevel = 1  -- Warning
    end
    
    -- Handle warning blink effect
    local currentTime = Spring.GetGameSeconds()
    if dangerLevel == 2 then
        if currentTime - lastWarningBlinkTime > BLINK_FREQUENCY then
            lastWarningBlinkTime = currentTime
            isWarningVisible = not isWarningVisible
        end
    else
        isWarningVisible = true
    end
    
    -- Choose text color based on danger level
    local scoreColor = COLOR_WHITE
    if dangerLevel == 2 and not isWarningVisible then
        scoreColor = COLOR_RED
    elseif dangerLevel == 1 then
        scoreColor = COLOR_YELLOW
    end
    
    -- Format territory display with more detailed information
    local format = "Territory Control: %d%% / %d%%"
    local text = string.format(format, score, threshold)
    
    -- Measure text dimensions for background - add more padding for better visibility
    local textWidth = gl.GetTextWidth(text) * fontSize
    local paddingX = math.floor(fontSize * 0.6)  -- Increased horizontal padding
    local paddingY = math.floor(fontSize * 0.6)  -- Increased vertical padding
    local bgWidth = textWidth + (paddingX * 2)
    local bgHeight = fontSize + (paddingY * 2)  -- More vertical padding
    
    -- Draw background rect properly centered on text position
    gl.PushMatrix()
    gl.Color(COLOR_BG[1], COLOR_BG[2], COLOR_BG[3], COLOR_BG[4])
    gl.Rect(
        displayX - bgWidth/2, 
        displayY - bgHeight/2 + (paddingY/4), -- Adjust to better center the text 
        displayX + bgWidth/2, 
        displayY + bgHeight/2 + (paddingY/4)  -- Adjust to better center the text
    )
    
    -- Draw the text
    gl.Color(scoreColor[1], scoreColor[2], scoreColor[3], scoreColor[4])
    gl.Text(text, displayX, displayY, fontSize, "co") -- 'co' = center, no outline
    gl.PopMatrix()
end

function gadget:DrawScreen()
    drawScore()
end

end