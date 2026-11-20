local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- unit_query.lua keeps the engine calls it makes at load, so the stubs read these tables instead.
local unitDefIDs = {}
local unitTeams = {}
env.Spring.GetUnitDefID = function(unitID)
	return unitDefIDs[unitID]
end
env.Spring.GetUnitTeam = function(unitID)
	return unitTeams[unitID]
end
env.UnitDefNames = { armpw = { id = 1 }, armcom = { id = 2 } }

describe("mission_api.unit_query", function()
	local missionApi, unitQuery ---@type table, table

	before_each(function()
		missionApi = MissionApiBuilder.new():WithTrackedUnit("commander", 100):Install(env)
		unitQuery = missionApi.Modules.UnitQuery
		unitDefIDs[100], unitTeams[100] = 2, 0
		unitDefIDs[101], unitTeams[101] = 1, 0
	end)

	after_each(function()
		missionApi.nameOfUnitBeingSpawned = nil
		missionApi.unitIDBeingSpawned = nil
	end)

	describe("DoesUnitMatchFilter", function()
		it("matches a unit with every fact given", function()
			local unitFilter = { unitName = "commander", unitDefName = "armcom", teamName = 0 }
			assert.is_true(unitQuery.DoesUnitMatchFilter(100, unitFilter))
		end)

		it("matches on a team alone", function()
			assert.is_true(unitQuery.DoesUnitMatchFilter(101, { teamName = 0 }))
			assert.is_false(unitQuery.DoesUnitMatchFilter(101, { teamName = 1 }))
		end)

		it("rejects a unit without the name", function()
			assert.is_false(unitQuery.DoesUnitMatchFilter(101, { unitName = "commander" }))
		end)

		it("rejects a unit of another unit def", function()
			assert.is_false(unitQuery.DoesUnitMatchFilter(100, { unitName = "commander", unitDefName = "armpw" }))
		end)

		it("rejects a unit on another team, though the other facts are true", function()
			assert.is_false(unitQuery.DoesUnitMatchFilter(100, { unitName = "commander", teamName = 1 }))
		end)

		it("treats a unit being spawned as having its loadout name", function()
			missionApi.nameOfUnitBeingSpawned = "pawn"
			missionApi.unitIDBeingSpawned = 101
			assert.is_true(unitQuery.DoesUnitMatchFilter(101, { unitName = "pawn" }))
		end)

		it("treats no other unit as having the loadout name while one is spawned", function()
			missionApi.nameOfUnitBeingSpawned = "pawn"
			missionApi.unitIDBeingSpawned = 101
			assert.is_false(unitQuery.DoesUnitMatchFilter(100, { unitName = "pawn" }))
		end)
	end)
end)
