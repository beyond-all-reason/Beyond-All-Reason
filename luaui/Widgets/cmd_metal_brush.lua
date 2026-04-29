local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Metal Brush",
		desc = "Paint and stamp metal deposits on the map. Requires /cheat.",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local MSG_PAINT = "$metal_paint$"
local MSG_STAMP = "$metal_stamp$"
local MSG_CLEAR = "$metal_clear$"
local MSG_LOAD  = "$metal_load$"
local MSG_UNDO  = "$metal_undo$"
local MSG_REDO  = "$metal_redo$"
local CHEAT_TAG = "$c$"

local function SendLuaRulesMsg(header, payload)
	local tag = Spring.IsCheatingEnabled() and CHEAT_TAG or ""
	Spring.SendLuaRulesMsg(header .. tag .. payload)
end

local GetMouseState = Spring.GetMouseState
local TraceScreenRay = Spring.TraceScreenRay
local GetGroundHeight = Spring.GetGroundHeight
local GetMetalAmount = Spring.GetMetalAmount
local GetMetalMapSize = Spring.GetMetalMapSize
local WorldToScreenCoords = Spring.WorldToScreenCoords
local Echo = Spring.Echo
local IsCheatingEnabled = Spring.IsCheatingEnabled

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glPolygonOffset = gl.PolygonOffset
local glText = gl.Text
local GL_LINE_LOOP = GL.LINE_LOOP
local GL_LINES = GL.LINES
local GL_LINE_STRIP = GL.LINE_STRIP
local GL_QUADS = GL.QUADS
local GL_POINTS = GL.POINTS

local floor = math.floor
local max = math.max
local min = math.min
local cos = math.cos
local sin = math.sin
local abs = math.abs
local pi = math.pi
local sqrt = math.sqrt
local format = string.format

local METAL_SQ = Game.metalMapSquareSize or 16
local EXTRACTOR_RADIUS = Game.extractorRadius or 90
local EXTRACTOR_RADIUS_SQ = EXTRACTOR_RADIUS * EXTRACTOR_RADIUS
local CIRCLE_SEGMENTS = 48
local UPDATE_INTERVAL = 0.05
local MIN_METAL_VALUE = 0.01
local MAX_METAL_VALUE = 50.0
local DEFAULT_METAL_VALUE = 2.0
local DEFAULT_RADIUS = METAL_SQ + METAL_SQ * 0.5  -- 3x3 metal pixels (n=1)
local SAVE_DIR = "Terraform Brush/MetalMaps/"

local CACHE_REBUILD_THROTTLE   = 0.25
local CACHE_REBUILD_DELAY      = 0.12  -- wait for gadget RecvLuaMsg to apply SetMetalAmount
local cacheRebuildHoldUntil    = 0     -- os.clock() threshold; don't rebuild before this

-- State
local active = false
local subMode = "stamp"       -- "paint" or "stamp"
local metalValue = DEFAULT_METAL_VALUE
local painting = false
local paintButton = 0         -- 1 = LMB (raise), 3 = RMB (lower/erase)
local lastPaintTime = 0

local function getSharedState()
	if WG.TerraformBrush then
		local st = WG.TerraformBrush.getState()
		return {
			radius = st.radius or DEFAULT_RADIUS,
			shape = st.shape or "circle",
			rotationDeg = st.rotationDeg or 0,
			curve = st.curve or 1.0,
			intensity = st.intensity or 1.0,
			gridSnap = st.gridSnap and true or false,
		}
	end
	return {
		radius = DEFAULT_RADIUS,
		shape = "circle",
		rotationDeg = 0,
		curve = 1.0,
		intensity = 1.0,
		gridSnap = false,
	}
end

-- Snap a world position to the nearest metal map square centre
local function snapToMetalGrid(wx, wz)
	return floor(wx / METAL_SQ) * METAL_SQ + METAL_SQ * 0.5,
	       floor(wz / METAL_SQ) * METAL_SQ + METAL_SQ * 0.5
end

local function getWorldPos()
	local mx, my = GetMouseState()
	local kind, pos = TraceScreenRay(mx, my, true)
	if kind == "ground" then
		return pos[1], pos[3]
	end
	return nil, nil
end

local function sendPaintMessage(worldX, worldZ)
	local ss = getSharedState()
	local direction = (paintButton == 1) and 1 or -1
	local tb = WG.TerraformBrush
	local positions
	if ss.gridSnap then
		worldX, worldZ = snapToMetalGrid(worldX, worldZ)
	elseif tb and tb.snapWorld then
		worldX, worldZ = tb.snapWorld(worldX, worldZ, ss.rotationDeg)
	end
	if tb and tb.getSymmetricPositions then
		positions = tb.getSymmetricPositions(worldX, worldZ, ss.rotationDeg)
	end
	if not positions or #positions == 0 then
		positions = { { x = worldX, z = worldZ, rot = ss.rotationDeg } }
	end
	for i = 1, #positions do
		local p = positions[i]
		local payload = direction .. " "
			.. floor(p.x) .. " "
			.. floor(p.z) .. " "
			.. ss.radius .. " "
			.. ss.shape .. " "
			.. (p.rot or ss.rotationDeg) .. " "
			.. format("%.1f", ss.curve) .. " "
			.. format("%.1f", ss.intensity) .. " "
			.. format("%.2f", metalValue)
		SendLuaRulesMsg(MSG_PAINT, payload)
	end
	spotsCacheDirty = true
	clusterCacheDirty = true
	overlayListDirty = true
	clusterVisDirty = true
	balanceAxisSumsDirty = true
	cacheRebuildHoldUntil = os.clock() + CACHE_REBUILD_DELAY
	lastCacheBuildClock   = 0
end

local function sendStampMessage(worldX, worldZ)
	local ss = getSharedState()
	local direction = (paintButton == 3) and -1 or 1
	local tb = WG.TerraformBrush
	local positions
	if ss.gridSnap then
		worldX, worldZ = snapToMetalGrid(worldX, worldZ)
	elseif tb and tb.snapWorld then
		worldX, worldZ = tb.snapWorld(worldX, worldZ, ss.rotationDeg)
	end
	if tb and tb.getSymmetricPositions then
		positions = tb.getSymmetricPositions(worldX, worldZ, ss.rotationDeg)
	end
	if not positions or #positions == 0 then
		positions = { { x = worldX, z = worldZ, rot = ss.rotationDeg } }
	end
	for i = 1, #positions do
		local p = positions[i]
		local payload = floor(p.x) .. " "
			.. floor(p.z) .. " "
			.. ss.radius .. " "
			.. format("%.2f", metalValue) .. " "
			.. ss.shape .. " "
			.. (p.rot or ss.rotationDeg) .. " "
			.. direction
		SendLuaRulesMsg(MSG_STAMP, payload)
	end
	spotsCacheDirty = true
	clusterCacheDirty = true
	overlayListDirty = true
	clusterVisDirty = true
	balanceAxisSumsDirty = true
	cacheRebuildHoldUntil = os.clock() + CACHE_REBUILD_DELAY
	lastCacheBuildClock   = 0
end

-- ============================================================
-- Drawing
-- ============================================================

local function drawShapeOutline(worldX, worldZ, radius, shape, angleDeg)
	if shape == "circle" then
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 0, CIRCLE_SEGMENTS - 1 do
				local angle = (i / CIRCLE_SEGMENTS) * 2 * pi
				local x = worldX + radius * cos(angle)
				local z = worldZ + radius * sin(angle)
				glVertex(x, GetGroundHeight(x, z) + 2, z)
			end
		end)
	else
		local sides = 4
		if shape == "hexagon" then sides = 6
		elseif shape == "octagon" then sides = 8 end
		-- square/hexagon isInsideShape uses inradius (center-to-edge = radius);
		-- offset vertices by half-step and scale to circumradius so outline matches painted area.
		-- octagon isInsideShape uses circumradius, so no correction needed.
		local angleOffset = (shape ~= "octagon") and (pi / sides) or 0
		local outlineRadius = (shape ~= "octagon") and (radius / cos(pi / sides)) or radius
		local angleRad = (angleDeg or 0) * pi / 180
		local c, s = cos(angleRad), sin(angleRad)
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 0, sides - 1 do
				local a = (i / sides) * 2 * pi + angleOffset
				local dx0, dz0 = outlineRadius * cos(a), outlineRadius * sin(a)
				local dx = dx0 * c - dz0 * s
				local dz = dx0 * s + dz0 * c
				local x, z = worldX + dx, worldZ + dz
				glVertex(x, GetGroundHeight(x, z) + 2, z)
			end
		end)
	end
end

local function drawMetalOverlay(worldX, worldZ, radius)
	local halfSq = METAL_SQ * 0.5
	local mxMin = max(0, floor((worldX - radius - METAL_SQ) / METAL_SQ))
	local mxMax = floor((worldX + radius + METAL_SQ) / METAL_SQ)
	local mzMin = max(0, floor((worldZ - radius - METAL_SQ) / METAL_SQ))
	local mzMax = floor((worldZ + radius + METAL_SQ) / METAL_SQ)

	local mmX, mmZ = GetMetalMapSize()
	mxMax = min(mxMax, mmX - 1)
	mzMax = min(mzMax, mmZ - 1)

	-- Cap to prevent excessive draw calls
	if (mxMax - mxMin + 1) * (mzMax - mzMin + 1) > 4000 then return end

	glPolygonOffset(-2, -2)
	for mz = mzMin, mzMax do
		local wz = mz * METAL_SQ + halfSq
		for mx = mxMin, mxMax do
			local amount = GetMetalAmount(mx, mz)
			if amount > 0.01 then
				local wx = mx * METAL_SQ + halfSq
				local brightness = min(1.0, amount / 120)
				glColor(0.1, 0.4 + brightness * 0.6, 0.1, 0.35 + brightness * 0.3)
				local y = GetGroundHeight(wx, wz) + 0.5
				glBeginEnd(GL_QUADS, function()
					glVertex(wx - halfSq, y, wz - halfSq)
					glVertex(wx + halfSq, y, wz - halfSq)
					glVertex(wx + halfSq, y, wz + halfSq)
					glVertex(wx - halfSq, y, wz + halfSq)
				end)
			end
		end
	end
	glPolygonOffset(false)
end

local function drawCursorInfo(worldX, worldZ)
	-- Sum metal within extractor radius (predicted mex "spot worth" at baseline T1)
	local cx = floor(worldX / METAL_SQ)
	local cz = floor(worldZ / METAL_SQ)
	local cellRange = floor(EXTRACTOR_RADIUS / METAL_SQ) + 1
	local mmX, mmZ = GetMetalMapSize()
	local spotMetal = 0
	local halfSq = METAL_SQ * 0.5
	for dz = -cellRange, cellRange do
		local mz = cz + dz
		if mz >= 0 and mz < mmZ then
			local worldDz = (mz * METAL_SQ + halfSq) - worldZ
			for dx = -cellRange, cellRange do
				local mx = cx + dx
				if mx >= 0 and mx < mmX then
					local worldDx = (mx * METAL_SQ + halfSq) - worldX
					if worldDx * worldDx + worldDz * worldDz < EXTRACTOR_RADIUS_SQ then
						spotMetal = spotMetal + GetMetalAmount(mx, mz)
					end
				end
			end
		end
	end

	local sx, sy = WorldToScreenCoords(worldX, GetGroundHeight(worldX, worldZ), worldZ)

	local text
	if subMode == "stamp" then
		text = format("STAMP: %.1f  [spot: %.2f]", metalValue, spotMetal * 0.001)
	else
		text = format("Metal: %.1f  [spot: %.2f]", metalValue, spotMetal * 0.001)
	end

	glColor(0, 0, 0, 0.92)
	glText(text, sx + 2, sy + 18, 24, "co")
	glColor(1, 1, 1, 1.0)
	glText(text, sx, sy + 20, 24, "co")
end

-- ============================================================
-- Metal Map Save
-- ============================================================

local function saveMetalMap()
	Spring.CreateDir(SAVE_DIR)
	local mmX, mmZ = GetMetalMapSize()
	local mapName = Game.mapName or "unknown"
	local filename = SAVE_DIR .. mapName .. "_metalmap.lua"

	local lines = {}
	lines[#lines + 1] = "-- Metal map data for " .. mapName
	lines[#lines + 1] = "-- Generated by Metal Brush"
	lines[#lines + 1] = "-- Metalmap size: " .. mmX .. " x " .. mmZ .. "  squareSize: " .. METAL_SQ
	lines[#lines + 1] = "return {"
	lines[#lines + 1] = "  squareSize = " .. METAL_SQ .. ","
	lines[#lines + 1] = "  width = " .. mmX .. ","
	lines[#lines + 1] = "  height = " .. mmZ .. ","
	lines[#lines + 1] = "  spots = {"

	local spotCount = 0
	for mz = 0, mmZ - 1 do
		for mx = 0, mmX - 1 do
			local amount = GetMetalAmount(mx, mz)
			if amount > 0.001 then
				local wx = mx * METAL_SQ + METAL_SQ * 0.5
				local wz = mz * METAL_SQ + METAL_SQ * 0.5
				lines[#lines + 1] = "    {x=" .. format("%.0f", wx)
					.. ",z=" .. format("%.0f", wz)
					.. ",mx=" .. mx .. ",mz=" .. mz
					.. ",amount=" .. format("%.3f", amount) .. "},"
				spotCount = spotCount + 1
			end
		end
	end

	lines[#lines + 1] = "  },"
	lines[#lines + 1] = "}"

	local content = table.concat(lines, "\n")
	local file = io.open(filename, "w")
	if file then
		file:write(content)
		file:close()
		Echo("[Metal Brush] Saved " .. spotCount .. " metal pixels to: " .. filename)
	else
		Echo("[Metal Brush] ERROR: Could not save to " .. filename)
	end
end

local function loadMetalMap()
	local mapName = Game.mapName or "unknown"
	local filename = SAVE_DIR .. mapName .. "_metalmap.lua"

	local chunk, err = loadfile(filename)
	if not chunk then
		Echo("[Metal Brush] No saved metal map found: " .. filename)
		return
	end

	local ok, data = pcall(chunk)
	if not ok or type(data) ~= "table" or not data.spots then
		Echo("[Metal Brush] ERROR: Invalid metal map file: " .. filename)
		return
	end

	-- First clear everything
	SendLuaRulesMsg(MSG_CLEAR, "")

	-- Then load spots in batches to avoid message size limits
	local BATCH = 100
	local spots = data.spots
	local parts = {}
	local batchCount = 0

	for i = 1, #spots do
		local s = spots[i]
		if s.mx and s.mz and s.amount then
			parts[#parts + 1] = s.mx
			parts[#parts + 1] = s.mz
			parts[#parts + 1] = format("%.3f", s.amount)
			batchCount = batchCount + 1

			if batchCount >= BATCH then
				SendLuaRulesMsg(MSG_LOAD, table.concat(parts, " "))
				parts = {}
				batchCount = 0
			end
		end
	end

	if batchCount > 0 then
		SendLuaRulesMsg(MSG_LOAD, table.concat(parts, " "))
	end

	Echo("[Metal Brush] Loaded " .. #spots .. " metal spots from: " .. filename)
end

local function clearMetalMap()
	SendLuaRulesMsg(MSG_CLEAR, "")
	Echo("[Metal Brush] Cleared all metal from map")
end

-- ============================================================
-- Metal Map Analysis: whole-map overlay, clustering, lasso
-- ============================================================

local DEFAULT_CLUSTER_RADIUS = 256

local mapOverlay = false
local MAP_OVERLAY_DIM = 0.45  -- darkness applied to map while overlay is active
local savedDarknessBeforeOverlay = nil  -- non-nil while we've applied overlay dim
local clusterCounter = false
local clusterRadius = DEFAULT_CLUSTER_RADIUS
local lassoActive = false
local lassoPoints = {}       -- in-progress polygon (not yet committed)
local lassos = {}            -- array of { points = {...}, total = number } committed loops

-- Free-draw (drag-while-held) lasso tracking
local lassoDragStartSx, lassoDragStartSy = nil, nil
local lassoDragDetected = false
local LASSO_DRAG_THRESHOLD_PX = 6
local LASSO_FREEDRAW_MIN_SPACING_SQ = 24 * 24 -- world elmos^2 between appended points

local spotsCache = nil
local spotsCacheDirty = true
local clusterCache = nil
local clusterCacheRadius = -1
local clusterCacheDirty = true
local overlayList = nil
local overlayListDirty = true
local clusterVisList = nil
local clusterVisDirty = true
local lastCacheBuildClock = 0

local function invalidateMetalCaches()
	spotsCacheDirty = true
	clusterCacheDirty = true
	overlayListDirty = true
	clusterVisDirty = true
	cacheRebuildHoldUntil = os.clock() + CACHE_REBUILD_DELAY
	lastCacheBuildClock   = 0  -- once hold elapses, bypass throttle for immediate rebuild
end

local function buildSpotCache()
	local mmX, mmZ = GetMetalMapSize()
	local out = {}
	local halfSq = METAL_SQ * 0.5
	for mz = 0, mmZ - 1 do
		local wz = mz * METAL_SQ + halfSq
		for mx = 0, mmX - 1 do
			local amt = GetMetalAmount(mx, mz)
			if amt > 0.01 then
				out[#out + 1] = { mx = mx, mz = mz, wx = mx * METAL_SQ + halfSq, wz = wz, amount = amt }
			end
		end
	end
	spotsCache = out
	spotsCacheDirty = false
	lastCacheBuildClock = os.clock()
end

local function ensureSpotCache()
	if os.clock() < cacheRebuildHoldUntil then return end  -- waiting for gadget to apply paint
	if not spotsCache then
		buildSpotCache()
	elseif spotsCacheDirty and (os.clock() - lastCacheBuildClock) > CACHE_REBUILD_THROTTLE then
		buildSpotCache()
	end
end

local function buildClusters(radius)
	ensureSpotCache()
	local r2 = radius * radius
	local clusters = {}
	for i = 1, #spotsCache do
		local s = spotsCache[i]
		local best, bestD2 = nil, r2
		for ci = 1, #clusters do
			local c = clusters[ci]
			local dx = s.wx - c.cx
			local dz = s.wz - c.cz
			local d2 = dx * dx + dz * dz
			if d2 < bestD2 then
				bestD2 = d2
				best = ci
			end
		end
		if best then
			local c = clusters[best]
			c.totalAmount = c.totalAmount + s.amount
			c.count = c.count + 1
			c.sumX = c.sumX + s.wx * s.amount
			c.sumZ = c.sumZ + s.wz * s.amount
			c.sumW = c.sumW + s.amount
			c.cx = c.sumX / c.sumW
			c.cz = c.sumZ / c.sumW
			c.members[#c.members + 1] = i
			s.cluster = best
		else
			clusters[#clusters + 1] = {
				cx = s.wx, cz = s.wz,
				sumX = s.wx * s.amount, sumZ = s.wz * s.amount, sumW = s.amount,
				totalAmount = s.amount, count = 1,
				members = { i },
			}
			s.cluster = #clusters
		end
	end
	clusterCache = clusters
	clusterCacheRadius = radius
	clusterCacheDirty = false
	clusterVisDirty = true
end

local function ensureClusters()
	if not clusterCache or clusterCacheDirty or clusterCacheRadius ~= clusterRadius then
		buildClusters(clusterRadius)
	end
end

-- Convex hull (Andrew's monotone chain) on an array of {x,z} points.
local function convexHull2D(pts)
	local n = #pts
	if n < 3 then return pts end
	local sorted = {}
	for i = 1, n do sorted[i] = pts[i] end
	table.sort(sorted, function(a, b)
		if a.x == b.x then return a.z < b.z end
		return a.x < b.x
	end)
	local function cross(o, a, b)
		return (a.x - o.x) * (b.z - o.z) - (a.z - o.z) * (b.x - o.x)
	end
	local lower = {}
	for i = 1, n do
		while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], sorted[i]) <= 0 do
			lower[#lower] = nil
		end
		lower[#lower + 1] = sorted[i]
	end
	local upper = {}
	for i = n, 1, -1 do
		while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], sorted[i]) <= 0 do
			upper[#upper] = nil
		end
		upper[#upper + 1] = sorted[i]
	end
	lower[#lower] = nil
	upper[#upper] = nil
	for i = 1, #upper do lower[#lower + 1] = upper[i] end
	return lower
end

-- Color palette for clusters (HSV → RGB rotated by cluster id for contrast).
local function clusterColor(idx)
	local golden = 0.61803398875
	local h = (idx * golden) % 1.0
	-- HSV (h, 0.65, 1.0) → RGB
	local s, v = 0.70, 1.0
	local i = floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)
	local im = i % 6
	if im == 0 then return v, t, p
	elseif im == 1 then return q, v, p
	elseif im == 2 then return p, v, t
	elseif im == 3 then return p, q, v
	elseif im == 4 then return t, p, v
	else return v, p, q end
end

local function buildClusterVisList()
	ensureClusters()
	if clusterCacheDirty then return end -- still throttled
	if clusterVisList then gl.DeleteList(clusterVisList); clusterVisList = nil end
	local spots = spotsCache
	local clusters = clusterCache
	if not spots or not clusters or #clusters == 0 then
		clusterVisDirty = false
		return
	end
	local halfSq = METAL_SQ * 0.5
	clusterVisList = gl.CreateList(function()
		glPolygonOffset(-3, -3)
		-- 1) Per-cluster colored filled quads on metal pixels
		for ci = 1, #clusters do
			local c = clusters[ci]
			local r, g, b = clusterColor(ci)
			glColor(r, g, b, 0.42)
			local mem = c.members
			glBeginEnd(GL_QUADS, function()
				for mi = 1, #mem do
					local s = spots[mem[mi]]
					local wx, wz = s.wx, s.wz
					local y = GetGroundHeight(wx, wz) + 0.6
					glVertex(wx - halfSq, y, wz - halfSq)
					glVertex(wx + halfSq, y, wz - halfSq)
					glVertex(wx + halfSq, y, wz + halfSq)
					glVertex(wx - halfSq, y, wz + halfSq)
				end
			end)
		end
		glPolygonOffset(false)
		-- 2) Convex hull outline per cluster (only if >= 3 spots)
		glLineWidth(2)
		for ci = 1, #clusters do
			local c = clusters[ci]
			if #c.members >= 3 then
				local pts = {}
				local mem = c.members
				for mi = 1, #mem do
					local s = spots[mem[mi]]
					pts[#pts + 1] = { x = s.wx, z = s.wz }
				end
				local hull = convexHull2D(pts)
				if #hull >= 3 then
					local r, g, b = clusterColor(ci)
					glColor(r, g, b, 0.95)
					glBeginEnd(GL_LINE_LOOP, function()
						for i = 1, #hull do
							local p = hull[i]
							glVertex(p.x, GetGroundHeight(p.x, p.z) + 4, p.z)
						end
					end)
				end
			end
		end
		glLineWidth(1)
		glColor(1, 1, 1, 1)
	end)
	clusterVisDirty = false
end

local function pointInPoly(px, pz, pts)
	local n = #pts
	if n < 3 then return false end
	local inside = false
	local j = n
	for i = 1, n do
		local xi, zi = pts[i].x, pts[i].z
		local xj, zj = pts[j].x, pts[j].z
		if ((zi > pz) ~= (zj > pz)) and (px < (xj - xi) * (pz - zi) / (zj - zi + 1e-9) + xi) then
			inside = not inside
		end
		j = i
	end
	return inside
end

local function computePointsSum(points)
	if not points or #points < 3 then return 0 end
	ensureSpotCache()
	local total = 0
	for i = 1, #spotsCache do
		local s = spotsCache[i]
		if pointInPoly(s.wx, s.wz, points) then
			total = total + s.amount
		end
	end
	return total * 0.001
end

local function lassoGrandTotal()
	local t = 0
	for i = 1, #lassos do t = t + (lassos[i].total or 0) end
	return t
end

-- Commit current in-progress polygon to the lassos list if it has enough
-- points. Always resets lassoPoints so the next click starts a new loop.
local function commitCurrentLasso()
	if #lassoPoints >= 3 then
		local pts = {}
		for i = 1, #lassoPoints do pts[i] = lassoPoints[i] end
		lassos[#lassos + 1] = { points = pts, total = computePointsSum(pts) }
	end
	lassoPoints = {}
end

-- Refresh every committed lasso's total (call after the spot cache changes).
local function recomputeAllLassoTotals()
	for i = 1, #lassos do
		lassos[i].total = computePointsSum(lassos[i].points)
	end
end

local function buildOverlayList()
	ensureSpotCache()
	if spotsCacheDirty then return end -- still throttled; retry next frame
	if overlayList then gl.DeleteList(overlayList); overlayList = nil end
	local spots = spotsCache
	local halfSq = METAL_SQ * 0.5
	overlayList = gl.CreateList(function()
		glPolygonOffset(-2, -2)
		for i = 1, #spots do
			local s = spots[i]
			local wx, wz, amt = s.wx, s.wz, s.amount
			local t = min(1.0, amt / 6.0)
			local r = 0.15 + 0.35 * (1 - t)
			local g = 0.55 + 0.45 * t
			local b = 0.25 + 0.70 * t
			glColor(r, g, b, 0.55)
			local y = GetGroundHeight(wx, wz) + 0.5
			glBeginEnd(GL_QUADS, function()
				glVertex(wx - halfSq, y, wz - halfSq)
				glVertex(wx + halfSq, y, wz - halfSq)
				glVertex(wx + halfSq, y, wz + halfSq)
				glVertex(wx - halfSq, y, wz + halfSq)
			end)
		end
		glPolygonOffset(false)
	end)
	overlayListDirty = false
end

local function drawPolyPoints(pts)
	gl.PointSize(7)
	glBeginEnd(GL_POINTS, function()
		for i = 1, #pts do
			local p = pts[i]
			glVertex(p.x, GetGroundHeight(p.x, p.z) + 5, p.z)
		end
	end)
	gl.PointSize(1)
end

local function drawLassoWorld()
	glLineWidth(2)

	-- Committed closed loops
	for li = 1, #lassos do
		local pts = lassos[li].points
		if pts and #pts >= 3 then
			glColor(1, 0.6, 0.1, 0.9)
			glBeginEnd(GL_LINE_LOOP, function()
				for i = 1, #pts do
					local p = pts[i]
					glVertex(p.x, GetGroundHeight(p.x, p.z) + 4, p.z)
				end
			end)
			drawPolyPoints(pts)
		end
	end

	-- In-progress polygon (not yet committed)
	local n = #lassoPoints
	if n >= 1 then
		-- Brighter color to distinguish the active trace from committed loops
		glColor(1, 0.85, 0.2, 0.95)
		if n >= 2 then
			glBeginEnd(GL_LINE_STRIP, function()
				for i = 1, n do
					local p = lassoPoints[i]
					glVertex(p.x, GetGroundHeight(p.x, p.z) + 4, p.z)
				end
			end)
		end
		local cx, cz = getWorldPos()
		if cx then
			local last = lassoPoints[n]
			glBeginEnd(GL_LINES, function()
				glVertex(last.x, GetGroundHeight(last.x, last.z) + 4, last.z)
				glVertex(cx, GetGroundHeight(cx, cz) + 4, cz)
			end)
		end
		drawPolyPoints(lassoPoints)
	end

	glLineWidth(1)
	glColor(1, 1, 1, 1)
end

local function drawClusterLabels()
	ensureClusters()
	for i = 1, #clusterCache do
		local c = clusterCache[i]
		local gy = GetGroundHeight(c.cx, c.cz)
		local sx, sy = WorldToScreenCoords(c.cx, gy + 20, c.cz)
		if sx then
			local txt = format("%.2f (%d)", c.totalAmount * 0.001, c.count)
			glColor(0, 0, 0, 0.92)
			glText(txt, sx + 2, sy - 2, 18, "co")
			glColor(1.0, 0.95, 0.4, 1)
			glText(txt, sx, sy, 18, "co")
		end
	end
end

local function polyCenter(pts)
	local n = #pts
	if n == 0 then return nil end
	local cx, cz = 0, 0
	for i = 1, n do cx = cx + pts[i].x; cz = cz + pts[i].z end
	return cx / n, cz / n
end

local function drawLassoInfo()
	-- Per-lasso label at each committed loop's centroid
	for li = 1, #lassos do
		local entry = lassos[li]
		local pts = entry.points
		if pts and #pts >= 3 then
			local cx, cz = polyCenter(pts)
			if cx then
				local sx, sy = WorldToScreenCoords(cx, GetGroundHeight(cx, cz) + 30, cz)
				if sx then
					local txt = format("#%d  %.2f", li, entry.total or 0)
					glColor(0, 0, 0, 0.92)
					glText(txt, sx + 2, sy - 2, 20, "co")
					glColor(1, 0.7, 0.2, 1)
					glText(txt, sx, sy, 20, "co")
				end
			end
		end
	end

	-- Grand total + in-progress hint (screen bottom-center-ish overlay)
	local nLassos = #lassos
	local inProg = #lassoPoints
	if nLassos == 0 and inProg == 0 then return end
	local vsx, vsy = gl.GetViewSizes()
	local ox = vsx * 0.5
	local oy = vsy * 0.08

	if nLassos > 0 then
		local txt = format("TOTAL %d lasso%s = %.2f   (RMB to remove last)",
			nLassos, nLassos == 1 and "" or "s", lassoGrandTotal())
		glColor(0, 0, 0, 0.92)
		glText(txt, ox + 2, oy - 2, 22, "co")
		glColor(1, 0.85, 0.25, 1)
		glText(txt, ox, oy, 22, "co")
	end

	if inProg > 0 then
		local hint = format("LASSO  click points or drag to freedraw - RMB to close   [%d]", inProg)
		glColor(0, 0, 0, 0.92)
		glText(hint, ox + 2, oy - 28 - 2, 20, "co")
		glColor(1, 0.95, 0.5, 1)
		glText(hint, ox, oy - 28, 20, "co")
	end
end

local function setMapOverlay(v)
	mapOverlay = v and true or false
	if mapOverlay then
		invalidateMetalCaches()
		-- Dim the map so metal patches stand out; save previous darkness to restore later
		if savedDarknessBeforeOverlay == nil and WG['darkenmap'] then
			savedDarknessBeforeOverlay = WG['darkenmap'].getMapDarkness()
			WG['darkenmap'].setMapDarkness(MAP_OVERLAY_DIM)
		end
	else
		-- Restore map brightness
		if savedDarknessBeforeOverlay ~= nil and WG['darkenmap'] then
			WG['darkenmap'].setMapDarkness(savedDarknessBeforeOverlay)
		end
		savedDarknessBeforeOverlay = nil
	end
end

local function setClusterCounter(v)
	clusterCounter = v and true or false
	if clusterCounter then clusterCacheDirty = true end
end

local function setClusterRadius(r)
	r = tonumber(r) or DEFAULT_CLUSTER_RADIUS
	if r < 32 then r = 32 end
	if r > 4096 then r = 4096 end
	clusterRadius = r
	clusterCacheDirty = true
end

local function startLasso()
	lassoActive = true
	lassoPoints = {}
	lassos = {}
	lassoDragStartSx, lassoDragStartSy = nil, nil
	lassoDragDetected = false
end

local function finishLasso()
	-- Commit current in-progress polygon (if any) without leaving lasso mode.
	commitCurrentLasso()
end

local function clearLasso()
	lassoActive = false
	lassoPoints = {}
	lassos = {}
	lassoDragStartSx, lassoDragStartSy = nil, nil
	lassoDragDetected = false
end

-- Remove the most recently committed lasso. Returns true if one was removed.
local function popLastLasso()
	local n = #lassos
	if n == 0 then return false end
	lassos[n] = nil
	return true
end

local function toggleLasso()
	if lassoActive then
		clearLasso()
	else
		startLasso()
	end
end

-- ============================================================
-- Balance Axis: pick an axis line on the map; show metal sums on each side.
-- ============================================================

local balanceAxisActive = false
local balanceAxisAngleDeg = 0           -- 0 = axis runs along X (east-west line)
local balanceAxisOriginX = nil          -- nil -> map center
local balanceAxisOriginZ = nil
local balanceAxisPlacingOrigin = false  -- next LMB sets origin
local balanceAxisSumA = 0               -- positive side (normal direction)
local balanceAxisSumB = 0               -- negative side
local balanceAxisSumsDirty = true
local balanceAxisHovering = false
local balanceAxisDragging = false
local BALANCE_AXIS_HOVER_DIST = 48   -- world elmos perpendicular hover threshold

local function getBalanceAxisOrigin()
	local ox = balanceAxisOriginX or (Game.mapSizeX * 0.5)
	local oz = balanceAxisOriginZ or (Game.mapSizeZ * 0.5)
	return ox, oz
end

local function recomputeBalanceAxisSums()
	ensureSpotCache()
	if spotsCacheDirty then return end -- throttled; retry next frame
	local spots = spotsCache
	if not spots then
		balanceAxisSumA, balanceAxisSumB = 0, 0
		balanceAxisSumsDirty = false
		return
	end
	local ox, oz = getBalanceAxisOrigin()
	local ang = balanceAxisAngleDeg * pi / 180
	-- axis direction (cosA, sinA); normal perpendicular is (-sinA, cosA)
	local nx = -sin(ang)
	local nz = cos(ang)
	local a, b = 0, 0
	for i = 1, #spots do
		local s = spots[i]
		local d = (s.wx - ox) * nx + (s.wz - oz) * nz
		if d >= 0 then
			a = a + s.amount
		else
			b = b + s.amount
		end
	end
	balanceAxisSumA = a * 0.001
	balanceAxisSumB = b * 0.001
	balanceAxisSumsDirty = false
end

local function invalidateBalanceAxisSums()
	balanceAxisSumsDirty = true
end

-- Extend cache invalidator so map-edits refresh axis sums too.
local _origInvalidateMetalCaches = invalidateMetalCaches
invalidateMetalCaches = function()
	_origInvalidateMetalCaches()
	balanceAxisSumsDirty = true
end

local function setBalanceAxisActive(v)
	balanceAxisActive = v and true or false
	if balanceAxisActive then balanceAxisSumsDirty = true end
	if not balanceAxisActive then balanceAxisPlacingOrigin = false end
end

local function toggleBalanceAxis()
	setBalanceAxisActive(not balanceAxisActive)
end

local function setBalanceAxisAngle(deg)
	deg = tonumber(deg) or 0
	deg = ((deg % 360) + 360) % 360
	balanceAxisAngleDeg = deg
	balanceAxisSumsDirty = true
end

local function setBalanceAxisOrigin(x, z)
	balanceAxisOriginX = x
	balanceAxisOriginZ = z
	balanceAxisSumsDirty = true
end

local function setBalanceAxisPlacingOrigin(v)
	balanceAxisPlacingOrigin = v and true or false
end

-- Clip the infinite axis line (through origin in direction dir) to the map AABB.
-- Returns x1,z1,x2,z2 or nil if it doesn't intersect the map.
local function clipAxisToMap(ox, oz, dx, dz)
	local mx, mz = Game.mapSizeX, Game.mapSizeZ
	local tmin, tmax = -1e9, 1e9
	-- X slab
	if abs(dx) > 1e-6 then
		local t1 = (0 - ox) / dx
		local t2 = (mx - ox) / dx
		if t1 > t2 then t1, t2 = t2, t1 end
		if t1 > tmin then tmin = t1 end
		if t2 < tmax then tmax = t2 end
	elseif ox < 0 or ox > mx then
		return nil
	end
	-- Z slab
	if abs(dz) > 1e-6 then
		local t1 = (0 - oz) / dz
		local t2 = (mz - oz) / dz
		if t1 > t2 then t1, t2 = t2, t1 end
		if t1 > tmin then tmin = t1 end
		if t2 < tmax then tmax = t2 end
	elseif oz < 0 or oz > mz then
		return nil
	end
	if tmin > tmax then return nil end
	return ox + dx * tmin, oz + dz * tmin, ox + dx * tmax, oz + dz * tmax
end

-- Draw axis line across the whole map, tinted halves, origin marker.
local function drawBalanceAxisWorld()
	local ox, oz = getBalanceAxisOrigin()
	local ang = balanceAxisAngleDeg * pi / 180
	local dx, dz = cos(ang), sin(ang)
	local x1, z1, x2, z2 = clipAxisToMap(ox, oz, dx, dz)
	if not x1 then return end
	glLineWidth(balanceAxisDragging and 4 or (balanceAxisHovering and 3.5 or 3))
	if balanceAxisDragging then
		glColor(1.0, 1.0, 0.6, 1.0)
	elseif balanceAxisHovering then
		glColor(1.0, 0.95, 0.4, 1.0)
	else
		glColor(1.0, 0.85, 0.2, 0.95)
	end
	glBeginEnd(GL_LINES, function()
		glVertex(x1, GetGroundHeight(x1, z1) + 6, z1)
		glVertex(x2, GetGroundHeight(x2, z2) + 6, z2)
	end)

	-- Normal tick at origin to indicate "side A" (positive normal direction)
	local nx, nz = -sin(ang), cos(ang)
	local tL = 180
	glLineWidth(2)
	glColor(0.4, 1.0, 0.4, 0.9)
	glBeginEnd(GL_LINES, function()
		glVertex(ox, GetGroundHeight(ox, oz) + 6, oz)
		glVertex(ox + nx * tL, GetGroundHeight(ox + nx * tL, oz + nz * tL) + 6, oz + nz * tL)
	end)
	glColor(1.0, 0.5, 0.5, 0.9)
	glBeginEnd(GL_LINES, function()
		glVertex(ox, GetGroundHeight(ox, oz) + 6, oz)
		glVertex(ox - nx * tL, GetGroundHeight(ox - nx * tL, oz - nz * tL) + 6, oz - nz * tL)
	end)

	-- Origin marker
	gl.PointSize(balanceAxisHovering and 12 or 9)
	glColor(1, 1, 1, 1)
	glBeginEnd(GL_POINTS, function()
		glVertex(ox, GetGroundHeight(ox, oz) + 8, oz)
	end)
	gl.PointSize(1)
	glLineWidth(1)
	glColor(1, 1, 1, 1)
end

local function drawBalanceAxisInfo()
	if balanceAxisSumsDirty then recomputeBalanceAxisSums() end
	local ox, oz = getBalanceAxisOrigin()
	local ang = balanceAxisAngleDeg * pi / 180
	local nx, nz = -sin(ang), cos(ang)
	local labelDist = 300
	local axA = ox + nx * labelDist
	local azA = oz + nz * labelDist
	local axB = ox - nx * labelDist
	local azB = oz - nz * labelDist

	local function label(wx, wz, text, r, g, b)
		local sx, sy = WorldToScreenCoords(wx, GetGroundHeight(wx, wz) + 40, wz)
		if sx then
			glColor(0, 0, 0, 0.92)
			glText(text, sx + 2, sy - 2, 22, "co")
			glColor(r, g, b, 1)
			glText(text, sx, sy, 22, "co")
		end
	end

	label(axA, azA, format("A: %.2f", balanceAxisSumA), 0.5, 1.0, 0.5)
	label(axB, azB, format("B: %.2f", balanceAxisSumB), 1.0, 0.6, 0.6)

	if balanceAxisPlacingOrigin then
		local vsx, vsy = gl.GetViewSizes()
		glColor(0, 0, 0, 0.92)
		glText("BALANCE AXIS - click map to place origin", vsx * 0.5 + 2, vsy * 0.12 - 2, 22, "co")
		glColor(1, 0.95, 0.5, 1)
		glText("BALANCE AXIS - click map to place origin", vsx * 0.5, vsy * 0.12, 22, "co")
	end
end

-- ============================================================
-- State Management & WG Interface
-- ============================================================

local function activate(mode)
	active = true
	subMode = mode or "stamp"
	painting = false
	-- Apply metal-friendly defaults: 3x3 square brush, grid snap, map overlay
	local tb = WG.TerraformBrush
	if tb then
		tb.setRadius(DEFAULT_RADIUS)
		tb.setShape("square")
		if tb.setGridSnap then tb.setGridSnap(true) end
	end
	if not mapOverlay then setMapOverlay(true) end
	Echo("[Metal Brush] Activated: " .. subMode:upper() .. " | Metal Value: " .. metalValue)
end

local function deactivate()
	if active then
		Echo("[Metal Brush] Deactivated")
	end
	active = false
	painting = false
	paintButton = 0
	-- Restore map brightness if overlay was on when we deactivated
	if savedDarknessBeforeOverlay ~= nil and WG['darkenmap'] then
		WG['darkenmap'].setMapDarkness(savedDarknessBeforeOverlay)
	end
	savedDarknessBeforeOverlay = nil
end

local function setSubMode(mode)
	subMode = mode or "paint"
end

local function setMetalValue(v)
	metalValue = max(MIN_METAL_VALUE, min(MAX_METAL_VALUE, v))
end

local function getState()
	return {
		active = active,
		subMode = subMode,
		metalValue = metalValue,
		mapOverlay = mapOverlay,
		clusterCounter = clusterCounter,
		clusterRadius = clusterRadius,
		lassoActive = lassoActive,
		lassoClosed = (#lassos > 0),        -- back-compat: true if any committed loop exists
		lassoPointCount = #lassoPoints,
		lassoTotal = lassoGrandTotal(),     -- back-compat: now the grand total across all committed loops
		lassoCount = #lassos,               -- new: number of committed loops
		balanceAxisActive = balanceAxisActive,
		balanceAxisAngleDeg = balanceAxisAngleDeg,
		balanceAxisOriginX = balanceAxisOriginX,
		balanceAxisOriginZ = balanceAxisOriginZ,
		balanceAxisPlacingOrigin = balanceAxisPlacingOrigin,
		balanceAxisSumA = balanceAxisSumA,
		balanceAxisSumB = balanceAxisSumB,
	}
end

-- ============================================================
-- Widget Callbacks
-- ============================================================

function widget:Initialize()
	WG.MetalBrush = {
		activate = activate,
		deactivate = deactivate,
		getState = getState,
		setSubMode = setSubMode,
		setMetalValue = setMetalValue,
		saveMetalMap = saveMetalMap,
		loadMetalMap = loadMetalMap,
		clearMetalMap = clearMetalMap,
		setMapOverlay = setMapOverlay,
		setClusterCounter = setClusterCounter,
		setClusterRadius = setClusterRadius,
		startLasso = startLasso,
		finishLasso = finishLasso,
		clearLasso = clearLasso,
		toggleLasso = toggleLasso,
		setBalanceAxisActive = setBalanceAxisActive,
		toggleBalanceAxis = toggleBalanceAxis,
		setBalanceAxisAngle = setBalanceAxisAngle,
		setBalanceAxisOrigin = setBalanceAxisOrigin,
		setBalanceAxisPlacingOrigin = setBalanceAxisPlacingOrigin,
		refreshAnalysis = invalidateMetalCaches,
		undo = function() SendLuaRulesMsg(MSG_UNDO, "") end,
		redo = function() SendLuaRulesMsg(MSG_REDO, "") end,
	}
end

function widget:Shutdown()
	WG.MetalBrush = nil
	if overlayList then gl.DeleteList(overlayList); overlayList = nil end
	if clusterVisList then gl.DeleteList(clusterVisList); clusterVisList = nil end
	-- Restore map brightness if overlay dim was active
	if savedDarknessBeforeOverlay ~= nil and WG['darkenmap'] then
		WG['darkenmap'].setMapDarkness(savedDarknessBeforeOverlay)
		savedDarknessBeforeOverlay = nil
	end
end

function widget:IsAbove(x, y)
	return false
end

function widget:MousePress(mx, my, button)
	if not active then return false end

	-- Balance axis origin placement: consume next LMB as origin, RMB cancels.
	if balanceAxisPlacingOrigin then
		if button == 1 then
			local wx, wz = getWorldPos()
			if wx then
				setBalanceAxisOrigin(wx, wz)
			end
			balanceAxisPlacingOrigin = false
			return true
		elseif button == 3 then
			balanceAxisPlacingOrigin = false
			return true
		end
	end

	-- Balance axis drag: LMB on the line starts a drag (translates origin along
	-- the axis normal so the whole line slides perpendicular to itself).
	if balanceAxisActive and balanceAxisHovering and button == 1 then
		balanceAxisDragging = true
		return true
	end

	-- Lasso tool: intercepts clicks before anything else (works without cheat)
	if lassoActive then
		local worldX, worldZ = getWorldPos()
		if not worldX then return false end
		if button == 1 then
			-- Reset drag tracking for this press; drag-mode activates if the
			-- cursor moves beyond threshold before release (free-draw loop).
			lassoDragStartSx, lassoDragStartSy = mx, my
			lassoDragDetected = false

			-- Click near first point closes and commits the in-progress polygon.
			if #lassoPoints >= 3 then
				local dx = worldX - lassoPoints[1].x
				local dz = worldZ - lassoPoints[1].z
				if dx * dx + dz * dz < 32 * 32 then
					commitCurrentLasso()
					return true
				end
			end
			lassoPoints[#lassoPoints + 1] = { x = worldX, z = worldZ }
			return true
		elseif button == 3 then
			-- RMB behaviour:
			--   * in-progress polygon exists -> close it (commit if ≥3 pts, else discard)
			--   * otherwise -> remove the most recently committed loop
			if #lassoPoints > 0 then
				commitCurrentLasso()
			else
				popLastLasso()
			end
			return true
		end
	end

	if not IsCheatingEnabled() then return false end

	-- Defer to measure tool when active so metal paint doesn't consume the click
	local tb = WG.TerraformBrush
	if tb and tb.getState then
		local st = tb.getState()
		if st and st.measureActive then return false end
		-- Defer to symmetry origin placement / drag-grab so terraform can handle it
		if st and st.symmetryActive then
			if st.symmetryPlacingOrigin or st.symmetryHoveringOrigin or st.symmetryDraggingOrigin then
				return false
			end
		end
	end

	local worldX, worldZ = getWorldPos()
	if not worldX then return false end

	if button == 1 or button == 3 then
		paintButton = button
		if subMode == "stamp" then
			sendStampMessage(worldX, worldZ)
			return true
		else
			painting = true
			lastPaintTime = 0
			sendPaintMessage(worldX, worldZ)
			return true
		end
	end

	return false
end

function widget:MouseMove(mx, my, dx, dy, button)
	-- Balance axis drag: slide origin along axis normal so line stays parallel.
	if balanceAxisDragging then
		local wx, wz = getWorldPos()
		if wx then
			local ox, oz = getBalanceAxisOrigin()
			local ang = balanceAxisAngleDeg * pi / 180
			local nx, nz = -sin(ang), cos(ang)
			local d = (wx - ox) * nx + (wz - oz) * nz
			setBalanceAxisOrigin(ox + nx * d, oz + nz * d)
		end
		return
	end

	-- Lasso free-draw: while LMB is held, append points along the cursor path
	-- once the drag has crossed a small pixel threshold. Converts a single
	-- click-and-drag gesture into a closed loop on release.
	if not active or not lassoActive then return end
	if not lassoDragStartSx then return end
	-- button arg can be the held button id or nil depending on caller; we
	-- already know LMB is held because MousePress captured it and we clear
	-- the drag-start markers on release.

	if not lassoDragDetected then
		local sdx = mx - lassoDragStartSx
		local sdy = my - lassoDragStartSy
		if sdx * sdx + sdy * sdy < LASSO_DRAG_THRESHOLD_PX * LASSO_DRAG_THRESHOLD_PX then
			return
		end
		lassoDragDetected = true
	end

	local wx, wz = getWorldPos()
	if not wx then return end
	local n = #lassoPoints
	if n > 0 then
		local last = lassoPoints[n]
		local ddx = wx - last.x
		local ddz = wz - last.z
		if ddx * ddx + ddz * ddz < LASSO_FREEDRAW_MIN_SPACING_SQ then return end
	end
	lassoPoints[n + 1] = { x = wx, z = wz }
end

function widget:MouseRelease(mx, my, button)
	if balanceAxisDragging and button == 1 then
		balanceAxisDragging = false
		return
	end
	-- Lasso free-draw auto-close on LMB release after a drag gesture.
	if lassoActive and button == 1 and lassoDragDetected then
		commitCurrentLasso()
		lassoDragDetected = false
		lassoDragStartSx, lassoDragStartSy = nil, nil
		return
	end
	lassoDragDetected = false
	lassoDragStartSx, lassoDragStartSy = nil, nil

	if painting and button == paintButton then
		painting = false
		paintButton = 0
		-- sendPaintMessage already set cacheRebuildHoldUntil and lastCacheBuildClock=0.
		-- Just mark the visual lists dirty; the hold mechanism defers the cache
		-- rebuild until the gadget has had time to apply SetMetalAmount.
		spotsCacheDirty = true
		clusterCacheDirty = true
		overlayListDirty = true
		clusterVisDirty = true
		balanceAxisSumsDirty = true
	end
end

function widget:MouseWheel(up, value)
	if not active then return false end
	local alt, ctrl, _, shift = Spring.GetModKeyState()
	local space = Spring.GetKeyState(0x20)

	-- Space+scroll: metalValue (counterpart of intensity)
	if space then
		local step = 0.1
		if metalValue > 10.0 then step = 1.0
		elseif metalValue > 5.0 then step = 0.5
		end
		if up then
			metalValue = min(MAX_METAL_VALUE, metalValue + step)
		else
			metalValue = max(MIN_METAL_VALUE, metalValue - step)
		end
		Echo("[Metal Brush] Metal value: " .. format("%.2f", metalValue))
		return true
	end

	local tb = WG.TerraformBrush
	if not tb then return false end
	local st = tb.getState()

	-- Ctrl+Alt+scroll: length
	if ctrl and alt then
		local ls = (st.lengthScale or 1.0) + (up and 0.1 or -0.1)
		tb.setLengthScale(max(0.1, ls))
		return true
	end

	-- Ctrl+scroll: size — step by one metal pixel ring (METAL_SQ per step)
	if ctrl then
		local currentR = st.radius or DEFAULT_RADIUS
		local n = floor(currentR / METAL_SQ)  -- current pixel ring index
		if up then n = n + 1 else n = max(0, n - 1) end
		tb.setRadius(n * METAL_SQ + METAL_SQ * 0.5)  -- snapped to n*METAL_SQ + halfSq
		return true
	end

	-- Alt+scroll: rotation (snap to TB protractor step when angleSnap on)
	if alt then
		local step = 3
		if st.angleSnap and (st.angleSnapStep or 0) > 0 then
			step = st.angleSnapStep
		end
		local rot = (((st.rotationDeg or 0) + (up and step or -step)) % 360 + 360) % 360
		tb.setRotation(rot)
		return true
	end

	-- Shift+scroll: falloff (curve)
	if shift then
		local c = (st.curve or 1.0) + (up and 0.1 or -0.1)
		c = max(0.1, min(5.0, c))
		c = floor(c * 10 + 0.5) / 10
		tb.setCurve(c)
		return true
	end

	return false
end

function widget:Update(dt)
	-- Balance axis hover check (when not dragging, not placing)
	if active and balanceAxisActive and not balanceAxisDragging and not balanceAxisPlacingOrigin then
		local wx, wz = getWorldPos()
		if wx then
			local ox, oz = getBalanceAxisOrigin()
			local ang = balanceAxisAngleDeg * pi / 180
			local nx, nz = -sin(ang), cos(ang)
			local d = abs((wx - ox) * nx + (wz - oz) * nz)
			balanceAxisHovering = (d <= BALANCE_AXIS_HOVER_DIST)
		else
			balanceAxisHovering = false
		end
	elseif not balanceAxisDragging then
		balanceAxisHovering = false
	end

	if not active or not painting then return end

	lastPaintTime = lastPaintTime + dt
	if lastPaintTime < UPDATE_INTERVAL then return end
	lastPaintTime = 0

	local worldX, worldZ = getWorldPos()
	if not worldX then return end

	sendPaintMessage(worldX, worldZ)
end

function widget:DrawWorld()
	if not active then return end

	-- Map-wide metal overlay (full map)
	if mapOverlay then
		if overlayListDirty or not overlayList then buildOverlayList() end
		if overlayList then gl.CallList(overlayList) end
	end

	-- Cluster membership visualization (colored pixels + convex hull per cluster)
	if clusterCounter then
		if clusterVisDirty or not clusterVisList then buildClusterVisList() end
		if clusterVisList then gl.CallList(clusterVisList) end
	end

	-- Lasso polygon
	if lassoActive or #lassos > 0 then
		drawLassoWorld()
	end

	-- Balance axis
	if balanceAxisActive then
		drawBalanceAxisWorld()
	end

	local worldX, worldZ = getWorldPos()
	do
		local tb = WG.TerraformBrush
		if tb and tb.animateUnmouse then
			local ss2 = getSharedState()
			worldX, worldZ = tb.animateUnmouse("metalBrush", worldX, worldZ, ss2 and ss2.radius or 200, 1.0)
		elseif tb and tb.getUnmouseTarget and not worldX then
			local ss2 = getSharedState()
			worldX, worldZ = tb.getUnmouseTarget(ss2 and ss2.radius or 200, 1.0)
		end
	end
	if not worldX then return end

	local ss = getSharedState()

	-- Apply metal grid snap to cursor position when gridSnap is active
	if ss.gridSnap then
		worldX, worldZ = snapToMetalGrid(worldX, worldZ)
	end

	-- Draw metal density overlay near cursor
	drawMetalOverlay(worldX, worldZ, ss.radius)

	-- Draw brush outline
	local colorR, colorG, colorB = 0.2, 1.0, 0.2
	if subMode == "stamp" then
		if paintButton == 3 then
			colorR, colorG, colorB = 1.0, 0.3, 0.0
		else
			colorR, colorG, colorB = 1.0, 0.85, 0.0
		end
	elseif paintButton == 3 then
		colorR, colorG, colorB = 1.0, 0.3, 0.3
	end
	-- Draw outlines at all symmetric positions so the cursor matches what gets stamped
	local outlineTb = WG.TerraformBrush
	local outlinePositions = nil
	if outlineTb and outlineTb.getSymmetricPositions then
		outlinePositions = outlineTb.getSymmetricPositions(worldX, worldZ, ss.rotationDeg)
	end
	if not outlinePositions or #outlinePositions == 0 then
		outlinePositions = {{ x = worldX, z = worldZ, rot = ss.rotationDeg }}
	end
	glColor(colorR, colorG, colorB, 0.85)
	glLineWidth(2)
	for oi = 1, #outlinePositions do
		local op = outlinePositions[oi]
		drawShapeOutline(op.x, op.z, ss.radius, ss.shape, op.rot or ss.rotationDeg)
	end

	-- Draw center cross
	local groundY = GetGroundHeight(worldX, worldZ)
	glColor(1, 1, 1, 0.5)
	glBeginEnd(GL_LINES, function()
		glVertex(worldX - 8, groundY + 2, worldZ)
		glVertex(worldX + 8, groundY + 2, worldZ)
		glVertex(worldX, groundY + 2, worldZ - 8)
		glVertex(worldX, groundY + 2, worldZ + 8)
	end)

	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

function widget:DrawScreen()
	if not active then return end

	if clusterCounter then drawClusterLabels() end
	if lassoActive or #lassos > 0 then drawLassoInfo() end
	if balanceAxisActive then drawBalanceAxisInfo() end

	local worldX, worldZ = getWorldPos()
	if not worldX then return end

	drawCursorInfo(worldX, worldZ)
end

-- Gadget signals "mb_metal_updated" after every SetMetalAmount batch so we
-- know the values are committed and can cancel the blind timer hold, letting
-- the overlay cache rebuild on the very next DrawWorld call.
function widget:RecvLuaMsg(msg, playerID)
	if msg == "mb_metal_updated" then
		spotsCacheDirty    = true
		clusterCacheDirty  = true
		overlayListDirty   = true
		clusterVisDirty    = true
		balanceAxisSumsDirty = true
		cacheRebuildHoldUntil = 0  -- cancel timer hold; gadget already applied changes
		lastCacheBuildClock   = 0  -- bypass throttle so next DrawWorld rebuilds immediately
	end
end
