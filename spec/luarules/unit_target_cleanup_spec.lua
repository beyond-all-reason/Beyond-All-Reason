local function loadTargetGadget()
	local currentCommand
	local target
	local rules = {}
	local events = {}
	local checks = {}
	local deadTargets = {}
	local crashingTargets = {}
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
			GetUnitIsDead = function(unitID)
				return deadTargets[unitID] or false
			end,
			GetUnitLosState = function()
				return 3
			end,
			GetUnitMoveTypeData = function(unitID)
				return crashingTargets[unitID] and { aircraftState = "crashing" } or {}
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
		deadTargets = deadTargets,
		crashingTargets = crashingTargets,
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
		set = function(targetID, append)
			env.gadget:AllowCommand(
				1,
				1,
				1,
				env.GameCMD.UNIT_SET_TARGET,
				type(targetID) == "table" and targetID or { targetID },
				{ shift = append, coded = 0 },
				1,
				1
			)
		end,
	}
end

describe("Set Target invalid-target cleanup", function()
	for _, kind in ipairs({ "dead", "crashing" }) do
		it("skips a " .. kind .. " active target on the next selection update", function()
			local g = loadTargetGadget()
			g.set(10)
			g.set(20, true)
			assert.are.equal(10, g.target())
			g[kind == "dead" and "deadTargets" or "crashingTargets"][10] = true
			-- TryTarget deliberately still succeeds: crashing aircraft can remain targetable.
			g.update(1)
			assert.are.equal(20, g.target())
			assert.same({ 20 }, g.checks)
			assert.are.equal(1, #g.env.GG.GetUnitTargetList(1))
		end)

		it("rejects a new " .. kind .. " target", function()
			local g = loadTargetGadget()
			g[kind == "dead" and "deadTargets" or "crashingTargets"][10] = true
			g.set(10)
			assert.is_nil(g.target())
			assert.is_nil(g.env.GG.GetUnitTargetList(1))
		end)

		it("cleans up a " .. kind .. " target while Set Target is paused", function()
			local g = loadTargetGadget()
			g.set(10)
			g.command(g.env.CMD.WAIT)
			g.update(15)
			assert.are.equal(1, g.rules.hasPriorityTarget)
			g[kind == "dead" and "deadTargets" or "crashingTargets"][10] = true
			g.update(30)
			assert.is_nil(g.rules.hasPriorityTarget)
		end)
	end

	it("clears the assignment when its last target starts crashing", function()
		local g = loadTargetGadget()
		g.set(10)
		g.crashingTargets[10] = true
		g.update(1)
		assert.is_nil(g.target())
		assert.is_nil(g.env.GG.GetUnitTargetList(1))
	end)
end)
