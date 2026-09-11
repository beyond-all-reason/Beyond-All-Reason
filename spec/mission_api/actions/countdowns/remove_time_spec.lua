require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- Action files read GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/countdowns/remove_time.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local countdownsModule = VFS.Include("luarules/mission_api/countdowns.lua")

describe("mission_api.actions.remove_time", function()

	---@type { Countdowns: table<string, MissionCountdown> }
	local missionApi

	before_each(function()
		missionApi = Builders.MissionApi
			.new()
			:WithModule("Countdowns", countdownsModule)
			:WithCountdown("evacuate", { id = "evacuate", timeRemaining = 120, paused = false, displayed = true })
			:Install()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "RemoveTime",
			countdownID = "CountdownID!",
			seconds = "Quantity!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("shortens the remaining time", function()
			action.actionFunction("evacuate", 20)
			assert.are.equal(100, missionApi.Countdowns["evacuate"].timeRemaining)
		end)
	end)

end)
