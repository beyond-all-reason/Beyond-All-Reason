function widget:GetInfo()
  return {
    name      = "HighlightUnit GL4",
    version   = "v0.2",
    desc      = "Highlight any unit via WG.HighlightUnitGL4",
    author    = "ivand, Beherith",
    date      = "2021.11.04",
    license   = "GPL",
    layer     = 0,
    enabled   = false,
  }
end

-- TODO/Notes:
-- Separate out units/unitdefs?
-- Use drawflags to hide on zoomout
-- support features too!
-- Parameters: 
	-- worldposrot (offset if unitID)
	-- isstatic, teamcoloramount, 
	-- animamount -- how much to the blend fracty stuff into it 
	-- plainalpha, -- how much 
	-- edgealpha, (exponent maybe hard-codeable?), 
	-- color, alpha
-- 

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevboidtable.lua")

local highlightunitShader, unitShapeShader

local highlightunitShaderConfig = {
	STATICMODEL = 0.0, -- do not touch!
	TRANSPARENCY = 0.5, -- transparency of the stuff drawn
	FREQUENCY = 1.0,
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
layout (location = 7) in vec4 parameters; // x = alpha, y = isstatic, z = globalteamcoloramount, w = selectionanimation
layout (location = 8) in vec4 hcolor; // x = override teamcolor if < 256
layout (location = 9) in uvec4 instData;

uniform float iconDistance;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 15000
//layout(std140, binding=0) readonly buffer MatrixBuffer {
layout(std140, binding=0) buffer MatrixBuffer {
	mat4 mat[];
};

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

out vec4 v_parameters;
out vec4 myTeamColor;
out vec3 worldPos;
out vec3 v_toeye;
out vec3 v_normal;
out vec4 v_hcolor;

void main() {
	uint baseIndex = instData.x;
	
	mat4 modelMatrix = mat[baseIndex];
	
	// dynamic models have one extra matrix, as their first matrix is their world pos/offset
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

	myTeamColor = vec4(teamColor[teamIndex].rgb, parameters.x); // pass alpha through

	vec4 viewpos = cameraView * worldModelPos;
	v_toeye = cameraViewInv[3].xyz - worldModelPos.xyz ;
	v_hcolor = hcolor;
	
	vec3 modelBaseToCamera = cameraViewInv[3].xyz - (pieceMatrix[3].xyz + worldposrot.xyz);
	if ( dot (modelBaseToCamera, modelBaseToCamera) >  (iconDistance * iconDistance)) {
		myTeamColor.a = 0.0; // do something if we are far out?
		v_hcolor.a = 0.0;
	}
	
	v_parameters = parameters;
	mat3 pieceMat3 = mat3(pieceMatrix);
	mat3 modelMat3 = mat3(modelMatrix);
	//v_normal = (((pieceMat3*vec4(rotY *normal,1.0)))).xyz;
	v_normal = modelMat3*pieceMat3*rotY* normal;
	worldPos = worldModelPos.xyz;
	gl_Position = cameraViewProj * worldModelPos;
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

in vec4 v_parameters;
in vec4 myTeamColor;
in vec3 worldPos;
in vec3 v_toeye;
in vec3 v_normal;
in vec4 v_hcolor;


#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)
out vec4 fragColor;
#line 25000
void main() {
	
	float opac = dot(normalize(v_normal), normalize(v_toeye));
	opac = 1.0 - abs(opac);
	opac = pow(opac, 2.0);
	float worldposfactor = fract(worldPos.y * 0.033 + timeInfo.x*0.033);
	fragColor = vec4(opac, 1.0, worldposfactor,worldposfactor);
	
	fragColor.rgb = vec3(1.0);
	fragColor.a = opac;
}
]]


local highlightUnitVBOTable

local uniqueID = 0

local function HighlightUnitGL4(unitID, unitDefID, px, py, pz, rotationY, alpha, teamID, teamcoloroverride, highlight)
	Spring.Debug.TraceEcho()
	-- Documentation for HighlightUnitGL4:
	--	unitID: the actual unitID that you want to draw
	--	unitDefID: which unitDef is it (leave nil for autocomplete)
	-- px, py, py: Apply an offset to the position of the unit, usually all 0
	-- rotationY: Angle in radians on how much to rotate the unit around Y, usually 0
	-- alpha: the transparency level of the unit
	-- teamID: which teams teamcolor should this unit get, leave nil if you want to keep the original teamID
	-- teamcoloroverride: much we should mix the teamcolor into the model color [0-1]
	-- highlight: how much we should add a highlighting animation to the unit (blends white with [0-1])
	-- returns: a unique handler ID number that you should store and call StopHighlightUnitGL4(uniqueID) with to stop drawing it
	-- note that widgets are responsible for stopping the drawing of every unit that they submit!


	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)
	uniqueID = uniqueID + 1
	teamID = teamID or 256
	--teamID = Spring.GetUnitTeam(unitID)
	highlight = highlight or 0
	teamcoloroverride = teamcoloroverride or 0

	Spring.Echo("HighlightUnitGL4", objecttype, UnitDefs[unitDefID].name, unitID, "to uniqueID", uniqueID,"elemID", elementID)

	local elementID = pushElementInstance(highlightUnitVBOTable, {
			px, py, pz, rotationY,
			alpha, 0, teamcoloroverride,highlight ,
			0,0,0,0,
			0,0,0,0
		},
		uniqueID,
		true,
		nil,
		unitID,
		"unitID")
	return uniqueID
end


local function HighlightUnitShapeGL4(unitDefID, px, py, pz, rotationY, alpha, teamID, teamcoloroverride, highlight)
	-- Documentation for HighlightUnitShapeGL4:
	--	unitDefID: which unitDef do you want to draw
	-- px, py, py: where in the world to do you want to draw it
	-- rotationY: Angle in radians on how much to rotate the unit around Y,
		-- 0 means it faces south, (+Z),
		-- pi/2 points west (-X)
		-- -pi/2 points east
	-- alpha: the transparency level of the unit
	-- teamID: which teams teamcolor should this unit get, leave nil if you want to keep the original teamID
	-- teamcoloroverride: much we should mix the teamcolor into the model color [0-1]
	-- highlight: how much we should add a highlighting animation to the unit (blends white with [0-1])
	-- returns: a unique handler ID number that you should store and call StopHighlightUnitGL4(uniqueID) with to stop drawing it
	-- note that widgets are responsible for stopping the drawing of every unit that they submit!
	uniqueID = uniqueID + 1

	teamcoloroverride = teamcoloroverride or 0
	teamID = teamID or 256
	highlight = highlight or 0
	
	--py = py - (UnitDefs[unitDefID].model.midy or 0) -- cause our midpos is somehow offset?
	--py = py - (UnitDefs[unitDefID].model.midy or 0) -- cause our midpos is somehow offset?

	--Spring.Echo("HighlightUnitShapeGL4", "unitDefID", unitDefID, UnitDefs[unitDefID].name, "to unitDefID", uniqueID,"elemID", elementID) 

	local elementID = pushElementInstance(highlightUnitVBOTable, {
			px, py, pz, rotationY,
			alpha, 1, teamcoloroverride, highlight,
			0,0,0,0,
			0,0,0,0
		},
		uniqueID,
		true,
		nil,
		unitDefID,
		"unitDefID")
	return uniqueID
end

local function StopHighlightUnitGL4(uniqueID)
	if highlightUnitVBOTable.instanceIDtoIndex[uniqueID] then
		popElementInstance(highlightUnitVBOTable, uniqueID)
	else
		Spring.Echo("Unable to remove what you wanted in StopHighlightUnitGL4", uniqueID)
	end
	--Spring.Echo("Popped element", uniqueID)
end

local function StopHighlightUnitShapeGL4(uniqueID)
	if highlightUnitVBOTable.instanceIDtoIndex[uniqueID] then
		popElementInstance(highlightUnitVBOTable, uniqueID)
	else
		Spring.Echo("Unable to remove what you wanted in StopHighlightUnitShapeGL4", uniqueID)
	end
	--Spring.Echo("Popped element", uniqueID)
end

local unitIDtoUniqueID = {}
local unitDefIDtoUniqueID = {}

local TESTMODE = true

function widget:UnitCreated(unitID, unitDefID)
	if TESTMODE then
		unitIDtoUniqueID[unitID] =  HighlightUnitGL4(unitID, unitDefID,  0, 0, 0, 0.0, 0.6)

		local px, py, pz = Spring.GetUnitPosition(unitID)
		--unitDefIDtoUniqueID[unitID] = HighlightUnitShapeGL4(Spring.GetUnitDefID(unitID), px+20, py + 50, pz+20, 0, 0.6)
	end
end

function widget:UnitDestroyed(unitID)
	if TESTMODE then
		StopHighlightUnitGL4(unitIDtoUniqueID[unitID])
		unitIDtoUniqueID[unitID] = nil

		StopHighlightUnitShapeGL4(unitDefIDtoUniqueID[unitID])
		unitDefIDtoUniqueID[unitID] = nil
	end
end

function widget:Initialize()

	local vertVBO = gl.GetVBO(GL.ARRAY_BUFFER, false) -- GL.ARRAY_BUFFER, false
	local indxVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false) -- GL.ARRAY_BUFFER, false
	vertVBO:ModelsVBO()
	indxVBO:ModelsVBO()

	local VBOLayout = {
			{id = 6, name = "worldposrot", size = 4},
			{id = 7, name = "parameters" , size = 4},
			{id = 8, name = "hcolor",      size = 4},
			{id = 9, name = "instData", type = GL.UNSIGNED_INT, size = 4},
		}

	local maxElements = 6 -- start small for testing
	local unitIDAttributeIndex = 9
	highlightUnitVBOTable = makeInstanceVBOTable(VBOLayout, maxElements, "highlightUnitVBOTable", unitIDAttributeIndex, "unitID")

	highlightUnitVBOTable.VAO = makeVAOandAttach(vertVBO, highlightUnitVBOTable.instanceVBO, indxVBO)
	highlightUnitVBOTable.indexVBO = indxVBO
	highlightUnitVBOTable.vertexVBO = vertVBO

	local unitIDs = Spring.GetAllUnits()
	local featuresIDs = Spring.GetAllFeatures()

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)

	highlightunitShader = LuaShader({
		vertex = vsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(highlightunitShaderConfig)),
		fragment = fsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(highlightunitShaderConfig)),
		uniformInt = {
			--tex1 = 0,
			--tex2 = 1,
		},
		uniformFloat = {
			iconDistance = 1,
		  },
	}, "highlightUnitShader API")

	local highlightunitShaderCompiled = highlightunitShader:Initialize()
	if highlightunitShaderCompiled ~= true then
		Spring.Echo("highlightUnitShader API shader compilation failed", highlightunitShaderCompiled)
		widgetHandler:RemoveWidget()
	end
	if TESTMODE then
		for i, unitID in ipairs(Spring.GetAllUnits()) do
			widget:UnitCreated(unitID)
		end
	end
	WG['HighlightUnitGL4'] = HighlightUnitGL4
	WG['HighlightUnitShapeGL4'] = HighlightUnitShapeGL4
	WG['StopHighlightUnitGL4'] = StopHighlightUnitGL4
	WG['StopHighlightUnitShapeGL4'] = StopHighlightUnitShapeGL4
end


function widget:Shutdown()
	if highlightUnitVBOTable.VAO then highlightUnitVBOTable.VAO:Delete() end
	if highlightunitShader then highlightunitShader:Finalize() end

	WG['HighlightUnitGL4'] = nil
	WG['HighlightUnitShapeGL4'] = nil
	WG['StopHighlightUnitGL4'] = nil
	WG['StopHighlightUnitShapeGL4'] = nil
end


function widget:DrawWorld()
	if highlightUnitVBOTable.usedElements > 0 then
		gl.Culling(GL.BACK)
		gl.DepthMask(true)
		gl.DepthTest(true)
		gl.PolygonOffset( -2 ,-2)
		highlightunitShader:Activate()
		highlightunitShader:SetUniform("iconDistance",27 * Spring.GetConfigInt("UnitIconDist", 200))
		highlightUnitVBOTable.VAO:Submit()
		highlightunitShader:Deactivate()
		gl.PolygonOffset(false)
		gl.Culling(false)
	end
end

function widget:DrawWorldPreUnit() -- this is for UnitDef
	if true then return end -- remove for now
	if highlightUnitVBOTable.usedElements > 0  then
		gl.Culling(GL.BACK)
		gl.DepthMask(false) -- this might be a problem for non-transparent stuff?
		gl.DepthTest(GL.LEQUAL)
		--gl.PolygonOffset ( 0.5,0.5 )
		unitShapeShader:Activate()
		unitShapeShader:SetUniform("iconDistance",27 * Spring.GetConfigInt("UnitIconDist", 200))
		highlightUnitVBOTable.VAO:Submit()
		unitShapeShader:Deactivate()
		gl.UnitShapeTextures(udefID, false)
		--gl.PolygonOffset( false )
		gl.Culling(false)
	end
end
