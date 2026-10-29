require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local lockAction = VFS.Include("luarules/mission_api/actions/game/lock_player_input.lua")[1]
local unlockAction = VFS.Include("luarules/mission_api/actions/game/unlock_player_input.lua")[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.lock_player_input", function()
	---@type table[]
	local params

	before_each(function()
		params = {}
		_G.Spring = Builders.Spring.new():Build()
		Spring.SetGameRulesParam = function(...)
			params[#params + 1] = { ... }
		end
	end)

	it("declares both actions without parameters", function()
		assert.are.same({ type = "LockPlayerInput" }, summarizeSchema(lockAction))
		assert.are.same({ type = "UnlockPlayerInput" }, summarizeSchema(unlockAction))
	end)

	it("sets and clears the playerInputLock game rules param", function()
		lockAction.actionFunction()
		unlockAction.actionFunction()
		assert.are.same({ { "playerInputLock", 1 }, { "playerInputLock", 0 } }, params)
	end)
end)
