function widget:GetInfo()
	return {
		name      = "Decal Capture",
		desc      = "Capture a top-down PNG of the map's diffuse gbuffer for use as a ground decal. Console: /decalcapture <name> [radius]",
		author    = "tf-brush",
		date      = "2026",
		license   = "GPL-2.0+",
		layer     = 0,
		enabled   = true,
	}
end

--[[
Pipeline (diffuse-only MVP):
  1. User runs `/decalcapture <name> [radius]` (radius in elmos, default 256).
     Capture is centered on cursor world position.
  2. On next DrawScreen we run a fullscreen-quad fragment shader that, for
     each output texel, computes its world (x,z), samples $heightmap to get
     y, projects through the current view-projection matrix into screen UV,
     and reads $map_gbuffer_difftex at that UV. Off-screen / behind-camera
     texels write transparent. Radial feather alpha at edge.
  3. SaveImage writes PNG to LuaUI/Cache/decal_captures/<name>.png in the
     spring write dir; echo absolute path.

Limitations (will iterate):
  - Captures only what's on-screen RIGHT NOW. Fly your camera so the area
    is fully visible before issuing the command.
  - Diffuse only. Normal/specular channels later.
  - Alpha is currently a radial feather only — no smart color isolation
    yet (next iteration).
  - No engine atlas auto-registration. After capture the user must:
      a) move PNG into bitmaps/decals/
      b) append filename to gamedata/resources.lua `graphics.decals`
      c) restart the game so the atlas rebuilds.
]]

local OUT_SIZE         = 512
local DEFAULT_RADIUS   = 256
local CACHE_SUBDIR     = "LuaUI/Cache/decal_captures/"

local pendingCaptures  = {}    -- queue of { name=, cx=, cz=, radius= }
local captureShader
local uniViewProj, uniWorldOrigin, uniWorldExtent, uniMapSize, uniFeatherStart

--------------------------------------------------------------------------------
-- Shader
--------------------------------------------------------------------------------
local VERT_SRC = [[
	#version 150 compatibility
	void main() {
		gl_TexCoord[0] = gl_MultiTexCoord0;
		gl_Position = gl_Vertex;
	}
]]

-- Fragment: project world→screen, sample current-frame gbuffer.
--
-- INPUT
--   tex0           : $map_gbuffer_difftex (screen-space lit diffuse)
--   heightMap      : $heightmap (red channel = ground Y in world units)
--   worldOrigin    : world (x,z) at output (0,0)
--   worldExtent    : world span (= 2*radius), so worldPos = origin + uv*extent
--   viewProj       : current view-projection matrix
--   mapSize        : (mapSizeX, mapSizeZ)
--   featherStart   : 0..1, radius from center where alpha begins to fade
local FRAG_SRC = [[
	#version 150 compatibility
	uniform sampler2D tex0;
	uniform sampler2D heightMap;
	uniform vec2 worldOrigin;
	uniform vec2 worldExtent;
	uniform mat4 viewProj;
	uniform vec2 mapSize;
	uniform float featherStart;

	void main() {
		vec2 uv = gl_TexCoord[0].st;

		// world XZ for this output texel (uv 0..1 → origin..origin+extent)
		vec2 wxz = worldOrigin + uv * worldExtent;

		// height from engine heightmap (clamped to [0,1] uv space)
		vec2 hUV = clamp(wxz / mapSize, vec2(0.0), vec2(1.0));
		float wy = texture2D(heightMap, hUV).x;

		// project to clip
		vec4 clip = viewProj * vec4(wxz.x, wy, wxz.y, 1.0);
		if (clip.w <= 0.0) {
			// behind camera
			gl_FragColor = vec4(0.0);
			return;
		}
		vec3 ndc = clip.xyz / clip.w;
		vec2 sUV = ndc.xy * 0.5 + 0.5;

		// off-screen → transparent
		if (sUV.x < 0.0 || sUV.x > 1.0 || sUV.y < 0.0 || sUV.y > 1.0) {
			gl_FragColor = vec4(0.0);
			return;
		}
		// off-map → transparent (out-of-bounds heightmap was clamped, but the
		// world point itself is invalid)
		if (wxz.x < 0.0 || wxz.x > mapSize.x || wxz.y < 0.0 || wxz.y > mapSize.y) {
			gl_FragColor = vec4(0.0);
			return;
		}

		vec3 rgb = texture2D(tex0, sUV).rgb;

		// radial feather alpha
		vec2 c = uv * 2.0 - 1.0;
		float r = length(c);
		float alpha = 1.0 - smoothstep(featherStart, 1.0, r);

		gl_FragColor = vec4(rgb, alpha);
	}
]]

local function initShader()
	if captureShader ~= nil then return captureShader and true or false end
	captureShader = gl.CreateShader({
		vertex      = VERT_SRC,
		fragment    = FRAG_SRC,
		uniformInt  = { tex0 = 0, heightMap = 1 },
		uniformFloat = {
			worldOrigin  = { 0, 0 },
			worldExtent  = { 1, 1 },
			mapSize      = { 1, 1 },
			featherStart = 0.85,
		},
	})
	if not captureShader or captureShader == 0 then
		Spring.Echo("[DecalCapture] shader compile failed: " .. tostring(gl.GetShaderLog()))
		captureShader = false
		return false
	end
	uniViewProj     = gl.GetUniformLocation(captureShader, "viewProj")
	uniWorldOrigin  = gl.GetUniformLocation(captureShader, "worldOrigin")
	uniWorldExtent  = gl.GetUniformLocation(captureShader, "worldExtent")
	uniMapSize      = gl.GetUniformLocation(captureShader, "mapSize")
	uniFeatherStart = gl.GetUniformLocation(captureShader, "featherStart")
	return true
end

--------------------------------------------------------------------------------
-- Capture (must run inside DrawScreen — gl.RenderToTexture restriction)
--------------------------------------------------------------------------------
local function runCapture(job)
	if not initShader() then return false, "shader unavailable" end

	local fbo = gl.CreateTexture(OUT_SIZE, OUT_SIZE, {
		border     = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s     = GL.CLAMP_TO_EDGE,
		wrap_t     = GL.CLAMP_TO_EDGE,
		fbo        = true,
	})
	if not fbo then return false, "FBO create failed" end

	local cx, cz, r = job.cx, job.cz, job.radius
	local ox, oz = cx - r, cz - r
	local extent = 2 * r
	local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ
	local vp = { gl.GetMatrixData("viewprojection") }
	if #vp ~= 16 then
		gl.DeleteTexture(fbo)
		return false, "could not read viewproj matrix"
	end

	local outPath = CACHE_SUBDIR .. job.name .. ".png"
	local saved = false

	gl.RenderToTexture(fbo, function()
		gl.Blending(false)
		gl.DepthTest(false)
		gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)

		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PushMatrix()
		gl.LoadIdentity()

		gl.UseShader(captureShader)
		gl.Uniform(uniWorldOrigin, ox, oz)
		gl.Uniform(uniWorldExtent, extent, extent)
		gl.Uniform(uniMapSize, mapSizeX, mapSizeZ)
		gl.Uniform(uniFeatherStart, 0.85)
		gl.UniformMatrix(uniViewProj, unpack(vp))

		gl.Texture(0, "$map_gbuffer_difftex")
		gl.Texture(1, "$heightmap")

		-- Quad in NDC; tex coords carry the 0..1 sampling space.
		gl.BeginEnd(GL.QUADS, function()
			gl.TexCoord(0, 0); gl.Vertex(-1, -1, 0)
			gl.TexCoord(1, 0); gl.Vertex( 1, -1, 0)
			gl.TexCoord(1, 1); gl.Vertex( 1,  1, 0)
			gl.TexCoord(0, 1); gl.Vertex(-1,  1, 0)
		end)

		gl.UseShader(0)
		gl.Texture(0, false)
		gl.Texture(1, false)

		-- Save inside the FBO callback (proven pattern: dp_preview_bake.lua)
		gl.SaveImage(0, 0, OUT_SIZE, OUT_SIZE, outPath, { yflip = false, alpha = true })
		saved = true

		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PopMatrix()
		gl.Blending(true)
	end)

	gl.DeleteTexture(fbo)
	return saved, outPath
end

--------------------------------------------------------------------------------
-- Action handler
--------------------------------------------------------------------------------
local function sanitizeName(s)
	if not s then return nil end
	s = tostring(s):gsub("[^%w_-]", "_")
	if s == "" then return nil end
	return s
end

local function actionCapture(_, _, params)
	-- params is the raw arg string after the action name
	local name, radiusStr
	if type(params) == "table" then
		name, radiusStr = params[1], params[2]
	elseif type(params) == "string" then
		name, radiusStr = params:match("^(%S+)%s*(%S*)$")
	end
	name = sanitizeName(name)
	if not name then
		Spring.Echo("[DecalCapture] usage: /decalcapture <name> [radius]")
		return true
	end
	local radius = tonumber(radiusStr) or DEFAULT_RADIUS
	if radius < 16 or radius > 4096 then
		Spring.Echo("[DecalCapture] radius out of range (16..4096)")
		return true
	end

	-- Capture at cursor world position
	local mx, my = Spring.GetMouseState()
	local kind, pos = Spring.TraceScreenRay(mx, my, true)
	if not pos or (kind ~= "ground" and type(pos) ~= "table") then
		Spring.Echo("[DecalCapture] cursor not over ground; aim at terrain and retry")
		return true
	end
	local cx, cz = pos[1], pos[3]

	pendingCaptures[#pendingCaptures + 1] = {
		name   = name,
		cx     = cx,
		cz     = cz,
		radius = radius,
	}
	Spring.Echo(string.format(
		"[DecalCapture] queued '%s' at (%d, %d) r=%d", name, cx, cz, radius))
	return true
end

--------------------------------------------------------------------------------
-- Widget callins
--------------------------------------------------------------------------------
local function actionDump()
	local names, files = Spring.GetGroundDecalTextures(true, true)
	names = names or {}
	files = files or {}
	Spring.Echo(string.format("[DecalCapture] atlas textures: %d", #names))
	for i, n in ipairs(names) do
		Spring.Echo(string.format("  [%d] %s -> %s", i, tostring(n), tostring(files[i])))
	end
	return true
end

local function actionDumpRes()
	-- Show what the VFS actually serves for resources.lua and graphics.decals
	local path = "gamedata/resources.lua"
	local raw = VFS.LoadFile(path, VFS.MOD)
	if not raw then
		raw = VFS.LoadFile(path, VFS.ZIP)
	end
	if not raw then
		raw = VFS.LoadFile(path)
	end
	if raw then
		Spring.Echo(string.format("[DecalCapture] VFS resources.lua bytes=%d", #raw))
		-- Echo a slice around 'decals = {' so we can see what entries the VFS sees.
		local s, e = raw:find("decals%s*=%s*{")
		if s then
			local snippet = raw:sub(s, math.min(e + 400, #raw))
			Spring.Echo("[DecalCapture] VFS resources.lua decals block:")
			for line in snippet:gmatch("[^\r\n]+") do
				Spring.Echo("  " .. line)
			end
		else
			Spring.Echo("[DecalCapture] could not find 'decals = {' in VFS resources.lua")
		end
	else
		Spring.Echo("[DecalCapture] VFS.LoadFile returned nil for resources.lua")
	end

	local ok, tbl = pcall(VFS.Include, path, nil, VFS.MOD)
	if not ok or type(tbl) ~= "table" then
		ok, tbl = pcall(VFS.Include, path)
	end
	if ok and type(tbl) == "table" and type(tbl.graphics) == "table" and type(tbl.graphics.decals) == "table" then
		local d = tbl.graphics.decals
		Spring.Echo(string.format("[DecalCapture] VFS.Include graphics.decals length=%d", #d))
		for i = 1, #d do
			Spring.Echo(string.format("  [%d] %s", i, tostring(d[i])))
		end
	else
		Spring.Echo("[DecalCapture] VFS.Include failed or no graphics.decals table")
	end

	-- Probe direct file presence in the VFS for both files we expect.
	for _, f in ipairs({
		"bitmaps/decals/atg_metal_spot.png",
		"bitmaps/decals/mexatg.png",
	}) do
		local exists = VFS.FileExists(f)
		local existsMod = VFS.FileExists(f, VFS.MOD)
		Spring.Echo(string.format("[DecalCapture] VFS.FileExists %s any=%s mod=%s",
			f, tostring(exists), tostring(existsMod)))
	end
	return true
end

--------------------------------------------------------------------------------
-- Auto-install: copy capture into the .sdd's bitmaps/decals/ and append the
-- entry to gamedata/resources.lua so a single restart picks it up.
--
-- Returns true on success, false (with echo'd reason) otherwise. Uses io.*
-- with absolute paths derived from VFS.GetFileAbsolutePath. Only works when
-- the mod is loaded from a writable .sdd directory; falls back gracefully
-- for .sdz/.sd7 archives.
--------------------------------------------------------------------------------
local function autoInstall(name, capturedRel)
	local resAbs = VFS.GetFileAbsolutePath("gamedata/resources.lua", VFS.MOD)
	if not resAbs then
		Spring.Echo("[DecalCapture] cannot resolve resources.lua absolute path; manual install required")
		return false
	end
	resAbs = resAbs:gsub("\\", "/")
	local sddRoot = resAbs:match("^(.-/)gamedata/resources%.lua$")
	if not sddRoot then
		Spring.Echo("[DecalCapture] cannot parse SDD root from " .. resAbs)
		return false
	end
	if not sddRoot:find("%.sdd/$") then
		Spring.Echo("[DecalCapture] mod is not in a .sdd; manual install required (got " .. sddRoot .. ")")
		return false
	end
	local writeDir = sddRoot:match("^(.-/)games/[^/]+%.sdd/$")
	if not writeDir then
		Spring.Echo("[DecalCapture] cannot derive writeDir from " .. sddRoot)
		return false
	end

	-- gl.SaveImage writes relative to Spring.GetWriteDir(), not to the .sdd.
	local springWrite = (Spring.GetWriteDir and Spring.GetWriteDir()) or writeDir
	springWrite = springWrite:gsub("\\", "/")
	if not springWrite:find("/$") then springWrite = springWrite .. "/" end
	local srcAbs = springWrite .. capturedRel

	local dstRel = "bitmaps/decals/" .. name .. ".png"
	local dstAbs = sddRoot .. dstRel
	-- Path under writeDir for sandboxed io.open: games/<sdd-name>/bitmaps/decals/<name>.png
	local sddName = sddRoot:match("/games/([^/]+%.sdd)/$") or ""
	local dstWriteRel = sddName ~= "" and ("games/" .. sddName .. "/" .. dstRel) or nil

	-- Refuse to clobber an existing file in bitmaps/decals/
	local probe = (dstWriteRel and io.open(dstWriteRel, "rb")) or io.open(dstAbs, "rb")
	if probe then
		probe:close()
		Spring.Echo("[DecalCapture] " .. dstAbs .. " already exists; rename your capture and retry")
		return false
	end

	-- Spring's sandboxed io.open accepts paths relative to writeDir; try that first
	-- and fall back to absolute.
	local fi = io.open(capturedRel, "rb") or io.open(srcAbs, "rb")
	if not fi then
		Spring.Echo("[DecalCapture] cannot open captured PNG: " .. srcAbs)
		return false
	end
	local data = fi:read("*a"); fi:close()
	local fo = (dstWriteRel and io.open(dstWriteRel, "wb")) or io.open(dstAbs, "wb")
	if not fo then
		Spring.Echo("[DecalCapture] cannot write: " .. dstAbs .. " (read-only?)")
		return false
	end
	fo:write(data); fo:close()
	Spring.Echo("[DecalCapture] copied -> " .. dstAbs)

	local resWriteRel = sddName ~= "" and ("games/" .. sddName .. "/gamedata/resources.lua") or nil
	local rfi = (resWriteRel and io.open(resWriteRel, "rb")) or io.open(resAbs, "rb")
	if not rfi then
		Spring.Echo("[DecalCapture] cannot read resources.lua at " .. resAbs)
		return false
	end
	local res = rfi:read("*a"); rfi:close()
	local entry = "decals/" .. name .. ".png"
	if res:find(entry, 1, true) then
		Spring.Echo("[DecalCapture] resources.lua already lists '" .. entry .. "'")
	else
		local blockStart = res:find("decals%s*=%s*{")
		if not blockStart then
			Spring.Echo("[DecalCapture] no 'decals = {' in resources.lua; manual edit required")
			return false
		end
		local blockEnd = res:find("}", blockStart, true)
		if not blockEnd then
			Spring.Echo("[DecalCapture] malformed decals block; manual edit required")
			return false
		end
		-- Locate last existing 'decals/...png', entry inside the block
		local lastEnd
		local searchFrom = blockStart
		while true do
			local s, e = res:find("'decals/[^']+'%s*,", searchFrom)
			if not s or s > blockEnd then break end
			lastEnd = e
			searchFrom = e + 1
		end
		if not lastEnd then
			Spring.Echo("[DecalCapture] no anchor entry in decals block; manual edit required")
			return false
		end
		-- Reuse the indent of the existing entry's line
		local block = res:sub(blockStart, blockEnd)
		local indent = block:match("\n([ \t]+)'decals/") or "\t\t\t"
		local insertion = indent .. "'" .. entry .. "',\n"
		local nl = res:find("\n", lastEnd, true) or lastEnd
		local newRes = res:sub(1, nl) .. insertion .. res:sub(nl + 1)
		local rfo = (resWriteRel and io.open(resWriteRel, "wb")) or io.open(resAbs, "wb")
		if not rfo then
			Spring.Echo("[DecalCapture] cannot write resources.lua: " .. resAbs)
			return false
		end
		rfo:write(newRes); rfo:close()
		Spring.Echo("[DecalCapture] appended '" .. entry .. "' to resources.lua")
	end

	Spring.Echo("[DecalCapture] >>> RESTART BAR to rebuild the ground decal atlas <<<")
	return true
end

function widget:Initialize()
	Spring.CreateDir(CACHE_SUBDIR)
	widgetHandler:AddAction("decalcapture", actionCapture, nil, "t")
	widgetHandler:AddAction("decalsdump", actionDump, nil, "t")
	widgetHandler:AddAction("decaldumpres", actionDumpRes, nil, "t")
end

function widget:Shutdown()
	widgetHandler:RemoveAction("decalcapture")
	widgetHandler:RemoveAction("decalsdump")
	widgetHandler:RemoveAction("decaldumpres")
	if captureShader then
		gl.DeleteShader(captureShader)
		captureShader = nil
	end
end

function widget:DrawScreen()
	if #pendingCaptures == 0 then return end
	local job = table.remove(pendingCaptures, 1)
	local ok, info = runCapture(job)
	if ok then
		Spring.Echo(string.format("[DecalCapture] saved: %s", tostring(info)))
		autoInstall(job.name, info)
	else
		Spring.Echo("[DecalCapture] capture failed: " .. tostring(info))
	end
end
