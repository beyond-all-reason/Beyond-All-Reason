local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/campaign_ai/squad_repeat_enabled.lua")
local enableSquadRepeat, disableSquadRepeat = actions[1], actions[2]
local summarizeSchema = require("mission_api.schema_spec_helper")

local TEAM_ID = 3

describe("mission_api.actions.squad_repeat_enabled", function()
	local squads ---@type table
	local sent ---@type table[]

	before_each(function()
		squads = MissionSpecEnv.include(env, "luarules/mission_api/squads.lua")
		MissionApiBuilder.new():WithModule("Squads", squads):Install()

		sent = {}
		GG.CampaignAI = {
			SetSquadRepeat = function(...)
				sent[#sent + 1] = { ... }
			end,
		}
	end)

	after_each(function()
		GG.CampaignAI = nil
	end)

	it("declares EnableSquadRepeat's type and parameters", function()
		assert.are.same({ type = "EnableSquadRepeat", squadName = "SquadName!" }, summarizeSchema(enableSquadRepeat))
	end)

	it("declares DisableSquadRepeat's type and parameters", function()
		assert.are.same({ type = "DisableSquadRepeat", squadName = "SquadName!" }, summarizeSchema(disableSquadRepeat))
	end)

	it("has the AI recruit a squad again each time it is disbanded", function()
		local squadID = squads.Define("raiders", TEAM_ID)
		enableSquadRepeat.actionFunction("raiders")
		assert.are.same({ { squadID, true, TEAM_ID } }, sent)
	end)

	it("keeps a repeating squad by its name when the AI reports it disbanded", function()
		local squadID = squads.Define("raiders", TEAM_ID)
		enableSquadRepeat.actionFunction("raiders")
		squads.End(TEAM_ID, squadID)
		assert.are.equal(squadID, (squads.Get("raiders")))
	end)

	it("has the AI stop recruiting a squad again", function()
		local squadID = squads.Define("raiders", TEAM_ID)
		enableSquadRepeat.actionFunction("raiders")
		disableSquadRepeat.actionFunction("raiders")
		assert.are.same({ squadID, false, TEAM_ID }, sent[2])
	end)

	it("lets a squad that no longer repeats end when the AI reports it disbanded", function()
		local squadID = squads.Define("raiders", TEAM_ID)
		enableSquadRepeat.actionFunction("raiders")
		disableSquadRepeat.actionFunction("raiders")
		squads.End(TEAM_ID, squadID)
		assert.is_nil(squads.Get("raiders"))
	end)

	it("sends nothing for a squad that is not live", function()
		enableSquadRepeat.actionFunction("raiders")
		assert.are.same({}, sent)
	end)
end)
