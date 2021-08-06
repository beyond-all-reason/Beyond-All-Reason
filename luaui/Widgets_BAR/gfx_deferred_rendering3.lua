--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
	name      = "Deferred rendering3",
	version   = 3,
	desc      = "Collects and renders point, cone and beam lights",
	author    = "ivand",
	date      = "2020",
	license   = "GPL V2",
	layer     = -99999990,
	enabled   = false
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local glBeginEnd             = gl.BeginEnd
local glBlending             = gl.Blending
local glCulling              = gl.Culling
local glCallList             = gl.CallList
local glDeleteList           = gl.DeleteList
local glClear                = gl.Clear
local glVertex               = gl.Vertex
local glColor                = gl.Color
local glColorMask            = gl.ColorMask
local glStencilTest          = gl.StencilTest
local glStencilFunc          = gl.StencilFunc
local glStencilOpSeparate    = gl.StencilOpSeparate
local glStencilOp            = gl.StencilOp
local glCreateList           = gl.CreateList
local glDepthMask            = gl.DepthMask
local glDepthTest            = gl.DepthTest
local glGetViewSizes         = gl.GetViewSizes
local glMultiTexCoord        = gl.MultiTexCoord
local glTexture              = gl.Texture
local spEcho                 = Spring.Echo
local spGetCameraPosition    = Spring.GetCameraPosition
local spGetGroundHeight      = Spring.GetGroundHeight

local vsx, vsy

local gameFrame = -1

local GL_STENCIL_BUFFER_BIT = GL.STENCIL_BUFFER_BIT
local GL_POINTS = GL.POINTS
local GL_ONE = GL.ONE
local GL_BACK = GL.BACK
local GL_FRONT = GL.FRONT
local GL_GEQUAL = GL.GEQUAL
local GL_LEQUAL = GL.LEQUAL
local GL_ALWAYS = GL.ALWAYS
local GL_NOTEQUAL = GL.NOTEQUAL
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local GL_KEEP = 0x1E00
local GL_REPLACE = 0x1E01
local GL_ZERO = 0x0000
local GL_INCR = 0x1E02
local GL_INCR_WRAP = 0x8507
local GL_DECR_WRAP = 0x8508

-----------------------------------------

local SHAPE_DEBUG = false

local LONG_ENOUGH = 2
local RETAINED_VERIFICATION_FRERQUENCY = 30
local LIGHTS_UPDATE_FRERQUENCY = 150

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:ViewResize()
	vsx, vsy = glGetViewSizes()
	if (Spring.GetMiniMapDualScreen() == 'left') then
		vsx = vsx / 2
	end
	if (Spring.GetMiniMapDualScreen() == 'right') then
		vsx = vsx / 2
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

---------[[[NEW]]]-----------------

local luaShaderDir = "LuaUI/Widgets_BAR/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")


local vsSrc = [[
#version 330 compatibility
#line 104

layout (location = 0) in vec4 attr0;
layout (location = 1) in vec4 attr1;
layout (location = 2) in vec4 col0;
layout (location = 3) in vec4 col1;

uniform mat4 viewMat;
uniform mat4 projMat;

out DataVS {
	vec4 color0;
	vec4 color1;
	vec4 attrib1;
};

void main() {
	gl_Position = attr0;
	attrib1 = attr1;
	color0  = col0;
	color1  = col1;
}
]]


local gsSrc = [[
#version 330 compatibility
#line 126

layout (points) in;
layout (triangle_strip, max_vertices = 24) out;


uniform mat4 viewMat;
uniform mat4 projMat;

uniform vec3 eyePos;

uniform int shapeDebug;
uniform int clipCtrl01;

in DataVS {
	vec4 color0;
	vec4 color1;
	vec4 attrib1;
} dataIn[];

out DataGS {
	vec4 color0;
	vec4 color1;
	vec4 attrib0; //gl_Vertex
	vec4 attrib1; //gl_MultiTexCoord0
};

#define MyFillFrustumPlane(pIdx, idx0, idx1, idx2) \
{ \
	vec3 v01 = frustumPoints[idx1].xyz - frustumPoints[idx0].xyz; \
	vec3 v02 = frustumPoints[idx2].xyz - frustumPoints[idx0].xyz; \
	vec3 n = cross(v01, v02); \
	float nLen = length(n); \
	float d = dot(n, frustumPoints[idx0].xyz); \
	frustumPlanes[pIdx] = vec4(n, -d) / nLen; \
}

#define MyEmitVertex(idx, customColor) \
{ \
	gl_Position = frustumPoints[idx]; \
	color0 = dataIn[0].color0; \
	color1 = dataIn[0].color1; \
	if (shapeDebug == 1) { \
		color0.rgb = customColor; \
		color1.rgb = customColor; \
	} \
	attrib0 = gl_in[0].gl_Position; \
	attrib1 = dataIn[0].attrib1; \
	EmitVertex(); \
}

// Z-; Z+ are bottom top planes of frustum
void GenericFrustum(mat4 worldMat, vec4 zMinModelCenterPos, vec4 zMaxModelCenterPos, float zMinRadius, float zMaxRadius) {
	mat4 m = worldMat;

	vec4 frustumPoints[8] = vec4[](
		//zMin (-- -+ +- ++)
		m * (zMinModelCenterPos + vec4(-zMinRadius, -zMinRadius, 0.0, 0.0)),
		m * (zMinModelCenterPos + vec4(-zMinRadius,  zMinRadius, 0.0, 0.0)),
		m * (zMinModelCenterPos + vec4( zMinRadius, -zMinRadius, 0.0, 0.0)),
		m * (zMinModelCenterPos + vec4( zMinRadius,  zMinRadius, 0.0, 0.0)),

		//zMax (-- -+ +- ++)
		m * (zMaxModelCenterPos + vec4(-zMaxRadius, -zMaxRadius, 0.0, 0.0)),
		m * (zMaxModelCenterPos + vec4(-zMaxRadius,  zMaxRadius, 0.0, 0.0)),
		m * (zMaxModelCenterPos + vec4( zMaxRadius, -zMaxRadius, 0.0, 0.0)),
		m * (zMaxModelCenterPos + vec4( zMaxRadius,  zMaxRadius, 0.0, 0.0))
	);

	vec4 frustumPlanes[6];

	MyFillFrustumPlane(0, 3, 1, 2);
	MyFillFrustumPlane(1, 4, 5, 6);
	MyFillFrustumPlane(2, 0, 1, 4);
	MyFillFrustumPlane(3, 3, 2, 7);
	MyFillFrustumPlane(4, 0, 4, 2);
	MyFillFrustumPlane(5, 7, 5, 3);

	bool camInsideFrustum = true;

	for (int i = 0; i < 6; i++) {
		const float leeWay = 64.0;
		if (dot(vec4(eyePos, 1.0), frustumPlanes[i]) - leeWay > 0.0) {
			camInsideFrustum = false;
			break;
		}
	}

	for (int i = 0; i < 8; ++i) {
		frustumPoints[i] = projMat * viewMat * frustumPoints[i];
	}

	if (camInsideFrustum) { //switch over to screenwide quad in case we are inside the lights representor volume
		float zN = -1.0 + float(clipCtrl01);

		frustumPoints[0] = vec4( 1.0, -1.0,  zN, 1.0);
		frustumPoints[1] = vec4(-1.0, -1.0,  zN, 1.0);
		frustumPoints[2] = vec4( 1.0,  1.0,  zN, 1.0);
		frustumPoints[3] = vec4(-1.0,  1.0,  zN, 1.0);
		// Z-
		MyEmitVertex(3, vec3(1, 1, 1));
		MyEmitVertex(1, vec3(1, 0, 0));
		MyEmitVertex(2, vec3(0, 0, 1));
		MyEmitVertex(0, vec3(0, 1, 0));

		EndPrimitive();

		return;
	}

	// Z- / Red
	MyEmitVertex(3, vec3(1, 0, 0));
	MyEmitVertex(1, vec3(1, 0, 0));
	MyEmitVertex(2, vec3(1, 0, 0));
	MyEmitVertex(0, vec3(1, 0, 0));
	EndPrimitive();

	// Z+ / Yellow
	MyEmitVertex(4, vec3(1, 1, 0));
	MyEmitVertex(5, vec3(1, 1, 0));
	MyEmitVertex(6, vec3(1, 1, 0));
	MyEmitVertex(7, vec3(1, 1, 0));
	EndPrimitive();

	// X- / Green
	MyEmitVertex(0, vec3(0, 1, 0));
	MyEmitVertex(1, vec3(0, 1, 0));
	MyEmitVertex(4, vec3(0, 1, 0));
	MyEmitVertex(5, vec3(0, 1, 0));
	EndPrimitive();

	// X+ / Cyan
	MyEmitVertex(3, vec3(0, 1, 1));
	MyEmitVertex(2, vec3(0, 1, 1));
	MyEmitVertex(7, vec3(0, 1, 1));
	MyEmitVertex(6, vec3(0, 1, 1));
	EndPrimitive();

	// Y- / Blue
	MyEmitVertex(0, vec3(0, 0, 1));
	MyEmitVertex(4, vec3(0, 0, 1));
	MyEmitVertex(2, vec3(0, 0, 1));
	MyEmitVertex(6, vec3(0, 0, 1));
	EndPrimitive();

	// Y+ / Magenta
	MyEmitVertex(7, vec3(1, 0, 1));
	MyEmitVertex(5, vec3(1, 0, 1));
	MyEmitVertex(3, vec3(1, 0, 1));
	MyEmitVertex(1, vec3(1, 0, 1));
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

mat4 GetDirectionAndTranslationMatrix(vec3 f, vec3 xyz) {
	// https://math.stackexchange.com/questions/3122010/how-to-deterministically-pick-a-vector-that-is-guaranteed-to-be-non-parallel-to
	vec3 up = (f.y != 0.0) ? vec3(0.0, f.z, -f.y) : vec3(-f.z, 0.0, f.x);

	vec3 s = normalize(cross(f, up));
	vec3 u = cross(s, f);

	return mat4(
		vec4(s,   0.0),
		vec4(u,   0.0),
		vec4(f,   0.0),
		vec4(xyz, 1.0)
	);
}


void main() {
	vec3 pos0 = gl_in[0].gl_Position.xyz;
	float r0 = gl_in[0].gl_Position.w;

	const vec4 startModelPos = vec4(0.0, 0.0, 0.0, 1.0);

	if (dataIn[0].attrib1.w == 0) { // omni-dir light
		mat4 worldMat = GetDirectionAndTranslationMatrix(vec3(0, 1, 0), pos0);

		GetSphereBoundingShape(worldMat, startModelPos, r0);
	}
	else { // beam light
		vec3 pos1 = dataIn[0].attrib1.xyz;
		float r1 = dataIn[0].attrib1.w;

		vec4 dirLen = vec4(pos1 - pos0, 0.0);
		dirLen.w = length(dirLen.xyz);
		dirLen.xyz /= dirLen.w;

		vec4 endModelPos = vec4(0.0, 0.0, dirLen.w, 1.0);

		mat4 worldMat = GetDirectionAndTranslationMatrix(dirLen.xyz, pos0);

		GetBeamBoundingShape(worldMat, startModelPos, endModelPos, r0, r1);
	}
}

]]

local fsSrc = [[
#version 330 compatibility
#line 362

uniform vec2 viewPortSize;

uniform sampler2D mdlNormalTex;
uniform sampler2D mdlDepthTex;
uniform sampler2D mapNormalTex;
uniform sampler2D mapDepthTex;
uniform sampler2D mdlExtraTex;

uniform mat4 viewMat;
uniform mat4 invViewProjMat;

uniform int clipCtrl01;
uniform int shapeDebug;

in DataGS {
	vec4 color0;
	vec4 color1;
	vec4 attrib0;
	vec4 attrib1;
};

uniform vec3 eyePos;

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

// Calculate out of the fragment in screen space the view space position.
vec4 GetWorldPos(vec2 texCoord, float sampledDepth) {
	vec4 projPosition = vec4(0.0, 0.0, 0.0, 1.0);

	//texture space [0;1] to NDC space [-1;1]
	if (clipCtrl01 == 1) {
		//don't transform depth as it's in the same [0;1] space
		projPosition.xyz = vec3(NORM2SNORM(texCoord), sampledDepth);
	} else {
		projPosition.xyz = NORM2SNORM(vec3(texCoord, sampledDepth));
	}

	vec4 worldPosition = invViewProjMat * projPosition;
	worldPosition /= worldPosition.w;

	return worldPosition;
}

float GetPointProjectionOnLine(vec3 A, vec3 B, vec3 P, out vec3 pProj) {
	vec3 AB = B - A;
	vec3 AP = P - A;

	float t = dot(AP, AB) / dot (AB, AB);
	pProj = mix(A, B, t);
	return t;
}

float GetDistanceAttenuation(vec3 lightStart, vec3 lightEnd, vec3 worldPoint, float dAttRel) {
	vec3 worldPointLineProj;
	GetPointProjectionOnLine(lightStart, lightEnd, worldPoint, worldPointLineProj);

	float dMax = distance(lightStart, lightEnd);
	#if 0
		float dWorldPointDist = distance(lightStart, worldPointLineProj); //calculate distance along the light main direction
	#else
		float dWorldPointDist = distance(lightStart, worldPoint        ); //calculate distance no matter the direction
	#endif

	float dAtt = dMax * dAttRel;
	return smoothstep(dMax, dAtt, dWorldPointDist);
}

float GetRadialAttenuation(vec3 lightStart, vec3 lightEnd, vec3 worldPoint, float r0, float r1, float rAttRel) {
	vec3 worldPointLineProj;
	float t = GetPointProjectionOnLine(lightStart, lightEnd, worldPoint, worldPointLineProj);

	float dRadial = distance(worldPoint, worldPointLineProj);

	float r = mix(r0, r1, t);

	float rAtt = rAttRel * r;
	return smoothstep(r, rAtt, dRadial);
}

float GetBeamAttenuation(vec3 lightStart, vec3 lightEnd, vec3 worldPoint, float dAttRel, float rAttRel, float r0, float r1) {
	float attDir = GetDistanceAttenuation(lightStart, lightEnd, worldPoint, dAttRel);
	float attRad = GetRadialAttenuation(lightStart, lightEnd, worldPoint, r0, r1, rAttRel);
	return attDir * attRad;
}

float GetOmniAttenuation(vec3 lightStart, vec3 worldPos, float dAttRel, float r) {
	float d = distance(worldPos, lightStart);
	float dAtt = dAttRel * r;
	return smoothstep(r, dAtt, d);
}

void main() {
	float specularHighlight = 1.0; // default specular factor, for models it should be read
	float modelLightMult = 1.0; //models recieve additional lighting, looks better.
	float specularExponent = 8.0; //default specular power, for models it should be different TODO

	vec2 uv = gl_FragCoord.xy / viewPortSize;

	float mapDepth = texture(mapDepthTex, uv).x;
	float mdlDepth = texture(mdlDepthTex, uv).x;

	if (min(mapDepth, mdlDepth) == 1.0) {
		#if 1
			gl_FragColor = vec4(0.0);
			return;
		#else
			discard;
		#endif
	}

	vec4 worldPos;
	vec3 worldNormal;
	vec4 modelExtra = texture(mdlExtraTex, uv);

	//if (any(bvec2(mapDepth > mdlDepth, modelExtra.a < 0.5))) {
	if ((mdlDepth < mapDepth)) {
		worldPos = GetWorldPos(uv, mdlDepth);
		worldNormal = NORM2SNORM(texture(mdlNormalTex, uv).xyz);
		modelLightMult = 1.5;
		specularHighlight = 1.0 + 2.0 * modelExtra.g;
		specularExponent = specularExponent + 20.0;
	} else {
		worldPos = GetWorldPos(uv, mapDepth);
		worldNormal = NORM2SNORM(texture(mapNormalTex, uv).xyz);
	}

	worldNormal = normalize(worldNormal);

	float att;

	if (attrib1.w > 0) {
		att = GetBeamAttenuation(attrib0.xyz, attrib1.xyz, worldPos.xyz, color0.w, color1.w, attrib0.w, attrib1.w);
	} else {
		att = GetOmniAttenuation(attrib0.xyz, worldPos.xyz, color0.w, attrib0.w);
	}

	vec3 lightColor = mix(color1.rgb, color0.rgb, att);

	vec3 L = normalize(attrib0.xyz - worldPos.xyz); //lightPos - worldPos
	vec3 V = normalize(eyePos - worldPos.xyz); //viewPos - worldPos
	vec3 H = normalize(L + V);

	float diffTerm = max(dot(worldNormal, L), 0.0);
	float specTerm = specularHighlight * pow(max(dot(worldNormal, H), 0.0), specularExponent);
	//diffTerm = 0.0;

	gl_FragColor = modelLightMult * (att * diffTerm + pow(att, 0.5) * specTerm) * vec4(lightColor, 1.0);

	if (shapeDebug == 1)
		gl_FragColor = vec4(lightColor, 1.0);

}
]]

local lightsDefArrayGaps = {}
local lightsDefArray = {}
local function AddLight(color0, color1, attrib0, attrib1)
	local lightID = next(lightsDefArrayGaps)
	if lightID then --taking this gap
		lightsDefArrayGaps[lightID] = nil
	else --no gaps, add new entry
		lightID = #lightsDefArray + 1
	end
	lightsDefArray[lightID] = {
		color0 = color0,
		color1 = color1,
		attrib0 = attrib0,
		attrib1	= attrib1,
		gameFrame = gameFrame,
		deleted = false,
		retained = false,
	}
	return lightID
end

local retainedLightsDLNeedsUpdate = true
local function DeleteLight(lightID)
	if lightsDefArray[lightID] then
		lightsDefArray[lightID].deleted = true --mark for deletetion, but do not delete
		retainedLightsDLNeedsUpdate = retainedLightsDLNeedsUpdate or lightsDefArray[lightID].retained

		lightsDefArrayGaps[lightID] = true
	end
end

local function AddBeamLight(startPos, endPos, startRadius, endRadius, distAttRel, radialAttRel, mainColor, edgeColor)
	if not radialAttRel then
		radialAttRel = 0.5
	end
	radialAttRel = math.min(0.99, math.max(0.01, radialAttRel))

	if not distAttRel then
		distAttRel = 0.75
	end
	distAttRel = math.min(0.99, math.max(0.01, distAttRel))

	if not edgeColor then
		edgeColor = mainColor
	end

	startRadius = math.max(startRadius, 1e-3)
	endRadius = math.max(endRadius, 1e-3)

	local attrib0 = {startPos[1], startPos[2], startPos[3], startRadius}
	local attrib1 = {  endPos[1],   endPos[2],   endPos[3], endRadius}
	local color0  = {mainColor[1], mainColor[2], mainColor[3], distAttRel}
	local color1  = {edgeColor[1], edgeColor[2], edgeColor[3], radialAttRel}
	return AddLight(color0, color1, attrib0, attrib1)
end

local function AddConeLight(startPos, endPos, angleCutoff, distAttRel, radialAttRel, mainColor, edgeColor)
	local r = math.sqrt((endPos[1] - startPos[1])^2 + (endPos[2] - startPos[2])^2 + (endPos[3] - startPos[3])^2)
	angleCutoff = math.min(math.max(angleCutoff, 0.01), math.pi - 0.01)
	local rFar = r * math.tan(0.5 * angleCutoff);

	return AddBeamLight(startPos, endPos, 0, rFar, distAttRel, radialAttRel, mainColor, edgeColor)
end

local function AddPointLight(startPos, radius, distAttRel, mainColor, edgeColor)
	if not distAttRel then
		distAttRel = 0.75
	end
	distAttRel = math.min(0.99, math.max(0.01, distAttRel))

	if not edgeColor then
		edgeColor = mainColor
	end

	local attrib0 = {startPos[1], startPos[2], startPos[3], radius}
	local attrib1 = {0, 0, 0, 0}
	local color0  = {mainColor[1], mainColor[2], mainColor[3], distAttRel}
	local color1  = {edgeColor[1], edgeColor[2], edgeColor[3], 0}
	return AddLight(color0, color1, attrib0, attrib1)
end

local retainedLightsVAO
local immediateLightsVAO
local immediateLightsVAOs = {}

local lightsDefRetainedVAOArraySize = 0
local lightsDefRetainedVAOArray = {}
local function PrepareRetainedLights(forceRetainedSearch)
	if (not retainedLightsDLNeedsUpdate) and (not forceRetainedSearch) then
		return
	end

	if (not retainedLightsDLNeedsUpdate) and forceRetainedSearch then
		for i = 1, #lightsDefArray do
			local lightsDef = lightsDefArray[i]

			--not deleted, not retained yet, lives long enough
			if ((not lightsDef.deleted) or (not lightsDef.retained)) and (gameFrame - lightsDef.gameFrame >= LONG_ENOUGH) then
				retainedLightsDLNeedsUpdate = true
				break
			end
		end
	end

	if not retainedLightsDLNeedsUpdate then
		return
	end

	--retainedLightsDL
	--retainedLightsVAO
	lightsDefRetainedVAOArraySize = 0

	for i = 1, #lightsDefArray do
		local lightsDef = lightsDefArray[i]

		--not deleted, not retained yet, lives long enough
		if ((not lightsDef.deleted) or (not lightsDef.retained)) and (gameFrame - lightsDef.gameFrame >= LONG_ENOUGH) then
			lightsDef.retained = true

			local color0 = lightsDef.color0
			local color1 = lightsDef.color1
			local attrib0 = lightsDef.attrib0
			local attrib1 = lightsDef.attrib1

			local m = i - 1

			lightsDefRetainedVAOArray[16 * m +  1] = attrib0[1]
			lightsDefRetainedVAOArray[16 * m +  2] = attrib0[2]
			lightsDefRetainedVAOArray[16 * m +  3] = attrib0[3]
			lightsDefRetainedVAOArray[16 * m +  4] = attrib0[4]

			lightsDefRetainedVAOArray[16 * m +  5] = attrib1[1]
			lightsDefRetainedVAOArray[16 * m +  6] = attrib1[2]
			lightsDefRetainedVAOArray[16 * m +  7] = attrib1[3]
			lightsDefRetainedVAOArray[16 * m +  8] = attrib1[4]

			lightsDefRetainedVAOArray[16 * m +  9] =  color0[1]
			lightsDefRetainedVAOArray[16 * m + 10] =  color0[2]
			lightsDefRetainedVAOArray[16 * m + 11] =  color0[3]
			lightsDefRetainedVAOArray[16 * m + 12] =  color0[4]

			lightsDefRetainedVAOArray[16 * m + 13] =  color1[1]
			lightsDefRetainedVAOArray[16 * m + 14] =  color1[2]
			lightsDefRetainedVAOArray[16 * m + 15] =  color1[3]
			lightsDefRetainedVAOArray[16 * m + 16] =  color1[4]
			
			lightsDefRetainedVAOArraySize = lightsDefRetainedVAOArraySize + 1
		end
	end
	
	retainedLightsVAO:UploadVertexBulk(lightsDefRetainedVAOArray, 0)
	--Spring.Echo("PrepareRetainedLights", Spring.GetGameFrame())

	retainedLightsDLNeedsUpdate = false
end

local lightsDefImmediateVAOArray = {}
local lightsDefImmediateVAOArraySize = 0
local function RenderImmediateLights()
	--Spring.Echo(#lightsDefArray)
	--local immediateCnt = 0
	--[[
	glBeginEnd(GL_POINTS, function ()
		for i = 1, #lightsDefArray do
			local lightsDef = lightsDefArray[i]
			if (not lightsDef.deleted) and (not lightsDef.retained) then
				local color0 = lightsDef.color0
				local color1 = lightsDef.color1
				local attrib0 = lightsDef.attrib0
				local attrib1 = lightsDef.attrib1

				glColor(color0[1], color0[2], color0[3], color0[4])
				glMultiTexCoord(1, color1[1], color1[2], color1[3], color1[4])
				glMultiTexCoord(0, attrib1[1], attrib1[2], attrib1[3],  attrib1[4])
				glVertex(attrib0[1], attrib0[2], attrib0[3],  attrib0[4])

				--immediateCnt = immediateCnt + 1
			end
		end
	end)
	]]--
	--Spring.Echo("Immediate $count = ".. immediateCnt)
	
	--table.setn(lightsDefVAOArray, #lightsDefArray * 4 * 4)
	lightsDefImmediateVAOArraySize = 0

	for i = 1, #lightsDefArray do
		local lightsDef = lightsDefArray[i]
		if (not lightsDef.deleted) and (not lightsDef.retained) then
			local color0 = lightsDef.color0
			local color1 = lightsDef.color1
			local attrib0 = lightsDef.attrib0
			local attrib1 = lightsDef.attrib1
			
			local m = i - 1

			lightsDefImmediateVAOArray[16 * m +  1] = attrib0[1]
			lightsDefImmediateVAOArray[16 * m +  2] = attrib0[2]
			lightsDefImmediateVAOArray[16 * m +  3] = attrib0[3]
			lightsDefImmediateVAOArray[16 * m +  4] = attrib0[4]

			lightsDefImmediateVAOArray[16 * m +  5] = attrib1[1]
			lightsDefImmediateVAOArray[16 * m +  6] = attrib1[2]
			lightsDefImmediateVAOArray[16 * m +  7] = attrib1[3]
			lightsDefImmediateVAOArray[16 * m +  8] = attrib1[4]

			lightsDefImmediateVAOArray[16 * m +  9] =  color0[1]
			lightsDefImmediateVAOArray[16 * m + 10] =  color0[2]
			lightsDefImmediateVAOArray[16 * m + 11] =  color0[3]
			lightsDefImmediateVAOArray[16 * m + 12] =  color0[4]

			lightsDefImmediateVAOArray[16 * m + 13] =  color1[1]
			lightsDefImmediateVAOArray[16 * m + 14] =  color1[2]
			lightsDefImmediateVAOArray[16 * m + 15] =  color1[3]
			lightsDefImmediateVAOArray[16 * m + 16] =  color1[4]

			--immediateCnt = immediateCnt + 1
			lightsDefImmediateVAOArraySize = lightsDefImmediateVAOArraySize + 1
		end
	end
	
	--Spring.Echo("#lightsDefImmediateVAOArray=", #lightsDefImmediateVAOArray, #lightsDefArray)
	
	local df = Spring.GetDrawFrame()
	local tf, pf = (df + 1) % 3 + 1, df % 3 + 1
	
	--Spring.Echo("df, tf, pf  ", df, tf, pf)
	
	--immediateLightsVAOs[tf]:UploadVertexBulk(lightsDefImmediateVAOArray, 0)
	--immediateLightsVAOs[pf]:DrawArrays(GL_POINTS, lightsDefImmediateVAOArraySize)

	--immediateLightsVAO:UploadVertexBulk(lightsDefImmediateVAOArray, 0)
	--immediateLightsVAO:DrawArrays(GL_POINTS, lightsDefImmediateVAOArraySize)
end

local lightsList = {}
local function PrepareLightDisplayLists()
--[[
	AddPointLight({2000, 250, 1500}, 100, 0.5, {1, 0, 1}, nil)
	AddPointLight({2050, 250, 1550}, 200, 0.5, {1, 0, 0}, nil)

	AddBeamLight({5000, 150, 4000}, {4700, 115, 4000}, 10, 250, 0.75, 0.5, {1, 0, 0}, {1, 0, 1})
	AddBeamLight({4000, 150, 4000}, {4300, 115, 4000}, 10, 250, 0.75, 0.85, {1, 1, 1}, {1, 1, 0})
	AddBeamLight({4000, 275, 5000}, {4000, 250, 4700}, 10, 250, 0.75, 0.5, {1, 0, 0}, {1, 0, 1})
	AddBeamLight({4000, 150, 4000}, {4000, 115, 4300}, 10, 250, 0.75, 0.85, {1, 1, 1}, {1, 1, 0})
	--AddBeamLight({4500, 115, 4200}, {4500, 115, 4000}, 10, 250, 0.5, 0.5, {0, 0, 1}, nil)

	--AddBeamLight({2500, 600, 4500}, {2500, 50, 4500}, 10, 250, 0.5, 0.5, {0, 0, 1}, nil)
	AddBeamLight({2500, 600, 4000}, {2500, 50, 4500}, 10, 250, 0.75, 0.5, {1, 0, 0}, nil)
	AddBeamLight({2500, 600, 4000}, {2500, 50, 3500}, 10, 250, 0.75, 0.5, {1, 0, 0}, nil)

	AddConeLight({3615, 1000, 4243}, {3615, 100, 3500}, math.pi / 4, 0.75, 0.5, {0.5, 0.5, 0.5}, {1, 0, 0})
]]--
	for lightID, _ in pairs(lightsList) do
		DeleteLight(lightID)
		lightsList[lightID] = nil
	end

	local cnt = 0

	for x = 0, Game.mapSizeX, 512 do
		for z = 0, Game.mapSizeZ, 512 do

			local gh = Spring.GetGroundHeight(x, z)
			local lightID = AddConeLight({x, gh + 150, z}, {x,  gh - 50, z}, 0.5 * math.pi, 0.5, 0.5,
				{math.random(), math.random(), math.random()},
				{math.random(), math.random(), math.random()}
			)
			lightsList[lightID] = true


			local gh = Spring.GetGroundHeight(x + 128, z + 128)
			local lightID = AddPointLight({x + 128, gh + 50, z + 128}, 100, 0.5,
				{math.random(), math.random(), math.random()},
				{math.random(), math.random(), math.random()}
			)
			lightsList[lightID] = true

			cnt = cnt + 2
		end
	end

	--Spring.Echo("Added "..cnt.." lights")

	local lightID = AddConeLight({3615, 1000, 4243}, {3615, 100, 3500}, math.pi / 4, 0.75, 0.5, {0.5, 0.5, 0.5}, {1, 0, 0})
	lightsList[lightID] = true
end

function widget:Initialize()
	widget:ViewResize()
	 ------[[[NEW]]-----
	 --[[
		glTexture(0, "$model_gbuffer_normtex")
		glTexture(1, "$model_gbuffer_zvaltex")
		glTexture(2, "$map_gbuffer_normtex")
		glTexture(3, "$map_gbuffer_zvaltex")
		glTexture(4, "$model_gbuffer_spectex")
	 ]]--

	lightShader = LuaShader({
		vertex = vsSrc,
		geometry = gsSrc,
		fragment = fsSrc,
		uniformInt = {
			mdlNormalTex = 0,
			mdlDepthTex  = 1,
			mapNormalTex = 2,
			mapDepthTex  = 3,
			mdlExtraTex  = 4,

			clipCtrl01 = (Platform.glSupportClipSpaceControl and 1) or 0,
			shapeDebug = (SHAPE_DEBUG and 1) or 0,
		},
		uniformFloat = {
			viewPortSize = {vsx, vsy},
			eyePos = {0, 0, 0},
		},
	}, "Light Volume Shader2")
	lightShader:Initialize()

	if (gl.CreateShader == nil) then
		Spring.Echo('Deferred Rendering requires shader support!')
		widgetHandler:RemoveWidget(self)
		return
	end

	Spring.SetConfigInt("AllowDeferredMapRendering", 1)
	Spring.SetConfigInt("AllowDeferredModelRendering", 1)

	if (Spring.GetConfigString("AllowDeferredMapRendering") == '0' or Spring.GetConfigString("AllowDeferredModelRendering") == '0') then
		Spring.Echo('Deferred Rendering (gfx_deferred_rendering.lua) requires  AllowDeferredMapRendering and AllowDeferredModelRendering to be enabled in springsettings.cfg!')
		widgetHandler:RemoveWidget(self)
		return
	end

	retainedLightsVAO = gl.GetVAO(true)
	immediateLightsVAO = gl.GetVAO(true)
	
	immediateLightsVAOs = {
		gl.GetVAO(true),
		gl.GetVAO(true),
		gl.GetVAO(true),
	}
	
	immediateLightsVAOs[1]:SetVertexAttributes(32768, {
		[0] = {name = "attr0", size = 4},
		[1] = {name = "attr1", size = 4},
		[2] = {name = "col0", size = 4},
		[3] = {name = "col1", size = 4},
	})

	immediateLightsVAOs[2]:SetVertexAttributes(32768, {
		[0] = {name = "attr0", size = 4},
		[1] = {name = "attr1", size = 4},
		[2] = {name = "col0", size = 4},
		[3] = {name = "col1", size = 4},
	})
	
	immediateLightsVAOs[3]:SetVertexAttributes(32768, {
		[0] = {name = "attr0", size = 4},
		[1] = {name = "attr1", size = 4},
		[2] = {name = "col0", size = 4},
		[3] = {name = "col1", size = 4},
	})


	retainedLightsVAO:SetVertexAttributes(32768, {
		[0] = {name = "attr0", size = 4},
		[1] = {name = "attr1", size = 4},
		[2] = {name = "col0", size = 4},
		[3] = {name = "col1", size = 4},
	})

	immediateLightsVAO:SetVertexAttributes(32768, {
		[0] = {name = "attr0", size = 4},
		[1] = {name = "attr1", size = 4},
		[2] = {name = "col0", size = 4},
		[3] = {name = "col1", size = 4},
	})
end

function widget:Shutdown()
	lightShader:Finalize()
end

function widget:GameFrame(gf)
	gameFrame = gf
	if gf % LIGHTS_UPDATE_FRERQUENCY == 0 then
		PrepareLightDisplayLists()
	end
	PrepareRetainedLights(gf % RETAINED_VERIFICATION_FRERQUENCY == 0)
end

function widget:DrawWorld()
	glDepthMask(false)
	glBlending(GL_ONE, GL_ONE)

	if SHAPE_DEBUG then
		--glCulling(false)
		glDepthMask(true)
	end

	glTexture(0, "$model_gbuffer_normtex")
	glTexture(1, "$model_gbuffer_zvaltex")
	glTexture(2, "$map_gbuffer_normtex")
	glTexture(3, "$map_gbuffer_zvaltex")
	glTexture(4, "$model_gbuffer_spectex")

	lightShader:ActivateWith( function ()
		lightShader:SetUniformMatrix("viewMat", "camera")
		lightShader:SetUniformMatrix("projMat", "projection")
		lightShader:SetUniformMatrix("invViewProjMat","viewprojectioninverse") -- TODO GET THE FUCKING INVERSE OF THIS SHIT!

		local cpx, cpy, cpz = spGetCameraPosition()
		lightShader:SetUniformAlways("eyePos", cpx, cpy, cpz)

		glDepthTest(GL_LEQUAL)
		glCulling(GL_BACK)

		--if retainedLightsDL then
			--glCallList(retainedLightsDL)
		--end
		retainedLightsVAO:DrawArrays(GL_POINTS, lightsDefRetainedVAOArraySize)
		
		RenderImmediateLights()
	end)

	glTexture(0, false)
	glTexture(1, false)
	glTexture(2, false)
	glTexture(3, false)
	glTexture(4, false)

	glDepthMask(true)
	glDepthTest(GL_LEQUAL)
	glCulling(GL_BACK)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
end