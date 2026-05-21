--------------------------------------------------------------------------------
-- IceUI-GL4 - GL4 render core
--------------------------------------------------------------------------------
-- A small, instanced GL4 renderer for screen-space UI in Beyond All Reason.
--
-- Design goals (vs the old FlowUI immediate-mode drawing):
--   * One shared vertex quad + one instanced VBO + one shader
--     -> the whole UI is drawn in a single instanced draw call.
--   * No render-to-texture caching needed; cheap enough to draw every frame.
--   * Rounded rectangles done with a signed-distance-field (SDF) in the
--     fragment shader. No geometry shader -> simpler and broadly compatible.
--   * Every visual property (corner radius, border, gloss, hover/press tint,
--     gradient) is per-instance, so styling is fully data-driven.
--
-- This file only knows about geometry + pixels. It has no concept of styles,
-- layout or widgets -- that lives in the layers above (style.lua, layout.lua).
--
-- Renderer layout follows the proven pattern from dbg_frame_grapher.lua:
--   * a static unit-quad vertex VBO (location 0)
--   * an instance VBO with per-element attributes (locations 1+)
--   * makeVAOandAttach() ties them together, drawInstanceVBO() draws.
--
-- Usage (typically from the IceUI-GL4 host widget, not directly):
--   local Core = VFS.Include("luaui/Include/IceUI/core_gl4.lua")
--   local renderer = Core.new()        -- allocates VBO + shader
--   renderer:clear()                   -- start a frame
--   renderer:add(quad)                 -- queue an element (see :add docs)
--   renderer:flush()                   -- one instanced draw for everything
--   renderer:free()                    -- on shutdown
--------------------------------------------------------------------------------

local InstanceVBOTable = gl.InstanceVBOTable
local LuaShader        = gl.LuaShader

-- Per-instance attribute layout. Location 0 is reserved for the static quad
-- vertex buffer, so instance attributes start at id = 1.
-- Keep this in sync with the vertex shader `layout` block and INSTANCE_FLOATS.
local instanceLayout = {
	{ id = 1, name = "rect",    size = 4 }, -- left, bottom, right, top  (pixels)
	{ id = 2, name = "corners", size = 4 }, -- corner radius: tl, tr, br, bl (pixels)
	{ id = 3, name = "color1",  size = 4 }, -- top gradient color    rgba
	{ id = 4, name = "color2",  size = 4 }, -- bottom gradient color rgba
	{ id = 5, name = "border",  size = 4 }, -- borderWidth, borderR, borderG, borderB
	{ id = 6, name = "params",  size = 4 }, -- glossStrength, hoverTint, pressTint, zDepth
	{ id = 7, name = "uv",      size = 4 }, -- atlas UV rect: u0, v0, u1, v1
	{ id = 8, name = "flags",   size = 4 }, -- hasTexture, iconInset, unused, unused
}
local INSTANCE_FLOATS = 32 -- total floats per instance (must equal sum of sizes)

local INITIAL_CAPACITY = 1024

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------

local vsSrc = [[
#version 420
#line 10000

//__ENGINEUNIFORMBUFFERDEFS__

// location 0 comes from the static quad vertex buffer (makeRectVBO):
//   xy in [0,1] is the unit-quad corner, zw are quad UVs (unused here)
layout (location = 0) in vec4 quadcoord;

// instance attributes:
layout (location = 1) in vec4 rect;       // l, b, r, t  (pixels)
layout (location = 2) in vec4 corners;    // tl, tr, br, bl radius (pixels)
layout (location = 3) in vec4 color1;     // top color
layout (location = 4) in vec4 color2;     // bottom color
layout (location = 5) in vec4 border;     // width, r, g, b
layout (location = 6) in vec4 params;     // gloss, hoverTint, pressTint, z
layout (location = 7) in vec4 uv;         // atlas UV rect: u0, v0, u1, v1
layout (location = 8) in vec4 flags;      // hasTexture, iconInset, -, -

out DataVS {
	vec2  v_localpos;      // pixel offset from element's bottom-left
	vec2  v_pixelpos;      // absolute screen pixel position of the fragment
	vec2  v_size;          // element size in pixels
	vec2  v_quaduv;        // 0..1 corner uv of the element
	vec4  v_corners;
	vec4  v_color1;
	vec4  v_color2;
	vec4  v_border;
	vec4  v_params;
	vec4  v_uv;
	vec4  v_flags;
};

void main() {
	vec2 cornerUV = quadcoord.xy;                          // [0,1]
	vec2 size     = vec2(rect.z - rect.x, rect.w - rect.y);
	vec2 pixelPos = rect.xy + cornerUV * size;

	v_localpos = cornerUV * size;
	v_pixelpos = pixelPos;
	v_size     = size;
	v_quaduv   = cornerUV;
	v_corners  = corners;
	v_color1   = color1;
	v_color2   = color2;
	v_border   = border;
	v_params   = params;
	v_uv       = uv;
	v_flags    = flags;

	// pixel -> NDC (viewGeometry.xy is the screen size in pixels)
	vec2 ndc = (pixelPos / viewGeometry.xy) * 2.0 - 1.0;
	gl_Position = vec4(ndc, params.w, 1.0);
}
]]

local fsSrc = [[
#version 420
#line 20000

//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D atlasTex;   // shared icon atlas (texture unit 0)

// Hover highlight, driven entirely by uniforms (no per-instance hover data).
// TWO slots so one element can fade out while another fades in (cross-fade).
//   hoverRect[i]   = l, b, r, t  of slot i's element (pixels); zero if unused
//   hoverParams[i] = fade(0..1), tintStrength, pressFade(0..1), pressStrength
uniform vec4 hoverRect[2]   = vec4[2](vec4(0.0), vec4(0.0));
uniform vec4 hoverParams[2] = vec4[2](vec4(0.0), vec4(0.0));

in DataVS {
	vec2  v_localpos;
	vec2  v_pixelpos;
	vec2  v_size;
	vec2  v_quaduv;
	vec4  v_corners;
	vec4  v_color1;
	vec4  v_color2;
	vec4  v_border;
	vec4  v_params;
	vec4  v_uv;
	vec4  v_flags;
};

out vec4 fragColor;

// Signed distance to a rounded box centered at origin with half-size b and
// per-corner radius r packed as r = (tl, bl, tr, br). p is relative to center.
float sdRoundBox(vec2 p, vec2 b, vec4 r) {
	// pick the radius for the quadrant p is in: x>0 -> right, y>0 -> top
	r.xy = (p.x > 0.0) ? r.zw : r.xy;   // right -> (tr,br) : left -> (tl,bl)
	r.x  = (p.y > 0.0) ? r.x  : r.y;    // top   -> first    : bottom -> second
	vec2 q = abs(p) - b + r.x;
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}

void main() {
	vec2 halfSize = v_size * 0.5;
	vec2 p        = v_localpos - halfSize;       // relative to element center

	// v_corners is (tl, tr, br, bl); sdRoundBox wants (tl, bl, tr, br):
	vec4 r = vec4(v_corners.x, v_corners.w, v_corners.y, v_corners.z);
	float dist = sdRoundBox(p, halfSize, r);

	// 1px anti-aliased coverage
	float aa    = fwidth(dist) + 1e-4;
	float alpha = 1.0 - smoothstep(-aa, aa, dist);
	if (alpha <= 0.0) discard;

	// vertical gradient fill
	float topness = v_localpos.y / max(v_size.y, 1.0);
	vec4  col     = mix(v_color2, v_color1, topness);

	// border: blend toward border color near the inner edge
	float bw = v_border.x;
	if (bw > 0.0) {
		// dist is negative inside; the band [-bw, 0] is the border region
		float edge = smoothstep(-bw - aa, -bw + aa, dist);
		col.rgb = mix(col.rgb, v_border.yzw, edge);
	}

	// gloss: subtle bright band across the upper half
	float gloss = v_params.x;
	if (gloss > 0.0) {
		col.rgb += smoothstep(0.45, 1.0, topness) * gloss;
	}

	// resolve this fragment's hover state FIRST (needed for icon zoom below).
	// Two slots are checked so a fading-out and a fading-in element both
	// respond. Elements never overlap -> at most one slot matches.
	// hFade = hover fade 0..1, pFade = press fade 0..1 for this fragment.
	float hFade = 0.0, hTint = 0.0, pFade = 0.0, pTint = 0.0;
	for (int i = 0; i < 2; ++i) {
		vec4 hr = hoverRect[i];
		vec4 hp = hoverParams[i];
		if ((hp.x > 0.001 || hp.z > 0.001) && (hr.z - hr.x) > 0.5) {
			if (v_pixelpos.x >= hr.x && v_pixelpos.x <= hr.z &&
			    v_pixelpos.y >= hr.y && v_pixelpos.y <= hr.w) {
				hFade = hp.x; hTint = hp.y;
				pFade = hp.z; pTint = hp.w;
			}
		}
	}

	// optional icon: sample the atlas inside an inset sub-rect of the element.
	// flags.x = hasTexture, flags.y = icon inset fraction (0..0.5 per side).
	// On hover the icon zooms in toward the element centre, animated by hFade.
	if (v_flags.x > 0.5) {
		float inset = clamp(v_flags.y, 0.0, 0.49);
		vec2  iconUV = (v_quaduv - inset) / max(1.0 - 2.0 * inset, 1e-3);
		// zoom: shrink the sampled uv range around its centre as hFade rises
		float zoom = 1.0 - 0.10 * hFade;          // 1.0 .. 0.90
		iconUV = (iconUV - 0.5) * zoom + 0.5;
		if (all(greaterThanEqual(iconUV, vec2(0.0)))
				&& all(lessThanEqual(iconUV, vec2(1.0)))) {
			// flip V: atlas textures have a top-left origin, screen space is
			// bottom-left, so the icon needs its vertical axis inverted.
			iconUV.y = 1.0 - iconUV.y;
			vec2 atlasUV = mix(v_uv.xy, v_uv.zw, iconUV);
			vec4 tex = texture(atlasTex, atlasUV);
			// brighten the icon on hover, in sync with the zoom
			tex.rgb *= 1.0 + 0.25 * hFade;
			col.rgb = mix(col.rgb, tex.rgb, tex.a);
		}
	}

	// hover / press tinting applied on top of the (zoomed) icon
	col.rgb += hFade * hTint;   // hover: lighten
	col.rgb -= pFade * pTint;   // press: darken

	fragColor = vec4(col.rgb, col.a * alpha);
}
]]

--------------------------------------------------------------------------------
-- Renderer object
--------------------------------------------------------------------------------

local Core = {}
Core.__index = Core

-- Build the shared shader. Returns the LuaShader object or nil on failure.
local function makeShader()
	local engineDefs = LuaShader.GetEngineUniformBufferDefs()
	local shader = LuaShader({
		vertex   = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs),
		fragment = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs),
		uniformInt = {
			atlasTex = 0,   -- icon atlas sampler -> texture unit 0
		},
		-- array uniforms are addressed per element by indexed name
		uniformFloat = {
			["hoverRect[0]"]   = { 0, 0, 0, 0 },
			["hoverRect[1]"]   = { 0, 0, 0, 0 },
			["hoverParams[0]"] = { 0, 0, 0, 0 },
			["hoverParams[1]"] = { 0, 0, 0, 0 },
		},
	}, "IceUI-GL4 core shader")

	if not shader:Initialize() then
		Spring.Echo("[IceUI-GL4] core shader failed to compile")
		return nil
	end
	return shader
end

-- Allocate a renderer: a static quad VBO, one instance VBO, one VAO, one shader.
-- Returns nil if the GPU/driver can't support it (e.g. headless).
function Core.new()
	if not gl.CreateShader then
		return nil
	end

	local self = setmetatable({}, Core)

	-- static unit quad (0,0)-(1,1); xy = corner, zw = uv
	local quadVBO, numVertices = InstanceVBOTable.makeRectVBO(0, 0, 1, 1, 0, 0, 1, 1)
	if not quadVBO then
		Spring.Echo("[IceUI-GL4] failed to create quad VBO")
		return nil
	end

	self.vbo = InstanceVBOTable.makeInstanceVBOTable(
		instanceLayout, INITIAL_CAPACITY, "IceUI-GL4 instance VBO")
	if not self.vbo then
		Spring.Echo("[IceUI-GL4] failed to create instance VBO")
		return nil
	end

	self.vbo.VAO         = InstanceVBOTable.makeVAOandAttach(quadVBO, self.vbo.instanceVBO)
	self.vbo.numVertices = numVertices

	self.shader = makeShader()
	if not self.shader then
		return nil
	end

	self.count   = 0      -- number of instances queued this frame
	self.atlas   = nil    -- icon atlas texture id (set via :setAtlas)
	self.scratch = {}     -- reusable flat array for one instance
	for i = 1, INSTANCE_FLOATS do self.scratch[i] = 0 end

	-- hover highlight uniforms: two slots for cross-fade (see :setHoverSlot)
	self.hoverRect = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }
	self.hoverPrm  = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }

	return self
end

-- Set one of the two hover highlight slots, applied by the shader without
-- touching the VBO. Two slots let one element fade out while another fades in.
--   slot          : 1 or 2
--   rect          : {l,b,r,t} of the element in pixels, or nil to clear
--   fade          : 0..1 hover fade amount (animated by the caller)
--   tintStrength  : how much to lighten at fade==1
--   pressFade     : 0..1 press fade amount
--   pressStrength : how much to darken at pressFade==1
function Core:setHoverSlot(slot, rect, fade, tintStrength, pressFade, pressStrength)
	local hr, hp = self.hoverRect[slot], self.hoverPrm[slot]
	if rect then
		hr[1], hr[2], hr[3], hr[4] = rect[1], rect[2], rect[3], rect[4]
	else
		hr[1], hr[2], hr[3], hr[4] = 0, 0, 0, 0
	end
	hp[1] = fade or 0
	hp[2] = tintStrength or 0.18
	hp[3] = pressFade or 0
	hp[4] = pressStrength or 0.22
end

-- Set the shared icon atlas texture. `atlas` is a texture id from
-- gl.FinalizeTextureAtlas (or any texture). Pass nil to draw without icons.
function Core:setAtlas(atlas)
	self.atlas = atlas
end

-- Begin a frame: drop all queued elements.
function Core:clear()
	InstanceVBOTable.clearInstanceTable(self.vbo)
	self.count = 0
	self.dirtyLo, self.dirtyHi = nil, nil
end

-- Fill the reusable scratch array with one element's 32 instance floats.
-- See :add for the `q` field documentation. Internal helper.
function Core:_fillScratch(q)
	local s = self.scratch

	-- rect
	s[1] = q.left;  s[2] = q.bottom;  s[3] = q.right;  s[4] = q.top

	-- corners
	local cr = q.corner or 0
	s[5] = q.tl or cr;  s[6] = q.tr or cr;  s[7] = q.br or cr;  s[8] = q.bl or cr

	-- colors
	local c1 = q.color1
	if c1 then
		s[9] = c1[1] or 1;  s[10] = c1[2] or 1;  s[11] = c1[3] or 1;  s[12] = c1[4] or 1
	else
		s[9], s[10], s[11], s[12] = 1, 1, 1, 1
	end
	local c2 = q.color2 or c1
	if c2 then
		s[13] = c2[1] or 1;  s[14] = c2[2] or 1;  s[15] = c2[3] or 1;  s[16] = c2[4] or 1
	else
		s[13], s[14], s[15], s[16] = s[9], s[10], s[11], s[12]
	end

	-- border
	local bc = q.borderColor
	s[17] = q.borderWidth or 0
	if bc then
		s[18] = bc[1] or 0;  s[19] = bc[2] or 0;  s[20] = bc[3] or 0
	else
		s[18], s[19], s[20] = 0, 0, 0
	end

	-- params: gloss, hover, press, z
	s[21] = q.gloss or 0
	s[22] = q.hover or 0
	s[23] = q.press or 0
	s[24] = q.z or 0

	-- uv rect + texture flags
	local uv = q.uv
	if uv then
		s[25] = uv[1] or 0;  s[26] = uv[2] or 0;  s[27] = uv[3] or 1;  s[28] = uv[4] or 1
		s[29] = 1                       -- hasTexture
		s[30] = q.iconInset or 0        -- icon inset fraction
		s[31] = 0
	else
		s[25], s[26], s[27], s[28] = 0, 0, 1, 1
		s[29] = 0                       -- no texture
		s[30] = 0
		s[31] = 0
	end
	s[32] = 0
	return s
end

-- Queue one element. `q` is a table with these fields (all pixel space,
-- origin bottom-left of the screen):
--   q.left, q.bottom, q.right, q.top   -- required, the rectangle
--   q.corner                           -- number, uniform corner radius, or
--   q.tl, q.tr, q.br, q.bl             -- per-corner radius (overrides q.corner)
--   q.color1 = {r,g,b,a}               -- top color    (default opaque white)
--   q.color2 = {r,g,b,a}               -- bottom color (default = color1)
--   q.borderWidth, q.borderColor={r,g,b}
--   q.gloss   -- 0..1 highlight strength (default 0)
--   q.hover   -- 0..1 hover tint        (default 0)
--   q.press   -- 0..1 press tint        (default 0)
--   q.z       -- depth -1..1, lower = in front (default 0)
--   q.uv = {u0,v0,u1,v1}  -- atlas UV rect of an icon to draw (optional)
--   q.iconInset           -- 0..0.5 inset of the icon inside the rect (default 0)
-- Returns the slot index of the queued element (usable with :setSlot).
function Core:add(q)
	local s = self:_fillScratch(q)
	local slot = self.count
	-- noUpload = true: we batch upload once in :flush()
	InstanceVBOTable.pushElementInstance(self.vbo, s, slot, true, true)
	self.count = self.count + 1
	return slot
end

-- Retained update: overwrite the element at an existing `slot` index with `q`,
-- WITHOUT re-uploading. Marks the slot's byte range dirty; call :uploadDirty()
-- once after a batch of :setSlot calls to push only the changed ranges.
-- This is the cheap path for hover/press tint changes: only the few changed
-- elements are touched, not the whole VBO.
function Core:setSlot(slot, q)
	local s = self:_fillScratch(q)
	InstanceVBOTable.pushElementInstance(self.vbo, s, slot, true, true)
	-- track the dirty slot range so :uploadDirty can upload a tight span
	if not self.dirtyLo or slot < self.dirtyLo then self.dirtyLo = slot end
	if not self.dirtyHi or slot > self.dirtyHi then self.dirtyHi = slot end
end

-- Upload only the slot range touched by :setSlot since the last upload.
-- No-op when nothing was changed. Much cheaper than a full :upload().
function Core:uploadDirty()
	if not self.dirtyLo then return end
	InstanceVBOTable.uploadElementRange(self.vbo, self.dirtyLo, self.dirtyHi)
	self.dirtyLo, self.dirtyHi = nil, nil
end

-- Upload the queued instances to the GPU. Only needed after the element set
-- changed (clear + add). Cheap to skip when nothing changed -- see :draw.
function Core:upload()
	if self.count > 0 then
		InstanceVBOTable.uploadAllElements(self.vbo)
	end
end

-- Issue the instanced draw call for whatever is currently in the VBO.
-- Does NOT upload -- the caller decides when an upload is needed. This lets a
-- static UI redraw every frame without re-uploading an unchanged VBO.
function Core:draw()
	if self.count == 0 then return end

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.DepthTest(false)

	-- bind the icon atlas to unit 0; the shader only samples it for textured
	-- instances (flags.x), so a missing atlas just means no icons are drawn.
	if self.atlas then
		gl.Texture(0, self.atlas)
	end

	self.shader:Activate()
	-- push the two hover slots as array uniforms (cheap; no VBO touch)
	local hr, hp = self.hoverRect, self.hoverPrm
	self.shader:SetUniformFloat("hoverRect[0]",   hr[1][1], hr[1][2], hr[1][3], hr[1][4])
	self.shader:SetUniformFloat("hoverRect[1]",   hr[2][1], hr[2][2], hr[2][3], hr[2][4])
	self.shader:SetUniformFloat("hoverParams[0]", hp[1][1], hp[1][2], hp[1][3], hp[1][4])
	self.shader:SetUniformFloat("hoverParams[1]", hp[2][1], hp[2][2], hp[2][3], hp[2][4])
	InstanceVBOTable.drawInstanceVBO(self.vbo)
	self.shader:Deactivate()

	if self.atlas then
		gl.Texture(0, false)
	end
end

-- Convenience: upload + draw in one call (used when the set just changed).
function Core:flush()
	self:upload()
	self:draw()
end

-- Release GPU resources. Call from widget:Shutdown().
function Core:free()
	if self.shader then
		self.shader:Finalize()
		self.shader = nil
	end
	-- the instance VBO and VAO are released by the engine GC once dereferenced
	self.vbo = nil
end

return Core
