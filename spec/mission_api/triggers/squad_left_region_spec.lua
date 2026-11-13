local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local TriggerBuilder = VFS.Include("spec/builders/trigger_builder.lua")
local TriggerContextBuilder = VFS.Include("spec/builders/trigger_context_builder.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local squadLeftRegion = VFS.Include("luarules/mission_api/triggers/squad_left_region.lua")
local onSquadLeftRegion = squadLeftRegion.callins.SquadLeftRegion
local summarizeSchema = require("mission_api.schema_spec_helper")

local TEAM_ID = 3

describe("mission_api.triggers.squad_left_region", function()
	local function timesFired(parameters, regionName, squadName, teamID)
		local context = TriggerContextBuilder.new():Build()
		local trigger = TriggerBuilder.new():WithParameters(parameters):Build()
		onSquadLeftRegion(trigger, "t", context, regionName, squadName, teamID)
		return context.timesFired()
	end

	it("declares its type and parameters", function()
		assert.are.same({
			type = "SquadLeftRegion",
			regionName = "RegionName",
			squadName = "SquadName",
			teamName = "TeamName",
			requiresOneOf = { "regionName", "squadName", "teamName" },
		}, summarizeSchema(squadLeftRegion))
	end)

	it("fires when a squad leaves its region", function()
		assert.are.equal(1, timesFired({ regionName = "gate" }, "gate", "raiders", TEAM_ID))
	end)

	it("ignores other regions", function()
		assert.are.equal(0, timesFired({ regionName = "gate" }, "bridge", "raiders", TEAM_ID))
	end)

	it("fires when its squad leaves a region", function()
		assert.are.equal(1, timesFired({ squadName = "raiders" }, "gate", "raiders", TEAM_ID))
	end)

	it("ignores other squads", function()
		assert.are.equal(0, timesFired({ squadName = "raiders" }, "gate", "guards", TEAM_ID))
	end)

	it("fires for any squad and region of its team", function()
		assert.are.equal(1, timesFired({ teamName = TEAM_ID }, "gate", "raiders", TEAM_ID))
	end)

	it("ignores other teams", function()
		assert.are.equal(0, timesFired({ teamName = TEAM_ID }, "gate", "raiders", TEAM_ID + 1))
	end)

	it("needs its region and its squad both to match", function()
		local parameters = { regionName = "gate", squadName = "raiders" }
		assert.are.equal(0, timesFired(parameters, "gate", "guards", TEAM_ID))
	end)
end)
