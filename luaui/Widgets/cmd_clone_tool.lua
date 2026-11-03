function widget:GetInfo()
	return {
		name = "Clone Tool",
		desc = "Select, copy, and paste map regions (terrain, metal, features, splats, grass, decals, weather, lights)",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1000001,
		enabled = false,
	}
end

-- ---------------------------------------------------------------------------
-- Spring API aliases
-- ---------------------------------------------------------------------------
local spGetGroundHeight = Spring.GetGroundHeight
local spGetMetalAmount = Spring.GetMetalAmount
local spGetMetalMapSize = Spring.GetMetalMapSize
local spTraceScreenRay = Spring.TraceScreenRay
local spGetMouseState = Spring.GetMouseState
local spGetModKeyState = Spring.GetModKeyState
local spSendLuaRulesMsg = Spring.SendLuaRulesMsg
local spIsCheatingEnabled = Spring.IsCheatingEnabled
local spGetAllFeatures = Spring.GetAllFeatures
local spGetFeaturesInRectangle = Spring.GetFeaturesInRectangle
local spGetFeatureDefID = Spring.GetFeatureDefID
local spGetFeaturePosition = Spring.GetFeaturePosition
local spGetFeatureHeading = Spring.GetFeatureHeading
local spGetFeatureRotation = Spring.GetFeatureRotation
local spGetGroundNormal = Spring.GetGroundNormal
local spEcho = Spring.Echo
local spGetGameFrame = Spring.GetGameFrame

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glDepthTest = gl.DepthTest
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glTexCoord = gl.TexCoord
local spGetLuaMemUsage = Spring.GetLuaMemUsage
local glPolygonOffset = gl.PolygonOffset
local glBlending = gl.Blending
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glCreateTexture = gl.CreateTexture
local glDeleteTexture = gl.DeleteTexture
local glRenderToTexture = gl.RenderToTexture

local GL_LINE_LOOP = GL.LINE_LOOP
local GL_LINES = GL.LINES
local GL_QUADS = GL.QUADS
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local floor = math.floor
local ceil = math.ceil
local min = math.min
local max = math.max
local cos = math.cos
local sin = math.sin
local rad = math.rad
local abs = math.abs
local huge = math.huge
local pi = math.pi

local Game = Game
local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ
local squareSize = Game.squareSize or 8
local metalSquareSize = 16

-- ---------------------------------------------------------------------------
-- Message headers (must match gadget)
-- ---------------------------------------------------------------------------
local MSG_METAL = "$clone_metal$"
local MSG_FEATURES = "$clone_features$"
local MSG_FEATURES_CLEAR = "$clone_features_clear$"
local MSG_UNDO = "$clone_undo$"
local MSG_REDO = "$clone_redo$"
local MSG_TBEGIN = "$clone_tbegin$"
local MSG_TGRID = "$clone_tgrid$"
local MSG_TEND = "$clone_tend$"

local TERRAIN_CHUNK_SIZE = 400 -- vertices per message (legacy triplet format)
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
	anchorX = 0,
	anchorZ = 0,
	origBox = nil,
}

-- Layer toggles
local layers = {
	terrain = true,
	metal = true,
	features = true,
	splats = true,
	-- The tileset shader's variant paint (the SURFACE tool). Its mask belongs to
	-- the surface painter, which is a write-dir widget, so the layer quietly
	-- carries nothing when that widget is not installed.
	surface = true,
	grass = true,
	decals = false,
	weather = false,
	lights = false,
}

-- Clone buffer
---@type table?
local cloneBuffer = nil

-- Paste state
local pasteRotation = 0
local pasteHeightOffset = 0
local PASTE_HEIGHT_LIMIT = 500 -- the panel slider's range; Shift+wheel stops here too
local pasteMirrorX = false
local pasteMirrorZ = false
-- Paste mode: "replace", "raise" (RAISE ONLY, a max blend) or "lower" (LOWER ONLY,
-- a min blend). See the include for what each keeps and how the layers follow.
local PasteMask = VFS.Include("luaui/Include/clone_paste_mask.lua")
local pasteBlend = "replace"

-- Paste ghost: the copied terrain drawn where the click would paste it. The mesh
-- and its textures live on the GPU (see the include), so a frame costs a few
-- uniforms and three instanced draws however large the box.
local ClonePreview = VFS.Include("luaui/Include/clone_preview_gl4.lua")
local previewOpacity = 0.7 -- 0 hides the ghost and falls back to the flat outline
local pendingPreviewCapture = nil -- GL needs a draw callin, like the splat capture
local previewInst = {} -- reused per frame: x, z, rotRad, mirror bits per pasted copy
local previewOpts = { offset = 0, opacity = 0.7 }
---@type { n: integer, x: number, z: number, pinX: number?, pinZ: number? }
local previewLast = { n = 0, x = 0, z = 0 }

-- Terrain quality: "full" (float, step=8), "balanced" (int, step=8), "fast" (int, step=24, gadget fill)
local terrainQuality = "full"

-- Undo/redo history counts (synced from gadget via CloneToolStackUpdate)
local historyUndoCount = 0
local historyRedoCount = 0

-- Coroutine for async operations
local activeCoroutine = nil
local coroutineProgress = 0
local coroutineLabel = ""

-- Splat FBO
---@type string?
local splatCaptureFBO = nil
local splatCaptureW = 0
local splatCaptureH = 0
local SPLAT_TEX_NAME = "$ssmf_splat_distr"

-- gl.TextureInfo answers for a texture the map does not have (a canvas with no
-- DNTS set bound) with a TABLE whose sizes are zero, so `if info then` never
-- fires and the paste went on to ask for a 0x0 texture. gl.CreateTexture throws
-- on that, the error escaped DrawWorld and the handler REMOVED the clone tool -
-- every paste on such a map killed the widget.
local function splatTexSize()
	local info = gl.TextureInfo(SPLAT_TEX_NAME)
	local w = (info and info.xsize) or 0
	local h = (info and info.ysize) or 0
	if w > 0 and h > 0 then
		return w, h
	end
	return nil
end
local pendingSplatCapture = nil -- deferred GL capture (GL calls need Draw context)
local splatPasteFBO = nil -- the texture the engine is currently showing (see the paste)
local pendingSurfaceCapture = nil -- same, for the tileset variant mask
local pendingSurfacePaste = nil
local pendingSplatPaste = nil -- deferred GL paste (GL calls need Draw context)

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
	if mirX then
		lx = sizeX - lx
	end
	if mirZ then
		lz = sizeZ - lz
	end
	local cx, cz = sizeX * 0.5, sizeZ * 0.5
	local dx, dz = lx - cx, lz - cz
	local cosR = cos(rot)
	local sinR = sin(rot)
	local rx = dx * cosR - dz * sinR
	local rz = dx * sinR + dz * cosR
	return rx + targetX, rz + targetZ
end

-- LuaUI runs ONE Lua heap (1.6 GB) shared by every widget, and a copy or a
-- paste is among the larger single allocations an editor session makes. Both
-- report where the heap stands and what the operation added, so an OOM report
-- names a culprit instead of leaving it to guesswork. Learned the hard way on
-- 2026-09-22: LuaUI died mid-paste, and a full heap cannot even load the code
-- to fix itself - `/luaui reload` failed with OOM inside LoadCode, so the
-- session was unrecoverable and the fix looked like it had not worked.
-- TWO numbers, because on 2026-09-22 they disagreed and only one of them kills
-- you: collectgarbage("count") is what the Lua GC tracks (barwidgets.lua runs an
-- emergency collect over 1.2 GB of it - that watchdog never fired), while
-- Spring.GetLuaMemUsage reports what the engine's allocator handed this Lua
-- state, which is the number in the OOM message. The crash came with the first
-- well under its limit and the second at the ceiling, so anything that shows
-- only the GC view can miss the growth entirely.
local function heapMB()
	local gcMB = collectgarbage("count") / 1024
	local allocMB = nil
	if spGetLuaMemUsage then
		local kb = spGetLuaMemUsage()
		allocMB = kb and (kb / 1024) or nil
	end
	return gcMB, allocMB
end

local function heapNote(beforeGC, beforeAlloc)
	local gcMB, allocMB = heapMB()
	local note = string.format(" | lua %.0f MB", gcMB)
	if beforeGC then
		note = note .. string.format(" (%+.0f)", gcMB - beforeGC)
	end
	if allocMB then
		note = note .. string.format(", alloc %.0f MB", allocMB)
		if beforeAlloc then
			note = note .. string.format(" (%+.0f)", allocMB - beforeAlloc)
		end
	end
	return note
end

-- The four destination corners of a pasted box in normalized map coordinates,
-- in the captured patch's own corner order ((0,0) (1,0) (1,1) (0,1)). Rotation
-- and mirroring already live in transformPoint, so the corner ORDER carries
-- them and a texture layer needs no separate rotation code: the same quad
-- serves the splat blit and the surface painter.
local function pasteQuadUV(sizeX, sizeZ, rot, mirX, mirZ, targetX, targetZ)
	local quad = {}
	local corners = { 0, 0, sizeX, 0, sizeX, sizeZ, 0, sizeZ }
	for i = 1, 8, 2 do
		local wx, wz = transformPoint(corners[i], corners[i + 1], sizeX, sizeZ, rot, mirX, mirZ, targetX, targetZ)
		quad[#quad + 1] = wx / mapSizeX
		quad[#quad + 1] = wz / mapSizeZ
	end
	return quad
end

-- The surface painter owns its mask textures, so a captured region is freed
-- through it. Every place that drops the clone buffer goes through here.
local function discardBuffer()
	pendingPreviewCapture = nil
	if cloneBuffer and cloneBuffer.preview then
		ClonePreview.free(cloneBuffer.preview)
		cloneBuffer.preview = nil
	end
	if cloneBuffer and cloneBuffer.surface then
		---@type table?
		local sp = WG.SurfacePainter
		if sp and sp.region then
			sp.region.free(cloneBuffer.surface)
		end
		cloneBuffer.surface = nil
	end
	cloneBuffer = nil
end

-- ---------------------------------------------------------------------------
-- Activate / Deactivate API
-- ---------------------------------------------------------------------------
local function activate()
	active = true
	state = "idle"
	discardBuffer()
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
		previewOpacity = previewOpacity,
		pasteBlend = pasteBlend,
	}
end

local function setPreviewOpacity(v)
	previewOpacity = max(0, min(1, tonumber(v) or 0.7))
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
	pasteHeightOffset = max(-PASTE_HEIGHT_LIMIT, min(PASTE_HEIGHT_LIMIT, val))
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
	discardBuffer() -- the previous capture's mask region belongs to the painter
	local heapGC, heapAlloc = heapMB()
	local box = normalizeBox(selBox)
	-- Copy on the heightmap's vertex grid: every sample below is then a real vertex
	-- instead of a blend of four, and the ghost's GPU snapshot matches it exactly.
	box.x1 = floor(box.x1 / squareSize + 0.5) * squareSize
	box.z1 = floor(box.z1 / squareSize + 0.5) * squareSize
	box.x2 = floor(box.x2 / squareSize + 0.5) * squareSize
	box.z2 = floor(box.z2 / squareSize + 0.5) * squareSize
	selBox = { x1 = box.x1, z1 = box.z1, x2 = box.x2, z2 = box.z2 }
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
				if h < minH then
					minH = h
				end
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
		pendingPreviewCapture = { x1 = box.x1, z1 = box.z1, cols = cols, rows = rows }
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
	local boxU0 = box.x1 / mapSizeX
	local boxV0 = box.z1 / mapSizeZ
	local boxU1 = box.x2 / mapSizeX
	local boxV1 = box.z2 / mapSizeZ

	if layers.splats then
		local tw, th = splatTexSize()
		if tw then
			local pw = max(1, floor((boxU1 - boxU0) * tw))
			local ph = max(1, floor((boxV1 - boxV0) * th))
			pendingSplatCapture = {
				u0 = boxU0,
				v0 = boxV0,
				u1 = boxU1,
				v1 = boxV1,
				pw = pw,
				ph = ph,
			}
		end
	end

	-- Tileset variant paint: the painter cuts the patch out of its own masks
	-- (there are two once variant 4 is in use) inside the next draw frame.
	if layers.surface then
		---@type table?
		local sp = WG.SurfacePainter
		if sp and sp.region and sp.hasMaskState and sp.hasMaskState() then
			pendingSurfaceCapture = { u0 = boxU0, v0 = boxV0, u1 = boxU1, v1 = boxV1 }
		end
	end

	-- Grass
	if layers.grass then
		local grassApi = WG.grassgl4
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
				-- GetGroundDecalMiddlePos returns (posX, posZ); GetGroundDecalSizeAndHeight
				-- returns half-extents (sizeX, sizeY) — same units SetGroundDecalPosAndDims takes.
				local dx, dz = Spring.GetGroundDecalMiddlePos(did)
				if dx and dx >= box.x1 and dx <= box.x2 and dz >= box.z1 and dz <= box.z2 then
					local sx, sz = Spring.GetGroundDecalSizeAndHeight(did)
					local dRot = Spring.GetGroundDecalRotation(did)
					local dAlpha = Spring.GetGroundDecalAlpha(did)
					local texName = Spring.GetGroundDecalTexture(did, true)
					local normTex = Spring.GetGroundDecalTexture(did, false)
					decalData[#decalData + 1] = {
						lx = dx - box.x1,
						lz = dz - box.z1,
						sizeX = sx,
						sizeZ = sz,
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

	-- Weather: the weather brush's persistent spawners whose centre is in the box
	if layers.weather then
		local weatherApi = WG.WeatherBrush
		if weatherApi and weatherApi.getPersistentSpawners then
			local now = spGetGameFrame()
			local weatherData = {}
			for _, s in ipairs(weatherApi.getPersistentSpawners()) do
				if s.x >= box.x1 and s.x <= box.x2 and s.z >= box.z1 and s.z <= box.z2 then
					s.lx, s.lz = s.x - box.x1, s.z - box.z1
					-- remaining lifetime in seconds, -1 = permanent (addSpawnerRaw's persistence)
					s.persistence = s.expireFrame and max(1, (s.expireFrame - now) / Game.gameSpeed) or -1
					weatherData[#weatherData + 1] = s
				end
			end
			buf.weather = weatherData
		end
	end

	-- Lights: the light placer's placed lights in the box, kept with their
	-- height above the ground so they land as high above the pasted ground
	if layers.lights then
		local lightApi = WG.LightPlacer
		if lightApi and lightApi.getPlacedLights then
			local lightData = {}
			for _, rec in ipairs(lightApi.getPlacedLights()) do
				local x, y, z = rec.pos[1], rec.pos[2], rec.pos[3]
				if x >= box.x1 and x <= box.x2 and z >= box.z1 and z <= box.z2 then
					local elevation = rec.elevation or 0
					lightData[#lightData + 1] = {
						lx = x - box.x1,
						lz = z - box.z1,
						groundY = y - elevation,
						def = rec,
					}
				end
			end
			buf.lights = lightData
		end
	end

	cloneBuffer = buf
	state = "copied"
	spEcho("[Clone Tool] Region copied" .. heapNote(heapGC, heapAlloc))
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
	if not cloneBuffer then
		return
	end
	if not spIsCheatingEnabled() then
		spEcho("[Clone Tool] WARNING: Cheats are not enabled - paste will be blocked by gadget! Enable cheats first.")
		return
	end
	local buf = cloneBuffer
	local heapGC, heapAlloc = heapMB()
	local rotRad = rad(pasteRotation)

	-- RAISE ONLY / LOWER ONLY: the terrain decides, every other layer pastes only
	-- where it does. All of it is judged against the ground as it is now, before
	-- the gadget applies the new heights. Without copied terrain there is nothing
	-- to judge by, and the paste replaces as before.
	local blend = buf.terrain and pasteBlend or "replace"
	local masked = blend ~= "replace"
	local function keepAt(lx, lz, wx, wz)
		if not masked then
			return true
		end
		local d = PasteMask.heightAt(buf.terrain, lx, lz) + pasteHeightOffset - spGetGroundHeight(wx, wz)
		return PasteMask.keep(blend, d)
	end
	-- the texture layers blend through the same cells, as a mask texture
	local pasteMask = nil
	if masked and (buf.splats or buf.surface) then
		pasteMask = PasteMask.grid(buf.terrain, pasteHeightOffset, blend, function(lx, lz)
			return transformPoint(lx, lz, buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
		end)
	end

	-- Helper to build grid-based terrain messages with quality control
	local function applyTerrain()
		if not buf.terrain then
			return
		end
		local t = buf.terrain
		local sX, sZ = buf.sizeX, buf.sizeZ
		local cx, cz = sX * 0.5, sZ * 0.5
		local cosR = cos(rotRad)
		local sinR = sin(rotRad)

		-- Quality determines paste step and height formatting
		local pasteStep = squareSize
		local formatHeight
		-- A masked paste writes every vertex at full precision: the gadget's fill
		-- between Fast's 24-elmo vertices, or Balanced's rounding, could otherwise
		-- dip a RAISE ONLY paste below the ground it must not lower (and the reverse).
		if terrainQuality == "full" or masked then
			formatHeight = function(h)
				return string.format("%.2f", h)
			end
		elseif terrainQuality == "fast" then
			pasteStep = squareSize * 3 -- 24: 9x fewer source vertices
			formatHeight = function(h)
				return tostring(floor(h + 0.5))
			end
		else -- "balanced"
			formatHeight = function(h)
				return tostring(floor(h + 0.5))
			end
		end

		-- Compute rotated AABB in world space
		local corners = {
			{ 0, 0 },
			{ sX, 0 },
			{ sX, sZ },
			{ 0, sZ },
		}
		local wMinX, wMinZ = huge, huge
		local wMaxX, wMaxZ = -huge, -huge
		for i = 1, 4 do
			local lx, lz = corners[i][1], corners[i][2]
			if pasteMirrorX then
				lx = sX - lx
			end
			if pasteMirrorZ then
				lz = sZ - lz
			end
			local dx, dz = lx - cx, lz - cz
			local wx = dx * cosR - dz * sinR + targetX
			local wz = dx * sinR + dz * cosR + targetZ
			if wx < wMinX then
				wMinX = wx
			end
			if wx > wMaxX then
				wMaxX = wx
			end
			if wz < wMinZ then
				wMinZ = wz
			end
			if wz > wMaxZ then
				wMaxZ = wz
			end
		end

		-- Snap to paste grid and clamp to map
		local gx0 = max(0, floor(wMinX / pasteStep) * pasteStep)
		local gz0 = max(0, floor(wMinZ / pasteStep) * pasteStep)
		local gx1 = min(mapSizeX, ceil(wMaxX / pasteStep) * pasteStep)
		local gz1 = min(mapSizeZ, ceil(wMaxZ / pasteStep) * pasteStep)

		-- Grid dimensions
		local cols = floor((gx1 - gx0) / pasteStep) + 1
		local rows = floor((gz1 - gz0) / pasteStep) + 1
		if cols <= 0 or rows <= 0 then
			return
		end

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
				if pasteMirrorX then
					lx = sX - lx
				end
				if pasteMirrorZ then
					lz = sZ - lz
				end

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
					h = h00 * (1 - fc) * (1 - fr) + h10 * fc * (1 - fr) + h01 * (1 - fc) * fr + h11 * fc * fr
					h = h + pasteHeightOffset
					if blend == "raise" then
						h = max(h, spGetGroundHeight(wx, wz))
					elseif blend == "lower" then
						h = min(h, spGetGroundHeight(wx, wz))
					end
				else
					-- Outside source: keep current ground height
					h = spGetGroundHeight(wx, wz)
				end

				idx = idx + 1
				gridBuf[idx] = formatHeight(h)
			end
		end

		-- Send begin message (tells gadget the full grid extent)
		sendMsg(MSG_TBEGIN .. gx0 .. " " .. gz0 .. " " .. pasteStep .. " " .. squareSize .. " " .. cols .. " " .. rows)

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
		if not buf.metal then
			return
		end
		local entries = {}
		for _, m in ipairs(buf.metal) do
			local wx, wz =
				transformPoint(m.lx, m.lz, buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
			wx, wz = clampToMap(wx, wz)
			if keepAt(m.lx, m.lz, wx, wz) then
				local mx = floor(wx / metalSquareSize)
				local mz = floor(wz / metalSquareSize)
				entries[#entries + 1] = tostring(mx) .. " " .. tostring(mz) .. " " .. tostring(m.val)
			end
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
			return
		end
		local featureCount = #buf.features
		if featureCount == 0 then
			return
		end
		-- Clear target area first
		local clearSizeX = buf.sizeX
		local clearSizeZ = buf.sizeZ
		-- Calculate rotated bounding box for clearing
		local cx1, cz1 =
			transformPoint(0, 0, clearSizeX, clearSizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
		local cx2, cz2 = transformPoint(
			clearSizeX,
			clearSizeZ,
			clearSizeX,
			clearSizeZ,
			rotRad,
			pasteMirrorX,
			pasteMirrorZ,
			targetX,
			targetZ
		)
		local cx3, cz3 =
			transformPoint(clearSizeX, 0, clearSizeX, clearSizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
		local cx4, cz4 =
			transformPoint(0, clearSizeZ, clearSizeX, clearSizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
		local clearX1 = min(cx1, cx2, cx3, cx4)
		local clearZ1 = min(cz1, cz2, cz3, cz4)
		local clearX2 = max(cx1, cx2, cx3, cx4)
		local clearZ2 = max(cz1, cz2, cz3, cz4)
		clearX1, clearZ1 = clampToMap(clearX1, clearZ1)
		clearX2, clearZ2 = clampToMap(clearX2, clearZ2)
		if not masked then
			sendMsg(
				MSG_FEATURES_CLEAR
					.. floor(clearX1)
					.. " "
					.. floor(clearZ1)
					.. " "
					.. floor(clearX2)
					.. " "
					.. floor(clearZ2)
			)
		else
			-- A masked paste clears only the features standing where the terrain
			-- pastes: each one is mapped back into the box and judged like the rest.
			local sX, sZ = buf.sizeX, buf.sizeZ
			local cosR, sinR = cos(rotRad), sin(rotRad)
			for _, fid in ipairs(spGetFeaturesInRectangle(clearX1, clearZ1, clearX2, clearZ2) or {}) do
				local fx, _, fz = spGetFeaturePosition(fid)
				if fx and fz then
					local dx, dz = fx - targetX, fz - targetZ
					local lx = dx * cosR + dz * sinR + sX * 0.5
					local lz = -dx * sinR + dz * cosR + sZ * 0.5
					if pasteMirrorX then
						lx = sX - lx
					end
					if pasteMirrorZ then
						lz = sZ - lz
					end
					if lx >= 0 and lx <= sX and lz >= 0 and lz <= sZ and keepAt(lx, lz, fx, fz) then
						sendMsg(
							MSG_FEATURES_CLEAR
								.. floor(fx) - 1
								.. " "
								.. floor(fz) - 1
								.. " "
								.. floor(fx) + 2
								.. " "
								.. floor(fz) + 2
						)
					end
				end
			end
		end

		-- The copied features that land, then sent in chunks of 50
		---@type { f: table, wx: number, wz: number }[]
		local landing = {}
		for _, f in ipairs(buf.features) do
			local wx, wz =
				transformPoint(f.lx, f.lz, buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
			wx, wz = clampToMap(wx, wz)
			if keepAt(f.lx, f.lz, wx, wz) then
				landing[#landing + 1] = { f = f, wx = wx, wz = wz }
			end
		end
		local parts, inChunk = {}, 0
		local function flush()
			if inChunk > 0 then
				sendMsg(MSG_FEATURES .. inChunk .. " " .. table.concat(parts, " "))
				parts, inChunk = {}, 0
			end
		end
		for _, e in ipairs(landing) do
			local f, wx, wz = e.f, e.wx, e.wz
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
			inChunk = inChunk + 1
			if inChunk >= 50 then
				flush()
			end
		end
		flush()
	end

	-- Splats: defer GL operations to next DrawWorld
	local function applySplats()
		if not buf.splats or not buf.splats.fboHandle then
			return
		end
		local tw, th = splatTexSize()
		if not tw then
			return
		end
		pendingSplatPaste = {
			tw = tw,
			th = th,
			fboHandle = buf.splats.fboHandle,
			-- The quad, not a rectangle: the paste target is the box CENTRE and
			-- may be turned or mirrored, which an axis-aligned blit from the
			-- corner could represent neither of.
			quad = pasteQuadUV(buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ),
			mask = pasteMask,
		}
	end

	-- Tileset variant paint, through the painter (it snapshots for undo and
	-- refreshes the tileset's far-field cache itself).
	local function applySurface()
		if not buf.surface then
			return
		end
		---@type table?
		local sp = WG.SurfacePainter
		if not (sp and sp.region) then
			return
		end
		pendingSurfacePaste = {
			region = buf.surface,
			quad = pasteQuadUV(buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ),
			mask = pasteMask,
		}
	end

	-- Grass
	local function applyGrass()
		if not buf.grass then
			return
		end
		local grassApi = WG.grassgl4
		if not grassApi or not grassApi.setDensityAt then
			return
		end
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
			local wx, wz =
				transformPoint(g.lx, g.lz, buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
			wx, wz = clampToMap(wx, wz)
			if keepAt(g.lx, g.lz, wx, wz) then
				grassApi.setDensityAt(wx, wz, g.density)
			end
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
		if not buf.decals or not Spring.CreateGroundDecal then
			return
		end
		for _, d in ipairs(buf.decals) do
			local wx, wz =
				transformPoint(d.lx, d.lz, buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
			wx, wz = clampToMap(wx, wz)
			local newRot = (d.rotation or 0) + rotRad
			-- CreateGroundDecal takes no arguments and returns a bare decal id;
			-- all properties go through the setters (same flow as cmd_decal_placer).
			local id = keepAt(d.lx, d.lz, wx, wz) and Spring.CreateGroundDecal()
			if id then
				if d.tex then
					Spring.SetGroundDecalTexture(id, d.tex, true)
				end
				if d.normTex then
					Spring.SetGroundDecalTexture(id, d.normTex, false)
				end
				Spring.SetGroundDecalPosAndDims(id, wx, wz, d.sizeX, d.sizeZ)
				Spring.SetGroundDecalRotation(id, newRot)
				if Spring.SetGroundDecalAlpha then
					Spring.SetGroundDecalAlpha(id, d.alpha or 1, 0)
				end
			end
		end
	end

	-- A yaw (degrees, 0 = +z, 90 = +x) turned and mirrored like the paste
	local function pasteYaw(yawDeg)
		local dx, dz = sin(rad(yawDeg or 0)), cos(rad(yawDeg or 0))
		if pasteMirrorX then
			dx = -dx
		end
		if pasteMirrorZ then
			dz = -dz
		end
		local c, s = cos(rotRad), sin(rotRad)
		return math.deg(math.atan2(dx * c - dz * s, dx * s + dz * c))
	end

	-- Lights: through the light placer, one undo step there. When the terrain
	-- is pasted too the ground under a light is the copied ground plus the
	-- height offset; the gadget has not applied it yet, so the height is given.
	local function applyLights()
		local lightApi = WG.LightPlacer
		if not (buf.lights and lightApi and lightApi.addLights) then
			return
		end
		local list = {}
		for _, l in ipairs(buf.lights) do
			local wx, wz =
				transformPoint(l.lx, l.lz, buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
			wx, wz = clampToMap(wx, wz)
			local def = {}
			for k, v in pairs(l.def) do
				def[k] = v
			end
			def.yaw = pasteYaw(l.def.yaw)
			local y = buf.terrain and (l.groundY + pasteHeightOffset + (l.def.elevation or 0)) or nil
			if keepAt(l.lx, l.lz, wx, wz) then
				list[#list + 1] = { x = wx, z = wz, y = y, def = def }
			end
		end
		lightApi.addLights(list)
	end

	-- Weather: persistent spawners through the weather brush. Their shape
	-- angle turns with the paste (a direction (cos, sin) in the x, z plane).
	local function applyWeather()
		local weatherApi = WG.WeatherBrush
		if not (buf.weather and weatherApi and weatherApi.addSpawnerRaw) then
			return
		end
		for _, s in ipairs(buf.weather) do
			local wx, wz =
				transformPoint(s.lx, s.lz, buf.sizeX, buf.sizeZ, rotRad, pasteMirrorX, pasteMirrorZ, targetX, targetZ)
			wx, wz = clampToMap(wx, wz)
			local a = rad(s.angleDeg or 0)
			local ax, az = cos(a), sin(a)
			if pasteMirrorX then
				ax = -ax
			end
			if pasteMirrorZ then
				az = -az
			end
			local c, sn = cos(rotRad), sin(rotRad)
			local entry = {}
			for k, v in pairs(s) do
				entry[k] = v
			end
			entry.x, entry.z = wx, wz
			entry.angleDeg = math.deg(math.atan2(ax * sn + az * c, ax * c - az * sn))
			if keepAt(s.lx, s.lz, wx, wz) then
				weatherApi.addSpawnerRaw(entry)
			end
		end
	end

	-- Execute in order
	applyTerrain()
	applySplats()
	applySurface()
	applyMetal()
	applyGrass()
	applyFeatures()
	applyDecals()
	applyLights()
	applyWeather()

	spEcho("[Clone Tool] Paste applied" .. heapNote(heapGC, heapAlloc))
end

-- ---------------------------------------------------------------------------
-- Cancel current operation
-- ---------------------------------------------------------------------------
local function cancelOperation()
	if state == "paste_preview" then
		state = "copied"
	elseif state == "copied" or state == "box_drawn" then
		state = "idle"
		discardBuffer()
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
		-- one BeginEnd for every row: a closure per row per frame is heap churn
		-- stylua: ignore start
		glBeginEnd(GL_QUADS, function()
			for z = z1, z2 - gridStep, gridStep do
				for x = x1, x2 - gridStep, gridStep do
					local nx = min(x + gridStep, x2)
					local nz = min(z + gridStep, z2)
					glVertex(x,  spGetGroundHeight(x,  z)  + y_offset, z)
					glVertex(nx, spGetGroundHeight(nx, z)  + y_offset, z)
					glVertex(nx, spGetGroundHeight(nx, nz) + y_offset, nz)
					glVertex(x,  spGetGroundHeight(x,  nz) + y_offset, nz)
				end
			end
		end)
		-- stylua: ignore end
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
	if not layers.features then
		return
	end
	local feats = spGetFeaturesInRectangle(box.x1, box.z1, box.x2, box.z2)
	if not feats or #feats == 0 then
		return
	end
	glColor(0.2, 1.0, 0.3, 0.8)
	local markerSize = 8
	glBeginEnd(GL_QUADS, function()
		for _, fid in ipairs(feats) do
			local fx, fy, fz = spGetFeaturePosition(fid)
			if fx and fz then
				glVertex(fx - markerSize, fy + 4, fz - markerSize)
				glVertex(fx + markerSize, fy + 4, fz - markerSize)
				glVertex(fx + markerSize, fy + 4, fz + markerSize)
				glVertex(fx - markerSize, fy + 4, fz + markerSize)
			end
		end
	end)
	glColor(1, 1, 1, 1)
end

-- Draw metal markers inside box
local function drawMetalMarkers(box)
	if not layers.metal then
		return
	end
	local mSizeX, mSizeZ = spGetMetalMapSize()
	local startMX = max(0, floor(box.x1 / metalSquareSize))
	local startMZ = max(0, floor(box.z1 / metalSquareSize))
	local endMX = min(mSizeX - 1, ceil(box.x2 / metalSquareSize))
	local endMZ = min(mSizeZ - 1, ceil(box.z2 / metalSquareSize))
	glColor(0.8, 0.6, 0.1, 0.7)
	local ms = 6
	glBeginEnd(GL_QUADS, function()
		for mz = startMZ, endMZ do
			for mx = startMX, endMX do
				local val = spGetMetalAmount(mx, mz)
				if val and val > 0 then
					local wx = mx * metalSquareSize
					local wz = mz * metalSquareSize
					local wy = spGetGroundHeight(wx, wz) + 4
					glVertex(wx - ms, wy, wz - ms)
					glVertex(wx + ms, wy, wz - ms)
					glVertex(wx + ms, wy, wz + ms)
					glVertex(wx - ms, wy, wz + ms)
				end
			end
		end
	end)
	glColor(1, 1, 1, 1)
end

-- Where a click at (wx, wz) pastes: grid snap, then one target per symmetric copy.
-- The click and the preview both go through here so the ghost sits exactly where
-- the paste lands. Each copy keeps its own turn (rot) and, when a mirror axis made
-- it, mirror = true; copyTransform turns that into the copy's paste transform.
local function resolvePasteTargets(wx, wz)
	local tb = WG.TerraformBrush
	local px, pz = wx, wz
	if tb and tb.snapWorld then
		px, pz = tb.snapWorld(wx, wz, pasteRotation)
	end
	if tb and tb.getSymmetricPositions then
		local positions = tb.getSymmetricPositions(px, pz, pasteRotation)
		if positions and #positions > 0 then
			return positions
		end
	end
	return { { x = px, z = pz } }
end

-- The paste transform of one symmetric copy: its own turn in degrees, and the
-- mirror flags. A reflection across any axis is the same as flipping Z and turning
-- by the copy's rot, so a mirrored copy flips the Z mirror.
local function copyTransform(p)
	local mirZ = pasteMirrorZ
	if p.mirror then
		mirZ = not mirZ
	end
	return p.rot or pasteRotation, pasteMirrorX, mirZ
end

-- Height of the pasted terrain at a box-local point: the same bilinear lookup the
-- paste does, so markers sit on the ghost rather than on the current ground.
local function pastedHeightAt(t, lx, lz)
	return PasteMask.heightAt(t, lx, lz) + pasteHeightOffset
end

-- Footprint outline at the current ground, for a clipboard without terrain (or the
-- ghost switched off): four corners, so it cuts through hills, which is fine there.
local function drawFlatFootprint(buf, rotRad, mirX, mirZ, targetX, targetZ)
	local sX, sZ = buf.sizeX, buf.sizeZ
	local c1x, c1z = transformPoint(0, 0, sX, sZ, rotRad, mirX, mirZ, targetX, targetZ)
	local c2x, c2z = transformPoint(sX, 0, sX, sZ, rotRad, mirX, mirZ, targetX, targetZ)
	local c3x, c3z = transformPoint(sX, sZ, sX, sZ, rotRad, mirX, mirZ, targetX, targetZ)
	local c4x, c4z = transformPoint(0, sZ, sX, sZ, rotRad, mirX, mirZ, targetX, targetZ)
	local yoff = 4
	local c1y = spGetGroundHeight(c1x, c1z) + yoff
	local c2y = spGetGroundHeight(c2x, c2z) + yoff
	local c3y = spGetGroundHeight(c3x, c3z) + yoff
	local c4y = spGetGroundHeight(c4x, c4z) + yoff
	glColor(0.0, 0.9, 1.0, 0.85)
	glLineWidth(2.5)
	glBeginEnd(GL_LINE_LOOP, function()
		glVertex(c1x, c1y, c1z)
		glVertex(c2x, c2y, c2z)
		glVertex(c3x, c3y, c3z)
		glVertex(c4x, c4y, c4z)
	end)
	glColor(0.0, 0.6, 0.8, 0.12)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glBeginEnd(GL_QUADS, function()
		glVertex(c1x, c1y, c1z)
		glVertex(c2x, c2y, c2z)
		glVertex(c3x, c3y, c3z)
		glVertex(c4x, c4y, c4z)
	end)
end

-- Small squares for the features and metal the paste carries, on the pasted surface
local function drawPasteMarkers(buf, rotRad, mirX, mirZ, targetX, targetZ)
	local t = buf.terrain
	local blend = t and pasteBlend or "replace"
	local function markers(list, ms)
		for _, e in ipairs(list) do
			local wx, wz = transformPoint(e.lx, e.lz, buf.sizeX, buf.sizeZ, rotRad, mirX, mirZ, targetX, targetZ)
			local groundY = spGetGroundHeight(wx, wz)
			local wy = t and pastedHeightAt(t, e.lx, e.lz) or groundY
			-- RAISE ONLY / LOWER ONLY: only what the paste will actually lay down
			if blend == "replace" or PasteMask.keep(blend, wy - groundY) then
				wy = wy + 4
				glVertex(wx - ms, wy, wz - ms)
				glVertex(wx + ms, wy, wz - ms)
				glVertex(wx + ms, wy, wz + ms)
				glVertex(wx - ms, wy, wz + ms)
			end
		end
	end
	if buf.features and layers.features and #buf.features > 0 then
		glColor(0.2, 1.0, 0.3, 0.6)
		glBeginEnd(GL_QUADS, markers, buf.features, 10)
	end
	if buf.metal and layers.metal and #buf.metal > 0 then
		glColor(0.8, 0.6, 0.1, 0.6)
		glBeginEnd(GL_QUADS, markers, buf.metal, 6)
	end
end

-- Draw the paste preview: the ghost terrain (or a flat outline) at every target
local function drawPastePreview(cursorX, cursorZ)
	if not cloneBuffer then
		return
	end
	local buf = cloneBuffer
	local targets = resolvePasteTargets(cursorX, cursorZ)
	local n = min(#targets, ClonePreview.MAX_INSTANCES)
	for i = 1, n do
		local k = (i - 1) * 4
		local rot, mirX, mirZ = copyTransform(targets[i])
		previewInst[k + 1] = targets[i].x
		previewInst[k + 2] = targets[i].z
		previewInst[k + 3] = rad(rot)
		previewInst[k + 4] = (mirX and 1 or 0) + (mirZ and 2 or 0)
	end
	previewLast.n, previewLast.x, previewLast.z = n, targets[1].x, targets[1].z

	local ghost = buf.terrain and buf.preview
	if ghost and previewOpacity > 0 then
		previewOpts.offset = pasteHeightOffset
		previewOpts.opacity = previewOpacity
		previewOpts.blend = PasteMask.MODES[pasteBlend] or 0
		ClonePreview.draw(ghost, previewInst, n, previewOpts)
		glDepthTest(true)
	else
		for i = 1, n do
			local rot, mirX, mirZ = copyTransform(targets[i])
			drawFlatFootprint(buf, rad(rot), mirX, mirZ, targets[i].x, targets[i].z)
		end
	end
	for i = 1, n do
		local rot, mirX, mirZ = copyTransform(targets[i])
		drawPasteMarkers(buf, rad(rot), mirX, mirZ, targets[i].x, targets[i].z)
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
	if abs(wx - x1) < ht and abs(wz - z1) < ht then
		return "tl"
	end
	if abs(wx - x2) < ht and abs(wz - z1) < ht then
		return "tr"
	end
	if abs(wx - x1) < ht and abs(wz - z2) < ht then
		return "bl"
	end
	if abs(wx - x2) < ht and abs(wz - z2) < ht then
		return "br"
	end

	-- Edges
	if abs(wz - z1) < ht and wx > x1 and wx < x2 then
		return "top"
	end
	if abs(wz - z2) < ht and wx > x1 and wx < x2 then
		return "bot"
	end
	if abs(wx - x1) < ht and wz > z1 and wz < z2 then
		return "left"
	end
	if abs(wx - x2) < ht and wz > z1 and wz < z2 then
		return "right"
	end

	-- Inside
	if wx >= x1 and wx <= x2 and wz >= z1 and wz <= z2 then
		return "center"
	end

	return nil
end

-- ---------------------------------------------------------------------------
-- Widget callins
-- ---------------------------------------------------------------------------
function widget:DrawWorld()
	if not active then
		return
	end

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
			-- NO gl.ReadPixels here. It used to pull the whole patch back into a
			-- nested Lua table purely so the paste could test that the capture
			-- had happened - and that table is one small table per texel: a few
			-- copies of a mid-sized box filled LuaUI's 1.6 GB Lua heap and the
			-- engine killed the whole interface with an OOM inside DrawWorld
			-- (2026-09-22). The paste only ever needed the texture handle.
			cloneBuffer.splats = {
				fboHandle = splatCaptureFBO,
				pixelW = sc.pw,
				pixelH = sc.ph,
				u0 = sc.u0,
				v0 = sc.v0,
				u1 = sc.u1,
				v1 = sc.v1,
			}
		end
	end

	-- Snapshot the copied heights and ground colour for the paste ghost
	if pendingPreviewCapture and cloneBuffer then
		local pc = pendingPreviewCapture
		pendingPreviewCapture = nil
		ClonePreview.free(cloneBuffer.preview)
		cloneBuffer.preview = ClonePreview.capture(pc.x1, pc.z1, pc.cols, pc.rows)
	end

	-- Cut the variant-mask patch out through the painter (it owns the masks)
	if pendingSurfaceCapture and cloneBuffer then
		local sc = pendingSurfaceCapture
		pendingSurfaceCapture = nil
		---@type table?
		local painter = WG.SurfacePainter
		if painter and painter.region then
			if cloneBuffer.surface then
				painter.region.free(cloneBuffer.surface)
			end
			cloneBuffer.surface = painter.region.copy(sc.u0, sc.v0, sc.u1, sc.v1)
		end
	end

	-- Lay it down again at the paste target
	if pendingSurfacePaste then
		local ps = pendingSurfacePaste
		pendingSurfacePaste = nil
		---@type table?
		local painter = WG.SurfacePainter
		if painter and painter.region then
			if not ps.mask then
				painter.region.paste(ps.region, ps.quad)
			elseif ps.mask.kept > 0 then
				-- RAISE ONLY / LOWER ONLY: the copied paint only where the terrain
				-- pastes, the destination's own everywhere else in the quad
				local blended = PasteMask.blendSurface(painter, ps.region, ps.quad, ps.mask)
				if blended then
					painter.region.paste(blended, ps.quad)
					PasteMask.freeRegion(blended)
				end
				PasteMask.deleteTexture(ps.mask)
			end
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
			-- RAISE ONLY / LOWER ONLY: through the mask; nothing kept, nothing drawn
			local maskDone = false
			if sp.mask then
				maskDone = sp.mask.kept == 0
				if not maskDone and sp.fboHandle and sp.quad and PasteMask.texture(sp.mask) then
					-- (the mask texture is built first: render targets do not nest)
					glRenderToTexture(fullFBO, function()
						maskDone = PasteMask.drawSplatQuad(sp.fboHandle, SPLAT_TEX_NAME, sp.mask, sp.quad, sp.tw, sp.th)
					end)
				end
				PasteMask.deleteTexture(sp.mask)
			end
			if not maskDone and sp.fboHandle and sp.quad then
				-- Four corners, so the patch lands turned and mirrored the way
				-- every other layer of the paste does, and centred on the
				-- cursor rather than half a box down and to the right.
				local q = sp.quad
				glRenderToTexture(fullFBO, function()
					glTexture(0, sp.fboHandle)
					glBeginEnd(GL_QUADS, function()
						glTexCoord(0, 0)
						glVertex(q[1] * 2 - 1, q[2] * 2 - 1)
						glTexCoord(1, 0)
						glVertex(q[3] * 2 - 1, q[4] * 2 - 1)
						glTexCoord(1, 1)
						glVertex(q[5] * 2 - 1, q[6] * 2 - 1)
						glTexCoord(0, 1)
						glVertex(q[7] * 2 - 1, q[8] * 2 - 1)
					end)
					glTexture(0, false)
				end)
			end
			Spring.SetMapShadingTexture(SPLAT_TEX_NAME, fullFBO)
			-- SetMapShadingTexture stores the GL id itself, so the texture the
			-- PREVIOUS paste handed over stops being referenced the moment this
			-- one is bound. Free it then, and never before: every paste used to
			-- leave a full-map RGBA8 behind (16 MB on a 32x32 map).
			if splatPasteFBO and splatPasteFBO ~= fullFBO then
				glDeleteTexture(splatPasteFBO)
			end
			splatPasteFBO = fullFBO
			-- the tileset's far cache / clipmap bake the splat channels: tell it
			-- the pasted rect changed (elmos) or the paste vanishes at zoom-out
			local T = WG.TilesetTerrain
			if T and T.refreshSurface and sp.quad then
				local q = sp.quad
				local minU, maxU, minV, maxV = q[1], q[1], q[2], q[2]
				for i = 3, 7, 2 do
					minU = math.min(minU, q[i])
					maxU = math.max(maxU, q[i])
					minV = math.min(minV, q[i + 1])
					maxV = math.max(maxV, q[i + 1])
				end
				T.refreshSurface(minU * mapSizeX, minV * mapSizeZ, maxU * mapSizeX, maxV * mapSizeZ)
			end
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
		if isGreen then
			cr, cg, cb = 0.3, 1.0, 0.5
		end
		drawGroundRect(box, cr, cg, cb, 0.9, 0.06)
		drawHandles(box)
		drawFeatureMarkers(box)
		drawMetalMarkers(box)
	elseif state == "paste_preview" then
		-- Keep showing the source box, dimmed, outline only
		drawGroundRect(box, 0.5, 0.5, 0.5, 0.3, nil)

		local wx, wz = getWorldMousePosition()
		if previewLast.pinX then
			wx, wz = previewLast.pinX, previewLast.pinZ
		end
		if wx then
			drawPastePreview(wx, wz)
		end
	end

	glPolygonOffset(false)
	glDepthTest(false)
	glLineWidth(1.0)
end

function widget:MousePress(mx, my, button)
	if not active then
		return false
	end

	-- Defer to measure tool when active
	do
		local tb = WG.TerraformBrush
		local stb = tb and tb.getState and tb.getState() or nil
		if stb and stb.measureActive then
			return false
		end
	end

	if button == 1 then -- LMB
		local wx, wz = getWorldMousePosition()
		if not wx then
			return false
		end

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
			discardBuffer()
			return true
		elseif state == "paste_preview" then
			-- Apply paste at cursor position (with snap + symmetric fan-out)
			-- applyPaste reads the global transform: set each copy's own, then put it back
			local rot0, mirX0, mirZ0 = pasteRotation, pasteMirrorX, pasteMirrorZ
			for _, p in ipairs(resolvePasteTargets(wx, wz)) do
				pasteRotation, pasteMirrorX, pasteMirrorZ = copyTransform(p)
				local ok, err = pcall(applyPaste, p.x, p.z)
				pasteRotation, pasteMirrorX, pasteMirrorZ = rot0, mirX0, mirZ0
				if not ok then
					error(err, 0)
				end
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
	if not active then
		return false
	end

	local wx, wz = getWorldMousePosition()
	if not wx then
		return false
	end

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
			discardBuffer()
			state = "box_drawn"
		end

		return true
	end

	return false
end

function widget:MouseRelease(mx, my, button)
	if not active then
		return false
	end

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
	if not active then
		return false
	end

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
	if not active or state ~= "paste_preview" then
		return false
	end

	local altHeld, _, _, shiftHeld = spGetModKeyState()

	if altHeld then
		-- Rotate (snap to TB protractor step when angleSnap on)
		---@type number
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
		setHeightOffset(pasteHeightOffset + (up and step or -step))
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
		activate = activate,
		deactivate = deactivate,
		getState = getState,
		setLayer = setLayer,
		setTerrainQuality = setTerrainQuality,
		setRotation = setRotation,
		setHeightOffset = setHeightOffset,
		setMirrorX = setMirrorX,
		setMirrorZ = setMirrorZ,
		doCopy = doCopy,
		startPaste = startPaste,
		cancelOperation = cancelOperation,
		undo = doUndo,
		redo = doRedo,
		setPreviewOpacity = setPreviewOpacity,
		-- "replace", "raise" (RAISE ONLY) or "lower" (LOWER ONLY)
		setPasteBlend = function(mode)
			if PasteMask.MODES[mode] then
				pasteBlend = mode
			end
		end,
		-- Test hooks: a box without mouse input, and what the ghost holds
		setSelection = function(x1, z1, x2, z2)
			selBox = normalizeBox({ x1 = x1, z1 = z1, x2 = x2, z2 = z2 })
			state = "box_drawn"
		end,
		-- ghost draw options for tuning: xray, maxCells, brightness, tint, rim
		setPreviewOption = function(key, value)
			if key ~= "offset" and key ~= "opacity" then
				previewOpts[key] = value
			end
		end,
		-- pins the preview to a world point instead of the cursor (nil releases it)
		setPreviewCursor = function(x, z)
			previewLast.pinX, previewLast.pinZ = x, z
		end,
		previewStats = function()
			local buf = cloneBuffer
			local s = buf and ClonePreview.stats(buf.preview) or {}
			s.pending = pendingPreviewCapture ~= nil
			s.heightTex = buf and buf.preview and buf.preview.heightTex or nil
			s.colorTex = buf and buf.preview and buf.preview.colorTex or nil
			s.targets, s.targetX, s.targetZ = previewLast.n, previewLast.x, previewLast.z
			s.metal = buf and buf.metal and #buf.metal or 0
			s.features = buf and buf.features and #buf.features or 0
			local t = buf and buf.terrain
			if t then
				-- a few Lua grid samples (0-based col, row, height) to compare with the texture
				s.samples = {}
				for _, f in ipairs({ { 0, 0 }, { 1, 1 }, { 0.5, 0.5 }, { 0.25, 0.75 } }) do
					local c, r = floor(f[1] * (t.cols - 1)), floor(f[2] * (t.rows - 1))
					s.samples[#s.samples + 1] = { c, r, t.grid[r + 1][c + 1] }
				end
			end
			return s
		end,
	}

	ClonePreview.init()

	widgetHandler:RegisterGlobal("CloneToolStackUpdate", function(undoCount, redoCount)
		historyUndoCount = undoCount or 0
		historyRedoCount = redoCount or 0
	end)
end

function widget:Shutdown()
	WG.CloneTool = nil
	widgetHandler:DeregisterGlobal("CloneToolStackUpdate")
	discardBuffer()
	if splatCaptureFBO then
		glDeleteTexture(splatCaptureFBO)
		splatCaptureFBO = nil
	end
	ClonePreview.shutdown()
	PasteMask.shutdown()
end

function widget:GetConfigData()
	return { previewOpacity = previewOpacity }
end

function widget:SetConfigData(data)
	if type(data) == "table" and type(data.previewOpacity) == "number" then
		setPreviewOpacity(data.previewOpacity)
	end
end
