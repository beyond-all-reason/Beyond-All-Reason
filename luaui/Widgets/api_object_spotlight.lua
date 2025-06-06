local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Object Spotlight API",
		desc = "Shows a vertical spotlight on units, features, or positions",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
		depends = { "gl4" },
	}
end

-- configuration
-- =============

local DEFAULT_CYLINDER_HEIGHT = 350
local DEFAULT_RADIUS = 100
local CYLINDER_SECTIONS = 32
local REMOVE_EXPIRED_SPOTLIGHTS_PERIOD = 1

local spotlightTypes = {
	unit = {
		getDefaultRadius = function(unitID)
			if not unitID then
				return nil
			end
			local unitDefID = Spring.GetUnitDefID(unitID)
			if not unitDefID then
				return nil
			end
			return UnitDefs[unitDefID].radius
		end,
		isValid = function(unitID)
			return Spring.ValidUnitID(unitID)
		end,
	},
	feature = {
		getDefaultRadius = function(featureID)
			return FeatureDefs[Spring.GetFeatureDefID(featureID)].radius
		end,
		isValid = function(featureID)
			return Spring.ValidFeatureID(featureID)
		end,
		postProcessVBO = function(vbo)
			vbo.featureIDs = true
		end,
	},
	ground = {
		getDefaultRadius = function(position)
			return 100
		end,
		isValid = function(position)
			return true
		end,
		postProcessVBO = function(vbo)
		end,
	},
}

-- GL4
-- ===

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable
local popElementInstance = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

---@language Glsl
local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000

//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec3 localPos;

layout (location = 1) in float radius;
layout (location = 2) in float height;
layout (location = 3) in vec4 color;
layout (location = 4) in float startTime;
layout (location = 5) in float expireTime;
layout (location = 6) in uvec4 instData;
layout (location = 7) in vec3 worldPosOverride;

out DataVS {
	vec4 color;
	vec3 localPos;
	float unitID;
	float cameraDistance;
	float lifetimeElapsed;
} outputVars;

uint SO_NODRAW_FLAG = 0;
uint SO_OPAQUE_FLAG = 1;
uint SO_ALPHAF_FLAG = 2;
uint SO_REFLEC_FLAG = 4;
uint SO_REFRAC_FLAG = 8;
uint SO_SHOPAQ_FLAG = 16;
uint SO_SHTRAN_FLAG = 32;
uint SO_DRICON_FLAG = 128;

bool hasDrawFlag(uint drawFlag, uint flag) {
	return (drawFlag & flag) == flag;
}

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

#line 15000
void main() {
	vec3 worldPos = uni[instData.y].drawPos.xyz;

	if (worldPosOverride.x != 0 && worldPosOverride.y != 0  && worldPosOverride.z != 0) {
		worldPos = worldPosOverride;
	}

	float cameraDistance = length(worldPos.xyz - cameraViewInv[3].xyz);

	float effectiveHeight = height * clamp(cameraDistance / 4500, 1.0, 2.5);

	vec2 resultPosXZ = localPos.xz * radius + worldPos.xz;
	vec3 resultPos = vec3(resultPosXZ.x, worldPos.y + localPos.y * effectiveHeight, resultPosXZ.y);

	gl_Position = cameraViewProj * vec4(resultPos, 1.0);

	outputVars.color = color;
	outputVars.localPos = localPos;
	outputVars.unitID = instData.y;
	outputVars.cameraDistance = cameraDistance;

	if (startTime != 0 && expireTime != 0 && startTime != expireTime) {
		// percent of lifetime that has passed so far
		outputVars.lifetimeElapsed = clamp((timeInfo.y - startTime) / (expireTime - startTime), 0.0, 1.0);
	} else {
		outputVars.lifetimeElapsed = 0;
	}
}
]]

---@language Glsl
local fsSrc = [[
#version 420
#line 20000

//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	vec4 color;
	vec3 localPos;
	float unitID;
	float cameraDistance;
	float lifetimeElapsed;
} inputVars;

out vec4 outputColor;

float noise(vec3 pos, float time) {
    float flicker = sin(time * 3.0 + pos.y * 2.0 + cos(pos.x * 4.0 + pos.z * 3.0)) * 0.5;
    float wave1 = sin(time * 2.0 + pos.x * 3.0 + pos.z * 2.0) * 0.5;
    float wave2 = cos(time * 1.5 + pos.y * 2.5 - pos.z * 3.5) * 0.3;
    return flicker + wave1 + wave2;
}

vec3 transformRGB(vec3 c, float v) {
	if (v > 0) {
		return mix(c, vec3(1.0), v);
	} else {
		return mix(c, vec3(0.0), abs(v));
	}
}

#line 25000
void main() {
	float effectiveY = inputVars.localPos.y;
	if (effectiveY < 0) {
		// spotlights below the object fade closer
		effectiveY = clamp(abs(effectiveY) * 4, 0.0, 1.0);
	}
	float t = 0.25 * timeInfo.y;
	float v1 = clamp(0.05 * noise(inputVars.localPos, t), -0.25, 0.25);
	float v2 = clamp(0.5 * noise(inputVars.localPos, t * 2), -0.5, 0.5);

	outputColor.rgba = vec4(
		transformRGB(inputVars.color.rgb, v1),
		inputVars.color.a
		 * (1 + v2)
		 * pow(1 - effectiveY, 4) // more opacity near the unit
		 * clamp(inputVars.cameraDistance / 4500, 0.1, 1.1) // more opacity viewing from far away
		 * pow(1 - inputVars.lifetimeElapsed, 1) // less opacity as it gets closer to expiring
	);
}
]]

local shader = nil

local spotlightVBOLayout = {
	{ id = 0, name = "localPos", size = 3 },
}

local instanceVBOs = nil
local instanceVBOLayout = {
	{ id = 1, name = "radius", size = 1 },
	{ id = 2, name = "height", size = 1 },
	{ id = 3, name = "color", size = 4 },
	{ id = 4, name = "startTime", size = 1 },
	{ id = 5, name = "expireTime", size = 1 },
	{ id = 6, name = "instData", size = 4, type = GL.UNSIGNED_INT },
	{ id = 7, name = "worldPosOverride", size = 3 },
}

local function makeCylinderVBO(sections)
	local vbo = gl.GetVBO(GL.ARRAY_BUFFER, true)

	local vboData = {}

	for i = 0, sections do
		local theta = 2 * math.pi * i / sections
		local x = math.cos(theta)
		local z = math.sin(theta)

		vboData[#vboData + 1] = x
		vboData[#vboData + 1] = -1
		vboData[#vboData + 1] = z

		vboData[#vboData + 1] = x
		vboData[#vboData + 1] = 1
		vboData[#vboData + 1] = z
	end

	local numVertices = #vboData / 3

	vbo:Define(
		numVertices,
		spotlightVBOLayout
	)
	vbo:Upload(vboData)

	return vbo, numVertices
end

local function makeInstanceVBO(layout, vertexVBO, numVertices, name)
	local vbo = InstanceVBOTable.makeInstanceVBOTable(
		layout,
		nil,
		name,
		6
	)
	vbo.vertexVBO = vertexVBO
	vbo.numVertices = numVertices
	vbo.VAO = InstanceVBOTable.makeVAOandAttach(vbo.vertexVBO, vbo.instanceVBO)
	return vbo
end

local function initGL4()
	local cylinderVBO, cylinderVertices = makeCylinderVBO(CYLINDER_SECTIONS)

	instanceVBOs = {}
	for spotlightType, spec in pairs(spotlightTypes) do
		local vbo = makeInstanceVBO(
			instanceVBOLayout,
			cylinderVBO,
			cylinderVertices,
			"api_object_spotlight_" .. spotlightType
		)

		if spec.postProcessVBO then
			spec.postProcessVBO(vbo)
		end

		instanceVBOs[spotlightType] = vbo
	end

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	shader = LuaShader(
		{
			vertex = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
			fragment = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs),
		},
		"api_object_spotlight"
	)
	local shaderCompiled = shader:Initialize()
	return shaderCompiled
end

-- widget code
-- ===========

---@alias ObjectType string
---@alias ObjectID number|number[]
---@alias OwnerID string
---@alias InstanceID number

---@type table<ObjectType, table<ObjectID, table<OwnerID, InstanceID>>>
local objectInstanceIDs = {}

---@type table<ObjectType, table<ObjectID, table<OwnerID, boolean>>>
local objectOwners = {}

---@type table<ObjectType, table<ObjectID, table<OwnerID, number>>>
local objectExpireTimes = {}

for k in pairs(spotlightTypes) do
	objectInstanceIDs[k] = {}
	objectExpireTimes[k] = {}
	objectOwners[k] = {}
end

local function isEmpty(tbl)
	for _ in pairs(tbl) do
		return false
	end
	return true
end

local function addSpotlight(objectType, owner, objectID, color, options)
	if not spotlightTypes[objectType] then
		error("invalid spotlight target type: " .. (objectType or "<nil>"))
	end

	if not spotlightTypes[objectType].isValid(objectID) then
		Spring.Echo("invalid spotlight object id: " .. (objectID or "<nil>"))
		return
	end

	options = options or {}

	-- radius
	local radius = (options.radiusCoefficient or 1) *
		(options.radius or spotlightTypes[objectType].getDefaultRadius(objectID) or DEFAULT_RADIUS)

	-- height
	local height = (options.heightCoefficient or 1) * (options.height or DEFAULT_CYLINDER_HEIGHT)

	-- duration
	local startTime
	local expireTime
	if options.duration ~= nil then
		startTime = Spring.GetDrawSeconds()
		expireTime = startTime + options.duration
	end

	if not objectExpireTimes[objectType][objectID] then
		objectExpireTimes[objectType][objectID] = {}
	end
	objectExpireTimes[objectType][objectID][owner] = expireTime

	-- owner
	if not objectOwners[objectType][objectID] then
		objectOwners[objectType][objectID] = {}
	end
	objectOwners[objectType][objectID][owner] = true

	local instanceObjectID
	local instanceWorldPosOverride

	if objectType == "ground" then
		instanceObjectID = nil
		instanceWorldPosOverride = objectID
	else
		instanceObjectID = objectID
		instanceWorldPosOverride = { 0, 0, 0 }
	end

	-- instance
	if not objectInstanceIDs[objectType][objectID] then
		objectInstanceIDs[objectType][objectID] = {}
	end
	objectInstanceIDs[objectType][objectID][owner] = pushElementInstance(
		instanceVBOs[objectType],
		{
			radius, -- { id = 1, name = "radius", size = 1 }
			height, -- { id = 2, name = "height", size = 1 }
			color[1], color[2], color[3], color[4], -- { id = 3, name = "color", size = 4 }
			startTime or 0, -- { id = 4, name = "startTime", size = 1 },
			expireTime or 0, -- { id = 5, name = "expireTime", size = 1 },
			0, 0, 0, 0, -- { id = 6, name = "instData", size = 4, type = GL.UNSIGNED_INT }
			instanceWorldPosOverride[1], instanceWorldPosOverride[2], instanceWorldPosOverride[3], -- { id = 7, name = "worldPosOverride", size = 3 },
		},
		objectInstanceIDs[objectType][objectID][owner],
		true,
		false,
		instanceObjectID
	)
end

local function removeSpotlight(objectType, owner, objectID)
	if not spotlightTypes[objectType] then
		error("invalid spotlight target type: " .. (objectType or "<nil>"))
	end

	if not objectInstanceIDs[objectType][objectID] or not objectInstanceIDs[objectType][objectID][owner] then
		return
	end

	-- owner
	objectOwners[objectType][objectID][owner] = nil
	if isEmpty(objectOwners[objectType][objectID]) then
		objectOwners[objectType][objectID] = nil
	end

	-- instance
	if instanceVBOs[objectType].instanceIDtoIndex[objectInstanceIDs[objectType][objectID][owner]] then
		popElementInstance(instanceVBOs[objectType], objectInstanceIDs[objectType][objectID][owner], false)
	end
	objectInstanceIDs[objectType][objectID][owner] = nil
	if isEmpty(objectInstanceIDs[objectType][objectID]) then
		objectInstanceIDs[objectType][objectID] = nil
	end

	-- duration
	if objectExpireTimes[objectType][objectID] and objectExpireTimes[objectType][objectID][owner] then
		objectExpireTimes[objectType][objectID][owner] = nil
		if isEmpty(objectExpireTimes[objectType][objectID]) then
			objectExpireTimes[objectType][objectID] = nil
		end
	end
end

local function getSpotlights(objectType, owner)
	return table.reduce(
		objectOwners[objectType],
		function(acc, v, k)
			if v[owner] then
				acc[#acc + 1] = k
			end
			return acc
		end,
		{}
	)
end

local function removeAllSpotlights(owner)
	for objectType in pairs(spotlightTypes) do
		for _, id in ipairs(getSpotlights(objectType, owner)) do
			removeSpotlight(
				objectType,
				owner,
				id
			)
		end
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if objectOwners["unit"][unitID] then
		for owner in pairs(objectOwners["unit"][unitID]) do
			removeSpotlight("unit", owner, unitID)
		end
	end
end

function widget:FeatureDestroyed(featureID, allyTeamID)
	if objectOwners["feature"][featureID] then
		for owner in pairs(objectOwners["feature"][featureID]) do
			removeSpotlight("feature", owner, featureID)
		end
	end
end

local t = 0
function widget:Update(dt)
	t = t + dt
	if t < REMOVE_EXPIRED_SPOTLIGHTS_PERIOD then
		return
	end
	t = 0

	-- remove expired spotlights
	local toRemove = {}
	local gs = Spring.GetDrawSeconds()
	for objectType, objectOwnerTimes in pairs(objectExpireTimes) do
		for objectID, ownerTimes in pairs(objectOwnerTimes) do
			for owner, expireTime in pairs(ownerTimes) do
				if gs > expireTime then
					table.insert(toRemove, { objectType, owner, objectID })
				end
			end
		end
	end

	for _, removeParams in ipairs(toRemove) do
		removeSpotlight(unpack(removeParams))
	end
end

function widget:DrawWorld()
	if Spring.IsGUIHidden() then
		return
	end

	gl.DepthTest(GL.LEQUAL)

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	shader:Activate()

	for spotlightType, vbo in pairs(instanceVBOs) do
		if vbo.usedElements > 0 then
			vbo.VAO:DrawArrays(
				GL.TRIANGLE_STRIP,
				vbo.numVertices,
				0,
				vbo.usedElements,
				0
			)
		end
	end

	shader:Deactivate()
end

function widget:Initialize()
	if not initGL4() then
		widgetHandler:RemoveWidget()
		return
	end

	WG["ObjectSpotlight"] = {
		---Adds a new spotlight for a given object. Only one call is needed to create the spotlight (the position is handled in
		---the shader), but this can be called again to update extra options. Unless a duration is provided, calling
		---removeSpotlight later is necessary to remove the spotlight.
		---@param objectType string "unit", "feature", or "ground"
		---@param owner string An identifier used to prevent name collisions. You can have one spotlight per objectID per owner.
		---@param objectID number|number[] unitID, featureID, or {x,y,z} table for a location
		---@param color table RGBA color used for the spotlight
		---@param options table extra optional parameters
		---@param options.duration number if specified, the spotlight will fade out over this period of seconds
		---@param options.radius number override the radius (default: the radius of the object, or 100 if that's not present)
		---@param options.radiusCoefficient number multiplicative factor for the radius (default: 1)
		---@param options.height number override the height (default: 300)
		---@param options.heightCoefficient number multiplicative factor for the height (default: 1)
		---@return nil
		addSpotlight = addSpotlight,

		---Removes the spotlight for a given object. This can be called even if a spotlight might not be present.
		---@param objectType string "unit" or "feature", or "ground"
		---@param owner string An identifier used to prevent name collisions. You can have one spotlight per objectID per owner.
		---@param objectID number|number[] unitID, featureID, or {x,y,z} table for a location
		---@return nil
		removeSpotlight = removeSpotlight,

		---Returns the objectID for all spotlights with the specified type and owner.
		---@param objectType string "unit" or "feature", or "ground"
		---@param owner string An identifier used to prevent name collisions. You can have one spotlight per objectID per owner.
		---@return (number|number[])[]
		getSpotlights = getSpotlights,

		---Removes all spotlights with the specified owner.
		---@param owner string An identifier used to prevent name collisions. You can have one spotlight per objectID per owner.
		---@return nil
		removeAllSpotlights = removeAllSpotlights,
	}
end

function widget:Shutdown()
	for _, vbo in pairs(instanceVBOs) do
		if vbo and vbo.VAO then
			vbo.VAO:Delete()
		end
	end

	if shader then
		shader:Finalize()
	end

	WG["ObjectSpotlight"] = nil
end
