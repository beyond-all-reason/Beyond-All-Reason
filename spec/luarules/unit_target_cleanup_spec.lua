local function loadTargetGadget()
	local currentCommand
	local target
	local rules = {}
	local events = {}
	local checks = {}
	local assigned = {}
	local deadTargets = {}
	local crashingTargets = {}
	local canTarget = function(_targetID)
		return true
	end
	local env = {
		gadget = {},
		GG = { Crashing = crashingTargets },
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
			InsertUnitCmdDesc = function() end,
			ValidUnitID = function()
				return true
			end,
			GetUnitDefID = function()
				return 1
			end,
			GetUnitTeam = function(unitID)
				return unitID <= 2 and 1 or 2
			end,
			GetUnitAllyTeam = function(unitID)
				return unitID <= 2 and 1 or 2
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
			GetUnitMoveTypeData = function()
				error("target selection must not allocate movement data")
			end,
			GetUnitWeaponTryTarget = function(_, _, targetID)
				checks[#checks + 1] = targetID
				return canTarget(targetID)
			end,
			GetUnitWeaponTestRange = function()
				return true
			end,
			GetUnitWeaponHaveFreeLineOfFire = function()
				return true
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
			SetUnitTarget = function(owner, newTarget)
				assigned[owner] = newTarget
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
		assigned = assigned,
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

describe("Set Target ghost transitions", function()
	local function observer()
		local g = loadTargetGadget()
		local contact
		g.env.Spring.GetGhostPosition = function(_, allyTeam)
			if allyTeam == 1 then
				return 15, 80, 30, contact
			end
		end
		return g,
			function(visible)
				contact = visible and 10 or nil
				local callback = visible and g.env.gadget.UnitEnteredRadar or g.env.gadget.UnitLeftLos
				callback(g.env.gadget, 10, 2, 1, 1, 1, 1048576)
			end
	end

	it("updates the builder and its product independently at each contact transition", function()
		local g, update = observer()
		g.set(10)
		g.env.gadget:UnitCreated(2, 1, 1, 1)
		for _, visible in ipairs({ false, true, false }) do
			update(visible)
			for _, id in ipairs({ 1, 2 }) do
				local list = g.env.GG.GetUnitTargetList(id)
				assert.same(visible and 10 or { 15, 80, 30 }, list[1].target)
				assert.equals(visible and 10 or 15, g.assigned[id])
			end
		end
		g.env.gadget:UnitCreated(3, 1, 2, 1)
		assert.is_nil(g.env.GG.GetUnitTargetList(3))
	end)

	it("keeps the first priority slot when a ghost resolves to an already listed unit", function()
		local g, update = observer()
		g.set(10)
		update(false)
		g.set(20, true)
		g.set(10, true)
		assert.equals(3, #g.env.GG.GetUnitTargetList(1))
		update(true)
		local list = g.env.GG.GetUnitTargetList(1)
		assert.equals(2, #list)
		assert.equals(10, list[1].target)
		assert.equals(20, list[2].target)
		g.set(10, true)
		assert.equals(2, #list)
	end)
end)

-- Load the real controller alongside the targeting gadget, sharing only GG.
local function loadCrashController(shared)
	local destroyed = {}
	local controller
	local spring = setmetatable({
		GetUnitHealth = function()
			return 100
		end,
		GetGameFrame = function()
			return 10
		end,
		GetUnitMoveTypeData = function()
			return {}
		end,
		MoveCtrl = {},
		DestroyUnit = function(id)
			destroyed[#destroyed + 1] = id
			controller:UnitDestroyed(id)
		end,
	}, {
		__index = function()
			return function() end
		end,
	})
	shared.UnitAttributes = {
		SetUnitAttribute = function() end,
		SetUnitModifier = function() end,
	}
	local env = setmetatable({
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
		},
		GG = shared,
		Spring = spring,
		COB = { CRASHING = 1 },
		CMD = { STOP = 0 },
		WeaponDefNames = { commanderexplosion = { id = 99 } },
		UnitDefs = { { id = 1, canFly = true, buildSpeed = 0, customParams = {}, weapons = {} } },
		SendToUnsynced = function() end,
	}, { __index = _G })
	local chunk = assert(loadfile("luarules/gadgets/unit_crashing_aircraft.lua"))
	setfenv(chunk, env)
	chunk()
	controller = env.gadget
	return controller, destroyed
end

describe("Shared crashing membership", function()
	it("publishes controller damage to an already loaded target consumer", function()
		local g = loadTargetGadget()
		g.set(10)
		g.set(20, true)
		local shared = g.env.GG.Crashing
		local controller = loadCrashController(g.env.GG)
		assert.is_true(shared == g.env.GG.Crashing)
		controller:UnitPreDamaged(10, 1, 2, 101, false, 1)
		assert.are.equal(460, shared[10])
		g.update(1)
		assert.are.equal(20, g.target())
		controller:UnitDestroyed(10)
		assert.is_nil(shared[10])
		-- Reusing the ID for a live unit must not retain crashing membership.
		g.set(10)
		assert.are.equal(10, g.env.GG.GetUnitTargetList(1)[1].target)
	end)

	it("lets later consumers acquire the same table and preserves deadlines on reload", function()
		local shared = {}
		local controller = loadCrashController(shared)
		controller:UnitPreDamaged(10, 1, 2, 101, false, 1)
		local membership = table.ensureTable(shared, "Crashing")
		assert.are.equal(460, membership[10])
		local reloaded, destroyed = loadCrashController(shared)
		assert.is_true(membership == shared.Crashing)
		reloaded:GameFrame(485)
		assert.same({ 10 }, destroyed)
		assert.is_nil(membership[10])
	end)

	it("does not publish nonlethal, paralyzing or excluded damage", function()
		local shared = {}
		local controller = loadCrashController(shared)
		controller:UnitPreDamaged(10, 1, 2, 50, false, 1)
		controller:UnitPreDamaged(11, 1, 2, 101, true, 1)
		controller:UnitPreDamaged(12, 1, 2, 101, false, 99)
		assert.same({}, shared.Crashing)
	end)
end)
