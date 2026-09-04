require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/countdowns/unpause_countdown.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local countdownsModule = VFS.Include("luarules/mission_api/countdowns.lua")

describe("mission_api.actions.unpause_countdown", function()

	local missionApi

	before_each(function()
		missionApi = Builders.MissionApi
			.new()
			:WithModule("Countdowns", countdownsModule)
			:WithCountdown("evacuate", { id = "evacuate", timeRemaining = 120, paused = true })
			:Install()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "UnpauseCountdown",
			countdownID = "CountdownID!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("unpauses the countdown", function()
			action.actionFunction("evacuate")
			assert.is_false(missionApi.Countdowns["evacuate"].paused)
		end)
	end)

end)
