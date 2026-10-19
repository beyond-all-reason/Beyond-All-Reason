-- Clone tool paste ghost: the copied terrain drawn where a paste would put it, lit and
-- textured like the ground and a little transparent.
--
-- The mesh has no vertex data. One instanced triangle strip is built from gl_VertexID
-- (rows of quads joined by degenerate triangles, as map_edge_extension2.lua does),
-- followed by a skirt that drops from the ghost's rim to the current ground so a raised
-- or sunken paste reads as a solid block. Heights come from an R32F snapshot of
-- $heightmap and colour from a snapshot of the ground colour, both cut at copy time so later
-- edits to the source do not change what the clipboard holds.
--
-- Usage (all GL calls need a draw callin):
--   CP.init()                                  compile, allocate the VAO
--   local h = CP.capture(x1, z1, cols, rows)   x1/z1 on the 8-elmo vertex grid
--   CP.draw(h, inst, n, opts)                  inst = flat {x, z, rotRad, mirrorBits} * n
--   CP.free(h)  CP.stats(h)  CP.shutdown()

local CP = {}

local LuaShader = gl.LuaShader

local GL_R32F = 0x822E
local SQUARE = Game.squareSize or 8
-- Strip cells per axis; larger boxes skip source vertices. A 4096-elmo box at 512
-- cells is 0.53M vertices per pass, and at the zoom that shows all of it a 16-elmo
-- cell is still only a few pixels.
local MAX_CELLS = 256
local XRAY_CELLS = 128 -- the faint buried pass gets a coarser mesh
local MAX_COLOR = 2048 -- colour snapshot texels per axis
local MAX_INSTANCES = 16

local ghostShader ---@type LuaShader?
local captureShader ---@type LuaShader?
local vao ---@type VAO?
local instVBO ---@type VBO?
local ready = false

local vsSrc = [[
#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
#line 10000

layout (location = 0) in vec4 inst; // target x, target z, rotation (radians), mirror bits (1 = x, 2 = z)

//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D srcHeightTex; // copy-time snapshot, one texel per source vertex
uniform sampler2D heightmapTex; // the live $heightmap at the destination
uniform vec4 grid; // cols, rows, stride, cells along x
uniform vec4 box; // size x, size z, height offset, cells along z
uniform vec4 liftParams; // base lift, lift per elmo of camera distance

out DataVS {
	vec3 worldPos;
	vec3 normal;
	vec2 srcUV;
	vec2 localPos;
	float skirt;
	float lift; // what the anti-z-fight lift added to worldPos.y
};

float hAt(ivec2 c) {
	return texelFetch(srcHeightTex, clamp(c, ivec2(0), ivec2(grid.xy) - 1), 0).x;
}

void main() {
	int stride = int(grid.z);
	int nc = int(grid.w);
	int nr = int(box.w);
	ivec2 last = ivec2(grid.xy) - 1;
	int perLine = 2 * (nc + 1) + 2;
	int mainCount = nr * perLine;

	ivec2 cell;
	bool isSkirt = false;
	bool bottom = false;
	if (gl_VertexID < mainCount) {
		int line = gl_VertexID / perLine;
		int k = gl_VertexID - line * perLine;
		cell = ivec2(k >> 1, line + (k & 1));
		if (k == perLine - 2) { // repeat the last vertex of the line
			cell = ivec2(nc, line + 1);
		} else if (k == perLine - 1) { // first vertex of the next line
			cell = ivec2(0, line + 1);
		}
	} else {
		// Skirt: two lead vertices keep the join degenerate, then (rim, ground) pairs
		// walk the perimeter (0,0) -> (nc,0) -> (nc,nr) -> (0,nr) -> (0,0).
		int s = gl_VertexID - mainCount;
		int p = 0;
		if (s == 0) {
			cell = ivec2(0, nr);
		} else {
			isSkirt = true;
			int q = max(s - 2, 0);
			p = q >> 1;
			bottom = (s >= 2) && ((q & 1) == 1);
			int P = 2 * (nc + nr);
			p = min(p, P);
			if (p <= nc) cell = ivec2(p, 0);
			else if (p <= nc + nr) cell = ivec2(nc, p - nc);
			else if (p <= 2 * nc + nr) cell = ivec2(nc - (p - nc - nr), nr);
			else cell = ivec2(0, nr - (p - 2 * nc - nr));
		}
	}

	ivec2 cr = min(cell * stride, last);
	vec2 p = vec2(cr) * 8.0;
	float h = hAt(cr) + box.z;

	// slope from the neighbours one stride away, one-sided at the box edge
	ivec2 cL = max(cr - ivec2(stride, 0), ivec2(0));
	ivec2 cR = min(cr + ivec2(stride, 0), last);
	ivec2 cD = max(cr - ivec2(0, stride), ivec2(0));
	ivec2 cU = min(cr + ivec2(0, stride), last);
	float dhdx = (hAt(cR) - hAt(cL)) / max(float(cR.x - cL.x) * 8.0, 1.0);
	float dhdz = (hAt(cU) - hAt(cD)) / max(float(cU.y - cD.y) * 8.0, 1.0);
	vec3 n = normalize(vec3(-dhdx, 1.0, -dhdz));

	localPos = p;
	srcUV = vec2(cr) / max(vec2(last), vec2(1.0));

	// same order as the paste's transformPoint: mirror in box space, rotate about the centre, move
	int mir = int(inst.w + 0.5);
	if ((mir & 1) != 0) { p.x = box.x - p.x; n.x = -n.x; }
	if ((mir & 2) != 0) { p.y = box.y - p.y; n.z = -n.z; }
	vec2 d = p - 0.5 * box.xy;
	float cs = cos(inst.z);
	float sn = sin(inst.z);
	vec2 w = vec2(d.x * cs - d.y * sn, d.x * sn + d.y * cs) + inst.xy;
	n.xz = vec2(n.x * cs - n.z * sn, n.x * sn + n.z * cs);

	if (bottom) {
		h = textureLod(heightmapTex, heightmapUVatWorldPos(w), 0.0).x;
	}

	vec3 camPos = cameraViewInv[3].xyz;
	vec3 wp = vec3(w.x, h, w.y);
	// a lift that grows with distance: the engine's ground mesh coarsens far away, where
	// polygon offset alone would let a ghost at offset 0 z-fight the real ground
	float liftY = bottom ? 0.0 : liftParams.x + liftParams.y * length(camPos - wp);
	wp.y += liftY;

	worldPos = wp;
	lift = liftY;
	normal = n;
	skirt = isSkirt ? 1.0 : 0.0;
	gl_Position = cameraViewProj * vec4(wp, 1.0);
}
]]

local fsSrc = [[
#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack : require
#line 20000

//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D colorTex;
uniform sampler2D heightmapTex;
uniform vec4 box; // size x, size z, height offset, cells along z
uniform vec4 look; // opacity, brightness, delta tint, pass (0 colour, 1 x-ray, 2 depth)
uniform vec4 rimParams; // rim strength, paste mode (0 replace, 1 raise only, 2 lower only), mode slack (elmos), unused

in DataVS {
	vec3 worldPos;
	vec3 normal;
	vec2 srcUV;
	vec2 localPos;
	float skirt;
	float lift; // what the anti-z-fight lift added to worldPos.y
};

out vec4 fragColor;

void main() {
	// RAISE ONLY keeps what stands above the ground, LOWER ONLY what lies below it,
	// judged on the unlifted height exactly as the paste judges each vertex
	float groundAt = textureLod(heightmapTex, heightmapUVatWorldPos(worldPos.xz), 0.0).x;
	float pasteD = worldPos.y - lift - groundAt;
	int mode = int(rimParams.y + 0.5);
	bool cut = (mode == 1 && pasteD <= rimParams.z) || (mode == 2 && pasteD >= -rimParams.z);

	// depth prepass: only the map clamp matters, skip the shading
	if (look.w > 1.5) {
		if (cut) discard;
		if (any(lessThan(worldPos.xz, vec2(0.0))) || any(greaterThan(worldPos.xz, mapSize.xy))) discard;
		fragColor = vec4(0.0);
		return;
	}

	// derivatives first: they are undefined after a discard in the same quad
	vec3 faceN = normalize(cross(dFdx(worldPos), dFdy(worldPos)));
	float edge = min(min(localPos.x, box.x - localPos.x), min(localPos.y, box.y - localPos.y));
	float edgeW = fwidth(edge);

	// the paste clamps to the map, so must the ghost
	if (any(lessThan(worldPos.xz, vec2(0.0))) || any(greaterThan(worldPos.xz, mapSize.xy))) discard;

	float groundH = groundAt;
	float delta = worldPos.y - groundH;
	bool xray = look.w > 0.5;
	if (xray && (cut || delta > -2.0)) discard;
	if (cut) {
		// not pasted: only the footprint outline stays, so the box still shows
		float rimCut = (skirt < 0.5) ? (1.0 - smoothstep(edgeW * 1.0, edgeW * 2.5, edge)) * rimParams.x : 0.0;
		if (rimCut < 0.05) discard;
		fragColor = vec4(0.1, 0.9, 1.0, rimCut * 0.9);
		return;
	}

	vec3 N = normalize(normal);
	vec3 albedo = texture(colorTex, srcUV).rgb;
	if (skirt > 0.5) {
		// walls light flat, facing the camera, and a shade darker like a fresh cut
		vec3 toCam = cameraViewInv[3].xyz - worldPos;
		N = (dot(faceN, toCam) < 0.0) ? -faceN : faceN;
		albedo *= 0.8;
	}
	vec3 col = albedo * (sunAmbientMap.rgb + sunDiffuseMap.rgb * max(dot(N, sunDir.xyz), 0.0)) * look.y;

	if (look.z > 0.0) {
		vec3 tint = (delta > 0.0) ? vec3(1.0, 0.45, 0.2) : vec3(0.25, 0.5, 1.0);
		col = mix(col, tint, look.z * clamp(abs(delta) / 64.0, 0.0, 1.0));
	}

	if (fogParams.w > 0.0) {
		float fogDist = length((cameraView * vec4(worldPos, 1.0)).xyz);
		float fogFactor = clamp((fogParams.y - fogDist) * fogParams.w, 0.0, 1.0);
		col = mix(fogColor.rgb, col, fogFactor);
	}

	float a = look.x;
	if (skirt < 0.5 && rimParams.x > 0.0) {
		// a thin screen-width outline on the footprint edge
		float rim = 1.0 - smoothstep(edgeW * 1.0, edgeW * 2.5, edge);
		col = mix(col, vec3(0.1, 0.9, 1.0), rim * rimParams.x);
		a = max(a, rim * rimParams.x * 0.9);
	}
	if (xray) {
		if (mode == 2) {
			// LOWER ONLY pastes nothing but what lies below the ground, so the
			// buried pass is the preview: drawn nearly as solid as the ghost
			col = mix(col, vec3(0.35, 0.65, 1.0), 0.2);
			a *= 0.85;
		} else {
			col = mix(col, vec3(0.35, 0.65, 1.0), 0.5);
			a *= 0.35;
		}
	}
	fragColor = vec4(clamp(col, 0.0, 1.0), a);
}
]]

-- Heightmap snapshot: one fullscreen triangle into a cols x rows R32F target, texel
-- (c, r) = $heightmap vertex (origin + (c, r)), clamped to the map like GetGroundHeight.
local captureVsSrc = [[
#version 330
void main() {
	vec2 p = vec2(float((gl_VertexID & 1) * 4 - 1), float((gl_VertexID >> 1) * 4 - 1));
	gl_Position = vec4(p, 0.0, 1.0);
}
]]

local captureFsSrc = [[
#version 330
uniform sampler2D heightmapTex;
uniform vec4 origin; // first heightmap vertex x, z
out vec4 fragColor;
void main() {
	ivec2 t = ivec2(gl_FragCoord.xy) + ivec2(origin.xy);
	t = clamp(t, ivec2(0), textureSize(heightmapTex, 0) - 1);
	fragColor = vec4(texelFetch(heightmapTex, t, 0).x, 0.0, 0.0, 1.0);
}
]]

local function finalize(shader)
	if shader and shader.shaderObj ~= nil then
		shader:Finalize()
	end
end

---@return boolean ok
function CP.init()
	if ready then
		return true
	end
	if not (gl.CreateShader and gl.GetVAO and gl.GetVBO and LuaShader) then
		return false
	end
	local defs = LuaShader.GetEngineUniformBufferDefs()
	local function assemble(src)
		return (src:gsub("//__ENGINEUNIFORMBUFFERDEFS__", function()
			return defs
		end))
	end
	ghostShader = LuaShader({
		vertex = assemble(vsSrc),
		fragment = assemble(fsSrc),
		uniformInt = { srcHeightTex = 0, heightmapTex = 1, colorTex = 2 },
		uniformFloat = {
			grid = { 2, 2, 1, 1 },
			box = { 8, 8, 0, 1 },
			liftParams = { 0.5, 3e-4, 0, 0 },
			look = { 0.7, 1, 0, 0 },
			rimParams = { 1, 0, 0, 0 },
		},
	}, "Clone Preview Ghost")
	captureShader = LuaShader({
		vertex = captureVsSrc,
		fragment = captureFsSrc,
		uniformInt = { heightmapTex = 0 },
		uniformFloat = { origin = { 0, 0, 0, 0 } },
	}, "Clone Preview Capture")
	if not (ghostShader:Initialize() and captureShader:Initialize()) then
		CP.shutdown()
		return false
	end
	vao = gl.GetVAO()
	instVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if not (vao and instVBO) then
		CP.shutdown()
		return false
	end
	instVBO:Define(MAX_INSTANCES, { { id = 0, name = "inst", size = 4 } })
	vao:AttachInstanceBuffer(instVBO)
	ready = true
	return true
end

function CP.shutdown()
	finalize(ghostShader)
	finalize(captureShader)
	ghostShader, captureShader = nil, nil
	if vao then
		vao:Delete()
	end
	if instVBO then
		instVBO:Delete()
	end
	vao, instVBO = nil, nil
	ready = false
end

local function makeTex(w, h, format, filter)
	local opts = {
		fbo = true,
		min_filter = filter,
		mag_filter = filter,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	}
	if format then
		opts.format = format
	end
	return gl.CreateTexture(w, h, opts)
end

---Snapshots `cols` x `rows` heightmap vertices from (x1, z1) and the matching rect of
---$grass. Draw callins only.
---@param x1 number west edge in elmos, a multiple of 8
---@param z1 number north edge in elmos, a multiple of 8
---@param cols integer
---@param rows integer
---@return table? handle
function CP.capture(x1, z1, cols, rows)
	if not (ready or CP.init()) then
		return nil
	end
	if cols < 2 or rows < 2 or not (vao and captureShader) then
		return nil
	end
	local t0 = Spring.GetTimer()
	local mapX, mapZ = Game.mapSizeX, Game.mapSizeZ
	local sizeX, sizeZ = (cols - 1) * SQUARE, (rows - 1) * SQUARE

	local heightTex = makeTex(cols, rows, GL_R32F, GL.NEAREST)
	if not heightTex then
		return nil
	end
	gl.Blending(false)
	gl.Texture(0, "$heightmap")
	captureShader:Activate()
	captureShader:SetUniform("origin", math.floor(x1 / SQUARE + 0.5), math.floor(z1 / SQUARE + 0.5), 0, 0)
	gl.RenderToTexture(heightTex, function()
		vao:DrawArrays(GL.TRIANGLES, 3, 0, 1)
	end)
	captureShader:Deactivate()
	gl.Texture(0, false)

	-- $grass is the ground's flat colour; on tileset maps it is the tileset's
	-- composite, which holds no slope rock (that is shaded per pixel), so ghost
	-- slopes read as flat ground there.
	local colorSrc = "$grass"
	local info = gl.TextureInfo(colorSrc)
	local gw = (info and info.xsize) or 0
	local gh = (info and info.ysize) or 0
	local colorTex, cw, ch = nil, 0, 0
	if gw > 0 and gh > 0 then
		cw = math.max(2, math.min(MAX_COLOR, math.ceil(sizeX / mapX * gw)))
		ch = math.max(2, math.min(MAX_COLOR, math.ceil(sizeZ / mapZ * gh)))
		colorTex = makeTex(cw, ch, nil, GL.LINEAR)
		if colorTex then
			local u0, v0 = x1 / mapX, z1 / mapZ
			local u1, v1 = (x1 + sizeX) / mapX, (z1 + sizeZ) / mapZ
			gl.RenderToTexture(colorTex, function()
				gl.Texture(0, colorSrc)
				gl.TexRect(-1, -1, 1, 1, u0, v0, u1, v1)
				gl.Texture(0, false)
			end)
		end
	end
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	return {
		heightTex = heightTex,
		colorTex = colorTex,
		x1 = x1,
		z1 = z1,
		cols = cols,
		rows = rows,
		sizeX = sizeX,
		sizeZ = sizeZ,
		colorW = cw,
		colorH = ch,
		captureMs = Spring.DiffTimers(Spring.GetTimer(), t0) * 1000,
	}
end

---@param h table?
function CP.free(h)
	if not h then
		return
	end
	if h.heightTex then
		gl.DeleteTexture(h.heightTex)
		h.heightTex = nil
	end
	if h.colorTex then
		gl.DeleteTexture(h.colorTex)
		h.colorTex = nil
	end
end

-- The strip is built from gl_VertexID, so its density is a per-draw choice: the
-- source stride that keeps the mesh within maxCells per axis, and its vertex count.
local function meshFor(h, maxCells)
	local stride = math.max(1, math.ceil(math.max(h.cols - 1, h.rows - 1) / maxCells))
	local nc = math.ceil((h.cols - 1) / stride)
	local nr = math.ceil((h.rows - 1) / stride)
	-- main strip plus the skirt (two lead vertices, then a pair per perimeter point)
	return stride, nc, nr, nr * (2 * (nc + 1) + 2) + 2 + 2 * (2 * (nc + nr) + 1)
end

---@param h table?
---@return table?
function CP.stats(h)
	if not h then
		return nil
	end
	local stride, _, _, verts = meshFor(h, h.lastCells or MAX_CELLS)
	return {
		cols = h.cols,
		rows = h.rows,
		stride = stride,
		verts = verts,
		heightW = h.heightTex and h.cols or 0,
		heightH = h.heightTex and h.rows or 0,
		colorW = h.colorTex and h.colorW or 0,
		colorH = h.colorTex and h.colorH or 0,
		captureMs = h.captureMs,
		live = h.heightTex ~= nil,
	}
end

---Draws the ghost once per instance. Expects the caller's polygon offset; leaves depth
---test off, depth mask off, colour mask on and alpha blending on.
---@param h table
---@param inst number[] flat x, z, rotRad, mirrorBits per copy (reused by the caller)
---@param n integer instance count
---@param opts table { offset, opacity, brightness, tint, xray, rim, maxCells }
function CP.draw(h, inst, n, opts)
	if not (ready and h and h.heightTex and ghostShader and vao and instVBO) or n < 1 then
		return
	end
	n = math.min(n, MAX_INSTANCES)
	local cells = opts.maxCells or MAX_CELLS
	h.lastCells = cells
	local stride, nc, nr, verts = meshFor(h, cells)
	instVBO:Upload(inst, -1, 0, 1, n * 4)

	gl.Culling(false)
	gl.Texture(0, h.heightTex)
	gl.Texture(1, "$heightmap")
	gl.Texture(2, h.colorTex or "$grass")
	ghostShader:Activate()
	local offset = opts.offset or 0
	ghostShader:SetUniform("rimParams", opts.rim or 1, opts.blend or 0, opts.blendSlack or 1, 0)
	local opacity = opts.opacity or 0.7
	local brightness = opts.brightness or 1
	local tint = opts.tint or 0
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- 1. parts below the current ground, faint, before the ghost owns any depth
	if opts.xray ~= false then
		local xs, xnc, xnr, xverts = meshFor(h, math.min(cells, XRAY_CELLS))
		ghostShader:SetUniform("grid", h.cols, h.rows, xs, xnc)
		ghostShader:SetUniform("box", h.sizeX, h.sizeZ, offset, xnr)
		ghostShader:SetUniform("look", opacity, brightness, tint, 1)
		gl.DepthTest(GL.GREATER)
		gl.DepthMask(false)
		vao:DrawArrays(GL.TRIANGLE_STRIP, xverts, 0, n)
	end
	ghostShader:SetUniform("grid", h.cols, h.rows, stride, nc)
	ghostShader:SetUniform("box", h.sizeX, h.sizeZ, offset, nr)
	-- 2. depth only, so a near ridge does not blend twice over the slope behind it
	ghostShader:SetUniform("look", opacity, brightness, tint, 2)
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(true)
	gl.ColorMask(false, false, false, false)
	vao:DrawArrays(GL.TRIANGLE_STRIP, verts, 0, n)
	-- 3. colour, nearest ghost surface only
	ghostShader:SetUniform("look", opacity, brightness, tint, 0)
	gl.ColorMask(true, true, true, true)
	gl.DepthMask(false)
	vao:DrawArrays(GL.TRIANGLE_STRIP, verts, 0, n)

	ghostShader:Deactivate()
	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)
	gl.DepthTest(false)
end

CP.MAX_INSTANCES = MAX_INSTANCES

return CP
