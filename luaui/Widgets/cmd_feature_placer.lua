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
-- Every message this widget sends changes the feature set, so it is also
-- where the project learns it has unsaved changes (a project load's own
-- messages are ignored by markDirty while the load runs).
local SendLuaRulesMsg = function(msg)
	---@type table?
	local mp = WG.MapProject
	if mp and mp.markDirty then
		mp.markDirty("features")
	end
	return Spring.SendLuaRulesMsg(msg)
end
local GetFeaturePosition = Spring.GetFeaturePosition
local GetFeatureDefID = Spring.GetFeatureDefID

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
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
-- Placement sends the list this widget generated and previewed, not brush
-- parameters for the gadget to roll its own dice with: preview and result are
-- the same array, so the ghost preview is truthful.
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

-- Features per message for placement, transforms and file loads. At ~45 chars
-- an entry a full batch stays around 2 KB.
local PLACE_BATCH = 40

local GHOST_ALPHA = 0.55
local GHOST_OWNER = "cmd_feature_placer"
-- Ceiling on previewed ghosts only; placement is never capped.
local PREVIEW_GHOST_CAP = 300

-- Layout generation lives widget-side so the preview can see it; see the
-- header of common/feature_scatter.lua.
local BrushShapes = require("common/brush_shapes")
local Gizmo = require("luaui/Include/gizmo3d_gl4")
local Scatter = require("common/feature_scatter")

local abs = math.abs
local asin = math.asin
local atan2 = math.atan2

local CIRCLE_SEGMENTS = 48
local DEFAULT_RADIUS = 200
local MIN_RADIUS = 8
local MAX_RADIUS = 2000
local RADIUS_STEP = 8
local ROTATION_STEP = 3
-- Bounds of the per-feature scale sliders. Wide on purpose: making trees read
-- small against the units is the whole point, so well below 1 matters most.
local SCALE_LIMIT_MIN = 0.1
local SCALE_LIMIT_MAX = 5.0
local KEYSYMS_SPACE = 0x20
local gridSnapSize = 48 -- mutable; user-adjustable via setGridSnapSize

local floor = math.floor
local max = math.max
local min = math.min
local cos = math.cos
local sin = math.sin
local pi = math.pi
local sqrt = math.sqrt

----------------------------------------------------------------
-- State (one table: this chunk sits at Lua 5.1's 200-local limit)
----------------------------------------------------------------
local fp = {
	active = false,
	mode = nil, -- "scatter", "point", "remove"
	shape = "circle",
	radius = DEFAULT_RADIUS,
	rotation = 0,
	rotRandom = 0, -- 0 = all same heading, 100 = fully random
	tiltRandom = 0, -- largest lean in degrees (0..45), random direction per feature
	featureCount = 1,
	cadence = 10, -- 1-1000 logarithmic (higher = faster)
	distribution = "random", -- "random", "regular", or "clustered"
	-- Per-feature visual scale range. 1/1 means untouched: entries then carry no
	-- scale token, keeping wire traffic and save files small.
	scaleMin = 1.0,
	-- Elmos above (+) or below (-) the ground the next placements land at (Ctrl+Shift+Scroll or
	-- the HEIGHT OFFSET slider). Rides each placement's own y, so undo, saves and projects keep it.
	heightOffset = 0,
	scaleMax = 1.0,
	-- Clustered distribution shape, see generateClustered in common/feature_scatter.lua.
	-- Defaults match that generator's own defaults.
	clumps = 0, -- 0 = auto
	clumpSize = 1.0,
	clumpLoose = 25, -- percent of features scattered between clumps
	clumpVariety = 0, -- percent
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
	placeTimer = 0,
	undoCount = 0,
	redoCount = 0,
}

-- Cursor fade from the edge-extended resolver: 1 inside the map, falling to 0
-- as the cursor recedes past the border. Scales every brush-cursor visual.
local edgeFade = 1
local gridOverlay = false
local gridSnap = false
local gridShowing = false
local gridDL = nil
local gridDLSize = nil
local gridDirty = false

----------------------------------------------------------------
-- Feature definition cache for asset library
----------------------------------------------------------------
local featureDefListBuilt = false
local featureCategories = {} -- { categoryName = { {name=..., id=...}, ... } }

local CATEGORY_ORDER = {
	"geo",
	"rocks",
	"trees",
	"foliage",
	"crystals",
	"osemo",
	"christmas",
	"raptor",
	"armada_wrecks",
	"cortex_wrecks",
	"legion_wrecks",
	"other",
}

local function classifyFeature(name, def)
	-- Geothermal vents get their own category: real maps ship a def named
	-- plain "geovent" (often model-less) next to the game's editor_geovent,
	-- and both buried in Other made it easy to place the wrong one.
	if def and def.geoThermal then
		return "geo"
	end

	-- Blockout models (off-map backdrop layers) are set in SCENE > BLOCKOUT, not placed
	if def and def.customParams and def.customParams.blockout then
		return nil
	end

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

	-- Osemo planet kit (clusters, small trees, background rings)
	if name:find("^osemo_") then
		return "osemo"
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

-- Baked scale variants (see tools/s3o_scale.py and features/enginetrees_override.lua).
-- A def with variants snaps each rolled scale to the nearest variant def; other
-- defs keep the rolled scale (see applyScaleVariants).
local variantSets = {} -- baseDefName -> sorted { { factor, name }, ... } including the base itself at 1.0

local function buildFeatureDefList()
	if featureDefListBuilt then
		return
	end
	featureDefListBuilt = true
	featureCategories = {}
	variantSets = {}
	for _, cat in ipairs(CATEGORY_ORDER) do
		featureCategories[cat] = {}
	end
	for id, def in pairs(FeatureDefs) do
		local cp = def.customParams
		local base = cp and cp.scale_base
		if base then
			-- Scale variants stay out of the asset library; the placer reaches
			-- them only through scale snapping.
			local factor = tonumber(cp.scale_factor)
			if factor and FeatureDefNames[base] then
				local set = variantSets[base]
				if not set then
					set = { { factor = 1.0, name = base } }
					variantSets[base] = set
				end
				set[#set + 1] = { factor = factor, name = def.name }
			end
		else
			local cat = classifyFeature(def.name, def)
			if cat then
				local entry = {
					name = def.name,
					id = id,
					category = cat,
				}
				if not featureCategories[cat] then
					featureCategories[cat] = {}
				end
				local catList = featureCategories[cat]
				catList[#catList + 1] = entry
			end
		end
	end
	for _, set in pairs(variantSets) do
		table.sort(set, function(a, b)
			return a.factor < b.factor
		end)
	end
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
-- Mirrors extraState.buildFullMapGrid in cmd_terraform_brush.lua, so the DISPLAY
-- "Grid" chip shows the same map-wide grid, not only the cursor-following
-- Building Grid GL4 quad.
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
	-- Building Grid GL4 is off by default. SendCommands works from any context;
	-- widgetHandler:EnableWidget can be nil inside RmlUi click handlers.
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
	edgeFade = 1
	-- Shared edge-extended cursor: keeps following the mouse slightly past the
	-- map border, with fade < 1 once the footprint no longer touches the map.
	local tb = WG.TerraformBrush
	if tb and tb.getWorldPositionExtended then
		local radius = fp.mode == "point" and 64 or fp.radius
		local wx, wz, fade = tb.getWorldPositionExtended(radius)
		if wx then
			edgeFade = fade or 1
			return wx, wz
		end
		return nil, nil
	end
	local mx, my = GetMouseState()
	local _, pos = TraceScreenRay(mx, my, true)
	if pos then
		return pos[1], pos[3]
	end
	return nil, nil
end

----------------------------------------------------------------
-- Symmetry helper: delegates to the terraform brush's symmetry system
----------------------------------------------------------------
local function getSymmetricPositions(wx, wz, rot)
	local tb = WG.TerraformBrush
	if tb and tb.getSymmetricPositions then
		return tb.getSymmetricPositions(wx, wz, rot or 0)
	end
	return { { x = wx, z = wz, rot = rot or 0 } }
end

----------------------------------------------------------------
-- Cadence to seconds between placements
----------------------------------------------------------------
local function getCadenceInterval()
	return max(0.03, 2.0 / fp.cadence)
end

----------------------------------------------------------------
-- Brush layout: generate once, resolve per frame
----------------------------------------------------------------
-- The layout is brush-relative and cached, so the preview keeps its shape while
-- the cursor moves. It is rebuilt when a brush parameter or the seed changes;
-- the seed is rerolled after every stamp so consecutive stamps differ.
local preview = {
	-- Clock-derived so two sessions do not open with the same scatter.
	seed = floor(os.clock() * 1000) % 16777216,
	layout = nil,
	layoutKey = nil,
	ghosts = {},
	ghostCount = 0,
	warnedCap = false,
}

-- Seeds stay under 2^24: Recoil builds Lua with LUA_NUMBER = float, so larger
-- integers are not exact (see the RNG note in common/feature_scatter.lua).
local SEED_MAX = 16777216
local SEED_STRIDE = 8191

local function rerollPreview()
	-- Step a counter, not the clock: os.clock is coarse enough that two stamps
	-- in one tick would get the same seed. math.random is no option either,
	-- widgets do not seed it.
	preview.seed = (preview.seed + SEED_STRIDE) % SEED_MAX
	preview.layoutKey = nil
end

local function layoutParams()
	return {
		shape = fp.shape,
		radius = fp.radius,
		-- Negated: Scatter turns positions and headings together the engine heading
		-- way, which is the mirror of how the outline (and the remove brush) turn, so
		-- this makes the whole stamp turn with the outline the user aims with.
		rotation = -fp.rotation,
		count = fp.featureCount,
		distribution = fp.distribution,
		rotRandom = fp.rotRandom,
		tiltRandom = fp.tiltRandom,
		scaleMin = fp.scaleMin,
		scaleMax = fp.scaleMax,
		heightOffset = fp.heightOffset,
		clumps = fp.clumps,
		clumpSize = fp.clumpSize,
		clumpLoose = fp.clumpLoose / 100,
		clumpVariety = fp.clumpVariety / 100,
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
		params.tiltRandom,
		params.scaleMin,
		params.scaleMax,
		params.clumps,
		params.clumpSize,
		params.clumpLoose,
		params.clumpVariety,
		table.concat(params.defNames, ","),
	}, "\0")
end

-- Defs with baked size variants swap the rolled scale for the nearest variant
-- def and clear the scale field: the size is baked into the variant's model, so
-- ghosts draw it unscaled and the wire carries a plain entry. Every other def
-- keeps its scale, which the gadget hands to the CUS shaders as a per-feature
-- uniform (continuous sizes, no baked models needed).
local function applyScaleVariants(layout)
	for i = 1, #layout do
		local entry = layout[i]
		local scale = entry.scale
		if scale then
			local set = variantSets[entry.defName]
			if set then
				entry.scale = nil
				local best = set[1]
				local bestDiff = abs(set[1].factor - scale)
				for j = 2, #set do
					local diff = abs(set[j].factor - scale)
					if diff < bestDiff then
						best, bestDiff = set[j], diff
					end
				end
				entry.defName = best.name
			end
		end
	end
	return layout
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
		local scale = nil
		if params.scaleMin ~= 1 or params.scaleMax ~= 1 then
			scale = Scatter.rollScale(rng, params.scaleMin, params.scaleMax)
		end
		local entry = {
			dx = 0,
			dz = 0,
			defName = params.defNames[rng:int(1, #params.defNames)],
			heading = (baseHeading + rng:int(-spread, spread)) % 65536,
			scale = scale,
		}
		entry.pitch, entry.roll = Scatter.rollTilt(rng, params.tiltRandom)
		preview.layout = applyScaleVariants({ entry })
	else
		preview.layout = applyScaleVariants(Scatter.generateLocal(params, preview.seed))
	end

	preview.layoutKey = key
	return preview.layout
end

-- The edge-extended cursor can put part of the footprint outside the map, and
-- both Scatter.resolve and the gadget CLAMP such positions onto the border, so
-- features would pile up along the edge. Out-of-map entries are dropped per
-- symmetry copy BEFORE resolving, with the same rotation maths resolve applies.
local function layoutInsideMap(layout, centerX, centerZ, extraRotDeg)
	local mapX, mapZ = Game.mapSizeX, Game.mapSizeZ
	local kept = {}
	for i = 1, #layout do
		local entry = layout[i]
		local dx, dz = entry.dx, entry.dz
		if extraRotDeg ~= 0 then
			dx, dz = Scatter.rotatePoint(dx, dz, extraRotDeg)
		end
		local x, z = centerX + dx, centerZ + dz
		if x >= 0 and x <= mapX and z >= 0 and z <= mapZ then
			kept[#kept + 1] = entry
		end
	end
	return kept
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
		-- Each symmetry copy carries its own rotation. The layout was rotated
		-- once by the base rotation, so hand resolve() only the difference, negated
		-- like the base rotation in layoutParams.
		local copyRot = fp.rotation - (p.rot or fp.rotation)
		local resolved = Scatter.resolve(layoutInsideMap(layout, p.x, p.z, copyRot), p.x, p.z, params, copyRot)
		for j = 1, #resolved do
			local r = resolved[j]
			-- resolve returns fresh entries at ground height; the offset lifts or sinks them.
			if fp.heightOffset ~= 0 then
				r.y = r.y + fp.heightOffset
			end
			placements[#placements + 1] = r
		end
	end
	return placements
end

----------------------------------------------------------------
-- Ghost preview
----------------------------------------------------------------
-- Heading and yaw run in OPPOSITE directions. GetVectorFromHeading gives
-- frontdir = (sin t, 0, cos t); a yaw-only draw matrix gives (-sin y, 0, cos y),
-- so y = -t. Without the sign every ghost is mirrored about Z.
local HEADING_TO_RAD = 2 * pi / 65536

local function headingToYaw(heading)
	return -(heading or 0) * HEADING_TO_RAD
end

-- A live feature's visual scale (the gadget's public "visualScale" rules param),
-- so removal highlights and gizmo ghosts match an already scaled feature.
local function getFeatureVisualScale(featureID)
	return Spring.GetFeatureRulesParam(featureID, "visualScale") or 1
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

	-- A big brush under symmetry would be thousands of instances a frame. Only
	-- the preview is capped, never the placement.
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
				(item.alpha or GHOST_ALPHA) * edgeFade,
				item.tintR or 1,
				item.tintG or 1,
				item.tintB or 1,
				item.tintAmount or 0,
				item.scale or 1,
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
						scale = getFeatureVisualScale(fid),
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
-- undo entry. Not math.random: widgets never seed it, so ids would repeat
-- across sessions.
local strokeCounter = 0
local function nextStrokeID()
	strokeCounter = strokeCounter + 1
	-- The counter is unique within a session; the clock part keeps a reloaded
	-- widget from reusing an id the gadget still has open. Both stay small
	-- because Lua numbers are floats.
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
		-- Token counts are the wire protocol: 4 plain, 5 with scale, 7 with
		-- tilt/lift, 8 with both. See parsePlacement in the gadget.
		if p.pitch ~= 0 or p.roll ~= 0 or p.y ~= GetGroundHeight(p.x, p.z) then
			entry =
				string.format("%s %.1f %.1f %d %.4f %.4f %.1f", p.defName, p.x, p.z, p.heading, p.pitch, p.roll, p.y)
		else
			entry = string.format("%s %.1f %.1f %d", p.defName, p.x, p.z, p.heading)
		end
		if p.scale and abs(p.scale - 1) > 0.001 then
			entry = entry .. string.format(" %.3f", p.scale)
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
-- library a click picks a feature instead of placing. Picking a library item
-- returns the tool to placing and drops the gizmo.
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

-- Remove mode is excluded on purpose: the erase brush is normally used with an
-- empty library, so its left button must keep erasing.
local function selectModeActive()
	return fp.active and (fp.mode == "scatter" or fp.mode == "point") and #fp.selectedDefs == 0
end

local function readFeatureTransform(featureID)
	local x, y, z = GetFeaturePosition(featureID)
	if not x then
		return nil
	end
	local pitch, yaw, roll = Spring.GetFeatureRotation(featureID)
	return {
		x = x,
		y = y,
		z = z,
		pitch = pitch or 0,
		yaw = yaw or 0,
		roll = roll or 0,
		scale = getFeatureVisualScale(featureID),
	}
end

-- How far a feature reaches from its origin (the model's base). Counts model
-- height, not only radius, so the gizmo clears a tree's canopy. Def dimensions
-- are model-space, so the live visual scale multiplies in.
local function featureReach(featureID)
	local defID = GetFeatureDefID(featureID)
	local def = defID and FeatureDefs[defID]
	if not def then
		return 16
	end
	local r = def.radius or 16
	local h = def.model and def.model.maxy or 0
	return ((h > r) and h or r) * getFeatureVisualScale(featureID)
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
	-- outside the group. The gizmo caps its own size against the viewport.
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
-- The gizmo rings are WORLD-aligned, so a drag is a world-space rotation.
-- Adding the angle to an euler component is wrong: SetFeatureRotation composes
-- M = Rx(pitch) * Ry(yaw) * Rz(roll), so roll turns about the model's LOCAL Z,
-- which any yaw swings away from world Z. Instead: rebuild the matrix,
-- pre-multiply the world delta, read the eulers back. Recoil's convention, not
-- GLSL's (see gfx_DrawFeatureShape_GL4.lua). Row-major m[row][col] on column vectors.
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

	-- Threshold is exactly 1.0 on purpose: the general branch errs ~eps/cos, the
	-- degenerate one ~cos, and taking the general branch up to sin = 1 measured
	-- 1e-8 worst round-trip error versus 8.8e-3 at 0.99999.
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

-- Where every selected feature ends up for a given gizmo delta. One ring drags
-- at a time, so the non-zero component of (dPitch, dYaw, dRoll) names the axis.
-- One delta matrix both spins each member and orbits it around the pivot.
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
				scale = base.scale,
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
				t.scale or getFeatureVisualScale(t.id),
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

	-- Hide the real features locally and drag ghosts: nothing goes over the wire
	-- until the mouse comes up.
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

	-- A click on a handle without a drag costs no undo entry.
	if not moved or not targets then
		showHiddenFeatures()
		clearGizmoGhosts()
		recomputePivot()
		return
	end

	sendTransforms(targets)

	-- Keep the ghosts up until the sim has moved the real features, or they snap
	-- back for the round-trip. The deadline covers a message that never lands.
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
local function deactivate()
	fp.active = false
	fp.mode = nil
	fp.dragging = false
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

-- The min/max setters below push the other bound along rather than rejecting
-- the input, so the pair can never invert.
local function clampScale(v)
	v = tonumber(v)
	if not v then
		return nil
	end
	return max(SCALE_LIMIT_MIN, min(SCALE_LIMIT_MAX, v))
end

local function setScaleMin(v)
	v = clampScale(v)
	if not v then
		return
	end
	fp.scaleMin = v
	if fp.scaleMax < v then
		fp.scaleMax = v
	end
end

local function setScaleMax(v)
	v = clampScale(v)
	if not v then
		return
	end
	fp.scaleMax = v
	if fp.scaleMin > v then
		fp.scaleMin = v
	end
end

local function setSmartEnabled(val)
	fp.smartEnabled = val and true or false
end

-- Clump controls for the clustered distribution, one table to save locals.
local clumpSetters = {
	setClumps = function(v)
		v = tonumber(v)
		if v then
			fp.clumps = max(0, min(24, floor(v + 0.5)))
		end
	end,
	setClumpSize = function(v)
		v = tonumber(v)
		if v then
			fp.clumpSize = max(0.2, min(3, v))
		end
	end,
	setClumpLoose = function(v)
		v = tonumber(v)
		if v then
			fp.clumpLoose = max(0, min(100, floor(v + 0.5)))
		end
	end,
	setClumpVariety = function(v)
		v = tonumber(v)
		if v then
			fp.clumpVariety = max(0, min(100, floor(v + 0.5)))
		end
	end,
}

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

-- One-shot feature-list read for other widgets, served by the synced gadget.
-- Engine trap: Spring.GetFeatureRotation in LuaUI reads a transform that is only
-- refreshed for features drawn this frame, so off-screen features read zero.
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
				-- Token counts, as the gadget exports them: 4 plain, 5 with scale,
				-- 7 tilt/lift, 8 both. The gadget writes the tails only for
				-- features off the engine's own resting alignment.
				local n = #parts
				local scale
				if n == 5 then
					scale = tonumber(parts[5])
				elseif n >= 8 then
					scale = tonumber(parts[8])
				end
				entries[#entries + 1] = {
					name = parts[1],
					x = tonumber(parts[2]),
					z = tonumber(parts[3]),
					rot = tonumber(parts[4]) or 0,
					pitch = n >= 6 and tonumber(parts[5]) or nil,
					roll = n >= 6 and tonumber(parts[6]) or nil,
					y = n >= 6 and tonumber(parts[7]) or nil,
					scale = scale,
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

local function handleSaveBegin()
	saveBuffer = {}
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

	-- FeaturePlacer setcfg format (unitlist / buildinglist / objectlist with `rot`),
	-- which the map-side feature placer gadget reads as is.
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
				-- Optional tails appear only for tilted, lifted or scaled features,
				-- so plain maps keep the plain format. Token counts: 4 plain,
				-- 5 scale, 7 tilt, 8 tilt+scale (scale is token 5 or token 8).
				local n = #parts
				local scaleField = ""
				if n == 5 then
					scaleField = string.format(", scale = %s", parts[5])
				elseif n >= 8 then
					scaleField = string.format(", scale = %s", parts[8])
				end
				if n >= 7 then
					file:write(
						string.format(
							"\t{ name = %q, x = %s, z = %s, rot = %s, pitch = %s, roll = %s, y = %s%s },\n",
							defName,
							x,
							z,
							rot,
							parts[5],
							parts[6],
							parts[7],
							scaleField
						)
					)
				else
					file:write(
						string.format("\t{ name = %q, x = %s, z = %s, rot = %s%s },\n", defName, x, z, rot, scaleField)
					)
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

	-- io.open cannot always reopen VFS.DirList's absolute paths on Windows when
	-- they contain spaces; VFS.LoadFile with VFS.RAW handles both path kinds.
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

	local fn, err = loadstring(content, nil, {})
	if not fn then
		Echo("[Feature Placer] Parse error: " .. tostring(err))
		return
	end

	local ok, data = pcall(fn)
	if not ok or type(data) ~= "table" then
		Echo("[Feature Placer] Invalid feature map file")
		return
	end

	-- Save compatibility: reads the setcfg objectlist format (`rot`) and the older
	-- flat array of {name, x, z, heading}.
	local list = data.objectlist or data

	-- All batches share one stroke id, so loading a whole map is one undo step.
	local strokeID = nextStrokeID()
	local count = #list
	for i = 1, count, PLACE_BATCH do
		local batch = {}
		for j = i, min(i + PLACE_BATCH - 1, count) do
			local f = list[j]
			if f.name and f.x and f.z then
				-- `rot` (setcfg) or `heading` (older files); a non-number such as "random" rolls a heading
				local rot = f.rot or f.heading or 0
				if type(rot) ~= "number" then
					rot = math.random(-32768, 32767)
				end
				local entry = f.name .. " " .. floor(f.x) .. " " .. floor(f.z) .. " " .. floor(rot)
				-- Optional gizmo transform; records without these fields load plain.
				local hasScale = tonumber(f.scale) and abs(tonumber(f.scale) - 1) > 0.001
				if f.pitch or f.roll or f.y then
					entry = entry .. string.format(" %.4f %.4f", tonumber(f.pitch) or 0, tonumber(f.roll) or 0)
					if f.y then
						entry = entry .. string.format(" %.1f", tonumber(f.y))
					elseif hasScale then
						-- Scale is token 8, unambiguous only after a full tilt
						-- tail, so a tilted, unlifted record writes its ground height.
						entry = entry .. string.format(" %.1f", GetGroundHeight(f.x, f.z))
					end
				end
				if hasScale then
					entry = entry .. string.format(" %.3f", tonumber(f.scale))
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
		tiltRandom = fp.tiltRandom,
		featureCount = fp.featureCount,
		cadence = fp.cadence,
		distribution = fp.distribution,
		scaleMin = fp.scaleMin,
		scaleMax = fp.scaleMax,
		heightOffset = fp.heightOffset,
		clumps = fp.clumps,
		clumpSize = fp.clumpSize,
		clumpLoose = fp.clumpLoose,
		clumpVariety = fp.clumpVariety,
		smartEnabled = fp.smartEnabled,
		smartFilters = fp.smartFilters,
		selectedDefs = fp.selectedDefs,
		selectedSet = fp.selectedSet,
		undoCount = fp.undoCount,
		redoCount = fp.redoCount,
		gridOverlay = gridOverlay,
		gridSnap = gridSnap,
		gridSnapSize = gridSnapSize,
		-- selectMode tells the panel whether a map click picks or places.
		selectMode = selectModeActive(),
		selectionCount = #gz.selection,
		gizmoDragging = gz.dragging,
	}
end

local function getFeatureCategories()
	buildFeatureDefList()
	return featureCategories
end

local function getCategoryOrder()
	return CATEGORY_ORDER
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

-- Local-space containment for the smart filter overlay: the same test placement
-- runs on its unrotated layout (insideLocal in common/feature_scatter.lua), so the
-- green/red grid covers exactly the area features can land in.
local function isInsideBrush(lx, lz, radius, shape)
	return (BrushShapes.isInside(lx, lz, radius, shape, 0))
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
						glColor(0.2, 0.85, 0.3, 0.08 * edgeFade)
					else
						glColor(0.9, 0.15, 0.15, 0.14 * edgeFade)
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

-- Shape corners for the altitude cap prism.
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
	elseif shape == "triangle" then
		-- Same vertices as the outline (drawRegularPolygon with 3 sides).
		for i = 0, 2 do
			local a = i * (2 * pi / 3) + rad
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
		glColor(1.0, 0.6, 0.1, 0.55 * edgeFade)
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 1, #corners do
				glVertex(cx + corners[i][1], topY, cz + corners[i][2])
			end
		end)
	end

	if botY then
		glColor(0.1, 0.6, 1.0, 0.55 * edgeFade)
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 1, #corners do
				glVertex(cx + corners[i][1], botY, cz + corners[i][2])
			end
		end)
	end

	local stride = max(1, floor(#corners / 8))
	local strutBot = botY or (topY and topY - 100) or 0
	local strutTop = topY or (botY and botY + 100) or 0
	glColor(1, 1, 1, 0.2 * edgeFade)
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
		-- First Escape drops the selection, the second leaves the tool.
		if #gz.selection > 0 then
			clearSelection()
		else
			deactivate()
		end
		return true
	end

	-- Delete / Backspace removes the gizmo selection.
	if (key == 0x7F or key == 0x08) and #gz.selection > 0 then
		deleteSelection()
		return true
	end

	-- Ctrl+A selects every feature on screen.
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

	-- Empty mouse: the left button selects and moves what is already on the map.
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

		-- Empty ground: start a box select. The release decides box or deselect.
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
		fp.placeTimer = 0

		-- First stamp on press; Update repeats it at the cadence while held.
		if fp.mode == "remove" then
			sendRemoveMessage(worldX, worldZ)
		else
			placeAt(worldX, worldZ)
		end

		return true
	end

	-- Right-click clears the library pick so the mouse selects again (as in the UNITS
	-- tool); it never removes. Decided on RELEASE and only for a click, so a right
	-- drag does not empty the mouse.
	if button == 3 and fp.mode ~= "remove" and #fp.selectedDefs > 0 then
		fp.rightPress = { mx, my }
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

	if button == 3 and fp.rightPress then
		local px, py = fp.rightPress[1], fp.rightPress[2]
		fp.rightPress = nil
		if abs(mx - px) < BOX_MIN_PX and abs(my - py) < BOX_MIN_PX then
			clearSelectedFeatures()
		end
		return true
	end

	if (button == 1 or button == 3) and fp.dragging then
		fp.dragging = false
		return true
	end
	return false
end

function widget:MouseWheel(up, value)
	if not fp.active then
		return false
	end

	local alt, ctrl, _, shift = GetModKeyState()

	if alt and shift then
		-- Alt+Shift+Scroll = RANDOMIZE TILT, 3 degrees a notch
		fp.tiltRandom = max(0, min(45, (fp.tiltRandom or 0) + (up and 3 or -3)))
		return true
	end

	if ctrl and alt then
		-- Ctrl+Alt+Scroll = feature count
		setFeatureCount(fp.featureCount + (up and 1 or -1))
		return true
	end

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
		return true
	end

	if shift and ctrl then
		-- Ctrl+Shift+Scroll = HEIGHT OFFSET of the next placements, 4 elmos a notch
		fp.heightOffset = max(-500, min(500, fp.heightOffset + (up and 4 or -4)))
		return true
	end

	if shift then
		-- Shift+Scroll = one fixed scale: both SCALE MIN / MAX bounds collapse onto
		-- it, so the sliders show what is in effect. 10% a notch, snapping onto 1x.
		local cur = (fp.scaleMin + fp.scaleMax) * 0.5
		---@type number
		local v = up and cur * 1.1 or cur / 1.1
		if (cur < 1 and v > 1) or (cur > 1 and v < 1) or abs(v - 1) < 0.03 then
			v = 1
		end
		v = clampScale(v) or v
		fp.scaleMin = v
		fp.scaleMax = v
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
		return true
	end

	if ctrl then
		-- Ctrl+Scroll = resize
		local step = up and RADIUS_STEP or -RADIUS_STEP
		setRadius(fp.radius + step)
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

	-- Selection survives a mode switch but not a library pick, or a stale gizmo
	-- would catch clicks meant for the brush.
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

	local _, _, leftPressed = GetMouseState()
	if not leftPressed then
		fp.dragging = false
		return
	end

	-- Held button: repeat stamps at the cadence.
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

	if fp.mode == "remove" then
		sendRemoveMessage(worldX, worldZ)
	else
		placeAt(worldX, worldZ)
	end
end

----------------------------------------------------------------
-- Selection markers
----------------------------------------------------------------
-- A ground ring under each selected feature, sized from its radius. Not a tinted
-- ghost: a second model drawn over the first reads as a rendering fault.
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
-- DrawWorld: brush outline
----------------------------------------------------------------
function widget:DrawWorld()
	-- Full-map grid overlay, drawn even while the tool is inactive.
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

	-- Drawn before the cursor check, so they stay up while the cursor is over the panel.
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

	-- Ghosts of the exact features about to be placed; remove mode tints what
	-- the brush would destroy instead.
	if fp.mode == "remove" then
		syncGhosts(collectRemovalTargets(worldX, worldZ))
	else
		syncGhosts(resolvePlacements(worldX, worldZ))
	end

	if fp.mode == "scatter" then
		glColor(0.2, 0.8, 0.4, 0.7 * edgeFade)
	elseif fp.mode == "point" then
		glColor(0.4, 0.7, 1.0, 0.7 * edgeFade)
	elseif fp.mode == "remove" then
		glColor(0.9, 0.2, 0.2, 0.7 * edgeFade)
	end

	glLineWidth(2)

	if fp.mode == "point" then
		local cy = GetGroundHeight(worldX, worldZ) + 4
		local s = 12
		glBeginEnd(GL.LINES, function()
			glVertex(worldX - s, cy, worldZ)
			glVertex(worldX + s, cy, worldZ)
			glVertex(worldX, cy, worldZ - s)
			glVertex(worldX, cy, worldZ + s)
		end)
	else
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
			if fp.mode == "scatter" then
				glColor(0.2, 0.8, 0.4, 0.3 * edgeFade)
			elseif fp.mode == "point" then
				glColor(0.4, 0.7, 1.0, 0.3 * edgeFade)
			elseif fp.mode == "remove" then
				glColor(0.9, 0.2, 0.2, 0.3 * edgeFade)
			end

			if fp.mode == "point" then
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
-- DrawScreen: box selection rectangle
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

-- Geothermalspots removes itself on maps that boot without vents, so the first
-- vent placed at runtime re-enables it; it then tracks further vents itself.
function widget:FeatureCreated(featureID, allyTeamID)
	local def = FeatureDefs[GetFeatureDefID(featureID)]
	if def and def.geoThermal and not WG.geothermalspots then
		Spring.SendCommands("luaui enablewidget Geothermalspots")
	end
end

----------------------------------------------------------------
-- Initialize / Shutdown
----------------------------------------------------------------
function widget:Initialize()
	buildFeatureDefList()

	if not Gizmo.init() then
		-- Placement still works without it; only the transform gizmo is lost.
		Echo("[Feature Placer] Gizmo unavailable (GL4 init failed); selection editing disabled")
	end

	-- Expose API
	WG.FeaturePlacer = {
		getState = getState,
		getFeatureCategories = getFeatureCategories,
		getCategoryOrder = getCategoryOrder,
		setMode = setMode,
		setShape = setShape,
		setRadius = setRadius,
		setRotation = setRotation,
		rotate = rotate,
		setRotRandom = setRotRandom,
		-- Inline setters save file locals.
		setHeightOffset = function(v)
			fp.heightOffset = max(-500, min(500, floor((tonumber(v) or 0) + 0.5)))
		end,
		setTiltRandom = function(v)
			fp.tiltRandom = max(0, min(45, floor(v + 0.5)))
		end,
		setFeatureCount = setFeatureCount,
		setCadence = setCadence,
		setDistribution = setDistribution,
		setScaleMin = setScaleMin,
		setScaleMax = setScaleMax,
		setClumps = clumpSetters.setClumps,
		setClumpSize = clumpSetters.setClumpSize,
		setClumpLoose = clumpSetters.setClumpLoose,
		setClumpVariety = clumpSetters.setClumpVariety,
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

	-- RegisterGlobal silently returns false on a name clash in the shared widget
	-- namespace, so warn instead of failing invisibly.
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
end
