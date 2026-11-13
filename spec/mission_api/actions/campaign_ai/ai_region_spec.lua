local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/campaign_ai/ai_region.lua")
local defineAiRegion, clearAiRegion = actions[1], actions[2]
local summarizeSchema = require("mission_api.schema_spec_helper")

local TEAM_ID = 3
local AREA = { x1 = 0, z1 = 0, x2 = 128, z2 = 128 }
local POLYGON = { 0, 0, 128, 0, 128, 128, 0, 128 }

describe("mission_api.actions.ai_region", function()
	local sent ---@type table[]

	before_each(function()
		MissionApiBuilder.new()
			:WithModule("AreaPolygons", MissionSpecEnv.include(env, "luarules/mission_api/area_polygons.lua"))
			:WithModule("AiRegions", MissionSpecEnv.include(env, "luarules/mission_api/ai_regions.lua"))
			:Install()

		sent = {}
		GG.CampaignAI = {
			DefineAiRegion = function(...)
				sent[#sent + 1] = { "define", ... }
			end,
			ClearAiRegion = function(...)
				sent[#sent + 1] = { "clear", ... }
			end,
		}
	end)

	after_each(function()
		GG.CampaignAI = nil
	end)

	describe("DefineAiRegion", function()
		it("declares its type and parameters", function()
			assert.are.same({
				type = "DefineAiRegion",
				regionName = "RegionName!",
				teamName = "TeamName!",
				area = "Area!",
			}, summarizeSchema(defineAiRegion))
		end)

		it("gives the team's AI the region as a polygon", function()
			defineAiRegion.actionFunction("gate", TEAM_ID, AREA)
			assert.are.same({ { "define", 1, POLYGON, TEAM_ID } }, sent)
		end)

		it("sends nothing while a region of that name is live", function()
			defineAiRegion.actionFunction("gate", TEAM_ID, AREA)
			defineAiRegion.actionFunction("gate", TEAM_ID, { x1 = 640, z1 = 640, x2 = 768, z2 = 768 })
			assert.are.equal(1, #sent)
		end)
	end)

	describe("ClearAiRegion", function()
		it("declares its type and parameters", function()
			assert.are.same({ type = "ClearAiRegion", regionName = "RegionName!" }, summarizeSchema(clearAiRegion))
		end)

		it("clears the region for its team's AI", function()
			defineAiRegion.actionFunction("gate", TEAM_ID, AREA)
			clearAiRegion.actionFunction("gate")
			assert.are.same({ "clear", 1, TEAM_ID }, sent[2])
		end)

		it("sends nothing for a region that is not live", function()
			clearAiRegion.actionFunction("gate")
			assert.are.same({}, sent)
		end)
	end)
end)
