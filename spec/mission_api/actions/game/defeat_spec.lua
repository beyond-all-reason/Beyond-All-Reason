local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/game/defeat.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.defeat", function()

	before_each(function()
		env.Spring = SpringSyncedBuilder.new():Build()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "Defeat",
			allyTeamIDs = "AllyTeamIDs!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("calls GameOver with teams not in the losing list", function()
			env.Spring.GetAllyTeamList = function()
				return { 0, 1, 2 }
			end
			action.actionFunction({ 1 }) -- ally team 1 loses; 0 and 2 win
			assert.are.equal(1, #env.Spring.calls.gameOver)
			local winners = env.Spring.calls.gameOver[1]
			-- order may vary, so check membership
			local found0, found2 = false, false
			for _, v in ipairs(winners) do
				if v == 0 then
					found0 = true
				end
				if v == 2 then
					found2 = true
				end
			end
			assert.is_true(found0)
			assert.is_true(found2)
			assert.are.equal(2, #winners)
		end)

		it("passes no winners when all teams are in the losing list", function()
			env.Spring.GetAllyTeamList = function()
				return { 0, 1 }
			end
			action.actionFunction({ 0, 1 })
			assert.are.equal(1, #env.Spring.calls.gameOver)
			assert.are.equal(0, #env.Spring.calls.gameOver[1])
		end)

		it("passes all teams as winners when no teams are in the losing list", function()
			env.Spring.GetAllyTeamList = function()
				return { 0, 1 }
			end
			action.actionFunction({})
			local winners = env.Spring.calls.gameOver[1]
			assert.are.equal(2, #winners)
		end)
	end)

end)
