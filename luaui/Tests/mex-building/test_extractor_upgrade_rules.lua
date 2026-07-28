function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
end

function cleanup()
	Test.clearMap()
end

function test()
	assert(WG["resource_spot_builder"], "resource_spot_builder API widget not loaded")
	assert(WG["resource_spot_builder"].ExtractorCanBeUpgraded, "ExtractorCanBeUpgraded missing")

	local myTeamID = Spring.GetMyTeamID()
	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local y = Spring.GetGroundHeight(x, z)
	local facing = 0

	local cases = {
		-- label, current unit, new unit, expected
		{ "1", "armmex", "armamex", true },       -- arm mex -> stealthy mex
		{ "2", "armamex", "armmex", false },      -- stealthy mex -> t1 mex
		{ "3", "armgmm", "armageo", true },       -- prude -> ageo
		{ "4", "armageo", "armgmm", true },       -- ageo -> prude
		{ "5", "corbhmth", "legrampart", true },  -- cerberus -> legion rampart
		{ "6", "armgeo", "corgeo", false },       -- t1 geo cross-faction
		{ "7", "armageo", "corageo", false },     -- ageo cross-faction
		{ "8", "armmoho", "cormoho", false },     -- t2 mex cross-faction
	}

	for i = 1, #cases do
		local label, currentName, newName, expected = cases[i][1], cases[i][2], cases[i][3], cases[i][4]

		assert(UnitDefNames[currentName], "missing UnitDefNames." .. currentName)
		assert(UnitDefNames[newName], "missing UnitDefNames." .. newName)

		Test.clearMap()

		local unitName = currentName
		local teamID = myTeamID
		local currentUnitID = SyncedRun(function(locals)
			return Spring.CreateUnit(locals.unitName, locals.x, locals.y, locals.z, locals.facing, locals.teamID)
		end)
		assert(currentUnitID, "failed to create " .. currentName)

		local canUpgrade = WG["resource_spot_builder"].ExtractorCanBeUpgraded(
			currentUnitID,
			UnitDefNames[newName].id
		)
		assertEqual(
			canUpgrade,
			expected,
			string.format(
				"%s: expected ExtractorCanBeUpgraded(%s -> %s) == %s, got %s",
				label,
				currentName,
				newName,
				tostring(expected),
				tostring(canUpgrade)
			)
		)
	end
end
