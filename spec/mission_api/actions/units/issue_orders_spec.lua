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
	return builder:Install()
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
			marching = "Boolean",
			direction = "Direction",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("is a no-op for an untracked unit name", function()
			local mission = MissionApiBuilder.new():Install()
			action.actionFunction("unknownUnit", {})
			assert.are.equal(0, #mission.calls.giveOrders)
		end)

		it("gives the tracked unit map the orders", function()
			local mission = seedUnits("bots", 101, 102)
			local orders = { { 10, {}, {} } }
			action.actionFunction("bots", orders)
			assert.are.equal(1, #mission.calls.giveOrders)
			assert.are.same(missionApi.trackedUnitIDs["bots"], mission.calls.giveOrders[1].unitIDs)
		end)

		it("gives each unit its marching orders when marching, with the direction", function()
			local asked = {}
			local unitOrders = { [101] = { { 10, { 5, 0, 5 }, {} } } }
			local mission = MissionApiBuilder.new()
				:WithTrackedUnit("bots", 101)
				:WithModule("Marching", {
					GetMarchingOrders = function(unitMap, orders, direction)
						asked.unitMap, asked.direction = unitMap, direction
						return unitOrders
					end,
				})
				:Install()
			local direction = { angle = 90 }

			action.actionFunction("bots", { { 10, { 0, 0, 0 }, {} } }, true, direction)

			assert.are.same(missionApi.trackedUnitIDs["bots"], asked.unitMap)
			assert.are.equal(direction, asked.direction)
			assert.are.equal(unitOrders, mission.calls.giveOrders[1].unitOrders)
		end)
	end)

end)
