local function skip()
	return Spring.GetGameFrame() <= 0
		or select(1, Spring.GetTeamInfo(1, false)) == nil
		or Game.mapName ~= "All That Glitters v2.2.3"
end

local function setup()
	Test.clearMap()
	Spring.SendCommands("setspeed 5")
end

local function cleanup()
	Spring.SendCommands("setspeed 1")
	Test.clearMap()
end

local function createScenario()
	local gauntletID = assert(Spring.CreateUnit("corpun", 721, 515, 3945, "south", 0))
	local fatboyID = assert(Spring.CreateUnit("armfboy", 991, 224, 4174, "south", 1))

	Spring.GiveOrderToUnit(gauntletID, CMD.FIRE_STATE, { CMD.FIRESTATE_HOLDFIRE }, 0)
	Spring.GiveOrderToUnit(fatboyID, CMD.MOVE, { 1039.68, 221.86, 4209.592, 1051.112, 0, 4240.067 }, CMD.OPT_ALT)
	Spring.GiveOrderToUnit(fatboyID, CMD.MOVE_STATE, { 2 }, 0)
	Spring.GiveOrderToUnit(fatboyID, CMD.MOVE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnit(fatboyID, CMD.FIRE_STATE, { CMD.FIRESTATE_HOLDFIRE }, 0)

	return gauntletID, fatboyID
end

local function test()
	local gauntletID, fatboyID = SyncedRun(createScenario)
	local targetX, targetY, targetZ = 712.059, 199.503, 4978.311

	local function targetsSetPosition()
		for weaponNum = 1, 2 do
			local targetType, _, target = Spring.GetUnitWeaponTarget(gauntletID, weaponNum)
			---@cast targetType integer
			---@cast target float3
			if targetType == 2 and math.abs(target[1] - targetX) < 1 and math.abs(target[3] - targetZ) < 1 then
				return true
			end
		end
		return false
	end

	local function targetsFatboy()
		for weaponNum = 1, 2 do
			local targetType, _, targetID = Spring.GetUnitWeaponTarget(gauntletID, weaponNum)
			---@cast targetType integer
			---@cast targetID integer
			if targetType == 1 and targetID == fatboyID then
				return true
			end
		end
		return false
	end

	Spring.GiveOrderToUnit(gauntletID, GameCMD.UNIT_SET_TARGET, { targetX, targetY, targetZ, 0 }, 0)
	Test.waitUntil(targetsSetPosition, 90)
	Test.waitFrames(178)
	Spring.GiveOrderToUnit(gauntletID, CMD.ATTACK, { fatboyID }, 0)
	Test.waitFrames(241)
	-- The Set Target may stay listed; the Attack target must be engaged while both are present.
	assert(targetsFatboy(), "Attack order did not make the Gauntlet engage the Fatboy")

	Spring.GiveOrderToUnit(gauntletID, GameCMD.UNIT_CANCEL_TARGET, {}, 0)
	Test.waitUntil(targetsFatboy, 90)

	local commandID, _, _, commandTargetID = Spring.GetUnitCurrentCommand(gauntletID)
	assert(commandID == CMD.ATTACK and commandTargetID == fatboyID, "Clear Target changed the current Attack command")
	for _ = 1, 300 do
		Test.waitFrames(1)
		assert(not targetsSetPosition(), "Gauntlet resumed shooting the cleared Set Target position")
	end
end

return { skip = skip, setup = setup, test = test, cleanup = cleanup }
