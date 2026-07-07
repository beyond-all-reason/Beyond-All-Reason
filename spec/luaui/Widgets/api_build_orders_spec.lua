-- luassert's chained API (assert.equals / assert.same / assert.not_equals /
-- assert.is_not_nil) and its 3-arg overload (expected, actual, message) are
-- not modeled by the bundled type stubs, so we silence those two diagnostics
-- file-wide rather than peppering every line.
---@diagnostic disable: undefined-field, redundant-parameter

local Builders = VFS.Include("spec/builders/index.lua")

local UnitDef = Builders.UnitDef

local WIDGET_PATH = "luaui/Widgets/api_build_orders.lua"
local DEFINITIONS_PATH = "luaui/Include/blueprint_substitution/definitions.lua"
local LOGIC_PATH = "luaui/Include/blueprint_substitution/logic.lua"

-- ============================================================
-- SubLogic mocks
--
-- The real definitions/logic modules iterate UnitDefs at load and pull in
-- the full BAR substitution table; here we stub them so the engine sees a
-- known getEquivalentUnitDefID contract and we can test its algorithm in
-- isolation. A future integration spec can use the real includes.
-- ============================================================

local SIDES = { ARMADA = "arm", CORTEX = "cor", LEGION = "leg" }

local function withMinimalSubLogic(builder)
	return builder
		:WithVFSInclude(DEFINITIONS_PATH, {
			SIDES = SIDES,
			UNIT_CATEGORIES = {},
			categoryUnits = {},
			unitCategories = {},
		})
		:WithVFSInclude(LOGIC_PATH, {
			SIDES = SIDES,
			equivalentUnits = {},
			MasterBuildingData = {},
			unitCategories = {},
			getSideFromUnitName = function()
				return nil
			end,
			getEquivalentUnitDefID = function(name)
				return name
			end,
		})
end

-- ARM↔COR substitution by defID — armmex(10)↔cormex(20), armsolr(11)↔corsolr(21).
local function withArmCorSubLogic(builder)
	local sideByName = {
		armmex = "arm",
		armsolr = "arm",
		armcon = "arm",
		armhcon = "arm",
		armrcon = "arm",
		cormex = "cor",
		corsolr = "cor",
		corcon = "cor",
	}
	local armToCor = { [10] = 20, [11] = 21 }
	local corToArm = { [20] = 10, [21] = 11 }

	return builder
		:WithVFSInclude(DEFINITIONS_PATH, {
			SIDES = SIDES,
			UNIT_CATEGORIES = {},
			categoryUnits = {},
			unitCategories = {},
		})
		:WithVFSInclude(LOGIC_PATH, {
			SIDES = SIDES,
			equivalentUnits = {},
			MasterBuildingData = {},
			unitCategories = {},
			getSideFromUnitName = function(name)
				return sideByName[name]
			end,
			getEquivalentUnitDefID = function(unitDefID, targetSide)
				if targetSide == "arm" then
					return corToArm[unitDefID] or unitDefID
				end
				if targetSide == "cor" then
					return armToCor[unitDefID] or unitDefID
				end
				return unitDefID
			end,
		})
end

-- ============================================================
-- World setup
-- ============================================================

-- A two-faction world: ARM and COR, each with its own metal extractor and
-- solar collector. Three ARM constructors (standard, heavy, recon-only) and
-- two COR constructors (one player owns two of them) give us the variation
-- needed for proportional and fork/followup tests.
local function buildArmCorWorld()
	return Builders
		.EngineUnsynced
		.new()
		-- Buildings
		:WithUnitDef(UnitDef.new("armmex"):WithDefID(10):WithCost(100):WithFootprint(2, 2))
		:WithUnitDef(UnitDef.new("armsolr"):WithDefID(11):WithCost(100):WithFootprint(2, 2))
		:WithUnitDef(UnitDef.new("cormex"):WithDefID(20):WithCost(100):WithFootprint(2, 2))
		:WithUnitDef(UnitDef.new("corsolr"):WithDefID(21):WithCost(100):WithFootprint(2, 2))
		-- Constructors
		:WithUnitDef(UnitDef.new("armcon"):WithDefID(100):WithSpeed(100):Builds(10, 11):WithFootprint(2, 2))
		:WithUnitDef(UnitDef.new("armhcon"):WithDefID(101):WithSpeed(300):Builds(10, 11):WithFootprint(2, 2))
		:WithUnitDef(UnitDef.new("armrcon"):WithDefID(102):WithSpeed(200):Builds(10):WithFootprint(2, 2))
		:WithUnitDef(UnitDef.new("corcon"):WithDefID(200):WithSpeed(100):Builds(20, 21):WithFootprint(2, 2))
		-- Live builders on the map
		:WithUnit(1, "armcon")
		:WithUnit(2, "armhcon")
		:WithUnit(3, "armrcon")
		:WithUnit(4, "corcon")
		:WithUnit(5, "corcon")
end

-- ============================================================
-- Helpers
-- ============================================================

-- A building object as produced by api_blueprint.createBuildings and consumed by
-- the engine (identity-positioned here, which is what createBuildings yields at
-- facing 0 / a single origin in the mock).
local function building(blueprintUnitID, defID, name, x)
	return {
		blueprintUnitID = blueprintUnitID,
		unitDefID = defID,
		position = { x or 0, 0, 0 },
		facing = 0,
		originalName = name,
	}
end

-- Resolve a list of unit IDs to BuilderInfo objects via the engine's own
-- getBuilderInfo, dropping any that don't resolve (mirrors placeBlueprint).
local function builderInfos(bo, ids)
	local infos = {}
	for _, id in ipairs(ids) do
		local info = bo.getBuilderInfo(id)
		if info then
			table.insert(infos, info)
		end
	end
	return infos
end

-- Extract positive building defIDs from a GiveOrderArrayToUnitArray orders list.
local function orderDefIDs(orders)
	local ids = {}
	for _, order in ipairs(orders) do
		table.insert(ids, -order[1])
	end
	return ids
end

-- Extract the x coordinate of each order's build position (used to identify
-- which building an order targets in split-mode tests).
local function orderXs(orders)
	local xs = {}
	for _, order in ipairs(orders) do
		table.insert(xs, order[2][1])
	end
	return xs
end

-- Find the GiveOrderArrayToUnitArray call whose target group includes a given
-- builder. In split mode every builder forms its own group, so each call targets
-- a single builder; in sequential mode a group may contain several.
local function callForBuilder(calls, builderID)
	for _, c in ipairs(calls) do
		for _, id in ipairs(c.unitIDs or {}) do
			if id == builderID then
				return c
			end
		end
	end
	return nil
end

-- ============================================================
-- Tests
-- ============================================================

describe("api_build_orders", function()
	describe("with no real units to act on", function()
		---@type UnsyncedWidgetMock
		local widget

		before_each(function()
			widget = withMinimalSubLogic(Builders.EngineUnsynced.new()):LoadWidget(WIDGET_PATH)
		end)

		it("issues no orders when there are no buildings", function()
			local bo = widget.WG.api_build_orders
			local calls = widget.captureArrayOrders()
			bo.distributeBuildOrders(bo.groupBuilders({}), {}, {})
			assert.equals(0, #calls)
		end)

		it("in split mode, issues no orders when the builders list is empty", function()
			local bo = widget.WG.api_build_orders
			local calls = widget.captureArrayOrders()
			bo.splitBuildOrders({}, { building(1, 10, "armmex", 0) }, {})
			assert.equals(0, #calls)
		end)

		it("in split mode, issues no orders when no builder has a valid unit def", function()
			-- getBuilderInfo returns nil for unmapped IDs (default mock)
			local bo = widget.WG.api_build_orders
			local calls = widget.captureArrayOrders()
			bo.splitBuildOrders(builderInfos(bo, { 100, 101 }), { building(1, 10, "armmex", 0) }, {})
			assert.equals(0, #calls)
		end)
	end)

	describe("when every builder has zero build speed", function()
		it("issues no orders", function()
			local widget = withMinimalSubLogic(Builders.EngineUnsynced.new():WithUnitDef(UnitDef.new("armcon"):WithDefID(42):WithSpeed(0)):WithUnit(1, "armcon")):LoadWidget(WIDGET_PATH)

			local bo = widget.WG.api_build_orders
			local calls = widget.captureArrayOrders()
			bo.distributeBuildOrders(bo.groupBuilders({ 1 }), {}, {})
			assert.equals(0, #calls)
		end)
	end)

	-- distributeBuildOrders: builder groups are sorted by total build power
	-- (count × speed). Buildings are partitioned into cost-proportional chunks,
	-- the highest-power group gets the first chunk, the last group takes whatever
	-- remains. Buildings a group cannot construct become "leftovers" that get
	-- round-robined to any capable group.
	describe("distributeBuildOrders (proportional / sequential)", function()
		---@type UnsyncedWidgetMock
		local widget

		before_each(function()
			widget = withArmCorSubLogic(buildArmCorWorld()):LoadWidget(WIDGET_PATH)
		end)

		it("issues ARM orders to an ARM builder placing an ARM blueprint", function()
			local bo = widget.WG.api_build_orders
			local calls = widget.captureArrayOrders()

			bo.distributeBuildOrders(bo.groupBuilders({ 1 }), {
				building(1, 10, "armmex", 0),
				building(2, 11, "armsolr", 16),
			}, {})

			assert.equals(1, #calls)
			local call = calls[1]
			---@cast call -nil
			assert.same({ 1 }, call.unitIDs)
			assert.same({ 10, 11 }, orderDefIDs(call.orders))
		end)

		it("substitutes ARM defIDs to COR equivalents when a COR builder builds an ARM blueprint", function()
			-- Documents the bug fix: passing a string name to getEquivalentUnitDefID
			-- caused canBuild() to always return false for cross-faction placements.
			local bo = widget.WG.api_build_orders
			local calls = widget.captureArrayOrders()

			bo.distributeBuildOrders(bo.groupBuilders({ 4 }), {
				building(1, 10, "armmex", 0),
				building(2, 11, "armsolr", 16),
			}, {})

			assert.equals(1, #calls)
			local call = calls[1]
			---@cast call -nil
			assert.same({ 4 }, call.unitIDs)
			assert.same({ 20, 21 }, orderDefIDs(call.orders))
		end)

		it("distributes 4 buildings 3:1 between armhcon and armcon (build power 300:100)", function()
			local bo = widget.WG.api_build_orders
			local calls = widget.captureArrayOrders()

			bo.distributeBuildOrders(bo.groupBuilders({ 1, 2 }), {
				building(1, 10, "armmex", 0),
				building(2, 10, "armmex", 16),
				building(3, 10, "armmex", 32),
				building(4, 10, "armmex", 48),
			}, {})

			assert.equals(2, #calls, "expected one GiveOrderArrayToUnitArray call per builder group")

			local hconCall, conCall
			for _, c in ipairs(calls) do
				if c.unitIDs[1] == 2 then
					hconCall = c
				end
				if c.unitIDs[1] == 1 then
					conCall = c
				end
			end

			assert.is_not_nil(hconCall, "armhcon (unitID=2) should receive orders")
			assert.is_not_nil(conCall, "armcon  (unitID=1) should receive orders")
			---@cast hconCall -nil
			---@cast conCall -nil
			assert.equals(3, #hconCall.orders, "armhcon (power=300) should get 3 of 4 buildings")
			assert.equals(1, #conCall.orders, "armcon  (power=100) should get 1 of 4 buildings")
		end)

		it("redistributes a group's unbuildable chunk to capable groups via round-robin", function()
			-- armrcon can only build armmex (defID 10). With [armsolr×3, armmex×1]
			-- and totalPower=300 (armrcon=200, armcon=100), armrcon's 0.67 share
			-- targets [armsolr×3] but it can build none of them — so all 3 spill
			-- to armcon, which already had the 1 armmex from its own slice.
			local bo = widget.WG.api_build_orders
			local calls = widget.captureArrayOrders()

			bo.distributeBuildOrders(bo.groupBuilders({ 1, 3 }), {
				building(1, 11, "armsolr", 0),
				building(2, 11, "armsolr", 16),
				building(3, 11, "armsolr", 32),
				building(4, 10, "armmex", 48),
			}, {})

			for _, c in ipairs(calls) do
				assert.not_equals(3, c.unitIDs[1], "armrcon (unitID=3) should not receive any orders")
			end

			local conCall
			for _, c in ipairs(calls) do
				if c.unitIDs[1] == 1 then
					conCall = c
				end
			end
			assert.is_not_nil(conCall, "armcon (unitID=1) should receive all redistributed orders")
			---@cast conCall -nil
			assert.equals(4, #conCall.orders)
			-- chunk order first (armmex from armcon's own slice), then leftovers
			assert.same({ 10, 11, 11, 11 }, orderDefIDs(conCall.orders))
		end)

		it("only the first order per builder group honors the caller's shift state", function()
			-- The first order keeps the caller's cmdOpts so it replaces the queue
			-- when shift isn't held; the rest force shift so the blueprint's other
			-- buildings queue instead of overwriting one another.
			local bo = widget.WG.api_build_orders
			local calls = widget.captureArrayOrders()

			bo.distributeBuildOrders(bo.groupBuilders({ 1 }), {
				building(1, 10, "armmex", 0),
				building(2, 11, "armsolr", 16),
				building(3, 10, "armmex", 32),
			}, {}) -- shift not held

			assert.equals(1, #calls)
			local orders = calls[1].orders
			assert.equals(3, #orders)
			assert.is_falsy(orders[1][3].shift, "first order should not force shift")
			for i = 2, #orders do
				assert.is_true(orders[i][3].shift, "order " .. i .. " should force shift")
			end
		end)

		it("distributes 3 buildings 2:1 by builder count (two corcon vs one armcon)", function()
			-- Proportionality tracks each group's total build power, which scales
			-- with builder count: two corcon (power 200) take twice the share of one
			-- armcon (power 100) -- not a flat 50/50. (efrec's #cons>>>#cons case.)
			local bo = widget.WG.api_build_orders
			local calls = widget.captureArrayOrders()

			bo.distributeBuildOrders(bo.groupBuilders({ 1, 4, 5 }), {
				building(1, 10, "armmex", 0),
				building(2, 10, "armmex", 16),
				building(3, 10, "armmex", 32),
			}, {})

			assert.equals(2, #calls, "one call per builder group (armcon, corcon)")

			local corCall = callForBuilder(calls, 4) -- the corcon group is { 4, 5 }
			local armCall = callForBuilder(calls, 1)
			assert.is_not_nil(corCall, "corcon group should receive orders")
			assert.is_not_nil(armCall, "armcon group should receive orders")
			---@cast corCall -nil
			---@cast armCall -nil
			assert.equals(2, #corCall.orders, "corcon (power 200) should get 2 of 3 buildings")
			assert.equals(1, #armCall.orders, "armcon (power 100) should get 1 of 3 buildings")
		end)
	end)

	-- splitBuildOrders: each builder works its own fork -- a proportional,
	-- contiguous chunk first, then every other building it can build appended as a
	-- followup so it helps peers once its own chunk is done. Buildings are
	-- substituted to each builder's own faction. There is no faction round-robin --
	-- the split tracks build power, not a flat 50/50 per side.
	describe("splitBuildOrders (per-builder forks)", function()
		---@type UnsyncedWidgetMock
		local widget

		before_each(function()
			widget = withArmCorSubLogic(buildArmCorWorld()):LoadWidget(WIDGET_PATH)
		end)

		it("gives each builder its own disjoint chunk first, then peers' buildings as followups", function()
			local bo = widget.WG.api_build_orders
			local calls = widget.captureArrayOrders()

			bo.splitBuildOrders(builderInfos(bo, { 4, 5 }), {
				building(1, 10, "armmex", 0),
				building(2, 10, "armmex", 16),
				building(3, 11, "armsolr", 32),
				building(4, 11, "armsolr", 48),
			}, {})

			assert.equals(2, #calls, "one GiveOrderArrayToUnitArray call per builder")

			local c4, c5 = callForBuilder(calls, 4), callForBuilder(calls, 5)
			assert.is_not_nil(c4, "corcon 4 should receive orders")
			assert.is_not_nil(c5, "corcon 5 should receive orders")
			---@cast c4 -nil
			---@cast c5 -nil

			-- every order is in COR defIDs (each builder builds in its own faction)
			for _, c in ipairs(calls) do
				for _, defID in ipairs(orderDefIDs(c.orders)) do
					assert.is_true(defID == 20 or defID == 21, "expected COR defID 20/21, got " .. tostring(defID))
				end
			end

			-- each builder gets its own 2-building chunk first, then the other 2 as
			-- followups (4 orders total), and the two own-chunks partition all four.
			assert.equals(4, #c4.orders, "builder 4 gets its 2-building fork plus 2 followups")
			assert.equals(4, #c5.orders, "builder 5 gets its 2-building fork plus 2 followups")
			local own = { orderXs(c4.orders)[1], orderXs(c4.orders)[2], orderXs(c5.orders)[1], orderXs(c5.orders)[2] }
			table.sort(own)
			assert.same({ 0, 16, 32, 48 }, own, "the two own-chunks should partition all four buildings")
		end)

		it("substitutes per builder's faction and does not force a 50/50 split", function()
			local bo = widget.WG.api_build_orders
			local calls = widget.captureArrayOrders()

			bo.splitBuildOrders(builderInfos(bo, { 1, 4 }), {
				building(1, 10, "armmex", 0),
				building(2, 10, "armmex", 16),
			}, {})

			local armCall, corCall = callForBuilder(calls, 1), callForBuilder(calls, 4)
			assert.is_not_nil(armCall, "armcon (1) should receive orders")
			assert.is_not_nil(corCall, "corcon (4) should receive orders")
			---@cast armCall -nil
			---@cast corCall -nil

			-- each builder builds both mexes (its own fork + the peer's as a
			-- followup), each in its own faction's defID -- no faction round-robin.
			for _, defID in ipairs(orderDefIDs(armCall.orders)) do
				assert.equals(10, defID, "armcon should build armmex (10)")
			end
			for _, defID in ipairs(orderDefIDs(corCall.orders)) do
				assert.equals(20, defID, "corcon should build cormex (20), not armmex")
			end
		end)

		it("doubles up builders onto buildings when builders outnumber buildings", function()
			local bo = widget.WG.api_build_orders
			local calls = widget.captureArrayOrders()

			bo.splitBuildOrders(builderInfos(bo, { 1, 2, 3 }), {
				building(1, 10, "armmex", 0),
				building(2, 10, "armmex", 16),
			}, {})

			-- every builder gets work (nobody idle), and each building is queued to
			-- more than one builder via followups
			assert.equals(3, #calls, "all three builders should receive orders")
			local counts = {}
			for _, c in ipairs(calls) do
				for _, x in ipairs(orderXs(c.orders)) do
					counts[x] = (counts[x] or 0) + 1
				end
			end
			assert.is_true((counts[0] or 0) >= 2, "building @0 should be queued to multiple builders")
			assert.is_true((counts[16] or 0) >= 2, "building @16 should be queued to multiple builders")
		end)

		it("excludes buildings a builder cannot construct, even as followups", function()
			local bo = widget.WG.api_build_orders
			local calls = widget.captureArrayOrders()

			bo.splitBuildOrders(builderInfos(bo, { 1, 3 }), {
				building(1, 10, "armmex", 0),
				building(2, 11, "armsolr", 16),
			}, {})

			local rconCall = callForBuilder(calls, 3)
			assert.is_not_nil(rconCall, "armrcon (3) should receive orders")
			---@cast rconCall -nil

			-- armrcon can only build armmex (10); armsolr must never appear in its
			-- queue, not even as a followup.
			for _, defID in ipairs(orderDefIDs(rconCall.orders)) do
				assert.equals(10, defID, "armrcon should only ever be ordered to build armmex (10)")
			end
		end)

		it("sends a builder that can build nothing to guard a working builder", function()
			local bo = widget.WG.api_build_orders
			local arrayCalls = widget.captureArrayOrders()
			local unitCalls = widget.captureUnitOrders()

			-- armrcon builds only armmex; it can construct none of an all-armsolr
			-- blueprint, while armcon can build every solr.
			bo.splitBuildOrders(builderInfos(bo, { 1, 3 }), {
				building(1, 11, "armsolr", 0),
				building(2, 11, "armsolr", 16),
			}, {})

			-- armcon (1) does the building; armrcon (3) gets no build orders
			assert.is_not_nil(callForBuilder(arrayCalls, 1), "armcon (1) should receive build orders")
			assert.is_nil(callForBuilder(arrayCalls, 3), "armrcon (3) should not receive build orders")

			-- instead of idling, armrcon (3) is told to guard the working builder
			assert.equals(1, #unitCalls, "exactly one guard order should be issued")
			local guard = unitCalls[1]
			assert.equals(3, guard.unitID, "armrcon (3) should be the one guarding")
			assert.equals(widget.env.CMD.GUARD, guard.cmdID, "the order should be a guard")
			assert.equals(1, guard.params[1], "armrcon should guard the working builder armcon (1)")
		end)
	end)
end)
