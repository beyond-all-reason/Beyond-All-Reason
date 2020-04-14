local matTemplate = VFS.Include("ModelMaterials/Templates/defaultMaterialTemplate.lua")

local unitsNormalMapTemplate = Spring.Utilities.MergeWithDefault(matTemplate, {
	texUnits  = {
		[0] = "%%UNITDEFID:0",
		[1] = "%%UNITDEFID:1",
		[2] = "%NORMALTEX",
	},
	shaderDefinitions = {
		"#define RENDERING_MODE 0",
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
		"#define RENDERING_MODE 1",
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
	shadowOptions = {
		health_displace = true,
	},
	shaderOptions = {
		normalmapping = true,
		flashlights = true,
		vertex_ao = true,
		health_displace = true,
		health_texturing = true,
	},
	deferredOptions = {
		normalmapping = true,
		flashlights = true,
		vertex_ao = true,
		health_displace = true,
		health_texturing = true,
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
		elseif (h / mh - unitsHealth[unitID]) >= 0.005 then --consider the change of 0.5% significant. Health is increasing
			unitsHealth[unitID] = h / mh
		elseif (unitsHealth[unitID] - h / mh) >= 0.125 then --health is decreasing. Quantize by 12.5%.
			unitsHealth[unitID] = h / mh
		end
		healthArray[1] = unitsHealth[unitID]
		--Spring.Echo("SendHealthInfo", unitID, isDeferred, urSetMaterialUniform[isDeferred], healthArray[1])
		urSetMaterialUniform[isDeferred](unitID, "opaque", 3, "floatOptions[1]", GL_FLOAT, healthArray)
		if not isDeferred then
			urSetMaterialUniform[isDeferred](unitID, "shadow", 3, "floatOptions[1]", GL_FLOAT, healthArray)
		end
	end
end

local vertDisp = {} --cache
local vdArray = {[1] = 0.0}
local function SendVertDisplacement(unitID, unitDefID, isDeferred)
	-- fill cache, if empty
	if not vertDisp[unitDefID] then
		local udefCM = UnitDefs[unitDefID].customParams
		vertDisp[unitDefID] = tonumber(udefCM.scavvertdisp) or 0
		vertDisp[unitDefID] = 3.0;
	end

	if vertDisp[unitDefID] > 0 then
		vdArray[1] = vertDisp[unitDefID]
		urSetMaterialUniform[isDeferred](unitID, "opaque", 3, "floatOptions[2]", GL_FLOAT, vdArray)
		if not isDeferred then
			urSetMaterialUniform[isDeferred](unitID, "shadow", 3, "floatOptions[2]", GL_FLOAT, vdArray)
		end
	end
end

local uidArray = {[1] = 0}
local function SendUnitID(unitID, isDeferred)
	uidArray[1] = unitID
	urSetMaterialUniform[isDeferred](unitID, "opaque", 3, "intOptions[0]", GL_INT, uidArray)
	if not isDeferred then
		urSetMaterialUniform[isDeferred](unitID, "shadow", 3, "intOptions[0]", GL_INT, uidArray)
	end
end

local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitDirection = Spring.GetUnitDirection

local threadsArray = {[1] = 0.0}
local function SendTracksOffset(unitID, isDeferred, gf, mod, texSpeed, atlasSize)
	local usx, usy, usz, speed = spGetUnitVelocity(unitID)
	if speed > 0.01 then speed = 1 end

	local udx, udy, udz = spGetUnitDirection(unitID)
	if udx > 0 and usx < 0  or  udx < 0 and usx > 0  or  udz > 0 and usz < 0  or  udz < 0 and usz > 0 then
		speed = -speed
	end

	local offset = ((gf % mod) * (texSpeed / atlasSize)) * speed
	----

	if not isDeferred then
		threadsArray[1] = offset
		urSetMaterialUniform[isDeferred](unitID, "opaque", 3, "floatOptions[3]", GL_FLOAT, threadsArray)
	end
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


local function GameFrameArmTanks(gf, mat, isDeferred)
	for unitID, _ in pairs(armTanks) do
		---------------
		SendTracksOffset(unitID, isDeferred, gf, 12, 4.0, 4096.0)
		---------------
		SendHealthInfo(unitID, isDeferred)
		---------------
	end
end

local function GameFrameCoreTanks(gf, mat, isDeferred)
	for unitID, _ in pairs(coreTanks) do
		---------------
		SendTracksOffset(unitID, isDeferred, gf, 8, -8.0, 2048.0)
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
		texUnits  = {
			[3] = "%TEXW1",
			[4] = "%TEXW2",
			[5] = "%NORMALTEX2",
		},
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
		texUnits  = {
			[3] = "%TEXW1",
			[4] = "%TEXW2",
			[5] = "%NORMALTEX2",
		},
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
	unitsNormalMapOthersArmCore = Spring.Utilities.MergeWithDefault(unitsNormalMapTemplate, {
		texUnits  = {
			[3] = "%TEXW1",
			[4] = "%TEXW2",
			[5] = "%NORMALTEX2",
		},
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

--[[
local unitAtlases = {
	["arm"] = {
		"unittextures/Arm_color.dds",
		"unittextures/Arm_other.dds",
		"unittextures/Arm_normal.dds",
	},
	["cor"] = {
		"unittextures/Core_color.dds",
		"unittextures/Core_other.dds",
		"unittextures/Core_normal.dds",
	},
}
]]--

local wreckAtlases = {
	["arm"] = {
		"unittextures/Arm_wreck_color.dds",
		"unittextures/Arm_wreck_other.dds",
		"unittextures/Arm_wreck_color_normal.dds",
	},
	["cor"] = {
		"unittextures/Core_color_wreck.dds",
		"unittextures/Core_other_wreck.dds",
		"unittextures/Core_color_wreck_normal.dds",
	},
}

local blankNormal = "unittextures/blank_normal.dds"

for id = 1, #UnitDefs do
	local udef = UnitDefs[id]

	if not cusUnitMaterials[id] and udef.modeltype == "s3o" then

		local udefCM = udef.customParams
		local lm = tonumber(udefCM.lumamult) or 1
		local scvd = tonumber(udefCM.scavvertdisp) or 0

		local udefName = udef.name or ""
		local facName = string.sub(udefName, 1, 3)

		local normalTex = udefCM.normaltex or blankNormal --assume all units have normal maps

		local wreckAtlas = wreckAtlases[facName]

		if udef.modCategories["tank"] then
			if facName == "arm" then
				unitMaterials[id] = {"unitsNormalMapArmTanks", NORMALTEX = normalTex, TEXW1 = wreckAtlas[1], TEXW2 = wreckAtlas[2], NORMALTEX2 = wreckAtlas[3]}
			elseif facName == "cor" then
				unitMaterials[id] = {"unitsNormalMapCoreTanks", NORMALTEX = normalTex, TEXW1 = wreckAtlas[1], TEXW2 = wreckAtlas[2], NORMALTEX2 = wreckAtlas[3]}
			end
		else
			if wreckAtlas then
				unitMaterials[id] = {"unitsNormalMapOthersArmCore", NORMALTEX = normalTex, TEXW1 = wreckAtlas[1], TEXW2 = wreckAtlas[2], NORMALTEX2 = wreckAtlas[3]}
			else
				unitMaterials[id] = {"unitsNormalMapOthers", NORMALTEX = normalTex}
			end
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, unitMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
