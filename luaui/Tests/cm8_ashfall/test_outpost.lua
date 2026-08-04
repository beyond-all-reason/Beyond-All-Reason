---@diagnostic disable: lowercase-global, undefined-field

-- CM8 Ashfall, Beat 2: the outpost changes hands, but only once it is seen.
--
-- The roster spawns the outpost on Gaia — pilotless, story-critical — and
-- Transfer.Give hands it to the player. That is fiat, not a share: Gaia is
-- nobody's ally, so no sharing mode can permit the move and the mission is not
-- asking permission.
--
-- Two things are worth a real game rather than a spec here.
--
-- The give itself: it once ran, reported success, and moved nothing, because
-- Spring.TransferUnit fires AllowUnitTransfer and the sharing policy answered
-- the question the fiat was supposed to have skipped. A mission whose opening
-- beat is "you inherit this base" instead left the base in hostile hands.
--
-- And the gate: the hand-over waits on Unit(...).IsSpotted, so the base must
-- stay Gaia's while the hub is under fog and move the moment it is seen. Both
-- halves are asserted, because only checking the second would pass just as
-- well with no gate at all.
--
-- Vision arrives via /globallos, which is how a player testing a mission grants
-- it. Worth recording: that DOES raise UnitEnteredLos, so the condition's
-- watcher wakes normally — measured, not assumed, by running this against a
-- polling version of IsSpotted and finding no difference.
--
-- Needs the same game as the waves scenario, for the same reason — the mission
-- cannot arm without an enemy team for the enclave:
--
--   spring-headless --isolation \
--     tools/headless_testing/startscript_cm8_waves.txt
--
-- Everywhere else it self-skips.

-- The outpost is six structures. Match by def so this does not depend on the
-- runtime's group bookkeeping — the question is where the units ARE, not where
-- the mission believes it put them.
local OUTPOST_DEFS = {
	corlab = true,
	corllt = true,
	corrad = true,
	corsolar = true,
}

local ARM_TIMEOUT = 900
-- Long enough that a hand-over which ignores the gate has had every chance to
-- happen: the give sits on MatchFlow.Started, which resolves on the first
-- cadence after arming.
-- Kept under the 30s that cm8's waves trigger waits before starting a
-- director: this scenario runs both tests in one game, and a director that
-- starts here is still running when the waves test arms.
local FOG_HOLD_FRAMES = 8 * 30

local function countOutpost(teamID)
	local found = 0
	for _, unitID in ipairs(Spring.GetTeamUnits(teamID) or {}) do
		local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
		if unitDef and OUTPOST_DEFS[unitDef.name] then
			found = found + 1
		end
	end
	return found
end

function skip()
	if Spring.GetGameFrame() <= 0 then
		return true
	end
	local gaia = Spring.GetGaiaTeamID()
	local playerTeamID = Spring.GetLocalTeamID()
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= gaia and teamID ~= playerTeamID then
			return false
		end
	end
	return true
end

---The player's allyteam, which is what /globallos actually takes: the command
---argument is an ALLYTEAM ID and the call TOGGLES it. "globallos 1" does not
---mean "on" — it means "flip allyteam 1", which on this scenario is the enemy.
local function playerAllyTeam()
	return select(6, Spring.GetTeamInfo(Spring.GetLocalTeamID(), false))
end

--- Because the command toggles, cleanup has to know whether the test already
--- flipped it back. Leaving the map dark would blind the waves test, which
--- shares this game and counts other teams' units.
local revealed = false

function setup()
	revealed = false
	Test.clearMap()
	-- The scenario's startscript turns global LOS on for every allyteam. That
	-- is the one thing this test cannot have: it would spot the outpost at
	-- spawn and the gate would be open before the mission armed.
	Spring.SendCommands("globallos " .. playerAllyTeam())
end

function cleanup()
	Test.clearMap()
	if not revealed then
		Spring.SendCommands("globallos " .. playerAllyTeam())
	end
end

function test()
	local playerTeamID = Spring.GetLocalTeamID()
	local gaiaTeamID = Spring.GetGaiaTeamID()

	assert(countOutpost(playerTeamID) == 0, "the outpost must not be the player's before the mission arms")

	Spring.SendCommands("luarules mission cm8_ashfall")
	Test.waitUntil(function()
		return Spring.GetGameRulesParam("mission_active") == 1
	end, ARM_TIMEOUT)

	-- Under fog the base stays where it is. This is the assertion the gate
	-- exists for, and the one that fails if the give goes back to firing on
	-- MatchFlow.Started alone.
	Test.waitFrames(FOG_HOLD_FRAMES)

	-- While it is nobody's, it is inert. Gaia shoots at everyone, so without
	-- this the player is fired on by the base they came to inherit.
	local gaiaOutpost = 0
	local gaiaInert = 0
	local gaiaArmed = 0
	for _, unitID in ipairs(Spring.GetTeamUnits(gaiaTeamID) or {}) do
		local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
		if unitDef and OUTPOST_DEFS[unitDef.name] then
			gaiaOutpost = gaiaOutpost + 1
			if Spring.GetUnitNeutral(unitID) then
				gaiaInert = gaiaInert + 1
			end
			-- Only units that can actually shoot. Fire state is meaningless on
			-- a solar collector: the engine ignores the order and reports the
			-- default, which counts as "armed" and says nothing.
			if #(unitDef.weapons or {}) > 0 then
				local states = Spring.GetUnitStates(unitID) or {}
				-- 0 hold fire, 1 return fire, 2 fire at will.
				if (states.firestate or 2) > 0 then
					gaiaArmed = gaiaArmed + 1
				end
			end
		end
	end
	assert(gaiaOutpost > 0, "the outpost should still be gaia's at this point")
	assert(gaiaInert == gaiaOutpost,
		("every unheld outpost unit must be inert, %d of %d were"):format(gaiaInert, gaiaOutpost))
	-- Neutral only stops it being SHOT AT. Holding fire is what stops the
	-- towers shooting the player who came to find them, and it is the half
	-- that was missing the first time.
	assert(gaiaArmed == 0,
		("%d unheld outpost weapons were still willing to open fire"):format(gaiaArmed))
	assert(countOutpost(playerTeamID) == 0,
		"the outpost must not change hands while the command hub is unseen")

	-- Reveal it, with no unit moving and so no edge to report. Toggling the
	-- player's own allyteam back on is what "reveal" means here.
	Spring.SendCommands("globallos " .. playerAllyTeam())
	revealed = true

	-- Split deliberately: the latch answers "did the engine report the unit
	-- being seen", the transfer answers "did the trigger act on it". When this
	-- broke, knowing which of the two failed was the whole diagnosis.
	local allyTeamID = select(6, Spring.GetTeamInfo(playerTeamID, false))
	local latch = "mission_unit_spotted_outpost_command_hub_" .. tostring(allyTeamID)
	Test.waitUntil(function()
		return Spring.GetGameRulesParam(latch) == 1
	end, ARM_TIMEOUT)

	Test.waitUntil(function()
		return countOutpost(playerTeamID) >= 6
	end, ARM_TIMEOUT)

	assert(countOutpost(gaiaTeamID) == 0,
		"every unit in the group moves, or the player inherits half a base")

	-- And it gets its teeth back: hold fire is not cleared by a transfer, so
	-- an inherited base would otherwise sit out the waves it exists to survive.
	for _, unitID in ipairs(Spring.GetTeamUnits(playerTeamID) or {}) do
		local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
		if unitDef and OUTPOST_DEFS[unitDef.name] and #(unitDef.weapons or {}) > 0 then
			local states = Spring.GetUnitStates(unitID) or {}
			assert((states.firestate or 0) > 0,
				"a handed-over outpost must be willing to defend its new owner")
		end
	end

	-- Deliberately NOT asserting that the handed-over units are no longer
	-- neutral. The engine clears the flag during the transfer, but the value a
	-- widget reads does not follow a change made after the unit was already
	-- visible — synced said false while this side still said true. Asserting it
	-- from here would be testing the staleness, not the behaviour.
end
