--------------------------------------------------------------------------------
--- Shared contact tracking and state magic for UnitDetected and UnitUndetected.
---
--- The engine holds no seismic bit, so this is the one detection level we keep
--- ourselves. It is a property of a unit and an allyTeam, not of any trigger,
--- so filtering belongs to the triggers reading it. See detection_levels.lua.
--------------------------------------------------------------------------------

-- Automatic seismic pings are raised only on the unit's SlowUpdate when moveType->progressState is Active.
--
-- We are "sampling" over time intervals of at least this length (half a second), then, and our detection
-- heuristic is a type of Bernoulli walk over those intervals, though non-automatic pings also can occur.
--
-- Note: `p` is the Bernoulli parameter we used for the sample stream. The "true" `p` is the underlying
-- probability that any one 15-frame interval produces a matching ping for the specific unit. Intervals
-- are weighted as a coin flip; so our `p` is generally very conservative so we can identify cheaters.
--
-- It is perfectly possible to stutter-step your way through infinite seismic detectors on RecoilEngine.
-- You just have to be either a genius or a computer. So low detection rates become longer falloff time.

-- Configuration ---------------------------------------------------------------

-- * To get a guaranteed time-to-undetected after departure, use: time = SCORE_LIMIT / 2.
-- * To get a guaranteed time-to-flap after first detection, use: time = DWELL_INTERVALS / 2.
-- * To get a ping rate that neither gains nor loses score, use: freq = 1 / (1 + SCORE_GAIN).
-- * Keep SCORE_GAIN as it is. +2/-1 (described below) are built on the log-likelihood.
-- * Keep the DWELL below the LIMIT, so single pings fall out noticeably faster than clusers.

-- A ping adds SCORE_GAIN and an empty interval subtracts one. The score is held within [0, SCORE_LIMIT].
local SCORE_GAIN = 2
--
-- Drift per interval at a true ping rate p is p * SCORE_GAIN - (1 - p), which is zero at:
--     p* = 1 / (1 + SCORE_GAIN)
--
-- Below p* the score drifts down toward falloff; above it, upward. SCORE_GAIN = 2 puts the floor at
-- p* = 1/3, so stutter-stepping to sit still through two of every three slow updates reads as a low
-- detection rate rather than as a loss of detection.

-- A contact holding a full score and then going undetected falls off in exactly SCORE_LIMIT intervals.
local SCORE_LIMIT = 16
--
-- The weakest contact reaches falloff in three intervals; by design, the score limit must exceed gain.
-- A full score takes 8 pings (4.0s of movement) to build and 16 intervals (8.0s) to drain, and a weak
-- contact drains sooner but is then held for DWELL_INTERVALS, so releases run from 4.0s to 8.0s.
--
-- Expected falloff from a full score solves E[T_s] = 1 + p*E[T_min(s+GAIN,LIMIT)] + (1-p)*E[T_s-1], with
-- E[T_0] = 0. All ping rates (p) below 1.0 eventually reach falloff but over an exponentially increasing
-- time curve beginning from the fixed rate (p* = 1 / (1 + gain) = 0.33) and up, and a gentle trend below.
--     p = 0     ->  8.0s       p = 0.33 ->  70.7s      p = 0.50 ->   1.9 hours
--     p = 0.25  -> 26.1s       p = 0.40 ->   4.8min    p = 0.60 -> 112.0 hours

-- A contact is held for at least this many intervals before any falloff is reported.
local DWELL_INTERVALS = 8
--
-- Score alone leaves symmetric triggers worst-behaved at low ping rates, not high ones. A lone ping reaches
-- falloff in three intervals, so a unit pinging seldom spends each one on a complete spotted/unspotted cycle.
-- Both triggers peak at around p = 0.2 with nearly 24 transitions/min, at a flap rate of every five seconds.
--
-- With "dwell" intervals and the same scenario, p = 0.2:
--     dwell = 0 -> 24 per min     dwell = 8  -> 15 per min
--     dwell = 4 -> 20 per min     dwell = 16 -> 10 per min
--
-- Holding a contact for an interval floor merges them into one detection and keeps the falloff distribution.
-- The cost is that any detected unit remains "spotted" for some time after it has left the detection radius.

-- Module code -----------------------------------------------------------------

local SEISMIC_INTERVAL_FRAMES = math.floor(0.5 * Game.gameSpeed) -- on SlowUpdates

-- Contacts : [allyTeamID][unitID]. A unit inside two allyTeams' coverages is a contact for
-- each of them separately, since each hears its own ping and holds its own detection level.
local contactsByAllyTeam = {}

---We set a flag (rather than counting); an interval either found movement or not.
local function recordPing(allyTeamID, unitID)
	local contacts = table.ensureTable(contactsByAllyTeam, allyTeamID)
	local contact = contacts[unitID]

	if contact then
		contact.pinged = true
		return
	end

	contacts[unitID] = { score = 0, pinged = true, intervals = 0 }
end

---Whether the unit is a seismic contact with detection level 1.
---@return boolean
local function isContact(unitID, allyTeamID)
	local contacts = contactsByAllyTeam[allyTeamID]
	return contacts ~= nil and contacts[unitID] ~= nil
end

---Scores an interval for every contact of every allyTeam, dropping any that have fallen off.
---Fallen units are collected into `undetected` so their detection level can be reevaluated.
---@return integer fallenOffCount
local function updateContacts(undetected)
	local count = 0
	for _, contacts in pairs(contactsByAllyTeam) do
		for unitID, contact in pairs(contacts) do
			if contact.pinged then
				contact.pinged = false
				contact.score = math.min(contact.score + SCORE_GAIN, SCORE_LIMIT)
			else
				contact.score = contact.score - 1
				if contact.score <= 0 then
					if contact.intervals >= DWELL_INTERVALS then
						contacts[unitID] = nil
						count = count + 1
						undetected[count] = unitID
					else
						contact.score = 0 -- locked while being held for the dwell period
					end
				end
			end
			contact.intervals = contact.intervals + 1
		end
	end
	return count -- Allows table reuse without tombstones.
end

-- Export ----------------------------------------------------------------------

return {
	IsContact = isContact,
	RecordPing = recordPing,
	UpdateContacts = updateContacts,
	UpdateInterval = SEISMIC_INTERVAL_FRAMES,
}
