local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Grass Brush",
		desc = "Paint, fill and erase grass density with smart filters and texture-color matching.",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

-- ============================================================
-- Engine API Locals
-- ============================================================
local GetMouseState       = Spring.GetMouseState
local TraceScreenRay      = Spring.TraceScreenRay
local GetGroundHeight     = Spring.GetGroundHeight
local GetGroundNormal     = Spring.GetGroundNormal
local WorldToScreenCoords = Spring.WorldToScreenCoords
local GetModKeyState      = Spring.GetModKeyState
local GetKeyState         = Spring.GetKeyState
local IsCheatingEnabled   = Spring.IsCheatingEnabled
local GetActiveCommand    = Spring.GetActiveCommand
local Echo                = Spring.Echo

local glColor         = gl.Color
local glLineWidth     = gl.LineWidth
local glBeginEnd      = gl.BeginEnd
local glVertex        = gl.Vertex
local glPolygonOffset = gl.PolygonOffset
local glText          = gl.Text
local glDepthTest     = gl.DepthTest
local glBlending      = gl.Blending
local GL_LINE_LOOP    = GL.LINE_LOOP
local GL_LINES        = GL.LINES
local GL_TRIANGLES    = GL.TRIANGLES
local GL_SRC_ALPHA    = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local floor  = math.floor
local ceil   = math.ceil
local max    = math.max
local min    = math.min
local cos    = math.cos
local sin    = math.sin
local abs    = math.abs
local pi     = math.pi
local sqrt   = math.sqrt
local format = string.format

local KEYSYMS_SPACE  = 0x20
local KEYSYMS_ESCAPE = 0x1B

-- Track the engine's active command so we can detect external tool switches
local lastActiveCmd = nil

-- ============================================================
-- Constants
-- ============================================================
local CIRCLE_SEGMENTS = 48
local UPDATE_INTERVAL = 0.033
local FILTER_GRID_STEP = 32

-- Parameter ranges (match terraform brush conventions)
local MIN_RADIUS       = 8
local MAX_RADIUS       = 2000
local RADIUS_STEP      = 8
local MIN_DENSITY      = 0.0
local MAX_DENSITY      = 1.0
local DENSITY_STEP     = 0.05
local DEFAULT_DENSITY  = 0.8
local DEFAULT_RADIUS   = 100
local MIN_CURVE        = 0.1
local MAX_CURVE        = 5.0
local CURVE_STEP       = 0.1
local DEFAULT_CURVE    = 0.5
local ROTATION_STEP    = 3
local DEFAULT_LENGTH_SCALE = 1.0
local MIN_LENGTH_SCALE = 0.2
local MAX_LENGTH_SCALE = 5.0
local LENGTH_SCALE_STEP = 0.1

-- ============================================================
-- Brush State
-- ============================================================
local active        = false
local subMode       = "paint"   -- "paint", "fill", "erase"
local targetDensity = DEFAULT_DENSITY
local brushRadius   = DEFAULT_RADIUS
local brushCurve    = DEFAULT_CURVE
local brushRotation = 0
local brushLengthScale = DEFAULT_LENGTH_SCALE
local brushShape    = "circle"
local painting      = false
local paintButton   = 0        -- 1 = LMB (add), 3 = RMB (remove)
local lastPaintTime = 0
local grassAvailable = false

-- ============================================================
-- Undo / Redo History
-- ============================================================
local MAX_HISTORY = 50
local undoStack   = {}   -- array of patch arrays; each patch = {x, z, before, after}
local redoStack   = {}
local strokeSnap  = nil  -- dict[x*100000+z] = {x, z, before}, in-progress stroke

local function strokeBegin()
	strokeSnap = {}
end

local function strokeSamplePatch(x, z)
	if not strokeSnap then return end
	local key = x * 100000 + z
	if strokeSnap[key] then return end
	local api = WG['grassgl4']
	if not api or not api.getDensityAt then return end
	strokeSnap[key] = { x = x, z = z, before = api.getDensityAt(x, z) }
end

local function strokeEnd()
	if not strokeSnap then return end
	local api = WG['grassgl4']
	if not api or not api.getDensityAt then strokeSnap = nil; return end
	local patches = {}
	local changed = false
	for _, p in pairs(strokeSnap) do
		local after = api.getDensityAt(p.x, p.z)
		if after ~= p.before then changed = true end
		patches[#patches + 1] = { x = p.x, z = p.z, before = p.before, after = after }
	end
	strokeSnap = nil
	if changed then
		undoStack[#undoStack + 1] = patches
		if #undoStack > MAX_HISTORY then table.remove(undoStack, 1) end
		redoStack = {}
	end
end

local function grassUndo()
	if #undoStack == 0 then return end
	local api = WG['grassgl4']
	if not api or not api.setDensityAt then return end
	local patches = undoStack[#undoStack]
	undoStack[#undoStack] = nil
	for i = 1, #patches do
		api.setDensityAt(patches[i].x, patches[i].z, patches[i].before)
	end
	redoStack[#redoStack + 1] = patches
	if #redoStack > MAX_HISTORY then table.remove(redoStack, 1) end
end

local function grassRedo()
	if #redoStack == 0 then return end
	local api = WG['grassgl4']
	if not api or not api.setDensityAt then return end
	local patches = redoStack[#redoStack]
	redoStack[#redoStack] = nil
	for i = 1, #patches do
		api.setDensityAt(patches[i].x, patches[i].z, patches[i].after)
	end
	undoStack[#undoStack + 1] = patches
end

local function grassUndoToIndex(targetIdx)
	local cur = #undoStack
	if targetIdx < cur then
		for _ = 1, cur - targetIdx do grassUndo() end
	elseif targetIdx > cur then
		for _ = 1, targetIdx - cur do grassRedo() end
	end
end

-- Smart filter state
local smartEnabled  = false
local smartFilters  = {
	avoidWater   = true,
	avoidCliffs  = true,
	slopeMax     = 45,
	preferSlopes = false,
	slopeMin     = 10,
	altMinEnable = false,
	altMin       = 0,
	altMaxEnable = false,
	altMax       = 200,
}

-- Texture color filter state
local texFilterEnabled = false
-- texFilterColor indices 1-3: include RGB
-- texFilterColor indices 4: exclude enabled flag (1/nil)
-- texFilterColor indices 5-7: exclude RGB
local texFilterColor   = { 0.25, 0.45, 0.15, nil, 0.65, 0.35, 0.10 }  -- include=green, exclude=brown
local texFilterThreshold = 0.35                   -- color distance threshold (0–1)
local texFilterPadding   = 0                      -- padding in elmos from excluded areas
local pipetteMode         = false   -- true while waiting for user to click terrain (include)
local pipettePending      = nil     -- { wx, wz } queued in MousePress, sampled in DrawScreen
local pipetteExcludeMode    = false -- true while waiting to click terrain (exclude)
local pipetteExcludePending = nil   -- { wx, wz } queued for exclude sample

-- ============================================================
-- Shape Testing
-- ============================================================

local function rotateInv(dx, dz, angleDeg)
	if angleDeg == 0 then return dx, dz end
	local rad = -angleDeg * pi / 180
	local c, s = cos(rad), sin(rad)
	return dx * c - dz * s, dx * s + dz * c
end

local function isInsideShape(dx, dz, radius, shape, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	local rx, rz = rotateInv(dx, dz, angleDeg)
	local radX = radius
	local radZ = radius * lengthScale
	if shape == "circle" then
		local normX = rx / radX
		local normZ = rz / radZ
		local d = sqrt(normX * normX + normZ * normZ)
		return d <= 1.0, d
	elseif shape == "square" then
		-- axis-aligned square; corners at (±radX, ±radZ) match outline
		local d = max(abs(rx) / radX, abs(rz) / radZ)
		return d <= 1.0, d
	elseif shape == "hexagon" then
		-- regular hexagon, vertices on ±x axis (pointy-on-x) matching outline
		-- constraints: |x| + |z|/sqrt(3) <= 1  and  2|z|/sqrt(3) <= 1
		local ax, az = abs(rx) / radX, abs(rz) / radZ
		local d = max(ax + az * 0.5773503, az * 1.1547005)
		return d <= 1.0, d
	elseif shape == "octagon" then
		-- regular octagon, vertex on +x axis matching outline
		local ax, az = abs(rx) / radX, abs(rz) / radZ
		local d = max(ax + az * 0.4142136, az + ax * 0.4142136)
		return d <= 1.0, d
	elseif shape == "triangle" then
		-- equilateral triangle pointing +x, vertices at angles 0°,120°,240°
		local nx = rx / radX
		local az = abs(rz) / radZ
		local d = max(nx + az * 1.7320508, -2 * nx)
		return d <= 1.0, d
	end
	return false, 1
end

local function computeFalloff(normDist, curve)
	if normDist >= 1 then return 0 end
	if normDist <= 0 then return 1 end
	local t = 1 - normDist
	if curve == 1.0 then return t end
	return t ^ curve
end

-- ============================================================
-- Smart Filter
-- ============================================================

local function isPointValid(px, pz, sf)
	local h = GetGroundHeight(px, pz)
	if sf.avoidWater and h < 0 then return false end
	if sf.avoidCliffs then
		local _, ny = GetGroundNormal(px, pz)
		ny = ny or 1.0
		local nyMin = cos(sf.slopeMax * pi / 180)
		if ny < nyMin then return false end
	end
	if sf.preferSlopes then
		local _, ny = GetGroundNormal(px, pz)
		ny = ny or 1.0
		local nyMax = cos(sf.slopeMin * pi / 180)
		if ny > nyMax then return false end
	end
	if sf.altMinEnable and h < sf.altMin then return false end
	if sf.altMaxEnable and h > sf.altMax then return false end
	return true
end

-- ============================================================
-- Texture Color Filter — Diffuse Sampling via $map_gbuffer_difftex
-- ============================================================
--
-- SOURCE: $map_gbuffer_difftex = terrain G-buffer diffuse, screen-space.
--   UV (0,0)→(1,1) maps to viewport bottom-left→top-right.
--   Matches the ACTUAL terrain renderer output (correct colors).
--   $minimap was dropped — different shading pipeline, wrong colors.
--
-- BATCH APPROACH (buildDiffuseCache):
--   1. WorldToScreenCoords for each grid cell → viewport pixel coords.
--   2. Compute screen bounding-box of all cells (minSX..maxSX).
--   3. Capture that bbox region from $map_gbuffer_difftex into a
--      (bboxW × bboxH) FBO via single TexRect (pass 1).
--   4. ReadPixels from the FBO (pass 2).
--   5. Look up each cell: FBO pixel = (sx - minSX, sy - minSY).
--
-- SINGLE-POINT APPROACH (sampleDiffuseAtPoint / pipette):
--   WorldToScreenCoords → screen UV → 1×1 FBO two-pass.
--
-- Runs in DrawScreen.  DrawWorld overlay uses cached dcR/dcG/dcB arrays.
-- SINGLE-SOURCE-OF-TRUTH: every consumer MUST call getDiffuseColorAt().
-- ============================================================

-- Cache constants
local DIFFUSE_GRID_MAX = 48   -- max grid dimension per axis
local CACHE_MIN_STEP = 16     -- minimum world elmos per grid cell
local CACHE_MARGIN = 48       -- extra padding in world elmos

-- Flat arrays (indexed by gz * gridW + gx + 1)
local dcR, dcG, dcB = {}, {}, {}
local dcValid = false

-- Cache metadata
local dcInfo = {
	cx = 0, cz = 0,           -- world center when cache was built
	halfExtent = 0,            -- requested half-extent
	gridW = 0, gridH = 0,     -- grid dimensions
	stepX = 0, stepZ = 0,     -- world elmos per grid cell
	fbo = nil,                 -- 1x1 FBO texture handle (pipette only)
	gridTex = nil,             -- viewport-sized FBO (gridW x gridH) for batch cache
	fboW = 0, fboH = 0,       -- current gridTex dimensions
	wx1 = 0, wz1 = 0,         -- NW corner (west, north = small x, small z)
	wx2 = 0, wz2 = 0,         -- SE corner (east, south = large x, large z)
	-- deferred readback state (render frame N, read frame N+1 to avoid GPU stall)
	pendingRead   = false,
	pendingGridSX = nil,
	pendingGridSY = nil,
	pendingMinSX  = 0,
	pendingMinSY  = 0,
	pendingBboxW  = 0,   -- actual FBO size (capped)
	pendingBboxH  = 0,   -- actual FBO size (capped)
	pendingScaleX = 1,   -- capW / fullBboxW — for scaled pixel lookup
	pendingScaleY = 1,   -- capH / fullBboxH
	pendingGridW  = 0,
	pendingGridH  = 0,
}

-- ------------------------------------------------
-- buildDiffuseCache(cx, cz, halfExtent)
--   Screen-space G-buffer sampling.  Project each grid cell to screen,
--   capture screen bbox from $map_gbuffer_difftex in one TexRect,
--   read back all pixels, store per cell.  DrawScreen only.
-- ------------------------------------------------
local function buildDiffuseCache(cx, cz, halfExtent)
	local GetGH  = Spring.GetGroundHeight
	local WToS   = Spring.WorldToScreenCoords
	local vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
	local msX, msZ = Game.mapSizeX, Game.mapSizeZ

	-- Clamp world rectangle to map bounds
	local x1 = max(0, cx - halfExtent)
	local z1 = max(0, cz - halfExtent)
	local x2 = min(msX, cx + halfExtent)
	local z2 = min(msZ, cz + halfExtent)
	local rangeX = x2 - x1
	local rangeZ = z2 - z1
	if rangeX <= 0 or rangeZ <= 0 then return end

	-- Determine grid resolution
	local stepX = max(CACHE_MIN_STEP, rangeX / DIFFUSE_GRID_MAX)
	local stepZ = max(CACHE_MIN_STEP, rangeZ / DIFFUSE_GRID_MAX)
	local gridW = max(1, floor(rangeX / stepX))
	local gridH = max(1, floor(rangeZ / stepZ))

	-- Pass 1: project each cell to screen coords, build bbox
	local gridSX = {}  -- viewport-relative pixel X per cell
	local gridSY = {}  -- viewport-relative pixel Y per cell
	local minSX = vsx;  local maxSX = 0
	local minSY = vsy;  local maxSY = 0
	local anyOn  = false
	for gz = 0, gridH - 1 do
		for gx = 0, gridW - 1 do
			local wx  = x1 + (gx + 0.5) * stepX
			local wz  = z1 + (gz + 0.5) * stepZ
			local sx, sy = WToS(wx, GetGH(wx, wz), wz)
			local idx = gz * gridW + gx + 1
			if sx then
				local isx = max(0, min(vsx - 1, floor(sx - vpx)))
				local isy = max(0, min(vsy - 1, floor(sy - vpy)))
				gridSX[idx] = isx
				gridSY[idx] = isy
				if isx < minSX then minSX = isx end
				if isx > maxSX then maxSX = isx end
				if isy < minSY then minSY = isy end
				if isy > maxSY then maxSY = isy end
				anyOn = true
			else
				gridSX[idx] = -1
				gridSY[idx] = -1
			end
		end
	end
	if not anyOn then dcValid = false; return end

	local bboxW = maxSX - minSX + 1
	local bboxH = maxSY - minSY + 1

	-- Cap FBO size to prevent huge ReadPixels Lua tables causing OOM.
	-- ReadPixels returns bboxW*bboxH pixel tables; at 800×800 that's 640k
	-- entries which overwhelms the 1.5GB LuaUI heap. 96×96 = 9216 entries max.
	local capW = min(bboxW, DIFFUSE_GRID_MAX * 2)
	local capH = min(bboxH, DIFFUSE_GRID_MAX * 2)
	local scaleX = capW / bboxW
	local scaleY = capH / bboxH

	-- Recreate FBO only if capped dimensions changed
	if dcInfo.gridTex and (dcInfo.fboW ~= capW or dcInfo.fboH ~= capH) then
		gl.DeleteTexture(dcInfo.gridTex)
		dcInfo.gridTex = nil
	end
	if not dcInfo.gridTex then
		dcInfo.gridTex = gl.CreateTexture(capW, capH, {
			min_filter = GL.NEAREST, mag_filter = GL.NEAREST, fbo = true,
		})
		dcInfo.fboW = capW
		dcInfo.fboH = capH
	end
	if not dcInfo.gridTex then return end

	-- Render pass: capture screen bbox from gbuffer into FBO (scaled down to capW×capH).
	-- ReadPixels is NOT done here — deferred to next DrawScreen frame
	-- to avoid synchronous GPU→CPU stall (causes SwapBuffers lag).
	local u0  = minSX / vsx
	local v0  = minSY / vsy
	local u1b = (maxSX + 1) / vsx
	local v1b = (maxSY + 1) / vsy
	gl.RenderToTexture(dcInfo.gridTex, function()
		gl.Texture("$map_gbuffer_difftex")
		gl.TexRect(-1, -1, 1, 1, u0, v0, u1b, v1b)
		gl.Texture(false)
	end)

	-- Store pending-read state for next frame
	dcInfo.pendingGridSX = gridSX
	dcInfo.pendingGridSY = gridSY
	dcInfo.pendingMinSX  = minSX
	dcInfo.pendingMinSY  = minSY
	dcInfo.pendingBboxW  = capW      -- actual FBO size (capped)
	dcInfo.pendingBboxH  = capH      -- actual FBO size (capped)
	dcInfo.pendingScaleX = scaleX    -- to convert screen-offset → FBO pixel
	dcInfo.pendingScaleY = scaleY
	dcInfo.pendingGridW  = gridW
	dcInfo.pendingGridH  = gridH
	dcInfo.pendingRead   = true

	-- Update position metadata NOW so needsCacheRebuild won't re-fire next frame
	dcValid = false   -- stays false until flushDiffuseRead() completes
	dcInfo.cx = cx;  dcInfo.cz = cz
	dcInfo.halfExtent = halfExtent
	dcInfo.gridW = gridW;  dcInfo.gridH = gridH
	dcInfo.stepX = stepX;  dcInfo.stepZ = stepZ
	dcInfo.wx1 = x1;  dcInfo.wz1 = z1
	dcInfo.wx2 = x2;  dcInfo.wz2 = z2
end

-- ------------------------------------------------
-- flushDiffuseRead()
--   Called at the START of DrawScreen each frame.
--   Completes the deferred ReadPixels from the previous frame's render pass.
--   GPU has had a full frame to finish rendering → no stall.
-- ------------------------------------------------
local function flushDiffuseRead()
	if not dcInfo.pendingRead then return end
	dcInfo.pendingRead = false
	local bboxW  = dcInfo.pendingBboxW
	local bboxH  = dcInfo.pendingBboxH
	local gridW  = dcInfo.pendingGridW
	local gridH  = dcInfo.pendingGridH
	local gridSX = dcInfo.pendingGridSX
	local gridSY = dcInfo.pendingGridSY
	local minSX  = dcInfo.pendingMinSX
	local minSY  = dcInfo.pendingMinSY
	if not (bboxW and bboxH and dcInfo.gridTex) then return end
	local scaleX = dcInfo.pendingScaleX
	local scaleY = dcInfo.pendingScaleY
	local pixels
	gl.RenderToTexture(dcInfo.gridTex, function()
		pixels = gl.ReadPixels(0, 0, bboxW, bboxH)
	end)
	if pixels then
		local total = gridW * gridH
		for i = total + 1, #dcR do dcR[i] = nil; dcG[i] = nil; dcB[i] = nil end
		for gz = 0, gridH - 1 do
			for gx = 0, gridW - 1 do
				local idx  = gz * gridW + gx + 1
				local isx  = gridSX[idx]
				local isy  = gridSY[idx]
				local r, g, b = 0, 0, 0
				if isx and isx >= 0 then
					-- scale screen-space offset → capped FBO pixel coords
					local fx  = max(0, min(bboxW - 1, floor((isx - minSX) * scaleX)))
					local fy  = max(0, min(bboxH - 1, floor((isy - minSY) * scaleY)))
					local row = pixels[fy + 1]
					local px  = row and row[fx + 1]
					if px then r, g, b = px[1], px[2], px[3] end
				end
				dcR[idx] = r
				dcG[idx] = g
				dcB[idx] = b
			end
		end
		dcValid = true
		dcInfo.pendingGridSX = nil
		dcInfo.pendingGridSY = nil
	end
end

-- ------------------------------------------------
-- getDiffuseColorAt(wx, wz)
--   SINGLE lookup function — every consumer calls this.
--   Returns r, g, b (0–1 floats) or nil if cache miss.
-- ------------------------------------------------
local function getDiffuseColorAt(wx, wz)
	if not dcValid then return nil end
	local gW, gH = dcInfo.gridW, dcInfo.gridH
	if gW == 0 or gH == 0 then return nil end

	-- Nearest-neighbor grid lookup
	local gx = floor((wx - dcInfo.wx1) / dcInfo.stepX)
	gx = max(0, min(gW - 1, gx))
	local gz = floor((wz - dcInfo.wz1) / dcInfo.stepZ)
	gz = max(0, min(gH - 1, gz))

	local idx = gz * gW + gx + 1
	local r = dcR[idx]
	if not r then return nil end
	return r, dcG[idx], dcB[idx]
end

-- ------------------------------------------------
-- invalidateDiffuseCache()
--   Clear the cache so next frame rebuilds it.
-- ------------------------------------------------
local function invalidateDiffuseCache()
	dcValid = false
	dcInfo.pendingRead = false
	dcInfo.pendingGridSX = nil
	dcInfo.pendingGridSY = nil
end

-- ------------------------------------------------
-- sampleDiffuseAtPoint(wx, wz)
--   Single-point pipette sample from $map_gbuffer_difftex.
--   Projects world→screen, samples G-buffer via 1×1 FBO (two-pass).
--   Must be called from DrawScreen.
-- ------------------------------------------------
local function sampleDiffuseAtPoint(wx, wz)
	local vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
	local sx, sy = Spring.WorldToScreenCoords(wx, Spring.GetGroundHeight(wx, wz), wz)
	if not sx then return nil end
	local u = max(0, min(1, (sx - vpx) / vsx))
	local v = max(0, min(1, (sy - vpy) / vsy))
	if not dcInfo.fbo then
		dcInfo.fbo = gl.CreateTexture(1, 1, {
			min_filter = GL.NEAREST, mag_filter = GL.NEAREST, fbo = true,
		})
	end
	if not dcInfo.fbo then return nil end
	-- Pass 1: render
	gl.RenderToTexture(dcInfo.fbo, function()
		gl.Texture("$map_gbuffer_difftex")
		gl.TexRect(-1, -1, 1, 1, u, v, u, v)
		gl.Texture(false)
	end)
	-- Pass 2: read
	local r, g, b
	gl.RenderToTexture(dcInfo.fbo, function()
		r, g, b = gl.ReadPixels(0, 0, 1, 1)
	end)
	return r, g, b
end

-- ------------------------------------------------
-- needsCacheRebuild(cx, cz, requiredHalf)
--   Returns true when the cache needs to be rebuilt.
-- ------------------------------------------------
local function needsCacheRebuild(cx, cz, requiredHalf)
	if dcInfo.pendingRead then return false end  -- render submitted, wait for read
	if not dcInfo.gridTex or not dcValid then return true end
	if abs(cx - dcInfo.cx) > CACHE_MIN_STEP then return true end
	if abs(cz - dcInfo.cz) > CACHE_MIN_STEP then return true end
	if dcInfo.halfExtent ~= requiredHalf then return true end
	return false
end

-- ------------------------------------------------
-- Color matching helpers
-- ------------------------------------------------
local function colorDistance(r1, g1, b1, r2, g2, b2)
	local dr = r1 - r2
	local dg = g1 - g2
	local db = b1 - b2
	return sqrt(dr * dr + dg * dg + db * db)
end

local function passesTexFilter(wx, wz)
	if not texFilterEnabled then return true end
	local r, g, b = getDiffuseColorAt(wx, wz)
	if not r then return false end
	local distInclude = colorDistance(r, g, b, texFilterColor[1], texFilterColor[2], texFilterColor[3])
	-- If exclusion color is set: score = distToInclude - distToExclude.
	-- Negative score = closer to include than to exclude = good.
	-- Threshold shifts the margin: score <= threshold allows some closeness to exclude.
	if texFilterColor[4] then
		local distExclude = colorDistance(r, g, b, texFilterColor[5], texFilterColor[6], texFilterColor[7])
		return (distInclude - distExclude) <= (texFilterThreshold - 0.5)
	end
	return distInclude <= texFilterThreshold
end

-- Padding filter: reject points within padding distance of an excluded area.
local function passesPaddingFilter(wx, wz, patchRes, grassApi, config)
	if texFilterPadding <= 0 then return true end
	local padSteps = ceil(texFilterPadding / patchRes)
	for pdx = -padSteps, padSteps do
		for pdz = -padSteps, padSteps do
			local dist = sqrt((pdx * patchRes) ^ 2 + (pdz * patchRes) ^ 2)
			if dist < texFilterPadding then
				local nx = wx + pdx * patchRes
				local nz = wz + pdz * patchRes
				if nx >= 0 and nx <= config.mapSizeX and nz >= 0 and nz <= config.mapSizeZ then
					if not passesTexFilter(nx, nz) then
						return false
					end
				end
			end
		end
	end
	return true
end

-- ============================================================
-- Brush Operations
-- ============================================================

local function ensureEditMode()
	local grassApi = WG['grassgl4']
	if not grassApi then return false end
	if not grassApi.isEditMode() then
		grassApi.enableEditMode()
	end
	return true
end

local function shouldApplyAt(wx, wz, patchRes, grassApi, config)
	if smartEnabled then
		if not isPointValid(wx, wz, smartFilters) then return false end
	end
	if texFilterEnabled then
		if not passesTexFilter(wx, wz) then return false end
		if not passesPaddingFilter(wx, wz, patchRes, grassApi, config) then return false end
	end
	return true
end

local function applyPaintBrush(worldX, worldZ, direction)
	local grassApi = WG['grassgl4']
	if not grassApi or not grassApi.setDensityAt or not grassApi.getDensityAt then return end
	if not grassApi.getConfig then return end

	local config = grassApi.getConfig()
	local patchRes = config.patchResolution

	local xMin = max(0, worldX - brushRadius)
	local xMax = min(config.mapSizeX, worldX + brushRadius)
	local zMin = max(0, worldZ - brushRadius * brushLengthScale)
	local zMax = min(config.mapSizeZ, worldZ + brushRadius * brushLengthScale)

	-- Minimum density that produces visible grass in the GL4 renderer
	local minVisible = (config.grassMinSize or 1) / max(1, config.grassMaxSize or 20)

	local filterActive = smartEnabled or texFilterEnabled

	for x = xMin, xMax, patchRes do
		for z = zMin, zMax, patchRes do
			local dx, dz = x - worldX, z - worldZ
			local inside, normDist = isInsideShape(dx, dz, brushRadius, brushShape, brushRotation, brushLengthScale)
			if inside then
				if shouldApplyAt(x, z, patchRes, grassApi, config) then
					local falloff = computeFalloff(normDist, brushCurve)
					local current = grassApi.getDensityAt(x, z)

					local newDensity
					if direction > 0 then
						-- Paint: max-blend toward target density * falloff
						local desired = targetDensity * falloff
						if desired > 0 and desired < minVisible then desired = minVisible end
						newDensity = max(current, desired)
					else
						-- Remove: reduce by target density * falloff
						local reduction = targetDensity * falloff
						newDensity = current - reduction
						if newDensity < minVisible then newDensity = 0 end
					end
					strokeSamplePatch(x, z)
					grassApi.setDensityAt(x, z, newDensity)
				elseif filterActive and direction > 0 then
					-- Filter rejected this position: clear existing grass
					strokeSamplePatch(x, z)
					grassApi.setDensityAt(x, z, 0)
				end
			end
		end
	end
end

local function applyFillBrush(worldX, worldZ, direction)
	local grassApi = WG['grassgl4']
	if not grassApi or not grassApi.setDensityAt then return end
	if not grassApi.getConfig then return end

	local config = grassApi.getConfig()
	local patchRes = config.patchResolution

	local xMin = max(0, worldX - brushRadius)
	local xMax = min(config.mapSizeX, worldX + brushRadius)
	local zMin = max(0, worldZ - brushRadius * brushLengthScale)
	local zMax = min(config.mapSizeZ, worldZ + brushRadius * brushLengthScale)

	local fillDensity = (direction > 0) and targetDensity or 0
	local filterActive = smartEnabled or texFilterEnabled

	for x = xMin, xMax, patchRes do
		for z = zMin, zMax, patchRes do
			local dx, dz = x - worldX, z - worldZ
			local inside = isInsideShape(dx, dz, brushRadius, brushShape, brushRotation, brushLengthScale)
			if inside then
				if shouldApplyAt(x, z, patchRes, grassApi, config) then
					strokeSamplePatch(x, z)
					grassApi.setDensityAt(x, z, fillDensity)
				elseif filterActive and direction > 0 then
					-- Filter rejected this position: clear existing grass
					strokeSamplePatch(x, z)
					grassApi.setDensityAt(x, z, 0)
				end
			end
		end
	end
end

local function applyEraseBrush(worldX, worldZ)
	local grassApi = WG['grassgl4']
	if not grassApi or not grassApi.setDensityAt or not grassApi.getDensityAt then return end
	if not grassApi.getConfig then return end

	local config = grassApi.getConfig()
	local patchRes = config.patchResolution
	local minVisible = (config.grassMinSize or 1) / max(1, config.grassMaxSize or 20)

	local xMin = max(0, worldX - brushRadius)
	local xMax = min(config.mapSizeX, worldX + brushRadius)
	local zMin = max(0, worldZ - brushRadius * brushLengthScale)
	local zMax = min(config.mapSizeZ, worldZ + brushRadius * brushLengthScale)

	for x = xMin, xMax, patchRes do
		for z = zMin, zMax, patchRes do
			local dx, dz = x - worldX, z - worldZ
			local inside, normDist = isInsideShape(dx, dz, brushRadius, brushShape, brushRotation, brushLengthScale)
			if inside then
				local falloff = computeFalloff(normDist, brushCurve)
				local current = grassApi.getDensityAt(x, z)
				local reduction = targetDensity * falloff
				local newDensity = current - reduction
				if newDensity < minVisible then newDensity = 0 end
				strokeSamplePatch(x, z)
				grassApi.setDensityAt(x, z, newDensity)
			end
		end
	end
end

local function applyBrush(worldX, worldZ)
	local tb = WG.TerraformBrush
	local rotDeg = 0
	if tb and tb.getState then
		local st = tb.getState()
		rotDeg = st.rotationDeg or 0
		-- Pull shared shape so the Shape row selection actually affects grass
		if st.shape then
			local s = st.shape
			if s == "circle" or s == "square" or s == "hexagon" or s == "octagon" or s == "triangle" then
				brushShape = s
			else
				brushShape = "circle"
			end
		end
		brushRotation = rotDeg
	end
	if tb and tb.snapWorld then
		worldX, worldZ = tb.snapWorld(worldX, worldZ, rotDeg)
	end
	local positions
	if tb and tb.getSymmetricPositions then
		positions = tb.getSymmetricPositions(worldX, worldZ, rotDeg)
	end
	if not positions or #positions == 0 then
		positions = { { x = worldX, z = worldZ, rot = rotDeg } }
	end
	for i = 1, #positions do
		local p = positions[i]
		local px, pz = p.x, p.z
		if subMode == "erase" then
			applyEraseBrush(px, pz)
		elseif subMode == "fill" then
			local direction = (paintButton == 1) and 1 or -1
			applyFillBrush(px, pz, direction)
		else
			-- paint mode: LMB = add, RMB = remove
			local direction = (paintButton == 1) and 1 or -1
			applyPaintBrush(px, pz, direction)
		end
	end
end

-- ============================================================
-- Drawing
-- ============================================================

local function getWorldPos()
	local mx, my = GetMouseState()
	local kind, pos = TraceScreenRay(mx, my, true)
	if kind == "ground" then
		return pos[1], pos[3]
	end
	return nil, nil
end

local function drawShapeOutline(worldX, worldZ, radius, shape, angleDeg, lengthScale)
	lengthScale = lengthScale or 1.0
	if shape == "circle" then
		local angleRad = (angleDeg or 0) * pi / 180
		local cosA, sinA = cos(angleRad), sin(angleRad)
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 0, CIRCLE_SEGMENTS - 1 do
				local angle = (i / CIRCLE_SEGMENTS) * 2 * pi
				local lx = radius * cos(angle)
				local lz = radius * lengthScale * sin(angle)
				local x = worldX + lx * cosA - lz * sinA
				local z = worldZ + lx * sinA + lz * cosA
				glVertex(x, GetGroundHeight(x, z) + 2, z)
			end
		end)
	else
		local angleRad = (angleDeg or 0) * pi / 180
		local c, s = cos(angleRad), sin(angleRad)
		if shape == "square" then
			-- axis-aligned square with corners at (±r, ±r*lengthScale) to match inside test
			local corners = { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } }
			glBeginEnd(GL_LINE_LOOP, function()
				for i = 1, 4 do
					local lx = radius * corners[i][1]
					local lz = radius * lengthScale * corners[i][2]
					local dx = lx * c - lz * s
					local dz = lx * s + lz * c
					local x, z = worldX + dx, worldZ + dz
					glVertex(x, GetGroundHeight(x, z) + 2, z)
				end
			end)
			return
		end
		local sides = 4
		if shape == "hexagon" then sides = 6
		elseif shape == "octagon" then sides = 8
		elseif shape == "triangle" then sides = 3 end
		glBeginEnd(GL_LINE_LOOP, function()
			for i = 0, sides - 1 do
				local a = (i / sides) * 2 * pi
				local lx = radius * cos(a)
				local lz = radius * lengthScale * sin(a)
				local dx = lx * c - lz * s
				local dz = lx * s + lz * c
				local x, z = worldX + dx, worldZ + dz
				glVertex(x, GetGroundHeight(x, z) + 2, z)
			end
		end)
	end
end

local function drawSmartFilterOverlay(cx, cz)
	if not smartEnabled and not texFilterEnabled then return end
	local step = FILTER_GRID_STEP
	local halfStep = step * 0.3
	local grassApi = WG['grassgl4']
	if not grassApi or not grassApi.getConfig then return end
	local config = grassApi.getConfig()
	local patchRes = config.patchResolution

	local rad = brushRotation * pi / 180
	local cosR, sinR = cos(rad), sin(rad)

	-- getDiffuseColorAt is a pure table lookup (no GL calls), so
	-- shouldApplyAt is safe to call inside glBeginEnd — no need for
	-- a pre-computed cells table (saves thousands of table allocations).
	glDepthTest(true)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glBeginEnd(GL_TRIANGLES, function()
		for lx = -brushRadius, brushRadius, step do
			for lz = -brushRadius * brushLengthScale, brushRadius * brushLengthScale, step do
				local inside = isInsideShape(lx, lz, brushRadius, brushShape, 0, brushLengthScale)
				if inside then
					local wx = cx + lx * cosR - lz * sinR
					local wz = cz + lx * sinR + lz * cosR
					if shouldApplyAt(wx, wz, patchRes, grassApi, config) then
						glColor(0.2, 0.85, 0.3, 0.08)
					else
						glColor(0.9, 0.15, 0.15, 0.14)
					end
					local y = GetGroundHeight(wx, wz) + 1
					glVertex(wx - halfStep, y, wz - halfStep)
					glVertex(wx + halfStep, y, wz - halfStep)
					glVertex(wx + halfStep, y, wz + halfStep)
					glVertex(wx - halfStep, y, wz + halfStep)
					glVertex(wx + halfStep, y, wz + halfStep)
					glVertex(wx - halfStep, y, wz - halfStep)
				end
			end
		end
	end)
	glDepthTest(false)
end

local function drawCursorInfo(worldX, worldZ)
	local grassApi = WG['grassgl4']
	local currentDensity = 0
	if grassApi and grassApi.getDensityAt then
		currentDensity = grassApi.getDensityAt(worldX, worldZ)
	end

	local sx, sy = WorldToScreenCoords(worldX, GetGroundHeight(worldX, worldZ), worldZ)
	if not sx then return end

	local modeName = subMode:upper()
	local text = format("%s: D%.0f%% R%d [cur: %.0f%%]", modeName, targetDensity * 100, brushRadius, currentDensity * 100)

	glColor(1, 1, 1, 0.9)
	glText(text, sx, sy + 20, 13, "co")
end





-- ============================================================
-- State Management & WG Interface
-- ============================================================

local function activate(mode)
	active = true
	subMode = mode or "paint"
	painting = false
	grassAvailable = ensureEditMode()
	-- Snapshot the current engine command so Update() doesn't
	-- immediately interpret it as a tool switch.
	local _, cmdID = GetActiveCommand()
	lastActiveCmd = cmdID
	local grassApi = WG['grassgl4']
	if grassApi and grassApi.setExternalBrush then
		grassApi.setExternalBrush(true)
	end
	Echo("[Grass Brush] Activated: " .. subMode:upper())
end

local function deactivate()
	if active then
		Echo("[Grass Brush] Deactivated")
	end
	active = false
	painting = false
	paintButton = 0
	local grassApi = WG['grassgl4']
	if grassApi then
		if grassApi.setExternalBrush then
			grassApi.setExternalBrush(false)
		end
		if grassApi.disableEditMode then
			grassApi.disableEditMode()
		end
	end
end

-- Defensive: detect when another tool has been activated (e.g. via keyboard
-- shortcut or direct API call) and self-deactivate so our mouse/draw handlers
-- don't bleed into the other tool's mode.
local function checkConflictAndDeactivate()
	if not active then return false end
	local tfState = WG.TerraformBrush and WG.TerraformBrush.getState()
	if tfState and tfState.active then deactivate(); return true end
	local fpState = WG.FeaturePlacer and WG.FeaturePlacer.getState()
	if fpState and fpState.active then deactivate(); return true end
	local wbState = WG.WeatherBrush and WG.WeatherBrush.getState()
	if wbState and wbState.active then deactivate(); return true end
	local spState = WG.SplatPainter and WG.SplatPainter.getState()
	if spState and spState.active then deactivate(); return true end
	local mbState = WG.MetalBrush and WG.MetalBrush.getState()
	if mbState and mbState.active then deactivate(); return true end
	return false
end

local function setSubMode(mode)
	if mode == "paint" or mode == "fill" or mode == "erase" then
		subMode = mode
	end
end

local function setDensity(v)
	targetDensity = max(MIN_DENSITY, min(MAX_DENSITY, v))
end

local function setRadius(v)
	brushRadius = max(MIN_RADIUS, min(MAX_RADIUS, v))
end

local function setCurve(v)
	brushCurve = max(MIN_CURVE, min(MAX_CURVE, v))
end

local function setRotation(v)
	brushRotation = v % 360
end

local function setLengthScale(v)
	brushLengthScale = max(MIN_LENGTH_SCALE, min(MAX_LENGTH_SCALE, v))
end

local function setShape(shape)
	if shape == "circle" or shape == "square" or shape == "hexagon" or shape == "octagon" or shape == "triangle" then
		brushShape = shape
	end
end

local function setSmartEnabled(val)
	smartEnabled = val and true or false
end

local function setSmartFilter(key, val)
	if smartFilters[key] ~= nil then
		smartFilters[key] = val
	end
end

local function setTexFilterEnabled(val)
	texFilterEnabled = val and true or false
end

local function setTexFilterThreshold(val)
	texFilterThreshold = max(0, min(1.5, val))
end

local function setTexFilterPadding(val)
	texFilterPadding = max(0, min(500, val))
end

local function setTexFilterColor(r, g, b)
	texFilterColor[1] = max(0, min(1, r))
	texFilterColor[2] = max(0, min(1, g))
	texFilterColor[3] = max(0, min(1, b))
end

local function setTexExcludeEnabled(val)
	texFilterColor[4] = val and true or nil
end

local function setTexExcludeColor(r, g, b)
	texFilterColor[5] = max(0, min(1, r))
	texFilterColor[6] = max(0, min(1, g))
	texFilterColor[7] = max(0, min(1, b))
end

local function setPipetteMode(val)
	pipetteMode = val and true or false
	if not val then pipettePending = nil end
end

local function setPipetteExcludeMode(val)
	pipetteExcludeMode = val and true or false
	if not val then pipetteExcludePending = nil end
end

local function getState()
	return {
		active = active,
		subMode = subMode,
		density = targetDensity,
		radius = brushRadius,
		curve = brushCurve,
		rotationDeg = brushRotation,
		lengthScale = brushLengthScale,
		shape = brushShape,
		smartEnabled = smartEnabled,
		smartFilters = smartFilters,
		texFilterEnabled = texFilterEnabled,
		texFilterColor = texFilterColor,
		texFilterThreshold = texFilterThreshold,
		texFilterPadding = texFilterPadding,
		texExcludeEnabled = texFilterColor[4] and true or false,
		pipetteMode = pipetteMode,
		pipetteExcludeMode = pipetteExcludeMode,
		historyIndex = #undoStack,
		historyMax   = #undoStack + #redoStack,
	}
end

function widget:Initialize()
	WG.GrassBrush = {
		activate       = activate,
		deactivate     = deactivate,
		getState       = getState,
		setSubMode     = setSubMode,
		setDensity     = setDensity,
		setRadius      = setRadius,
		setCurve       = setCurve,
		setRotation    = setRotation,
		setLengthScale = setLengthScale,
		setShape       = setShape,
		setSmartEnabled   = setSmartEnabled,
		setSmartFilter    = setSmartFilter,
		setTexFilterEnabled  = setTexFilterEnabled,
		setTexFilterThreshold = setTexFilterThreshold,
		setTexFilterPadding   = setTexFilterPadding,
		setTexFilterColor     = setTexFilterColor,
		setTexExcludeEnabled  = setTexExcludeEnabled,
		setTexExcludeColor    = setTexExcludeColor,
		setPipetteMode        = setPipetteMode,
		setPipetteExcludeMode = setPipetteExcludeMode,
		saveGrassMap   = saveGrassMap,
		undo           = grassUndo,
		redo           = grassRedo,
		undoToIndex    = grassUndoToIndex,
	}
end

function widget:Shutdown()
	local grassApi = WG['grassgl4']
	if grassApi then
		if grassApi.setExternalBrush then
			grassApi.setExternalBrush(false)
		end
		if grassApi.disableEditMode then
			grassApi.disableEditMode()
		end
	end
	if dcInfo.fbo then gl.DeleteTexture(dcInfo.fbo); dcInfo.fbo = nil end
	if dcInfo.gridTex then gl.DeleteTexture(dcInfo.gridTex); dcInfo.gridTex = nil end
	dcValid = false
	WG.GrassBrush = nil
end

-- Never claim mouse-above so camera MMB panning is not blocked
function widget:IsAbove(x, y)
	return false
end

function widget:MousePress(mx, my, button)
	if not active then return false end
	if checkConflictAndDeactivate() then return false end
	if not IsCheatingEnabled() then return false end

	-- Middle mouse: always pass through for camera
	if button == 2 then return false end

	-- Defer to measure tool when active so grass paint doesn't consume the click
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

	-- Pipette mode: LMB clicks terrain to sample diffuse color
	if pipetteMode and button == 1 then
		pipettePending = { wx = worldX, wz = worldZ }
		pipetteMode = false
		return true
	end

	-- Exclude pipette mode: LMB clicks terrain to sample exclusion color
	if pipetteExcludeMode and button == 1 then
		pipetteExcludePending = { wx = worldX, wz = worldZ }
		pipetteExcludeMode = false
		return true
	end

	if button == 1 or button == 3 then
		paintButton = button
		if not grassAvailable then
			grassAvailable = ensureEditMode()
		end
		if subMode == "fill" then
			strokeBegin()
			applyBrush(worldX, worldZ)
			strokeEnd()
			return true
		else
			strokeBegin()
			painting = true
			lastPaintTime = 0
			applyBrush(worldX, worldZ)
			return true
		end
	end

	return false
end

function widget:MouseRelease(mx, my, button)
	if painting and button == paintButton then
		strokeEnd()
		painting = false
		paintButton = 0
	end
end

function widget:MouseWheel(up, value)
	if not active then return false end
	if checkConflictAndDeactivate() then return false end

	local alt, ctrl, _, shift = GetModKeyState()
	local spaceHeld = GetKeyState(KEYSYMS_SPACE)

	-- Alt+Ctrl: length scale
	if alt and ctrl then
		if up then
			setLengthScale(brushLengthScale + LENGTH_SCALE_STEP)
		else
			setLengthScale(brushLengthScale - LENGTH_SCALE_STEP)
		end
		return true
	end

	-- Alt: rotation (snap to TB protractor step when angleSnap on)
	if alt then
		local step = ROTATION_STEP
		local tb = WG.TerraformBrush
		local tbs = tb and tb.getState and tb.getState() or nil
		if tbs and tbs.angleSnap and (tbs.angleSnapStep or 0) > 0 then
			step = tbs.angleSnapStep
		end
		setRotation(brushRotation + (up and step or -step))
		return true
	end

	-- Shift: curve
	if shift then
		if up then
			setCurve(brushCurve + CURVE_STEP)
		else
			setCurve(brushCurve - CURVE_STEP)
		end
		return true
	end

	-- Space: density
	if spaceHeld then
		if up then
			setDensity(targetDensity + DENSITY_STEP)
		else
			setDensity(targetDensity - DENSITY_STEP)
		end
		return true
	end

	-- Ctrl: size
	if ctrl then
		if up then
			setRadius(brushRadius + RADIUS_STEP)
		else
			setRadius(brushRadius - RADIUS_STEP)
		end
		return true
	end

	return false
end

function widget:Update(dt)
	if not active then return end
	if checkConflictAndDeactivate() then return end

	-- Detect if the user selected an engine command (attack, move, build, etc.)
	local _, cmdID = GetActiveCommand()
	if cmdID and cmdID ~= lastActiveCmd then
		-- An engine command became active — user switched away from grass brush
		deactivate()
		lastActiveCmd = cmdID
		return
	end
	lastActiveCmd = cmdID

	if not painting then return end

	lastPaintTime = lastPaintTime + dt
	if lastPaintTime < UPDATE_INTERVAL then return end
	lastPaintTime = 0

	local worldX, worldZ = getWorldPos()
	if not worldX then return end

	applyBrush(worldX, worldZ)
end

function widget:KeyPress(key, mods, isRepeat)
	if not active then return false end
	if key == KEYSYMS_ESCAPE then
		if pipetteMode then
			setPipetteMode(false)
			return true
		end
		if pipetteExcludeMode then
			setPipetteExcludeMode(false)
			return true
		end
		deactivate()
		return true
	end
	if key == 122 and mods.ctrl then  -- Ctrl+Z
		if mods.shift then
			grassRedo()
		else
			grassUndo()
		end
		return true
	end
	return false
end

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if active then
		deactivate()
	end
	return false
end

function widget:DrawWorld()
	if not active then return end
	if checkConflictAndDeactivate() then return end

	local worldX, worldZ = getWorldPos()
	if not worldX then return end

	-- Smart filter / texture filter overlay
	drawSmartFilterOverlay(worldX, worldZ)

	-- Brush outline color: green = add, red = remove/erase
	local colorR, colorG, colorB = 0.06, 0.72, 0.51
	if subMode == "erase" then
		colorR, colorG, colorB = 1.0, 0.3, 0.3
	elseif subMode == "fill" then
		if paintButton == 3 then
			colorR, colorG, colorB = 1.0, 0.3, 0.0
		else
			colorR, colorG, colorB = 0.2, 0.9, 0.4
		end
	elseif paintButton == 3 then
		colorR, colorG, colorB = 1.0, 0.3, 0.3
	end

	glColor(colorR, colorG, colorB, 0.85)
	glLineWidth(2)
	-- Sync shape/rotation from shared state for outline preview
	do
		local tb = WG.TerraformBrush
		if tb and tb.getState then
			local st = tb.getState()
			if st.shape == "circle" or st.shape == "square" or st.shape == "hexagon" or st.shape == "octagon" or st.shape == "triangle" then
				brushShape = st.shape
			end
			brushRotation = st.rotationDeg or brushRotation
		end
	end
	drawShapeOutline(worldX, worldZ, brushRadius, brushShape, brushRotation, brushLengthScale)

	-- Center cross
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
	if checkConflictAndDeactivate() then return end

	-- Complete deferred ReadPixels from previous frame (GPU already done → no stall)
	flushDiffuseRead()

	local worldX, worldZ = getWorldPos()
	if not worldX then return end

	-- Process pending pipette sample (queued by MousePress, executed here in DrawScreen GL context)
	if pipettePending then
		local pw, pz = pipettePending.wx, pipettePending.wz
		pipettePending = nil
		local sr, sg, sb = sampleDiffuseAtPoint(pw, pz)
		if sr then
			setTexFilterColor(sr, sg, sb)
			texFilterEnabled = true
			invalidateDiffuseCache()
		end
	end

	-- Process pending exclude pipette sample
	if pipetteExcludePending then
		local pw, pz = pipetteExcludePending.wx, pipetteExcludePending.wz
		pipetteExcludePending = nil
		local sr, sg, sb = sampleDiffuseAtPoint(pw, pz)
		if sr then
			setTexExcludeColor(sr, sg, sb)
			setTexExcludeEnabled(true)
			invalidateDiffuseCache()
		end
	end

	-- Build/refresh diffuse cache (viewport FBO, two-pass) in DrawScreen GL context
	if texFilterEnabled then
		local brushHalf = max(brushRadius, brushRadius * brushLengthScale) + CACHE_MARGIN
		if needsCacheRebuild(worldX, worldZ, brushHalf) then
			buildDiffuseCache(worldX, worldZ, brushHalf)
		end
	end

	drawCursorInfo(worldX, worldZ)
end
