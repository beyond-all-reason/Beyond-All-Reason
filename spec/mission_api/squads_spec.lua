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

	it("assembles a live squad, returning its name", function()
		local squadID = squads.Define("first", 3)
		assert.are.equal("first", squads.Assemble(3, squadID))
	end)

	it("assembles nothing for another team's ID", function()
		local squadID = squads.Define("first", 3)
		assert.is_nil(squads.Assemble(4, squadID))
	end)

	it("gets an assembled squad's ID and team by its name", function()
		local squadID = squads.Define("first", 3)
		squads.Assemble(3, squadID)
		assert.are.same({ squadID, 3 }, { squads.GetAssembled("first") })
	end)

	it("gets nothing for a squad that is still gathering", function()
		squads.Define("first", 3)
		assert.is_nil(squads.GetAssembled("first"))
	end)

	it("gets nothing for a name that is not live", function()
		assert.is_nil(squads.GetAssembled("first"))
	end)

	it("gets a live squad's name by its team and ID", function()
		local squadID = squads.Define("first", 3)
		assert.are.equal("first", squads.GetName(3, squadID))
		assert.is_nil(squads.GetName(4, squadID))
	end)

	it("gets a gathering squad's ID and team by its name, and that it is not assembled", function()
		local squadID = squads.Define("first", 3)
		assert.are.same({ squadID, 3, false }, { squads.Get("first") })
	end)

	it("gets that a squad is assembled", function()
		local squadID = squads.Define("first", 3)
		squads.Assemble(3, squadID)
		assert.are.same({ squadID, 3, true }, { squads.Get("first") })
	end)

	it("cancels a squad, returning its ID and team", function()
		local squadID = squads.Define("first", 3)
		assert.are.same({ squadID, 3 }, { squads.Cancel("first") })
	end)

	it("forgets a cancelled squad", function()
		local squadID = squads.Define("first", 3)
		squads.Cancel("first")
		assert.is_nil(squads.Get("first"))
		assert.is_nil(squads.End(3, squadID))
	end)

	it("ends a squad, returning its name", function()
		local squadID = squads.Define("first", 3)
		assert.are.equal("first", squads.End(3, squadID))
		assert.is_nil(squads.Assemble(3, squadID))
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

	it("has a squad of a reused name gather anew", function()
		local squadID = squads.Define("first", 3)
		squads.Assemble(3, squadID)
		squads.End(3, squadID)
		squads.Define("first", 3)
		assert.is_nil(squads.GetAssembled("first"))
	end)
end)
