require("spec_helper")

local actions = VFS.Include("luarules/mission_api/actions/game/pause.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.pause", function()

	local calls

	before_each(function()
		calls = { pause = 0, unpause = 0 }
		GG["ScriptedPause"] = {
			Pause = function()
				calls.pause = calls.pause + 1
			end,
			Unpause = function()
				calls.unpause = calls.unpause + 1
			end,
		}
	end)

	after_each(function()
		GG["ScriptedPause"] = nil
	end)

	it("declares its type and no parameters", function()
		assert.are.same({
			type = "Pause",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("calls GG.ScriptedPause.Pause", function()
			action.actionFunction()
			assert.are.equal(1, calls.pause)
			assert.are.equal(0, calls.unpause)
		end)
	end)

end)
