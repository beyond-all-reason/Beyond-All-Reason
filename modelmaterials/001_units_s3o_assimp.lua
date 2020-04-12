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
	},
	deferredOptions = {
		normalmapping = true,
		flashlights = true,
		vertex_ao = true,
	},
})


----------------------------------------------


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
local function UnitCreatedArmTanks(unitID, unitDefID, mat)
	armTanks[unitID] = true
end

local coreTanks = {}
local function UnitCreatedCoreTanks(unitID, unitDefID, mat)
	coreTanks[unitID] = true
end

local function UnitDestroyedArmTanks(unitID, unitDefID)
	armTanks[unitID] = nil
end

local function UnitDestroyedCoreTanks(unitID, unitDefID)
	coreTanks[unitID] = nil
end

local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitDirection = Spring.GetUnitDirection

local GL_FLOAT = 0x1406
local threadsArray = {[1] = 0.0}

local function GameFrameArmTanks(gf, mat, isDeferred)
	if isDeferred then
		return
	end

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

		threadsArray[1] = offset
		urSetMaterialUniform[false](unitID, "opaque", 3, "floatOptions[3]", GL_FLOAT, threadsArray)
	end
end

local function GameFrameCoreTanks(gf, mat, isDeferred)
	if isDeferred then
		return
	end
	
	for unitID, _ in pairs(coreTanks) do
		-----
		local usx, usy, usz, speed = spGetUnitVelocity(unitID)
		if speed > 0.01 then speed = 1 end

		local udx, udy, udz = spGetUnitDirection(unitID)
		if udx > 0 and usx < 0  or  udx < 0 and usx > 0  or  udz > 0 and usz < 0  or  udz < 0 and usz > 0 then
			speed = -speed
		end

		local offset = ((gf % 10) * (8.0 / 2048.0)) * speed
		----

		threadsArray[1] = offset
		urSetMaterialUniform[false](unitID, "opaque", 3, "floatOptions[3]", GL_FLOAT, threadsArray)
	end
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
		UnitCreated = UnitCreatedArmTanks,
		UnitDestroyed = UnitDestroyedArmTanks,
		GameFrame = GameFrameArmTanks,
	}),
	unitsNormalMapCoreTanks = Spring.Utilities.MergeWithDefault(unitsNormalMapTemplate, {
		shaderOptions = {
			threads_core = true,
		},
		deferredOptions = {
			materialIndex = 2,
		},
		UnitCreated = UnitCreatedCoreTanks,
		UnitDestroyed = UnitDestroyedCoreTanks,
		GameFrame = GameFrameCoreTanks,
	}),
	unitsNormalMapOthers = Spring.Utilities.MergeWithDefault(unitsNormalMapTemplate, {
		shaderOptions = {
		},
		deferredOptions = {
			materialIndex = 3,
		},
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
