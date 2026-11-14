local MissionSpecEnv = require("mission_api.spec_helper")

local GAIA_TEAM_ID = 2

-- parameter_processing reads the team map and the definitions from GG when it is included.
local env = MissionSpecEnv.new()
local parameterTypes = MissionSpecEnv.registerModules(env).ParameterTypes
GG["MissionAPI"].Teams = { rebels = 1, [1] = "rebels", gaia = GAIA_TEAM_ID, [GAIA_TEAM_ID] = "gaia" }
GG["MissionAPI"].Alliances = {}
GG["MissionAPI"].ActionDefinitions = MissionSpecEnv.include(env, "luarules/mission_api/actions_loader.lua")
	.LoadActionDefinitions()
GG["MissionAPI"].ConditionDefinitions = MissionSpecEnv.include(env, "luarules/mission_api/conditions_loader.lua")
	.LoadConditionDefinitions()
local parameterProcessing = MissionSpecEnv.include(env, "luarules/mission_api/parameter_processing.lua")
GG["MissionAPI"] = nil

describe("mission_api.parameter_processing Gaia's team", function()
	local function processLoadout(teamName)
		local unitLoadout = { { unitDefName = "bot", teamName = teamName, position = { x = 0, z = 0 } } }
		return parameterProcessing.ProcessValue(parameterTypes.Types.UnitLoadout, unitLoadout)
	end

	it("turns a team name into its team ID", function()
		assert.are.equal(1, processLoadout("rebels")[1].teamName)
	end)

	it("turns the name gaia into Gaia's team ID", function()
		assert.are.equal(GAIA_TEAM_ID, processLoadout("gaia")[1].teamName)
	end)
end)
