function widget:GetInfo()
	return {
		name = "Terraform Brush Capture",
		desc = "Exports a maximum-resolution top-down photo of the map plus a Figma-ready SVG layer of every placed unit. Console: /tfcapture",
		author = "PtaQ",
		date = "2026",
		license = "GPL-2.0+",
		layer = 0,
		-- Off by default like the rest of the Terraform Brush suite
		-- (cmd_terraform_brush, cmd_map_project): enabled from the widget list.
		enabled = false,
	}
end

--[[
Capture pipeline
================

The map photo is a camera walk, not a single screenshot. Per tile we park the
camera high above the tile looking straight down, let the frame render, copy the
composited screen, then run a reprojection shader that maps every OUTPUT texel
to its true world (x,z), looks the ground height up in $heightmap, projects that
world point through the frame's real view-projection matrix and reads the screen
copy at the resulting UV.

Reprojecting rather than cropping screenshots is what makes tiles stitch
pixel-exact: a plain crop bakes in the frame's perspective, so hilltops shift
outward from screen centre and every tile seam shows a ridge discontinuity.
Reprojection is orthographic in world XZ by construction, so neighbouring tiles
agree on every shared texel regardless of where the camera happened to be.

Tiles are composited into ONE oversized FBO (sub-rect per tile) and written with
a single gl.SaveImage, so there is no external stitching step. Output resolution
is therefore capped by GL_MAX_TEXTURE_SIZE, not by screen resolution: the screen
only limits pixels-per-TILE, and we simply use more, smaller tiles for more
detail (halving the world span per tile doubles px/elmo).

Units are NOT in the photo -- they are hidden for the walk and exported as a
separate SVG whose <image> children each carry a base64 PNG. Figma imports that
as one movable layer per unit, which is the whole point: a campaign designer
drops photo + unit layer into one frame and re-blocks the mission by dragging.

Reads the unit list through WG.MapProject.requestUnits (a synced gadget
round-trip). The widget-side unit view is LOS-limited, so enumerating here would
silently drop every unit outside the player's own LOS -- exactly the units a
mission draft is about.
]]

--------------------------------------------------------------------------------
-- Tunables
--------------------------------------------------------------------------------

local OUT_ROOT = "Terraform Brush/Captures/"
local SETTLE_FRAMES = 2 -- frames to let a camera move land before sampling
local TILE_SCREEN_FRAC = 0.80 -- fraction of the short screen axis a tile may cover
local CAPTURE_FOV = 30 -- narrow FOV keeps the walk near-orthographic (less occlusion)
local FIT_MARGIN = 0.04 -- NDC slack required around a tile before we accept the frame
local FIT_MAX_TRIES = 6
local SPRITES_PER_FRAME = 4
local MAX_TEX_FALLBACK = 8192 -- used when GL_MAX_TEXTURE_SIZE cannot be queried
local GL_MAX_TEXTURE_SIZE = 0x0D33
-- Second ceiling beside GL_MAX_TEXTURE_SIZE: gl.SaveImage reads the whole mosaic
-- back into RAM (4 bytes/px) and then PNG-encodes it, so a target that allocates
-- fine on the GPU can still fail on the readback. 120 MPix ~= 480 MB.
local MAX_OUT_PIXELS = 120e6
-- Readback chunk used when a whole-image save is refused; the mosaic is re-cut
-- into horizontal bands of roughly this many pixels each.
local BAND_PIXELS = 24e6
local SPRITE_MAX_PX = 256 -- raster ceiling per sprite (SVG size is what it is)

local floor, ceil, min, max, abs = math.floor, math.ceil, math.min, math.max, math.abs
local sqrt, pi = math.sqrt, math.pi
local format = string.format
local Echo = Spring.Echo

--------------------------------------------------------------------------------
-- Settings (mirrored into the Terraform Brush UI through WG.TerraformCapture)
--------------------------------------------------------------------------------

local settings = {
	detail = 1, -- output pixels per elmo: 0.5 / 1 / 2
	photoWater = true,
	photoShadows = true,
	photoBloom = true,
	photoFog = false,
	photoFeatures = true, -- features baked into the photo
	unitLayer = true,
	unitStyle = "portrait", -- "portrait" (buildpic tile) | "topdown" (model render)
	unitSize = 96, -- sprite px at detail 1x; scales with detail so it stays map-relative
	unitScaling = 0.35, -- 0 = every sprite equal, 1 = fully proportional to footprint
	unitGroupTeam = true,
	unitLabels = false,
	featureLayer = false, -- features ALSO as their own movable SVG layer
	commentLayer = false,
}

--------------------------------------------------------------------------------
-- Base64 (SVG images must be inlined -- Figma will not fetch local files)
--------------------------------------------------------------------------------

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64chunks = {}

local function base64(data)
	local n = #data
	local out, oi = b64chunks, 0
	for i = 1, n - 2, 3 do
		local a, b, c = data:byte(i, i + 2)
		local v = a * 65536 + b * 256 + c
		oi = oi + 1
		out[oi] = B64:sub(floor(v / 262144) + 1, floor(v / 262144) + 1)
			.. B64:sub(floor(v / 4096) % 64 + 1, floor(v / 4096) % 64 + 1)
			.. B64:sub(floor(v / 64) % 64 + 1, floor(v / 64) % 64 + 1)
			.. B64:sub(v % 64 + 1, v % 64 + 1)
	end
	local tail = n % 3
	if tail == 1 then
		local a = data:byte(n)
		local v = a * 16
		oi = oi + 1
		out[oi] = B64:sub(floor(v / 64) + 1, floor(v / 64) + 1) .. B64:sub(v % 64 + 1, v % 64 + 1) .. "=="
	elseif tail == 2 then
		local a, b = data:byte(n - 1, n)
		local v = a * 1024 + b * 4
		oi = oi + 1
		out[oi] = B64:sub(floor(v / 4096) + 1, floor(v / 4096) + 1)
			.. B64:sub(floor(v / 64) % 64 + 1, floor(v / 64) % 64 + 1)
			.. B64:sub(v % 64 + 1, v % 64 + 1)
			.. "="
	end
	local s = table.concat(out, "", 1, oi)
	for i = 1, oi do
		out[i] = nil
	end
	return s
end

local function xmlEscape(s)
	return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------

local VERT_SRC = [[
	#version 150 compatibility
	void main() {
		gl_TexCoord[0] = gl_MultiTexCoord0;
		gl_Position = gl_Vertex;
	}
]]

-- Reprojection: output texel -> world XZ -> ground Y -> clip -> screen UV.
-- Anything off-screen/off-map/behind the camera writes transparent, which shows
-- up as a hole in the mosaic and is caught by the per-tile fit check.
local REPROJ_FRAG = [[
	#version 150 compatibility
	uniform sampler2D screenTex;
	uniform sampler2D heightMap;
	uniform vec2 worldOrigin;
	uniform vec2 worldExtent;
	uniform vec2 mapSize;
	uniform mat4 viewProj;
	uniform float clampWater;   // 1 = sample the water surface over submerged ground

	void main() {
		vec2 uv  = gl_TexCoord[0].st;
		vec2 wxz = worldOrigin + uv * worldExtent;

		vec2 hUV = clamp(wxz / mapSize, vec2(0.0), vec2(1.0));
		float wy = texture2D(heightMap, hUV).x;
		// Submerged ground projects to the seabed while the screen shows the
		// water plane above it; clamping to y=0 samples the surface instead of
		// dragging a displaced seabed pixel up into the photo.
		if (clampWater > 0.5) wy = max(wy, 0.0);

		vec4 clip = viewProj * vec4(wxz.x, wy, wxz.y, 1.0);
		if (clip.w <= 0.0) { gl_FragColor = vec4(0.0); return; }

		vec2 sUV = (clip.xy / clip.w) * 0.5 + 0.5;
		if (sUV.x < 0.0 || sUV.x > 1.0 || sUV.y < 0.0 || sUV.y > 1.0) { gl_FragColor = vec4(0.0); return; }

		gl_FragColor = vec4(texture2D(screenTex, sUV).rgb, 1.0);
	}
]]

-- Buildpic tile: rounded-rect team-coloured frame with the portrait inset,
-- matching the picture-in-picture minimap's unitpic look.
local SPRITE_FRAG = [[
	#version 150 compatibility
	uniform sampler2D pic;
	uniform vec3 teamCol;
	uniform float sizePx;
	uniform float borderPx;
	uniform float radiusPx;
	uniform float inset;

	float roundedBox(vec2 p, vec2 b, float r) {
		return length(max(abs(p) - b + r, 0.0)) - r;
	}

	void main() {
		vec2 uv = gl_TexCoord[0].st;
		vec2 p  = (uv * 2.0 - 1.0) * (sizePx * 0.5);
		vec2 b  = vec2(sizePx * 0.5 - 1.0);

		float dOuter = roundedBox(p, b, radiusPx);
		float aOuter = 1.0 - smoothstep(-1.0, 1.0, dOuter);
		if (aOuter <= 0.0) { gl_FragColor = vec4(0.0); return; }

		float dInner = roundedBox(p, b - vec2(borderPx), max(radiusPx - borderPx, 1.0));
		float aInner = 1.0 - smoothstep(-1.0, 1.0, dInner);

		vec2 picUV = mix(vec2(inset), vec2(1.0 - inset), uv);
		vec3 rgb   = mix(teamCol, texture2D(pic, picUV).rgb, aInner);
		gl_FragColor = vec4(rgb, aOuter);
	}
]]

-- Plan-view model sprites. gl.UnitShape with rawState=true runs the model's
-- DrawStatic() and nothing else -- no shader, no textures, no team colour --
-- which rasterises a flat white hull. rawState=false is not the answer either:
-- the engine's setup path RESETS the projection and modelview matrices, which
-- throws away the orthographic transform this bake depends on and renders
-- nothing. So we keep rawState=true, push the model's textures by hand, and
-- supply this shader.
--
-- gl.UnitShape scopes to the LEGACY model drawer, so the fixed-function vertex
-- aliases are valid here (same as modelmaterials/Templates/defaultMaterialTemplate.lua).
-- Team colour lives in the diffuse ALPHA channel, not a second texture:
-- mix(texColor1.rgb, teamColor.rgb, texColor1.a), per cus_gl4.frag.glsl.
local MODEL_VERT = [[
	#version 150 compatibility
	varying vec3 vNormal;
	void main() {
		gl_TexCoord[0] = gl_MultiTexCoord0;
		vNormal = gl_NormalMatrix * gl_Normal;
		gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
	}
]]

local MODEL_FRAG = [[
	#version 150 compatibility
	uniform sampler2D tex0;
	uniform vec3 teamCol;
	varying vec3 vNormal;

	void main() {
		vec4 t = texture2D(tex0, gl_TexCoord[0].st);
		vec3 albedo = mix(t.rgb, teamCol, t.a);
		// Fixed key light from above-front: there is no sun uniform on this path,
		// and a plan view wants readable shape over matching in-game lighting.
		float ndl = clamp(dot(normalize(vNormal), normalize(vec3(0.35, 1.0, 0.25))), 0.0, 1.0);
		gl_FragColor = vec4(albedo * (0.55 + 0.45 * ndl), 1.0);
	}
]]

local reprojShader, spriteShader, modelShader
local uRe, uSp, uMdl = {}, {}, {}

local function initShaders()
	if reprojShader == nil then
		reprojShader = gl.CreateShader({
			vertex = VERT_SRC,
			fragment = REPROJ_FRAG,
			uniformInt = { screenTex = 0, heightMap = 1 },
			uniformFloat = { worldOrigin = { 0, 0 }, worldExtent = { 1, 1 }, mapSize = { 1, 1 }, clampWater = 1 },
		})
		if not reprojShader or reprojShader == 0 then
			Echo("[TF Capture] reprojection shader failed: " .. tostring(gl.GetShaderLog()))
			reprojShader = false
		else
			for _, n in ipairs({ "worldOrigin", "worldExtent", "mapSize", "viewProj", "clampWater" }) do
				uRe[n] = gl.GetUniformLocation(reprojShader, n)
			end
		end
	end
	if spriteShader == nil then
		spriteShader = gl.CreateShader({
			vertex = VERT_SRC,
			fragment = SPRITE_FRAG,
			uniformInt = { pic = 0 },
			uniformFloat = { teamCol = { 1, 1, 1 }, sizePx = 96, borderPx = 4, radiusPx = 14, inset = 0.1 },
		})
		if not spriteShader or spriteShader == 0 then
			Echo("[TF Capture] sprite shader failed: " .. tostring(gl.GetShaderLog()))
			spriteShader = false
		else
			for _, n in ipairs({ "teamCol", "sizePx", "borderPx", "radiusPx", "inset" }) do
				uSp[n] = gl.GetUniformLocation(spriteShader, n)
			end
		end
	end
	if modelShader == nil then
		modelShader = gl.CreateShader({
			vertex = MODEL_VERT,
			fragment = MODEL_FRAG,
			uniformInt = { tex0 = 0 },
			uniformFloat = { teamCol = { 1, 1, 1 } },
		})
		if not modelShader or modelShader == 0 then
			Echo("[TF Capture] model shader failed: " .. tostring(gl.GetShaderLog()))
			modelShader = false
		else
			uMdl.teamCol = gl.GetUniformLocation(modelShader, "teamCol")
		end
	end
	-- The model shader is only needed by the plan-view sprite mode, so a failure
	-- there must not block a portrait capture.
	return (reprojShader and spriteShader) and true or false
end

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------

local maxTexSize
local function getMaxTexSize()
	if maxTexSize then
		return maxTexSize
	end
	local ok, v = pcall(gl.GetNumber, GL_MAX_TEXTURE_SIZE)
	if ok and type(v) == "number" and v >= 1024 then
		maxTexSize = floor(v)
	elseif ok and type(v) == "table" and tonumber(v[1]) then
		maxTexSize = floor(v[1])
	else
		maxTexSize = MAX_TEX_FALLBACK
	end
	return maxTexSize
end

local function sanitize(s)
	s = tostring(s or ""):gsub("[^%w%-_]+", "_"):gsub("^_+", ""):gsub("_+$", "")
	return (s ~= "") and s or "map"
end

local function mapBaseName()
	-- Generated canvases carry a per-restart uniquifier ("... s<time>"); strip it
	-- so repeated captures of the same canvas sort together on disk.
	local name = Game.mapName or "map"
	local mo = Spring.GetMapOptions()
	if type(mo) == "table" and ((tonumber(mo.blank_map_x) or 0) > 0 or (tonumber(mo.blank_map_y) or 0) > 0) then
		name = name:match("^(.-) s%d+$") or name
	end
	return sanitize(name)
end

local function writeText(path, text)
	local f = io.open(path, "wb")
	if not f then
		return nil
	end
	f:write(text)
	f:close()
	return #text
end

local function readBinary(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local d = f:read("*a")
	f:close()
	return d
end

-- gl.GetMatrixData returns column-major, so clip.x = m1*x + m5*y + m9*z + m13.
local function projectPoint(m, x, y, z)
	local cx = m[1] * x + m[5] * y + m[9] * z + m[13]
	local cy = m[2] * x + m[6] * y + m[10] * z + m[14]
	local cw = m[4] * x + m[8] * y + m[12] * z + m[16]
	return cx, cy, cw
end

--------------------------------------------------------------------------------
-- Capture job state
--------------------------------------------------------------------------------

local job = nil -- nil when idle
local status =
	{ active = false, phase = "", step = 0, total = 0, message = "", lastPath = "", lastSummary = "", error = "" }

-- The camera state that actually points straight down is resolved empirically
-- once per session: the tilt field and its sign differ between camera
-- controllers, and guessing wrong would silently produce oblique tiles.
local downCam = nil

local function setStatus(phase, stepN, totalN, msg)
	status.phase = phase
	status.step = stepN or 0
	status.total = totalN or 0
	if msg then
		status.message = msg
	end
end

--------------------------------------------------------------------------------
-- Estimation (drives the live readout in the Capture window)
--------------------------------------------------------------------------------

local function estimate(detail)
	detail = tonumber(detail) or settings.detail
	local mapX, mapZ = Game.mapSizeX, Game.mapSizeZ
	local cap = getMaxTexSize()

	-- Only the WIDTH is a hard limit. A full-height mosaic is attempted first
	-- because it yields a single PNG, but when it will not allocate the capture
	-- falls back to one strip per tile row -- and a strip is only outW wide, so
	-- output height is unbounded.
	local effective = detail
	local capped = false
	local widthLimit = cap / mapX
	if effective > widthLimit then
		effective = max(0.05, floor(widthLimit * 100) / 100)
		capped = true
	end

	local outW = max(1, floor(mapX * effective + 0.5))
	local outH = max(1, floor(mapZ * effective + 0.5))
	-- Mirrors the choice phasePrep makes, so the readout can warn up front.
	local strips = (outH > cap) or ((outW * outH) > MAX_OUT_PIXELS)

	local vsx, vsy = Spring.GetViewGeometry()
	local tileScreenPx = max(256, floor(min(vsx or 1920, vsy or 1080) * TILE_SCREEN_FRAC))
	local tileSpan = tileScreenPx / effective
	local tilesX = max(1, ceil(mapX / tileSpan))
	local tilesZ = max(1, ceil(mapZ / tileSpan))
	local tiles = tilesX * tilesZ

	return {
		detail = detail,
		effectiveDetail = effective,
		capped = capped,
		maxTex = cap,
		strips = strips,
		outW = outW,
		outH = outH,
		tilesX = tilesX,
		tilesZ = tilesZ,
		tiles = tiles,
		-- Each tile costs a camera move plus its settle frames.
		seconds = (tiles * (SETTLE_FRAMES + 1)) / 60,
	}
end

--------------------------------------------------------------------------------
-- Scene state save / restore
--------------------------------------------------------------------------------

-- Everything the walk changes is restored through this one function, which also
-- runs from Shutdown and from the cancel path: a capture that dies half way
-- through must never leave the session with invisible units.
local function restoreScene()
	local j = job
	if not j or not j.sceneChanged then
		return
	end
	j.sceneChanged = false

	if j.hiddenUnits then
		for i = 1, #j.hiddenUnits do
			pcall(Spring.SetUnitNoDraw, j.hiddenUnits[i], false)
		end
		j.hiddenUnits = nil
	end
	if j.hiddenFeatures then
		for i = 1, #j.hiddenFeatures do
			pcall(Spring.SetFeatureNoDraw, j.hiddenFeatures[i], false)
		end
		j.hiddenFeatures = nil
	end
	if j.savedFog then
		pcall(Spring.SetAtmosphere, { fogStart = j.savedFog[1], fogEnd = j.savedFog[2] })
		j.savedFog = nil
	end
	if j.savedWater then
		pcall(Spring.SendCommands, "water " .. j.savedWater)
		j.savedWater = nil
	end
	if j.savedShadows then
		pcall(Spring.SendCommands, "shadows " .. j.savedShadows)
		j.savedShadows = nil
	end
	if j.bloomDisabled then
		pcall(function()
			widgetHandler:EnableWidget("Bloom Shader Deferred")
		end)
		j.bloomDisabled = nil
	end
	if j.savedSampleRate then
		pcall(Spring.SetConfigFloat, "MinSampleShadingRate", j.savedSampleRate)
		j.savedSampleRate = nil
	end
	if j.guiHidden then
		pcall(Spring.SendCommands, "hideinterface 0")
		j.guiHidden = nil
	end
	if j.savedCam then
		pcall(Spring.SetCameraState, j.savedCam, 0)
		j.savedCam = nil
	end
end

local function prepareScene()
	local j = job
	j.savedCam = Spring.GetCameraState()
	j.sceneChanged = true

	-- Units are the separate layer, so they must not appear in the photo.
	-- Only IDs we actually touched get restored, so a unit hidden by some other
	-- gadget (transportees, pre-spawn) is left to that gadget.
	local hidden = {}
	local units = Spring.GetAllUnits() or {}
	for i = 1, #units do
		if pcall(Spring.SetUnitNoDraw, units[i], true) then
			hidden[#hidden + 1] = units[i]
		end
	end
	j.hiddenUnits = hidden

	if not settings.photoFeatures then
		local hf = {}
		local feats = Spring.GetAllFeatures() or {}
		for i = 1, #feats do
			if pcall(Spring.SetFeatureNoDraw, feats[i], true) then
				hf[#hf + 1] = feats[i]
			end
		end
		j.hiddenFeatures = hf
	end

	-- Fog only ever gets forced OFF. Turning it back "on" would mean inventing a
	-- density the session never had, so an enabled toggle just leaves it alone.
	if not settings.photoFog then
		local fs, fe = gl.GetAtmosphere("fogStart"), gl.GetAtmosphere("fogEnd")
		if fs and fe then
			j.savedFog = { fs, fe }
			pcall(Spring.SetAtmosphere, { fogStart = 1.99, fogEnd = 2.0 })
		end
	end
	if not settings.photoWater then
		j.savedWater = Spring.GetConfigInt("Water", 4)
		pcall(Spring.SendCommands, "water 0")
	end
	if not settings.photoShadows then
		j.savedShadows = Spring.GetConfigInt("Shadows", 1)
		pcall(Spring.SendCommands, "shadows 0")
	end
	if not settings.photoBloom then
		local w = widgetHandler:FindWidget("Bloom Shader Deferred")
		if w then
			j.bloomDisabled = true
			pcall(function()
				widgetHandler:DisableWidget("Bloom Shader Deferred")
			end)
		end
	end

	-- Per-sample shading is the only supersampling lever Lua has: there is no way
	-- to re-render the world offscreen, and MSAALevel changes need a device reset.
	-- It only bites when MSAA is already on, and costs nothing when it is not.
	j.savedSampleRate = Spring.GetConfigFloat("MinSampleShadingRate", 0.0)
	pcall(Spring.SetConfigFloat, "MinSampleShadingRate", 1.0)

	-- World-space widget overlays (healthbars, ranges, selection) would otherwise
	-- be sampled straight into the photo.
	j.guiHidden = true
	pcall(Spring.SendCommands, "hideinterface 1")
end

--------------------------------------------------------------------------------
-- Camera
--------------------------------------------------------------------------------

-- Vertical component of where the camera is actually pointing. Asking the engine
-- beats deriving it from the view matrix: no row/column convention to get wrong,
-- and this is the value the probe's whole correctness rests on.
local function cameraDownness()
	local dx, dy, dz = Spring.GetCameraDirection()
	if not dy then
		local m = { gl.GetMatrixData("view") }
		if #m ~= 16 then
			return nil
		end
		return -m[7]
	end
	local len = sqrt((dx or 0) ^ 2 + dy ^ 2 + (dz or 0) ^ 2)
	return (len > 0) and (dy / len) or dy
end

local DOWN_CANDIDATES = {
	{ name = "ta", mode = 1, tilt = "angle", value = 0 },
	{ name = "ta", mode = 1, tilt = "angle", value = -pi * 0.5 },
	{ name = "ta", mode = 1, tilt = "angle", value = pi * 0.5 },
	{ name = "spring", mode = 2, tilt = "rx", value = pi * 0.5 },
	{ name = "spring", mode = 2, tilt = "rx", value = -pi * 0.5 },
	{ name = "spring", mode = 2, tilt = "rx", value = pi },
}

local function applyCam(cand, cx, cz, groundY, height)
	local cs = { name = cand.name, mode = cand.mode, fov = CAPTURE_FOV, px = cx, py = groundY, pz = cz }
	cs[cand.tilt] = cand.value
	if cand.name == "ta" then
		cs.height = height
		cs.flipped = 1
	else
		cs.dist = height
		cs.ry = 0
		cs.rz = 0
	end
	pcall(Spring.SetCameraState, cs, 0)
end

--------------------------------------------------------------------------------
-- Tile capture
--------------------------------------------------------------------------------

-- True when the tile's world AABB (both height extremes at all four corners)
-- sits comfortably inside the frustum. Cheaper and far more reliable than
-- trusting a computed altitude: tall terrain near the camera eats coverage.
local function tileFits(j, t)
	local m = { gl.GetMatrixData("viewprojection") }
	if #m ~= 16 then
		return false, 2
	end
	local worst = 0
	for _, x in ipairs({ t.wx0, t.wx1 }) do
		for _, z in ipairs({ t.wz0, t.wz1 }) do
			for _, y in ipairs({ j.minH, j.maxH }) do
				local cx, cy, cw = projectPoint(m, x, y, z)
				if cw <= 0 then
					return false, 2
				end
				local ax, ay = abs(cx / cw), abs(cy / cw)
				worst = max(worst, ax, ay)
			end
		end
	end
	return worst <= (1 - FIT_MARGIN), worst
end

local function drawTile(j, t)
	local vsx, vsy = Spring.GetViewGeometry()
	gl.CopyToTexture(j.screenTex, 0, 0, 0, 0, vsx, vsy)

	local vp = { gl.GetMatrixData("viewprojection") }
	if #vp ~= 16 then
		return false
	end

	-- Pixel rect inside the render target, converted to NDC. Image row 0 is world
	-- z=0 (north up), so the tile's low-z edge maps to the target's top. In strip
	-- mode the target is one tile row tall, so rows are offset back to zero.
	local target, originZ, targetH = j.mosaic, 0, j.outH
	if j.stripMode then
		target, originZ, targetH = j.strip, t.rowZ0, j.stripH
	end
	local x0n = (t.px0 / j.outW) * 2 - 1
	local x1n = (t.px1 / j.outW) * 2 - 1
	local yTop = 1 - ((t.pz0 - originZ) / targetH) * 2
	local yBot = 1 - ((t.pz1 - originZ) / targetH) * 2

	gl.RenderToTexture(target, function()
		gl.Blending(false)
		gl.DepthTest(false)
		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PushMatrix()
		gl.LoadIdentity()

		gl.UseShader(reprojShader)
		gl.Uniform(uRe.worldOrigin, t.wx0, t.wz0)
		gl.Uniform(uRe.worldExtent, t.wx1 - t.wx0, t.wz1 - t.wz0)
		gl.Uniform(uRe.mapSize, Game.mapSizeX, Game.mapSizeZ)
		gl.Uniform(uRe.clampWater, settings.photoWater and 1 or 0)
		gl.UniformMatrix(uRe.viewProj, unpack(vp))

		gl.Texture(0, j.screenTex)
		gl.Texture(1, "$heightmap")

		gl.BeginEnd(GL.QUADS, function()
			gl.TexCoord(0, 0)
			gl.Vertex(x0n, yTop, 0)
			gl.TexCoord(1, 0)
			gl.Vertex(x1n, yTop, 0)
			gl.TexCoord(1, 1)
			gl.Vertex(x1n, yBot, 0)
			gl.TexCoord(0, 1)
			gl.Vertex(x0n, yBot, 0)
		end)

		gl.UseShader(0)
		gl.Texture(0, false)
		gl.Texture(1, false)
		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PopMatrix()
		gl.Blending(true)
	end)
	return true
end

-- Write image rows [imgY0, imgY1) of a render target as a PNG. Row 0 is the TOP
-- of the target while glReadPixels counts from the bottom, hence the flipped
-- origin.
--
-- yflip stays at the engine default (true). yflip=false — which the other
-- SaveImage callers in this repo use — skips the bottom-up-to-top-down flip, so
-- every image comes out vertically mirrored: the terrain landed south-up while
-- the unit SVG places y=0 at world z=0, and the two only lined up after
-- mirroring one of them. Wrapped in a pcall because a large readback is exactly
-- where gl.SaveImage gives up, and that has to read as a message, not a crash.
local function saveTargetRegion(tex, w, texH, imgY0, imgY1, path)
	local h = imgY1 - imgY0
	if h <= 0 then
		return false, "empty region"
	end
	local ran, saved = false, false
	local okCall, callErr = pcall(gl.RenderToTexture, tex, function()
		ran = true
		-- Returns boolean? — nil counts as success (older builds return nothing);
		-- only an explicit false is a refusal.
		saved = (gl.SaveImage(0, texH - imgY1, w, h, path, { yflip = true, alpha = false }) ~= false)
	end)
	if okCall and ran and saved then
		return true
	end
	return false,
		(not okCall) and tostring(callErr)
			or (not ran) and "render target could not be bound"
			or "the image encoder refused it"
end

--------------------------------------------------------------------------------
-- Sprite baking
--------------------------------------------------------------------------------

local function teamColor(teamID)
	local r, g, b = Spring.GetTeamColor(teamID)
	if not r then
		return 0.7, 0.7, 0.75
	end
	return r, g, b
end

local function bakePortrait(j, spr)
	local px = spr.px
	local fbo = gl.CreateTexture(px, px, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
	})
	if not fbo then
		return false
	end
	local r, g, b = teamColor(spr.team)
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

		gl.UseShader(spriteShader)
		gl.Uniform(uSp.teamCol, r, g, b)
		gl.Uniform(uSp.sizePx, px)
		gl.Uniform(uSp.borderPx, max(2, px * 0.045))
		gl.Uniform(uSp.radiusPx, px * 0.16)
		gl.Uniform(uSp.inset, 0.1)
		gl.Texture(0, "#" .. spr.defID)

		gl.BeginEnd(GL.QUADS, function()
			gl.TexCoord(0, 1)
			gl.Vertex(-1, -1, 0)
			gl.TexCoord(1, 1)
			gl.Vertex(1, -1, 0)
			gl.TexCoord(1, 0)
			gl.Vertex(1, 1, 0)
			gl.TexCoord(0, 0)
			gl.Vertex(-1, 1, 0)
		end)

		gl.UseShader(0)
		gl.Texture(0, false)
		gl.SaveImage(0, 0, px, px, j.dir .. spr.file, { yflip = true, alpha = true })
		saved = true

		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PopMatrix()
		gl.Blending(true)
	end)

	gl.DeleteTexture(fbo)
	return saved
end

-- Top-down model render. Orthographic from directly above so the sprite is a
-- true plan view at map scale, which is what makes the SVG layer read as a
-- battlefield rather than a legend.
local function bakeTopDown(j, spr)
	if not modelShader then
		return false
	end
	local px = spr.px
	local fbo = gl.CreateTexture(px, px, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
	})
	if not fbo then
		return false
	end
	local half = spr.worldSize * 0.5
	local saved = false

	gl.RenderToTexture(fbo, function()
		gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
		gl.Clear(GL.DEPTH_BUFFER_BIT, 1)
		-- RenderToTexture targets are colour-only, so depth testing may be inert
		-- here; back-face culling is what actually keeps the far side of a closed
		-- model from painting over the near side. Depth stays on for the case
		-- where the driver does give us a depth attachment.
		gl.DepthTest(true)
		gl.Culling(GL.BACK)
		gl.Blending(false)

		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity()
		gl.Ortho(-half, half, -half, half, -half * 8, half * 8)
		gl.MatrixMode(GL.MODELVIEW)
		gl.PushMatrix()
		gl.LoadIdentity()
		-- +90 about X sends world +y to eye +z, i.e. the camera ends up above the
		-- model looking down; world -z lands at the top of the sprite.
		gl.Rotate(90, 1, 0, 0)

		-- rawState stays TRUE so our ortho matrices survive; textures and shading
		-- are supplied here instead. See the MODEL_VERT/MODEL_FRAG note.
		local r, g, b = teamColor(spr.team)
		gl.UnitShapeTextures(spr.defID, true)
		gl.UseShader(modelShader)
		gl.Uniform(uMdl.teamCol, r, g, b)
		gl.UnitShape(spr.defID, spr.team, true, false, true)
		gl.UseShader(0)
		gl.UnitShapeTextures(spr.defID, false)

		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PopMatrix()
		gl.Culling(false)
		gl.DepthTest(false)

		gl.SaveImage(0, 0, px, px, j.dir .. spr.file, { yflip = true, alpha = true })
		saved = true
		gl.Blending(true)
	end)

	gl.DeleteTexture(fbo)
	return saved
end

local function bakeFeature(j, spr)
	if not modelShader then
		return false
	end
	local px = spr.px
	local fbo = gl.CreateTexture(px, px, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
	})
	if not fbo then
		return false
	end
	local half = spr.worldSize * 0.5
	local saved = false

	gl.RenderToTexture(fbo, function()
		gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
		gl.Clear(GL.DEPTH_BUFFER_BIT, 1)
		gl.DepthTest(true)
		gl.Culling(GL.BACK)
		gl.Blending(false)
		gl.MatrixMode(GL.PROJECTION)
		gl.PushMatrix()
		gl.LoadIdentity()
		gl.Ortho(-half, half, -half, half, -half * 8, half * 8)
		gl.MatrixMode(GL.MODELVIEW)
		gl.PushMatrix()
		gl.LoadIdentity()
		gl.Rotate(90, 1, 0, 0)

		-- Same state pairing as bakeTopDown; see the note there. Features carry no
		-- team mask, so the "team" colour just neutralises the mix.
		gl.FeatureShapeTextures(spr.defID, true)
		gl.UseShader(modelShader)
		gl.Uniform(uMdl.teamCol, 0.7, 0.7, 0.7)
		gl.FeatureShape(spr.defID, spr.team or Spring.GetGaiaTeamID(), true, false, true)
		gl.UseShader(0)
		gl.FeatureShapeTextures(spr.defID, false)

		gl.MatrixMode(GL.PROJECTION)
		gl.PopMatrix()
		gl.MatrixMode(GL.MODELVIEW)
		gl.PopMatrix()
		gl.Culling(false)
		gl.DepthTest(false)
		gl.SaveImage(0, 0, px, px, j.dir .. spr.file, { yflip = true, alpha = true })
		saved = true
		gl.Blending(true)
	end)

	gl.DeleteTexture(fbo)
	return saved
end

--------------------------------------------------------------------------------
-- SVG
--------------------------------------------------------------------------------

local function svgHeader(w, h, title)
	return format(
		'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"\n'
			.. '     width="%d" height="%d" viewBox="0 0 %d %d" id="%s">\n',
		w,
		h,
		w,
		h,
		xmlEscape(title)
	)
end

-- One <image> per object. Figma turns each into its own movable layer and takes
-- the layer name from the id, so the id carries the readable label.
local function svgImage(id, x, y, w, h, rotDeg, dataURI)
	local transform = ""
	if rotDeg and abs(rotDeg) > 0.01 then
		transform = format(' transform="rotate(%.2f %.2f %.2f)"', rotDeg, x + w * 0.5, y + h * 0.5)
	end
	return format(
		'  <image id="%s" x="%.2f" y="%.2f" width="%.2f" height="%.2f"%s xlink:href="%s"/>\n',
		xmlEscape(id),
		x,
		y,
		w,
		h,
		transform,
		dataURI
	)
end

local function svgLabel(id, x, y, sizePx, text)
	return format(
		'  <text id="%s" x="%.2f" y="%.2f" font-family="Arial" font-size="%.1f" '
			.. 'fill="#ffffff" stroke="#000000" stroke-width="%.1f" paint-order="stroke" '
			.. 'text-anchor="middle">%s</text>\n',
		xmlEscape(id),
		x,
		y,
		sizePx,
		max(1, sizePx * 0.18),
		xmlEscape(text)
	)
end

--------------------------------------------------------------------------------
-- Job construction
--------------------------------------------------------------------------------

local function buildTiles(j)
	local mapX, mapZ = Game.mapSizeX, Game.mapSizeZ
	local tiles = {}
	for r = 0, j.tilesZ - 1 do
		for c = 0, j.tilesX - 1 do
			-- Integer pixel boundaries derived from the mosaic size (not from
			-- rounding each tile separately) so tiles butt up with no seam pixel.
			local px0 = floor(c * j.outW / j.tilesX + 0.5)
			local px1 = floor((c + 1) * j.outW / j.tilesX + 0.5)
			local pz0 = floor(r * j.outH / j.tilesZ + 0.5)
			local pz1 = floor((r + 1) * j.outH / j.tilesZ + 0.5)
			tiles[#tiles + 1] = {
				-- row/rowZ0/rowH drive strip mode, where each tile row is
				-- rendered and written on its own instead of into one mosaic.
				row = r,
				rowZ0 = pz0,
				rowH = pz1 - pz0,
				lastInRow = (c == j.tilesX - 1),
				px0 = px0,
				px1 = px1,
				pz0 = pz0,
				pz1 = pz1,
				wx0 = px0 / j.outW * mapX,
				wx1 = px1 / j.outW * mapX,
				wz0 = pz0 / j.outH * mapZ,
				wz1 = pz1 / j.outH * mapZ,
			}
		end
	end
	j.tiles = tiles
	j.maxRowH = 0
	for i = 1, #tiles do
		if tiles[i].rowH > j.maxRowH then
			j.maxRowH = tiles[i].rowH
		end
	end
end

local function spriteKey(kind, defID, team)
	return kind .. "_" .. defID .. "_" .. team
end

-- One raster per (def, team): a hundred Pawns share a single PNG on disk, and
-- the SVG inlines that one payload per instance.
local function addSprite(j, kind, defID, team, def)
	local key = spriteKey(kind, defID, team)
	if j.sprites[key] then
		return j.sprites[key]
	end

	local footX = (def.xsize or 8) * 8
	local footZ = (def.zsize or 8) * 8
	local worldSize = max(footX, footZ, (def.radius or 16) * 2)

	local spr = { key = key, kind = kind, defID = defID, team = team, worldSize = worldSize * 1.15 }
	if kind == "portrait" then
		spr.px = min(SPRITE_MAX_PX, max(32, floor(settings.unitSize)))
	else
		spr.px = min(SPRITE_MAX_PX, max(32, floor(spr.worldSize * j.detail + 0.5)))
	end
	spr.file = "sprites/" .. kind .. "_" .. sanitize(def.name or defID) .. "_t" .. team .. ".png"
	j.sprites[key] = spr
	j.spriteList[#j.spriteList + 1] = spr
	return spr
end

--------------------------------------------------------------------------------
-- Phases
--------------------------------------------------------------------------------

local function finish(err)
	restoreScene()
	local j = job
	if j then
		if j.mosaic then
			gl.DeleteTexture(j.mosaic)
			j.mosaic = nil
		end
		if j.strip then
			gl.DeleteTexture(j.strip)
			j.strip = nil
		end
		if j.screenTex then
			gl.DeleteTexture(j.screenTex)
			j.screenTex = nil
		end
	end
	job = nil
	status.active = false
	status.phase = err and "error" or "done"
	status.error = err or ""
	if err then
		status.message = err
		Echo("[TF Capture] failed: " .. err)
	end
end

local function phaseCollect(j)
	if not j.unitsRequested then
		if not settings.unitLayer then
			j.unitsRequested, j.units, j.unitsDone = true, {}, true
			return
		end

		-- The unit list comes from Map Project's synced round-trip, and that
		-- widget ships disabled. Enable it ourselves rather than failing the
		-- headline feature on a dependency the user never chose to skip, then
		-- give it one frame to publish WG.MapProject.
		if not (WG.MapProject and WG.MapProject.requestUnits) then
			if not j.mapProjectEnableTried then
				j.mapProjectEnableTried = true
				setStatus("collect", 0, 0, "loading Map Project...")
				pcall(function()
					widgetHandler:EnableWidget("Map Project")
				end)
				return
			end
			j.unitsRequested, j.units, j.unitsDone = true, {}, true
			j.unitsError = "could not enable the Map Project widget -- unit layer skipped"
			return
		end

		j.unitsRequested = true
		j.collectTicks = 0
		setStatus("collect", 0, 0, "reading unit list...")
		WG.MapProject.requestUnits(function(list, err)
			if err then
				j.unitsError = err
				j.units = {}
			else
				j.units = list or {}
			end
			j.unitsDone = true
		end)
		return
	end

	j.collectTicks = (j.collectTicks or 0) + 1
	if not j.unitsDone then
		if j.collectTicks > 300 then
			j.unitsError = "unit export timed out"
			j.units = {}
			j.unitsDone = true
		else
			return
		end
	end

	-- Features are not LOS-gated the way units are, so a plain widget-side walk
	-- is enough for the separate feature layer.
	j.features = {}
	if settings.featureLayer then
		local ids = Spring.GetAllFeatures() or {}
		for i = 1, #ids do
			local fid = ids[i]
			local defID = Spring.GetFeatureDefID(fid)
			local def = defID and FeatureDefs[defID]
			local x, _, z = Spring.GetFeaturePosition(fid)
			if def and x then
				j.features[#j.features + 1] = {
					defID = defID,
					def = def,
					x = x,
					z = z,
					rot = Spring.GetFeatureHeading(fid) or 0,
				}
			end
		end
	end

	j.phase = "prep"
end

local function phasePrep(j)
	if not initShaders() then
		return finish("shader compile failed (see console)")
	end

	-- One mosaic is preferred (it yields a single PNG), but a full-resolution
	-- target is hundreds of MB and the allocation is allowed to fail. Falling
	-- back to one tile row at a time keeps VRAM at a few tens of MB and keeps
	-- the capture working at any resolution; the cost is one PNG per row.
	local cap = getMaxTexSize()
	local trySingle = (j.outH <= cap) and ((j.outW * j.outH) <= MAX_OUT_PIXELS)
	j.mosaic = trySingle
			and gl.CreateTexture(j.outW, j.outH, {
				border = false,
				min_filter = GL.LINEAR,
				mag_filter = GL.LINEAR,
				wrap_s = GL.CLAMP_TO_EDGE,
				wrap_t = GL.CLAMP_TO_EDGE,
				fbo = true,
			})
		or nil
	if j.mosaic then
		gl.RenderToTexture(j.mosaic, function()
			gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
		end)
	else
		j.stripMode = true
		j.stripH = j.maxRowH
		Echo(
			format(
				"[TF Capture] %dx%d in one piece needs %d MB; writing one %dx%d strip per tile row instead",
				j.outW,
				j.outH,
				floor(j.outW * j.outH * 4 / 1048576),
				j.outW,
				j.stripH
			)
		)
		local probe = gl.CreateTexture(j.outW, j.stripH, {
			border = false,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true,
		})
		if not probe then
			return finish(format("could not allocate even a %dx%d strip -- lower the detail setting", j.outW, j.stripH))
		end
		gl.DeleteTexture(probe)
	end
	j.terrainFiles = {}

	local vsx, vsy = Spring.GetViewGeometry()
	j.screenTex = gl.CreateTexture(vsx, vsy, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
	if not j.screenTex then
		return finish("could not allocate screen copy texture")
	end

	local iMin, iMax, cMin, cMax = Spring.GetGroundExtremes()
	j.minH = min(iMin or 0, cMin or 0, 0)
	j.maxH = max(iMax or 100, cMax or 100, 1)

	Spring.CreateDir(OUT_ROOT)
	Spring.CreateDir(j.dir)
	Spring.CreateDir(j.dir .. "sprites/")

	prepareScene()
	j.phase = downCam and "tiles" or "probe"
	j.probeIndex = 0
	j.probeBest = nil
	j.settle = 0
	j.tileIndex = 1
	j.fitTries = 0
	setStatus("prepare", 0, #j.tiles, "preparing scene...")
end

-- Try each controller/tilt combination once and keep whichever actually looks
-- most steeply downward. Cheaper than encoding per-controller sign conventions,
-- and it cannot silently pick an oblique camera.
local function phaseProbe(j)
	if j.settle > 0 then
		j.settle = j.settle - 1
		return
	end
	if j.probeIndex > 0 then
		local fy = cameraDownness()
		if fy and (not j.probeBest or fy < j.probeBest.fy) then
			j.probeBest = { cand = DOWN_CANDIDATES[j.probeIndex], fy = fy }
		end
	end
	if j.probeIndex >= #DOWN_CANDIDATES then
		if not j.probeBest or j.probeBest.fy > -0.9 then
			return finish("could not point the camera straight down (camera controller refused)")
		end
		downCam = j.probeBest.cand
		j.phase = "tiles"
		return
	end
	j.probeIndex = j.probeIndex + 1
	local cand = DOWN_CANDIDATES[j.probeIndex]
	applyCam(cand, Game.mapSizeX * 0.5, Game.mapSizeZ * 0.5, 0, 2000)
	j.settle = SETTLE_FRAMES
	setStatus("probe", j.probeIndex, #DOWN_CANDIDATES, "calibrating camera...")
end

local function phaseTiles(j)
	local t = j.tiles[j.tileIndex]
	if not t then
		j.phase = "save"
		return
	end

	-- Strip mode: open a fresh one-row target when this tile starts a new row.
	if j.stripMode and not j.strip then
		j.strip = gl.CreateTexture(j.outW, j.stripH, {
			border = false,
			min_filter = GL.LINEAR,
			mag_filter = GL.LINEAR,
			wrap_s = GL.CLAMP_TO_EDGE,
			wrap_t = GL.CLAMP_TO_EDGE,
			fbo = true,
		})
		if not j.strip then
			return finish("could not allocate the row strip mid-capture")
		end
		gl.RenderToTexture(j.strip, function()
			gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
		end)
	end

	if not t.posted then
		local cx = (t.wx0 + t.wx1) * 0.5
		local cz = (t.wz0 + t.wz1) * 0.5
		local span = max(t.wx1 - t.wx0, t.wz1 - t.wz0)
		-- Start from the exact perspective fit, then let tileFits correct for
		-- terrain that eats coverage.
		t.height = t.height or (span * 0.5 / math.tan(math.rad(CAPTURE_FOV) * 0.5) * 1.2)
		applyCam(downCam, cx, cz, Spring.GetGroundHeight(cx, cz) or 0, t.height)
		t.posted = true
		j.settle = SETTLE_FRAMES
		setStatus("tiles", j.tileIndex, #j.tiles, format("tile %d / %d", j.tileIndex, #j.tiles))
		return
	end

	if j.settle > 0 then
		j.settle = j.settle - 1
		return
	end

	local fits, worst = tileFits(j, t)
	if not fits then
		j.fitTries = j.fitTries + 1
		if j.fitTries > FIT_MAX_TRIES then
			-- Almost always the camera controller refusing to climb any higher.
			-- Raising the detail shrinks the tiles, which needs LESS altitude.
			return finish(
				format(
					"tile %d never fit on screen -- the camera cannot get high enough; try a higher detail setting (smaller tiles)",
					j.tileIndex
				)
			)
		end
		t.height = t.height * min(2.0, max(1.08, worst / (1 - FIT_MARGIN)))
		t.posted = false
		return
	end

	if not drawTile(j, t) then
		return finish("could not read the view-projection matrix")
	end
	j.tileIndex = j.tileIndex + 1
	j.fitTries = 0

	-- Strip mode: the row is complete, write it and release the target.
	if j.stripMode and t.lastInRow then
		local name = format("terrain_y%d.png", t.rowZ0)
		-- Content sits at the TOP of the strip; glReadPixels counts from the
		-- bottom, hence the stripH - rowH origin.
		local ok, err = saveTargetRegion(j.strip, j.outW, j.stripH, 0, t.rowH, j.dir .. name)
		gl.DeleteTexture(j.strip)
		j.strip = nil
		if not ok then
			return finish(format("could not write %s (%dx%d): %s", name, j.outW, t.rowH, tostring(err)))
		end
		j.terrainFiles[#j.terrainFiles + 1] = { file = name, x = 0, y = t.rowZ0, w = j.outW, h = t.rowH }
	end
end

local function phaseSave(j)
	-- Strip mode already wrote each row as it finished.
	if not j.stripMode then
		local ok, err = saveTargetRegion(j.mosaic, j.outW, j.outH, 0, j.outH, j.dir .. "terrain.png")
		if ok then
			j.terrainFiles[#j.terrainFiles + 1] = { file = "terrain.png", x = 0, y = 0, w = j.outW, h = j.outH }
		else
			-- The mosaic itself rendered fine; only the one-shot readback failed.
			-- Re-cut it into bands from the SAME texture: no re-render, identical
			-- pixels, and each readback is a fraction of the size.
			Echo(
				format(
					"[TF Capture] one-piece save of %dx%d failed (%s); writing bands instead",
					j.outW,
					j.outH,
					tostring(err)
				)
			)
			local bandH = max(256, floor(BAND_PIXELS / j.outW))
			local y = 0
			while y < j.outH do
				local y1 = min(j.outH, y + bandH)
				local name = format("terrain_y%d.png", y)
				local bok, berr = saveTargetRegion(j.mosaic, j.outW, j.outH, y, y1, j.dir .. name)
				if not bok then
					return finish(format("could not write %s (%d\195\151%d): %s", name, j.outW, y1 - y, tostring(berr)))
				end
				j.terrainFiles[#j.terrainFiles + 1] = { file = name, x = 0, y = y, w = j.outW, h = y1 - y }
				y = y1
			end
		end
	end
	if #j.terrainFiles == 0 then
		return finish("no terrain image was written")
	end

	-- The world is only borrowed for the walk; give it back before the (slower)
	-- sprite and SVG work so the session looks normal again as early as possible.
	restoreScene()

	-- Queue sprite bakes now that the unit list is known.
	j.sprites, j.spriteList, j.spriteIndex = {}, {}, 1
	for i = 1, #(j.units or {}) do
		local u = j.units[i]
		local defID = UnitDefNames[u.name] and UnitDefNames[u.name].id
		local def = defID and UnitDefs[defID]
		if def then
			u.defID = defID
			u.def = def
			u.sprite = addSprite(j, settings.unitStyle, defID, u.team or 0, def)
		end
	end
	for i = 1, #(j.features or {}) do
		local f = j.features[i]
		f.sprite = addSprite(j, "feature", f.defID, Spring.GetGaiaTeamID() or 0, f.def)
	end

	j.phase = "sprites"
	setStatus("sprites", 0, #j.spriteList, "rendering unit sprites...")
end

local function phaseSprites(j)
	local done = 0
	while j.spriteIndex <= #j.spriteList and done < SPRITES_PER_FRAME do
		local spr = j.spriteList[j.spriteIndex]
		local ok
		if spr.kind == "portrait" then
			ok = bakePortrait(j, spr)
		elseif spr.kind == "feature" then
			ok = bakeFeature(j, spr)
		else
			ok = bakeTopDown(j, spr)
		end
		spr.baked = ok and true or false
		j.spriteIndex = j.spriteIndex + 1
		done = done + 1
	end
	setStatus(
		"sprites",
		j.spriteIndex - 1,
		#j.spriteList,
		format("sprite %d / %d", min(j.spriteIndex - 1, #j.spriteList), #j.spriteList)
	)
	if j.spriteIndex > #j.spriteList then
		j.phase = "svg"
	end
end

local function spriteDataURI(j, spr)
	if spr.uri ~= nil then
		return spr.uri
	end
	if not spr.baked then
		spr.uri = false
		return false
	end
	local bytes = readBinary(j.dir .. spr.file)
	spr.uri = bytes and ("data:image/png;base64," .. base64(bytes)) or false
	return spr.uri
end

local function phaseSvg(j)
	local written = {}
	for i = 1, #j.terrainFiles do
		written[i] = j.terrainFiles[i].file
	end
	local scale = j.detail -- world elmos -> output pixels

	-- Units -------------------------------------------------------------------
	if settings.unitLayer and j.units and #j.units > 0 then
		local byTeam = {}
		local order = {}
		for i = 1, #j.units do
			local u = j.units[i]
			if u.sprite then
				local key = settings.unitGroupTeam and (u.team or 0) or 0
				if not byTeam[key] then
					byTeam[key] = {}
					order[#order + 1] = key
				end
				local g = byTeam[key]
				g[#g + 1] = u
			end
		end
		table.sort(order)

		local out = { svgHeader(j.outW, j.outH, "Units") }
		local median = 8 * 8
		for _, key in ipairs(order) do
			local groupName = settings.unitGroupTeam and format("Team %d", key) or "Units"
			out[#out + 1] = format(' <g id="%s">\n', xmlEscape(groupName))
			local group = byTeam[key]
			for i = 1, #group do
				local u = group[i]
				local uri = spriteDataURI(j, u.sprite)
				if uri then
					local w
					if settings.unitStyle == "portrait" then
						-- Sprite size is defined at detail 1x and multiplied by the
						-- detail, so a unit covers the same patch of MAP whichever
						-- resolution the photo was taken at.
						local footprint = max((u.def.xsize or 8) * 8, (u.def.zsize or 8) * 8)
						local sizeScale = (footprint / median) ^ settings.unitScaling
						sizeScale = max(0.6, min(2.2, sizeScale))
						w = settings.unitSize * scale * sizeScale
					else
						w = u.sprite.worldSize * scale
					end
					local cx, cy = u.x * scale, u.z * scale
					-- Buildpics are three-quarter art, so rotating them would only
					-- tilt a portrait; plan-view sprites carry the real heading.
					local rot = nil
					if settings.unitStyle ~= "portrait" then
						rot = 180 + (u.rot or 0) * 360 / 65536
					end
					local label = format("%s - %s", u.def.humanName or u.def.name, u.def.name)
					out[#out + 1] = svgImage(label, cx - w * 0.5, cy - w * 0.5, w, w, rot, uri)
					if settings.unitLabels then
						out[#out + 1] = svgLabel(
							label .. " (label)",
							cx,
							cy + w * 0.5 + w * 0.22,
							max(8, w * 0.2),
							u.def.humanName or u.def.name
						)
					end
				end
			end
			out[#out + 1] = " </g>\n"
		end
		out[#out + 1] = "</svg>\n"
		if writeText(j.dir .. "units.svg", table.concat(out)) then
			written[#written + 1] = "units.svg"
		end
	end

	-- Features ----------------------------------------------------------------
	if settings.featureLayer and j.features and #j.features > 0 then
		local out = { svgHeader(j.outW, j.outH, "Features"), ' <g id="Features">\n' }
		for i = 1, #j.features do
			local f = j.features[i]
			local uri = f.sprite and spriteDataURI(j, f.sprite)
			if uri then
				local w = f.sprite.worldSize * scale
				local cx, cy = f.x * scale, f.z * scale
				out[#out + 1] = svgImage(
					format("%s - %s", f.def.humanName or f.def.name, f.def.name),
					cx - w * 0.5,
					cy - w * 0.5,
					w,
					w,
					180 + (f.rot or 0) * 360 / 65536,
					uri
				)
			end
		end
		out[#out + 1] = " </g>\n</svg>\n"
		if writeText(j.dir .. "features.svg", table.concat(out)) then
			written[#written + 1] = "features.svg"
		end
	end

	-- Comments ----------------------------------------------------------------
	if settings.commentLayer and WG.MapLabels and WG.MapLabels.getLabels then
		local labels = WG.MapLabels.getLabels() or {}
		if #labels > 0 then
			local out = { svgHeader(j.outW, j.outH, "Comments"), ' <g id="Comments">\n' }
			local r = max(6, 14 * scale)
			for i = 1, #labels do
				local L = labels[i]
				local cx, cy = L.x * scale, L.z * scale
				out[#out + 1] = format(
					'  <circle id="pin %d" cx="%.2f" cy="%.2f" r="%.2f" fill="%s" stroke="#000000" stroke-width="%.2f"/>\n',
					L.id or i,
					cx,
					cy,
					r,
					xmlEscape(L.color or "#ffcc00"),
					max(1, r * 0.15)
				)
				if L.text and L.text ~= "" then
					out[#out + 1] = svgLabel(format("comment %d", L.id or i), cx, cy - r * 1.6, max(9, r * 1.1), L.text)
				end
			end
			out[#out + 1] = " </g>\n</svg>\n"
			if writeText(j.dir .. "comments.svg", table.concat(out)) then
				written[#written + 1] = "comments.svg"
			end
		end
	end

	-- Manifest ----------------------------------------------------------------
	local meta = {
		"return {",
		format("\tmap = %q,", Game.mapName or ""),
		format("\tmapSizeX = %d, mapSizeZ = %d,", Game.mapSizeX, Game.mapSizeZ),
		format("\timageW = %d, imageH = %d,", j.outW, j.outH),
		format("\tpixelsPerElmo = %.6f,", j.detail),
		format("\ttiles = %d,", #j.tiles),
		format("\tunitStyle = %q,", settings.unitStyle),
		format("\tunits = %d,", #(j.units or {})),
		"\t-- image pixel = world elmo * pixelsPerElmo; row 0 is world z = 0",
		"\t-- terrain: place each file at its x/y in a canvas of imageW x imageH",
		"\tterrain = {",
	}
	for i = 1, #j.terrainFiles do
		local f = j.terrainFiles[i]
		meta[#meta + 1] = format("\t\t{ file = %q, x = %d, y = %d, w = %d, h = %d },", f.file, f.x, f.y, f.w, f.h)
	end
	meta[#meta + 1] = "\t},"
	meta[#meta + 1] = "}"
	writeText(j.dir .. "capture.lua", table.concat(meta, "\n") .. "\n")
	written[#written + 1] = "capture.lua"

	status.lastPath = j.dir
	-- Short enough to sit on the result bar's header line next to "SAVED".
	local unitCount = #(j.units or {})
	status.lastSummary = format("%d\195\151%d px", j.outW, j.outH)
	if #j.terrainFiles > 1 then
		status.lastSummary = status.lastSummary .. format(" in %d strips", #j.terrainFiles)
	end
	if unitCount > 0 then
		status.lastSummary = status.lastSummary .. format(" \194\183 %d units", unitCount)
	end

	Echo(
		format(
			"[TF Capture] wrote %s (%dx%d in %d image%s, %d tiles, %d units, %d sprites)",
			j.dir,
			j.outW,
			j.outH,
			#j.terrainFiles,
			(#j.terrainFiles == 1) and "" or "s",
			#j.tiles,
			unitCount,
			#j.spriteList
		)
	)
	if #j.terrainFiles > 1 then
		Echo("[TF Capture] terrain came out as strips; each filename carries its Y offset (x is always 0)")
	end
	if j.unitsError then
		Echo("[TF Capture] unit layer: " .. j.unitsError)
	end
	setStatus("done", 1, 1, format("%d x %d px -> %s", j.outW, j.outH, j.dir))
	finish(nil)
end

--------------------------------------------------------------------------------
-- Driver
--------------------------------------------------------------------------------

local function startCapture()
	if job then
		return false, "a capture is already running"
	end
	if Spring.IsGUIHidden and Spring.IsGUIHidden() then
		return false, "hide-interface is on; turn it off first"
	end

	local est = estimate(settings.detail)
	local stamp = os.date("%Y-%m-%d_%H-%M-%S")
	job = {
		phase = "collect",
		dir = OUT_ROOT .. mapBaseName() .. "_" .. stamp .. "/",
		detail = est.effectiveDetail,
		outW = est.outW,
		outH = est.outH,
		tilesX = est.tilesX,
		tilesZ = est.tilesZ,
		sprites = {},
		spriteList = {},
		spriteIndex = 1,
		settle = 0,
		tileIndex = 1,
		fitTries = 0,
	}
	buildTiles(job)
	status.active = true
	status.error = ""
	status.lastPath = ""
	status.lastSummary = ""
	setStatus("collect", 0, #job.tiles, "starting...")
	if est.capped then
		Echo(
			format(
				"[TF Capture] %.2fx is wider than the %d px texture limit -- capped to %.2fx (%dx%d)",
				est.detail,
				est.maxTex,
				est.effectiveDetail,
				est.outW,
				est.outH
			)
		)
	end
	return true
end

local PHASES = {
	collect = phaseCollect,
	prep = phasePrep,
	probe = phaseProbe,
	tiles = phaseTiles,
	save = phaseSave,
	sprites = phaseSprites,
	svg = phaseSvg,
}

-- Everything runs from DrawScreenEffects: it is the one callin that is both
-- allowed to gl.RenderToTexture and guaranteed to see the finished world frame
-- (bloom draws last in DrawWorld) without any interface on top of it yet.
-- The status bar has room for one line, and a bare GL error message is useless
-- without knowing which call raised it, so the traceback is attached here and
-- echoed to the console/infolog.
local function phaseTraceback(err)
	local tb = (debug and debug.traceback) and debug.traceback("", 2) or "(no traceback available)"
	return tostring(err) .. "\n" .. tb
end

function widget:DrawScreenEffects()
	if not job then
		return
	end
	local phase = job.phase
	local fn = PHASES[phase]
	if not fn then
		return finish("internal phase error: " .. tostring(phase))
	end
	local ok, err = xpcall(function()
		return fn(job)
	end, phaseTraceback)
	if not ok then
		Echo("[TF Capture] crash in phase '" .. tostring(phase) .. "':\n" .. tostring(err))
		finish("crashed in phase " .. tostring(phase) .. " -- traceback in console (F10)")
	end
end

function widget:DrawScreen()
	if not job then
		return
	end
	local vsx, vsy = Spring.GetViewGeometry()
	local x, y = vsx * 0.5, vsy * 0.82
	gl.Color(0, 0, 0, 0.6)
	gl.Rect(x - 180, y - 26, x + 180, y + 34)
	gl.Color(1, 1, 1, 1)
	gl.Text("\255\255\220\120CAPTURING MAP", x, y + 12, 18, "cn")
	gl.Text(status.message or "", x, y - 10, 14, "cn")
	gl.Text("\255\160\160\160Esc to cancel", x, y - 24, 11, "cn")
	gl.Color(1, 1, 1, 1)
end

function widget:KeyPress(key)
	if job and key == 27 then
		finish("cancelled")
		Echo("[TF Capture] cancelled")
		return true
	end
	return false
end

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------

local function captureAction(_, _, params)
	local arg = (type(params) == "table") and params[1] or params
	if arg == "cancel" then
		if job then
			finish("cancelled")
		end
		return true
	end
	local detail = tonumber(arg)
	if detail then
		settings.detail = detail
	end
	local ok, err = startCapture()
	if not ok then
		Echo("[TF Capture] " .. tostring(err))
	end
	return true
end

function widget:Initialize()
	widgetHandler:AddAction("tfcapture", captureAction, nil, "t")
	WG.TerraformCapture = {
		getSettings = function()
			local copy = {}
			for k, v in pairs(settings) do
				copy[k] = v
			end
			return copy
		end,
		setSetting = function(key, value)
			if settings[key] == nil then
				return false
			end
			settings[key] = value
			return true
		end,
		estimate = estimate,
		start = startCapture,
		cancel = function()
			if job then
				finish("cancelled")
			end
		end,
		isBusy = function()
			return job ~= nil
		end,
		getStatus = function()
			return status
		end,
	}
end

function widget:Shutdown()
	-- A reload mid-capture must not leave the scene stripped.
	restoreScene()
	if job then
		if job.mosaic then
			gl.DeleteTexture(job.mosaic)
		end
		if job.strip then
			gl.DeleteTexture(job.strip)
		end
		if job.screenTex then
			gl.DeleteTexture(job.screenTex)
		end
		job = nil
	end
	if reprojShader then
		gl.DeleteShader(reprojShader)
	end
	if spriteShader then
		gl.DeleteShader(spriteShader)
	end
	if modelShader then
		gl.DeleteShader(modelShader)
	end
	widgetHandler:RemoveAction("tfcapture")
	WG.TerraformCapture = nil
end
