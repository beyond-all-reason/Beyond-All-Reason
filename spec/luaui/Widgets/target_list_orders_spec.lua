local function loadCommands()
	---@type table<string, any>
	local env = setmetatable({
		CMD = { ATTACK = 20, INSERT = 1, STOP = 0, OPT_SHIFT = 32, OPT_CTRL = 64, OPT_META = 4, OPT_ALT = 128 },
		GameCMD = {
			ATTACK_TARGETS = 34927,
			UNIT_SET_TARGETS = 34926,
			UNIT_SET_TARGET = 34923,
			UNIT_CANCEL_TARGET = 34924,
		},
	}, { __index = _G })
	env.VFS = {
		Include = function(path)
			local chunk = assert(loadfile(path))
			setfenv(chunk, env)
			return chunk()
		end,
	}
	return env, env.VFS.Include("common/luaUtilities/target_list_orders.lua")
end

local function sequence(count, offset)
	local ids = {}
	for i = 1, count do
		ids[i] = (offset or 0) + i
	end
	return ids
end

local function collector()
	local orders = {}
	return orders,
		function(units, commandID, params, options)
			assert.is_true(17 + 2 * #units + 4 * #params <= 8192, "command exceeds NETMSG_AICOMMANDS limit")
			orders[#orders + 1] = { units = units, id = commandID, params = params, options = options }
		end
end

local function assertDelivery(orders, sources, targets, commandID, options, cmd)
	local counts, reconstructed = {}, {}
	for _, order in ipairs(orders) do
		local firstParam = options.meta and 4 or 1
		assert.are.equal(options.meta and cmd.INSERT or commandID, order.id)
		local targetCount = #order.params - firstParam + 1
		for _, unitID in ipairs(order.units) do
			counts[unitID] = (counts[unitID] or 0) + targetCount
		end
		if order.units[1] == sources[1] then
			if options.meta then
				assert.are.equal(0, order.params[1])
				assert.are.equal(commandID, order.params[2])
				assert.are.equal(cmd.OPT_ALT, order.options)
				for i = #order.params, firstParam, -1 do
					table.insert(reconstructed, 1, order.params[i])
				end
			else
				assert.are.equal((#reconstructed > 0 or options.shift) and cmd.OPT_SHIFT or 0, order.options)
				for i = firstParam, #order.params do
					reconstructed[#reconstructed + 1] = order.params[i]
				end
			end
		end
	end
	for _, unitID in ipairs(sources) do
		assert.are.equal(#targets, counts[unitID])
	end
	assert.same(targets, reconstructed)
end

describe("target-list packet delivery", function()
	for _, commandName in ipairs({ "ATTACK_TARGETS", "UNIT_SET_TARGETS" }) do
		for _, operation in ipairs({ "replace", "append", "prepend" }) do
			it(
				"preserves " .. commandName .. " order during " .. operation .. " across source and target batches",
				function()
					local env, send = loadCommands()
					local sources, targets = sequence(300), sequence(4000, 10000)
					local options = { shift = operation == "append", meta = operation == "prepend", coded = 0 }
					local orders, emit = collector()
					assert.is_true(send(env.GameCMD[commandName], sources, targets, options, emit))
					assert.is_true(#orders > 2)
					assertDelivery(orders, sources, targets, env.GameCMD[commandName], options, env.CMD)
				end
			)
		end
	end

	it("leaves empty target selections to the caller", function()
		local env, send = loadCommands()
		local orders, emit = collector()
		assert.is_false(send(env.GameCMD.ATTACK_TARGETS, { 1 }, {}, {}, emit))
		assert.are.equal(0, #orders)
	end)
end)

describe("wall-filter target-list delivery", function()
	for _, operation in ipairs({ "replace", "append", "prepend" }) do
		it("splits the 1200-attacker wall-filter order during " .. operation, function()
			local env = loadCommands()
			local sources, targets = sequence(1200), sequence(1600, 10000)
			local area = sequence(1600, 10000)
			area[#area + 1] = 20000
			local orders, emit = collector()
			env.widget = {}
			env.UnitDefs = { { customParams = {} }, { customParams = { objectify = true } } }
			env.Spring = {
				GetUnitDefID = function(id)
					return id == 20000 and 2 or 1
				end,
				GetUnitNeutral = function(id)
					return id == 20000
				end,
				GetSelectedUnits = function()
					return sources
				end,
				GetUnitsInCylinder = function()
					return area
				end,
				GiveOrderToUnitArray = emit,
			}
			env.VFS.Include("luaui/Widgets/cmd_exclude_walls_area_attacks.lua")
			local options = { shift = operation == "append", meta = operation == "prepend", coded = 0 }
			assert.is_true(env.widget:CommandNotify(env.CMD.ATTACK, { 0, 0, 0, 1000 }, options))
			assert.is_true(#orders > 1)
			assertDelivery(orders, sources, targets, env.GameCMD.ATTACK_TARGETS, options, env.CMD)
		end)
	end
end)
