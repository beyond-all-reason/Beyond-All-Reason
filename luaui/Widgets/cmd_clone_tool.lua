function widget:GetInfo()
	return {
		name = "Clone Tool",
		desc = "Select, copy, and paste map regions (terrain, metal, features, splats, grass, decals, weather, lights)",
		author = "BARb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

-- ---------------------------------------------------------------------------
-- Spring API aliases
-- ---------------------------------------------------------------------------
local spGetGroundHeight       = Spring.GetGroundHeight
local spGetMetalAmount        = Spring.GetMetalAmount
local spGetMetalMapSize       = Spring.GetMetalMapSize
local spTraceScreenRay        = Spring.TraceScreenRay
local spGetMouseState         = Spring.GetMouseState
local spGetModKeyState        = Spring.GetModKeyState
local spSendLuaRulesMsg       = Spring.SendLuaRulesMsg
local spIsCheatingEnabled     = Spring.IsCheatingEnabled
local spGetAllFeatures        = Spring.GetAllFeatures
local spGetFeaturesInRectangle = Spring.GetFeaturesInRectangle
local spGetFeatureDefID       = Spring.GetFeatureDefID
local spGetFeaturePosition    = Spring.GetFeaturePosition
local spGetFeatureHeading     = Spring.GetFeatureHeading
local spGetFeatureRotation    = Spring.GetFeatureRotation
local spGetGroundNormal       = Spring.GetGroundNormal
local spEcho                  = Spring.Echo
local spGetGameFrame          = Spring.GetGameFrame

local glColor            = gl.Color
local glLineWidth        = gl.LineWidth
local glDepthTest        = gl.DepthTest
local glBeginEnd         = gl.BeginEnd
local glVertex           = gl.Vertex
local glPolygonOffset    = gl.PolygonOffset
local glBlending         = gl.Blending
local glTexture          = gl.Texture
local glTexRect          = gl.TexRect
local glCreateTexture    = gl.CreateTexture
local glDeleteTexture    = gl.DeleteTexture
local glRenderToTexture  = gl.RenderToTexture
local glReadPixels       = gl.ReadPixels

local GL_LINE_LOOP       = GL.LINE_LOOP
local GL_LINES           = GL.LINES
local GL_QUADS           = GL.QUADS
local GL_TRIANGLE_FAN    = GL.TRIANGLE_FAN
local GL_SRC_ALPHA       = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local floor = math.floor
local ceil  = math.ceil
local min   = math.min
local max   = math.max
local cos   = math.cos
local sin   = math.sin
local rad   = math.rad
local abs   = math.abs
local huge  = math.huge
local pi    = math.pi

local Game = Game
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local squareSize = Game.squareSize or 8
local metalSquareSize = 16

-- ---------------------------------------------------------------------------
-- Message headers (must match gadget)
-- ---------------------------------------------------------------------------
local MSG_TERRAIN         = "$clone_terrain$"
local MSG_METAL           = "$clone_metal$"
local MSG_FEATURES        = "$clone_features$"
local MSG_FEATURES_CLEAR  = "$clone_features_clear$"
local MSG_UNDO            = "$clone_undo$"
local MSG_REDO            = "$clone_redo$"
local MSG_TBEGIN          = "$clone_tbegin$"
local MSG_TGRID           = "$clone_tgrid$"
local MSG_TEND            = "$clone_tend$"

local TERRAIN_CHUNK_SIZE  = 400 -- vertices per message (legacy triplet format)
local GRID_HEIGHTS_PER_CHUNK = 3000 -- heights per grid message (~15KB)

-- ---------------------------------------------------------------------------
-- Tool state
-- ---------------------------------------------------------------------------
local active = false

-- States: "idle", "selecting", "box_drawn", "copied", "paste_preview"
local state = "idle"

-- Selection box (world coords)
local selBox = { x1 = 0, z1 = 0, x2 = 0, z2 = 0 }

-- Box manipulation state
local boxDrag = {
	active = false,
	handle = nil, -- "tl","tr","bl","br","top","bot","left","right","center"
	anchorX = 0, anchorZ = 0,
	origBox = nil,
}

-- Layer toggles
local layers = {
	terrain  = true,
	metal    = true,
	features = true,
	splats   = true,
	grass    = true,
	decals   = false,
	weather  = false,
	lights   = false,
}

-- Clone buffer
local cloneBuffer = nil

-- Paste state
local pasteRotation = 0
local pasteHeightOffset = 0
local pasteMirrorX = false
local pasteMirrorZ = false

-- Terrain quality: "full" (float, step=8), "balanced" (int, step=8), "fast" (int, step=24, gadget fill)
local terrainQuality = "balanced"

-- Undo/redo history counts (synced from gadget via CloneToolStackUpdate)
local historyUndoCount = 0
local historyRedoCount = 0

-- Coroutine for async operations
local activeCoroutine = nil
local coroutineProgress = 0
local coroutineLabel = ""

-- Splat FBO
local splatCaptureFBO = nil
local splatCaptureW = 0
local splatCaptureH = 0
local SPLAT_TEX_NAME = "$ssmf_splat_distr"
local pendingSplatCapture = nil  -- deferred GL capture (GL calls need Draw context)
local pendingSplatPaste = nil    -- deferred GL paste (GL calls need Draw context)

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function sendMsg(msg)
	spSendLuaRulesMsg(spIsCheatingEnabled() and ("$c$" .. msg) or msg)
end

local function getWorldMousePosition()
	local mx, my = spGetMouseState()
	local _, pos = spTraceScreenRay(mx, my, true)
	if pos then
		return pos[1], pos[3]
	end
	return nil, nil
end

local function clampToMap(x, z)
	return max(0, min(mapSizeX, x)), max(0, min(mapSizeZ, z))
end

local function normalizeBox(b)
	local x1 = min(b.x1, b.x2)
	local z1 = min(b.z1, b.z2)
	local x2 = max(b.x1, b.x2)
	local z2 = max(b.z1, b.z2)
	return { x1 = x1, z1 = z1, x2 = x2, z2 = z2 }
end

-- Transform a local point for paste (mirror, rotate, translate)
local function transformPoint(lx, lz, sizeX, sizeZ, rot, mirX, mirZ, targetX, targetZ)
	if mirX then lx = sizeX - lx end
	if mirZ then lz = sizeZ - lz end
	local cx, cz = sizeX * 0.5, sizeZ * 0.5
	local dx, dz = lx - cx, lz - cz
	local cosR = cos(rot)
	local sinR = sin(rot)
	local rx = dx * cosR - dz * sinR
	local rz = dx * sinR + dz * cosR
	return rx + targetX, rz + targetZ
end

-- ---------------------------------------------------------------------------
-- Activate / Deactivate API
-- ---------------------------------------------------------------------------
local function activate()
	active = true
	state = "idle"
	cloneBuffer = nil
	pasteRotation = 0
	pasteHeightOffset = 0
	pasteMirrorX = false
	pasteMirrorZ = false
end

local function deactivate()
	active = false
	state = "idle"
	activeCoroutine = nil
	coroutineProgress = 0
	boxDrag.active = false
end

local function getState()
	return {
		active = active,
		state = state,
		layers = layers,
		pasteRotation = pasteRotation,
		pasteHeightOffset = pasteHeightOffset,
		pasteMirrorX = pasteMirrorX,
		pasteMirrorZ = pasteMirrorZ,
		progress = coroutineProgress,
		progressLabel = coroutineLabel,
		hasBuffer = cloneBuffer ~= nil,
		selBox = (state ~= "idle") and normalizeBox(selBox) or nil,
		undoCount = historyUndoCount,
		redoCount = historyRedoCount,
		terrainQuality = terrainQuality,
	}
end

local function setLayer(name, enabled)
	if layers[name] ~= nil then
		layers[name] = enabled
	end
end

local function setTerrainQuality(q)
	if q == "full" or q == "balanced" or q == "fast" then
		terrainQuality = q
	end
end

local function setRotation(deg)
	pasteRotation = deg % 360
end

local function setHeightOffset(val)
	pasteHeightOffset = val
end

local function setMirrorX(val)
	pasteMirrorX = val
end

local function setMirrorZ(val)
	pasteMirrorZ = val
end

-- ---------------------------------------------------------------------------
-- COPY: capture data from selection box
-- ---------------------------------------------------------------------------
local function doCopy()
	local box = normalizeBox(selBox)
	local sizeX = box.x2 - box.x1
	local sizeZ = box.z2 - box.z1
	if sizeX < squareSize or sizeZ < squareSize then
		spEcho("[Clone Tool] Selection too small")
		return
	end

	local buf = {
		originX = box.x1,
		originZ = box.z1,
		sizeX = sizeX,
		sizeZ = sizeZ,
		enabledLayers = {},
	}

	for k, v in pairs(layers) do
		buf.enabledLayers[k] = v
	end

	-- Terrain
	if layers.terrain then
		local grid = {}
		local stepX = squareSize
		local stepZ = squareSize
		local minH = huge
		local cols = floor(sizeX / stepX) + 1
		local rows = floor(sizeZ / stepZ) + 1
		for r = 0, rows - 1 do
			local rowData = {}
			for c = 0, cols - 1 do
				local wx = box.x1 + c * stepX
				local wz = box.z1 + r * stepZ
				wx = min(wx, mapSizeX)
				wz = min(wz, mapSizeZ)
				local h = spGetGroundHeight(wx, wz)
				if h < minH then minH = h end
				rowData[c + 1] = h
			end
			grid[r + 1] = rowData
		end
		buf.terrain = {
			baseHeight = minH,
			grid = grid,
			stepX = stepX,
			stepZ = stepZ,
			cols = cols,
			rows = rows,
		}
	end

	-- Metal
	if layers.metal then
		local metalData = {}
		local mSizeX, mSizeZ = spGetMetalMapSize()
		local startMX = floor(box.x1 / metalSquareSize)
		local startMZ = floor(box.z1 / metalSquareSize)
		local endMX = ceil(box.x2 / metalSquareSize)
		local endMZ = ceil(box.z2 / metalSquareSize)
		startMX = max(0, min(startMX, mSizeX - 1))
		startMZ = max(0, min(startMZ, mSizeZ - 1))
		endMX = max(0, min(endMX, mSizeX - 1))
		endMZ = max(0, min(endMZ, mSizeZ - 1))
		for mz = startMZ, endMZ do
			for mx = startMX, endMX do
				local val = spGetMetalAmount(mx, mz)
				if val and val > 0 then
					metalData[#metalData + 1] = {
						lx = mx * metalSquareSize - box.x1,
						lz = mz * metalSquareSize - box.z1,
						mx = mx,
						mz = mz,
						val = val,
					}
				end
			end
		end
		buf.metal = metalData
	end

	-- Features
	if layers.features then
		local feats = spGetFeaturesInRectangle(box.x1, box.z1, box.x2, box.z2)
		local featureData = {}
		if feats then
			for _, fid in ipairs(feats) do
				local defID = spGetFeatureDefID(fid)
				local def = FeatureDefs[defID]
				if def then
					local fx, fy, fz = spGetFeaturePosition(fid)
					local heading = spGetFeatureHeading(fid) or 0
					featureData[#featureData + 1] = {
						defName = def.name,
						lx = fx - box.x1,
						ly = fy,
						lz = fz - box.z1,
						heading = heading,
					}
				end
			end
		end
		buf.features = featureData
	end

	-- Splats: defer GL capture to next DrawWorld (GL calls not allowed in KeyPress)
	if layers.splats then
		local texInfo = gl.TextureInfo(SPLAT_TEX_NAME)
		if texInfo then
			local tw, th = texInfo.xsize, texInfo.ysize
			local u0 = box.x1 / mapSizeX
			local v0 = box.z1 / mapSizeZ
			local u1 = box.x2 / mapSizeX
			local v1 = box.z2 / mapSizeZ
			local pw = max(1, floor((u1 - u0) * tw))
			local ph = max(1, floor((v1 - v0) * th))
			pendingSplatCapture = {
				u0 = u0, v0 = v0, u1 = u1, v1 = v1,
				pw = pw, ph = ph,
			}
		end
	end

	-- Grass
	if layers.grass then
		local grassApi = WG['grassgl4']
		if grassApi and grassApi.getDensityAt then
			local grassData = {}
			local gStep = 32 -- grass patch resolution
			for lz = 0, sizeZ, gStep do
				for lx = 0, sizeX, gStep do
					local wx = box.x1 + lx
					local wz = box.z1 + lz
					if wx <= mapSizeX and wz <= mapSizeZ then
						local density = grassApi.getDensityAt(wx, wz)
						if density and density > 0 then
							grassData[#grassData + 1] = { lx = lx, lz = lz, density = density }
						end
					end
				end
			end
			buf.grass = grassData
		end
	end

	-- Decals
	if layers.decals and Spring.GetAllGroundDecals then
		local decalData = {}
		local allDecals = Spring.GetAllGroundDecals()
		if allDecals then
			for _, did in ipairs(allDecals) do
				local dx, _, dz = Spring.GetGroundDecalPosition(did)
				if dx and dx >= box.x1 and dx <= box.x2 and dz >= box.z1 and dz <= box.z2 then
					local sx, sz = Spring.GetGroundDecalSize(did)
					local dRot = Spring.GetGroundDecalRotation(did)
					local dAlpha = Spring.GetGroundDecalAlpha(did)
					local texName = Spring.GetGroundDecalTexture(did, true)
					local normTex = Spring.GetGroundDecalTexture(did, false)
					decalData[#decalData + 1] = {
						lx = dx - box.x1,
						lz = dz - box.z1,
						sizeX = sx, sizeZ = sz,
						rotation = dRot,
						alpha = dAlpha,
						tex = texName,
						normTex = normTex,
					}
				end
			end
		end
		buf.decals = decalData
	end

	-- Weather (read from weather brush widget state)
	if layers.weather then
		local weatherApi = WG.WeatherBrush
		if weatherApi and weatherApi.getState then
			local ws = weatherApi.getState()
			-- Weather stores active placements; capture those in our box
			buf.weather = {} -- Will be populated if weather brush exposes placed instances
		end
	end

	-- Lights (read from light placer widget state)
	if layers.lights then
		local lightApi = WG.LightPlacer
		if lightApi and lightApi.getState then
			local ls = lightApi.getState()
			if ls and ls.placedLights then
				local lightData = {}
				for _, light in ipairs(ls.placedLights) do
					if light.x and light.x >= box.x1 and light.x <= box.x2
						and light.z and light.z >= box.z1 and light.z <= box.z2 then
						lightData[#lightData + 1] = {
							lx = light.x - box.x1,
							ly = light.y or 0,
							lz = light.z - box.z1,
							params = light.params,
						}
					end
				end
				buf.lights = lightData
			end
		end
	end

	cloneBuffer = buf
	state = "copied"
	spEcho("[Clone Tool] Region copied")
end

local function doUndo()
	if historyUndoCount > 0 then
		sendMsg(MSG_UNDO)
	end
end

local function doRedo()
	if historyRedoCount > 0 then
		sendMsg(MSG_REDO)
	end
end

-- ---------------------------------------------------------------------------
-- PASTE: apply clone buffer at target position
-- ---------------------------------------------------------------------------
local function startPaste()
	if not cloneBuffer then
		spEcho("[Clone Tool] Nothing copied")
		return
	end
	state = "paste_preview"
end

local function applyPaste(targetX, targetZ)
	if not cloneBuffer then return end
	if not spIsCheatingEnabled() then
		spEcho("[Clone Tool] WARNING: Cheats are not enabled - paste will be blocked by gadget! Enable cheats first.")
		return
	end
	local buf = cloneBuffer
	local rotRad = rad(pasteRotation)

	-- Helper to build grid-based terrain messages with quality control
	local function applyTerrain()
		if not buf.terrain then return end
		local t = buf.terrain
		local sX, sZ = buf.sizeX, buf.sizeZ
		local cx, cz = sX * 0.5, sZ * 0.5
		local cosR = cos(rotRad)
		local sinR = sin(rotRad)

		-- Quality determines paste step and height formatting
		local pasteStep = squareSize
		local formatHeight
		if terrainQuality == "full" then
			formatHeight = function(h) return string.format("%.2f", h) end
		elseif terrainQuality == "fast" then
			pasteStep = squareSize * 3  -- 24: 9x fewer source vertices
			formatHeight = function(h) return tostring(floor(h + 0.5)) end
		else -- "balanced"
			formatHeight = function(h) return tostring(floor(h + 0.5)) end
		end

		-- Compute rotated AABB in world space
		local corners = {
			{0, 0}, {sX, 0}, {sX, sZ}, {0, sZ}
		}
		local wMinX, wMinZ = huge, huge
		local wMaxX, wMaxZ = -huge, -huge
		for i = 1, 4 do
			local lx, lz = corners[i][1], corners[i][2]
			if pasteMirrorX then lx = sX - lx end
			if pasteMirrorZ then lz = sZ - lz end
			local dx, dz = lx - cx, lz - cz
			local wx = dx * cosR - dz * sinR + targetX
			local wz = dx * sinR + dz * cosR + targetZ
			if wx < wMinX then wMinX = wx end
			if wx > wMaxX then wMaxX = wx end
			if wz < wMinZ then wMinZ = wz end
			if wz > wMaxZ then wMaxZ = wz end
		end

		-- Snap to paste grid and clamp to map
		local gx0 = max(0, floor(wMinX / pasteStep) * pasteStep)
		local gz0 = max(0, floor(wMinZ / pasteStep) * pasteStep)
		local gx1 = min(mapSizeX, ceil(wMaxX / pasteStep) * pasteStep)
		local gz1 = min(mapSizeZ, ceil(wMaxZ / pasteStep) * pasteStep)

		-- Grid dimensions
		local cols = floor((gx1 - gx0) / pasteStep) + 1
		local rows = floor((gz1 - gz0) / pasteStep) + 1
		if cols <= 0 or rows <= 0 then return end

		-- Inverse rotation matrix
		local icosR = cosR
		local isinR = -sinR

		-- Source grid bounds for bilinear sampling
		local maxCol = t.cols - 1
		local maxRow = t.rows - 1
		local stepX = t.stepX
		local stepZ = t.stepZ

		-- Build height grid (row-major flat array of formatted strings)
		local gridBuf = {}
		local idx = 0
		for r = 0, rows - 1 do
			local wz = gz0 + r * pasteStep
			for c = 0, cols - 1 do
				local wx = gx0 + c * pasteStep
				local h

				-- Inverse transform: world → local source coords
				local dx, dz = wx - targetX, wz - targetZ
				local lx = dx * icosR - dz * isinR + cx
				local lz = dx * isinR + dz * icosR + cz
				if pasteMirrorX then lx = sX - lx end
				if pasteMirrorZ then lz = sZ - lz end

				-- Check if inside source bounds
				if lx >= -0.5 and lx <= sX + 0.5 and lz >= -0.5 and lz <= sZ + 0.5 then
					-- Bilinear interpolation in source grid
					local gc = lx / stepX
					local gr = lz / stepZ
					local c0 = max(0, min(maxCol, floor(gc)))
					local r0 = max(0, min(maxRow, floor(gr)))
					local c1 = min(maxCol, c0 + 1)
					local r1 = min(maxRow, r0 + 1)
					local fc = gc - c0
					local fr = gr - r0
					fc = max(0, min(1, fc))
					fr = max(0, min(1, fr))

					local h00 = t.grid[r0 + 1][c0 + 1]
					local h10 = t.grid[r0 + 1][c1 + 1]
					local h01 = t.grid[r1 + 1][c0 + 1]
					local h11 = t.grid[r1 + 1][c1 + 1]
					h = h00 * (1 - fc) * (1 - fr)
						+ h10 * fc * (1 - fr)
						+ h01 * (1 - fc) * fr
						+ h11 * fc * fr
					h = h + pasteHeightOffset
				else
					-- Outside source: keep current ground height
					h = spGetGroundHeight(wx, wz)
				end

				idx = idx + 1
				gridBuf[idx] = formatHeight(h)
			end
		end

		-- Send begin message (tells gadget the full grid extent)
		sendMsg(MSG_TBEGIN .. gx0 .. " " .. gz0 .. " " .. pasteStep .. " "
			.. squareSize .. " " .. cols .. " " .. rows)

		-- Send grid chunks (by rows)
		local rowsPerChunk = max(1, floor(GRID_HEIGHTS_PER_CHUNK / cols))
		local rowOffset = 0
		while rowOffset < rows do
			local rc = min(rowsPerChunk, rows - rowOffset)
			local parts = { tostring(rowOffset), tostring(rc) }
			local startIdx = rowOffset * cols + 1
			local endIdx = (rowOffset + rc) * cols
			for i = startIdx, endIdx do
				parts[#parts + 1] = gridBuf[i]
			end
			sendMsg(MSG_TGRID .. table.concat(parts, " "))
			rowOffset = rowOffset + rc
		end

		-- Send end message (triggers gadget fill + undo push)
		sendMsg(MSG_TEND)
	end

	-- Metal
	local function applyMetal()
		if not buf.metal then return end
		local entries = {}
		for _, m in ipairs(buf.metal) do
			local wx, wz = transformPoint(m.lx, m.lz, buf.sizeX, buf.sizeZ,
				rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
			wx, wz = clampToMap(wx, wz)
			local mx = floor(wx / metalSquareSize)
			local mz = floor(wz / metalSquareSize)
			entries[#entries + 1] = tostring(mx) .. " " .. tostring(mz) .. " " .. tostring(m.val)
		end
		if #entries > 0 then
			-- Chunk
			local offset = 0
			while offset < #entries do
				local chunkSize = min(200, #entries - offset)
				local parts = { tostring(chunkSize) }
				for i = 1, chunkSize do
					parts[#parts + 1] = entries[offset + i]
				end
				sendMsg(MSG_METAL .. table.concat(parts, " "))
				offset = offset + chunkSize
			end
		end
	end

	-- Features
	local function applyFeatures()
		if not buf.features then
			spEcho("[Clone Tool] Features: skipped (layer was off during copy)")
			return
		end
		local featureCount = #buf.features
		spEcho("[Clone Tool] Features: pasting " .. featureCount .. " feature(s)")
		if featureCount == 0 then
			spEcho("[Clone Tool] Features: buffer empty, skipping clear+create")
			return
		end
		-- Clear target area first
		local clearSizeX = buf.sizeX
		local clearSizeZ = buf.sizeZ
		-- Calculate rotated bounding box for clearing
		local cx1, cz1 = transformPoint(0, 0, clearSizeX, clearSizeZ,
			rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
		local cx2, cz2 = transformPoint(clearSizeX, clearSizeZ, clearSizeX, clearSizeZ,
			rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
		local cx3, cz3 = transformPoint(clearSizeX, 0, clearSizeX, clearSizeZ,
			rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
		local cx4, cz4 = transformPoint(0, clearSizeZ, clearSizeX, clearSizeZ,
			rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
		local clearX1 = min(cx1, cx2, cx3, cx4)
		local clearZ1 = min(cz1, cz2, cz3, cz4)
		local clearX2 = max(cx1, cx2, cx3, cx4)
		local clearZ2 = max(cz1, cz2, cz3, cz4)
		clearX1, clearZ1 = clampToMap(clearX1, clearZ1)
		clearX2, clearZ2 = clampToMap(clearX2, clearZ2)
		sendMsg(MSG_FEATURES_CLEAR .. floor(clearX1) .. " " .. floor(clearZ1) .. " " .. floor(clearX2) .. " " .. floor(clearZ2))

		-- Send features in chunks of 50
		local offset = 0
		while offset < #buf.features do
			local chunkSize = min(50, #buf.features - offset)
			local parts = { tostring(chunkSize) }
			for i = 1, chunkSize do
				local f = buf.features[offset + i]
				local wx, wz = transformPoint(f.lx, f.lz, buf.sizeX, buf.sizeZ,
					rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
				wx, wz = clampToMap(wx, wz)
				local wy = spGetGroundHeight(wx, wz)
				local newHeading = f.heading
				if pasteRotation ~= 0 then
					-- heading is 0-65535 range, add rotation
					newHeading = (newHeading + floor(pasteRotation / 360 * 65536)) % 65536
				end
				if pasteMirrorX then
					newHeading = (65536 - newHeading) % 65536
				end
				if pasteMirrorZ then
					newHeading = (32768 - newHeading) % 65536
				end
				parts[#parts + 1] = f.defName
				parts[#parts + 1] = tostring(floor(wx))
				parts[#parts + 1] = tostring(floor(wy))
				parts[#parts + 1] = tostring(floor(wz))
				parts[#parts + 1] = tostring(newHeading)
			end
			sendMsg(MSG_FEATURES .. table.concat(parts, " "))
			offset = offset + chunkSize
		end
	end

	-- Splats: defer GL operations to next DrawWorld
	local function applySplats()
		if not buf.splats or not buf.splats.pixels then return end
		local splatTexInfo = gl.TextureInfo(SPLAT_TEX_NAME)
		if not splatTexInfo then return end
		pendingSplatPaste = {
			tw = splatTexInfo.xsize,
			th = splatTexInfo.ysize,
			fboHandle = buf.splats.fboHandle,
			sizeX = buf.sizeX,
			sizeZ = buf.sizeZ,
			targetX = targetX,
			targetZ = targetZ,
		}
	end

	-- Grass
	local function applyGrass()
		if not buf.grass then return end
		local grassApi = WG['grassgl4']
		if not grassApi or not grassApi.setDensityAt then return end
		if grassApi.enableEditMode then
			grassApi.enableEditMode()
		end
		-- Suppress the built-in grass painting UI while we write density values,
		-- otherwise placementMode=true + externalBrushActive=false causes the
		-- grassgl4 widget to intercept all subsequent mouse clicks.
		if grassApi.setExternalBrush then
			grassApi.setExternalBrush(true)
		end
		for _, g in ipairs(buf.grass) do
			local wx, wz = transformPoint(g.lx, g.lz, buf.sizeX, buf.sizeZ,
				rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
			wx, wz = clampToMap(wx, wz)
			grassApi.setDensityAt(wx, wz, g.density)
		end
		-- Flush spawn animations and disable the external-brush flag so the
		-- grassgl4 widget returns to its normal dormant state.
		if grassApi.setExternalBrush then
			grassApi.setExternalBrush(false)
		end
		if grassApi.disableEditMode then
			grassApi.disableEditMode()
		end
	end

	-- Decals
	local function applyDecals()
		if not buf.decals or not Spring.CreateGroundDecal then return end
		for _, d in ipairs(buf.decals) do
			local wx, wz = transformPoint(d.lx, d.lz, buf.sizeX, buf.sizeZ,
				rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
			wx, wz = clampToMap(wx, wz)
			local newRot = (d.rotation or 0) + rotRad
			Spring.CreateGroundDecal(d.tex, d.normTex, wx, wz, d.sizeX, d.sizeZ, newRot, d.alpha or 1)
		end
	end

	-- Lights
	local function applyLights()
		if not buf.lights then return end
		for _, l in ipairs(buf.lights) do
			local wx, wz = transformPoint(l.lx, l.lz, buf.sizeX, buf.sizeZ,
				rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
			wx, wz = clampToMap(wx, wz)
			local wy = l.ly + pasteHeightOffset
			if l.params then
				local p = {}
				for k, v in pairs(l.params) do p[k] = v end
				p.position = { wx, wy, wz }
				Spring.AddMapLight(p)
			end
		end
	end

	-- Execute in order
	applyTerrain()
	applySplats()
	applyMetal()
	applyGrass()
	applyFeatures()
	applyDecals()
	applyLights()
	-- Weather: would need to place CEGs at positions; deferred for now

	spEcho("[Clone Tool] Paste applied")
end

-- ---------------------------------------------------------------------------
-- Cancel current operation
-- ---------------------------------------------------------------------------
local function cancelOperation()
	if state == "paste_preview" then
		state = "copied"
	elseif state == "copied" or state == "box_drawn" then
		state = "idle"
		cloneBuffer = nil
	end
end

-- ---------------------------------------------------------------------------
-- Drawing: selection box on terrain
-- ---------------------------------------------------------------------------
local function drawGroundRect(box, r, g, b, a, fillA)
	local x1, z1, x2, z2 = box.x1, box.z1, box.x2, box.z2
	local step = 16
	local y_offset = 2

	-- Outline
	glColor(r, g, b, a)
	glLineWidth(2.0)
	glBeginEnd(GL_LINE_LOOP, function()
		-- Top edge (z1)
		for x = x1, x2, step do
			local cx = min(x, x2)
			glVertex(cx, spGetGroundHeight(cx, z1) + y_offset, z1)
		end
		-- Right edge (x2)
		for z = z1, z2, step do
			local cz = min(z, z2)
			glVertex(x2, spGetGroundHeight(x2, cz) + y_offset, cz)
		end
		-- Bottom edge (z2) reverse
		for x = x2, x1, -step do
			local cx = max(x, x1)
			glVertex(cx, spGetGroundHeight(cx, z2) + y_offset, z2)
		end
		-- Left edge (x1) reverse
		for z = z2, z1, -step do
			local cz = max(z, z1)
			glVertex(x1, spGetGroundHeight(x1, cz) + y_offset, cz)
		end
	end)

	-- Fill
	if fillA and fillA > 0 then
		glColor(r, g, b, fillA)
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
		local gridStep = 64
		for z = z1, z2 - gridStep, gridStep do
			glBeginEnd(GL_QUADS, function()
				for x = x1, x2 - gridStep, gridStep do
					local nx = min(x + gridStep, x2)
					local nz = min(z + gridStep, z2)
					glVertex(x,  spGetGroundHeight(x,  z)  + y_offset, z)
					glVertex(nx, spGetGroundHeight(nx, z)  + y_offset, z)
					glVertex(nx, spGetGroundHeight(nx, nz) + y_offset, nz)
					glVertex(x,  spGetGroundHeight(x,  nz) + y_offset, nz)
				end
			end)
		end
	end
	glColor(1, 1, 1, 1)
end

-- Draw corner/edge handles
local function drawHandles(box)
	local x1, z1, x2, z2 = box.x1, box.z1, box.x2, box.z2
	local hs = 24 -- handle half-size in world units
	local yoff = 4
	local corners = {
		{ x = x1, z = z1 },
		{ x = x2, z = z1 },
		{ x = x1, z = z2 },
		{ x = x2, z = z2 },
	}
	glColor(1, 1, 1, 0.9)
	for _, c in ipairs(corners) do
		local hy = spGetGroundHeight(c.x, c.z) + yoff
		glBeginEnd(GL_QUADS, function()
			glVertex(c.x - hs, hy, c.z - hs)
			glVertex(c.x + hs, hy, c.z - hs)
			glVertex(c.x + hs, hy, c.z + hs)
			glVertex(c.x - hs, hy, c.z + hs)
		end)
	end
	glColor(1, 1, 1, 1)
end

-- Draw feature markers inside box
local function drawFeatureMarkers(box)
	if not layers.features then return end
	local feats = spGetFeaturesInRectangle(box.x1, box.z1, box.x2, box.z2)
	if not feats or #feats == 0 then return end
	glColor(0.2, 1.0, 0.3, 0.8)
	local markerSize = 8
	for _, fid in ipairs(feats) do
		local fx, fy, fz = spGetFeaturePosition(fid)
		if fx then
			glBeginEnd(GL_QUADS, function()
				glVertex(fx - markerSize, fy + 4, fz - markerSize)
				glVertex(fx + markerSize, fy + 4, fz - markerSize)
				glVertex(fx + markerSize, fy + 4, fz + markerSize)
				glVertex(fx - markerSize, fy + 4, fz + markerSize)
			end)
		end
	end
	glColor(1, 1, 1, 1)
end

-- Draw metal markers inside box
local function drawMetalMarkers(box)
	if not layers.metal then return end
	local mSizeX, mSizeZ = spGetMetalMapSize()
	local startMX = max(0, floor(box.x1 / metalSquareSize))
	local startMZ = max(0, floor(box.z1 / metalSquareSize))
	local endMX = min(mSizeX - 1, ceil(box.x2 / metalSquareSize))
	local endMZ = min(mSizeZ - 1, ceil(box.z2 / metalSquareSize))
	glColor(0.8, 0.6, 0.1, 0.7)
	local ms = 6
	for mz = startMZ, endMZ do
		for mx = startMX, endMX do
			local val = spGetMetalAmount(mx, mz)
			if val and val > 0 then
				local wx = mx * metalSquareSize
				local wz = mz * metalSquareSize
				local wy = spGetGroundHeight(wx, wz) + 4
				glBeginEnd(GL_QUADS, function()
					glVertex(wx - ms, wy, wz - ms)
					glVertex(wx + ms, wy, wz - ms)
					glVertex(wx + ms, wy, wz + ms)
					glVertex(wx - ms, wy, wz + ms)
				end)
			end
		end
	end
	glColor(1, 1, 1, 1)
end

-- Draw paste preview ghost
local function drawPastePreview(targetX, targetZ)
	if not cloneBuffer then return end
	local buf = cloneBuffer
	local rotRad = rad(pasteRotation)

	-- Draw outline of paste region
	local corners = {
		transformPoint(0, 0, buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ),
		transformPoint(buf.sizeX, 0, buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ),
		transformPoint(buf.sizeX, buf.sizeZ, buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ),
		transformPoint(0, buf.sizeZ, buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ),
	}

	-- Transform returns two values, need to handle differently
	local c1x, c1z = transformPoint(0, 0, buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
	local c2x, c2z = transformPoint(buf.sizeX, 0, buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
	local c3x, c3z = transformPoint(buf.sizeX, buf.sizeZ, buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
	local c4x, c4z = transformPoint(0, buf.sizeZ, buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)

	local yoff = 4

	-- Dashed outline in cyan
	glColor(0.0, 0.9, 1.0, 0.85)
	glLineWidth(2.5)
	glBeginEnd(GL_LINE_LOOP, function()
		glVertex(c1x, spGetGroundHeight(c1x, c1z) + yoff, c1z)
		glVertex(c2x, spGetGroundHeight(c2x, c2z) + yoff, c2z)
		glVertex(c3x, spGetGroundHeight(c3x, c3z) + yoff, c3z)
		glVertex(c4x, spGetGroundHeight(c4x, c4z) + yoff, c4z)
	end)

	-- Semi-transparent fill
	glColor(0.0, 0.6, 0.8, 0.12)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glBeginEnd(GL_QUADS, function()
		glVertex(c1x, spGetGroundHeight(c1x, c1z) + yoff, c1z)
		glVertex(c2x, spGetGroundHeight(c2x, c2z) + yoff, c2z)
		glVertex(c3x, spGetGroundHeight(c3x, c3z) + yoff, c3z)
		glVertex(c4x, spGetGroundHeight(c4x, c4z) + yoff, c4z)
	end)

	-- Feature ghost markers
	if buf.features and layers.features then
		glColor(0.2, 1.0, 0.3, 0.5)
		local ms = 10
		for _, f in ipairs(buf.features) do
			local wx, wz = transformPoint(f.lx, f.lz, buf.sizeX, buf.sizeZ,
				rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
			local wy = spGetGroundHeight(wx, wz) + yoff
			glBeginEnd(GL_QUADS, function()
				glVertex(wx - ms, wy, wz - ms)
				glVertex(wx + ms, wy, wz - ms)
				glVertex(wx + ms, wy, wz + ms)
				glVertex(wx - ms, wy, wz + ms)
			end)
		end
	end

	-- Metal ghost markers
	if buf.metal and layers.metal then
		glColor(0.8, 0.6, 0.1, 0.5)
		local ms = 6
		for _, m in ipairs(buf.metal) do
			local wx, wz = transformPoint(m.lx, m.lz, buf.sizeX, buf.sizeZ,
				rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
			local wy = spGetGroundHeight(wx, wz) + yoff
			glBeginEnd(GL_QUADS, function()
				glVertex(wx - ms, wy, wz - ms)
				glVertex(wx + ms, wy, wz - ms)
				glVertex(wx + ms, wy, wz + ms)
				glVertex(wx - ms, wy, wz + ms)
			end)
		end
	end

	-- Terrain height preview (sample grid)
	if buf.terrain and layers.terrain then
		local t = buf.terrain
		glColor(0.4, 0.7, 1.0, 0.25)
		local previewStep = max(1, floor(t.cols / 50)) -- limit density for perf
		for r = 0, t.rows - 1, previewStep do
			for c = 0, t.cols - 1, previewStep do
				local lx = c * t.stepX
				local lz = r * t.stepZ
				local wx, wz = transformPoint(lx, lz, buf.sizeX, buf.sizeZ,
					rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
				local targetH = t.grid[r + 1][c + 1] + pasteHeightOffset
				local currentH = spGetGroundHeight(wx, wz)
				local delta = targetH - currentH
				-- Color by delta: blue=lower, green=same, red=raise
				if delta > 5 then
					glColor(0.9, 0.3, 0.1, 0.35)
				elseif delta < -5 then
					glColor(0.1, 0.3, 0.9, 0.35)
				else
					glColor(0.3, 0.8, 0.3, 0.2)
				end
				local ms = max(4, t.stepX * previewStep * 0.4)
				glBeginEnd(GL_QUADS, function()
					glVertex(wx - ms, currentH + yoff, wz - ms)
					glVertex(wx + ms, currentH + yoff, wz - ms)
					glVertex(wx + ms, currentH + yoff, wz + ms)
					glVertex(wx - ms, currentH + yoff, wz + ms)
				end)
			end
		end
	end

	glColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Box handle hit testing
-- ---------------------------------------------------------------------------
local HANDLE_THRESHOLD = 40 -- world units

local function getBoxHandle(wx, wz, box)
	local x1, z1, x2, z2 = box.x1, box.z1, box.x2, box.z2
	local mx = (x1 + x2) * 0.5
	local mz = (z1 + z2) * 0.5
	local ht = HANDLE_THRESHOLD

	-- Corners
	if abs(wx - x1) < ht and abs(wz - z1) < ht then return "tl" end
	if abs(wx - x2) < ht and abs(wz - z1) < ht then return "tr" end
	if abs(wx - x1) < ht and abs(wz - z2) < ht then return "bl" end
	if abs(wx - x2) < ht and abs(wz - z2) < ht then return "br" end

	-- Edges
	if abs(wz - z1) < ht and wx > x1 and wx < x2 then return "top" end
	if abs(wz - z2) < ht and wx > x1 and wx < x2 then return "bot" end
	if abs(wx - x1) < ht and wz > z1 and wz < z2 then return "left" end
	if abs(wx - x2) < ht and wz > z1 and wz < z2 then return "right" end

	-- Inside
	if wx >= x1 and wx <= x2 and wz >= z1 and wz <= z2 then return "center" end

	return nil
end

-- ---------------------------------------------------------------------------
-- Widget callins
-- ---------------------------------------------------------------------------
function widget:DrawWorld()
	if not active then return end

	-- Complete deferred splat capture (GL calls require Draw context)
	if pendingSplatCapture and cloneBuffer then
		local sc = pendingSplatCapture
		pendingSplatCapture = nil
		if splatCaptureFBO then
			glDeleteTexture(splatCaptureFBO)
		end
		splatCaptureFBO = glCreateTexture(sc.pw, sc.ph, {
			fbo = true,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
		})
		if splatCaptureFBO then
			glRenderToTexture(splatCaptureFBO, function()
				glTexture(0, SPLAT_TEX_NAME)
				glTexRect(-1, -1, 1, 1, sc.u0, sc.v0, sc.u1, sc.v1)
				glTexture(0, false)
			end)
			splatCaptureW = sc.pw
			splatCaptureH = sc.ph
			local pixelData = {}
			glRenderToTexture(splatCaptureFBO, function()
				pixelData = glReadPixels(0, 0, sc.pw, sc.ph)
			end)
			cloneBuffer.splats = {
				fboHandle = splatCaptureFBO,
				pixelW = sc.pw,
				pixelH = sc.ph,
				u0 = sc.u0, v0 = sc.v0, u1 = sc.u1, v1 = sc.v1,
				pixels = pixelData,
			}
		end
	end

	-- Complete deferred splat paste (GL calls require Draw context)
	if pendingSplatPaste then
		local sp = pendingSplatPaste
		pendingSplatPaste = nil
		local fullFBO = glCreateTexture(sp.tw, sp.th, {
			fbo = true,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
		})
		if fullFBO then
			glRenderToTexture(fullFBO, function()
				glTexture(0, SPLAT_TEX_NAME)
				glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
				glTexture(0, false)
			end)
			if sp.fboHandle then
				local tu0 = sp.targetX / mapSizeX
				local tv0 = sp.targetZ / mapSizeZ
				local tu1 = (sp.targetX + sp.sizeX) / mapSizeX
				local tv1 = (sp.targetZ + sp.sizeZ) / mapSizeZ
				glRenderToTexture(fullFBO, function()
					glTexture(0, sp.fboHandle)
					local ndcX0 = tu0 * 2 - 1
					local ndcY0 = tv0 * 2 - 1
					local ndcX1 = tu1 * 2 - 1
					local ndcY1 = tv1 * 2 - 1
					glTexRect(ndcX0, ndcY0, ndcX1, ndcY1, 0, 0, 1, 1)
					glTexture(0, false)
				end)
			end
			Spring.SetMapShadingTexture("$ssmf_splat_distr", fullFBO)
		end
	end

	glDepthTest(true)
	glPolygonOffset(-2, -2)

	local box = normalizeBox(selBox)

	if state == "selecting" then
		drawGroundRect(box, 1.0, 0.8, 0.0, 0.9, 0.08)
	elseif state == "box_drawn" or state == "copied" then
		local isGreen = (state == "copied")
		local cr, cg, cb = 1.0, 0.8, 0.0
		if isGreen then cr, cg, cb = 0.3, 1.0, 0.5 end
		drawGroundRect(box, cr, cg, cb, 0.9, 0.06)
		drawHandles(box)
		drawFeatureMarkers(box)
		drawMetalMarkers(box)
	elseif state == "paste_preview" then
		-- Keep showing source box dimmed
		drawGroundRect(box, 0.5, 0.5, 0.5, 0.3, 0.02)

		local wx, wz = getWorldMousePosition()
		if wx then
			drawPastePreview(wx, wz)
		end
	end

	glPolygonOffset(false)
	glDepthTest(false)
	glLineWidth(1.0)
end

function widget:MousePress(mx, my, button)
	if not active then return false end

	-- Defer to measure tool when active
	do
		local tb = WG.TerraformBrush
		local stb = tb and tb.getState and tb.getState() or nil
		if stb and stb.measureActive then return false end
	end

	if button == 1 then -- LMB
		local wx, wz = getWorldMousePosition()
		if not wx then return false end

		if state == "idle" then
			-- Start selection
			state = "selecting"
			selBox.x1 = wx
			selBox.z1 = wz
			selBox.x2 = wx
			selBox.z2 = wz
			return true
		elseif state == "box_drawn" or state == "copied" then
			-- Check if clicking a handle
			local box = normalizeBox(selBox)
			local handle = getBoxHandle(wx, wz, box)
			if handle then
				boxDrag.active = true
				boxDrag.handle = handle
				boxDrag.anchorX = wx
				boxDrag.anchorZ = wz
				boxDrag.origBox = { x1 = box.x1, z1 = box.z1, x2 = box.x2, z2 = box.z2 }
				return true
			end
			-- Clicking outside box in box_drawn → start new selection
			state = "selecting"
			selBox.x1 = wx
			selBox.z1 = wz
			selBox.x2 = wx
			selBox.z2 = wz
			cloneBuffer = nil
			return true
		elseif state == "paste_preview" then
			-- Apply paste at cursor position (with snap + symmetric fan-out)
			local tb = WG.TerraformBrush
			local stb = tb and tb.getState and tb.getState() or nil
			local px, pz = wx, wz
			if stb and stb.gridSnap and tb.snapWorld then
				px, pz = tb.snapWorld(wx, wz, pasteRotation)
			end
			if stb and stb.symmetryActive and tb.getSymmetricPositions then
				local positions2 = tb.getSymmetricPositions(px, pz, pasteRotation)
				if positions2 and #positions2 > 0 then
					for _, p in ipairs(positions2) do applyPaste(p.x, p.z) end
				else
					applyPaste(px, pz)
				end
			else
				applyPaste(px, pz)
			end
			-- Stay in paste_preview for re-pasting
			return true
		end
	elseif button == 3 then -- RMB
		if state ~= "idle" then
			cancelOperation()
			return true
		end
	end

	return false
end

function widget:MouseMove(mx, my, dmx, dmy, button)
	if not active then return false end

	local wx, wz = getWorldMousePosition()
	if not wx then return false end

	if state == "selecting" then
		selBox.x2 = wx
		selBox.z2 = wz
		return true
	end

	if boxDrag.active then
		local dx = wx - boxDrag.anchorX
		local dz = wz - boxDrag.anchorZ
		local ob = boxDrag.origBox
		local h = boxDrag.handle

		if h == "center" then
			selBox.x1 = ob.x1 + dx
			selBox.z1 = ob.z1 + dz
			selBox.x2 = ob.x2 + dx
			selBox.z2 = ob.z2 + dz
		elseif h == "tl" then
			selBox.x1 = ob.x1 + dx
			selBox.z1 = ob.z1 + dz
			selBox.x2 = ob.x2
			selBox.z2 = ob.z2
		elseif h == "tr" then
			selBox.x1 = ob.x1
			selBox.z1 = ob.z1 + dz
			selBox.x2 = ob.x2 + dx
			selBox.z2 = ob.z2
		elseif h == "bl" then
			selBox.x1 = ob.x1 + dx
			selBox.z1 = ob.z1
			selBox.x2 = ob.x2
			selBox.z2 = ob.z2 + dz
		elseif h == "br" then
			selBox.x1 = ob.x1
			selBox.z1 = ob.z1
			selBox.x2 = ob.x2 + dx
			selBox.z2 = ob.z2 + dz
		elseif h == "top" then
			selBox.z1 = ob.z1 + dz
		elseif h == "bot" then
			selBox.z2 = ob.z2 + dz
		elseif h == "left" then
			selBox.x1 = ob.x1 + dx
		elseif h == "right" then
			selBox.x2 = ob.x2 + dx
		end

		-- Invalidate buffer on resize
		if h ~= "center" and cloneBuffer then
			cloneBuffer = nil
			state = "box_drawn"
		end

		return true
	end

	return false
end

function widget:MouseRelease(mx, my, button)
	if not active then return false end

	if button == 1 then
		if state == "selecting" then
			local box = normalizeBox(selBox)
			if (box.x2 - box.x1) > squareSize and (box.z2 - box.z1) > squareSize then
				selBox = box
				state = "box_drawn"
			else
				state = "idle"
			end
			return true
		end

		if boxDrag.active then
			boxDrag.active = false
			-- Re-normalize
			selBox = normalizeBox(selBox)
			return true
		end
	end

	return false
end

function widget:KeyPress(key, mods, isRepeat)
	if not active then return false end

	-- Ctrl+C → Copy
	if key == 99 and mods.ctrl then -- 'c'
		if state == "box_drawn" or state == "copied" then
			doCopy()
			return true
		end
	end

	-- Ctrl+V → Paste
	if key == 118 and mods.ctrl then -- 'v'
		if state == "copied" or cloneBuffer then
			startPaste()
			return true
		end
	end

	-- Ctrl+Z → Undo
	if key == 122 and mods.ctrl and not mods.shift then
		sendMsg(MSG_UNDO)
		return true
	end

	-- Ctrl+Shift+Z → Redo
	if key == 122 and mods.ctrl and mods.shift then
		sendMsg(MSG_REDO)
		return true
	end

	-- Escape → cancel
	if key == 27 then
		cancelOperation()
		return true
	end

	-- Shift+X → Mirror X
	if key == 120 and mods.shift then -- 'x'
		if state == "paste_preview" then
			pasteMirrorX = not pasteMirrorX
			return true
		end
	end

	-- Shift+Z → Mirror Z
	if key == 122 and mods.shift and not mods.ctrl then -- 'z'
		if state == "paste_preview" then
			pasteMirrorZ = not pasteMirrorZ
			return true
		end
	end

	return false
end

function widget:MouseWheel(up, value)
	if not active or state ~= "paste_preview" then return false end

	local altHeld, _, _, shiftHeld = spGetModKeyState()

	if altHeld then
		-- Rotate (snap to TB protractor step when angleSnap on)
		local step = 15
		local tb = WG.TerraformBrush
		local tbs = tb and tb.getState and tb.getState() or nil
		if tbs and tbs.angleSnap and (tbs.angleSnapStep or 0) > 0 then
			step = tbs.angleSnapStep
		end
		local dir = up and 1 or -1
		pasteRotation = ((pasteRotation + dir * step) % 360 + 360) % 360
		return true
	end

	if shiftHeld then
		-- Height offset
		local step = 10
		if up then
			pasteHeightOffset = pasteHeightOffset + step
		else
			pasteHeightOffset = pasteHeightOffset - step
		end
		return true
	end

	return false
end

function widget:IsAbove(x, y)
	return false
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------
function widget:Initialize()
	-- Expose API
	WG.CloneTool = {
		activate     = activate,
		deactivate   = deactivate,
		getState     = getState,
		setLayer     = setLayer,
		setTerrainQuality = setTerrainQuality,
		setRotation  = setRotation,
		setHeightOffset = setHeightOffset,
		setMirrorX   = setMirrorX,
		setMirrorZ   = setMirrorZ,
		doCopy       = doCopy,
		startPaste   = startPaste,
		cancelOperation = cancelOperation,
		undo         = doUndo,
		redo         = doRedo,
	}

	widgetHandler:RegisterGlobal("CloneToolStackUpdate", function(undoCount, redoCount)
		historyUndoCount = undoCount or 0
		historyRedoCount = redoCount or 0
	end)
end

function widget:Shutdown()
	WG.CloneTool = nil
	widgetHandler:DeregisterGlobal("CloneToolStackUpdate")
	if splatCaptureFBO then
		glDeleteTexture(splatCaptureFBO)
		splatCaptureFBO = nil
	end
end
