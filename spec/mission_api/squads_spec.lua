local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

describe("mission_api.squads", function()
	local squads ---@type table

	before_each(function()
		squads = MissionSpecEnv.include(env, "luarules/mission_api/squads.lua")
	end)

	it("gives each squad of a team an ID of its own", function()
		assert.are.equal(1, squads.Define("first", 3))
		assert.are.equal(2, squads.Define("second", 3))
	end)

	it("counts each team's squads from 1", function()
		squads.Define("first", 3)
		assert.are.equal(1, squads.Define("second", 4))
	end)

	it("refuses a name while a squad of that name is live", function()
		squads.Define("first", 3)
		assert.is_nil(squads.Define("first", 3))
	end)
end)
