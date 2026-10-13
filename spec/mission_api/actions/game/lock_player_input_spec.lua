require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local lockAction = VFS.Include("luarules/mission_api/actions/game/lock_player_input.lua")[1]
local unlockAction = VFS.Include("luarules/mission_api/actions/game/unlock_player_input.lua")[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.lock_player_input", function()
	---@type table[]
	local sent

	before_each(function()
		sent = {}
		Builders.MissionApi
			.new()
			:WithModule("ClientActions", {
				Send = function(kind, params, teamID)
					sent[#sent + 1] = { kind = kind, params = params, teamID = teamID }
				end,
			})
			:Install()
	end)

	it("declares both actions", function()
		assert.are.same({ type = "LockPlayerInput", teamID = "TeamID" }, summarizeSchema(lockAction))
		assert.are.same({ type = "UnlockPlayerInput", teamID = "TeamID" }, summarizeSchema(unlockAction))
	end)

	it("locks and unlocks the clients of a team", function()
		lockAction.actionFunction(0)
		unlockAction.actionFunction(0)
		assert.are.same({
			{ kind = "lock", params = {}, teamID = 0 },
			{ kind = "unlock", params = {}, teamID = 0 },
		}, sent)
	end)
end)
