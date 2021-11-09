function widget:GetInfo()
  return {
    name      = "DrawUnitShape GL4",
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
-- Shader:
  --Possible params for:
    -- transparency
    -- teamID (override for all 4 teamcolor stuff)
	-- drawveryfar
  -- Handle out-of-bounds with mapping to 0,0,0,1 vertex
  -- For Units:
	-- clip when Icon
  -- for UnitIDs:
	-- Dont clip when icon, doesnt make sense :D
  
-- unified shader -- needs matrix detection for unit offsets
-- When to draw?
  --UnitShape is in Preunit
	-- enable depth testing and backface culling
	-- Use the actual team color (or any teamID specified if not -1?)

  --drawUnit is in drawworld
	-- enable depth testing and backface culling
	-- this usually additively blends with a 'flat' (usually team) color
	
  -- NO REFLECTIONS, REFRACTIONS ET AL

-- void LuaVAOImpl::RemoveFromSubmission(int idx)

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevboidtable.lua")

local unitShader, unitShapeShader

local unitShaderConfig = {
	STATICMODEL = 0.0, -- do not touch!
	TRANSPARENCY = 0.5, -- transparency of the stuff drawn
}

local unitShapeShaderConfig = {
	STATICMODEL = 1.0, -- do not touch!
	TRANSPARENCY = 0.5,
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
layout (location = 8) in uvec2 overrideteam; // x = override teamcolor if < 256
layout (location = 9) in uvec4 instData;

uniform float iconDistance;

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
	
	uint isDynamic = 1u; //default dynamic model
	if (parameters.y > 0.5) isDynamic = 0u;  //if paramy == 1 then the unit is static
	mat4 pieceMatrix = mat4mix(mat4(1.0), mat[baseIndex + pieceIndex + isDynamic ], modelMatrix[3][3]); // dynamic models have a world pos added to them, naturally
  
	vec4 modelPos = modelMatrix * pieceMatrix * vec4(pos, 1.0);

	modelPos.xyz += vec3(0.0, 0.0, 0.0) +  worldposrot.xyz; //instOffset;	
	//if (parameters.y > 0.5) modelPos.xyz += mouseWorldPos.xyz; // we offset drawn defs with mouse
	
	vec3 modelBaseToCamera = cameraViewInv[3].xyz - modelMatrix[3].xyz;
	if ( dot (modelBaseToCamera, modelBaseToCamera) >  (iconDistance * iconDistance)) ; // do something if we are far out?

	gl_Position = cameraViewProj * modelPos;

	vuv = uv.xy;
	col = vec3(float(pieceIndex) / 21.0);
	uint teamIndex = (instData.y & 0x000000FFu); //leftmost ubyte is teamIndex
	uint drawFlags = (instData.y & 0x0000FF00u) >> 8 ; // hopefully this works
	//uint isDrawn = drawFlags & 0x00000080u
	myTeamColor = vec4(teamColor[teamIndex].rgb, parameters.x); // pass alpha through
	
	//uint tester = uint(mod(timeInfo.x*0.25, 10));
	//if ((drawFlags & (1u << tester) )> 0u )  myTeamColor.rgba = vec4(0.0);
	//if (drawFlags == 0u )  myTeamColor.rgba = vec4(1.0);
	myTeamColor.a = parameters.x;
	
	if ( dot (modelBaseToCamera, modelBaseToCamera) >  (iconDistance * iconDistance)) myTeamColor.a = 0.4; // do something if we are far out?
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
	vec4 extraColor = texture(tex2, vuv.xy);
	modelColor += modelColor * extraColor.r; // emission
	//modelColor.a = extraColor.a; // transparency
	modelColor.rgb = mix(modelColor.rgb, myTeamColor.rgb, modelColor.a);
	fragColor = vec4(modelColor.rgb, myTeamColor.a);
	//fragColor = vec4(col.rgb, 1.0);
}
]]

local udefID = UnitDefNames["armcom"].id

local corcomUnitDefID = UnitDefNames["corcom"].id
local armcomUnitDefID = UnitDefNames["armcom"].id

local corDrawUnitVBOTable, corDrawUnitShapeVBOTable
local armDrawUnitVBOTable, armDrawUnitShapeVBOTable
local VBOTables = {}

local corUnitDefIDs = {}
local armUnitDefIDs = {}


local uniqueID = 0

local function DrawUnitGL4(unitID, unitDefID, px, py, pz, rot, alpha, param1, param2, param3)
	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)
	uniqueID = uniqueID + 1
	
	local DrawUnitVBOTable 
	if corUnitDefIDs[unitDefID] then DrawUnitVBOTable = corDrawUnitVBOTable 
	elseif armUnitDefIDs[unitDefID] then DrawUnitVBOTable = armDrawUnitVBOTable 
	else 
		Spring.Echo("The given unitDefID", unitDefID, "is neither arm nor cor, only those two are supported at the moment")
		return nil
	end

	local elementID = pushElementInstance(DrawUnitVBOTable, {
			px, py, pz, 0,
			0.6, 0, 1.0, 1.0,
			256, 0, 
			0,0,0,0
		},
		uniqueID,
		true,
		nil,
		unitID,
		"unitID")
	--Spring.Echo("Pushed", objecttype, unitID, "to uniqueID", uniqueID,"elemID", elementID)
	return uniqueID
end


local function DrawUnitShapeGL4(unitDefID, px, py, pz, rot, alpha, param1, param2, param3)
	uniqueID = uniqueID + 1
	
	local DrawUnitShapeVBOTable 
	if corUnitDefIDs[unitDefID] then DrawUnitShapeVBOTable = corDrawUnitShapeVBOTable 
	elseif armUnitDefIDs[unitDefID] then DrawUnitShapeVBOTable = armDrawUnitShapeVBOTable 
	else
		Spring.Echo("The given unitDefID", unitDefID, "is neither arm nor cor, only those two are supported at the moment")
		return nil
	end
	
	local elementID = pushElementInstance(DrawUnitShapeVBOTable, {
			px, py, pz, 0,
			0.6, 1, 1.0, 1.0,
			256, 0, 
			0,0,0,0
		},
		uniqueID,
		true,
		nil,
		unitDefID,
		"unitDefID")
	Spring.Echo("Pushed", "unitDefID", unitDefID, "to unitDefID", uniqueID,"elemID", elementID)
	return uniqueID
end

local function StopDrawUnitGL4(uniqueID)
	if corDrawUnitVBOTable.instanceIDtoIndex[uniqueID] then
		popElementInstance(corDrawUnitVBOTable, uniqueID)
	elseif armDrawUnitVBOTable.instanceIDtoIndex[uniqueID] then
		popElementInstance(armDrawUnitVBOTable, uniqueID)
	else
		Spring.Echo("Unable to remove what you wanted in StopDrawUnitGL4", uniqueID)
	end
	Spring.Echo("Popped element", uniqueID)
end

local function StopDrawUnitDefGL4(uniqueID)
	if corDrawUnitShapeVBOTable.instanceIDtoIndex[uniqueID] then
		popElementInstance(corDrawUnitShapeVBOTable, uniqueID)
	elseif armDrawUnitShapeVBOTable.instanceIDtoIndex[uniqueID] then
		popElementInstance(armDrawUnitShapeVBOTable, uniqueID)
	else
		Spring.Echo("Unable to remove what you wanted in StopDrawUnitDefGL4", uniqueID)
	end
	Spring.Echo("Popped element", uniqueID)
end

local unitIDtoUniqueID = {}
local unitDefIDtoUniqueID = {}


function widget:UnitCreated(unitID, unitDefID)
	--unitIDtoUniqueID[unitID] =  DrawUnitGL4(unitID, unitDefID,  0, 64, 0, 0, 0.6)
	
	local px, py, pz = Spring.GetUnitPosition(unitID)
	unitDefIDtoUniqueID[unitID] = DrawUnitShapeGL4(Spring.GetUnitDefID(unitID), px+20, py + 50, pz+20, 0, 0.6)
end

function widget:UnitDestroyed(unitID)
	--StopDrawUnitGL4(unitIDtoUniqueID[unitID])
	--unitIDtoUniqueID[unitID] = nil
	
	StopDrawUnitDefGL4(unitDefIDtoUniqueID[unitID])
	unitDefIDtoUniqueID[unitID] = nil
end

function widget:Initialize()
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.model and unitDef.model.textures and unitDef.model.textures.tex1:lower() == "arm_color.dds" then
			armUnitDefIDs[unitDefID] = true
		elseif unitDef.model and unitDef.model.textures and unitDef.model.textures.tex1:lower() == "cor_color.dds" then
			corUnitDefIDs[unitDefID] = true
		end
	end
	
	local vertVBO = gl.GetVBO(GL.ARRAY_BUFFER, false) -- GL.ARRAY_BUFFER, false
	local indxVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false) -- GL.ARRAY_BUFFER, false
	vertVBO:ModelsVBO()
	indxVBO:ModelsVBO()
	
	local VBOLayout = { 
			{id = 6, name = "worldposrot", size = 4},
			{id = 7, name = "parameters" , size = 4},
			{id = 8, name = "overrideteam" , type = GL.UNSIGNED_INT, size = 2},
			{id = 9, name = "instData", type = GL.UNSIGNED_INT, size = 4},
		}

	local maxElements = 32 -- start small for testing
	local unitIDAttributeIndex = 9
	corDrawUnitVBOTable         = makeInstanceVBOTable(VBOLayout, maxElements, "corDrawUnitVBOTable", unitIDAttributeIndex, "unitID")
	armDrawUnitVBOTable         = makeInstanceVBOTable(VBOLayout, maxElements, "armDrawUnitVBOTable", unitIDAttributeIndex, "unitID")
	corDrawUnitShapeVBOTable    = makeInstanceVBOTable(VBOLayout, maxElements, "corDrawUnitShapeVBOTable", unitIDAttributeIndex, "unitDefID")
	armDrawUnitShapeVBOTable    = makeInstanceVBOTable(VBOLayout, maxElements, "armDrawUnitShapeVBOTable", unitIDAttributeIndex, "unitDefID")
	VBOTables = {corDrawUnitVBOTable, corDrawUnitShapeVBOTable, armDrawUnitVBOTable, armDrawUnitShapeVBOTable}
	
	for i,VBOTable in ipairs(VBOTables) do -- attach everything together
		VBOTable.VAO = makeVAOandAttach(vertVBO, VBOTable.instanceVBO, indxVBO)
		VBOTable.indexVBO = indxVBO
		VBOTable.vertexVBO = vertVBO
	end
	
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
	
	unitShapeShader = LuaShader({
		vertex = vsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(unitShapeShaderConfig)),
		fragment = fsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(unitShapeShaderConfig)),
		uniformInt = {
			tex1 = 0,
			tex2 = 1,
		},
		uniformFloat = {
			iconDistance = 1,
		  },
	}, "UnitShapeGL4 API")
	
	local shaderCompiled = unitShader:Initialize()
	local shaderCompiled = unitShapeShader:Initialize()
	--Spring.Echo("Hello")
	
	for i, unitID in ipairs(Spring.GetAllUnits()) do
		widget:UnitCreated(unitID)
	end
end


function widget:Shutdown()
	for i,VBOTable in ipairs(VBOTables) do
		if VBOTable.VAO then VBOTable.VAO:Delete() end
	end
	if unitShader then unitShader:Finalize() end
	if unitShapeShader then unitShapeShader:Finalize() end
end

function widget:DrawWorldPreUnit() -- this is for UnitDef
	if armDrawUnitShapeVBOTable.usedElements > 0 or corDrawUnitShapeVBOTable.usedElements > 0 then 
		gl.Culling(GL.BACK)
		gl.DepthMask(false)
		gl.DepthTest(false)
		gl.PolygonOffset ( 0.5,0.5 ) 
		unitShapeShader:Activate()
		unitShapeShader:SetUniform("iconDistance",27 * Spring.GetConfigInt("UnitIconDist", 200)) 
		if (corDrawUnitShapeVBOTable.usedElements > 0 ) then
			gl.UnitShapeTextures(corcomUnitDefID, true)
			corDrawUnitShapeVBOTable.VAO:Submit()
		end
		
		if (armDrawUnitShapeVBOTable.usedElements > 0 ) then
			gl.UnitShapeTextures(armcomUnitDefID, true)
			armDrawUnitShapeVBOTable.VAO:Submit()
		end
		
		unitShapeShader:Deactivate()
		gl.UnitShapeTextures(udefID, false)
		gl.PolygonOffset( false ) 
		gl.Culling(false)
	end
end

function widget:DrawWorld()
	if armDrawUnitVBOTable.usedElements > 0 or corDrawUnitVBOTable.usedElements > 0 then 
		gl.Culling(GL.BACK)
		gl.DepthMask(true)
		gl.DepthTest(true)
		gl.PolygonOffset( 0.5 ,0.5) 
		unitShader:Activate()
		unitShader:SetUniform("iconDistance",27 * Spring.GetConfigInt("UnitIconDist", 200)) 
		if (corDrawUnitVBOTable.usedElements > 0 ) then
			gl.UnitShapeTextures(corcomUnitDefID, true)
			corDrawUnitVBOTable.VAO:Submit()
		end
		
		if (armDrawUnitVBOTable.usedElements > 0 ) then
			gl.UnitShapeTextures(armcomUnitDefID, true)
			armDrawUnitVBOTable.VAO:Submit()
		end
		unitShader:Deactivate()
		gl.UnitShapeTextures(udefID, false)
		gl.PolygonOffset( false ) 
		gl.Culling(false)
	end
end
