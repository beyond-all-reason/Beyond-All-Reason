local matTemplate = VFS.Include("ModelMaterials/Templates/defaultMaterialTemplate.lua")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GL_FLOAT = 0x1406
local GL_INT = 0x1404
-- args=<objID, matName, lodMatNum, uniformName, uniformType, uniformData>
local mySetMaterialUniform = {
	[false] = Spring.FeatureRendering.SetForwardMaterialUniform,
	[true]  = Spring.FeatureRendering.SetDeferredMaterialUniform,
}

local spGetFeatureHealth = Spring.GetFeatureHealth
local featuresHealth = {} --cache
local healthArray = {[1] = 0.0}

local function SendHealthInfo(featureID, featureDefID, hasStd, hasDef, hasShad)
	local h, mh = spGetFeatureHealth(featureID)
	if h and mh then

		h = math.max(h, 0)
		mh = math.max(mh, 0.01)

		if not featuresHealth[featureID] then
			featuresHealth[featureID] = h / mh
		elseif (h / mh - featuresHealth[featureID]) >= 0.02 then --consider the change of 2% significant. Health is increasing
			featuresHealth[featureID] = h / mh
		elseif (featuresHealth[featureID] - h / mh) >= 0.10 then --health is decreasing. Quantize by 10%.
			featuresHealth[featureID] = h / mh
		end

		local healthMixMult = 0.80
		healthArray[1] = healthMixMult * (1.0 - featuresHealth[featureID]) --invert so it can be used as mix() easier

		if hasStd then
			mySetMaterialUniform[false](featureID, "opaque", 3, "floatOptions[0]", GL_FLOAT, healthArray)
		end
		if hasDef then
			mySetMaterialUniform[true ](featureID, "opaque", 3, "floatOptions[0]", GL_FLOAT, healthArray)
		end
		if hasShad then
			mySetMaterialUniform[false](featureID, "shadow", 3, "floatOptions[0]", GL_FLOAT, healthArray)
		end
	end
end

local healthMod = {} --cache
local vertDisp = {} --cache
local vdhmArray = {[1] = 0.0, [2] = 0.0}
local function SendVertDispAndHelthMod(featureID, featureDefID, hasStd, hasDef, hasShad)
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
		if hasStd then
			mySetMaterialUniform[false](featureID, "opaque", 3, "floatOptions[1]", GL_FLOAT, vdhmArray)
		end
		if hasDef then
			mySetMaterialUniform[true ](featureID, "opaque", 3, "floatOptions[1]", GL_FLOAT, vdhmArray)
		end
		if hasShad then
			mySetMaterialUniform[false](featureID, "shadow", 3, "floatOptions[1]", GL_FLOAT, vdhmArray)
		end
	end
end

local fidArray = {[1] = 0}
local function SendFeatureID(featureID, hasStd, hasDef, hasShad)
	fidArray[1] = featureID
	if hasStd then
		mySetMaterialUniform[false](featureID, "opaque", 3, "intOptions[0]", GL_INT, fidArray)
	end
	if hasDef then
		mySetMaterialUniform[true ](featureID, "opaque", 3, "intOptions[0]", GL_INT, fidArray)
	end
	if hasShad then
		mySetMaterialUniform[false](featureID, "shadow", 3, "intOptions[0]", GL_INT, fidArray)
	end
end

local featuresList = {}
local function FeatureCreated(featureID, featureDefID, mat)
	featuresList[featureID] = featureDefID

	local hasStd, hasDef, hasShad = mat.hasStandardShader, mat.hasDeferredShader, mat.hasShadowShader

	SendFeatureID(featureID, featureID, hasDef, hasShad)
	SendVertDispAndHelthMod(featureID, featureDefID, hasStd, hasDef, hasShad)
	SendHealthInfo(featureID, featureDefID, hasStd, hasDef, hasShad)
end

local function FeatureDestroyed(featureID, featureDefID, mat)
	featuresList[featureID] = nil
end

local function GameFrameSlow(gf, mat)
	local hasStd, hasDef, hasShad = mat.hasStandardShader, mat.hasDeferredShader, mat.hasShadowShader
	for featureID, featureDefID in pairs(featuresList) do
		SendHealthInfo(featureID, featureDefID, hasStd, hasDef, hasShad)
	end
end

local function FeatureDamaged(featureID, featureDefID, mat)
	local hasStd, hasDef, hasShad = mat.hasStandardShader, mat.hasDeferredShader, mat.hasShadowShader
	SendHealthInfo(featureID, featureDefID, hasStd, hasDef, hasShad)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local featureTreeTemplate = table.merge(matTemplate, {
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

		"#define TONEMAP(c) CustomTM(c)",
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

		"#define TONEMAP(c) CustomTM(c)",
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

local featuresMetalTemplate = table.merge(matTemplate, {
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

		"#define TONEMAP(c) CustomTM(c)",
	},
	deferredDefinitions = {
		"#define RENDERING_MODE 1",
		"#define SUNMULT 1.0",
		--"#define EXPOSURE 1.0",

		"#define METALNESS 0.2",
		"#define ROUGHNESS 0.6",

		--"#define USE_ENVIRONMENT_DIFFUSE",
		--"#define USE_ENVIRONMENT_SPECULAR",

		"#define TONEMAP(c) CustomTM(c)",
	},
	--Initialize	= Initialize,
	--Finalize	= Finalize,
	--GameFrameSlow = GameFrameSlow,
})

local materials = {
	featuresTreeNormal = table.merge(featureTreeTemplate, {
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
		FeatureCreated = FeatureCreated,
		FeatureDestroyed = FeatureDestroyed,
	}),

	featuresTreeAutoNormal = table.merge(featureTreeTemplate, {
		shaderOptions = {
			autonormal = true,
			autoNormalParams = {1.5, 0.005},
		},
		deferredOptions = {
			materialIndex = 129,
		},
		FeatureCreated = FeatureCreated,
		FeatureDestroyed = FeatureDestroyed,
	}),

	featuresTreeAutoNormalNoSway = table.merge(featureTreeTemplate, {
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

	featuresMetalDeadOrHeap = table.merge(featuresMetalTemplate, {
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

	featuresMetalNoWreck = table.merge(featuresMetalTemplate, {
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
	{str = "lowpoly_tree", prefix = true, fakeNormal = false},

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
	local normalMap = nil
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
				local fdNM = (fdef.customParams or {}).normaltex
				if fdNM then
					normalMap = fdNM
				else
					normalMap = (treeInfo.fakeNormal and FAKE_NORMALTEX) or nil
				end
			end

			for _, exc in ipairs(featureNameTreesNoSway) do
				noSway = noSway or fdef.name:find(exc) ~= nil
				if noSway then
					normalMap = nil --don't use fake normals for noSway trees
				end
			end

			break
		end
	end

	return isTree, normalMap, noSway
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local cusFeaturesMaterials = GG.CUS.featureMaterialDefs
local featureMaterials = {}
local failedwrecknormaltex = {}
--metallic features & trees
for id = 1, #FeatureDefs do
	local featureDef = FeatureDefs[id]
	if not cusFeaturesMaterials[id] and featureDef.modeltype ~= "3do" then
		local isTree, normalMap, noSway = GetTreeInfo(featureDef)
		local metallic = featureDef.metal >= 1

		if isTree then
			if normalMap then
				featureMaterials[id] = {"featuresTreeNormal", NORMALTEX = normalMap}
			else
				if noSway then
					featureMaterials[id] = {"featuresTreeAutoNormalNoSway"}
				else
					featureMaterials[id] = {"featuresTreeAutoNormal"}
				end
			end

		elseif metallic then
			local fromUnit = featureDef.name:find("_dead") or featureDef.name:find("_heap")

			if fromUnit then
				Spring.PreloadFeatureDefModel(id)
				local lowercasetex1 = ""

				if featureDef.model.textures.tex1 == nil then 
					Spring.Echo("nil texture 1 detected for",featureDef.name) 
				else
					lowercasetex1 = string.lower( featureDef.model.textures.tex1)
				end

				local wreckNormalTex = featureDef.model.textures.tex1  and
					((lowercasetex1:find("arm_wreck") and "unittextures/Arm_wreck_color_normal.dds") or
					(lowercasetex1:find("arm_color") and "unittextures/Arm_normal.dds") or -- for things like dead dragons claw armclaw
					(lowercasetex1:find("cor_color.dds",1,true) and "unittextures/cor_normal.dds") or -- for things like dead dragons maw cormaw
					(lowercasetex1:find("cor_color_wreck") and "unittextures/cor_color_wreck_normal.dds"))

				if not wreckNormalTex then
					table.insert(failedwrecknormaltex, 1, featureDef.name)
					Spring.Echo("Failed to find normal map for unit wreck: ", featureDef.name,lowercasetex1)
				end

				featureMaterials[id] = {"featuresMetalDeadOrHeap", NORMALTEX = wreckNormalTex}
			else
				featureMaterials[id] = {"featuresMetalNoWreck"}
			end
		end
		-- 133_feature_other will handle the rest of features
	end
end

if #failedwrecknormaltex > 0 then 
	Spring.Echo("Failed to find normal map for unit wreck: ", table.concat(failedwrecknormaltex,','))
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, featureMaterials
