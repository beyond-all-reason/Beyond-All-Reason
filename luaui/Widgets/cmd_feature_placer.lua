function widget:GetInfo()
	return {
		name = "Feature Placer",
		desc = "Brush tool for placing, arranging, and removing map features",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1000000,
		enabled = false,
	}
end

----------------------------------------------------------------
-- Localize engine calls
----------------------------------------------------------------
local Echo = Spring.Echo
local GetMouseState = Spring.GetMouseState
local GetModKeyState = Spring.GetModKeyState
local GetKeyState = Spring.GetKeyState
local TraceScreenRay = Spring.TraceScreenRay
local GetGroundHeight = Spring.GetGroundHeight
local GetGroundNormal = Spring.GetGroundNormal
local GetGameFrame = Spring.GetGameFrame
local SendLuaRulesMsg = Spring.SendLuaRulesMsg
local GetAllFeatures = Spring.GetAllFeatures
local GetFeaturePosition = Spring.GetFeaturePosition
local GetFeatureDefID = Spring.GetFeatureDefID

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glDepthTest = gl.DepthTest
local glCreateList = gl.CreateList
local glDeleteList = gl.DeleteList
local glCallList = gl.CallList
local glPolygonOffset = gl.PolygonOffset
local GL_TRIANGLES = GL.TRIANGLES
local GL_LINES = GL.LINES
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_LINE_STRIP = GL.LINE_STRIP

----------------------------------------------------------------
-- Constants
----------------------------------------------------------------
-- Placement is now a list this widget generated and previewed, not a set of
-- brush parameters for the gadget to roll its own dice with. That is what makes
-- the ghost preview truthful: preview and result are the same array.
local PLACELIST_HEADER = "$feature_place_list$"
local TRANSFORM_HEADER = "$feature_transform$"
local REMOVEIDS_HEADER = "$feature_remove_ids$"
local REMOVE_HEADER = "$feature_remove$"
local UNDO_HEADER = "$feature_undo$"
local REDO_HEADER = "$feature_redo$"
local SAVE_HEADER = "$feature_save$"
local LOAD_HEADER = "$feature_load$"
local CLEARALL_HEADER = "$feature_clearall$"

local SAVE_DIR = "Terraform Brush/FeatureMaps/"

-- Features per message. The richer placement format runs ~45 chars an entry, so
-- this keeps a full batch around 2 KB, in line with the load path that has been
-- shipping 50 shorter entries per message.
local PLACE_BATCH = 40

local GHOST_ALPHA = 0.55
local GHOST_OWNER = "cmd_feature_placer"
-- Ceiling on previewed ghosts only; placement is never capped.
local PREVIEW_GHOST_CAP = 300

-- Same generators the gadget used to run, moved widget-side so the preview can
-- see them. See the header of that file for why.
local Scatter = VFS.Include("common/feature_scatter.lua")
local BrushShapes = VFS.Include("common/brush_shapes.lua")
local Gizmo = VFS.Include("luaui/Include/gizmo3d_gl4.lua")

local abs = math.abs
local asin = math.asin
local atan2 = math.atan2

local CIRCLE_SEGMENTS = 48
local DEFAULT_RADIUS = 200
local MIN_RADIUS = 8
local MAX_RADIUS = 2000
local RADIUS_STEP = 8
local ROTATION_STEP = 3
local KEYSYMS_SPACE = 0x20
local UPDATE_INTERVAL = 1 / 30
local GRID_SNAP_SIZE = 48 -- matches build grid widget spacing (3 * 16 elmos)
local gridSnapSize = 48 -- mutable; user-adjustable via setGridSnapSize

local floor = math.floor
local max = math.max
local min = math.min
local cos = math.cos
local sin = math.sin
local pi = math.pi
local sqrt = math.sqrt

----------------------------------------------------------------
-- State (packed into table to conserve locals)
----------------------------------------------------------------
local fp = {
	active = false,
	mode = nil, -- "scatter", "point", "remove"
	shape = "circle",
	radius = DEFAULT_RADIUS,
	rotation = 0,
	rotRandom = 0, -- 0 = all same heading, 100 = fully random
	featureCount = 1,
	cadence = 10, -- 1-1000 logarithmic (higher = faster)
	distribution = "random", -- "random", "regular", or "clustered"
	smartEnabled = false, -- terrain-aware filtering applied on top of distribution
	smartFilters = {
		avoidWater = false, -- reject underwater positions (height < 0)
		avoidCliffs = false, -- reject terrain steeper than slopeMax degrees
		slopeMax = 45,
		preferSlopes = false, -- reject terrain flatter than slopeMin degrees
		slopeMin = 10,
		altMinEnable = false, -- reject terrain below altMin
		altMin = 0,
		altMaxEnable = false, -- reject terrain above altMax
		altMax = 200,
	},
	selectedDefs = {}, -- { defName1, defName2, ... }
	selectedSet = {}, -- { [defName] = true } for quick lookup
	dragging = false,
	dragAction = nil, -- "place" or "remove"
	lockedWorldX = nil,
	lockedWorldZ = nil,
	placeTimer = 0,
	undoCount = 0,
	redoCount = 0,
}

local updateTimer = 0
local gridOverlay = false
local gridSnap = false
local gridShowing = false
local gridDL = nil
local gridDLSize = nil
local gridDirty = false

----------------------------------------------------------------
-- Feature definition cache for asset library
----------------------------------------------------------------
local featureDefList = {} -- sorted { {name=..., id=...}, ... }
local featureDefListBuilt = false
local featureCategories = {} -- { categoryName = { {name=..., id=...}, ... } }

local CATEGORY_ORDER = {
	"rocks",
	"trees",
	"foliage",
	"crystals",
	"christmas",
	"raptor",
	"armada_wrecks",
	"cortex_wrecks",
	"legion_wrecks",
	"other",
}

local CATEGORY_LABELS = {
	rocks = "Rocks",
	trees = "Trees",
	foliage = "Foliage",
	crystals = "Crystals",
	christmas = "Christmas",
	raptor = "Raptor",
	armada_wrecks = "Armada Wrecks",
	cortex_wrecks = "Cortex Wrecks",
	legion_wrecks = "Legion Wrecks",
	other = "Other",
}

local function classifyFeature(name, def)
	-- Exclude debris and heaps entirely
	if name:find("_heap$") then
		return nil
	end
	if name:find("debris") then
		return nil
	end

	-- Christmas items
	if name:find("^candycane") or name:find("^xmascom") then
		return "christmas"
	end

	-- Raptor items
	if name:find("^raptor_egg") then
		return "raptor"
	end

	-- Crystals
	if name:find("^pilha_crystal") or name:find("^tiberium") then
		return "crystals"
	end

	-- Rocks
	if
		name:find("^rocks30_")
		or name:find("^prock%d")
		or name:find("^pdrock")
		or name:find("^brock_")
		or name:find("^moonrock")
		or name:find("^rocksoar")
		or name:find("^agorm_rock")
		or name:find("^slrock")
		or name:find("^rock%d")
		or name:find("^pvolcanicrock")
	then
		return "rocks"
	end

	-- Trees (checked before bushes since some naming overlaps)
	if
		name:find("^treetype%d")
		or name:find("^ad0_pine")
		or name:find("^ad0_aleppo")
		or name:find("^ad0_banyan")
		or name:find("^ad0_baobab")
		or name:find("^ad0_senegal")
		or name:find("^allpinesb_")
		or name:find("^lowpoly_tree_")
		or name:find("^cedar_atlas")
		or name:find("^btree")
		or name:find("^cluster")
		or name:find("^treecluster")
		or name:find("^talltree")
		or name:find("^fir_tree_")
		or name:find("^fir_sapling")
		or name:find("^hclus%d")
		or name:find("^hpalm%d")
		or name:find("^palmetto_")
		or name:find("^artbirch")
		or name:find("^artmaple")
		or name:find("^artoak")
	then
		return "trees"
	end

	-- Foliage and small plants
	if
		name:find("^ad0_bush")
		or name:find("^artbush")
		or name:find("^peyote")
		or name:find("^pedro")
		or name:find("^fern")
		or name:find("^cycas")
		or name:find("^mushroom")
	then
		return "foliage"
	end

	-- Faction wrecks (features created from unit deaths)
	if name:find("_dead$") then
		if name:find("^arm") then
			return "armada_wrecks"
		elseif name:find("^cor") then
			return "cortex_wrecks"
		elseif name:find("^leg") then
			return "legion_wrecks"
		end
		return "other"
	end

	return "other"
end

local function buildFeatureDefList()
	if featureDefListBuilt then
		return
	end
	featureDefListBuilt = true
	featureDefList = {}
	featureCategories = {}
	for _, cat in ipairs(CATEGORY_ORDER) do
		featureCategories[cat] = {}
	end
	for id, def in pairs(FeatureDefs) do
		local cat = classifyFeature(def.name, def)
		if cat then
			local entry = {
				name = def.name,
				id = id,
				category = cat,
			}
			featureDefList[#featureDefList + 1] = entry
			if not featureCategories[cat] then
				featureCategories[cat] = {}
			end
			local catList = featureCategories[cat]
			catList[#catList + 1] = entry
		end
	end
	table.sort(featureDefList, function(a, b)
		return a.name < b.name
	end)
	for _, cat in ipairs(CATEGORY_ORDER) do
		if featureCategories[cat] then
			table.sort(featureCategories[cat], function(a, b)
				return a.name < b.name
			end)
		end
	end
end

----------------------------------------------------------------
-- Grid overlay / snap helpers
----------------------------------------------------------------
local gridForceShowDefID
for id, def in pairs(UnitDefs) do
	if not def.modCategories or not def.modCategories.underwater then
		gridForceShowDefID = id
		break
	end
end

local function showBuildGrid()
	if gridShowing then
		return
	end
	local bg = WG.buildinggrid
	if bg and bg.setForceShow and gridForceShowDefID then
		bg.setForceShow("featureplacer", true, gridForceShowDefID)
		gridShowing = true
	end
end

local function hideBuildGrid()
	if not gridShowing then
		return
	end
	local bg = WG.buildinggrid
	if bg and bg.setForceShow then
		bg.setForceShow("featureplacer", false)
		gridShowing = false
	end
end

local function snapToGrid(x, z)
	return floor(x / gridSnapSize + 0.5) * gridSnapSize, floor(z / gridSnapSize + 0.5) * gridSnapSize
end

-- Full-map grid display list: terrain-following lines at gridSnapSize intervals.
-- Mirrors the implementation in cmd_terraform_brush.lua (extraState.buildFullMapGrid)
-- so that the FP DISPLAY "Grid" chip shows the same map-wide grid as TB's Display Grid,
-- not just the cursor-following Building Grid GL4 quad.
local function buildFullMapGrid()
	if gridDL then
		glDeleteList(gridDL)
		gridDL = nil
	end
	local gs = gridSnapSize
	local msx = Game.mapSizeX
	local msz = Game.mapSizeZ
	local BUMP = 3
	gridDL = glCreateList(function()
		glLineWidth(1)
		glColor(1, 1, 0.6, 0.20)
		glPolygonOffset(-2, -2)
		local z = 0
		while z <= msz do
			glBeginEnd(GL_LINE_STRIP, function()
				local x = 0
				while x <= msx do
					glVertex(x, GetGroundHeight(x, z) + BUMP, z)
					x = x + gs
				end
				if msx % gs ~= 0 then
					glVertex(msx, GetGroundHeight(msx, z) + BUMP, z)
				end
			end)
			z = z + gs
		end
		local x = 0
		while x <= msx do
			glBeginEnd(GL_LINE_STRIP, function()
				local zz = 0
				while zz <= msz do
					glVertex(x, GetGroundHeight(x, zz) + BUMP, zz)
					zz = zz + gs
				end
				if msz % gs ~= 0 then
					glVertex(x, GetGroundHeight(x, msz) + BUMP, msz)
				end
			end)
			x = x + gs
		end
		glPolygonOffset(0, 0)
		glColor(1, 1, 1, 1)
		glLineWidth(1)
	end)
	gridDLSize = gs
	gridDirty = false
end

local function ensureBuildGridLoaded()
	if WG.buildinggrid then
		return
	end
	-- Building Grid GL4 is disabled by default. Use SendCommands so the call
	-- works from any context (including RmlUi data-event-click handlers, where
	-- the dynamically-attached widgetHandler:EnableWidget can be nil).
	Spring.SendCommands("luaui enablewidget Building Grid GL4")
end

local function setGridOverlay(value)
	gridOverlay = value and true or false
	if gridOverlay then
		ensureBuildGridLoaded()
		gridDirty = true
	end
end

local function setGridSnap(value)
	gridSnap = value and true or false
	if gridSnap then
		ensureBuildGridLoaded()
	end
end

local function setGridSnapSize(value)
	gridSnapSize = max(16, min(128, floor(tonumber(value) or gridSnapSize)))
	gridDirty = true
end

----------------------------------------------------------------
-- World mouse position
----------------------------------------------------------------
local function getWorldMousePosition()
	local mx, my = GetMouseState()
	local _, pos = TraceScreenRay(mx, my, true)
	if pos then
		return pos[1], pos[3]
	end
	return nil, nil
end

----------------------------------------------------------------
-- Symmetry helper — delegates to terraform brush's symmetry system
----------------------------------------------------------------
local function getSymmetricPositions(wx, wz, rot)
	local tb = WG.TerraformBrush
	if tb and tb.getSymmetricPositions then
		return tb.getSymmetricPositions(wx, wz, rot or 0)
	end
	return { { x = wx, z = wz, rot = rot or 0 } }
end

----------------------------------------------------------------
-- Cadence → seconds between placements
----------------------------------------------------------------
local function getCadenceInterval()
	-- cadence 1-1000 (logarithmic slider): interval inversely proportional to rate
	return max(0.03, 2.0 / fp.cadence)
end

----------------------------------------------------------------
-- Brush layout: generate once, resolve per frame
----------------------------------------------------------------
-- The layout is brush-relative and cached, so the preview keeps its shape while
-- the cursor moves instead of reshuffling every frame. It is rebuilt only when a
-- brush parameter or the seed changes; the seed is rerolled after every stamp so
-- consecutive stamps do not come out identical.
local preview = {
	-- Clock-derived so two sessions do not open with the same scatter, then
	-- advanced by a fixed stride on every reroll. Kept well under 2^24.
	seed = floor(os.clock() * 1000) % 16777216,
	layout = nil,
	layoutKey = nil,
	ghosts = {},
	ghostCount = 0,
	warnedCap = false,
}

-- Seeds stay under 2^24 because Recoil builds Lua with LUA_NUMBER = float, so
-- integers above that are not exact -- see the RNG note in common/feature_scatter.lua.
local SEED_MAX = 16777216
local SEED_STRIDE = 8191

local function rerollPreview()
	-- Advance a counter rather than re-reading the clock: os.clock is coarse
	-- enough that two stamps in the same tick would land on the same seed and
	-- rubber-stamp an identical layout. The clock only seeds the very first one,
	-- so layouts differ between sessions too (widgets do not seed math.random,
	-- so that is not an option here).
	preview.seed = (preview.seed + SEED_STRIDE) % SEED_MAX
	preview.layoutKey = nil
end

local function layoutParams()
	return {
		shape = fp.shape,
		radius = fp.radius,
		rotation = fp.rotation,
		count = fp.featureCount,
		distribution = fp.distribution,
		rotRandom = fp.rotRandom,
		defNames = fp.selectedDefs,
		smartEnabled = fp.smartEnabled,
		smartFilters = fp.smartFilters,
	}
end

local function layoutKey(params)
	return table.concat({
		preview.seed,
		fp.mode or "",
		params.shape,
		params.radius,
		params.rotation,
		params.count,
		params.distribution,
		params.rotRandom,
		table.concat(params.defNames, ","),
	}, "\0")
end

local function ensureLayout(params)
	local key = layoutKey(params)
	if preview.layoutKey == key then
		return preview.layout
	end

	if #params.defNames == 0 then
		preview.layout = {}
	elseif fp.mode == "point" then
		-- One feature under the cursor. Generated here rather than through the
		-- scatter generators, which would offset it away from the crosshair.
		local rng = Scatter.newRng(preview.seed)
		local baseHeading = floor(params.rotation / 360 * 65536) % 65536
		local spread = floor(params.rotRandom / 100 * 32768)
		preview.layout = {
			{
				dx = 0,
				dz = 0,
				defName = params.defNames[rng:int(1, #params.defNames)],
				heading = (baseHeading + rng:int(-spread, spread)) % 65536,
			},
		}
	else
		preview.layout = Scatter.generateLocal(params, preview.seed)
	end

	preview.layoutKey = key
	return preview.layout
end

-- Every placement the brush would make right now, across all symmetry copies.
local function resolvePlacements(worldX, worldZ)
	local params = layoutParams()
	local layout = ensureLayout(params)
	if not layout or #layout == 0 then
		return {}
	end

	local placements = {}
	local positions = getSymmetricPositions(worldX, worldZ, fp.rotation)
	for i = 1, #positions do
		local p = positions[i]
		-- Each symmetry copy carries its own rotation, and the outline and the
		-- erase brush both already honour it. The layout was rotated once by the
		-- base rotation, so hand resolve() only the difference.
		local resolved = Scatter.resolve(layout, p.x, p.z, params, (p.rot or fp.rotation) - fp.rotation)
		for j = 1, #resolved do
			placements[#placements + 1] = resolved[j]
		end
	end
	return placements
end

----------------------------------------------------------------
-- Ghost preview
----------------------------------------------------------------
-- Heading and yaw run in OPPOSITE directions, so these conversions are not just
-- a unit change.
--
-- GetVectorFromHeading builds frontdir = (sin t, 0, cos t) with t = heading in
-- radians (System/SpringMath.cpp). A draw matrix carrying only yaw y has
-- frontdir = column 2 of the engine's Ry, which is (-sin y, 0, cos y). Equating
-- the two gives y = -t. Drop the sign and every previewed feature is mirrored
-- about the Z axis relative to the one that actually gets placed.
local HEADING_TO_RAD = 2 * pi / 65536

local function headingToYaw(heading)
	return -(heading or 0) * HEADING_TO_RAD
end

local function yawToHeading(yaw)
	return floor(-(yaw or 0) / HEADING_TO_RAD) % 65536
end

local function clearGhosts()
	if WG.StopDrawFeatureShapesGL4 and preview.ghostCount > 0 then
		WG.StopDrawFeatureShapesGL4(GHOST_OWNER)
	end
	for i = 1, preview.ghostCount do
		preview.ghosts[i] = nil
	end
	preview.ghostCount = 0
end

-- Reuses handles in place so a moving cursor updates instances rather than
-- churning the instance buffer.
local function syncGhosts(items)
	local draw = WG.DrawFeatureShapeGL4
	if not draw then
		return
	end

	-- The preview is redrawn every frame while the cursor moves, so a 500-feature
	-- brush under symmetry would be thousands of instances a frame for something
	-- the eye cannot read anyway. Placement is NOT capped -- only what is shown.
	local shown = #items
	if shown > PREVIEW_GHOST_CAP then
		shown = PREVIEW_GHOST_CAP
		if not preview.warnedCap then
			preview.warnedCap = true
			Echo(
				"[Feature Placer] Preview limited to "
					.. PREVIEW_GHOST_CAP
					.. " ghosts; all "
					.. #items
					.. " features are still placed on click"
			)
		end
	end

	local ghosts = preview.ghosts
	local n = 0
	for i = 1, shown do
		local item = items[i]
		local def = FeatureDefNames[item.defName]
		if def then
			local handle = draw(
				def.id,
				item.x,
				item.y,
				item.z,
				headingToYaw(item.heading),
				item.pitch or 0,
				item.roll or 0,
				item.alpha or GHOST_ALPHA,
				item.tintR or 1,
				item.tintG or 1,
				item.tintB or 1,
				item.tintAmount or 0,
				ghosts[n + 1],
				GHOST_OWNER
			)
			if handle then
				n = n + 1
				ghosts[n] = handle
			end
		end
	end

	for i = n + 1, preview.ghostCount do
		if WG.StopDrawFeatureShapeGL4 then
			WG.StopDrawFeatureShapeGL4(ghosts[i])
		end
		ghosts[i] = nil
	end
	preview.ghostCount = n
end

-- Remove mode has nothing to preview, so it highlights what the brush is about
-- to destroy instead: the features under it, tinted red.
local function collectRemovalTargets(worldX, worldZ)
	local items = {}
	local positions = getSymmetricPositions(worldX, worldZ, fp.rotation)
	for i = 1, #positions do
		local p = positions[i]
		local featureIDs = Spring.GetFeaturesInCylinder(p.x, p.z, fp.radius * 1.42)
		for j = 1, (featureIDs and #featureIDs or 0) do
			local fid = featureIDs[j]
			local fx, fy, fz = GetFeaturePosition(fid)
			if fx and BrushShapes.isInside(fx - p.x, fz - p.z, fp.radius, fp.shape, p.rot) then
				local defID = GetFeatureDefID(fid)
				local def = defID and FeatureDefs[defID]
				if def then
					local pitch, yaw, roll = Spring.GetFeatureRotation(fid)
					items[#items + 1] = {
						defName = def.name,
						x = fx,
						y = fy,
						z = fz,
						heading = (yaw or 0) / (2 * pi) * 65536,
						pitch = pitch or 0,
						roll = roll or 0,
						alpha = 0.7,
						tintR = 1,
						tintG = 0.15,
						tintB = 0.1,
						tintAmount = 0.75,
					}
				end
			end
		end
	end
	return items
end

----------------------------------------------------------------
-- Send messages to gadget
----------------------------------------------------------------
-- Stroke ids let the gadget fold every message of one user action into a single
-- undo entry. os.clock rather than math.random: widgets never seed math.random,
-- so it would hand out an identical sequence every session and merge unrelated
-- actions into one another's undo entries.
local strokeCounter = 0
local function nextStrokeID()
	strokeCounter = strokeCounter + 1
	-- Counter guarantees uniqueness within a session; the clock component only
	-- keeps a reloaded widget from reusing an id the gadget still has open. Both
	-- stay small because Lua numbers are floats here.
	return string.format("%d.%d", floor(os.clock() * 100) % 65536, strokeCounter)
end

local function sendPlacements(placements)
	if #placements == 0 then
		return
	end

	-- One stamp is one undo step no matter how many messages it takes.
	local strokeID = nextStrokeID()
	local batch = {}
	local function flush()
		if #batch > 0 then
			SendLuaRulesMsg(PLACELIST_HEADER .. strokeID .. "|" .. table.concat(batch, "|"))
			batch = {}
		end
	end

	for i = 1, #placements do
		local p = placements[i]
		local entry
		if p.pitch ~= 0 or p.roll ~= 0 or p.y ~= GetGroundHeight(p.x, p.z) then
			entry =
				string.format("%s %.1f %.1f %d %.4f %.4f %.1f", p.defName, p.x, p.z, p.heading, p.pitch, p.roll, p.y)
		else
			entry = string.format("%s %.1f %.1f %d", p.defName, p.x, p.z, p.heading)
		end
		batch[#batch + 1] = entry
		if #batch >= PLACE_BATCH then
			flush()
		end
	end
	flush()
end

local function placeAt(worldX, worldZ)
	if #fp.selectedDefs == 0 then
		return
	end
	sendPlacements(resolvePlacements(worldX, worldZ))
	-- Next stamp gets a fresh layout, or dragging would rubber-stamp one pattern.
	rerollPreview()
end

local function sendRemoveMessage(worldX, worldZ)
	local positions = getSymmetricPositions(worldX, worldZ, fp.rotation)
	for i = 1, #positions do
		local p = positions[i]
		local msg = REMOVE_HEADER
			.. floor(p.x)
			.. " "
			.. floor(p.z)
			.. " "
			.. fp.radius
			.. " "
			.. fp.shape
			.. " "
			.. p.rot
		SendLuaRulesMsg(msg)
	end
end

----------------------------------------------------------------
-- Selection and gizmo
----------------------------------------------------------------
-- Selection is only live on an "empty mouse": with nothing chosen in the asset
-- library there is nothing to place, so a click means "pick that one" instead.
-- The moment a library item is selected the tool goes back to placing and the
-- gizmo disappears.
local gz = {
	selection = {},
	selectedSet = {},
	base = {}, -- featureID -> transform snapshotted at drag start
	pivotBase = nil,
	hovered = nil,
	dragging = false,
	strokeID = nil,
	boxing = false,
	boxX1 = 0,
	boxY1 = 0,
	boxX2 = 0,
	boxY2 = 0,
	ghosts = {},
	ghostCount = 0,
	hidden = {},
	settleTargets = nil, -- transforms awaiting the sim before the real feature is shown again
	settleDeadline = 0,
}

local GIZMO_OWNER = "cmd_feature_placer_gizmo"
-- A drag never survives this long; without a deadline a dropped message would
-- leave features permanently invisible.
local SETTLE_TIMEOUT = 2.0
local SETTLE_EPSILON = 0.5
-- A press that moves less than this many pixels is a click, not a box select.
local BOX_MIN_PX = 4

-- Remove mode is excluded on purpose: an empty library is the normal way to use
-- the erase brush, so hijacking its left button for selection would break the
-- tool's whole point.
local function selectModeActive()
	return fp.active and (fp.mode == "scatter" or fp.mode == "point") and #fp.selectedDefs == 0
end

local function readFeatureTransform(featureID)
	local x, y, z = GetFeaturePosition(featureID)
	if not x then
		return nil
	end
	local pitch, yaw, roll = Spring.GetFeatureRotation(featureID)
	return { x = x, y = y, z = z, pitch = pitch or 0, yaw = yaw or 0, roll = roll or 0 }
end

-- How far a feature reaches from its own origin. Position is the model's base,
-- so a tall tree needs its height counted, not just its collision radius, or the
-- gizmo would sit around the trunk with the canopy hiding it.
local function featureReach(featureID)
	local defID = GetFeatureDefID(featureID)
	local def = defID and FeatureDefs[defID]
	if not def then
		return 16
	end
	local r = def.radius or 16
	local h = def.model and def.model.maxy or 0
	return (h > r) and h or r
end

local function recomputePivot()
	local n = #gz.selection
	if n == 0 then
		Gizmo.setPivot(nil)
		Gizmo.setObjectRadius(0)
		return
	end

	local sx, sy, sz, valid = 0, 0, 0, 0
	for i = 1, n do
		local t = readFeatureTransform(gz.selection[i])
		if t then
			sx, sy, sz = sx + t.x, sy + t.y, sz + t.z
			valid = valid + 1
		end
	end

	if valid == 0 then
		Gizmo.setPivot(nil)
		Gizmo.setObjectRadius(0)
		return
	end

	local px, py, pz = sx / valid, sy / valid, sz / valid
	Gizmo.setPivot(px, py, pz)

	-- Bounding radius of the whole selection about the pivot, so the handles sit
	-- outside the group rather than buried among its members. For a single
	-- feature this reduces to that feature's own reach.
	--
	-- The gizmo caps itself against the viewport (see gizmoScale), which is what
	-- keeps a huge group zoomed in from producing a gizmo thousands of pixels
	-- across.
	local reach = 0
	for i = 1, n do
		local featureID = gz.selection[i]
		local x, y, z = GetFeaturePosition(featureID)
		if x then
			local dx, dy, dz = x - px, y - py, z - pz
			local d = sqrt(dx * dx + dy * dy + dz * dz) + featureReach(featureID)
			if d > reach then
				reach = d
			end
		end
	end
	Gizmo.setObjectRadius(reach)
end

local function clearGizmoGhosts()
	if WG.StopDrawFeatureShapesGL4 and gz.ghostCount > 0 then
		WG.StopDrawFeatureShapesGL4(GIZMO_OWNER)
	end
	for i = 1, gz.ghostCount do
		gz.ghosts[i] = nil
	end
	gz.ghostCount = 0
end

local function showHiddenFeatures()
	for featureID in pairs(gz.hidden) do
		if Spring.ValidFeatureID(featureID) then
			Spring.SetFeatureNoDraw(featureID, false)
		end
	end
	gz.hidden = {}
end

local function clearSelection()
	gz.selection = {}
	gz.selectedSet = {}
	gz.base = {}
	gz.dragging = false
	Gizmo.setPivot(nil)
	Gizmo.setObjectRadius(0)
	Gizmo.endDrag()
	clearGizmoGhosts()
	showHiddenFeatures()
	gz.settleTargets = nil
end

local function setSelection(featureIDs)
	gz.selection = {}
	gz.selectedSet = {}
	for i = 1, #featureIDs do
		local featureID = featureIDs[i]
		if Spring.ValidFeatureID(featureID) and not gz.selectedSet[featureID] then
			gz.selectedSet[featureID] = true
			gz.selection[#gz.selection + 1] = featureID
		end
	end
	recomputePivot()
end

local function toggleSelection(featureID)
	if gz.selectedSet[featureID] then
		gz.selectedSet[featureID] = nil
		for i = 1, #gz.selection do
			if gz.selection[i] == featureID then
				table.remove(gz.selection, i)
				break
			end
		end
	else
		gz.selectedSet[featureID] = true
		gz.selection[#gz.selection + 1] = featureID
	end
	recomputePivot()
end

----------------------------------------------------------------
-- Orientation maths (Recoil convention)
----------------------------------------------------------------
-- The gizmo presents three WORLD-aligned rings, so a drag has to be composed as
-- a world-space rotation. Adding the drag angle to the matching euler component
-- does not do that, and is wrong in the ordinary case:
--
--   SetFeatureRotation composes M = Rx(pitch) * Ry(yaw) * Rz(roll). Only pitch
--   is applied last and is therefore a genuine world-X rotation. Roll is applied
--   FIRST, so it turns the model about its own local Z -- and once a feature has
--   a yaw (scatter gives every feature a random heading) that local Z has swung
--   away from world Z. At yaw 90 degrees it lies along world X, so the roll ring
--   does exactly what the pitch ring does.
--
-- So: rebuild the current matrix, pre-multiply the world delta, read the euler
-- triple back out. Matrices are Recoil's, not the right-handed GLSL ones -- see
-- the note in gfx_DrawFeatureShape_GL4.lua's vertex shader.
--
-- Row-major, m[row][col], acting on column vectors.
local function mat3Mul(a, b)
	local r = { {}, {}, {} }
	for i = 1, 3 do
		local ai = a[i]
		local ri = r[i]
		for j = 1, 3 do
			ri[j] = ai[1] * b[1][j] + ai[2] * b[2][j] + ai[3] * b[3][j]
		end
	end
	return r
end

local function rotX(a)
	local c, s = cos(a), sin(a)
	return { { 1, 0, 0 }, { 0, c, s }, { 0, -s, c } }
end

local function rotY(a)
	local c, s = cos(a), sin(a)
	return { { c, 0, -s }, { 0, 1, 0 }, { s, 0, c } }
end

local function rotZ(a)
	local c, s = cos(a), sin(a)
	return { { c, s, 0 }, { -s, c, 0 }, { 0, 0, 1 } }
end

local function matFromEuler(pitch, yaw, roll)
	return mat3Mul(rotX(pitch), mat3Mul(rotY(yaw), rotZ(roll)))
end

-- Inverse of matFromEuler. Same decomposition the engine's
-- CMatrix44f::GetEulerAnglesLftHand performs, including the gimbal-lock branch
-- at yaw = +/-90 degrees, which is a perfectly ordinary feature heading here.
local function eulerFromMat(m)
	local sy = -m[1][3]
	if sy > 1 then
		sy = 1
	elseif sy < -1 then
		sy = -1
	end
	local yaw = asin(sy)

	-- Both branches lose accuracy as cos(yaw) goes to zero, in opposite
	-- directions: the general one divides by it (error ~ eps/cos), the
	-- degenerate one assumes it is exactly zero (error ~ cos). They cross around
	-- cos(yaw) = sqrt(eps), so the best split is to take the general branch right
	-- up to the point where sin(yaw) stops being representably below 1. Measured
	-- over 60k samples biased hard toward gimbal lock: worst round-trip error
	-- 1.0e-8 at this threshold, versus 8.8e-3 at a "safe-looking" 0.99999.
	-- Exact +/-90 degrees still lands in the degenerate branch, since sin is
	-- exactly 1.0 there.
	if abs(m[1][3]) < 1.0 then
		return atan2(m[2][3], m[3][3]), yaw, atan2(m[1][2], m[1][1])
	end
	-- cos(yaw) == 0: pitch and roll act on the same axis and cannot be told
	-- apart. Pin roll and put the whole rotation in pitch.
	return atan2(-m[3][2], m[2][2]), yaw, 0
end

-- World-space rotation of `angle` about a cardinal axis.
local function worldRotation(axis, angle)
	if axis == 1 then
		return rotX(angle)
	elseif axis == 2 then
		return rotY(angle)
	end
	return rotZ(angle)
end

local function applyMat(m, x, y, z)
	return m[1][1] * x + m[1][2] * y + m[1][3] * z,
		m[2][1] * x + m[2][2] * y + m[2][3] * z,
		m[3][1] * x + m[3][2] * y + m[3][3] * z
end

-- Where every selected feature ends up for a given gizmo delta.
--
-- Exactly one ring drags at a time, so (dPitch, dYaw, dRoll) is really one
-- world-axis rotation: the non-zero component names both the axis and the angle.
-- That single delta matrix both spins each member and orbits it around the
-- pivot, so the two can never disagree.
local function computeDragTargets(dx, dy, dz, dPitch, dYaw, dRoll)
	local pivotBase = gz.pivotBase

	local delta = nil
	if dPitch ~= 0 then
		delta = worldRotation(1, dPitch)
	elseif dYaw ~= 0 then
		delta = worldRotation(2, dYaw)
	elseif dRoll ~= 0 then
		delta = worldRotation(3, dRoll)
	end

	local targets = {}
	for i = 1, #gz.selection do
		local featureID = gz.selection[i]
		local base = gz.base[featureID]
		if base then
			local ox, oy, oz = base.x - pivotBase.x, base.y - pivotBase.y, base.z - pivotBase.z
			local pitch, yaw, roll = base.pitch, base.yaw, base.roll

			if delta then
				ox, oy, oz = applyMat(delta, ox, oy, oz)
				pitch, yaw, roll = eulerFromMat(mat3Mul(delta, matFromEuler(base.pitch, base.yaw, base.roll)))
			end

			targets[#targets + 1] = {
				id = featureID,
				x = pivotBase.x + ox + dx,
				y = pivotBase.y + oy + dy,
				z = pivotBase.z + oz + dz,
				pitch = pitch,
				yaw = yaw,
				roll = roll,
			}
		end
	end
	return targets
end

local function syncGizmoGhosts(targets)
	local draw = WG.DrawFeatureShapeGL4
	if not draw then
		return
	end

	local n = 0
	for i = 1, #targets do
		local t = targets[i]
		local defID = GetFeatureDefID(t.id)
		if defID then
			local handle = draw(
				defID,
				t.x,
				t.y,
				t.z,
				t.yaw,
				t.pitch,
				t.roll,
				-- Not fully opaque: with depth writes off, a solid model shows
				-- its own back faces through the front ones.
				0.85,
				1,
				1,
				1,
				0,
				gz.ghosts[n + 1],
				GIZMO_OWNER
			)
			if handle then
				n = n + 1
				gz.ghosts[n] = handle
			end
		end
	end

	for i = n + 1, gz.ghostCount do
		if WG.StopDrawFeatureShapeGL4 then
			WG.StopDrawFeatureShapeGL4(gz.ghosts[i])
		end
		gz.ghosts[i] = nil
	end
	gz.ghostCount = n
end

local function beginGizmoDrag(handle, mx, my)
	if not Gizmo.beginDrag(handle, mx, my) then
		return false
	end

	local pivot = Gizmo.getPivot()
	gz.pivotBase = { x = pivot.x, y = pivot.y, z = pivot.z }
	gz.base = {}
	for i = 1, #gz.selection do
		local featureID = gz.selection[i]
		gz.base[featureID] = readFeatureTransform(featureID)
	end

	-- Hide the real features locally and show ghosts instead. The drag is then a
	-- pure client-side preview: nothing goes over the wire until the mouse comes
	-- up, so a slow drag costs no network traffic and no sim churn.
	for i = 1, #gz.selection do
		local featureID = gz.selection[i]
		if Spring.ValidFeatureID(featureID) then
			Spring.SetFeatureNoDraw(featureID, true)
			gz.hidden[featureID] = true
		end
	end

	gz.dragging = true
	gz.strokeID = nextStrokeID()

	local tb = WG.TerraformBrush
	local tbState = tb and tb.getState and tb.getState()
	Gizmo.setSnap({
		grid = gridSnap and gridSnapSize or nil,
		angleDeg = (tbState and tbState.angleSnap) and tbState.angleSnapStep or nil,
	})

	syncGizmoGhosts(computeDragTargets(0, 0, 0, 0, 0, 0))
	return true
end

local function updateGizmoDrag(mx, my)
	if not gz.dragging then
		return nil, false
	end
	local dx, dy, dz, dPitch, dYaw, dRoll = Gizmo.updateDrag(mx, my)
	local targets = computeDragTargets(dx, dy, dz, dPitch, dYaw, dRoll)
	syncGizmoGhosts(targets)
	Gizmo.setPivot(gz.pivotBase.x + dx, gz.pivotBase.y + dy, gz.pivotBase.z + dz)

	local moved = abs(dx) > 0.01
		or abs(dy) > 0.01
		or abs(dz) > 0.01
		or abs(dPitch) > 1e-4
		or abs(dYaw) > 1e-4
		or abs(dRoll) > 1e-4
	return targets, moved
end

local function sendTransforms(targets)
	if #targets == 0 then
		return
	end

	local batch = {}
	local function flush()
		if #batch > 0 then
			SendLuaRulesMsg(TRANSFORM_HEADER .. gz.strokeID .. "|" .. table.concat(batch, "|"))
			batch = {}
		end
	end

	for i = 1, #targets do
		local t = targets[i]
		batch[#batch + 1] =
			string.format("%d %.2f %.2f %.2f %.5f %.5f %.5f", t.id, t.x, t.y, t.z, t.pitch, t.yaw, t.roll)
		if #batch >= PLACE_BATCH then
			flush()
		end
	end
	flush()
end

local function endGizmoDrag(mx, my)
	if not gz.dragging then
		return
	end

	local targets, moved = updateGizmoDrag(mx, my)
	Gizmo.endDrag()
	gz.dragging = false

	-- A click that grabbed a handle without dragging it anywhere should not cost
	-- an undo entry.
	if not moved or not targets then
		showHiddenFeatures()
		clearGizmoGhosts()
		recomputePivot()
		return
	end

	sendTransforms(targets)

	-- Keep the ghosts up until the sim has actually moved the real features,
	-- otherwise they visibly snap back for the round-trip. Deadline guards
	-- against a message that never lands.
	gz.settleTargets = targets
	gz.settleDeadline = os.clock() + SETTLE_TIMEOUT
end

-- Swaps ghosts back out for the real features as the sim catches up.
local function tickSettle()
	if not gz.settleTargets then
		return
	end

	local remaining = {}
	for i = 1, #gz.settleTargets do
		local t = gz.settleTargets[i]
		local x, y, z = GetFeaturePosition(t.id)
		local settled = not Spring.ValidFeatureID(t.id)
			or (x and abs(x - t.x) < SETTLE_EPSILON and abs(y - t.y) < SETTLE_EPSILON and abs(z - t.z) < SETTLE_EPSILON)
		if settled then
			if gz.hidden[t.id] and Spring.ValidFeatureID(t.id) then
				Spring.SetFeatureNoDraw(t.id, false)
				gz.hidden[t.id] = nil
			end
		else
			remaining[#remaining + 1] = t
		end
	end

	if #remaining == 0 or os.clock() > gz.settleDeadline then
		showHiddenFeatures()
		clearGizmoGhosts()
		gz.settleTargets = nil
		recomputePivot()
		return
	end

	gz.settleTargets = remaining
	syncGizmoGhosts(remaining)
end

local function deleteSelection()
	if #gz.selection == 0 then
		return
	end

	local ids = {}
	for i = 1, #gz.selection do
		ids[#ids + 1] = tostring(gz.selection[i])
	end
	SendLuaRulesMsg(REMOVEIDS_HEADER .. table.concat(ids, "|"))
	clearSelection()
end

local function selectAllInBox(x1, y1, x2, y2)
	local featureIDs = Spring.GetFeaturesInScreenRectangle(x1, y1, x2, y2)
	setSelection(featureIDs or {})
end

----------------------------------------------------------------
-- Activation / Mode management
----------------------------------------------------------------
local function activate(mode)
	-- Deactivate terraform brush when feature placer activates
	if WG.TerraformBrush then
		WG.TerraformBrush.deactivate()
	end
	-- Deactivate weather brush when feature placer activates
	if WG.WeatherBrush then
		WG.WeatherBrush.deactivate()
	end
	fp.active = true
	fp.mode = mode
	buildFeatureDefList()
	local labels = { scatter = "SCATTER", point = "POINT", remove = "REMOVE" }
	Echo("[Feature Placer] Mode: " .. (labels[mode] or mode) .. " | LMB to place/remove, /featureplaceroff to stop")
	return true
end

local function deactivate()
	if fp.active then
		Echo("[Feature Placer] Deactivated")
	end
	fp.active = false
	fp.mode = nil
	fp.dragging = false
	fp.lockedWorldX = nil
	fp.lockedWorldZ = nil
	hideBuildGrid()
	clearGhosts()
	clearSelection()
	return true
end

local function setMode(mode)
	if mode == "scatter" or mode == "point" or mode == "remove" then
		-- Deactivate terraform brush when feature placer activates
		if not fp.active and WG.TerraformBrush then
			WG.TerraformBrush.deactivate()
		end
		-- Deactivate weather brush when feature placer activates
		if not fp.active and WG.WeatherBrush then
			WG.WeatherBrush.deactivate()
		end
		fp.mode = mode
		if not fp.active then
			fp.active = true
			buildFeatureDefList()
		end
	end
end

local function setShape(shape)
	if shape == "circle" or shape == "square" or shape == "hexagon" or shape == "octagon" or shape == "triangle" then
		fp.shape = shape
	end
end

local function setRadius(r)
	fp.radius = max(MIN_RADIUS, min(MAX_RADIUS, floor(r)))
end

local function setRotation(deg)
	fp.rotation = deg % 360
end

local function rotate(step)
	fp.rotation = (fp.rotation + step) % 360
end

local function setRotRandom(v)
	fp.rotRandom = max(0, min(100, floor(v)))
end

local function setFeatureCount(n)
	fp.featureCount = max(1, min(500, floor(n)))
end

local function setCadence(v)
	fp.cadence = max(1, min(1000, floor(v)))
end

local function setDistribution(mode)
	if mode == "random" or mode == "regular" or mode == "clustered" then
		fp.distribution = mode
	end
end

local function setSmartEnabled(val)
	fp.smartEnabled = val and true or false
end

local function setSmartFilter(key, val)
	if fp.smartFilters[key] ~= nil then
		fp.smartFilters[key] = val
	end
end

local function selectFeature(defName)
	fp.selectedDefs = { defName }
	fp.selectedSet = { [defName] = true }
end

local function toggleFeature(defName)
	if fp.selectedSet[defName] then
		fp.selectedSet[defName] = nil
		for i = #fp.selectedDefs, 1, -1 do
			if fp.selectedDefs[i] == defName then
				table.remove(fp.selectedDefs, i)
				break
			end
		end
	else
		fp.selectedSet[defName] = true
		fp.selectedDefs[#fp.selectedDefs + 1] = defName
	end
end

local function clearSelectedFeatures()
	fp.selectedDefs = {}
	fp.selectedSet = {}
end

local function featureUndo()
	SendLuaRulesMsg(UNDO_HEADER)
end

local function featureRedo()
	SendLuaRulesMsg(REDO_HEADER)
end

local function featureClearAll()
	SendLuaRulesMsg(CLEARALL_HEADER)
end

----------------------------------------------------------------
-- Save / Load feature map
----------------------------------------------------------------
local saveBuffer = {}
local saveExpectedCount = 0

-- One-shot feature-list read for other widgets. The Map Project save used to
-- walk Spring.GetAllFeatures() itself, but Spring.GetFeatureRotation called from
-- LuaUI reads transMatrix[0], which FeatureDrawerData only refreshes for
-- features that were actually drawn this frame -- so off-screen features
-- reported zero rotation and the saved file depended on where the camera was
-- pointing. The gadget runs synced, where the transform is always current.
local dataWaiter = nil
local dataWaiterTicks = 0
local DATA_WAITER_TIMEOUT = 300 -- Update ticks, ~10s

local function parseSavedEntries()
	local entries = {}
	for _, batchStr in ipairs(saveBuffer) do
		for chunk in batchStr:gmatch("[^|]+") do
			local parts = {}
			for word in chunk:gmatch("%S+") do
				parts[#parts + 1] = word
			end
			if parts[1] and parts[2] and parts[3] then
				entries[#entries + 1] = {
					name = parts[1],
					x = tonumber(parts[2]),
					z = tonumber(parts[3]),
					rot = tonumber(parts[4]) or 0,
					-- Present only for features the gizmo tilted or lifted; the
					-- gadget decides, comparing against the engine's own resting
					-- alignment rather than against zero.
					pitch = tonumber(parts[5]),
					roll = tonumber(parts[6]),
					y = tonumber(parts[7]),
				}
			end
		end
	end
	return entries
end

---@param callback function receives (entries) or (nil, errorMessage)
---@return boolean started
local function requestFeatureData(callback)
	if type(callback) ~= "function" then
		return false
	end
	if dataWaiter then
		callback(nil, "a feature export is already pending")
		return false
	end
	if not Spring.IsCheatingEnabled() then
		callback(nil, "feature export requires /cheat")
		return false
	end
	saveBuffer = {}
	dataWaiter = callback
	dataWaiterTicks = 0
	SendLuaRulesMsg(SAVE_HEADER)
	return true
end

local function handleSaveBegin(count)
	saveBuffer = {}
	saveExpectedCount = count or 0
end

local function handleSaveData(dataStr)
	if not dataStr then
		return
	end
	saveBuffer[#saveBuffer + 1] = dataStr
end

local function handleSaveEnd(count)
	-- A pending data request consumes the export instead of writing a file.
	if dataWaiter then
		local cb = dataWaiter
		dataWaiter = nil
		local entries = parseSavedEntries()
		saveBuffer = {}
		cb(entries)
		return
	end

	Spring.CreateDir(SAVE_DIR)
	local mapName = Game.mapName or "unknown"
	local timestamp = os.date("%Y%m%d_%H%M%S")
	local filename = SAVE_DIR .. mapName .. "_features_" .. timestamp .. ".lua"

	local file = io.open(filename, "w")
	if not file then
		Echo("[Feature Placer] Failed to open " .. filename .. " for writing")
		return
	end

	-- FeaturePlacer setcfg format: unitlist / buildinglist / objectlist with `rot`,
	-- consumed out-of-the-box by the map-side feature placer gadget.
	file:write("----------------------------------------------------------\n")
	file:write("-- Feature map: " .. mapName .. "\n")
	file:write("-- Saved: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
	file:write("-- Features: " .. tostring(count or 0) .. "\n")
	file:write("local setcfg = {\n")
	file:write("\tunitlist = {\n\t},\n")
	file:write("\tbuildinglist = {\n\t},\n")
	file:write("\tobjectlist = {\n")

	for _, batchStr in ipairs(saveBuffer) do
		for entry in batchStr:gmatch("[^|]+") do
			local parts = {}
			for word in entry:gmatch("%S+") do
				parts[#parts + 1] = word
			end
			local defName = parts[1]
			local x = parts[2]
			local z = parts[3]
			local rot = parts[4] or "0" -- engine heading, written as rot
			if defName and x and z then
				-- pitch/roll/y only appear for features the gizmo tilted or
				-- lifted, so a map that was never gizmo-edited writes exactly
				-- the same bytes it always did.
				if parts[5] and parts[6] and parts[7] then
					file:write(
						string.format(
							"\t{ name = %q, x = %s, z = %s, rot = %s, pitch = %s, roll = %s, y = %s },\n",
							defName,
							x,
							z,
							rot,
							parts[5],
							parts[6],
							parts[7]
						)
					)
				else
					file:write(string.format("\t{ name = %q, x = %s, z = %s, rot = %s },\n", defName, x, z, rot))
				end
			end
		end
	end

	file:write("\t},\n")
	file:write("}\n")
	file:write("return setcfg\n")
	file:close()

	saveBuffer = {}
	Echo("[Feature Placer] Saved " .. tostring(count or 0) .. " features to " .. filename)
end

local function featureSave()
	SendLuaRulesMsg(SAVE_HEADER)
end

local function featureLoad(filename)
	if not filename or filename == "" then
		Echo("[Feature Placer] No filename specified")
		return
	end

	-- VFS.DirList returns absolute paths that io.open can't always reopen on
	-- Windows when the path contains spaces; VFS.LoadFile with VFS.RAW handles
	-- both absolute and relative write-dir paths consistently.
	local content = VFS.LoadFile(filename, VFS.RAW)
	if not content then
		local file = io.open(filename, "r")
		if file then
			content = file:read("*a")
			file:close()
		end
	end
	if not content then
		Echo("[Feature Placer] Cannot open " .. filename)
		return
	end

	local fn, err = loadstring(content)
	if not fn then
		Echo("[Feature Placer] Parse error: " .. tostring(err))
		return
	end

	local ok, data = pcall(fn)
	if not ok or type(data) ~= "table" then
		Echo("[Feature Placer] Invalid feature map file")
		return
	end

	-- Accept the setcfg/objectlist format (map-gadget compatible, `rot`) as well as
	-- the legacy flat array of {name, x, z, heading}.
	local list = data.objectlist or data

	-- Send features to gadget in batches, all under one stroke id so replaying a
	-- whole saved map is a single undo step rather than #features/40 of them.
	local strokeID = nextStrokeID()
	local count = #list
	for i = 1, count, PLACE_BATCH do
		local batch = {}
		for j = i, min(i + PLACE_BATCH - 1, count) do
			local f = list[j]
			if f.name and f.x and f.z then
				-- `rot` (setcfg) or `heading` (legacy); "random"/non-numeric → random heading
				local rot = f.rot or f.heading or 0
				if type(rot) ~= "number" then
					rot = math.random(-32768, 32767)
				end
				local entry = f.name .. " " .. floor(f.x) .. " " .. floor(f.z) .. " " .. floor(rot)
				-- Optional gizmo transform. Files written before the gizmo
				-- existed simply have none of these and load as they always did.
				if f.pitch or f.roll or f.y then
					entry = entry .. string.format(" %.4f %.4f", tonumber(f.pitch) or 0, tonumber(f.roll) or 0)
					if f.y then
						entry = entry .. string.format(" %.1f", tonumber(f.y))
					end
				end
				batch[#batch + 1] = entry
			end
		end
		if #batch > 0 then
			SendLuaRulesMsg(LOAD_HEADER .. strokeID .. "|" .. table.concat(batch, "|"))
		end
	end

	Echo("[Feature Placer] Loading " .. count .. " features from " .. filename)
end

local function listSavedFeatureMaps()
	local files = VFS.DirList(SAVE_DIR, "*.lua", VFS.RAW)
	return files or {}
end

local function getState()
	return {
		active = fp.active,
		mode = fp.mode,
		shape = fp.shape,
		radius = fp.radius,
		rotation = fp.rotation,
		rotRandom = fp.rotRandom,
		featureCount = fp.featureCount,
		cadence = fp.cadence,
		distribution = fp.distribution,
		smartEnabled = fp.smartEnabled,
		smartFilters = fp.smartFilters,
		selectedDefs = fp.selectedDefs,
		selectedSet = fp.selectedSet,
		undoCount = fp.undoCount,
		redoCount = fp.redoCount,
		gridOverlay = gridOverlay,
		gridSnap = gridSnap,
		gridSnapSize = gridSnapSize,
		-- Gizmo selection. selectMode tells the panel whether clicking the map
		-- picks features or places them.
		selectMode = selectModeActive(),
		selectionCount = #gz.selection,
		gizmoDragging = gz.dragging,
	}
end

local function getFeatureDefList()
	buildFeatureDefList()
	return featureDefList
end

local function getFeatureCategories()
	buildFeatureDefList()
	return featureCategories
end

local function getCategoryOrder()
	return CATEGORY_ORDER
end

local function getCategoryLabels()
	return CATEGORY_LABELS
end

----------------------------------------------------------------
-- History callback from gadget
----------------------------------------------------------------
local function handleHistoryUpdate(undoCount, redoCount)
	fp.undoCount = undoCount or 0
	fp.redoCount = redoCount or 0
end

----------------------------------------------------------------
-- Drawing helpers
----------------------------------------------------------------
local function rotatePoint(px, pz, angleDeg)
	local rad = angleDeg * pi / 180
	return px * cos(rad) - pz * sin(rad), px * sin(rad) + pz * cos(rad)
end

local function drawRegularPolygon(cx, cz, radius, angleDeg, numSides)
	local angleStep = 2 * pi / numSides
	local offsetRad = angleDeg * pi / 180
	glBeginEnd(GL.LINE_LOOP, function()
		for i = 0, numSides - 1 do
			local a = i * angleStep + offsetRad
			local x = cx + radius * cos(a)
			local z = cz + radius * sin(a)
			local y = GetGroundHeight(x, z) + 4
			glVertex(x, y, z)
		end
	end)
end

local function drawRotatedSquare(cx, cz, radius, angleDeg)
	local corners = {
		{ -radius, -radius },
		{ radius, -radius },
		{ radius, radius },
		{ -radius, radius },
	}
	glBeginEnd(GL.LINE_LOOP, function()
		for i = 1, 4 do
			local rx, rz = rotatePoint(corners[i][1], corners[i][2], angleDeg)
			local wx, wz = cx + rx, cz + rz
			local wy = GetGroundHeight(wx, wz)
			glVertex(wx, wy + 4, wz)
		end
	end)
end

----------------------------------------------------------------
-- Smart filter visualization helpers
----------------------------------------------------------------
local GRID_STEP = 24 -- elmos between sample points

-- Check if a point passes the current smart filter constraints
local function isPointValid(px, pz, sf)
	local h = GetGroundHeight(px, pz)
	if sf.avoidWater and h < 0 then
		return false
	end
	if sf.avoidCliffs or sf.preferSlopes then
		local _, ny = GetGroundNormal(px, pz)
		ny = ny or 1.0
		if sf.avoidCliffs then
			local nyMin = cos(sf.slopeMax * pi / 180)
			if ny < nyMin then
				return false
			end
		end
		if sf.preferSlopes then
			local nyMax = cos(sf.slopeMin * pi / 180)
			if ny > nyMax then
				return false
			end
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

-- Check if a local-space point is inside the brush shape
local function isInsideBrush(lx, lz, radius, shape)
	if shape == "circle" then
		return (lx * lx + lz * lz) <= radius * radius
	elseif shape == "square" then
		return math.abs(lx) <= radius and math.abs(lz) <= radius
	elseif shape == "hexagon" then
		local ax, az = math.abs(lx), math.abs(lz)
		local apothem = radius * cos(pi / 6)
		if az > apothem then
			return false
		end
		if ax > radius then
			return false
		end
		return ax * cos(pi / 6) + az * sin(pi / 6) <= apothem
	elseif shape == "octagon" then
		local ax, az = math.abs(lx), math.abs(lz)
		local cut = radius * sin(pi / 8)
		local side = radius * cos(pi / 8)
		if ax > side or az > side then
			return false
		end
		return (ax + az) <= (side + cut)
	elseif shape == "triangle" then
		local dist = sqrt(lx * lx + lz * lz)
		if dist < 0.001 then
			return true
		end
		local angle = math.atan2(lz, lx)
		if angle < 0 then
			angle = angle + 2 * pi
		end
		local sectorAngle = 2 * pi / 3
		local angleInSector = (angle % sectorAngle) - sectorAngle / 2
		local apothem = radius * cos(pi / 3)
		local edgeDist = apothem / cos(angleInSector)
		return dist <= edgeDist
	end
	return true
end

-- Draw colored terrain-following quads showing valid (green) vs rejected (red) areas
local function drawSmartFilterOverlay(cx, cz, radius, shape, angleDeg, sf)
	local step = GRID_STEP
	local halfStep = step * 0.3
	local rad = angleDeg * pi / 180
	local cosR, sinR = cos(rad), sin(rad)

	glDepthTest(true)
	glBeginEnd(GL_TRIANGLES, function()
		for lx = -radius, radius, step do
			for lz = -radius, radius, step do
				if isInsideBrush(lx, lz, radius, shape) then
					local wx = cx + lx * cosR - lz * sinR
					local wz = cz + lx * sinR + lz * cosR
					local valid = isPointValid(wx, wz, sf)

					if valid then
						glColor(0.2, 0.85, 0.3, 0.08)
					else
						glColor(0.9, 0.15, 0.15, 0.14)
					end

					local x0 = wx - halfStep
					local x1 = wx + halfStep
					local z0 = wz - halfStep
					local z1 = wz + halfStep
					local y00 = GetGroundHeight(x0, z0) + 3
					local y10 = GetGroundHeight(x1, z0) + 3
					local y01 = GetGroundHeight(x0, z1) + 3
					local y11 = GetGroundHeight(x1, z1) + 3

					glVertex(x0, y00, z0)
					glVertex(x1, y10, z0)
					glVertex(x1, y11, z1)

					glVertex(x0, y00, z0)
					glVertex(x1, y11, z1)
					glVertex(x0, y01, z1)
				end
			end
		end
	end)
	glDepthTest(false)
end

-- Get shape corner points for altitude cap prism drawing
local function getShapeCorners(shape, radius, angleDeg)
	local corners = {}
	local rad = angleDeg * pi / 180
	if shape == "circle" then
		for i = 0, 15 do
			local a = i * (2 * pi / 16) + rad
			corners[#corners + 1] = { radius * cos(a), radius * sin(a) }
		end
	elseif shape == "square" then
		local pts = { { -radius, -radius }, { radius, -radius }, { radius, radius }, { -radius, radius } }
		for _, p in ipairs(pts) do
			local rx = p[1] * cos(rad) - p[2] * sin(rad)
			local rz = p[1] * sin(rad) + p[2] * cos(rad)
			corners[#corners + 1] = { rx, rz }
		end
	elseif shape == "hexagon" then
		for i = 0, 5 do
			local a = i * (2 * pi / 6) + rad
			corners[#corners + 1] = { radius * cos(a), radius * sin(a) }
		end
	elseif shape == "octagon" then
		for i = 0, 7 do
			local a = i * (2 * pi / 8) + rad
			corners[#corners + 1] = { radius * cos(a), radius * sin(a) }
		end
	end
	return corners
end

-- Draw altitude cap prism (orange for max, cyan for min, white struts)
local function drawAltitudeCapPrism(cx, cz, radius, shape, angleDeg, sf)
	if not sf.altMinEnable and not sf.altMaxEnable then
		return
	end

	local corners = getShapeCorners(shape, radius, angleDeg)
	if #corners == 0 then
		return
	end

	local botY = sf.altMinEnable and sf.altMin or nil
	local topY = sf.altMaxEnable and sf.altMax or nil

	glDepthTest(true)
	glLineWidth(1.5)

	if topY then
		glColor(1.0, 0.6, 0.1, 0.55)
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 1, #corners do
				glVertex(cx + corners[i][1], topY, cz + corners[i][2])
			end
		end)
	end

	if botY then
		glColor(0.1, 0.6, 1.0, 0.55)
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 1, #corners do
				glVertex(cx + corners[i][1], botY, cz + corners[i][2])
			end
		end)
	end

	local stride = max(1, floor(#corners / 8))
	local strutBot = botY or (topY and topY - 100) or 0
	local strutTop = topY or (botY and botY + 100) or 0
	glColor(1, 1, 1, 0.2)
	glBeginEnd(GL_LINES, function()
		for i = 1, #corners, stride do
			local wx = cx + corners[i][1]
			local wz = cz + corners[i][2]
			glVertex(wx, strutBot, wz)
			glVertex(wx, strutTop, wz)
		end
	end)

	glLineWidth(1)
	glDepthTest(false)
end

----------------------------------------------------------------
-- Keybinds
----------------------------------------------------------------
function widget:KeyPress(key, mods, isRepeat)
	if not fp.active then
		return false
	end

	if key == 0x1B then -- Escape
		-- First Escape drops the selection, second leaves the tool. Deactivating
		-- out from under an active selection loses work with no way back.
		if #gz.selection > 0 then
			clearSelection()
		else
			deactivate()
		end
		return true
	end

	-- Delete / Backspace removes the gizmo selection. The right mouse button
	-- keeps its brush-erase meaning in every mode, as it does in the other tools.
	if (key == 0x7F or key == 0x08) and #gz.selection > 0 then
		deleteSelection()
		return true
	end

	-- Ctrl+A selects everything the camera can see.
	if mods.ctrl and key == 97 and selectModeActive() then -- a
		local vsx, vsy = Spring.GetViewGeometry()
		selectAllInBox(0, 0, vsx, vsy)
		return true
	end

	-- Ctrl+Z / Ctrl+Shift+Z for undo/redo
	if mods.ctrl and key == 122 then -- z
		if mods.shift then
			featureRedo()
		else
			featureUndo()
		end
		return true
	end

	return false
end

----------------------------------------------------------------
-- Mouse
----------------------------------------------------------------
function widget:IsAbove(x, y)
	return false
end

function widget:MousePress(mx, my, button)
	if not fp.active or not fp.mode then
		return false
	end

	-- Defer to measure / symmetry origin tools when active
	local tb = WG.TerraformBrush
	if tb and tb.getState then
		local st = tb.getState()
		if st and st.measureActive then
			return false
		end
		if st and st.heightSamplingMode then
			return false
		end
		if st and st.symmetryActive then
			if st.symmetryPlacingOrigin or st.symmetryHoveringOrigin or st.symmetryDraggingOrigin then
				return false
			end
		end
	end
	if tb and tb.getHeightSamplingMode and tb.getHeightSamplingMode() then
		return false
	end

	-- Empty mouse: nothing is selected in the library, so the left button
	-- manipulates what is already on the map instead of placing more.
	if button == 1 and selectModeActive() then
		if #gz.selection > 0 then
			local handle = Gizmo.hitTest(mx, my)
			if handle and beginGizmoDrag(handle, mx, my) then
				return true
			end
		end

		local traceType, traceID = TraceScreenRay(mx, my)
		if traceType == "feature" then
			local _, _, _, shift = GetModKeyState()
			if shift then
				toggleSelection(traceID)
			else
				setSelection({ traceID })
			end
			return true
		end

		-- Empty ground: start a box select. Whether this was a box or just a
		-- click that clears the selection is decided on release.
		gz.boxing = true
		gz.boxX1, gz.boxY1 = mx, my
		gz.boxX2, gz.boxY2 = mx, my
		return true
	end

	if button == 1 then
		local worldX, worldZ = getWorldMousePosition()
		if not worldX then
			return false
		end
		if gridSnap then
			worldX, worldZ = snapToGrid(worldX, worldZ)
		end

		fp.dragging = true
		fp.dragAction = "place"
		fp.lockedWorldX = worldX
		fp.lockedWorldZ = worldZ
		fp.placeTimer = 0

		-- Perform initial placement
		if fp.mode == "remove" then
			sendRemoveMessage(worldX, worldZ)
		else
			placeAt(worldX, worldZ)
		end

		return true
	end

	-- Right-click removes features regardless of current mode
	if button == 3 then
		local worldX, worldZ = getWorldMousePosition()
		if not worldX then
			return false
		end
		if gridSnap then
			worldX, worldZ = snapToGrid(worldX, worldZ)
		end

		fp.dragging = true
		fp.dragAction = "remove"
		fp.lockedWorldX = worldX
		fp.lockedWorldZ = worldZ
		fp.placeTimer = 0

		sendRemoveMessage(worldX, worldZ)
		return true
	end

	return false
end

function widget:MouseMove(mx, my, dx, dy, button)
	if gz.dragging then
		updateGizmoDrag(mx, my)
		return true
	end
	if gz.boxing then
		gz.boxX2, gz.boxY2 = mx, my
		return true
	end
	return false
end

function widget:MouseRelease(mx, my, button)
	if button == 1 and gz.dragging then
		endGizmoDrag(mx, my)
		return true
	end

	if button == 1 and gz.boxing then
		gz.boxing = false
		gz.boxX2, gz.boxY2 = mx, my
		if abs(gz.boxX2 - gz.boxX1) >= BOX_MIN_PX or abs(gz.boxY2 - gz.boxY1) >= BOX_MIN_PX then
			selectAllInBox(gz.boxX1, gz.boxY1, gz.boxX2, gz.boxY2)
		else
			-- A click on empty ground, not a drag: deselect.
			clearSelection()
		end
		return true
	end

	if (button == 1 or button == 3) and fp.dragging then
		fp.dragging = false
		fp.dragAction = nil
		fp.lockedWorldX = nil
		fp.lockedWorldZ = nil
		return true
	end
	return false
end

function widget:MouseWheel(up, value)
	if not fp.active then
		return false
	end

	local alt, ctrl, _, shift = GetModKeyState()

	if alt then
		-- Alt+Scroll = rotate brush (snap to TB protractor step when angleSnap on)
		local step = ROTATION_STEP
		local tb = WG.TerraformBrush
		local tbs = tb and tb.getState and tb.getState() or nil
		if tbs and tbs.angleSnap and (tbs.angleSnapStep or 0) > 0 then
			step = tbs.angleSnapStep
		end
		local dir = up and 1 or -1
		fp.rotation = ((fp.rotation + dir * step) % 360 + 360) % 360
		Echo("[Feature Placer] Rotation: " .. fp.rotation .. "°")
		return true
	end

	if shift then
		-- Shift+Scroll = feature count
		local step = up and 1 or -1
		setFeatureCount(fp.featureCount + step)
		Echo("[Feature Placer] Count: " .. fp.featureCount)
		return true
	end

	local spaceHeld = GetKeyState(KEYSYMS_SPACE)
	if spaceHeld then
		-- Space+Scroll = cadence (logarithmic)
		if up then
			local newC = fp.cadence * 1.15
			if newC < fp.cadence + 1 then
				newC = fp.cadence + 1
			end
			setCadence(newC)
		else
			local newC = fp.cadence / 1.15
			if newC > fp.cadence - 1 then
				newC = fp.cadence - 1
			end
			setCadence(newC)
		end
		Echo("[Feature Placer] Cadence: " .. fp.cadence)
		return true
	end

	if ctrl then
		-- Ctrl+Scroll = resize
		local step = up and RADIUS_STEP or -RADIUS_STEP
		setRadius(fp.radius + step)
		Echo("[Feature Placer] Radius: " .. fp.radius)
		return true
	end

	return false
end

----------------------------------------------------------------
-- Update loop
----------------------------------------------------------------
function widget:Update(dt)
	if not fp.active then
		return
	end

	-- Selection survives a mode switch but not a library pick: choosing something
	-- to place means the tool is placing again, and a stale gizmo would sit there
	-- catching clicks meant for the brush.
	if #fp.selectedDefs > 0 and #gz.selection > 0 then
		clearSelection()
	end

	-- A refused or lost export must not wedge every later request.
	if dataWaiter then
		dataWaiterTicks = dataWaiterTicks + 1
		if dataWaiterTicks > DATA_WAITER_TIMEOUT then
			local cb = dataWaiter
			dataWaiter = nil
			cb(nil, "feature export timed out")
		end
	end

	tickSettle()

	if selectModeActive() and not gz.dragging and #gz.selection > 0 then
		local mx, my = GetMouseState()
		gz.hovered = Gizmo.hitTest(mx, my)
	else
		gz.hovered = nil
	end

	-- MouseMove only fires while a button is down in some camera modes; poll the
	-- release too so a drag cannot get stuck if the release event is swallowed.
	if gz.dragging then
		local mx, my, leftPressed = GetMouseState()
		if leftPressed then
			updateGizmoDrag(mx, my)
		else
			endGizmoDrag(mx, my)
		end
		return
	end

	if not fp.dragging then
		return
	end

	local mx, my, leftPressed, _, rightPressed = GetMouseState()
	local buttonHeld = (fp.dragAction == "remove" and rightPressed) or (fp.dragAction == "place" and leftPressed)
	if not buttonHeld then
		fp.dragging = false
		fp.dragAction = nil
		fp.lockedWorldX = nil
		fp.lockedWorldZ = nil
		return
	end

	-- Accumulate real time and check cadence interval
	fp.placeTimer = (fp.placeTimer or 0) + dt
	local interval = getCadenceInterval()
	if fp.placeTimer < interval then
		return
	end
	fp.placeTimer = fp.placeTimer - interval

	local worldX, worldZ = getWorldMousePosition()
	if not worldX then
		return
	end
	if gridSnap then
		worldX, worldZ = snapToGrid(worldX, worldZ)
	end

	fp.lockedWorldX = worldX
	fp.lockedWorldZ = worldZ

	if fp.dragAction == "remove" or fp.mode == "remove" then
		sendRemoveMessage(worldX, worldZ)
	else
		placeAt(worldX, worldZ)
	end
end

----------------------------------------------------------------
-- Selection markers
----------------------------------------------------------------
-- A ring on the ground under each selected feature, sized from the feature's own
-- collision radius. Deliberately not a tinted model ghost: that would draw the
-- model a second time on top of itself and read as a rendering fault.
local function drawSelectionMarkers()
	glDepthTest(false)
	glLineWidth(2)
	glColor(1.0, 0.85, 0.25, 0.85)

	for i = 1, #gz.selection do
		local featureID = gz.selection[i]
		local x, _, z = GetFeaturePosition(featureID)
		if x then
			local defID = GetFeatureDefID(featureID)
			local def = defID and FeatureDefs[defID]
			local r = (def and def.radius or 16) * 1.1
			drawRegularPolygon(x, z, r, 0, 20)
		end
	end

	glLineWidth(1)
end

----------------------------------------------------------------
-- DrawWorld — brush outline
----------------------------------------------------------------
function widget:DrawWorld()
	-- Full-map grid overlay: visible across the whole map regardless of brush active state
	-- (mirrors cmd_terraform_brush.lua DISPLAY Grid behavior).
	if gridOverlay then
		if (not gridDL) or gridDLSize ~= gridSnapSize or gridDirty then
			buildFullMapGrid()
		end
		if gridDL then
			glCallList(gridDL)
		end
	end

	if not fp.active or not fp.mode then
		hideBuildGrid()
		clearGhosts()
		return
	end

	-- Selection rings and the gizmo sit on top of everything else this tool
	-- draws, and stay up while the brush outline is hidden behind the panel.
	if #gz.selection > 0 then
		drawSelectionMarkers()
		Gizmo.draw(gz.hovered)
	end

	local worldX, worldZ = getWorldMousePosition()
	do
		local tb = WG.TerraformBrush
		if tb and tb.animateUnmouse then
			worldX, worldZ = tb.animateUnmouse("featurePlacer", worldX, worldZ, fp.radius, 1.0)
		elseif tb and tb.getUnmouseTarget and not worldX then
			worldX, worldZ = tb.getUnmouseTarget(fp.radius, 1.0)
		end
	end
	if not worldX then
		clearGhosts()
		return
	end

	-- Grid snap + visual
	if gridSnap then
		worldX, worldZ = snapToGrid(worldX, worldZ)
		showBuildGrid()
	elseif gridOverlay then
		showBuildGrid()
	else
		hideBuildGrid()
	end

	-- WYSIWYG: the exact features about to be placed, at their exact positions
	-- and orientations. Remove mode has nothing to place, so it tints what the
	-- brush would destroy instead.
	if fp.mode == "remove" or (fp.dragging and fp.dragAction == "remove") then
		syncGhosts(collectRemovalTargets(worldX, worldZ))
	else
		syncGhosts(resolvePlacements(worldX, worldZ))
	end

	-- Color by mode (red when right-dragging to remove)
	local _, _, _, _, rightPressed = GetMouseState()
	if fp.dragging and fp.dragAction == "remove" then
		glColor(0.9, 0.2, 0.2, 0.7)
	elseif fp.mode == "scatter" then
		glColor(0.2, 0.8, 0.4, 0.7)
	elseif fp.mode == "point" then
		glColor(0.4, 0.7, 1.0, 0.7)
	elseif fp.mode == "remove" then
		glColor(0.9, 0.2, 0.2, 0.7)
	end

	glLineWidth(2)

	if fp.mode == "point" and not (fp.dragging and fp.dragAction == "remove") then
		-- Draw small crosshair for point mode
		local cy = GetGroundHeight(worldX, worldZ) + 4
		local s = 12
		glBeginEnd(GL.LINES, function()
			glVertex(worldX - s, cy, worldZ)
			glVertex(worldX + s, cy, worldZ)
			glVertex(worldX, cy, worldZ - s)
			glVertex(worldX, cy, worldZ + s)
		end)
	else
		-- Draw brush shape
		if fp.shape == "circle" then
			drawRegularPolygon(worldX, worldZ, fp.radius, fp.rotation, CIRCLE_SEGMENTS)
		elseif fp.shape == "square" then
			drawRotatedSquare(worldX, worldZ, fp.radius, fp.rotation)
		elseif fp.shape == "hexagon" then
			drawRegularPolygon(worldX, worldZ, fp.radius, fp.rotation, 6)
		elseif fp.shape == "octagon" then
			drawRegularPolygon(worldX, worldZ, fp.radius, fp.rotation, 8)
		elseif fp.shape == "triangle" then
			drawRegularPolygon(worldX, worldZ, fp.radius, fp.rotation, 3)
		end

		-- Smart filter overlay: show valid/rejected terrain areas
		if fp.smartEnabled then
			drawSmartFilterOverlay(worldX, worldZ, fp.radius, fp.shape, fp.rotation, fp.smartFilters)
			drawAltitudeCapPrism(worldX, worldZ, fp.radius, fp.shape, fp.rotation, fp.smartFilters)
		end
	end

	-- Symmetry ghost cursors
	local positions = getSymmetricPositions(worldX, worldZ, fp.rotation)
	if #positions > 1 then
		for i = 2, #positions do
			local p = positions[i]
			if fp.dragging and fp.dragAction == "remove" then
				glColor(0.9, 0.2, 0.2, 0.3)
			elseif fp.mode == "scatter" then
				glColor(0.2, 0.8, 0.4, 0.3)
			elseif fp.mode == "point" then
				glColor(0.4, 0.7, 1.0, 0.3)
			elseif fp.mode == "remove" then
				glColor(0.9, 0.2, 0.2, 0.3)
			end

			if fp.mode == "point" and not (fp.dragging and fp.dragAction == "remove") then
				local cy = GetGroundHeight(p.x, p.z) + 4
				local s = 12
				glBeginEnd(GL.LINES, function()
					glVertex(p.x - s, cy, p.z)
					glVertex(p.x + s, cy, p.z)
					glVertex(p.x, cy, p.z - s)
					glVertex(p.x, cy, p.z + s)
				end)
			else
				if fp.shape == "circle" then
					drawRegularPolygon(p.x, p.z, fp.radius, p.rot, CIRCLE_SEGMENTS)
				elseif fp.shape == "square" then
					drawRotatedSquare(p.x, p.z, fp.radius, p.rot)
				elseif fp.shape == "hexagon" then
					drawRegularPolygon(p.x, p.z, fp.radius, p.rot, 6)
				elseif fp.shape == "octagon" then
					drawRegularPolygon(p.x, p.z, fp.radius, p.rot, 8)
				elseif fp.shape == "triangle" then
					drawRegularPolygon(p.x, p.z, fp.radius, p.rot, 3)
				end
			end
		end
	end

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

----------------------------------------------------------------
-- DrawScreen — box selection rectangle
----------------------------------------------------------------
function widget:DrawScreen()
	if not gz.boxing then
		return
	end

	local x1, y1 = gz.boxX1, gz.boxY1
	local x2, y2 = gz.boxX2, gz.boxY2

	gl.Color(1.0, 0.85, 0.25, 0.12)
	gl.Rect(x1, y1, x2, y2)

	gl.Color(1.0, 0.85, 0.25, 0.9)
	glLineWidth(1.5)
	glBeginEnd(GL_LINE_LOOP, function()
		glVertex(x1, y1)
		glVertex(x2, y1)
		glVertex(x2, y2)
		glVertex(x1, y2)
	end)
	glLineWidth(1)
	gl.Color(1, 1, 1, 1)
end

----------------------------------------------------------------
-- Initialize / Shutdown
----------------------------------------------------------------
function widget:Initialize()
	widgetHandler:AddAction("featureplacer", function(_, _, args)
		if args and args[1] then
			return activate(args[1])
		end
		return activate("point")
	end, nil, "t")
	widgetHandler:AddAction("featureplacerscatter", function()
		return activate("scatter")
	end, nil, "t")
	widgetHandler:AddAction("featureplacerpoint", function()
		return activate("point")
	end, nil, "t")
	widgetHandler:AddAction("featureplacerremove", function()
		return activate("remove")
	end, nil, "t")
	widgetHandler:AddAction("featureplaceroff", deactivate, nil, "t")

	buildFeatureDefList()

	if not Gizmo.init() then
		-- Placement still works without it; only the transform gizmo is lost.
		Echo("[Feature Placer] Gizmo unavailable (GL4 init failed); selection editing disabled")
	end

	-- Expose API
	WG.FeaturePlacer = {
		getState = getState,
		getFeatureDefList = getFeatureDefList,
		getFeatureCategories = getFeatureCategories,
		getCategoryOrder = getCategoryOrder,
		getCategoryLabels = getCategoryLabels,
		setMode = setMode,
		setShape = setShape,
		setRadius = setRadius,
		setRotation = setRotation,
		rotate = rotate,
		setRotRandom = setRotRandom,
		setFeatureCount = setFeatureCount,
		setCadence = setCadence,
		setDistribution = setDistribution,
		setSmartEnabled = setSmartEnabled,
		setSmartFilter = setSmartFilter,
		selectFeature = selectFeature,
		toggleFeature = toggleFeature,
		clearSelectedFeatures = clearSelectedFeatures,
		undo = featureUndo,
		redo = featureRedo,
		save = featureSave,
		load = featureLoad,
		listSaves = listSavedFeatureMaps,
		clearAll = featureClearAll,
		setGridOverlay = setGridOverlay,
		setGridSnap = setGridSnap,
		setGridSnapSize = setGridSnapSize,
		reroll = rerollPreview,
		requestFeatureData = requestFeatureData,
		clearSelection = clearSelection,
		deleteSelection = deleteSelection,
		selectAllVisible = function()
			local vsx, vsy = Spring.GetViewGeometry()
			selectAllInBox(0, 0, vsx, vsy)
		end,
		deactivate = deactivate,
	}

	-- These names live in the shared widget global namespace; RegisterGlobal
	-- silently returns false on a name clash, so namespace them and warn if a
	-- collision ever happens rather than failing invisibly.
	local function registerGlobalChecked(name, fn)
		if not widgetHandler:RegisterGlobal(name, fn) then
			Spring.Echo("[Feature Placer] RegisterGlobal name collision, callback inactive: " .. name)
		end
	end
	registerGlobalChecked("terraform_feature_history", handleHistoryUpdate)
	registerGlobalChecked("terraform_feature_save_begin", handleSaveBegin)
	registerGlobalChecked("terraform_feature_save_data", handleSaveData)
	registerGlobalChecked("terraform_feature_save_end", handleSaveEnd)
end

function widget:Shutdown()
	hideBuildGrid()
	clearGhosts()
	clearSelection()
	Gizmo.shutdown()
	if gridDL then
		glDeleteList(gridDL)
		gridDL = nil
	end
	WG.FeaturePlacer = nil
	widgetHandler:DeregisterGlobal("terraform_feature_history")
	widgetHandler:DeregisterGlobal("terraform_feature_save_begin")
	widgetHandler:DeregisterGlobal("terraform_feature_save_data")
	widgetHandler:DeregisterGlobal("terraform_feature_save_end")
	widgetHandler:RemoveAction("featureplacer")
	widgetHandler:RemoveAction("featureplacerscatter")
	widgetHandler:RemoveAction("featureplacerpoint")
	widgetHandler:RemoveAction("featureplacerremove")
	widgetHandler:RemoveAction("featureplaceroff")
end
