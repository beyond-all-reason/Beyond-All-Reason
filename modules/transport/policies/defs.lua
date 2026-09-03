local Defs = VFS.Include("modules/defs/contract.lua") ---@type DefsContract
local Contract = VFS.Include("modules/transport/contract.lua") ---@type TransportContract
local TransportEnums = VFS.Include("modules/transport/enums.lua")

local TransportEnemy = TransportEnums.TransportEnemy

-- Which enemies a carrier may lift is written onto the defs, where the
-- engine reads it: transportByEnemy is the def-level face of the option.
Policies.On(Defs.UnitDef).Answer(Contract.UnitDef.EnemyTransport, function(ctx)
	local which = ctx.modOptions[TransportEnums.ModOptions.TransportEnemy]
	if which == TransportEnemy.None then
		ctx.def.transportbyenemy = false
	elseif which == TransportEnemy.NotCommanders and ctx.def.customparams.iscommander then
		ctx.def.transportbyenemy = false
	end
end)
