local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Unit Stencil GL4",
		desc      = "A fun approach to minimizing the cost of some fun shaders",
		author    = "Beherith; macOS NoGS adaptation",
		date      = "2022.03.05",
		license   = "GNU GPL, v2 or later",
		layer     = 50,
		enabled   = true,
		depends   = {'gl4'},
	}
end

-- Official BAR contract:
-- Lua tracks visible units/features and uploads bbox + id instance data.
-- The GPU expands each instance into a low-res stencil proxy texture.
local spEcho = Spring.Echo

local unitStencilVBO = nil
local featureStencilVBO = nil
local unitStencilShader = nil
local stencilProxyVBO = nil
local stencilProxyVertexCount = 18

local unitFeatureStencilTex = nil

local unitDimensionsXYZ = {}
local featureDimensionsXYZ = {}

local addRadius = 10

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable
local popElementInstance = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 5000

layout (location = 0) in vec4 unitModelMinXYZ;
layout (location = 1) in vec4 unitModelMaxXYZ;
layout (location = 2) in uvec4 instData;
layout (location = 3) in vec4 proxyVertex;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

struct SUniformsBuffer {
	uint composite; // u8 drawFlag; u8 unused1; u16 id;

	uint unused2;
	uint unused3;
	uint unused4;

	float maxHealth;
	float health;
	float unused5;
	float unused6;

	vec4 drawPos;
	vec4 speed;
	vec4[4] userDefined;
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
	SUniformsBuffer uni[];
};

#line 10000

uniform float addRadius = 10;
uniform int debugDisableProxyCull = 0;
uniform int debugTopFaceOnly = 0;
uniform int debugFixedProxy = 0;
uniform int debugPointSprite = 0;
uniform float debugPointSize = 5.0;
uniform float pointSizeScale = 1.0;
uniform vec2 stencilTexSize = vec2(512.0, 512.0);

float SelectMinMax(float minValue, float maxValue, float selector)
{
	return (selector < 0.5) ? minValue : maxValue;
}

void main()
{
	vec4 centerpos = vec4(uni[instData.y].drawPos);
	vec4 Mins = unitModelMinXYZ;
	vec4 Maxs = unitModelMaxXYZ;

	bool drawProxy = true;

	if (debugDisableProxyCull == 0) {
		if (isSphereVisibleXY(vec4(centerpos.xyz, 1.0), addRadius + Maxs.x + Maxs.z)) {
			drawProxy = false;
		}

		if ((uni[instData.y].composite & 0x00000003u) < 1u) {
			drawProxy = false;
		}
	}

	if (!drawProxy) {
		gl_Position = vec4(0.0, 0.0, 2.0, 1.0);
		return;
	}

	if (debugPointSprite == 1) {
		vec4 centerClip = cameraViewProj * vec4(centerpos.xyz, 1.0);
		vec2 maxXZ = max(abs(Mins.xz), abs(Maxs.xz));
		float radius = length(maxXZ) + addRadius;
		vec3 cameraRight = cameraViewInv[0].xyz;
		vec4 radiusClip = cameraViewProj * vec4(centerpos.xyz + cameraRight * radius, 1.0);
		vec2 centerNDC = centerClip.xy / max(abs(centerClip.w), 0.0001);
		vec2 radiusNDC = radiusClip.xy / max(abs(radiusClip.w), 0.0001);
		float pointDiameter = 2.0 * length((radiusNDC - centerNDC) * stencilTexSize * 0.5);

		gl_Position = centerClip;
		gl_PointSize = clamp(max(debugPointSize, pointDiameter * pointSizeScale), 2.0, 96.0);
		return;
	}

	vec3 camPos = cameraViewInv[3].xyz;
	vec3 camDir = normalize(camPos - centerpos.xyz);

	float s = sin(centerpos.w);
	float c = cos(centerpos.w);

	mat3 rotY = mat3(
		 c, 0.0, -s,
		0.0, 1.0, 0.0,
		 s, 0.0,  c);

	float face = proxyVertex.x;
	if (debugTopFaceOnly == 1 && face > 0.5) {
		gl_Position = vec4(0.0, 0.0, 2.0, 1.0);
		return;
	}

	if (debugFixedProxy == 1) {
		float halfSize = 12.0;
		float x = SelectMinMax(-halfSize, halfSize, proxyVertex.y);
		float z = SelectMinMax(-halfSize, halfSize, proxyVertex.w);
		vec3 expandedPos = centerpos.xyz + vec3(x, 8.0, z);
		gl_Position = cameraViewProj * vec4(expandedPos, 1.0);
		return;
	}

	float x = SelectMinMax(Mins.x, Maxs.x, proxyVertex.y);
	float y = SelectMinMax(Mins.y, Maxs.y, proxyVertex.z);
	float z = SelectMinMax(Mins.z, Maxs.z, proxyVertex.w);

	if (face > 0.5 && face < 1.5) {
		x = (dot(vec3(c, 0.0, -s), camDir) < 0.0) ? Mins.x : Maxs.x;
	} else if (face > 1.5) {
		z = (dot(vec3(s, 0.0, c), camDir) > 0.0) ? Maxs.z : Mins.z;
	}

	vec3 primitiveCoords = vec3(x, y, z);
	vec3 vecnorm = sign(primitiveCoords);
	vec3 expandedPos = centerpos.xyz + rotY * (vec3(addRadius, 0.0, addRadius) * vecnorm + primitiveCoords);
	gl_Position = cameraViewProj * vec4(expandedPos, 1.0);
}
]]

local fsSrc = [[
#version 150 compatibility

uniform float stencilColor = 1.0;
uniform int debugPointSprite = 0;

void main(void)
{
	if (debugPointSprite == 1) {
		vec2 pointCoord = gl_PointCoord * 2.0 - 1.0;
		if (dot(pointCoord, pointCoord) > 1.0) {
			discard;
		}
	}
	gl_FragColor = vec4(stencilColor, stencilColor, stencilColor, 1.0);
}
]]

local function goodbye(reason)
	spEcho("Unit Stencil GL4 widget exiting with reason: " .. reason)
end

local resolution = 4
local vsx, vsy
local debugStencilTexture = false
local debugDisableProxyCull = false
local debugTopFaceOnly = false
local debugFixedProxy = false
local debugPointSprite = true
local debugPointSize = 2
local pointSizeScale = 1.15

local function MakeStencilProxyVBO()
	local data = {
		-- Top face, two triangles equivalent to the official triangle strip.
		0, 0, 1, 0,
		0, 1, 1, 0,
		0, 0, 1, 1,
		0, 0, 1, 1,
		0, 1, 1, 0,
		0, 1, 1, 1,

		-- Camera-facing left/right face.
		1, 0, 1, 0,
		1, 0, 1, 1,
		1, 0, 0, 0,
		1, 0, 0, 0,
		1, 0, 1, 1,
		1, 0, 0, 1,

		-- Camera-facing front/back face.
		2, 0, 1, 0,
		2, 1, 1, 0,
		2, 0, 0, 0,
		2, 0, 0, 0,
		2, 1, 1, 0,
		2, 1, 0, 0,
	}

	local vbo = gl.GetVBO(GL.ARRAY_BUFFER, false)
	if vbo == nil then
		goodbye("Failed to create unit stencil proxy VBO")
		return nil
	end

	vbo:Define(stencilProxyVertexCount, {
		{id = 3, name = 'proxyVertex', size = 4},
	})
	vbo:Upload(data)

	return vbo
end

function widget:ViewResize()
	local GL_R8 = 0x8229
	vsx, vsy = Spring.GetViewGeometry()
	if unitFeatureStencilTex then gl.DeleteTexture(unitFeatureStencilTex) end
	unitFeatureStencilTex = gl.CreateTexture(vsx / resolution, vsy / resolution, {
		format = GL_R8,
		fbo = true,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	})
end

local function AttachStencilVAO(instanceTable)
	instanceTable.VAO = gl.GetVAO()
	if instanceTable.VAO == nil then
		goodbye("Failed to create stencil VAO")
		return false
	end
	if debugPointSprite then
		instanceTable.VAO:AttachVertexBuffer(instanceTable.instanceVBO)
	else
		instanceTable.VAO:AttachVertexBuffer(stencilProxyVBO)
		instanceTable.VAO:AttachInstanceBuffer(instanceTable.instanceVBO)
	end
	return true
end

local function InitDrawPrimitiveAtUnit(DPATname)
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	local patchedVsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	local patchedFsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)

	local drawPrimitiveAtUnitShader = LuaShader(
		{
			vertex = patchedVsSrc,
			fragment = patchedFsSrc,
			uniformInt = {
				debugDisableProxyCull = 0,
				debugTopFaceOnly = 0,
				debugFixedProxy = 0,
				debugPointSprite = 0,
			},
			uniformFloat = {
				addRadius = 1,
				stencilColor = 1,
				debugPointSize = 2,
				pointSizeScale = 1,
				stencilTexSize = {512, 512},
			},
		},
		DPATname .. "Shader GL4 NoGS"
	)

	local shaderCompiled = drawPrimitiveAtUnitShader:Initialize()
	if not shaderCompiled then
		goodbye("Failed to compile " .. DPATname .. " GL4 NoGS")
		return nil
	end

	stencilProxyVBO = MakeStencilProxyVBO()
	if stencilProxyVBO == nil then
		return nil
	end

	unitStencilVBO = InstanceVBOTable.makeInstanceVBOTable(
		{
			{id = 0, name = 'unitModelMinXYZ', size = 4},
			{id = 1, name = 'unitModelMaxXYZ', size = 4},
			{id = 2, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
		},
		64,
		DPATname .. "VBO",
		2
	)
	if unitStencilVBO == nil then
		goodbye("Failed to create " .. DPATname .. "VBO")
		return nil
	end
	if not AttachStencilVAO(unitStencilVBO) then
		return nil
	end

	featureStencilVBO = InstanceVBOTable.makeInstanceVBOTable(
		{
			{id = 0, name = 'unitModelMinXYZ', size = 4},
			{id = 1, name = 'unitModelMaxXYZ', size = 4},
			{id = 2, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
		},
		64,
		"featurestencil VBO",
		2
	)
	if featureStencilVBO == nil then
		goodbye("Failed to create featurestencil VBO")
		return nil
	end
	if not AttachStencilVAO(featureStencilVBO) then
		return nil
	end
	featureStencilVBO.featureIDs = true

	return drawPrimitiveAtUnitShader
end

function widget:VisibleUnitAdded(unitID, unitDefID)
	if unitStencilVBO == nil then return end

	if unitDimensionsXYZ[unitDefID] == nil then
		local unitDef = UnitDefs[unitDefID]
		unitDimensionsXYZ[unitDefID] = {
			unitDef.model.minx, math.min(0, unitDef.model.miny), unitDef.model.minz,
			unitDef.model.maxx, unitDef.model.maxy, unitDef.model.maxz,
		}
	end

	local dimsXYZ = unitDimensionsXYZ[unitDefID]
	pushElementInstance(
		unitStencilVBO,
		{
			dimsXYZ[1], dimsXYZ[2], dimsXYZ[3], 0,
			dimsXYZ[4], dimsXYZ[5], dimsXYZ[6], 0,
			0, 0, 0, 0,
		},
		unitID,
		true,
		nil,
		unitID
	)
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	if unitStencilVBO == nil then return end
	InstanceVBOTable.clearInstanceTable(unitStencilVBO)
	for unitID, unitDefID in pairs(extVisibleUnits) do
		widget:VisibleUnitAdded(unitID, unitDefID)
	end
end

function widget:VisibleUnitRemoved(unitID)
	if unitStencilVBO and unitStencilVBO.instanceIDtoIndex[unitID] then
		popElementInstance(unitStencilVBO, unitID)
	end
end

function widget:FeatureCreated(featureID, allyTeam)
	if featureStencilVBO == nil then return end

	local featureDefID = Spring.GetFeatureDefID(featureID)
	if featureDefID == nil then return end

	if featureDimensionsXYZ[featureDefID] == nil then
		local featureDef = FeatureDefs[featureDefID]
		if featureDef and featureDef.model then
			local dimsXYZ = {
				featureDef.model.minx, featureDef.model.miny, featureDef.model.minz,
				featureDef.model.maxx, featureDef.model.maxy, featureDef.model.maxz,
			}
			if (dimsXYZ[4] - dimsXYZ[1]) < 1 then return end
			featureDimensionsXYZ[featureDefID] = dimsXYZ
		else
			return
		end
	end

	local dimsXYZ = featureDimensionsXYZ[featureDefID]
	if dimsXYZ == nil then return end
	pushElementInstance(
		featureStencilVBO,
		{
			dimsXYZ[1], dimsXYZ[2], dimsXYZ[3], 0,
			dimsXYZ[4], dimsXYZ[5], dimsXYZ[6], 0,
			0, 0, 0, 0,
		},
		featureID,
		true,
		nil,
		featureID
	)
end

function widget:FeatureDestroyed(featureID)
	if featureStencilVBO and featureStencilVBO.instanceIDtoIndex[featureID] then
		popElementInstance(featureStencilVBO, featureID)
	end
end

local function DrawMe()
	if unitStencilVBO == nil or featureStencilVBO == nil then return end
	if unitStencilVBO.usedElements > 0 or featureStencilVBO.usedElements > 0 then
		gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
		gl.Blending(GL.ONE, GL.ZERO)
		gl.Culling(false)
		unitStencilShader:Activate()
		unitStencilShader:SetUniform("addRadius", addRadius)
		unitStencilShader:SetUniformInt("debugDisableProxyCull", debugDisableProxyCull and 1 or 0)
		unitStencilShader:SetUniformInt("debugTopFaceOnly", debugTopFaceOnly and 1 or 0)
		unitStencilShader:SetUniformInt("debugFixedProxy", debugFixedProxy and 1 or 0)
		unitStencilShader:SetUniformInt("debugPointSprite", debugPointSprite and 1 or 0)
		unitStencilShader:SetUniform("debugPointSize", debugPointSize)
		unitStencilShader:SetUniform("pointSizeScale", pointSizeScale)
		unitStencilShader:SetUniform("stencilTexSize", vsx / resolution, vsy / resolution)
		if featureStencilVBO.usedElements > 0 then
			unitStencilShader:SetUniform("stencilColor", 0.5)
			if debugPointSprite then
				featureStencilVBO.VAO:DrawArrays(GL.POINTS, featureStencilVBO.usedElements)
			else
				featureStencilVBO.VAO:DrawArrays(GL.TRIANGLES, stencilProxyVertexCount, 0, featureStencilVBO.usedElements, 0)
			end
		end
		if unitStencilVBO.usedElements > 0 then
			unitStencilShader:SetUniform("stencilColor", 1.0)
			if debugPointSprite then
				unitStencilVBO.VAO:DrawArrays(GL.POINTS, unitStencilVBO.usedElements)
			else
				unitStencilVBO.VAO:DrawArrays(GL.TRIANGLES, stencilProxyVertexCount, 0, unitStencilVBO.usedElements, 0)
			end
		end
		unitStencilShader:Deactivate()
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
end

function widget:DrawWorldPreUnit()
	-- DrawMe()
end

local stencilRequested = false

function widget:DrawWorld()
	if stencilRequested then
		gl.RenderToTexture(unitFeatureStencilTex, DrawMe)
		stencilRequested = false
	end
end

function widget:DrawScreen()
	if not debugStencilTexture or not unitFeatureStencilTex then return end

	stencilRequested = true
	local width = 512
	local height = math.max(1, width * (vsy / vsx))
	local x0 = 16
	local y0 = 16
	local unitCount = (unitStencilVBO and unitStencilVBO.usedElements) or 0
	local featureCount = (featureStencilVBO and featureStencilVBO.usedElements) or 0

	gl.Color(1, 1, 1, 1)
	gl.Blending(GL.ONE, GL.ZERO)
	gl.Texture(unitFeatureStencilTex)
	gl.TexRect(x0, y0, x0 + width, y0 + height, 0, 0, 1, 1)
	gl.Texture(false)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	if gl.Text then
		gl.Color(1, 1, 1, 1)
		gl.Text("UnitStencil u=" .. unitCount .. " f=" .. featureCount, x0, y0 + height + 10, 14, "o")
	end
end

local function GetUnitStencilTexture()
	stencilRequested = true
	return unitFeatureStencilTex
end

function widget:Initialize()
	unitStencilShader = InitDrawPrimitiveAtUnit("unitStencils")
	if unitStencilShader == nil then
		widgetHandler:RemoveWidget()
		return
	end

	widget:ViewResize()

	WG['unitstencilapi'] = {}
	WG['unitstencilapi'].GetUnitStencilTexture = GetUnitStencilTexture
	WG['unitstencilapi'].members = {
		ok = "yes",
		mode = "nogs-gpu-point-sprite",
		vsSrc = vsSrc,
		fsSrc = fsSrc,
		unitStencilVBO = unitStencilVBO,
		featureStencilVBO = featureStencilVBO,
		stencilProxyVBO = stencilProxyVBO,
	}
	widgetHandler:RegisterGlobal('GetUnitStencilTexture', WG['unitstencilapi'].GetUnitStencilTexture)

	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		local visibleUnits = WG['unittrackerapi'].visibleUnits
		for unitID, unitDefID in pairs(visibleUnits) do
			widget:VisibleUnitAdded(unitID, unitDefID)
		end
		for _, featureID in ipairs(Spring.GetAllFeatures()) do
			widget:FeatureCreated(featureID)
		end
	end
end

function widget:Shutdown()
	if unitFeatureStencilTex then
		gl.DeleteTexture(unitFeatureStencilTex)
		unitFeatureStencilTex = nil
	end
	WG['unitstencilapi'] = nil
	widgetHandler:DeregisterGlobal('GetUnitStencilTexture')
end
