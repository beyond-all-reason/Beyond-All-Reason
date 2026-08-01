---@diagnostic disable: lowercase-global, undefined-field

-- CM8 Ashfall, Beat 2: the outpost changes hands.
--
-- The roster spawns the outpost on Gaia — pilotless, story-critical — and
-- Transfer.Give hands it to the player at match start. That is fiat, not a
-- share: Gaia is nobody's ally, so no sharing mode can permit the move and
-- the mission is not asking permission.
--
-- Which is precisely what made this worth a test. Give ran, reported success,
-- and the units did not move, because Spring.TransferUnit fires
-- AllowUnitTransfer and the sharing policy answered the question the fiat was
-- supposed to have skipped. A mission whose opening beat is "you inherit this
-- base" instead left the base in hostile hands.
--
-- Needs the same game as the waves scenario, for the same reason — the
-- mission cannot arm without an enemy team for the enclave:
--
--   spring-headless --isolation \
--     tools/headless_testing/startscript_cm8_waves.txt
--
-- Everywhere else it self-skips.

-- The outpost is six structures. Match by def so this does not depend on the
-- runtime's group bookkeeping — the question is where the units ARE, not
-- where the mission believes it put them.
local OUTPOST_DEFS = {
	corlab = true,
	corllt = true,
	corrad = true,
	corsolar = true,
}

local ARM_TIMEOUT = 900

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

function setup()
	Test.clearMap()
end

function cleanup()
	Test.clearMap()
end

function test()
	local playerTeamID = Spring.GetLocalTeamID()
	local gaiaTeamID = Spring.GetGaiaTeamID()

	assert(countOutpost(playerTeamID) == 0, "the outpost must not be the player's before the mission arms")

	Spring.SendCommands("luarules mission cm8_ashfall")
	Test.waitUntil(function()
		return Spring.GetGameRulesParam("mission_active") == 1
	end, ARM_TIMEOUT)

	-- The give is on MatchFlow.Started with no delay, so it lands on the first
	-- cadence after arming. Waiting on the units rather than on the trigger:
	-- the trigger firing was never the part that broke.
	Test.waitUntil(function()
		return countOutpost(playerTeamID) >= 6
	end, ARM_TIMEOUT)

	assert(countOutpost(gaiaTeamID) == 0,
		"every unit in the group moves, or the player inherits half a base")
end
