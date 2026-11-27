local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

describe("mission_api.base_plans", function()
	local basePlans ---@type table

	before_each(function()
		basePlans = MissionSpecEnv.include(env, "luarules/mission_api/base_plans.lua")
	end)

	it("starts a plan under a new name, with IDs from 1 for each team", function()
		assert.are.equal(1, basePlans.GetOrStart("north", 3))
		assert.are.equal(2, basePlans.GetOrStart("south", 3))
		assert.are.equal(1, basePlans.GetOrStart("west", 4))
	end)

	it("gets a live plan's ID by its name", function()
		local basePlanID = basePlans.GetOrStart("north", 3)
		assert.are.equal(basePlanID, basePlans.GetOrStart("north", 3))
	end)

	it("refuses the name of another team's plan", function()
		basePlans.GetOrStart("north", 3)
		assert.is_nil(basePlans.GetOrStart("north", 4))
	end)

	it("cancels a plan, returning its ID and team", function()
		local basePlanID = basePlans.GetOrStart("north", 3)
		assert.are.same({ basePlanID, 3 }, { basePlans.Cancel("north") })
	end)

	it("cancels a plan only once", function()
		basePlans.GetOrStart("north", 3)
		basePlans.Cancel("north")
		assert.is_nil(basePlans.Cancel("north"))
	end)

	it("starts a new plan, under a new ID, for a name whose plan was cancelled", function()
		local basePlanID = basePlans.GetOrStart("north", 3)
		basePlans.Cancel("north")
		assert.are.equal(basePlanID + 1, basePlans.GetOrStart("north", 3))
	end)
end)
