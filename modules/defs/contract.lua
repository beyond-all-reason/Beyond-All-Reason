local PolicyBuilder = VFS.Include("modules/policy_builder.lua")

---@class DefContext one def, on its way through post-processing
---@field name string the def's key in UnitDefs or WeaponDefs
---@field def table the def table, edited in place
---@field modOptions table

---@class UnitDefStages: PolicyStages<DefContext, DefContext>
---@field Base string the base game's post-processing, gamedata/alldefs_post.lua

---@type UnitDefStages
local UnitDef = {
	Base = "Base",
}

---@class WeaponDefStages: PolicyStages<DefContext, DefContext>
---@field Base string

---@type WeaponDefStages
local WeaponDef = {
	Base = "Base",
}

---@class DefsPipelines what LoadPolicies("defs") hands back
---@field unit_def AssembledPipeline<DefContext, DefContext>
---@field weapon_def AssembledPipeline<DefContext, DefContext>

---@class DefsContract
---@field UnitDef UnitDefStages
---@field WeaponDef WeaponDefStages

return PolicyBuilder.Contract("defs", {
	UnitDef = PolicyBuilder.Fold(UnitDef),
	WeaponDef = PolicyBuilder.Fold(WeaponDef),
})
