function widget:GetInfo()
	return {
		name = "Decal Placer",
		desc = "Brush tool for placing, scattering, and removing ground decals from the engine atlas",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1000000,
		enabled = false,
	}
end

----------------------------------------------------------------
-- Localize
----------------------------------------------------------------
local Echo = Spring.Echo
local GetMouseState = Spring.GetMouseState
local GetModKeyState = Spring.GetModKeyState
local GetKeyState = Spring.GetKeyState
local TraceScreenRay = Spring.TraceScreenRay
local GetGroundHeight = Spring.GetGroundHeight

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glDepthTest = gl.DepthTest
local GL_LINE_LOOP = GL.LINE_LOOP

local CreateGroundDecal = Spring.CreateGroundDecal
local DestroyGroundDecal = Spring.DestroyGroundDecal
local SetGroundDecalTexture = Spring.SetGroundDecalTexture
local SetGroundDecalPosAndDims = Spring.SetGroundDecalPosAndDims
local SetGroundDecalRotation = Spring.SetGroundDecalRotation
local SetGroundDecalAlpha = Spring.SetGroundDecalAlpha
local SetGroundDecalTint = Spring.SetGroundDecalTint
local SetGroundDecalNormal = Spring.SetGroundDecalNormal
local GetAllGroundDecals = Spring.GetAllGroundDecals
local GetGroundDecalMiddlePos = Spring.GetGroundDecalMiddlePos
local GetGroundDecalSizeAndHeight = Spring.GetGroundDecalSizeAndHeight
local GetGroundDecalTextures = Spring.GetGroundDecalTextures

local floor = math.floor
local max = math.max
local min = math.min
local cos = math.cos
local sin = math.sin
local pi = math.pi
local random = math.random

local BrushShapes = require("common/brush_shapes")

----------------------------------------------------------------
-- Constants
----------------------------------------------------------------
local DEFAULT_RADIUS = 200
local MIN_RADIUS = 8
local MAX_RADIUS = 2000
local RADIUS_STEP = 8
local ROTATION_STEP = 3
local KEYSYMS_SPACE = 0x20
local UPDATE_INTERVAL = 1 / 30

local SAVE_DIR = "Terraform Brush/DecalMaps/"

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local dp = {
	active = false,
	mode = nil, -- "scatter", "point", "remove"
	shape = "circle",
	radius = DEFAULT_RADIUS,
	rotation = 0,
	rotRandom = 100, -- 0=all same, 100=fully random
	decalCount = 8, -- per scatter
	cadence = 50, -- per second
	-- Decal-specific options
	sizeMin = 32,
	sizeMax = 96,
	alpha = 0.85,
	tintR = 0.5,
	tintG = 0.5,
	tintB = 0.5,
	tintA = 0.5,
	alignToNormal = true, -- orient to terrain normal
	-- Selection
	selectedDecals = {}, -- array of texture names
	selectedSet = {}, -- { [tex] = true }
	-- Drag state
	dragging = false,
	dragAction = nil,
	placeTimer = 0,
	-- Undo/Redo
	undoStack = {}, -- each entry = { decalIDs = {id1,id2,...} }
	redoStack = {}, -- each entry = { specs = { spec, ... } } (see specs)
	-- How each placed decal was made, by id, so an undone batch can be made again
	specs = {},
	-- Registry of decals this tool placed (set of ids). GetAllGroundDecals() also
	-- returns engine decals (unit tracks, scars, building plates); project export
	-- must only serialize our own placements.
	projectIDs = {},
	undoCount = 0,
	redoCount = 0,
}
local MAX_UNDO = 100

local updateTimer = 0

----------------------------------------------------------------
-- Decal library: query atlas + categorize
----------------------------------------------------------------
local decalList = {} -- sorted [{name, category}]
local decalCategories = {} -- { [cat] = { entries... } }
local decalListBuilt = false

local CATEGORY_ORDER = {
	"scars",
	"explosions",
	"tracks",
	"builds",
	"footprints",
	"scorch",
	"groundplates",
	"other",
}

local function classifyDecal(name)
	local n = name:lower()
	if n:find("scar") then
		return "scars"
	end
	if n:find("explo") or n:find("explod") or n:find("crater") then
		return "explosions"
	end
	if n:find("scorch") or n:find("burn") or n:find("char") then
		return "scorch"
	end
	if n:find("track") or n:find("tread") or n:find("wheel") then
		return "tracks"
	end
	if n:find("foot") or n:find("step") then
		return "footprints"
	end
	if n:find("build") or n:find("plate") or n:find("ground_plate") then
		return "builds"
	end
	if n:find("decal_") then
		if n:find("track") then
			return "tracks"
		end
		return "scars"
	end
	if n:find("groundplate") or n:find("_plate") then
		return "groundplates"
	end
	return "other"
end

----------------------------------------------------------------
-- Normal-map detection + main<->norm pairing.
-- The engine decal atlas exposes both the color ("main*") and normal
-- ("norm*") halves of a pair as individual "main" textures (from
-- GetGroundDecalTextures' perspective), but the UX use is to pick ONE
-- entry that bundles both. We hide the norm-only entries from the UI and
-- bind the paired normal automatically when the main is placed.
----------------------------------------------------------------
local function isNormalName(lname)
	-- Leading "norm" / "nrm" / trailing "_norm" / "_nrm" / "_normal" / "_n"
	return lname:find("^norm") ~= nil
		or lname:find("^nrm") ~= nil
		or lname:find("_norm$") ~= nil
		or lname:find("_nrm$") ~= nil
		or lname:find("_normal$") ~= nil
		or lname:find("_n$") ~= nil
end

local function normalBaseKey(lname)
	-- Produce a canonical "pair key" so main and norm textures collide.
	-- "mainscar_5" -> "scar_5", "normscar_5" -> "scar_5"
	-- "armyork_tracks_norm" -> "armyork_tracks"
	local k = lname
	k = k:gsub("^main", ""):gsub("^norm", ""):gsub("^nrm", "")
	k = k:gsub("_norm$", ""):gsub("_nrm$", ""):gsub("_normal$", ""):gsub("_n$", "")
	return k
end

local normPartnerByMain = {} -- { [mainName] = normName }

local function buildDecalList()
	if decalListBuilt then
		return
	end
	decalListBuilt = true
	decalList = {}
	decalCategories = {}
	normPartnerByMain = {}
	for _, c in ipairs(CATEGORY_ORDER) do
		decalCategories[c] = {}
	end
	if not GetGroundDecalTextures then
		Echo("[Decal Placer] Spring.GetGroundDecalTextures not available")
		return
	end
	local names, filenames = GetGroundDecalTextures(true, true)
	names = names or {}
	filenames = filenames or {}

	-- Pass 1: bucket every entry into the main/norm side of its pair key.
	local mainsByKey = {}
	local normsByKey = {}
	for i, name in ipairs(names) do
		local lname = name:lower()
		local key = normalBaseKey(lname)
		if isNormalName(lname) then
			normsByKey[key] = normsByKey[key] or { name = name, filename = filenames[i] }
		else
			mainsByKey[key] = mainsByKey[key] or { name = name, filename = filenames[i] }
		end
	end

	-- Pass 2: emit one library entry per pair, preferring the main half.
	-- Any key that only has a norm half (orphan normal) is skipped — rendering
	-- a raw normal map on terrain looks like nothing useful.
	for key, m in pairs(mainsByKey) do
		local entry = {
			name = m.name,
			category = classifyDecal(m.name),
			filename = m.filename,
			normalName = normsByKey[key] and normsByKey[key].name or nil,
			normalFilename = normsByKey[key] and normsByKey[key].filename or nil,
		}
		if entry.normalName then
			normPartnerByMain[m.name] = entry.normalName
		end
		decalList[#decalList + 1] = entry
		local cat = entry.category
		if not decalCategories[cat] then
			decalCategories[cat] = {}
		end
		local cl = decalCategories[cat]
		cl[#cl + 1] = entry
	end

	-- Custom ground decals are registered into the engine atlas via
	-- gamedata/resources.lua `graphics.decals` subtable; engine assigns them
	-- the atlas name `maindecal_<i>` and they show up here automatically.

	table.sort(decalList, function(a, b)
		return a.name < b.name
	end)
	for _, c in ipairs(CATEGORY_ORDER) do
		if decalCategories[c] then
			table.sort(decalCategories[c], function(a, b)
				return a.name < b.name
			end)
		end
	end
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

local function getCadenceInterval()
	return max(0.03, 2.0 / dp.cadence)
end

----------------------------------------------------------------
-- Shape containment (mirrors feature placer)
----------------------------------------------------------------
local function rotatePoint(px, pz, angleDeg)
	local rad = angleDeg * pi / 180
	local ca = cos(rad)
	local sa = sin(rad)
	return px * ca - pz * sa, px * sa + pz * ca
end

local function isInsideShape(dx, dz, radius, shape, angleDeg)
	-- Shared point-in-shape test (see common/brush_shapes.lua).
	return (BrushShapes.isInside(dx, dz, radius, shape, angleDeg))
end

----------------------------------------------------------------
-- Decal placement
----------------------------------------------------------------
local function pickRandomTexture()
	local n = #dp.selectedDecals
	if n == 0 then
		return nil
	end
	return dp.selectedDecals[random(1, n)]
end

local function applyDecal(tex, wx, wz, sizeX, sizeZ, rotRad)
	if not CreateGroundDecal then
		return nil
	end
	local id = CreateGroundDecal()
	if not id then
		return nil
	end
	SetGroundDecalTexture(id, tex, true)
	-- Bind matching normal map, if the atlas has one registered for this main.
	-- Placing the main alone makes the decal unlit/flat; wiring the norm sibling
	-- gives proper per-pixel lighting that blends with the terrain.
	local norm = normPartnerByMain[tex]
	if norm then
		SetGroundDecalTexture(id, norm, false)
	end
	SetGroundDecalPosAndDims(id, wx, wz, sizeX, sizeZ)
	SetGroundDecalRotation(id, rotRad)
	if SetGroundDecalAlpha then
		SetGroundDecalAlpha(id, dp.alpha, 0)
	end
	if SetGroundDecalTint then
		SetGroundDecalTint(id, dp.tintR, dp.tintG, dp.tintB, dp.tintA)
	end
	if dp.alignToNormal and SetGroundDecalNormal then
		SetGroundDecalNormal(id, 0, 0, 0)
	end
	dp.projectIDs[id] = true
	dp.specs[id] = {
		tex = tex,
		x = wx,
		z = wz,
		sx = sizeX,
		sz = sizeZ,
		rot = rotRad,
		alpha = dp.alpha,
		tint = { dp.tintR, dp.tintG, dp.tintB, dp.tintA },
		align = dp.alignToNormal,
	}
	return id
end

local function pushUndoBatch(ids)
	if #ids == 0 then
		return
	end
	-- Every decal edit passes here: the project has unsaved changes.
	---@type table?
	local mp = WG.MapProject
	if mp and mp.markDirty then
		mp.markDirty("decals")
	end
	dp.redoStack = {}
	dp.undoStack[#dp.undoStack + 1] = { decalIDs = ids }
	while #dp.undoStack > MAX_UNDO do
		table.remove(dp.undoStack, 1)
	end
	dp.undoCount = #dp.undoStack
	dp.redoCount = 0
end

local function placeScatter(cx, cz)
	if #dp.selectedDecals == 0 then
		return
	end
	local count = dp.decalCount
	local r = dp.radius
	local placed = {}
	local attempts = 0
	local maxAttempts = count * 8
	while #placed < count and attempts < maxAttempts do
		attempts = attempts + 1
		local rx = (random() * 2 - 1) * r
		local rz = (random() * 2 - 1) * r
		if isInsideShape(rx, rz, r, dp.shape, 0) then
			local wx, wz = rotatePoint(rx, rz, dp.rotation)
			wx, wz = cx + wx, cz + wz
			local tex = pickRandomTexture()
			if tex then
				local sizeBase = dp.sizeMin + random() * (dp.sizeMax - dp.sizeMin)
				local rotDeg = dp.rotation + (random() * 2 - 1) * (dp.rotRandom * 1.8)
				local rotRad = rotDeg * pi / 180
				local id = applyDecal(tex, wx, wz, sizeBase, sizeBase, rotRad)
				if id then
					placed[#placed + 1] = id
				end
			end
		end
	end
	pushUndoBatch(placed)
end

local function placePoint(cx, cz)
	if #dp.selectedDecals == 0 then
		return
	end
	local tex = pickRandomTexture()
	if not tex then
		return
	end
	local sizeBase = dp.sizeMin + random() * (dp.sizeMax - dp.sizeMin)
	local rotDeg = dp.rotation + (random() * 2 - 1) * (dp.rotRandom * 1.8)
	local id = applyDecal(tex, cx, cz, sizeBase, sizeBase, rotDeg * pi / 180)
	if id then
		pushUndoBatch({ id })
	end
end

local function placeRemove(cx, cz)
	if not GetAllGroundDecals or not GetGroundDecalMiddlePos then
		return
	end
	local r = dp.radius
	local r2 = r * r
	for _, id in ipairs(GetAllGroundDecals()) do
		local dx, dz = GetGroundDecalMiddlePos(id)
		if dx then
			local ddx = dx - cx
			local ddz = dz - cz
			if ddx * ddx + ddz * ddz <= r2 then
				if DestroyGroundDecal(id) then
					dp.projectIDs[id] = nil
				end
			end
		end
	end
end

-- Apply TerraformBrush grid-snap + symmetric fan-out to a placement call.
-- `fn(x, z)` is one of placeScatter / placePoint / placeRemove.
local function placeSymmetric(fn, cx, cz)
	local tb = WG.TerraformBrush
	local rot = dp.rotation or 0
	if tb and tb.getState then
		local st = tb.getState()
		if st.angleSnap then
			rot = st.rotationDeg or rot
		end
		if st.gridSnap and tb.snapWorld then
			cx, cz = tb.snapWorld(cx, cz, rot)
		end
		if st.symmetryActive and tb.getSymmetricPositions then
			local positions = tb.getSymmetricPositions(cx, cz, rot)
			if positions and #positions > 0 then
				for _, p in ipairs(positions) do
					fn(p.x, p.z)
				end
				return
			end
		end
	end
	fn(cx, cz)
end

local function decalUndo()
	local entry = dp.undoStack[#dp.undoStack]
	if not entry then
		return
	end
	dp.undoStack[#dp.undoStack] = nil
	local specs = {}
	for _, id in ipairs(entry.decalIDs) do
		specs[#specs + 1] = dp.specs[id]
		dp.specs[id] = nil
		DestroyGroundDecal(id)
		dp.projectIDs[id] = nil
	end
	dp.redoStack[#dp.redoStack + 1] = { specs = specs }
	dp.undoCount = #dp.undoStack
	dp.redoCount = #dp.redoStack
	---@type table?
	local mp = WG.MapProject
	if mp and mp.markDirty then
		mp.markDirty("decals")
	end
end

-- Makes an undone batch again, with the alpha, tint and alignment it had
local function decalRedo()
	local entry = dp.redoStack[#dp.redoStack]
	if not entry then
		return
	end
	dp.redoStack[#dp.redoStack] = nil
	local saved = { dp.alpha, dp.tintR, dp.tintG, dp.tintB, dp.tintA, dp.alignToNormal }
	local ids = {}
	for _, s in ipairs(entry.specs) do
		dp.alpha, dp.alignToNormal = s.alpha, s.align
		dp.tintR, dp.tintG, dp.tintB, dp.tintA = s.tint[1], s.tint[2], s.tint[3], s.tint[4]
		ids[#ids + 1] = applyDecal(s.tex, s.x, s.z, s.sx, s.sz, s.rot)
	end
	dp.alpha, dp.tintR, dp.tintG, dp.tintB, dp.tintA, dp.alignToNormal =
		saved[1], saved[2], saved[3], saved[4], saved[5], saved[6]
	dp.undoStack[#dp.undoStack + 1] = { decalIDs = ids }
	dp.undoCount = #dp.undoStack
	dp.redoCount = #dp.redoStack
	---@type table?
	local mp = WG.MapProject
	if mp and mp.markDirty then
		mp.markDirty("decals")
	end
end

local function decalClearAll()
	if not GetAllGroundDecals then
		return
	end
	local n = 0
	for _, id in ipairs(GetAllGroundDecals()) do
		if DestroyGroundDecal(id) then
			n = n + 1
		end
	end
	dp.projectIDs = {}
	dp.specs = {}
	dp.undoStack = {}
	dp.redoStack = {}
	dp.undoCount = 0
	dp.redoCount = 0
	Echo("[Decal Placer] Cleared " .. n .. " decal(s)")
end

----------------------------------------------------------------
-- Activation / Mode
----------------------------------------------------------------
local function deactivate()
	dp.active = false
	dp.mode = nil
	dp.dragging = false
	return true
end

local function setMode(mode)
	if mode == "scatter" or mode == "point" or mode == "remove" then
		if not dp.active and WG.TerraformBrush then
			WG.TerraformBrush.deactivate()
		end
		if not dp.active and WG.WeatherBrush then
			WG.WeatherBrush.deactivate()
		end
		if not dp.active and WG.FeaturePlacer then
			WG.FeaturePlacer.deactivate()
		end
		dp.mode = mode
		if mode == "point" then
			dp.decalCount = 1
			dp.cadence = 1
		end
		if not dp.active then
			dp.active = true
			buildDecalList()
		end
	end
end

----------------------------------------------------------------
-- Setters
----------------------------------------------------------------
local function setRadius(r)
	dp.radius = max(MIN_RADIUS, min(MAX_RADIUS, floor(r)))
end
local function setRotation(d)
	dp.rotation = d % 360
end
local function setRotRandom(v)
	dp.rotRandom = max(0, min(100, floor(v)))
end
local function setDecalCount(n)
	dp.decalCount = max(1, min(500, floor(n)))
end
local function setCadence(v)
	dp.cadence = max(1, min(1000, floor(v)))
end
local function setSizeMin(v)
	dp.sizeMin = max(4, min(1024, floor(v)))
	if dp.sizeMin > dp.sizeMax then
		dp.sizeMax = dp.sizeMin
	end
end
local function setSizeMax(v)
	dp.sizeMax = max(4, min(1024, floor(v)))
	if dp.sizeMax < dp.sizeMin then
		dp.sizeMin = dp.sizeMax
	end
end
local function setAlpha(v)
	dp.alpha = max(0, min(1, v))
end
local function setAlignToNormal(v)
	dp.alignToNormal = v and true or false
end

local function selectDecal(name)
	dp.selectedDecals = { name }
	dp.selectedSet = { [name] = true }
end

local function toggleDecal(name)
	if dp.selectedSet[name] then
		dp.selectedSet[name] = nil
		for i = #dp.selectedDecals, 1, -1 do
			if dp.selectedDecals[i] == name then
				table.remove(dp.selectedDecals, i)
				break
			end
		end
	else
		dp.selectedSet[name] = true
		dp.selectedDecals[#dp.selectedDecals + 1] = name
	end
end

local function clearSelectedDecals()
	dp.selectedDecals = {}
	dp.selectedSet = {}
end

local function getState()
	return {
		active = dp.active,
		mode = dp.mode,
		shape = dp.shape,
		radius = dp.radius,
		rotation = dp.rotation,
		rotRandom = dp.rotRandom,
		decalCount = dp.decalCount,
		cadence = dp.cadence,
		sizeMin = dp.sizeMin,
		sizeMax = dp.sizeMax,
		alpha = dp.alpha,
		tintR = dp.tintR,
		tintG = dp.tintG,
		tintB = dp.tintB,
		tintA = dp.tintA,
		alignToNormal = dp.alignToNormal,
		selectedDecals = dp.selectedDecals,
		selectedSet = dp.selectedSet,
		undoCount = dp.undoCount,
		redoCount = dp.redoCount,
	}
end

local function getDecalCategories()
	buildDecalList()
	return decalCategories
end
local function getCategoryOrder()
	return CATEGORY_ORDER
end

----------------------------------------------------------------
-- Save / Load decal map
----------------------------------------------------------------
local function decalSave()
	if not GetAllGroundDecals then
		return
	end
	Spring.CreateDir(SAVE_DIR)
	local mapName = Game.mapName or "unknown"
	local timestamp = os.date("%Y%m%d_%H%M%S")
	local filename = SAVE_DIR .. mapName .. "_decals_" .. timestamp .. ".lua"
	local f = io.open(filename, "w")
	if not f then
		Echo("[Decal Placer] Cannot write " .. filename)
		return
	end
	f:write("-- Decal map: " .. mapName .. "\n")
	f:write("-- Saved: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
	f:write("return {\n")
	local n = 0
	for _, id in ipairs(GetAllGroundDecals()) do
		local dx, dz = GetGroundDecalMiddlePos(id)
		local sx, sz = GetGroundDecalSizeAndHeight(id)
		local rot = Spring.GetGroundDecalRotation and Spring.GetGroundDecalRotation(id) or 0
		local tex = Spring.GetGroundDecalTexture and Spring.GetGroundDecalTexture(id, true) or ""
		if dx and tex and tex ~= "" then
			f:write(
				string.format(
					"\t{tex=%q, x=%.1f, z=%.1f, sx=%.1f, sz=%.1f, rot=%.4f},\n",
					tex,
					dx,
					dz,
					sx or 64,
					sz or 64,
					rot
				)
			)
			n = n + 1
		end
	end
	f:write("}\n")
	f:close()
	Echo("[Decal Placer] Saved " .. n .. " decals to " .. filename)
end

-- Project-mode save: only decals placed by this tool (dp.projectIDs), stable order,
-- no timestamp comment — repeated saves of the same scene must serialize identically
-- (project files live in git). Returns the decal count written, or nil on error.
local function decalSaveProject(explicitPath)
	if not GetAllGroundDecals then
		return nil
	end
	-- "wb": project files must be byte-identical across OSes (no CRLF translation)
	local f = io.open(explicitPath, "wb")
	if not f then
		Echo("[Decal Placer] Cannot write " .. explicitPath)
		return nil
	end
	local lines = {}
	for _, id in ipairs(GetAllGroundDecals()) do
		if dp.projectIDs[id] then
			local dx, dz = GetGroundDecalMiddlePos(id)
			local sx, sz = GetGroundDecalSizeAndHeight(id)
			local rot = Spring.GetGroundDecalRotation and Spring.GetGroundDecalRotation(id) or 0
			local tex = Spring.GetGroundDecalTexture and Spring.GetGroundDecalTexture(id, true) or ""
			if dx and tex and tex ~= "" then
				lines[#lines + 1] = string.format(
					"\t{tex=%q, x=%.1f, z=%.1f, sx=%.1f, sz=%.1f, rot=%.4f},",
					tex,
					dx,
					dz,
					sx or 64,
					sz or 64,
					rot
				)
			end
		end
	end
	-- Sorting the fully serialized lines gives a total order over every field, so
	-- ties can never reorder entries between sessions (files live in git).
	table.sort(lines)
	f:write("return {\n")
	f:write(table.concat(lines, "\n"))
	if #lines > 0 then
		f:write("\n")
	end
	f:write("}\n")
	f:close()
	return #lines
end

local function decalLoad(filename)
	if not filename or filename == "" then
		local saves = VFS.DirList(SAVE_DIR, "*.lua", VFS.RAW) or {}
		if #saves == 0 then
			Echo("[Decal Placer] No saved decal files")
			return
		end
		filename = saves[#saves]
	end
	-- Prefer loadfile (BAR's canonical pattern, see cmd_light_placer.load).
	-- io.open + loadstring occasionally fails inside the widget sandbox for
	-- files under SAVE_DIR; loadfile resolves the same path reliably.
	local fn, err = loadfile(filename)
	if not fn then
		-- Fallback: try io.open + loadstring in case the VFS path disagrees.
		local f = io.open(filename, "r")
		if not f then
			Echo("[Decal Placer] Cannot open " .. filename .. ": " .. tostring(err))
			return
		end
		local content = f:read("*a")
		f:close()
		fn, err = loadstring(content, filename)
		if not fn then
			Echo("[Decal Placer] Parse error: " .. tostring(err))
			return
		end
	end
	setfenv(fn, {})
	local ok, data = pcall(fn)
	if not ok or type(data) ~= "table" then
		Echo("[Decal Placer] Invalid file: " .. tostring(data))
		return
	end
	local placed = {}
	for _, d in ipairs(data) do
		if d.tex and d.x and d.z then
			local id = applyDecal(d.tex, d.x, d.z, d.sx or 64, d.sz or 64, d.rot or 0)
			if id then
				placed[#placed + 1] = id
			end
		end
	end
	pushUndoBatch(placed)
	Echo("[Decal Placer] Loaded " .. #placed .. " decals from " .. filename)
end

local function listSavedDecalMaps()
	local files = VFS.DirList(SAVE_DIR, "*.lua", VFS.RAW)
	return files or {}
end

----------------------------------------------------------------
-- Drawing brush outline
----------------------------------------------------------------
-- The brush is always a circle: nothing sets another shape.
local function drawCircleOutline(cx, cz, radius)
	glBeginEnd(GL_LINE_LOOP, function()
		for i = 0, 47 do
			local a = i * (2 * pi / 48)
			local x = cx + radius * cos(a)
			local z = cz + radius * sin(a)
			glVertex(x, GetGroundHeight(x, z) + 4, z)
		end
	end)
end

local function drawCurrentBrush()
	local cx, cz = getWorldMousePosition()
	do
		local tb = WG.TerraformBrush
		if tb and tb.animateUnmouse then
			cx, cz = tb.animateUnmouse("decalPlacer", cx, cz, dp.radius, 1.0)
		elseif tb and tb.getUnmouseTarget and not cx then
			cx, cz = tb.getUnmouseTarget(dp.radius, 1.0)
		end
	end
	if not cx then
		return
	end
	do
		local tb2 = WG.TerraformBrush
		local st2 = tb2 and tb2.getState and tb2.getState()
		if st2 and (st2.symmetryHoveringOrigin or st2.symmetryDraggingOrigin) then
			return
		end
	end
	glDepthTest(true)
	glLineWidth(2)
	if dp.dragAction == "remove" or dp.mode == "remove" then
		glColor(1.0, 0.3, 0.3, 0.85)
	elseif #dp.selectedDecals == 0 then
		glColor(0.9, 0.85, 0.2, 0.85)
	else
		glColor(0.3, 0.85, 1.0, 0.85)
	end
	drawCircleOutline(cx, cz, dp.radius)
	glLineWidth(1)
	glColor(1, 1, 1, 1)
	glDepthTest(false)
end

----------------------------------------------------------------
-- Widget callins
----------------------------------------------------------------
function widget:Initialize()
	WG.DecalPlacer = {
		getState = getState,
		getDecalCategories = getDecalCategories,
		getCategoryOrder = getCategoryOrder,
		setMode = setMode,
		setRadius = setRadius,
		setRotation = setRotation,
		setRotRandom = setRotRandom,
		setDecalCount = setDecalCount,
		setCadence = setCadence,
		setSizeMin = setSizeMin,
		setSizeMax = setSizeMax,
		setAlpha = setAlpha,
		setAlignToNormal = setAlignToNormal,
		selectDecal = selectDecal,
		toggleDecal = toggleDecal,
		clearSelectedDecals = clearSelectedDecals,
		undo = decalUndo,
		redo = decalRedo,
		clearAll = decalClearAll,
		save = decalSave,
		saveProject = decalSaveProject,
		load = decalLoad,
		listSaves = listSavedDecalMaps,
		deactivate = deactivate,
	}
end

-- Persist the placement registry across /luaui reload: placed ground decals are
-- engine objects that survive a widget reload, but dp.projectIDs would not —
-- a project save right after a reload would then see zero owned decals and
-- delete the project's decals section. Guards: ids are only re-adopted in the
-- same session (game frame is monotonic within one) and are re-validated
-- against GetAllGroundDecals() at save time anyway.
function widget:GetConfigData()
	local ids = {}
	for id in pairs(dp.projectIDs) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	return {
		projectIDs = ids,
		savedAtFrame = Spring.GetGameFrame(),
		mapName = Game.mapName,
	}
end

function widget:SetConfigData(data)
	if not (data and data.projectIDs) then
		return
	end
	if data.mapName ~= Game.mapName then
		return
	end
	local frame = Spring.GetGameFrame()
	if not data.savedAtFrame or data.savedAtFrame > frame then
		return
	end
	for _, id in ipairs(data.projectIDs) do
		dp.projectIDs[id] = true
	end
end

function widget:Shutdown()
	WG.DecalPlacer = nil
end

function widget:KeyPress(key, mods)
	if not dp.active then
		return false
	end
	if key == 0x1B then
		deactivate()
		return true
	end
	if mods.ctrl and key == 122 and mods.shift then -- Ctrl+Shift+Z
		decalRedo()
		return true
	end
	if mods.ctrl and key == 122 then -- Ctrl+Z
		decalUndo()
		return true
	end
	if mods.ctrl and key == 121 then -- Ctrl+Y
		decalRedo()
		return true
	end
	return false
end

function widget:MousePress(mx, my, button)
	if not dp.active or not dp.mode then
		return false
	end
	-- Defer to measure tool when active so decal placement doesn't consume the click
	do
		local tb = WG.TerraformBrush
		local st = tb and tb.getState and tb.getState() or nil
		if st and st.measureActive then
			return false
		end
		-- Defer to symmetry origin drag so terraform can grab the drag
		if st and st.symmetryActive then
			if st.symmetryPlacingOrigin or st.symmetryHoveringOrigin or st.symmetryDraggingOrigin then
				return false
			end
		end
	end
	if button == 1 then
		local wx, wz = getWorldMousePosition()
		if not wx then
			return false
		end
		dp.dragging = true
		dp.dragAction = "place"
		dp.placeTimer = 0
		if dp.mode == "scatter" then
			placeSymmetric(placeScatter, wx, wz)
		elseif dp.mode == "point" then
			placeSymmetric(placePoint, wx, wz)
		elseif dp.mode == "remove" then
			placeSymmetric(placeRemove, wx, wz)
		end
		return true
	end
	if button == 3 then
		local wx, wz = getWorldMousePosition()
		if not wx then
			return false
		end
		dp.dragging = true
		dp.dragAction = "remove"
		placeSymmetric(placeRemove, wx, wz)
		return true
	end
	return false
end

function widget:MouseRelease(_, _, button)
	if (button == 1 or button == 3) and dp.dragging then
		dp.dragging = false
		dp.dragAction = nil
		return true
	end
	return false
end

function widget:MouseWheel(up, _)
	if not dp.active then
		return false
	end
	local alt, ctrl, _, shift = GetModKeyState()
	if alt then
		local step = ROTATION_STEP
		local tb = WG.TerraformBrush
		local tbs = tb and tb.getState and tb.getState() or nil
		if tbs and tbs.angleSnap and (tbs.angleSnapStep or 0) > 0 then
			step = tbs.angleSnapStep
		end
		local dir = up and 1 or -1
		dp.rotation = ((dp.rotation + dir * step) % 360 + 360) % 360
		return true
	end
	if shift then
		setDecalCount(dp.decalCount + (up and 1 or -1))
		return true
	end
	if GetKeyState(KEYSYMS_SPACE) then
		if up then
			setCadence(dp.cadence * 1.15)
		else
			setCadence(dp.cadence / 1.15)
		end
		return true
	end
	if ctrl then
		setRadius(dp.radius + (up and RADIUS_STEP or -RADIUS_STEP))
		return true
	end
	return false
end

function widget:Update(dt)
	if not dp.active then
		return
	end
	updateTimer = updateTimer + dt
	if updateTimer < UPDATE_INTERVAL then
		return
	end
	updateTimer = 0
	if dp.dragging and dp.dragAction == "place" then
		dp.placeTimer = dp.placeTimer + UPDATE_INTERVAL
		if dp.placeTimer >= getCadenceInterval() then
			dp.placeTimer = 0
			local wx, wz = getWorldMousePosition()
			if wx then
				if dp.mode == "scatter" then
					placeSymmetric(placeScatter, wx, wz)
				elseif dp.mode == "point" then
					placeSymmetric(placePoint, wx, wz)
				end
			end
		end
	elseif dp.dragging and dp.dragAction == "remove" then
		local wx, wz = getWorldMousePosition()
		if wx then
			placeSymmetric(placeRemove, wx, wz)
		end
	end
end

function widget:DrawWorld()
	if not dp.active then
		return
	end
	drawCurrentBrush()
end
