local widget = widget ---@type Widget

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
    depends   = {'gl4'},
  }
end


-- Localized functions for performance

-- Localized Spring API for performance
local spGetUnitDefID = Spring.GetUnitDefID
local spEcho = Spring.Echo

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
-- NOTE: DYNAMIC MODELS ARE UNSUPPORTED WITH QUATERNIONS!!!
-- void LuaVAOImpl::RemoveFromSubmission(int idx)


local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOIdTable

local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance  = InstanceVBOTable.popElementInstance


local unitShader, unitShapeShader

local unitShaderConfig = {
	STATICMODEL = 0.0, -- do not touch!
	TRANSPARENCY = 0.5, -- transparency of the stuff drawn
	USEQUATERNIONS = Engine.FeatureSupport.transformsInGL4 and "1" or "0",
}

local unitShapeShaderConfig = {
	STATICMODEL = 1.0, -- do not touch!
	TRANSPARENCY = 0.5,
	USEQUATERNIONS = Engine.FeatureSupport.transformsInGL4 and "1" or "0",
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

layout (location = 5) in uvec2 bonesInfo; //boneIDs, boneWeights
#define pieceIndex (bonesInfo.x & 0x000000FFu)

layout (location = 6) in vec4 worldposrot;
layout (location = 7) in vec4 parameters; // x = alpha, y = isstatic, z = globalteamcoloramount, w = selectionanimation
layout (location = 8) in uvec2 overrideteam; // x = override teamcolor if < 256
layout (location = 9) in uvec4 instData;

uniform float iconDistance;

//__ENGINEUNIFORMBUFFERDEFS__

#line 15000

#if USEQUATERNIONS == 0
	layout(std140, binding=0) buffer MatrixBuffer {
		mat4 mat[];
	};
	mat4 GetPieceMatrix(bool staticModel) {
    	return mat[instData.x + pieceIndex + uint(!staticModel)];
	}
#else
	//__QUATERNIONDEFS__
#endif



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
	// parameters.y is always 1 (as we only use this lib for static models)

	// dynamic models have one extra matrix, as their first matrix is their world pos/offset
	uint isDynamic = 1u; //default dynamic model
	if (parameters.y > 0.5) isDynamic = 0u;  //if paramy == 1 then the unit is static

	#if USEQUATERNIONS == 0
		mat4 pieceMatrix = mat[baseIndex + pieceIndex + isDynamic];

		vec4 localModelPos = pieceMatrix * vec4(pos, 1.0);
	#else
		Transform tx = GetStaticPieceModelTransform(baseIndex, pieceIndex );
		vec4 localModelPos = ApplyTransform(tx, vec4(pos, 1.0));
	#endif

	// Make the rotation matrix around Y and rotate the model
	mat3 rotY = rotation3dY(worldposrot.w);
	localModelPos.xyz = rotY * localModelPos.xyz;

	vec4 worldModelPos = localModelPos;
	// Dynamic model:
	#if USEQUATERNIONS == 0
		if (parameters.y < 0.5) {
			mat4 modelMatrix = mat[baseIndex];
			worldModelPos = modelMatrix*localModelPos;
		}
	#endif
	worldModelPos.xyz += worldposrot.xyz; //Place it in the world

	uint teamIndex = (instData.z & 0x000000FFu); //leftmost ubyte is teamIndex
	uint drawFlags = (instData.z & 0x0000FF00u) >> 8 ; // hopefully this works
	if (overrideteam.x < 255u) teamIndex = overrideteam.x;

	myTeamColor = vec4(teamColor[teamIndex].rgb, parameters.x); // pass alpha through

	vec3 modelBaseToCamera = cameraViewInv[3].xyz - (worldposrot.xyz);
	if ( dot (modelBaseToCamera, modelBaseToCamera) >  (iconDistance * iconDistance)) {
		if (isDynamic == 1u) { // Only hide dynamic units when zoomed out
			myTeamColor.a = 0.0; // do something if we are far out?
		}
	}

	v_parameters = parameters;
	v_uv = uv.xy;
	worldPos = worldModelPos.xyz;
	gl_Position = cameraViewProj * worldModelPos;
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

local unitDefIDtoTex1 = {} -- Keys unit def IDs to whichever tex1 is used
local tex1ToVBO = {['arm_color.dds'] = true, ['cor_color.dds'] = true, ['leg_color.dds'] = true, ['legmech_color.dds'] = true} -- Keys texture1 to which VBO is used, small intermediate table, not really used
local unitDeftoUnitShapeVBOTable = {} --  The important one, which keys the unitDefID to the actual vbo table to be used
local uniqueIDtoUnitShapeVBOTable = {}

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

	unitDefID = unitDefID or spGetUnitDefID(unitID)

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
	
	local DrawUnitVBOTable
	--spEcho("DrawUnitGL4", objecttype, UnitDefs[unitDefID].name, unitID, "to uniqueID", uniqueID,"elemID", elementID)
	if corUnitDefIDs[unitDefID] then DrawUnitVBOTable = corDrawUnitVBOTable
	elseif armUnitDefIDs[unitDefID] then DrawUnitVBOTable = armDrawUnitVBOTable
	else
		spEcho("DrawUnitGL4 : The given unitDefID", unitDefID, UnitDefs[unitDefID].name, "is neither arm nor cor, only those two are supported at the moment")
		Spring.Debug.TraceFullEcho(nil,nil,nil,"DrawUnitGL4")
		return nil
	end
	
	instanceCache[1], instanceCache[2], instanceCache[3], instanceCache[4] = px, py, pz, rotationY
	instanceCache[5], instanceCache[6], instanceCache[7], instanceCache[8] = alpha, 0, teamcoloroverride, highlight
	instanceCache[9] = teamID
	
	local elementID = pushElementInstance(
		DrawUnitVBOTable,
		instanceCache,
		updateID,
		true,
		nil,
		unitID,
		"unitID")
	return updateID
end

---DrawUnitShapeGL4(unitDefID, px, py, pz, rotationY, alpha, teamID, teamcoloroverride, highlight, updateID, ownerID)
---Draw a static unit shape model anywhere. Like for ghosted buildings 
---note that widgets are responsible for stopping the drawing of every unit that they submit! They may use RemoveMyDraws(ownerID) 
---@param unitDefID number which unitDef do you want to draw
---@param px number where in the world to do you want to draw it
---@param py number where in the world to do you want to draw it
---@param pz number where in the world to do you want to draw it
---@param rotationY number Angle in radians on how much to rotate the unit around Y, 0 means it faces south, (+Z), pi/2 points west (-X) -pi/2 points east
---@param alpha number optional the transparency level of the unit
---@param teamID number optional which teams teamcolor should this unit get, leave nil if you want to keep the original teamID
---@param teamcoloroverride number optional much we should mix the teamcolor into the model color [0-1]
---@param highlight number optional how much we should add a highlighting animation to the unit (blends white with [0-1])
---@param updateID number optional specify the previous uniqueID if you want to update it
---@param ownerID any optional unique identifier so that widgets can batch remove all of their own stuff
---@return uniqueID number a unique handler ID number that you should store and call StopDrawUnitGL4(uniqueID) with to stop drawing it
local function DrawUnitShapeGL4(unitDefID, px, py, pz, rotationY, alpha, teamID, teamcoloroverride, highlight, updateID, ownerID)
	alpha = alpha or 0.5
	teamcoloroverride = teamcoloroverride or 0
	teamID = teamID or 256
	highlight = highlight or 0
	
	if not updateID then 
		uniqueID = uniqueID + 1
		updateID = uniqueID
	end
	
	if ownerID then owners[updateID] = ownerID end

	local DrawUnitShapeVBOTable = unitDeftoUnitShapeVBOTable[unitDefID]
	
	if not DrawUnitShapeVBOTable then 
		spEcho("DrawUnitShapeGL4: The given unitDefID", unitDefID,  UnitDefs[unitDefID].name, "is missing a target DrawUnitShapeVBOTable")
		Spring.Debug.TraceFullEcho(nil,nil,nil,"DrawUnitGL4")
		return nil
	end
	uniqueIDtoUnitShapeVBOTable[uniqueID] = DrawUnitShapeVBOTable
	--spEcho("DrawUnitShapeGL4", "unitDefID", unitDefID, UnitDefs[unitDefID].name, "to unitDefID", uniqueID,"elemID", elementID)
	
	instanceCache[1], instanceCache[2], instanceCache[3], instanceCache[4] = px, py, pz, rotationY
	instanceCache[5], instanceCache[6], instanceCache[7], instanceCache[8] = alpha, 1, teamcoloroverride, highlight
	instanceCache[9] = teamID
	
	local elementID = pushElementInstance(
		DrawUnitShapeVBOTable,
		instanceCache,
		updateID,
		true,
		nil,
		unitDefID,
		"unitDefID")
	return updateID
end

---StopDrawUnitGL4(uniqueID)
---@param uniqueID number the unique id of whatever you want to stop drawing
---@return the ownerID the uniqueID was associated to
local function StopDrawUnitGL4(uniqueID)
	if corDrawUnitVBOTable.instanceIDtoIndex[uniqueID] then
		popElementInstance(corDrawUnitVBOTable, uniqueID)
	elseif armDrawUnitVBOTable.instanceIDtoIndex[uniqueID] then
		popElementInstance(armDrawUnitVBOTable, uniqueID)
	else
		spEcho("Unable to remove what you wanted in StopDrawUnitGL4", uniqueID)
	end
	local owner = owners[uniqueID]
	owners[uniqueID] = nil
	--spEcho("Popped element", uniqueID)
	return owner
end

---StopDrawUnitGL4(uniqueID)
---@param uniqueID number the unique id of whatever you want to stop drawing
---@return the ownerID the uniqueID was associated to
local function StopDrawUnitShapeGL4(uniqueID)
	
	if uniqueIDtoUnitShapeVBOTable[uniqueID] then 
		local DrawUnitShapeVBOTable = uniqueIDtoUnitShapeVBOTable[uniqueID]
		if DrawUnitShapeVBOTable.instanceIDtoIndex[uniqueID] then
			popElementInstance(DrawUnitShapeVBOTable, uniqueID) 
		else
			spEcho("DrawUnitShapeGL4: the given uniqueID", uniqueID," is not present in the DrawUnitShapeVBOTable", DrawUnitShapeVBOTable.vboname, "that we expected it to be in" )
		end
		
	else
	
		spEcho("DrawUnitShapeGL4: the given uniqueID", uniqueID," is not present in the uniqueIDtoUnitShapeVBOTable, it might already have been removed?")	
	end
	
	uniqueIDtoUnitShapeVBOTable[uniqueID] = nil
	
	local owner = owners[uniqueID]
	owners[uniqueID] = nil
	--spEcho("Popped element", uniqueID)
	return owner
end

---StopDrawAll(ownerID) removes all units and unitshapes registered for this owner ID
---@param ownerID any identifier for which to remove all things being drawn. All get removed if ownerID is nil
---@return ownedCount number how many items were removed
local function StopDrawAll(ownerID)
	local ownedCount = 0
	for uniqueID, owner in pairs(owners) do 
		if owner == ownerID or ownerID == nil then 
			for _,VBOTable in ipairs(VBOTables) do -- attach everything together
				if VBOTable.instanceIDtoIndex[uniqueID] then 
					popElementInstance(VBOTable, uniqueID)
					break
				end
			end
			if uniqueIDtoUnitShapeVBOTable[uniqueID] then 
				local DrawUnitShapeVBOTable = uniqueIDtoUnitShapeVBOTable[uniqueID]
				if DrawUnitShapeVBOTable.instanceIDtoIndex[uniqueID] then
					popElementInstance(DrawUnitShapeVBOTable, uniqueID) 
				else
					spEcho("DrawUnitShapeGL4 StopDrawAll: the given uniqueID", uniqueID," is not present in the DrawUnitShapeVBOTable", DrawUnitShapeVBOTable.vboname, "that we expected it to be in" )
				end
			end 
			
			owners[uniqueID] = nil
			ownedCount = ownedCount + 1
			
		end
		
	end
	return ownedCount
end

local TESTMODE = false

if TESTMODE then 
	local unitIDtoUniqueID = {}
	local unitDefIDtoUniqueID = {}
	function widget:UnitCreated(unitID, unitDefID)
		unitIDtoUniqueID[unitID] =  DrawUnitGL4(unitID, unitDefID,  0, 0, 0, math.random()*2, 0.6)
		local px, py, pz = Spring.GetUnitPosition(unitID)
		unitDefIDtoUniqueID[unitID] = DrawUnitShapeGL4(spGetUnitDefID(unitID), px+20, py + 50, pz+20, 0, 0.6)
	end

	function widget:UnitDestroyed(unitID)
		StopDrawUnitGL4(unitIDtoUniqueID[unitID])
		unitIDtoUniqueID[unitID] = nil

		StopDrawUnitShapeGL4(unitDefIDtoUniqueID[unitID])
		unitDefIDtoUniqueID[unitID] = nil
	end
end

function widget:Initialize()
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.model and unitDef.model.textures and unitDef.model.textures.tex1 then 
			unitDefIDtoTex1[unitDefID] = unitDef.model.textures.tex1:lower()
		end
		
		if unitDef.model and unitDef.model.textures and unitDef.model.textures.tex1:lower() == "arm_color.dds" then
			armUnitDefIDs[unitDefID] = true
		elseif unitDef.model and unitDef.model.textures and unitDef.model.textures.tex1:lower() == "cor_color.dds" then
			corUnitDefIDs[unitDefID] = true
		end
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
	corDrawUnitVBOTable         = InstanceVBOTable.makeInstanceVBOTable(VBOLayout, maxElements, "corDrawUnitVBOTable", unitIDAttributeIndex, "unitID")
	armDrawUnitVBOTable         = InstanceVBOTable.makeInstanceVBOTable(VBOLayout, maxElements, "armDrawUnitVBOTable", unitIDAttributeIndex, "unitID")

	VBOTables = {corDrawUnitVBOTable, armDrawUnitVBOTable}

	for i,VBOTable in ipairs(VBOTables) do -- attach everything together
		VBOTable.VAO = InstanceVBOTable.makeVAOandAttach(vertexVBO, VBOTable.instanceVBO, indexVBO)
		VBOTable.indexVBO = indexVBO
		VBOTable.vertexVBO = vertexVBO
	end
		
	-- This section is for automatically creating all vbos for all posible tex combos.
	-- However it is disabled here, as there are only 4 true tex combos, as defined above in tex1ToVBOx
	--for unitDefID, tex1 in pairs(unitDefIDtoTex1) do 
	--	if not tex1ToVBO[tex1] then spEcho("DrawUnitShape unique tex1 is",tex1) end
	--	tex1ToVBO[tex1] = true 
	--end 
	
	for tex1, _ in pairs(tex1ToVBO) do 
		local vboname = 'DrawUnitShapeVBOTable:' .. tex1
		local vboTable = InstanceVBOTable.makeInstanceVBOTable(VBOLayout, maxElements, vboname, unitIDAttributeIndex, "unitDefID")
		vboTable.VAO = InstanceVBOTable.makeVAOandAttach(vertexVBO, vboTable.instanceVBO, indexVBO)
		vboTable.indexVBO = indexVBO
		vboTable.vertexVBO = vertexVBO
		tex1ToVBO[tex1] = vboTable
	end
	
	for unitDefID, tex1 in pairs(unitDefIDtoTex1) do 
		if tex1ToVBO[tex1] then 
			unitDeftoUnitShapeVBOTable[unitDefID] = tex1ToVBO[tex1]
			-- This is very important, we need to remember an example unitDefID here
			-- to use to retrive the corresponding texture bucket
			unitDeftoUnitShapeVBOTable[unitDefID].UnitShapeTexturesUnitDefID = unitDefID
		end
	end

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	vsSrc = vsSrc:gsub("//__QUATERNIONDEFS__", LuaShader.GetQuaternionDefs())
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__QUATERNIONDEFS__", LuaShader.GetQuaternionDefs())

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
		spEcho("DrawUnitShape shader compilation failed", unitshaderCompiled, unitshapeshaderCompiled)
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
				InstanceVBOTable.dumpAndCompareInstanceData(VBOTable)
			end
			VBOTable.VAO:Delete()
		end
	end
	
	for tex1,VBOTable in ipairs(tex1ToVBO) do
		if VBOTable.VAO then
			if Spring.Utilities.IsDevMode() then
				InstanceVBOTable.dumpAndCompareInstanceData(VBOTable)
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
	WG['StopDrawAll'] = nil
	WG['armDrawUnitShapeVBOTable'] = nil
	WG['corDrawUnitShapeVBOTable'] = nil
	widgetHandler:DeregisterGlobal('DrawUnitGL4')
	widgetHandler:DeregisterGlobal('DrawUnitShapeGL4')
	widgetHandler:DeregisterGlobal('StopDrawUnitGL4')
	widgetHandler:DeregisterGlobal('StopDrawUnitShapeGL4')
	widgetHandler:DeregisterGlobal('armDrawUnitShapeVBOTable')
	widgetHandler:DeregisterGlobal('corDrawUnitShapeVBOTable')
	widgetHandler:DeregisterGlobal('StopDrawAll')
end


function widget:DrawWorldPreUnit() -- this is for UnitDef
	local active = false
	
	for tex1, unitShapeVBOTable in pairs(tex1ToVBO) do 
		if unitShapeVBOTable.usedElements > 0 then 
			
			if not active then 
				gl.Culling(GL.BACK)
				gl.DepthMask(true)
				gl.DepthTest(GL.LEQUAL)
				gl.PolygonOffset(1, 1) -- so as not to clash with engine ghosts
				unitShapeShader:Activate()
				unitShapeShader:SetUniform("iconDistance",27 * Spring.GetConfigInt("UnitIconDist", 200))
				active = true
			end
			
			gl.UnitShapeTextures(unitShapeVBOTable.UnitShapeTexturesUnitDefID, true)
			unitShapeVBOTable.VAO:Submit()
		end
	end
	if active then 
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
