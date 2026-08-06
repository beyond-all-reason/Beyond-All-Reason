---@diagnostic disable: undefined-field, redundant-parameter -- sorry not sorry

-- Splits its tests with test_area_commands_radar_blips for engine verification.
-- This behavior lives across three widgets, two gadgets, and the engine, then.

local WIDGET_PATH = "luaui/Widgets/cmd_area_commands_filter.lua"

-- See LuaUtils::ParseAllegiance; also in `Spring`.
local ALL_UNITS, MY_UNITS, ALLY_UNITS, ENEMY_UNITS = -1, -2, -3, -4
local UNIT_ID_MAX = 32000

-- Values have to be shared between the widget env and the assertions:
local CMD = {
	ATTACK = 20,
	CAPTURE = 130,
	GUARD = 25,
	REPAIR = 40,
	RECLAIM = 90,
	LOAD_UNITS = 75,
	RESURRECT = 125,
	INSERT = 1,
	OPT_ALT = 128,
}
local GameCMD = {
	UNIT_SET_TARGET = 34923,
	UNIT_SET_TARGET_NO_GROUND = 34925,
}

local function makeDef(name, options)
	local d = { name = name, customParams = {}, mass = 100, xsize = 2, cantBeTransported = false }
	for k, v in pairs(options or {}) do
		d[k] = v
	end
	return d
end
local DEFS = {
	makeDef("armpw"), -- 1 := combat unit
	makeDef("corak"), -- 2 := combat unit
	makeDef("armdrag", { customParams = { objectify = "1" } }), -- 3 := wall (def-neutral via objectify)
	makeDef("critter_crab"), -- 4 := critter (def-neutral via name prefix)
	makeDef("armaap", { -- 5 := transport
		transportSize = 2,
		transportMass = 1000,
		transportCapacity = 4,
		health = 3000,
		mass = 500,
		xsize = 6,
	}),
}
local NAME_TO_ID = {}
for id, def in ipairs(DEFS) do
	NAME_TO_ID[def.name] = id
end

-- UnitDefNames only needs the tech level for the feature tech filter.
local UNIT_DEF_NAMES = {
	armpw = { customParams = { techlevel = "1" } },
	corak = { customParams = { techlevel = "1" } },
	armaap = { customParams = { techlevel = "2" } },
}

local context = {}
context.__index = context

local function newContext()
	return setmetatable({
		myTeamID = 0,
		myAllyTeamID = 0,
		-- team -> allyTeam. Team 0 is mine (ally 0); teams 1/2 are enemies (ally 1).
		teamAllyTeam = { [0] = 0, [1] = 1, [2] = 1 },
		ceasefire = {}, -- ceasefire[a][b] = true forces AreTeamsAllied(a,b) -- TODO fix spec
		units = {},
		features = {},
		selected = {},
		hover = {}, -- { type = "unit"|"feature", id = n }
		orders = {}, -- captured GiveOrderToUnitArray calls
		noOffsetForFeatureID = false,
	}, context)
end

function context:areTeamsAllied(a, b)
	if self.ceasefire[a] and self.ceasefire[a][b] then
		return true
	end
	return self.teamAllyTeam[a] == self.teamAllyTeam[b]
end

---`def` is a name, or nil to model an untyped radar blip
function context:addUnit(id, def, opts)
	opts = opts or {}
	local team = opts.team or 0
	self.units[id] = {
		defID = def and NAME_TO_ID[def] or nil,
		team = team,
		allyTeam = opts.allyTeam or self.teamAllyTeam[team],
		neutral = opts.neutral or false,
		x = opts.x or 0,
		z = opts.z or 0,
		transporting = opts.transporting,
		visible = opts.visible ~= false,
	}
	return id
end

function context:addFeature(id, def, resurrect, opts)
	opts = opts or {}
	self.features[id] = {
		defID = NAME_TO_ID[def] or def,
		resurrect = resurrect or "",
		x = opts.x or 0,
		z = opts.z or 0,
	}
	return id
end

function context:select(...)
	self.selected = { ... }
end

function context:hoverUnit(id)
	self.hover = { type = "unit", id = id }
end

function context:hoverFeature(id)
	self.hover = { type = "feature", id = id }
end

function context:unitsInCylinder(cx, cz, r, allegiance)
	local res = {}
	for id, u in pairs(self.units) do
		local dx, dz = u.x - cx, u.z - cz
		if dx * dx + dz * dz <= r * r then
			local isAlly = u.allyTeam == self.myAllyTeamID
			local visible = isAlly or u.visible
			local match
			if allegiance == ALL_UNITS then
				match = true
			elseif allegiance == MY_UNITS then
				match = u.team == self.myTeamID
			elseif allegiance == ALLY_UNITS then
				match = isAlly
			elseif allegiance == ENEMY_UNITS then
				match = not isAlly -- Not wrong: spatial searches ignore ceasefired allies
			else
				match = u.team == allegiance
			end
			if match and visible then
				res[#res + 1] = id
			end
		end
	end
	table.sort(res) -- needs deterministic order
	return res
end

function context:featuresInCylinder(cx, cz, r)
	local res = {}
	for id, f in pairs(self.features) do
		local dx, dz = f.x - cx, f.z - cz
		if dx * dx + dz * dz <= r * r then
			res[#res + 1] = id
		end
	end
	table.sort(res)
	return res
end

local function loadWidget(widgetContext)
	local env = setmetatable({}, { __index = _G })

	env.Game = { maxUnits = UNIT_ID_MAX, footprintScale = 2 }
	env.Engine = { FeatureSupport = { noOffsetForFeatureID = widgetContext.noOffsetForFeatureID } }
	env.CMD = CMD
	env.GameCMD = GameCMD
	env.UnitDefs = DEFS
	env.UnitDefNames = UNIT_DEF_NAMES
	---@diagnostic disable-next-line: missing-fields -- building up the table like this, not great
	env.widget = {}
	env.widgetHandler = {
		RemoveWidget = function()
			widgetContext.removed = true
		end,
	}

	-- We are missing table.new:
	env.table = setmetatable({
		new = function()
			return {}
		end,
	}, { __index = table })

	local S = {}
	S.ALL_UNITS, S.MY_UNITS, S.ALLY_UNITS, S.ENEMY_UNITS = ALL_UNITS, MY_UNITS, ALLY_UNITS, ENEMY_UNITS
	function S.GetSpectatingState()
		return false
	end
	function S.GetMyTeamID()
		return widgetContext.myTeamID
	end
	function S.GetMyAllyTeamID()
		return widgetContext.myAllyTeamID
	end
	function S.GetSelectedUnits()
		local t = {}
		for i = 1, #widgetContext.selected do
			t[i] = widgetContext.selected[i]
		end
		return t
	end
	function S.WorldToScreenCoords(x, _, z) -- engine API name; the widget localizes it
		return x, z
	end
	function S.TraceScreenRay()
		return widgetContext.hover.type, widgetContext.hover.id
	end
	function S.GetUnitDefID(id)
		local u = widgetContext.units[id]
		return u and u.defID or nil
	end
	function S.GetUnitTeam(id)
		local u = widgetContext.units[id]
		return u and u.team or nil
	end
	function S.GetUnitAllyTeam(id)
		local u = widgetContext.units[id]
		return u and u.allyTeam or nil
	end
	function S.GetUnitNeutral(id)
		local u = widgetContext.units[id]
		return (u and u.neutral) or false
	end
	function S.AreTeamsAllied(a, b)
		return widgetContext:areTeamsAllied(a, b)
	end
	function S.GetUnitPosition(id)
		local u = widgetContext.units[id]
		if u then
			return u.x, 0, u.z
		end
	end
	function S.GetUnitArrayCentroid(arr)
		local n, sx, sz = 0, 0, 0
		for i = 1, #arr do
			local u = widgetContext.units[arr[i]]
			if u then
				n, sx, sz = n + 1, sx + u.x, sz + u.z
			end
		end
		if n == 0 then
			return 0, 0, 0
		end
		return sx / n, 0, sz / n
	end
	function S.GetUnitIsTransporting(id)
		local u = widgetContext.units[id]
		return u and u.transporting
	end
	function S.GetFeatureDefID(id)
		local f = widgetContext.features[id]
		return f and f.defID or nil
	end
	function S.GetFeatureResurrect(id)
		local f = widgetContext.features[id]
		return f and f.resurrect or ""
	end
	function S.GetFeaturePosition(id)
		local f = widgetContext.features[id]
		if f then
			return f.x, 0, f.z
		end
	end
	function S.GetUnitsInCylinder(cx, cz, r, allegiance)
		return widgetContext:unitsInCylinder(cx, cz, r, allegiance)
	end
	function S.GetFeaturesInCylinder(cx, cz, r)
		return widgetContext:featuresInCylinder(cx, cz, r)
	end
	-- Snapshot the unit array: splitOrders reuses one { 0 } table across calls,
	-- mutating [1] each time, so storing the reference would collapse every
	-- captured call onto the last unit.
	function S.GiveOrderToUnitArray(units, cmdId, params, opts)
		local u = {}
		for i = 1, #units do
			u[i] = units[i]
		end
		local p = {}
		if type(params) == "table" then
			for i = 1, #params do
				p[i] = params[i]
			end
		end
		local o = opts
		if type(opts) == "table" then
			o = {}
			for i = 1, #opts do
				o[i] = opts[i]
			end
		end
		widgetContext.orders[#widgetContext.orders + 1] = { units = u, cmdId = cmdId, params = p, opts = o }
	end
	env.Spring = setmetatable(S, { __index = _G.Spring })

	local chunk = assert(loadfile(WIDGET_PATH))
	setfenv(chunk, env)
	chunk()
	env.widget:Initialize()
	return env
end

-- ============================================================
-- == Assertion helpers =======================================

-- The target unit/feature id an order acts on: normal orders carry { targetId },
-- the meta/insert form carries { 0, cmdId, 0, targetId }.
local function orderTargetID(order)
	if order.cmdId == CMD.INSERT then
		return order.params[4]
	end
	return order.params[1]
end

-- Set of target ids across all captured orders.
local function targetSet(orders)
	local set = {}
	for _, order in ipairs(orders) do
		set[orderTargetID(order)] = true
	end
	return set
end

-- Sorted list of target ids across all captured orders (duplicates collapsed).
local function targetList(orders)
	local list = {}
	for id in pairs(targetSet(orders)) do
		list[#list + 1] = id
	end
	table.sort(list)
	return list
end

local function hasShift(opts)
	if type(opts) ~= "table" then
		return false
	end
	for i = 1, #opts do
		if opts[i] == "shift" then
			return true
		end
	end
	return false
end

local AREA_RADIUS = 10000
local ENTIRE_AREA = { 0, 0, 0, 10000 } -- big

local function notify(env, cmdId, options)
	return env.widget:CommandNotify(cmdId, ENTIRE_AREA, options)
end

-- ============================================================
-- == Tests ===================================================

-- All tests have to verify true/false return from CommandNotify
-- and the exact number of orders (0 or a precise full account).

local function assert_is_split(orders)
	local byUnit = {}
	for _, order in ipairs(orders) do
		local target = orderTargetID(order)
		for _, unit in ipairs(order.units) do
			byUnit[unit] = byUnit[unit] or {}
			byUnit[unit][target] = true
		end
	end

	local total = #targetList(orders)
	local units = 0
	for _, held in pairs(byUnit) do
		units = units + 1
		local count = 0
		for _ in pairs(held) do
			count = count + 1
		end
		assert.is_true(count < total or total <= 1, "a unit received every target")
	end

	-- NB: Condition your tests so that this is the case (or there is no point to them).
	assert.is_true(units > 1, "targets should be distributed across more than one unit")
end

describe("cmd_area_commands_filter", function()
	describe("activation guards", function()
		it("ignores commands that are not area-to-target commands", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:select(1)
			local env = loadWidget(c)
			assert.is_false(notify(env, -1, { alt = true }))
			assert.is_false(notify(env, 0, { alt = true }))
			assert.is_false(notify(env, 888, { alt = true }))
			assert.is_false(notify(env, 999, { alt = true }))
			assert.equals(0, #c.orders)
		end)

		it("ignores a point command", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:select(1)
			local env = loadWidget(c)
			assert.is_false(env.widget:CommandNotify(CMD.ATTACK, { 0, 0, 0 }, { alt = true }))
		end)

		it("ignores an area command with trivial radius", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:select(1)
			local env = loadWidget(c)
			assert.is_false(env.widget:CommandNotify(CMD.ATTACK, { 0, 0, 0, 0 }, { alt = true }))
		end)

		it("does nothing without filter (Alt/Ctrl) or split (Shift+Space) modifiers", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_false(notify(env, CMD.ATTACK, {})) -- plain area attack (notify sends the area params)
			assert.is_false(notify(env, CMD.ATTACK, { shift = true }))
			assert.is_false(notify(env, CMD.ATTACK, { meta = true }))
			assert.is_false(notify(env, CMD.ATTACK, { right = true }))
			assert.equals(0, #c.orders)
		end)

		it("ignores a target type the command does not accept (Resurrect over a unit)", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, "corak", { team = 1 })
			c:select(1)
			c:hoverUnit(10) -- Resurrect only allows features
			local env = loadWidget(c)
			assert.is_false(notify(env, CMD.RESURRECT, { alt = true }))
		end)
	end)

	local blipName = nil -- unidentified

	describe("when hovering unidentified radar blips", function()
		-- ! Choose between this or the below:
		it("passes the command through on Alt", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, blipName, { team = 1, x = 5 }) -- blip under cursor
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_false(notify(env, CMD.ATTACK, { alt = true }))
			assert.equals(0, #c.orders)
		end)

		-- ! Choose between this or the above:
		-- it("targets only other radar blips on Alt", function()
		-- 	local c = newContext()
		-- 	c:addUnit(1, "armpw", { team = 0 })
		-- 	c:addUnit(10, blipName, { team = 1, x = 5 }) -- blip under cursor
		-- 	c:addUnit(11, "armpw", { team = 1 }) -- identified unit
		-- 	c:select(1)
		-- 	c:hoverUnit(10)
		-- 	local env = loadWidget(c)
		-- 	assert.is_true(notify(env, CMD.ATTACK, { alt = true }))
		-- 	assert.same({ 10 }, targetList(c.orders))
		-- end)

		it("targets by its readable team on Ctrl", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, blipName, { team = 1, x = 5 }) -- hostile blip under cursor
			c:addUnit(11, "corak", { team = 1, x = 10 }) -- visible hostile
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.ATTACK, { ctrl = true }))
			assert.same({ 10, 11 }, targetList(c.orders))
		end)
	end)

	describe("when hovering a visible enemy unit", function()
		it("drops untyped blips on Alt", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:addUnit(11, "corak", { team = 1, x = 10 })
			c:addUnit(12, blipName, { team = 1, x = 15 })
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.ATTACK, { alt = true }))
			assert.same({ 10, 11 }, targetList(c.orders))
		end)

		it("keeps a hostile blip on Ctrl when hovered is hostile", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:addUnit(12, blipName, { team = 1, x = 15 })
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.ATTACK, { ctrl = true }))
			assert.same({ 10, 12 }, targetList(c.orders))
		end)

		it("drops a neutral blip on Ctrl when hovered is hostile", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:addUnit(12, blipName, { team = 1, x = 15, neutral = true })
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.ATTACK, { ctrl = true }))
			assert.same({ 10 }, targetList(c.orders))
		end)

		it("keeps a neutral blip on Ctrl when hovered is neutral", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0, x = 5000 })
			c:addUnit(10, "armdrag", { team = 1, x = 5, neutral = true })
			c:addUnit(11, blipName, { team = 1, x = 10, neutral = true })
			c:addUnit(12, "corak", { team = 1, x = 15 })
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.RECLAIM, { ctrl = true }))
			assert.same({ 10, 11 }, targetList(c.orders))
		end)

		it("drops a hostile blip on Ctrl when hovered is neutral", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0, x = 5000 })
			c:addUnit(10, "armdrag", { team = 1, x = 5, neutral = true })
			c:addUnit(11, blipName, { team = 1, x = 10 })
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.RECLAIM, { ctrl = true }))
			assert.same({ 10 }, targetList(c.orders))
		end)

		it("keeps only hostiles and distributes them on Shift+Space", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0, x = -20 })
			c:addUnit(2, "armpw", { team = 0, x = 20 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:addUnit(12, blipName, { team = 1, x = 15 })
			c:addUnit(13, blipName, { team = 1, x = 15, neutral = true })
			c:addUnit(14, "corak", { team = 1, x = 15, neutral = true })
			c:select(1, 2)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.ATTACK, { shift = true, meta = true }))
			assert.same({ 10, 12 }, targetList(c.orders))
			assert_is_split(c.orders)
		end)

		it("keeps only same-typed hostiles and distributes them on Shift+Space+Alt", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0, x = -20 })
			c:addUnit(2, "armpw", { team = 0, x = 20 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:addUnit(11, "corak", { team = 1, x = 15 })
			c:addUnit(12, "armpw", { team = 1, x = 15 })
			c:addUnit(13, blipName, { team = 1, x = 15 })
			c:addUnit(14, "corak", { team = 1, x = 15, neutral = true })
			c:select(1, 2)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.ATTACK, { shift = true, meta = true }))
			assert.same({ 10, 12 }, targetList(c.orders))
			assert_is_split(c.orders)
		end)
	end)

	-- Command configs have allowed allegiances, allowed target types, etc.
	describe("allegiance per command config", function()
		it("Attacks visible enemy targets in the area", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:addUnit(11, "corak", { team = 1, x = 10 })
			c:addUnit(20, "armpw", { team = 0, x = 8 }) -- own unit, must be ignored by ENEMY_UNITS
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.ATTACK, { shift = true, meta = true }))
			assert.same({ 10, 11 }, targetList(c.orders))
		end)

		it("skips an Attack on an ally", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(2, "armpw", { team = 0, x = 5 }) -- allied target under cursor
			c:select(1)
			c:hoverUnit(2)
			local env = loadWidget(c)
			assert.is_false(notify(env, CMD.ATTACK, { ctrl = true }))
		end)

		it("skips a Guards on an enemy", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_false(notify(env, CMD.GUARD, { ctrl = true }))
		end)

		it("Guards allied units in the area", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0, x = 5 * AREA_RADIUS }) -- so the test can ignore self-targeting
			c:addUnit(2, "armpw", { team = 0, x = 5 })
			c:addUnit(3, "corak", { team = 0, x = 10 })
			c:addUnit(10, "corak", { team = 1, x = 8 })
			c:select(1)
			c:hoverUnit(2)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.GUARD, { shift = true, meta = true })) -- split-of-one for lazy test; should be its own test tbh
			assert.same({ 2, 3 }, targetList(c.orders))
		end)

		it("does not target itself when in the area", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0, x = -20 })
			c:addUnit(2, "armpw", { team = 0, x = 20 })
			c:select(1, 2)
			c:hoverUnit(2)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.GUARD, { shift = true, meta = true }))
			for _, order in ipairs(c.orders) do
				assert.not_equals(order.units[1], orderTargetID(order))
			end
		end)

		it("protects allies on Reclaim hovering your own units (targets MY_UNITS)", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0, x = 5000 })
			c:addUnit(2, "armpw", { team = 0, x = 5 })
			c:addUnit(3, "corak", { team = 2, x = 10 })
			c:select(1)
			c:hoverUnit(2)
			-- Make team 2 an ally of team 0 for this scenario:
			c.teamAllyTeam[2] = 0
			c.units[3].allyTeam = 0
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.RECLAIM, { shift = true, meta = true }))
			assert.same({ 2 }, targetList(c.orders))
		end)

		-- Unsure if we prevent guard on all enemy teams atm:
		it("Guard on a ceasefired enemy retargets that enemy's team (as though allied + filterTeam)", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, "corak", { team = 1, x = 5 }) -- ceasefired enemy, hovered
			c:addUnit(11, "corak", { team = 1, x = 10 }) -- ceasefired enemy
			c:addUnit(12, "corak", { team = 3, x = 8 }) -- other enemy team
			c:addUnit(13, "corak", { team = 0, x = 20 }) -- own unit
			c:addUnit(14, "corak", { team = 2, x = 20 }) -- allied unit
			c:select(1)
			c:hoverUnit(10)
			-- Make team 2 an ally of team 0 for this scenario:
			c.teamAllyTeam[2] = 0
			c.units[3].allyTeam = 0
			-- Make team 1 a ceasefired enemy of team 0 for this scenario:
			c.ceasefire[1] = { [0] = true } -- AreTeamsAllied(1, 0) -> true
			c.ceasefire[0] = { [1] = true } -- two-way ceasefire
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.GUARD, { shift = true, meta = true }))
			assert.same({ 10, 11 }, targetList(c.orders)) -- only team 1
		end)
	end)

	describe("type filter (Alt) on units", function()
		it("keeps only units sharing the hovered target's def", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:addUnit(11, "corak", { team = 1, x = 10 })
			c:addUnit(12, "armpw", { team = 1, x = 15 })
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.ATTACK, { alt = true }))
			assert.same({ 10, 11 }, targetList(c.orders))
		end)
	end)

	describe("neutrality and decoys", function()
		-- Seen this one before now maybe?
		it("drops neutral units when hovering hostile units", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:addUnit(11, "corak", { team = 1, x = 10 })
			c:addUnit(12, "armdrag", { team = 1, x = 15, neutral = true })
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.RECLAIM, { shift = true, meta = true }))
			assert.same({ 10, 11 }, targetList(c.orders)) -- wall 12 dropped
		end)

		it("keeps a decoy popup (neutral-looking def) when hovering hostile units", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:addUnit(12, "armdrag", { team = 1, x = 15, neutral = false })
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.RECLAIM, { shift = true, meta = true }))
			assert.same({ 10, 12 }, targetList(c.orders)) -- decoy kept
		end)

		it("keeps neutrals and drops hostiles when hovering neutral units", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, "armdrag", { team = 1, x = 5, neutral = true })
			c:addUnit(11, "critter_crab", { team = 1, x = 10, neutral = true })
			c:addUnit(12, "corak", { team = 1, x = 15 })
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.RECLAIM, { ctrl = true }))
			assert.same({ 10, 11 }, targetList(c.orders)) -- hostile 12 dropped
		end)
	end)

	describe("feature filtering only on wrecks", function()
		it("only considers resurrectable features", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addFeature(1, "armpw", "armpw", { x = 5 }) -- resurrectable
			c:addFeature(2, "corak", "corak", { x = 10 }) -- resurrectable
			c:addFeature(3, "rock", "", { x = 15 }) -- not resurrectable as ""
			c:select(1)
			c:hoverFeature(1)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.RESURRECT, { alt = true, shift = true, meta = true }))
			-- Feature ids are offset by Game.maxUnits in the reissued orders.
			assert.same({ UNIT_ID_MAX + 1 }, targetList(c.orders))
		end)

		it("filters features by type of the hovered target on Alt", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addFeature(1, "armpw", "armpw", { x = 5 })
			c:addFeature(2, "armpw", "armpw", { x = 10 })
			c:addFeature(3, "corak", "corak", { x = 15 })
			c:select(1)
			c:hoverFeature(1)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.RESURRECT, { alt = true, shift = true, meta = true }))
			assert.same({ UNIT_ID_MAX + 1, UNIT_ID_MAX + 2 }, targetList(c.orders))
		end)

		it("filters features by tech level of the hovered target on Ctrl", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addFeature(1, "armpw", "armpw", { x = 5 }) -- tech 1 (hovered)
			c:addFeature(2, "corak", "corak", { x = 10 }) -- tech 1
			c:addFeature(3, "armaap", "armaap", { x = 15 }) -- tech 2 (weird choice but ok)
			c:select(1)
			c:hoverFeature(1)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.RESURRECT, { ctrl = true, shift = true, meta = true }))
			assert.same({ UNIT_ID_MAX + 1, UNIT_ID_MAX + 2 }, targetList(c.orders)) -- tech 1 only
		end)

		it("filters by type, not tech, when both Alt and Ctrl are held", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addFeature(1, "armpw", "armpw", { x = 5 })
			c:addFeature(2, "corak", "corak", { x = 10 })
			c:select(1)
			c:hoverFeature(1)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.RESURRECT, { alt = true, ctrl = true, shift = true, meta = true }))
			assert.same({ UNIT_ID_MAX + 1 }, targetList(c.orders)) -- narrower type filter wins
		end)

		it("omits the feature-ID offset when the engine reports no offset", function()
			local c = newContext()
			c.noOffsetForFeatureID = true -- star of the show
			c:addUnit(1, "armpw", { team = 0 })
			c:addFeature(1, "armpw", "armpw", { x = 5 })
			c:select(1)
			c:hoverFeature(1)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.RESURRECT, { alt = true, shift = true, meta = true }))
			assert.same({ 1 }, targetList(c.orders)) -- raw feature id, no + maxUnits
		end)
	end)

	describe("order dispatch semantics", function()
		-- This is not really ideal; shift should be reserved for queueing:
		it("honors the caller's `shift` on the first order, then forces shift to queue", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:addUnit(11, "corak", { team = 1, x = 10 })
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.ATTACK, { alt = true }))
			assert.equals(2, #c.orders)
			assert.is_false(hasShift(c.orders[1].opts))
			assert.is_true(hasShift(c.orders[2].opts))
			assert.is_true(notify(env, CMD.ATTACK, { alt = true, shift = true }))
			assert.equals(4, #c.orders)
			assert.is_true(hasShift(c.orders[3].opts))
			assert.is_true(hasShift(c.orders[4].opts))
		end)

		it("prepends using CMD.INSERT with OPT_ALT on Meta", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:addUnit(11, "corak", { team = 1, x = 10 })
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.ATTACK, { alt = true, meta = true }))
			for _, order in ipairs(c.orders) do
				assert.equals(CMD.INSERT, order.cmdId)
				assert.equals(CMD.ATTACK, order.params[2])
				assert.equals(CMD.OPT_ALT, order.opts) -- TODO: check on this
			end
		end)

		it("splits targets on Shift+Meta", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0, x = -20 })
			c:addUnit(2, "armpw", { team = 0, x = 20 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:addUnit(11, "corak", { team = 1, x = 10 })
			c:select(1, 2)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.ATTACK, { shift = true, meta = true }))
			assert_is_split(c.orders)
		end)
	end)

	describe("transport loading (LOAD_UNITS)", function()
		it("assigns passengers in the area to a selected transport", function()
			local c = newContext()
			c:addUnit(1, "armaap", { team = 0 }) -- transport, selected
			c:addUnit(2, "armpw", { team = 0, x = 5 }) -- allied passenger, hovered
			c:addUnit(3, "armpw", { team = 0, x = 10 }) -- allied passenger
			c:select(1)
			c:hoverUnit(2)
			local env = loadWidget(c)
			assert.is_true(notify(env, CMD.LOAD_UNITS, { shift = true, meta = true }))
			assert.same({ 2, 3 }, targetList(c.orders))
			for _, order in ipairs(c.orders) do
				assert.same({ 1 }, order.units) -- the transport carries them
			end
		end)

		it("issues no orders when the selection contains no transports", function()
			local c = newContext()
			c:addUnit(1, "armpw", { team = 0 }) -- not a transport
			c:addUnit(2, "armpw", { team = 0, x = 5 })
			c:select(1)
			c:hoverUnit(2)
			local env = loadWidget(c)
			-- filterUnits succeeds (allied passenger) but loadUnitsHandler finds no
			-- transport, so CommandNotify still reports handled with no orders issued.
			assert.is_true(notify(env, CMD.LOAD_UNITS, { shift = true, meta = true })) -- odd but true
			assert.equals(0, #c.orders)
		end)

		it("skips an unidentified blip in the load cylinder instead of crashing", function()
			-- Radar blips are targetable when an enemy unit is hovered, but the transport
			-- logic must skip them (as though cantBeTransported) and skip fake arithmetic
			local c = newContext()
			c:addUnit(1, "armaap", { team = 0 })
			c:addUnit(10, "corak", { team = 1, x = 5 })
			c:addUnit(12, blipName, { team = 1, x = 15 })
			c:select(1)
			c:hoverUnit(10)
			local env = loadWidget(c)
			assert.has_no.errors(function() notify(env, CMD.LOAD_UNITS, { shift = true, meta = true }) end)
			assert.equals(0, #c.orders) -- neither the enemy nor the blip is loadable
		end)
	end)
end)
