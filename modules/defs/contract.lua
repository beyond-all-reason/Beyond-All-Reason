local PolicyBuilder = VFS.Include("modules/policy_builder.lua")
local Modules = VFS.Include("modules/enums.lua").Modules

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

-- The module's whole policy fits here, so it is inline: the loader runs this
-- function with the registrar; including the contract never does.
return PolicyBuilder.Contract(Modules.Defs, {
	UnitDef = PolicyBuilder.Fold(UnitDef),
	WeaponDef = PolicyBuilder.Fold(WeaponDef),
}, function(Policies)
	-- The base game's post-processing is the first stage of each fold, included
	-- on first use and once per Lua state, so reading this file costs nothing
	-- outside def loading.
	local base = VFS.Include("modules/defs/lib/base.lua").Base

	Policies.On(UnitDef).Answer(UnitDef.Base, function(ctx)
		base().UnitDef_Post(ctx.name, ctx.def)
	end)

	Policies.On(WeaponDef).Answer(WeaponDef.Base, function(ctx)
		base().WeaponDef_Post(ctx.name, ctx.def)
	end)
end)
