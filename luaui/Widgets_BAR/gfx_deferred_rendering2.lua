--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-----------------------------------------------------------------
-- File path Constants
-----------------------------------------------------------------

local luaShaderDir = "LuaUI/Widgets_BAR/Include/"

-----------------------------------------------------------------
-- Shader Sources
-----------------------------------------------------------------

local vsSrc = [[
#version 150 compatibility

uniform mat4 viewMat;
uniform mat4 projMat;

out DataVS {
	vec4 colAtt;
	vec4 attrib0;
};

void main() {
	gl_Position = gl_Vertex;
	colAtt  = gl_Color;
	attrib0 = gl_MultiTexCoord0;
}
]]

local gsSrc = [[
#version 150 compatibility

uniform mat4 viewMat;
uniform mat4 projMat;

uniform int lightType;

layout (points) in;
layout (triangle_strip, max_vertices = 24) out;

#line 41

in DataVS {
	vec4 colAtt;
	vec4 attrib0;
} dataIn[];

out DataGS {
	vec4 colAtt;
	vec4 attrib0;
};

// Z-; Z+ are bottom top planes of frustum
void GenericFrustum(mat4 worldMat, vec4 zMinModelCenterPos, vec4 zMaxModelCenterPos, float zMinRadius, float zMaxRadius) {
	mat4 MVP = projMat * viewMat * worldMat;

	vec4 frustumPoints[8] = vec4[](
		//zMin (-- -+ +- ++)
		MVP * (zMinModelCenterPos + vec4(-zMinRadius, -zMinRadius, 0.0, 0.0)),
		MVP * (zMinModelCenterPos + vec4(-zMinRadius,  zMinRadius, 0.0, 0.0)),
		MVP * (zMinModelCenterPos + vec4( zMinRadius, -zMinRadius, 0.0, 0.0)),
		MVP * (zMinModelCenterPos + vec4( zMinRadius,  zMinRadius, 0.0, 0.0)),

		//zMax (-- -+ +- ++)
		MVP * (zMaxModelCenterPos + vec4(-zMaxRadius, -zMaxRadius, 0.0, 0.0)),
		MVP * (zMaxModelCenterPos + vec4(-zMaxRadius,  zMaxRadius, 0.0, 0.0)),
		MVP * (zMaxModelCenterPos + vec4( zMaxRadius, -zMaxRadius, 0.0, 0.0)),
		MVP * (zMaxModelCenterPos + vec4( zMaxRadius,  zMaxRadius, 0.0, 0.0))
	);

	#define MyEmitVertex(idx) \
	{ \
		gl_Position = frustumPoints[idx]; \
		colAtt = dataIn[0].colAtt; \
		attrib0 = dataIn[0].attrib0; \
		EmitVertex(); \
	}

	// Z-
	MyEmitVertex(3);
	MyEmitVertex(1);
	MyEmitVertex(2);
	MyEmitVertex(0);
	EndPrimitive();

	// Z+
	MyEmitVertex(4);
	MyEmitVertex(5);
	MyEmitVertex(6);
	MyEmitVertex(7);
	EndPrimitive();

	// X-
	MyEmitVertex(0);
	MyEmitVertex(1);
	MyEmitVertex(4);
	MyEmitVertex(5);
	EndPrimitive();

	// X+
	MyEmitVertex(3);
	MyEmitVertex(2);
	MyEmitVertex(7);
	MyEmitVertex(6);
	EndPrimitive();


	// Y-
	MyEmitVertex(0);
	MyEmitVertex(4);
	MyEmitVertex(2);
	MyEmitVertex(6);
	EndPrimitive();

	// Y+
	MyEmitVertex(7);
	MyEmitVertex(5);
	MyEmitVertex(3);
	MyEmitVertex(1);
	EndPrimitive();
}

void GetSphereBoundingShape(mat4 worldMat, vec4 modelCenterPos, float r) {
	vec4 zMinModelCenterPos = modelCenterPos; zMinModelCenterPos.z -= r;
	vec4 zMaxModelCenterPos = modelCenterPos; zMaxModelCenterPos.z += r;

	GenericFrustum(worldMat, zMinModelCenterPos, zMaxModelCenterPos, r, r);
}

void GetBeamBoundingShape(mat4 worldMat, vec4 modelBeamStartPos, vec4 modelBeamEndPos, float r0, float r1) {
	GenericFrustum(worldMat, modelBeamStartPos, modelBeamEndPos, r0, r1);
}

void GetConeBoundingShape(mat4 worldMat, vec4 modelBeamStartPos, float r, float phi) {
	vec4 modelBeamEndPos = modelBeamStartPos; modelBeamEndPos.z += r;
	float rFar = r * tan(0.5 * phi);

	GenericFrustum(worldMat, modelBeamStartPos, modelBeamEndPos, 0.0, rFar);
}

mat4 GetDirectionMatrix(vec3 dirNorm) {
	const vec3 up = vec3(0, 1, 0);
	
    vec3 zaxis = dirNorm;
    vec3 xaxis = normalize(cross(zaxis, up));
	
	xaxis = isnan(xaxis.x) ? vec3(1, 0, 0) : xaxis;
	
    vec3 yaxis = cross(xaxis, zaxis);

    return mat4(
		vec4(xaxis.x, yaxis.x, zaxis.x, 0.0),
		vec4(xaxis.y, yaxis.y, zaxis.y, 0.0),
		vec4(xaxis.z, yaxis.z, zaxis.z, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0)
	);
}


mat4 GetTranslationMatrix(vec3 xyz) {
	mat4 trlMat = mat4(1.0);
	trlMat[3] = vec4(xyz, 1.0);

	return trlMat;
}

void main() {
	vec3 pos0 = gl_in[0].gl_Position.xyz;
	float r0 = gl_in[0].gl_Position.w;

	vec3 pos1 = dataIn[0].attrib0.xyz;
	float r1 = dataIn[0].attrib0.w;

	const vec4 startModelPos = vec4(0.0, 0.0, 0.0, 1.0);

	if (lightType == 0) { // omni-dir light
		mat4 rotMat = GetDirectionMatrix(vec3(0, 1, 0));
		mat4 trlMat = GetTranslationMatrix(pos0);

		mat4 worldMat = trlMat * rotMat;

		GetSphereBoundingShape(worldMat, startModelPos, r0);
	}
	else if (lightType == 1) { // beam light
		vec4 dirLen = vec4(pos1 - pos0, 0.0);
		dirLen.w = length(dirLen.xyz);
		dirLen.xyz /= dirLen.w;

		vec4 endModelPos = vec4(0.0, 0.0, dirLen.w, 1.0);

		mat4 rotMat = GetDirectionMatrix(dirLen.xyz);
		mat4 trlMat = GetTranslationMatrix(pos0);

		mat4 worldMat = trlMat * rotMat;

		GetBeamBoundingShape(worldMat, startModelPos, endModelPos, r0, r1);
	}
	else if (lightType == 2) { // //cone light
		mat4 rotMat = GetDirectionMatrix(normalize(pos1));
		mat4 trlMat = GetTranslationMatrix(pos0);
		
		mat4 worldMat = trlMat * rotMat;

		GetConeBoundingShape(worldMat, startModelPos, r0, r1);
	}
}

]]

local fsSrc = [[
#version 150 compatibility

uniform int lightType;
uniform vec2 viewPortSize;

#define LIGHTRADIUS lightpos.w
uniform sampler2D modelnormals;
uniform sampler2D modeldepths;
uniform sampler2D mapnormals;
uniform sampler2D mapdepths;
uniform sampler2D modelExtra;

in DataGS {
	vec4 colAtt;
	vec4 attrib0;
};

void main() {
	vec2 uv = gl_FragCoord.xy / viewPortSize;

	//gl_FragColor = !gl_FrontFacing ? vec4(colAtt.rgb, 1.0) : vec4(vec3(1.0), 1.0);
	gl_FragColor = vec4(colAtt.rgb, 1.0);
	gl_FragColor = vec4(uv, 0.0, 1.0);
}
]]

-----------------------------------------------------------------
-- Global Variables
-----------------------------------------------------------------


local glBlending             = gl.Blending
local glTexture              = gl.Texture


local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
local vsx, vsy, vpx, vpy
local lightShader
local dlPoint, dlBeam, dlCone

-----------------------------------------------------------------

function widget:GetInfo()
  return {
	name      = "Deferred rendering2",
	version   = 3,
	desc      = "Bla",
	author    = "beherith, aeonios",
	date      = "2015 Sept.",
	license   = "GPL V2",
	layer     = -99999990,
	enabled   = true
  }
end

function widget:Initialize()
	local vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
	lightShader = LuaShader({
		vertex = vsSrc,
		geometry = gsSrc,
		fragment = fsSrc,
		uniformFloat = {
			viewPortSize = {vsx, vsy},
		},
	}, "Light Volume Shader")
	lightShader:Initialize()
end

function widget:Finalize()
	if dlPoint then
		gl.DeleteList(dlPoint)
		dlPoint = nil
	end
	if dlBeam then
		gl.DeleteList(dlBeam)
		dlBeam = nil
	end
	if dlCone then
		gl.DeleteList(dlCone)
		dlCone = nil
	end
	lightShader:Finalize()
end

function widget:ViewResize()
	widget:Finalize()
	widget:Initialize()
end

local function PrepareLightDisplayLists()
	if dlPoint then
		gl.DeleteList(dlPoint)
		dlPoint = nil
	end
	if dlBeam then
		gl.DeleteList(dlBeam)
		dlBeam = nil
	end
	if dlCone then
		gl.DeleteList(dlCone)
		dlCone = nil
	end

	dlBeam = gl.CreateList( function()
		gl.BeginEnd(GL.POINTS, function ()
			gl.Color(0, -1, 1, 1)
			gl.MultiTexCoord(0, 2738, 140, 4519, 32)
			gl.Vertex(2556, 140, 4753, 400)

			gl.Color(1, 1, 1, 1)
			gl.MultiTexCoord(0, 3200, 140, 4519, 32)
			gl.Vertex(2556, 100, 4753, 400)
		end)
	end)
	
	dlPoint = gl.CreateList( function()
		gl.BeginEnd(GL.POINTS, function ()
			gl.Color(1, 1, 1, 1)
			gl.MultiTexCoord(0, 3200, 140, 4519, 32)
			gl.Vertex(2821, 100, 4871, 100)
		end)
	end)

	dlCone = gl.CreateList( function()
		gl.BeginEnd(GL.POINTS, function ()
			gl.Color(0, 0, 1, 1)
			gl.MultiTexCoord(0, 0, -1, 0, 60 / 360 * math.pi)
			gl.Vertex(2595, 200, 4985, 200)
		end)
	end)	
end

local GL_KEEP = 0x1E00
local GL_ZERO = 0x0000
local GL_INCR = 0x1E02
local GL_INCR_WRAP = 0x8507
local GL_DECR_WRAP = 0x8508
local function LightVolumePass1()
	gl.StencilTest(true)
	gl.Culling(GL.BACK)
	gl.ColorMask(false, false, false, false)
	gl.DepthTest(GL.LEQUAL)
	gl.StencilOp(GL_ZERO, GL_INCR, GL_ZERO)
	gl.StencilFunc(GL.ALWAYS, 0, 0xFF)

	if dlPoint then
		lightShader:SetUniformIntAlways("lightType", 0)
		gl.CallList(dlPoint)
	end
	if dlBeam then
		lightShader:SetUniformIntAlways("lightType", 1)
		gl.CallList(dlBeam)
	end
	if dlCone then
		lightShader:SetUniformIntAlways("lightType", 2)
		gl.CallList(dlCone)
	end
end

local function LightVolumePass2()
	gl.Culling(GL.FRONT)
	gl.ColorMask(true, true, true, true)
	gl.DepthTest(GL.GEQUAL)
	gl.StencilOp(GL_ZERO, GL_ZERO, GL_ZERO)
	gl.StencilFunc(GL.EQUAL, 0, 0xFF)
	
	glBlending(GL.SRC_ALPHA, GL.ONE)
	glTexture(0, "$model_gbuffer_normtex")
	glTexture(1, "$model_gbuffer_zvaltex")
	glTexture(2, "$map_gbuffer_normtex")
	glTexture(3, "$map_gbuffer_zvaltex")
	glTexture(4, "$model_gbuffer_spectex")
	

	if dlPoint then
		lightShader:SetUniformIntAlways("lightType", 0)
		gl.CallList(dlPoint)
	end
	if dlBeam then
		lightShader:SetUniformIntAlways("lightType", 1)
		gl.CallList(dlBeam)
	end
	if dlCone then
		lightShader:SetUniformIntAlways("lightType", 2)
		gl.CallList(dlCone)
	end
	--cleanup
	gl.StencilTest(false)
	gl.DepthTest(GL.LEQUAL)
	gl.Culling(false)
	
	glTexture(0, false)
	glTexture(1, false)
	glTexture(2, false)
	glTexture(3, false)
	glTexture(4, false)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end

--[[

local function LightVolumePass1A()
	gl.StencilTest(true)
	gl.Culling(GL.FRONT)
	gl.ColorMask(false, false, false, false)
	gl.DepthTest(GL.GEQUAL)
	gl.StencilOp(GL_ZERO, GL_INCR, GL_ZERO)
	gl.StencilFunc(GL.ALWAYS, 0, 0xFF)

	if dlPoint then
		lightShader:SetUniformIntAlways("lightType", 0)
		gl.CallList(dlPoint)
	end
	if dlBeam then
		lightShader:SetUniformIntAlways("lightType", 1)
		gl.CallList(dlBeam)
	end
	if dlCone then
		lightShader:SetUniformIntAlways("lightType", 2)
		gl.CallList(dlCone)
	end
end

local function LightVolumePass2A()
	gl.Culling(GL.BACK)
	gl.ColorMask(true, true, true, true)
	gl.DepthTest(GL.LEQUAL)
	gl.StencilOp(GL_ZERO, GL_ZERO, GL_ZERO)
	gl.StencilFunc(GL.EQUAL, 0, 0xFF)

	if dlPoint then
		lightShader:SetUniformIntAlways("lightType", 0)
		gl.CallList(dlPoint)
	end
	if dlBeam then
		lightShader:SetUniformIntAlways("lightType", 1)
		gl.CallList(dlBeam)
	end
	if dlCone then
		lightShader:SetUniformIntAlways("lightType", 2)
		gl.CallList(dlCone)
	end
	--cleanup
	gl.StencilTest(false)
	--gl.DepthTest(GL.LEQUAL)
	gl.Culling(false)
end

]]--
--[[
local function LightVolumePass1B()
	gl.StencilTest(true)

	gl.Culling(false)
	gl.DepthTest(GL.LEQUAL)
	gl.ColorMask(false, false, false, false)

	gl.StencilOpSeparate(GL.BACK, GL_KEEP, GL_INCR_WRAP, GL_KEEP)
	gl.StencilOpSeparate(GL.FRONT, GL_KEEP, GL_DECR_WRAP, GL_KEEP)

	gl.StencilFunc(GL.ALWAYS, 0, 0)

	if dlPoint then
		lightShader:SetUniformIntAlways("lightType", 0)
		gl.CallList(dlPoint)
	end
	if dlBeam then
		lightShader:SetUniformIntAlways("lightType", 1)
		gl.CallList(dlBeam)
	end
	if dlCone then
		lightShader:SetUniformIntAlways("lightType", 2)
		gl.CallList(dlCone)
	end
end

local function LightVolumePass2B()
	gl.Culling(GL.FRONT)
	gl.ColorMask(true, true, true, true)

	gl.DepthTest(false)
	--gl.StencilOp(GL_ZERO, GL_ZERO, GL_ZERO)
	gl.StencilFunc(GL.NOTEQUAL, 0, 0xFF);

	if dlPoint then
		lightShader:SetUniformIntAlways("lightType", 0)
		gl.CallList(dlPoint)
	end
	if dlBeam then
		lightShader:SetUniformIntAlways("lightType", 1)
		gl.CallList(dlBeam)
	end
	if dlCone then
		lightShader:SetUniformIntAlways("lightType", 2)
		gl.CallList(dlCone)
	end
	--cleanup
	gl.StencilTest(false)
	--gl.Culling(GL.BACK)
end
]]--

local function LightVolumePassSimple()
	gl.Culling(GL.BACK)
	gl.DepthTest(GL.LEQUAL)

	if dlPoint then
		lightShader:SetUniformIntAlways("lightType", 0)
		gl.CallList(dlPoint)
	end
	if dlBeam then
		lightShader:SetUniformIntAlways("lightType", 1)
		gl.CallList(dlBeam)
	end
	if dlCone then
		lightShader:SetUniformIntAlways("lightType", 2)
		gl.CallList(dlCone)
	end
	--cleanup
	gl.DepthTest(GL.LEQUAL)
	gl.Culling(false)
end

local function LightVolumePassDebug()
	gl.DepthTest(true)

	if dlPoint then
		lightShader:SetUniformIntAlways("lightType", 0)
		gl.CallList(dlPoint)
	end
	if dlBeam then
		lightShader:SetUniformIntAlways("lightType", 1)
		gl.CallList(dlBeam)
	end
	if dlCone then
		lightShader:SetUniformIntAlways("lightType", 2)
		gl.CallList(dlCone)
	end
	gl.DepthTest(GL.LEQUAL)
end

function widget:Update()
	PrepareLightDisplayLists()
end

function widget:DrawWorld()
	lightShader:ActivateWith( function ()
		lightShader:SetUniformMatrix("viewMat", "camera")
		lightShader:SetUniformMatrix("projMat", "projection")
		LightVolumePass1()
		LightVolumePass2()
		--LightVolumePassSimple()
		--LightVolumePassDebug()
		--LightVolumePass1B()
		--LightVolumePass2B()
	end)
end