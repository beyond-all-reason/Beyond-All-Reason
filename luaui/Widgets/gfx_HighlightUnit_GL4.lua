local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "HighlightUnit API GL4",
    version   = "v0.2",
    desc      = "DEPRECATED! Highlight any unit, feature, unitDef or FeatureDef via WG.HighlightUnitGL4",
    author    = "Beherith,ivand",
    date      = "2022.01.04",
	license   = "GNU GPL, v2 or later",
    layer     = -999999,
    enabled   = true,
  }
end


-- Localized functions for performance

-- Localized Spring API for performance
local spGetUnitDefID = Spring.GetUnitDefID
local spEcho = Spring.Echo

-- Notes: this API can be considered mildly deprecated, as CUS GL4 now handles the major consumers of this API.
-- This API is now fully deprecated, as the swith to quaternions breaks it entirely.


local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOIdTable

local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance  = InstanceVBOTable.popElementInstance

local highlightunitShader, unitShapeShader
local highlightUnitVBOTable
local uniqueID = 0

local debugmode = 0

local highlightunitShaderConfig = {
	ANIMSPEED = 2 / Game.gameSpeed,
	ANIMFREQUENCY = 1 / Game.gameSpeed,
	SKINSUPPORT = Script.IsEngineMinVersion(105, 0, 1653) and 1 or 0,
}


local vsSrc =
[[#version 420
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
layout (location = 7) in vec4 parameters; // x =isstatic, y = edgealpha, z = edgeexponent, w = animamount
layout (location = 8) in vec4 hcolor; // rgb color, plainalpha
layout (location = 9) in uvec4 instData;

uniform float iconDistance;

//__ENGINEUNIFORMBUFFERDEFS__


#line 15000
layout(std140, binding=0) readonly buffer MatrixBuffer {
	mat4 mat[];
};

struct SUniformsBuffer {
    uint composite; //     u8 drawFlag; u8 unused1; u16 id;

    uint unused2;
    uint unused3;
    uint unused4;

    float maxHealth;
    float health;
    float unused5;
    float unused6;

    vec4 drawPos;
    vec4 speed;
    vec4[4] userDefined; //can't use float[16] because float in arrays occupies 4 * float space
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
    SUniformsBuffer uni[];
};

out vec4 v_parameters;
out vec3 worldPos;
out vec3 v_toeye;
out vec3 v_normal;
out vec4 v_hcolor;

void main() {
	uint baseIndex = instData.x;

	mat4 modelWorldMatrix = mat[baseIndex];

	// dynamic models have one extra matrix, as their first matrix is their world pos/offset
	uint isDynamic = 1u; //default dynamic model
	if (parameters.x > 0.5) isDynamic = 0u;  //if paramy == 1 then the unit is static
	mat4 pieceMatrix = mat[baseIndex + pieceIndex + isDynamic];

	vec4 localModelPos = pieceMatrix * vec4(pos, 1.0);


	// Make the rotation matrix around Y and rotate the model
	mat3 rotY = rotation3dY(worldposrot.w);
	localModelPos.xyz = rotY * localModelPos.xyz;

	vec4 worldModelPos = localModelPos;
	if (parameters.x < 0.5) worldModelPos = modelWorldMatrix * localModelPos; // dynamic models must be tranformed into their correct pos
	worldModelPos.xyz += worldposrot.xyz; //Place it in the world

	uint teamIndex = (instData.z & 0x000000FFu); //leftmost ubyte is teamIndex
	uint drawFlags = (instData.z & 0x0000FF00u) >> 8 ; // hopefully this works

	vec4 viewpos = cameraView * worldModelPos;
	v_toeye = cameraViewInv[3].xyz - worldModelPos.xyz ;
	v_hcolor = hcolor;

	vec3 modelBaseToCamera = cameraViewInv[3].xyz - (pieceMatrix[3].xyz + worldposrot.xyz);
	if ( dot (modelBaseToCamera, modelBaseToCamera) >  (iconDistance * iconDistance)) {
		v_hcolor.a = 0.0;
	}
	v_parameters = parameters;
	if ((uni[instData.y].composite & 0x00000001u) == 0u ) { // alpha 0 drawing of icons stuff
		v_hcolor.a = 0.0;
		v_parameters.yw = vec2(0.0);
	}

	mat3 pieceMatrixRotationOnly = mat3(pieceMatrix);
	mat3 modelWorldMatrixRotationOnly = mat3(modelWorldMatrix);

	v_normal = modelWorldMatrixRotationOnly * pieceMatrixRotationOnly * rotY * normal;
	worldPos = worldModelPos.xyz;
	gl_Position = cameraViewProj * worldModelPos;
}
]]

local fsSrc = [[
#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in vec4 v_parameters; // x =isstatic, y = edgealpha, z = edgeexponent, w = animamount
in vec3 worldPos;
in vec3 v_toeye;
in vec3 v_normal;
in vec4 v_hcolor;

#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)
out vec4 fragColor;
#line 25000
void main() {
	float worldposfactor = fract(worldPos.y * ANIMFREQUENCY + (timeInfo.x + timeInfo.w)  * ANIMSPEED);

	fragColor = v_hcolor; // Base highlight amount
	fragColor.a = mix(fragColor.a, worldposfactor * fragColor.a, v_parameters.w); // mix in animation into plain highight

	float opac = dot(normalize(v_normal), normalize(v_toeye));
	opac = 1.0 - abs(opac);
	opac = pow(opac, v_parameters.z) * v_parameters.y;
	fragColor.a +=   mix(opac, opac * worldposfactor, v_parameters.w) ; // edge highlighing mixed according to animation

	fragColor.rgb += opac * 1.3; // brighten all, a bit more

	// debug all 3 components:
	//fragColor.rgba = vec4(v_hcolor.a, opac * v_parameters.y, worldposfactor * v_parameters.w , 1.0);
}
]]

local uniqueIDtoUnitID = {}
local unitIDtoUniqueID = {} -- table of tables, as a unitid can have multiple highlights fuck yeah

local unitDefIgnore = {} -- We explicitly disallow the highlighting of any unitDef like this, as it interferes with unit tracker api!
--for unitDefID, unitDef in pairs(UnitDefs) do
--	if unitDef.customParams and unitDef.customParams.nohealthbars then
--		unitDefIgnore[unitDefID] = true
--	end --ignore debug units
--end


local function HighlightUnitGL4(objectID, objecttype, r, g, b, alpha, edgealpha, edgeexponent, animamount, px, py, pz, rotationY, consumerID)
	-- Documentation for HighlightUnitGL4:
	-- objectID: the unitID, unitDefID, featureID or featureDefID you want
	-- objecttype: "unitID" or "unitDefID" or "featureID" or "featureDefID"
	-- r,g,b : the color to use for highlighting
	-- a, the global amount of alpha
	-- rotationY: Angle in radians on how much to rotate the unit around Y, usually 0
	-- alpha: the transparency level of the unit
	-- edgealpha: the amount of edge highlighting
	-- edgeexponent, the exponent of the edges
	-- animamount, the amount of top-down anim to add
	-- px, py, py: Apply an offset to the position of the unit, usually all 0
	-- rotationY: apply a rot offset, usually all 0
	-- consumerID: just a an optional tag for which widget added this garbage to this table so we can later find out who forgot to pop shit from here.
	-- returns: a unique handler ID number that you should store and call StopHighlightUnitGL4(uniqueID) with to stop drawing it
	-- note that widgets are responsible for stopping the drawing of every unit that they submit!


	if objecttype == 'unitID' then
		local unitDefID = spGetUnitDefID(objectID)
		if unitDefID== nil or unitDefIgnore[unitDefID] then
			spEcho("Warning: Unit", objectID, "with unitDefID", unitDefID,  "is explicitly disallowed in highlightUnitVBOTable from",consumerID)
			return nil
		end
	end

	uniqueID = uniqueID + 1
	local key = uniqueID
	if consumerID then
		key = tostring(objectID) .. consumerID
	end
	local staticmodel = (objecttype == "unitDefID" or objecttype == "featureDefID") and 1 or 0
	-- spEcho("HighlightUnitGL4", objecttype, objectID, staticmodel,"to uniqueID", uniqueID, r, g, b, alpha, edgealpha, edgeexponent, animamount, px, py, pz, rotationY, highlight)
	local elementID = pushElementInstance(highlightUnitVBOTable, {
			px or 0, py or 0, pz or 0, rotationY or 0,
			0, edgealpha or 0.1, edgeexponent or 2.0, animamount or 0,
			r or 1, g or 1, b or 1, alpha or 0.25,
			0,0,0,0
		},
		key, true, nil, objectID, objecttype)
	uniqueIDtoUnitID[key] = objectID
	if unitIDtoUniqueID[objectID] then
		unitIDtoUniqueID[objectID][key] = true
	else
		unitIDtoUniqueID[objectID] = {}
		unitIDtoUniqueID[objectID][key] = true
	end
	if debugmode > 0 then
		local unitdefname = "unknown unitdefname"
		if objecttype == 'unitID' then
			unitdefname = UnitDefs[spGetUnitDefID(objectID)].name
		end
		spEcho("HighlightUnitGL4", objectID, objecttype, consumerID, key, unitdefname)
	end
	return key
end

local function StopHighlightUnitGL4(uniqueID, noUpload)
	if debugmode > 0 then
		local unitdefname = "bad unitdefid"
		if uniqueIDtoUnitID[uniqueID] and spGetUnitDefID(uniqueIDtoUnitID[uniqueID]) then
			unitdefname =  UnitDefs[spGetUnitDefID(uniqueIDtoUnitID[uniqueID])].name
		end
		spEcho("StopHighlightUnitGL4", uniqueID, noUpload, 'from index',highlightUnitVBOTable.instanceIDtoIndex[uniqueID], unitdefname )

	end
	if highlightUnitVBOTable.instanceIDtoIndex[uniqueID] then
		popElementInstance(highlightUnitVBOTable, uniqueID, noUpload)
		unitID = uniqueIDtoUnitID[uniqueID]
		uniqueIDtoUnitID[uniqueID] = nil
		if unitIDtoUniqueID[unitID][uniqueID] then
			unitIDtoUniqueID[unitID][uniqueID] = nil
		else
			spEcho("Warning", uniqueID, "no longer present in highlightUnitVBOTable")
		end
	else
		return nil
		--spEcho("Unable to remove what you wanted in StopHighlightUnitGL4", uniqueID)
	end
	return uniqueID
	--Spring.("Popped element", uniqueID)
end

local function RefreshHighlightUnitGL4()
	InstanceVBOTable.uploadAllElements(highlightUnitVBOTable)
end


local TESTMODE = false

if TESTMODE then
	function widget:UnitCreated(unitID, unitDefID)
		local uniqueID = HighlightUnitGL4(unitID, "unitID", 0.0,0.25,1,    0.2, 0.5, 3.0, 0.2)

	end
	function widget:UnitDestroyed(unitID)
		StopHighlightUnitGL4(unitIDtoUniqueID[unitID])
	end
end

function widget:GameFrame(n)
	if (n%61) == 1 then
		InstanceVBOTable.validateInstanceVBOIDTable(highlightUnitVBOTable, "api validation")
	end
end

-- TODO: the api is the correct place for removal on unit


function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits) -- extVisibleUnits is a table of [unitID:unitDefID]
	-- use uniqueIDtoUnitID
	-- at this point we cant pop back any more!
	-- Ok this is really bad, as I have no guarantee that this will run first of all the resets.
	uniqueIDtoUnitID = {}
	unitIDtoUniqueID = {}
	if highlightUnitVBOTable then
		InstanceVBOTable.clearInstanceTable(highlightUnitVBOTable)
	end

	--for uniqueID, unitID in pairs(uniqueIDtoUnitID) do
		-- i am no longer nice to consumers
		--if extVisibleUnits[unitID] == nil then -- no longer visible, so we must remove the uniqueID
			--StopHighlightUnitGL4(uniqueID)
		--end
	--end
end

function widget:VisibleUnitRemoved(unitID) -- remove the corresponding ground plate if it exists
	if unitIDtoUniqueID[unitID] then
		for uniqueID, _ in pairs(unitIDtoUniqueID[unitID]) do
			StopHighlightUnitGL4(uniqueID)
		end
	end
end

function widget:Initialize()
	if not gl.CreateShader or Engine.FeatureSupport.transformsInGL4 then -- no shader support or outdated non-quaterion engine,  so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
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
	highlightUnitVBOTable = InstanceVBOTable.makeInstanceVBOTable(VBOLayout, maxElements, "highlightUnitVBOTable", unitIDAttributeIndex, "unitID")

	highlightUnitVBOTable.VAO = InstanceVBOTable.makeVAOandAttach(vertVBO, highlightUnitVBOTable.instanceVBO, indxVBO)
	highlightUnitVBOTable.indexVBO = indxVBO
	highlightUnitVBOTable.vertexVBO = vertVBO
	highlightUnitVBOTable.debugZombies = false


	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)

	highlightunitShader = LuaShader({
		vertex = vsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(highlightunitShaderConfig)),
		fragment = fsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(highlightunitShaderConfig)),
		uniformInt = {
			--tex1 = 0,
		},
		uniformFloat = {
			iconDistance = 1,
		  },
	}, "highlightUnitShader API")

	if highlightunitShader:Initialize() ~= true then
		spEcho("highlightUnitShader API shader compilation failed")
		widgetHandler:RemoveWidget()
		return
	end
	if TESTMODE then
		for i, unitID in ipairs(Spring.GetAllUnits()) do
			widget:UnitCreated(unitID)
		end
		for i, featureID in ipairs(Spring.GetAllFeatures()) do
			HighlightUnitGL4(featureID, "featureID", 0.0,0.25,1,    0.2, 0.5, 3.0, 0.0)
		end
	end
	WG['HighlightUnitGL4'] = HighlightUnitGL4
	WG['StopHighlightUnitGL4'] = StopHighlightUnitGL4
	WG['RefreshHighlightUnitGL4'] = RefreshHighlightUnitGL4
end

function widget:Shutdown()
	if highlightUnitVBOTable and highlightUnitVBOTable.VAO then
		if Spring.Utilities.IsDevMode() then
			InstanceVBOTable.dumpAndCompareInstanceData(highlightUnitVBOTable)
		end
		highlightUnitVBOTable.VAO:Delete()
	end
	if highlightunitShader then highlightunitShader:Finalize() end

	WG['HighlightUnitGL4'] = nil
	WG['StopHighlightUnitGL4'] = nil
	WG['RefreshHighlightUnitGL4'] = nil
end

function widget:TextCommand(command)
	if string.find(command, "debugapihighlightunit", nil, true) == 1 then
		local startmatch, endmatch = string.find(command, "debugapihighlightunit", nil, true)
		local param = string.sub(command, endmatch + 2,nil)
		if param and tonumber(param) then
			local newdebuglevel = tonumber(param)
			if newdebuglevel ~= debugmode then
				spEcho("Debug level for API HighLightUnit GL4 set to:", newdebuglevel)
				debugmode = newdebuglevel
			end
			highlightUnitVBOTable.debugZombies = (newdebuglevel>0)
		end

		for uniqueID, unitID in pairs(uniqueIDtoUnitID) do
			local unitdefname = "bad unitid"
			if spGetUnitDefID(unitID) then
				unitdefname =  UnitDefs[spGetUnitDefID(unitID)].name
			end
			spEcho("debugapihighlightunit", uniqueID, unitID, unitdefname, highlightUnitVBOTable.instanceIDtoIndex[uniqueID] )
		end

	end
end

local deprecationWarning = "Highlight Unit API is deprecated due to lack of quaterion support. Please use CUS GL4 unit uniform buffers instead"

function widget:DrawWorld()
	if highlightUnitVBOTable.usedElements > 0 then
		if deprecationWarning then
			spEcho(deprecationWarning)
			deprecationWarning = nil
		end
		gl.Culling(GL.BACK)
		gl.DepthMask(true)
		gl.DepthTest(true)
		gl.Blending(GL.SRC_ALPHA, GL.ONE)
		gl.PolygonOffset( -0.1 ,-0.1) -- too much here bleeds
		highlightunitShader:Activate()
		highlightunitShader:SetUniform("iconDistance",27 * Spring.GetConfigInt("UnitIconDist", 200))
		highlightUnitVBOTable.VAO:Submit()
		highlightunitShader:Deactivate()
		gl.PolygonOffset(false)
		gl.Culling(false)
	end
end
