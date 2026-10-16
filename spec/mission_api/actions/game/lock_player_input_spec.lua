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
		_G.SendToUnsynced = function(...) ---@diagnostic disable-line: global-in-non-module
			sent[#sent + 1] = { ... }
		end
	end)

	it("declares both actions without parameters", function()
		assert.are.same({ type = "LockPlayerInput" }, summarizeSchema(lockAction))
		assert.are.same({ type = "UnlockPlayerInput" }, summarizeSchema(unlockAction))
	end)

	it("locks and unlocks every player", function()
		lockAction.actionFunction()
		unlockAction.actionFunction()
		assert.are.same({ { "MissionLockPlayerInput" }, { "MissionUnlockPlayerInput" } }, sent)
	end)
end)
