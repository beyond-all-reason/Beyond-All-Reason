function widget:GetInfo()
	return {
		name    = "Feature Placer",
		desc    = "Brush tool for placing, arranging, and removing map features",
		author  = "BARb",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

----------------------------------------------------------------
-- Localize engine calls
----------------------------------------------------------------
local Echo             = Spring.Echo
local GetMouseState    = Spring.GetMouseState
local GetModKeyState   = Spring.GetModKeyState
local GetKeyState      = Spring.GetKeyState
local TraceScreenRay   = Spring.TraceScreenRay
local GetGroundHeight  = Spring.GetGroundHeight
local GetGroundNormal  = Spring.GetGroundNormal
local GetGameFrame     = Spring.GetGameFrame
local SendLuaRulesMsg  = Spring.SendLuaRulesMsg
local GetAllFeatures   = Spring.GetAllFeatures
local GetFeaturePosition = Spring.GetFeaturePosition
local GetFeatureDefID  = Spring.GetFeatureDefID

local glColor     = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd  = gl.BeginEnd
local glVertex    = gl.Vertex
local glPushMatrix  = gl.PushMatrix
local glPopMatrix   = gl.PopMatrix
local glTranslate   = gl.Translate
local glDepthTest   = gl.DepthTest
local GL_TRIANGLES  = GL.TRIANGLES
local GL_LINES      = GL.LINES
local GL_LINE_LOOP  = GL.LINE_LOOP

----------------------------------------------------------------
-- Constants
----------------------------------------------------------------
local SCATTER_HEADER = "$feature_scatter$"
local POINT_HEADER   = "$feature_point$"
local REMOVE_HEADER  = "$feature_remove$"
local UNDO_HEADER    = "$feature_undo$"
local REDO_HEADER    = "$feature_redo$"
local SAVE_HEADER    = "$feature_save$"
local LOAD_HEADER    = "$feature_load$"
local CLEARALL_HEADER = "$feature_clearall$"

local SAVE_DIR = "Terraform Brush/FeatureMaps/"

local CIRCLE_SEGMENTS = 48
local DEFAULT_RADIUS  = 200
local MIN_RADIUS      = 8
local MAX_RADIUS      = 2000
local RADIUS_STEP     = 8
local ROTATION_STEP   = 3
local KEYSYMS_SPACE   = 0x20
local UPDATE_INTERVAL = 1 / 30
local GRID_SNAP_SIZE  = 48  -- matches build grid widget spacing (3 * 16 elmos)

local floor = math.floor
local max   = math.max
local min   = math.min
local cos   = math.cos
local sin   = math.sin
local pi    = math.pi
local sqrt  = math.sqrt

----------------------------------------------------------------
-- State (packed into table to conserve locals)
----------------------------------------------------------------
local fp = {
	active        = false,
	mode          = nil,       -- "scatter", "point", "remove"
	shape         = "circle",
	radius        = DEFAULT_RADIUS,
	rotation      = 0,
	rotRandom     = 100,   -- 0 = all same heading, 100 = fully random
	featureCount  = 10,
	cadence       = 50,        -- 1-1000 logarithmic (higher = faster)
	distribution  = "random",  -- "random", "regular", or "clustered"
	smartEnabled  = false,     -- terrain-aware filtering applied on top of distribution
	smartFilters  = {
		avoidWater   = true,   -- reject underwater positions (height < 0)
		avoidCliffs  = true,   -- reject terrain steeper than slopeMax degrees
		slopeMax     = 45,
		preferSlopes = false,  -- reject terrain flatter than slopeMin degrees
		slopeMin     = 10,
		altMinEnable = false,  -- reject terrain below altMin
		altMin       = 0,
		altMaxEnable = false,  -- reject terrain above altMax
		altMax       = 200,
	},
	selectedDefs  = {},        -- { defName1, defName2, ... }
	selectedSet   = {},        -- { [defName] = true } for quick lookup
	dragging      = false,
	dragAction    = nil,       -- "place" or "remove"
	lockedWorldX  = nil,
	lockedWorldZ  = nil,
	placeTimer    = 0,
	undoCount     = 0,
	redoCount     = 0,
}

local updateTimer = 0
local gridOverlay = false
local gridSnap = false
local gridShowing = false

----------------------------------------------------------------
-- Feature definition cache for asset library
----------------------------------------------------------------
local featureDefList = {}   -- sorted { {name=..., id=...}, ... }
local featureDefListBuilt = false
local featureCategories = {} -- { categoryName = { {name=..., id=...}, ... } }

local CATEGORY_ORDER = {
	"rocks", "trees", "bushes", "crystals", "christmas",
	"raptor", "armada_wrecks", "cortex_wrecks", "legion_wrecks", "other",
}

local CATEGORY_LABELS = {
	rocks = "Rocks",
	trees = "Trees",
	bushes = "Bushes & Plants",
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
	if name:find("_heap$") then return nil end
	if name:find("debris") then return nil end

	-- Christmas items
	if name:find("^candycane") or name:find("^xmascom") then return "christmas" end

	-- Raptor items
	if name:find("^raptor_egg") then return "raptor" end

	-- Crystals
	if name:find("^pilha_crystal") or name:find("^tiberium") then return "crystals" end

	-- Rocks
	if name:find("^rocks30_") or name:find("^prock%d") or name:find("^pdrock")
	   or name:find("^brock_") or name:find("^moonrock") or name:find("^rocksoar")
	   or name:find("^agorm_rock") or name:find("^slrock") or name:find("^rock%d")
	   or name:find("^pvolcanicrock") then
		return "rocks"
	end

	-- Trees (checked before bushes since some naming overlaps)
	if name:find("^treetype%d") or name:find("^ad0_pine") or name:find("^ad0_aleppo")
	   or name:find("^ad0_banyan") or name:find("^ad0_baobab") or name:find("^ad0_senegal")
	   or name:find("^allpinesb_") or name:find("^lowpoly_tree_") or name:find("^cedar_atlas")
	   or name:find("^btree") or name:find("^cluster") or name:find("^treecluster")
	   or name:find("^talltree") or name:find("^fir_tree_") or name:find("^fir_sapling")
	   or name:find("^hclus%d") or name:find("^hpalm%d") or name:find("^palmetto_")
	   or name:find("^artbirch") or name:find("^artmaple") or name:find("^artoak") then
		return "trees"
	end

	-- Bushes and small plants
	if name:find("^ad0_bush") or name:find("^artbush") or name:find("^peyote")
	   or name:find("^pedro") or name:find("^fern") or name:find("^cycas")
	   or name:find("^mushroom") then
		return "bushes"
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
	if featureDefListBuilt then return end
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
	table.sort(featureDefList, function(a, b) return a.name < b.name end)
	for _, cat in ipairs(CATEGORY_ORDER) do
		if featureCategories[cat] then
			table.sort(featureCategories[cat], function(a, b) return a.name < b.name end)
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
	if gridShowing then return end
	local bg = WG['buildinggrid']
	if bg and bg.setForceShow and gridForceShowDefID then
		bg.setForceShow("featureplacer", true, gridForceShowDefID)
		gridShowing = true
	end
end

local function hideBuildGrid()
	if not gridShowing then return end
	local bg = WG['buildinggrid']
	if bg and bg.setForceShow then
		bg.setForceShow("featureplacer", false)
		gridShowing = false
	end
end

local function snapToGrid(x, z)
	return floor(x / GRID_SNAP_SIZE + 0.5) * GRID_SNAP_SIZE,
	       floor(z / GRID_SNAP_SIZE + 0.5) * GRID_SNAP_SIZE
end

local function setGridOverlay(value)
	gridOverlay = value and true or false
end

local function setGridSnap(value)
	gridSnap = value and true or false
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
	return {{ x = wx, z = wz, rot = rot or 0 }}
end

----------------------------------------------------------------
-- Cadence → seconds between placements
----------------------------------------------------------------
local function getCadenceInterval()
	-- cadence 1-1000 (logarithmic slider): interval inversely proportional to rate
	return max(0.03, 2.0 / fp.cadence)
end

----------------------------------------------------------------
-- Send messages to gadget
----------------------------------------------------------------
local function sendScatterMessage(worldX, worldZ)
	if #fp.selectedDefs == 0 then return end
	local defList = table.concat(fp.selectedDefs, "|")
	local sf = fp.smartFilters
	local positions = getSymmetricPositions(worldX, worldZ, fp.rotation)
	for i = 1, #positions do
		local p = positions[i]
		local msg = SCATTER_HEADER
			.. defList .. " "
			.. floor(p.x) .. " "
			.. floor(p.z) .. " "
			.. fp.radius .. " "
			.. fp.shape .. " "
			.. p.rot .. " "
			.. fp.featureCount .. " "
			.. fp.distribution .. " "
			.. fp.rotRandom .. " "
			.. (fp.smartEnabled and "1" or "0") .. " "
			.. (sf.avoidWater   and "1" or "0") .. " "
			.. (sf.avoidCliffs  and "1" or "0") .. " "
			.. sf.slopeMax .. " "
			.. (sf.preferSlopes and "1" or "0") .. " "
			.. sf.slopeMin .. " "
			.. (sf.altMinEnable and tostring(floor(sf.altMin)) or "_") .. " "
			.. (sf.altMaxEnable and tostring(floor(sf.altMax)) or "_")
		SendLuaRulesMsg(msg)
	end
end

local function sendPointMessage(worldX, worldZ)
	if #fp.selectedDefs == 0 then return end
	local defList = table.concat(fp.selectedDefs, "|")
	local positions = getSymmetricPositions(worldX, worldZ, fp.rotation)
	for i = 1, #positions do
		local p = positions[i]
		local baseHeading = floor(p.rot / 360 * 65536) % 65536
		local spread = floor(fp.rotRandom / 100 * 32768)
		local heading = (baseHeading + math.random(-spread, spread)) % 65536
		local msg = POINT_HEADER
			.. defList .. " "
			.. floor(p.x) .. " "
			.. floor(p.z) .. " "
			.. heading
		SendLuaRulesMsg(msg)
	end
end

local function sendRemoveMessage(worldX, worldZ)
	local positions = getSymmetricPositions(worldX, worldZ, fp.rotation)
	for i = 1, #positions do
		local p = positions[i]
		local msg = REMOVE_HEADER
			.. floor(p.x) .. " "
			.. floor(p.z) .. " "
			.. fp.radius .. " "
			.. fp.shape .. " "
			.. p.rot
		SendLuaRulesMsg(msg)
	end
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

local function handleSaveBegin(_, _, count)
	saveBuffer = {}
	saveExpectedCount = count or 0
end

local function handleSaveData(_, _, dataStr)
	if not dataStr then return end
	saveBuffer[#saveBuffer + 1] = dataStr
end

local function handleSaveEnd(_, _, count)
	Spring.CreateDir(SAVE_DIR)
	local mapName = Game.mapName or "unknown"
	local timestamp = os.date("%Y%m%d_%H%M%S")
	local filename = SAVE_DIR .. mapName .. "_features_" .. timestamp .. ".lua"

	local file = io.open(filename, "w")
	if not file then
		Echo("[Feature Placer] Failed to open " .. filename .. " for writing")
		return
	end

	file:write("-- Feature map: " .. mapName .. "\n")
	file:write("-- Saved: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
	file:write("-- Features: " .. tostring(count or 0) .. "\n")
	file:write("return {\n")

	for _, batchStr in ipairs(saveBuffer) do
		for entry in batchStr:gmatch("[^|]+") do
			local parts = {}
			for word in entry:gmatch("%S+") do
				parts[#parts + 1] = word
			end
			local defName = parts[1]
			local x       = parts[2]
			local z       = parts[3]
			local heading = parts[4] or "0"
			if defName and x and z then
				file:write(string.format('\t{name=%q, x=%s, z=%s, heading=%s},\n', defName, x, z, heading))
			end
		end
	end

	file:write("}\n")
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

	local file = io.open(filename, "r")
	if not file then
		Echo("[Feature Placer] Cannot open " .. filename)
		return
	end
	local content = file:read("*a")
	file:close()

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

	-- Send features to gadget in batches
	local BATCH = 50
	local count = #data
	for i = 1, count, BATCH do
		local batch = {}
		for j = i, min(i + BATCH - 1, count) do
			local f = data[j]
			if f.name and f.x and f.z then
				batch[#batch + 1] = f.name .. " " .. floor(f.x) .. " " .. floor(f.z) .. " " .. (f.heading or 0)
			end
		end
		if #batch > 0 then
			SendLuaRulesMsg(LOAD_HEADER .. table.concat(batch, "|"))
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
		active       = fp.active,
		mode         = fp.mode,
		shape        = fp.shape,
		radius       = fp.radius,
		rotation     = fp.rotation,
		rotRandom    = fp.rotRandom,
		featureCount = fp.featureCount,
		cadence      = fp.cadence,
		distribution = fp.distribution,
		smartEnabled = fp.smartEnabled,
		smartFilters = fp.smartFilters,
		selectedDefs = fp.selectedDefs,
		selectedSet  = fp.selectedSet,
		undoCount    = fp.undoCount,
		redoCount    = fp.redoCount,
		gridOverlay  = gridOverlay,
		gridSnap     = gridSnap,
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
		{  radius, -radius },
		{  radius,  radius },
		{ -radius,  radius },
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
local GRID_STEP = 24   -- elmos between sample points

-- Check if a point passes the current smart filter constraints
local function isPointValid(px, pz, sf)
	local h = GetGroundHeight(px, pz)
	local _, ny = GetGroundNormal(px, pz)
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

-- Check if a local-space point is inside the brush shape
local function isInsideBrush(lx, lz, radius, shape)
	if shape == "circle" then
		return (lx * lx + lz * lz) <= radius * radius
	elseif shape == "square" then
		return math.abs(lx) <= radius and math.abs(lz) <= radius
	elseif shape == "hexagon" then
		local ax, az = math.abs(lx), math.abs(lz)
		local apothem = radius * cos(pi / 6)
		if az > apothem then return false end
		if ax > radius then return false end
		return ax * cos(pi / 6) + az * sin(pi / 6) <= apothem
	elseif shape == "octagon" then
		local ax, az = math.abs(lx), math.abs(lz)
		local cut = radius * sin(pi / 8)
		local side = radius * cos(pi / 8)
		if ax > side or az > side then return false end
		return (ax + az) <= (side + cut)
	elseif shape == "triangle" then
		local dist = sqrt(lx * lx + lz * lz)
		if dist < 0.001 then return true end
		local angle = math.atan2(lz, lx)
		if angle < 0 then angle = angle + 2 * pi end
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
		local pts = { {-radius,-radius}, {radius,-radius}, {radius,radius}, {-radius,radius} }
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
	if not sf.altMinEnable and not sf.altMaxEnable then return end

	local corners = getShapeCorners(shape, radius, angleDeg)
	if #corners == 0 then return end

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
	if not fp.active then return false end

	if key == 0x1B then -- Escape
		deactivate()
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
	if not fp.active or not fp.mode then return false end

	-- Defer to measure / symmetry origin tools when active
	local tb = WG.TerraformBrush
	if tb and tb.getState then
		local st = tb.getState()
		if st and st.measureActive then return false end
		if st and st.symmetryActive then
			if st.symmetryPlacingOrigin or st.symmetryHoveringOrigin or st.symmetryDraggingOrigin then
				return false
			end
		end
	end

	if button == 1 then
		local worldX, worldZ = getWorldMousePosition()
		if not worldX then return false end
		if gridSnap then worldX, worldZ = snapToGrid(worldX, worldZ) end

		fp.dragging = true
		fp.dragAction = "place"
		fp.lockedWorldX = worldX
		fp.lockedWorldZ = worldZ
		fp.placeTimer = 0

		-- Perform initial placement
		if fp.mode == "scatter" then
			sendScatterMessage(worldX, worldZ)
		elseif fp.mode == "point" then
			sendPointMessage(worldX, worldZ)
		elseif fp.mode == "remove" then
			sendRemoveMessage(worldX, worldZ)
		end

		return true
	end

	-- Right-click removes features regardless of current mode
	if button == 3 then
		local worldX, worldZ = getWorldMousePosition()
		if not worldX then return false end
		if gridSnap then worldX, worldZ = snapToGrid(worldX, worldZ) end

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

function widget:MouseRelease(mx, my, button)
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
	if not fp.active then return false end

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
			if newC < fp.cadence + 1 then newC = fp.cadence + 1 end
			setCadence(newC)
		else
			local newC = fp.cadence / 1.15
			if newC > fp.cadence - 1 then newC = fp.cadence - 1 end
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
	if not fp.active then return end

	if not fp.dragging then return end

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
	if fp.placeTimer < interval then return end
	fp.placeTimer = fp.placeTimer - interval

	local worldX, worldZ = getWorldMousePosition()
	if not worldX then return end
	if gridSnap then worldX, worldZ = snapToGrid(worldX, worldZ) end

	fp.lockedWorldX = worldX
	fp.lockedWorldZ = worldZ

	if fp.dragAction == "remove" then
		sendRemoveMessage(worldX, worldZ)
	elseif fp.mode == "scatter" then
		sendScatterMessage(worldX, worldZ)
	elseif fp.mode == "point" then
		sendPointMessage(worldX, worldZ)
	elseif fp.mode == "remove" then
		sendRemoveMessage(worldX, worldZ)
	end
end

----------------------------------------------------------------
-- DrawWorld — brush outline
----------------------------------------------------------------
function widget:DrawWorld()
	if not fp.active or not fp.mode then
		hideBuildGrid()
		return
	end

	local worldX, worldZ = getWorldMousePosition()
	if not worldX then return end

	-- Grid snap + visual
	if gridSnap then
		worldX, worldZ = snapToGrid(worldX, worldZ)
		showBuildGrid()
	elseif gridOverlay then
		showBuildGrid()
	else
		hideBuildGrid()
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
-- Initialize / Shutdown
----------------------------------------------------------------
function widget:Initialize()
	widgetHandler:AddAction("featureplacer", function(_, _, args)
		if args and args[1] then
			return activate(args[1])
		end
		return activate("scatter")
	end, nil, "t")
	widgetHandler:AddAction("featureplacerscatter", function() return activate("scatter") end, nil, "t")
	widgetHandler:AddAction("featureplacerpoint",   function() return activate("point") end, nil, "t")
	widgetHandler:AddAction("featureplacerremove",  function() return activate("remove") end, nil, "t")
	widgetHandler:AddAction("featureplaceroff",     deactivate, nil, "t")

	buildFeatureDefList()

	-- Expose API
	WG.FeaturePlacer = {
		getState            = getState,
		getFeatureDefList   = getFeatureDefList,
		getFeatureCategories = getFeatureCategories,
		getCategoryOrder     = getCategoryOrder,
		getCategoryLabels    = getCategoryLabels,
		setMode             = setMode,
		setShape            = setShape,
		setRadius           = setRadius,
		setRotation         = setRotation,
		rotate              = rotate,
		setRotRandom        = setRotRandom,
		setFeatureCount     = setFeatureCount,
		setCadence          = setCadence,
		setDistribution     = setDistribution,
		setSmartEnabled     = setSmartEnabled,
		setSmartFilter      = setSmartFilter,
		selectFeature       = selectFeature,
		toggleFeature       = toggleFeature,
		clearSelectedFeatures = clearSelectedFeatures,
		undo                = featureUndo,
		redo                = featureRedo,
		save                = featureSave,
		load                = featureLoad,
		listSaves           = listSavedFeatureMaps,
		clearAll            = featureClearAll,
		setGridOverlay      = setGridOverlay,
		setGridSnap         = setGridSnap,
		deactivate          = deactivate,
	}

	widgetHandler:RegisterGlobal("feature_placer_history", handleHistoryUpdate)
	widgetHandler:RegisterGlobal("feature_save_begin", handleSaveBegin)
	widgetHandler:RegisterGlobal("feature_save_data", handleSaveData)
	widgetHandler:RegisterGlobal("feature_save_end", handleSaveEnd)
end

function widget:Shutdown()
	hideBuildGrid()
	WG.FeaturePlacer = nil
	widgetHandler:DeregisterGlobal("feature_placer_history")
	widgetHandler:DeregisterGlobal("feature_save_begin")
	widgetHandler:DeregisterGlobal("feature_save_data")
	widgetHandler:DeregisterGlobal("feature_save_end")
	widgetHandler:RemoveAction("featureplacer")
	widgetHandler:RemoveAction("featureplacerscatter")
	widgetHandler:RemoveAction("featureplacerpoint")
	widgetHandler:RemoveAction("featureplacerremove")
	widgetHandler:RemoveAction("featureplaceroff")
end
