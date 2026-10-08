local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Sensor Ranges Jammer Preview",
		desc = "Engine-accurate jammer coverage, drawn as a sheet over the terrain while placing or selecting a jammer (GL4)",
		author = "Floris",
		date = "2026.10.06",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

-- Springsettings
-- JammerPreviewAlwaysShow (0/1, default on): always draw the coverage of all allied jammers, not only while placing or selecting one
-- JammerPreviewAlliedCoverage (0/1, default on): while previewing a jammer, also draw the coverage of all allied jammers
-- JammerPreviewMinimap (0/1, default on): also fill the coverage on the minimap (and the PIP minimap)

------------------------------------------------------------------------------------------------
-- Jammer coverage ignores the terrain: the engine jams a disc of radar cells (radarMipLevel from modrules,
-- 2 => 32 elmo cells) around the cell of the jammer's mid position, with the radius rounded down to whole cells
-- (CLosMap::AddCircle in rts/Sim/Misc/LosMap.cpp). This draws exactly those cells:
--  1. Disc pass: the previewed jammer's disc, and the union of the allied jammers' discs over the whole map,
--     each re-rendered only when it changes.
--  2. Smoothing pass: eases the shown disc towards the new one, so dragging the preview fades instead of popping.
--  3. Sheet pass: projects the coverage onto the terrain. Drawn over the coverage's screen area, every pixel
--     rebuilds its world position from the map g-buffer depth and takes the coverage of its radar cell.
--  4. Minimap pass (JammerPreviewMinimap setting): a flat, outlined fill of the same coverage on the minimap.
-- A selected jammer that does not jam right now (switched off, stunned, paused, unpaid or unfinished) still shows
-- its range, faintly.
-- The pass vertex, smoothing and minimap shaders are shared with gui_sensor_ranges_radar_preview.lua.
------------------------------------------------------------------------------------------------

-- Tunables
local SETTINGS_POLL_SECONDS = 2 -- how often the JammerPreview* settings are re-read
local ALLIED_POLL_SECONDS = 0.2 -- how often the allied jammers are checked for changes while their coverage is shown
local SMOOTH_RATE = 14 -- 1/s, how fast the sheet follows coverage changes (higher = snappier)
local SMOOTH_RATE_DRAG = 60 -- 1/s, used while the placement preview is dragged across radar cells, so the sheet keeps up with the cursor
local MAX_RADIUS_CELLS = 256 -- sanity limit of the jammer radius in cells
local OUTLINE_DASHES = 4 -- stipple density of the outline: dashes per radar cell side, centred on the cell corners
local OUTLINE_DASH_SPEED = 6 -- elmos per second the stipple travels clockwise around the coverage, 0 = still

-- The sheet is projected through the map g-buffer depth; units and features are left out via the model g-buffer
-- depth. BAR turns both on (luaintro/springconfig.lua).
local hasMapDepth = Spring.GetConfigString("AllowDeferredMapRendering") == "1"
local hasModelDepth = hasMapDepth and Spring.GetConfigString("AllowDeferredModelRendering") == "1"

-- Engine sensor model (rts/Sim/Misc/LosHandler.cpp, LosMap.cpp)
local RADAR_MIP_LEVEL = 2 -- modrules sensors.los.radarMipLevel; overridden below when the file can be read
do
	local modrules = VFS.LoadFile("gamedata/modrules.lua")
	local mip = modrules and modrules:match("radarMipLevel%s*=%s*(%d+)")
	if mip then
		RADAR_MIP_LEVEL = tonumber(mip) or RADAR_MIP_LEVEL
	end
end

local SQUARE_SIZE = 8
local RADAR_CELL = SQUARE_SIZE * 2 ^ RADAR_MIP_LEVEL -- elmos per radar cell
local MAP_CELLS_X = math.floor(Game.mapSizeX / RADAR_CELL) -- radar cells of the whole map
local MAP_CELLS_Z = math.floor(Game.mapSizeZ / RADAR_CELL)
local engineRequiresUpkeep = Game.sensorsRequireUpkeep == true -- sensors.requireUpkeep: unpaid units lose their sensors

local shaderConfig = {
	MODEL_DEPTH_TEST = hasModelDepth and 1 or 0,
	RADAR_CELL_SIZE = RADAR_CELL,
	MAP_CELLS_X = MAP_CELLS_X,
	MAP_CELLS_Z = MAP_CELLS_Z,
	SHEET_COLOR = "vec3(0.90, 0.22, 0.20)", -- color of the previewed jammer's coverage, on the sheet and the minimap
	ALLIED_COLOR = "vec3(0.62, 0.35, 0.33)", -- cells covered only by other allied jammers
	ALLIED_ALPHA = 0.85, -- their opacity relative to the previewed jammer's cells
	OUTLINE_COLOR = "vec3(1.00, 0.32, 0.22)", -- stippled outline along the border with uncovered radar cells
	SHEET_ALPHA = 0.17, -- opacity of the sheet
	SHEET_OUTLINE_ALPHA = 0.66, -- opacity of the dashes of the OUTLINE_COLOR border of the sheet
	OUTLINE_GAP_ALPHA = 0.3, -- opacity of that border between its dashes, relative to the dashes
	OUTLINE_WIDTH = 1.2, -- outline width in pixels at 1080p, scaled with the screen's vertical resolution
	OUTLINE_WORLD_WIDTH = 0.89, -- elmos added to the outline width, so it gets a little thicker when zoomed in
	OUTLINE_DASHES = OUTLINE_DASHES,
	MINIMAP_ALPHA = 0.33, -- opacity of the coverage fill on the minimap, SHEET_COLOR / ALLIED_COLOR
	MINIMAP_OUTLINE_ALPHA = 0.4, -- opacity of the OUTLINE_COLOR border on the minimap around the previewed jammer's coverage
	MINIMAP_ALLIED_OUTLINE_ALPHA = 0.25, -- opacity of that border around cells covered only by other allied jammers
	MINIMAP_OUTLINE_WIDTH = 2, -- minimap outline width in pixels at 1080p, scaled with the screen's vertical resolution
	INACTIVE_ALPHA = 0.5, -- fill opacity of a selected jammer that does not jam (off, stunned, paused or unpaid), relative to a jamming one's
	INACTIVE_OUTLINE_ALPHA = 0.4, -- opacity of its outline, relative to a jamming one's
	MIN_COVERAGE = 0.04, -- cells fainter than this are not drawn
	SPAWN_SPEED = 18.0, -- jammer ranges per second the spawn ripple travels outward
}

-- Localized functions for performance
local mathFloor = math.floor
local mathCeil = math.ceil
local mathMin = math.min
local mathMax = math.max
local mathExp = math.exp
local mathHuge = math.huge
local osClock = os.clock

-- Localized Spring API for performance
local spEcho = Spring.Echo
local spGetUnitDefID = Spring.GetUnitDefID
local spGetActiveCommand = Spring.GetActiveCommand
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetUnitPosition = Spring.GetUnitPosition
local spGetGroundHeight = Spring.GetGroundHeight
local spGetCameraPosition = Spring.GetCameraPosition
local spGetCameraDirection = Spring.GetCameraDirection
local spGetGroundExtremes = Spring.GetGroundExtremes
local spGetViewGeometry = Spring.GetViewGeometry
local spGetDrawFrame = Spring.GetDrawFrame
local spGetGameFrame = Spring.GetGameFrame
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetTeamList = Spring.GetTeamList
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitSensorRadius = Spring.GetUnitSensorRadius
local spGetUnitIsActive = Spring.GetUnitIsActive
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spGetUnitIsUpkeepPaid = Spring.GetUnitIsUpkeepPaid
local spIsUnitSelected = Spring.IsUnitSelected
local spPos2BuildPos = Spring.Pos2BuildPos
local spGetBuildFacing = Spring.GetBuildFacing
local getCurrentMiniMapRotationOption = require("luaui/Include/minimap_utils").getCurrentMiniMapRotationOption

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable
local GL_R8 = 0x8229
local GL_R16F = 0x822D

-- ILosType::GetRadius: (radius / SQUARE_SIZE) >> radarMipLevel, integer arithmetic
local function radiusToCells(radius)
	return mathMin(mathFloor(mathFloor(radius / SQUARE_SIZE) / 2 ^ RADAR_MIP_LEVEL), MAX_RADIUS_CELLS)
end

-- ILosType::PosToSquare: int(pos / cell size), truncated toward zero
local function worldToCell(v)
	local cell = v / RADAR_CELL
	return cell >= 0 and mathFloor(cell) or mathCeil(cell)
end

-- unitDefID -> jammer parameters of every unit type with a radar jammer
local jammerDefs = {} ---@type table<number, table>
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.radarDistanceJam and unitDef.radarDistanceJam > 0 then
		local dims = Spring.GetUnitDefDimensions(unitDefID)
		jammerDefs[unitDefID] = {
			unitDefID = unitDefID,
			radiusCells = radiusToCells(unitDef.radarDistanceJam),
			midX = (dims and dims.midx) or 0, -- model mid position offset, the jammer emits from the unit's mid position
			midZ = (dims and dims.midz) or 0,
		}
	end
end

local discShader ---@type LuaShader
local smoothShader ---@type LuaShader
local sheetShader ---@type LuaShader
local minimapShader ---@type LuaShader
local passVAO ---@type VAO

local alliedTex ---@type string -- union of the allied jammers' coverage, one texel per radar cell of the map
local sets = {} ---@type table<number, table|false> -- radius in cells -> textures of the previewed disc
local jammerUnits = {} ---@type table<UnitID, boolean> -- units with a radar jammer, filtered to the local ally team when collected
local selectedJammerUnitID = false ---@type UnitID|false

-- live values of the JammerPreview* configint settings
local settings = {
	alwaysShow = true, -- JammerPreviewAlwaysShow
	alliedCoverage = true, -- JammerPreviewAlliedCoverage
	minimap = true, -- JammerPreviewMinimap
}
local settingsCheckedAt = -mathHuge

-- the allied jammers' coverage, as last rendered into alliedTex
local allied = {
	count = -1, -- covering jammers; -1 until the first check, so the texture gets cleared
	cells = {}, -- emitter cell x, cell z, radius in cells per covering jammer
	scratch = {},
	x0 = mathHuge, -- bounding rectangle of the union in radar cells
	z0 = mathHuge,
	x1 = -mathHuge,
	z1 = -mathHuge,
	checkedAt = -mathHuge,
	shownFrame = -10, -- last draw frame it was shown
}

-- the previewed jammer
local preview = {
	frame = -10, -- last draw frame it was drawn
	time = 0,
	radius = nil,
	x = 0, -- emitter world position
	z = 0,
	spawnStart = 0.0,
	movedAt = -mathHuge, -- last time the emitter moved to another radar cell
	inactive = 0.0, -- 0 while the previewed jammer jams, 1 while it does not, eased in between
}

-- what DrawWorld drew, for DrawInMiniMap
local minimapFrame = -10
local minimapSet ---@type table?
local minimapAllied = false
local minimapInactive = 0.0

local passVsPath = "LuaUI/Shaders/sensor_ranges_radar_preview_pass.vert.glsl"

local discShaderCache = {
	vssrcpath = passVsPath,
	fssrcpath = "LuaUI/Shaders/sensor_ranges_jammer_preview_disc.frag.glsl",
	shaderName = "jammerPreviewDisc GL4",
	uniformFloat = {
		discParams = { 0, 0, 1, 0 },
		passRect = { -1, -1, 1, 1 },
	},
	shaderConfig = shaderConfig,
}

local smoothShaderCache = {
	vssrcpath = passVsPath,
	fssrcpath = "LuaUI/Shaders/sensor_ranges_radar_preview_smooth.frag.glsl",
	shaderName = "jammerPreviewSmooth GL4",
	uniformInt = {
		prevTex = 0,
		targetTex = 1,
	},
	uniformFloat = {
		smoothParams = { 0, 0, 1, 1 },
	},
	shaderConfig = shaderConfig,
}

local sheetShaderCache = {
	vssrcpath = passVsPath,
	fssrcpath = "LuaUI/Shaders/sensor_ranges_jammer_preview.frag.glsl",
	shaderName = "jammerPreviewSheet GL4",
	uniformInt = {
		mapDepths = 0,
		modelDepths = hasModelDepth and 1 or nil,
		coverageTex = 2,
		alliedTex = 3,
		targetTex = 4,
	},
	uniformFloat = {
		previewParams = { 0, 0, -1, 0 },
		previewInactive = 0,
		stippleOffset = 0,
		emitterXZ = { 0, 0 },
		alliedParams = { 0, 0 },
		passRect = { -1, -1, 1, 1 },
	},
	shaderConfig = shaderConfig,
}

local minimapShaderCache = {
	vssrcpath = "LuaUI/Shaders/sensor_ranges_radar_preview_minimap.vert.glsl",
	fssrcpath = "LuaUI/Shaders/sensor_ranges_radar_preview_minimap.frag.glsl",
	shaderName = "jammerPreviewMinimap GL4",
	uniformInt = {
		coverageTex = 0,
		radarInfoTex = 1,
		targetTex = 2,
	},
	uniformFloat = {
		discParams = { 0, 0, -1, 0 },
		inactiveParams = { 0, 1, 1 },
		mapParams = { MAP_CELLS_X, MAP_CELLS_Z, 0, 0 },
	},
	shaderConfig = shaderConfig,
}

local function goodbye(reason)
	spEcho("Sensor Ranges Jammer Preview widget exiting with reason: " .. reason)
	widgetHandler:RemoveWidget()
end

local function makeDataTexture(sizeX, sizeY, format)
	return gl.CreateTexture(sizeX, sizeY, {
		format = format,
		fbo = true,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
end

local function deleteSetTextures(set)
	for _, tex in ipairs({ set.target, set.state[1], set.state[2] }) do
		gl.DeleteTexture(tex)
	end
end

-- textures of the previewed disc for a radius in cells, created on demand: the exact disc and the smoothed
-- coverage (ping-ponged), (2 * radius + 1)^2 texels around the emitter's cell
local function getSet(radiusCells)
	local set = sets[radiusCells]
	if set == nil then
		local size = 2 * radiusCells + 1
		set = {
			radius = radiusCells,
			target = makeDataTexture(size, size, GL_R16F),
			state = { makeDataTexture(size, size, GL_R16F), makeDataTexture(size, size, GL_R16F) },
			cur = 1,
			bx = nil, -- emitter cell of the rendered disc
			bz = nil,
		}
		if not (set.target and set.state[1] and set.state[2]) then
			deleteSetTextures(set)
			set = false
		end
		sets[radiusCells] = set
	end
	return set or nil
end

local function deleteTextures()
	for _, set in pairs(sets) do
		if set then
			deleteSetTextures(set)
		end
	end
	sets = {}
	if alliedTex then
		gl.DeleteTexture(alliedTex)
		alliedTex = nil
	end
end

local function initgl4()
	if not hasMapDepth then
		goodbye("AllowDeferredMapRendering is off, the coverage is projected through the map depth buffer")
		return false
	end
	-- Files added to the game archive while a game is running are invisible to the VFS (the .sdd file
	-- list is indexed at game start), and CheckShaderUpdates silently returns nil for missing sources.
	local caches = { discShaderCache, smoothShaderCache, sheetShaderCache, minimapShaderCache }
	for _, cache in ipairs(caches) do
		for _, path in ipairs({ cache.vssrcpath, cache.fssrcpath }) do
			if not VFS.FileExists(path) then
				goodbye("shader source not found: " .. path .. " (new files need a game restart to show up in the VFS)")
				return false
			end
		end
	end

	local shaders = {}
	for i, cache in ipairs(caches) do
		---@diagnostic disable-next-line: call-non-callable, need-check-nil
		shaders[i] = LuaShader.CheckShaderUpdates(cache)
		if not shaders[i] then
			goodbye("Failed to compile " .. cache.shaderName)
			return false
		end
	end
	discShader, smoothShader, sheetShader, minimapShader = shaders[1], shaders[2], shaders[3], shaders[4]

	local vao = InstanceVBOTable.MakeTexRectVAO()
	if not vao then
		goodbye("Failed to create the jammer preview VAO")
		return false
	end
	passVAO = vao

	local tex = makeDataTexture(MAP_CELLS_X, MAP_CELLS_Z, GL_R8)
	if not tex then
		goodbye("Failed to create the allied jammer coverage texture")
		return false
	end
	alliedTex = tex
	return true
end

local function readConfig()
	settings.alwaysShow = Spring.GetConfigInt("JammerPreviewAlwaysShow", 1) ~= 0
	settings.alliedCoverage = Spring.GetConfigInt("JammerPreviewAlliedCoverage", 1) ~= 0
	settings.minimap = Spring.GetConfigInt("JammerPreviewMinimap", 1) ~= 0
end

function widget:Update()
	local now = osClock()
	if now - settingsCheckedAt > SETTINGS_POLL_SECONDS then
		settingsCheckedAt = now
		readConfig()
	end
end

local function trackUnit(unitID, unitDefID)
	if jammerDefs[unitDefID] then
		jammerUnits[unitID] = true
	end
end

local function scanAlliedUnits()
	jammerUnits = {}
	for _, teamID in ipairs(spGetTeamList(spGetMyAllyTeamID()) or {}) do
		for _, unitID in ipairs(spGetTeamUnits(teamID) or {}) do
			trackUnit(unitID, spGetUnitDefID(unitID))
		end
	end
	allied.checkedAt = -mathHuge
end

function widget:UnitCreated(unitID, unitDefID)
	trackUnit(unitID, unitDefID)
end

function widget:UnitGiven(unitID, unitDefID)
	trackUnit(unitID, unitDefID)
end

function widget:UnitDestroyed(unitID)
	jammerUnits[unitID] = nil
end

function widget:PlayerChanged()
	scanAlliedUnits()
end

-- Whether the engine lets the unit's jammer work: on, not stunned and, with the sensors.requireUpkeep modrule,
-- its upkeep paid (a game-side pause zeroes the radius instead)
local function isJamming(unitID)
	return spGetUnitIsActive(unitID)
		and not spGetUnitIsStunned(unitID)
		and (not engineRequiresUpkeep or spGetUnitIsUpkeepPaid(unitID))
end

-- Allied jammers the engine gives coverage (ILosType::UpdateUnit: finished, activated, not stunned): emitter cell
-- and radius in cells of each, appended to the flat list `out`. Returns their count.
local function collectAlliedJammers(out)
	local myAllyTeamID = spGetMyAllyTeamID()
	local n = 0
	for unitID in pairs(jammerUnits) do
		if spGetUnitAllyTeam(unitID) ~= myAllyTeamID then -- gone, or given away
			jammerUnits[unitID] = nil
		elseif isJamming(unitID) then
			local radiusCells = radiusToCells(spGetUnitSensorRadius(unitID, "radarJammer") or 0)
			if radiusCells >= 1 then
				local _, _, _, mx, _, mz = spGetUnitPosition(unitID, true)
				if mx then
					out[n + 1], out[n + 2], out[n + 3] = worldToCell(mx), worldToCell(mz), radiusCells
					n = n + 3
				end
			end
		end
	end
	return n / 3
end

-- Renders the union of the allied jammers' discs into alliedTex: each draws just its disc's rectangle
local function drawAlliedUnion()
	gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
	local cells = allied.cells ---@type table<integer, number>
	local sx, sz = 2 / MAP_CELLS_X, 2 / MAP_CELLS_Z
	discShader:Activate()
	for i = 1, allied.count * 3, 3 do
		local bx, bz, radius = cells[i], cells[i + 1], cells[i + 2]
		discShader:SetUniform("discParams", bx, bz, radius, 1)
		discShader:SetUniform(
			"passRect",
			(bx - radius) * sx - 1,
			(bz - radius) * sz - 1,
			(bx + radius + 1) * sx - 1,
			(bz + radius + 1) * sz - 1
		)
		passVAO:DrawArrays(GL.TRIANGLES)
	end
	discShader:SetUniform("passRect", -1, -1, 1, 1)
	discShader:Deactivate()
end

-- Re-renders the allied coverage when a jammer turned on or off, moved to another cell or changed its range
local function updateAllied(now, force)
	if not force and now - allied.checkedAt < ALLIED_POLL_SECONDS then
		return
	end
	allied.checkedAt = now
	local cells, previous = allied.scratch, allied.cells
	local count = collectAlliedJammers(cells)
	local changed = count ~= allied.count
	if not changed then
		for i = 1, count * 3 do
			if cells[i] ~= previous[i] then
				changed = true
				break
			end
		end
	end
	if not changed then
		return
	end

	allied.cells, allied.scratch, allied.count = cells, previous, count
	local x0, z0, x1, z1 = mathHuge, mathHuge, -mathHuge, -mathHuge
	for i = 1, count * 3, 3 do
		local radius = cells[i + 2]
		x0, x1 = mathMin(x0, cells[i] - radius), mathMax(x1, cells[i] + radius)
		z0, z1 = mathMin(z0, cells[i + 1] - radius), mathMax(z1, cells[i + 1] + radius)
	end
	allied.x0, allied.z0, allied.x1, allied.z1 = x0, z0, x1, z1
	gl.RenderToTexture(alliedTex, drawAlliedUnion)
end

-- The jammer being previewed right now: its jammerDefs entry and the selected unit (nil while placing one), or nil.
-- Evaluated live by every draw callin rather than cached, so nothing can outlive the command / selection it came from.
local function previewSource()
	if selectedJammerUnitID then
		-- verify every frame, not just on SelectionChanged: the unit may be gone or no longer selected
		local unitDefID = spGetUnitDefID(selectedJammerUnitID)
		local def = unitDefID and jammerDefs[unitDefID]
		if def and spIsUnitSelected(selectedJammerUnitID) then
			return def, selectedJammerUnitID
		end
		selectedJammerUnitID = false
		return nil
	end

	local _, cmdID = spGetActiveCommand()
	local unitDefID ---@type number?
	if cmdID and cmdID < 0 then
		unitDefID = -cmdID
	elseif spGetGameFrame() <= 0 then
		-- before game start builds are queued through the pregame build widget, not via an active command
		local pregameBuild = WG["pregame-build"]
		unitDefID = pregameBuild and pregameBuild.getPreGameDefID and pregameBuild.getPreGameDefID()
	end
	local def = unitDefID and jammerDefs[unitDefID]
	if def and def.radiusCells >= 1 then
		return def, nil
	end
	return nil
end

-- World position under the cursor: through a PIP window, the minimap or the world view; nil on the sky or off the map
local function cursorWorldPos()
	local mx, my = spGetMouseState()
	-- Hovering a PIP (or the PIP-minimap: WG.pip_minimap is the same object as WG.pipN)
	-- maps to the world position under the cursor in that view, not the ground behind it
	for pipNumber = 0, 4 do
		local pipApi = WG["pip" .. pipNumber]
		if pipApi and pipApi.ScreenToWorld then
			local wx, wz = pipApi.ScreenToWorld(mx, my)
			if wx and wz then
				if wx < 0 or wz < 0 or wx > Game.mapSizeX or wz > Game.mapSizeZ then
					return nil
				end
				return wx, spGetGroundHeight(wx, wz), wz
			end
		end
	end
	-- useMiniMap=true: over the engine minimap, trace through it instead of the world behind it
	local _, coords = spTraceScreenRay(mx, my, true, true)
	if not coords or coords[1] < 0 or coords[3] < 0 or coords[1] > Game.mapSizeX or coords[3] > Game.mapSizeZ then
		return nil
	end
	return coords[1], coords[2], coords[3]
end

-- x, z of the mid position of a building placed at x, z with the given facing (CSolidObject::GetObjectSpacePos,
-- buildings are upright: frontdir is the facing's direction and rightdir = (-frontdir.z, frontdir.x))
local function placedMidPos(def, x, z, facing)
	if facing == 1 then
		return x + def.midZ, z + def.midX
	elseif facing == 2 then
		return x + def.midX, z - def.midZ
	elseif facing == 3 then
		return x - def.midZ, z - def.midX
	end
	return x - def.midX, z + def.midZ
end

-- The previewed jammer's radius in cells, the world x, z of its emitter (the unit's mid position) and 1 when it
-- does not jam right now (0 when it does or is being placed), or nil
local function getPreview()
	local def, unitID = previewSource()
	if not def then
		return nil
	end
	if unitID then
		local _, _, _, mx, _, mz = spGetUnitPosition(unitID, true)
		if not mx then
			return nil
		end
		local radiusCells = radiusToCells(spGetUnitSensorRadius(unitID, "radarJammer") or 0)
		local jamming = radiusCells >= 1 and isJamming(unitID)
		if radiusCells < 1 then
			radiusCells = def.radiusCells -- a game-side pause zeroes the radius
		end
		if radiusCells < 1 then
			return nil
		end
		return radiusCells, mx, mz, jamming and 0 or 1
	end

	local x, y, z = cursorWorldPos()
	if not x then
		return nil
	end
	-- snap to the build grid the way the placement itself is snapped (build facing included), so the preview
	-- is computed for the spot the jammer will actually stand on, not the raw cursor position
	local facing = spGetBuildFacing()
	local buildX, _, buildZ = spPos2BuildPos(def.unitDefID, x, y, z, facing)
	return def.radiusCells, placedMidPos(def, buildX, buildZ, facing)
end

local function drawPass()
	passVAO:DrawArrays(GL.TRIANGLES)
end

local function drawClearedPass()
	gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
	passVAO:DrawArrays(GL.TRIANGLES)
end

-- Disc and smoothing passes of the previewed jammer. Returns its texture set, nil if it could not be created.
local function preparePreview(radius, emitterX, emitterZ, inactive, alreadyShown, now, drawFrame)
	local set = getSet(radius)
	if not set then
		return nil
	end

	-- a gap in draw frames or another radius means the preview just (re)appeared
	local fresh = (drawFrame - preview.frame > 1) or (preview.radius ~= radius)
	local dt = fresh and 0 or mathMin(now - preview.time, 0.1)
	if fresh then
		preview.spawnStart = now - (alreadyShown and 60 or 0) -- coverage already on screen doesn't spread out again
		preview.inactive = inactive
	end
	preview.frame, preview.time, preview.radius = drawFrame, now, radius
	preview.x, preview.z = emitterX, emitterZ
	preview.inactive = preview.inactive + (inactive - preview.inactive) * (1 - mathExp(-dt * SMOOTH_RATE))

	local bx, bz = worldToCell(emitterX), worldToCell(emitterZ)
	-- cells the emitter moved since the last frame
	local moved = set.bx and not fresh
	local shiftX = moved and bx - set.bx or 0
	local shiftZ = moved and bz - set.bz or 0
	if shiftX ~= 0 or shiftZ ~= 0 then
		preview.movedAt = now
	end
	if fresh or set.bx ~= bx or set.bz ~= bz then
		if selectedJammerUnitID then
			allied.checkedAt = -mathHuge -- a selected jammer's allied coverage moves along with it, in the same frame
		end
		discShader:Activate()
		discShader:SetUniform("discParams", bx, bz, radius, 0)
		gl.RenderToTexture(set.target, drawClearedPass)
		discShader:Deactivate()
		set.bx, set.bz = bx, bz
	end

	-- ease the shown coverage towards the disc (ping-pong between the two state textures); the previous state
	-- is read shifted by the emitter's move, so cells stay put in the world
	local prevTex = set.state[set.cur]
	set.cur = 3 - set.cur
	gl.Texture(0, prevTex)
	gl.Texture(1, set.target)
	smoothShader:Activate()
	local smoothRate = (not selectedJammerUnitID and (now - preview.movedAt) < 0.3) and SMOOTH_RATE_DRAG or SMOOTH_RATE
	smoothShader:SetUniform("smoothParams", shiftX, shiftZ, 1 - mathExp(-dt * smoothRate), fresh and 1 or 0)
	gl.RenderToTexture(set.state[set.cur], drawPass)
	smoothShader:Deactivate()
	gl.Texture(0, false)
	gl.Texture(1, false)
	return set
end

-- Clip-space rectangle of the screen area that can show a rectangle of radar cells: the screen bounds of its box from
-- the lowest to the highest ground, clipped to the screen. The whole screen when the box reaches behind the camera.
local function getScreenRect(x0, z0, x1, z1)
	local minY, maxY = spGetGroundExtremes()
	minY, maxY = mathMax(minY or 0, 0), mathMax(maxY or 0, 0) -- below 0 the sheet lies on the water surface
	local camX, camY, camZ = spGetCameraPosition()
	local dirX, dirY, dirZ = spGetCameraDirection()
	local vsx, vsy = spGetViewGeometry()
	local left, bottom, right, top = mathHuge, mathHuge, -mathHuge, -mathHuge
	for corner = 0, 7 do
		local x, y, z = x0, minY, z0
		if corner % 2 == 1 then
			x = x1 + 1
		end
		if corner % 4 >= 2 then
			z = z1 + 1
		end
		if corner >= 4 then
			y = maxY
		end
		x, z = x * RADAR_CELL, z * RADAR_CELL
		if (x - camX) * dirX + (y - camY) * dirY + (z - camZ) * dirZ < 1 then
			return -1, -1, 1, 1
		end
		local sx, sy = spWorldToScreenCoords(x, y, z)
		left, right = mathMin(left, sx), mathMax(right, sx)
		bottom, top = mathMin(bottom, sy), mathMax(top, sy)
	end
	-- a pixel of slack for the outline's anti-aliasing
	return mathMax((left - 1) / vsx * 2 - 1, -1),
		mathMax((bottom - 1) / vsy * 2 - 1, -1),
		mathMin((right + 1) / vsx * 2 - 1, 1),
		mathMin((top + 1) / vsy * 2 - 1, 1)
end

-- The sheet of the previewed disc and the allied coverage: one pass over their screen area that projects it onto the terrain
local function drawSheet(set, showAllied, now)
	local x0, z0, x1, z1 = mathHuge, mathHuge, -mathHuge, -mathHuge
	if set then
		x0, z0, x1, z1 = set.bx - set.radius, set.bz - set.radius, set.bx + set.radius, set.bz + set.radius
	end
	if showAllied and allied.count > 0 then
		x0, z0 = mathMin(x0, allied.x0), mathMin(z0, allied.z0)
		x1, z1 = mathMax(x1, allied.x1), mathMax(z1, allied.z1)
	end
	x0, z0 = mathMax(x0, 0), mathMax(z0, 0)
	x1, z1 = mathMin(x1, MAP_CELLS_X - 1), mathMin(z1, MAP_CELLS_Z - 1)
	if x1 < x0 or z1 < z0 then
		return
	end
	local left, bottom, right, top = getScreenRect(x0, z0, x1, z1)
	if right <= left or top <= bottom then
		return -- off screen
	end

	gl.Texture(0, "$map_gbuffer_zvaltex")
	if hasModelDepth then
		gl.Texture(1, "$model_gbuffer_zvaltex")
	end
	if set then
		gl.Texture(2, set.state[set.cur])
		gl.Texture(4, set.target) -- exact coverage: the outline follows it without the smoothing's delay
	end
	if showAllied then
		gl.Texture(3, alliedTex)
	end
	sheetShader:Activate()
	if set then
		sheetShader:SetUniform("previewParams", set.bx, set.bz, set.radius, now - preview.spawnStart)
	else
		sheetShader:SetUniform("previewParams", 0, 0, -1, 0)
	end
	sheetShader:SetUniform("previewInactive", set and preview.inactive or 0)
	sheetShader:SetUniform("emitterXZ", preview.x, preview.z)
	-- the allied coverage fades in with the preview, unless it is always shown
	local alliedOpacity = settings.alwaysShow and 1 or mathMin((now - preview.spawnStart) * 4, 1)
	sheetShader:SetUniform("alliedParams", showAllied and 1 or 0, alliedOpacity)
	sheetShader:SetUniform("stippleOffset", (now * OUTLINE_DASH_SPEED / RADAR_CELL) % 1)
	sheetShader:SetUniform("passRect", left, bottom, right, top)
	passVAO:DrawArrays(GL.TRIANGLES)
	sheetShader:Deactivate()
	for unit = 0, 4 do
		gl.Texture(unit, false)
	end
end

function widget:DrawWorld()
	if Spring.IsGUIHidden() or (WG.topbar and WG.topbar.showingQuit()) then
		return
	end
	local radius, emitterX, emitterZ, inactive = getPreview()
	local showAllied = settings.alwaysShow or (radius ~= nil and settings.alliedCoverage)
	if not (radius or showAllied) then
		return
	end

	local now = osClock()
	local drawFrame = spGetDrawFrame()
	gl.DepthTest(false)
	gl.Culling(false)
	gl.Blending(false)
	local set
	if radius then
		-- a selected allied jammer that jams was already drawn with the always shown allied coverage
		local alreadyShown = settings.alwaysShow and inactive == 0 and jammerUnits[selectedJammerUnitID] == true
		set = preparePreview(radius, emitterX, emitterZ, inactive or 0, alreadyShown, now, drawFrame)
	end
	if showAllied then
		-- check right away when the allied coverage (re)appears, it may be stale
		updateAllied(now, drawFrame - allied.shownFrame > 1)
		allied.shownFrame = drawFrame
	end
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	drawSheet(set, showAllied, now)
	minimapFrame, minimapSet, minimapAllied, minimapInactive = drawFrame, set, showAllied, preview.inactive
end

-- Flat fill of the previewed (and allied) jammer coverage on the minimap, outlined at uncovered cells. Also
-- reached through the PIP minimap, which forwards this callin with its viewport remapped. Only draws while
-- DrawWorld is drawing: the engine renders its minimap texture from Game::Update, before DrawWorld and at its
-- own refresh rate, so the previous draw frame has to count as current here.
function widget:DrawInMiniMap()
	if not settings.minimap or spGetDrawFrame() - minimapFrame > 1 then
		return
	end
	-- the live check keeps the preview on the minimap from outliving its command / selection
	local set = minimapSet
	if set and not previewSource() then
		set = nil
	end
	local showAllied = minimapAllied and (settings.alwaysShow or set ~= nil)
	if not (set or showAllied) then
		return
	end

	gl.DepthTest(false)
	gl.Culling(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	if set then
		gl.Texture(0, set.state[set.cur]) -- smoothed coverage: the fill
		gl.Texture(2, set.target) -- exact engine coverage: the outline
	end
	if showAllied then
		gl.Texture(1, alliedTex)
	end
	minimapShader:Activate()
	if set then
		minimapShader:SetUniform("discParams", set.bx, set.bz, set.radius, showAllied and 1 or 0)
	else
		minimapShader:SetUniform("discParams", 0, 0, -1, 1)
	end
	minimapShader:SetUniform(
		"inactiveParams",
		set and minimapInactive or 0,
		shaderConfig.INACTIVE_ALPHA,
		shaderConfig.INACTIVE_OUTLINE_ALPHA
	)
	local _, vsy = spGetViewGeometry()
	minimapShader:SetUniform(
		"mapParams",
		Game.mapSizeX / RADAR_CELL,
		Game.mapSizeZ / RADAR_CELL,
		getCurrentMiniMapRotationOption() or 0,
		shaderConfig.MINIMAP_OUTLINE_WIDTH * (vsy or 1080) / 1080 -- outline width in pixels
	)
	passVAO:DrawArrays(GL.TRIANGLES)
	minimapShader:Deactivate()
	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)
end

function widget:SelectionChanged(sel)
	selectedJammerUnitID = false
	if #sel == 1 and jammerDefs[spGetUnitDefID(sel[1])] then
		selectedJammerUnitID = sel[1]
	end
end

function widget:Initialize()
	-- no shader support (headless), or no fog of war, which leaves jammers nothing to hide
	if not gl.CreateShader or Spring.GetModOptions().disable_fogofwar then
		widgetHandler:RemoveWidget()
		return
	end
	if not initgl4() then
		return
	end
	readConfig()
	scanAlliedUnits()
	widget:SelectionChanged(Spring.GetSelectedUnits())
end

function widget:Shutdown()
	deleteTextures()
	for _, shader in ipairs({ discShader, smoothShader, sheetShader, minimapShader }) do
		shader:Delete()
	end
end
