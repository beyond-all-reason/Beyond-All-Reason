local function skip()
	return Spring.GetGameFrame() <= 0 or select(1, Spring.GetTeamInfo(1, false)) == nil
end

local function setup()
	Test.clearMap()
	Spring.SendCommands("setspeed 5")
end

local function cleanup()
	Spring.SendCommands("setspeed 1")
	Test.clearMap()
end

local function createScenarios()
	return SyncedRun(function()
		local centerX = Game.mapSizeX / 2
		local centerZ = Game.mapSizeZ / 2
		local function createUnit(name, xOffset, zOffset, teamID)
			local x = centerX + xOffset
			local z = centerZ + zOffset
			local y = Spring.GetGroundHeight(x, z)
			return assert(Spring.CreateUnit(name, x, y, z, "south", teamID))
		end
		local function createScenario(attackerName, zOffset)
			return {
				attackerID = createUnit(attackerName, 0, zOffset, 0),
				setTargetID = createUnit("armflea", -250, zOffset, 1),
				attackTargetID = createUnit("armflea", 250, zOffset, 1),
			}
		end

		local scenarios = {
			createScenario("corpun", -600),
			createScenario("armfboy", 600),
		}
		local allUnits = {}
		for _, scenario in ipairs(scenarios) do
			allUnits[#allUnits + 1] = scenario.attackerID
			allUnits[#allUnits + 1] = scenario.setTargetID
			allUnits[#allUnits + 1] = scenario.attackTargetID
		end
		Spring.GiveOrderToUnitArray(allUnits, CMD.FIRE_STATE, { CMD.FIRESTATE_HOLDFIRE }, 0)
		Spring.GiveOrderToUnitArray(allUnits, CMD.MOVE_STATE, { 0 }, 0)

		return scenarios
	end)
end

local function hasWeaponTarget(unitID, expectedTargets)
	local unitDefID = Spring.GetUnitDefID(unitID)
	for weaponNum = 1, #UnitDefs[unitDefID].weapons do
		local targetType, isUserTarget, targetID = Spring.GetUnitWeaponTarget(unitID, weaponNum)
		if targetType == 1 and isUserTarget and expectedTargets[targetID] then
			return true
		end
	end
	return false
end

local function hasAttackCommand(unitID, expectedTargetID)
	local commandID, _, _, commandTargetID = Spring.GetUnitCurrentCommand(unitID)
	return commandID == CMD.ATTACK and commandTargetID == expectedTargetID
end

local function testAttackHandoff(scenario)
	local setTargets = { [scenario.setTargetID] = true }

	Spring.GiveOrderToUnit(scenario.attackerID, GameCMD.UNIT_SET_TARGET, { scenario.setTargetID }, 0)
	Test.waitUntil(function()
		return hasWeaponTarget(scenario.attackerID, setTargets)
	end, 90)

	Spring.GiveOrderToUnit(scenario.attackerID, CMD.ATTACK, { scenario.attackTargetID }, 0)
	Test.waitUntil(function()
		return hasAttackCommand(scenario.attackerID, scenario.attackTargetID)
			and hasWeaponTarget(scenario.attackerID, setTargets)
	end, 90)

	Test.waitUntil(function()
		return Spring.GetUnitIsDead(scenario.setTargetID) ~= false
	end, 1200)

	Test.waitUntil(function()
		return Spring.GetUnitIsDead(scenario.attackTargetID) ~= false
	end, 1200)
end

local function test()
	for _, scenario in ipairs(createScenarios()) do
		testAttackHandoff(scenario)
	end
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
