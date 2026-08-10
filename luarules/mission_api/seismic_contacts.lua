--------------------------------------------------------------------------------
--- Shared contact tracking for UnitSpottedBySeismic and UnitUnspottedBySeismic.
---
--- Each trigger reads the same ping series and must agree when a contact raises
--- and lowers the detection level. The per-trigger state still uses `context`.
--------------------------------------------------------------------------------

-- Automatic seismic pings are raised only on the unit's SlowUpdate when moveType->progressState is Active.
local SEISMIC_INTERVAL_FRAMES = 15
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
local SCORE_LIMIT = 8
--
-- The weakest contact reaches falloff in three intervals; by design, the score limit must exceed gain.
--
-- A weak contact then has `gain + 1` intervals (1.5s) to falloff, and a strong one, 8 intervals (4.0s).
-- Movement within the seismic radius increases detection score. A full score requires 2.0s of movement.
--
-- Expected falloff time from a full score solves E[T_s] = 1 + p*E[T_min(s+GAIN,LIMIT)] + (1-p)*E[T_s-1],
-- and climbs steeply as true-p approaches and passes the floor:
--     p = 0     -> 4.0s        p = 0.34 -> 20.5s       p = 0.67 -> 1.0h
--     p = 0.25  -> 10.7s       p = 0.50 -> 2.2min      p = 0.90 -> unreachable

-- Scores per [triggerID][unitID]. Each trigger file includes its own copy of this module, and
-- VFS.Include re-runs the file, so this clears whenever the trigger definitions are reloaded.
local contactsByTrigger = {}

---A unit sitting inside two allyTeams' coverages raises a ping for each allyTeam.
---We set a flag (rather than counting): an interval either found movement or not.
---@return boolean addedNewContact
local function recordPing(triggerID, unitID)
	local contacts = table.ensureTable(contactsByTrigger, triggerID)
	local contact = contacts[unitID]

	if contact then
		contact.pinged = true
		return false
	end

	contacts[unitID] = { score = 0, pinged = true }
	return true
end

---Fallen contacts are collected into `undetected` for triggers that report them and
---drop before we return them so the trigger is re-armed for those units either way.
---@return integer fallenOffCount
local function updateScores(triggerID, undetected)
	local contacts = contactsByTrigger[triggerID]
	if not contacts then
		return 0
	end

	local count = 0
	for unitID, contact in pairs(contacts) do
		if contact.pinged then
			contact.pinged = false
			contact.score = math.min(contact.score + SCORE_GAIN, SCORE_LIMIT)
		else
			contact.score = contact.score - 1
			if contact.score <= 0 then
				contacts[unitID] = nil
				count = count + 1
				if undetected then
					undetected[count] = unitID
				end
			end
		end
	end
	return count
end

local function forget(triggerID, unitID)
	local contacts = contactsByTrigger[triggerID]
	if contacts then
		contacts[unitID] = nil
	end
end

local function isIntervalEnd(frameNumber)
	return frameNumber % SEISMIC_INTERVAL_FRAMES == 0
end

return {
	IsIntervalEnd = isIntervalEnd,
	RecordPing    = recordPing,
	UpdateScores  = updateScores,
	Forget        = forget,
}
