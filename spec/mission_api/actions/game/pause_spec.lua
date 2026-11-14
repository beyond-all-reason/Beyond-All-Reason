local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

MissionApiBuilder.new():Install()

local actions = MissionSpecEnv.include(env, "luarules/mission_api/actions/game/pause.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.pause", function()

	---@type table
	local calls

	before_each(function()
		calls = { pause = 0, unpause = 0 }
		GG["GamePause"] = {
			Pause = function(source, publish, seconds)
				calls.pause = calls.pause + 1
				calls.source = source
				calls.publish = publish
				calls.seconds = seconds
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

	it("declares its type and the optional seconds", function()
		assert.are.same({
			type = "Pause",
			seconds = "Quantity",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("calls GG.GamePause.Pause with its seconds", function()
			action.actionFunction(2.5)
			assert.are.equal(1, calls.pause)
			assert.are.equal(0, calls.unpause)
			assert.are.equal("mission", calls.source)
			assert.is_false(calls.publish)
			assert.are.equal(2.5, calls.seconds)
		end)
	end)

end)
