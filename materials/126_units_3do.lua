local matTemplate = VFS.Include("ModelMaterials/Templates/defaultMaterialTemplate.lua")

local materials = {
	units3do = Spring.Utilities.MergeWithDefault(matTemplate, {
		texUnits  = {
			[0] = "$units1",
			[1] = "$units2",
		},
		shaderOptions = {
			autonormal = true,
			autoNormalParams = {0.250, 0.001},
		},
		deferredOptions = {
			materialIndex = 126,
		},
		culling = false,
	})
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local cusUnitMaterials = GG.CUS.unitMaterialDefs
local unitMaterials = {}

for id = 1, #UnitDefs do
	local udef = UnitDefs[id]
	if not cusUnitMaterials[id] and udef.modeltype == "3do" then
		unitMaterials[id] = {"units3do"}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, unitMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
