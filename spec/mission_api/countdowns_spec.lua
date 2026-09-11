require("spec_helper")

local countdowns = VFS.Include("luarules/mission_api/countdowns.lua")

describe("mission_api.countdowns", function()
	---@type number
	local currentFrame

	before_each(function()
		GG["MissionAPI"] = { Countdowns = {} }
		currentFrame = 0
		-- GetGameFrame returns frameNum % dayFrames and frameNum / dayFrames; a
		-- spec never reaches a second day, so the day count is always 0.
		Spring.GetGameFrame = function()
			return currentFrame, 0
		end
	end)

	local function get(countdownID)
		return GG["MissionAPI"].Countdowns[countdownID]
	end

	-- Decrement() takes the current game frame, as the gadget passes it every
	-- frame. tickSecond() advances the clock to the next whole second and ticks,
	-- driving the shared cadence of displayed countdowns.
	local function tickSecond()
		currentFrame = currentFrame + Game.gameSpeed - (currentFrame % Game.gameSpeed)
		return countdowns.Decrement(currentFrame)
	end

	-- Consume the one-tick buffer a newly added countdown starts with, so tests
	-- about ticking proper don't each have to spell out the extra tick.
	-- Only for a test's first countdown: the tickSecond() ticks everything else.
	local function addTicking(countdownID, seconds)
		countdowns.AddCountdown(countdownID, seconds)
		tickSecond()
	end

	describe("AddCountdown", function()
		it("adds an unpaused countdown with the given time", function()
			countdowns.AddCountdown("evacuate", 120)

			local countdown = get("evacuate")
			assert.are.equal("evacuate", countdown.id)
			assert.are.equal(120, countdown.timeRemaining)
			assert.is_false(countdown.paused)
		end)

		it("stores displayed, defaulting to true", function()
			countdowns.AddCountdown("shown", 10)
			countdowns.AddCountdown("hidden", 10, false)

			assert.is_true(get("shown").displayed)
			assert.is_false(get("hidden").displayed)
		end)

		it("rounds to whole seconds and clamps negative time to 0", function()
			countdowns.AddCountdown("fractional", 9.6)
			countdowns.AddCountdown("negative", -5)

			assert.are.equal(10, get("fractional").timeRemaining)
			assert.are.equal(0, get("negative").timeRemaining)
		end)

		it("replaces an existing countdown with the same ID, held again", function()
			addTicking("timer", 10)
			tickSecond()
			assert.are.equal(9, get("timer").timeRemaining)

			countdowns.AddCountdown("timer", 30)

			assert.are.equal(30, get("timer").timeRemaining)
			tickSecond() -- consumed as the hold-back tick
			assert.are.equal(30, get("timer").timeRemaining)
		end)
	end)

	describe("Decrement", function()
		it("holds a new countdown for one tick before counting down", function()
			countdowns.AddCountdown("fresh", 10)

			tickSecond()
			assert.are.equal(10, get("fresh").timeRemaining)

			tickSecond()
			assert.are.equal(9, get("fresh").timeRemaining)
		end)

		it("ticks every unpaused countdown down together", function()
			countdowns.AddCountdown("first", 10)
			countdowns.AddCountdown("second", 20)
			tickSecond() -- consume both hold-back ticks

			tickSecond()

			assert.are.equal(9, get("first").timeRemaining)
			assert.are.equal(19, get("second").timeRemaining)
		end)

		it("does not tick paused countdowns", function()
			countdowns.AddCountdown("paused", 10)
			countdowns.AddCountdown("running", 10)
			tickSecond() -- consume both hold-back ticks
			countdowns.PauseCountdown("paused")

			tickSecond()

			assert.are.equal(10, get("paused").timeRemaining)
			assert.are.equal(9, get("running").timeRemaining)
		end)

		it("resumes ticking after unpausing", function()
			addTicking("timer", 10)
			countdowns.PauseCountdown("timer")
			tickSecond()
			countdowns.UnpauseCountdown("timer")

			tickSecond()

			assert.are.equal(9, get("timer").timeRemaining)
		end)

		it("keeps the hold-back tick while paused", function()
			countdowns.AddCountdown("timer", 10)
			countdowns.PauseCountdown("timer")
			tickSecond()
			countdowns.UnpauseCountdown("timer")

			tickSecond() -- consumes the buffer instead of ticking
			assert.are.equal(10, get("timer").timeRemaining)

			tickSecond()
			assert.are.equal(9, get("timer").timeRemaining)
		end)

		it("removes a countdown that reaches 0 and returns its ID", function()
			addTicking("ending", 1)

			local endedIDs = tickSecond()

			assert.are.same({ "ending" }, endedIDs)
			assert.is_nil(get("ending"))
		end)

		it("returns every countdown that ended on the same tick", function()
			countdowns.AddCountdown("first", 1)
			countdowns.AddCountdown("second", 1)
			countdowns.AddCountdown("later", 5)
			tickSecond() -- consume the hold-back ticks

			local endedIDs = tickSecond()

			table.sort(endedIDs)
			assert.are.same({ "first", "second" }, endedIDs)
			assert.are.equal(4, get("later").timeRemaining)
		end)

		it("returns no IDs when nothing ended", function()
			addTicking("timer", 10)

			assert.are.same({}, tickSecond())
		end)

		it("returns each ticked countdown with its new time", function()
			countdowns.AddCountdown("first", 10)
			countdowns.AddCountdown("second", 20)
			tickSecond() -- consume both hold-back ticks

			local _, ticks = tickSecond()

			table.sort(ticks, function(a, b)
				return a.id < b.id
			end)
			assert.are.same({
				{ id = "first", timeRemaining = 9 },
				{ id = "second", timeRemaining = 19 },
			}, ticks)
		end)

		it("does not report held or paused countdowns as ticked", function()
			addTicking("paused", 10)
			countdowns.PauseCountdown("paused")
			countdowns.AddCountdown("held", 5)

			local _, ticks = tickSecond()

			assert.are.same({}, ticks)
		end)

		it("reports an ending countdown ticking to zero", function()
			addTicking("ending", 1)

			local endedIDs, ticks = tickSecond()

			assert.are.same({ "ending" }, endedIDs)
			assert.are.same({ { id = "ending", timeRemaining = 0 } }, ticks)
		end)
	end)

	describe("non-displayed countdowns", function()
		it("tick relative to their creation frame, without the hold-back", function()
			currentFrame = 47
			countdowns.AddCountdown("hidden", 10, false)

			for frame = 48, 76 do
				countdowns.Decrement(frame)
			end
			assert.are.equal(10, get("hidden").timeRemaining)

			countdowns.Decrement(77)
			assert.are.equal(9, get("hidden").timeRemaining)
		end)

		it("end after exactly their duration", function()
			currentFrame = 47
			countdowns.AddCountdown("hidden", 3, false)

			local endedIDs
			for frame = 48, 47 + 3 * 30 do
				endedIDs = countdowns.Decrement(frame)
			end

			assert.are.same({ "hidden" }, endedIDs)
			assert.is_nil(get("hidden"))
		end)

		it("SetTime restarts their cadence from the set frame", function()
			currentFrame = 47
			countdowns.AddCountdown("hidden", 10, false)
			countdowns.Decrement(77) -- first tick, 9 remaining

			currentFrame = 85
			countdowns.SetTime("hidden", 5)

			countdowns.Decrement(107) -- the old cadence frame: no tick
			assert.are.equal(5, get("hidden").timeRemaining)

			countdowns.Decrement(115) -- one second after the set
			assert.are.equal(4, get("hidden").timeRemaining)
		end)
	end)

	describe("CancelCountdown", function()
		it("removes the countdown so it never reports as ended", function()
			addTicking("canceled", 1)

			countdowns.CancelCountdown("canceled")

			assert.is_nil(get("canceled"))
			assert.are.same({}, tickSecond())
		end)
	end)

	describe("time adjustments", function()
		it("SetTime replaces the remaining time", function()
			addTicking("timer", 10)
			countdowns.SetTime("timer", 60)
			assert.are.equal(60, get("timer").timeRemaining)
		end)

		it("SetTime holds the countdown through its next tick, like a new countdown", function()
			addTicking("timer", 10)
			countdowns.SetTime("timer", 5)

			tickSecond() -- consumed as the hold-back tick
			assert.are.equal(5, get("timer").timeRemaining)

			tickSecond()
			assert.are.equal(4, get("timer").timeRemaining)
		end)

		it("AddTime extends the remaining time", function()
			addTicking("timer", 10)
			countdowns.AddTime("timer", 15)
			assert.are.equal(25, get("timer").timeRemaining)
		end)

		it("RemoveTime shortens the remaining time", function()
			addTicking("timer", 10)
			countdowns.RemoveTime("timer", 4)
			assert.are.equal(6, get("timer").timeRemaining)
		end)

		it("RemoveTime clamps at 0, ending the countdown on the next tick", function()
			addTicking("timer", 10)
			countdowns.RemoveTime("timer", 99)

			assert.are.equal(0, get("timer").timeRemaining)
			assert.are.same({ "timer" }, tickSecond())
		end)
	end)

	describe("unknown countdown IDs", function()
		it("are safe no-ops for every operation", function()
			assert.has_no.errors(function()
				countdowns.CancelCountdown("missing")
				countdowns.PauseCountdown("missing")
				countdowns.UnpauseCountdown("missing")
				countdowns.SetTime("missing", 10)
				countdowns.AddTime("missing", 10)
				countdowns.RemoveTime("missing", 10)
			end)
			assert.is_nil(get("missing"))
		end)
	end)

end)
