local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()
env.UnitDefNames = { corllt = { id = 7, isImmobile = true }, corak = { id = 9, isImmobile = false } }

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/campaign_ai/base_plan.lua")
local addToBasePlan, cancelBasePlan = actions[1], actions[2]
local summarizeSchema = require("mission_api.schema_spec_helper")

local TEAM_ID = 3
local POSITION = { x = 4300, y = 320, z = 1400 }

describe("mission_api.actions.base_plan", function()
	local sent ---@type table[]

	before_each(function()
		MissionApiBuilder.new()
			:WithModule("BasePlans", MissionSpecEnv.include(env, "luarules/mission_api/base_plans.lua"))
			:Install()

		sent = {}
		GG.CampaignAI = {
			AddToBasePlan = function(...)
				sent[#sent + 1] = { "add", ... }
			end,
			CancelBasePlan = function(...)
				sent[#sent + 1] = { "cancel", ... }
			end,
		}
	end)

	after_each(function()
		GG.CampaignAI = nil
	end)

	describe("AddToBasePlan", function()
		it("declares its type and parameters", function()
			assert.are.same({
				type = "AddToBasePlan",
				basePlanName = "BasePlanName!",
				teamName = "TeamName!",
				unitDefName = "UnitDefName!",
				position = "Position!",
				rebuild = "Boolean",
			}, summarizeSchema(addToBasePlan))
		end)

		it("adds a structure, by its unit def ID, to the team's plan", function()
			addToBasePlan.actionFunction("north", TEAM_ID, "corllt", POSITION, true)
			assert.are.same({ { "add", 1, 7, 4300, 1400, true, TEAM_ID } }, sent)
		end)

		it("adds a second structure to the same plan, built once unless told otherwise", function()
			addToBasePlan.actionFunction("north", TEAM_ID, "corllt", POSITION, true)
			addToBasePlan.actionFunction("north", TEAM_ID, "corllt", { x = 4500, z = 1400 })
			assert.are.same({ "add", 1, 7, 4500, 1400, false, TEAM_ID }, sent[2])
		end)

		it("sends nothing for a unit that is not a structure", function()
			addToBasePlan.actionFunction("north", TEAM_ID, "corak", POSITION)
			assert.are.same({}, sent)
		end)

		it("sends nothing for the name of another team's plan", function()
			addToBasePlan.actionFunction("north", TEAM_ID, "corllt", POSITION)
			addToBasePlan.actionFunction("north", TEAM_ID + 1, "corllt", POSITION)
			assert.are.equal(1, #sent)
		end)
	end)

	describe("CancelBasePlan", function()
		it("declares its type and parameters", function()
			assert.are.same(
				{ type = "CancelBasePlan", basePlanName = "BasePlanName!" },
				summarizeSchema(cancelBasePlan)
			)
		end)

		it("cancels the plan for its team's AI", function()
			addToBasePlan.actionFunction("north", TEAM_ID, "corllt", POSITION)
			cancelBasePlan.actionFunction("north")
			assert.are.same({ "cancel", 1, TEAM_ID }, sent[2])
		end)

		it("sends nothing for a plan that is not live", function()
			cancelBasePlan.actionFunction("north")
			assert.are.same({}, sent)
		end)
	end)
end)
