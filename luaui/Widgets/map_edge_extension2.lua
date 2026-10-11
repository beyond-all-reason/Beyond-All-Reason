local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Map Edge Extension",
		version = "v0.8",
		desc = "Draws a mirrored map next to the edges of the real map",
		author = "ivand",
		date = "2020",
		license = "GPL",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local brightness = 0.3
local nightFactor = 1.0
local curvature = true
local fogEffect = true

local mapBorderStyle = "texture" -- either 'texture' or 'cutaway'

-- cell size of the mirrored terrain mesh, in elmos
local gridSize = 32
local gridSizeDeferred = 2 * gridSize

-- With curvature on, a mirror fades out with its distance from the map edge and the fragment
-- shader discards everything below alpha 0.05, which is this fraction of the map size away
-- (the fade curve is in the vertex shader), so the mesh only spans that much along mirrored axes.
local visibleFraction = math.sqrt(0.18 + 0.95 / 6.0)

local hasBadCulling = false -- AMD+Linux combo: face culling drops half the tris

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spIsAABBInView = Spring.IsAABBInView
local spGetGroundExtremes = Spring.GetGroundExtremes
local spGetCameraPosition = Spring.GetCameraPosition
local spGetCameraDirection = Spring.GetCameraDirection
local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gridTex = "LuaUI/Images/vr_grid_large.dds"
local realTex = "$grass"
local colorTex = (mapBorderStyle == "texture" and realTex) or gridTex

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local LuaShader = gl.LuaShader

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local restoreMapBorder = true
local mapExtensionShader ---@type LuaShader?
local mapExtensionShaderDeferred ---@type LuaShader?
local terrainVAO ---@type VAO?
local terrainInstanceVBO ---@type VBO?

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Every mirror is one instanced triangle strip that the vertex shader builds from gl_VertexID:
-- a row of quads after another, rows joined by two degenerate triangles, so no vertex or index
-- buffer is needed and the mesh extent can follow the curvature setting.
local vsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 10000

// xy: which axes are mirrored (0 or 1), zw: where the mirror lies, in map sizes (-1, 0 or 1)
layout (location = 0) in vec4 aMirrorParams;

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D heightTex;
uniform vec4 shaderParams; // brightness, curvature, fog, unused
uniform vec4 meshParams; // cells along x and z: the whole map, then trimmed to the visible part

#define curvature shaderParams.y
#define edgeFog shaderParams.z

out DataVS {
	vec2 alphaFog;
	vec2 uv;
	vec2 normalSign;
};

void main() {
	vec2 flip = aMirrorParams.xy;
	vec2 offset = aMirrorParams.zw;

	// Mirrored axes only span the part of the map that is not faded out
	int cols = int((flip.x > 0.5) ? meshParams.z : meshParams.x);
	int rows = int((flip.y > 0.5) ? meshParams.w : meshParams.y);

	// A mirror placed before the map reverses its world axis (which flips the winding); one placed after it
	// reverses the sampled map axis. Faces must stay front-facing in the world, and quads keep the old
	// split along the main diagonal in map space, so pick the strip direction and pair order per instance.
	int rev = int((flip.x > 0.5 && offset.x < 0.0) != (flip.y > 0.5 && offset.y < 0.0));
	int mapRev = int((flip.x > 0.5 && offset.x > 0.0) != (flip.y > 0.5 && offset.y > 0.0));
	bool alongZ = (rev == mapRev);
	int swap = alongZ ? (1 - rev) : rev;
	int outer = alongZ ? cols : rows;
	int inner = alongZ ? rows : cols;
	int perLine = 2 * (inner + 1) + 2;
	int line = gl_VertexID / perLine;
	int k = gl_VertexID - line * perLine;
	int i = k >> 1;
	int o = line + ((k & 1) ^ swap);
	if (k == perLine - 2) { // repeat the last vertex of the line
		i = inner;
		o = line + (1 ^ swap);
	} else if (k == perLine - 1) { // first vertex of the next line
		i = 0;
		o = line + 1 + swap;
	}
	if (line >= outer) { // the draw covers the largest mirror: collapse the rest onto the strip's last vertex
		i = 0;
		o = outer + swap;
	}
	int c = alongZ ? o : i;
	int r = alongZ ? i : o;

	// Along a mirrored axis t is the distance from the map edge: sampled back into the map, placed outside it
	vec2 t = vec2(float(c), float(r)) * GRID_SIZE;
	bvec2 mirrored = greaterThan(flip, vec2(0.5));
	vec2 edge = step(0.0, offset) * mapSize.xy;
	vec2 dir = sign(offset);
	vec2 mapPos = mix(t, edge - dir * t, mirrored);
	vec2 worldXZ = mix(t, edge + dir * t, mirrored) - offset * EDGE_TIGHTENING;

	float height = textureLod(heightTex, heightmapUVatWorldPos(mapPos), 0.0).x;

	float alpha = 1.0;
	if (curvature == 1.0) {
		vec2 dist = flip * (t - EDGE_TIGHTENING);
		vec2 bend = dist / 150.0;
		height -= dot(bend, bend);
		vec2 fade = dist / mapSize.xy;
		alpha = clamp(1.0 + 6.0 * (0.18 - dot(fade, fade)), 0.0, 1.0);
	}

	vec4 worldPos = vec4(worldXZ.x, height, worldXZ.y, 1.0);

	// emulate linear fog; fogParams = {start, end, 0.0, scale}
	float fogFactor = 1.0;
	if (edgeFog == 1.0) {
		float fogDist = length((cameraView * worldPos).xyz);
		fogFactor = clamp((fogParams.y - fogDist) * fogParams.w, 0.0, 1.0);
	}

	alphaFog = vec2(alpha, fogFactor);
	uv = mapPos / mapSize.xy;
	normalSign = 1.0 - 2.0 * flip;
	gl_Position = cameraViewProj * worldPos;
}
]]

local fsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 20000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D colorTex;
uniform sampler2D mapNormalTex;

uniform vec4 shaderParams;
#define brightness shaderParams.x

in DataVS {
	vec2 alphaFog;
	vec2 uv;
	vec2 normalSign;
};

#ifdef DEFERRED_MODE
	#define GBUFFER_NORMTEX_IDX 0
	#define GBUFFER_DIFFTEX_IDX 1
	out vec4 fragData[2];
#else
	out vec4 fragColor;
#endif

// BT.709 luma; scaling only Y of the YCbCr form amounts to this offset on all three channels
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

#define MINIMAP_HALF_TEXEL (0.5/1024.0)

void main() {
	// remove tiling seams from minimap texel edges
	vec2 clampeduv = clamp(uv, MINIMAP_HALF_TEXEL, 1.0 - MINIMAP_HALF_TEXEL);

	vec4 finalColor = texture(colorTex, clampeduv);

	// Note that normals are Z up in textures, but Y up in the world
	vec3 mapNormal;
	#ifdef DEFERRED_MODE
		mapNormal.xz = texture(mapNormalTex, clampeduv).ra;
		// clamp before sqrt to prevent NaN when xz values are out of [-1,1] range
		mapNormal.y = sqrt(max(0.0, 1.0 - dot(mapNormal.xz, mapNormal.xz)));
	#else
		mapNormal = texture(mapNormalTex, clamp(uv, MINIMAP_HALF_TEXEL / 4.0, 1.0 - (MINIMAP_HALF_TEXEL / 4.0))).rbg * 2.0 - 1.0;
	#endif

	// faded out past the curvature falloff
	if (alphaFog.x < 0.05) discard;

	float luma = dot(finalColor.rgb, LUMA);
	finalColor.rgb += clamp(luma * brightness, 0.0, 1.0) - luma;

	// guard against zero-length normal (normalize(vec3(0)) = NaN on most GPUs)
	float normalLen = length(mapNormal);
	mapNormal = (normalLen > 0.001) ? mapNormal / normalLen : vec3(0.0, 1.0, 0.0);

	// Flip normals if the mirror is flipped
	mapNormal.xz *= normalSign;

	// Apply some lighting based on the normal vector
	finalColor.rgb *= dot(mapNormal, sunDir.xyz) * 0.5 + 1.0;

	// clamp to prevent NaN/overflow from lighting producing white pixels
	finalColor.rgb = clamp(finalColor.rgb, 0.0, 1.0);
	finalColor.rgb = mix(fogColor.rgb, finalColor.rgb, alphaFog.y);
	finalColor.a = alphaFog.x;

	#ifdef DEFERRED_MODE
		fragData[GBUFFER_NORMTEX_IDX] = vec4(mapNormal * 0.5 + 0.5, 1.0);
		fragData[GBUFFER_DIFFTEX_IDX] = finalColor;
	#else
		fragColor = finalColor;
	#endif
}
]]

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

---@class MirrorMesh
---@field cols number cells along x over the whole map
---@field rows number cells along z over the whole map
---@field trimCols number cells along x of a mirror that flips x
---@field trimRows number cells along z of a mirror that flips z
---@field vertexCount number strip vertices of the largest mirror currently in view

---@param cellSize number
---@return MirrorMesh
local function MakeMirrorMesh(cellSize)
	local cols = math.ceil(mapSizeX / cellSize)
	local rows = math.ceil(mapSizeZ / cellSize)
	local trimCols, trimRows = cols, rows
	if curvature then
		trimCols = math.min(cols, math.ceil(visibleFraction * cols))
		trimRows = math.min(rows, math.ceil(visibleFraction * rows))
	end
	return { cols = cols, rows = rows, trimCols = trimCols, trimRows = trimRows, vertexCount = 0 }
end

-- vertices of a strip with `outer` lines of `inner` quads, see the vertex shader
local function StripVertexCount(inner, outer)
	return outer * (2 * (inner + 1) + 2)
end

local mirrorMesh ---@type MirrorMesh
local mirrorMeshDeferred ---@type MirrorMesh

local mirrorParams = {}
local hasSideMirrorX, hasSideMirrorZ, hasCornerMirror = false, false, false

local function UpdateVertexCounts()
	for _, mesh in ipairs({ mirrorMesh, mirrorMeshDeferred }) do
		local count = 0.0
		if hasSideMirrorX then
			count = math.max(count, StripVertexCount(mesh.trimCols, mesh.rows))
		end
		if hasSideMirrorZ then
			count = math.max(count, StripVertexCount(mesh.cols, mesh.trimRows))
		end
		if hasCornerMirror then
			count = math.max(count, StripVertexCount(mesh.trimRows, mesh.trimCols)) -- corner strips run along z
		end
		mesh.vertexCount = count
	end
end

local function UpdateMeshes()
	mirrorMesh = MakeMirrorMesh(gridSize)
	mirrorMeshDeferred = MakeMirrorMesh(gridSizeDeferred)
	UpdateVertexCounts()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function Distance2(x1, y1, z1, x2, y2, z2)
	local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
	return dx * dx + dy * dy + dz * dz
end

-- presumes normalized vectors
local function DotProduct(x1, y1, z1, x2, y2, z2)
	return x1 * x2 + y1 * y2 + z1 * z2
end

local borderMargin = 40
local cachedCameraPosDir = { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 }
local cachedMinY, cachedMaxY

local function AddMirror(flipX, flipZ, offsetX, offsetZ)
	local n = #mirrorParams
	mirrorParams[n + 1] = flipX
	mirrorParams[n + 2] = flipZ
	mirrorParams[n + 3] = offsetX
	mirrorParams[n + 4] = offsetZ
	if flipX == 1 and flipZ == 1 then
		hasCornerMirror = true
	elseif flipX == 1 then
		hasSideMirrorX = true
	else
		hasSideMirrorZ = true
	end
end

local function UpdateMirrorParams()
	local cpX, cpY, cpZ = spGetCameraPosition()
	local cdX, cdY, cdZ = spGetCameraDirection()
	local initMinY, initMaxY, currMinY, currMaxY = spGetGroundExtremes()
	local minY = currMinY or initMinY
	local maxY = currMaxY or initMaxY

	local checkInView = false
	if minY ~= cachedMinY or maxY ~= cachedMaxY then
		checkInView = true
		cachedMinY = minY
		cachedMaxY = maxY
	end

	if Distance2(cpX, cpY, cpZ, cachedCameraPosDir[1], cachedCameraPosDir[2], cachedCameraPosDir[3]) > 900 then
		checkInView = true
		cachedCameraPosDir[1] = cpX
		cachedCameraPosDir[2] = cpY
		cachedCameraPosDir[3] = cpZ
	end

	if
		checkInView
		or DotProduct(cdX, cdY, cdZ, cachedCameraPosDir[4], cachedCameraPosDir[5], cachedCameraPosDir[6]) < 0.95
	then
		checkInView = true
		cachedCameraPosDir[4] = cdX
		cachedCameraPosDir[5] = cdY
		cachedCameraPosDir[6] = cdZ
	end

	if not checkInView then
		return
	end

	mirrorParams = {}
	hasSideMirrorX, hasSideMirrorZ, hasCornerMirror = false, false, false

	if spIsAABBInView(-mapSizeX, minY, -mapSizeZ, borderMargin, maxY, borderMargin) then
		AddMirror(1, 1, -1, -1) -- TL
	end
	if spIsAABBInView(-mapSizeX, minY, -borderMargin, 0, maxY, mapSizeZ) then
		AddMirror(1, 0, -1, 0) -- ML
	end
	if spIsAABBInView(-mapSizeX, minY, mapSizeZ - borderMargin, borderMargin, maxY, mapSizeZ * 2) then
		AddMirror(1, 1, -1, 1) -- BL
	end
	if spIsAABBInView(-borderMargin, minY, -mapSizeZ, mapSizeX + borderMargin, maxY, borderMargin) then
		AddMirror(0, 1, 0, -1) -- TM
	end
	if spIsAABBInView(-borderMargin, minY, mapSizeZ - borderMargin, mapSizeX + borderMargin, maxY, mapSizeZ * 2) then
		AddMirror(0, 1, 0, 1) -- BM
	end
	if spIsAABBInView(mapSizeX - borderMargin, minY, -mapSizeZ, mapSizeX * 2, maxY, borderMargin) then
		AddMirror(1, 1, 1, -1) -- TR
	end
	if spIsAABBInView(mapSizeX - borderMargin, minY, -borderMargin, mapSizeX * 2, maxY, mapSizeZ) then
		AddMirror(1, 0, 1, 0) -- MR
	end
	if spIsAABBInView(mapSizeX - borderMargin, minY, mapSizeZ - borderMargin, mapSizeX * 2, maxY, mapSizeZ * 2) then
		AddMirror(1, 1, 1, 1) -- BR
	end

	if #mirrorParams > 0 then
		terrainInstanceVBO:Upload(mirrorParams)
	end
	UpdateVertexCounts()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

---@param shader LuaShader?
---@param mesh MirrorMesh
---@param normalTex string
local function DrawMirrors(shader, mesh, normalTex)
	if not shader then
		return
	end
	if hasBadCulling then
		gl.Culling(false) -- amdlinux on steam deck or else half the tris are invisible
	else
		gl.Culling(GL.BACK)
	end
	gl.Texture(0, colorTex)
	gl.Texture(1, "$heightmap")
	gl.Texture(2, normalTex)
	shader:Activate()
	shader:SetUniform(
		"shaderParams",
		brightness * nightFactor,
		(curvature and 1.0) or 0.0,
		(fogEffect and 1.0) or 0.0,
		0.0
	)
	shader:SetUniform("meshParams", mesh.cols, mesh.rows, mesh.trimCols, mesh.trimRows)
	terrainVAO:DrawArrays(GL.TRIANGLE_STRIP, mesh.vertexCount, 0, #mirrorParams / 4)
	shader:Deactivate()
	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)
	gl.Culling(false) -- restore the default state, don't leak face culling into later draws
end

-- Needs AllowDrawMapDeferredEvents; writes the mirrors' normals and depth into the map G-buffer
function widget:DrawGroundDeferred()
	if #mirrorParams == 0 then
		return
	end
	DrawMirrors(mapExtensionShaderDeferred, mirrorMeshDeferred, "$normals")
end

function widget:DrawWorldPreUnit()
	UpdateMirrorParams()

	if #mirrorParams == 0 then
		return
	end

	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(true)
	DrawMirrors(mapExtensionShader, mirrorMesh, "$ssmf_normals")
	gl.DepthTest(false)
	gl.DepthMask(false)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function MakeShader(name, defines)
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	local function assemble(src)
		src = src:gsub("//__DEFINES__", function()
			return defines
		end)
		src = src:gsub("//__ENGINEUNIFORMBUFFERDEFS__", function()
			return engineUniformBufferDefs
		end)
		return src
	end
	local shader = LuaShader({
		vertex = assemble(vsSrc),
		fragment = assemble(fsSrc),
		uniformInt = {
			colorTex = 0,
			heightTex = 1,
			mapNormalTex = 2,
		},
		uniformFloat = {
			shaderParams = { brightness, (curvature and 1.0) or 0.0, (fogEffect and 1.0) or 0.0, 0.0 },
			meshParams = { 0, 0, 0, 0 },
		},
	}, name)
	if shader:Initialize() then
		return shader
	end
	if shader.shaderObj ~= nil then
		shader:Finalize()
	end
	return nil
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if BAR.Lava.isLavaMap == true then
		widgetHandler:RemoveWidget()
		return
	end

	WG.mapedgeextension = {}
	WG.mapedgeextension.getBrightness = function()
		return brightness
	end
	WG.mapedgeextension.setBrightness = function(value)
		brightness = value
	end
	WG.mapedgeextension.getCurvature = function()
		return curvature
	end
	WG.mapedgeextension.setCurvature = function(value)
		curvature = value
		UpdateMeshes()
	end

	Spring.SendCommands("mapborder 1") --..(mapBorderStyle == 'cutaway' and "1" or "0"))

	if gl.GetMapRendering("voidGround") or gl.GetMapRendering("voidWater") then
		restoreMapBorder = false
		widgetHandler:RemoveWidget()
		return
	end

	terrainVAO = gl.GetVAO()
	terrainInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	if terrainVAO == nil or terrainInstanceVBO == nil then
		widgetHandler:RemoveWidget()
		return
	end

	terrainInstanceVBO:Define(8, {
		{ id = 0, name = "mirrorParams", size = 4 },
	})
	terrainVAO:AttachInstanceBuffer(terrainInstanceVBO)

	hasBadCulling = ((Platform.gpuVendor == "AMD" and Platform.osFamily == "Linux") == true)

	mapExtensionShader = MakeShader(
		"Map Extension Shader2",
		string.format("#define GRID_SIZE %.1f\n#define EDGE_TIGHTENING 0.0\n", gridSize)
	)
	mapExtensionShaderDeferred = MakeShader(
		"Map Extension Shader Deferred",
		string.format(
			"#define DEFERRED_MODE 1\n#define GRID_SIZE %.1f\n#define EDGE_TIGHTENING 0.5\n",
			gridSizeDeferred
		)
	)
	if not mapExtensionShader or not mapExtensionShaderDeferred then
		widgetHandler:RemoveWidget()
		return
	end

	UpdateMeshes()
end

function widget:Shutdown()
	Spring.SendCommands("mapborder " .. (restoreMapBorder and "1" or "0"))

	if mapExtensionShader and mapExtensionShader.shaderObj ~= nil then
		mapExtensionShader:Finalize()
	end
	mapExtensionShader = nil

	if mapExtensionShaderDeferred and mapExtensionShaderDeferred.shaderObj ~= nil then
		mapExtensionShaderDeferred:Finalize()
	end
	mapExtensionShaderDeferred = nil

	if terrainVAO then
		terrainVAO:Delete()
		terrainVAO = nil
	end

	if terrainInstanceVBO then
		terrainInstanceVBO:Delete()
		terrainInstanceVBO = nil
	end

	WG.mapedgeextension = nil
end

function widget:NightFactorChanged(red, green, blue, shadow, altitude)
	nightFactor = (red + green + blue) * 0.33
end

function widget:GetConfigData(data)
	return {
		brightness = brightness,
		curvature = curvature,
		fogEffect = fogEffect,
	}
end

function widget:SetConfigData(data)
	if data.brightness ~= nil then
		brightness = data.brightness
	end
	if data.curvature ~= nil then
		curvature = data.curvature
	end
	if data.fogEffect ~= nil then
		fogEffect = data.fogEffect
	end
	if terrainVAO then
		UpdateMeshes()
	end
end
