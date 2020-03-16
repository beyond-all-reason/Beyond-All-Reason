local matTemplate = VFS.Include("ModelMaterials/Templates/defaultMaterialTemplate.lua")

local unitsNewNormalMap = Spring.Utilities.MergeWithDefault(matTemplate, {
	texUnits  = {
		[0] = "%TEX1",
		[1] = "%TEX2",
		[5] = "%NORMALTEX",
	},
	shaderOptions = {
		normalmapping = true,
	},
	deferredOptions = {
		normalmapping = true,
		materialIndex = 1,
	},
})
local unitsNewNormalMapFL = Spring.Utilities.MergeWithDefault(unitsNewNormalMap, {
	shaderOptions = {
		flashlights = true,
	},
})
local unitsNewNoNormalMap = Spring.Utilities.MergeWithDefault(matTemplate, {
	texUnits  = {
		[0] = "%TEX1",
		[1] = "%TEX2",
	},
	shaderOptions = {
		autonormal  = true,
	},
	deferredOptions = {
		materialIndex = 2,
	},
})
local unitsNewNoNormalMapFL = Spring.Utilities.MergeWithDefault(unitsNewNoNormalMap, {
	shaderOptions = {
		flashlights = false, --TODO change to true and sort out which units misbehave manually
	},
})

local materials = {
	unitsNewNormalMap = unitsNewNormalMap,
	unitsNewNormalMapFL = unitsNewNormalMapFL,
	unitsNewNoNormalMap = unitsNewNoNormalMap,
	unitsNewNoNormalMapFL = unitsNewNoNormalMapFL,
}


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function FindNormalMap(tex1, tex2)
	local normaltex

	--// check if there is a corresponding _normals.dds file
	if tex1 and (VFS.FileExists(tex1)) then
		local basefilename = tex1:gsub("%....", "")
		if (tonumber(basefilename:sub(-1, -1))) then
			basefilename = basefilename:sub(1, -2)
		end
		if (basefilename:sub(-1, -1) == "_") then
			basefilename = basefilename:sub(1, -2)
		end
		normaltex = basefilename .. "_normals.dds"
		if (not VFS.FileExists(normaltex)) then
			normaltex = nil
		end
	end --if FileExists

	if (not normaltex) and tex2 and (VFS.FileExists(tex2)) then
		local basefilename = tex2:gsub("%....", "")
		if (tonumber(basefilename:sub(-1, -1))) then
			basefilename = basefilename:sub(1, -2)
		end
		if (basefilename:sub(-1,-1) == "_") then
			basefilename = basefilename:sub(1, -2)
		end
		normaltex = basefilename .. "_normals.dds"
		if (not VFS.FileExists(normaltex)) then
			normaltex = nil
		end
	end

	return normaltex
end

local function GetS3ONormalTex(udef, tex1, tex2)
	local normaltex = nil
	local modelpath = udef.modelpath

	if (modelpath) then
		--// udef.model.textures is empty at gamestart, so read the texture filenames from the s3o directly
		local rawstr = VFS.LoadFile(modelpath)
		local header = rawstr:sub(1, 60)
		local texPtrs = VFS.UnpackU32(header, 45, 2)
		local tex1,tex2
		if texPtrs then
			if (texPtrs[2] > 0) then
				tex2 = "UnitTextures/" .. rawstr:sub(texPtrs[2] + 1, rawstr:len() - 1)
			else
				texPtrs[2] = rawstr:len()
			end
			if (texPtrs[1] > 0) then
				tex1 = "UnitTextures/" .. rawstr:sub(texPtrs[1] + 1, texPtrs[2] - 1)
			end
		end

		-- output units without tex2
		if not tex2 then
			Spring.Log(gadget:GetInfo().name, LOG.WARNING, "CustomUnitShaders: " .. udef.name .. "has no tex2")
		end

		normaltex = FindNormalMap(tex1, tex2)
	end

	return normaltex
end

local function GetAssimpNormalTex(udef, tex1, tex2)
	local normaltex = nil
	local modelInfoPath = udef.modelpath

	if (modelInfoPath) then
		modelInfoPath = modelInfoPath .. ".lua"

		if (VFS.FileExists(modelInfoPath)) then
			local infoTbl = VFS.Include(modelInfoPath)
			if (infoTbl) then
				local tex1 = "UnitTextures/" .. (infoTbl.tex1 or "")
				local tex2 = "UnitTextures/" .. (infoTbl.tex2 or "")

				-- output units without tex2
				if not tex2 then
					Spring.Log(gadget:GetInfo().name, LOG.WARNING, "CustomUnitShaders: " .. udef.name .. "has no tex2")
				end

				normaltex = FindNormalMap(tex1, tex2)
			end
		end
	end

	return normaltex
end

local function GetNormalTex(udef)
	local normalTex = nil
	if (udef.customParams.normaltex and VFS.FileExists(udef.customParams.normaltex)) then
		normalTex = udef.customParams.normaltex
	elseif ((not normalTex) and udef.modeltype == "s3o") then --s3o
		normalTex = GetS3ONormalTex(udef, tex1, tex2)
	elseif ((not normalTex) and udef.modeltype ~= "3do") then --assimp, 3do crap is handled later as it requires special culling and textures
		normalTex = GetAssimpNormalTex(udef, tex1, tex2)
	end
	return normalTex
end

local function GetUnitMaterial(tex1, tex2, normalTex, flashlights)
	local unitMaterial

	if normalTex then
		if flashlights then
			unitMaterial = {"unitsNewNormalMapFL", TEX1 = tex1, TEX2 = tex2, NORMALTEX = normalTex}
		else
			unitMaterial = {"unitsNewNormalMap", TEX1 = tex1, TEX2 = tex2, NORMALTEX = normalTex}
		end
	else
		if flashlights then
			unitMaterial = {"unitsNewNoNormalMapFL", TEX1 = tex1, TEX2 = tex2}
		else
			unitMaterial = {"unitsNewNoNormalMap", TEX1 = tex1, TEX2 = tex2}
		end
	end

	return unitMaterial
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local cusUnitMaterials = GG.CUS.unitMaterialDefs
local unitMaterials = {}

for id = 1, #UnitDefs do
	local udef = UnitDefs[id]
	if not cusUnitMaterials[id] and udef.modeltype ~= "3do" then
		local tex1 = "%%"..id..":0"
		local tex2 = "%%"..id..":1"

		local flashlights = true
		if (udef.customParams.cus_noflashlight and udef.customParams.cus_noflashlight == "1") then
			flashlights = false
		end

		if (udef.customParams.altskin and VFS.FileExists(udef.customParams.altskin)) then
			tex1 = udef.customParams.altskin
		end

		if (udef.customParams.altskin2 and VFS.FileExists(udef.customParams.altskin2)) then
			tex1 = udef.customParams.altskin2
		end

		local normalTex = GetNormalTex(udef)


		unitMaterials[id] = GetUnitMaterial(tex1, tex2, normalTex, flashlights)
	end
end

local skinDefs = include("LuaRules/Configs/dynamic_comm_skins.lua")

for name, data in pairs(skinDefs) do
	local udefParent = UnitDefNames["dyn" .. data.chassis .. "0"]

	local flashlights = true
	if (udefParent.customParams.cus_noflashlight) then
		flashlights = false
	end

	local tex1 = data.altskin
	local tex2 = data.altskin2
	if not tex2 then
		tex2 = "%%" .. udefParent.id .. ":1"
	end

	local normalTex = GetNormalTex(udefParent)
	unitMaterials[name] = GetUnitMaterial(tex1, tex2, normalTex, flashlights)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, unitMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
