local Policy = require("modules/policy")

local NAP_MAX_SPEED = 0.5

---@class TransportApproachContext where a carrier meets the ground: shared by load and unload
---@field goalY number
---@field height number|nil
---@field reach number|nil
---@field distance number|nil

---@param ctx TransportApproachContext
---@return boolean
local function submerged(ctx)
	return ctx.height == nil or ctx.goalY + ctx.height < 0
end

---@param ctx TransportApproachContext
---@return boolean
local function withinReach(ctx)
	return ctx.reach == nil or (ctx.distance or 0) <= ctx.reach
end

-- May this carrier pick that passenger up here
--
---@class TransportLoadContext: TransportApproachContext
---@field carrierDef table|nil
---@field passengerDef table|nil
---@field allied boolean|nil
---@field ownTeam boolean|nil
---@field nano boolean|nil
---@field passengerSpeed number|nil

---@class TransportLoadPolicy: PolicySteps<TransportLoadContext, boolean>
---@field Submerged "Submerged"
---@field WithinReach "WithinReach"
---@field MovingEnemy "MovingEnemy"
---@field AlliedNano "AlliedNano"
---@field Allowed "Allowed"

---@type TransportLoadPolicy
local Load = {
	Submerged = "Submerged",
	WithinReach = "WithinReach",
	MovingEnemy = "MovingEnemy",
	AlliedNano = "AlliedNano",
	Allowed = "Allowed",
}
Policy.Single(Load)

Policies.On(Load)
	.Unless(Load.Submerged, submerged)
	.If(Load.WithinReach, withinReach)
	.Unless(Load.MovingEnemy, function(ctx)
		return ctx.allied == false and (ctx.passengerSpeed or 0) >= NAP_MAX_SPEED
	end)
	.Unless(Load.AlliedNano, function(ctx)
		return ctx.nano == true and ctx.allied == true and ctx.ownTeam ~= true
	end)
	.Answer(Load.Allowed, function()
		return true
	end)

-- May this carrier set its passenger down here
--
---@class TransportUnloadContext: TransportApproachContext
---@field nano boolean|nil
---@field groundNormalY number|nil

---@class TransportUnloadPolicy: PolicySteps<TransportUnloadContext, boolean>
---@field Submerged "Submerged"
---@field WithinReach "WithinReach"
---@field NanoOnSlope "NanoOnSlope"
---@field Allowed "Allowed"

---@type TransportUnloadPolicy
local Unload = {
	Submerged = "Submerged",
	WithinReach = "WithinReach",
	NanoOnSlope = "NanoOnSlope",
	Allowed = "Allowed",
}
Policy.Single(Unload)

Policies.On(Unload)
	.Unless(Unload.Submerged, submerged)
	.If(Unload.WithinReach, withinReach)
	.Unless(Unload.NanoOnSlope, function(ctx)
		return ctx.nano and (ctx.goalY < 0 or (ctx.groundNormalY or 1) < 0.9)
	end)
	.Answer(Unload.Allowed, function()
		return true
	end)

---@class (partial) TransportContract
local Contract = {}
Contract.Load = Load
Contract.Unload = Unload

return Contract
