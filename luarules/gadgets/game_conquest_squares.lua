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
	include("keysym.h.lua")
--zzz need to remove all button config stuff so things don't break
	
	local colorConfig = { --An array of R, G, B, Alpha
		drawStencil = true, -- wether to draw the outer, merged rings (quite expensive!)
		drawInnerRings = true, -- wether to draw inner, per defense rings (very cheap)
		externalalpha = 0.70, -- alpha of outer rings
		internalalpha = 0.0, -- alpha of inner rings
		distanceScaleStart = 2000, -- Linewidth is 100% up to this camera height
		distanceScaleEnd = 4000, -- Linewidth becomes 50% above this camera height
		ground = { --kept as a functional example of params temporarily
			color = {1.0, 0.2, 0.0, 1.0},
			fadeparams = { 2000, 5000, 1.0, 0.0}, -- FadeStart, FadeEnd, StartAlpha, EndAlpha
			externallinethickness = 4.0,
			internallinethickness = 2.0,
		},
	}
	--- Camera Height based line shrinkage: zzz-- ???? does this reference the above? It was an empty gap
	
	
	local unitDefRings = {} --each entry should be  a unitdefIDkey to very specific table:
		-- a list of tables, ideally ranged from 0 where
	
	local function initializeUnitDefRing(unitDefID)
		local color = colorConfig.ground
		local fadeparams = colorConfig.ground.fadeparams
		local range = 100
		local someOtherParamRelatedToWeaponCharacteristics = 1

		local ringParams = {range, color[1],color[2], color[3], color[4],
			fadeparams[1], fadeparams[2], fadeparams[3], fadeparams[4], someOtherParamRelatedToWeaponCharacteristics }
		unitDefRings[unitDefID]['rings'][420360] = ringParams
	end
	
	
	--------------------------------------------------------------------------------
	
	local glDepthTest           = gl.DepthTest
	local glLineWidth           = gl.LineWidth
	local glTexture             = gl.Texture
	local glClear				= gl.Clear
	local glColorMask			= gl.ColorMask
	local glStencilTest			= gl.StencilTest
	local glStencilMask			= gl.StencilMask
	local glStencilFunc			= gl.StencilFunc
	local glStencilOp			= gl.StencilOp
	
	local GL_KEEP = 0x1E00 --GL.KEEP
	local GL_REPLACE = GL.REPLACE --GL.KEEP
	
	local spGetPositionLosState = Spring.GetPositionLosState
	local spGetUnitDefID        = Spring.GetUnitDefID
	local spGetUnitPosition     = Spring.GetUnitPosition
	
	------ GL4 THINGS  -----
	-- nukes and cannons:
	local largeCircleVBO = nil
	local largeCircleSegments = 512
	
	-- others:
	local smallCircleVBO = nil
	local smallCircleSegments = 128

	local chobbyInterfaceActive = false
	
	local cameraHeightFactor = 0

	local myAllyTeam = nil
	local allyTeamsList = {}
	local drawcounts = {}
	local defenseRangeVAOs = {}
	
	local circleInstanceVBOLayout = {
			  {id = 1, name = 'posscale', size = 4}, -- a vec4 for pos + scale
			  {id = 2, name = 'color1', size = 4}, --  vec4 the color of this new
			  {id = 3, name = 'visibility', size = 4}, --- vec4 heightdrawstart, heightdrawend, fadefactorin, fadefactorout
			  {id = 4, name = 'projectileParams', size = 4}, --- heightboost gradient
			}
	
	local luaShaderDir = "LuaUI/Widgets/Include/"
	local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
	VFS.Include(luaShaderDir.."instancevbotable.lua")
	local testRangeShader = nil
	
	
	local function goodbye(reason)
	  Spring.Echo("DefenseRange GL4 widget exiting with reason: "..reason)
	  widgetHandler:RemoveWidget()
	end
	
	local function makeCircleVBO(circleSegments)
		circleSegments  = circleSegments -1 -- for po2 buffers
		local circleVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
		if circleVBO == nil then goodbye("Failed to create circleVBO") end
	
		local VBOLayout = {
		 {id = 0, name = "position", size = 4},
		}
	
		local VBOData = {}
	
		for i = 0, circleSegments  do -- this is +1
			VBOData[#VBOData+1] = math.sin(math.pi*2* i / circleSegments) -- X
			VBOData[#VBOData+1] = math.cos(math.pi*2* i / circleSegments) -- Y
			VBOData[#VBOData+1] = i / circleSegments -- circumference [0-1]
			VBOData[#VBOData+1] = 0
		end
	
		circleVBO:Define(
			circleSegments + 1,
			VBOLayout
		)
		circleVBO:Upload(VBOData)
		return circleVBO
	end
	
	local vsSrc = [[
	#version 420
	#line 10000
	
	//__DEFINES__
	
	layout (location = 0) in vec4 circlepointposition;
	layout (location = 1) in vec4 posscale;
	layout (location = 2) in vec4 color1;
	layout (location = 3) in vec4 visibility; // FadeStart, FadeEnd, StartAlpha, EndAlpha
	layout (location = 4) in vec4 projectileParams; // projectileSpeed, iscylinder!!!! , heightBoostFactor , heightMod
	
	uniform float lineAlphaUniform = 1.0;
	uniform float cannonmode = 0.0;
	
	uniform sampler2D heightmapTex;
	uniform sampler2D losTex; // hmm maybe?
	
	out DataVS {
		flat vec4 blendedcolor;
	};
	
	//__ENGINEUNIFORMBUFFERDEFS__
	
	#line 11000
	
	float heightAtWorldPos(vec2 w){
		vec2 uvhm =  heightmapUVatWorldPos(w);
		return textureLod(heightmapTex, uvhm, 0.0).x;
	}
	
	float GetRangeFactor(float projectileSpeed) { // returns >0 if weapon can shoot here, <0 if it cannot, 0 if just right
		// on first run, with yDiff = 0, what do we get?
		float speed2d = projectileSpeed * 0.707106;
		float gravity =  120.0 	* (0.001111111);
		return ((speed2d * speed2d) * 2.0 ) / (gravity);
	}
	
	float GetRange2DCannon(float yDiff,float projectileSpeed,float rangeFactor,float heightBoostFactor) { // returns >0 if weapon can shoot here, <0 if it cannot, 0 if just right
		// on first run, with yDiff = 0, what do we get?
	
		//float factor = 0.707106;
		float smoothHeight = 100.0;
		float speed2d = projectileSpeed*0.707106;
		float speed2dSq = speed2d * speed2d;
		float gravity = -1.0*  (120.0 /900);
	
		if (heightBoostFactor < 0){
			heightBoostFactor = (2.0 - rangeFactor) / sqrt(rangeFactor);
		}
	
		if (yDiff < -100.0){
			yDiff = yDiff * heightBoostFactor;
		}else {
			if (yDiff < 0.0) {
				yDiff = yDiff * (1.0 + (heightBoostFactor - 1.0 ) * (-1.0 * yDiff) * 0.01);
			}
		}
	
		float root1 = speed2dSq + 2 * gravity *yDiff;
		if (root1 < 0.0 ){
			return 0.0;
		}else{
			return rangeFactor * ( speed2dSq + speed2d * sqrt( root1 ) ) / (-1.0 * gravity);
		}
	}
	
	//float heightMod  default: 0.2 (0.8 for #Cannon, 1.0 for #BeamLaser and #LightningCannon)
	//Changes the spherical weapon range into an ellipsoid. Values above 1.0 mean the weapon cannot target as high as it can far, values below 1.0 mean it can target higher than it can far. For example 0.5 would allow the weapon to target twice as high as far.
	
	//float heightBoostFactor default: -1.0
	//Controls the boost given to range by high terrain. Values > 1.0 result in increased range, 0.0 means the cannon has fixed range regardless of height difference to target. Any value < 0.0 (i.e. the default value) result in an automatically calculated value based on range and theoretical maximum range.
	
	#define RANGE posscale.w
	#define PROJECTILESPEED projectileParams.x
	#define ISCYLINDER projectileParams.y
	#define HEIGHTBOOSTFACTOR projectileParams.z
	#define HEIGHTMOD projectileParams.w
	#define YGROUND posscale.y
	
	#define OUTOFBOUNDSALPHA alphaControl.y
	#define FADEALPHA alphaControl.z
	#define MOUSEALPHA alphaControl.w
	
	
	void main() {
		// translate to world pos:
		vec4 circleWorldPos = vec4(1.0);
		circleWorldPos.xz = circlepointposition.xy * RANGE +  posscale.xz;
	
		vec4 alphaControl = vec4(1.0);
	
		// get heightmap
		circleWorldPos.y = heightAtWorldPos(circleWorldPos.xz);
	
	
		if (cannonmode > 0.5){
	
			// BAR only has 3 distinct ballistic projectiles, heightBoostFactor is only a handful from -1 to 2.8 and 6 and 8
			// gravity we can assume to be linear
	
			float heightDiff = (circleWorldPos.y - YGROUND) * 0.5;
	
			float rangeFactor = RANGE /  GetRangeFactor(PROJECTILESPEED); //correct
			if (rangeFactor > 1.0 ) rangeFactor = 1.0;
			if (rangeFactor <= 0.0 ) rangeFactor = 1.0;
			float radius = RANGE;// - heightDiff;
			float adjRadius = GetRange2DCannon(heightDiff * HEIGHTMOD, PROJECTILESPEED, rangeFactor, HEIGHTBOOSTFACTOR);
			float adjustment = radius * 0.5;
			float yDiff = 0;
			float adds = 0;
			//for (int i = 0; i < mod(timeInfo.x/8,16); i ++){ //i am a debugging god
			for (int i = 0; i < 16; i ++){
					if (adjRadius > radius){
						radius = radius + adjustment;
						adds = adds + 1;
					}else{
						radius = radius - adjustment;
						adds = adds - 1;
					}
					adjustment = adjustment * 0.5;
					circleWorldPos.xz = circlepointposition.xy * radius + posscale.xz;
					float newY = heightAtWorldPos(circleWorldPos.xz );
					yDiff = abs(circleWorldPos.y - newY);
					circleWorldPos.y = max(0, newY);
					heightDiff = circleWorldPos.y - posscale.y;
					adjRadius = GetRange2DCannon(heightDiff * HEIGHTMOD, PROJECTILESPEED, rangeFactor, HEIGHTBOOSTFACTOR);
			}
		}else{
			if (ISCYLINDER < 0.5){ // isCylinder
				//simple implementation, 4 samples per point
				//for (int i = 0; i<mod(timeInfo.x/4,30); i++){
				for (int i = 0; i<8; i++){
					// draw vector from centerpoint to new height point and normalize it to range length
					vec3 tonew = circleWorldPos.xyz - posscale.xyz;
					tonew.y *= HEIGHTMOD;
					tonew = normalize(tonew) * RANGE;
					circleWorldPos.xz = posscale.xz + tonew.xz;
					circleWorldPos.y = heightAtWorldPos(circleWorldPos.xz);
				}
			}
		}
	
		circleWorldPos.y += 6; // lift it from the ground
	
		// -- MAP OUT OF BOUNDS
		vec2 mymin = min(circleWorldPos.xz,mapSize.xy - circleWorldPos.xz);
		float inboundsness = min(mymin.x, mymin.y);
		OUTOFBOUNDSALPHA = 1.0 - clamp(inboundsness*(-0.02),0.0,1.0);
	
	
		//--- DISTANCE FADE ---
		vec4 camPos = cameraViewInv[3];
		float distToCam = length(posscale.xyz - camPos.xyz); //dist from cam
		// FadeStart, FadeEnd, StartAlpha, EndAlpha
		float fadeDist = visibility.y - visibility.x;
		FADEALPHA  = clamp((visibility.y - distToCam)/(fadeDist),0,1);//,visibility.z,visibility.w);
	
		//--- Optimize by anything faded out getting transformed back to origin with 0 range?
		//seems pretty ok!
		if (FADEALPHA < 0.001) {
			circleWorldPos.xyz = posscale.xyz;
		}
	
		if (cannonmode > 0.5){
		// cannons should fade distance based on their range
			float cvmin = max(visibility.x, 2* RANGE);
			float cvmax = max(visibility.y, 4* RANGE);
			//FADEALPHA = clamp((cvmin - distToCam)/(cvmax - cvmin + 1.0),visibility.z,visibility.w);
		}
	
		blendedcolor = color1;
	
		// -- DARKEN OUT OF LOS
		vec4 losTexSample = texture(losTex, vec2(circleWorldPos.x / mapSize.z, circleWorldPos.z / mapSize.w)); // lostex is PO2
		float inlos = dot(losTexSample.rgb,vec3(0.33));
		inlos = clamp(inlos*5 -1.4	, 0.5,1.0); // fuck if i know why, but change this if LOSCOLORS are changed!
		blendedcolor.rgb *= inlos;
	
		// --- YES FOG
		float fogDist = length((cameraView * vec4(circleWorldPos.xyz,1.0)).xyz);
		float fogFactor = clamp((fogParams.y - fogDist) * fogParams.w, 0, 1);
		blendedcolor.rgb = mix(fogColor.rgb, vec3(blendedcolor), fogFactor);
	
	
		// -- IN-SHADER MOUSE-POS BASED HIGHLIGHTING
		float disttomousefromunit = 1.0 - smoothstep(48, 64, length(posscale.xz - mouseWorldPos.xz));
		// this will be positive if in mouse, negative else
		float highightme = clamp( (disttomousefromunit ) + 0.0, 0.0, 1.0);
		MOUSEALPHA = highightme;
	
		// ------------ dump the stuff for FS --------------------
		//worldPos = circleWorldPos;
		//worldPos.a = RANGE;
		alphaControl.x = circlepointposition.z; // save circle progress here
		gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0);
	
	
		//lets blend the alpha here, and save work in FS:
		float outalpha = OUTOFBOUNDSALPHA * (MOUSEALPHA + FADEALPHA *  lineAlphaUniform);
		blendedcolor.a *= outalpha ;
		//blendedcolor.rgb = vec3(fract(distToCam/100));
	}
	]]
	
	local fsSrc =  [[
	#version 330
	
	#extension GL_ARB_uniform_buffer_object : require
	#extension GL_ARB_shading_language_420pack: require
	
	//_DEFINES__
	
	#line 21000
	
	
	//_ENGINEUNIFORMBUFFERDEFS__
	
	in DataVS {
		flat vec4 blendedcolor;
	};
	
	out vec4 fragColor;
	
	void main() {
		fragColor = blendedcolor; // now pared down to only this, all work is done in vertex shader now
	}
	]]
	
	
	local compileSuccess = false
	local function makeShaders()
		local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
		vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
		fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
		testRangeShader =  LuaShader(
		{
			vertex = vsSrc:gsub("//__DEFINES__", "#define MYGRAVITY "..tostring(Game.gravity+0.1)),
			fragment = fsSrc,
			--geometry = gsSrc, no geom shader for now
			uniformInt = {
				heightmapTex = 0,
				losTex = 1,
			},
			uniformFloat = {
				lineAlphaUniform = 1,
				cannonmode = 0,
			},
		},
		"testRangeShader GL4"
		)
		compileSuccess = testRangeShader:Initialize()
		if not compileSuccess then
			goodbye("Failed to compile testRangeShader GL4 ")
			return false
		end
		return true
	end
	
	local function initGL4()
		smallCircleVBO = makeCircleVBO(smallCircleSegments)
		largeCircleVBO = makeCircleVBO(largeCircleSegments)
		defenseRangeVAOs['testLargeCircle'] = makeInstanceVBOTable(circleInstanceVBOLayout,16,"test_range_vbo")
		defenseRangeVAOs['testLargeCircle'].vertexVBO = largeCircleVBO
		defenseRangeVAOs['testLargeCircle'].numVertices = largeCircleSegments
		local newVAO = makeVAOandAttach(defenseRangeVAOs['testLargeCircle'].vertexVBO,defenseRangeVAOs['testLargeCircle'].instanceVBO)
		defenseRangeVAOs['testLargeCircle'].VAO = newVAO
		return makeShaders()
	end
	
	function widget:Initialize()
		if initGL4() == false then
			return
		end
	end

	local function UnitDetected(unitID, unitDefID, unitTeam, noUpload)
-- zzz this appears to be where the coordinates for where to draw the rings was made, check original widget for reference
	end
	
	
	function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
		-- the set of visible units changed. Now is a good time to reevalueate our life choices
		-- This happens when we move from team to team, or when we move from spec to other
		-- zzz this seems to be how to update changed instances?

		for vaokey, instanceTable in pairs(defenseRangeVAOs) do
			clearInstanceTable(instanceTable) -- clear all instances
		end
		for unitID, unitDefID in pairs(extVisibleUnits) do
			UnitDetected(unitID, unitDefID, Spring.GetUnitTeam(unitID), true) -- add them with noUpload = true
		end
		for vaokey, instanceTable in pairs(defenseRangeVAOs) do
			uploadAllElements(instanceTable) -- clear all instances
		end
	end
	
	local function removeUnit(unitID,defense)
		for instanceKey,vaoKey in pairs(defense.vaokeys) do
			--Spring.Echo(vaoKey,instanceKey)
			if defenseRangeVAOs[vaoKey].instanceIDtoIndex[instanceKey] then
				popElementInstance(defenseRangeVAOs[vaoKey],instanceKey)
			end
		end
	end
	
	function widget:GameFrame(gf)
	end
	
	function widget:Update(dt)
	end
	
	function widget:RecvLuaMsg(msg, playerID)
		if msg:sub(1,18) == 'LobbyOverlayActive' then
			chobbyInterfaceActive = (msg:sub(1,19) == 'LobbyOverlayActive1')
		end
	end
	
	local function GetCameraHeightFactor() -- returns a smoothstepped value between 0 and 1 for height based rescaling of line width.
		local camX, camY, camZ = Spring.GetCameraPosition()
		local camheight = camY - math.max(Spring.GetGroundHeight(camX, camZ), 0)
		-- Smoothstep to half line width as camera goes over 2k height to 4k height
		--genType t;  /* Or genDType t; */
		--t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
		--return t * t * (3.0 - 2.0 * t);
	
		camheight = math.max(0.0, math.min(1.0, (camheight - colorConfig.distanceScaleStart) / (colorConfig.distanceScaleEnd - colorConfig.distanceScaleStart)))
		--return camheight * camheight * (3 - 2 *camheight)
		return 1
	end

	local allyenemypairs = {"ally","enemy"}
	local groundnukeair = {"ground","air","nuke"}
	local function DRAWRINGS(primitiveType, linethickness)
		local stencilMask
		testRangeShader:SetUniform("cannonmode",0)
		for i,allyState in ipairs(allyenemypairs) do
			for j, wt in ipairs(groundnukeair) do
				local defRangeClass = allyState..wt
				local iT = defenseRangeVAOs[defRangeClass]
				stencilMask = 2 ^ ( 4 * (i-1) + (j-1)) -- from 1 to 128
				drawcounts[stencilMask] = iT.usedElements
				if iT.usedElements > 0 then
					if linethickness then
						glLineWidth(colorConfig[wt][linethickness] * cameraHeightFactor)
					end
					glStencilMask(stencilMask)  -- only allow these bits to get written
					glStencilFunc(GL.NOTEQUAL, stencilMask, stencilMask) -- what to do with the stencil
					iT.VAO:DrawArrays(primitiveType,iT.numVertices,0,iT.usedElements,0) -- +1!!!
				end
			end
		end
	
		testRangeShader:SetUniform("cannonmode",1)
		for i,allyState in ipairs(allyenemypairs) do
			local defRangeClass = allyState.."cannon"
			local iT = defenseRangeVAOs[defRangeClass]
			stencilMask = 2 ^ ( 4 * (i-1) + 3)
			drawcounts[stencilMask] = iT.usedElements
			if iT.usedElements > 0 then
				if linethickness then
					glLineWidth(colorConfig['cannon'][linethickness] * cameraHeightFactor)
				end
				glStencilMask(stencilMask)
				glStencilFunc(GL.NOTEQUAL, stencilMask, stencilMask)
				iT.VAO:DrawArrays(primitiveType,iT.numVertices,0,iT.usedElements,0) -- +1!!!
			end
		end
	end
	
	function widget:DrawWorldPreUnit()
		--if fullview and not enabledAsSpec then
		--	return
		--end
		if chobbyInterface then return end
		if not Spring.IsGUIHidden() and (not WG['topbar'] or not WG['topbar'].showingQuit()) then
			cameraHeightFactor = GetCameraHeightFactor() * 0.5 + 0.5
			glTexture(0, "$heightmap")
			glTexture(1, "$info")
	
			-- Stencil Setup
			-- 	-- https://learnopengl.com/Advanced-OpenGL/Stencil-testing
			if colorConfig.drawStencil then
				glClear(GL.STENCIL_BUFFER_BIT) -- clear prev stencil
				glDepthTest(false) -- always draw
				glColorMask(false, false, false, false) -- disable color drawing
				glStencilTest(true) -- enable stencil test
				glStencilMask(255) -- all 8 bits
				glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon
	
				testRangeShader:Activate()
				DRAWRINGS(GL.TRIANGLE_FAN) -- FILL THE CIRCLES
				--glLineWidth(math.max(0.1,4 + math.sin(gameFrame * 0.04) * 10))
				glColorMask(true, true, true, true)	-- re-enable color drawing
				glStencilMask(0)
	
				testRangeShader:SetUniform("lineAlphaUniform",colorConfig.externalalpha)
				glDepthTest(GL.LEQUAL) -- test for depth on these outside cases
				DRAWRINGS(GL.LINE_LOOP, 'externallinethickness') -- DRAW THE OUTER RINGS
				glStencilTest(false)
	
			end
	
			if colorConfig.drawInnerRings then
				testRangeShader:SetUniform("lineAlphaUniform",colorConfig.internalalpha)
				DRAWRINGS(GL.LINE_LOOP, 'internallinethickness') -- DRAW THE INNER RINGS
			end
	
			testRangeShader:Deactivate()
	
			glTexture(0, false)
			glTexture(1, false)
			glDepthTest(false)
			if false and Spring.GetDrawFrame() % 60 == 0 then
				local s = 'drawcounts: '
				for k,v in pairs(drawcounts) do s = s .. " " .. tostring(k) .. ":" .. tostring(v) end
				Spring.Echo(s)
			end
		end
	end

	local gridData = {}
	local allyScores = {}
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
			
			-- Update VBO data
			--updateSquareVBO(gridID, allyOwnerID, blinking)
			
		elseif cmd == "UpdateGridSquare" then
			-- Update a grid square's ownership and blinking state
			local gridID = args[1]
			local allyOwnerID = args[2]
			local blinking = args[3]
			
			-- Only update if the grid square exists
			if gridData[gridID] then
				gridData[gridID].allyOwnerID = allyOwnerID
				gridData[gridID].blinking = blinking
				
				-- Update VBO data
				--updateSquareVBO(gridID, allyOwnerID, blinking)
			end
			
		elseif cmd == "UpdateAllyScore" then
			-- Update an ally team's score
			local allyID = args[1]
			local score = args[2]
			allyScores[allyID] = score
		end
	end
end