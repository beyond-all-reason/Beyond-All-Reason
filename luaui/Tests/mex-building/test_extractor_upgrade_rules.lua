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
	assert(WG.resource_spot_builder, "resource_spot_builder API widget not loaded")
	assert(WG.resource_spot_builder.ExtractorCanBeUpgraded, "ExtractorCanBeUpgraded missing")

	local myTeamID = Spring.GetLocalTeamID()
	local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local y = Spring.GetGroundHeight(x, z)
	local facing = 0

	local cases = {
		-- current unit, new unit, expected
		{ "armmex", "armamex", true }, -- arm mex -> stealthy mex
		{ "armamex", "armmex", false }, -- stealthy mex -> t1 mex
		{ "armgmm", "armageo", true }, -- prude -> ageo
		{ "armageo", "armgmm", true }, -- ageo -> prude
		{ "armgeo", "corgeo", false }, -- t1 geo cross-faction
		{ "armageo", "corageo", false }, -- ageo cross-faction
		{ "armmoho", "cormoho", false }, -- t2 mex cross-faction
		{ "armmoho", "armmex", false }, -- t2 mex to t1 mex
		{ "armmoho", "cormoho", false }, -- t2 mex to t2 mex cross-faction
		{ "armamex", "armmex", false }, -- t1 mex to t1 mex
		{ "armgmm", "armgmm", false }, -- prude -> prude
	}

	for i = 1, #cases do
		local currentName, newName, expected = cases[i][1], cases[i][2], cases[i][3]

		assert(UnitDefNames[currentName], "missing UnitDefNames." .. currentName)
		assert(UnitDefNames[newName], "missing UnitDefNames." .. newName)

		Test.clearMap()

		local unitName = currentName
		local teamID = myTeamID
		local currentUnitID = SyncedRun(function(locals)
			return Spring.CreateUnit(locals.unitName, locals.x, locals.y, locals.z, locals.facing, locals.teamID)
		end)
		assert(currentUnitID, "failed to create " .. currentName)

		local canUpgrade = WG.resource_spot_builder.ExtractorCanBeUpgraded(currentUnitID, UnitDefNames[newName].id)
		assertEqual(
			canUpgrade,
			expected,
			string.format(
				"expected ExtractorCanBeUpgraded(%s -> %s) == %s, got %s",
				currentName,
				newName,
				tostring(expected),
				tostring(canUpgrade)
			)
		)
	end
end

return { skip = skip, setup = setup, test = test, cleanup = cleanup }
