local matTemplate = VFS.Include("ModelMaterials/Templates/defaultMaterialTemplate.lua")

local unitsNormalMapTemplate = Spring.Utilities.MergeWithDefault(matTemplate, {
	texUnits  = {
		[0] = "%TEX1",
		[1] = "%TEX2",
		[4] = "%NORMALTEX",
	},
	shaderDefinitions = {
		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		--"#define GAMMA 2.2",
		"#define TONEMAP(c) CustomTM(c)",
	},
	deferredDefinitions = {
		"#define SUNMULT pbrParams[6]",
		"#define EXPOSURE pbrParams[7]",

		"#define SPECULAR_AO",

		"#define ROUGHNESS_AA 1.0",

		"#define ENV_SMPL_NUM " .. tostring(Spring.GetConfigInt("ENV_SMPL_NUM", 64)),
		"#define USE_ENVIRONMENT_DIFFUSE 1",
		"#define USE_ENVIRONMENT_SPECULAR 1",

		--"#define GAMMA 2.2",
		"#define TONEMAP(c) CustomTM(c)",
	},
	shaderOptions = {
		normalmapping = true,
		flashlights = true,
		vertex_ao = true,
		health_displace = true,
	},
	deferredOptions = {
		normalmapping = true,
		flashlights = true,
		vertex_ao = true,
	},
})


----------------------------------------------

local GL_FLOAT = 0x1406
local GL_INT = 0x1404
-- args=<objID, matName, lodMatNum, uniformName, uniformType, uniformData>
local urSetMaterialUniform = {
	[false] = Spring.UnitRendering.SetForwardMaterialUniform,
	[true]  = Spring.UnitRendering.SetDeferredMaterialUniform,
}

-- args=<objID, matName, lodMatNum, uniformName>
local urClearMaterialUniform = {
	[false] = Spring.UnitRendering.ClearForwardMaterialUniform,
	[true]  = Spring.UnitRendering.ClearDeferredMaterialUniform,
}

local armTanks = {}
local coreTanks = {}
local otherUnits = {}

local spGetUnitHealth = Spring.GetUnitHealth

local unitsHealth = {} --cache
local healthArray = {[1] = 0.0}
local function SendHealthInfo(unitID, isDeferred)
	local h, mh = spGetUnitHealth(unitID, isDeferred)
	if h and mh then

		if not unitsHealth[unitID] then
			unitsHealth[unitID] = h / mh
		elseif math.abs(unitsHealth[unitID] - h / mh) >= 0.005 then --consider the change of 0.5% significant
			unitsHealth[unitID] = h / mh
		end
		healthArray[1] = unitsHealth[unitID]
		--Spring.Echo("SendHealthInfo", unitID, isDeferred, urSetMaterialUniform[isDeferred], healthArray[1])
		urSetMaterialUniform[isDeferred](unitID, "opaque", 3, "floatOptions[1]", GL_FLOAT, healthArray)
	end
end

local vertDisp = {} --cache
local vdArray = {[1] = 0.0}
local function SendVertDisplacement(unitID, unitDefID, isDeferred)
	-- fill cache, if empty
	if not vertDisp[unitDefID] then
		local udefCM = UnitDefs[unitDefID].customParams
		vertDisp[unitDefID] = tonumber(udefCM.scavvertdisp) or 0
		vertDisp[unitDefID] = 20.0;
	end

	if vertDisp[unitDefID] > 0 then
		vdArray[1] = vertDisp[unitDefID]
		urSetMaterialUniform[isDeferred](unitID, "opaque", 3, "floatOptions[2]", GL_FLOAT, vdArray)
	end
end

local uidArray = {[1] = 0}
local function SendUnitID(unitID, isDeferred)
	uidArray[1] = unitID
	urSetMaterialUniform[isDeferred](unitID, "opaque", 3, "intOptions[0]", GL_INT, uidArray)
end

local function UnitCreated(unitsList, unitID, unitDefID, mat)
	unitsList[unitID] = true
	if mat.standardShaderObj then
		SendUnitID(unitID, false)
		SendVertDisplacement(unitID, unitDefID, false)
		SendHealthInfo(unitID, false)
	end
	if mat.deferredShaderObj then
		SendUnitID(unitID, true)
		SendVertDisplacement(unitID, unitDefID, true)
		SendHealthInfo(unitID, true)
	end
end

local function UnitDestroyed(unitsList, unitID, unitDefID)
	unitsList[unitID] = nil
end

local function GameFrameSlow(unitsList, gf, mat, isDeferred)
	for unitID, _ in pairs(unitsList) do
		SendHealthInfo(unitID, isDeferred)
	end
end

local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitDirection = Spring.GetUnitDirection


local threadsArray = {[1] = 0.0}
local function GameFrameArmTanks(gf, mat, isDeferred)
	for unitID, _ in pairs(armTanks) do
		-----
		local usx, usy, usz, speed = spGetUnitVelocity(unitID)
		if speed > 0.01 then speed = 1 end

		local udx, udy, udz = spGetUnitDirection(unitID)
		if udx > 0 and usx < 0  or  udx < 0 and usx > 0  or  udz > 0 and usz < 0  or  udz < 0 and usz > 0 then
			speed = -speed
		end

		local offset = ((gf % 12) * (4.0 / 4096.0)) * speed
		----

		if isDeferred then
			threadsArray[1] = offset
			urSetMaterialUniform[false](unitID, "opaque", 3, "floatOptions[3]", GL_FLOAT, threadsArray)
		end
		---------------
		SendHealthInfo(unitID, isDeferred)
		---------------
	end
end

local function GameFrameCoreTanks(gf, mat, isDeferred)
	for unitID, _ in pairs(coreTanks) do
		-----
		local usx, usy, usz, speed = spGetUnitVelocity(unitID)
		if speed > 0.01 then speed = 1 end

		local udx, udy, udz = spGetUnitDirection(unitID)
		if udx > 0 and usx < 0  or  udx < 0 and usx > 0  or  udz > 0 and usz < 0  or  udz < 0 and usz > 0 then
			speed = -speed
		end

		local offset = ((gf % 8) * (8.0 / 2048.0)) * speed
		----

		if isDeferred then
			threadsArray[1] = -offset
			urSetMaterialUniform[false](unitID, "opaque", 3, "floatOptions[3]", GL_FLOAT, threadsArray)
		end
		---------------
		SendHealthInfo(unitID, isDeferred)
		---------------
	end
end

local function GameFrameOtherUnits(gf, mat, isDeferred)
	for unitID, _ in pairs(otherUnits) do
		SendHealthInfo(unitID, isDeferred)
	end
end

local function UnitDamaged(unitID, unitDefID, mat, isDeferred)
	SendHealthInfo(unitID, isDeferred)
end

---------------------------------------------------


local materials = {
	unitsNormalMapArmTanks = Spring.Utilities.MergeWithDefault(unitsNormalMapTemplate, {
		shaderOptions = {
			threads_arm = true,
		},
		deferredOptions = {
			materialIndex = 1,
		},
		UnitCreated = function (unitID, unitDefID, mat) UnitCreated(armTanks, unitID, unitDefID, mat) end,
		UnitDestroyed = function (unitID, unitDefID) UnitDestroyed(armTanks, unitID, unitDefID) end,

		GameFrame = GameFrameArmTanks,
		--GameFrameSlow = function (gf, mat, isDeferred) GameFrameSlow(otherUnits, gf, mat, isDeferred) end,

		UnitDamaged = UnitDamaged,
	}),
	unitsNormalMapCoreTanks = Spring.Utilities.MergeWithDefault(unitsNormalMapTemplate, {
		shaderOptions = {
			threads_core = true,
		},
		deferredOptions = {
			materialIndex = 2,
		},
		UnitCreated = function (unitID, unitDefID, mat) UnitCreated(coreTanks, unitID, unitDefID, mat) end,
		UnitDestroyed = function (unitID, unitDefID) UnitDestroyed(coreTanks, unitID, unitDefID) end,

		GameFrame = GameFrameCoreTanks,
		--GameFrameSlow = function (gf, mat, isDeferred) GameFrameSlow(otherUnits, gf, mat, isDeferred) end,

		UnitDamaged = UnitDamaged,
	}),
	unitsNormalMapOthers = Spring.Utilities.MergeWithDefault(unitsNormalMapTemplate, {
		shaderOptions = {
		},
		deferredOptions = {
			materialIndex = 3,
		},
		UnitCreated = function (unitID, unitDefID, mat) UnitCreated(otherUnits, unitID, unitDefID, mat) end,
		UnitDestroyed = function (unitID, unitDefID) UnitDestroyed(otherUnits, unitID, unitDefID) end,

		GameFrame = GameFrameOtherUnits,
		--GameFrameSlow = function (gf, mat, isDeferred) GameFrameSlow(otherUnits, gf, mat, isDeferred) end,

		UnitDamaged = UnitDamaged,
	}),
}


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local cusUnitMaterials = GG.CUS.unitMaterialDefs
local unitMaterials = {}

for id = 1, #UnitDefs do
	local udef = UnitDefs[id]

	if not cusUnitMaterials[id] and udef.modeltype == "s3o" then
		local udefCM = udef.customParams
		local lm = tonumber(udefCM.lumamult) or 1
		local scvd = tonumber(udefCM.scavvertdisp) or 0

		local tex1 = "%%"..id..":0"
		local tex2 = "%%"..id..":1"
		local normalTex = udefCM.normaltex

		if udef.modCategories["tank"] then
			local facName = string.sub(udef.name, 1, 3)
			if facName == "arm" then
				unitMaterials[id] = {"unitsNormalMapArmTanks", TEX1 = tex1, TEX2 = tex2, NORMALTEX = normalTex}
			elseif facName == "cor" then
				unitMaterials[id] = {"unitsNormalMapCoreTanks", TEX1 = tex1, TEX2 = tex2, NORMALTEX = normalTex}
			end
		else
			unitMaterials[id] = {"unitsNormalMapOthers", TEX1 = tex1, TEX2 = tex2, NORMALTEX = normalTex}
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, unitMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
