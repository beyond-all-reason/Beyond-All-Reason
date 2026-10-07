local function loadTargetGadget(unitTeams, areaTargets)
	local currentCommand
	local target
	local rules = {}
	local events = {}
	local checks = {}
	local deadTargets = {}
	local crashingTargets = {}
	local losStates = {}
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
			GetUnitsInCylinder = function()
				return areaTargets or {}
			end,
			ValidUnitID = function()
				return true
			end,
			GetUnitDefID = function()
				return 1
			end,
			GetUnitTeam = function(unitID)
				return unitTeams and unitTeams[unitID] or (unitID == 1 and 1 or 2)
			end,
			GetUnitAllyTeam = function(unitID)
				return unitTeams and unitTeams[unitID] or (unitID == 1 and 1 or 2)
			end,
			AreTeamsAllied = function(a, b)
				return a == b
			end,
			GetUnitIsDead = function(unitID)
				return deadTargets[unitID] or false
			end,
			GetUnitLosState = function(unitID)
				return losStates[unitID] or 3
			end,
			GetUnitMoveTypeData = function()
				error("target selection must not allocate movement data")
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
		ensureTable = function(parent, key)
			parent[key] = parent[key] or {}
			return parent[key]
		end,
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
		losStates = losStates,
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
	it("preserves the legacy limit when replay commands append individual targets", function()
		local g = loadTargetGadget()
		for targetID = 10, 149 do
			g.set(targetID, true)
		end
		local targets = g.env.GG.GetUnitTargetList(1)
		assert.are.equal(128, #targets)
		assert.are.equal(10, targets[1].target)
		assert.are.equal(137, targets[128].target)
	end)

	it("allows compact Set Target commands to exceed the legacy limit", function()
		local g = loadTargetGadget()
		local targets = {}
		for targetID = 10, 149 do
			targets[#targets + 1] = targetID
		end
		g.env.gadget:AllowCommand(1, 1, 1, g.env.GameCMD.UNIT_SET_TARGETS, targets, { coded = 0 }, 1, 1)
		assert.are.equal(140, #g.env.GG.GetUnitTargetList(1))
	end)

	it("preserves the legacy limit for shifted area commands", function()
		local areaTargets = {}
		for targetID = 20, 149 do
			areaTargets[#areaTargets + 1] = targetID
		end
		local g = loadTargetGadget(nil, areaTargets)
		g.set(10)
		g.set({ 100, 0, 100, 100 }, true)
		local targets = g.env.GG.GetUnitTargetList(1)
		assert.are.equal(128, #targets)
		assert.are.equal(10, targets[1].target)
		assert.are.equal(146, targets[128].target)
	end)

	it("preserves unseen expiry when an area command appends several targets", function()
		local g = loadTargetGadget(nil, { 30, 40 })
		g.set(10)
		g.set(20, true)
		g.losStates[10] = 0
		g.canTarget(function(targetID)
			return targetID ~= 10
		end)
		g.update(15)
		g.set({ 100, 0, 100, 100 }, true)
		g.update(30)
		g.update(45)
		assert.are.equal(4, #g.env.GG.GetUnitTargetList(1))
		g.update(60)
		local targets = g.env.GG.GetUnitTargetList(1)
		assert.are.equal(3, #targets)
		assert.are.equal(20, targets[1].target)
	end)

	it("preserves unseen expiry when a single append detaches a shared list", function()
		local g = loadTargetGadget({ [2] = 1 })
		for unitID = 1, 2 do
			g.env.gadget:AllowCommand(unitID, 1, 1, g.env.GameCMD.UNIT_SET_TARGETS, { 10, 20 }, { coded = 0 }, 1, 1)
		end
		assert.are.equal(g.env.GG.GetUnitTargetListID(1), g.env.GG.GetUnitTargetListID(2))
		g.losStates[10] = 0
		g.canTarget(function(targetID)
			return targetID ~= 10
		end)
		g.update(15)
		g.set(30, true)
		g.update(30)
		g.update(45)
		g.update(60)
		assert.are.equal(2, #g.env.GG.GetUnitTargetList(1))
		assert.are.equal(20, g.env.GG.GetUnitTargetList(1)[1].target)
		assert.are.equal(1, #g.env.GG.GetUnitTargetList(2))
		assert.are.equal(20, g.env.GG.GetUnitTargetList(2)[1].target)
	end)

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

	it("keeps an unseen target's expiry when other entries die during selection", function()
		local g = loadTargetGadget()
		g.set(10)
		g.set(20, true)
		g.set(30, true)
		g.set(40, true)
		g.losStates[20] = 0
		g.canTarget(function(targetID)
			return targetID ~= 20
		end)
		g.update(15)
		g.deadTargets[10] = true
		g.update(16)
		g.update(30)
		g.deadTargets[30] = true
		g.update(31)
		g.update(45)
		assert.are.equal(2, #g.env.GG.GetUnitTargetList(1))
		g.update(60)
		assert.are.equal(1, #g.env.GG.GetUnitTargetList(1))
		assert.are.equal(40, g.env.GG.GetUnitTargetList(1)[1].target)
		g.losStates[20] = 3
		g.canTarget(function()
			return true
		end)
		g.update(61)
		assert.are.equal(40, g.target())
	end)

	it("does not shorten grace while both the source and reduced lists remain active", function()
		local g = loadTargetGadget({ [2] = 1 })
		for unitID = 1, 2 do
			g.env.gadget:AllowCommand(unitID, 1, 1, g.env.GameCMD.UNIT_SET_TARGETS, { 10, 20, 30 }, { coded = 0 }, 1, 1)
		end
		g.losStates[20] = 0
		g.canTarget(function(targetID)
			return targetID ~= 20
		end)
		g.update(15)
		g.env.gadget:AllowCommand(1, 1, 1, g.env.GameCMD.UNIT_CANCEL_TARGET, { 10 }, { coded = 0 }, 1, 1)
		g.update(30)
		g.update(45)
		assert.are.equal(2, #g.env.GG.GetUnitTargetList(1))
		assert.are.equal(3, #g.env.GG.GetUnitTargetList(2))
		g.update(60)
		assert.are.equal(1, #g.env.GG.GetUnitTargetList(1))
		assert.are.equal(2, #g.env.GG.GetUnitTargetList(2))
	end)

	it("clears the assignment when its last target starts crashing", function()
		local g = loadTargetGadget()
		g.set(10)
		g.crashingTargets[10] = true
		g.update(1)
		assert.is_nil(g.target())
		assert.is_nil(g.env.GG.GetUnitTargetList(1))
	end)
end)

local function loadTargetDrawing(synced, fullview)
	local actions, icons = {}, {}
	local function noop() end
	local env = setmetatable({
		gadget = {},
		GG = {},
		GameCMD = synced.env.GameCMD,
		CMD = synced.env.CMD,
		GL = { LINE_BITS = 1, LINE_STRIP = 2, LINES = 3 },
		gl = setmetatable({
			BeginEnd = function(_, fn, ...)
				fn(...)
			end,
		}, {
			__index = function()
				return noop
			end,
		}),
		gadgetHandler = {
			IsSyncedCode = function()
				return false
			end,
			AddChatAction = noop,
			AddSyncAction = function(_, name, fn)
				actions[name] = fn
			end,
		},
		Spring = setmetatable({
			GetLocalAllyTeamID = function()
				return 1
			end,
			GetLocalTeamID = function()
				return 1
			end,
			GetSpectatingState = function()
				return fullview, fullview
			end,
			GetUnitAllyTeam = function()
				return 1
			end,
			GetUnitTeam = function()
				return 1
			end,
			IsUnitSelected = function()
				return true
			end,
			ValidUnitID = function()
				return true
			end,
			GetUnitPosition = function(id)
				return id, 0, 0, id, 0, 0
			end,
			GetUnitWeaponTarget = function()
				return 1, true, 10
			end,
			AddWorldIcon = function(_, x)
				icons[x] = true
			end,
		}, {
			__index = function()
				return noop
			end,
		}),
		CallAsTeam = function(_, fn, ...)
			return fn(...)
		end,
	}, { __index = _G })
	local chunk = assert(loadfile("luarules/gadgets/unit_target_on_the_move.lua"))
	setfenv(chunk, env)
	chunk()
	env.gadget:Initialize()
	local nextEvent = 1
	return function()
		for i = nextEvent, #synced.events do
			local event = synced.events[i]
			if actions[event[1]] then
				actions[event[1]](unpack(event))
			end
		end
		nextEvent = #synced.events + 1
		icons = {}
		env.gadget:DrawWorld()
		return icons
	end
end

describe("Set Target drawing while shared-list removal is pending", function()
	for _, fullview in ipairs({ false, true }) do
		for _, kind in ipairs({ "dead", "crashing" }) do
			it("hides a " .. kind .. " queued target with fullview=" .. tostring(fullview), function()
				local g = loadTargetGadget()
				local draw = loadTargetDrawing(g, fullview)
				g.set(10)
				g.set(20, true)
				g.update(1)
				assert.is_true(draw()[20])
				g[kind == "dead" and "deadTargets" or "crashingTargets"][20] = true
				g.update(2)
				-- Selection stops at 10, so 20 is still physically present until the slow sweep.
				assert.are.equal(2, #g.env.GG.GetUnitTargetList(1))
				local icons = draw()
				assert.is_true(icons[10])
				assert.is_nil(icons[20])
			end)
		end
	end

	it("keeps unseen live targets visible to fullview, then hides them when they crash", function()
		local g = loadTargetGadget()
		local playerDraw, spectatorDraw = loadTargetDrawing(g, false), loadTargetDrawing(g, true)
		g.set(10)
		g.set(20, true)
		g.losStates[20] = 0
		g.update(1)
		assert.is_nil(playerDraw()[20])
		assert.is_true(spectatorDraw()[20])
		g.crashingTargets[20] = true
		g.update(2)
		assert.is_nil(spectatorDraw()[20])
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
