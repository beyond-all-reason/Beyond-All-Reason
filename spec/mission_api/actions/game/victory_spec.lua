local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/game/victory.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.victory", function()

	before_each(function()
		env.Spring = SpringSyncedBuilder.new():Build()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "Victory",
			allyTeamIDs = "AllyTeamIDs!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("calls Spring.GameOver with the given allyTeamIDs", function()
			action.actionFunction({ 0 })
			assert.are.equal(1, #env.Spring.calls.gameOver)
			assert.are.same({ 0 }, env.Spring.calls.gameOver[1])
		end)

		it("passes multiple winning ally teams", function()
			action.actionFunction({ 0, 2 })
			assert.are.equal(2, #env.Spring.calls.gameOver[1])
		end)

		it("passes an empty list when no winners are provided", function()
			action.actionFunction({})
			assert.are.equal(0, #env.Spring.calls.gameOver[1])
		end)
	end)

end)
