---@diagnostic disable: undefined-field

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

-- An enemy is a team on ANOTHER allyteam; an allied seat must not count.
local function enemyTeamID()
	local gaia = Spring.GetGaiaTeamID()
	local mine = Spring.GetLocalTeamID()
	local _, _, _, _, _, myAllyTeamID = Spring.GetTeamInfo(mine, false)
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= gaia and teamID ~= mine then
			local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID, false)
			if allyTeamID ~= myAllyTeamID then
				return teamID
			end
		end
	end
	return nil
end

local function skip()
	if Spring.GetGameFrame() <= 0 then
		return true
	end
	return enemyTeamID() == nil
end

local function setup()
	-- Deliberately does NOT clear the map: the occupied seat IS the case.
end

local function cleanup()
	Test.clearMap()
end

local function test()
	local enemy = enemyTeamID()

	-- PATH ONE: the seat is occupied. Every bare team is given a commander at
	-- game start, so this is what a mission dropped into a skirmish meets.
	local before = countDef(enemy, "armcom")
	assert(before == 1, ("this scenario should open with exactly one enemy commander, found %d"):format(before))
	local incumbent
	for _, unitID in ipairs(Spring.GetTeamUnits(enemy) or {}) do
		local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
		if unitDef and unitDef.name == "armcom" then
			incumbent = unitID
		end
	end

	Spring.SendCommands("luarules mission smoke_claim")
	Test.waitUntil(function()
		return Spring.GetGameRulesParam("mission_active") == 1
	end, ARM_TIMEOUT)
	Test.waitUntil(function()
		return Spring.GetGameRulesParam("mission_unit_mark") ~= nil
	end, ARM_TIMEOUT)

	local after = countDef(enemy, "armcom")
	local bound = Spring.GetGameRulesParam("mission_unit_mark")
	assert(after == 1, ("the enemy must hold exactly one commander, found %d"):format(after))
	-- The one assertion that separates claiming from spawning: the mission's
	-- name has to point at the unit that was already standing there.
	assert(bound == incumbent, "the claim must bind to the commander the team already had")
	assert(Spring.ValidUnitID(bound), "the claim is bound to a dead or unknown unit")
	assert(Spring.GetUnitTeam(bound) == enemy, "the claim is bound to a unit on the wrong team")

	Test.clearMap()
	Test.waitUntil(function()
		return #(Spring.GetTeamUnits(enemy) or {}) == 0
	end, ARM_TIMEOUT)
	Spring.SendCommands("luarules mission smoke_claim")
	Test.waitUntil(function()
		return (Spring.GetGameRulesParam("mission_unit_mark") or -1) ~= (bound or -1)
	end, ARM_TIMEOUT)
	local built = countDef(enemy, "armcom")
	assert(built == 1, ("an empty seat must be filled with exactly one commander, found %d"):format(built))
end

return { skip = skip, setup = setup, cleanup = cleanup, test = test }
