local Contract = VFS.Include("modules/defs/contract.lua") ---@type DefsContract
local Base = VFS.Include("modules/defs/lib/base.lua")

-- The base game's post-processing is the first stage of each fold. It is
-- included on first use, and once per Lua state, so that reading this file
-- costs nothing outside def loading.
local base = Base.Base

Policies.Pipeline(Contract.UnitDef).Select(Contract.UnitDef.Base, function(ctx)
	base().UnitDef_Post(ctx.name, ctx.def)
end)

Policies.Pipeline(Contract.WeaponDef).Select(Contract.WeaponDef.Base, function(ctx)
	base().WeaponDef_Post(ctx.name, ctx.def)
end)
