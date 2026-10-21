local Builders = VFS.Include("spec/builders/index.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes and .Countdowns at load
-- time, and Game.gameSpeed (30, from the root spec_helper) in its handlers.
Builders.MissionApi.new():Install()
local env = MissionSpecEnv.new()
local currentFrame = 0
env.Spring.GetGameFrame = function()
	return currentFrame, 0
end
local countdowns = MissionSpecEnv.include(env, "luarules/mission_api/countdowns.lua")
GG["MissionAPI"].Modules.Countdowns = countdowns

local timeElapsed = VFS.Include("luarules/mission_api/triggers/time_elapsed.lua")
local onGameStart = timeElapsed.callins.GameStart
local onCountdownEnded = timeElapsed.callins.CountdownEnded

describe("mission_api.triggers.time_elapsed", function()
	local function trigger(parameters, settings)
		return Builders.Trigger.new():WithParameters(parameters):WithSettings(settings):Build()
	end

	-- Starts the mission on startFrame (0 by default), then runs the countdowns for the
	-- frames after it, as api_missions_triggers.lua does, and returns the frames after the
	-- start on which context.ActivateTrigger was invoked.
	local function firedFrames(triggerTable, maxFrame, startFrame)
		startFrame = startFrame or 0
		GG["MissionAPI"].Countdowns = {}
		local fired = {}
		local context = Builders.TriggerContext.new():Build()
		currentFrame = startFrame
		onGameStart(triggerTable, "t", context)
		-- The game ticks the countdowns on the start frame too, after GameStart.
		countdowns.Decrement(startFrame)
		for frame = 1, maxFrame do
			currentFrame = startFrame + frame
			-- Re-pointed each frame, so the recorded value is the frame that fired.
			context.ActivateTrigger = function()
				fired[#fired + 1] = frame
			end
			local endedIDs = countdowns.Decrement(currentFrame)
			for _, countdownID in ipairs(endedIDs) do
				onCountdownEnded(triggerTable, "t", context, countdownID)
			end
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

	it("counts from the frame the mission started on", function()
		assert.are.same({ 60 }, firedFrames(trigger({ seconds = 2 }), 90, 450))
		assert.are.same({ 45 }, firedFrames(trigger({ seconds = 1.5 }), 90, 457))
	end)

	it("runs on a hidden countdown named after the trigger", function()
		GG["MissionAPI"].Countdowns = {}
		currentFrame = 0
		onGameStart(trigger({ seconds = 3 }), "ambush", Builders.TriggerContext.new():Build())
		local countdown = assert(GG["MissionAPI"].Countdowns.__timeElapsed_ambush)
		assert.is_false(countdown.displayed)
		assert.are.equal(3, countdown.timeRemaining)
	end)

	it("ignores countdowns that are not its own", function()
		local fired = 0
		local context = Builders.TriggerContext.new():Build()
		context.ActivateTrigger = function()
			fired = fired + 1
		end
		onCountdownEnded(trigger({ seconds = 1 }), "t", context, "evacuate")
		onCountdownEnded(trigger({ seconds = 1 }), "t", context, "__timeElapsed_other")
		assert.are.equal(0, fired)
	end)
end)
