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

	it("finds a live squad's name by its team and ID", function()
		local squadID = squads.Define("first", 3)
		assert.are.equal("first", squads.Find(3, squadID))
	end)

	it("finds nothing for another team's ID", function()
		local squadID = squads.Define("first", 3)
		assert.is_nil(squads.Find(4, squadID))
	end)

	it("ends a squad, returning its name", function()
		local squadID = squads.Define("first", 3)
		assert.are.equal("first", squads.End(3, squadID))
		assert.is_nil(squads.Find(3, squadID))
	end)

	it("ends a squad only once", function()
		local squadID = squads.Define("first", 3)
		squads.End(3, squadID)
		assert.is_nil(squads.End(3, squadID))
	end)

	it("gives a name that is defined again after its squad ended a new ID", function()
		local squadID = squads.Define("first", 3)
		squads.End(3, squadID)
		assert.are.equal(squadID + 1, squads.Define("first", 3))
	end)
end)
