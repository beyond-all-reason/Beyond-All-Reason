require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time.
Builders.MissionApi.new():Install()

local countdownFinished = VFS.Include("luarules/mission_api/triggers/countdown_finished.lua")
local onCountdownEnded = countdownFinished.callins.CountdownEnded
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.triggers.countdown_finished", function()
	local function trigger(parameters)
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	it("declares its type and parameters", function()
		assert.are.same({
			type = "CountdownFinished",
			countdownID = "CountdownID!",
		}, summarizeSchema(countdownFinished))
	end)

	it("fires when its countdown ends", function()
		local context = Builders.TriggerContext.new():Build()
		onCountdownEnded(trigger({ countdownID = "evacuate" }), "t", context, "evacuate")
		assert.are.equal(1, context.timesFired())
	end)

	it("ignores other countdowns ending", function()
		local context = Builders.TriggerContext.new():Build()
		onCountdownEnded(trigger({ countdownID = "evacuate" }), "t", context, "other")
		assert.are.equal(0, context.timesFired())
	end)
end)
