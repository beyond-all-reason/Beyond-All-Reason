local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/campaign_ai/run_squad.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local TEAM_ID = 3
local POSITION = { x = 4300, y = 320, z = 1600 }

describe("mission_api.actions.run_squad", function()
	local squads ---@type table
	local runs ---@type table[]

	before_each(function()
		squads = MissionSpecEnv.include(env, "luarules/mission_api/squads.lua")
		MissionApiBuilder.new():WithModule("Squads", squads):Install()

		runs = {}
		GG.CampaignAI = {
			RunSquad = function(...)
				runs[#runs + 1] = { ... }
			end,
		}
	end)

	after_each(function()
		GG.CampaignAI = nil
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "RunSquad",
			squadName = "SquadName!",
			task = "SquadTask!",
			position = "Position!",
			attackRange = "Quantity",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("gives an assembled squad its task, by the AI's number for it", function()
			local squadID = squads.Define("raiders", TEAM_ID)
			squads.Assemble(TEAM_ID, squadID)

			action.actionFunction("raiders", "ATTACK", POSITION, 400)

			assert.are.same({ { squadID, 4, 4300, 1600, 400, TEAM_ID } }, runs)
		end)

		it("sends nothing to a squad that is still gathering", function()
			squads.Define("raiders", TEAM_ID)
			action.actionFunction("raiders", "DEFEND", POSITION)
			assert.are.same({}, runs)
		end)

		it("sends nothing for a squad that is not live", function()
			action.actionFunction("raiders", "DEFEND", POSITION)
			assert.are.same({}, runs)
		end)
	end)
end)
