require("spec_helper")
require("mission_api.spec_helper")

local SeismicContacts = VFS.Include('luarules/mission_api/seismic_contacts.lua')

-- These boundaries are not based on the actual configuration values in the specced file.
-- We want these values to be, actually, configurable. And we can admit to ourselves that
-- though the design looks like it is handling an underlying mathematical reality of ping
-- streams and discrete intervals and what they indicate for signal processing, the real
-- design target is human-perceptual, not mathematical-definite, so we can do the below:

local SATURATING_INTERVALS = 64 -- more pinged intervals than any cap should need to fill
local LONGEST_RUN = 512         -- more silent intervals than any contact should survive
local SLOWEST_PERIOD = 12       -- slower than any break-even ping period should sit
local RUN_CYCLES = 100          -- ping cycles long enough for a losing rate to drain a full score

-- Tests, then, must not name a configuration value or number. They measure what the module does;
-- they assert the relationships that the design requires; they hold up after fudging the numbers.

describe("mission_api.seismic_contacts", function()
	local ALLY, OTHER_ALLY = 0, 1
	local undetected
	local nextUnitID

	-- Each contact is global to the module rather than per-trigger, and the spec helper caches includes.
	-- So each test drains any possible score (even under ludicrous configs) from any test before itself.
	before_each(function()
		undetected = {}
		nextUnitID = 1000
		for _ = 1, LONGEST_RUN do
			SeismicContacts.UpdateContacts(undetected)
		end
	end)

	-- Contacts are globally tracked so must be unique across tests.
	local function freshUnitID()
		nextUnitID = nextUnitID + 1
		return nextUnitID
	end

	---Advances one scoring interval, optionally pinging units first.
	---@return integer fallenOffCount
	local function advance(pingedUnitIDs, allyTeamID)
		for _, unitID in ipairs(pingedUnitIDs or {}) do
			SeismicContacts.RecordPing(allyTeamID or ALLY, unitID)
		end
		return SeismicContacts.UpdateContacts(undetected)
	end

	local function silence(intervals)
		for _ = 1, intervals do
			advance()
		end
	end

	---NB: Cannot distinguish between a fallen->retriggered contact.
	local function isContact(unitID, allyTeamID)
		return SeismicContacts.IsContact(unitID, allyTeamID or ALLY)
	end

	local function isFallenContact(fallenOffCount, unitID)
		for index = 1, fallenOffCount do
			if undetected[index] == unitID then
				return true
			end
		end
		return false
	end

	---This is a concentrated example for what it means to test over a loose configuration.
	---@return integer intervalsSurvived
	local function lockedAfterPinging(pingedIntervals)
		local unitID = freshUnitID()
		for _ = 1, pingedIntervals do
			advance({ unitID })
		end
		for survived = 1, LONGEST_RUN do
			advance()
			if not isContact(unitID) then
				return survived
			end
		end
		return LONGEST_RUN
	end

	---Whether a saturated contact survives a long run of pinging once every `period` intervals
	---without ever being dropped. Read from the falloff reports rather than from the contacts
	---directly since a ping after a falloff opens a fresh contact that would look like the old.
	local function holdsAtPingPeriod(period)
		local unitID = freshUnitID()
		for _ = 1, SATURATING_INTERVALS do
			advance({ unitID })
		end

		for _ = 1, RUN_CYCLES do
			if isFallenContact(advance({ unitID }), unitID) then
				return false
			end
			for _ = 2, period do
				if isFallenContact(advance(), unitID) then
					return false
				end
			end
		end
		return true
	end

	describe("scoring an interval", function()
		it("raises a contact on the first ping", function()
			SeismicContacts.RecordPing(ALLY, 100)
			assert.is_true(isContact(100))
		end)

		it("holds no contact for a unit that never pinged", function()
			assert.is_false(isContact(100))
		end)

		-- An interval either found movement or it did not. A unit inside two allyTeams'
		-- coverages raises a ping for each, and extra pings must not buy extra score,
		-- so maybe this ought to be a test for only that? Or figure out something else?
		it("scores an interval once no matter how many pings it held", function()
			local once, many = freshUnitID(), freshUnitID()
			SeismicContacts.RecordPing(ALLY, once)
			for _ = 1, 10 do
				SeismicContacts.RecordPing(ALLY, many)
			end
			advance()

			for _ = 1, LONGEST_RUN do
				advance()
				if not isContact(once) then break end
			end
			assert.is_false(isContact(many)) -- counting them would outlive the single ping
		end)
	end)

	describe("time to undetected", function()
		-- The dwell floor must stay under the cap, so a unit passing through releases sooner
		-- than one that settled in. Were they equal, every contact would release together.
		it("holds a saturated contact longer than a passing one", function()
			local passing = lockedAfterPinging(1)
			local settled = lockedAfterPinging(SATURATING_INTERVALS)
			assert.is_true(settled > passing)
		end)

		it("always releases a unit that stops pinging", function()
			assert.is_true(lockedAfterPinging(SATURATING_INTERVALS) < LONGEST_RUN)
		end)

		-- The cap is what makes the guarantee a guarantee: no amount of extra movement
		-- can buy a longer stay than a full score already does.
		it("does not hold a contact any longer for pinging past the cap", function()
			local filled = lockedAfterPinging(SATURATING_INTERVALS)
			local overfilled = lockedAfterPinging(SATURATING_INTERVALS * 4)
			assert.are.equal(filled, overfilled)
		end)

		it("releases on one exact interval, having held the one before it", function()
			local unitID = freshUnitID()
			advance({ unitID })
			local survived = 0
			for _ = 1, LONGEST_RUN do
				if not isContact(unitID) then break end
				survived = survived + 1
				advance()
			end

			assert.is_true(survived > 0)
			assert.is_false(isContact(unitID))
		end)
	end)

	-- The score rises by a gain and falls by one, so there is a ping period below which a
	-- contact holds forever and above which it drains. That threshold is for anti-exploit
	-- where a stutter-stepper can avoid emitting seismic pings by moving outside updates.
	describe("the break-even ping period", function()
		-- Could be derived but then the test may break later. Just probe for the value.
		local function findBreakEven()
			for period = 1, SLOWEST_PERIOD do
				if not holdsAtPingPeriod(period) then
					return period
				end
			end
		end

		it("drops a unit pinging slowly enough", function()
			assert.is_not_nil(findBreakEven())
		end)

		it("never drops a unit pinging every other interval", function()
			-- Any gain of one or more buys at least one interval of silence per ping.
			-- I probably screw up this test by not allowing config value based tests.
			assert.is_true(holdsAtPingPeriod(2))
		end)

		it("holds every period below the break-even, so the threshold is one edge", function()
			local breakEven = findBreakEven()
			for period = 1, breakEven - 1 do
				assert.is_true(holdsAtPingPeriod(period))
			end
		end)

		it("drops every period above the break-even", function()
			local breakEven = findBreakEven()
			for period = breakEven, SLOWEST_PERIOD do
				assert.is_false(holdsAtPingPeriod(period))
			end
		end)
	end)

	describe("reporting falloffs", function()
		it("reports a fallen contact so its detection level can be reevaluated", function()
			local unitID = freshUnitID()
			advance({ unitID })

			local reported = false
			for _ = 1, LONGEST_RUN do
				reported = reported or isFallenContact(advance(), unitID)
				if not isContact(unitID) then break end
			end
			assert.is_true(reported) -- Marks the contact dirty so the rest of the sensorType enum can be checked before dropping.
		end)

		it("reports nothing while every contact is still held", function()
			local unitID = freshUnitID()
			for _ = 1, SATURATING_INTERVALS do
				assert.are.equal(0, advance({ unitID }))
			end
		end)

		it("reports a fallen unit only once", function()
			local unitID = freshUnitID()
			advance({ unitID })

			local reports = 0
			for _ = 1, LONGEST_RUN do
				if isFallenContact(advance(), unitID) then
					reports = reports + 1
				end
			end
			assert.are.equal(1, reports)
		end)
	end)

	describe("allyTeams", function()
		it("tracks a unit separately for each allyTeam that hears it", function()
			advance({ 100 }, ALLY)
			assert.is_true(isContact(100, ALLY))
			assert.is_false(isContact(100, OTHER_ALLY))
		end)

		-- One unit, two allyTeams, two scores: the one still hearing it holds the contact
		-- while the one that stopped lets go, on its own pings rather than on the unit's.
		it("scores the same unit separately for each allyTeam", function()
			local unitID = freshUnitID()
			advance({ unitID }, OTHER_ALLY) -- heard here once, and never again
			for _ = 1, SATURATING_INTERVALS do
				advance({ unitID }, ALLY) -- still heard here on every interval
			end
			assert.is_true(isContact(unitID, ALLY))
			assert.is_false(isContact(unitID, OTHER_ALLY))
		end)
	end)
end)
