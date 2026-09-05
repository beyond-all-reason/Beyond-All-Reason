local Contract = VFS.Include("modules/defs/contract.lua") ---@type DefsContract

-- The base game's post-processing is the first stage of each fold. It is
-- included on first use so that reading this file costs nothing outside
-- def loading.
local alldefs = nil
local function base()
	if alldefs == nil then
		alldefs = VFS.Include("gamedata/alldefs_post.lua")
	end
	return alldefs
end

Policies.Pipeline(Contract.UnitDef).Select(Contract.UnitDef.Base, function(ctx)
	base().UnitDef_Post(ctx.name, ctx.def)
end)

Policies.Pipeline(Contract.WeaponDef).Select(Contract.WeaponDef.Base, function(ctx)
	base().WeaponDef_Post(ctx.name, ctx.def)
end)
