local function skip()
	return Spring.GetGameFrame() <= 0
		or select(1, Spring.GetTeamInfo(1, false)) == nil
		or Game.mapName ~= "All That Glitters v2.2.3"
end

local function setup()
	SyncedRun(function()
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			if Spring.GetUnitTeam(unitID) ~= 1 then
				Spring.DestroyUnit(unitID, false, true)
			else
				Spring.SetUnitNoSelect(unitID, true)
				Spring.SetUnitNoDraw(unitID, true)
			end
		end
		for _, featureID in ipairs(Spring.GetAllFeatures()) do
			Spring.DestroyFeature(featureID)
		end
	end)
	Spring.SendCommands("setspeed 5")
end

local function cleanup()
	Spring.SendCommands("setspeed 1")
	Test.clearMap()
end

local function createScenario()
	local enemyTeamID = 1
	local function createUnit(name, x, z, teamID)
		local y = Spring.GetGroundHeight(x, z)
		return assert(Spring.CreateUnit(name, x, y, z, "south", teamID))
	end

	local agitatorID = createUnit("corpun", 736, 3952, 0)
	local tickIDs = {
		createUnit("armflea", 621, 4471, enemyTeamID),
		createUnit("armflea", 893, 4478, enemyTeamID),
		createUnit("armflea", 986, 4479, enemyTeamID),
		createUnit("armflea", 718, 4474, enemyTeamID),
		createUnit("armflea", 790, 4480, enemyTeamID),
	}
	local fatboyID = createUnit("armfboy", 827, 4824, enemyTeamID)
	local allUnits = { agitatorID, fatboyID, unpack(tickIDs) }
	Spring.GiveOrderToUnitArray(allUnits, CMD.FIRE_STATE, { CMD.FIRESTATE_HOLDFIRE }, 0)
	Spring.GiveOrderToUnitArray(allUnits, CMD.MOVE_STATE, { 0 }, 0)

	return agitatorID, tickIDs[1], tickIDs[2], tickIDs[3], tickIDs[4], tickIDs[5], fatboyID
end

local function test()
	local agitatorID, tick1, tick2, tick3, tick4, tick5, fatboyID = SyncedRun(createScenario)
	local tickIDs = { tick1, tick2, tick3, tick4, tick5 }
	local tickLookup = {}
	for _, tickID in ipairs(tickIDs) do
		assert(Spring.ValidUnitID(tickID), "Tick was not created at the replay position")
		tickLookup[tickID] = true
	end
	assert(Spring.ValidUnitID(agitatorID), "Agitator was not created at the replay position")
	assert(Spring.ValidUnitID(fatboyID), "Fatboy was not created at the replay position")
	local targetY = Spring.GetGroundHeight(800, 4476)
	Spring.GiveOrderToUnit(agitatorID, GameCMD.UNIT_SET_TARGET, { 800, targetY, 4476, 240 }, 0)
	local function hasTickWeaponTarget()
		for weaponNum = 1, 2 do
			local targetType, _, targetID = Spring.GetUnitWeaponTarget(agitatorID, weaponNum)
			if targetType == 1 and tickLookup[targetID] then
				return true
			end
		end
		return false
	end
	Test.waitUntil(function()
		return hasTickWeaponTarget()
	end, 90)
	Spring.GiveOrderToUnit(agitatorID, CMD.ATTACK, { fatboyID }, 0)
	Test.waitFrames(30)
	assert(hasTickWeaponTarget(), "Set Target did not retain precedence over Attack")
	Test.waitUntil(function()
		for _, tickID in ipairs(tickIDs) do
			if Spring.ValidUnitID(tickID) and not Spring.GetUnitIsDead(tickID) then
				return false
			end
		end
		return true
	end, 1200)

	Test.waitFrames(30)
	local commandID, _, _, commandTargetID = Spring.GetUnitCurrentCommand(agitatorID)
	local targetType1, _, targetID1 = Spring.GetUnitWeaponTarget(agitatorID, 1)
	local targetType2, _, targetID2 = Spring.GetUnitWeaponTarget(agitatorID, 2)
	local fatboyValid = Spring.ValidUnitID(fatboyID)
	local fatboyDead = fatboyValid and Spring.GetUnitIsDead(fatboyID)
	local fatboyHealth = fatboyValid and Spring.GetUnitHealth(fatboyID)
	assert(
		(targetType1 == 1 and targetID1 == fatboyID) or (targetType2 == 1 and targetID2 == fatboyID),
		string.format(
			"Agitator did not resume Fatboy target %d (valid %s, dead %s, health %s): command %s target %s, weapon targets %s/%s and %s/%s",
			fatboyID,
			tostring(fatboyValid),
			tostring(fatboyDead),
			tostring(fatboyHealth),
			tostring(commandID),
			tostring(commandTargetID),
			tostring(targetType1),
			tostring(targetID1),
			tostring(targetType2),
			tostring(targetID2)
		)
	)
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
