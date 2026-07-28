function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
end

function cleanup()
	Test.clearMap()
end

local function createExtractor(unitName, teamID)
	return SyncedRun(function(locals)
		local x, z = Game.mapSizeX / 2, Game.mapSizeZ / 2
		local y = Spring.GetGroundHeight(x, z)
		local unitID = Spring.CreateUnit(locals.unitName, x, y, z, 0, locals.teamID)
		assert(unitID, "failed to create " .. tostring(locals.unitName))
		return unitID
	end)
end

local function assertUpgrade(currentName, newName, expected, label)
	Test.clearMap()

	local myTeamID = Spring.GetMyTeamID()
	local currentUnitID = createExtractor(currentName, myTeamID)
	local newDefID = UnitDefNames[newName].id

	local canUpgrade = WG["resource_spot_builder"].ExtractorCanBeUpgraded(currentUnitID, newDefID)
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

function test()
	assert(WG["resource_spot_builder"], "resource_spot_builder API widget not loaded")
	assert(WG["resource_spot_builder"].ExtractorCanBeUpgraded, "ExtractorCanBeUpgraded missing")

	-- 1. arm mex upgradable to arm stealthy mex
	assertUpgrade("armmex", "armamex", true, "1")

	-- 2. arm stealthy mex not upgradable to arm t1 mex
	assertUpgrade("armamex", "armmex", false, "2")

	-- 3. prude upgradable to ageo
	assertUpgrade("armgmm", "armageo", true, "3")

	-- 4. ageo upgradable to prude
	assertUpgrade("armageo", "armgmm", true, "4")

	-- 5. cerberus upgradable into legion antinuke jammer geo (Rampart)
	assertUpgrade("corbhmth", "legrampart", true, "5")

	-- 6. t1 geo for one faction not upgradable to the same-tier t1 geo from another faction
	assertUpgrade("armgeo", "corgeo", false, "6")

	-- 7. ageo for one faction not upgradable to ageo from another faction
	assertUpgrade("armageo", "corageo", false, "7")

	-- 8. t2 mex not upgradable into t2 mex for another faction
	assertUpgrade("armmoho", "cormoho", false, "8")
end
