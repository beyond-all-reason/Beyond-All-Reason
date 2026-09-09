local function loadTargetGadget()
	local currentCommand
	local target
	local rules = {}
	local events = {}
	local checks = {}
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
			ATTACK_TARGETS = 1006,
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
				return unitID == 1 and 1 or 2
			end,
			GetUnitAllyTeam = function(unitID)
				return unitID == 1 and 1 or 2
			end,
			AreTeamsAllied = function(a, b)
				return a == b
			end,
			GetUnitIsDead = function()
				return false
			end,
			GetUnitLosState = function(unitID)
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
			SetUnitTarget = function(_, newTarget)
				target = newTarget
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
		canTarget = function(fn)
			canTarget = fn
		end,
		update = function(frame)
			for i = #checks, 1, -1 do
				checks[i] = nil
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
		set = function(targetID, append, shared)
			env.gadget:AllowCommand(
				1,
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
		assert.same({ 10, 20, 30 }, g.checks)
		assert.are.equal(20, g.target())
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
			assert.are.equal(128, #g.checks)
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
