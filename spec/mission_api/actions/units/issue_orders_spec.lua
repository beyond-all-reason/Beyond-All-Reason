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
	end)

end)
