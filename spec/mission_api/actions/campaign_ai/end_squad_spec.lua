local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/campaign_ai/end_squad.lua")
local cancelSquad, disbandSquad = actions[1], actions[2]
local summarizeSchema = require("mission_api.schema_spec_helper")

local TEAM_ID = 3

describe("mission_api.actions.end_squad", function()
	local squads ---@type table
	local sent ---@type table[]

	before_each(function()
		squads = MissionSpecEnv.include(env, "luarules/mission_api/squads.lua")
		MissionApiBuilder.new():WithModule("Squads", squads):Install()

		sent = {}
		GG.CampaignAI = {
			CancelSquad = function(...)
				sent[#sent + 1] = { "cancel", ... }
			end,
			DisbandSquad = function(...)
				sent[#sent + 1] = { "disband", ... }
			end,
		}
	end)

	after_each(function()
		GG.CampaignAI = nil
	end)

	describe("CancelSquad", function()
		it("declares its type and parameters", function()
			assert.are.same({ type = "CancelSquad", squadName = "SquadName!" }, summarizeSchema(cancelSquad))
		end)

		it("cancels a squad that is still gathering", function()
			local squadID = squads.Define("raiders", TEAM_ID)
			cancelSquad.actionFunction("raiders")
			assert.are.same({ { "cancel", squadID, TEAM_ID } }, sent)
		end)

		it("forgets the squad, so the AI's signal that it removed the squad ends none", function()
			local squadID = squads.Define("raiders", TEAM_ID)
			cancelSquad.actionFunction("raiders")
			assert.is_nil(squads.End(TEAM_ID, squadID))
		end)

		it("sends nothing for a squad that is not live", function()
			cancelSquad.actionFunction("raiders")
			assert.are.same({}, sent)
		end)
	end)

	describe("DisbandSquad", function()
		it("declares its type and parameters", function()
			assert.are.same({ type = "DisbandSquad", squadName = "SquadName!" }, summarizeSchema(disbandSquad))
		end)

		it("disbands an assembled squad", function()
			local squadID = squads.Define("raiders", TEAM_ID)
			squads.Assemble(TEAM_ID, squadID)
			disbandSquad.actionFunction("raiders")
			assert.are.same({ { "disband", squadID, TEAM_ID } }, sent)
		end)

		it("keeps the squad until the AI's signal that it removed the squad", function()
			local squadID = squads.Define("raiders", TEAM_ID)
			disbandSquad.actionFunction("raiders")
			assert.are.equal("raiders", squads.End(TEAM_ID, squadID))
		end)

		it("sends nothing for a squad that is not live", function()
			disbandSquad.actionFunction("raiders")
			assert.are.same({}, sent)
		end)
	end)
end)
