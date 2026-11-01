local function loadQueue(enabled, coop)
	local units, rules, orders, destroyed = {}, {}, {}, {}
	local players = { [0] = { team = 0 }, [1] = { team = 0 } }
	local storage = { metal = 1000, energy = 1000 }
	local nextID, nextTag = 100, 1000
	local recycled = {}
	local env = setmetatable({
		gadget = {},
		Game = { allowPreGameCommands = enabled, mapSizeX = 4096, mapSizeZ = 4096 },
		CMD = { ANY = -1, STOP = 0, INSERT = 1, REMOVE = 2, OPT_SHIFT = 32 },
		GG = {
			coopMode = coop ~= false,
			playerStartingUnits = { [0] = 1, [1] = 1 },
			coopStartPoints = { [1] = { 1200, 0, 1300 } },
		},
		UnitDefNames = { armcom = { id = 1 }, dummycom = { id = 9 } },
		UnitDefs = {
			[3] = { name = "armmex" },
			[4] = { name = "cormex" },
			[1] = { name = "armcom", buildOptions = { 3 } },
			[2] = { name = "corcom", buildOptions = { 4 } },
		},
	}, { __index = _G })
	env.VFS = {
		Include = function(path)
			if path:find("mission_options") then
				return {
					IsStartUnitSpawnDisabled = function()
						return false
					end,
				}
			end
			return {
				getSideFromUnitName = function(name)
					return name:sub(1, 3)
				end,
				getEquivalentUnitDefID = function(id, side)
					return side == "cor" and id == 3 and 4 or side == "arm" and id == 4 and 3 or id
				end,
			}
		end,
	}
	env.gadgetHandler = {
		IsSyncedCode = function()
			return true
		end,
		RegisterAllowCommand = function() end,
		RemoveGadget = function()
			env.removed = true
		end,
	}
	env.Spring = {
		GetPlayerList = function()
			return { 0, 1 }
		end,
		GetPlayerInfo = function(id)
			return "player", true, players[id].spectator, players[id].team
		end,
		GetGameFrame = function()
			return 0
		end,
		GetModOptions = function()
			return {}
		end,
		GetTeamStartPosition = function()
			return 500, 0, 600
		end,
		GetGroundHeight = function()
			return 10
		end,
		GetTeamRulesParam = function(team, key)
			return rules[team .. key] or (key == "startUnit" and 1 or nil)
		end,
		SetTeamRulesParam = function(team, key, value)
			rules[team .. key] = value
		end,
		GetUnitDefID = function(id)
			return units[id].def
		end,
		GetUnitTeam = function(id)
			return units[id].team
		end,
		CreateUnit = function(def, x, y, z, facing, team, built, flatten, id, builder, skipStats)
			storage.metal, storage.energy = storage.metal + 1000, storage.energy + 1000
			nextID = nextID + 1
			local createdID = id or nextID
			if id then
				assert.is_true(recycled[id])
				recycled[id] = nil
			end
			assert.is_nil(units[createdID])
			units[createdID] = {
				def = def,
				team = team,
				x = x,
				z = z,
				skipStats = skipStats,
				storage = { metal = 1000, energy = 1000 },
				queue = {},
				rules = {},
			}
			return createdID
		end,
		SetUnitStorage = function(id, value)
			for resource, amount in pairs(value) do
				storage[resource] = storage[resource] - units[id].storage[resource] + amount
				units[id].storage[resource] = amount
			end
		end,
		SetUnitPosition = function(id, x, z)
			units[id].x, units[id].z = x, z
		end,
		SetUnitRulesParam = function(id, key, value)
			units[id].rules[key] = value
		end,
		GetUnitRulesParam = function(id, key)
			return units[id].rules[key]
		end,
		SetUnitBlocking = function() end,
		SetUnitNoDraw = function() end,
		SetUnitNoMinimap = function() end,
		GetUnitCommands = function(id)
			return units[id].queue
		end,
		GiveOrderToUnit = function(id, cmd, params, options)
			orders[#orders + 1] = { id, cmd, params, options }
			if cmd == 0 then
				units[id].queue = {}
			else
				nextTag = nextTag + 1
				units[id].queue = units[id].queue or {}
				table.insert(
					units[id].queue,
					{ id = cmd, params = params, tag = nextTag, options = { coded = options, shift = options >= 32 } }
				)
			end
		end,
		DestroyUnit = function(id, selfd, reclaimed, attacker, immediate)
			for resource, amount in pairs(units[id].storage) do
				storage[resource] = storage[resource] - amount
			end
			destroyed[id] = { selfd, reclaimed }
			recycled[id] = immediate
			if env.widget and env.widget.UnitDestroyed then
				env.widget:UnitDestroyed(id)
			end
			env.gadget:UnitDestroyed(id)
			units[id] = nil
		end,
		GetAllUnits = function()
			local ids = {}
			for id in pairs(units) do
				ids[#ids + 1] = id
			end
			return ids
		end,
	}
	env.Game.Commands = {
		ReissueOrder = function(id, cmd, params, options, tag, fromInsert)
			if fromInsert then
				local packed = { tag, cmd, options.coded }
				for _, value in ipairs(params) do
					packed[#packed + 1] = value
				end
				env.Spring.GiveOrderToUnit(id, env.CMD.INSERT, packed, fromInsert.coded)
			else
				env.Spring.GiveOrderToUnit(id, cmd, params, options.coded)
			end
		end,
	}
	setfenv(assert(loadfile("luarules/gadgets/game_pregame_queue.lua")), env)()
	env.gadget:Initialize()
	return env, units, rules, orders, destroyed, players, storage
end

local function buildQueue(unit)
	unit.queue = {
		{ id = -3, tag = 1, params = { 800, 0, 900, 0 }, options = { coded = 0 } },
		{ id = 10, tag = 2, params = { 1000, 0, 1100 }, options = { coded = 32, shift = true } },
	}
end

describe("Pregame engine queue lifecycle", function()
	it("updates position synchronously without waiting for a refresh message", function()
		local env, units, rules = loadQueue(true)
		local id = rules["0pregameQueue_0"]
		assert.equals(0, units[id].rules.pregame_positioned)
		env.GG.UpdatePregameQueuePosition(0, 1800, 1900)
		assert.equals(1800, units[id].x)
		assert.equals(1900, units[id].z)
		assert.equals(1, units[id].rules.pregame_positioned)
		env.gadget:RecvLuaMsg("pregameQueueRefresh", 0)
		assert.equals(1800, units[id].x)
		env.GG.UpdatePregameQueuePosition(0, 2000, 2100)
		assert.equals(2000, units[id].x)
	end)

	it("does not remove the real commander's storage after the GameStart reset", function()
		local env, units, rules, _, _, _, storage = loadQueue(true)
		assert.same({ metal = 1000, energy = 1000 }, storage)
		env.GG.playerStartingUnits[0] = 2
		env.gadget:RecvLuaMsg("pregameQueueRefresh", 0)
		assert.same({ metal = 1000, energy = 1000 }, storage)
		env.gadget:GameStart()
		env.GG.CreatePregameStartUnit(0, 2, 500, 10, 600, 0, 0)
		-- Team Resourcing assigns absolute team storage at GameStart.
		storage.metal, storage.energy = 1000, 1000
		env.gadget:GameFrame(1)
		assert.same({ metal = 1000, energy = 1000 }, storage)
	end)

	it("does nothing without the engine opt-in", function()
		local env, units = loadQueue(false)
		assert.is_true(env.removed)
		assert.same({}, units)
	end)

	it("uses player-specific coop positions and excludes temporary units from statistics", function()
		local _, units, rules = loadQueue(true)
		assert.equals(500, units[rules["0pregameQueue_0"]].x)
		assert.equals(1200, units[rules["0pregameQueue_1"]].x)
		assert.is_true(units[rules["0pregameQueue_0"]].skipStats)
	end)

	it("allows only the owner or synced Lua to command a proxy", function()
		local env, _, rules = loadQueue(true)
		local id = rules["0pregameQueue_0"]
		assert.is_true(env.gadget:AllowCommand(id, 1, 0, 10, {}, {}, 0, 0, false))
		assert.is_false(env.gadget:AllowCommand(id, 1, 0, 10, {}, {}, 0, 1, false))
		-- LuaUI AINetOrder is synced too; only synced Lua itself may bypass ownership.
		assert.is_false(env.gadget:AllowCommand(id, 1, 0, 10, {}, {}, 0, 1, true, false))
		assert.is_true(env.gadget:AllowCommand(id, 1, 0, 10, {}, {}, 0, 1, true, true))
	end)

	it("translates builds on faction replacement while retaining moves and shift options", function()
		local env, units, rules, orders, destroyed = loadQueue(true)
		local old = rules["0pregameQueue_0"]
		buildQueue(units[old])
		env.GG.playerStartingUnits[0] = 2
		env.gadget:RecvLuaMsg("pregameQueueRefresh", 0)
		local replacement = rules["0pregameQueue_0"]
		assert.equals(old, replacement)
		assert.same({ replacement, -4, { 800, 0, 900, 0 }, 32 }, orders[1])
		assert.equals(10, orders[2][2])
		assert.same({ false, true }, destroyed[old])
	end)

	it("keeps the selected preview for Random and translates on spawn, including coop", function()
		local env, units, rules, orders, destroyed = loadQueue(true)
		local old = rules["0pregameQueue_0"]
		buildQueue(units[old])
		buildQueue(units[rules["0pregameQueue_1"]])
		env.GG.playerStartingUnits[0] = 9
		env.gadget:RecvLuaMsg("pregameQueueRefresh", 0)
		assert.equals(old, rules["0pregameQueue_0"])
		env.gadget:GameStart()
		local coopID = rules["0pregameQueue_1"]
		assert.equals(old, env.GG.CreatePregameStartUnit(0, 2, 500, 10, 600, 0, 0))
		assert.equals(coopID, env.GG.CreatePregameStartUnit(1, 1, 1200, 10, 1300, 0, 0))
		env.gadget:GameFrame(1)
		assert.equals(old, rules["0pregameQueueTarget_0"])
		assert.equals(coopID, rules["0pregameQueueTarget_1"])
		assert.equals(4, #orders)
		for _, order in ipairs(orders) do
			if order[2] < 0 then
				assert.equals(order[1] == old and -4 or -3, order[2])
			end
		end
		assert.is_not_nil(destroyed[old])
		assert.equals(-1, rules["0pregameQueue_0"])
	end)

	it("recreates a proxy on team changes and removes it for spectators", function()
		local env, units, rules, _, _, players = loadQueue(true)
		players[0].team = 2
		env.gadget:RecvLuaMsg("pregameQueueRefresh", 0)
		assert.equals(-1, rules["0pregameQueue_0"])
		assert.equals(2, units[rules["2pregameQueue_0"]].team)
		players[0].spectator = true
		env.gadget:RecvLuaMsg("pregameQueueRefresh", 0)
		assert.equals(-1, rules["2pregameQueue_0"])
	end)
end)

describe("Shared pregame engine queues", function()
	it("publishes one queue per team, permits both players, and transfers it only once", function()
		local env, units, rules, orders = loadQueue(true, false)
		local id = rules["0pregameQueue_0"]
		assert.equals(id, rules["0pregameQueue_1"])
		for player = 0, 1 do
			assert.is_true(env.gadget:AllowCommand(id, 1, 0, 10, {}, {}, 0, player, true, false))
		end
		buildQueue(units[id])
		env.GG.UpdatePregameQueuePosition(1, 1800, 1900)
		env.gadget:RecvLuaMsg("pregameQueueRefresh", 0)
		assert.equals(1800, units[id].x)
		rules["0startUnit"] = 2
		env.gadget:RecvLuaMsg("pregameQueueRefresh", 1)
		id = rules["0pregameQueue_0"]
		assert.equals(id, rules["0pregameQueue_1"])
		assert.equals(2, units[id].def)
		assert.equals(-4, units[id].queue[1].id)
		env.gadget:GameStart()
		assert.equals(id, env.GG.CreatePregameStartUnit(0, 2, 500, 10, 600, 0, 0))
		env.gadget:GameFrame(1)
		assert.equals(id, rules["0pregameQueueTarget_0"])
		assert.equals(id, rules["0pregameQueueTarget_1"])
		assert.equals(2, #units[id].queue)
		assert.equals(4, #orders)
	end)

	it("keeps the shared queue when one player leaves the team", function()
		local env, units, rules, _, destroyed, players = loadQueue(true, false)
		local id = rules["0pregameQueue_0"]
		buildQueue(units[id])
		players[0].team = 2
		env.gadget:RecvLuaMsg("pregameQueueRefresh", 0)
		assert.is_nil(destroyed[id])
		assert.equals(id, rules["0pregameQueue_1"])
		assert.equals(2, #units[id].queue)
		assert.equals(-1, rules["0pregameQueue_0"])
	end)
end)

local function loadAdapter(env, rules)
	env.widget, env.WG = {}, {}
	env.widgetHandler = { RemoveWidget = function() end }
	env.Spring.GetSpectatingState = function()
		return false
	end
	env.Spring.GetMyPlayerID = function()
		return 0
	end
	env.Spring.GetMyTeamID = function()
		return 0
	end
	env.Spring.ValidUnitID = function()
		return true
	end
	env.Spring.SetUnitCommandDrawStart = function() end
	env.Spring.GetActiveCommand = function() end
	env.Spring.SelectUnitArray = function() end
	local pending
	env.Spring.SendLuaRulesMsg = function(message)
		pending = message
	end
	setfenv(assert(loadfile("luaui/Widgets/gui_pregame_queue.lua")), env)()
	env.widget:Initialize()
	env.widget:Update(0)
	return env.WG.pregameQueue, function()
		env.gadget:RecvLuaMsg(pending, 0)
	end
end

describe("Quick Start engine queue metadata", function()
	it("round-trips generated builds through JSON and command tags, including faction replacement", function()
		local env, units, rules = loadQueue(true)
		local adapter, deliver = loadAdapter(env, rules)
		adapter.setBuildQueue({ { 3, 800, 0, 900, 0, quickStartGenerated = true }, { -10, 1000, 0, 1100 } })
		assert.equals(0, #adapter.getBuildQueue()) -- no local shadow queue while the request is in flight
		deliver()
		local queue = adapter.getBuildQueue()
		assert.is_true(queue[1].quickStartGenerated)
		assert.is_false(queue[2].quickStartGenerated)
		env.GG.playerStartingUnits[0] = 2
		env.gadget:RecvLuaMsg("pregameQueueRefresh", 0)
		env.widget:Update(0)
		queue = adapter.getBuildQueue()
		assert.equals(4, queue[1][1])
		assert.is_true(queue[1].quickStartGenerated)
		adapter.setBuildQueue({ queue[2] }) -- clearing suggestions preserves the manual move
		deliver()
		assert.equals(1, #adapter.getBuildQueue())
		adapter.setBuildQueue({ { 4, 800, 0, 900, 0 } }) -- manually requeue the same building
		deliver()
		assert.is_false(adapter.getBuildQueue()[1].quickStartGenerated)
	end)

	it("rejects malformed updates without clearing existing commands", function()
		local env, units, rules = loadQueue(true)
		local id = rules["0pregameQueue_0"]
		buildQueue(units[id])
		for _, payload in ipairs({ "{", "false", "[[42, false, 0]]", "[[-999, [], 0]]", "[[10, [1, false], 0]]" }) do
			env.gadget:RecvLuaMsg("pregameQueueSet:" .. payload, 0)
			assert.equals(2, #units[id].queue)
		end
	end)
end)

describe("Stable pregame unit IDs", function()
	it("translates late Cortex builds and inserted builds after switching to Armada", function()
		local env, units, rules, orders = loadQueue(true)
		local id = rules["0pregameQueue_0"]
		env.GG.playerStartingUnits[0] = 2
		env.gadget:RecvLuaMsg("pregameQueueRefresh", 0)
		env.GG.playerStartingUnits[0] = 1
		env.gadget:RecvLuaMsg("pregameQueueRefresh", 0)
		assert.equals(id, rules["0pregameQueue_0"])
		assert.equals(1, units[id].def)
		assert.is_false(env.gadget:AllowCommand(id, 1, 0, -4, { 800, 0, 900, 0 }, { coded = 32 }, 0, 0, true, false))
		assert.same({ id, -3, { 800, 0, 900, 0 }, 32 }, orders[#orders])
		assert.is_false(
			env.gadget:AllowCommand(
				id,
				1,
				0,
				-4,
				{ 1100, 0, 1200, 2 },
				{ coded = 32 },
				5,
				0,
				true,
				false,
				{ coded = 128, alt = true }
			)
		)
		assert.same({ id, 1, { 5, -3, 32, 1100, 0, 1200, 2 }, 128 }, orders[#orders])
		local before = #orders
		assert.is_false(env.gadget:AllowCommand(id, 1, 0, -4, {}, { coded = 32 }, 0, 1, true, false))
		assert.equals(before, #orders) -- another coop player cannot redirect orders into this queue
	end)

	it("keeps the ID and translates late builds after the real commander spawns", function()
		local env, units, rules, orders = loadQueue(true)
		local id = rules["0pregameQueue_0"]
		buildQueue(units[id])
		env.gadget:GameStart()
		assert.equals(id, env.GG.CreatePregameStartUnit(0, 2, 500, 10, 600, 0, 0))
		assert.is_nil(units[id].skipStats)
		assert.is_nil(units[id].rules.pregame_proxy)
		assert.equals(-4, units[id].queue[1].id)
		assert.is_false(env.gadget:AllowCommand(id, 2, 0, -3, { 800, 0, 900, 0 }, { coded = 32 }, 0, 0, true, false))
		assert.equals(-4, orders[#orders][2])
		env.gadget:UnitDestroyed(id)
		assert.is_true(env.gadget:AllowCommand(id, 2, 0, -3, {}, {}, 0, 0, true, false))
	end)
end)

describe("Queue tag generations", function()
	it("discards stale tag edits until that player acknowledges the current queue", function()
		local env, units, rules = loadQueue(true, false)
		local id = rules["0pregameQueue_0"]
		local old = units[id].rules.pregame_generation
		rules["0startUnit"] = 2
		env.gadget:RecvLuaMsg("pregameQueueRefresh", 0)
		local generation = units[id].rules.pregame_generation
		local function remove(player)
			return env.gadget:AllowCommand(id, 2, 0, 2, { 8 }, { coded = 0 }, 0, player, true, false)
		end
		assert.is_false(remove(0))
		env.gadget:RecvLuaMsg("pregameQueueAck:" .. id .. ":" .. old, 0)
		assert.is_false(remove(0))
		env.gadget:RecvLuaMsg("pregameQueueAck:" .. id .. ":" .. generation, 0)
		assert.is_true(remove(0))
		assert.is_false(remove(1)) -- shared controllers acknowledge independently
		assert.is_false(
			env.gadget:AllowCommand(id, 2, 0, 10, { 800, 0, 900 }, { coded = 32 }, 8, 1, true, false, { coded = 0 })
		)
		env.gadget:RecvLuaMsg("pregameQueueAck:" .. id .. ":" .. generation, 1)
		assert.is_true(remove(1))
	end)
end)

describe("Pregame builder selection", function()
	it("restores the faction blueprint after command descriptions rebuild, including GameStart", function()
		local env, _, rules = loadQueue(true)
		loadAdapter(env, rules)
		local active
		env.Spring.GetCmdDescIndex = function(command)
			return command
		end
		env.Spring.SetActiveCommand = function(command)
			active = command
		end
		env.widget:ActiveCommandChanged(-3)
		env.GG.playerStartingUnits[0] = 2
		env.gadget:RecvLuaMsg("pregameQueueRefresh", 0)
		env.widget:Update(0)
		assert.is_nil(active)
		env.widget:Update(0)
		assert.equals(-4, active)
		env.Spring.GetActiveCommand = function()
			return 1, active
		end
		env.gadget:GameStart()
		env.GG.CreatePregameStartUnit(0, 1, 500, 10, 600, 0, 0)
		active = nil
		env.widget:GameStart()
		env.widget:Update(0)
		env.widget:Update(0)
		assert.equals(-3, active)
	end)
end)

describe("Pregame queue reconnect acknowledgement", function()
	it("accepts fresh tag edits when LuaUI loads after GameStart", function()
		local env, _, rules = loadQueue(true)
		local id = rules["0pregameQueue_0"]
		env.gadget:GameStart()
		env.GG.CreatePregameStartUnit(0, 1, 500, 10, 600, 0, 0)
		assert.is_false(env.gadget:AllowCommand(id, 1, 0, 2, { 8 }, { coded = 0 }, 0, 0, true, false))
		env.Spring.GetGameFrame = function()
			return 30
		end
		local _, deliver = loadAdapter(env, rules)
		deliver()
		assert.is_true(env.gadget:AllowCommand(id, 1, 0, 2, { 8 }, { coded = 0 }, 0, 0, true, false))
	end)
end)
