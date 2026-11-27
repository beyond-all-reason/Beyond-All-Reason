local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

describe("mission_api.build_areas", function()
	local buildAreas ---@type table

	before_each(function()
		buildAreas = MissionSpecEnv.include(env, "luarules/mission_api/build_areas.lua")
	end)

	it("gives each build area of a team an ID of its own, from 1", function()
		assert.are.equal(1, buildAreas.Define("first", 3))
		assert.are.equal(2, buildAreas.Define("second", 3))
	end)

	it("counts each team's build areas from 1", function()
		buildAreas.Define("first", 3)
		assert.are.equal(1, buildAreas.Define("second", 4))
	end)

	it("refuses a name that is taken", function()
		buildAreas.Define("first", 3)
		assert.is_nil(buildAreas.Define("first", 3))
	end)
end)
