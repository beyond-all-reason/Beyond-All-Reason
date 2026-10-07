require("spec_helper")

local actions = VFS.Include("luarules/mission_api/actions/game/unpause.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.unpause", function()

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
			type = "Unpause",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("calls GG.GamePause.Unpause", function()
			action.actionFunction()
			assert.are.equal(0, calls.pause)
			assert.are.equal(1, calls.unpause)
			assert.are.equal("mission", calls.source)
		end)
	end)

end)
