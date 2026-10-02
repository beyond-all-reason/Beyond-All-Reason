local Modules = require("modules/enums").Modules
local Policy = require("modules/policy")
local TransportEnums = require("modules/transport/enums")

---@type DefsContract
local Defs = Policies.Contract(Modules.Defs)

-- Whether an enemy may carry a unit is written onto its def, from the transportenemy option
--
---@class TransportUnitDefSteps: PolicySteps<DefContext, DefContext>
---@field EnemyTransport "EnemyTransport"

---@type TransportUnitDefSteps
local UnitDef = {
	EnemyTransport = "EnemyTransport",
}
Policy.Contributes(Defs.UnitDef, UnitDef)

local TransportEnemy = TransportEnums.TransportEnemy

Policies.On(UnitDef).Apply(UnitDef.EnemyTransport, function(ctx)
	local which = ctx.modOptions[TransportEnums.ModOptions.TransportEnemy]
	if which == TransportEnemy.None then
		ctx.def.transportbyenemy = false
	elseif which == TransportEnemy.NotCommanders and ctx.def.customparams.iscommander then
		ctx.def.transportbyenemy = false
	end
end)

---@class (partial) TransportContract
local Contract = {}
Contract.UnitDef = UnitDef

return Contract
