require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local countdownReached = VFS.Include("luarules/mission_api/triggers/countdown_reached.lua")
local onCountdownTick = countdownReached.callins.CountdownTick
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.triggers.countdown_reached", function()
	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	it("declares its type and parameters", function()
		assert.are.same({
			type = "CountdownReached",
			countdownID = "CountdownID!",
			timeRemaining = "Number!",
		}, summarizeSchema(countdownReached))
	end)

	it("fires when its countdown ticks down to the watched time", function()
		local context = Builders.TriggerContext.new():Build()
		onCountdownTick(trigger({ countdownID = "evacuate", timeRemaining = 10 }), "t", context, "evacuate", 10)
		assert.are.equal(1, context.timesFired())
	end)

	it("ignores ticks of other countdowns", function()
		local context = Builders.TriggerContext.new():Build()
		onCountdownTick(trigger({ countdownID = "evacuate", timeRemaining = 10 }), "t", context, "other", 10)
		assert.are.equal(0, context.timesFired())
	end)

	it("ignores ticks to other times", function()
		local context = Builders.TriggerContext.new():Build()
		onCountdownTick(trigger({ countdownID = "evacuate", timeRemaining = 10 }), "t", context, "evacuate", 11)
		assert.are.equal(0, context.timesFired())
	end)

	it("fires at zero on the final tick", function()
		local context = Builders.TriggerContext.new():Build()
		onCountdownTick(trigger({ countdownID = "evacuate", timeRemaining = 0 }), "t", context, "evacuate", 0)
		assert.are.equal(1, context.timesFired())
	end)
end)
