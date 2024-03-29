function widget:GetInfo()
  return {
    name      = "DrawUnitShape GEOSHADER GL4",
    version   = "v0.2",
    desc      = "Faster gl.UnitShape, Use WG.UnitGeoshaderGL4",
    author    = "ivand, Beherith",
    date      = "2021.11.04",
	license   = "GNU GPL, v2 or later",
    layer     = -9999,
    enabled   = true,
  }
end


-- void LuaVAOImpl::RemoveFromSubmission(int idx)

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevboidtable.lua")

local unitShader

local unitShaderConfig = {
	STATICMODEL = 0.0, -- do not touch!
	TRANSPARENCY = 0.5, -- transparency of the stuff drawn
}

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 10000
//__DEFINES__

layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec3 T;
layout (location = 3) in vec3 B;
layout (location = 4) in vec4 uv;
#if (SKINSUPPORT == 0)
	layout (location = 5) in uint pieceIndex;
#else
	layout (location = 5) in uvec2 bonesInfo; //boneIDs, boneWeights
	#define pieceIndex (bonesInfo.x & 0x000000FFu)
#endif
layout (location = 6) in vec4 worldposrot;
layout (location = 7) in vec4 parameters; // x = alpha, y = isstatic, z = globalteamcoloramount, w = selectionanimation
layout (location = 8) in uvec2 overrideteam; // x = override teamcolor if < 256
layout (location = 9) in uvec4 instData;

uniform float iconDistance;

//__ENGINEUNIFORMBUFFERDEFS__
layout(std140, binding = 2) uniform FixedStateMatrices {
	mat4 modelViewMat;
	mat4 projectionMat;
	mat4 textureMat;
	mat4 modelViewProjectionMat;
};
#line 15000
//layout(std140, binding=0) readonly buffer MatrixBuffer {
layout(std140, binding=0) buffer MatrixBuffer {
	mat4 mat[];
};

mat4 GetPieceMatrix(bool staticModel) {
    return mat[instData.x + pieceIndex + uint(!staticModel)];
}

//enum DrawFlags : uint8_t {
//    SO_NODRAW_FLAG = 0, // must be 0
//    SO_OPAQUE_FLAG = 1,
//    SO_ALPHAF_FLAG = 2,
//    SO_REFLEC_FLAG = 4,
//    SO_REFRAC_FLAG = 8,
//    SO_SHADOW_FLAG = 16,
//    SO_FARTEX_FLAG = 32,
//    SO_DRICON_FLAG = 128, //unused so far
//};

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

out DataVS {
	vec2 v_uv;
	vec4 v_parameters;
	vec4 myTeamColor;
	vec3 worldPos;
};

void main() {
	uint baseIndex = instData.x;

	// dynamic models have one extra matrix, as their first matrix is their world pos/offset
	mat4 modelMatrix = mat[baseIndex];
	uint isDynamic = 1u; //default dynamic model
	if (parameters.y > 0.5) isDynamic = 0u;  //if paramy == 1 then the unit is static
	mat4 pieceMatrix = mat[baseIndex + pieceIndex + isDynamic];

	vec4 localModelPos = pieceMatrix * vec4(pos, 1.0);


	// Make the rotation matrix around Y and rotate the model
	mat3 rotY = rotation3dY(worldposrot.w);
	localModelPos.xyz = rotY * localModelPos.xyz;

	vec4 worldModelPos = localModelPos;
	if (parameters.y < 0.5) worldModelPos = modelMatrix*localModelPos;
	worldModelPos.xyz += worldposrot.xyz; //Place it in the world

	uint teamIndex = (instData.z & 0x000000FFu); //leftmost ubyte is teamIndex
	uint drawFlags = (instData.z & 0x0000FF00u) >> 8 ; // hopefully this works
	if (overrideteam.x < 255u) teamIndex = overrideteam.x;

	myTeamColor = vec4(teamColor[teamIndex].rgb, parameters.x); // pass alpha through

	vec3 modelBaseToCamera = cameraViewInv[3].xyz - (pieceMatrix[3].xyz + worldposrot.xyz);
	if ( dot (modelBaseToCamera, modelBaseToCamera) >  (iconDistance * iconDistance)) {
		myTeamColor.a = 0.0; // do something if we are far out?
	}

	v_parameters = parameters;
	v_uv = uv.xy;
	worldPos = worldModelPos.xyz;
	gl_Position = cameraViewProj * worldModelPos;
}
]]

local gsSrc = [[

#version 330

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__


layout (points) in;
layout (triangle_strip, max_vertices = 64) out;


in DataVS {
	vec2 v_uv;
	vec4 v_parameters;
	vec4 myTeamColor;
	vec3 worldPos;
};

out DataGS {
	vec2 g_uv;
	vec4 g_parameters;
	vec4 g_myTeamColor;
	vec3 g_worldPos;
};

vec3 centerpos;
mat3 rotY;

void offsetVertex4(float x, float y, float z, float u, float v, float addRadiusCorr){
	g_uv.xy = vec2(u,v);
	vec3 primitiveCoords = vec3(x,y,z);
	vec3 vecnorm = normalize(primitiveCoords);
	//PRE_OFFSET
	gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * (addRadius * addRadiusCorr * vecnorm + primitiveCoords ), 1.0);
	g_uv.zw = dataIn[0].v_parameters.zw;
	//POST_GEOMETRY
	EmitVertex();
}

void main(){
		g_myTeamColor = myTeamColor;
		g_parameters = v_parameters;
		rotY = mat3(cameraViewInv[0].xyz,cameraViewInv[2].xyz, cameraViewInv[1].xyz); // swizzle cause we use xz
		centerpos = dataIn[0].g_worldPos;
		centerpos.y += fract(timeInfo.x * 0.01) * 100;
		
		float length = 10;
		float width = 10;
		offsetVertex4( width * 0.5, 0.0,  length * 0.5, 0.0, 1.0, 1.414);
		offsetVertex4( width * 0.5, 0.0, -length * 0.5, 0.0, 0.0, 1.414);
		offsetVertex4(-width * 0.5, 0.0,  length * 0.5, 1.0, 1.0, 1.414);
		offsetVertex4(-width * 0.5, 0.0, -length * 0.5, 1.0, 0.0, 1.414);
		EndPrimitive();
}

]]



local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000

uniform sampler2D tex1;
uniform sampler2D tex2;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in DataGS {
	vec2 g_uv;
	vec4 g_parameters;
	vec4 g_myTeamColor;
	vec3 g_worldPos;
};


out vec4 fragColor;
#line 25000
void main() {
/*
	vec4 modelColor = texture(tex1, g_uv.xy);
	vec4 extraColor = texture(tex2, g_uv.xy);
	modelColor += modelColor * extraColor.r; // emission
	modelColor.a *= extraColor.a; // basic model transparency
	modelColor.rgb = mix(modelColor.rgb, g_myTeamColor.rgb, modelColor.a); // apply teamcolor

	modelColor.a *= g_myTeamColor.a; // shader define transparency
	modelColor.rgb = mix(modelColor.rgb, g_myTeamColor.rgb, g_parameters.z); //globalteamcoloramount override
	if (g_parameters.w > 0){
		modelColor.rgb = mix(modelColor.rgb, vec3(1.0), g_parameters.w*fract(g_worldPos.y*0.03 + (timeInfo.x + timeInfo.w)*0.05));
	}
*/
	fragColor = vec4(g_myTeamColor.rgb, g_myTeamColor.a);
}
]]

local udefID = UnitDefNames["armcom"].id

local corcomUnitDefID = UnitDefNames["corcom"].id
local armcomUnitDefID = UnitDefNames["armcom"].id

local DrawUnitGeoshaderVBOTable
local VBOTables = {}

local owners = {} -- maps uniqueIDs to their optional owners

local uniqueID = 0

local instanceCache = {}
for i= 1, 14 do instanceCache[i] = 0 end

---DrawUnitGL4(unitID, unitDefID, px, py, pz, rotationY, alpha, teamID, teamcoloroverride, highlight, updateID, ownerID)
---Draw a copy of an actual unit, with all of its animations too. That unit must be in view. For things like highlighting under construction stuff. 
---note that widgets are responsible for stopping the drawing of every unit that they submit! They may use RemoveMyDraws(ownerID). Note that prompt removal when widget:VisibleUnitRemoved(unitID) is essential here!
---@param unitID number the actual unitID that you want to draw
---@param unitDefID number which unitDef do you want to draw
---@param px number optional where in the world to do you want to draw it
---@param py number optional where in the world to do you want to draw it
---@param pz number optional where in the world to do you want to draw it
---@param rotationY number optional Angle in radians on how much to rotate the unit around Y, 0 means it faces south, (+Z), pi/2 points west (-X) -pi/2 points east
---@param alpha number optional the transparency level of the unit
---@param teamID number optional which teams teamcolor should this unit get, leave nil if you want to keep the original teamID
---@param teamcoloroverride number optional much we should mix the teamcolor into the model color [0-1]
---@param highlight number optional how much we should add a highlighting animation to the unit (blends white with [0-1])
---@param updateID number optional specify the previous uniqueID if you want to update it
---@param ownerID any optional unique identifier so that widgets can batch remove all of their own stuff
---@return uniqueID number a unique handler ID number that you should store and call StopDrawUnitGL4(uniqueID) with to stop drawing it
local function DrawUnitGL4(unitID, unitDefID, px, py, pz, rotationY, alpha, teamID, teamcoloroverride, highlight, updateID, ownerID)

	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)

	px = px or 0 
	py = py or 0
	pz = pz or 0
	rotationY = rotationY or 0 
	alpha = alpha or 1
	teamID = teamID or 256
	--teamID = Spring.GetUnitTeam(unitID)
	highlight = highlight or 0
	teamcoloroverride = teamcoloroverride or 0

	if not updateID then 
		uniqueID = uniqueID + 1
		updateID = uniqueID
	end
	
	if ownerID then owners[updateID] = ownerID end
	
	--Spring.Echo("DrawUnitGL4", objecttype, UnitDefs[unitDefID].name, unitID, "to uniqueID", uniqueID,"elemID", elementID)
	
	instanceCache[1], instanceCache[2], instanceCache[3], instanceCache[4] = px, py, pz, rotationY
	instanceCache[5], instanceCache[6], instanceCache[7], instanceCache[8] = alpha, 0, teamcoloroverride, highlight
	instanceCache[9] = teamID
	
	local elementID = pushElementInstance(
		DrawUnitGeoshaderVBOTable,
		instanceCache,
		updateID,
		true,
		nil,
		unitID,
		"unitID")
	return updateID
end

---StopDrawUnitGL4(uniqueID)
---@param uniqueID number the unique id of whatever you want to stop drawing
---@return the ownerID the uniqueID was associated to
local function StopDrawUnitGL4(uniqueID)
	if DrawUnitGeoshaderVBOTable.instanceIDtoIndex[uniqueID] then
		popElementInstance(DrawUnitGeoshaderVBOTable, uniqueID)
	else
		Spring.Echo("Unable to remove what you wanted in StopDrawUnitGL4", uniqueID)
	end
	local owner = owners[uniqueID]
	owners[uniqueID] = nil
	--Spring.Echo("Popped element", uniqueID)
	return owner
end

---StopDrawAll(ownerID) removes all units and unitshapes registered for this owner ID
---@param ownerID any identifier for which to remove all things being drawn. All get removed if ownerID is nil
---@return ownedCount number how many items were removed
local function StopDrawAll(ownerID)
	local ownedCount = 0
	for uniqueID, owner in pairs(owners) do 
		if owner == ownerID or ownerID == nil then 
			if DrawUnitGeoshaderVBOTable.instanceIDtoIndex[uniqueID] then 
				popElementInstance(DrawUnitGeoshaderVBOTable, uniqueID)
			end
			owners[uniqueID] = nil
			ownedCount = ownedCount + 1
		end
	end
	return ownedCount
end

local TESTMODE = true

if TESTMODE then 
	local unitIDtoUniqueID = {}
	function widget:UnitCreated(unitID, unitDefID)
		unitIDtoUniqueID[unitID] =  DrawUnitGL4(unitID, unitDefID,  0, 0, 0, math.random()*2, 0.6)
	end

	function widget:UnitDestroyed(unitID)
		StopDrawUnitGL4(unitIDtoUniqueID[unitID])
		unitIDtoUniqueID[unitID] = nil
	end
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	
	local vertexVBO = gl.GetVBO(GL.ARRAY_BUFFER, false) -- GL.ARRAY_BUFFER, false
	local indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false) -- GL.ARRAY_BUFFER, false
	vertexVBO:ModelsVBO()
	indexVBO:ModelsVBO()

	local VBOLayout = {
			{id = 6, name = "worldposrot", size = 4},
			{id = 7, name = "parameters" , size = 4},
			{id = 8, name = "overrideteam" , type = GL.UNSIGNED_INT, size = 2},
			{id = 9, name = "instData", type = GL.UNSIGNED_INT, size = 4},
		}

	local maxElements = 6 -- start small for testing
	local unitIDAttributeIndex = 9
	DrawUnitGeoshaderVBOTable         = makeInstanceVBOTable(VBOLayout, maxElements, "corDrawUnitVBOTable", unitIDAttributeIndex, "unitID")

	DrawUnitGeoshaderVBOTable.VAO = makeVAOandAttach(vertexVBO, DrawUnitGeoshaderVBOTable.instanceVBO, indexVBO)
	DrawUnitGeoshaderVBOTable.indexVBO = indexVBO
	DrawUnitGeoshaderVBOTable.vertexVBO = vertexVBO


	local unitIDs = Spring.GetAllUnits()
	local featuresIDs = Spring.GetAllFeatures()

	local communitdefid = UnitDefNames["armcom"].id
	local pwdefid = UnitDefNames["armpw"].id
	local corcomunitdefid = UnitDefNames["corcom"].id

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)

	unitShader = LuaShader({
		vertex = vsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(unitShaderConfig)),
		fragment = fsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(unitShaderConfig)),
		uniformInt = {
			tex1 = 0,
			tex2 = 1,
		},
		uniformFloat = {
			iconDistance = 1,
		  },
	}, "UnitGL4 API")

	local unitshaderCompiled = unitShader:Initialize()
	if unitshaderCompiled ~= true  then
		Spring.Echo("DrawUnitShape shader compilation failed", unitshaderCompiled)
		widgetHandler:RemoveWidget()
	end
	if TESTMODE then
		for i, unitID in ipairs(Spring.GetAllUnits()) do
			widget:UnitCreated(unitID)
		end
	end
	WG['DrawUnitGL4'] = DrawUnitGL4
	WG['DrawUnitShapeGL4'] = DrawUnitShapeGL4
	WG['StopDrawUnitGL4'] = StopDrawUnitGL4
	WG['StopDrawUnitShapeGL4'] = StopDrawUnitShapeGL4
	WG['StopDrawAll'] = StopDrawAll
	WG['armDrawUnitShapeVBOTable'] = armDrawUnitShapeVBOTable
	WG['corDrawUnitShapeVBOTable'] = corDrawUnitShapeVBOTable
	widgetHandler:RegisterGlobal('DrawUnitGL4', DrawUnitGL4)
	widgetHandler:RegisterGlobal('DrawUnitShapeGL4', DrawUnitShapeGL4)
	widgetHandler:RegisterGlobal('StopDrawUnitGL4', StopDrawUnitGL4)
	widgetHandler:RegisterGlobal('StopDrawUnitShapeGL4', StopDrawUnitShapeGL4)
	widgetHandler:RegisterGlobal('armDrawUnitShapeVBOTable', armDrawUnitShapeVBOTable)
	widgetHandler:RegisterGlobal('corDrawUnitShapeVBOTable', corDrawUnitShapeVBOTable)
	widgetHandler:RegisterGlobal('StopDrawAll', StopDrawAll)
end


function widget:Shutdown()
	for i,VBOTable in ipairs(VBOTables) do
		if VBOTable.VAO then
			if Spring.Utilities.IsDevMode() then
				dumpAndCompareInstanceData(VBOTable)
			end
			VBOTable.VAO:Delete()
		end
	end
	if unitShader then unitShader:Finalize() end
	if unitShapeShader then unitShapeShader:Finalize() end
--[[
	WG['DrawUnitGL4'] = nil
	WG['DrawUnitShapeGL4'] = nil
	WG['StopDrawUnitGL4'] = nil
	WG['StopDrawUnitShapeGL4'] = nil
	WG['StopDrawAll'] = nil
	WG['armDrawUnitShapeVBOTable'] = nil
	WG['corDrawUnitShapeVBOTable'] = nil
	widgetHandler:DeregisterGlobal('DrawUnitGL4')
	widgetHandler:DeregisterGlobal('DrawUnitShapeGL4')
	widgetHandler:DeregisterGlobal('StopDrawUnitGL4')
	widgetHandler:DeregisterGlobal('StopDrawUnitShapeGL4')
	widgetHandler:DeregisterGlobal('armDrawUnitShapeVBOTable')
	widgetHandler:DeregisterGlobal('armDrawUnitShapeVBOTable')
	widgetHandler:DeregisterGlobal('StopDrawAll')
	]]--
end

function widget:DrawWorld()
	if DrawUnitGeoshaderVBOTable.usedElements > 0  then
		gl.Culling(GL.BACK)
		gl.DepthMask(true)
		gl.DepthTest(true)
		--gl.PolygonOffset( -2 ,-2)
		unitShader:Activate()
		unitShader:SetUniform("iconDistance",27 * Spring.GetConfigInt("UnitIconDist", 200))

		DrawUnitGeoshaderVBOTable.VAO:Submit()

		unitShader:Deactivate()
		--gl.UnitShapeTextures(udefID, false)
		--gl.PolygonOffset( false )
		gl.Culling(false)
    gl.DepthMask(false) --"BK OpenGL state resets", reset to default state
	end
end
