local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()
env.UnitDefNames = { corak = { id = 7 }, corthud = { id = 9 } }

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/campaign_ai/define_squad.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local TEAM_ID = 3
local POSITION = { x = 4300, y = 320, z = 1600 }

describe("mission_api.actions.define_squad", function()
	local defined ---@type table[]

	before_each(function()
		local squadsModule = MissionSpecEnv.include(env, "luarules/mission_api/squads.lua")
		MissionApiBuilder.new():WithModule("Squads", squadsModule):Install()

		defined = {}
		GG.CampaignAI = {
			DefineSquad = function(...)
				defined[#defined + 1] = { ... }
			end,
		}
	end)

	after_each(function()
		GG.CampaignAI = nil
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "DefineSquad",
			squadName = "SquadName!",
			teamName = "TeamName!",
			position = "Position!",
			gatherRange = "Quantity!",
			composition = "UnitDefCounts!",
			attackRange = "Quantity",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("asks the team's AI for the squad, with unit defs by ID", function()
			action.actionFunction("raiders", TEAM_ID, POSITION, 600, { corak = 3, corthud = 2 }, 400)
			assert.are.same({ { 1, { [7] = 3, [9] = 2 }, 4300, 1600, 600, 400, TEAM_ID } }, defined)
		end)

		it("gives a second squad the next ID", function()
			action.actionFunction("raiders", TEAM_ID, POSITION, 600, { corak = 3 })
			action.actionFunction("guards", TEAM_ID, POSITION, 600, { corak = 1 })
			assert.are.same({ 2, { [7] = 1 }, 4300, 1600, 600, nil, TEAM_ID }, defined[2])
		end)

		it("asks for nothing while a squad of that name is live", function()
			action.actionFunction("raiders", TEAM_ID, POSITION, 600, { corak = 3 })
			action.actionFunction("raiders", TEAM_ID, POSITION, 600, { corak = 5 })
			assert.are.equal(1, #defined)
		end)
	end)
end)
