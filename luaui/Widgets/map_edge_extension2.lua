
function widget:GetInfo()
  return {
    name      = "Map Edge Extension",
    version   = "v0.7",
    desc      = "Draws a mirrored map next to the edges of the real map",
    author    = "ivand",
    date      = "2020",
    license   = "GPL",
    layer     = 0,
    enabled   = true,
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local brightness = 0.3
local curvature = true
local fogEffect = true

local mapBorderStyle = 'texture'	-- either 'texture' or 'cutaway'

local gridSize = 32
local wiremap = false

local hasClipDistance = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetGroundHeight = Spring.GetGroundHeight
local floor = math.floor
local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gridTex = "LuaUI/Images/vr_grid_large.dds"
local realTex = "$grass"
local colorTex = (mapBorderStyle == 'texture' and realTex) or gridTex

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local restoreMapBorder = true
local mapExtensionShader = nil
local terrainVAO = nil
local terrainVertexVBO = nil
local terrainInstanceVBO = nil

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function UpdateShader()
	mapExtensionShader:ActivateWith(function()
		mapExtensionShader:SetUniformAlways("shaderParams", gridSize, brightness, (curvature and 1.0) or 0.0, (fogEffect and 1.0) or 0.0)
	end)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local vsSrc = [[
#version 330
#line 10065

layout (location = 0) in vec2 aPos;
layout (location = 1) in vec4 aMirrorParams;

out DataVS {
	vec4 vMirrorParams;
};

void main() {
	gl_Position = vec4(aPos.x, 0.0, aPos.y, 1.0);
	vMirrorParams = aMirrorParams;
}
]]


local gsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

layout (points) in;
layout (triangle_strip, max_vertices = 4) out;

#line 20090

layout(std140, binding = 0) uniform UniformMatrixBuffer {
	mat4 screenView;
	mat4 screenProj;
	mat4 screenViewProj;

	mat4 cameraView;
	mat4 cameraProj;
	mat4 cameraViewProj;
	mat4 cameraBillboard;

	mat4 cameraViewInv;
	mat4 cameraProjInv;
	mat4 cameraViewProjInv;

	mat4 shadowView;
	mat4 shadowProj;
	mat4 shadowViewProj;

	//TODO: minimap matrices
};

layout(std140, binding = 1) uniform UniformParamsBuffer {
	vec3 rndVec3; //new every draw frame.
	uint renderCaps; //various render booleans

	vec4 timeInfo; //gameFrame, gameSeconds, drawFrame, frameTimeOffset
	vec4 viewGeometry; //vsx, vsy, vpx, vpy
	vec4 mapSize; //xz, xzPO2

	vec4 fogColor; //fog color
	vec4 fogParams; //fog {start, end, 0.0, scale}
};

uniform sampler2D heightTex;
uniform vec4 shaderParams;

#define gridSize shaderParams.x
#define curvature shaderParams.z
#define edgeFog shaderParams.w


in DataVS {
	vec4 vMirrorParams;
} dataIn[];

out DataGS {
	///
	vec2 alphaFog;
	vec2 uv;
};

#define SUPPORTS_CLIPDISTANCE ###SUPPORTS_CLIPDISTANCE###

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

void MyEmitVertex(vec2 xzVec) {
	vec4 worldPos = gl_in[0].gl_Position + vec4(xzVec.x, 0.0, xzVec.y, 0.0);

	uv = worldPos.xz / mapSize.xy;

	vec2 ts = vec2(textureSize(heightTex, 0));

	//avoid sampling edges
	vec2 uvHM = NORM2SNORM(uv);
	uvHM *= (ts - vec2(1.0)) / ts;
	uvHM = SNORM2NORM(uvHM);

	worldPos.y = textureLod(heightTex, uvHM, 0.0).x;

	const vec2 edgeTightening = vec2(0.5); // to tighten edges a little better
	worldPos.xz = abs(dataIn[0].vMirrorParams.xy * mapSize.xy - worldPos.xz);
	worldPos.xz += dataIn[0].vMirrorParams.zw * (mapSize.xy - edgeTightening);

	float alpha = 1.0;

	if (curvature == 1.0) {
		const float curvatureBend = 150.0;

		alpha = 0.0;

		vec2 refPoint = SNORM2NORM(dataIn[0].vMirrorParams.zw) * mapSize.xy;
		if (dataIn[0].vMirrorParams.x != 0.0) {
			worldPos.y -= pow((worldPos.x - refPoint.x) / curvatureBend, 2.0);
			alpha -= pow((worldPos.x - refPoint.x) / mapSize.x, 2.0);
		}

		if (dataIn[0].vMirrorParams.y != 0.0) {
			worldPos.y -= pow((worldPos.z - refPoint.y) / curvatureBend, 2.0);
			alpha -= pow((worldPos.z - refPoint.y) / mapSize.y, 2.0);
		}

		alpha = 1.0 + (6.0 * (alpha + 0.18));
		alpha = clamp(alpha, 0.0, 1.0);
	}

	float fogFactor = 1.0;
	if (edgeFog == 1.0) {
		vec4 forCoord = cameraView * worldPos;

		// emulate linear fog
		// vec4 fogParams; //fog {start, end, 0.0, scale}
		float fogDist = length(forCoord.xyz);
		fogFactor = (fogParams.y - fogDist) * fogParams.w;
		fogFactor = clamp(fogFactor, 0.0, 1.0);
	}

	alphaFog = vec2(alpha, fogFactor);

	gl_Position = cameraViewProj * worldPos;

	#if (SUPPORTS_CLIPDISTANCE == 1)
		gl_ClipDistance[4] = min(alpha - 0.05, fogFactor - 0.025);
	#endif

	EmitVertex();
}

void main() {

	#if 1 //culling case
		if ( all(equal(dataIn[0].vMirrorParams.xy, vec2(1.0))) ) {
			MyEmitVertex(vec2(gridSize,      0.0)); //TR
			MyEmitVertex(vec2(0.0     ,      0.0)); //TL
			MyEmitVertex(vec2(gridSize, gridSize)); //BR
			MyEmitVertex(vec2(0.0     , gridSize)); //BL
		} else {
			MyEmitVertex(vec2(0.0     , gridSize)); //BL
			MyEmitVertex(vec2(0.0     ,      0.0)); //TL
			MyEmitVertex(vec2(gridSize, gridSize)); //BR
			MyEmitVertex(vec2(gridSize,      0.0)); //TR
		}
	#else
		MyEmitVertex(vec2(0.0     , gridSize)); //BL
		MyEmitVertex(vec2(0.0     ,      0.0)); //TL
		MyEmitVertex(vec2(gridSize, gridSize)); //BR
		MyEmitVertex(vec2(gridSize,      0.0)); //TR
	#endif

	EndPrimitive();
}
]]


local fsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

layout(std140, binding = 1) uniform UniformParamsBuffer {
	vec3 rndVec3; //new every draw frame.
	uint renderCaps; //various render booleans

	vec4 timeInfo; //gameFrame, gameSeconds, drawFrame, frameTimeOffset
	vec4 viewGeometry; //vsx, vsy, vpx, vpy
	vec4 mapSize; //xz, xzPO2

	vec4 fogColor; //fog color
	vec4 fogParams; //fog {start, end, 0.0, scale}
};

uniform sampler2D colorTex;

uniform vec4 shaderParams;
#define brightness shaderParams.y

in DataGS {
	///
	vec2 alphaFog;
	vec2 uv;
};

out vec4 fragColor;

const mat3 RGB2YCBCR = mat3(
	0.2126, -0.114572, 0.5,
	0.7152, -0.385428, -0.454153,
	0.0722, 0.5, -0.0458471);

const mat3 YCBCR2RGB = mat3(
	1.0, 1.0, 1.0,
	0.0, -0.187324, 1.8556,
	1.5748, -0.468124, -5.55112e-17);

void main() {

	fragColor = texture(colorTex, uv);
	#if 1
		vec3 yCbCr = RGB2YCBCR * fragColor.rgb;
		yCbCr.x = clamp(yCbCr.x * brightness, 0.0, 1.0);
		fragColor.rgb = YCBCR2RGB * yCbCr;
	#else
		fragColor.rgb *= brightness;
	#endif

	fragColor.rgb = mix(fogColor.rgb, fragColor.rgb, alphaFog.y);
	fragColor.a = alphaFog.x;

}
]]


local numPoints

function widget:Initialize()
	WG['mapedgeextension'] = {}
	WG['mapedgeextension'].getBrightness = function()
		return brightness
	end
	WG['mapedgeextension'].setBrightness = function(value)
		brightness = value
		UpdateShader()
	end
	WG['mapedgeextension'].getCurvature = function()
		return curvature
	end
	WG['mapedgeextension'].setCurvature = function(value)
		curvature = value
		UpdateShader()
	end

	Spring.SendCommands("mapborder " .. (mapBorderStyle == 'cutaway' and "1" or "0"))

	if gl.GetMapRendering("voidGround") then
		restoreMapBorder = false
		widgetHandler:RemoveWidget(self)
	end

	if gl.GetMapRendering("voidWater") then
		restoreMapBorder = false
		widgetHandler:RemoveWidget(self)
	end

	-----------
	terrainVAO = gl.GetVAO()
	if terrainVAO == nil then
		Spring.SendCommands("luaui enablewidget Map Edge Extension Old")
		widgetHandler:RemoveWidget(self)
	end

	terrainVertexVBO = gl.GetVBO() -- GL.ARRAY_BUFFER, false
	if terrainVertexVBO == nil then
		Spring.SendCommands("luaui enablewidget Map Edge Extension Old")
		widgetHandler:RemoveWidget(self)
	end

	terrainInstanceVBO = gl.GetVBO() -- GL.ARRAY_BUFFER, false
	if terrainInstanceVBO == nil then
		Spring.SendCommands("luaui enablewidget Map Edge Extension Old")
		widgetHandler:RemoveWidget(self)
	end
	-----------

	local qX = mapSizeX / gridSize
	local qZ = mapSizeZ / gridSize

	local posArray = {}

	local posIdx = 1
	for qx = 0, qX - 1 do
	for qz = 0, qZ - 1 do
		--only Top-Left point. The rest is re-created by a geometry shader
		local x, z = qx * gridSize, qz * gridSize
		posArray[posIdx + 0] = x
		posArray[posIdx + 1] = z

		posIdx = posIdx + 2
	end
	end

	numPoints = #posArray / 2

	terrainVertexVBO:Define(numPoints, {
		{id = 0, name = "pos", size = 2}, --only update {x,z} once
	})
	terrainVertexVBO:Upload(posArray)

	terrainInstanceVBO:Define(8, {
		{id = 1, name = "mirrorParams", size = 4},
	})

	local mirrorParams = {
		-- flipX, flipZ, shiftX, shiftZ
		1, 1, -1, -1, --TL
		1, 0, -1,  0, --ML
		1, 1, -1,  1, --BL

		0, 1,  0, -1, --TM
		0, 1,  0,  1, --BM

		1, 1,  1, -1, --TR
		1, 0,  1,  0, --MR
		1, 1,  1,  1, --BR
	}
	terrainInstanceVBO:Upload(mirrorParams)

	terrainVAO:AttachVertexBuffer(terrainVertexVBO)
	terrainVAO:AttachInstanceBuffer(terrainInstanceVBO)

	hasClipDistance = ((Platform.gpuVendor == "AMD" and Platform.osFamily == "Linux") == false)
	gsSrc = gsSrc:gsub("###SUPPORTS_CLIPDISTANCE###", (hasClipDistance and "1" or "0"))
	--Spring.Echo(gsSrc)

	mapExtensionShader = LuaShader({
		vertex = vsSrc,
		geometry = gsSrc,
		fragment = fsSrc,
		uniformInt = {
			colorTex = 0,
			heightTex = 1,
			mapDepthTex = 2,
		},
		uniformFloat = {
			shaderParams = {gridSize, brightness, (curvature and 1.0) or 0.0, (fogEffect and 1.0) or 0.0},
		},
	}, "Map Extension Shader")
	local shaderCompiled = mapExtensionShader:Initialize()

	if not shaderCompiled then
		Spring.SendCommands("luaui enablewidget Map Edge Extension Old")
		widgetHandler:RemoveWidget(self)
	end

	Spring.SendCommands("luaui disablewidget External VR Grid")
end

function widget:Shutdown()
	if restoreMapBorder then
		Spring.SendCommands('mapborder '..(restoreMapBorder and '1' or '0'))
	end

	if mapExtensionShader then
		mapExtensionShader:Finalize()
	end

	if terrainVAO then
		--terrainVAO:Delete()
		terrainVAO = nil
	end

	if terrainVertexVBO then
		--terrainVertexVBO:Delete()
		terrainVertexVBO = nil
	end

	if terrainInstanceVBO then
		--terrainInstanceVBO:Delete()
		terrainInstanceVBO = nil
	end
	--collectgarbage("collect")
end


-- depth defaults:
--[[
	false
	false
	GL_DEPTH_FUNC = GL_ALWAYS
]]--
-- blending defaults:
--[[
	true
	GL_SRC_ALPHA
	GL_ONE_MINUS_SRC_ALPHA
]]--
-- culling defaults
--[[
	false
	GL_CULL_FACE_MODE = GL_BACK
]]--
function widget:DrawWorldPreUnit()
	--local q = gl.CreateQuery()
	--Spring.Utilities.TableEcho({gl.GetFixedState("alphatest", true)})
	if hasClipDistance then
		gl.ClipDistance(1, true)
	end
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(true)
	gl.Culling(true)

	gl.Texture(0, colorTex)
	gl.Texture(1, "$heightmap")
	mapExtensionShader:Activate()

	--gl.RunQuery(q, function()
		terrainVAO:DrawArrays(GL.POINTS, numPoints, 0, 8)
	--end)
	mapExtensionShader:Deactivate()
	gl.Texture(0, false)
	gl.Texture(1, false)

	gl.DepthTest(GL.ALWAYS)
	gl.DepthTest(false)
	gl.DepthMask(false)
	gl.Culling(false)
	if hasClipDistance then
		gl.ClipDistance(1, false)
	end

	--Spring.Echo(gl.GetQuery(q))
end

-- I see no value in this call
--[[
function widget:DrawWorldRefraction()
	--DrawWorldFunc()
end
]]--

--function widget:GameFrame()
	--local res = Spring.GetProjectilesInRectangle(-10000, -10000, 10000, 10000)
	--local res = Spring.GetVisibleProjectiles()
	--Spring.Utilities.TableEcho(res)
--end


function widget:GetConfigData(data)
	return {
		brightness = brightness,
		curvature = curvature,
		fogEffect = fogEffect
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
end