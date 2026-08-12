require("spec_helper")

-- timers.lua captures GG['MissionAPI'].timers as an upvalue at load time, so it
-- must exist in GG['MissionAPI'] *before* VFS.Include is called. We keep the same
-- table object alive for the whole test run and wipe its contents in before_each
-- so every test starts from a clean slate.
GG['MissionAPI'] = GG['MissionAPI'] or {}
local timerState = {}
GG['MissionAPI'].timers = timerState

local timers = VFS.Include('luarules/mission_api/timers.lua')

local function clearTimers()
	for name in pairs(timerState) do timerState[name] = nil end
end

-- Counts the timers up for `frameCount` game frames, as the triggers gadget does.
local function runFrames(frameCount)
	for _ = 1, frameCount do
		timers.UpdateTimers()
	end
end

describe("mission_api.timers", function()

	before_each(function()
		clearTimers()
	end)

	-- ── SetTimer ──────────────────────────────────────────────────────────────

	describe("SetTimer", function()
		-- Assertions read the raw table directly so they do not depend on any
		-- other module function whose correctness has not yet been established.

		it("starts a timer at zero frames, running", function()
			timers.SetTimer('countdown')

			assert.are.equal(0, timerState['countdown'].frames)
			assert.is_false(timerState['countdown'].paused)
		end)

		it("restarts a running timer from zero", function()
			timers.SetTimer('countdown')
			runFrames(10)
			timers.SetTimer('countdown')

			assert.are.equal(0, timerState['countdown'].frames)
		end)

		it("restarts a paused timer as running", function()
			timers.SetTimer('countdown')
			timers.PauseTimer('countdown')
			timers.SetTimer('countdown')

			assert.is_false(timerState['countdown'].paused)
		end)
	end)

	-- ── UpdateTimers ──────────────────────────────────────────────────────────

	describe("UpdateTimers", function()
		it("counts up one frame per update", function()
			timers.SetTimer('countdown')
			runFrames(10)

			assert.are.equal(10, timerState['countdown'].frames)
		end)

		it("keeps counting for as long as the timer exists", function()
			timers.SetTimer('countdown')
			runFrames(10000)

			assert.are.equal(10000, timerState['countdown'].frames)
		end)

		it("counts timers up independently", function()
			timers.SetTimer('early')
			runFrames(10)
			timers.SetTimer('late')
			runFrames(10)

			assert.are.equal(20, timerState['early'].frames)
			assert.are.equal(10, timerState['late'].frames)
		end)
	end)

	-- ── PauseTimer ────────────────────────────────────────────────────────────

	describe("PauseTimer", function()
		it("stops the timer counting", function()
			timers.SetTimer('countdown')
			runFrames(10)
			timers.PauseTimer('countdown')
			runFrames(100)

			assert.is_true(timerState['countdown'].paused)
			assert.are.equal(10, timerState['countdown'].frames)
		end)

		it("resumes counting from the frames counted so far when paused = false", function()
			timers.SetTimer('countdown')
			runFrames(10)
			timers.PauseTimer('countdown')
			runFrames(100)
			timers.PauseTimer('countdown', false)
			runFrames(5)

			assert.is_false(timerState['countdown'].paused)
			-- The 100 frames it spent paused are not counted:
			assert.are.equal(15, timerState['countdown'].frames)
		end)

		it("leaves other timers counting", function()
			timers.SetTimer('paused')
			timers.SetTimer('running')
			timers.PauseTimer('paused')
			runFrames(10)

			assert.are.equal(0, timerState['paused'].frames)
			assert.are.equal(10, timerState['running'].frames)
		end)

		it("ignores an unknown timer name", function()
			timers.PauseTimer('nosuchtimer')

			assert.is_nil(timerState['nosuchtimer'])
		end)
	end)

	-- ── RemoveTimer ───────────────────────────────────────────────────────────

	describe("RemoveTimer", function()
		it("removes the timer", function()
			timers.SetTimer('countdown')
			runFrames(10)
			timers.RemoveTimer('countdown')

			assert.is_nil(timerState['countdown'])
		end)

		it("stops it being counted up", function()
			timers.SetTimer('countdown')
			timers.RemoveTimer('countdown')
			runFrames(10)

			assert.is_nil(timerState['countdown'])
		end)

		it("ignores an unknown timer name", function()
			timers.RemoveTimer('nosuchtimer')

			assert.is_nil(timerState['nosuchtimer'])
		end)
	end)

	-- ── Timer state read by triggers ──────────────────────────────────────────

	describe("GetTimerFrames", function()
		it("returns the frames the timer has counted", function()
			timers.SetTimer('countdown')
			runFrames(10)

			assert.are.equal(10, timers.GetTimerFrames('countdown'))
		end)

		it("returns zero for a timer that has just been set", function()
			timers.SetTimer('countdown')

			assert.are.equal(0, timers.GetTimerFrames('countdown'))
		end)

		it("does not count the frames a timer spent paused", function()
			timers.SetTimer('countdown')
			runFrames(10)
			timers.PauseTimer('countdown')
			runFrames(100)
			timers.PauseTimer('countdown', false)
			runFrames(10)

			assert.are.equal(20, timers.GetTimerFrames('countdown'))
		end)

		it("returns nil for an unknown timer name", function()
			assert.is_nil(timers.GetTimerFrames('nosuchtimer'))
		end)

		it("returns nil for a removed timer", function()
			timers.SetTimer('countdown')
			runFrames(10)
			timers.RemoveTimer('countdown')

			assert.is_nil(timers.GetTimerFrames('countdown'))
		end)
	end)
end)
