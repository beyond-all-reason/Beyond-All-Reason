local matTemplate = VFS.Include("ModelMaterials/Templates/defaultMaterialTemplate.lua")

local materials = {
	unitsFallback = Spring.Utilities.MergeWithDefault(matTemplate, {
		texUnits  = {
			[0] = "%%UNITDEFID:0",
			[1] = "%%UNITDEFID:1",
		},
		deferredOptions = {
			materialIndex = 127,
		}
	})
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local cusUnitMaterials = GG.CUS.unitMaterialDefs
local unitMaterials = {}

for id = 1, #UnitDefs do
	if not cusUnitMaterials[id] then
		Spring.Log(gadget:GetInfo().name, LOG.WARNING, string.format("Assigning unitsFallback material to unit %s. This should never happen.", UnitDefs[id].name))
		unitMaterials[id] = {"unitsFallback"}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return materials, unitMaterials

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
