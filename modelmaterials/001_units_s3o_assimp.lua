local matTemplate = VFS.Include("ModelMaterials/Templates/defaultMaterialTemplate.lua")

local unitsNewNormalMap = Spring.Utilities.MergeWithDefault(matTemplate, {
	texUnits  = {
		[0] = "%TEX1",
		[1] = "%TEX2",
	},
	shaderOptions = {
		normalmapping = true,
		flashlights = true,
	},
	deferredOptions = {
		normalmapping = true,
		materialIndex = 1,
	},
})

local materials = {
	unitsNewNormalMap = unitsNewNormalMap,
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

		unitMaterials[id] = {"unitsNewNormalMap", TEX1 = tex1, TEX2 = tex2, NORMALTEX = normalTex}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, unitMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
