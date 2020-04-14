local matTemplate = VFS.Include("ModelMaterials/Templates/defaultMaterialTemplate.lua")

--[[
local sentError = false

local metalWreckTreshold = 1
local function SetWreckMetalThreshold(mwt)
	metalWreckTreshold = mwt
end

local registered = false
local function Initialize(matName, matSrc)
	if not registered then
		gadgetHandler:RegisterGlobal("SetWreckMetalThreshold", SetWreckMetalThreshold)
		registered = true
	end
	if matSrc.ProcessOptions then
		matSrc.ProcessOptions(matSrc, "metal_highlight", {false})
	end
end

local unregistered = false
local function Finalize(matName, matSrc)
	if not unregistered then
		gadgetHandler:DeregisterGlobal("SetWreckMetalThreshold")
		unregistered = true
	end
end


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

local GL_FLOAT = 0x1406
local mhArray = {[1] = 0.0}
local metalInfo = {}
local abs = math.abs
local function GameFrameSlow(gf, mat, isDeferred)
	local highlightActive
	if isDeferred then
		highlightActive = mat.deferredOptions.metal_highlight
	else
		highlightActive = mat.shaderOptions.metal_highlight
	end

	if highlightActive then
		local fs = Spring.GetAllFeatures()
		--local fs = Spring.GetVisibleFeatures(-1, 30, false)
		for _, fID in ipairs(fs) do
			local metalHere = Spring.GetFeatureResources(fID)

			--only update when metalHere has changed or object has never been seen before
			if not metalInfo[fID] or abs(metalInfo[fID] - metalHere) > 1.0 then
				metalInfo[fID] = metalHere
				mhArray[1] = ((metalHere >= metalWreckTreshold) and metalHere) or 0.0

				if not (frSetMaterialUniform and frSetMaterialUniform[isDeferred]) then
					if not sentError then
						sentError = true
						Spring.Echo("LUA_ERRRUN", "ModelMaterials/128_features_special.lua", "GameFrameSlow")
						Spring.Echo("frSetMaterialUniform", frSetMaterialUniform)
						Spring.Echo("isDeferred", isDeferred)
						Spring.Echo("fID", fID)
						local fx, fy, fz = Spring.GetFeaturePosition(fID)
						Spring.Echo("fx, fy, fz", fx, fy, fz)
					end
					return
				end
				frSetMaterialUniform[isDeferred](fID, "opaque", 3, "floatOptions[1]", GL_FLOAT, mhArray)
			end

		end
	end
end
]]--

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
			autoNormalParams = {0.5, 0.01},
		},
		deferredOptions = {
			materialIndex = 129,
		},
	}),

	featuresMetalDeadOrHeap = Spring.Utilities.MergeWithDefault(featuresMetalTemplate, {
		texUnits  = {
			[2] = "%NORMALTEX",
		},
		shaderOptions = {
			normalmapping = true,
		},
		deferredOptions = {
			materialIndex = 130,
		},
	}),

	featuresMetalNoWreck = Spring.Utilities.MergeWithDefault(featuresMetalTemplate, {
		shaderOptions = {
			autonormal = true,
			autoNormalParams = {0.5, 0.01},
		},
		deferredOptions = {
			materialIndex = 131,
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


local featureNameTreeExceptions = {
	"fern1",  --doesn't look good on DownPour_v1
	"fern6",
	"fern8",
	"street",
}

local FAKE_NORMALTEX = "UnitTextures/default_tree_normal.dds"
FAKE_NORMALTEX = VFS.FileExists(FAKE_NORMALTEX) and FAKE_NORMALTEX or nil
local function GetTreeInfo(fdef)
	if not fdef or not fdef.name then
		return false, false
	end

	local isTree = false
	local fakeNormal = false

	for _, treeInfo in ipairs(featureNameTrees) do
		local idx = fdef.name:find(treeInfo.str)
		if idx and ((treeInfo.prefix and idx == 1) or (not treeInfo.prefix)) then
				--Spring.Echo(fdef.name)

			local isException = false
			for _, exc in ipairs(featureNameTreeExceptions) do
				isException = isException or fdef.name:find(exc) ~= nil
			end

			if not isException then
				isTree = true
				fakeNormal = FAKE_NORMALTEX and treeInfo.fakeNormal
			end
		end
	end

	return isTree, fakeNormal
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
		local isTree, fakeNormal = GetTreeInfo(featureDef)
		local metallic = featureDef.metal >= 1

		if isTree then
			if fakeNormal then
				featureMaterials[id] = {"featuresTreeFakeNormal", NORMALTEX = FAKE_NORMALTEX}
			else
				featureMaterials[id] = {"featuresTreeAutoNormal", NORMALTEX = FAKE_NORMALTEX}
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
