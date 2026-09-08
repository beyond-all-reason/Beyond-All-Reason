require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/countdowns/add_countdown.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local countdownsModule = VFS.Include("luarules/mission_api/countdowns.lua")

describe("mission_api.actions.add_countdown", function()

	local missionApi

	before_each(function()
		missionApi = Builders.MissionApi.new():WithModule("Countdowns", countdownsModule):Install()
		Spring.GetGameFrame = function()
			return 0
		end
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "AddCountdown",
			countdownID = "CountdownID!",
			seconds = "Quantity!",
			displayed = "Boolean",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("adds a running countdown with the given time", function()
			action.actionFunction("evacuate", 120)
			assert.are.equal(120, missionApi.Countdowns["evacuate"].timeRemaining)
			assert.is_false(missionApi.Countdowns["evacuate"].paused)
		end)

		it("passes displayed through, defaulting to true", function()
			action.actionFunction("shown", 60)
			action.actionFunction("hidden", 60, false)
			assert.is_true(missionApi.Countdowns["shown"].displayed)
			assert.is_false(missionApi.Countdowns["hidden"].displayed)
		end)
	end)

end)
