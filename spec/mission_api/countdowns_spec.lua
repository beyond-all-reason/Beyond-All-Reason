require("spec_helper")

local countdowns = VFS.Include("luarules/mission_api/countdowns.lua")

describe("mission_api.countdowns", function()
	before_each(function()
		GG["MissionAPI"] = { Countdowns = {} }
	end)

	local function get(countdownID)
		return GG["MissionAPI"].Countdowns[countdownID]
	end

	-- Consume the one-tick buffer a newly added countdown starts with, so tests
	-- about ticking proper don't each have to spell out the extra Decrement().
	-- Only for a test's first countdown: the Decrement() ticks everything else.
	local function addTicking(countdownID, seconds)
		countdowns.AddCountdown(countdownID, seconds)
		countdowns.Decrement()
	end

	describe("AddCountdown", function()
		it("adds an unpaused countdown with the given time", function()
			countdowns.AddCountdown("evacuate", 120)

			local countdown = get("evacuate")
			assert.are.equal("evacuate", countdown.id)
			assert.are.equal(120, countdown.timeRemaining)
			assert.is_false(countdown.paused)
		end)

		it("rounds to whole seconds and clamps negative time to 0", function()
			countdowns.AddCountdown("fractional", 9.6)
			countdowns.AddCountdown("negative", -5)

			assert.are.equal(10, get("fractional").timeRemaining)
			assert.are.equal(0, get("negative").timeRemaining)
		end)

		it("replaces an existing countdown with the same ID, held again", function()
			addTicking("timer", 10)
			countdowns.Decrement()
			assert.are.equal(9, get("timer").timeRemaining)

			countdowns.AddCountdown("timer", 30)

			assert.are.equal(30, get("timer").timeRemaining)
			countdowns.Decrement() -- consumed as the hold-back tick
			assert.are.equal(30, get("timer").timeRemaining)
		end)
	end)

	describe("Decrement", function()
		it("holds a new countdown for one tick before counting down", function()
			countdowns.AddCountdown("fresh", 10)

			countdowns.Decrement()
			assert.are.equal(10, get("fresh").timeRemaining)

			countdowns.Decrement()
			assert.are.equal(9, get("fresh").timeRemaining)
		end)

		it("ticks every unpaused countdown down together", function()
			countdowns.AddCountdown("first", 10)
			countdowns.AddCountdown("second", 20)
			countdowns.Decrement() -- consume both hold-back ticks

			countdowns.Decrement()

			assert.are.equal(9, get("first").timeRemaining)
			assert.are.equal(19, get("second").timeRemaining)
		end)

		it("does not tick paused countdowns", function()
			countdowns.AddCountdown("paused", 10)
			countdowns.AddCountdown("running", 10)
			countdowns.Decrement() -- consume both hold-back ticks
			countdowns.PauseCountdown("paused")

			countdowns.Decrement()

			assert.are.equal(10, get("paused").timeRemaining)
			assert.are.equal(9, get("running").timeRemaining)
		end)

		it("resumes ticking after unpausing", function()
			addTicking("timer", 10)
			countdowns.PauseCountdown("timer")
			countdowns.Decrement()
			countdowns.UnpauseCountdown("timer")

			countdowns.Decrement()

			assert.are.equal(9, get("timer").timeRemaining)
		end)

		it("keeps the hold-back tick while paused", function()
			countdowns.AddCountdown("timer", 10)
			countdowns.PauseCountdown("timer")
			countdowns.Decrement()
			countdowns.UnpauseCountdown("timer")

			countdowns.Decrement() -- consumes the buffer instead of ticking
			assert.are.equal(10, get("timer").timeRemaining)

			countdowns.Decrement()
			assert.are.equal(9, get("timer").timeRemaining)
		end)

		it("removes a countdown that reaches 0 and returns its ID", function()
			addTicking("ending", 1)

			local endedIDs = countdowns.Decrement()

			assert.are.same({ "ending" }, endedIDs)
			assert.is_nil(get("ending"))
		end)

		it("returns every countdown that ended on the same tick", function()
			countdowns.AddCountdown("first", 1)
			countdowns.AddCountdown("second", 1)
			countdowns.AddCountdown("later", 5)
			countdowns.Decrement() -- consume the hold-back ticks

			local endedIDs = countdowns.Decrement()

			table.sort(endedIDs)
			assert.are.same({ "first", "second" }, endedIDs)
			assert.are.equal(4, get("later").timeRemaining)
		end)

		it("returns no IDs when nothing ended", function()
			addTicking("timer", 10)

			assert.are.same({}, countdowns.Decrement())
		end)

		it("returns each ticked countdown with its new time", function()
			countdowns.AddCountdown("first", 10)
			countdowns.AddCountdown("second", 20)
			countdowns.Decrement() -- consume both hold-back ticks

			local _, ticks = countdowns.Decrement()

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

			local _, ticks = countdowns.Decrement()

			assert.are.same({}, ticks)
		end)

		it("reports an ending countdown ticking to zero", function()
			addTicking("ending", 1)

			local endedIDs, ticks = countdowns.Decrement()

			assert.are.same({ "ending" }, endedIDs)
			assert.are.same({ { id = "ending", timeRemaining = 0 } }, ticks)
		end)
	end)

	describe("CancelCountdown", function()
		it("removes the countdown so it never reports as ended", function()
			addTicking("canceled", 1)

			countdowns.CancelCountdown("canceled")

			assert.is_nil(get("canceled"))
			assert.are.same({}, countdowns.Decrement())
		end)
	end)

	describe("time adjustments", function()
		it("SetTime replaces the remaining time", function()
			addTicking("timer", 10)
			countdowns.SetTime("timer", 60)
			assert.are.equal(60, get("timer").timeRemaining)
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
			assert.are.same({ "timer" }, countdowns.Decrement())
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
