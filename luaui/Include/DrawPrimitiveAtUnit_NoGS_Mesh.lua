-------------------------------------------------
-- DrawPrimitiveAtUnit NoGS adapter.
-- Keeps the official Lua-side object stream and replaces GS expansion with
-- an instanced static mesh expanded in the vertex shader.
-------------------------------------------------

local DrawPrimitiveAtUnit = {}

local shaderConfig = {
	TRANSPARENCY = 0.2,
	HEIGHTOFFSET = 1,
	ANIMATION = 1,
	INITIALSIZE = 0.66,
	GROWTHRATE = 4,
	BREATHERATE = 30.0,
	BREATHESIZE = 0.05,
	TEAMCOLORIZATION = 1.0,
	CLIPTOLERANCE = 1.1,
	USETEXTURE = 1,
	BILLBOARD = 0,
	POST_ANIM = " ",
	POST_VERTEX = "v_color = v_color;",
	ZPULL = 256.0,
	POST_GEOMETRY = "",
	POST_SHADING = "fragColor.rgba = fragColor.rgba;",
	MAXVERTICES = 64,
	USE_CIRCLES = 1,
	USE_CORNERRECT = 1,
	USE_TRIANGLES = 1,
	USE_QUADS = 1,
	FULL_ROTATION = 0,
	DISCARD = 0,
	ROTATE_CIRCLES = 1,
	PRE_OFFSET = "",
	USEQUATERNIONS = Engine.FeatureSupport.transformsInGL4 and "1" or "0",
}

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local primitiveShapeVBO = nil
local primitiveShapeVertexCount = 0

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 5000

layout (location = 0) in vec4 lengthwidthcornerheight;
layout (location = 1) in uint teamID;
layout (location = 2) in uint numvertices;
layout (location = 3) in vec4 parameters;
layout (location = 4) in vec4 uvoffsets;
layout (location = 5) in uvec4 instData;

layout (location = 6) in vec4 shapeXZ;
layout (location = 7) in vec4 shapeUV;
layout (location = 8) in vec4 shapeMeta;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

struct SUniformsBuffer {
	uint composite;

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

#define UNITID (uni[instData.y].composite >> 16)

#if USEQUATERNIONS == 0
layout(std140, binding=0) readonly buffer MatrixBuffer {
	mat4 UnitPieces[];
};
#else
//__QUATERNIONDEFS__
#endif

#line 10000

uniform float addRadius = 0.0;
uniform float iconDistance = 20000.0;

out vec4 g_color;
out vec4 g_uv;

struct DataGSCompat {
	uint v_numvertices;
	float v_rotationY;
	vec4 v_color;
	vec4 v_lengthwidthcornerheight;
	vec4 v_centerpos;
	vec4 v_uvoffsets;
	vec4 v_parameters;
	mat3 v_fullrotation;
};

mat3 RotationY(float angle)
{
	float s = sin(angle);
	float c = cos(angle);
	return mat3(
		 c, 0.0, -s,
		0.0, 1.0, 0.0,
		 s, 0.0,  c);
}

bool vertexClipped(vec4 clipspace, float tolerance)
{
	return any(lessThan(clipspace.xyz, -clipspace.www * tolerance)) ||
	       any(greaterThan(clipspace.xyz, clipspace.www * tolerance));
}

vec2 transformUV(vec4 atlas, float u, float v)
{
	float a = atlas.t - atlas.s;
	float b = atlas.q - atlas.p;
	return vec2(atlas.s + a * u, atlas.p + b * v);
}

bool BuildPrimitive(uint actualNumVertices, vec4 dims, out vec3 primitiveCoords, out vec2 primitiveUV, out float addRadiusCorr)
{
	float shapeType = shapeMeta.x;
	float length = dims.x;
	float width = dims.y;
	float cs = dims.z;
	float csuv = (cs / max(length + width, 1.0)) * 2.0;

	addRadiusCorr = shapeMeta.w;
	primitiveCoords = vec3(0.0);
	primitiveUV = vec2(0.0);

	#ifdef USE_TRIANGLES
		if (shapeType == 3.0 && actualNumVertices == 3u) {
			primitiveCoords = vec3(shapeXZ.x * width, 0.0, shapeXZ.z * length);
			primitiveUV = vec2(shapeUV.x, shapeUV.z);
			return true;
		}
	#endif

	#ifdef USE_QUADS
		if (shapeType == 4.0 && actualNumVertices == 4u) {
			primitiveCoords = vec3(shapeXZ.x * width, 0.0, shapeXZ.z * length);
			primitiveUV = vec2(shapeUV.x, shapeUV.z);
			return true;
		}
	#endif

	#ifdef USE_CORNERRECT
		if (shapeType == 2.0 && actualNumVertices == 2u) {
			primitiveCoords = vec3(shapeXZ.x * width + shapeXZ.y * cs, 0.0, shapeXZ.z * length + shapeXZ.w * cs);
			primitiveUV = vec2(shapeUV.x + shapeUV.y * csuv, shapeUV.z + shapeUV.w * csuv);
			return true;
		}
	#endif

	#ifdef USE_CIRCLES
		if (shapeType == 64.0 && actualNumVertices > 5u) {
			uint clampedVertices = min(actualNumVertices, 64u);
			uint stripIndex = uint(shapeMeta.y + 0.5);
			uint triangleMaxStripIndex = uint(shapeMeta.z + 0.5);
			if (triangleMaxStripIndex >= clampedVertices) {
				return false;
			}

			float internalAngle = float(clampedVertices - 2u) * radians(180.0) / float(clampedVertices);
			addRadiusCorr = 1.0 / sin(internalAngle * 0.5);

			if (stripIndex == 0u) {
				primitiveCoords = vec3(-width * 0.5, 0.0, 0.0);
				primitiveUV = vec2(0.0, 0.5);
				return true;
			}

			if (stripIndex == clampedVertices - 1u) {
				primitiveCoords = vec3(width * 0.5, 0.0, 0.0);
				primitiveUV = vec2(1.0, 0.5);
				return true;
			}

			uint numSides = clampedVertices / 2u;
			uint pairIndex = ((stripIndex - 1u) / 2u) + 1u;
			bool upperHalf = ((stripIndex - 1u) % 2u) == 0u;
			float phi = (float(pairIndex) * 3.14159265359 / float(numSides)) - 1.57079632679;
			float sinphi = sin(phi);
			float cosphi = cos(phi);
			float zSign = upperHalf ? 1.0 : -1.0;

			primitiveCoords = vec3(width * 0.5 * sinphi, 0.0, length * 0.5 * cosphi * zSign);
			primitiveUV = vec2(sinphi * 0.5 + 0.5, cosphi * 0.5 * zSign + 0.5);
			return true;
		}
	#endif

	return false;
}

void main()
{
	uint baseIndex = instData.x;
	#if USEQUATERNIONS == 0
		mat4 modelMatrix = UnitPieces[baseIndex];
	#else
		Transform modelWorldTX = GetModelWorldTransform(instData.x);
		mat4 modelMatrix = TransformToMatrix(modelWorldTX);
	#endif

	vec4 v_centerpos = vec4(modelMatrix[3].xyz, 1.0);
	vec4 v_parameters = parameters;
	vec4 v_color = teamColor[teamID];
	vec4 v_uvoffsets = uvoffsets;
	vec4 v_lengthwidthcornerheight = lengthwidthcornerheight;
	uint v_numvertices = numvertices;
	float v_rotationY = atan(modelMatrix[0][2], modelMatrix[0][0]);
	#if (FULL_ROTATION == 1)
		mat3 v_fullrotation = mat3(modelMatrix);
	#endif

	float cameraDistance = length(cameraViewInv[3].xyz - v_centerpos.xyz);

	#if (ANIMATION == 1)
		float animation = clamp(((timeInfo.x + timeInfo.w) - parameters.x) / GROWTHRATE + INITIALSIZE, INITIALSIZE, 1.0);
		if (BREATHERATE != 0.0) {
			animation += sin(timeInfo.x / BREATHERATE) * BREATHESIZE;
		}
		v_lengthwidthcornerheight.xy *= animation;
	#endif

	POST_ANIM

	vec4 centerClipPos = cameraViewProj * vec4(v_centerpos.xyz, 1.0);
	if (vertexClipped(centerClipPos, CLIPTOLERANCE)) {
		v_numvertices = 0u;
	}

	if (cameraDistance > iconDistance) {
		v_numvertices = 0u;
	}

	if (dot(v_centerpos.xyz, v_centerpos.xyz) < 1.0) {
		v_numvertices = 0u;
	}

	v_centerpos.y += HEIGHTOFFSET;
	v_centerpos.y += v_lengthwidthcornerheight.w;

	if ((uni[instData.y].composite & 0x00000003u) < 1u) {
		v_numvertices = 0u;
	}

	POST_VERTEX

	vec3 primitiveCoords;
	vec2 primitiveUV;
	float addRadiusCorr;
	bool activeVertex = BuildPrimitive(v_numvertices, v_lengthwidthcornerheight, primitiveCoords, primitiveUV, addRadiusCorr);

	PRE_OFFSET

	mat3 rotY;
	#if (BILLBOARD == 1)
		rotY = mat3(cameraViewInv[0].xyz, cameraViewInv[2].xyz, cameraViewInv[1].xyz);
	#else
		#if (FULL_ROTATION == 1)
			rotY = v_fullrotation;
		#else
			#if (ROTATE_CIRCLES == 1)
				rotY = RotationY(-1.0 * v_rotationY);
			#else
				if (v_numvertices > 5u) {
					rotY = mat3(1.0);
				} else {
					rotY = RotationY(-1.0 * v_rotationY);
				}
			#endif
		#endif
	#endif

	vec3 vecnorm = normalize(primitiveCoords);
	if (dot(primitiveCoords, primitiveCoords) < 0.0001) {
		vecnorm = vec3(0.0);
	}

	vec3 expandedPos = v_centerpos.xyz + rotY * (addRadius * addRadiusCorr * vecnorm + primitiveCoords);
	vec4 clipPos = cameraViewProj * vec4(expandedPos, 1.0);

	#ifdef ZPULL
		clipPos.z = clipPos.z - ZPULL / max(abs(clipPos.w), 0.0001);
	#endif

	if (!activeVertex) {
		gl_Position = vec4(0.0, 0.0, 2.0, 1.0);
		g_color = vec4(0.0);
		g_uv = vec4(0.0);
		return;
	}

	gl_Position = clipPos;
	g_color = v_color;
	g_uv = vec4(transformUV(v_uvoffsets, primitiveUV.x, primitiveUV.y), v_parameters.zw);

	DataGSCompat dataIn[1];
	dataIn[0].v_numvertices = v_numvertices;
	dataIn[0].v_rotationY = v_rotationY;
	dataIn[0].v_color = v_color;
	dataIn[0].v_lengthwidthcornerheight = v_lengthwidthcornerheight;
	dataIn[0].v_centerpos = v_centerpos;
	dataIn[0].v_uvoffsets = v_uvoffsets;
	dataIn[0].v_parameters = v_parameters;
	#if (FULL_ROTATION == 1)
		dataIn[0].v_fullrotation = v_fullrotation;
	#else
		dataIn[0].v_fullrotation = mat3(1.0);
	#endif

	POST_GEOMETRY
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000

uniform float addRadius = 0.0;
uniform float iconDistance = 20000.0;
uniform sampler2D DrawPrimitiveAtUnitTexture;

in vec4 g_color;
in vec4 g_uv;

out vec4 fragColor;

void main(void)
{
	vec4 texcolor = vec4(1.0);

	#if (USETEXTURE == 1)
		texcolor = texture(DrawPrimitiveAtUnitTexture, g_uv.xy);
	#endif

	fragColor.rgba = vec4(g_color.rgb * texcolor.rgb + addRadius, texcolor.a * TRANSPARENCY + addRadius);
	POST_SHADING

	#if (DISCARD == 1)
		if (fragColor.a < 0.01) {
			discard;
		}
	#endif
}
]]

local function GLSLValue(value)
	if type(value) == "boolean" then
		return value and "1" or "0"
	end
	return tostring(value)
end

local function BuildDefines(config)
	local lines = {}
	local keys = {}
	for key, value in pairs(config) do
		if value ~= nil then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		local value = config[key]
		if type(value) == "string" then
			value = value:gsub("\r", " "):gsub("\n", " ")
		end
		lines[#lines + 1] = "#define " .. key .. " " .. GLSLValue(value)
	end
	return table.concat(lines, "\n")
end

local function PatchShaderSource(source, config)
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	local quaternionDefs = ""
	if LuaShader.GetQuaternionDefs then
		quaternionDefs = LuaShader.GetQuaternionDefs() or ""
	end
	return source
		:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
		:gsub("//__QUATERNIONDEFS__", quaternionDefs)
		:gsub("//__DEFINES__", BuildDefines(config))
end

local function AddShapeVertex(data, xWidth, xCorner, zLength, zCorner, uBase, uCorner, vBase, vCorner, shapeType, stripIndex, triangleMaxStripIndex, addRadiusCorr)
	data[#data + 1] = xWidth
	data[#data + 1] = xCorner
	data[#data + 1] = zLength
	data[#data + 1] = zCorner
	data[#data + 1] = uBase
	data[#data + 1] = uCorner
	data[#data + 1] = vBase
	data[#data + 1] = vCorner
	data[#data + 1] = shapeType
	data[#data + 1] = stripIndex or 0
	data[#data + 1] = triangleMaxStripIndex or 0
	data[#data + 1] = addRadiusCorr or 1
end

local function AddTriangle(data)
	AddShapeVertex(data, 0, 0, 1, 0, 0.5, 0, 1.0, 0, 3, 0, 0, 2.0)
	AddShapeVertex(data, -0.866, 0, -0.5, 0, 0.0, 0, 0.0, 0, 3, 0, 0, 2.0)
	AddShapeVertex(data, 0.866, 0, -0.5, 0, 1.0, 0, 0.0, 0, 3, 0, 0, 2.0)
end

local function AddQuad(data)
	local verts = {
		{0.5, 0.5, 0.0, 1.0},
		{0.5, -0.5, 0.0, 0.0},
		{-0.5, 0.5, 1.0, 1.0},
		{-0.5, 0.5, 1.0, 1.0},
		{0.5, -0.5, 0.0, 0.0},
		{-0.5, -0.5, 1.0, 0.0},
	}
	for _, vertex in ipairs(verts) do
		AddShapeVertex(data, vertex[1], 0, vertex[2], 0, vertex[3], 0, vertex[4], 0, 4, 0, 0, 1.414)
	end
end

local function AddCornerRect(data)
	local strip = {
		{-0.5, 0, -0.5, 1, 0, 0, 0, 1},
		{-0.5, 0, 0.5, -1, 0, 0, 1, -1},
		{-0.5, 1, -0.5, 0, 0, 1, 0, 0},
		{-0.5, 1, 0.5, 0, 0, 1, 1, 0},
		{0.5, -1, -0.5, 0, 1, -1, 0, 0},
		{0.5, -1, 0.5, 0, 1, -1, 1, 0},
		{0.5, 0, -0.5, 1, 1, 0, 0, 1},
		{0.5, 0, 0.5, -1, 1, -1, 1, 0},
	}
	local indices = {1, 2, 3, 3, 2, 4, 3, 4, 5, 5, 4, 6, 5, 6, 7, 7, 6, 8}
	for _, index in ipairs(indices) do
		local vertex = strip[index]
		AddShapeVertex(data, vertex[1], vertex[2], vertex[3], vertex[4], vertex[5], vertex[6], vertex[7], vertex[8], 2, 0, 0, 1.1)
	end
end

local function AddCircle(data)
	local maxVertices = 64
	for i = 0, maxVertices - 3 do
		local tri
		if (i % 2) == 0 then
			tri = {i, i + 1, i + 2}
		else
			tri = {i + 1, i, i + 2}
		end
		for _, stripIndex in ipairs(tri) do
			AddShapeVertex(data, 0, 0, 0, 0, 0, 0, 0, 0, 64, stripIndex, i + 2, 1.0)
		end
	end
end

local function MakePrimitiveShapeVBO()
	if primitiveShapeVBO ~= nil then
		return primitiveShapeVBO, primitiveShapeVertexCount
	end

	local data = {}
	AddTriangle(data)
	AddQuad(data)
	AddCornerRect(data)
	AddCircle(data)

	primitiveShapeVertexCount = #data / 12
	primitiveShapeVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	if primitiveShapeVBO == nil then
		Spring.Echo("Failed to create DrawPrimitiveAtUnit shape VBO")
		return nil, 0
	end

	primitiveShapeVBO:Define(primitiveShapeVertexCount, {
		{id = 6, name = 'shapeXZ', size = 4},
		{id = 7, name = 'shapeUV', size = 4},
		{id = 8, name = 'shapeMeta', size = 4},
	})
	primitiveShapeVBO:Upload(data)

	return primitiveShapeVBO, primitiveShapeVertexCount
end

local function MakeVAOWrapper(realVAO, instanceTable)
	return {
		DrawArrays = function(_, _, vertexCount, _, instanceCount, instanceFirst)
			local instances = instanceCount or vertexCount or instanceTable.usedElements or 0
			if instances <= 0 then
				return
			end
			realVAO:DrawArrays(GL.TRIANGLES, primitiveShapeVertexCount, 0, instances, instanceFirst or 0)
		end,
		Delete = function()
			if realVAO.Delete then
				realVAO:Delete()
			end
		end,
		realVAO = realVAO,
	}
end

local function InitDrawPrimitiveAtUnit(config, DPATname)
	local shapeVBO = MakePrimitiveShapeVBO()
	if shapeVBO == nil then
		return nil
	end

	local shaderName = DPATname .. "Shader GL4 NoGS Mesh"
	local uniformInt = {}
	if config.USETEXTURE and config.USETEXTURE ~= 0 then
		uniformInt.DrawPrimitiveAtUnitTexture = 0
	end
	local drawPrimitiveAtUnitShader = LuaShader(
		{
			vertex = PatchShaderSource(vsSrc, config),
			fragment = PatchShaderSource(fsSrc, config),
			uniformInt = uniformInt,
			uniformFloat = {
				addRadius = 0.0,
				iconDistance = 20000.0,
			},
		},
		shaderName
	)

	local shaderCompiled = drawPrimitiveAtUnitShader:Initialize()
	if not shaderCompiled then
		Spring.Echo("Failed to compile shader for ", DPATname, " NoGS Mesh")
		return nil
	end

	local drawPrimitiveAtUnitVBO = InstanceVBOTable.makeInstanceVBOTable(
		{
			{id = 0, name = 'lengthwidthcorner', size = 4},
			{id = 1, name = 'teamID', size = 1, type = GL.UNSIGNED_INT},
			{id = 2, name = 'numvertices', size = 1, type = GL.UNSIGNED_INT},
			{id = 3, name = 'parameters', size = 4},
			{id = 4, name = 'uvoffsets', size = 4},
			{id = 5, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
		},
		64,
		DPATname .. "VBO",
		5
	)
	if drawPrimitiveAtUnitVBO == nil then
		Spring.Echo("Failed to create DrawPrimitiveAtUnitVBO for ", DPATname)
		return nil
	end

	local realVAO = gl.GetVAO()
	if realVAO == nil then
		Spring.Echo("Failed to create DrawPrimitiveAtUnitVAO for ", DPATname)
		return nil
	end
	realVAO:AttachVertexBuffer(shapeVBO)
	realVAO:AttachInstanceBuffer(drawPrimitiveAtUnitVBO.instanceVBO)
	drawPrimitiveAtUnitVBO.VAO = MakeVAOWrapper(realVAO, drawPrimitiveAtUnitVBO)

	return drawPrimitiveAtUnitVBO, drawPrimitiveAtUnitShader
end

return {
	InitDrawPrimitiveAtUnit = InitDrawPrimitiveAtUnit,
	shaderConfig = shaderConfig,
}
