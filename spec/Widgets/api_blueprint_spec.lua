-- luassert's chained API (assert.equals / assert.same / assert.not_equals /
-- assert.is_not_nil) and its 3-arg overload (expected, actual, message) are
-- not modeled by the bundled type stubs, so we silence those two diagnostics
-- file-wide rather than peppering every line.
---@diagnostic disable: undefined-field, redundant-parameter

local Builders = VFS.Include("spec/builders/index.lua")

local UnitDef = Builders.UnitDef

local WIDGET_PATH = "luaui/Widgets/api_blueprint.lua"
local DEFINITIONS_PATH = "luaui/Include/blueprint_substitution/definitions.lua"
local LOGIC_PATH = "luaui/Include/blueprint_substitution/logic.lua"

-- ============================================================
-- SubLogic mocks
--
-- The real definitions/logic modules iterate UnitDefs at load and pull in
-- the full BAR substitution table; here we stub them so placeBlueprint sees
-- a known getEquivalentUnitDefID contract and we can test its algorithm in
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
-- needed for proportional and round-robin tests.
local function buildArmCorWorld()
	return Builders
		.SpringUnsynced
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

local function armBlueprint(units)
	return { units = units, name = "test", spacing = 0, facing = 0 }
end

local function bpUnit(blueprintUnitID, defID, name, x)
	return {
		blueprintUnitID = blueprintUnitID,
		unitDefID = defID,
		position = { x or 0, 0, 0 },
		facing = 0,
		originalName = name,
	}
end

local ORIGIN = { { 0, 0, 0 } }

-- Extract positive building defIDs from a GiveOrderArrayToUnitArray orders list.
local function orderDefIDs(orders)
	local ids = {}
	for _, order in ipairs(orders) do
		table.insert(ids, -order[1])
	end
	return ids
end

-- ============================================================
-- Tests
-- ============================================================

describe("api_blueprint.placeBlueprint", function()
	describe("with no real units to act on", function()
		---@type UnsyncedWidgetMock
		local widget

		before_each(function()
			widget = withMinimalSubLogic(Builders.SpringUnsynced.new()):LoadWidget(WIDGET_PATH)
		end)

		it("issues no orders when buildPositions is empty", function()
			local arrayCalls = widget.captureArrayOrders()
			local unitCalls = widget.captureUnitOrders()
			widget.WG.api_blueprint.placeBlueprint(armBlueprint({}), {}, {}, false, {})
			assert.equals(0, #arrayCalls)
			assert.equals(0, #unitCalls)
		end)

		it("in split mode, issues no orders when the builders list is empty", function()
			local calls = widget.captureUnitOrders()
			widget.WG.api_blueprint.placeBlueprint(armBlueprint({}), ORIGIN, {}, true, {})
			assert.equals(0, #calls)
		end)

		it("in split mode, issues no orders when no builder has a valid unit def", function()
			-- GetUnitDefID returns nil for unmapped IDs (default mock)
			local calls = widget.captureUnitOrders()
			widget.WG.api_blueprint.placeBlueprint(armBlueprint({}), ORIGIN, { 100, 101 }, true, {})
			assert.equals(0, #calls)
		end)
	end)

	describe("when every builder has zero build speed", function()
		it("issues no orders", function()
			local widget = withMinimalSubLogic(Builders.SpringUnsynced.new():WithUnitDef(UnitDef.new("armcon"):WithDefID(42):WithSpeed(0)):WithUnit(1, "armcon")):LoadWidget(WIDGET_PATH)

			local calls = widget.captureArrayOrders()
			widget.WG.api_blueprint.placeBlueprint(armBlueprint({}), ORIGIN, { 1 }, false, {})
			assert.equals(0, #calls)
		end)
	end)

	-- In sequential mode, builder groups are sorted by total build power
	-- (count × speed). Buildings are partitioned into cost-proportional
	-- chunks, the highest-power group gets the first chunk, the last group
	-- takes whatever remains. Buildings a group cannot construct become
	-- "leftovers" that get round-robined to any capable group.
	describe("in sequential mode (isBuildSplit=false)", function()
		---@type UnsyncedWidgetMock
		local widget

		before_each(function()
			widget = withArmCorSubLogic(buildArmCorWorld()):LoadWidget(WIDGET_PATH)
		end)

		it("issues ARM orders to an ARM builder placing an ARM blueprint", function()
			local calls = widget.captureArrayOrders()

			widget.WG.api_blueprint.placeBlueprint(
				armBlueprint({
					bpUnit(1, 10, "armmex", 0),
					bpUnit(2, 11, "armsolr", 16),
				}),
				ORIGIN,
				{ 1 }, -- armcon
				false,
				{}
			)

			assert.equals(1, #calls)
			local call = calls[1]
			---@cast call -nil
			assert.same({ 1 }, call.unitIDs)
			assert.same({ 10, 11 }, orderDefIDs(call.orders))
		end)

		it("substitutes ARM defIDs to COR equivalents when a COR builder places an ARM blueprint", function()
			-- Documents the bug fix: passing a string name to getEquivalentUnitDefID
			-- caused canBuild() to always return false for cross-faction placements.
			local calls = widget.captureArrayOrders()

			widget.WG.api_blueprint.placeBlueprint(
				armBlueprint({
					bpUnit(1, 10, "armmex", 0),
					bpUnit(2, 11, "armsolr", 16),
				}),
				ORIGIN,
				{ 4 }, -- corcon
				false,
				{}
			)

			assert.equals(1, #calls)
			local call = calls[1]
			---@cast call -nil
			assert.same({ 4 }, call.unitIDs)
			assert.same({ 20, 21 }, orderDefIDs(call.orders))
		end)

		it("distributes 4 buildings 3:1 between armhcon and armcon (build power 300:100)", function()
			local calls = widget.captureArrayOrders()

			widget.WG.api_blueprint.placeBlueprint(
				armBlueprint({
					bpUnit(1, 10, "armmex", 0),
					bpUnit(2, 10, "armmex", 16),
					bpUnit(3, 10, "armmex", 32),
					bpUnit(4, 10, "armmex", 48),
				}),
				ORIGIN,
				{ 1, 2 }, -- armcon + armhcon
				false,
				{}
			)

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
			local calls = widget.captureArrayOrders()

			widget.WG.api_blueprint.placeBlueprint(
				armBlueprint({
					bpUnit(1, 11, "armsolr", 0),
					bpUnit(2, 11, "armsolr", 16),
					bpUnit(3, 11, "armsolr", 32),
					bpUnit(4, 10, "armmex", 48),
				}),
				ORIGIN,
				{ 1, 3 }, -- armcon + armrcon
				false,
				{}
			)

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
	end)

	-- In split mode, builders are grouped by faction. For each building,
	-- capable factions are determined and the buildings are round-robined
	-- across them. Within each faction, individual builders also take turns.
	-- Each faction always receives orders in its own defIDs.
	describe("in split mode (isBuildSplit=true)", function()
		---@type UnsyncedWidgetMock
		local widget

		before_each(function()
			widget = withArmCorSubLogic(buildArmCorWorld()):LoadWidget(WIDGET_PATH)
		end)

		it("alternates two same-faction COR builders and substitutes ARM defIDs to COR", function()
			local calls = widget.captureUnitOrders()

			widget.WG.api_blueprint.placeBlueprint(
				armBlueprint({
					bpUnit(1, 10, "armmex", 0),
					bpUnit(2, 10, "armmex", 16),
					bpUnit(3, 11, "armsolr", 32),
					bpUnit(4, 11, "armsolr", 48),
				}),
				ORIGIN,
				{ 4, 5 }, -- two corcon
				true,
				{}
			)

			assert.equals(4, #calls, "one GiveOrderToUnit call per building")

			local by4, by5 = {}, {}
			for _, c in ipairs(calls) do
				if c.unitID == 4 then
					table.insert(by4, c)
				end
				if c.unitID == 5 then
					table.insert(by5, c)
				end
			end
			assert.equals(2, #by4, "builder 4 should receive 2 orders (round-robin)")
			assert.equals(2, #by5, "builder 5 should receive 2 orders (round-robin)")

			for _, c in ipairs(calls) do
				assert.is_true(c.cmdID == -20 or c.cmdID == -21, "expected COR defID -20 (cormex) or -21 (corsolr), got " .. tostring(c.cmdID))
			end
		end)

		it("gives each faction its own defIDs when ARM and COR builders share the same blueprint", function()
			local calls = widget.captureUnitOrders()

			widget.WG.api_blueprint.placeBlueprint(
				armBlueprint({
					bpUnit(1, 10, "armmex", 0),
					bpUnit(2, 10, "armmex", 16),
				}),
				ORIGIN,
				{ 1, 4 }, -- armcon + corcon
				true,
				{}
			)

			assert.equals(2, #calls, "one order per building")

			local armOrder, corOrder
			for _, c in ipairs(calls) do
				if c.unitID == 1 then
					armOrder = c
				end
				if c.unitID == 4 then
					corOrder = c
				end
			end

			assert.is_not_nil(armOrder, "armcon (unitID=1) should receive an order")
			assert.is_not_nil(corOrder, "corcon (unitID=4) should receive an order")
			---@cast armOrder -nil
			---@cast corOrder -nil
			assert.equals(-10, armOrder.cmdID, "ARM builder should receive armmex defID (10)")
			assert.equals(-20, corOrder.cmdID, "COR builder should receive cormex defID (20), not armmex (10)")
		end)
	end)
end)
