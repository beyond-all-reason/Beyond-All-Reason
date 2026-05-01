function widget:GetInfo()
	return {
		name    = "Decal Placer",
		desc    = "Brush tool for placing, scattering, and removing ground decals from the engine atlas",
		author  = "BARb",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

----------------------------------------------------------------
-- Localize
----------------------------------------------------------------
local Echo            = Spring.Echo
local GetMouseState   = Spring.GetMouseState
local GetModKeyState  = Spring.GetModKeyState
local GetKeyState     = Spring.GetKeyState
local TraceScreenRay  = Spring.TraceScreenRay
local GetGroundHeight = Spring.GetGroundHeight
local GetGroundNormal = Spring.GetGroundNormal

local glColor    = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex   = gl.Vertex
local glDepthTest = gl.DepthTest
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_LINES     = GL.LINES

local CreateGroundDecal       = Spring.CreateGroundDecal
local DestroyGroundDecal      = Spring.DestroyGroundDecal
local SetGroundDecalTexture   = Spring.SetGroundDecalTexture
local SetGroundDecalPosAndDims = Spring.SetGroundDecalPosAndDims
local SetGroundDecalRotation  = Spring.SetGroundDecalRotation
local SetGroundDecalAlpha     = Spring.SetGroundDecalAlpha
local SetGroundDecalTint      = Spring.SetGroundDecalTint
local SetGroundDecalNormal    = Spring.SetGroundDecalNormal
local GetAllGroundDecals      = Spring.GetAllGroundDecals
local GetGroundDecalMiddlePos = Spring.GetGroundDecalMiddlePos
local GetGroundDecalSizeAndHeight = Spring.GetGroundDecalSizeAndHeight
local GetGroundDecalTextures  = Spring.GetGroundDecalTextures

local floor  = math.floor
local max    = math.max
local min    = math.min
local cos    = math.cos
local sin    = math.sin
local pi     = math.pi
local sqrt   = math.sqrt
local atan2  = math.atan2
local random = math.random

----------------------------------------------------------------
-- Constants
----------------------------------------------------------------
local DEFAULT_RADIUS = 200
local MIN_RADIUS     = 8
local MAX_RADIUS     = 2000
local RADIUS_STEP    = 8
local ROTATION_STEP  = 3
local KEYSYMS_SPACE  = 0x20
local UPDATE_INTERVAL = 1 / 30

local SAVE_DIR = "Terraform Brush/DecalMaps/"

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local dp = {
	active        = false,
	mode          = nil,    -- "scatter", "point", "remove"
	shape         = "circle",
	radius        = DEFAULT_RADIUS,
	rotation      = 0,
	rotRandom     = 100,    -- 0=all same, 100=fully random
	decalCount    = 8,      -- per scatter
	cadence       = 50,     -- per second
	distribution  = "random",
	smartEnabled  = false,
	smartFilters  = {
		avoidWater   = false,
		avoidCliffs  = false,
		slopeMax     = 45,
		preferSlopes = false,
		slopeMin     = 10,
		altMinEnable = false,
		altMin       = 0,
		altMaxEnable = false,
		altMax       = 200,
	},
	-- Decal-specific options
	sizeMin       = 32,
	sizeMax       = 96,
	alpha         = 0.85,
	tintR         = 0.5,
	tintG         = 0.5,
	tintB         = 0.5,
	tintA         = 0.5,
	alignToNormal = true,    -- orient to terrain normal
	-- Selection
	selectedDecals = {},     -- array of texture names
	selectedSet    = {},     -- { [tex] = true }
	-- Drag state
	dragging      = false,
	dragAction    = nil,
	lockedWorldX  = nil,
	lockedWorldZ  = nil,
	placeTimer    = 0,
	-- Undo/Redo
	undoStack     = {},      -- each entry = { decalIDs = {id1,id2,...} }
	redoStack     = {},
	undoCount     = 0,
	redoCount     = 0,
}
local MAX_UNDO = 100

local updateTimer = 0

----------------------------------------------------------------
-- Decal library: query atlas + categorize
----------------------------------------------------------------
local decalList = {}             -- sorted [{name, category}]
local decalCategories = {}       -- { [cat] = { entries... } }
local decalListBuilt = false

local CATEGORY_ORDER = {
	"scars", "explosions", "tracks", "builds", "footprints", "scorch", "groundplates", "other",
}

local CATEGORY_LABELS = {
	scars        = "Scars",
	explosions   = "Explosions",
	tracks       = "Tracks",
	builds       = "Builds",
	footprints   = "Footprints",
	scorch       = "Scorch",
	groundplates = "Plates",
	other        = "Other",
}

local function classifyDecal(name)
	local n = name:lower()
	if n:find("scar") then return "scars" end
	if n:find("explo") or n:find("explod") or n:find("crater") then return "explosions" end
	if n:find("scorch") or n:find("burn") or n:find("char") then return "scorch" end
	if n:find("track") or n:find("tread") or n:find("wheel") then return "tracks" end
	if n:find("foot") or n:find("step") then return "footprints" end
	if n:find("build") or n:find("plate") or n:find("ground_plate") then return "builds" end
	if n:find("decal_") then
		if n:find("track") then return "tracks" end
		return "scars"
	end
	if n:find("groundplate") or n:find("_plate") then return "groundplates" end
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

-- Exposed so UI / exporter can look up the norm partner.
local normPartnerByMain = {}  -- { [mainName] = normName }

local function getNormalPartner(mainName)
	return normPartnerByMain[mainName]
end

local function buildDecalList()
	if decalListBuilt then return end
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
	local skippedNormals = 0
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
		if not decalCategories[cat] then decalCategories[cat] = {} end
		local cl = decalCategories[cat]
		cl[#cl + 1] = entry
	end
	for key, _ in pairs(normsByKey) do
		if not mainsByKey[key] then skippedNormals = skippedNormals + 1 end
	end

	-- Custom ground decals are registered into the engine atlas via
	-- gamedata/resources.lua `graphics.decals` subtable; engine assigns them
	-- the atlas name `maindecal_<i>` and they show up here automatically.

	table.sort(decalList, function(a, b) return a.name < b.name end)
	for _, c in ipairs(CATEGORY_ORDER) do
		if decalCategories[c] then
			table.sort(decalCategories[c], function(a, b) return a.name < b.name end)
		end
	end
	Echo(string.format(
		"[Decal Placer] Loaded %d decals (%d main/norm pairs, %d orphan normals hidden)",
		#decalList, #decalList, skippedNormals))
end

----------------------------------------------------------------
-- World mouse position
----------------------------------------------------------------
local function getWorldMousePosition()
	local mx, my = GetMouseState()
	local _, pos = TraceScreenRay(mx, my, true)
	if pos then return pos[1], pos[3] end
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
	local lx, lz = rotatePoint(dx, dz, -angleDeg)
	local ax, az = math.abs(lx), math.abs(lz)
	if shape == "circle" then
		return lx * lx + lz * lz <= radius * radius
	elseif shape == "square" then
		return ax <= radius and az <= radius
	elseif shape == "hexagon" or shape == "octagon" or shape == "triangle" then
		local sides = shape == "hexagon" and 6 or (shape == "octagon" and 8 or 3)
		local dist = sqrt(lx * lx + lz * lz)
		if dist < 0.001 then return true end
		local angle = atan2(lz, lx)
		if angle < 0 then angle = angle + 2 * pi end
		local secA = 2 * pi / sides
		local inSec = (angle % secA) - secA / 2
		local apothem = radius * cos(pi / sides)
		return dist <= apothem / cos(inSec)
	end
	return false
end

----------------------------------------------------------------
-- Smart filter test
----------------------------------------------------------------
local function passesSmartFilter(wx, wz)
	if not dp.smartEnabled then return true end
	local sf = dp.smartFilters
	local h = GetGroundHeight(wx, wz)
	local _, ny = GetGroundNormal(wx, wz)
	ny = ny or 1.0
	if sf.avoidWater and h < 0 then return false end
	if sf.avoidCliffs then
		local nyMin = cos(sf.slopeMax * pi / 180)
		if ny < nyMin then return false end
	end
	if sf.preferSlopes then
		local nyMax = cos(sf.slopeMin * pi / 180)
		if ny > nyMax then return false end
	end
	if sf.altMinEnable and h < sf.altMin then return false end
	if sf.altMaxEnable and h > sf.altMax then return false end
	return true
end

----------------------------------------------------------------
-- Decal placement
----------------------------------------------------------------
local function pickRandomTexture()
	local n = #dp.selectedDecals
	if n == 0 then return nil end
	return dp.selectedDecals[random(1, n)]
end

local function applyDecal(tex, wx, wz, sizeX, sizeZ, rotRad)
	if not CreateGroundDecal then return nil end
	local id = CreateGroundDecal()
	if not id then return nil end
	SetGroundDecalTexture(id, tex, true)
	-- Bind matching normal map, if the atlas has one registered for this main.
	-- Placing the main alone makes the decal unlit/flat; wiring the norm sibling
	-- gives proper per-pixel lighting that blends with the terrain.
	local norm = normPartnerByMain[tex]
	if norm then SetGroundDecalTexture(id, norm, false) end
	SetGroundDecalPosAndDims(id, wx, wz, sizeX, sizeZ)
	SetGroundDecalRotation(id, rotRad)
	if SetGroundDecalAlpha then SetGroundDecalAlpha(id, dp.alpha, 0) end
	if SetGroundDecalTint then SetGroundDecalTint(id, dp.tintR, dp.tintG, dp.tintB, dp.tintA) end
	if dp.alignToNormal and SetGroundDecalNormal then
		SetGroundDecalNormal(id, 0, 0, 0)
	end
	return id
end

local function pushUndoBatch(ids)
	if #ids == 0 then return end
	dp.redoStack = {}
	dp.undoStack[#dp.undoStack + 1] = { decalIDs = ids }
	while #dp.undoStack > MAX_UNDO do
		table.remove(dp.undoStack, 1)
	end
	dp.undoCount = #dp.undoStack
	dp.redoCount = 0
end

local function placeScatter(cx, cz)
	if #dp.selectedDecals == 0 then return end
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
			if passesSmartFilter(wx, wz) then
				local tex = pickRandomTexture()
				if tex then
					local sizeBase = dp.sizeMin + random() * (dp.sizeMax - dp.sizeMin)
					local rotDeg = dp.rotation + (random() * 2 - 1) * (dp.rotRandom * 1.8)
					local rotRad = rotDeg * pi / 180
					local id = applyDecal(tex, wx, wz, sizeBase, sizeBase, rotRad)
					if id then placed[#placed + 1] = id end
				end
			end
		end
	end
	pushUndoBatch(placed)
end

local function placePoint(cx, cz)
	if #dp.selectedDecals == 0 then return end
	if not passesSmartFilter(cx, cz) then return end
	local tex = pickRandomTexture()
	if not tex then return end
	local sizeBase = dp.sizeMin + random() * (dp.sizeMax - dp.sizeMin)
	local rotDeg = dp.rotation + (random() * 2 - 1) * (dp.rotRandom * 1.8)
	local id = applyDecal(tex, cx, cz, sizeBase, sizeBase, rotDeg * pi / 180)
	if id then pushUndoBatch({ id }) end
end

local function placeRemove(cx, cz)
	if not GetAllGroundDecals or not GetGroundDecalMiddlePos then return end
	local r = dp.radius
	local r2 = r * r
	local removed = 0
	for _, id in ipairs(GetAllGroundDecals()) do
		local dx, dz = GetGroundDecalMiddlePos(id)
		if dx then
			local ddx = dx - cx
			local ddz = dz - cz
			if ddx * ddx + ddz * ddz <= r2 then
				if DestroyGroundDecal(id) then removed = removed + 1 end
			end
		end
	end
	if removed > 0 then
		Echo("[Decal Placer] Removed " .. removed .. " decal(s)")
	end
end

-- Apply TerraformBrush grid-snap + symmetric fan-out to a placement call.
-- `fn(x, z)` is one of placeScatter / placePoint / placeRemove.
local function placeSymmetric(fn, cx, cz)
	local tb = WG.TerraformBrush
	local rot = dp.rotation or 0
	if tb and tb.getState then
		local st = tb.getState()
		if st.angleSnap then rot = st.rotationDeg or rot end
		if st.gridSnap and tb.snapWorld then
			cx, cz = tb.snapWorld(cx, cz, rot)
		end
		if st.symmetryActive and tb.getSymmetricPositions then
			local positions = tb.getSymmetricPositions(cx, cz, rot)
			if positions and #positions > 0 then
				for _, p in ipairs(positions) do fn(p.x, p.z) end
				return
			end
		end
	end
	fn(cx, cz)
end

local function decalUndo()
	local entry = dp.undoStack[#dp.undoStack]
	if not entry then return end
	dp.undoStack[#dp.undoStack] = nil
	for _, id in ipairs(entry.decalIDs) do
		DestroyGroundDecal(id)
	end
	dp.undoCount = #dp.undoStack
	-- redoStack would need re-creation info; skip redo for destructive ops
end

local function decalClearAll()
	if not GetAllGroundDecals then return end
	local n = 0
	for _, id in ipairs(GetAllGroundDecals()) do
		if DestroyGroundDecal(id) then n = n + 1 end
	end
	dp.undoStack = {}
	dp.redoStack = {}
	dp.undoCount = 0
	dp.redoCount = 0
	Echo("[Decal Placer] Cleared " .. n .. " decal(s)")
end

----------------------------------------------------------------
-- Activation / Mode
----------------------------------------------------------------
local function activate(mode)
	if WG.TerraformBrush then WG.TerraformBrush.deactivate() end
	if WG.WeatherBrush then WG.WeatherBrush.deactivate() end
	if WG.FeaturePlacer then WG.FeaturePlacer.deactivate() end
	dp.active = true
	dp.mode = mode
	if mode == "point" then
		dp.decalCount = 1
		dp.cadence = 1
	end
	buildDecalList()
	local labels = { scatter = "SCATTER", point = "POINT", remove = "REMOVE" }
	Echo("[Decal Placer] Mode: " .. (labels[mode] or mode) .. " | LMB place, RMB remove, /decalplaceroff to stop")
	return true
end

local function deactivate()
	if dp.active then Echo("[Decal Placer] Deactivated") end
	dp.active = false
	dp.mode = nil
	dp.dragging = false
	dp.lockedWorldX = nil
	dp.lockedWorldZ = nil
	return true
end

local function setMode(mode)
	if mode == "scatter" or mode == "point" or mode == "remove" then
		if not dp.active and WG.TerraformBrush then WG.TerraformBrush.deactivate() end
		if not dp.active and WG.WeatherBrush then WG.WeatherBrush.deactivate() end
		if not dp.active and WG.FeaturePlacer then WG.FeaturePlacer.deactivate() end
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
local function setShape(s)
	if s == "circle" or s == "square" or s == "hexagon" or s == "octagon" or s == "triangle" then
		dp.shape = s
	end
end
local function setRadius(r)   dp.radius = max(MIN_RADIUS, min(MAX_RADIUS, floor(r))) end
local function setRotation(d) dp.rotation = d % 360 end
local function rotate(step)   dp.rotation = (dp.rotation + step) % 360 end
local function setRotRandom(v) dp.rotRandom = max(0, min(100, floor(v))) end
local function setDecalCount(n) dp.decalCount = max(1, min(500, floor(n))) end
local function setCadence(v)  dp.cadence = max(1, min(1000, floor(v))) end
local function setDistribution(m) if m == "random" or m == "regular" or m == "clustered" then dp.distribution = m end end
local function setSmartEnabled(v) dp.smartEnabled = v and true or false end
local function setSmartFilter(k, v) if dp.smartFilters[k] ~= nil then dp.smartFilters[k] = v end end
local function setSizeMin(v)  dp.sizeMin = max(4, min(1024, floor(v))); if dp.sizeMin > dp.sizeMax then dp.sizeMax = dp.sizeMin end end
local function setSizeMax(v)  dp.sizeMax = max(4, min(1024, floor(v))); if dp.sizeMax < dp.sizeMin then dp.sizeMin = dp.sizeMax end end
local function setAlpha(v)    dp.alpha = max(0, min(1, v)) end
local function setTint(r, g, b, a)
	dp.tintR = max(0, min(1, r or dp.tintR))
	dp.tintG = max(0, min(1, g or dp.tintG))
	dp.tintB = max(0, min(1, b or dp.tintB))
	dp.tintA = max(0, min(1, a or dp.tintA))
end
local function setAlignToNormal(v) dp.alignToNormal = v and true or false end

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
		active        = dp.active,
		mode          = dp.mode,
		shape         = dp.shape,
		radius        = dp.radius,
		rotation      = dp.rotation,
		rotRandom     = dp.rotRandom,
		decalCount    = dp.decalCount,
		cadence       = dp.cadence,
		distribution  = dp.distribution,
		smartEnabled  = dp.smartEnabled,
		smartFilters  = dp.smartFilters,
		sizeMin       = dp.sizeMin,
		sizeMax       = dp.sizeMax,
		alpha         = dp.alpha,
		tintR         = dp.tintR,
		tintG         = dp.tintG,
		tintB         = dp.tintB,
		tintA         = dp.tintA,
		alignToNormal = dp.alignToNormal,
		selectedDecals = dp.selectedDecals,
		selectedSet    = dp.selectedSet,
		undoCount     = dp.undoCount,
		redoCount     = dp.redoCount,
	}
end

local function getDecalList()       buildDecalList(); return decalList end
local function getDecalCategories() buildDecalList(); return decalCategories end
local function getCategoryOrder()   return CATEGORY_ORDER end
local function getCategoryLabels()  return CATEGORY_LABELS end

----------------------------------------------------------------
-- Save / Load decal map
----------------------------------------------------------------
local function decalSave()
	if not GetAllGroundDecals then return end
	Spring.CreateDir(SAVE_DIR)
	local mapName = Game.mapName or "unknown"
	local timestamp = os.date("%Y%m%d_%H%M%S")
	local filename = SAVE_DIR .. mapName .. "_decals_" .. timestamp .. ".lua"
	local f = io.open(filename, "w")
	if not f then Echo("[Decal Placer] Cannot write " .. filename); return end
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
			f:write(string.format('\t{tex=%q, x=%.1f, z=%.1f, sx=%.1f, sz=%.1f, rot=%.4f},\n',
				tex, dx, dz, sx or 64, sz or 64, rot))
			n = n + 1
		end
	end
	f:write("}\n")
	f:close()
	Echo("[Decal Placer] Saved " .. n .. " decals to " .. filename)
end

local function decalLoad(filename)
	if not filename or filename == "" then
		local saves = VFS.DirList(SAVE_DIR, "*.lua", VFS.RAW) or {}
		if #saves == 0 then Echo("[Decal Placer] No saved decal files"); return end
		filename = saves[#saves]
	end
	-- Prefer loadfile (BAR's canonical pattern, see cmd_light_placer.load).
	-- io.open + loadstring occasionally fails inside the widget sandbox for
	-- files under SAVE_DIR; loadfile resolves the same path reliably.
	local fn, err = loadfile(filename)
	if not fn then
		-- Fallback: try io.open + loadstring in case the VFS path disagrees.
		local f = io.open(filename, "r")
		if not f then Echo("[Decal Placer] Cannot open " .. filename .. ": " .. tostring(err)); return end
		local content = f:read("*a")
		f:close()
		fn, err = loadstring(content, filename)
		if not fn then Echo("[Decal Placer] Parse error: " .. tostring(err)); return end
	end
	local ok, data = pcall(fn)
	if not ok or type(data) ~= "table" then
		Echo("[Decal Placer] Invalid file: " .. tostring(data))
		return
	end
	local placed = {}
	for _, d in ipairs(data) do
		if d.tex and d.x and d.z then
			local id = applyDecal(d.tex, d.x, d.z, d.sx or 64, d.sz or 64, d.rot or 0)
			if id then placed[#placed + 1] = id end
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
local function drawRegularPolygon(cx, cz, radius, angleDeg, sides)
	local step = 2 * pi / sides
	local off = angleDeg * pi / 180
	glBeginEnd(GL_LINE_LOOP, function()
		for i = 0, sides - 1 do
			local a = i * step + off
			local x = cx + radius * cos(a)
			local z = cz + radius * sin(a)
			glVertex(x, GetGroundHeight(x, z) + 4, z)
		end
	end)
end

local function drawSquareOutline(cx, cz, radius, angleDeg)
	local corners = { {-radius,-radius}, {radius,-radius}, {radius,radius}, {-radius,radius} }
	glBeginEnd(GL_LINE_LOOP, function()
		for i = 1, 4 do
			local rx, rz = rotatePoint(corners[i][1], corners[i][2], angleDeg)
			local wx, wz = cx + rx, cz + rz
			glVertex(wx, GetGroundHeight(wx, wz) + 4, wz)
		end
	end)
end

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
	if not cx then return end
	do
		local tb2 = WG.TerraformBrush
		local st2 = tb2 and tb2.getState and tb2.getState()
		if st2 and (st2.symmetryHoveringOrigin or st2.symmetryDraggingOrigin) then return end
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
	if dp.shape == "circle" then
		drawCircleOutline(cx, cz, dp.radius)
	elseif dp.shape == "square" then
		drawSquareOutline(cx, cz, dp.radius, dp.rotation)
	elseif dp.shape == "hexagon" then
		drawRegularPolygon(cx, cz, dp.radius, dp.rotation, 6)
	elseif dp.shape == "octagon" then
		drawRegularPolygon(cx, cz, dp.radius, dp.rotation, 8)
	elseif dp.shape == "triangle" then
		drawRegularPolygon(cx, cz, dp.radius, dp.rotation, 3)
	end
	glLineWidth(1)
	glColor(1, 1, 1, 1)
	glDepthTest(false)
end

----------------------------------------------------------------
-- Widget callins
----------------------------------------------------------------
function widget:Initialize()
	widgetHandler:AddAction("decalplacer", function(_, _, args)
		if args and args[1] then return activate(args[1]) end
		return activate("scatter")
	end, nil, "t")
	widgetHandler:AddAction("decalplacerscatter", function() return activate("scatter") end, nil, "t")
	widgetHandler:AddAction("decalplacerpoint",   function() return activate("point")   end, nil, "t")
	widgetHandler:AddAction("decalplacerremove",  function() return activate("remove")  end, nil, "t")
	widgetHandler:AddAction("decalplaceroff",     deactivate, nil, "t")

	WG.DecalPlacer = {
		getState              = getState,
		getDecalList          = getDecalList,
		getDecalCategories    = getDecalCategories,
		getCategoryOrder      = getCategoryOrder,
		getCategoryLabels     = getCategoryLabels,
		getNormalPartner      = getNormalPartner,
		setMode               = setMode,
		setShape              = setShape,
		setRadius             = setRadius,
		setRotation           = setRotation,
		rotate                = rotate,
		setRotRandom          = setRotRandom,
		setDecalCount         = setDecalCount,
		setCadence            = setCadence,
		setDistribution       = setDistribution,
		setSmartEnabled       = setSmartEnabled,
		setSmartFilter        = setSmartFilter,
		setSizeMin            = setSizeMin,
		setSizeMax            = setSizeMax,
		setAlpha              = setAlpha,
		setTint               = setTint,
		setAlignToNormal      = setAlignToNormal,
		selectDecal           = selectDecal,
		toggleDecal           = toggleDecal,
		clearSelectedDecals   = clearSelectedDecals,
		undo                  = decalUndo,
		clearAll              = decalClearAll,
		save                  = decalSave,
		load                  = decalLoad,
		listSaves             = listSavedDecalMaps,
		deactivate            = deactivate,
	}
end

function widget:Shutdown()
	WG.DecalPlacer = nil
	widgetHandler:RemoveAction("decalplacer")
	widgetHandler:RemoveAction("decalplacerscatter")
	widgetHandler:RemoveAction("decalplacerpoint")
	widgetHandler:RemoveAction("decalplacerremove")
	widgetHandler:RemoveAction("decalplaceroff")
end

function widget:IsAbove() return false end

function widget:KeyPress(key, mods)
	if not dp.active then return false end
	if key == 0x1B then deactivate(); return true end
	if mods.ctrl and key == 122 then -- Ctrl+Z
		decalUndo()
		return true
	end
	return false
end

function widget:MousePress(mx, my, button)
	if not dp.active or not dp.mode then return false end
	-- Defer to measure tool when active so decal placement doesn't consume the click
	do
		local tb = WG.TerraformBrush
		local st = tb and tb.getState and tb.getState() or nil
		if st and st.measureActive then return false end
		-- Defer to symmetry origin drag so terraform can grab the drag
		if st and st.symmetryActive then
			if st.symmetryPlacingOrigin or st.symmetryHoveringOrigin or st.symmetryDraggingOrigin then
				return false
			end
		end
	end
	if button == 1 then
		local wx, wz = getWorldMousePosition()
		if not wx then return false end
		dp.dragging = true
		dp.dragAction = "place"
		dp.lockedWorldX = wx
		dp.lockedWorldZ = wz
		dp.placeTimer = 0
		if dp.mode == "scatter" then placeSymmetric(placeScatter, wx, wz)
		elseif dp.mode == "point" then placeSymmetric(placePoint, wx, wz)
		elseif dp.mode == "remove" then placeSymmetric(placeRemove, wx, wz) end
		return true
	end
	if button == 3 then
		local wx, wz = getWorldMousePosition()
		if not wx then return false end
		dp.dragging = true
		dp.dragAction = "remove"
		dp.lockedWorldX = wx
		dp.lockedWorldZ = wz
		placeSymmetric(placeRemove, wx, wz)
		return true
	end
	return false
end

function widget:MouseRelease(_, _, button)
	if (button == 1 or button == 3) and dp.dragging then
		dp.dragging = false
		dp.dragAction = nil
		dp.lockedWorldX = nil
		dp.lockedWorldZ = nil
		return true
	end
	return false
end

function widget:MouseWheel(up, _)
	if not dp.active then return false end
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
		if up then setCadence(dp.cadence * 1.15)
		else setCadence(dp.cadence / 1.15) end
		return true
	end
	if ctrl then
		setRadius(dp.radius + (up and RADIUS_STEP or -RADIUS_STEP))
		return true
	end
	return false
end

function widget:Update(dt)
	if not dp.active then return end
	updateTimer = updateTimer + dt
	if updateTimer < UPDATE_INTERVAL then return end
	updateTimer = 0
	if dp.dragging and dp.dragAction == "place" then
		dp.placeTimer = dp.placeTimer + UPDATE_INTERVAL
		if dp.placeTimer >= getCadenceInterval() then
			dp.placeTimer = 0
			local wx, wz = getWorldMousePosition()
			if wx then
				if dp.mode == "scatter" then placeSymmetric(placeScatter, wx, wz)
				elseif dp.mode == "point" then placeSymmetric(placePoint, wx, wz) end
			end
		end
	elseif dp.dragging and dp.dragAction == "remove" then
		local wx, wz = getWorldMousePosition()
		if wx then placeSymmetric(placeRemove, wx, wz) end
	end
end

function widget:DrawWorld()
	if not dp.active then return end
	drawCurrentBrush()
end
