local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()
env.UnitDefNames = { corak = { id = 7 } }

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/campaign_ai/ai_settings.lua")
local setAiMexCap, setAiMilitaryQuota, setUnitDefRetreatThreshold = actions[1], actions[2], actions[3]
local summarizeSchema = require("mission_api.schema_spec_helper")

local TEAM_ID = 3

describe("mission_api.actions.ai_settings", function()
	local sent ---@type table[]

	before_each(function()
		sent = {}
		GG.CampaignAI = {
			SetMexCap = function(...)
				sent[#sent + 1] = { "mexCap", ... }
			end,
			SetMilitaryQuota = function(...)
				sent[#sent + 1] = { "quota", ... }
			end,
			SetUnitDefRetreat = function(...)
				sent[#sent + 1] = { "retreat", ... }
			end,
		}
	end)

	after_each(function()
		GG.CampaignAI = nil
	end)

	describe("SetAiMexCap", function()
		it("declares its type and parameters", function()
			assert.are.same(
				{ type = "SetAiMexCap", teamName = "TeamName!", share = "Fraction!", countsAllies = "Boolean" },
				summarizeSchema(setAiMexCap)
			)
		end)

		it("caps the AI's own extractors unless told to count its allies' too", function()
			setAiMexCap.actionFunction(TEAM_ID, 0.25)
			assert.are.same({ { "mexCap", 0.25, false, TEAM_ID } }, sent)
		end)

		it("can count the allies' extractors against the cap", function()
			setAiMexCap.actionFunction(TEAM_ID, 0.25, true)
			assert.are.same({ { "mexCap", 0.25, true, TEAM_ID } }, sent)
		end)
	end)

	describe("SetAiMilitaryQuota", function()
		it("declares its type and parameters", function()
			assert.are.same({
				type = "SetAiMilitaryQuota",
				teamName = "TeamName!",
				scouts = "Quantity",
				attackPower = "Quantity",
				raidPower = "Quantity",
				requiresOneOf = { "scouts", "attackPower", "raidPower" },
			}, summarizeSchema(setAiMilitaryQuota))
		end)

		it("passes on the quotas that are given", function()
			setAiMilitaryQuota.actionFunction(TEAM_ID, nil, 120)
			assert.are.same({ "quota", nil, 120, nil, TEAM_ID }, sent[1])
		end)
	end)

	describe("SetUnitDefRetreatThreshold", function()
		it("declares its type and parameters", function()
			assert.are.same({
				type = "SetUnitDefRetreatThreshold",
				unitDefName = "UnitDefName!",
				threshold = "Fraction!",
				teamName = "TeamName!",
			}, summarizeSchema(setUnitDefRetreatThreshold))
		end)

		it("sets the threshold for the unit def by its ID", function()
			setUnitDefRetreatThreshold.actionFunction("corak", 0.4, TEAM_ID)
			assert.are.same({ { "retreat", 7, 0.4, TEAM_ID } }, sent)
		end)
	end)
end)
