local function loadController(hasUnitDeleted, hasTargetRemoved)
	if hasUnitDeleted == nil then
		hasUnitDeleted = true
	end
	local queue, targets, dead, deleted, crashing = {}, {}, {}, {}, {}
	local nextTag, listID, stunned = 0, 1, false
	local stops = {}
	local env = {
		gadget = {},
		GG = {},
		GameCMD = { ATTACK_TARGETS = 34927 },
		CMD = {
			ATTACK = 20,
			INSERT = 1,
			REMOVE = 2,
			FIGHT = 16,
			GUARD = 25,
			OPT_INTERNAL = 8,
			OPT_SHIFT = 32,
			OPT_ALT = 128,
		},
		CMDTYPE = { ICON = 0 },
		UnitDefs = { { canAttack = true } },
		Script = {
			GetCallInList = function()
				return hasUnitDeleted
						and { UnitDeleted = {}, UnitAttackTargetRemoved = hasTargetRemoved ~= false and {} or nil }
					or {}
			end,
		},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
			RegisterCMDID = function() end,
			RegisterAllowCommand = function() end,
		},
		Spring = {},
	}
	env.math = setmetatable({
		bit_or = function(a, b)
			assert(a == 0 and b == 32)
			return 32
		end,
	}, { __index = math })
	setmetatable(env, { __index = _G })
	local function insert(id, params, position)
		nextTag = nextTag + 1
		table.insert(queue, position or #queue + 1, { id = id, params = params, tag = nextTag })
	end
	env.Spring.ClearUnitGoal = function(unitID, stop)
		stops[#stops + 1] = { unitID, stop }
	end
	env.Spring.GetUnitCommands = function(_, count)
		local copy = {}
		for index = 1, count == -1 and #queue or math.min(count, #queue) do
			copy[index] = queue[index]
		end
		return copy
	end
	env.Spring.GetUnitCommandCount = function()
		return #queue
	end
	env.Spring.ValidUnitID = function(id)
		return not deleted[id]
	end
	env.Spring.GetUnitIsDead = function(id)
		return dead[id] or false
	end
	env.Spring.GetUnitMoveTypeData = function(id)
		return { aircraftState = crashing[id] and "crashing" or "flying" }
	end
	env.Spring.GetUnitIsBeingBuilt = function()
		return false
	end
	env.Spring.GetUnitIsStunned = function()
		return stunned
	end
	env.Spring.RegisterCommand = function() end
	env.Spring.GetUnitTeam = function()
		return 1
	end
	env.Spring.AreTeamsAllied = function()
		return false
	end
	env.Spring.GiveOrderToUnit = function(_, id, params)
		if id == env.CMD.INSERT then
			local embedded = {}
			for i = 4, #params do
				embedded[#embedded + 1] = params[i]
			end
			insert(params[2], embedded, params[1] + 1)
		elseif id == env.CMD.REMOVE then
			for i = #queue, 1, -1 do
				if queue[i].tag == params[1] then
					table.remove(queue, i)
				end
			end
		else
			insert(id, params)
		end
	end
	env.GG.SetUnitAttackTargetList = function(_, _, ids)
		targets = {}
		for _, id in ipairs(ids) do
			targets[#targets + 1] = { target = id }
		end
		return listID
	end
	env.GG.AppendUnitAttackTargetList = function(_, _, ids)
		local updated = {}
		for _, entry in ipairs(targets) do
			updated[#updated + 1] = entry
		end
		for _, id in ipairs(ids) do
			updated[#updated + 1] = { target = id }
		end
		targets = updated
		listID = listID + 1
		return listID
	end
	env.GG.GetUnitAttackTargetList = function()
		return targets
	end
	env.GG.GetUnitAttackTargetListID = function()
		return listID
	end
	env.GG.ClearUnitAttackTargetList = function() end
	local chunk = assert(loadfile("luarules/gadgets/cmd_attack_targets.lua"))
	setfenv(chunk, env)()
	env.gadget:Initialize()
	insert(34927, { 10, 20, 30, 40 })
	env.gadget:CommandFallback(1, 1, 0, 34927, queue[1].params, 0, queue[1].tag)
	assert.are.equal(10, queue[1].params[1])
	return {
		env = env,
		stops = stops,
		queue = queue,
		dead = dead,
		crashing = crashing,
		eraseActive = function()
			table.remove(queue, 1)
		end,
		delete = function(id)
			dead[id], deleted[id] = true, true
			env.gadget:UnitDeleted(id)
		end,
		reuse = function(id)
			dead[id], deleted[id] = nil, nil
		end,
		stun = function()
			stunned = true
		end,
		prune = function(id)
			local result = {}
			for _, entry in ipairs(targets) do
				if entry.target ~= id then
					result[#result + 1] = entry
				end
			end
			targets = result
		end,
	}
end

describe("pending Attack controller targets", function()
	it("exposes only the matching reference and preserves the pending cursor", function()
		local g = loadController()
		assert.are.equal(20, g.env.GG.GetPendingAttackTarget(1, -1))
		assert.is_nil(g.env.GG.GetPendingAttackTarget(1, -2))
		assert.is_nil(g.env.GG.GetPendingAttackTarget(2, -1))
		assert.are.equal(20, g.env.GG.GetPendingAttackTarget(1, -1))
	end)
	it("retains a crashing pending target until its native-equivalent deletion", function()
		local g = loadController()
		g.crashing[20] = true
		assert.are.equal(20, g.env.GG.GetPendingAttackTarget(1, -1))
	end)
	it("advances at deletion, not at UnitDestroyed", function()
		local g = loadController()
		g.eraseActive()
		g.dead[20] = true
		g.env.gadget:UnitDestroyed(20)
		assert.are.equal(34927, g.queue[1].id)
		g.delete(20)
		assert.are.equal(20, g.queue[1].id)
		assert.are.equal(30, g.queue[1].params[1])
	end)
	it("advances even when the shared list was pruned before deletion", function()
		local g = loadController()
		g.eraseActive()
		g.prune(20)
		g.delete(20)
		assert.are.equal(30, g.queue[1].params[1])
	end)
	it("keeps pruned future targets in the execution snapshot across fallback", function()
		local g = loadController()
		g.prune(30)
		g.eraseActive()
		local front = g.queue[1]
		g.env.gadget:CommandFallback(1, 1, 0, front.id, front.params, 0, front.tag)
		assert.are.equal(20, g.queue[1].params[1])
		assert.are.equal(30, g.env.GG.GetPendingAttackTarget(1, -1))
		g.eraseActive()
		g.delete(30)
		assert.are.equal(40, g.queue[1].params[1])
	end)
	it("keeps pruned pending targets when appending another Attack", function()
		local g = loadController()
		g.prune(30)
		assert.is_false(g.env.gadget:AllowCommand(1, 1, 0, 20, { 50 }, { shift = true, coded = 32 }))
		g.eraseActive()
		local front = g.queue[1]
		g.env.gadget:CommandFallback(1, 1, 0, front.id, front.params, 0, front.tag)
		assert.are.equal(20, g.queue[1].params[1])
		assert.are.equal(30, g.env.GG.GetPendingAttackTarget(1, -1))
		g.eraseActive()
		g.delete(30)
		assert.are.equal(40, g.queue[1].params[1])
		assert.are.equal(50, g.env.GG.GetPendingAttackTarget(1, -1))
	end)
	it("retains the raw suffix when a new Attack is prepended", function()
		local g = loadController()
		g.prune(30)
		local params = { 0, 20, 0, 60 }
		g.env.Spring.GiveOrderToUnit(1, g.env.CMD.INSERT, params)
		g.env.gadget:UnitCommand(1, 1, 0, g.env.CMD.INSERT, params, {})
		g.env.gadget:GameFrame()
		assert.are.equal(60, g.env.GG.GetPendingAttackTarget(1, -1))
		local front = g.queue[1]
		g.env.gadget:CommandFallback(1, 1, 0, front.id, front.params, 0, front.tag)
		assert.are.equal(60, g.queue[1].params[1])
		assert.are.equal(10, g.env.GG.GetPendingAttackTarget(1, -1))
	end)
	it("uses native queues on engines without deletion notifications", function()
		local g = loadController(false)
		for index = #g.queue, 1, -1 do
			table.remove(g.queue, index)
		end
		assert.is_false(g.env.gadget:AllowCommand(1, 1, 0, 34927, { 70, 80 }, { coded = 0 }))
		assert.are.equal(2, #g.queue)
		assert.are.equal(20, g.queue[1].id)
		assert.are.equal(70, g.queue[1].params[1])
		assert.are.equal(80, g.queue[2].params[1])
	end)
	it("does not revive a deleted future target when the engine reuses its ID", function()
		local g = loadController()
		g.delete(30)
		g.reuse(30)
		g.eraseActive()
		local front = g.queue[1]
		g.env.gadget:CommandFallback(1, 1, 0, front.id, front.params, 0, front.tag)
		assert.are.equal(20, g.queue[1].params[1])
		assert.are.equal(40, g.env.GG.GetPendingAttackTarget(1, -1))
	end)
	it("does not revive a recycled ID through an unrelated append", function()
		local g = loadController()
		g.delete(30)
		g.reuse(30)
		assert.is_false(g.env.gadget:AllowCommand(1, 1, 0, 20, { 50 }, { shift = true, coded = 32 }))
		g.eraseActive()
		local front = g.queue[1]
		g.env.gadget:CommandFallback(1, 1, 0, front.id, front.params, 0, front.tag)
		assert.are.equal(40, g.env.GG.GetPendingAttackTarget(1, -1))
	end)
	it("does not interrupt a still-active native Attack", function()
		local g = loadController()
		g.delete(20)
		assert.are.equal(10, g.queue[1].params[1])
		assert.are.equal(30, g.env.GG.GetPendingAttackTarget(1, -1))
	end)
	it("does not wake a stunned controller", function()
		local g = loadController()
		g.eraseActive()
		g.stun()
		g.delete(20)
		assert.are.equal(34927, g.queue[1].id)
	end)
	it("clears deletion watchers when its owner is destroyed", function()
		local g = loadController()
		g.eraseActive()
		g.env.gadget:UnitDestroyed(1)
		g.delete(20)
		assert.are.equal(34927, g.queue[1].id)
		assert.is_nil(g.env.GG.GetPendingAttackTarget(1, -1))
	end)
end)

describe("controller completion and neutralized targets", function()
	it("stops movement when the last virtual attacks become unattackable", function()
		local g = loadController()
		g.eraseActive()
		g.crashing[20], g.crashing[30], g.crashing[40] = true, true, true
		local c = g.queue[1]
		local handled, remove = g.env.gadget:CommandFallback(1, 1, 0, c.id, c.params, 0, c.tag)
		assert.is_true(handled)
		assert.is_true(remove)
		assert.same({ { 1, false } }, g.stops)
	end)
	it("retains crashing pending orders until execution or deletion", function()
		local g = loadController()
		g.eraseActive()
		g.crashing[20], g.crashing[30] = true, true
		g.delete(40)
		assert.are.equal(34927, g.queue[1].id)
		assert.same({}, g.stops)
		g.delete(20)
		assert.same({}, g.queue)
		assert.same({ { 1, false } }, g.stops)
	end)
	it("keeps the active Attack and its crashing suffix until the native removal phase", function()
		local g = loadController()
		g.crashing[20], g.crashing[30] = true, true
		g.delete(40)
		assert.are.equal(10, g.queue[1].params[1])
		assert.are.equal(2, #g.queue)
		assert.same({}, g.stops)
	end)
	it("removes neutralized pending targets only for the notified unit", function()
		local g = loadController()
		g.env.gadget:UnitAttackTargetRemoved(2, 1, 0, 20)
		assert.are.equal(20, g.env.GG.GetPendingAttackTarget(1, -1))
		g.env.gadget:UnitAttackTargetRemoved(1, 1, 0, 20)
		assert.are.equal(30, g.env.GG.GetPendingAttackTarget(1, -1))
		assert.are.equal(10, g.queue[1].params[1])
		assert.same({}, g.stops)
		g.eraseActive()
		local c = g.queue[1]
		g.env.gadget:CommandFallback(1, 1, 0, c.id, c.params, 0, c.tag)
		assert.are.equal(30, g.queue[1].params[1])
	end)
	it("does not advance or stop at neutralization of the pending head", function()
		local g = loadController()
		g.eraseActive()
		g.env.gadget:UnitAttackTargetRemoved(1, 1, 0, 20)
		assert.are.equal(34927, g.queue[1].id)
		assert.are.equal(30, g.env.GG.GetPendingAttackTarget(1, -1))
		assert.same({}, g.stops)
	end)
	it("can explicitly append a target removed by neutralization", function()
		local g = loadController()
		g.env.gadget:UnitAttackTargetRemoved(1, 1, 0, 20)
		g.env.gadget:AllowCommand(1, 1, 0, 20, { 20 }, { shift = true, coded = 32 })
		g.delete(30)
		g.delete(40)
		assert.are.equal(20, g.env.GG.GetPendingAttackTarget(1, -1))
	end)
end)

describe("neutralized controller reference cleanup", function()
	it("returns the exhausted reference tag without finishing or stopping it in Lua", function()
		local g = loadController()
		g.eraseActive()
		local tag = g.queue[1].tag
		g.env.gadget:UnitAttackTargetRemoved(1, 1, 0, 20)
		g.env.gadget:UnitAttackTargetRemoved(1, 1, 0, 30)
		assert.same({ tag }, g.env.gadget:UnitAttackTargetRemoved(1, 1, 0, 40))
		assert.are.equal(tag, g.queue[1].tag)
		assert.same({}, g.stops)
		assert.is_nil(g.env.GG.GetPendingAttackTarget(1, -1))
	end)
	it("removes the reference behind the final retained Attack", function()
		local g = loadController()
		g.env.gadget:UnitAttackTargetRemoved(1, 1, 0, 30)
		g.env.gadget:UnitAttackTargetRemoved(1, 1, 0, 40)
		g.eraseActive()
		local c = g.queue[1]
		g.env.gadget:CommandFallback(1, 1, 0, c.id, c.params, 0, c.tag)
		assert.are.equal(1, #g.queue)
		assert.are.equal(20, g.queue[1].params[1])
		assert.same({}, g.stops)
	end)
	it("uses native orders if only UnitDeleted is available", function()
		local g = loadController(true, false)
		local before = #g.queue
		assert.is_false(g.env.gadget:AllowCommand(2, 1, 0, 34927, { 50, 60 }, { coded = 0 }))
		assert.are.equal(before + 2, #g.queue)
		assert.are.equal(20, g.queue[#g.queue].id)
		assert.are.equal(60, g.queue[#g.queue].params[1])
	end)
end)
