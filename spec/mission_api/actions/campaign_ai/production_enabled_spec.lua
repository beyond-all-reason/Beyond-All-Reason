local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/campaign_ai/production_enabled.lua")
local enableProduction, disableProduction = actions[1], actions[2]
local summarizeSchema = require("mission_api.schema_spec_helper")

local TEAM_ID = 3

describe("mission_api.actions.production_enabled", function()
	local sent ---@type table[]

	before_each(function()
		MissionApiBuilder.new():WithTrackedUnit("labs", 102):WithTrackedUnit("labs", 101):Install()

		sent = {}
		GG.CampaignAI = {
			SetProductionEnabled = function(...)
				sent[#sent + 1] = { ... }
			end,
		}
	end)

	after_each(function()
		GG.CampaignAI = nil
	end)

	it("declares EnableProduction's type and parameters", function()
		assert.are.same(
			{ type = "EnableProduction", unitName = "UnitName!", teamName = "TeamName!" },
			summarizeSchema(enableProduction)
		)
	end)

	it("declares DisableProduction's type and parameters", function()
		assert.are.same(
			{ type = "DisableProduction", unitName = "UnitName!", teamName = "TeamName!" },
			summarizeSchema(disableProduction)
		)
	end)

	it("stops the AI's production at the named factories, in unit ID order", function()
		disableProduction.actionFunction("labs", TEAM_ID)
		assert.are.same({ { { 101, 102 }, false, TEAM_ID } }, sent)
	end)

	it("lets the AI produce at the named factories again", function()
		enableProduction.actionFunction("labs", TEAM_ID)
		assert.are.same({ { { 101, 102 }, true, TEAM_ID } }, sent)
	end)

	it("sends nothing for a name no unit has", function()
		disableProduction.actionFunction("ghost", TEAM_ID)
		assert.are.same({}, sent)
	end)
end)
