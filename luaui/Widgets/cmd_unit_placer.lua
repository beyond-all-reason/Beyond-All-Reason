local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Unit Placer",
		desc = "The terraform brush's UNITS tool: scatter, point, formations, remove, select and edit real units, undo by stroke",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false, -- the terraform suite turns it on; it must never load in a normal game
	}
end

-- The terraform brush's UNITS tool (refactor plan, U6). The same unit library and the same
-- placer as the mission editor (luaui/RmlWidgets/gui_unit_library, luaui/Include/unit_placer);
-- what differs is where a placement goes: here it becomes REAL units, through the Unit Placer
-- gadget, which keeps every gesture as one stroke to undo and redo.
--
-- It works the way the FEATURES tool (cmd_feature_placer.lua) does, with units:
--   SCATTER  a brush (shape, radius, count, cadence) stamping units at random, regular or
--            clustered spots; or, with distribution line / grid / box, a FORMATION dragged
--            out through the shared placer (the Blueprint API draws it)
--   POINT    one unit per click under the cursor (a multi-pick cycles the type)
--   REMOVE   the brush takes units away; in the other modes right-click lets go of the pick
-- Every placement honours the smart filters and the terraform brush's symmetry. With
-- nothing picked the left button SELECTS instead: click, Shift+click, box drag; drag a
-- selected unit to move them all, R turns them, Ctrl+click faces them at a point, Delete,
-- Ctrl+C / X / V.
--
-- Keys while active: Ctrl+Z / Ctrl+Y (Ctrl+Shift+Z) undo and redo whole strokes, Tab cycles
-- the formation, R / Shift+R turn, Escape steps back (selection, then the pick). Wheel: Alt
-- rotate, Shift count, Space cadence, Ctrl radius. The panel's TEAM chip cycles the team.

local Placer = VFS.Include("luaui/Include/unit_placer/placer.lua")
local Cycle = VFS.Include("luaui/Include/unit_placer/cycle.lua")
local Layout = VFS.Include("luaui/Include/unit_placer/layout.lua")
local BrushShapes = require("common/brush_shapes")
local Scatter = require("common/feature_scatter")

local MSG = {
	place = "$unit_place$",
	remove = "$unit_remove$",
	transform = "$unit_transform$",
	clearAll = "$unit_clearall$",
	undo = "$unit_place_undo$",
	redo = "$unit_place_redo$",
	mission = "$unit_mission$",
}

-- MISSION UNITS (Terraform Brush 1.18). The brush places either LIVE units (normal units
-- to look at, fight with, light) or MISSION units: stand-ins for a mission, frozen in place
-- by the gadget and carrying a mission TEAM NUMBER (0..TEAMS-1) that need not exist in this
-- session (they stand on Gaia when it does not). The map project saves them with that
-- number, which is what the mission editor takes as its loadout. The kind and the mission
-- team are the brush's own (owner "terraform_brush"); another owner (the mission editor)
-- brings its own sink and teams.
local mission = {
	TEAMS = 16,
	PARAM = "mission_team",
	-- one colour per mission team for the ground rings
	PALETTE = {
		{ 0.20, 0.45, 1.00 },
		{ 1.00, 0.25, 0.20 },
		{ 0.20, 0.85, 0.30 },
		{ 1.00, 0.85, 0.15 },
		{ 0.75, 0.30, 1.00 },
		{ 0.15, 0.90, 0.90 },
		{ 1.00, 0.55, 0.10 },
		{ 1.00, 0.45, 0.75 },
		{ 0.55, 0.75, 0.20 },
		{ 0.45, 0.30, 0.15 },
		{ 0.60, 0.60, 1.00 },
		{ 0.90, 0.90, 0.90 },
		{ 0.10, 0.40, 0.30 },
		{ 0.70, 0.10, 0.30 },
		{ 0.35, 0.35, 0.35 },
		{ 0.95, 0.75, 0.55 },
	},
	markers = {}, -- { unitID, team } refreshed every few frames
	markersAt = -1000,
	lastGame = {}, -- the game's selection as the LIVE mirror last saw it (a set)
}

--- The mission team of a unit, nil for a live one.
function mission.teamOf(unitID)
	local m = Spring.GetUnitRulesParam(unitID, mission.PARAM)
	return (m and m >= 0) and m or nil
end

--- The session team a team number stands on: itself when it exists, else Gaia.
function mission.realTeam(team)
	local tid, _, isDead = Spring.GetTeamInfo(team, false)
	if tid and not isDead then
		return team
	end
	return Spring.GetGaiaTeamID()
end
local LIBRARY_TITLE = "TERRAFORM BRUSH"
local SAVE_DIR = "Terraform Brush/UnitMaps/"
--- Units per message: a 40x40 grid is 1600 units, and one message carrying them all would
--- be a very long string for one frame.
local BATCH = 40
local KEY = {
	backspace = 8,
	escape = 27,
	a = 97,
	c = 99,
	r = 114,
	v = 118,
	x = 120,
	y = 121,
	z = 122,
	delete = 127,
	space = 0x20,
}
-- Brush limits, the feature placer's.
local LIMIT = {
	radiusMin = 8,
	radiusMax = 2000,
	radiusStep = 8,
	countMax = 500,
	rotationStep = 15,
	spacingMax = 32,
}
local GHOST_ALPHA = 0.5
--- Ghosts shown at most; placement is never capped.
local PREVIEW_GHOST_CAP = 300
--- A press that moves less than this many pixels is a click, not a box or a drag.
local BOX_MIN_PX = 4
local CIRCLE_SEGMENTS = 48
local SMART_GRID_STEP = 24
local SEED_MAX = 16777216 -- 2^24: Lua numbers are floats here
local SEED_STRIDE = 8191
local FORMATION_MODE = { line = "LINE", grid = "GRID", box = "BOX" }
---@type table<string, boolean>
local DISTRIBUTIONS = { random = true, regular = true, clustered = true, line = true, grid = true, box = true }
---@type table<string, boolean>
local SHAPES = { circle = true, square = true, hexagon = true, octagon = true, triangle = true }
---@type table<string, boolean>
local MODES = { scatter = true, point = true, remove = true }

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local cos, sin, pi = math.cos, math.sin, math.pi

----------------------------------------------------------------
-- State (tables, to keep the file's locals few)
----------------------------------------------------------------
---@class UnitPlacerSmartFilters
---@field avoidWater boolean
---@field avoidCliffs boolean
---@field slopeMax number
---@field preferSlopes boolean
---@field slopeMin number
---@field altMinEnable boolean
---@field altMin number
---@field altMaxEnable boolean
---@field altMax number

---@class UnitPlacerState
---@field active boolean
---@field mode string?
---@field shape string
---@field radius number
---@field rotation number
---@field rotRandom number
---@field unitCount number
---@field cadence number
---@field distribution string
---@field smartEnabled boolean
---@field smartFilters UnitPlacerSmartFilters
---@field team number?
---@field dragging boolean
---@field dragAction string?
---@field dragStroke (string|number)?
---@field placeTimer number
---@field undoCount number
---@field redoCount number
---@field strokeCount number
---@field edgeFade number
---@field spacing number
---@field modDrag boolean
---@field modOverride boolean
---@field modBase string?
---@field lastStampX number?
---@field lastStampZ number?

---@type UnitPlacerState
local up = {
	active = false,
	mode = nil, -- "scatter" | "point" | "remove"
	shape = "circle",
	radius = 200,
	rotation = 0,
	rotRandom = 0, -- 0 = every unit the same heading, 100 = fully random
	unitCount = 1,
	cadence = 10, -- 1-1000, logarithmic (higher = faster)
	distribution = "random",
	smartEnabled = false,
	smartFilters = {
		avoidWater = false,
		avoidCliffs = false,
		slopeMax = 45,
		preferSlopes = false,
		slopeMin = 10,
		altMinEnable = false,
		altMin = 0,
		altMaxEnable = false,
		altMax = 200,
	},
	team = nil,
	kind = "live", -- "live" | "mission": what the brush places (see `mission`)
	missionTeam = 0, -- the mission team number new mission units get
	dragging = false, -- the button is held on a brush gesture
	dragAction = nil, -- "place" | "remove"
	dragStroke = nil, -- one hold is one stroke
	placeTimer = 0,
	undoCount = 0,
	redoCount = 0,
	strokeCount = 0,
	edgeFade = 1,
	spacing = 0, -- build squares between units in a line / grid / box drag (the game's build spacing)
	modDrag = false, -- a Shift-press drag through the placer, from point or brush mode
	modOverride = false, -- the build-drag keys hold the placer's shape right now
	modBase = nil, -- the shape to go back to when they are let go
}

---@class UnitPlacerGrid
---@field overlay boolean
---@field snap boolean
---@field snapSize number
---@field showing boolean
---@field dl any
---@field dlSize number?
---@field dirty boolean
---@field forceShowDefID number?

---@type UnitPlacerGrid
local grid = {
	overlay = false,
	snap = false,
	snapSize = 48, -- the build grid widget's spacing (3 * 16 elmos)
	showing = false,
	dl = nil,
	dlSize = nil,
	dirty = false,
	forceShowDefID = nil,
}

-- The stamp preview: a brush-relative layout cached by seed and parameters, so it keeps its
-- shape while the cursor moves; the seed is rerolled after every stamp.
---@class UnitPlacerPreview
---@field seed number
---@field layout table?
---@field layoutKey string?
---@field stampKey string?
---@field stamp table?
---@field warnedCap boolean

---@type UnitPlacerPreview
local pv = {
	seed = floor(os.clock() * 1000) % SEED_MAX,
	layout = nil,
	layoutKey = nil,
	stampKey = nil,
	stamp = nil,
	warnedCap = false,
}

-- The selection (select mode: active, scatter or point, nothing picked).
---@class UnitPlacerSelection
---@field ids UnitID[]
---@field set table<UnitID, boolean>
---@field boxing boolean
---@field boxX1 number
---@field boxY1 number
---@field boxX2 number
---@field boxY2 number
---@field drag table?
---@field clipboard table?
---@field pruneTimer number
---@field boxAdditive boolean?
---@field silent boolean? set while an owner selects, so its sink is not told back
---@field pointer { x: number, z: number }? a harness point standing in for the mouse

---@type UnitPlacerSelection
local sel = {
	ids = {},
	set = {},
	boxing = false,
	boxX1 = 0,
	boxY1 = 0,
	boxX2 = 0,
	boxY2 = 0,
	drag = nil, -- { grabID, pressX, pressY, startX, startZ, moved, origins, targets }
	clipboard = nil, -- { { unitDefName, dx, dz, facing, team }, ... }
	pointer = nil, -- a harness pointer { x, z } standing in for the mouse (Tool.setPointer)
	pruneTimer = 0,
}

-- The lasso round a multi-selection (see "The lasso" below); here because the selection
-- code above that section marks it dirty.
---@type { hull: table?, dirty: boolean, age: number, hover: boolean }
local lasso = { hull = nil, dirty = true, age = 0, hover = false }

-- Built in widget:Initialize, before any callin that reads it.
local placer ---@type table
---@type table?
local lastPick -- { kind = "unit" | "blueprint" | "paste", value, facing, cycle }
local Tool = {} -- WG.UnitPlacerTool

----------------------------------------------------------------
-- Provider and sink (units unification, phase 2)
----------------------------------------------------------------
-- Everything the gestures READ about placed units goes through `owner.provider`, and
-- everything they DO goes through `owner.sink`. The brush installs the engine pair (real
-- units through the Unit Placer gadget, below); the mission editor installs a pair over its
-- document (records keyed by string, its own undo), and the same gestures, brush,
-- formations, keys and panel drive both. An id is whatever the provider hands out: a unit
-- id here, a record key there; the tool never arithmetics on it.
--
-- provider = { valid(id), info(id) -> { id, name, defID, x, z, facing, xsize, zsize, team,
--   extra? } | nil, extra?(id) -> table (optional: what a copy carries besides type and place), all() -> ids, inScreenRect(x1, y1, x2, y2) -> ids, inCylinder(x, z, r)
--   -> ids, teams() -> teamIDs, myTeam() -> teamID, pick(mx, my) -> id | nil }
-- sink = { place(spots, strokeId) -> strokeId, remove(ids, strokeId), transform(moves),
--   undo(), redo(), clearAll(strokeId) }
local engineProvider = {
	valid = function(unitID)
		return Spring.ValidUnitID(unitID)
	end,
	info = function(unitID)
		if not Spring.ValidUnitID(unitID) then
			return nil
		end
		local def = UnitDefs[Spring.GetUnitDefID(unitID)]
		local x, _, z = Spring.GetUnitPosition(unitID)
		if not (def and x) then
			return nil
		end
		return {
			id = unitID,
			name = def.name,
			defID = def.id,
			x = x,
			z = z,
			facing = (Spring.GetUnitBuildFacing(unitID) or 0) % 4,
			xsize = def.xsize,
			zsize = def.zsize,
			-- a mission unit reports its mission team, so a copy pastes onto that team
			team = mission.teamOf(unitID) or Spring.GetUnitTeam(unitID),
		}
	end,
	all = function()
		return Spring.GetAllUnits() or {}
	end,
	inScreenRect = function(x1, y1, x2, y2)
		return Spring.GetUnitsInScreenRectangle(x1, y1, x2, y2) or {}
	end,
	inCylinder = function(x, z, radius)
		return Spring.GetUnitsInCylinder(x, z, radius) or {}
	end,
	teams = function()
		return Spring.GetTeamList() or {}
	end,
	myTeam = function()
		return Spring.GetMyTeamID()
	end,
	--- The unit under a screen point, or nil (what a click selects).
	pick = function(mx, my, _gx, _gz)
		local kind, target = Spring.TraceScreenRay(mx, my)
		return kind == "unit" and target or nil
	end,
}
-- The gadget sink is installed once its message functions exist (after "Messages to the
-- gadget" below); until then the tool is not active anyway.
local owner = { name = "terraform_brush", provider = engineProvider, sink = nil }
local gadgetSink

--- The unit library opens under the owner's name: a pick belongs to whoever opened it.
local function libraryTitle()
	return owner.title or LIBRARY_TITLE
end

local PROVIDER_FIELDS = { "valid", "info", "all", "inScreenRect", "inCylinder", "teams", "myTeam", "pick" }
local SINK_FIELDS = { "place", "remove", "transform", "undo", "redo", "clearAll" }

----------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------
--- Every message changes the units, so it is also where a map project learns it has
--- unsaved changes.
local function sendMsg(msg)
	---@type table?
	local mp = WG.MapProject
	if mp and mp.markDirty then
		mp.markDirty("units")
	end
	Spring.SendLuaRulesMsg(msg)
end

local function nextStrokeId()
	up.strokeCount = up.strokeCount + 1
	-- The clock part keeps a reloaded widget from reusing an id the gadget still holds; both
	-- stay small because Lua numbers are floats here.
	return string.format("s%d_%d", floor(os.clock() * 100) % 65536, up.strokeCount)
end

local function teams()
	local out = {}
	for _, teamID in ipairs(owner.provider.teams()) do
		out[#out + 1] = teamID
	end
	table.sort(out)
	return out
end

--- The brush in MISSION mode (another owner brings its own placement rules).
function mission.on()
	return up.kind == "mission" and owner.name == "terraform_brush"
end

local function currentTeam()
	if mission.on() then
		return up.missionTeam
	end
	if up.team == nil then
		up.team = owner.provider.myTeam()
	end
	return up.team
end

local function isFormation()
	return FORMATION_MODE[up.distribution] ~= nil
end

--- Is the pointer over the unit library, or (`withPanel`) over the terraform brush panel or
--- a project dialog in front of the world? Keys only step aside for the library, as before.
local function overUi(withPanel)
	-- A harness pointer is on the map by definition.
	if sel.pointer then
		return false
	end
	local mx, my = Spring.GetMouseState()
	-- The unit library (RmlUi coordinates, y down).
	---@type table?
	local lib = WG.UnitLibrary
	if lib and lib.contains then
		local _, vsy = Spring.GetViewGeometry()
		if lib.contains(mx, vsy - my) then
			return true
		end
	end
	if not withPanel then
		return false
	end
	---@type table?
	local tfUI = WG.TerraformBrushUI
	if tfUI and tfUI.getPanelBounds then
		local bounds = (tfUI.getHoverBounds and tfUI.getHoverBounds()) or tfUI.getPanelBounds()
		if bounds and mx >= bounds.left and mx <= bounds.right and my >= bounds.bottomY and my <= bounds.topY then
			return true
		end
	end
	return false
end

--- The ground under the pointer, plain (the placer and the selection use it).
local function groundUnderMouse()
	if sel.pointer then
		return sel.pointer.x, sel.pointer.z
	end
	local mx, my = Spring.GetMouseState()
	local kind, coords = Spring.TraceScreenRay(mx, my, true)
	if kind ~= "ground" or not coords then
		return nil
	end
	return coords[1], coords[3]
end

--- The brush cursor: the terraform brush's edge-extended one when it is there, which keeps
--- following the mouse a little past the map border and fades out.
local function brushCursor()
	up.edgeFade = 1
	---@type table?
	local tb = WG.TerraformBrush
	if tb and tb.getWorldPositionExtended then
		local wx, wz, fade = tb.getWorldPositionExtended(up.mode == "point" and 64 or up.radius)
		if wx then
			up.edgeFade = fade or 1
			return wx, wz
		end
		return nil, nil
	end
	return groundUnderMouse()
end

local function getSymmetricPositions(wx, wz, rot)
	---@type table?
	local tb = WG.TerraformBrush
	if tb and tb.getSymmetricPositions then
		return tb.getSymmetricPositions(wx, wz, rot or 0)
	end
	return { { x = wx, z = wz, rot = rot or 0 } }
end

local function snapToGrid(x, z)
	local size = grid.snapSize
	return floor(x / size + 0.5) * size, floor(z / size + 0.5) * size
end

local function cadenceInterval()
	return max(0.03, 2.0 / up.cadence)
end

--- A heading (0-65535) as the nearer of the four facings: 0 S, 1 E, 2 N, 3 W.
local function headingToFacing(heading)
	return floor(((heading + 8192) % 65536) / 16384) % 4
end

local function degreesToFacing(deg)
	return headingToFacing(floor((deg or 0) / 360 * 65536) % 65536)
end

local function isStructure(def)
	return def.isBuilding or def.isImmobile or (def.speed or 0) == 0
end

--- Where a unit of `def` facing `facing` stands when asked for (x, z): structures snap to the
--- build grid as the engine places them.
local function standingSpot(def, x, z, facing)
	if isStructure(def) then
		---@type number?, number?, number?
		local sx, _, sz = Spring.Pos2BuildPos(def.id, x, Spring.GetGroundHeight(x, z), z, facing)
		if sx and sz then
			return floor(sx + 0.5), floor(sz + 0.5)
		end
	end
	return floor(x + 0.5), floor(z + 0.5)
end

local function insideMap(x, z)
	return x >= 0 and z >= 0 and x <= Game.mapSizeX and z <= Game.mapSizeZ
end

--- The smart filters at one point (the feature placer's rules).
local function passesFilters(x, z)
	if not up.smartEnabled then
		return true
	end
	local sf = up.smartFilters
	local h = Spring.GetGroundHeight(x, z)
	if sf.avoidWater and h < 0 then
		return false
	end
	if sf.avoidCliffs or sf.preferSlopes then
		local _, ny = Spring.GetGroundNormal(x, z)
		ny = ny or 1.0
		if sf.avoidCliffs and ny < cos(sf.slopeMax * pi / 180) then
			return false
		end
		if sf.preferSlopes and ny > cos(sf.slopeMin * pi / 180) then
			return false
		end
	end
	if sf.altMinEnable and h < sf.altMin then
		return false
	end
	if sf.altMaxEnable and h > sf.altMax then
		return false
	end
	return true
end

--- Spots whose footprint overlaps an earlier one are dropped (a spatial hash, so a big
--- stamp under symmetry stays cheap). Each spot carries w and h in elmos.
local function dropOverlaps(spots)
	local cell = 64
	local buckets, kept = {}, {}
	for _, spot in ipairs(spots) do
		local x0, x1 = floor((spot.x - spot.w / 2) / cell), floor((spot.x + spot.w / 2) / cell)
		local z0, z1 = floor((spot.z - spot.h / 2) / cell), floor((spot.z + spot.h / 2) / cell)
		local clash = false
		for cx = x0, x1 do
			for cz = z0, z1 do
				---@type table?
				local bucket = buckets[cx * 65536 + cz]
				if bucket then
					for _, other in ipairs(bucket) do
						if
							abs(spot.x - other.x) * 2 < spot.w + other.w
							and abs(spot.z - other.z) * 2 < spot.h + other.h
						then
							clash = true
							break
						end
					end
				end
				if clash then
					break
				end
			end
			if clash then
				break
			end
		end
		if not clash then
			kept[#kept + 1] = spot
			for cx = x0, x1 do
				for cz = z0, z1 do
					local key = cx * 65536 + cz
					buckets[key] = buckets[key] or {}
					local bucket = buckets[key]
					bucket[#bucket + 1] = spot
				end
			end
		end
	end
	return kept
end

--- A spot for a unit: snapped as it will stand, its footprint, or nil when the map or the
--- smart filters refuse it.
local function makeSpot(name, x, z, facing, team)
	---@type table?
	local def = UnitDefNames[name]
	if not (def and insideMap(x, z)) then
		return nil
	end
	facing = facing % 4
	local sx, sz = standingSpot(def, x, z, facing)
	if not (insideMap(sx, sz) and passesFilters(sx, sz)) then
		return nil
	end
	local w, h = Layout.footprint(def.xsize, def.zsize, facing)
	return { name = def.name, defID = def.id, x = sx, z = sz, facing = facing, team = team, w = w, h = h }
end

----------------------------------------------------------------
-- Build grid overlay and snap (the feature placer's)
----------------------------------------------------------------
for id, def in pairs(UnitDefs) do
	if not def.modCategories or not def.modCategories.underwater then
		grid.forceShowDefID = id
		break
	end
end

local function showBuildGrid()
	if grid.showing then
		return
	end
	---@type table?
	local bg = WG.buildinggrid
	if bg and bg.setForceShow and grid.forceShowDefID then
		bg.setForceShow("unitplacer", true, grid.forceShowDefID)
		grid.showing = true
	end
end

local function hideBuildGrid()
	if not grid.showing then
		return
	end
	---@type table?
	local bg = WG.buildinggrid
	if bg and bg.setForceShow then
		bg.setForceShow("unitplacer", false)
	end
	grid.showing = false
end

--- A full-map, terrain-following grid at the snap size, as the terraform brush's DISPLAY
--- Grid and the feature placer's draw it.
local function buildFullMapGrid()
	if grid.dl then
		gl.DeleteList(grid.dl)
		grid.dl = nil
	end
	local gs = grid.snapSize
	local msx, msz = Game.mapSizeX, Game.mapSizeZ
	local BUMP = 3
	local GetGroundHeight = Spring.GetGroundHeight
	grid.dl = gl.CreateList(function()
		gl.LineWidth(1)
		gl.Color(1, 1, 0.6, 0.20)
		gl.PolygonOffset(-2, -2)
		local z = 0.0
		while z <= msz do
			gl.BeginEnd(GL.LINE_STRIP, function()
				local x = 0.0
				while x <= msx do
					gl.Vertex(x, GetGroundHeight(x, z) + BUMP, z)
					x = x + gs
				end
				if msx % gs ~= 0 then
					gl.Vertex(msx, GetGroundHeight(msx, z) + BUMP, z)
				end
			end)
			z = z + gs
		end
		local x = 0.0
		while x <= msx do
			gl.BeginEnd(GL.LINE_STRIP, function()
				local zz = 0.0
				while zz <= msz do
					gl.Vertex(x, GetGroundHeight(x, zz) + BUMP, zz)
					zz = zz + gs
				end
				if msz % gs ~= 0 then
					gl.Vertex(x, GetGroundHeight(x, msz) + BUMP, msz)
				end
			end)
			x = x + gs
		end
		gl.PolygonOffset(0, 0)
		gl.Color(1, 1, 1, 1)
		gl.LineWidth(1)
	end)
	grid.dlSize = gs
	grid.dirty = false
end

local function ensureBuildGridLoaded()
	if not WG.buildinggrid then
		-- SendCommands works from any context, RmlUi event handlers included.
		Spring.SendCommands("luaui enablewidget Building Grid GL4")
	end
end

----------------------------------------------------------------
-- Messages to the gadget
----------------------------------------------------------------
--- Placements as one stroke: { { name, x, z, facing, team }, ... }, in batches per team.
local function gadgetPlace(spots, strokeId)
	if #spots == 0 then
		return nil
	end
	strokeId = strokeId or nextStrokeId()
	local byTeam, order = {}, {}
	local missionKind = mission.on()
	for _, spot in ipairs(spots) do
		local team = spot.team or currentTeam()
		if not missionKind and not Spring.GetTeamInfo(team, false) then
			-- a mission unit's copy pasted live: its mission team may not exist here
			team = owner.provider.myTeam()
		end
		if not byTeam[team] then
			byTeam[team] = {}
			order[#order + 1] = team
		end
		local list = byTeam[team]
		list[#list + 1] = string.format("%s,%d,%d,%d", spot.name, spot.x, spot.z, spot.facing or 0)
	end
	for _, team in ipairs(order) do
		local list = byTeam[team]
		for first = 1, #list, BATCH do
			local entries = {}
			for index = first, min(first + BATCH - 1, #list) do
				entries[#entries + 1] = list[index]
			end
			local teamField = missionKind and ("m" .. tostring(team)) or tostring(team)
			sendMsg(MSG.place .. strokeId .. "|" .. teamField .. "|" .. table.concat(entries, ";"))
		end
	end
	return strokeId
end

local function gadgetRemove(ids, strokeId)
	if #ids == 0 then
		return
	end
	strokeId = strokeId or nextStrokeId()
	for first = 1, #ids, BATCH * 2 do
		local part = {}
		for index = first, min(first + BATCH * 2 - 1, #ids) do
			part[#part + 1] = tostring(ids[index])
		end
		sendMsg(MSG.remove .. strokeId .. "|" .. table.concat(part, ","))
	end
end

--- Moves and turns: { { id, x, z, facing }, ... }, one stroke.
local function gadgetTransform(moves)
	if #moves == 0 then
		return
	end
	local strokeId = nextStrokeId()
	for first = 1, #moves, BATCH do
		local part = {}
		for index = first, min(first + BATCH - 1, #moves) do
			local move = moves[index]
			part[#part + 1] = string.format("%d,%d,%d,%d", move.id, move.x, move.z, move.facing % 4)
		end
		sendMsg(MSG.transform .. strokeId .. "|" .. table.concat(part, ";"))
	end
end

-- The brush's sink: real units through the gadget, one stroke per gesture.
gadgetSink = {
	place = gadgetPlace,
	remove = gadgetRemove,
	transform = gadgetTransform,
	undo = function()
		sendMsg(MSG.undo)
	end,
	redo = function()
		sendMsg(MSG.redo)
	end,
	clearAll = function(strokeId)
		sendMsg(MSG.clearAll .. tostring(strokeId or nextStrokeId()))
	end,
}
owner.sink = gadgetSink

--- What every gesture calls: the owner's sink, whichever it is.
local function sendPlacements(spots, strokeId)
	return owner.sink.place(spots, strokeId)
end

local function sendRemove(ids, strokeId)
	return owner.sink.remove(ids, strokeId)
end

local function sendTransforms(moves)
	return owner.sink.transform(moves)
end

----------------------------------------------------------------
-- What is picked
----------------------------------------------------------------
--- The unit names armed now (a cycle's whole set for a unit pick, a group's members).
local function pickedNames()
	if not lastPick then
		return {}
	end
	if lastPick.kind == "unit" then
		if lastPick.cycle then
			local out = {}
			for index, name in ipairs(lastPick.cycle.names()) do
				out[index] = name
			end
			return out
		end
		return { lastPick.value }
	end
	local out, seen = {}, {}
	local units = lastPick.kind == "paste" and lastPick.value or (lastPick.value and lastPick.value.units) or {}
	for _, unit in ipairs(units) do
		local name = unit.unitDefName
		if name and not seen[name] then
			seen[name] = true
			out[#out + 1] = name
		end
	end
	return out
end

--- Does the shared placer (the Blueprint API drag) do the placing now? Groups always; a unit
--- pick when the scatter distribution is a formation.
--- The game's own build-drag keys, as cmd_blueprint reads them (determineBuildMode):
--- Shift drags a line, Shift+Ctrl a snapped line, Shift+Alt a filled grid and
--- Shift+Alt+Ctrl a hollow box. nil without Shift.
local function gameBuildMode()
	local alt, ctrl, _, shift = Spring.GetModKeyState()
	if not shift then
		return nil
	end
	if alt then
		return ctrl and "BOX" or "GRID"
	end
	return ctrl and "SNAPLINE" or "LINE"
end

local function placerWanted()
	if not (up.active and lastPick and up.mode ~= "remove") then
		return false
	end
	if lastPick.kind ~= "unit" or up.modDrag then
		return true
	end
	return up.mode == "scatter" and isFormation()
end

--- Arm the placer with the pick as things stand, or let go of it when the brush places.
local function syncArming()
	if not placerWanted() then
		if placer and placer.armed() then
			placer.disarm()
		end
		up.modOverride, up.modBase = false, nil
		return
	end
	local pick = lastPick ---@cast pick table
	if pick.kind == "unit" then
		local live = placer.spec()
		if live and not live.group then
			pick.facing = live.facing
		end
		placer.arm({
			unitDefName = pick.value,
			team = currentTeam(),
			spacing = up.spacing,
			mode = FORMATION_MODE[up.distribution] or "GRID",
			facing = pick.facing,
		})
	elseif pick.kind == "blueprint" then
		placer.armGroup(pick.value.units, { team = currentTeam() })
	else
		placer.armGroup(pick.value, { team = currentTeam() })
	end
end

--- The pick is gone (Escape, a right-click on the placer, deactivation): back to select mode.
local function dropPick()
	lastPick = nil
	if placer and placer.armed() then
		placer.disarm()
	end
	---@type table?
	local lib = WG.UnitLibrary
	if lib and lib.clearPicks and lib.owner and lib.owner() == libraryTitle() then
		lib.clearPicks()
	end
	pv.layoutKey, pv.stampKey = nil, nil
end

local function advanceCycle()
	local pick = lastPick
	if pick and pick.kind == "unit" and pick.cycle and pick.cycle.cycles() then
		pick.value = pick.cycle.advance()
		if placer.armed() then
			syncArming()
		end
	end
end

----------------------------------------------------------------
-- The brush stamp: layout, spots, symmetry
----------------------------------------------------------------
local function reroll()
	-- A counter, not the clock: two stamps in one clock tick would repeat a layout.
	pv.seed = (pv.seed + SEED_STRIDE) % SEED_MAX
	pv.layoutKey, pv.stampKey = nil, nil
end

--- The largest footprint among the names, in elmos: the clustered spacing.
local function largestFootprint(names)
	local largest = 16.0
	for _, name in ipairs(names) do
		---@type table?
		local def = UnitDefNames[name]
		if def then
			largest = max(largest, (def.xsize or 2) * 8, (def.zsize or 2) * 8)
		end
	end
	return largest
end

local function stampParams(names)
	return {
		shape = up.shape,
		radius = up.radius,
		rotation = up.rotation,
		count = up.unitCount,
		distribution = up.distribution,
		rotRandom = up.rotRandom,
		defNames = names,
		smartEnabled = up.smartEnabled,
		smartFilters = up.smartFilters,
		minSpacing = up.distribution == "clustered" and largestFootprint(names) * 1.2 or nil,
	}
end

local function ensureLayout(params)
	local key = table.concat({
		pv.seed,
		params.shape,
		params.radius,
		params.rotation,
		params.count,
		params.distribution,
		params.rotRandom,
		table.concat(params.defNames, ","),
	}, "\0")
	if pv.layoutKey ~= key then
		pv.layout = Scatter.generateLocal(params, pv.seed)
		pv.layoutKey = key
	end
	return pv.layout
end

--- Out-of-map entries are dropped per symmetry copy BEFORE resolve, which would clamp them
--- onto the border (the feature placer's layoutInsideMap).
local function layoutInsideMap(layout, cx, cz, extraRotDeg)
	local kept = {}
	for _, entry in ipairs(layout) do
		local dx, dz = entry.dx, entry.dz
		if extraRotDeg ~= 0 then
			dx, dz = Scatter.rotatePoint(dx, dz, extraRotDeg)
		end
		if insideMap(cx + dx, cz + dz) then
			kept[#kept + 1] = entry
		end
	end
	return kept
end

--- A key for everything a stamp at (x, z) depends on besides the layout: the symmetry copies
--- and the smart filters.
local function stampKey(positions, x, z)
	local parts = { pv.layoutKey or "", up.mode or "", floor(x), floor(z), currentTeam() }
	for _, p in ipairs(positions) do
		parts[#parts + 1] = floor(p.x) .. ":" .. floor(p.z) .. ":" .. floor((p.rot or 0) * 10)
	end
	if up.smartEnabled then
		local sf = up.smartFilters
		parts[#parts + 1] = table.concat({
			tostring(sf.avoidWater),
			tostring(sf.avoidCliffs),
			sf.slopeMax,
			tostring(sf.preferSlopes),
			sf.slopeMin,
			tostring(sf.altMinEnable),
			sf.altMin,
			tostring(sf.altMaxEnable),
			sf.altMax,
		}, ",")
	end
	return table.concat(parts, "|")
end

--- Every unit a click at (x, z) would place now, across the symmetry copies: SCATTER from the
--- cached layout, POINT one unit under the cursor per copy. Cached per cursor spot.
local function currentStamp(x, z)
	if not (lastPick and lastPick.kind == "unit") then
		return {}
	end
	local names = pickedNames()
	local positions = getSymmetricPositions(x, z, up.rotation)
	if up.mode == "scatter" then
		ensureLayout(stampParams(names))
	end
	local key = stampKey(positions, x, z)
	if pv.stampKey == key and pv.stamp then
		return pv.stamp
	end
	local team = currentTeam()
	local spots = {}
	if up.mode == "scatter" then
		local params = stampParams(names)
		local layout = ensureLayout(params)
		for _, p in ipairs(positions) do
			local copyRot = (p.rot or up.rotation) - up.rotation
			local resolved = Scatter.resolve(layoutInsideMap(layout, p.x, p.z, copyRot), p.x, p.z, params, copyRot)
			for _, placement in ipairs(resolved) do
				local spot =
					makeSpot(placement.defName, placement.x, placement.z, headingToFacing(placement.heading), team)
				if spot then
					spots[#spots + 1] = spot
				end
			end
		end
	elseif up.mode == "point" then
		local rng = Scatter.newRng(pv.seed)
		for _, p in ipairs(positions) do
			local facing = degreesToFacing(p.rot or up.rotation)
			if up.rotRandom > 0 and rng:next() * 100 < up.rotRandom then
				facing = rng:int(0, 3)
			end
			local spot = makeSpot(lastPick.value, p.x, p.z, facing, team)
			if spot then
				spots[#spots + 1] = spot
			end
		end
	end
	pv.stamp = dropOverlaps(spots)
	pv.stampKey = key
	return pv.stamp
end

--- Place what the cursor shows at (x, z), as part of the stroke held now (or a new one).
local function stampAt(x, z)
	local spots = currentStamp(x, z)
	if #spots == 0 then
		return false
	end
	up.lastStampX, up.lastStampZ = x, z
	local strokeId = sendPlacements(spots, up.dragStroke)
	if up.dragging then
		up.dragStroke = strokeId
	end
	reroll()
	if up.mode == "point" then
		advanceCycle()
	end
	return true
end

--- A formation or a group the placer finished: through the smart filters, then copied to
--- every symmetry position, each copy turned by its own rotation.
local function expandPlacement(result)
	local spots = {}
	-- `extra` is the owner's: what a copied or blueprinted unit carried besides its type and
	-- place (the mission editor's orders, quantity, ...). Carried through untouched; the
	-- gadget's sink never sends it.
	local function add(name, x, z, facing, team, extra)
		local positions = getSymmetricPositions(x, z, facing * 90)
		for index, p in ipairs(positions) do
			local copyFacing = index == 1 and facing or degreesToFacing(p.rot)
			local spot = makeSpot(name, p.x, p.z, copyFacing, team)
			if spot then
				spot.extra = extra
				spots[#spots + 1] = spot
			end
		end
	end
	if result.group then
		local paste = lastPick and lastPick.kind == "paste" and lastPick.value or nil
		local blueprint = lastPick and lastPick.kind == "blueprint" and lastPick.value and lastPick.value.units or nil
		local source = paste or blueprint
		for _, unit in ipairs(result.units or {}) do
			local member = source and unit.index and source[unit.index]
			add(
				unit.unitDefName,
				unit.x,
				unit.z,
				unit.facing or 0,
				paste and member and member.team or result.team,
				member and member.extra
			)
		end
	else
		for _, unit in ipairs(result.spots or {}) do
			add(result.unitDefName, unit.x, unit.z, unit.facing or 0, result.team)
		end
	end
	return dropOverlaps(spots)
end

----------------------------------------------------------------
-- Removal
----------------------------------------------------------------
--- The units under the brush at (x, z), across the symmetry copies.
local function unitsInBrush(x, z)
	local ids, seen = {}, {}
	for _, p in ipairs(getSymmetricPositions(x, z, up.rotation)) do
		for _, unitID in ipairs(owner.provider.inCylinder(p.x, p.z, up.radius * 1.42)) do
			if not seen[unitID] then
				local info = owner.provider.info(unitID)
				local ux, uz = info and info.x, info and info.z
				if
					ux
					and uz
					and BrushShapes.isInside(ux - p.x, uz - p.z, up.radius, up.shape, p.rot or up.rotation)
				then
					seen[unitID] = true
					ids[#ids + 1] = unitID
				end
			end
		end
	end
	return ids
end

local function removeAt(x, z)
	local ids = unitsInBrush(x, z)
	if #ids == 0 then
		return
	end
	up.dragStroke = up.dragStroke or nextStrokeId()
	sendRemove(ids, up.dragStroke)
end

----------------------------------------------------------------
-- Ghosts (DrawUnitShapeGL4): the stamp preview and the selection drag
----------------------------------------------------------------
local function newGhostPool(ghostOwner)
	local pool = { handles = {}, count = 0 }

	function pool.clear()
		---@type function?
		local stop = WG.StopDrawUnitShapeGL4
		for index = 1, pool.count do
			if stop and pool.handles[index] then
				stop(pool.handles[index])
			end
			pool.handles[index] = nil
		end
		pool.count = 0
	end

	--- Show `items` ({ defID, x, z, facing, team }), reusing instances in place.
	function pool.sync(items, alpha)
		---@type function?
		local draw = WG.DrawUnitShapeGL4
		if not draw then
			return
		end
		local shown = min(#items, PREVIEW_GHOST_CAP)
		if #items > PREVIEW_GHOST_CAP and not pv.warnedCap then
			pv.warnedCap = true
			Spring.Echo(
				"[Unit Placer] Preview limited to "
					.. PREVIEW_GHOST_CAP
					.. " ghosts; all "
					.. #items
					.. " units are still placed on click"
			)
		end
		local handles, n = pool.handles, 0
		for index = 1, shown do
			local item = items[index]
			local y = Spring.GetGroundHeight(item.x, item.z)
			local handle = draw(
				item.defID,
				item.x,
				y,
				item.z,
				(item.facing or 0) * pi / 2,
				alpha or GHOST_ALPHA,
				mission.realTeam(item.team),
				0.15,
				0,
				handles[n + 1],
				ghostOwner
			)
			if handle then
				n = n + 1
				handles[n] = handle
			end
		end
		---@type function?
		local stop = WG.StopDrawUnitShapeGL4
		for index = n + 1, pool.count do
			if stop and handles[index] then
				stop(handles[index])
			end
			handles[index] = nil
		end
		pool.count = n
	end

	return pool
end

local stampGhosts = newGhostPool("cmd_unit_placer")
local dragGhosts = newGhostPool("cmd_unit_placer_drag")

----------------------------------------------------------------
-- Selection
----------------------------------------------------------------
--- LIVE mode: with nothing picked, plain clicks belong to the game (select and order the
--- live units). MISSION mode and other owners keep the tool's own selection.
function mission.gameOwnsClicks()
	return owner.name == "terraform_brush" and up.kind ~= "mission"
end

--- The selection features (Delete, R, Ctrl+A, density, copy): on with nothing picked. In
--- LIVE mode they act on the game's selection (mirrored into `sel`, see mission.mirror).
local function selectModeActive()
	return up.active
		and (up.mode == "scatter" or up.mode == "point")
		and lastPick == nil
		and not (placer and placer.armed())
end

--- The tool takes plain clicks for its own selection: select mode, outside LIVE.
local function selectClicksActive()
	return selectModeActive() and not mission.gameOwnsClicks()
end

--- An owner that wants to know what is selected (the mission editor's roster follows the
--- tool's selection) hears every change through its sink's optional `selectionChanged`.
local function notifySelection()
	lasso.dirty = true
	local sink = owner.sink
	-- Only while the tool is on: a deactivation or an owner change clears the tool's own
	-- selection, which is not the owner's business.
	if up.active and not sel.silent and sink and sink.selectionChanged then
		sink.selectionChanged(sel.ids)
	end
end

local function clearSelection()
	sel.ids, sel.set = {}, {}
	sel.drag = nil
	sel.boxing = false
	dragGhosts.clear()
	notifySelection()
end

local function setSelection(ids, additive)
	if not additive then
		sel.ids, sel.set = {}, {}
	end
	for _, unitID in ipairs(ids) do
		if owner.provider.valid(unitID) and not sel.set[unitID] then
			sel.set[unitID] = true
			sel.ids[#sel.ids + 1] = unitID
		end
	end
	notifySelection()
	if mission.gameOwnsClicks() then
		mission.pushToGame()
	end
end

--- LIVE mode: the tool's selection becomes the game's.
function mission.pushToGame()
	Spring.SelectUnitArray(sel.ids)
	local seen = {}
	for _, unitID in ipairs(sel.ids) do
		seen[unitID] = true
	end
	mission.lastGame = seen
end

--- LIVE mode: take the game's selection as the tool's (the other half of setSelection's
--- push), so Delete, R, Ctrl+A, density and copy act on what was selected the normal way.
--- Only the PLAYER's changes count: a unit added, or a living one let go. A unit the gadget
--- re-creates (move, turn, undo) dies out of the game's selection before its remap arrives,
--- and that must not drop it from the tool's.
function mission.mirror()
	local ids = Spring.GetSelectedUnits() or {}
	local now, changed = {}, false
	for _, unitID in ipairs(ids) do
		now[unitID] = true
		if not mission.lastGame[unitID] then
			changed = true
		end
	end
	for unitID in pairs(mission.lastGame) do
		if not now[unitID] and Spring.ValidUnitID(unitID) then
			changed = true
		end
	end
	mission.lastGame = now
	if changed then
		sel.ids, sel.set = {}, {}
		for _, unitID in ipairs(ids) do
			sel.set[unitID] = true
			sel.ids[#sel.ids + 1] = unitID
		end
		notifySelection()
	end
end

local function toggleSelection(unitID)
	if sel.set[unitID] then
		sel.set[unitID] = nil
		for index = #sel.ids, 1, -1 do
			if sel.ids[index] == unitID then
				table.remove(sel.ids, index)
			end
		end
		notifySelection()
	else
		setSelection({ unitID }, true)
	end
end

--- What is placed under this id, as the owner's provider tells it (the engine's unit, or
--- the mission editor's record). nil when it is gone.
local function unitInfo(unitID)
	return owner.provider.info(unitID)
end

local function selectedInfos()
	local out = {}
	for _, unitID in ipairs(sel.ids) do
		local info = unitInfo(unitID)
		if info then
			out[#out + 1] = info
		end
	end
	return out
end

----------------------------------------------------------------
-- The lasso: a loop round a selection of two or more. A press on empty ground INSIDE it
-- grabs the whole group (a drag moves them all), one outside starts a box as ever. Drawn as
-- a faint fill, brighter under the pointer. (From the mission editor, PtaQ 2026-09-29.)
----------------------------------------------------------------
local LASSO_PAD = 20
local LASSO_SIDES = 12
local LASSO_REFRESH = 0.25 -- seconds: positions change under undo and other owners' edits
local LASSO_COS, LASSO_SIN = {}, {}
for i = 0, LASSO_SIDES - 1 do
	LASSO_COS[i], LASSO_SIN[i] = cos(i * 2 * pi / LASSO_SIDES), sin(i * 2 * pi / LASSO_SIDES)
end

local function convexHull(points)
	table.sort(points, function(a, b)
		return a.x < b.x or (a.x == b.x and a.z < b.z)
	end)
	local function cross(o, a, b)
		return (a.x - o.x) * (b.z - o.z) - (a.z - o.z) * (b.x - o.x)
	end
	local lower, upper = {}, {}
	for i = 1, #points do
		while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], points[i]) <= 0 do
			lower[#lower] = nil
		end
		lower[#lower + 1] = points[i]
	end
	for i = #points, 1, -1 do
		while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], points[i]) <= 0 do
			upper[#upper] = nil
		end
		upper[#upper + 1] = points[i]
	end
	lower[#lower] = nil
	upper[#upper] = nil
	for i = 1, #upper do
		lower[#lower + 1] = upper[i]
	end
	return lower
end

--- The loop round the selection (counter-clockwise), or nil under two selected.
local function lassoHull()
	if #sel.ids < 2 then
		lasso.hull = nil
		return nil
	end
	if not lasso.dirty and lasso.hull then
		return lasso.hull
	end
	lasso.dirty = false
	local points = {}
	for _, info in ipairs(selectedInfos()) do
		local w, h = Layout.footprint(info.xsize, info.zsize, info.facing)
		local radius = math.sqrt(w * w + h * h) / 2 + LASSO_PAD
		for i = 0, LASSO_SIDES - 1 do
			points[#points + 1] = { x = info.x + LASSO_COS[i] * radius, z = info.z + LASSO_SIN[i] * radius }
		end
	end
	lasso.hull = #points >= 3 and convexHull(points) or nil
	return lasso.hull
end

local function insideLasso(x, z)
	local hull = lassoHull()
	if not (hull and x and #hull >= 3) then
		return false
	end
	for i = 1, #hull do
		local a, b = hull[i], hull[i % #hull + 1]
		if (b.x - a.x) * (z - a.z) - (b.z - a.z) * (x - a.x) < 0 then
			return false
		end
	end
	return true
end

Tool.insideLasso = insideLasso

--- Moves for the units that actually change.
local function movesFrom(infos, spots)
	local moves = {}
	for index, info in ipairs(infos) do
		local spot = spots[index]
		if spot then
			local x = max(0, min(Game.mapSizeX, floor(spot.x + 0.5)))
			local z = max(0, min(Game.mapSizeZ, floor(spot.z + 0.5)))
			local facing = (spot.facing or info.facing) % 4
			if x ~= floor(info.x + 0.5) or z ~= floor(info.z + 0.5) or facing ~= info.facing then
				moves[#moves + 1] = { id = info.id, x = x, z = z, facing = facing }
			end
		end
	end
	return moves
end

local function deleteSelection()
	if #sel.ids == 0 then
		return
	end
	local ids = {}
	for _, unitID in ipairs(sel.ids) do
		if owner.provider.valid(unitID) then
			ids[#ids + 1] = unitID
		end
	end
	sendRemove(ids)
	clearSelection()
end

local function selectAllInBox(x1, y1, x2, y2, additive)
	local ids = owner.provider.inScreenRect(min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2))
	setSelection(ids, additive)
end

local function selectAllVisible()
	local vsx, vsy = Spring.GetViewGeometry()
	selectAllInBox(0, 0, vsx, vsy, false)
end

--- R on the selection: a quarter turn about its middle, offsets and facings together.
local function turnSelection(dir)
	local infos = selectedInfos()
	if #infos == 0 then
		return false
	end
	local turns = ((tonumber(dir) or 1) >= 0) and 1 or 3
	local offsets, cx, cz = Layout.centreOffsets(infos)
	local spots = {}
	for index, info in ipairs(infos) do
		local ox, oz = Layout.turnOffset(offsets[index].dx, offsets[index].dz, turns)
		local facing = (info.facing + turns) % 4
		local w, h = Layout.footprint(info.xsize, info.zsize, facing)
		spots[index] = { x = Layout.snapAxis(cx + ox, w), z = Layout.snapAxis(cz + oz, h), facing = facing }
	end
	sendTransforms(movesFrom(infos, spots))
	return true
end

local function reformSelection(mode)
	mode = tostring(mode or "GRID"):upper()
	local infos = selectedInfos()
	if #infos < 2 then
		Spring.Echo("[Unit Placer] select two or more units to re-form")
		return false
	end
	sendTransforms(movesFrom(infos, Layout.reform(infos, mode)))
	return true
end

local function spaceSelection(factor)
	factor = tonumber(factor) or 1
	local infos = selectedInfos()
	if #infos < 2 or factor == 1 then
		Spring.Echo("[Unit Placer] select two or more units to space")
		return false
	end
	local spots = Layout.space(infos, factor)
	if not spots then
		Spring.Echo("[Unit Placer] they are as tight as they go")
		return false
	end
	sendTransforms(movesFrom(infos, spots))
	return true
end

--- Ctrl+click: every selected unit turns to face the point.
local function faceSelection(tx, tz)
	local infos = selectedInfos()
	local spots = {}
	for index, info in ipairs(infos) do
		local facing = Layout.facingToward(info.x, info.z, tx, tz)
		local w, h = Layout.footprint(info.xsize, info.zsize, facing)
		spots[index] = { x = Layout.snapAxis(info.x, w), z = Layout.snapAxis(info.z, h), facing = facing }
	end
	sendTransforms(movesFrom(infos, spots))
end

local function copySelection()
	local infos = selectedInfos()
	if #infos == 0 then
		return false
	end
	local offsets = Layout.centreOffsets(infos)
	local units = {}
	for index, info in ipairs(infos) do
		units[index] = {
			unitDefName = info.name,
			dx = offsets[index].dx,
			dz = offsets[index].dz,
			facing = info.facing,
			team = info.team,
			-- Asked only here: an owner's extra fields are built on demand, not every frame.
			extra = owner.provider.extra and owner.provider.extra(info.id) or info.extra,
		}
	end
	sel.clipboard = units
	Spring.Echo(string.format("[Unit Placer] copied %d unit(s)", #units))
	return true
end

local function cutSelection()
	if copySelection() then
		deleteSelection()
		return true
	end
	return false
end

local function paste()
	if not (sel.clipboard and #sel.clipboard > 0) then
		Spring.Echo("[Unit Placer] nothing copied")
		return false
	end
	if not up.active then
		return false
	end
	if up.mode == "remove" or not up.mode then
		up.mode = "point"
	end
	clearSelection()
	lastPick = { kind = "paste", value = sel.clipboard }
	syncArming()
	return placer.armed()
end

--- The selection drag: the grabbed unit follows the pointer (grid snap on it, then each unit
--- snapped for its own footprint) and the others keep their offsets from it.
local function dragTargets(wx, wz)
	local drag = sel.drag --[[@as table]]
	local grab = drag.origins[drag.grabID]
	if not grab then
		return {}
	end
	local gx, gz = grab.x + (wx - drag.startX), grab.z + (wz - drag.startZ)
	if grid.snap then
		gx, gz = snapToGrid(gx, gz)
	end
	local gw, gh = Layout.footprint(grab.xsize, grab.zsize, grab.facing)
	local dx, dz = Layout.snapAxis(gx, gw) - grab.x, Layout.snapAxis(gz, gh) - grab.z
	local targets = {}
	for _, info in ipairs(drag.infos) do
		local w, h = Layout.footprint(info.xsize, info.zsize, info.facing)
		targets[#targets + 1] = {
			x = Layout.snapAxis(info.x + dx, w),
			z = Layout.snapAxis(info.z + dz, h),
			facing = info.facing,
			defID = info.defID,
			team = info.team,
		}
	end
	return targets
end

local function beginSelectionDrag(unitID, mx, my)
	local wx, wz = groundUnderMouse()
	if not wx then
		return false
	end
	local infos = selectedInfos()
	local origins = {}
	for _, info in ipairs(infos) do
		origins[info.id] = info
	end
	if not origins[unitID] then
		return false
	end
	sel.drag = {
		grabID = unitID,
		pressX = mx,
		pressY = my,
		startX = wx,
		startZ = wz,
		moved = false,
		infos = infos,
		origins = origins,
		targets = nil,
	}
	return true
end

local function updateSelectionDrag(mx, my)
	local drag = sel.drag
	if not drag then
		return
	end
	if not drag.moved and abs(mx - drag.pressX) < BOX_MIN_PX and abs(my - drag.pressY) < BOX_MIN_PX then
		return
	end
	drag.moved = true
	local wx, wz = groundUnderMouse()
	if not wx then
		return
	end
	drag.targets = dragTargets(wx, wz)
	dragGhosts.sync(drag.targets, 0.45)
end

local function endSelectionDrag()
	local drag = sel.drag
	sel.drag = nil
	dragGhosts.clear()
	if drag and drag.moved and drag.targets then
		sendTransforms(movesFrom(drag.infos, drag.targets))
	elseif drag and not drag.moved and drag.collapse then
		setSelection({ drag.grabID }, false)
	end
end

----------------------------------------------------------------
-- Library, activation
----------------------------------------------------------------
local function openLibrary()
	if not (WG.UnitLibrary and WG.UnitLibrary.open) then
		Spring.Echo("[Unit Placer] the unit library is not loaded (Unit Library UI)")
		return false
	end
	return WG.UnitLibrary.open({
		title = libraryTitle(),
		-- Several picked (Shift+click): each drop moves on to the next type (PtaQ's N2).
		onPick = function(unitDefName, set)
			local names = set and set.names or { unitDefName }
			local cycle = #names > 1 and Cycle.new(names, set.mode) or nil
			local facing = lastPick and lastPick.facing or nil
			lastPick =
				{ kind = "unit", value = cycle and cycle.current() or unitDefName, cycle = cycle, facing = facing }
			pv.layoutKey, pv.stampKey = nil, nil
			clearSelection()
			syncArming()
		end,
		onPickBlueprint = function(blueprint)
			lastPick = { kind = "blueprint", value = blueprint }
			clearSelection()
			syncArming()
		end,
	})
end

local function activate()
	up.active = true
	up.mode = up.mode or "point"
	openLibrary()
	syncArming()
end

local function deactivate()
	up.active = false
	up.mode = nil
	up.dragging, up.dragAction, up.dragStroke = false, nil, nil
	dropPick()
	clearSelection()
	stampGhosts.clear()
	hideBuildGrid()
	if WG.UnitLibrary and WG.UnitLibrary.owner and WG.UnitLibrary.owner() == libraryTitle() then
		WG.UnitLibrary.close()
	end
end

local function cycleTeam()
	if mission.on() then
		up.missionTeam = (up.missionTeam + 1) % mission.TEAMS
		pv.stampKey = nil
		if placer.armed() then
			syncArming()
		end
		return up.missionTeam
	end
	local list = teams()
	local now = currentTeam()
	local nextTeam = list[1]
	for index, teamID in ipairs(list) do
		if teamID == now then
			nextTeam = list[index % #list + 1]
		end
	end
	up.team = nextTeam
	pv.stampKey = nil
	if placer.armed() then
		syncArming()
	end
	return up.team
end

----------------------------------------------------------------
-- Save / load / clear
----------------------------------------------------------------
local function saveUnits()
	Spring.CreateDir(SAVE_DIR)
	local filename = SAVE_DIR .. (Game.mapName or "unknown") .. "_units_" .. os.date("%Y%m%d_%H%M%S") .. ".lua"
	local file = io.open(filename, "w")
	if not file then
		Spring.Echo("[Unit Placer] Failed to open " .. filename .. " for writing")
		return nil
	end
	local count = 0
	file:write("-- Unit map: " .. tostring(Game.mapName) .. ", saved " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
	file:write("return {\n\tunits = {\n")
	for _, unitID in ipairs(owner.provider.all()) do
		local info = unitInfo(unitID)
		if info then
			count = count + 1
			file:write(
				string.format(
					"\t\t{ name = %q, x = %d, z = %d, facing = %d, team = %d },\n",
					info.name,
					floor(info.x + 0.5),
					floor(info.z + 0.5),
					info.facing,
					info.team or 0
				)
			)
		end
	end
	file:write("\t},\n}\n")
	file:close()
	Spring.Echo("[Unit Placer] Saved " .. count .. " units to " .. filename)
	return filename
end

local function loadUnits(path)
	if not path or path == "" then
		Spring.Echo("[Unit Placer] No file named")
		return false
	end
	local content = VFS.LoadFile(path, VFS.RAW)
	if not content then
		local file = io.open(path, "r")
		if file then
			content = file:read("*a")
			file:close()
		end
	end
	if not content then
		Spring.Echo("[Unit Placer] Cannot open " .. tostring(path))
		return false
	end
	local fn, err = loadstring(content, nil, {})
	if not fn then
		Spring.Echo("[Unit Placer] Parse error: " .. tostring(err))
		return false
	end
	local ok, data = pcall(fn)
	if not (ok and type(data) == "table" and type(data.units) == "table") then
		Spring.Echo("[Unit Placer] Not a unit map: " .. tostring(path))
		return false
	end
	local known = {}
	for _, teamID in ipairs(teams()) do
		known[teamID] = true
	end
	local spots = {}
	for _, unit in ipairs(data.units) do
		local x, z = tonumber(unit.x), tonumber(unit.z)
		local team = tonumber(unit.team)
		if type(unit.name) == "string" and UnitDefNames[unit.name] and x and z then
			spots[#spots + 1] = {
				name = unit.name,
				x = floor(x),
				z = floor(z),
				facing = floor(tonumber(unit.facing) or 0) % 4,
				team = (team and known[team]) and team or currentTeam(),
			}
		end
	end
	-- One stroke: the whole file is one undo.
	sendPlacements(spots)
	Spring.Echo("[Unit Placer] Loading " .. #spots .. " units from " .. tostring(path))
	return true
end

local function listSaves()
	return VFS.DirList(SAVE_DIR, "*.lua", VFS.RAW) or {}
end

----------------------------------------------------------------
-- The API (WG.UnitPlacerTool)
----------------------------------------------------------------
Tool.activate = activate
Tool.deactivate = deactivate
Tool.openLibrary = openLibrary
Tool.team = currentTeam
Tool.cycleTeam = cycleTeam
--- The TEAM chip's text: "TEAM 1" live, "MISSION TEAM 2" in MISSION mode
Tool.teamLabel = function()
	return (mission.on() and "MISSION TEAM " or "TEAM ") .. tostring(currentTeam())
end
--- "live" | "mission"
Tool.kind = function()
	return up.kind
end
Tool.setKind = function(kind)
	if kind ~= "live" and kind ~= "mission" then
		return false
	end
	if up.kind ~= kind then
		up.kind = kind
		clearSelection()
		pv.stampKey = nil
		if placer.armed() then
			syncArming()
		end
	end
	return true
end
--- Every unit on the map into a mission unit (toMission) or back into a live one, in place,
--- as one undo step. Each keeps its team as its mission team.
Tool.convertAll = function(toMission)
	sendMsg(MSG.mission .. nextStrokeId() .. "|" .. (toMission and "1" or "0") .. "|ALL")
end
Tool.reroll = reroll
Tool.clearSelection = clearSelection
Tool.deleteSelection = deleteSelection
Tool.selectAllVisible = selectAllVisible
Tool.reformSelection = reformSelection
Tool.spaceSelection = spaceSelection
Tool.turnSelection = turnSelection
Tool.save = saveUnits
Tool.load = loadUnits
Tool.listSaves = listSaves

function Tool.isActive()
	return up.active
end

function Tool.getState()
	return {
		active = up.active,
		mode = up.mode,
		shape = up.shape,
		radius = up.radius,
		rotation = up.rotation,
		rotRandom = up.rotRandom,
		unitCount = up.unitCount,
		cadence = up.cadence,
		distribution = up.distribution,
		smartEnabled = up.smartEnabled,
		smartFilters = up.smartFilters,
		pickedNames = pickedNames(),
		team = currentTeam(),
		undoCount = up.undoCount,
		redoCount = up.redoCount,
		gridOverlay = grid.overlay,
		gridSnap = grid.snap,
		gridSnapSize = grid.snapSize,
		selectMode = selectModeActive() and true or false,
		gameClicks = mission.gameOwnsClicks(), -- LIVE: plain clicks select and order as in a game
		kind = up.kind,
		selectionCount = #sel.ids,
		dragging = up.dragging or (sel.drag ~= nil and sel.drag.moved) or false,
		formation = isFormation(),
		spacing = up.spacing,
	}
end

--- Spacing of a line / grid / box drag, in build squares, kept across picks.
--- Let go of the library pick, as a right-click on the map does.
function Tool.dropPick()
	dropPick()
end

function Tool.setSpacing(n)
	up.spacing = max(0, min(LIMIT.spacingMax, floor(tonumber(n) or 0)))
	local spec = placer and placer.spec()
	if spec and not spec.group then
		placer.setSpacing(up.spacing)
	end
	return up.spacing
end

--- FORMATION density: a selection on an empty mouse packs or spreads (the mission
--- editor's TIGHTER / LOOSER); otherwise it is the spacing of the next drag.
function Tool.density(dir)
	if selectModeActive() and #sel.ids >= 2 then
		return spaceSelection(dir > 0 and (4 / 3) or 0.75)
	end
	Tool.setSpacing(up.spacing + (dir > 0 and 1 or -1))
	return true
end

--- Switching mode turns the tool on (and opens the library), as the feature placer's does.
function Tool.setMode(mode)
	if not MODES[mode] then
		return
	end
	up.mode = mode
	if not up.active then
		up.active = true
	end
	if WG.UnitLibrary and not (WG.UnitLibrary.isOpen and WG.UnitLibrary.isOpen()) then
		openLibrary()
	end
	pv.stampKey = nil
	syncArming()
end

function Tool.setShape(shape)
	if SHAPES[shape] then
		up.shape = shape
	end
end

function Tool.setRadius(r)
	up.radius = max(LIMIT.radiusMin, min(LIMIT.radiusMax, floor(tonumber(r) or up.radius)))
end

function Tool.setRotation(deg)
	up.rotation = floor(tonumber(deg) or 0) % 360
end

function Tool.rotate(delta)
	-- Not floored: the terraform brush's angle snap can step by half a degree.
	up.rotation = (up.rotation + (tonumber(delta) or 0)) % 360
end

function Tool.setRotRandom(v)
	up.rotRandom = max(0, min(100, floor(tonumber(v) or 0)))
	pv.stampKey = nil
end

function Tool.setUnitCount(n)
	up.unitCount = max(1, min(LIMIT.countMax, floor(tonumber(n) or 1)))
end

function Tool.setCadence(c)
	up.cadence = max(1, min(1000, floor(tonumber(c) or up.cadence)))
end

function Tool.setDistribution(d)
	if DISTRIBUTIONS[d] then
		up.distribution = d
		pv.layoutKey, pv.stampKey = nil, nil
		syncArming()
	end
end

function Tool.setSmartEnabled(b)
	up.smartEnabled = b and true or false
	pv.stampKey = nil
end

function Tool.setSmartFilter(key, value)
	if up.smartFilters[key] ~= nil then
		up.smartFilters[key] = value
		pv.stampKey = nil
	end
end

function Tool.setGridOverlay(b)
	grid.overlay = b and true or false
	if grid.overlay then
		ensureBuildGridLoaded()
		grid.dirty = true
	end
end

function Tool.setGridSnap(b)
	grid.snap = b and true or false
	if grid.snap then
		ensureBuildGridLoaded()
	end
end

function Tool.setGridSnapSize(n)
	grid.snapSize = max(16, min(128, floor(tonumber(n) or grid.snapSize)))
	grid.dirty = true
end

function Tool.undo()
	owner.sink.undo()
end

function Tool.redo()
	owner.sink.redo()
end

function Tool.clearAll()
	clearSelection()
	owner.sink.clearAll(nextStrokeId())
end

--- Another owner takes the tool (units unification, phase 2): its provider says what is
--- placed, its sink does what a gesture asks. The mission editor installs a pair over its
--- document; `Tool.resetOwner` gives the brush its engine pair back. Both drop the
--- selection and the pick: ids mean nothing across owners.
---@param name string
---@param provider table see PROVIDER_FIELDS
---@param sink table see SINK_FIELDS
---@param opts table|nil { title = the unit library's title under this owner }
---@return boolean ok, string|nil why
function Tool.setOwner(name, provider, sink, opts)
	for _, field in ipairs(PROVIDER_FIELDS) do
		if type(provider) ~= "table" or type(provider[field]) ~= "function" then
			return false, "provider has no " .. field
		end
	end
	for _, field in ipairs(SINK_FIELDS) do
		if type(sink) ~= "table" or type(sink[field]) ~= "function" then
			return false, "sink has no " .. field
		end
	end
	clearSelection()
	dropPick()
	owner.name, owner.provider, owner.sink = tostring(name), provider, sink
	owner.title = type(opts) == "table" and opts.title or nil
	up.team = nil
	up.undoCount, up.redoCount = 0, 0
	return true
end

function Tool.resetOwner()
	clearSelection()
	dropPick()
	owner.name, owner.provider, owner.sink, owner.title = "terraform_brush", engineProvider, gadgetSink, nil
	up.team = nil
	up.undoCount, up.redoCount = 0, 0
end

function Tool.ownerName()
	return owner.name
end

--- An owner reports its undo depth (the gadget does so through unit_placer_history).
function Tool.setHistory(undoCount, redoCount)
	up.undoCount = tonumber(undoCount) or 0
	up.redoCount = tonumber(redoCount) or 0
end

--- For the harness: the placer, the type armed now, and a drop at a world point as a click
--- would (a drag from (x1, z1) to (x2, z2) for the placer; a stamp at (x1, z1) for the brush).
function Tool.placer()
	return placer
end

function Tool.pickedType()
	return lastPick and lastPick.kind == "unit" and lastPick.value or nil
end

--- Is anything on the cursor (a unit, a blueprint, a paste, an armed placer)? An owner that
--- sees right-clicks and Escape first asks this before taking them for itself.
function Tool.hasPick()
	return lastPick ~= nil or (placer ~= nil and placer.armed()) or false
end

--- Does the tool hold anything Escape would let go of (a selection, a drag, a pick)?
function Tool.holdsSomething()
	return #sel.ids > 0 or sel.drag ~= nil or Tool.hasPick()
end

--- The selection, as ids in the order selected (a copy).
function Tool.selection()
	local out = {}
	for index, id in ipairs(sel.ids) do
		out[index] = id
	end
	return out
end

--- Set the selection from outside (an owner whose own lists select things: the mission
--- editor's roster). `silent` keeps the owner's sink from hearing it back.
---@param ids table
---@param silent boolean|nil
function Tool.select(ids, silent)
	-- Selecting means no longer placing: a pick left on the cursor would clear the selection
	-- on the next update ("a pick means placing again").
	if ids and #ids > 0 then
		dropPick()
	end
	sel.silent = silent == true
	setSelection(ids or {}, false)
	sel.silent = false
end

--- A HARNESS POINTER: a world point standing in for the mouse (nil gives the mouse back),
--- and a press, a move and a release there, as the mouse would send them. A probe window
--- that is not focused cannot move the real pointer, and a world point is what a check
--- knows. `mods` = { shift, ctrl, alt } held for the press.
function Tool.setPointer(x, z)
	sel.pointer = (x and z) and { x = x, z = z } or nil
end

local function pointerScreen()
	local p = sel.pointer
	if not p then
		local mx, my = Spring.GetMouseState()
		return mx, my
	end
	local sx, sy = Spring.WorldToScreenCoords(p.x, Spring.GetGroundHeight(p.x, p.z), p.z)
	return floor(sx or 0), floor(sy or 0)
end

local function withMods(mods, fn)
	local real = Spring.GetModKeyState
	mods = mods or {}
	Spring.GetModKeyState = function()
		return mods.alt == true, mods.ctrl == true, false, mods.shift == true
	end
	local ok, result = pcall(fn)
	Spring.GetModKeyState = real
	return ok and result
end

function Tool.pointerDown(mods)
	local sx, sy = pointerScreen()
	return withMods(mods, function()
		local press = widget.MousePress
		return press and press(widget, sx, sy, tonumber(mods and mods.button) or 1)
	end)
end

function Tool.pointerMove()
	local sx, sy = pointerScreen()
	return withMods(nil, function()
		return widget:MouseMove(sx, sy, 0, 0, 1)
	end)
end

function Tool.pointerUp(mods)
	local sx, sy = pointerScreen()
	return withMods(mods, function()
		return widget:MouseRelease(sx, sy, tonumber(mods and mods.button) or 1)
	end)
end

--- A key, as if pressed over the map: for an owner that sees keys first and passes some
--- on (the mission editor), and for its harness.
function Tool.keyPress(key, mods)
	return widget:KeyPress(key, mods or {}, false, "", 0, 0)
end

function Tool.placeAt(x1, z1, x2, z2)
	if placer.armed() then
		placer.mousePress(x1, z1, 1)
		placer.mouseMove(x2 or x1, z2 or z1)
		return placer.mouseRelease()
	end
	if up.active and (up.mode == "scatter" or up.mode == "point") and lastPick and lastPick.kind == "unit" then
		return stampAt(x1, z1)
	end
	return false
end

----------------------------------------------------------------
-- Callbacks from the gadget
----------------------------------------------------------------
local function onHistory(undoCount, redoCount)
	up.undoCount = tonumber(undoCount) or 0
	up.redoCount = tonumber(redoCount) or 0
end

--- A unit created again (undo, redo, a move) has a new id: the selection follows it.
local function onRemap(oldID, newID)
	if not (oldID and newID and sel.set[oldID]) then
		return
	end
	sel.set[oldID] = nil
	sel.set[newID] = true
	for index, unitID in ipairs(sel.ids) do
		if unitID == oldID then
			sel.ids[index] = newID
		end
	end
	if mission.gameOwnsClicks() then
		mission.pushToGame()
	end
end

----------------------------------------------------------------
-- Widget
----------------------------------------------------------------
function widget:Initialize()
	local modOptions = Spring.GetModOptions() or {}
	mission.session = tostring(modOptions.editor_sandbox or "") == "1" or tostring(modOptions.mapeditor or "") == "1"
	placer = Placer.new({
		owner = "unit_placer_tool",
		-- Stays armed after a placement: laying out a base is many drags of the same thing.
		sticky = true,
		onPlaced = function(result)
			sendPlacements(expandPlacement(result))
			advanceCycle()
		end,
		onCancelled = function()
			dropPick()
		end,
	})
	WG.UnitPlacerTool = Tool
	-- The game's spacing keys (Alt+Z wider, Alt+X tighter, in every keybind layout: the
	-- buildspacing action) drive FORMATION density: the next drag's spacing with a unit
	-- picked, or the selection packed or spread on an empty mouse.
	widgetHandler:AddAction("buildspacing", function(_, _, args)
		if not (up.active and up.mode ~= "remove") then
			return false
		end
		local dir = args and args[1] == "inc" and 1 or (args and args[1] == "dec" and -1 or 0)
		if dir == 0 then
			return false
		end
		Tool.density(dir)
		return true
	end, nil, "p")

	local function registerGlobalChecked(name, fn)
		if not widgetHandler:RegisterGlobal(name, fn) then
			Spring.Echo("[Unit Placer] RegisterGlobal name collision, callback inactive: " .. name)
		end
	end
	registerGlobalChecked("unit_placer_history", onHistory)
	registerGlobalChecked("unit_placer_remap", onRemap)
end

function widget:Shutdown()
	if placer then
		placer.shutdown()
	end
	stampGhosts.clear()
	dragGhosts.clear()
	hideBuildGrid()
	if grid.dl then
		gl.DeleteList(grid.dl)
		grid.dl = nil
	end
	widgetHandler:RemoveAction("buildspacing")
	widgetHandler:DeregisterGlobal("unit_placer_history")
	widgetHandler:DeregisterGlobal("unit_placer_remap")
	WG.UnitPlacerTool = nil
end

--- The terraform brush's own click tools (measure, height sampling, the symmetry origin)
--- take the mouse first.
local function deferToTerraformBrush()
	---@type table?
	local tb = WG.TerraformBrush
	if not tb then
		return false
	end
	---@type table?
	local st = tb.getState and tb.getState()
	if st then
		if st.measureActive or st.heightSamplingMode then
			return true
		end
		if
			st.symmetryActive
			and (st.symmetryPlacingOrigin or st.symmetryHoveringOrigin or st.symmetryDraggingOrigin)
		then
			return true
		end
	end
	return tb.getHeightSamplingMode and tb.getHeightSamplingMode() and true or false
end

--- Start a brush gesture (place or remove) at the cursor; held, it repeats at the cadence.
local function beginBrush(action)
	local x, z = brushCursor()
	if not x then
		return false
	end
	if grid.snap then
		x, z = snapToGrid(x, z)
	end
	up.dragging, up.dragAction, up.dragStroke, up.placeTimer = true, action, nil, 0
	if action == "remove" then
		removeAt(x, z)
	else
		stampAt(x, z)
	end
	return true
end

local function selectPress(mx, my)
	local _, ctrl, _, shift = Spring.GetModKeyState()
	local gx, gz = groundUnderMouse()
	local target = owner.provider.pick(mx, my, gx, gz)
	if target ~= nil and not ctrl then
		if shift then
			toggleSelection(target)
			return true
		end
		-- A click (no drag) on one of several selected units selects just that one.
		local collapse = sel.set[target] and #sel.ids > 1
		if not sel.set[target] then
			setSelection({ target }, false)
		end
		if beginSelectionDrag(target, mx, my) and sel.drag then
			sel.drag.collapse = collapse
		end
		return true
	end
	if ctrl and #sel.ids > 0 then
		local x, z = groundUnderMouse()
		if x then
			faceSelection(x, z)
			return true
		end
	end
	-- Empty ground inside the lasso: grab the whole group, as a press on one of them would.
	if not shift and #sel.ids >= 2 then
		local ix, iz = groundUnderMouse()
		if ix and insideLasso(ix, iz) and beginSelectionDrag(sel.ids[1], mx, my) then
			return true
		end
	end
	sel.boxing = true
	sel.boxAdditive = shift and true or false
	sel.boxX1, sel.boxY1, sel.boxX2, sel.boxY2 = mx, my, mx, my
	return true
end

function widget:MousePress(mx, my, button)
	if not (up.active and up.mode) then
		return false
	end
	-- Mouse buttons 4 and 5 are the game's other spacing control (gui_buildspacing, which
	-- only acts on a real build command). Not consumed: barwidgets sends no release for
	-- them, so taking the press would leave this widget owning the mouse.
	if button == 4 or button == 5 then
		local _, ctrl, meta = Spring.GetModKeyState()
		if up.mode ~= "remove" and not (ctrl or meta) then
			Tool.density(button == 4 and 1 or -1)
		end
		return false
	end
	if deferToTerraformBrush() or overUi(true) then
		return false
	end
	-- A right-click during a Shift drag drops the drag, not the pick, as in the game.
	if button == 3 and up.modDrag then
		up.modDrag = false
		syncArming()
		return true
	end
	-- Shift on the press: the game's build drag (line, grid, box by the keys held), from
	-- point mode or the brush alike. The plain click keeps doing what the mode does.
	if
		button == 1
		and lastPick
		and lastPick.kind == "unit"
		and up.mode ~= "remove"
		and not placer.armed()
		and gameBuildMode()
	then
		up.modDrag = true
		syncArming()
		placer.setMode("SINGLE")
		up.modOverride, up.modBase = false, nil
	end
	if placer.armed() then
		local x, z = groundUnderMouse()
		if button == 1 and not x then
			return false
		end
		return placer.mousePress(x, z, button)
	end
	if button == 1 then
		if up.mode == "remove" then
			return beginBrush("remove")
		end
		if selectClicksActive() then
			return selectPress(mx, my)
		end
		if lastPick == nil and mission.gameOwnsClicks() then
			return false
		end
		return beginBrush("place")
	end
	-- Right-click lets go of the library pick (nothing on the cursor any more: clicks select
	-- again). It never removes: that is Delete on a selection, or the REMOVE mode's brush.
	if button == 3 and lastPick and up.mode ~= "remove" then
		dropPick()
		return true
	end
	return false
end

function widget:MouseMove(mx, my)
	if sel.drag then
		updateSelectionDrag(mx, my)
		return true
	end
	if sel.boxing then
		sel.boxX2, sel.boxY2 = mx, my
		return true
	end
	if up.active and placer.armed() then
		local x, z = groundUnderMouse()
		return placer.mouseMove(x, z)
	end
	return false
end

function widget:MouseRelease(mx, my, button)
	if button == 1 and sel.drag then
		endSelectionDrag()
		return true
	end
	if button == 1 and sel.boxing then
		sel.boxing = false
		sel.boxX2, sel.boxY2 = mx, my
		if abs(sel.boxX2 - sel.boxX1) >= BOX_MIN_PX or abs(sel.boxY2 - sel.boxY1) >= BOX_MIN_PX then
			selectAllInBox(sel.boxX1, sel.boxY1, sel.boxX2, sel.boxY2, sel.boxAdditive)
		elseif not sel.boxAdditive then
			clearSelection()
		end
		return true
	end
	if up.dragging and (button == 1 or button == 3) then
		up.dragging, up.dragAction, up.dragStroke = false, nil, nil
		return true
	end
	-- Only the left button ends a drag: this widget owns the mouse for the whole drag, so the
	-- release of a spacing button (mouse 4 / 5) pressed mid-drag arrives here too, and used to
	-- drop the formation on the spot.
	if up.active and placer.armed() and button == 1 then
		local consumed = placer.mouseRelease()
		if up.modDrag then
			up.modDrag = false
			syncArming()
		end
		return consumed
	end
	return false
end

---@return boolean
function widget:MouseWheel(wheelUp)
	if not up.active or overUi(true) then
		return false
	end
	local alt, ctrl, _, shift = Spring.GetModKeyState()
	local dir = wheelUp and 1 or -1
	if alt then
		local step = LIMIT.rotationStep
		---@type table?
		local tb = WG.TerraformBrush
		local tbs = tb and tb.getState and tb.getState() or nil
		if tbs and tbs.angleSnap and (tbs.angleSnapStep or 0) > 0 then
			step = tbs.angleSnapStep
		end
		Tool.rotate(dir * step)
		return true
	end
	if shift then
		Tool.setUnitCount(up.unitCount + dir)
		return true
	end
	if Spring.GetKeyState(KEY.space) then
		local c = up.cadence
		Tool.setCadence(wheelUp and max(c * 1.15, c + 1) or min(c / 1.15, c - 1))
		return true
	end
	if ctrl then
		Tool.setRadius(up.radius + dir * LIMIT.radiusStep)
		return true
	end
	return false
end

function widget:KeyPress(key, mods)
	if not up.active then
		return false
	end
	mods = mods or {}
	-- Over the unit library its grid keys (plain letters: Q W E R, A S D F, Z X C V, T G B)
	-- belong to it. Delete, Escape, Tab and the Ctrl shortcuts are never its, so they work
	-- wherever the pointer is.
	local plainLetter = key >= 97 and key <= 122 and not (mods.ctrl or mods.alt or mods.meta)
	if plainLetter and overUi() then
		return false
	end
	if mods.ctrl and key == KEY.z and not mods.shift then
		Tool.undo()
		return true
	end
	if mods.ctrl and (key == KEY.y or (key == KEY.z and mods.shift)) then
		Tool.redo()
		return true
	end
	if key == KEY.escape then
		if sel.drag or #sel.ids > 0 then
			clearSelection()
			return true
		end
		if lastPick or placer.armed() then
			dropPick()
			return true
		end
		return false
	end
	if mods.ctrl and key == KEY.c then
		return copySelection()
	end
	if mods.ctrl and key == KEY.x then
		return cutSelection()
	end
	if mods.ctrl and key == KEY.v then
		return paste()
	end
	if placer.armed() then
		return placer.keyPress(key, mods)
	end
	if selectModeActive() then
		if (key == KEY.delete or key == KEY.backspace) and #sel.ids > 0 then
			deleteSelection()
			return true
		end
		if key == KEY.r and not mods.ctrl and #sel.ids > 0 then
			return turnSelection(mods.shift and -1 or 1)
		end
		if mods.ctrl and key == KEY.a then
			selectAllVisible()
			return true
		end
	end
	return false
end

function widget:Update(dt)
	if not up.active then
		return
	end
	if mission.gameOwnsClicks() then
		mission.mirror()
	end
	if #sel.ids >= 2 then
		lasso.age = lasso.age + (dt or 0)
		if lasso.age >= LASSO_REFRESH or sel.drag then
			lasso.age, lasso.dirty = 0, true
		end
		local gx, gz = groundUnderMouse()
		lasso.hover = gx ~= nil and insideLasso(gx, gz)
	else
		lasso.hull, lasso.hover = nil, false
	end
	if placer.armed() then
		-- The build-drag keys take the shape while held and give it back when let go, so a
		-- formation picked in the panel, or a Tab, is what a plain drag lays out again.
		local spec = placer.spec()
		local want = gameBuildMode()
		if want then
			if not up.modOverride then
				up.modOverride, up.modBase = true, spec and spec.mode
			end
			placer.setMode(want)
		elseif up.modOverride then
			up.modOverride = false
			placer.setMode(up.modBase or "SINGLE")
			up.modBase = nil
		end
		local x, z = groundUnderMouse()
		placer.update(x, z)
	end
	-- A Shift drag whose release was swallowed must not leave the placer armed.
	if up.modDrag and not select(3, Spring.GetMouseState()) then
		up.modDrag = false
		syncArming()
	end

	-- A pick means placing again: a stale selection would catch clicks meant for the brush.
	if lastPick and #sel.ids > 0 then
		clearSelection()
	end
	sel.pruneTimer = sel.pruneTimer + dt
	if sel.pruneTimer > 0.5 then
		sel.pruneTimer = 0
		for index = #sel.ids, 1, -1 do
			local unitID = sel.ids[index]
			if not owner.provider.valid(unitID) then
				sel.set[unitID] = nil
				table.remove(sel.ids, index)
			end
		end
	end

	-- MouseMove only fires while a button is down in some camera modes; poll the release
	-- too, so a drag cannot stick when the release is swallowed. Not under a harness
	-- pointer: the harness presses and lets go itself, and the real button is up.
	if sel.pointer then
		return
	end
	local mx, my, left, _, right = Spring.GetMouseState()
	if sel.drag then
		if left then
			updateSelectionDrag(mx, my)
		else
			endSelectionDrag()
		end
		return
	end
	if not up.dragging then
		return
	end
	local held = (up.dragAction == "remove" and (left or right)) or (up.dragAction == "place" and left)
	if not held then
		up.dragging, up.dragAction, up.dragStroke = false, nil, nil
		return
	end
	up.placeTimer = up.placeTimer + dt
	local interval = cadenceInterval()
	if up.placeTimer < interval then
		return
	end
	up.placeTimer = up.placeTimer - interval
	local x, z = brushCursor()
	if not x then
		return
	end
	if grid.snap then
		x, z = snapToGrid(x, z)
	end
	if up.dragAction == "remove" then
		removeAt(x, z)
	elseif
		up.mode ~= "point"
		or not (up.lastStampX and up.lastStampZ)
		or abs(x - up.lastStampX) >= 16
		or abs(z - up.lastStampZ) >= 16
	then
		-- POINT held still would stack units on one spot; it repeats once the cursor moves.
		stampAt(x, z)
	end
end

----------------------------------------------------------------
-- Drawing
----------------------------------------------------------------
local function rotatePoint(px, pz, angleDeg)
	local rad = angleDeg * pi / 180
	return px * cos(rad) - pz * sin(rad), px * sin(rad) + pz * cos(rad)
end

local function drawRegularPolygon(cx, cz, radius, angleDeg, sides)
	local step = 2 * pi / sides
	local offset = angleDeg * pi / 180
	gl.BeginEnd(GL.LINE_LOOP, function()
		for i = 0, sides - 1 do
			local a = i * step + offset
			local x, z = cx + radius * cos(a), cz + radius * sin(a)
			gl.Vertex(x, Spring.GetGroundHeight(x, z) + 4, z)
		end
	end)
end

local function drawRotatedSquare(cx, cz, radius, angleDeg)
	local corners = { { -radius, -radius }, { radius, -radius }, { radius, radius }, { -radius, radius } }
	gl.BeginEnd(GL.LINE_LOOP, function()
		for _, c in ipairs(corners) do
			local rx, rz = rotatePoint(c[1], c[2], angleDeg)
			local x, z = cx + rx, cz + rz
			gl.Vertex(x, Spring.GetGroundHeight(x, z) + 4, z)
		end
	end)
end

local SHAPE_SIDES = { circle = CIRCLE_SEGMENTS, hexagon = 6, octagon = 8, triangle = 3 }

local function drawShape(cx, cz, angleDeg)
	if up.shape == "square" then
		drawRotatedSquare(cx, cz, up.radius, angleDeg)
	else
		drawRegularPolygon(cx, cz, up.radius, angleDeg, SHAPE_SIDES[up.shape] or CIRCLE_SEGMENTS)
	end
end

local function drawCrosshair(x, z)
	local y = Spring.GetGroundHeight(x, z) + 4
	local s = 12
	gl.BeginEnd(GL.LINES, function()
		gl.Vertex(x - s, y, z)
		gl.Vertex(x + s, y, z)
		gl.Vertex(x, y, z - s)
		gl.Vertex(x, y, z + s)
	end)
end

--- A footprint rectangle on the ground.
local function drawFootprint(x, z, w, h)
	local corners =
		{ { x - w / 2, z - h / 2 }, { x + w / 2, z - h / 2 }, { x + w / 2, z + h / 2 }, { x - w / 2, z + h / 2 } }
	gl.BeginEnd(GL.LINE_LOOP, function()
		for i = 1, 4 do
			local cx, cz = corners[i][1], corners[i][2]
			gl.Vertex(cx, Spring.GetGroundHeight(cx, cz) + 4, cz)
		end
	end)
end

--- Green where the smart filters let a unit stand, red where they refuse.
local function drawSmartFilterOverlay(cx, cz)
	local radius = up.radius
	local rad = up.rotation * pi / 180
	local cosR, sinR = cos(rad), sin(rad)
	local half = SMART_GRID_STEP * 0.3
	local fade = up.edgeFade
	local GetGroundHeight = Spring.GetGroundHeight
	gl.DepthTest(true)
	gl.BeginEnd(GL.TRIANGLES, function()
		for lx = -radius, radius, SMART_GRID_STEP do
			for lz = -radius, radius, SMART_GRID_STEP do
				if BrushShapes.isInside(lx, lz, radius, up.shape, 0) then
					local wx, wz = cx + lx * cosR - lz * sinR, cz + lx * sinR + lz * cosR
					if passesFilters(wx, wz) then
						gl.Color(0.2, 0.85, 0.3, 0.08 * fade)
					else
						gl.Color(0.9, 0.15, 0.15, 0.14 * fade)
					end
					local x0, x1, z0, z1 = wx - half, wx + half, wz - half, wz + half
					local y00, y10 = GetGroundHeight(x0, z0) + 3, GetGroundHeight(x1, z0) + 3
					local y01, y11 = GetGroundHeight(x0, z1) + 3, GetGroundHeight(x1, z1) + 3
					gl.Vertex(x0, y00, z0)
					gl.Vertex(x1, y10, z0)
					gl.Vertex(x1, y11, z1)
					gl.Vertex(x0, y00, z0)
					gl.Vertex(x1, y11, z1)
					gl.Vertex(x0, y01, z1)
				end
			end
		end
	end)
	gl.DepthTest(false)
end

--- Rings under the selected units, sized by footprint.
local function drawSelection()
	gl.LineWidth(2)
	gl.Color(1.0, 0.85, 0.25, 0.85)
	for _, unitID in ipairs(sel.ids) do
		local info = unitInfo(unitID)
		if info then
			drawRegularPolygon(info.x, info.z, max(info.xsize or 2, info.zsize or 2) * 8 * 0.75 + 4, 0, 20)
		end
	end
	gl.LineWidth(1)
end

--- The lasso round a multi-selection: a faint fill, brighter under the pointer or in a drag,
--- and a loop that follows the ground (edges cut into short steps so it does not dive).
local function drawLasso()
	local hull = lassoHull()
	if not (hull and #hull >= 3) then
		return
	end
	local hot = lasso.hover or sel.drag ~= nil
	gl.DepthTest(false)
	local cx, cz = 0.0, 0.0
	for _, point in ipairs(hull) do
		cx, cz = cx + point.x, cz + point.z
	end
	cx, cz = cx / #hull, cz / #hull
	gl.Color(1.0, 0.85, 0.25, hot and 0.09 or 0.035)
	gl.BeginEnd(GL.TRIANGLE_FAN, function()
		gl.Vertex(cx, Spring.GetGroundHeight(cx, cz) + 4, cz)
		for i = 1, #hull + 1 do
			local point = hull[(i - 1) % #hull + 1]
			gl.Vertex(point.x, Spring.GetGroundHeight(point.x, point.z) + 4, point.z)
		end
	end)
	gl.LineWidth(2)
	gl.Color(1.0, 0.85, 0.25, hot and 0.8 or 0.45)
	gl.BeginEnd(GL.LINE_LOOP, function()
		for i = 1, #hull do
			local a, b = hull[i], hull[i % #hull + 1]
			local length = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
			local steps = max(1, floor(length / 32))
			for step = 0, steps - 1 do
				local t = step / steps
				local x, z = a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t
				gl.Vertex(x, Spring.GetGroundHeight(x, z) + 5, z)
			end
		end
	end)
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
	gl.DepthTest(true)
end

--- Red footprints under the units a removal would take.
local function drawRemovalTargets(x, z)
	gl.LineWidth(2)
	gl.Color(1.0, 0.2, 0.15, 0.9 * up.edgeFade)
	for _, unitID in ipairs(unitsInBrush(x, z)) do
		local info = unitInfo(unitID)
		if info then
			local w, h = Layout.footprint(info.xsize, info.zsize, info.facing or 0)
			drawFootprint(info.x, info.z, w + 4, h + 4)
			drawRegularPolygon(info.x, info.z, max(w, h) * 0.5, 45, 4)
		end
	end
	gl.LineWidth(1)
end

local function brushColor(alpha)
	local removing = up.mode == "remove" or (up.dragging and up.dragAction == "remove")
	if removing then
		gl.Color(0.9, 0.2, 0.2, alpha * up.edgeFade)
	elseif up.mode == "scatter" then
		gl.Color(0.2, 0.8, 0.4, alpha * up.edgeFade)
	else
		gl.Color(0.4, 0.7, 1.0, alpha * up.edgeFade)
	end
	return removing
end

--- Ground rings in the mission team's colour under every mission unit in view, so mission
--- teams read apart even where they all stand on Gaia. Editor sessions only.
function mission.drawMarkers()
	local frame = Spring.GetDrawFrame()
	if frame - mission.markersAt > 15 or frame < mission.markersAt then
		mission.markersAt = frame
		local list = {}
		for _, unitID in ipairs(Spring.GetVisibleUnits(-1, nil, false) or {}) do
			local m = mission.teamOf(unitID)
			if m then
				list[#list + 1] = { unitID, m }
			end
		end
		mission.markers = list
	end
	if #mission.markers == 0 then
		return
	end
	gl.LineWidth(3)
	for _, entry in ipairs(mission.markers) do
		local unitID, m = entry[1], entry[2]
		local x, y, z = Spring.GetUnitPosition(unitID)
		if x then
			local c = mission.PALETTE[(m % #mission.PALETTE) + 1]
			gl.Color(c[1], c[2], c[3], 0.85)
			gl.DrawGroundCircle(x, y, z, (Spring.GetUnitRadius(unitID) or 20) * 1.1, 24)
		end
	end
	gl.Color(1, 1, 1, 1)
	gl.LineWidth(1)
end

--- "M<team>" over each marked mission unit (screen space, after DrawWorld's rings).
function mission.drawLabels()
	if #mission.markers == 0 then
		return
	end
	for _, entry in ipairs(mission.markers) do
		local x, y, z = Spring.GetUnitPosition(entry[1])
		if x then
			local sx, sy, sz = Spring.WorldToScreenCoords(x, y + (Spring.GetUnitHeight(entry[1]) or 30), z)
			if sz and sz < 1 then
				local c = mission.PALETTE[(entry[2] % #mission.PALETTE) + 1]
				gl.Color(c[1], c[2], c[3], 1)
				gl.Text("M" .. entry[2], sx, sy, 13, "co")
			end
		end
	end
	gl.Color(1, 1, 1, 1)
end

function widget:DrawWorld()
	if mission.session then
		mission.drawMarkers()
	end
	if grid.overlay then
		if (not grid.dl) or grid.dlSize ~= grid.snapSize or grid.dirty then
			buildFullMapGrid()
		end
		if grid.dl then
			gl.CallList(grid.dl)
		end
	end

	if not (up.active and up.mode) then
		hideBuildGrid()
		stampGhosts.clear()
		return
	end

	if #sel.ids > 0 and not mission.gameOwnsClicks() then
		drawSelection()
	end
	if #sel.ids >= 2 and not mission.gameOwnsClicks() then
		drawLasso()
	end

	if grid.snap or grid.overlay then
		showBuildGrid()
	else
		hideBuildGrid()
	end

	-- The placer's preview is the Blueprint API's own.
	if placer.armed() then
		stampGhosts.clear()
		placer.drawWorld()
		return
	end

	local removing = up.mode == "remove" or (up.dragging and up.dragAction == "remove")
	-- Select mode shows no brush: a click there selects.
	if selectModeActive() and not removing then
		stampGhosts.clear()
		return
	end

	local x, z = brushCursor()
	---@type table?
	local tb = WG.TerraformBrush
	if tb and tb.animateUnmouse then
		x, z = tb.animateUnmouse("unitPlacer", x, z, up.radius, 1.0)
	elseif tb and tb.getUnmouseTarget and not x then
		x, z = tb.getUnmouseTarget(up.radius, 1.0)
	end
	if not x then
		stampGhosts.clear()
		return
	end
	if grid.snap then
		x, z = snapToGrid(x, z)
	end

	if removing then
		stampGhosts.clear()
		drawRemovalTargets(x, z)
	else
		stampGhosts.sync(currentStamp(x, z), GHOST_ALPHA * up.edgeFade)
	end

	local positions = getSymmetricPositions(x, z, up.rotation)
	gl.LineWidth(2)
	for index, p in ipairs(positions) do
		brushColor(index == 1 and 0.7 or 0.3)
		if up.mode == "point" and not removing then
			drawCrosshair(p.x, p.z)
		else
			drawShape(p.x, p.z, p.rot or up.rotation)
		end
	end
	if up.smartEnabled and up.mode == "scatter" and not removing then
		drawSmartFilterOverlay(x, z)
	end
	gl.Color(1, 1, 1, 1)
	gl.LineWidth(1)
end

function widget:DrawScreen()
	if mission.session then
		mission.drawLabels()
	end
	if not sel.boxing then
		return
	end
	local x1, y1, x2, y2 = sel.boxX1, sel.boxY1, sel.boxX2, sel.boxY2
	gl.Color(1.0, 0.85, 0.25, 0.12)
	gl.Rect(x1, y1, x2, y2)
	gl.Color(1.0, 0.85, 0.25, 0.9)
	gl.LineWidth(1.5)
	gl.BeginEnd(GL.LINE_LOOP, function()
		gl.Vertex(x1, y1)
		gl.Vertex(x2, y1)
		gl.Vertex(x2, y2)
		gl.Vertex(x1, y2)
	end)
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end
