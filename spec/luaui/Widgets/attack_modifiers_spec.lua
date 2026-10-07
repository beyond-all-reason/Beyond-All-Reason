local function loadWidgets(withWall, wallOnly)
	local orders = {}
	local targets = { 101, 102, 103, 104 }
	if withWall then
		targets[#targets + 1] = 900
	end
	local env = setmetatable({
		CMD = {
			STOP = 0,
			INSERT = 1,
			ATTACK = 20,
			CAPTURE = 130,
			GUARD = 25,
			REPAIR = 40,
			RECLAIM = 90,
			LOAD_UNITS = 75,
			RESURRECT = 125,
			OPT_SHIFT = 32,
			OPT_CTRL = 64,
			OPT_ALT = 128,
			OPT_RIGHT = 16,
			OPT_META = 4,
		},
		GameCMD = {
			UNIT_SET_TARGET = 34923,
			UNIT_SET_TARGET_NO_GROUND = 34922,
			UNIT_SET_TARGETS = 34926,
			UNIT_CANCEL_TARGET = 34924,
			ATTACK_TARGETS = 34927,
		},
		Game = { maxUnits = 32000 },
		UnitDefs = { { customParams = {} }, { customParams = { objectify = true } } },
	}, { __index = _G })
	local function position(id)
		return id, 0, 0
	end
	env.Spring = {
		ENEMY_UNITS = -4,
		ALLY_UNITS = -3,
		ALL_UNITS = -1,
		GetSelectedUnits = function()
			return { 1, 2 }
		end,
		GetUnitsInCylinder = function()
			return targets
		end,
		GetUnitDefID = function(id)
			return id == 900 and 2 or 1
		end,
		GetUnitNeutral = function(id)
			return id == 900
		end,
		GetUnitPosition = position,
		GetUnitViewPosition = position,
		GetUnitArrayCentroid = function(units)
			local x = 0
			for _, id in ipairs(units) do
				x = x + id
			end
			return x / #units, 0, 0
		end,
		WorldToScreenCoords = function(x, _, z)
			return x, z
		end,
		TraceScreenRay = function()
			return "unit", 101
		end,
		GetUnitAllyTeam = function()
			return 2
		end,
		GetUnitTeam = function()
			return 2
		end,
		GetLocalAllyTeamID = function()
			return 1
		end,
		GetSpectatingState = function()
			return false
		end,
		GiveOrderArrayToUnitArray = function(units, commands)
			for _, cmd in ipairs(commands) do
				orders[#orders + 1] = { units = units, id = cmd[1], params = cmd[2], opts = cmd[3] }
			end
		end,
		GiveOrderToUnitArray = function(units, id, params, opts)
			orders[#orders + 1] = { units = units, id = id, params = params, opts = opts }
		end,
	}
	env.VFS = {
		Include = function(path)
			local chunk = assert(loadfile(path))
			setfenv(chunk, env)
			return chunk()
		end,
	}
	local widgets = {}
	for _, name in ipairs({ "cmd_exclude_walls_area_attacks", "cmd_area_commands_filter" }) do
		env.widget = {}
		env.VFS.Include("luaui/Widgets/" .. name .. ".lua")
		widgets[#widgets + 1] = env.widget
		if env.widget.Initialize then
			env.widget:Initialize()
		end
	end
	table.sort(widgets, function(a, b)
		return a:GetInfo().layer < b:GetInfo().layer
	end)
	return env,
		orders,
		function(params, options)
			for _, widget in ipairs(widgets) do
				if
					(not wallOnly or widget:GetInfo().name == "Exclude walls from area attacks")
					and widget:CommandNotify(env.CMD.ATTACK, params, options)
				then
					return true
				end
			end
			return false
		end
end

local function has(options, flag)
	return math.floor(options / flag) % 2 == 1
end

describe("Attack modifiers through area widgets", function()
	for mask = 0, 31 do
		for _, path in ipairs({ "area", "chain", "wall fallback" }) do
			local withWall = path ~= "area"
			it("preserves queues and target distribution, modifier mask " .. mask .. ", path " .. path, function()
				local env, orders, notify = loadWidgets(withWall, path == "wall fallback")
				local options = {
					shift = has(mask, 1),
					meta = has(mask, 2),
					right = has(mask, 4),
					ctrl = has(mask, 8),
					alt = has(mask, 16),
				}
				assert.is_true(notify({ 101, 0, 0, 1000 }, options))
				local queues = { { 999 }, { 999 } }
				for _, order in ipairs(orders) do
					local inserted = order.id == env.CMD.INSERT
					assert.are.equal(options.meta and not options.shift, inserted)
					local opts = inserted and order.params[3] or order.opts
					assert.are.equal(options.right, has(opts, env.CMD.OPT_RIGHT))
					assert.are.equal(options.ctrl, has(opts, env.CMD.OPT_CTRL))
					assert.are.equal(options.alt, has(opts, env.CMD.OPT_ALT))
					if inserted then
						-- RIGHT on the outer INSERT would replace an existing queue entry.
						assert.are.equal(env.CMD.OPT_ALT, order.opts)
					end
					local cmdID = inserted and order.params[2] or order.id
					assert.is_true(cmdID == env.CMD.ATTACK or cmdID == env.GameCMD.ATTACK_TARGETS)
					for _, unit in ipairs(order.units) do
						if not inserted and not has(opts, env.CMD.OPT_SHIFT) then
							queues[unit] = {}
						end
						local first = inserted and 4 or 1
						if inserted then
							for i = #order.params, first, -1 do
								table.insert(queues[unit], 1, order.params[i])
							end
						else
							for i = first, #order.params do
								table.insert(queues[unit], order.params[i])
							end
						end
					end
				end
				for unit = 1, 2 do
					local expected = options.shift and options.meta and (unit == 1 and { 101, 103 } or { 102, 104 })
						or { 101, 102, 103, 104 }
					if options.shift then
						table.insert(expected, 1, 999)
					elseif options.meta then
						expected[#expected + 1] = 999
					end
					assert.same(expected, queues[unit])
				end
			end)
		end
		it("leaves default single-target and ground Attack to the normal command path, mask " .. mask, function()
			local _, orders, notify = loadWidgets(true)
			local options = {
				shift = has(mask, 1),
				meta = has(mask, 2),
				right = has(mask, 4),
				ctrl = has(mask, 8),
				alt = has(mask, 16),
			}
			assert.is_false(notify({ 101 }, options))
			assert.is_false(notify({ 101, 0, 0 }, options))
			assert.same({}, orders)
		end)
	end
end)
