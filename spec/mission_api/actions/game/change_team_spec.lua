local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/game/change_team.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.change_team", function()
	---@type table<integer, integer[]>
	local playersByTeam

	before_each(function()
		Builders.MissionApi.new():WithTeam("rebels", 0):WithTeam("loyalists", 1):Install()
		_G.Spring = Builders.Spring.new():Build()
		playersByTeam = { [0] = {}, [1] = {} }
		Spring.GetPlayerList = function(teamID)
			return playersByTeam[teamID]
		end
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "ChangeTeam",
			oldTeam = "TeamName!",
			newTeam = "TeamName!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("assigns the old team's player to the new team", function()
			playersByTeam[0] = { 3 }
			action.actionFunction("rebels", "loyalists")
			assert.are.same({ { playerID = 3, teamID = 1 } }, Spring.calls.assignPlayerToTeam)
		end)

		it("assigns every player on the old team", function()
			playersByTeam[0] = { 3, 4 }
			playersByTeam[1] = { 5 }
			action.actionFunction("rebels", "loyalists")
			assert.are.same({
				{ playerID = 3, teamID = 1 },
				{ playerID = 4, teamID = 1 },
			}, Spring.calls.assignPlayerToTeam)
		end)

		it("is a no-op when the old team has no players", function()
			action.actionFunction("rebels", "loyalists")
			assert.are.equal(0, #Spring.calls.assignPlayerToTeam)
		end)
	end)
end)
