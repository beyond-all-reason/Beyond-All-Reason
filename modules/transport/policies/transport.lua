local Contract = VFS.Include("modules/transport/contract.lua") ---@type TransportContract
local load = Contract.Load
local unload = Contract.Unload
local loadedSpeed = Contract.LoadedSpeed

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

Policies.Pipeline(load)
	.Unless(load.Submerged, submerged)
	.If(load.WithinReach, withinReach)
	.Unless(load.Untransportable, function(ctx)
		return ctx.passengerDef ~= nil and ctx.passengerDef.cantBeTransported == true
	end)
	.Unless(load.Carried, function(ctx)
		return ctx.carried == true
	end)
	.Unless(load.UnderConstruction, function(ctx)
		return ctx.underConstruction == true
	end)
	.Unless(load.InAnimation, function(ctx)
		return ctx.inAnimation == true
	end)
	.Unless(load.MovingEnemy, function(ctx)
		return ctx.allied == false and (ctx.passengerSpeed or 0) >= NAP_MAX_SPEED
	end)
	.Unless(load.EnemyLoading, function(ctx)
		return ctx.allied == false and ctx.enemyLoading == false
	end)
	.Unless(load.EnemyImmune, function(ctx)
		return ctx.allied == false and ctx.passengerDef ~= nil and ctx.passengerDef.transportByEnemy == false
	end)
	.Unless(load.Unseen, function(ctx)
		return ctx.allied == false and ctx.seen == false
	end)
	.Unless(load.AlliedNano, function(ctx)
		return ctx.nano == true and ctx.allied == true and ctx.ownTeam ~= true
	end)
	.Select(load.Allowed, function()
		return true
	end)

Policies.Pipeline(unload)
	.Unless(unload.Submerged, submerged)
	.If(unload.WithinReach, withinReach)
	.Unless(unload.NanoOnSlope, function(ctx)
		return ctx.nano and (ctx.goalY < 0 or (ctx.groundNormalY or 1) < 0.9)
	end)
	.Select(unload.Allowed, function(ctx)
		return true
	end)

Policies.Pipeline(loadedSpeed).Select(loadedSpeed.CommanderDrag, function(ctx)
	if ctx.dragEnabled and ctx.carriesCommander then
		return COMMANDER_DRAG_SPEED / ctx.framesPerSecond
	end
	return ctx.transportSpeed / ctx.framesPerSecond
end)
