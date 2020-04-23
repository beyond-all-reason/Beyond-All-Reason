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
local unitDefSide = {} -- 1 - arm, 2 - core, 0 - hell know what
local function SendHealthInfo(unitID, unitDefID, isDeferred)
	local h, mh = spGetUnitHealth(unitID)
	if h and mh then

		h = math.max(h, 0)
		mh = math.max(mh, 0.01)

		if not unitDefSide[unitDefID] then
			local facName = string.sub(UnitDefs[unitDefID].name, 1, 3)
			if facName == "arm" then
				unitDefSide[unitDefID] = 1
			elseif facname == "cor" then
				unitDefSide[unitDefID] = 2
			else
				unitDefSide[unitDefID] = 0
			end
		end

		if not unitsHealth[unitID] then
			unitsHealth[unitID] = h / mh
		elseif (h / mh - unitsHealth[unitID]) >= 0.005 then --consider the change of 0.5% significant. Health is increasing
			unitsHealth[unitID] = h / mh
		elseif (unitsHealth[unitID] - h / mh) >= 0.0625 then --health is decreasing. Quantize by 6.25%.
			unitsHealth[unitID] = h / mh
		end

		local healthMixMult = 0.80
		-- if unitDefSide[unitDefID] == 1 then --arm
		-- 	healthMixMult = 0.90
		-- elseif unitDefSide[unitDefID] == 2 then --core
		-- 	healthMixMult = 0.90
		-- end

		healthArray[1] = healthMixMult * (1.0 - unitsHealth[unitID]) --invert so it can be used as mix() easier
		--Spring.Echo("SendHealthInfo", unitID, isDeferred, urSetMaterialUniform[isDeferred], healthArray[1])
		urSetMaterialUniform[isDeferred](unitID, "opaque", 3, "floatOptions[0]", GL_FLOAT, healthArray)
		if not isDeferred then
			urSetMaterialUniform[isDeferred](unitID, "shadow", 3, "floatOptions[0]", GL_FLOAT, healthArray)
		end
	end
end

local healthMod = {} --cache
local vertDisp = {} --cache
local vdhmArray = {[1] = 0.0, [2] = 0.0}
local function SendVertDispAndHelthMod(unitID, unitDefID, isDeferred)
	-- fill caches, if empty
	if not healthMod[unitDefID] then
		local udefCM = UnitDefs[unitDefID].customParams
		healthMod[unitDefID] = tonumber(udefCM.healthlookmod) or 0
	end

	if not vertDisp[unitDefID] then
		local udefCM = UnitDefs[unitDefID].customParams
		vertDisp[unitDefID] = tonumber(udefCM.vertdisp) or 0
	end

	if vertDisp[unitDefID] > 0 or healthMod[unitDefID] > 0 then
		vdhmArray[1] = healthMod[unitDefID]
		vdhmArray[2] = vertDisp[unitDefID]
		urSetMaterialUniform[isDeferred](unitID, "opaque", 3, "floatOptions[1]", GL_FLOAT, vdhmArray)
		if not isDeferred then
			urSetMaterialUniform[isDeferred](unitID, "shadow", 3, "floatOptions[1]", GL_FLOAT, vdhmArray)
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

local threadSpeeds = {} --cache
local threadsArray = {[1] = 0.0}
local function SendTracksOffset(unitID, isDeferred)
	if not threadSpeeds[unitID] then
		threadSpeeds[unitID] = 0.0
	end

	local usx, usy, usz, speed = spGetUnitVelocity(unitID)
	if speed > 0.05 then speed = 1 else speed = 0 end

	local udx, udy, udz = spGetUnitDirection(unitID)
	if udx > 0 and usx < 0  or  udx < 0 and usx > 0  or  udz > 0 and usz < 0  or  udz < 0 and usz > 0 then
		speed = -speed
	end

	if threadSpeeds[unitID] ~= speed and not isDeferred then
		threadSpeeds[unitID] = speed
		threadsArray[1] = speed
		urSetMaterialUniform[isDeferred](unitID, "opaque", 3, "floatOptions[3]", GL_FLOAT, threadsArray)
	end
end

local function UnitCreated(unitsList, unitID, unitDefID, mat)
	unitsList[unitID] = unitDefID
	if mat.standardShaderObj then
		SendUnitID(unitID, false)
		SendVertDispAndHelthMod(unitID, unitDefID, false)
		SendHealthInfo(unitID, unitDefID, false)
	end
	if mat.deferredShaderObj then
		SendUnitID(unitID, true)
		SendVertDispAndHelthMod(unitID, unitDefID, true)
		SendHealthInfo(unitID, unitDefID, true)
	end
end

local function UnitDestroyed(unitsList, unitID, unitDefID)
	unitsList[unitID] = nil
end

local function GameFrame(isTank, unitsList, gf, mat, isDeferred)
	local gfRem = gf % 10
	for unitID, unitDefID in pairs(unitsList) do
		if gfRem == unitID % 10 then
			if isTank then
				SendTracksOffset(unitID, isDeferred)
			end
			SendHealthInfo(unitID, unitDefID, isDeferred)
		end
	end
end

local function UnitDamaged(unitID, unitDefID, mat, isDeferred)
	SendHealthInfo(unitID, unitDefID, isDeferred)
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

		GameFrame = function (gf, mat, isDeferred) GameFrame(true, armTanks, gf, mat, isDeferred) end,

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

		GameFrame = function (gf, mat, isDeferred) GameFrame(true, coreTanks, gf, mat, isDeferred) end,

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

		GameFrame = function (gf, mat, isDeferred) GameFrame(false, otherUnits, gf, mat, isDeferred) end,

		UnitDamaged = UnitDamaged,
	}),
	unitsNormalMapOthers = Spring.Utilities.MergeWithDefault(unitsNormalMapTemplate, {
		shaderOptions = {
		},
		deferredOptions = {
			materialIndex = 3,
		},

		-- are these below required?
		UnitCreated = function (unitID, unitDefID, mat) UnitCreated(otherUnits, unitID, unitDefID, mat) end,
		UnitDestroyed = function (unitID, unitDefID) UnitDestroyed(otherUnits, unitID, unitDefID) end,

		GameFrame = function (gf, mat, isDeferred) GameFrame(false, otherUnits, gf, mat, isDeferred) end,

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
