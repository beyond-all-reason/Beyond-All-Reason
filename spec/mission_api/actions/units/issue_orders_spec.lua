local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/units/issue_orders.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local missionApi = GG["MissionAPI"]

local function seedUnits(name, ...)
	local builder = MissionApiBuilder.new()
	for _, unitID in ipairs({ ... }) do
		builder:WithTrackedUnit(name, unitID)
	end
	builder:Install()
end

describe("mission_api.actions.issue_orders", function()

	before_each(function()
		MissionApiBuilder.new():Install()
		env.Spring = SpringSyncedBuilder.new():Build()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "IssueOrders",
			unitName = "UnitName!",
			orders = "Orders!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("is a no-op for an untracked unit name", function()
			action.actionFunction("unknownUnit", {})
			assert.are.equal(0, #env.Spring.calls.giveOrderArrayToUnitMap)
		end)

		it("calls GiveOrderArrayToUnitMap with the tracked unit map and converted orders", function()
			seedUnits("bots", 101, 102)
			local orders = { { 10, {}, {} } }
			action.actionFunction("bots", orders)
			assert.are.equal(1, #env.Spring.calls.giveOrderArrayToUnitMap)
			assert.are.same(missionApi.trackedUnitIDs["bots"], env.Spring.calls.giveOrderArrayToUnitMap[1].unitMap)
		end)

		it("passes the result of ConvertOrdersTargetingNames as the orders", function()
			local convertedOrders = { { 999, {}, {} } }
			MissionApiBuilder.new()
				:WithTrackedUnit("scout", 5)
				:WithModule("Loadout", {
					ConvertOrdersTargetingNames = function()
						return convertedOrders
					end,
				})
				:Install()
			action.actionFunction("scout", {})
			assert.are.same(convertedOrders, env.Spring.calls.giveOrderArrayToUnitMap[1].orders)
		end)

		it("gives the orders with each GATHERWAIT tagged, and the name's units wait for each other", function()
			local taggedOrders = { { 5, { 4, -1 }, { "shift" } } }
			local added
			MissionApiBuilder.new()
				:WithTrackedUnit("bots", 101)
				:WithTrackedUnit("bots", 102)
				:WithModule("GatherWaits", {
					TagOrders = function()
						return taggedOrders, { -1 }
					end,
					Add = function(keys, unitIDs)
						added = { keys = keys, unitIDs = unitIDs }
					end,
				})
				:Install()
			action.actionFunction("bots", { { 9, {}, {} } })
			assert.are.same(taggedOrders, env.Spring.calls.giveOrderArrayToUnitMap[1].orders)
			assert.are.same({ keys = { -1 }, unitIDs = { [101] = true, [102] = true } }, added)
		end)

		it("gives a factory of the name the orders as written, and does not wait for it", function()
			local orders = { { 9, {}, {} } }
			local taggedOrders = { { 5, { 4, -1 }, { "shift" } } }
			local added
			MissionApiBuilder.new()
				:WithTrackedUnit("outpost", 101)
				:WithTrackedUnit("outpost", 102)
				:WithModule("GatherWaits", {
					TagOrders = function()
						return taggedOrders, { -1 }
					end,
					CanGather = function(unitDef)
						return not unitDef.isFactory
					end,
					Add = function(keys, unitIDs)
						added = { keys = keys, unitIDs = unitIDs }
					end,
				})
				:Install()
			env.UnitDefs = { [1] = { canMove = true }, [2] = { canMove = true, isFactory = true } }
			env.Spring.GetUnitDefID = function(unitID)
				return unitID == 102 and 2 or 1
			end
			action.actionFunction("outpost", orders)

			local given = env.Spring.calls.giveOrderArrayToUnitMap
			assert.are.same({ [101] = true }, given[1].unitMap)
			assert.are.same(taggedOrders, given[1].orders)
			assert.are.same({ [102] = true }, given[2].unitMap)
			assert.are.same(orders, given[2].orders)
			assert.are.same({ keys = { -1 }, unitIDs = { [101] = true } }, added)
		end)
	end)

end)
