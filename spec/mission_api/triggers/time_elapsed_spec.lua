require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time,
-- and Game.gameSpeed (30, from the root spec_helper) inside its GameFrame handler.
Builders.MissionApi.new():Install()

local timeElapsed = VFS.Include("luarules/mission_api/triggers/time_elapsed.lua")
local onGameFrame = timeElapsed.callins.GameFrame

describe("mission_api.triggers.time_elapsed", function()
	local function trigger(parameters, settings)
		return Builders.Trigger.new():WithParameters(parameters):WithSettings(settings):Build()
	end

	-- Runs the GameFrame handler for frames 1..maxFrame and returns the list of
	-- frames on which context.ActivateTrigger was invoked.
	local function firedFrames(triggerTable, maxFrame)
		local fired = {}
		local context = Builders.TriggerContext.new():Build()
		for frame = 1, maxFrame do
			-- Re-pointed each frame, so the recorded value is the frame that fired.
			context.ActivateTrigger = function()
				fired[#fired + 1] = frame
			end
			onGameFrame(triggerTable, "t", context, frame)
		end
		return fired
	end

	it("declares seconds as required and interval as optional", function()
		assert.are.equal("TimeElapsed", timeElapsed.type)
		assert.are.equal("seconds", timeElapsed.parameters[1].name)
		assert.is_true(timeElapsed.parameters[1].required)
		assert.are.equal("interval", timeElapsed.parameters[2].name)
		assert.is_falsy(timeElapsed.parameters[2].required)
	end)

	it("fires once at seconds * gameSpeed", function()
		assert.are.same({ 60 }, firedFrames(trigger({ seconds = 2 }), 90))
	end)

	it("does not fire before the target frame", function()
		assert.are.same({}, firedFrames(trigger({ seconds = 3 }), 89))
	end)

	it("fires on the first frame for seconds = 0", function()
		assert.are.same({ 1 }, firedFrames(trigger({ seconds = 0 }), 5))
	end)

	it("rounds a fractional-frame conversion to the nearest frame", function()
		-- 1/30 s * 30 fps = 0.9999… which must round to frame 1, not be missed.
		assert.are.same({ 1 }, firedFrames(trigger({ seconds = 1 / 30 }), 5))
		-- 1.5 s * 30 fps = 45.
		assert.are.same({ 45 }, firedFrames(trigger({ seconds = 1.5 }), 90))
	end)

	it("fires at the target then every interval when repeating", function()
		-- seconds = 1 -> frame 30; interval = 2 -> every 60 frames.
		assert.are.same({ 30, 90, 150 }, firedFrames(trigger({ seconds = 1, interval = 2 }, { repeating = true }), 200))
	end)

	it("fires only once when repeating without an interval", function()
		assert.are.same({ 30 }, firedFrames(trigger({ seconds = 1 }, { repeating = true }), 200))
	end)
end)
