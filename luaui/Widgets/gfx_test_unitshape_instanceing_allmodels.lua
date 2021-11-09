function widget:GetInfo()
  return {
    name      = "UnitShapeGL4 API",
    version   = "v0.2",
    desc      = "Faster gl.UnitShape, Use WG.UnitShapeGL4",
    author    = "ivand, Beherith",
    date      = "2021.11.04",
    license   = "GPL",
    layer     = 0,
    enabled   = false,
  }
end

-- TODO: correctly track add/remove per vbotable
-- Dont Allow mixed types, it will fuck with textures anyway
-- need 4 vbos:
  -- corunitVBO
  -- armunitVBO
	-- for unitVBOs, we need to make sure we dont draw outside of disticon stuff, or else suffer for it
	
  -- corunitShapeVBO
  -- armunitShapeVBO
		-- for unitshape, we also need a teamID so that we can lookup the teamcolor!
-- Possible params:
  -- transparency
  -- teamID (override for all
  
-- unified shader -- needs matrix detection for unit offsets
-- When to draw?
  --UnitShape is in Preunit
  --drawUnit is in drawworld
  -- NO REFLECTIONS, REFRACTIONS ET AL


-- void LuaVAOImpl::RemoveFromSubmission(int idx)
local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevboidtable.lua")

local vao

local unitShader

local shaderConfig = {
	TRANSPARENCY = 0.5, -- transparency of the stuff drawn
}

local vsSrc = [[
#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 10000

layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec3 T;
layout (location = 3) in vec3 B;
layout (location = 4) in vec4 uv;
layout (location = 5) in uint pieceIndex;
layout (location = 6) in vec4 worldposrot;
layout (location = 7) in vec4 parameters; // x = alpha, y = isstatic
layout (location = 8) in uvec4 instData;


//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__
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

out vec2 vuv;
out vec3 col;
out vec4 myTeamColor;

void main() {
	uint baseIndex = instData.x;
	mat4 modelMatrix = mat[baseIndex];
	
	uint isStatic = 1u;
	if (parameters.y > 0.5) isStatic = 0u;
	mat4 pieceMatrix = mat4mix(mat4(1.0), mat[baseIndex + pieceIndex + isStatic ], modelMatrix[3][3]); // the +1u is not needed here?
  
	vec4 modelPos = modelMatrix * pieceMatrix * vec4(pos, 1.0);

	modelPos.xyz += vec3(0.0, 10.0, 0.0) +  worldposrot.xyz; //instOffset;	
	if (parameters.y > 0.5) modelPos.xyz += mouseWorldPos.xyz;
	

	gl_Position = cameraViewProj * modelPos;

	vuv = uv.xy;
	col = vec3(float(pieceIndex) / 21.0);
	uint teamIndex = (instData.y & 0x000000FFu); //leftmost ubyte is teamIndex
	uint drawFlags = (instData.y & 0x0000FF00u) >> 8 ; // hopefully this works
	//uint isDrawn = drawFlags & 0x00000080u
	myTeamColor = vec4(teamColor[teamIndex].rgb, parameters.x); // pass alpha through
	//if ((drawFlags & 0x00000080u) > 0u)   myTeamColor.a = 0.0;
	//if ((drawFlags & 0x00000040u) > 0u)   myTeamColor.r = 1.0;
	//if ((drawFlags & 0x00000020u) > 0u)   myTeamColor.g = 1.0;
	//if ((drawFlags & 0x00000010u) > 0u)   myTeamColor.b = 0.0;
	uint tester = uint(mod(timeInfo.x*0.25, 10));
	if ((drawFlags & (1u << tester) )> 0u )  myTeamColor.rgba = vec4(0.0);
	if (drawFlags == 0u )  myTeamColor.rgba = vec4(1.0);
}

]]

local fsSrc = [[
#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000

uniform sampler2D tex1;
uniform sampler2D tex2;


//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in vec2 vuv;
in vec3 col;
in vec4 myTeamColor;

out vec4 fragColor;
#line 25000
void main() {
	vec4 modelColor = texture(tex1, vuv.xy);
	modelColor.rgb = mix(modelColor.rgb, myTeamColor.rgb, modelColor.a);
	fragColor = vec4(modelColor.rgb, myTeamColor.a);
	//fragColor = vec4(col.rgb, 1.0);
}
]]

local udefID = UnitDefNames["armcom"].id
local instVBO

local corcomUnitDefID = UnitDefNames["corcom"].id
local armcomUnitDefID = UnitDefNames["armcom"].id
local corInstanceVBO, armInstanceVBO
local corIndexToID, armIndexToID
local corUnitShapeVAO, corUnitVAO
local corUnitShape
local featurevao


local corUnitDefIDs = {}
local armUnitDefIDs = {}

-- some assumptions:
-- we have a cor and and arm instance Table
-- we must check that we dont do a resize, as the resize is what is hard to do with this method...
-- TODO: unitshapetextureclass into unitdef customparams

local vaoIDtoType = {} -- -1 as its lua to c

local function popObjectID(elemindex) -- popElementInstance 
	Spring.Echo("Popped element", elemindex)
	popElementInstance(corInstanceVBO, elemindex)
	local objecttype = vaoIDtoType[elementindex]
	vao:RemoveFromSubmission(elemindex - 1 )
end


local function pushObjectIDtoPosition(objectID, objecttype, px, py, pz, rot, alpha, param1, param2, param3)
	--lets be dumb here, and blindly pushelements
	-- when we push without key, we get elementindex back?
	local isStatic = 0
	if objecttype == "unitDefID" or objecttype == "featureDefID" then isStatic = 1 end
	local elementID = pushElementInstance(corInstanceVBO, {
			px, py, pz, 0,
			0.6, isStatic, 1.0, 1.0,
			0,0,0,0
		},
		nil,
		true,
		nil,
		objectID,
		objecttype)
	--if true then return end
	local vaopos = nil
	if objecttype == "unitID" then 
		vaopos = vao:AddUnitsToSubmission(objectID)
	elseif objecttype == "unitDefID" then 
		vaopos = vao:AddUnitDefsToSubmission(objectID)
	elseif objecttype == "featureID" then 
		vaopos = vao:AddFeaturesToSubmission(objectID)
	elseif objecttype == "featureDefID" then 
		vaopos = vao:AddFeatureDefsToSubmission(objectID)
	end
	vaoIDtoType[vaopos] = objecttype
	Spring.Echo("Pushed", objecttype, objectID, "to vaopos", vaopos,"elemID", elementID)
end

function widget:Initialize()
	local vertVBO = gl.GetVBO(GL.ARRAY_BUFFER, false) -- GL.ARRAY_BUFFER, false
	local indxVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false) -- GL.ARRAY_BUFFER, false

	corInstanceVBO = makeInstanceVBOTable({
			{id = 6, name = "worldposrot", size = 4},
			{id = 7, name = "parameters" , size = 4},
			{id = 8, name = "instData", type = GL.UNSIGNED_INT, size = 4},
		},
		200,
		"instancevboidtable", 
		8, -- objectTypeAttribID
		"unitID"
	)
	
	local unitIDs = Spring.GetAllUnits()
	local featuresIDs = Spring.GetAllFeatures()
  
	local communitdefid = UnitDefNames["armcom"].id
	local pwdefid = UnitDefNames["armpw"].id
	local corcomunitdefid = UnitDefNames["corcom"].id
	local featureDefID1 = FeatureDefNames["cormstor_dead"].id
	local featureDefID1 = FeatureDefNames["cormstor_dead"].id
	
	vertVBO:ModelsVBO()
	indxVBO:ModelsVBO()
	

	vao = gl.GetVAO()
	vao:AttachVertexBuffer(vertVBO)
	vao:AttachIndexBuffer(indxVBO)
	vao:AttachInstanceBuffer(corInstanceVBO.instanceVBO)
	
	for x=1, 10 do
		for z = 1, 10 do
			--pushObjectIDtoPosition(UnitDefNames["armck"].id,"unitDefID", x*32, 50, z*32)
		end
	end
	
	pushObjectIDtoPosition(UnitDefNames["armfboy"].id,"unitDefID", 100, 0, 0)
	pushObjectIDtoPosition(FeatureDefNames["armsy_dead"].id,"featureDefID", -100, 0, 0) -- put in armcom unitdefid
	pushObjectIDtoPosition(UnitDefNames["armfboy"].id,"unitDefID", 150, 0, 0)
	--pushObjectIDtoPosition(UnitDefNames["armflea"].id,"unitDefID", 0, 200, 0)
	--pushObjectIDtoPosition(unitIDs[1],"unitID", 0, 0  , 200) -- put in armcom unitdefid
	--pushObjectIDtoPosition(UnitDefNames["armpw"].id,"unitDefID", 0, 300, 0)
	--pushObjectIDtoPosition(UnitDefNames["armrock"].id,"unitDefID", 0, 400, 0)
	--pushObjectIDtoPosition(UnitDefNames["armham"].id,"unitDefID", 0, 500, 0)
	--pushObjectIDtoPosition(unitIDs[1],"unitID", 0, 0  , 100) -- put in armcom unitdefid
	--pushObjectIDtoPosition(featuresIDs[1],"featureID", 0, 0, -100) -- put in armcom unitdefid
	--pushObjectIDtoPosition(pwdefid,"unitDefID", 100, 100, 100)
	--pushObjectIDtoPosition(pwdefid,"unitDefID", 100, 100, 200)
	
	--
	--popObjectID(6) -- this this is stupid

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	unitShader = LuaShader({
		vertex = vsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		fragment = fsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		uniformInt = {
			tex1 = 0,
			tex2 = 1,
		},
	}, "UnitShapeGL4 API")
	
	local shaderCompiled = unitShader:Initialize()
	--Spring.Echo("Hello")
end


function widget:CreateUnit(unitID, unitDefID)
end

function widget:DestroyUnit(unitID, unitDefID)
end


function widget:Shutdown()
	if vao then
		vao:Delete()
	end
	if unitShader then
		unitShader:Finalize()
	end
end

function widget:DrawWorld()
  gl.Culling(GL.BACK)
	gl.DepthMask(true)
	gl.DepthTest(true)
	gl.UnitShapeTextures(udefID, true)
	unitShader:Activate()
	vao:Submit()
	unitShader:Deactivate()
	gl.UnitShapeTextures(udefID, false)
	gl.PolygonOffset ( false ) 
end

function widget:DrawScreenEffects()
	local vsx, vsy = widgetHandler:GetViewSizes()
end