-- Clone tool paste modes: RAISE ONLY and LOWER ONLY.
--
-- REPLACE (the default) lays the copied terrain down as it is. RAISE ONLY keeps the
-- higher of the copied surface and the ground under it (a heightmap "max" blend),
-- so only what stands above the ground arrives: a copied hill and valley pasted on
-- flat ground leave the hill. LOWER ONLY keeps the lower of the two (a "min" blend)
-- and leaves the valley.
--
-- Every other layer follows the terrain: a feature, metal spot, decal, light,
-- weather spawner or grass cell pastes only where the terrain does, and splats and
-- surface paint are blended through a mask of the same cells. The mask is decided
-- on the CPU at paste time, against the ground as it is before the paste, because
-- the texture blits run a frame later, when the gadget may already have moved it.
--
-- Usage:
--   M.keep(mode, d)                       d = pasted height - ground height
--   M.heightAt(t, lx, lz)                 the copied height at a box-local point
--   M.grid(t, offset, mode, toWorld)      mask over the copied vertex grid
--   inside a Draw callin:
--   M.texture(mask) / M.deleteTexture(mask)
--   M.drawSplatQuad(srcTex, mask, quad, tw, th)   inside glRenderToTexture
--   M.blendSurface(painter, region, quad, mask) -> region to paste, free with M.freeRegion

local M = {}

local floor, max, min = math.floor, math.max, math.min

-- An elmo of slack, so ground the paste leaves where it was (the edges of a hill,
-- flat ground under flat ground) does not count as pasted.
M.EPS = 1.0

M.MODES = { replace = 0, raise = 1, lower = 2 }

---@param mode string "replace", "raise" or "lower"
---@param d number pasted height minus ground height
function M.keep(mode, d)
	if mode == "raise" then
		return d > M.EPS
	elseif mode == "lower" then
		return d < -M.EPS
	end
	return true
end

-- Bilinear height of the copied grid at a box-local point (no height offset).
function M.heightAt(t, lx, lz)
	local gc = max(0, min(t.cols - 1, lx / t.stepX))
	local gr = max(0, min(t.rows - 1, lz / t.stepZ))
	local c0, r0 = floor(gc), floor(gr)
	local c1 = (c0 < t.cols - 1) and c0 + 1 or c0
	local r1 = (r0 < t.rows - 1) and r0 + 1 or r0
	local fc, fr = gc - c0, gr - r0
	local row0, row1 = t.grid[r0 + 1], t.grid[r1 + 1]
	local h0 = row0[c0 + 1] + (row0[c1 + 1] - row0[c0 + 1]) * fc
	local h1 = row1[c0 + 1] + (row1[c1 + 1] - row1[c0 + 1]) * fc
	return h0 + (h1 - h0) * fr
end

-- Which copied vertices paste, against the ground at their destination.
-- toWorld(lx, lz) -> wx, wz is the paste transform of this copy.
---@return table mask { cols, rows, bits (row-major 0/1), kept, total }
function M.grid(t, offset, mode, toWorld)
	local GetGroundHeight = Spring.GetGroundHeight
	local mapX, mapZ = Game.mapSizeX, Game.mapSizeZ
	local bits, n, kept = {}, 0, 0
	for r = 0, t.rows - 1 do
		local row = t.grid[r + 1]
		local lz = r * t.stepZ
		for c = 0, t.cols - 1 do
			local wx, wz = toWorld(c * t.stepX, lz)
			local k = 0
			if wx >= 0 and wx <= mapX and wz >= 0 and wz <= mapZ then
				if M.keep(mode, row[c + 1] + offset - GetGroundHeight(wx, wz)) then
					k = 1
					kept = kept + 1
				end
			end
			n = n + 1
			bits[n] = k
		end
	end
	return { cols = t.cols, rows = t.rows, bits = bits, kept = kept, total = n }
end

----------------------------------------------------------------
-- GPU side (Draw callins only)
----------------------------------------------------------------

-- The mask as a texture, one texel per copied vertex, linear filtered so the
-- blend edge falls off over one grid cell like the terrain itself does.
function M.texture(mask)
	if mask.tex then
		return mask.tex
	end
	local tex = gl.CreateTexture(mask.cols, mask.rows, {
		fbo = true,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
	if not tex then
		return nil
	end
	local cols, rows, bits = mask.cols, mask.rows, mask.bits
	gl.RenderToTexture(tex, function()
		gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
		gl.Blending(false)
		gl.Texture(0, false)
		gl.Color(1, 1, 1, 1)
		-- one quad per run of kept vertices along a row
		gl.BeginEnd(GL.QUADS, function()
			for r = 0, rows - 1 do
				local base = r * cols
				local y0, y1 = r / rows * 2 - 1, (r + 1) / rows * 2 - 1
				local c = 0
				while c < cols do
					if bits[base + c + 1] == 1 then
						local c0 = c
						while c < cols and bits[base + c + 1] == 1 do
							c = c + 1
						end
						local x0, x1 = c0 / cols * 2 - 1, c / cols * 2 - 1
						gl.Vertex(x0, y0)
						gl.Vertex(x1, y0)
						gl.Vertex(x1, y1)
						gl.Vertex(x0, y1)
					else
						c = c + 1
					end
				end
			end
		end)
	end)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	mask.tex = tex
	return tex
end

function M.deleteTexture(mask)
	if mask and mask.tex then
		gl.DeleteTexture(mask.tex)
		mask.tex = nil
	end
end

local VS = [[
varying vec2 uv;
void main() {
	uv = gl_MultiTexCoord0.xy;
	gl_Position = vec4(gl_Vertex.xy, 0.0, 1.0);
}
]]

-- Splats: the copied patch over the live distribution, through the mask. The live
-- texel under each fragment comes from the engine's own texture (the target is a
-- copy of it being written), so ground outside the mask stays bit-exact.
local SPLAT_FS = [[
uniform sampler2D srcTex;
uniform sampler2D maskTex;
uniform sampler2D curTex;
uniform vec4 dims; // mask cols, mask rows, target width, target height
varying vec2 uv;
void main() {
	vec2 muv = (uv * (dims.xy - 1.0) + 0.5) / dims.xy;
	float m = texture2D(maskTex, muv).r;
	vec4 cur = texture2D(curTex, gl_FragCoord.xy / dims.zw);
	gl_FragColor = mix(cur, texture2D(srcTex, uv), m);
}
]]

-- Surface paint: a region in the copied box's own space, the copied paint where the
-- mask keeps it and the destination's paint (read back through the quad) elsewhere.
local SURFACE_FS = [[
uniform sampler2D srcTex;
uniform sampler2D maskTex;
uniform sampler2D dstTex;
uniform vec4 dims; // mask cols, mask rows, output width, output height
uniform vec4 q0;   // destination of box corner (0,0) and (1,0), map uv
uniform vec4 q1;   // destination of box corner (0,1), then the dst region's origin
uniform vec4 q2;   // dst region size, has source, has destination
varying vec2 uv;
void main() {
	vec2 s = gl_FragCoord.xy / dims.zw;
	float m = texture2D(maskTex, (s * (dims.xy - 1.0) + 0.5) / dims.xy).r;
	vec2 mapUV = q0.xy + s.x * (q0.zw - q0.xy) + s.y * (q1.xy - q0.xy);
	vec4 dst = (q2.w > 0.5) ? texture2D(dstTex, (mapUV - q1.zw) / q2.xy) : vec4(0.0);
	vec4 src = (q2.z > 0.5) ? texture2D(srcTex, s) : vec4(0.0);
	gl_FragColor = mix(dst, src, m);
}
]]

local splatShader ---@type integer?
local surfaceShader ---@type integer?
local shaderFailed = false

local function shaders()
	if shaderFailed then
		return nil
	end
	if not splatShader then
		splatShader = gl.CreateShader({
			vertex = VS,
			fragment = SPLAT_FS,
			uniformInt = { srcTex = 0, maskTex = 1, curTex = 2 },
		})
		surfaceShader = gl.CreateShader({
			vertex = VS,
			fragment = SURFACE_FS,
			uniformInt = { srcTex = 0, maskTex = 1, dstTex = 2 },
		})
		if not (splatShader and surfaceShader) then
			Spring.Echo("[Clone Tool] paste mask shaders failed: " .. tostring(gl.GetShaderLog()))
			shaderFailed = true
			return nil
		end
	end
	return true
end

-- Draws the copied splat patch onto the bound render target (the full-size copy of
-- the live distribution) through the mask. quad = pasteQuadUV corners, map uv.
---@return boolean drawn false = no shader, caller falls back to a plain paste
function M.drawSplatQuad(srcTex, curTexName, mask, quad, tw, th)
	local maskTex = M.texture(mask)
	if not (maskTex and shaders()) then
		return false
	end
	local sh = splatShader --[[@as integer]] -- set by shaders() above
	gl.UseShader(sh)
	gl.Uniform(gl.GetUniformLocation(sh, "dims"), mask.cols, mask.rows, tw, th)
	gl.Blending(false)
	gl.Texture(0, srcTex)
	gl.Texture(1, maskTex)
	gl.Texture(2, curTexName)
	local q = quad
	gl.BeginEnd(GL.QUADS, function()
		gl.TexCoord(0, 0)
		gl.Vertex(q[1] * 2 - 1, q[2] * 2 - 1)
		gl.TexCoord(1, 0)
		gl.Vertex(q[3] * 2 - 1, q[4] * 2 - 1)
		gl.TexCoord(1, 1)
		gl.Vertex(q[5] * 2 - 1, q[6] * 2 - 1)
		gl.TexCoord(0, 1)
		gl.Vertex(q[7] * 2 - 1, q[8] * 2 - 1)
	end)
	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)
	gl.UseShader(0)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	return true
end

local function blendOne(srcTex, dstTex, w, h, maskTex, mask, quad, du0, dv0, dw, dh)
	local out = gl.CreateTexture(w, h, {
		fbo = true,
		format = GL.RGBA8,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
	if not out then
		return nil
	end
	gl.RenderToTexture(out, function()
		local sh = surfaceShader --[[@as integer]] -- set by shaders() in blendSurface
		gl.UseShader(sh)
		gl.Uniform(gl.GetUniformLocation(sh, "dims"), mask.cols, mask.rows, w, h)
		gl.Uniform(gl.GetUniformLocation(sh, "q0"), quad[1], quad[2], quad[3], quad[4])
		gl.Uniform(gl.GetUniformLocation(sh, "q1"), quad[7], quad[8], du0, dv0)
		gl.Uniform(gl.GetUniformLocation(sh, "q2"), dw, dh, srcTex and 1 or 0, dstTex and 1 or 0)
		gl.Blending(false)
		gl.Texture(0, srcTex or false)
		gl.Texture(1, maskTex)
		gl.Texture(2, dstTex or false)
		gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		gl.Texture(0, false)
		gl.Texture(1, false)
		gl.Texture(2, false)
		gl.UseShader(0)
	end)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	return out
end

-- A region (the painter's copy format) holding the copied paint where the mask keeps
-- it and the destination's own paint elsewhere, ready for painter.region.paste.
---@return table? region { w, h, tex, tex2 } to paste and then free with M.freeRegion
function M.blendSurface(painter, region, quad, mask)
	local maskTex = M.texture(mask)
	if not (maskTex and shaders()) then
		return nil
	end
	local u0, v0, u1, v1 = quad[1], quad[2], quad[1], quad[2]
	for i = 3, 7, 2 do
		u0, u1 = min(u0, quad[i]), max(u1, quad[i])
		v0, v1 = min(v0, quad[i + 1]), max(v1, quad[i + 1])
	end
	u0, v0, u1, v1 = max(0, u0), max(0, v0), min(1, u1), min(1, v1)
	if u1 <= u0 or v1 <= v0 then
		return nil
	end
	local dest = painter.region.copy(u0, v0, u1, v1)
	if not dest then
		return nil
	end
	local dw, dh = u1 - u0, v1 - v0
	local out = { w = region.w, h = region.h }
	out.tex = blendOne(region.tex, dest.tex, region.w, region.h, maskTex, mask, quad, u0, v0, dw, dh)
	if region.tex2 or dest.tex2 then
		out.tex2 = blendOne(region.tex2, dest.tex2, region.w, region.h, maskTex, mask, quad, u0, v0, dw, dh)
	end
	painter.region.free(dest)
	if not out.tex then
		M.freeRegion(out)
		return nil
	end
	return out
end

function M.freeRegion(region)
	if region then
		if region.tex then
			gl.DeleteTexture(region.tex)
			region.tex = nil
		end
		if region.tex2 then
			gl.DeleteTexture(region.tex2)
			region.tex2 = nil
		end
	end
end

function M.shutdown()
	if splatShader then
		gl.DeleteShader(splatShader)
	end
	if surfaceShader then
		gl.DeleteShader(surfaceShader)
	end
	splatShader, surfaceShader = nil, nil
end

return M
