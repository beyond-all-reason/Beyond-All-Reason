local matTemplate = VFS.Include("ModelMaterials/Templates/defaultMaterialTemplate.lua")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GL_FLOAT = 0x1406
local GL_INT = 0x1404
-- args=<objID, matName, lodMatNum, uniformName, uniformType, uniformData>
local frSetMaterialUniform = {
	[false] = Spring.FeatureRendering.SetForwardMaterialUniform,
	[true]  = Spring.FeatureRendering.SetDeferredMaterialUniform,
}

-- args=<objID, matName, lodMatNum, uniformName>
local frClearMaterialUniform = {
	[false] = Spring.FeatureRendering.ClearForwardMaterialUniform,
	[true]  = Spring.FeatureRendering.ClearDeferredMaterialUniform,
}

----------------------------------------------

local spGetFeatureHealth = Spring.GetFeatureHealth

local featuresHealth = {} --cache
local healthArray = {[1] = 0.0}
local featureDefSide = {} -- 1 - arm, 2 - core, 0 - hell know what
local function SendHealthInfo(featureID, featureDefID, isDeferred)
	local h, mh = spGetFeatureHealth(featureID)
	if h and mh then

		h = math.max(h, 0)
		mh = math.max(mh, 0.01)

		if not featureDefSide[featureDefID] then
			local facName = string.sub(FeatureDefs[featureDefID].name, 1, 3)
			if facName == "arm" then
				featureDefSide[featureDefID] = 1
			elseif facname == "cor" then
				featureDefSide[featureDefID] = 2
			else
				featureDefSide[featureDefID] = 0
			end
		end

		if not featuresHealth[featureID] then
			featuresHealth[featureID] = h / mh
		elseif (h / mh - featuresHealth[featureID]) >= 0.005 then --consider the change of 0.5% significant. Health is increasing
			featuresHealth[featureID] = h / mh
		elseif (featuresHealth[featureID] - h / mh) >= 0.0625 then --health is decreasing. Quantize by 6.25%.
			featuresHealth[featureID] = h / mh
		end

		local healthMixMult = 0.80
		-- if featureDefSide[featureDefID] == 1 then --arm
		-- 	healthMixMult = 0.90
		-- elseif featureDefSide[featureDefID] == 2 then --core
		-- 	healthMixMult = 0.90
		-- end

		healthArray[1] = healthMixMult * (1.0 - featuresHealth[featureID]) --invert so it can be used as mix() easier
		--healthArray[1] = 1.0;
		--Spring.Echo("SendHealthInfo", featureID, isDeferred, frSetMaterialUniform[isDeferred], healthArray[1])
		frSetMaterialUniform[isDeferred](featureID, "opaque", 3, "floatOptions[0]", GL_FLOAT, healthArray)
		if not isDeferred then
			frSetMaterialUniform[isDeferred](featureID, "shadow", 3, "floatOptions[0]", GL_FLOAT, healthArray)
		end
	end
end

local healthMod = {} --cache
local vertDisp = {} --cache
local vdhmArray = {[1] = 0.0, [2] = 0.0}
local function SendVertDispAndHelthMod(featureID, featureDefID, isDeferred)
	-- fill caches, if empty
	if not healthMod[featureDefID] then
		local fdefCM = FeatureDefs[featureDefID].customParams
		healthMod[featureDefID] = tonumber(fdefCM.healthlookmod) or 0
	end

	if not vertDisp[featureDefID] then
		local fdefCM = FeatureDefs[featureDefID].customParams
		vertDisp[featureDefID] = tonumber(fdefCM.vertdisp) or 10
	end

	if vertDisp[featureDefID] > 0 or healthMod[featureDefID] > 0 then
		vdhmArray[1] = healthMod[featureDefID]
		vdhmArray[2] = vertDisp[featureDefID]
		frSetMaterialUniform[isDeferred](featureID, "opaque", 3, "floatOptions[1]", GL_FLOAT, vdhmArray)
		if not isDeferred then
			frSetMaterialUniform[isDeferred](featureID, "shadow", 3, "floatOptions[1]", GL_FLOAT, vdhmArray)
		end
	end
end

local fidArray = {[1] = 0}
local function SendFeatureID(featureID, isDeferred)
	fidArray[1] = featureID
	frSetMaterialUniform[isDeferred](featureID, "opaque", 3, "intOptions[0]", GL_INT, fidArray)
	if not isDeferred then
		frSetMaterialUniform[isDeferred](featureID, "shadow", 3, "intOptions[0]", GL_INT, fidArray)
	end
end

local featuresList = {}
local function FeatureCreated(featureID, featureDefID, mat)
	featuresList[featureID] = featureDefID
	if mat.standardShaderObj then
		SendFeatureID(featureID, false)
		SendVertDispAndHelthMod(featureID, featureDefID, false)
		SendHealthInfo(featureID, featureDefID, false)
	end
	if mat.deferredShaderObj then
		SendFeatureID(featureID, true)
		SendVertDispAndHelthMod(featureID, featureDefID, true)
		SendHealthInfo(featureID, featureDefID, true)
	end
end

local function FeatureDestroyed(featureID, featureDefID)
	featuresList[featureID] = nil
end

local function GameFrameSlow(gf, mat, isDeferred)
	for featureID, featureDefID in pairs(featuresList) do
		SendHealthInfo(featureID, featureDefID, isDeferred)
	end
end

local function FeatureDamaged(featureID, featureDefID, mat, isDeferred)
	SendHealthInfo(featureID, featureDefID, isDeferred)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local featureTreeTemplate = Spring.Utilities.MergeWithDefault(matTemplate, {
	texUnits  = {
		[0] = "%%FEATUREDEFID:0",
		[1] = "%%FEATUREDEFID:1",
	},
	feature = true,
	shaderDefinitions = {
		"#define RENDERING_MODE 0",
		"#define USE_LOSMAP",

		"#define SUNMULT 1.5",
		--"#define EXPOSURE 1.0",

		"#define METALNESS 0.1",
		"#define ROUGHNESS 0.8",
		"#define EMISSIVENESS 0.0",

		--"#define USE_ENVIRONMENT_DIFFUSE",
		--"#define USE_ENVIRONMENT_SPECULAR",

		--"#define GAMMA 2.2",
		--"#define TONEMAP(c) ACESFilmicTM(c)",
	},
	deferredDefinitions = {
		"#define RENDERING_MODE 1",
		"#define USE_LOSMAP",

		"#define SUNMULT 1.5",
		--"#define EXPOSURE 1.0",

		"#define METALNESS 0.1",
		"#define ROUGHNESS 0.8",
		"#define EMISSIVENESS 0.0",

		--"#define USE_ENVIRONMENT_DIFFUSE",
		--"#define USE_ENVIRONMENT_SPECULAR",

		--"#define GAMMA 2.2",
		--"#define TONEMAP(c) SteveMTM1(c)",
	},
	shaderOptions = {
		treewind = true,
	},
	deferredOptions = {
		treewind = true,
	},
	shadowOptions = {
		treewind = true,
	},
})

local featuresMetalTemplate = Spring.Utilities.MergeWithDefault(matTemplate, {
	texUnits  = {
		[0] = "%%FEATUREDEFID:0",
		[1] = "%%FEATUREDEFID:1",
	},
	feature = true,
	shaderDefinitions = {
		"#define RENDERING_MODE 0",
		"#define SUNMULT 1.0",
		--"#define EXPOSURE 1.0",

		"#define METALNESS 0.2",
		"#define ROUGHNESS 0.6",

		--"#define USE_ENVIRONMENT_DIFFUSE",
		--"#define USE_ENVIRONMENT_SPECULAR",

		--"#define GAMMA 2.2",
		--"#define TONEMAP(c) SteveMTM1(c)",
	},
	deferredDefinitions = {
		"#define RENDERING_MODE 1",
		"#define SUNMULT 1.0",
		--"#define EXPOSURE 1.0",

		"#define METALNESS 0.2",
		"#define ROUGHNESS 0.6",

		--"#define USE_ENVIRONMENT_DIFFUSE",
		--"#define USE_ENVIRONMENT_SPECULAR",

		--"#define GAMMA 2.2",
		--"#define TONEMAP(c) SteveMTM1(c)",
	},
	--Initialize	= Initialize,
	--Finalize	= Finalize,
	--GameFrameSlow = GameFrameSlow,
})

local materials = {
	featuresTreeFakeNormal = Spring.Utilities.MergeWithDefault(featureTreeTemplate, {
		texUnits  = {
			[2] = "%NORMALTEX",
		},
		shaderOptions = {
			normalmapping = true,
		},
		deferredOptions = {
			normalmapping = true,
			materialIndex = 128,
		},
	}),

	featuresTreeAutoNormal = Spring.Utilities.MergeWithDefault(featureTreeTemplate, {
		shaderOptions = {
			autonormal = true,
			autoNormalParams = {1.5, 0.005},
		},
		deferredOptions = {
			materialIndex = 129,
		},
	}),

	featuresTreeAutoNormalNoSway = Spring.Utilities.MergeWithDefault(featureTreeTemplate, {
		shaderOptions = {
			treewind = false,
			autonormal = true,
			autoNormalParams = {1.5, 0.005},
		},
		deferredOptions = {
			treewind = false,
			materialIndex = 130,
		},
		shadowOptions = {
			treewind = false,
		},
	}),

	featuresMetalDeadOrHeap = Spring.Utilities.MergeWithDefault(featuresMetalTemplate, {
		texUnits  = {
			[2] = "%NORMALTEX",
		},
		shaderOptions = {
			normalmapping = true,
			health_displace = true,
		},
		deferredOptions = {
			materialIndex = 131,
			health_displace = true,
		},
		FeatureCreated = FeatureCreated,
		FeatureDestroyed = FeatureDestroyed,
		FeatureDamaged = FeatureDamaged,
		GameFrameSlow = GameFrameSlow,
	}),

	featuresMetalNoWreck = Spring.Utilities.MergeWithDefault(featuresMetalTemplate, {
		shaderOptions = {
			autonormal = true,
			autoNormalParams = {1.5, 0.005},
		},
		deferredOptions = {
			materialIndex = 1,
		},
	}),

}


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local featureNameTrees = {
	-- all of the 0ad, beherith and artturi features start with these.
	{str = "ad0_", prefix = true, fakeNormal = true},
	{str = "art", prefix = true, fakeNormal = true},

	-- from BAR
	{str = "allpinesb", prefix = true, fakeNormal = true},
	{str = "bush", prefix = true, fakeNormal = true},
	{str = "vegetation", prefix = true, fakeNormal = true},
	{str = "vegitation", prefix = true, fakeNormal = true},
	{str = "baobab", prefix = true, fakeNormal = true},
	{str = "aleppo", prefix = true, fakeNormal = true},
	{str = "pine", prefix = true, fakeNormal = true},
	{str = "senegal", prefix = true, fakeNormal = true},
	{str = "palm", prefix = true, fakeNormal = true},
	{str = "shrub", prefix = true, fakeNormal = true},
	{str = "bloodthorn", prefix = true, fakeNormal = true},
	{str = "birch", prefix = true, fakeNormal = true},
	{str = "maple", prefix = true, fakeNormal = true},
	{str = "oak", prefix = true, fakeNormal = true},
	{str = "fern", prefix = true, fakeNormal = true},
	{str = "grass", prefix = true, fakeNormal = true},
	{str = "weed", prefix = true, fakeNormal = true},
	{str = "plant", prefix = true, fakeNormal = true},
	{str = "palmetto", prefix = true, fakeNormal = true},
	{str = "lowpoly_tree", prefix = true, fakeNormal = true},

	{str = "treetype", prefix = true, fakeNormal = true}, --engine trees

	{str = "btree", prefix = true, fakeNormal = false},	--beherith trees don't gain from fake normal

	-- Other trees will probably contain "tree" as a substring.
	{str = "tree", prefix = false, fakeNormal = true},
}

local featureNameTreesNoSway = {
	"fern1",  --doesn't look good on DownPour_v1
	"fern6",
	"fern8",
}

local featureNameTreeExceptions = {
	"street",
}

local FAKE_NORMALTEX = "UnitTextures/default_tree_normal.dds"
FAKE_NORMALTEX = VFS.FileExists(FAKE_NORMALTEX) and FAKE_NORMALTEX or nil
local function GetTreeInfo(fdef)
	if not fdef or not fdef.name then
		return false, false, false
	end

	local isTree = false
	local fakeNormal = false
	local noSway = false

	for _, treeInfo in ipairs(featureNameTrees) do
		local idx = fdef.name:find(treeInfo.str)
		if idx and ((treeInfo.prefix and idx == 1) or (not treeInfo.prefix)) then

			local isException = false
			for _, exc in ipairs(featureNameTreeExceptions) do
				isException = isException or fdef.name:find(exc) ~= nil
			end

			if not isException then
				isTree = true
				fakeNormal = treeInfo.fakeNormal
			end

			for _, exc in ipairs(featureNameTreesNoSway) do
				noSway = noSway or fdef.name:find(exc) ~= nil
				if noSway then
					fakeNormal = false --don't use fake normals for noSway trees
				end
			end

			break
		end
	end

	return isTree, fakeNormal, noSway
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------




--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local cusFeaturesMaterials = GG.CUS.featureMaterialDefs
local featureMaterials = {}

--metallic features & trees
for id = 1, #FeatureDefs do
	local featureDef = FeatureDefs[id]
	if not cusFeaturesMaterials[id] and featureDef.modeltype ~= "3do" then
		--Spring.Echo(featureDef.name)
		local isTree, fakeNormal, noSway = GetTreeInfo(featureDef)
		local metallic = featureDef.metal >= 1

		if isTree then
			if fakeNormal then
				featureMaterials[id] = {"featuresTreeFakeNormal", NORMALTEX = FAKE_NORMALTEX}
			else
				if noSway then
					featureMaterials[id] = {"featuresTreeAutoNormalNoSway"}
				else
					Spring.Echo(featureDef.name,  isTree, fakeNormal, noSway)
					featureMaterials[id] = {"featuresTreeAutoNormal"}
				end
			end

		elseif metallic then
			local fromUnit = featureDef.name:find("_dead") or featureDef.name:find("_heap")
			if fromUnit then
				Spring.PreloadFeatureDefModel(id)

				--Spring.Echo("featureDef.name", featureDef.name)
				--Spring.Echo("featureDef.model.textures", featureDef.model.textures)
				local wreckNormalTex = featureDef.model.textures.tex1  and
					((featureDef.model.textures.tex1:find("Arm_wreck") and "unittextures/Arm_wreck_color_normal.dds") or
					(featureDef.model.textures.tex1:find("Core_color_wreck") and "unittextures/Core_color_wreck_normal.dds"))

				if not wreckNormalTex then
					Spring.Echo("Failed to find normal map for unit wreck: ", featureDef.name)
				end

				featureMaterials[id] = {"featuresMetalDeadOrHeap", NORMALTEX = wreckNormalTex}

			else
				--Spring.Echo("featuresMetalNoWreck ", featureDef.name)
				featureMaterials[id] = {"featuresMetalNoWreck"}
			end
		end
		-- 133_feature_other will handle the rest of features
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, featureMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
