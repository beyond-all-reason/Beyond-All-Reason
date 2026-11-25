local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/campaign_ai/squad_regather_enabled.lua")
local enableSquadRegather, disableSquadRegather = actions[1], actions[2]
local summarizeSchema = require("mission_api.schema_spec_helper")

local TEAM_ID = 3

describe("mission_api.actions.squad_regather_enabled", function()
	local squads ---@type table
	local sent ---@type table[]

	before_each(function()
		squads = MissionSpecEnv.include(env, "luarules/mission_api/squads.lua")
		MissionApiBuilder.new():WithModule("Squads", squads):Install()

		sent = {}
		GG.CampaignAI = {
			SetSquadRegather = function(...)
				sent[#sent + 1] = { ... }
			end,
		}
	end)

	after_each(function()
		GG.CampaignAI = nil
	end)

	it("declares EnableSquadRegather's type and parameters", function()
		assert.are.same(
			{ type = "EnableSquadRegather", squadName = "SquadName!" },
			summarizeSchema(enableSquadRegather)
		)
	end)

	it("declares DisableSquadRegather's type and parameters", function()
		assert.are.same(
			{ type = "DisableSquadRegather", squadName = "SquadName!" },
			summarizeSchema(disableSquadRegather)
		)
	end)

	it("has the AI recruit a squad again each time it is disbanded", function()
		local squadID = squads.Define("raiders", TEAM_ID)
		enableSquadRegather.actionFunction("raiders")
		assert.are.same({ { squadID, true, TEAM_ID } }, sent)
	end)

	it("keeps a squad that regathers by its name when the AI reports it disbanded", function()
		local squadID = squads.Define("raiders", TEAM_ID)
		enableSquadRegather.actionFunction("raiders")
		squads.End(TEAM_ID, squadID)
		assert.are.equal(squadID, (squads.Get("raiders")))
	end)

	it("has the AI stop recruiting a squad again", function()
		local squadID = squads.Define("raiders", TEAM_ID)
		enableSquadRegather.actionFunction("raiders")
		disableSquadRegather.actionFunction("raiders")
		assert.are.same({ squadID, false, TEAM_ID }, sent[2])
	end)

	it("lets a squad that no longer regathers end when the AI reports it disbanded", function()
		local squadID = squads.Define("raiders", TEAM_ID)
		enableSquadRegather.actionFunction("raiders")
		disableSquadRegather.actionFunction("raiders")
		squads.End(TEAM_ID, squadID)
		assert.is_nil(squads.Get("raiders"))
	end)

	it("sends nothing for a squad that is not live", function()
		enableSquadRegather.actionFunction("raiders")
		assert.are.same({}, sent)
	end)
end)
