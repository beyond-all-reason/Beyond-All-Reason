local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Commands FX",
		desc = "Shows commands given by allies",
		author = "Floris (bluestone helped optimizing)",
		date = "20 may 2015",
		license = "GNU GPL, v2 or later",
		layer = 2,
		enabled = true,
	}
end


-- Localized functions for performance
local mathMax = math.max

-- Localized Spring API for performance
local spGetMyTeamID = Spring.GetMyTeamID
local spGetSpectatingState = Spring.GetSpectatingState

-- future:          hotkey to show all current cmds? (like current shift+space)
--                  handle set target
--					quickfade on cmd cancel

-- Command IDs consolidated into single table to reduce upvalue count
local CMDS = {
	RAW_MOVE     = GameCMD.RAW_MOVE,
	ATTACK       = CMD.ATTACK,
	CAPTURE      = CMD.CAPTURE,
	FIGHT        = CMD.FIGHT,
	GUARD        = CMD.GUARD,
	INSERT       = CMD.INSERT,
	LOAD_ONTO    = CMD.LOAD_ONTO,
	LOAD_UNITS   = CMD.LOAD_UNITS,
	MANUALFIRE   = CMD.MANUALFIRE,
	MOVE         = CMD.MOVE,
	PATROL       = CMD.PATROL,
	RECLAIM      = CMD.RECLAIM,
	REPAIR       = CMD.REPAIR,
	RESTORE      = CMD.RESTORE,
	RESURRECT    = CMD.RESURRECT,
	-- SET_TARGET = GameCMD.UNIT_SET_TARGET,  -- custom command, doesn't go through UnitCommand
	UNLOAD_UNIT  = CMD.UNLOAD_UNIT,
	UNLOAD_UNITS = CMD.UNLOAD_UNITS,
	BUILD        = -1,
}

local os_clock = os.clock
local mathFloor = math.floor

local GaiaTeamID = Spring.GetGaiaTeamID()
local myTeamID = spGetMyTeamID()
local mySpec = spGetSpectatingState()
local hidden
local guiHidden

local prevTexOffset = 0
local texOffset = 0
local prevOsClock = os_clock()

local unprocessedCommands = {}
local unprocessedCommandsNum = 0
local newUnitCommands = {}

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local useTeamColors = false
local useTeamColorsWhenSpec = true

local hideBelowGameframe = 100    -- delay to give spawn fx some time

local filterOwn = false
local filterAIteams = true

local drawBuildQueue = true
local drawLineTexture = true

local opacity = 1
local duration = 0.85

local lineWidth = 5.5
local lineOpacity = 0.75
local lineWidthEnd = 0.8        -- multiplier
local lineTextureLength = 3
local lineTextureSpeed = 4

-- limit amount of effects to keep performance sane
local maxCommandCount = 700        -- dont draw more commands than this amount, but keep processing them
local maxTotalCommandCount = 1200        -- dont add more commands above this amount

local lineImg = ":n:LuaUI/Images/commandsfx/line.dds"

local isCritter = {}
local ignoreUnits = {}
for udefID, def in ipairs(UnitDefs) do
	if string.find(def.name, "critter_") then
		isCritter[udefID] = true
	end
	if def.customParams.nohealthbars then
		ignoreUnits[udefID] = true
	end
	if def.customParams.drone then
		ignoreUnits[udefID] = true
	end
end

local mapX = Game.mapSizeX
local mapZ = Game.mapSizeZ

-- CONFIG maps command ID directly to colour {r, g, b, alpha} — flat lookup, no .colour indirection
local CONFIG = {
	[CMDS.ATTACK]       = { 1.0, 0.2, 0.2, 0.30 },
	[CMDS.CAPTURE]      = { 1.0, 1.0, 0.3, 0.30 },
	[CMDS.FIGHT]        = { 1.0, 0.2, 1.0, 0.25 },
	[CMDS.GUARD]        = { 0.6, 1.0, 1.0, 0.25 },
	[CMDS.LOAD_ONTO]    = { 0.4, 0.9, 0.9, 0.25 },
	[CMDS.LOAD_UNITS]   = { 0.4, 0.9, 0.9, 0.30 },
	[CMDS.MANUALFIRE]   = { 1.0, 0.0, 0.0, 0.30 },
	[CMDS.MOVE]         = { 0.1, 1.0, 0.1, 0.25 },
	[CMDS.RAW_MOVE]     = { 0.1, 1.0, 0.1, 0.25 },
	[CMDS.PATROL]       = { 0.2, 0.5, 1.0, 0.25 },
	[CMDS.RECLAIM]      = { 0.5, 1.0, 0.4, 0.40 },
	[CMDS.REPAIR]       = { 1.0, 0.9, 0.2, 0.40 },
	[CMDS.RESTORE]      = { 0.0, 0.5, 0.0, 0.25 },
	[CMDS.RESURRECT]    = { 0.9, 0.5, 1.0, 0.25 },
	[CMDS.UNLOAD_UNIT]  = { 1.0, 0.8, 0.0, 0.25 },
	[CMDS.UNLOAD_UNITS] = { 1.0, 0.8, 0.0, 0.25 },
	[CMDS.BUILD]        = { 0.0, 1.0, 0.0, 0.25 },
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local enabledTeams = {}
local commands = {}
local maxCommand = 0
local totalCommands = 0

local unitCommand = {} -- most recent key in command table of order for unitID
local osClock

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitCommands = Spring.GetUnitCommands
local spIsUnitInView = Spring.IsUnitInView
local spIsSphereInView = Spring.IsSphereInView
local spValidUnitID = Spring.ValidUnitID
local spValidFeatureID = Spring.ValidFeatureID
local spGetFeaturePosition = Spring.GetFeaturePosition
local spIsGUIHidden = Spring.IsGUIHidden
local spLoadCmdColorsConfig = Spring.LoadCmdColorsConfig
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitTeam = Spring.GetUnitTeam

local MAX_UNITS = Game.maxUnits

--------------------------------------------------------------------------------
-- GL4 instanced rendering
--------------------------------------------------------------------------------

local gl4 = nil  -- nil = not initialized, false = init failed, table = active
local GL4_MAX_SEGMENTS = 4096
local GL4_FLOATS_PER_SEG = 12  -- 3 vec4 attributes per instance

-- Pre-allocated arrays for build queue ghost rendering (legacy pass)
local buildGhosts = {
	x = {}, y = {}, z = {},
	defID = {}, facing = {},
	r = {}, g = {}, b = {}, a = {},
	count = 0,
}

local function InitGL4()
	if not gl.GetVBO or not gl.GetVAO or not gl.CreateShader then
		return false
	end

	local vertSrc = [[
		#version 330

		// Per-vertex (static quad corner)
		layout(location = 0) in vec2 a_corner;

		// Per-instance (line segment data)
		layout(location = 1) in vec4 a_posStart;   // startX, startY, startZ, endX
		layout(location = 2) in vec4 a_posEndW;    // endY, endZ, width, alpha
		layout(location = 3) in vec4 a_colorTex;   // r, g, b, texOffset

		uniform mat4 u_viewMat;
		uniform mat4 u_projMat;
		uniform float u_lineTexLen;
		uniform float u_lineWidth;

		out vec4 v_color;
		out vec2 v_texCoord;

		void main() {
			vec3 sPos = a_posStart.xyz;
			vec3 ePos = vec3(a_posStart.w, a_posEndW.xy);
			float w = a_posEndW.z;

			// Direction in XZ plane — perpendicular expansion only in XZ (matches legacy)
			vec2 dXZ = ePos.xz - sPos.xz;
			float lenXZ = length(dXZ);
			vec2 perpXZ = (lenXZ > 0.001) ? vec2(-dXZ.y, dXZ.x) / lenXZ : vec2(0.0, 1.0);

			float side  = a_corner.x * 2.0 - 1.0;  // -1 or +1
			float along = a_corner.y;               // 0 = start, 1 = end

			vec3 pos;
			pos.xz = mix(sPos.xz, ePos.xz, along) + perpXZ * w * 0.5 * side;
			pos.y  = mix(sPos.y,  ePos.y,  along);

			gl_Position = u_projMat * u_viewMat * vec4(pos, 1.0);

			v_color = vec4(a_colorTex.rgb, a_posEndW.w);

			// Scrolling texture coordinates
			float dist3D = length(ePos - sPos);
			float texLen = dist3D / (u_lineTexLen * u_lineWidth);
			v_texCoord.x = (1.0 - along) * (texLen + 1.0) - a_colorTex.w;
			v_texCoord.y = a_corner.x;
		}
	]]

	local fragSrc = [[
		#version 330

		uniform sampler2D u_tex;
		uniform int u_useTex;

		in vec4 v_color;
		in vec2 v_texCoord;

		out vec4 fragColor;

		void main() {
			if (u_useTex != 0) {
				fragColor = v_color * texture(u_tex, v_texCoord);
			} else {
				fragColor = v_color;
			}
		}
	]]

	local shader = gl.CreateShader({
		vertex = vertSrc,
		fragment = fragSrc,
		uniformInt = { u_tex = 0, u_useTex = 0 },
		uniformFloat = { u_lineTexLen = lineTextureLength },
	})
	if not shader then
		Spring.Echo("[CommandsFX2] GL4 shader failed: " .. tostring(gl.GetShaderLog()))
		return false
	end

	local locs = {
		viewMat    = gl.GetUniformLocation(shader, 'u_viewMat'),
		projMat    = gl.GetUniformLocation(shader, 'u_projMat'),
		lineTexLen = gl.GetUniformLocation(shader, 'u_lineTexLen'),
		lineWidth  = gl.GetUniformLocation(shader, 'u_lineWidth'),
		useTex     = gl.GetUniformLocation(shader, 'u_useTex'),
	}

	-- Static quad VBO (TRIANGLE_STRIP order: BL, BR, TL, TR)
	local quadVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	if not quadVBO then
		gl.DeleteShader(shader)
		return false
	end
	quadVBO:Define(4, { {id = 0, name = 'a_corner', size = 2} })
	quadVBO:Upload({0,0, 1,0, 0,1, 1,1})

	-- Instance VBO (streaming — rebuilt each frame)
	local instVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if not instVBO then
		gl.DeleteShader(shader)
		return false
	end
	instVBO:Define(GL4_MAX_SEGMENTS, {
		{id = 1, name = 'a_posStart',  size = 4},
		{id = 2, name = 'a_posEndW',   size = 4},
		{id = 3, name = 'a_colorTex',  size = 4},
	})

	local vao = gl.GetVAO()
	if not vao then
		gl.DeleteShader(shader)
		return false
	end
	vao:AttachVertexBuffer(quadVBO)
	vao:AttachInstanceBuffer(instVBO)

	gl4 = {
		shader  = shader,
		locs    = locs,
		vao     = vao,
		quadVBO = quadVBO,
		instVBO = instVBO,
		segData = {},  -- flat float array, pre-allocated on use
		segCount = 0,
	}
	return true
end

local function ShutdownGL4()
	if gl4 then
		if gl4.shader then gl.DeleteShader(gl4.shader) end
		-- VAO/VBO are garbage-collected by Spring but nil them for safety
		gl4.vao = nil
		gl4.instVBO = nil
		gl4.quadVBO = nil
		gl4 = nil
	end
end

--------------------------------------------------------------------------------
-- Table pools for performance (reuse tables instead of allocating new ones)
--------------------------------------------------------------------------------
-- Performance optimizations:
-- 1. Table pooling: Reuse tables instead of creating new ones to reduce GC pressure
-- 2. Efficient table clearing: Clear tables in-place instead of reallocating
-- 3. Position caching: Cache unit positions per frame to avoid redundant API calls
-- 4. Loop optimization: Precompute invariant values outside loops
-- 5. Local variable caching: Cache frequently accessed values to reduce table lookups

local tablePool = {}
local tablePoolCount = 0
local maxTablePoolSize = 100

local function getTable()
	if tablePoolCount > 0 then
		local t = tablePool[tablePoolCount]
		tablePool[tablePoolCount] = nil
		tablePoolCount = tablePoolCount - 1
		return t
	else
		return {}
	end
end

local function releaseTable(t)
	-- Clear the table
	for k in pairs(t) do
		t[k] = nil
	end
	-- Return to pool if not full
	if tablePoolCount < maxTablePoolSize then
		tablePoolCount = tablePoolCount + 1
		tablePool[tablePoolCount] = t
	end
end

-- Cache for unit positions to avoid repeated API calls per frame
-- Uses 3 flat tables instead of {x,y,z} sub-tables to avoid per-unit allocation
local unitPosCacheX = {}
local unitPosCacheY = {}
local unitPosCacheZ = {}
local currentGameFrame = -1

local function clearPositionCache()
	local k = next(unitPosCacheX)
	while k do
		unitPosCacheX[k] = nil
		unitPosCacheY[k] = nil
		unitPosCacheZ[k] = nil
		k = next(unitPosCacheX)
	end
end

local function getCachedUnitPosition(unitID)
	local cx = unitPosCacheX[unitID]
	if cx then
		return cx, unitPosCacheY[unitID], unitPosCacheZ[unitID]
	end

	local x, y, z = spGetUnitPosition(unitID)
	if x then
		unitPosCacheX[unitID] = x
		unitPosCacheY[unitID] = y
		unitPosCacheZ[unitID] = z
	end
	return x, y, z
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local teamColor = {}
local function loadTeamColors()
	local teams = Spring.GetTeamList()
	for i = 1, #teams do
		local r, g, b = Spring.GetTeamColor(teams[i])
		local min = 0.12
		teamColor[teams[i]] = { mathMax(r, min), mathMax(g, min), mathMax(b, min), 0.33 }
	end
end
loadTeamColors()

local function setCmdLineColors(alpha)
	spLoadCmdColorsConfig('move        0.5  1.0  0.5  ' .. alpha)
	spLoadCmdColorsConfig('attack      1.0  0.2  0.2  ' .. alpha)
	spLoadCmdColorsConfig('fight       1.0  0.2  1.0  ' .. alpha)
	spLoadCmdColorsConfig('wait        0.5  0.5  0.5  ' .. alpha)
	spLoadCmdColorsConfig('build       0.0  1.0  0.0  ' .. alpha)
	spLoadCmdColorsConfig('guard       0.6  1.0  1.0  ' .. alpha)
	spLoadCmdColorsConfig('stop        0.0  0.0  0.0  ' .. alpha)
	spLoadCmdColorsConfig('patrol      0.2  0.5  1.0  ' .. alpha)
	spLoadCmdColorsConfig('capture     1.0  1.0  0.3  ' .. alpha)
	spLoadCmdColorsConfig('repair      1.0  0.9  0.2  ' .. alpha)
	spLoadCmdColorsConfig('reclaim     0.5  1.0  0.4  ' .. alpha)
	spLoadCmdColorsConfig('restore     0.0  1.0  0.0  ' .. alpha)
	spLoadCmdColorsConfig('resurrect   0.9  0.5  1.0  ' .. alpha)
	spLoadCmdColorsConfig('load        0.4  0.9  0.9  ' .. alpha)
	spLoadCmdColorsConfig('unload      1.0  0.8  0.0  ' .. alpha)
	spLoadCmdColorsConfig('deathWatch  0.5  0.5  0.5  ' .. alpha)
end

local function applyCmdQueueVisibility(hide)
	if hide then
		spLoadCmdColorsConfig('queueIconAlpha  0 ')
		setCmdLineColors(0)
	else
		spLoadCmdColorsConfig('queueIconAlpha  0.5 ')
		setCmdLineColors(0.5)
	end
end

local function resetEnabledTeams()
	enabledTeams = {}
	local t = Spring.GetTeamList()
	for _, teamID in ipairs(t) do
		if not filterAIteams or not select(4, Spring.GetTeamInfo(teamID, false)) then
			enabledTeams[teamID] = true
		end
	end
end

function widget:Initialize()
	--spLoadCmdColorsConfig('useQueueIcons  0 ')
	spLoadCmdColorsConfig('queueIconScale  0.66 ')
	applyCmdQueueVisibility(spIsGUIHidden())

	resetEnabledTeams()

	WG['commandsfx'] = {}
	WG['commandsfx'].getOpacity = function()
		return opacity
	end
	WG['commandsfx'].setOpacity = function(value)
		opacity = value
	end
	WG['commandsfx'].getDuration = function()
		return duration
	end
	WG['commandsfx'].setDuration = function(value)
		duration = value
	end
	WG['commandsfx'].getFilterAI = function()
		return filterAIteams
	end
	WG['commandsfx'].setFilterAI = function(value)
		filterAIteams = value
		resetEnabledTeams()
	end
	WG['commandsfx'].getUseTeamColors = function()
		return useTeamColors
	end
	WG['commandsfx'].setUseTeamColors = function(value)
		useTeamColors = value
	end
	WG['commandsfx'].setUseTeamColorsWhenSpec = function()
		return useTeamColorsWhenSpec
	end
	WG['commandsfx'].setUseTeamColorsWhenSpec = function(value)
		useTeamColorsWhenSpec = value
	end

	if not InitGL4() then
		Spring.Echo("[CommandsFX2] GL4 initialization failed, disabling widget")
		widgetHandler:RemoveWidget(self)
		return
	end
end

function widget:Shutdown()
	ShutdownGL4()
	--spLoadCmdColorsConfig('useQueueIcons  1 ')
	spLoadCmdColorsConfig('queueIconScale  1 ')
	spLoadCmdColorsConfig('queueIconAlpha  1 ')
	setCmdLineColors(0.7)
end

local function RemovePreviousCommand(unitID)
	if unitCommand[unitID] and commands[unitCommand[unitID]] then
		commands[unitCommand[unitID]].draw = false
	end
end

local function addUnitCommand(unitID, unitDefID, cmdID)
	if unitID and (CONFIG[cmdID] or cmdID == CMDS.INSERT or cmdID < 0) then
		unprocessedCommandsNum = unprocessedCommandsNum + 1
		local cmd = getTable()
		cmd.unitID = unitID
		cmd.draw = false
		unprocessedCommands[unprocessedCommandsNum] = cmd
		if useTeamColors or (mySpec and useTeamColorsWhenSpec) then
			cmd.teamID = spGetUnitTeam(unitID)
		end
	end
end

-- Parallel tables for deferred unit commands — avoids creating {unitDefID, cmdID} tables
local deferredUnitDefID = {}
local deferredUnitCmdID = {}

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if enabledTeams[teamID] ~= nil and (not filterOwn or mySpec or teamID ~= myTeamID) then
		if teamID ~= GaiaTeamID or not isCritter[unitDefID] then
			if ignoreUnits[unitDefID] == nil then
				if newUnitCommands[unitID] == nil then
					-- only process the first in queue, else when super large queue order is given widget will hog memory and crash
					addUnitCommand(unitID, unitDefID, cmdID)
					newUnitCommands[unitID] = true
				else
					-- Store deferred command data in parallel flat tables (no table alloc)
					newUnitCommands[unitID] = false
					deferredUnitDefID[unitID] = unitDefID
					deferredUnitCmdID[unitID] = cmdID
				end
			end
		end
	end
end

-- Queue entry target types for pre-extracted positions
local QTARGET_COORD = 1    -- static coordinate (MOVE, BUILD, PATROL, etc.)
local QTARGET_UNIT = 2     -- unit target (needs live position each frame)
local QTARGET_FEATURE = 3  -- feature target (needs live position each frame)

local function getCommandsQueue(unitID)
	local q = spGetUnitCommands(unitID, 35) or {}
	local our_q = getTable()
	local our_qCount = 0
	for i = 1, #q do
		local entry = q[i]
		local id = entry.id
		if CONFIG[id] or id < 0 then
			local params = entry.params
			local a, b, c, d = params[1], params[2], params[3], params[4]

			if id < 0 then
				entry.buildingID = -id
				id = CMDS.BUILD
				entry.id = id
				entry.facing = d or 0
			end

			-- Pre-extract target position and classify target type
			local ttype, tid
			if c or d then
				if id == CMDS.RECLAIM and a >= MAX_UNITS and spValidFeatureID(a - MAX_UNITS) then
					tid = a - MAX_UNITS
					ttype = QTARGET_FEATURE
					entry.tx, entry.ty, entry.tz = spGetFeaturePosition(tid)
				elseif id == CMDS.REPAIR and spValidUnitID(a) then
					tid = a
					ttype = QTARGET_UNIT
					entry.tx, entry.ty, entry.tz = spGetUnitPosition(a)
				else
					ttype = QTARGET_COORD
					entry.tx, entry.ty, entry.tz = a, b, c
				end
			elseif a then
				if a >= MAX_UNITS then
					tid = a - MAX_UNITS
					ttype = QTARGET_FEATURE
					entry.tx, entry.ty, entry.tz = spGetFeaturePosition(tid)
				else
					tid = a
					ttype = QTARGET_UNIT
					entry.tx, entry.ty, entry.tz = spGetUnitPosition(a)
				end
			end

			entry.ttype = ttype
			entry.targetID = tid
			entry.colour = CONFIG[id]

			our_qCount = our_qCount + 1
			our_q[our_qCount] = entry
		end
	end
	return our_q, our_qCount
end

local sec = 0
local lastUpdate = 0
function widget:Update(dt)

	sec = sec + dt
	if sec > lastUpdate + 0.1 then
		local gf = spGetGameFrame()
		if not hidden then
			if gf < hideBelowGameframe then
				hidden = true
				applyCmdQueueVisibility(true)
			end
		elseif gf >= hideBelowGameframe then
			hidden = nil
			applyCmdQueueVisibility(false)
		end
		lastUpdate = sec

		-- also react to GUI hidden toggle so engine queue lines/icons are hidden too
		local isGuiHidden = spIsGUIHidden()
		if guiHidden ~= isGuiHidden then
			guiHidden = isGuiHidden
			applyCmdQueueVisibility(guiHidden)
		end

		-- process newly given commands
		-- (not done in widgetUnitCommand() because with huge build queue
		-- it eats memory and can crash lua)
		local uid = next(newUnitCommands)
		while uid do
			local v = newUnitCommands[uid]
			if v == false then
				local dDefID = deferredUnitDefID[uid]
				if ignoreUnits[dDefID] == nil then
					addUnitCommand(uid, dDefID, deferredUnitCmdID[uid])
				end
				deferredUnitDefID[uid] = nil
				deferredUnitCmdID[uid] = nil
			end
			newUnitCommands[uid] = nil
			uid = next(newUnitCommands)
		end

		-- process new commands (cant be done directly because at
		-- widget:UnitCommand() the queue isnt updated yet)
		for k = 1, #unprocessedCommands do
			local cmd = unprocessedCommands[k]
			if totalCommands <= maxTotalCommandCount then
				maxCommand = maxCommand + 1
				local i = maxCommand
				commands[i] = cmd
				totalCommands = totalCommands + 1

				RemovePreviousCommand(cmd.unitID)
				unitCommand[cmd.unitID] = i

				-- get pruned command queue
				local our_q, qsize = getCommandsQueue(cmd.unitID)
				commands[i].queue = our_q
				commands[i].queueSize = qsize
				if qsize > 0 then
					commands[i].draw = true
				end

				-- get location of final command (pre-extracted in getCommandsQueue)
				if qsize > 0 then
					local lastCmd = our_q[qsize]
					if lastCmd.tx then
						commands[i].x = lastCmd.tx
						commands[i].y = lastCmd.ty
						commands[i].z = lastCmd.tz
					end
				end
				commands[i].time = os_clock()
			else
				-- If we didn't use this command, release it back to pool
				releaseTable(cmd)
			end
		end
		-- Clear unprocessedCommands array (tables already moved to commands or released)
		for k = 1, unprocessedCommandsNum do
			unprocessedCommands[k] = nil
		end
		unprocessedCommandsNum = 0
	end
end

local function IsPointInView(x, y, z)
	if x and y and z then
		return spIsSphereInView(x, y, z, 1) --better way of doing this?
	end
	return false
end

-- Hoisted closure for gl.ActiveShader to avoid per-frame allocation
local gl4SegCount = 0
local function gl4DrawFunc()
	gl.UniformMatrix(gl4.locs.viewMat, "camera")
	gl.UniformMatrix(gl4.locs.projMat, "projection")
	gl.Uniform(gl4.locs.lineTexLen, lineTextureLength)
	gl.Uniform(gl4.locs.lineWidth, lineWidth)
	gl.UniformInt(gl4.locs.useTex, drawLineTexture and 1 or 0)
	gl4.vao:DrawArrays(GL.TRIANGLE_STRIP, 4, 0, gl4SegCount)
end

function widget:DrawWorldPreUnit()
	if hidden then return end
	if spIsGUIHidden() then return end

	osClock = os_clock()
	if drawLineTexture then
		texOffset = prevTexOffset - ((osClock - prevOsClock) * lineTextureSpeed)
		texOffset = texOffset - mathFloor(texOffset)
		prevTexOffset = texOffset
	end
	prevOsClock = os_clock()

	-- Clear position cache once per game frame
	local gf = spGetGameFrame()
	if currentGameFrame ~= gf then
		currentGameFrame = gf
		clearPositionCache()
	end

	gl.DepthTest(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- Precompute values used in loop
	local useTeamColorsForDraw = useTeamColors or (mySpec and useTeamColorsWhenSpec)
	local lineWidthDelta = lineWidth - (lineWidth * lineWidthEnd)
	local opacityMul = opacity * lineOpacity * 2
	local segCount = 0
	local segData = gl4.segData
	buildGhosts.count = 0

	local commandCount = 0
	local i = next(commands)
	while i do
		local nextI = next(commands, i)  -- grab next key before we might nil commands[i]
		local command = commands[i]
		if command and command.time then
			local progress = (osClock - command.time) / duration
			local unitID = command.unitID

			if progress >= 1 then
				if command.queue then
					releaseTable(command.queue)
				end
				commands[i] = nil
				totalCommands = totalCommands - 1
				if unitCommand[unitID] == i then
					unitCommand[unitID] = nil
				end

			elseif command.draw and (spIsUnitInView(unitID) or
				IsPointInView(command.x, command.y, command.z)) then

				-- draw command queue
				local prevX, prevY, prevZ = getCachedUnitPosition(unitID)
				local queueSize = command.queueSize
				if queueSize > 0 and prevX and commandCount < maxCommandCount then

					local lineAlphaMultiplier = opacityMul * (1 - progress)
					local usedLineWidth = lineWidth - (progress * lineWidthDelta)
					local queue = command.queue
					local cmdTeamColour = useTeamColorsForDraw and command.teamID and teamColor[command.teamID]

					for j = 1, queueSize do
						local qe = queue[j]
						-- Resolve position from pre-extracted data
						local X, Y, Z
						local ttype = qe.ttype
						if ttype == QTARGET_COORD then
							X, Y, Z = qe.tx, qe.ty, qe.tz
						elseif ttype == QTARGET_UNIT then
							X, Y, Z = getCachedUnitPosition(qe.targetID)
						elseif ttype == QTARGET_FEATURE then
							X, Y, Z = spGetFeaturePosition(qe.targetID)
						end
						if X and Z and X >= 0 and X <= mapX and Z >= 0 and Z <= mapZ then
							commandCount = commandCount + 1
							local lineColour = cmdTeamColour or qe.colour
							local lineAlpha = lineColour[4] * lineAlphaMultiplier
							if lineAlpha > 0 then
								if segCount < GL4_MAX_SEGMENTS then
									segCount = segCount + 1
									local base = (segCount - 1) * GL4_FLOATS_PER_SEG
									segData[base+1]  = prevX
									segData[base+2]  = prevY
									segData[base+3]  = prevZ
									segData[base+4]  = X
									segData[base+5]  = Y
									segData[base+6]  = Z
									segData[base+7]  = usedLineWidth
									segData[base+8]  = lineAlpha
									segData[base+9]  = lineColour[1]
									segData[base+10] = lineColour[2]
									segData[base+11] = lineColour[3]
									segData[base+12] = texOffset
								end
								if drawBuildQueue and qe.buildingID then
									local gc = buildGhosts.count + 1
									buildGhosts.count = gc
									buildGhosts.x[gc] = X
									buildGhosts.y[gc] = Y
									buildGhosts.z[gc] = Z
									buildGhosts.defID[gc] = qe.buildingID
									buildGhosts.facing[gc] = qe.facing
									buildGhosts.r[gc] = lineColour[1]
									buildGhosts.g[gc] = lineColour[2]
									buildGhosts.b[gc] = lineColour[3]
									buildGhosts.a[gc] = lineAlpha
								end
							end
							prevX, prevY, prevZ = X, Y, Z
						end
					end
				end
			end
		end -- end if command check
		i = nextI
	end

	-- GL4 draw pass: one instanced draw call for all line segments
	if segCount > 0 then
		gl4.instVBO:Upload(segData, -1, 0, 1, segCount * GL4_FLOATS_PER_SEG)
		if drawLineTexture then
			gl.Texture(0, lineImg)
		end
		gl4SegCount = segCount
		gl.ActiveShader(gl4.shader, gl4DrawFunc)
		if drawLineTexture then
			gl.Texture(0, false)
		end
	end

	-- Build queue ghosts (legacy pass — requires gl.UnitShape)
	if buildGhosts.count > 0 then
		for k = 1, buildGhosts.count do
			gl.Color(buildGhosts.r[k], buildGhosts.g[k], buildGhosts.b[k], buildGhosts.a[k])
			gl.PushMatrix()
			gl.Translate(buildGhosts.x[k], buildGhosts.y[k] + 1, buildGhosts.z[k])
			gl.Rotate(90 * buildGhosts.facing[k], 0, 1, 0)
			gl.UnitShape(buildGhosts.defID[k], myTeamID, true, false, false)
			gl.Rotate(-90 * buildGhosts.facing[k], 0, 1, 0)
			gl.Translate(-buildGhosts.x[k], -buildGhosts.y[k] - 1, -buildGhosts.z[k])
			gl.PopMatrix()
		end
	end

	gl.Color(1, 1, 1, 1)
end


function widget:PlayerChanged()
	myTeamID = spGetMyTeamID()
	mySpec = spGetSpectatingState()
end

function widget:GetConfigData()
	return { opacity = opacity, filterAIteams = filterAIteams, filterOwn = filterOwn, useTeamColors = useTeamColors, useTeamColorsWhenSpec = useTeamColorsWhenSpec, duration = duration }
end

function widget:SetConfigData(data)
	if data.opacity ~= nil then
		opacity = data.opacity
	end
	if data.filterAIteams ~= nil then
		filterAIteams = data.filterAIteams
	end
	if data.filterOwn ~= nil then
		filterOwn = data.filterOwn
	end
	if data.useTeamColors ~= nil then
		useTeamColors = data.useTeamColors
	end
	if data.useTeamColorsWhenSpec ~= nil then
		useTeamColorsWhenSpec = data.useTeamColorsWhenSpec
	end
	if data.duration ~= nil then
		duration = data.duration
	end
end
