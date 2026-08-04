---@diagnostic disable: lowercase-global, undefined-field

-- CM8 Ashfall: the enemy ends up with exactly one commander.
--
-- The mission's story has one Armada commander and killing it wins. Dropped
-- into a game whose enemy seat is already occupied, a roster that SPAWNS its
-- commander leaves that team holding two — and the objective pointing at
-- whichever one the mission happened to create. So units.lua claims the
-- existing one where there is one, and builds at the enclave only where there
-- is not.
--
-- This counts what is actually on the field, which is the only way to tell the
-- two paths apart from outside.
--
--   spring-headless --isolation \
--     tools/headless_testing/startscript_cm8_waves.txt

local ARM_TIMEOUT = 900

local function countDef(teamID, defName)
	local n = 0
	for _, unitID in ipairs(Spring.GetTeamUnits(teamID) or {}) do
		local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
		if unitDef and unitDef.name == defName then
			n = n + 1
		end
	end
	return n
end

local function enemyTeamID()
	local gaia = Spring.GetGaiaTeamID()
	local mine = Spring.GetLocalTeamID()
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= gaia and teamID ~= mine then
			return teamID
		end
	end
	return nil
end

function skip()
	if Spring.GetGameFrame() <= 0 then
		return true
	end
	return enemyTeamID() == nil
end

function setup()
	-- Deliberately does NOT clear the map. The interesting case is the seat
	-- being ALREADY occupied, which is what a skirmish looks like, and clearing
	-- first would only ever exercise the build-one fallback.
end

function cleanup()
	Test.clearMap()
end

function test()
	local enemy = enemyTeamID()

	-- PATH ONE: the seat is occupied. Every team is given a commander at game
	-- start, so this is the situation any mission dropped into a running
	-- skirmish meets.
	local before = countDef(enemy, "armcom")
	assert(before == 1,
		("this scenario should open with exactly one enemy commander, found %d"):format(before))
	local incumbent
	for _, unitID in ipairs(Spring.GetTeamUnits(enemy) or {}) do
		local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
		if unitDef and unitDef.name == "armcom" then
			incumbent = unitID
		end
	end

	Spring.SendCommands("luarules mission cm8_ashfall")
	Test.waitUntil(function()
		return Spring.GetGameRulesParam("mission_active") == 1
	end, ARM_TIMEOUT)
	Test.waitUntil(function()
		return Spring.GetGameRulesParam("mission_unit_armada_commander") ~= nil
	end, ARM_TIMEOUT)

	local after = countDef(enemy, "armcom")
	local bound = Spring.GetGameRulesParam("mission_unit_armada_commander")
	Spring.Echo(("[cm8] occupied seat: before=%d after=%d incumbent=%s bound=%s")
		:format(before, after, tostring(incumbent), tostring(bound)))

	assert(after == 1,
		("the enemy must hold exactly one commander, found %d"):format(after))
	-- The one assertion that separates claiming from spawning: the mission's
	-- name has to point at the unit that was already standing there.
	assert(bound == incumbent,
		"armada_commander must be bound to the commander the team already had")

	-- And the mission's name must point at a real, living unit on that team.
	local bound = Spring.GetGameRulesParam("mission_unit_armada_commander")
	assert(bound ~= nil, "armada_commander was never bound to a unit")
	assert(Spring.ValidUnitID(bound), "armada_commander is bound to a dead or unknown unit")
	assert(Spring.GetUnitTeam(bound) == enemy, "armada_commander is bound to a unit on the wrong team")

	-- PATH TWO: an empty seat, which is CM8's own single-player game. Now the
	-- roster has to build one at the enclave instead.
	Test.clearMap()
	Test.waitUntil(function()
		return #(Spring.GetTeamUnits(enemy) or {}) == 0
	end, ARM_TIMEOUT)

	Spring.SendCommands("luarules mission cm8_ashfall")
	Test.waitUntil(function()
		return (Spring.GetGameRulesParam("mission_unit_armada_commander") or -1) ~= (bound or -1)
	end, ARM_TIMEOUT)

	local built = countDef(enemy, "armcom")
	Spring.Echo(("[cm8] empty seat: after=%d"):format(built))
	assert(built == 1,
		("an empty seat must be filled with exactly one commander, found %d"):format(built))
end
