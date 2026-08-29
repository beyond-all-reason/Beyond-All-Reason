local Stages = VFS.Include("modules/transport/policy_stages.lua") ---@type TransportPolicyStages

local NAP_MAX_SPEED = 0.5
local COMMANDER_DRAG_SPEED = 120

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

Policies.On(Stages.load)
	.Unless(Stages.load.Submerged, submerged)
	.If(Stages.load.WithinReach, withinReach)
	.Unless(Stages.load.MovingEnemy, function(ctx)
		return ctx.allied == false and (ctx.passengerSpeed or 0) >= NAP_MAX_SPEED
	end)
	.Answer(Stages.load.Allowed, function()
		return true
	end)

Policies.On(Stages.unload)
	.Unless(Stages.unload.Submerged, submerged)
	.If(Stages.unload.WithinReach, withinReach)
	.Unless(Stages.unload.NanoOnSlope, function(ctx)
		return ctx.nano and (ctx.goalY < 0 or (ctx.groundNormalY or 1) < 0.9)
	end)
	.Answer(Stages.unload.Allowed, function(ctx)
		return true
	end)

Policies.On(Stages.loaded_speed).Answer(Stages.loaded_speed.CommanderDrag, function(ctx)
	if ctx.dragEnabled and ctx.carriesCommander then
		return COMMANDER_DRAG_SPEED / ctx.framesPerSecond
	end
	return ctx.transportSpeed / ctx.framesPerSecond
end)
