local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "IceUI-GL4",
		desc    = "IceUI-GL4 instanced UI render core. Hosts the shared renderer for IceUI widgets.",
		author  = "BAR team",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = -100000,  -- early, so WG.IceUI exists before consumer widgets init
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- IceUI-GL4 host widget
--------------------------------------------------------------------------------
-- This widget owns the single shared GL4 render core and exposes it through
-- WG.IceUI. Consumer widgets (e.g. the new commands menu) do NOT create their
-- own VBO/shader -- they queue elements into the shared renderer and let this
-- host flush them.
--
-- Each frame runs in two phases so that text lands ON TOP of the rectangles:
--   1. draw phase  -- consumers queue rounded-rect instances via WG.IceUI.add
--      ...then the host does ONE instanced draw call (renderer:flush).
--   2. text phase  -- consumers draw their font text, now over the rects.
-- Text can't go through the SDF rect shader, so it must be a separate pass
-- after the flush -- otherwise the rects overpaint it.
--
-- ICONS: this host owns a single shared texture atlas. It scans ICON_DIR at
-- init, packs every image into one atlas, and hands consumers the UV rect of
-- a given image via WG.IceUI.getIconUV(name). One atlas keeps the whole UI a
-- single draw call. Drop icon PNGs into ICON_DIR; no code change needed.
--
-- The actual drawing logic lives in luaui/Include/IceUI/. This widget is just
-- the lifecycle host: create on Initialize, free on Shutdown, expose API.
--------------------------------------------------------------------------------

-- VFS.RAW_FIRST so the include resolves whether IceUI lives in the unpacked
-- working copy (BAR.sdd) or inside a packaged mod archive.
local Core = VFS.Include("luaui/Include/IceUI/core_gl4.lua", nil, VFS.RAW_FIRST)

-- Folder scanned for icon images at init. Put IceUI icon PNGs here.
local ICON_DIR    = "LuaUI/Images/iceui/"
local ATLAS_SIZE  = 2048

-- Two independent renderers, each with its own VBO, so the base layer can stay
-- cached while the overlay layer is rebuilt every frame.
local baseRenderer    -- base layer: normal UI content (cached)
local overlayRenderer -- overlay layer: tooltips etc. (rebuilt every frame)

local drawCallbacks   -- ordered list of { id, fn, text, overlay }
local iconAtlas       -- atlas texture id, or nil if no icons were found
local iconUVs         -- map: lowercase filename -> {u0,v0,u1,v1}
local needsRebuild = true   -- true -> rebuild + re-upload the base VBO
                            -- (the cached-texture FBOs have their OWN per-widget
                            --  `texturesDirty` flag -- see drawCachedTexture)

-- Buildpic LOD-bias shader (see WG.IceUI.drawTexture `sharp`). A mipmapped
-- engine texture drawn plain is only crisp at power-of-two sizes; a negative
-- LOD bias forces a sharper mip so buildpics stay sharp at any size.
local buildpicShader  -- LuaShader, or nil if it failed / no shader support

-- Hover highlight state (animated; driven by shader uniforms, not the VBO).
-- Hover is tracked PER CONSUMER WIDGET, keyed by registerDraw id, so two
-- widgets (commands menu + build menu) each have their own hover and never
-- overwrite each other. Each widget's state:
--   target  : {l,b,r,t} the mouse is over this frame, or nil
--   pressed : true while the button is held on the hovered element
--   slots   : 2 cross-fade slots { rect, fade, press } -- slot 1 fades in,
--             slot 2 takes the previous element to fade out
--   fadeIn / fadeOut / tint / pressTint : timing/strength (per widget style)
-- The shader only has 2 hover slots, so each frame the host picks the 2
-- brightest slots across ALL widgets and sends those.
local hoverByID = {}

--------------------------------------------------------------------------------
-- build clock (drawPie) -- module scope so the triangle-fan callback is a
-- single static function, NOT a closure allocated on every drawPie call.
--------------------------------------------------------------------------------

local PIE_SEGMENTS = 64
local PIE_TWO_PI   = math.pi * 2

-- Intersection of a ray from the rect centre (angle `a`, 12 o'clock = up,
-- clockwise) with the rect border -- a fan of these points fills the rect
-- exactly (no circle spill).
local function rectEdgePoint(cx, cy, hw, hh, a)
	local dx, dy = math.sin(a), math.cos(a)
	local tx = (dx ~= 0) and (hw / math.abs(dx)) or math.huge
	local ty = (dy ~= 0) and (hh / math.abs(dy)) or math.huge
	local t  = math.min(tx, ty)
	return cx + dx * t, cy + dy * t
end

-- The triangle-fan emitter for drawPie. Passed to gl.BeginEnd with its args,
-- so it stays a static function and allocates nothing per call.
local function emitPieFan(cx, cy, hw, hh, progress)
	gl.Vertex(cx, cy)
	local sx, sy = rectEdgePoint(cx, cy, hw, hh, progress * PIE_TWO_PI)
	gl.Vertex(sx, sy)
	local firstSeg = math.ceil(progress * PIE_SEGMENTS)
	for s = firstSeg, PIE_SEGMENTS do
		local px, py = rectEdgePoint(cx, cy, hw, hh,
			(s / PIE_SEGMENTS) * PIE_TWO_PI)
		gl.Vertex(px, py)
	end
end

-- Get (creating if needed) the hover state for a consumer id.
local function hoverState(id)
	local h = hoverByID[id]
	if not h then
		h = {
			target = nil, pressed = false,
			slots = {
				{ rect = nil, fade = 0, press = 0 },
				{ rect = nil, fade = 0, press = 0 },
			},
			fadeIn = 0.10, fadeOut = 0.35, tint = 0.18, pressTint = 0.22,
		}
		hoverByID[id] = h
	end
	return h
end

--------------------------------------------------------------------------------
-- icon atlas
--------------------------------------------------------------------------------

local IMAGE_EXTS = { png = true, dds = true, tga = true, jpg = true, bmp = true }

-- Build the shared icon atlas from every image file in ICON_DIR.
-- Sets `iconAtlas` (texture id) and fills `iconUVs` (name -> uv rect).
-- Safe to call with an empty/missing folder: leaves iconAtlas nil.
local function buildIconAtlas()
	iconUVs = {}

	local files = VFS.DirList(ICON_DIR) or {}
	local images = {}
	for i = 1, #files do
		local ext = files[i]:sub(-3):lower()
		if IMAGE_EXTS[ext] then
			images[#images + 1] = files[i]
		end
	end
	if #images == 0 then
		Spring.Echo("[IceUI-GL4] no icons found in " .. ICON_DIR)
		return
	end

	local atlas = gl.CreateTextureAtlas(ATLAS_SIZE, ATLAS_SIZE, 1)
	for i = 1, #images do
		gl.AddAtlasTexture(atlas, images[i])
	end
	gl.FinalizeTextureAtlas(atlas)

	-- record each image's UV rect, keyed by lowercase basename.
	-- NOTE: gl.GetAtlasTexture returns coords as xXyY = (u0, u1, v0, v1),
	-- NOT (u0, v0, u1, v1). Reorder into the {u0,v0,u1,v1} the shader wants.
	for i = 1, #images do
		local path = images[i]
		local u0, u1, v0, v1 = gl.GetAtlasTexture(atlas, path)
		if u0 then
			local name = path:match("([^/\\]+)$"):lower()
			iconUVs[name] = { u0, v0, u1, v1 }
		end
	end

	iconAtlas = atlas
	Spring.Echo("[IceUI-GL4] icon atlas built: " .. #images .. " images")
end

-- Negative LOD bias for buildpic sampling. -0.75 matches FlowUI; more negative
-- = sharper but more aliasing when heavily downscaled.
local BUILDPIC_LOD_BIAS = -0.75

-- Build the buildpic LOD-bias shader: a fragment-only shader (#version 150
-- compatibility) so gl.TexRect feeds it geometry through the fixed-function
-- pipeline (gl_TexCoord[0] / gl_Color) -- no VBO needed. Pattern from
-- gfx_guishader.lua. Leaves buildpicShader nil on failure (drawTexture then
-- falls back to a plain gl.TexRect).
local function buildBuildpicShader()
	if not gl.LuaShader then return end
	local shader = gl.LuaShader({
		fragment = [[
			#version 150 compatibility
			uniform sampler2D tex0;
			uniform float lodBias;
			void main(void) {
				gl_FragColor = texture(tex0, gl_TexCoord[0].st, lodBias)
					* gl_Color;
			}
		]],
		uniformInt   = { tex0 = 0 },
		uniformFloat = { lodBias = BUILDPIC_LOD_BIAS },
	}, "IceUI-GL4 buildpic shader")

	if not shader:Initialize() then
		Spring.Echo("[IceUI-GL4] buildpic shader failed -- buildpics fall back "
			.. "to plain sampling")
		return
	end
	buildpicShader = shader
end

--------------------------------------------------------------------------------

function widget:Initialize()
	if not gl.CreateShader then
		Spring.Echo("[IceUI-GL4] no shader support, disabling")
		widgetHandler:RemoveWidget()
		return
	end

	baseRenderer    = Core.new()
	overlayRenderer = Core.new()
	if not baseRenderer or not overlayRenderer then
		Spring.Echo("[IceUI-GL4] failed to create render core, disabling")
		widgetHandler:RemoveWidget()
		return
	end

	buildIconAtlas()
	baseRenderer:setAtlas(iconAtlas)
	overlayRenderer:setAtlas(iconAtlas)

	buildBuildpicShader()

	drawCallbacks = {}
	overlayQuads  = {}

	-- Public API
	WG.IceUI = {}

	-- Queue one element into this frame's draw list. See Core:add() for the
	-- shape of `quad`. Must be called from within a registered draw callback.
	-- Goes into the BASE layer (normal UI content).
	WG.IceUI.add = function(quad)
		baseRenderer:add(quad)
	end

	-- Like add(), but queues into the OVERLAY layer -- a separate pass drawn
	-- AFTER all base content of every widget. Use this for tooltips and other
	-- elements that must always sit on top, regardless of widget draw order.
	-- Pushes straight into overlayRenderer (which copies the values out), so
	-- the caller may pass a reused/shared quad table -- nothing is retained.
	WG.IceUI.addOverlay = function(quad)
		overlayRenderer:add(quad)
	end

	-- Register a consumer's per-frame callbacks under `id`. `cb` is a table:
	--   cb.draw          : base draw phase -- queue base rects via WG.IceUI.add().
	--                      Runs ONLY on a rebuild (cached otherwise).
	--   cb.text          : base text phase -- draw base font text. Every frame.
	--   cb.textures      : (optional) engine-texture phase -- draw textured quads
	--                      LIVE every frame (use only for things that animate,
	--                      e.g. a build-progress clock). Most buildpic-style
	--                      content should use texturesCached instead.
	--   cb.texturesCached: (optional) like `textures`, but rendered ONCE into an
	--                      offscreen texture on rebuild and blitted every frame
	--                      (1 draw call/frame instead of hundreds). Requires
	--                      cb.textureRect. Use for static buildpics/icons.
	--   cb.textureRect   : (required with texturesCached) function returning the
	--                      consumer's bounding rect {l,b,r,t} in pixels, or nil
	--                      when the consumer is hidden.
	--   cb.overlayBuild  : overlay build phase -- queue overlay rects via
	--                      WG.IceUI.addOverlay(). Runs EVERY frame.
	--   cb.overlayText   : overlay text phase -- draw overlay font text. Every
	--                      frame, after the overlay flush.
	-- Calling registerDraw again with the same id replaces the callbacks.
	WG.IceUI.registerDraw = function(id, cb)
		for i = 1, #drawCallbacks do
			if drawCallbacks[i].id == id then
				local e = drawCallbacks[i]
				e.fn            = cb.draw
				e.text          = cb.text
				e.textures      = cb.textures
				e.texturesCached = cb.texturesCached
				e.textureRect   = cb.textureRect
				e.overlayBuild  = cb.overlayBuild
				e.overlayText   = cb.overlayText
				e.texturesDirty = true   -- re-render the FBO after a re-register
				return
			end
		end
		drawCallbacks[#drawCallbacks + 1] = {
			id = id,
			fn            = cb.draw,
			text          = cb.text,
			textures      = cb.textures,
			texturesCached = cb.texturesCached,
			textureRect   = cb.textureRect,
			overlayBuild  = cb.overlayBuild,
			overlayText   = cb.overlayText,
			-- cached-texture state (managed by the host, see DrawScreen).
			-- texturesDirty: re-render the FBO on the next frame. Starts true so
			-- a freshly registered widget fills its texture once. Set by
			-- setDirty (full) but NOT by setDirtyTextOnly -- that lets a widget
			-- rebuild its base VBO (e.g. for live numbers) WITHOUT paying the
			-- R2T re-render, which otherwise disturbs GL state and flickers text.
			fboTex = nil, fboW = 0, fboH = 0, texturesDirty = true,
		}
	end

	-- Draw one engine texture onto a screen rect. For things that can't go in
	-- the instanced atlas -- e.g. per-unit buildpics via the '#'..unitDefID
	-- engine texture syntax. Each call is its own draw, so use sparingly
	-- (a build menu page of ~30 buildpics is fine). Call only from a `textures`
	-- callback. `rect` = {l,b,r,t}; `texture` = a gl.Texture name string.
	--   color    : optional {r,g,b,a} tint
	--   zoom     : optional 0..1 -- shrinks the sampled UV range, so the image
	--              appears slightly enlarged within the rect. FlowUI always
	--              uses a small zoom (~0.02) on buildpics to hide the texture's
	--              hard edge; pass that for the same look.
	--   additive : optional bool -- draw with additive blending. Used to
	--              brighten an image on hover: draw it once normally, then
	--              again additively with a faded colour -- the bright parts of
	--              the image light up. (gl.Color > 1 is clamped, so a plain
	--              tint cannot brighten -- additive is the way.)
	--   sharp    : optional bool -- draw through the buildpic LOD-bias shader so
	--              a mipmapped texture stays crisp at non-power-of-two sizes
	--              (72px etc). Use for buildpics; not needed for tiny icons.
	WG.IceUI.drawTexture = function(rect, texture, color, zoom, additive, sharp)
		gl.Color(color and color[1] or 1, color and color[2] or 1,
		         color and color[3] or 1, color and color[4] or 1)
		if additive then
			gl.Blending(GL.SRC_ALPHA, GL.ONE)
		end
		gl.Texture(texture)
		local useShader = sharp and buildpicShader
		if useShader then
			buildpicShader:Activate()
		end
		if zoom and zoom > 0 then
			-- shrink the UV rect around its centre -> the image appears bigger
			-- but stays clipped to `rect`. The V coords are flipped (v1 high,
			-- v2 low): gl.TexRect WITHOUT uvs flips V internally, but the uv
			-- form does not -- so we flip it ourselves to keep the image
			-- upright (otherwise the buildpic shows upside-down).
			local m = 0.5 * math.min(zoom, 0.9)
			gl.TexRect(rect[1], rect[2], rect[3], rect[4],
				m, 1 - m, 1 - m, m)
		else
			gl.TexRect(rect[1], rect[2], rect[3], rect[4])
		end
		if useShader then
			buildpicShader:Deactivate()
		end
		gl.Texture(false)
		gl.Color(1, 1, 1, 1)
		if additive then
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		end
	end

	-- Draw a plain filled rectangle. For loose overlay bits (e.g. a queue
	-- badge background) that must sit on top of textures drawn in the same
	-- `textures` phase. `color` = {r,g,b,a}.
	WG.IceUI.drawRect = function(rect, color)
		gl.Texture(false)
		gl.Color(color and color[1] or 0, color and color[2] or 0,
		         color and color[3] or 0, color and color[4] or 1)
		gl.Rect(rect[1], rect[2], rect[3], rect[4])
		gl.Color(1, 1, 1, 1)
	end

	-- Draw a "build clock": a dark pie wedge over `rect`, clipped to the cell.
	-- `progress` is the fraction ALREADY BUILT (0..1): at 0 the whole cell is
	-- covered dark, at 1 nothing is -- the dark cover shrinks clockwise from
	-- 12 o'clock as the unit builds. The sweep edge is continuous (no segment
	-- snapping) so it animates smoothly. `color` = {r,g,b,a} of the cover.
	-- Untextured triangle fan from the cell centre; call from a `textures` cb.
	-- The fan emitter is the module-level emitPieFan -- no per-call closure.
	WG.IceUI.drawPie = function(rect, progress, color)
		progress = math.max(0, math.min(1, progress or 0))
		if progress >= 1 then return end          -- fully built: nothing to draw
		local cx = (rect[1] + rect[3]) * 0.5
		local cy = (rect[2] + rect[4]) * 0.5
		local hw = (rect[3] - rect[1]) * 0.5
		local hh = (rect[4] - rect[2]) * 0.5

		gl.Texture(false)
		gl.Color(color and color[1] or 0, color and color[2] or 0,
		         color and color[3] or 0, color and color[4] or 0.6)
		gl.BeginEnd(GL.TRIANGLE_FAN, emitPieFan, cx, cy, hw, hh, progress)
		gl.Color(1, 1, 1, 1)
	end

	WG.IceUI.unregisterDraw = function(id)
		for i = 1, #drawCallbacks do
			if drawCallbacks[i].id == id then
				local e = drawCallbacks[i]
				if e.fboTex then              -- free the cached-texture FBO
					gl.DeleteTexture(e.fboTex)
					e.fboTex = nil
				end
				table.remove(drawCallbacks, i)
				break
			end
		end
		hoverByID[id] = nil             -- drop this widget's hover state
		WG.IceUI.setOccluder(id, nil)   -- drop any occluder for this id too
	end

	-- Register a consumer's panel rect(s) so the tooltip widget suppresses
	-- area-based tooltips from FlowUI widgets underneath. `rects` is a list
	-- of {x1,y1,x2,y2}; pass nil to clear. A no-op if gui_tooltip is absent.
	WG.IceUI.setOccluder = function(id, rects)
		if WG['tooltip'] and WG['tooltip'].SetOccluder then
			WG['tooltip'].SetOccluder("iceui_" .. id, rects)
		end
	end

	-- Mark the UI as needing a rebuild on the next frame. The host only re-runs
	-- the draw callbacks + re-uploads the VBO when something is dirty; otherwise
	-- it just re-issues the (cheap) draw call with last frame's geometry.
	-- Consumers MUST call this whenever their visible content changes (selection
	-- change, a state toggle, a resize, ...). NOTE: hover does NOT need this --
	-- hover is a shader uniform, see setHover.
	WG.IceUI.setDirty = function()
		needsRebuild = true
		-- a full dirty also re-renders every cached-texture FBO -- the layout or
		-- textured content may have changed (selection, resize, ...).
		if drawCallbacks then
			for i = 1, #drawCallbacks do
				drawCallbacks[i].texturesDirty = true
			end
		end
	end

	-- Like setDirty, but rebuilds ONLY the base VBO (+ text) -- the cached
	-- buildpic FBOs are NOT re-rendered. Use this when a widget's TEXT changed
	-- but its textures did not: e.g. the info panel's live HP / income numbers,
	-- which tick several times a second. Re-rendering the FBO that often is
	-- both wasteful and a source of text flicker (the R2T pass disturbs GL
	-- state), so a text-only change must avoid it.
	WG.IceUI.setDirtyTextOnly = function()
		needsRebuild = true
	end

	-- Set the hovered element FOR A WIDGET. Hover is per-widget (keyed by `id`,
	-- the same id passed to registerDraw) so widgets never overwrite each
	-- other's hover. The highlight + fade are shader uniforms -- no rebuild.
	--   id      : the consumer's registerDraw id
	--   rect    : {l,b,r,t} of the hovered element in pixels, or nil for none
	--   pressed : true while the mouse button is held on it
	--   opts    : optional { fadeIn=, fadeOut=, tint=, pressTint= } overrides
	WG.IceUI.setHover = function(id, rect, pressed, opts)
		local h = hoverState(id)
		h.target  = rect
		h.pressed = pressed or false
		if opts then
			h.fadeIn    = opts.fadeIn    or h.fadeIn
			h.fadeOut   = opts.fadeOut   or h.fadeOut
			h.tint      = opts.tint      or h.tint
			h.pressTint = opts.pressTint or h.pressTint
		end
	end

	-- Current animated hover fade (0..1) for an element at `rect` within
	-- widget `id`. Lets a widget animate its own content (e.g. zoom a
	-- buildpic) in sync with the shader hover glow. 0 if not hovered.
	WG.IceUI.getHoverFade = function(id, rect)
		if not rect then return 0 end
		local h = hoverByID[id]
		if not h then return 0 end
		for s = 1, 2 do
			local slot = h.slots[s]
			local sr = slot.rect
			if sr and sr[1] == rect[1] and sr[2] == rect[2]
					and sr[3] == rect[3] and sr[4] == rect[4] then
				return slot.fade
			end
		end
		return 0
	end

	-- Look up the atlas UV rect {u0,v0,u1,v1} for an icon by file name
	-- (case-insensitive, e.g. "move.png"). Returns nil if not in the atlas.
	-- Pass the result as quad.uv to WG.IceUI.add() to draw that icon.
	WG.IceUI.getIconUV = function(name)
		if not name or not iconUVs then return nil end
		return iconUVs[name:lower()]
	end

	-- True if the icon atlas is available (any icons were found at init).
	WG.IceUI.hasIcons = function()
		return iconAtlas ~= nil
	end

	Spring.Echo("[IceUI-GL4] render core ready")
end

function widget:Shutdown()
	if baseRenderer then
		baseRenderer:free()
		baseRenderer = nil
	end
	if overlayRenderer then
		overlayRenderer:free()
		overlayRenderer = nil
	end
	if iconAtlas then
		gl.DeleteTextureAtlas(iconAtlas)
		iconAtlas = nil
	end
	if buildpicShader then
		buildpicShader:Finalize()
		buildpicShader = nil
	end
	if drawCallbacks then
		for i = 1, #drawCallbacks do
			local e = drawCallbacks[i]
			if e.fboTex then
				gl.DeleteTexture(e.fboTex)
				e.fboTex = nil
			end
		end
	end
	WG.IceUI = nil
end

-- True if two rects refer to the same element (same coordinates).
local function sameRect(a, b)
	if a == b then return true end
	if not a or not b then return false end
	return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

-- Move a value toward `goal` at a rate of 1/`time` per second.
local function approach(value, goal, time, dt)
	local rate = dt / math.max(time, 0.001)
	if value < goal then return math.min(goal, value + rate) end
	if value > goal then return math.max(goal, value - rate) end
	return value
end

-- Advance the cross-fade for ONE widget's hover state. slot 1 holds the
-- currently hovered element (fades in); when the hover moves to a new element
-- slot 1's still-visible old element is handed to slot 2 to fade out.
local function animateHoverState(h, dt)
	local s1, s2 = h.slots[1], h.slots[2]

	if not sameRect(h.target, s1.rect) then
		-- hover target changed; hand slot 1 to slot 2 if it is still visible.
		if s1.rect and s1.fade > 0.001 then
			if not s2.rect or s1.fade >= s2.fade then
				s2.rect, s2.fade, s2.press = s1.rect, s1.fade, s1.press
			end
		end
		s1.rect  = h.target
		s1.fade  = 0
		s1.press = 0
	end

	local g1 = s1.rect and 1 or 0
	s1.fade  = approach(s1.fade, g1,
		(g1 > s1.fade) and h.fadeIn or h.fadeOut, dt)
	s1.press = approach(s1.press, h.pressed and 1 or 0, 0.06, dt)

	s2.fade  = approach(s2.fade, 0, h.fadeOut, dt)
	s2.press = approach(s2.press, 0, 0.06, dt)
	if s2.fade <= 0 then s2.rect = nil end
end

-- Advance every widget's hover cross-fade. `dt` is elapsed seconds.
local function animateHover(dt)
	for _, h in pairs(hoverByID) do
		animateHoverState(h, dt)
	end
end

-- The shader has only 2 hover slots. Pick the 2 brightest slots across ALL
-- widgets and write them into shaderSlot1/shaderSlot2 for Core:setHoverSlot.
-- Usually all bright slots belong to one widget; when the cursor crosses from
-- one menu to another, the two can briefly belong to different widgets.
local shaderSlotA = { rect = nil, fade = 0, press = 0, tint = 0.18, pressTint = 0.22 }
local shaderSlotB = { rect = nil, fade = 0, press = 0, tint = 0.18, pressTint = 0.22 }

local function pickShaderSlots()
	-- reset
	shaderSlotA.rect, shaderSlotA.fade = nil, 0
	shaderSlotB.rect, shaderSlotB.fade = nil, 0

	for _, h in pairs(hoverByID) do
		for s = 1, 2 do
			local slot = h.slots[s]
			if slot.rect and slot.fade > 0.001 then
				-- insert into the brightest-two, keeping A >= B
				if slot.fade >= shaderSlotA.fade then
					-- A drops to B
					shaderSlotB.rect, shaderSlotB.fade  = shaderSlotA.rect, shaderSlotA.fade
					shaderSlotB.press = shaderSlotA.press
					shaderSlotB.tint, shaderSlotB.pressTint = shaderSlotA.tint, shaderSlotA.pressTint
					shaderSlotA.rect, shaderSlotA.fade  = slot.rect, slot.fade
					shaderSlotA.press = slot.press
					shaderSlotA.tint, shaderSlotA.pressTint = h.tint, h.pressTint
				elseif slot.fade >= shaderSlotB.fade then
					shaderSlotB.rect, shaderSlotB.fade  = slot.rect, slot.fade
					shaderSlotB.press = slot.press
					shaderSlotB.tint, shaderSlotB.pressTint = h.tint, h.pressTint
				end
			end
		end
	end
end

-- Cached-texture phase: render a consumer's `texturesCached` callback once into
-- an offscreen FBO texture, then blit that single texture every frame. This is
-- how FlowUI keeps its build menu cheap -- ~30 buildpics become one TexRect.
--   `e` : the drawCallbacks entry
-- The FBO is re-rendered when `e.texturesDirty` is set (the widget's textured
-- content or layout changed) OR when the FBO was just (re)created. It is NOT
-- re-rendered on every base-VBO rebuild -- a text-only rebuild (live numbers)
-- must not pay the R2T pass. The FBO is also (re)created when the consumer's
-- rect size changes. gl.R2tHelper maps the screen rect onto the texture, so the
-- callback keeps using screen coords. Does nothing if the consumer is hidden.
-- PERF/DEBUG PROBE: true forces the cached-texture content to be drawn LIVE
-- every frame (no R2T / FBO). Used to confirm whether the periodic text flicker
-- is caused by the R2T re-render disturbing GL state. Leave false for normal use.
local DEBUG_NO_R2T = false

local function drawCachedTexture(e)
	if DEBUG_NO_R2T or not gl.R2tHelper
			or not e.texturesCached or not e.textureRect then
		-- no R2T (or probe on): draw the callback live every frame
		if e.texturesCached then e.texturesCached() end
		return
	end
	local rect = e.textureRect()
	if not rect then return end          -- consumer hidden

	local x1, y1, x2, y2 = rect[1], rect[2], rect[3], rect[4]
	local w = math.floor(x2 - x1 + 0.5)
	local h = math.floor(y2 - y1 + 0.5)
	if w < 1 or h < 1 then return end

	-- (re)create the FBO texture when the size changed. Render at 2x for a
	-- crisp result when the menu is small relative to the screen (FlowUI does
	-- the same -- its buildmenuTex is created at 2x).
	local texW, texH = w * 2, h * 2
	local rebuild = e.texturesDirty
	if not e.fboTex or e.fboW ~= texW or e.fboH ~= texH then
		if e.fboTex then gl.DeleteTexture(e.fboTex) end
		e.fboTex = gl.CreateTexture(texW, texH, {
			target = GL.TEXTURE_2D, format = GL.RGBA, fbo = true,
		})
		e.fboW, e.fboH = texW, texH
		rebuild = true                   -- a fresh texture must be filled
	end

	if rebuild and e.fboTex then
		gl.R2tHelper.RenderInRect(e.fboTex, x1, y1, x2, y2, e.texturesCached, true)
		e.texturesDirty = false
	end

	-- blit the cached texture onto the menu's screen rect
	if e.fboTex then
		gl.R2tHelper.BlendTexRect(e.fboTex, x1, y1, x2, y2, true)
	end
end

local lastDrawTime   -- timer for per-frame dt

-- Per-phase profiling: accumulates microseconds per DrawScreen phase and echoes
-- an average every PERF_INTERVAL seconds. Set PERF to false to disable.
local PERF          = true
local PERF_INTERVAL = 2.0
local perfAccum     = { base = 0, tex = 0, text = 0, overlay = 0 }
local perfFrames    = 0
local perfNextEcho  = 0

function widget:DrawScreen()
	if not baseRenderer or Spring.IsGUIHidden() then
		return
	end
	if #drawCallbacks == 0 then
		return
	end

	-- elapsed time since the last DrawScreen, for the fade animation
	local nowT = Spring.GetTimer()
	local dt = lastDrawTime and Spring.DiffTimers(nowT, lastDrawTime) or 0
	lastDrawTime = nowT
	animateHover(dt)

	local tBase = PERF and Spring.GetTimer() or nil

	---------------------------------------------------------------- base layer
	-- Rebuild the base VBO only when something changed (needsRebuild). When
	-- nothing changed we skip the callbacks + the upload and just re-issue the
	-- draw call with last frame's geometry -- the big per-frame saving.
	-- The cached-texture FBOs re-render independently, gated by each widget's
	-- own `texturesDirty` flag (see drawCachedTexture) -- a text-only rebuild
	-- does not re-render them.
	if needsRebuild then
		baseRenderer:clear()
		for i = 1, #drawCallbacks do
			if drawCallbacks[i].fn then drawCallbacks[i].fn() end
		end
		baseRenderer:upload()
		needsRebuild = false
	end

	-- hover highlight is a shader uniform: cheap, no VBO touch. The shader has
	-- 2 slots; pick the 2 brightest across all widgets (per-widget hover).
	pickShaderSlots()
	local a, b = shaderSlotA, shaderSlotB
	baseRenderer:setHoverSlot(1, a.rect, a.fade, a.tint, a.press, a.pressTint)
	baseRenderer:setHoverSlot(2, b.rect, b.fade, b.tint, b.press, b.pressTint)
	baseRenderer:draw()                  -- the draw call runs every frame

	local tTex = PERF and Spring.GetTimer() or nil

	-- engine-texture phase. Two kinds, both between the base rects and the text:
	--   texturesCached -- buildpics/icons rendered into an FBO when the widget's
	--                     texturesDirty flag is set, then blitted (1 draw call).
	--   textures       -- live content (the build clock) drawn every frame, on
	--                     top of the cached texture.
	for i = 1, #drawCallbacks do
		local e = drawCallbacks[i]
		if e.texturesCached then
			drawCachedTexture(e)
		end
		if e.textures then
			e.textures()
		end
	end

	local tText = PERF and Spring.GetTimer() or nil

	-- base text, every frame (text is not part of the cached VBO; panels keep
	-- their text list across non-rebuild frames -- see iceui.lua)
	for i = 1, #drawCallbacks do
		if drawCallbacks[i].text then
			drawCallbacks[i].text()
		end
	end

	local tOverlay = PERF and Spring.GetTimer() or nil

	---------------------------------------------------------------- overlay layer
	-- The overlay (tooltips) follows the mouse, so it is rebuilt EVERY frame on
	-- its own renderer -- never cached, never disturbs the base VBO.
	-- clear() first: overlayBuild callbacks push straight via addOverlay.
	overlayRenderer:clear()
	for i = 1, #drawCallbacks do
		if drawCallbacks[i].overlayBuild then
			drawCallbacks[i].overlayBuild()   -- pushes overlay quads directly
		end
	end
	overlayRenderer:flush()

	for i = 1, #drawCallbacks do
		if drawCallbacks[i].overlayText then
			drawCallbacks[i].overlayText()
		end
	end

	-- per-phase profiling
	if PERF then
		local tEnd = Spring.GetTimer()
		perfAccum.base    = perfAccum.base    + Spring.DiffTimers(tTex,     tBase)    * 1e6
		perfAccum.tex     = perfAccum.tex     + Spring.DiffTimers(tText,    tTex)     * 1e6
		perfAccum.text    = perfAccum.text    + Spring.DiffTimers(tOverlay, tText)    * 1e6
		perfAccum.overlay = perfAccum.overlay + Spring.DiffTimers(tEnd,     tOverlay) * 1e6
		perfFrames = perfFrames + 1
		local clk = os.clock()
		if clk >= perfNextEcho then
			if perfNextEcho > 0 and perfFrames > 0 then
				local f = perfFrames
				Spring.Echo(string.format(
					"[IceUI perf] base=%.0f tex=%.0f text=%.0f overlay=%.0f us/frame (%d frames)",
					perfAccum.base / f, perfAccum.tex / f,
					perfAccum.text / f, perfAccum.overlay / f, f))
			end
			perfAccum.base, perfAccum.tex      = 0, 0
			perfAccum.text, perfAccum.overlay  = 0, 0
			perfFrames   = 0
			perfNextEcho = clk + PERF_INTERVAL
		end
	end
end
