local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Diffuse Painter",
		desc    = "WM/Gaea/Terragen-style layered diffuse paint over the SMF base texture",
		author  = "PtaQ",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

-- ============================================================================
-- Engine API aliases
-- ============================================================================
local Echo                  = Spring.Echo
local GetMouseState         = Spring.GetMouseState
local TraceScreenRay        = Spring.TraceScreenRay
local GetGroundHeight       = Spring.GetGroundHeight
local GetGroundNormal       = Spring.GetGroundNormal
local SetMapSquareTexture   = Spring.SetMapSquareTexture
local GetMapSquareTextureFn = Spring.GetMapSquareTexture
local SetMapShadingTexture  = Spring.SetMapShadingTexture

local glCreateTexture  = gl.CreateTexture
local glDeleteTexture  = gl.DeleteTexture
local glTexture        = gl.Texture
local glRenderToTexture = gl.RenderToTexture
local glCreateShader   = gl.CreateShader
local glDeleteShader   = gl.DeleteShader
local glUseShader      = gl.UseShader
local glUniform        = gl.Uniform
local glUniformInt     = gl.UniformInt
local glGetUniformLocation = gl.GetUniformLocation
local glTexRect        = gl.TexRect
local glColor          = gl.Color
local glBlending       = gl.Blending
local glLineWidth      = gl.LineWidth
local glDrawGroundCircle = gl.DrawGroundCircle
local glBeginEnd       = gl.BeginEnd
local glVertex         = gl.Vertex
local glDepthTest      = gl.DepthTest

local floor, max, min = math.floor, math.max, math.min
local cos, sin, pi    = math.cos, math.sin, math.pi
local sqrt, abs       = math.sqrt, math.abs

-- ============================================================================
-- Constants
-- ============================================================================
local SQUARE_SIZE_ELMOS = 1024 -- engine constant (one SMF texture square)
-- TILE_PX is the texture we hand to the engine via SetMapSquareTexture; it MUST
-- match the engine's native square size (1024) or the bind is rejected and the
-- square shows nothing. So the composite is capped at 1 texel/elmo — we cannot
-- exceed native map diffuse resolution through this API.
-- MASK_PX is internal (the compositor samples it, the engine never sees it). It
-- used to be 512, i.e. hand-paint deposits were 0.5 texel/elmo and got upscaled
-- into the 1024 composite — that upscale was the blur. Matching it to TILE_PX
-- removes the upscale step entirely (2x sharper painted strokes), which is the
-- most fidelity we can get out of the 8K source at this composite resolution.
local TILE_PX           = 1024 -- composite/seed resolution per square (engine-fixed, do not raise)
local MASK_PX           = 1024 -- per-layer hand-paint mask resolution (match TILE_PX: no upscale blur)
local MAX_LAYERS        = 8

local MIN_RADIUS = 8
local MAX_RADIUS = 2000
local DEFAULT_RADIUS = 128
local MIN_STRENGTH = 0.01
local MAX_STRENGTH = 1.0
local DEFAULT_STRENGTH = 1.0
local MIN_CURVE = 0.1
local MAX_CURVE = 5.0
local DEFAULT_CURVE = 1.5

local RADIUS_STEP   = 8
local STRENGTH_STEP = 0.05
local CURVE_STEP    = 0.1

local MIN_FRACTAL       = 0.0
local MAX_FRACTAL       = 1.0
local MIN_FRACTAL_FREQ  = 0.0001
local MAX_FRACTAL_FREQ  = 0.05
local FRACTAL_FREQ_STEP = 0.001

-- ============================================================================
-- State
-- ============================================================================
local active = false

local mapSizeX, mapSizeZ = 0, 0
local numSqX, numSqZ = 0, 0

-- squares[key] = {sx, sy, seedTex, compositeTex, bound, dirty}
local squares = {}
-- masks[layerId][key] = RGBA8 paint-canvas FBO texture (per layer per square).
-- For hand-paint layers, strokes are baked here with material*layerColor already
-- composited in, so switching material later only affects FUTURE strokes.
local masks = {}
-- maskClearTex: tiny zeroed FBO used to clear newly-allocated masks (lazy)
local maskClearTex = nil

-- Layer record table; one starter built-in layer pre-populated in Initialize.
-- layer = { id, name, enabled, opacity, color={r,g,b}, blend (string),
--           altMin, altMax, altFalloffLo, altFalloffHi, altEnabled,
--           slopeMin, slopeMax, slopeFalloffLo, slopeFalloffHi, slopeEnabled,
--           handPaintEnabled }
local layers = {}
local activeLayerId = nil
local nextLayerId = 1

-- Material library catalog: array of { key, name, path, resK }
local materialLibrary = {}

-- ============================================================================
-- Shading-map channels (SSMF global textures painted alongside the diffuse).
-- This registry is the extension point: a future engine feature (e.g. biplanar
-- weights) becomes one more entry + one branch in the channel stamp shader.
-- All three current channels share a "zero alpha = no effect" contract in the
-- engine SMF shader ($ssmf_normals: a blends vs geometry normal; $ssmf_specular:
-- black rgb = no highlight; $ssmf_emission: a masks base color), so a fresh
-- texture is visually neutral and strokes accumulate alpha exactly like the
-- diffuse paint masks.
--   div: texture resolution divisor vs elmos (normals stay sharper than spec,
--        per Beherith's guide spec/splat can run at 1/4 of diffuse res).
-- ============================================================================
local CHANNEL_DEFS = {
	{ key = "normals",  texName = "$ssmf_normals",  div = 2, mode = 0, neutral = { 0.5, 0.5, 1.0, 0.0 } },
	{ key = "specular", texName = "$ssmf_specular", div = 4, mode = 1, neutral = { 0.0, 0.0, 0.0, 0.0 } },
	{ key = "emission", texName = "$ssmf_emission", div = 4, mode = 2, neutral = { 0.0, 0.0, 0.0, 0.0 } },
}
local CHANNEL_MAX_PX = 8192 -- GL-safe cap for 32x32 maps
local CH_TILE_PX     = 512  -- undo snapshot granularity on channel textures

-- channels[key] = { def, tex, w, h, bound }
local channels = {}
local channelsEnabled = { normals = false, specular = false, emission = false }
-- Global specular intensity: how much of the material albedo leaks into the
-- spec color. The guide wants spec RGB to be the albedo "greatly darkened".
local specIntensity = 0.25

-- Grass attach: layers with grassDensity > 0 also plant grass (via the
-- grassgl4 patch API) along each stroke; erase strokes remove it. Master
-- toggle lets users paint texture-only without touching their grass work.
local grassAttachEnabled = true
local GRASS_KEYWORDS = { "grass", "moss", "forest", "leaves", "meadow" }
-- Grass stamps are far cheaper to skip than texture stamps (each changed patch
-- is an immediate VBO upload in grassgl4), and max-blend makes dense stamp
-- overlap redundant — so grass runs at its own, wider spacing within a drag.
local grassLastX, grassLastZ = nil, nil
local grassEditModeArmed = false

local function defaultGrassDensityFor(name)
	local n = (name or ""):lower()
	for i = 1, #GRASS_KEYWORDS do
		if n:find(GRASS_KEYWORDS[i], 1, true) then return 0.8 end
	end
	return 0
end

-- Brush
local brushRadius        = DEFAULT_RADIUS
local brushStrength      = DEFAULT_STRENGTH
local brushCurve         = DEFAULT_CURVE
local eraseMode          = false
local brushFractalAmount = 0.0   -- 0 = no warp, 1 = maximum organic fractal edge
local brushFractalFreq   = 0.003 -- world-space fBm frequency (1/elmos)

-- Pen-pressure modulation (reuses WG.TerraformBrush pen-pressure system).
-- Returns (effRadius, effStrength) for the current frame. When pressure is
-- disabled or the WG API is missing, returns the raw brush values.
--
-- Painter convention (differs from TerraformBrush): full pressure == slider
-- value, light touch == small fraction. Scale ∈ [floor, 1] where floor keeps
-- the pen barely usable at 0 pressure. Sensitivity stretches the curve so
-- "medium" feels harder/lighter.
local PEN_RADIUS_FLOOR   = 0.25
local PEN_STRENGTH_FLOOR = 0.05
local _penDiagPrinted = false
local function getEffectiveBrush()
	local effRadius, effStrength = brushRadius, brushStrength
	local tfBrush = WG.TerraformBrush
	if not tfBrush or not tfBrush.getState then return effRadius, effStrength end
	local tbState = tfBrush.getState()
	if not tbState or not tbState.penPressureEnabled then return effRadius, effStrength end
	-- Pen not actually touching tablet (mouse click, hover, lifted pen) →
	-- pass through unmodulated. Without this, mouse-clicks paint at the
	-- 5% floor because pressureMapped reads as 0.
	if not tbState.penInContact then return effRadius, effStrength end
	local pressureMapped = tbState.penPressureMapped or tbState.penPressure or 1.0
	local sensitivity    = tbState.penPressureSensitivity or 1.0
	-- Stretch by sensitivity; clamp into [0,1].
	local pressure = pressureMapped * sensitivity
	if pressure < 0 then pressure = 0 elseif pressure > 1 then pressure = 1 end
	if not _penDiagPrinted then
		_penDiagPrinted = true
		Echo(string.format(
			"[Diffuse Painter] pen pressure ACTIVE: pm=%.3f sens=%.2f size=%s intensity=%s",
			pressureMapped, sensitivity, tostring(tbState.penPressureModulateSize), tostring(tbState.penPressureModulateIntensity)))
	end
	if tbState.penPressureModulateSize or tbState.penPressureModulateRadius then
		local factor = PEN_RADIUS_FLOOR + (1.0 - PEN_RADIUS_FLOOR) * pressure
		effRadius = max(MIN_RADIUS, min(MAX_RADIUS, floor(effRadius * factor + 0.5)))
	end
	if tbState.penPressureModulateIntensity then
		local factor = PEN_STRENGTH_FLOOR + (1.0 - PEN_STRENGTH_FLOOR) * pressure
		effStrength = max(MIN_STRENGTH, min(MAX_STRENGTH, effStrength * factor))
	end
	return effRadius, effStrength
end

-- Mouse drag
local leftMouseHeld = false
local lastPaintX, lastPaintZ = nil, nil

-- Undo/redo. One entry per drag stroke; each entry holds the pre-stroke copy of
-- every (layerId, squareKey) mask the stroke touched (false = mask did not
-- exist yet, undo clears it). Snapshot textures are MASK_PX RGBA8 (~4 MB each),
-- so the stack is capped: worst case MAX_UNDO strokes * touched squares.
-- Channel-tile snapshots (1 MB per 512px tile) and grass patches ride in the
-- same entries; a max-radius drag with all channels on can add ~40 MB/entry,
-- so MAX_UNDO is also the lever if channel VRAM ever becomes a complaint.
local MAX_UNDO  = 10
local undoStack = {}   -- array of { {layerId=, key=, tex=texOrFalse}, ... }
local redoStack = {}
local strokeSnap = nil -- in-flight drag: { items = {...}, seen = {"id:key"=true} }
local pendingStrokeFinish = false -- mouse released but queued strokes not yet executed
local pendingHistoryOps = {} -- "undo"/"redo"/number(target index); run in DrawWorld (GL context)

-- Deferred GL work (Draw call-in context required)
local pendingInit       = false
local pendingFullBake   = false  -- re-bake already-allocated squares
local pendingFullCover  = false  -- allocate every map square + bake (heavy)
local pendingPaintStrokes = {}   -- array of {wx, wz, layerId, erase}
local dirtySquares      = {}     -- squareKey -> true; consumed each Draw

-- Shaders
local compositorShader   = nil
local stampShader        = nil
local copyShader         = nil
local channelStampShader = nil

-- Reusable ping-pong scratch textures keyed by size (TILE_PX / MASK_PX).
-- Both the compositor and stamp passes overwrite every texel of the temp
-- target (full-quad TexRect with blending off), so previous contents never
-- leak through and one cached texture per size is safe to reuse.
local scratchTex = {}

local uComp = {} -- uniform locations on compositorShader
local uStamp = {}
local uChan = {} -- uniform locations on channelStampShader

-- ============================================================================
-- Helpers
-- ============================================================================
local function squareKey(sx, sy) return sx * 1024 + sy end

local function getOrAllocSquare(sx, sy)
	if sx < 0 or sx >= numSqX or sy < 0 or sy >= numSqZ then return nil end
	local k = squareKey(sx, sy)
	local s = squares[k]
	if s then return s end
	s = { sx = sx, sy = sy, seedTex = nil, compositeTex = nil, bound = false, dirty = true }
	squares[k] = s
	return s
end

local function ensureLayerMaskTex(layerId, key)
	local layerMasks = masks[layerId]
	if not layerMasks then layerMasks = {}; masks[layerId] = layerMasks end
	local maskTex = layerMasks[key]
	if maskTex then return maskTex end
	maskTex = glCreateTexture(MASK_PX, MASK_PX, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL.RGBA8,
	})
	if not maskTex then return nil end
	-- Clear to fully transparent (alpha=0 means "no paint here").
	glRenderToTexture(maskTex, function()
		glBlending(false)
		glColor(0, 0, 0, 0)
		glTexRect(-1, -1, 1, 1)
		glBlending(true)
	end)
	layerMasks[key] = maskTex
	return maskTex
end

local function getWorldMousePosition()
	local mx, my = GetMouseState()
	local _, pos = TraceScreenRay(mx, my, true)
	if pos then return pos[1], pos[3] end
	return nil, nil
end

local function getScratchTexRect(w, h)
	local key = w * 100000 + h
	local tex = scratchTex[key]
	if tex then return tex end
	tex = glCreateTexture(w, h, {
		border = false, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true, format = GL.RGBA8,
	})
	scratchTex[key] = tex
	return tex
end

local function getScratchTex(px)
	return getScratchTexRect(px, px)
end

local function findLayer(id)
	for i = 1, #layers do
		if layers[i].id == id then return layers[i], i end
	end
end

-- ============================================================================
-- Undo/redo: per-stroke mask snapshots (GL context required for all of these)
-- ============================================================================
local function copyTexInto(dstTex, srcTex)
	glRenderToTexture(dstTex, function()
		glBlending(false)
		glUseShader(copyShader)
		glTexture(0, srcTex)
		glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		glTexture(0, false)
		glUseShader(0)
		glBlending(true)
	end)
end

local function clearMaskTex(maskTex)
	glRenderToTexture(maskTex, function()
		glBlending(false); glColor(0, 0, 0, 0); glTexRect(-1, -1, 1, 1); glBlending(true)
	end)
end

local function freeHistoryEntry(entry)
	for i = 1, #entry do
		if entry[i].tex then glDeleteTexture(entry[i].tex) end
	end
end

-- Record the pre-stroke state of one (layer, square) mask, once per drag.
local function snapshotMaskForStroke(layerId, key, existingMaskTex)
	if not strokeSnap then return end
	local seenKey = layerId .. ":" .. key
	if strokeSnap.seen[seenKey] then return end
	strokeSnap.seen[seenKey] = true
	local item = { layerId = layerId, key = key, tex = false }
	if existingMaskTex then
		local snapTex = glCreateTexture(MASK_PX, MASK_PX, {
			border = false, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true, format = GL.RGBA8,
		})
		if snapTex then
			copyTexInto(snapTex, existingMaskTex)
			item.tex = snapTex
		end
	end
	strokeSnap.items[#strokeSnap.items + 1] = item
end

local function finishStrokeSnapshot()
	if not strokeSnap then return end
	local items = strokeSnap.items
	strokeSnap = nil
	if #items == 0 then return end
	-- New stroke invalidates the redo branch.
	for i = 1, #redoStack do freeHistoryEntry(redoStack[i]) end
	redoStack = {}
	undoStack[#undoStack + 1] = items
	while #undoStack > MAX_UNDO do
		freeHistoryEntry(table.remove(undoStack, 1))
	end
end

-- Drop all undo/redo history (used when reset/bulk ops make snapshots stale —
-- restoring a single stroke over a cleared map would resurrect paint).
local function clearHistory()
	for i = 1, #undoStack do freeHistoryEntry(undoStack[i]) end
	undoStack = {}
	for i = 1, #redoStack do freeHistoryEntry(redoStack[i]) end
	redoStack = {}
end

-- Remove one layer's items from both stacks (its masks are gone, the snapshots
-- would only hold dead VRAM and produce no-op history steps).
local function purgeLayerFromHistory(layerId)
	local function purgeStack(stack)
		for ei = #stack, 1, -1 do
			local entry = stack[ei]
			for ii = #entry, 1, -1 do
				if entry[ii].layerId == layerId then
					if entry[ii].tex then glDeleteTexture(entry[ii].tex) end
					table.remove(entry, ii)
				end
			end
			if #entry == 0 then table.remove(stack, ei) end
		end
	end
	purgeStack(undoStack)
	purgeStack(redoStack)
end

-- Restore one layer-mask history item: capture the current mask in-place so
-- the item becomes its own inverse, then copy the saved state back (or clear,
-- for "mask did not exist yet" items).
local function restoreMaskItem(item)
	local layerMasks = masks[item.layerId]
	local curTex = layerMasks and layerMasks[item.key]
	local savedTex = item.tex
	if not curTex then return end
	local capTex = glCreateTexture(MASK_PX, MASK_PX, {
		border = false, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true, format = GL.RGBA8,
	})
	if not capTex then
		-- VRAM pressure: leave both the mask and the saved snapshot untouched
		-- rather than degrading the entry into "clear".
		Echo("[Diffuse Painter] undo capture texture failed; step skipped")
		return
	end
	copyTexInto(capTex, curTex)
	if savedTex then
		copyTexInto(curTex, savedTex)
		glDeleteTexture(savedTex)
	else
		clearMaskTex(curTex)
	end
	item.tex = capTex
	dirtySquares[item.key] = true
end

-- Restore one channel-region history item (forward-declared: it needs the
-- channel table helpers defined below; assigned right after them).
local restoreChannelItem

-- Swap an entry's saved state with the current one (works for both undo and
-- redo: the popped entry, with current state captured into it, goes onto the
-- opposite stack).
local function applyHistoryEntry(entry)
	for i = 1, #entry do
		local item = entry[i]
		if item.channel then
			if restoreChannelItem then restoreChannelItem(item) end
		elseif item.grass then
			-- Grass-attach patch: swap stored density with the current one.
			local api = WG['grassgl4']
			if api and api.getDensityAt and api.setDensityAt then
				local cur = api.getDensityAt(item.x, item.z) or 0
				api.setDensityAt(item.x, item.z, item.d or 0)
				item.d = cur
			end
		else
			restoreMaskItem(item)
		end
	end
end

local function runHistoryOps()
	-- An undo landing mid-drag would rewrite masks the open snapshot already
	-- captured, corrupting that stroke's "before" state. Keep ops queued until
	-- the drag seals.
	if leftMouseHeld or strokeSnap then return end
	for i = 1, #pendingHistoryOps do
		local op = pendingHistoryOps[i]
		local steps
		if op == "undo" then steps = { -1 }
		elseif op == "redo" then steps = { 1 }
		else
			-- numeric target index into the undo history
			steps = {}
			local target = max(0, min(op, #undoStack + #redoStack))
			local delta = target - #undoStack
			for _ = 1, abs(delta) do steps[#steps + 1] = (delta > 0) and 1 or -1 end
		end
		for j = 1, #steps do
			if steps[j] < 0 and #undoStack > 0 then
				local entry = table.remove(undoStack)
				applyHistoryEntry(entry)
				redoStack[#redoStack + 1] = entry
			elseif steps[j] > 0 and #redoStack > 0 then
				local entry = table.remove(redoStack)
				applyHistoryEntry(entry)
				undoStack[#undoStack + 1] = entry
			end
		end
	end
	pendingHistoryOps = {}
end

-- ============================================================================
-- Shading-map channels: allocation, seeding, engine binding (GL context only,
-- except unbindChannel which is plain engine API)
-- ============================================================================
local pendingChannelEnable = {} -- channel keys awaiting GL-side setup in DrawWorld
local pendingChannelReseed = false

local function channelDef(key)
	for i = 1, #CHANNEL_DEFS do
		if CHANNEL_DEFS[i].key == key then return CHANNEL_DEFS[i] end
	end
end

-- Fill a channel texture with the map's own shading texture when it has one
-- (so painting starts from the shipped art), else the neutral value.
-- Must run while the engine still binds ITS texture (or after unbinding ours),
-- otherwise we'd copy our own paint back onto itself.
local function seedChannelTex(ch)
	local def = ch.def
	local existing = gl.TextureInfo and gl.TextureInfo(def.texName)
	if existing and (existing.xsize or 0) > 1 then
		glRenderToTexture(ch.tex, function()
			glBlending(false)
			glUseShader(copyShader)
			glTexture(0, def.texName)
			glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
			glTexture(0, false)
			glUseShader(0)
			glBlending(true)
		end)
	else
		local n = def.neutral
		glRenderToTexture(ch.tex, function()
			glBlending(false)
			glColor(n[1], n[2], n[3], n[4])
			glTexRect(-1, -1, 1, 1)
			glColor(1, 1, 1, 1)
			glBlending(true)
		end)
	end
end

local function ensureChannel(key)
	local ch = channels[key]
	if ch and ch.tex then return ch end
	local def = channelDef(key)
	if not def then return nil end
	local w = min(CHANNEL_MAX_PX, floor(mapSizeX / def.div))
	local h = min(CHANNEL_MAX_PX, floor(mapSizeZ / def.div))
	local tex = glCreateTexture(w, h, {
		border = false, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true, format = GL.RGBA8,
	})
	if not tex then
		Echo("[Diffuse Painter] failed to create " .. key .. " channel texture (" .. w .. "x" .. h .. ")")
		return nil
	end
	ch = { def = def, tex = tex, w = w, h = h, bound = false }
	seedChannelTex(ch)
	channels[key] = ch
	return ch
end

local function bindChannel(ch)
	if not ch or ch.bound then return end
	if SetMapShadingTexture(ch.def.texName, ch.tex) then
		ch.bound = true
	else
		Echo("[Diffuse Painter] SetMapShadingTexture failed for " .. ch.def.texName)
	end
end

local function unbindChannel(ch)
	if not ch or not ch.bound then return end
	SetMapShadingTexture(ch.def.texName, "") -- empty string reverts to engine default
	ch.bound = false
end

local function setChannelEnabled(key, on)
	if channelsEnabled[key] == nil then return end
	on = on and true or false
	if channelsEnabled[key] == on then return end
	channelsEnabled[key] = on
	if on then
		pendingChannelEnable[#pendingChannelEnable + 1] = key
	else
		-- Keep the texture so re-enabling is instant; just hand the engine its
		-- own texture back.
		unbindChannel(channels[key])
	end
end

-- Snapshot the CH_TILE_PX tiles a stamp's pixel bbox covers, once per drag.
local function snapshotChannelTiles(ch, x0, y0, x1, y1)
	if not strokeSnap then return end
	local tx0, ty0 = floor(x0 / CH_TILE_PX), floor(y0 / CH_TILE_PX)
	local tx1, ty1 = floor((x1 - 1) / CH_TILE_PX), floor((y1 - 1) / CH_TILE_PX)
	for ty = ty0, ty1 do
		for tx = tx0, tx1 do
			local seenKey = "ch:" .. ch.def.key .. ":" .. tx .. ":" .. ty
			if not strokeSnap.seen[seenKey] then
				strokeSnap.seen[seenKey] = true
				local px = tx * CH_TILE_PX
				local py = ty * CH_TILE_PX
				local w = min(CH_TILE_PX, ch.w - px)
				local h = min(CH_TILE_PX, ch.h - py)
				if w > 0 and h > 0 then
					local snapTex = glCreateTexture(w, h, {
						border = false, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
						wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
						fbo = true, format = GL.RGBA8,
					})
					if snapTex then
						local u0, v0 = px / ch.w, py / ch.h
						local u1, v1 = (px + w) / ch.w, (py + h) / ch.h
						glRenderToTexture(snapTex, function()
							glBlending(false)
							glUseShader(copyShader)
							glTexture(0, ch.tex)
							glTexRect(-1, -1, 1, 1, u0, v0, u1, v1)
							glTexture(0, false)
							glUseShader(0)
							glBlending(true)
						end)
						strokeSnap.items[#strokeSnap.items + 1] = {
							channel = ch.def.key, x0 = px, y0 = py, w = w, h = h, tex = snapTex,
						}
					end
				end
			end
		end
	end
end

-- Channel-region history restore (assigned to the forward-declared local used
-- by applyHistoryEntry). Same capture-swap contract as restoreMaskItem.
restoreChannelItem = function(item)
	local ch = channels[item.channel]
	if not ch or not ch.tex then return end
	local capTex = glCreateTexture(item.w, item.h, {
		border = false, min_filter = GL.LINEAR, mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE, wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true, format = GL.RGBA8,
	})
	if not capTex then
		Echo("[Diffuse Painter] channel undo capture texture failed; step skipped")
		return
	end
	local u0, v0 = item.x0 / ch.w, item.y0 / ch.h
	local u1, v1 = (item.x0 + item.w) / ch.w, (item.y0 + item.h) / ch.h
	-- Current region -> capTex
	glRenderToTexture(capTex, function()
		glBlending(false)
		glUseShader(copyShader)
		glTexture(0, ch.tex)
		glTexRect(-1, -1, 1, 1, u0, v0, u1, v1)
		glTexture(0, false)
		glUseShader(0)
		glBlending(true)
	end)
	-- Saved region -> channel texture
	glRenderToTexture(ch.tex, function()
		glBlending(false)
		glUseShader(copyShader)
		glTexture(0, item.tex)
		glTexRect(u0 * 2 - 1, v0 * 2 - 1, u1 * 2 - 1, v1 * 2 - 1, 0, 0, 1, 1)
		glTexture(0, false)
		glUseShader(0)
		glBlending(true)
	end)
	glDeleteTexture(item.tex)
	item.tex = capTex
end

-- Should this channel receive paint from this stroke?
local function channelApplies(key, layer, erase)
	if not channelsEnabled[key] then return false end
	if erase then return true end
	if key == "normals"  then return (layer.normalPath or "") ~= "" end
	if key == "specular" then return true end -- albedo falls back to layer color
	if key == "emission" then return (layer.glowStrength or 0) > 0.001 end
	return false
end

-- One brush stamp into every applicable global channel texture. Two passes per
-- channel: copy the brush bbox region into a scratch (the stamp blend reads the
-- destination, and FBO feedback is undefined), then stamp the bbox back.
local function stampChannels(wx, wz, layer, erase, effR, effS)
	if not channelStampShader then return end
	-- The fractal warp displaces the sampled world position, so the touched
	-- region extends past the radius by the warp reach (fBm amplitude sum is
	-- ±0.871 per axis → warp vector length reaches ~1.23R·amount).
	local pad = effR * brushFractalAmount * 1.25 + 8
	local wx0 = max(0, wx - effR - pad)
	local wz0 = max(0, wz - effR - pad)
	local wx1 = min(mapSizeX, wx + effR + pad)
	local wz1 = min(mapSizeZ, wz + effR + pad)
	if wx1 <= wx0 or wz1 <= wz0 then return end

	for ci = 1, #CHANNEL_DEFS do
		local key = CHANNEL_DEFS[ci].key
		if channelApplies(key, layer, erase) then
			local ch = channels[key]
			if ch and ch.tex then
				local x0 = floor(wx0 / mapSizeX * ch.w)
				local y0 = floor(wz0 / mapSizeZ * ch.h)
				local x1 = min(ch.w, floor(wx1 / mapSizeX * ch.w) + 1)
				local y1 = min(ch.h, floor(wz1 / mapSizeZ * ch.h) + 1)

				-- Bounded scratch: only the bbox is staged, so the scratch can be
				-- much smaller than the channel (a channel-sized scratch would
				-- double channel VRAM — +256 MB on a 32x32 map). Brushes whose
				-- bbox exceeds the scratch get a downsampled destination read
				-- (LINEAR), which only ever happens at extreme radius+fractal.
				local SW = min(ch.w, 4096)
				local SH = min(ch.h, 4096)
				local scratch = getScratchTexRect(SW, SH)
				if scratch then
					-- Snapshot only after the scratch is known good: a failed
					-- scratch alloc must not leave no-op tiles in the undo entry.
					snapshotChannelTiles(ch, x0, y0, x1, y1)

					local u0, v0 = x0 / ch.w, y0 / ch.h
					local u1, v1 = x1 / ch.w, y1 / ch.h
					local nx0, ny0 = u0 * 2 - 1, v0 * 2 - 1
					local nx1, ny1 = u1 * 2 - 1, v1 * 2 - 1
					local usedW = min(x1 - x0, SW)
					local usedH = min(y1 - y0, SH)
					local su1, sv1 = usedW / SW, usedH / SH

					-- Pass 1: bbox content -> scratch region [0..su1, 0..sv1]
					glRenderToTexture(scratch, function()
						glBlending(false)
						glUseShader(copyShader)
						glTexture(0, ch.tex)
						glTexRect(-1, -1, su1 * 2 - 1, sv1 * 2 - 1, u0, v0, u1, v1)
						glTexture(0, false)
						glUseShader(0)
						glBlending(true)
					end)

					-- Pass 2: stamp bbox back into the channel texture
					local useTex = false
					if layer.texturePath and layer.texturePath ~= "" then
						useTex = pcall(glTexture, 1, layer.texturePath) and true or false
					end
					if not useTex then glTexture(1, "$heightmap") end
					local useNormal = false
					if layer.normalPath and layer.normalPath ~= "" then
						useNormal = pcall(glTexture, 2, layer.normalPath) and true or false
					end
					if not useNormal then glTexture(2, "$heightmap") end
					local useRough = false
					if layer.roughPath and layer.roughPath ~= "" then
						useRough = pcall(glTexture, 3, layer.roughPath) and true or false
					end
					if not useRough then glTexture(3, "$heightmap") end

					glRenderToTexture(ch.tex, function()
						glBlending(false)
						glUseShader(channelStampShader)
						glTexture(0, scratch)
						glUniform(uChan.dstUvOffset, u0, v0)
						glUniform(uChan.dstUvScale, su1 / (u1 - u0), sv1 / (v1 - v0))
						glUniform(uChan.mapSize, mapSizeX, mapSizeZ)
						glUniform(uChan.brushPos, wx, wz)
						glUniform(uChan.brushRadius, effR)
						glUniform(uChan.brushStrength, effS)
						glUniform(uChan.brushCurve, brushCurve)
						glUniformInt(uChan.brushErase, erase and 1 or 0)
						glUniformInt(uChan.channelMode, ch.def.mode)
						glUniformInt(uChan.useLayerTex, useTex and 1 or 0)
						glUniformInt(uChan.useNormalTex, useNormal and 1 or 0)
						glUniformInt(uChan.useRoughTex, useRough and 1 or 0)
						glUniform(uChan.tileScale, layer.tileScale or 384)
						glUniform(uChan.layerColor, layer.color[1], layer.color[2], layer.color[3])
						glUniform(uChan.glowStrength, layer.glowStrength or 0)
						glUniform(uChan.specIntensity, specIntensity)
						glUniform(uChan.fractalAmount, brushFractalAmount)
						glUniform(uChan.fractalFreq, brushFractalFreq)
						glTexRect(nx0, ny0, nx1, ny1, u0, v0, u1, v1)
						glTexture(0, false)
						glUseShader(0)
						glBlending(true)
					end)
					glTexture(3, false)
					glTexture(2, false)
					glTexture(1, false)
				end
			end
		end
	end
end

-- ============================================================================
-- Grass attach: plant grass along strokes through the grassgl4 patch API
-- ============================================================================
local function paintGrassAttach(wx, wz, layer, erase, effR, effS)
	if not grassAttachEnabled then return end
	local gd = layer.grassDensity or 0
	if gd <= 0.001 then return end -- erase included: don't touch grass the layer never planted
	local api = WG['grassgl4']
	if not (api and api.setDensityAt and api.getDensityAt) then return end
	-- Blank/new maps ship no grass data; materialize the editable grass map
	-- once instead of silently no-opping (the New Map flow is a primary user).
	if api.hasGrass and not api.hasGrass() then
		if not grassEditModeArmed and api.enableEditMode then
			grassEditModeArmed = true
			api.enableEditMode()
		end
		if api.hasGrass and not api.hasGrass() then return end
	end

	-- Texture stamps land every 0.3*R; grass max-blend makes that overlap
	-- redundant and each changed patch costs a VBO upload — thin to ~0.75*R.
	if grassLastX then
		local gdx, gdz = wx - grassLastX, wz - grassLastZ
		if (gdx * gdx + gdz * gdz) < (effR * 0.75) * (effR * 0.75) then return end
	end
	grassLastX, grassLastZ = wx, wz

	local step, minVisible = 32, 0
	if api.getConfig then
		local cfg = api.getConfig()
		if cfg then
			step = cfg.patchResolution or 32
			-- Below this density grassgl4 quantizes to zero; skipping it here
			-- avoids re-uploading the whole falloff fringe as no-ops.
			minVisible = (cfg.grassMinSize or 1) / max(1, cfg.grassMaxSize or 20)
		end
	end
	-- Align to the patch grid (stable undo keys across stamps) and clamp to
	-- the map: grassgl4's world->cell math wraps rows instead of clamping, so
	-- unclamped coords would plant grass on the opposite map edge.
	local x0 = max(0, floor((wx - effR) / step) * step)
	local z0 = max(0, floor((wz - effR) / step) * step)
	local x1 = min(mapSizeX, wx + effR)
	local z1 = min(mapSizeZ, wz + effR)
	local r2 = effR * effR
	for x = x0, x1, step do
		for z = z0, z1, step do
			local dx, dz = x - wx, z - wz
			local d2 = dx * dx + dz * dz
			if d2 <= r2 then
				local fall = 1.0 - (d2 / r2) ^ (brushCurve * 0.5) -- == 1-(d/r)^curve
				local cur = api.getDensityAt(x, z) or 0
				local new
				if erase then
					new = max(0, cur - gd * effS * fall)
				else
					-- Max-blend like the grass brush paint mode: repeated strokes
					-- never exceed the layer's target density.
					new = max(cur, gd * effS * fall)
				end
				if new < minVisible then new = 0 end
				if new ~= cur then
					if strokeSnap then
						local seenKey = "g:" .. x .. ":" .. z
						if not strokeSnap.seen[seenKey] then
							strokeSnap.seen[seenKey] = true
							strokeSnap.items[#strokeSnap.items + 1] = { grass = true, x = x, z = z, d = cur }
						end
					end
					api.setDensityAt(x, z, new)
				end
			end
		end
	end
end

-- ============================================================================
-- Shaders
-- ============================================================================

local VERT_SRC = [[
	#version 130
	void main() {
		gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
		gl_TexCoord[0] = gl_MultiTexCoord0;
	}
]]

-- Stochastic non-tiling sampler (Inigo Quilez "Texture Repetition" technique
-- 3, simplified). Splits UV space into 1x1 macro-cells, each cell gets a
-- random offset + sign-flip (acts as random rotation/mirror per tile), and
-- the 4 neighboring cells are blended by smoothstep weights at the cell
-- boundaries. The result hides the underlying texture period without
-- introducing visible seams.
local FRACTAL_SAMPLE_GLSL = [[
	vec4 hash4(vec2 p) {
		p = vec2(dot(p, vec2(127.1, 311.7)),
		         dot(p, vec2(269.5, 183.3)));
		return fract(sin(vec4(p.x, p.y, p.x + p.y, p.x - p.y)) * 43758.5453);
	}
	vec3 sampleNoTile(sampler2D tex, vec2 uv) {
		vec2 iuv = floor(uv);
		vec2 fuv = fract(uv);
		vec4 ofa = hash4(iuv + vec2(0.0, 0.0));
		vec4 ofb = hash4(iuv + vec2(1.0, 0.0));
		vec4 ofc = hash4(iuv + vec2(0.0, 1.0));
		vec4 ofd = hash4(iuv + vec2(1.0, 1.0));
		// random per-cell sign flip (mirror) on uv coords for variety
		ofa.zw = sign(ofa.zw - 0.5);
		ofb.zw = sign(ofb.zw - 0.5);
		ofc.zw = sign(ofc.zw - 0.5);
		ofd.zw = sign(ofd.zw - 0.5);
		vec2 uva = uv * ofa.zw + ofa.xy;
		vec2 uvb = uv * ofb.zw + ofb.xy;
		vec2 uvc = uv * ofc.zw + ofc.xy;
		vec2 uvd = uv * ofd.zw + ofd.xy;
		// Narrow blend band (0.45..0.55) keeps each cell sharp; only a
		// thin seam shows the crossfade. Wider bands ghost the texture.
		vec2 b = smoothstep(0.45, 0.55, fuv);
		vec3 sa = texture2D(tex, uva).rgb;
		vec3 sb = texture2D(tex, uvb).rgb;
		vec3 sc = texture2D(tex, uvc).rgb;
		vec3 sd = texture2D(tex, uvd).rgb;
		return mix(mix(sa, sb, b.x), mix(sc, sd, b.x), b.y);
	}
	// Direction-preserving variant for normal maps: random per-cell OFFSETS
	// only, no mirroring — flipping a tangent-space normal map's UVs without
	// negating its XY inverts the lighting in the mirrored cells.
	vec3 sampleNoTileOffset(sampler2D tex, vec2 uv) {
		vec2 iuv = floor(uv);
		vec2 fuv = fract(uv);
		vec2 oa = hash4(iuv + vec2(0.0, 0.0)).xy;
		vec2 ob = hash4(iuv + vec2(1.0, 0.0)).xy;
		vec2 oc = hash4(iuv + vec2(0.0, 1.0)).xy;
		vec2 od = hash4(iuv + vec2(1.0, 1.0)).xy;
		vec2 b = smoothstep(0.45, 0.55, fuv);
		vec3 sa = texture2D(tex, uv + oa).rgb;
		vec3 sb = texture2D(tex, uv + ob).rgb;
		vec3 sc = texture2D(tex, uv + oc).rgb;
		vec3 sd = texture2D(tex, uv + od).rgb;
		return mix(mix(sa, sb, b.x), mix(sc, sd, b.x), b.y);
	}
]]

-- Compositor: 1 layer per pass. Reads compositeTex as input (start = seed),
-- samples layer mask + procedural masks, blends layer.color over input.
-- Supports blend modes: 0=Normal 1=Multiply 2=Screen 3=Overlay 4=SoftLight
--                       5=ColorDodge 6=HardLight 7=Difference
-- Hydro erosion mask: paints preferentially in concave valleys/channels.
-- Thermo erosion mask: paints at slope transitions near the repose angle.
local COMPOSITOR_FRAG_SRC = [[
	#version 130
	uniform sampler2D srcTex;      // current composite
	uniform sampler2D maskTex;     // per-layer hand-paint mask
	uniform sampler2D heightMap;   // engine $heightmap
	uniform sampler2D layerTex;    // optional tiled material diffuse
	uniform vec2  squareOrigin;    // world-space origin of this square (elmos)
	uniform vec2  squareSize;      // world-space size of this square (elmos)
	uniform vec2  mapSize;         // full map size (elmos)
	uniform vec3  layerColor;
	uniform float layerOpacity;
	uniform int   blendMode;       // 0=normal 1=multiply 2=screen 3=overlay 4=softlight 5=colordodge 6=hardlight 7=difference
	uniform int   useLayerTex;
	uniform float tileScale;       // world elmos per material UV tile
	// Altitude mask
	uniform int   altEnabled;
	uniform float altMin, altMax, altFalloffLo, altFalloffHi;
	// Slope mask
	uniform int   slopeEnabled;
	uniform float slopeMinCos;     // cos(maxAngle) — higher = flatter
	uniform float slopeMaxCos;     // cos(minAngle)
	uniform float slopeFalloffLo;  // in cos units
	uniform float slopeFalloffHi;
	// Hand paint
	uniform int   handPaintEnabled;
	// Hydro erosion (valley/channel affinity via heightmap concavity)
	uniform int   hydroEnabled;
	uniform float hydroStrength;   // scale: larger = more selective to valleys
	uniform float hydroFalloffLo;  // normalised flow at which painting starts
	uniform float hydroFalloffHi;  // normalised flow at full strength
	// Thermo erosion (talus / repose-angle zone)
	uniform int   thermoEnabled;
	uniform float thermoAngle;     // repose angle (degrees, e.g. 30)
	uniform float thermoFalloff;   // ± band width around repose angle (degrees)

	float smoothBand(float v, float lo, float hi, float fLo, float fHi) {
		float a = (fLo > 0.001) ? smoothstep(lo - fLo, lo, v) : step(lo, v);
		float b = (fHi > 0.001) ? (1.0 - smoothstep(hi, hi + fHi, v)) : step(v, hi);
		return clamp(a * b, 0.0, 1.0);
	}

	// Photoshop-style blend: base = existing layer, blend = incoming colour.
	vec3 blendColors(int mode, vec3 base, vec3 blend) {
		if (mode == 0) return blend;                                              // Normal
		if (mode == 1) return base * blend;                                       // Multiply
		if (mode == 2) return base + blend - base * blend;                        // Screen
		if (mode == 3) return mix(2.0*base*blend,                                 // Overlay
		                          1.0 - 2.0*(1.0-base)*(1.0-blend),
		                          step(vec3(0.5), base));
		if (mode == 4) return mix(                                                // Soft Light
		                    2.0*base*blend + base*base*(1.0-2.0*blend),
		                    sqrt(clamp(base,0.0001,1.0))*(2.0*blend-1.0) + 2.0*base*(1.0-blend),
		                    step(vec3(0.5), blend));
		if (mode == 5) return clamp(base / max(1.0-blend, vec3(0.001)), 0.0, 1.4); // Color Dodge
		if (mode == 6) return mix(2.0*base*blend,                                 // Hard Light
		                          1.0 - 2.0*(1.0-base)*(1.0-blend),
		                          step(vec3(0.5), blend));
		if (mode == 7) return abs(base - blend);                                  // Difference
		return blend;
	}

	void main() {
		vec2 localUV = gl_TexCoord[0].st;
		vec2 worldXZ = squareOrigin + localUV * squareSize;
		vec4 src = texture2D(srcTex, localUV);

		// Hand-paint: colour already baked at stroke time; just blend with mode.
		if (handPaintEnabled == 1) {
			vec4 paint = texture2D(maskTex, localUV);
			float pa = clamp(paint.a * layerOpacity, 0.0, 1.0);
			// paint.rgb is premultiplied (stored as color * alpha by the stamp shader).
			// De-premultiply to recover the actual deposited colour before blending,
			// otherwise the deposit contribution is paint.a² instead of paint.a.
			vec3 paintColor = (paint.a > 0.001) ? paint.rgb / paint.a : vec3(0.0);
			vec3 bl = blendColors(blendMode, src.rgb, paintColor);
			gl_FragColor = vec4(mix(src.rgb, bl, pa), 1.0);
			return;
		}

		float m = 1.0;

		// Shared heightmap samples (one tap for alt, four more for gradients).
		vec2 hmTexel = 1.0 / vec2(textureSize(heightMap, 0));
		vec2 uvCtr   = worldXZ / mapSize;
		vec2 cellSz  = mapSize * hmTexel;

		if (altEnabled == 1 || slopeEnabled == 1 || hydroEnabled == 1 || thermoEnabled == 1) {
			float hC = texture2D(heightMap, uvCtr).x;
			float hL = texture2D(heightMap, uvCtr + vec2(-hmTexel.x, 0.0)).x;
			float hR = texture2D(heightMap, uvCtr + vec2( hmTexel.x, 0.0)).x;
			float hD = texture2D(heightMap, uvCtr + vec2(0.0, -hmTexel.y)).x;
			float hU = texture2D(heightMap, uvCtr + vec2(0.0,  hmTexel.y)).x;

			if (altEnabled == 1) {
				m *= smoothBand(hC, altMin, altMax, altFalloffLo, altFalloffHi);
			}

			if (slopeEnabled == 1) {
				vec3 nrm = normalize(vec3(hL - hR, 2.0 * cellSz.x, hD - hU));
				m *= smoothBand(nrm.y, slopeMinCos, slopeMaxCos, slopeFalloffLo, slopeFalloffHi);
			}

			if (hydroEnabled == 1) {
				// Positive Laplacian = concave = valley/channel = high flow.
				float lap  = hL + hR + hD + hU - 4.0 * hC;
				float flow = clamp(lap * hydroStrength, 0.0, 1.0);
				float hfHi = max(hydroFalloffHi, hydroFalloffLo + 0.001);
				m *= smoothstep(hydroFalloffLo, hfHi, flow);
			}

			if (thermoEnabled == 1) {
				// Surface normal → slope angle in degrees.
				vec3 nrmT = normalize(vec3(hL - hR, 2.0 * cellSz.x, hD - hU));
				float slopeAngleDeg = acos(clamp(nrmT.y, 0.0, 1.0)) * (180.0 / 3.14159265);
				float tFall = max(thermoFalloff, 0.5);
				float tLo   = max(0.0, thermoAngle - tFall);
				float tHi   = thermoAngle + tFall;
				float tMask = smoothBand(slopeAngleDeg, tLo, tHi, tFall, tFall);
				// Weight by steepness of uphill source terrain (6-texel radius).
				vec2 grad2d = vec2(hR - hL, hU - hD);
				float gLen  = length(grad2d);
				float steep = 0.0;
				if (gLen > 0.0001) {
					vec2 upDir = (grad2d / gLen) * hmTexel * 6.0;
					vec2 upUV  = clamp(uvCtr + upDir, vec2(0.001), vec2(0.999));
					float hUp  = texture2D(heightMap, upUV).x;
					float rise = hUp - hC;
					float run  = length((grad2d / gLen) * cellSz * 6.0);
					float upAng = atan(rise / max(run, 0.001)) * (180.0 / 3.14159265);
					steep = clamp(upAng / 45.0, 0.0, 1.0);
				}
				m *= tMask * steep;
			}
		}

		float a = clamp(m * layerOpacity, 0.0, 1.0);
		vec3 layerRGB = layerColor;
		if (useLayerTex == 1) {
			vec2 tileUV = worldXZ / max(tileScale, 1.0);
			layerRGB = sampleNoTile(layerTex, tileUV) * layerColor;
		}
		vec3 blended = blendColors(blendMode, src.rgb, layerRGB);
		vec3 outRGB  = mix(src.rgb, blended, a);
		gl_FragColor = vec4(outRGB, 1.0);
	}
]]

-- Brush stamp into a per-layer RGBA canvas. The shader samples the current
-- material texture (if any) at world UV / tileScale, multiplies by layerColor,
-- and blends it over the canvas using brush alpha. This way the deposited RGB
-- is fully baked at stroke time — switching material later only affects FUTURE
-- strokes. Erase reduces canvas alpha to fade the paint.
-- fractalAmount > 0 applies fBm domain-warp to create organic/fractal edges.
local STAMP_FRAG_SRC = [[
	#version 130
	uniform sampler2D srcMask;     // current RGBA canvas
	uniform sampler2D layerTex;    // material diffuse (bound to a 1x1 white fallback if no path)
	uniform sampler2D normalTex;   // material normal (nor_gl); used iff useNormalTex==1
	uniform sampler2D roughTex;    // material roughness; used iff useRoughTex==1
	uniform vec2  squareOrigin;
	uniform vec2  squareSize;
	uniform vec2  brushPos;
	uniform float brushRadius;
	uniform float brushStrength;
	uniform float brushCurve;
	uniform int   brushErase;
	uniform int   useLayerTex;
	uniform int   useNormalTex;
	uniform int   useRoughTex;
	uniform float tileScale;
	uniform float pbrStrength;     // 0 = no shading bake; ~1.0 = strong
	uniform vec3  layerColor;
	uniform float fractalAmount;   // 0 = off, 0-1 = brush-edge fBm warp strength
	uniform float fractalFreq;     // world-space fBm frequency (1/elmos)

	float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

	// Value-noise fBm for organic brush-edge warping
	float hfh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
	float hfn(vec2 p) {
		vec2 i = floor(p), f = fract(p);
		vec2 u = f * f * (3.0 - 2.0 * f);
		return mix(mix(hfh(i), hfh(i+vec2(1.0,0.0)), u.x),
		           mix(hfh(i+vec2(0.0,1.0)), hfh(i+vec2(1.0,1.0)), u.x), u.y) * 2.0 - 1.0;
	}
	float hffbm(vec2 p) {
		float v = 0.0;
		v += 0.500 * hfn(p); p *= 2.13;
		v += 0.225 * hfn(p); p *= 2.13;
		v += 0.101 * hfn(p); p *= 2.13;
		v += 0.045 * hfn(p);
		return v;
	}

	void main() {
		vec2 uv    = gl_TexCoord[0].st;
		vec2 world = squareOrigin + uv * squareSize;

		// Domain-warp world position to produce fractal / organic brush edges.
		if (fractalAmount > 0.001) {
			float wx = hffbm(world * fractalFreq + vec2(31.4, 57.2));
			float wy = hffbm(world * fractalFreq + vec2(89.7, 23.1));
			world += vec2(wx, wy) * brushRadius * fractalAmount;
		}

		vec2  d = world - brushPos;
		float r = length(d) / brushRadius;
		vec4 current = texture2D(srcMask, uv);
		if (r >= 1.0) { gl_FragColor = current; return; }
		float fall   = 1.0 - pow(r, brushCurve);
		float amount = clamp(brushStrength * fall, 0.0, 1.0);
		if (brushErase == 1) {
			float newA = max(0.0, current.a - amount);
			gl_FragColor = vec4(current.rgb, newA);
			return;
		}
		vec3 deposit = layerColor;
		vec2 tileUV  = world / max(tileScale, 1.0);
		if (useLayerTex == 1) {
			deposit = sampleNoTile(layerTex, tileUV) * layerColor;
		}
		// Faux PBR shading bake. Engine API only takes diffuse, so we bake
		// directional light + crevice AO + bump-from-luminance + specular
		// highlight into RGB.
		if (pbrStrength > 0.001) {
			// Build a normal: prefer real normal map, else derive from diffuse
			// luminance gradient at multiple scales (free pseudo-bump).
			vec3 N;
			if (useNormalTex == 1) {
				vec3 nm = sampleNoTileOffset(normalTex, tileUV) * 2.0 - 1.0;
				N = normalize(vec3(nm.x, nm.y, max(nm.z, 0.05)));
			} else if (useLayerTex == 1) {
				// Gradient must use PLAIN texture() (not sampleNoTile) — the
				// no-tile sampler randomizes per-cell so neighbor taps would
				// cross random offsets and produce pure noise.
				float tx = 1.0 / max(tileScale, 1.0);
				float cL = luma(texture(layerTex, tileUV - vec2(tx, 0.0)).rgb);
				float cR = luma(texture(layerTex, tileUV + vec2(tx, 0.0)).rgb);
				float cD = luma(texture(layerTex, tileUV - vec2(0.0, tx)).rgb);
				float cU = luma(texture(layerTex, tileUV + vec2(0.0, tx)).rgb);
				float gx = (cR - cL) * 5.0;
				float gy = (cU - cD) * 5.0;
				N = normalize(vec3(-gx, -gy, 1.0));
			} else {
				N = vec3(0.0, 0.0, 1.0);
			}
			float rough = 0.55;
			if (useRoughTex == 1) {
				rough = clamp(sampleNoTile(roughTex, tileUV).r, 0.0, 1.0);
			} else if (useLayerTex == 1) {
				// Approximate roughness from diffuse luma: darker -> rougher.
				rough = clamp(1.0 - luma(deposit), 0.25, 0.85);
			}
			vec3 L = normalize(vec3(0.35, 0.45, 0.82));
			vec3 V = vec3(0.0, 0.0, 1.0);          // top-down view
			vec3 H = normalize(L + V);
			float lambert = clamp(dot(N, L), 0.0, 1.0);
			float ao = mix(0.55, 1.0, N.z);         // gentle crevice darkening
			float shade = (0.45 + 0.75 * lambert) * ao;
			// Specular highlight: Blinn-Phong, gated by (1 - rough).
			float specExp = mix(12.0, 48.0, 1.0 - rough);
			float specTerm = pow(clamp(dot(N, H), 0.0, 1.0), specExp);
			float specStrength = mix(0.02, 0.18, 1.0 - rough);
			// Mild contrast pump.
			float lum = luma(deposit);
			float contrast = mix(0.88, 1.12, smoothstep(0.0, 1.0, lum));
			shade *= contrast;
			shade = mix(1.0, shade, pbrStrength);
			deposit *= clamp(shade, 0.0, 1.6);
			deposit += vec3(specTerm * specStrength * pbrStrength);
			deposit = clamp(deposit, 0.0, 1.4);
		}
		float newA  = current.a + (1.0 - current.a) * amount;
		vec3 newRGB = mix(current.rgb, deposit, amount);
		gl_FragColor = vec4(newRGB, clamp(newA, 0.0, 1.0));
	}
]]

-- Channel stamp: writes one brush stamp into a global SSMF shading texture.
-- Drawn as the brush's bbox sub-quad only; texcoords carry the channel
-- texture's own UVs, so worldXZ = uv * mapSize. The previous content arrives
-- pre-copied into dstTex (same UVs) because the falloff blend needs a read of
-- the destination and FBO feedback loops are undefined behaviour.
-- Engine semantics painted against (verified in SMFFragProg.glsl):
--   normals : rgb*2-1 tangent normal, a = blend weight vs geometry normal
--   specular: rgb additive highlight color (premultiply by exponent per the
--             mapping guide), a*16 = Blinn exponent
--   emission: rgb added to frag, a masks out the underlying diffuse
local CHANNEL_STAMP_FRAG_SRC = [[
	#version 130
	uniform sampler2D dstTex;      // bbox copy of current channel content
	uniform vec2  dstUvOffset;     // bbox origin in channel UV space
	uniform vec2  dstUvScale;      // channel UV -> scratch UV (bbox may be downsampled)
	uniform sampler2D layerTex;    // material diffuse
	uniform sampler2D normalTex;   // material normal (nor_gl)
	uniform sampler2D roughTex;    // material roughness
	uniform vec2  mapSize;         // full map size (elmos)
	uniform vec2  brushPos;
	uniform float brushRadius;
	uniform float brushStrength;
	uniform float brushCurve;
	uniform int   brushErase;
	uniform int   channelMode;     // 0 = normals, 1 = specular, 2 = emission
	uniform int   useLayerTex;
	uniform int   useNormalTex;
	uniform int   useRoughTex;
	uniform float tileScale;
	uniform vec3  layerColor;
	uniform float glowStrength;    // emission level for this layer (0..1)
	uniform float specIntensity;   // global albedo->spec color factor
	uniform float fractalAmount;
	uniform float fractalFreq;

	// Same value-noise fBm as the diffuse stamp, so channel strokes warp
	// identically and stay registered with the painted diffuse.
	float hfh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
	float hfn(vec2 p) {
		vec2 i = floor(p), f = fract(p);
		vec2 u = f * f * (3.0 - 2.0 * f);
		return mix(mix(hfh(i), hfh(i+vec2(1.0,0.0)), u.x),
		           mix(hfh(i+vec2(0.0,1.0)), hfh(i+vec2(1.0,1.0)), u.x), u.y) * 2.0 - 1.0;
	}
	float hffbm(vec2 p) {
		float v = 0.0;
		v += 0.500 * hfn(p); p *= 2.13;
		v += 0.225 * hfn(p); p *= 2.13;
		v += 0.101 * hfn(p); p *= 2.13;
		v += 0.045 * hfn(p);
		return v;
	}

	void main() {
		vec2 uv    = gl_TexCoord[0].st;
		vec2 world = uv * mapSize;
		if (fractalAmount > 0.001) {
			float wx = hffbm(world * fractalFreq + vec2(31.4, 57.2));
			float wy = hffbm(world * fractalFreq + vec2(89.7, 23.1));
			world += vec2(wx, wy) * brushRadius * fractalAmount;
		}
		vec4 dst = texture2D(dstTex, (uv - dstUvOffset) * dstUvScale);
		vec2  d = world - brushPos;
		float r = length(d) / brushRadius;
		if (r >= 1.0) { gl_FragColor = dst; return; }
		float fall   = 1.0 - pow(r, brushCurve);
		float amount = clamp(brushStrength * fall, 0.0, 1.0);
		vec2 tileUV  = world / max(tileScale, 1.0);

		if (brushErase == 1) {
			if (channelMode == 1) {
				// Spec alpha is exponent data, not coverage — fade the color.
				gl_FragColor = vec4(dst.rgb * (1.0 - amount), dst.a);
			} else if (channelMode == 2) {
				// Emission rgb is added unconditionally by the engine (alpha only
				// masks the base diffuse), so the glow color must fade too or
				// erasing makes the area BRIGHTER.
				gl_FragColor = vec4(dst.rgb * (1.0 - amount), max(0.0, dst.a - amount));
			} else {
				gl_FragColor = vec4(dst.rgb, max(0.0, dst.a - amount));
			}
			return;
		}

		if (channelMode == 0) {
			// No-mirror sampler: the mirroring no-tile variant flips UVs without
			// negating the normal's XY, which inverts the lighting per macro-cell.
			vec3 nm = (useNormalTex == 1) ? sampleNoTileOffset(normalTex, tileUV) : vec3(0.5, 0.5, 1.0);
			float newA = dst.a + (1.0 - dst.a) * amount;
			gl_FragColor = vec4(mix(dst.rgb, nm, amount), newA);
		} else if (channelMode == 1) {
			vec3 albedo = layerColor;
			if (useLayerTex == 1) albedo = sampleNoTile(layerTex, tileUV) * layerColor;
			float rough = 0.55;
			if (useRoughTex == 1) rough = clamp(sampleNoTile(roughTex, tileUV).r, 0.0, 1.0);
			// Exponent below ~16/255 reads as diffuse light (guide p.10) — floor it.
			float expA    = clamp(1.0 - rough, 0.07, 1.0);
			vec3  specRGB = albedo * specIntensity * expA; // premultiplied by exponent
			gl_FragColor = vec4(mix(dst.rgb, specRGB, amount), mix(dst.a, expA, amount));
		} else {
			vec3 glowRGB = layerColor * glowStrength;
			gl_FragColor = vec4(mix(dst.rgb, glowRGB, amount), mix(dst.a, glowStrength, amount));
		}
	}
]]

local COPY_FRAG_SRC = [[
	#version 130
	uniform sampler2D tex0;
	void main() { gl_FragColor = texture2D(tex0, gl_TexCoord[0].st); }
]]

local function createShaders()
	local function injectFractal(src)
		return (src:gsub("(#version%s+%d+%s*\n)", "%1" .. FRACTAL_SAMPLE_GLSL .. "\n", 1))
	end
	compositorShader = glCreateShader({
		vertex = VERT_SRC, fragment = injectFractal(COMPOSITOR_FRAG_SRC),
		uniformInt = { srcTex = 0, maskTex = 1, heightMap = 2, layerTex = 3 },
	})
	if not compositorShader then
		Echo("[Diffuse Painter] compositor shader failed: " .. tostring(gl.GetShaderLog())); return false
	end
	uComp.squareOrigin     = glGetUniformLocation(compositorShader, "squareOrigin")
	uComp.squareSize       = glGetUniformLocation(compositorShader, "squareSize")
	uComp.mapSize          = glGetUniformLocation(compositorShader, "mapSize")
	uComp.layerColor       = glGetUniformLocation(compositorShader, "layerColor")
	uComp.layerOpacity     = glGetUniformLocation(compositorShader, "layerOpacity")
	uComp.blendMode        = glGetUniformLocation(compositorShader, "blendMode")
	uComp.altEnabled       = glGetUniformLocation(compositorShader, "altEnabled")
	uComp.altMin           = glGetUniformLocation(compositorShader, "altMin")
	uComp.altMax           = glGetUniformLocation(compositorShader, "altMax")
	uComp.altFalloffLo     = glGetUniformLocation(compositorShader, "altFalloffLo")
	uComp.altFalloffHi     = glGetUniformLocation(compositorShader, "altFalloffHi")
	uComp.slopeEnabled     = glGetUniformLocation(compositorShader, "slopeEnabled")
	uComp.slopeMinCos      = glGetUniformLocation(compositorShader, "slopeMinCos")
	uComp.slopeMaxCos      = glGetUniformLocation(compositorShader, "slopeMaxCos")
	uComp.slopeFalloffLo   = glGetUniformLocation(compositorShader, "slopeFalloffLo")
	uComp.slopeFalloffHi   = glGetUniformLocation(compositorShader, "slopeFalloffHi")
	uComp.handPaintEnabled = glGetUniformLocation(compositorShader, "handPaintEnabled")
	uComp.useLayerTex      = glGetUniformLocation(compositorShader, "useLayerTex")
	uComp.tileScale        = glGetUniformLocation(compositorShader, "tileScale")
	uComp.hydroEnabled     = glGetUniformLocation(compositorShader, "hydroEnabled")
	uComp.hydroStrength    = glGetUniformLocation(compositorShader, "hydroStrength")
	uComp.hydroFalloffLo   = glGetUniformLocation(compositorShader, "hydroFalloffLo")
	uComp.hydroFalloffHi   = glGetUniformLocation(compositorShader, "hydroFalloffHi")
	uComp.thermoEnabled    = glGetUniformLocation(compositorShader, "thermoEnabled")
	uComp.thermoAngle      = glGetUniformLocation(compositorShader, "thermoAngle")
	uComp.thermoFalloff    = glGetUniformLocation(compositorShader, "thermoFalloff")

	stampShader = glCreateShader({
		vertex = VERT_SRC, fragment = injectFractal(STAMP_FRAG_SRC),
		uniformInt = { srcMask = 0, layerTex = 1, normalTex = 2, roughTex = 3 },
	})
	if not stampShader then
		Echo("[Diffuse Painter] stamp shader failed: " .. tostring(gl.GetShaderLog())); return false
	end
	uStamp.squareOrigin  = glGetUniformLocation(stampShader, "squareOrigin")
	uStamp.squareSize    = glGetUniformLocation(stampShader, "squareSize")
	uStamp.brushPos      = glGetUniformLocation(stampShader, "brushPos")
	uStamp.brushRadius   = glGetUniformLocation(stampShader, "brushRadius")
	uStamp.brushStrength = glGetUniformLocation(stampShader, "brushStrength")
	uStamp.brushCurve    = glGetUniformLocation(stampShader, "brushCurve")
	uStamp.brushErase    = glGetUniformLocation(stampShader, "brushErase")
	uStamp.useLayerTex   = glGetUniformLocation(stampShader, "useLayerTex")
	uStamp.tileScale     = glGetUniformLocation(stampShader, "tileScale")
	uStamp.layerColor    = glGetUniformLocation(stampShader, "layerColor")
	uStamp.useNormalTex  = glGetUniformLocation(stampShader, "useNormalTex")
	uStamp.useRoughTex   = glGetUniformLocation(stampShader, "useRoughTex")
	uStamp.pbrStrength   = glGetUniformLocation(stampShader, "pbrStrength")
	uStamp.fractalAmount = glGetUniformLocation(stampShader, "fractalAmount")
	uStamp.fractalFreq   = glGetUniformLocation(stampShader, "fractalFreq")

	copyShader = glCreateShader({
		vertex = VERT_SRC, fragment = COPY_FRAG_SRC,
		uniformInt = { tex0 = 0 },
	})
	if not copyShader then
		Echo("[Diffuse Painter] copy shader failed: " .. tostring(gl.GetShaderLog())); return false
	end

	channelStampShader = glCreateShader({
		vertex = VERT_SRC, fragment = injectFractal(CHANNEL_STAMP_FRAG_SRC),
		uniformInt = { dstTex = 0, layerTex = 1, normalTex = 2, roughTex = 3 },
	})
	if not channelStampShader then
		Echo("[Diffuse Painter] channel stamp shader failed: " .. tostring(gl.GetShaderLog())); return false
	end
	for _, name in ipairs({
		"mapSize", "brushPos", "brushRadius", "brushStrength", "brushCurve",
		"brushErase", "channelMode", "useLayerTex", "useNormalTex", "useRoughTex",
		"tileScale", "layerColor", "glowStrength", "specIntensity",
		"fractalAmount", "fractalFreq", "dstUvOffset", "dstUvScale",
	}) do
		uChan[name] = glGetUniformLocation(channelStampShader, name)
	end

	return true
end

local function destroyShaders()
	if compositorShader   then glDeleteShader(compositorShader);   compositorShader   = nil end
	if stampShader        then glDeleteShader(stampShader);        stampShader        = nil end
	if copyShader         then glDeleteShader(copyShader);         copyShader         = nil end
	if channelStampShader then glDeleteShader(channelStampShader); channelStampShader = nil end
end

-- ============================================================================
-- Square texture allocation + seeding
-- ============================================================================
local function allocateSquare(s)
	if s.seedTex and s.compositeTex then return true end
	-- A square that already failed to seed stays failed — callers poll this every
	-- stroke, so without this guard one bad square spams the log indefinitely.
	if s.allocFailed then return false end

	local seedTex = glCreateTexture(TILE_PX, TILE_PX, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = false,
		format = GL.RGBA8,
	})
	if not seedTex then
		Echo("[Diffuse Painter] failed to create seed tex for square " .. s.sx .. "," .. s.sy)
		s.allocFailed = true
		return false
	end

	-- Ask engine to copy its current diffuse for this square into the seed tex
	local ok = GetMapSquareTextureFn(s.sx, s.sy, 0, seedTex, 0)
	if not ok then
		Echo("[Diffuse Painter] GetMapSquareTexture failed for " .. s.sx .. "," .. s.sy .. " (seeding disabled for this square)")
		glDeleteTexture(seedTex)
		s.allocFailed = true
		return false
	end

	local compositeTex = glCreateTexture(TILE_PX, TILE_PX, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL.RGBA8,
	})
	if not compositeTex then
		glDeleteTexture(seedTex)
		Echo("[Diffuse Painter] failed to create composite tex for " .. s.sx .. "," .. s.sy)
		return false
	end

	-- Initialize composite = seed (so unpainted look identical to engine)
	glRenderToTexture(compositeTex, function()
		glBlending(false)
		glUseShader(copyShader)
		glTexture(0, seedTex)
		glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		glTexture(0, false)
		glUseShader(0)
		glBlending(true)
	end)

	s.seedTex = seedTex
	s.compositeTex = compositeTex
	s.dirty = true
	return true
end

local function bindSquare(s)
	if s.bound or not s.compositeTex then return end
	local ok = SetMapSquareTexture(s.sx, s.sy, s.compositeTex)
	if ok then
		s.bound = true
	else
		Echo("[Diffuse Painter] SetMapSquareTexture failed for " .. s.sx .. "," .. s.sy)
	end
end

local function unbindAllSquares()
	for _, s in pairs(squares) do
		if s.bound then
			SetMapSquareTexture(s.sx, s.sy, "")
			s.bound = false
		end
	end
end

local function freeSquare(s)
	if s.bound then
		SetMapSquareTexture(s.sx, s.sy, "")
		s.bound = false
	end
	if s.compositeTex then glDeleteTexture(s.compositeTex); s.compositeTex = nil end
	if s.seedTex      then glDeleteTexture(s.seedTex);      s.seedTex      = nil end
end

-- ============================================================================
-- Compositor pass — bakes one square from seed through all enabled layers
-- ============================================================================
local function bakeSquare(s)
	if not s or not s.compositeTex or not s.seedTex then return end
	if not compositorShader then return end

	-- Start by copying seed -> composite
	glRenderToTexture(s.compositeTex, function()
		glBlending(false)
		glUseShader(copyShader)
		glTexture(0, s.seedTex)
		glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		glTexture(0, false)
		glUseShader(0)
		glBlending(true)
	end)

	-- Ping-pong buffer: render composite -> temp using compositor, then copy back.
	-- One temp per square per bake. Cheap (1024^2 RGBA8 ~4MB live).
	local key = squareKey(s.sx, s.sy)
	local squareOriginX = s.sx * SQUARE_SIZE_ELMOS
	local squareOriginZ = s.sy * SQUARE_SIZE_ELMOS

	for li = 1, #layers do
		local layer = layers[li]
		if layer.enabled and (layer.opacity or 0) > 0.001 then
			local maskTex = nil
			if layer.handPaintEnabled then
				maskTex = ensureLayerMaskTex(layer.id, key)
			end

			local tempTex = getScratchTex(TILE_PX)
			if tempTex then
				glRenderToTexture(tempTex, function()
					glBlending(false)
					glUseShader(compositorShader)
					glTexture(0, s.compositeTex)
					if maskTex then glTexture(1, maskTex) else glTexture(1, "$heightmap") end
					glTexture(2, "$heightmap")
					local useTex = false
					if layer.texturePath and layer.texturePath ~= "" then
						local ok = pcall(glTexture, 3, layer.texturePath)
						useTex = ok and true or false
					end
					if not useTex then glTexture(3, "$heightmap") end
					glUniformInt(uComp.useLayerTex, useTex and 1 or 0)
					glUniform(uComp.tileScale, layer.tileScale or 384)

					glUniform(uComp.squareOrigin, squareOriginX, squareOriginZ)
					glUniform(uComp.squareSize, SQUARE_SIZE_ELMOS, SQUARE_SIZE_ELMOS)
					glUniform(uComp.mapSize, mapSizeX, mapSizeZ)
					glUniform(uComp.layerColor, layer.color[1], layer.color[2], layer.color[3])
					glUniform(uComp.layerOpacity, layer.opacity)
					local blendModeIdx = ({ normal=0, multiply=1, screen=2, overlay=3,
					                        softlight=4, colordodge=5, hardlight=6, difference=7 })[layer.blend or "normal"] or 0
					glUniformInt(uComp.blendMode, blendModeIdx)
					glUniformInt(uComp.altEnabled, layer.altEnabled and 1 or 0)
					glUniform(uComp.altMin, layer.altMin)
					glUniform(uComp.altMax, layer.altMax)
					glUniform(uComp.altFalloffLo, layer.altFalloffLo)
					glUniform(uComp.altFalloffHi, layer.altFalloffHi)
					glUniformInt(uComp.slopeEnabled, layer.slopeEnabled and 1 or 0)
					-- slope params: layer.slopeMin/Max are degrees; convert to cos.
					-- A "small angle" (flat) has large cos; "large angle" (steep) has small cos.
					-- Layer says "apply between slopeMin..slopeMax degrees", so in cos space
					-- the valid band is [cos(slopeMax), cos(slopeMin)].
					local cosLo = cos(layer.slopeMax * pi / 180)
					local cosHi = cos(layer.slopeMin * pi / 180)
					glUniform(uComp.slopeMinCos, cosLo)
					glUniform(uComp.slopeMaxCos, cosHi)
					-- Falloff in cos units derived from degree falloff at the band edges
					local fLo = abs(cos((layer.slopeMax - (layer.slopeFalloffLo or 0)) * pi / 180) - cosLo)
					local fHi = abs(cos((layer.slopeMin + (layer.slopeFalloffHi or 0)) * pi / 180) - cosHi)
					glUniform(uComp.slopeFalloffLo, fLo)
					glUniform(uComp.slopeFalloffHi, fHi)
					glUniformInt(uComp.handPaintEnabled, (layer.handPaintEnabled and maskTex) and 1 or 0)
					-- Hydro erosion mask
					glUniformInt(uComp.hydroEnabled, layer.hydroEnabled and 1 or 0)
					glUniform(uComp.hydroStrength, layer.hydroStrength or 0.02)
					glUniform(uComp.hydroFalloffLo, layer.hydroFalloffLo or 0.1)
					glUniform(uComp.hydroFalloffHi, layer.hydroFalloffHi or 0.6)
					-- Thermo erosion mask
					glUniformInt(uComp.thermoEnabled, layer.thermoEnabled and 1 or 0)
					glUniform(uComp.thermoAngle, layer.thermoAngle or 30.0)
					glUniform(uComp.thermoFalloff, layer.thermoFalloff or 8.0)

					glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)

					glTexture(3, false); glTexture(2, false); glTexture(1, false); glTexture(0, false)
					glUseShader(0)
					glBlending(true)
				end)

				-- Copy temp back into composite
				glRenderToTexture(s.compositeTex, function()
					glBlending(false)
					glUseShader(copyShader)
					glTexture(0, tempTex)
					glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
					glTexture(0, false)
					glUseShader(0)
					glBlending(true)
				end)
			end
		end
	end

	s.dirty = false
	if not s.bound then bindSquare(s) end
end

-- ============================================================================
-- Brush: stamp into active layer mask for all affected squares
-- ============================================================================
local function affectedSquares(wx, wz, r)
	local out = {}
	local sx0 = floor((wx - r) / SQUARE_SIZE_ELMOS)
	local sx1 = floor((wx + r) / SQUARE_SIZE_ELMOS)
	local sy0 = floor((wz - r) / SQUARE_SIZE_ELMOS)
	local sy1 = floor((wz + r) / SQUARE_SIZE_ELMOS)
	for sx = sx0, sx1 do
		for sy = sy0, sy1 do
			if sx >= 0 and sx < numSqX and sy >= 0 and sy < numSqZ then
				out[#out + 1] = { sx, sy }
			end
		end
	end
	return out
end

local function executeStroke(wx, wz, layerId, erase)
	if not stampShader then return end
	local layer = findLayer(layerId)
	if not layer then return end
	-- Force hand-paint to be considered enabled for the duration of this layer
	-- if the brush is being used (otherwise stamping has no visible effect).
	layer.handPaintEnabled = true

	local effR, effS = getEffectiveBrush()
	local affected = affectedSquares(wx, wz, effR)
	for i = 1, #affected do
		local sx, sy = affected[i][1], affected[i][2]
		local s = getOrAllocSquare(sx, sy)
		if s then
			if not s.seedTex then allocateSquare(s) end
			local key = squareKey(sx, sy)
			-- Snapshot the pre-stroke mask before ensureLayerMaskTex can create it
			-- (a nil here records "mask did not exist" — undo will clear it).
			snapshotMaskForStroke(layerId, key, masks[layerId] and masks[layerId][key])
			local maskTex = ensureLayerMaskTex(layerId, key)
			if maskTex then
				-- Ping-pong stamp: write to temp, copy back
				local tempMask = getScratchTex(MASK_PX)
				if tempMask then
					local squareOriginX = sx * SQUARE_SIZE_ELMOS
					local squareOriginZ = sy * SQUARE_SIZE_ELMOS
					-- Bind material textures to units 1/2/3 with safe fallbacks.
					local useTex = false
					if layer.texturePath and layer.texturePath ~= "" then
						local ok = pcall(glTexture, 1, layer.texturePath)
						useTex = ok and true or false
					end
					if not useTex then glTexture(1, "$heightmap") end
					local useNormal = false
					if layer.normalPath and layer.normalPath ~= "" then
						local okN = pcall(glTexture, 2, layer.normalPath)
						useNormal = okN and true or false
					end
					if not useNormal then glTexture(2, "$heightmap") end
					local useRough = false
					if layer.roughPath and layer.roughPath ~= "" then
						local okR = pcall(glTexture, 3, layer.roughPath)
						useRough = okR and true or false
					end
					if not useRough then glTexture(3, "$heightmap") end
					if not layer._pbrLogged then
						layer._pbrLogged = true
						Echo(string.format(
							"[Diffuse Painter] layer '%s' PBR: diff=%s normal=%s(%s) rough=%s(%s)",
							tostring(layer.name), tostring(useTex),
							tostring(useNormal), tostring(layer.normalPath or "-"),
							tostring(useRough),  tostring(layer.roughPath  or "-")))
					end
					glRenderToTexture(tempMask, function()
						glBlending(false)
						glUseShader(stampShader)
						glTexture(0, maskTex)
						glUniform(uStamp.squareOrigin, squareOriginX, squareOriginZ)
						glUniform(uStamp.squareSize, SQUARE_SIZE_ELMOS, SQUARE_SIZE_ELMOS)
						glUniform(uStamp.brushPos, wx, wz)
						glUniform(uStamp.brushRadius, effR)
						glUniform(uStamp.brushStrength, effS)
						glUniform(uStamp.brushCurve, brushCurve)
						glUniformInt(uStamp.brushErase, erase and 1 or 0)
						glUniformInt(uStamp.useLayerTex, useTex and 1 or 0)
						glUniformInt(uStamp.useNormalTex, useNormal and 1 or 0)
						glUniformInt(uStamp.useRoughTex, useRough and 1 or 0)
						glUniform(uStamp.tileScale, layer.tileScale or 384)
						glUniform(uStamp.pbrStrength, layer.pbrStrength or 1.0)
						glUniform(uStamp.layerColor, layer.color[1], layer.color[2], layer.color[3])
						glUniform(uStamp.fractalAmount, brushFractalAmount)
						glUniform(uStamp.fractalFreq,   brushFractalFreq)
						glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
						glTexture(0, false)
						glUseShader(0)
						glBlending(true)
					end)
					glTexture(3, false)
					glTexture(2, false)
					glTexture(1, false)
					-- Copy back
					glRenderToTexture(maskTex, function()
						glBlending(false)
						glUseShader(copyShader)
						glTexture(0, tempMask)
						glTexRect(-1, -1, 1, 1, 0, 0, 1, 1)
						glTexture(0, false)
						glUseShader(0)
						glBlending(true)
					end)
				end
				dirtySquares[key] = true
			end
		end
	end

	-- Mirror the stroke into the enabled global shading channels (normals /
	-- specular / emission) so one gesture paints the whole material.
	stampChannels(wx, wz, layer, erase, effR, effS)

	-- Grass attach: plant/remove grass along the stroke for layers that carry
	-- a grass density. Plain CPU patch writes (no GL), undo-tracked per patch.
	paintGrassAttach(wx, wz, layer, erase, effR, effS)
end

-- ============================================================================
-- Layer management
-- ============================================================================
local function defaultLayer(name, r, g, b)
	return {
		id = 0, name = name or "Layer",
		enabled = true, opacity = 1.0,
		color = { r or 1, g or 1, b or 1 }, blend = "normal",
		altEnabled = false, altMin = 0, altMax = 200, altFalloffLo = 10, altFalloffHi = 10,
		slopeEnabled = false, slopeMin = 0, slopeMax = 30, slopeFalloffLo = 3, slopeFalloffHi = 3,
		handPaintEnabled = false,
		texturePath = nil, tileScale = 384,
		-- Hydro erosion: paint preferentially in concave valleys / flow channels
		hydroEnabled = false, hydroStrength = 0.02,
		hydroFalloffLo = 0.1, hydroFalloffHi = 0.6,
		-- Thermo erosion: paint at slope transitions near the repose angle
		thermoEnabled = false, thermoAngle = 30.0, thermoFalloff = 8.0,
		-- Emission channel: layerColor * glowStrength is painted into
		-- $ssmf_emission when the channel is enabled
		glowStrength = 0.0,
		-- Grass attach: strokes also plant grass at this density (0 = off).
		-- grassDensityCustom marks a user override that material auto-defaults
		-- must not clobber.
		grassDensity = 0.0, grassDensityCustom = false,
	}
end

local function addLayer(layerDef)
	if #layers >= MAX_LAYERS then
		Echo("[Diffuse Painter] layer cap reached (" .. MAX_LAYERS .. ")")
		return nil
	end
	local layer = defaultLayer()
	if layerDef then
		for k, v in pairs(layerDef) do layer[k] = v end
	end
	layer.id = nextLayerId
	nextLayerId = nextLayerId + 1
	layers[#layers + 1] = layer
	if not activeLayerId then activeLayerId = layer.id end
	pendingFullBake = true
	return layer.id
end

local function removeLayer(id)
	local _, idx = findLayer(id)
	if not idx then return end
	table.remove(layers, idx)
	-- Free that layer's masks
	if masks[id] then
		for _, maskTex in pairs(masks[id]) do glDeleteTexture(maskTex) end
		masks[id] = nil
	end
	purgeLayerFromHistory(id)
	if activeLayerId == id then activeLayerId = layers[1] and layers[1].id or nil end
	pendingFullBake = true
end

local function setLayerParam(id, key, val)
	local layer = findLayer(id)
	if not layer then return end
	layer[key] = val
	pendingFullBake = true
end

local function findSibling(diffPath, channel)
	-- Replace `_diff_` with `_<channel>_` and probe likely extensions.
	local exts
	if channel == "nor_gl" then exts = { "exr", "jpg", "png" }
	elseif channel == "rough" then exts = { "jpg", "exr", "png" }
	elseif channel == "disp" then exts = { "png", "exr", "jpg" }
	else exts = { "jpg", "png", "exr" } end
	local stem = diffPath:gsub("_diff_(%d+k)%.jpg$", "_" .. channel .. "_%1.")
	for i = 1, #exts do
		local candidate = stem .. exts[i]
		if VFS.FileExists and VFS.FileExists(candidate, VFS.RAW_FIRST) then
			return candidate
		end
	end
	return nil
end

local function scanMaterialLibrary()
	materialLibrary = {}
	-- Write-dir asset library (not committed to the game repo). VFS.RAW_FIRST
	-- below resolves it from <datadir>/Terraform Brush/textures/.
	local ROOT = "Terraform Brush/textures/"
	local byKey = {} -- prefer highest-resolution diffuse per material key (use the 8K)

	-- Diffuse textures may sit at any depth under ROOT (the source packs nest
	-- them in `<pack>.blend/textures/textures/`), so walk the tree explicitly
	-- rather than relying on a recursive DirList flag that not every engine
	-- build honours. Bounded depth guards against symlink/loop surprises.
	local function consume(files)
		for _, f in ipairs(files or {}) do
			-- Windows write-dir listings come back with backslashes; strip both
			-- separators or the "basename" keeps the whole path and every material
			-- name/layer label becomes a full path string.
			local base = f:gsub("^.*[/\\]", "")
			-- Parse: <name>_diff_<NK>.jpg
			local mat, res = base:match("^(.-)_diff_(%d+)k%.jpg$")
			if mat and res then
				local resK = tonumber(res) or 8
				local prev = byKey[mat]
				if (not prev) or resK > prev.resK then
					byKey[mat] = {
						key = mat, name = mat:gsub("_", " "), path = f, resK = resK,
						normalPath = findSibling(f, "nor_gl"),
						roughPath  = findSibling(f, "rough"),
						dispPath   = findSibling(f, "disp"),
					}
				end
			end
		end
	end

	local function walk(dir, depth)
		if depth > 8 then return end
		consume(VFS.DirList and VFS.DirList(dir, "*_diff_*k.jpg", VFS.RAW_FIRST) or {})
		for _, sub in ipairs((VFS.SubDirs and VFS.SubDirs(dir, "*", VFS.RAW_FIRST)) or {}) do
			walk(sub, depth + 1)
		end
	end
	walk(ROOT, 0)

	for _, v in pairs(byKey) do materialLibrary[#materialLibrary + 1] = v end
	table.sort(materialLibrary, function(a, b) return a.key < b.key end)
end

local function findMaterialByPath(p)
	if not p then return nil end
	for i = 1, #materialLibrary do
		if materialLibrary[i].path == p then return materialLibrary[i] end
	end
	return nil
end

local function setLayerTexture(id, path, tileScale, name)
	local layer = findLayer(id)
	if not layer then return end
	if path == "" then path = nil end
	layer.texturePath = path
	if tileScale then layer.tileScale = tileScale end
	-- Look up PBR siblings from the material library for the stamp shader.
	local mat = findMaterialByPath(path)
	layer.normalPath = mat and mat.normalPath or nil
	layer.roughPath  = mat and mat.roughPath  or nil
	layer.dispPath   = mat and mat.dispPath   or nil
	-- Auto-name the layer after the material when we have one. Keeps the
	-- LAYERS list readable ("snow 01", "rock face 03") instead of generic
	-- "Layer N" placeholders. User-renamed layers are preserved via the
	-- `customName` flag (set if the caller renames explicitly later).
	if name and not layer.customName then
		layer.name = name
	end
	-- Grass-category materials default to planting grass; explicit user
	-- settings survive material swaps.
	if not layer.grassDensityCustom then
		layer.grassDensity = defaultGrassDensityFor(name or path)
	end
	-- Hand-paint layers bake material at stroke time, so changing the active
	-- material must NOT rebake the canvas — only future strokes use the new
	-- texture. Procedural layers do sample texturePath in the compositor and
	-- therefore need a re-bake.
	if not layer.handPaintEnabled then
		pendingFullBake = true
	end
end

local function addLayerFromMaterial(path, name)
	local id = addLayer({
		name = name or "Layer",
		color = { 1.0, 1.0, 1.0 },
		handPaintEnabled = true,
		enabled = true,
		opacity = 1.0,
	})
	if id then
		-- Route through setLayerTexture so PBR sibling pairing, auto-naming and
		-- the grass-density default all apply (assigning texturePath directly
		-- would skip them).
		setLayerTexture(id, path, nil, name)
		activeLayerId = id
	end
	return id
end

-- ============================================================================
-- Activation
-- ============================================================================
local function activate()
	if active then return end
	if not compositorShader then
		if not createShaders() then
			Echo("[Diffuse Painter] activation aborted: shader creation failed")
			return
		end
	end
	active = true
	pendingInit = true
	Echo("[Diffuse Painter] active. LMB paint, RMB erase. /diffusepaint to toggle.")
end

local function deactivate()
	if not active then return end
	active = false
	leftMouseHeld = false
	lastPaintX, lastPaintZ = nil, nil
	-- Seal any in-flight drag so its snapshot textures land in the undo stack
	-- instead of leaking (DrawWorld still processes queued strokes + the finish
	-- flag while inactive).
	if strokeSnap then pendingStrokeFinish = true end
end

-- ============================================================================
-- Widget callbacks
-- ============================================================================
function widget:Initialize()
	mapSizeX = Game.mapSizeX
	mapSizeZ = Game.mapSizeZ
	numSqX = floor(mapSizeX / SQUARE_SIZE_ELMOS)
	numSqZ = floor(mapSizeZ / SQUARE_SIZE_ELMOS)
	if numSqX <= 0 or numSqZ <= 0 then
		Echo("[Diffuse Painter] map too small (no full SMF squares); disabling")
		widgetHandler:RemoveWidget()
		return
	end

	-- Single empty handpaint layer to start. User adds more by clicking
	-- materials in the UI (each material click on an unassigned active layer
	-- assigns it; otherwise spawns a new layer with that material).
	local paintId = addLayer({ name = "Layer 1", color = { 1.0, 1.0, 1.0 },
	           handPaintEnabled = true, enabled = true, opacity = 1.0 })
	activeLayerId = paintId

	scanMaterialLibrary()

	widgetHandler:AddAction("diffusepaint", function()
		if active then deactivate() else activate() end
	end, nil, "t")
	widgetHandler:AddAction("diffusepaintoff", deactivate, nil, "t")
	widgetHandler:AddAction("diffusepaintbake", function()
		if not active then activate() end
		pendingFullCover = true
	end, nil, "t")

	-- Dump every currently-composited square texture to disk as PNG so the
	-- user can repackage them into a real SMF map (engine API only lets us
	-- override diffuse per square at runtime; baked PBR shading is in RGB).
	local function exportSquares(folder)
		folder = folder or "tf_diffuse_export"
		local count = 0
		for _, s in pairs(squares) do
			if s and s.compositeTex then
				local fname = folder .. "/sq_" .. s.sx .. "_" .. s.sy .. ".png"
				local ok = pcall(gl.SaveImage, s.compositeTex, fname)
				if ok then count = count + 1 end
			end
		end
		Echo("[Diffuse Painter] exported " .. count .. " square textures to " ..
			tostring(Spring.GetConfigString and Spring.GetConfigString("WriteDir", "") or "") ..
			"/" .. folder .. "/")
		return count
	end
	widgetHandler:AddAction("diffusepaintexport", function() exportSquares() end, nil, "t")
	widgetHandler:AddAction("diffusepaintundo", function()
		if active then pendingHistoryOps[#pendingHistoryOps + 1] = "undo" end
	end, nil, "t")
	widgetHandler:AddAction("diffusepaintredo", function()
		if active then pendingHistoryOps[#pendingHistoryOps + 1] = "redo" end
	end, nil, "t")

	WG.DiffusePainter = {
		isActive       = function() return active end,
		-- Snapshot of everything the UI needs, mirroring WG.TerraformBrush.getState.
		getState       = function()
			return {
				active        = active,
				radius        = brushRadius,
				strength      = brushStrength,
				curve         = brushCurve,
				erase         = eraseMode,
				fractalAmount = brushFractalAmount,
				fractalFreq   = brushFractalFreq,
				layers        = layers,
				activeLayerId = activeLayerId,
				historyIndex  = #undoStack,
				historyMax    = #undoStack + #redoStack,
				channelNormals  = channelsEnabled.normals,
				channelSpecular = channelsEnabled.specular,
				channelEmission = channelsEnabled.emission,
				specIntensity   = specIntensity,
				grassAttach     = grassAttachEnabled,
			}
		end,
		undo           = function() pendingHistoryOps[#pendingHistoryOps + 1] = "undo" end,
		redo           = function() pendingHistoryOps[#pendingHistoryOps + 1] = "redo" end,
		undoToIndex    = function(idx) pendingHistoryOps[#pendingHistoryOps + 1] = tonumber(idx) or 0 end,
		setChannelEnabled = setChannelEnabled,
		setSpecIntensity  = function(v) specIntensity = max(0.0, min(1.0, v or 0.25)) end,
		setLayerGlow      = function(id, v)
			local layer = findLayer(id)
			if layer then layer.glowStrength = max(0.0, min(1.0, v or 0)) end
		end,
		setGrassAttach    = function(on) grassAttachEnabled = on and true or false end,
		setLayerGrassDensity = function(id, v)
			local layer = findLayer(id)
			if not layer then return end
			layer.grassDensity = max(0.0, min(1.0, v or 0))
			layer.grassDensityCustom = true
		end,
		activate       = activate,
		deactivate     = deactivate,
		getLayers      = function() return layers end,
		getActiveLayerId = function() return activeLayerId end,
		setActiveLayer = function(id) if findLayer(id) then activeLayerId = id end end,
		addLayer       = addLayer,
		removeLayer    = removeLayer,
		setLayerParam  = setLayerParam,
		setLayerTexture = setLayerTexture,
		addLayerFromMaterial = addLayerFromMaterial,
		getMaterialLibrary = function() return materialLibrary end,
		rescanMaterialLibrary = scanMaterialLibrary,
		bakeAll        = function() pendingFullCover = true end,
		exportSquares  = exportSquares,
		getBrush       = function() return brushRadius, brushStrength, brushCurve, eraseMode end,
		setRadius        = function(r) brushRadius = max(MIN_RADIUS, min(MAX_RADIUS, floor(r))) end,
		setStrength      = function(v) brushStrength = max(MIN_STRENGTH, min(MAX_STRENGTH, v)) end,
		setCurve         = function(v) brushCurve = max(MIN_CURVE, min(MAX_CURVE, v)) end,
		setErase         = function(b) eraseMode = b and true or false end,
		setFractal       = function(amount, freq)
			if amount ~= nil then brushFractalAmount = max(MIN_FRACTAL, min(MAX_FRACTAL, amount)) end
			if freq   ~= nil then brushFractalFreq   = max(MIN_FRACTAL_FREQ, min(MAX_FRACTAL_FREQ, freq)) end
		end,
		getFractal       = function() return brushFractalAmount, brushFractalFreq end,
		setLayerBlend    = function(id, mode)
			local layer = findLayer(id)
			if layer then layer.blend = mode or "normal"; pendingFullBake = true end
		end,
		setLayerHydro    = function(id, enabled, strength, fallLo, fallHi)
			local layer = findLayer(id)
			if not layer then return end
			if enabled   ~= nil then layer.hydroEnabled   = enabled and true or false end
			if strength  ~= nil then layer.hydroStrength  = max(0.001, strength) end
			if fallLo    ~= nil then layer.hydroFalloffLo = max(0.0, fallLo) end
			if fallHi    ~= nil then layer.hydroFalloffHi = max(0.0, fallHi) end
			pendingFullBake = true
		end,
		setLayerThermo   = function(id, enabled, angle, falloff)
			local layer = findLayer(id)
			if not layer then return end
			if enabled ~= nil then layer.thermoEnabled = enabled and true or false end
			if angle   ~= nil then layer.thermoAngle   = max(0.0, min(85.0, angle)) end
			if falloff ~= nil then layer.thermoFalloff = max(0.5, min(45.0, falloff)) end
			pendingFullBake = true
		end,
		resetSquare    = function(wx, wz)
			local sx, sy = floor(wx / SQUARE_SIZE_ELMOS), floor(wz / SQUARE_SIZE_ELMOS)
			local k = squareKey(sx, sy)
			for layerId, layerMasks in pairs(masks) do
				local maskTex = layerMasks[k]
				if maskTex then clearMaskTex(maskTex) end
			end
			-- Snapshots of this square are stale now; undoing one would restore
			-- paint onto a square the user explicitly cleared.
			clearHistory()
			dirtySquares[k] = true
		end,
		resetAll       = function()
			for layerId, layerMasks in pairs(masks) do
				for k, maskTex in pairs(layerMasks) do
					clearMaskTex(maskTex)
				end
			end
			clearHistory()
			pendingChannelReseed = true
			pendingFullBake = true
		end,
	}
end

function widget:Shutdown()
	unbindAllSquares()
	for _, ch in pairs(channels) do
		unbindChannel(ch)
		if ch.tex then glDeleteTexture(ch.tex) end
	end
	channels = {}
	for _, s in pairs(squares) do freeSquare(s) end
	squares = {}
	for _, layerMasks in pairs(masks) do
		for _, maskTex in pairs(layerMasks) do glDeleteTexture(maskTex) end
	end
	masks = {}
	for _, tex in pairs(scratchTex) do glDeleteTexture(tex) end
	scratchTex = {}
	for i = 1, #undoStack do freeHistoryEntry(undoStack[i]) end
	undoStack = {}
	for i = 1, #redoStack do freeHistoryEntry(redoStack[i]) end
	redoStack = {}
	if strokeSnap then
		freeHistoryEntry(strokeSnap.items)
		strokeSnap = nil
	end
	destroyShaders()
	widgetHandler:RemoveAction("diffusepaint")
	widgetHandler:RemoveAction("diffusepaintoff")
	widgetHandler:RemoveAction("diffusepaintbake")
	widgetHandler:RemoveAction("diffusepaintexport")
	widgetHandler:RemoveAction("diffusepaintundo")
	widgetHandler:RemoveAction("diffusepaintredo")
	WG.DiffusePainter = nil
end

function widget:MousePress(mx, my, button)
	if not active then return false end
	if button ~= 1 and button ~= 3 then return false end
	-- Defer to common tf instruments
	local tfBrush = WG.TerraformBrush
	if tfBrush and tfBrush.getState then
		local tbState = tfBrush.getState()
		if tbState and (tbState.measureActive or tbState.heightSamplingMode) then return false end
	end
	leftMouseHeld = true
	eraseMode = (button == 3)
	-- A second button pressed mid-drag must seal the in-flight snapshot first,
	-- or its already-captured textures leak and that drag's undo entry is lost.
	if strokeSnap then finishStrokeSnapshot() end
	strokeSnap = { items = {}, seen = {} }
	grassLastX, grassLastZ = nil, nil
	local wx, wz = getWorldMousePosition()
	if wx and activeLayerId then
		pendingPaintStrokes[#pendingPaintStrokes + 1] = { wx, wz, activeLayerId, eraseMode }
		lastPaintX, lastPaintZ = wx, wz
	end
	return true
end

function widget:MouseRelease(mx, my, button)
	if not active then return false end
	if button == 1 or button == 3 then
		leftMouseHeld = false
		lastPaintX, lastPaintZ = nil, nil
		-- Queued strokes for this drag may not have executed yet (they run in
		-- DrawWorld); defer sealing the undo entry until they have.
		if #pendingPaintStrokes == 0 then
			finishStrokeSnapshot()
		else
			pendingStrokeFinish = true
		end
		return true
	end
	return false
end

function widget:MouseMove(mx, my, dx, dy, button)
	if not active or not leftMouseHeld then return false end
	local wx, wz = getWorldMousePosition()
	if not wx or not activeLayerId then return false end
	local effR = getEffectiveBrush()
	local spacing = max(effR * 0.3, 8)
	if lastPaintX and lastPaintZ then
		local ddx, ddz = wx - lastPaintX, wz - lastPaintZ
		local dist = sqrt(ddx * ddx + ddz * ddz)
		if dist >= spacing then
			local steps = floor(dist / spacing)
			for i = 1, steps do
				local t = i / steps
				pendingPaintStrokes[#pendingPaintStrokes + 1] = {
					lastPaintX + ddx * t, lastPaintZ + ddz * t, activeLayerId, eraseMode
				}
			end
			lastPaintX, lastPaintZ = wx, wz
		end
	else
		pendingPaintStrokes[#pendingPaintStrokes + 1] = { wx, wz, activeLayerId, eraseMode }
		lastPaintX, lastPaintZ = wx, wz
	end
	return false
end

function widget:MouseWheel(up, value)
	if not active then return false end
	local alt, ctrl, _, shift = Spring.GetModKeyState()
	if ctrl then
		brushRadius = max(MIN_RADIUS, min(MAX_RADIUS, brushRadius + (up and RADIUS_STEP or -RADIUS_STEP)))
		return true
	elseif shift then
		brushCurve = max(MIN_CURVE, min(MAX_CURVE, brushCurve + (up and CURVE_STEP or -CURVE_STEP)))
		return true
	elseif alt then
		brushStrength = max(MIN_STRENGTH, min(MAX_STRENGTH, brushStrength + (up and STRENGTH_STEP or -STRENGTH_STEP)))
		return true
	end
	return false
end

function widget:DrawWorld()
	-- Lazy init: NO bulk alloc. Squares are allocated on first paint stroke
	-- (executeStroke) or on explicit /diffusepaintbake (which will allocate
	-- every map square — heavy, opt-in).
	if pendingInit then
		pendingInit = false
	end

	-- Channel enable requests (texture alloc + seed need this GL context).
	-- Must run BEFORE strokes: channelsEnabled flips synchronously in the UI
	-- handler, so a stroke queued the same frame would otherwise pass the
	-- channelApplies check while channels[key] is still nil and skip silently.
	if #pendingChannelEnable > 0 then
		for i = 1, #pendingChannelEnable do
			local key = pendingChannelEnable[i]
			if channelsEnabled[key] then
				local ch = ensureChannel(key)
				if ch then bindChannel(ch) end
			end
		end
		pendingChannelEnable = {}
	end

	-- Strokes
	if #pendingPaintStrokes > 0 then
		for i = 1, #pendingPaintStrokes do
			local stroke = pendingPaintStrokes[i]
			executeStroke(stroke[1], stroke[2], stroke[3], stroke[4])
		end
		pendingPaintStrokes = {}
	end
	if pendingStrokeFinish then
		pendingStrokeFinish = false
		finishStrokeSnapshot()
	end

	-- Undo/redo requests queued from UI/actions (need this GL context)
	if #pendingHistoryOps > 0 then
		runHistoryOps()
	end

	-- Reset-all also reverts channels to their seeded state. Unbind first so
	-- the seed copy reads the map's own texture, not our painted one.
	if pendingChannelReseed then
		pendingChannelReseed = false
		for key, ch in pairs(channels) do
			if ch.tex then
				local wasBound = ch.bound
				unbindChannel(ch)
				seedChannelTex(ch)
				if wasBound and channelsEnabled[key] then bindChannel(ch) end
			end
		end
	end

	-- Full bake = re-bake every ALREADY-allocated square. Cheap for layer
	-- param tweaks; does not allocate new squares.
	if pendingFullBake then
		pendingFullBake = false
		for k, s in pairs(squares) do
			if s.seedTex then dirtySquares[k] = true end
		end
	end

	-- Full coverage = allocate every map square + bake. Heavy; opt-in via
	-- /diffusepaintbake action.
	if pendingFullCover then
		pendingFullCover = false
		for sx = 0, numSqX - 1 do
			for sy = 0, numSqZ - 1 do
				local s = getOrAllocSquare(sx, sy)
				if s and not s.seedTex then allocateSquare(s) end
				if s and s.compositeTex then dirtySquares[squareKey(sx, sy)] = true end
			end
		end
	end

	-- Bake all dirty squares this frame (no rate limit yet)
	local bakedCount = 0
	for k, _ in pairs(dirtySquares) do
		local s = squares[k]
		if s and s.seedTex then bakeSquare(s) end
		dirtySquares[k] = nil
		bakedCount = bakedCount + 1
		if bakedCount >= 16 then break end  -- coarse rate limit per frame
	end

	-- Brush ring
	if active then
		local wx, wz = getWorldMousePosition()
		if wx then
			local groundY = GetGroundHeight(wx, wz)
			local effR = getEffectiveBrush()
			local col = eraseMode and { 1.0, 0.55, 0.1, 0.9 } or { 0.4, 0.85, 1.0, 0.9 }
			glColor(col[1], col[2], col[3], col[4])
			glLineWidth(2.0)
			glDrawGroundCircle(wx, groundY, wz, effR, 64)
			glLineWidth(1.0)
			-- Falloff ring at 50%
			if brushCurve > 0.1 then
				local halfR = effR * (0.5 ^ (1 / brushCurve))
				glColor(col[1], col[2], col[3], 0.35)
				glDrawGroundCircle(wx, groundY, wz, halfR, 64)
			end
		end
	end
end
