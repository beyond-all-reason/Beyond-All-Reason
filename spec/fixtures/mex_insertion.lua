-- Real widgets with deferred engine orders: issuing an order does not immediately
-- update GetUnitCommands, as in the networked game.
return function(pregame)
	local f = {
		frame = pregame and 0 or 100,
		shift = true,
		selected = pregame and {} or { 11 },
		actions = {},
		pending = {},
		queues = { [11] = {}, [12] = {}, [13] = {} },
		positions = { [11] = { 0, 0, 0 }, [12] = { 400, 0, 0 }, [13] = { 0, 0, 0 }, [21] = { 200, 0, 0 } },
		defs = { [11] = 1, [12] = 1, [13] = 3, [21] = 2 },
		start = { 0, 0, 0 },
		startDef = 1,
		widgets = {},
		spots = {},
	}
	local function noop() end
	local function copy(t)
		local r = {}
		for k, v in pairs(t) do
			r[k] = v
		end
		return r
	end
	local env = setmetatable({
		WG = {},
		Game = { maxUnits = 32000, extractorRadius = 8 },
		GameCMD = { AREA_MEX = 30100 },
		CMDTYPE = { ICON_AREA = 5 },
		LOG = { INFO = 1 },
		CMD = { MOVE = 10, GUARD = 25, INSERT = 1, OPT_ALT = 128, OPT_CTRL = 64, OPT_RIGHT = 16, OPT_SHIFT = 32 },
		UnitDefs = {
			[1] = { buildOptions = { 2 }, extractsMetal = 0, xsize = 2, zsize = 2, customParams = {} },
			[2] = {
				buildOptions = {},
				extractsMetal = 1,
				xsize = 2,
				zsize = 2,
				customParams = { standardextractor = true },
			},
			[3] = { buildOptions = { 4 }, extractsMetal = 0, xsize = 2, zsize = 2, customParams = {} },
			[4] = {
				buildOptions = {},
				extractsMetal = 2,
				xsize = 2,
				zsize = 2,
				customParams = { standardextractor = true },
			},
		},
		math = setmetatable({
			distance2dSquared = function(x, z, a, b)
				return (x - a) ^ 2 + (z - b) ^ 2
			end,
			getClosestPosition = function(_, _, positions)
				return positions[1]
			end,
		}, { __index = math }),
		table = setmetatable({
			copy = copy,
			map = function(t, fn)
				local r = {}
				for _, v in ipairs(t) do
					r[#r + 1] = fn(v)
				end
				return r
			end,
		}, { __index = table }),
	}, { __index = _G })
	env.require = function(path)
		if path == "luaui/Include/mission_options" then
			return {
				IsStartUnitSpawnDisabled = function()
					return false
				end,
			}
		end
		if path == "luaui/Include/blueprint_substitution/definitions" then
			return { unitCategories = {} }
		end
		if path == "luaui/Include/blueprint_substitution/logic" then
			return {
				getSideFromUnitName = function()
					return "arm"
				end,
				getEquivalentUnitDefID = function(id)
					return id
				end,
			}
		end
		local result = require(path)
		return result
	end
	local function give(id, cmd, params, opts)
		f.pending[#f.pending + 1] = { unit = id, id = cmd, params = copy(params), options = opts }
	end
	env.Spring = {
		GetGameFrame = function()
			return f.frame
		end,
		GetLocalTeamID = function()
			return 0
		end,
		GetSpectatingState = function()
			return false
		end,
		IsReplay = function()
			return false
		end,
		GetSelectedUnits = function()
			return f.selected
		end,
		GetTeamUnits = function()
			return { 11, 12, 13 }
		end,
		GetUnitDefID = function(id)
			return f.defs[id]
		end,
		GetUnitPosition = function(id)
			return unpack(f.positions[id])
		end,
		GetUnitCommands = function(id)
			return f.queues[id]
		end,
		GetUnitCommandCount = function(id)
			return #f.queues[id]
		end,
		GetUnitCurrentCommand = function(id, index)
			local c = f.queues[id][index]
			return c.id, 0, 0, unpack(c.params)
		end,
		GetModKeyState = function()
			return false, false, f.meta, f.shift
		end,
		GetTeamRulesParam = function()
			return f.startDef
		end,
		GetTeamStartPosition = function()
			return unpack(f.start)
		end,
		GetBuildFacing = function()
			return 0
		end,
		GetGroundHeight = function()
			return 0
		end,
		Pos2BuildPos = function(_, x, y, z)
			return x, y, z
		end,
		TestBuildOrder = function(_, x)
			return (f.blocked == x or f.terrainBlocked == x) and 0 or 1
		end,
		GetUnitsInCylinder = function(x)
			return f.occupied == x and { 21 } or {}
		end,
		GetUnitTeam = function()
			return 0
		end,
		AreTeamsAllied = function()
			return true
		end,
		GetUnitIsBeingBuilt = function()
			return false
		end,
		IsGUIHidden = function()
			return false
		end,
		GetMouseState = function()
			return 0, 0, false
		end,
		TraceScreenRay = function()
			return "ground", f.mouse or { 200, 0, 0 }
		end,
		GetMapDrawMode = function()
			return "normal"
		end,
		GiveOrderToUnit = give,
		GiveOrderArrayToUnitArray = function(ids, orders)
			for _, id in ipairs(ids) do
				for _, o in ipairs(orders) do
					give(id, o[1], o[2], o[3])
				end
			end
		end,
		GiveOrderToUnitArray = function(ids, cmd, params, opts)
			for _, id in ipairs(ids) do
				give(id, cmd, params, opts)
			end
		end,
		GiveOrder = function(cmd, params, opts)
			for _, id in ipairs(f.selected) do
				give(id, cmd, params, opts)
			end
		end,
		ForceLayoutUpdate = noop,
		SetActiveCommand = function(id)
			f.active = id == "areamex" and env.GameCMD.AREA_MEX or id
			return true
		end,
		GetActiveCommand = function()
			return 1, f.active
		end,
		GetCmdDescIndex = function(id)
			return id
		end,
		Log = noop,
		Echo = noop,
		SendCommands = noop,
	}
	env.WG.resource_spot_finder = {
		isMetalMap = false,
		metalSpotsList = f.spots,
		GetBuildingPositions = function(spot)
			return f.blocked == spot.x and {} or { spot }
		end,
	}
	function f:load(name)
		local e = setmetatable({ widget = {} }, { __index = env })
		e.widgetHandler = {
			customCommands = {},
			AddAction = function(_, name, fn, _, kind)
				local key = name .. kind
				self.actions[key] = self.actions[key] or {}
				table.insert(self.actions[key], fn)
			end,
			RegisterGlobal = noop,
			RemoveWidget = noop,
			RemoveAction = noop,
		}
		setfenv(assert(loadfile("luaui/Widgets/" .. name .. ".lua")), e)()
		local w = e.widget
		if w.Initialize then
			w:Initialize()
		end
		if w.SelectionChanged then
			w:SelectionChanged(self.selected)
		end
		self.widgets[name] = w
		return w, e
	end
	function f:modifier(kind, release)
		for _, fn in ipairs(self.actions["commandinsert" .. (release and "r" or "p")] or {}) do
			fn(nil, nil, { kind or "prepend_between" })
		end
	end
	function f:spot(x, worth)
		self.spots[#self.spots + 1] = { x = x, y = 0, z = 0, worth = worth or 1, isMex = true }
	end
	function f:area()
		local opts = { shift = self.shift, meta = self.meta }
		if self.widgets.cmd_commandinsert:CommandNotify(env.GameCMD.AREA_MEX, { 200, 0, 0, 1000 }, opts) then
			return
		end
		return self.widgets.cmd_area_mex:CommandNotify(env.GameCMD.AREA_MEX, { 200, 0, 0, 1000 }, opts)
	end
	function f:flush()
		for _, o in ipairs(self.pending) do
			local q = self.queues[o.unit]
			if o.id == env.CMD.INSERT then
				local p = o.params
				table.insert(q, math.min(p[1] + 1, #q + 1), { id = p[2], params = { unpack(p, 4) } })
			else
				local shift = o.options.shift
				for _, v in ipairs(o.options) do
					if v == "shift" then
						shift = true
					end
				end
				if not shift then
					q = {}
					self.queues[o.unit] = q
				end
				q[#q + 1] = { id = o.id, params = o.params }
			end
		end
		self.pending = {}
	end
	function f:expect(id, xs)
		local q = pregame and env.WG["pregame-build"].getBuildQueue() or self.queues[id]
		assert(#q == #xs, "queue length: expected " .. #xs .. ", got " .. #q)
		for i, x in ipairs(xs) do
			assert((pregame and q[i][2] or q[i].params[1]) == x, "wrong queue position " .. i)
		end
	end
	for id, def in pairs(env.UnitDefs) do
		def.name = "def" .. id
		def.cost = 100
		def.buildSpeed = 100
	end
	function f:select(ids)
		self.selected = ids
		for _, w in pairs(self.widgets) do
			if w.SelectionChanged then
				w:SelectionChanged(ids)
			end
		end
	end
	function f:split()
		self:load("api_build_orders")
		self:load("cmd_buildsplit")
		for _, fn in ipairs(self.actions.buildsplitp) do
			fn(nil, nil, nil, { true })
		end
	end
	f.env = env
	f:load("api_resource_spot_builder")
	f:load("cmd_commandinsert")
	if pregame then
		f:load("gui_pregame_build")
	end
	f:load("cmd_area_mex")
	return f
end
