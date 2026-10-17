local function loadTargetGadget(sourceCount, unitTeams)
	sourceCount = sourceCount or 1
	local currentCommand
	local target
	local targetsByUnit = {}
	local rules = {}
	local events = {}
	local checks = {}
	local trackingChecks = {}
	local released = {}
	---@type table<integer, boolean>
	local deadTargets = {}
	local canTarget = function(_targetID)
		return true
	end
	local env = {
		gadget = {},
		GG = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
		},
		CMD = {
			STOP = 0,
			ATTACK = 20,
			FIGHT = 16,
			GUARD = 25,
			WAIT = 5,
			MANUALFIRE = 105,
			AREA_ATTACK = 21,
			OPT_INTERNAL = 8,
			FIRESTATE_RETURNFIRE = 1,
		},
		GameCMD = {
			UNIT_SET_TARGET = 1001,
			UNIT_SET_TARGET_NO_GROUND = 1002,
			UNIT_CANCEL_TARGET = 1003,
			UNIT_SET_TARGET_RECTANGLE = 1004,
			UNIT_SET_TARGETS = 1005,
			AREA_ATTACK_GROUND = 1007,
		},
		CMDTYPE = { ICON = 0, ICON_UNIT_OR_AREA = 1 },
		Game = { gameSpeed = 30 },
		UnitDefs = {
			{
				canAttack = true,
				maxWeaponRange = 1000,
				speed = 30,
				customParams = {},
				weapons = { { weaponDef = 1, slavedTo = 0 } },
			},
		},
		WeaponDefs = { { type = "Cannon", range = 1000, customParams = {} } },
		Spring = {
			ValidUnitID = function()
				return true
			end,
			GetUnitDefID = function()
				return 1
			end,
			GetUnitTeam = function(unitID)
				return unitTeams and unitTeams[unitID] or (unitID <= sourceCount and 1 or 2)
			end,
			GetUnitAllyTeam = function(unitID)
				return unitID <= sourceCount and 1 or 2
			end,
			AreTeamsAllied = function(a, b)
				return a == b
			end,
			GetUnitIsDead = function(unitID)
				return deadTargets[unitID] or false
			end,
			GetUnitLosState = function(unitID)
				trackingChecks[#trackingChecks + 1] = unitID
				-- Destroyed units have no LOS state, which is how the gadget notices them.
				if deadTargets[unitID] then
					return nil
				end
				return 3
			end,
			GetUnitMoveTypeData = function()
				return {}
			end,
			GetUnitWeaponTryTarget = function(_, _, targetID)
				checks[#checks + 1] = targetID
				return canTarget(targetID)
			end,
			GetUnitWeaponTestTarget = function()
				return true
			end,
			GetUnitCurrentCommand = function(_, index)
				if currentCommand and (not index or index == 1) then
					return unpack(currentCommand)
				end
			end,
			GetUnitStates = function()
				return 2
			end,
			SetUnitTarget = function(unitID, newTarget)
				target = newTarget
				targetsByUnit[unitID] = newTarget
				if newTarget == nil then
					released[#released + 1] = unitID
				end
			end,
			SetUnitRulesParam = function(_, key, value)
				rules[key] = value
			end,
		},
		VFS = {
			Include = function(path)
				return dofile(path)
			end,
		},
		SendToUnsynced = function(...)
			events[#events + 1] = { ... }
		end,
		CallAsTeam = function(_, fn, ...)
			return fn(...)
		end,
	}
	env.math = setmetatable({
		bit_and = function(a, b)
			return a % (b * 2) >= b and b or 0
		end,
		clamp = function(value, low, high)
			return math.max(low, math.min(value, high))
		end,
	}, { __index = math })
	env.table = setmetatable({
		map = function(values, fn)
			local result = {}
			for k, v in pairs(values) do
				local value, key = fn(v, k)
				result[key] = value
			end
			return result
		end,
	}, { __index = table })
	setmetatable(env, { __index = _G })
	local chunk = assert(loadfile("luarules/gadgets/unit_target_on_the_move.lua"))
	setfenv(chunk, env)
	chunk()
	return {
		env = env,
		checks = checks,
		trackingChecks = trackingChecks,
		released = released,
		deadTargets = deadTargets,
		canTarget = function(fn)
			canTarget = fn
		end,
		update = function(frame)
			for i = #checks, 1, -1 do
				checks[i] = nil
			end
			for index = #trackingChecks, 1, -1 do
				trackingChecks[index] = nil
			end
			env.gadget:GameFrame(frame)
		end,
		rules = rules,
		events = events,
		command = function(id, targetID)
			currentCommand = id and { id, 0, 99, targetID }
		end,
		target = function()
			return target
		end,
		targetsByUnit = targetsByUnit,
		set = function(targetID, append, shared, sourceID)
			env.gadget:AllowCommand(
				sourceID or 1,
				1,
				1,
				shared and env.GameCMD.UNIT_SET_TARGETS or env.GameCMD.UNIT_SET_TARGET,
				type(targetID) == "table" and targetID or { targetID },
				{ shift = append, coded = 0 },
				1,
				1
			)
		end,
	}
end

describe("Set Target precedence after shared-list updates", function()
	for _, frame in ipairs({ 1, 15 }) do
		it("reasserts targets outside the scan chunk on frame " .. frame, function()
			local g = loadTargetGadget(80)
			for unitID = 1, 80 do
				g.set(1000, false, true, unitID)
				g.env.Spring.SetUnitTarget(unitID, 2000)
			end
			g.update(frame)
			for unitID = 1, 80 do
				assert.are.equal(1000, g.targetsByUnit[unitID])
			end
			assert.is_true(#g.checks <= 32)
		end)
	end

	it("reasserts engaged targets after the scan budget is exhausted", function()
		local g = loadTargetGadget(400)
		local targets = {}
		for index = 1, 300 do
			targets[index] = 1000 + index
		end
		for unitID = 1, 400 do
			g.set(targets, false, true, unitID)
			g.env.Spring.SetUnitTarget(unitID, 2000)
		end
		g.canTarget(function()
			return false
		end)
		g.update(1)
		assert.are.equal(8192, #g.checks)
		for unitID = 65, 400 do
			assert.are.equal(1001, g.targetsByUnit[unitID])
		end
	end)

	for _, shared in ipairs({ false, true }) do
		local label = shared and "explicit shared list" or "legacy single target"
		it("keeps a new " .. label .. " paused during Wait and resumes it afterward", function()
			local g = loadTargetGadget()
			g.command(g.env.CMD.WAIT)
			g.set(10, false, shared)
			assert.is_nil(g.target())
			assert.are.equal(1, g.rules.hasPriorityTarget)
			g.env.gadget:GameFrame(1)
			local referenced, paused = false, false
			for _, event in ipairs(g.events) do
				referenced = referenced or event[1] == "targetListReference"
				paused = paused or (event[1] == "targetPause" and event[3] == true)
			end
			assert.is_true(referenced)
			assert.is_true(paused)
			g.command(nil)
			g.env.gadget:GameFrame(15)
			g.env.gadget:GameFrame(16)
			assert.are.equal(10, g.target())
		end)

		it("does not let an appended " .. label .. " override a manual Attack", function()
			local g = loadTargetGadget()
			g.set(10, false, shared)
			assert.are.equal(10, g.target())
			g.command(g.env.CMD.ATTACK, 30)
			g.set(11, true, shared)
			assert.are.equal(30, g.target())
			assert.are.equal(1, g.rules.hasPriorityTarget)
			assert.is_nil(g.env.GG.GetUnitTargetIndex(1))
			assert.are.equal(2, #g.env.GG.GetUnitTargetList(1))
		end)
	end

	it("keeps Cancel Target available while paused and clears it on cancellation", function()
		local g = loadTargetGadget()
		g.command(g.env.CMD.WAIT)
		g.set(10)
		assert.are.equal(1, g.rules.hasPriorityTarget)
		g.env.gadget:AllowCommand(1, 1, 1, g.env.GameCMD.UNIT_CANCEL_TARGET, {}, { coded = 0 }, 1, 1)
		assert.is_nil(g.rules.hasPriorityTarget)
		assert.is_nil(g.env.GG.GetUnitTargetList(1))
	end)
end)

describe("Set Target scan budgets", function()
	it("bounds shared validation on slow frames and eventually visits every list", function()
		local g = loadTargetGadget(40)
		g.command(g.env.CMD.WAIT)
		for unitID = 1, 40 do
			local targets = {}
			for index = 1, 300 do
				targets[index] = unitID * 1000 + index
			end
			g.set(targets, false, true, unitID)
		end
		local seen = {}
		for frame = 15, 18 do
			g.update(frame)
			assert.is_true(#g.trackingChecks <= 8192)
			for _, targetID in ipairs(g.trackingChecks) do
				seen[targetID] = true
			end
		end
		for unitID = 1, 40 do
			for index = 1, 300 do
				assert.is_true(seen[unitID * 1000 + index])
			end
		end
	end)

	it("continues acquiring targets on slow-update frames", function()
		local g = loadTargetGadget()
		g.canTarget(function()
			return false
		end)
		g.set(1000, false, true)
		g.canTarget(function()
			return true
		end)
		g.update(15)
		assert.are.equal(1000, g.target())
		assert.same({ 1000 }, g.checks)
	end)

	it("batches transferred targets without rebuilding shared lists in transfer callbacks", function()
		local teams = {}
		local g = loadTargetGadget(80, teams)
		local targets = {}
		for index = 1, 600 do
			targets[index] = 1000 + index
		end
		for unitID = 1, 80 do
			g.set(targets, false, true, unitID)
		end
		local originalID = g.env.GG.GetUnitTargetListID(1)
		for targetID = 1001, 1200 do
			teams[targetID] = 1
			g.env.gadget:UnitGiven(targetID, 1, 1)
		end
		assert.are.equal(originalID, g.env.GG.GetUnitTargetListID(1))
		for frame = 1, 3 do
			g.update(frame)
		end
		for unitID = 1, 80 do
			assert.are.equal(400, #g.env.GG.GetUnitTargetList(unitID))
			assert.are.equal(1201, g.targetsByUnit[unitID])
			assert.are.equal(g.env.GG.GetUnitTargetListID(1), g.env.GG.GetUnitTargetListID(unitID))
		end
	end)

	it("retires every empty list despite validation-queue removals", function()
		local g = loadTargetGadget(4)
		for sourceID = 4, 1, -1 do
			g.set(1000 + sourceID, false, true, sourceID)
		end
		for targetID = 1001, 1004 do
			g.deadTargets[targetID] = true
		end
		g.update(15)
		table.sort(g.released)
		assert.same({ 1, 2, 3, 4 }, g.released)
		for sourceID = 1, 4 do
			assert.is_nil(g.env.GG.GetUnitTargetList(sourceID))
		end
	end)

	it("does not exhaust the frame budget on already acquired first targets", function()
		local g = loadTargetGadget(400)
		local targets = {}
		for i = 1, 128 do
			targets[i] = 1000 + i
		end
		for sourceID = 1, 400 do
			g.set(targets, false, true, sourceID)
		end
		g.update(1)
		assert.is_true(#g.checks > 64, "the old 128-entry sweeps stop after 64 units")
		assert.is_true(#g.checks <= 80)
		for _, targetID in ipairs(g.checks) do
			assert.are.equal(1001, targetID)
		end
	end)

	it("switches to the next attackable target in the same update", function()
		local g = loadTargetGadget()
		g.set({ 10, 20, 30 }, false, true)
		assert.are.equal(10, g.target())
		g.canTarget(function(targetID)
			return targetID ~= 10
		end)
		g.update(1)
		assert.are.equal(20, g.target())
		assert.same({ 10, 20 }, g.checks)
	end)

	it("restores an unchanged Set Target after the engine replaces its weapon target", function()
		local g = loadTargetGadget()
		g.set(10)
		assert.are.equal(10, g.target())
		-- Simulate automatic engine targeting between gadget updates.
		g.env.Spring.SetUnitTarget(1, 20)
		g.update(1)
		assert.are.equal(10, g.target())
	end)

	it("checks a single target only once per update", function()
		local g = loadTargetGadget()
		g.set(10, false, true)
		g.update(1)
		assert.same({ 10 }, g.checks)
		assert.are.equal(10, g.target())
	end)

	it("checks every short-list entry at most once, including unavailable weapon targets", function()
		local g = loadTargetGadget()
		g.canTarget(function()
			return false
		end)
		g.set({ 10, 20, 30 }, false, true)
		g.update(1)
		assert.same({ 10, 20, 30 }, g.checks)
		g.canTarget(function(targetID)
			return targetID == 20
		end)
		g.update(2)
		assert.same({ 10, 20 }, g.checks)
		assert.are.equal(20, g.target())
	end)

	it("stops at the first attackable target even in a long list", function()
		local g = loadTargetGadget()
		local targets = {}
		for i = 1, 300 do
			targets[i] = 1000 + i
		end
		g.set(targets, false, true)
		g.update(1)
		assert.are.equal(1001, g.target())
		g.update(2)
		assert.same({ 1001 }, g.checks)
		assert.are.equal(1001, g.target())
	end)

	it("shares validation removals with every owner before resuming target acquisition", function()
		local g = loadTargetGadget(80)
		for unitID = 1, 80 do
			g.set({ 1000, 1001 }, false, true, unitID)
		end
		local originalID = g.env.GG.GetUnitTargetListID(80)
		g.deadTargets[1000] = true
		g.update(1)
		local reducedID = g.env.GG.GetUnitTargetListID(1)
		assert.are_not.equal(originalID, reducedID)
		for unitID = 1, 80 do
			assert.are.equal(reducedID, g.env.GG.GetUnitTargetListID(unitID))
			assert.are.equal(1001, g.env.GG.GetUnitTargetList(unitID)[1].target)
		end
		g.update(2)
		g.update(3)
		for unitID = 1, 80 do
			assert.are.equal(reducedID, g.env.GG.GetUnitTargetListID(unitID))
		end
	end)

	it("continues a long scan across updates and eventually reacquires a higher-priority target", function()
		local g = loadTargetGadget()
		local targets = {}
		for i = 1, 300 do
			targets[i] = 1000 + i
		end
		g.canTarget(function(targetID)
			return targetID == 1300
		end)
		g.set(targets, false, true)
		for frame = 1, 3 do
			g.update(frame)
			assert.are.equal(frame < 3 and 128 or 44, #g.checks)
			local seen = {}
			for _, targetID in ipairs(g.checks) do
				assert.is_nil(seen[targetID])
				seen[targetID] = true
			end
		end
		assert.are.equal(1300, g.target())
		g.canTarget(function(targetID)
			return targetID == 1001 or targetID == 1300
		end)
		for frame = 4, 6 do
			g.update(frame)
		end
		assert.are.equal(1001, g.target())
	end)
end)
