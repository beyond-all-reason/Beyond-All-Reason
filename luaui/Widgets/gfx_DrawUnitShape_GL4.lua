function widget:GetInfo()
  return {
    name      = "DrawUnitShape GL4",
    version   = "v0.2",
    desc      = "Faster gl.UnitShape, Use WG.UnitShapeGL4",
    author    = "ivand, Beherith",
    date      = "2021.11.04",
	license   = "GNU GPL, v2 or later",
    layer     = -9999,
    enabled   = true,
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
	SKINSUPPORT = Spring.Utilities.EngineVersionAtLeast(105,1,1,1653) and 1 or 0,
}

local vsSrc = [[
#version 330
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

out vec2 v_uv;
out vec4 v_parameters;
out vec4 myTeamColor;
out vec3 worldPos;

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

local fsSrc = [[
#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000

uniform sampler2D tex1;
uniform sampler2D tex2;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in vec2 v_uv;
in vec4 v_parameters;
in vec4 myTeamColor;
in vec3 worldPos;

out vec4 fragColor;
#line 25000
void main() {
	vec4 modelColor = texture(tex1, v_uv.xy);
	vec4 extraColor = texture(tex2, v_uv.xy);
	modelColor += modelColor * extraColor.r; // emission
	modelColor.a *= extraColor.a; // basic model transparency
	modelColor.rgb = mix(modelColor.rgb, myTeamColor.rgb, modelColor.a); // apply teamcolor

	modelColor.a *= myTeamColor.a; // shader define transparency
	modelColor.rgb = mix(modelColor.rgb, myTeamColor.rgb, v_parameters.z); //globalteamcoloramount override
	if (v_parameters.w > 0){
		modelColor.rgb = mix(modelColor.rgb, vec3(1.0), v_parameters.w*fract(worldPos.y*0.03 + (timeInfo.x + timeInfo.w)*0.05));
	}

	fragColor = vec4(modelColor.rgb, myTeamColor.a);
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

local function DrawUnitGL4(unitID, unitDefID, px, py, pz, rotationY, alpha, teamID, teamcoloroverride, highlight)
	-- Documentation for DrawUnitGL4:
	--	unitID: the actual unitID that you want to draw
	--	unitDefID: which unitDef is it (leave nil for autocomplete)
	-- px, py, py: Apply an offset to the position of the unit, usually all 0
	-- rotationY: Angle in radians on how much to rotate the unit around Y, usually 0
	-- alpha: the transparency level of the unit
	-- teamID: which teams teamcolor should this unit get, leave nil if you want to keep the original teamID
	-- teamcoloroverride: much we should mix the teamcolor into the model color [0-1]
	-- highlight: how much we should add a highlighting animation to the unit (blends white with [0-1])
	-- returns: a unique handler ID number that you should store and call StopDrawUnitGL4(uniqueID) with to stop drawing it
	-- note that widgets are responsible for stopping the drawing of every unit that they submit!

	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)

	uniqueID = uniqueID + 1

	teamID = teamID or 256
	--teamID = Spring.GetUnitTeam(unitID)
	highlight = highlight or 0
	teamcoloroverride = teamcoloroverride or 0
	local DrawUnitVBOTable
	--Spring.Echo("DrawUnitGL4", objecttype, UnitDefs[unitDefID].name, unitID, "to uniqueID", uniqueID,"elemID", elementID)
	if corUnitDefIDs[unitDefID] then DrawUnitVBOTable = corDrawUnitVBOTable
	elseif armUnitDefIDs[unitDefID] then DrawUnitVBOTable = armDrawUnitVBOTable
	else
		Spring.Echo("The given unitDefID", unitDefID, "is neither arm nor cor, only those two are supported at the moment")
		Spring.Debug.TraceFullEcho(nil,nil,nil,"DrawUnitGL4")
		return nil
	end

	local elementID = pushElementInstance(DrawUnitVBOTable, {
			px, py, pz, rotationY,
			alpha, 0, teamcoloroverride,highlight ,
			teamID, 0,
			0,0,0,0
		},
		uniqueID,
		true,
		nil,
		unitID,
		"unitID")
	return uniqueID
end


local function DrawUnitShapeGL4(unitDefID, px, py, pz, rotationY, alpha, teamID, teamcoloroverride, highlight)
	-- Documentation for DrawUnitShapeGL4:
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
	-- returns: a unique handler ID number that you should store and call StopDrawUnitGL4(uniqueID) with to stop drawing it
	-- note that widgets are responsible for stopping the drawing of every unit that they submit!
	uniqueID = uniqueID + 1

	teamcoloroverride = teamcoloroverride or 0
	teamID = teamID or 256
	highlight = highlight or 0

	--py = py - (UnitDefs[unitDefID].model.midy or 0) -- cause our midpos is somehow offset?
	--py = py - (UnitDefs[unitDefID].model.midy or 0) -- cause our midpos is somehow offset?
	local DrawUnitShapeVBOTable
	--Spring.Echo("DrawUnitShapeGL4", "unitDefID", unitDefID, UnitDefs[unitDefID].name, "to unitDefID", uniqueID,"elemID", elementID)
	if corUnitDefIDs[unitDefID] then DrawUnitShapeVBOTable = corDrawUnitShapeVBOTable
	elseif armUnitDefIDs[unitDefID] then DrawUnitShapeVBOTable = armDrawUnitShapeVBOTable
	else
		Spring.Echo("The given unitDefID", unitDefID, "is neither arm nor cor, only those two are supported at the moment")
		Spring.Debug.TraceFullEcho(nil,nil,nil,"DrawUnitGL4")
		return nil
	end



	local elementID = pushElementInstance(DrawUnitShapeVBOTable, {
			px, py, pz, rotationY,
			alpha, 1, teamcoloroverride, highlight,
			teamID, 0,
			0,0,0,0
		},
		uniqueID,
		true,
		nil,
		unitDefID,
		"unitDefID")
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
	--Spring.Echo("Popped element", uniqueID)
end

local function StopDrawUnitShapeGL4(uniqueID)
	if corDrawUnitShapeVBOTable.instanceIDtoIndex[uniqueID] then
		popElementInstance(corDrawUnitShapeVBOTable, uniqueID)
	elseif armDrawUnitShapeVBOTable.instanceIDtoIndex[uniqueID] then
		popElementInstance(armDrawUnitShapeVBOTable, uniqueID)
	else
		Spring.Echo("Unable to remove what you wanted in StopDrawUnitShapeGL4", uniqueID)
	end
	--Spring.Echo("Popped element", uniqueID)
end

local unitIDtoUniqueID = {}
local unitDefIDtoUniqueID = {}

local TESTMODE = false

function widget:UnitCreated(unitID, unitDefID)
	if TESTMODE then
		unitIDtoUniqueID[unitID] =  DrawUnitGL4(unitID, unitDefID,  0, 0, 0, math.random()*2, 0.6)

		local px, py, pz = Spring.GetUnitPosition(unitID)
		unitDefIDtoUniqueID[unitID] = DrawUnitShapeGL4(Spring.GetUnitDefID(unitID), px+20, py + 50, pz+20, 0, 0.6)
	end
end

function widget:UnitDestroyed(unitID)
	if TESTMODE then
		StopDrawUnitGL4(unitIDtoUniqueID[unitID])
		unitIDtoUniqueID[unitID] = nil

		StopDrawUnitShapeGL4(unitDefIDtoUniqueID[unitID])
		unitDefIDtoUniqueID[unitID] = nil
	end
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
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

	local maxElements = 6 -- start small for testing
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

	local unitshaderCompiled = unitShader:Initialize()
	local unitshapeshaderCompiled = unitShapeShader:Initialize()
	if unitshaderCompiled ~= true or  unitshapeshaderCompiled ~= true then
		Spring.Echo("DrawUnitShape shader compilation failed", unitshaderCompiled, unitshapeshaderCompiled)
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
	WG['armDrawUnitShapeVBOTable'] = armDrawUnitShapeVBOTable
	WG['corDrawUnitShapeVBOTable'] = corDrawUnitShapeVBOTable
	widgetHandler:RegisterGlobal('DrawUnitGL4', DrawUnitGL4)
	widgetHandler:RegisterGlobal('DrawUnitShapeGL4', DrawUnitShapeGL4)
	widgetHandler:RegisterGlobal('StopDrawUnitGL4', StopDrawUnitGL4)
	widgetHandler:RegisterGlobal('StopDrawUnitShapeGL4', StopDrawUnitShapeGL4)
	widgetHandler:RegisterGlobal('armDrawUnitShapeVBOTable', armDrawUnitShapeVBOTable)
	widgetHandler:RegisterGlobal('corDrawUnitShapeVBOTable', corDrawUnitShapeVBOTable)
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

	WG['DrawUnitGL4'] = nil
	WG['DrawUnitShapeGL4'] = nil
	WG['StopDrawUnitGL4'] = nil
	WG['StopDrawUnitShapeGL4'] = nil
	WG['armDrawUnitShapeVBOTable'] = nil
	WG['corDrawUnitShapeVBOTable'] = nil
	widgetHandler:DeregisterGlobal('DrawUnitGL4')
	widgetHandler:DeregisterGlobal('DrawUnitShapeGL4')
	widgetHandler:DeregisterGlobal('StopDrawUnitGL4')
	widgetHandler:DeregisterGlobal('StopDrawUnitShapeGL4')
	widgetHandler:DeregisterGlobal('armDrawUnitShapeVBOTable')
	widgetHandler:DeregisterGlobal('armDrawUnitShapeVBOTable')
end

function widget:DrawWorldPreUnit() -- this is for UnitDef
	if armDrawUnitShapeVBOTable.usedElements > 0 or corDrawUnitShapeVBOTable.usedElements > 0 then
		gl.Culling(GL.BACK)
		gl.DepthMask(true)
		gl.DepthTest(GL.LEQUAL)
		--gl.PolygonOffset ( 0.5,0.5 )
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
		--gl.PolygonOffset( false )
		gl.Culling(false)
	end
end

function widget:DrawWorld()
	if armDrawUnitVBOTable.usedElements > 0 or corDrawUnitVBOTable.usedElements > 0 then
		gl.Culling(GL.BACK)
		gl.DepthMask(true)
		gl.DepthTest(true)
		gl.PolygonOffset( -2 ,-2)
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
    gl.DepthMask(false) --"BK OpenGL state resets", reset to default state
	end
end
