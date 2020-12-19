
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

local luaShaderDir = "LuaUI/Widgets_BAR/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local restoreMapBorder = true
local mapExtensionShader = nil
local terrainVAO = nil

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
#version 330 compatibility
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
#version 330 compatibility

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
	vec4 timeInfo; //gameFrame, gameSeconds, drawFrame, frameTimeOffset
	vec4 viewGeometry; //vsx, vsy, vpx, vpy
	vec4 mapSize; //xz, xzPO2
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

	worldPos.xz = abs(dataIn[0].vMirrorParams.xy * mapSize.xy - worldPos.xz);
	worldPos.xz += dataIn[0].vMirrorParams.zw * mapSize.xy;

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
		vec4 clipVertex = cameraView * worldPos;

		// emulate linear fog
		float fogCoord = length(clipVertex.xyz);
		fogFactor = (gl_Fog.end - fogCoord) * gl_Fog.scale; // gl_Fog.scale == 1.0 / (gl_Fog.end - gl_Fog.start)
		fogFactor = clamp(fogFactor, 0.0, 1.0);
	}

	alphaFog = vec2(alpha, fogFactor);

	gl_Position = cameraViewProj * worldPos;

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
#version 330 compatibility

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

	fragColor.rgb = mix(gl_Fog.color.rgb, fragColor.rgb, alphaFog.y);
	fragColor.a = alphaFog.x;}
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

	local voidGround = gl.GetMapRendering("voidGround")
	if voidGround then
		restoreMapBorder = false
		widgetHandler:RemoveWidget(self)
	end

	terrainVAO = gl.GetVAO(false)
	if terrainVAO == nil then
		Spring.SendCommands("luaui enablewidget Map Edge Extension Old")
		widgetHandler:RemoveWidget(self)
	end

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

	terrainVAO:SetVertexAttributes(numPoints, {
		{id = 0, name = "pos", size = 2}, --only update {x,z} once
	})
	terrainVAO:UploadVertexBulk(posArray, 0)

	terrainVAO:SetInstanceAttributes(8, {
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
	terrainVAO:UploadInstanceBulk(mirrorParams, 0)


	mapExtensionShader = LuaShader({
		vertex = vsSrc,
		geometry = gsSrc,
		fragment = fsSrc,
		uniformInt = {
			colorTex = 0,
			heightTex = 1,
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
		terrainVAO:Delete()
	end
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
	--Spring.Utilities.TableEcho({gl.GetFixedState("alphatest", true)})

	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(true)
	gl.Culling(true)

	gl.Texture(0, colorTex)
	gl.Texture(1, "$heightmap")
	mapExtensionShader:Activate()

	terrainVAO:DrawArrays(GL.POINTS, numPoints, 0, 8)

	mapExtensionShader:Deactivate()
	gl.Texture(0, false)
	gl.Texture(1, false)

	gl.DepthTest(GL.ALWAYS)
	gl.DepthTest(false)
	gl.DepthMask(false)
	gl.Culling(false)
end

-- I see no value in this call
--[[
function widget:DrawWorldRefraction()
	--DrawWorldFunc()
end
]]--


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
