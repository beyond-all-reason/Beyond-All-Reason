require("spec_helper")

local actions = VFS.Include("luarules/mission_api/actions/game/pause.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.pause", function()

	local calls

	before_each(function()
		calls = { pause = 0, unpause = 0 }
		GG["GamePause"] = {
			Pause = function(source)
				calls.pause = calls.pause + 1
				calls.source = source
			end,
			Unpause = function(source)
				calls.unpause = calls.unpause + 1
				calls.source = source
			end,
		}
	end)

	after_each(function()
		GG["GamePause"] = nil
	end)

	it("declares its type and no parameters", function()
		assert.are.same({
			type = "Pause",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("calls GG.GamePause.Pause", function()
			action.actionFunction()
			assert.are.equal(1, calls.pause)
			assert.are.equal(0, calls.unpause)
			assert.are.equal("mission", calls.source)
		end)
	end)

end)
