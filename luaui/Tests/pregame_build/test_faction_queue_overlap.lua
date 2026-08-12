local SubLogic = VFS.Include("luaui/Include/blueprint_substitution/logic.lua")

function skip()
	return Spring.GetGameFrame() <= 0 or not Spring.TestBuildOrderOverlap
end

function test()
	local armSolarID = UnitDefNames.armsolar.id
	local corSolarID = UnitDefNames.corsolar.id
	local x = Game.mapSizeX * 0.5
	local z = Game.mapSizeZ * 0.5
	local y = Spring.GetGroundHeight(x, z)
	local firstArmSolar = { armSolarID, x, y, z, 0 }
	local firstCorSolar = { corSolarID, x, y, z, 0 }
	local secondArmSolar

	for xOffset = -40, 40, 8 do
		for zOffset = -40, 40, 8 do
			local armCandidate = { armSolarID, x + xOffset, y, z + zOffset, 0 }
			local corCandidate = { corSolarID, x + xOffset, y, z + zOffset, 0 }
			local armOverlaps = Spring.TestBuildOrderOverlap(firstArmSolar, armCandidate)
			local corOverlaps = Spring.TestBuildOrderOverlap(firstCorSolar, corCandidate)

			if not armOverlaps and corOverlaps then
				secondArmSolar = armCandidate
				break
			end
		end
		if secondArmSolar then
			break
		end
	end

	assert(
		secondArmSolar,
		"expected to find a placement allowed by the Armada solar yardmap but not the Cortex solar yardmap"
	)

	local buildQueue = { firstArmSolar, secondArmSolar }
	local result = SubLogic.processBuildQueueSubstitution(buildQueue, SubLogic.SIDES.ARMADA, SubLogic.SIDES.CORTEX)
	assert(not result.substitutionFailed, result.summaryMessage)
	assertEqual(buildQueue[1][1], corSolarID)
	assertEqual(buildQueue[2][1], corSolarID)

	local removedCount = SubLogic.removeOverlappingBuildQueueItems(buildQueue, function(proposedBuild, queuedBuild)
		return Spring.TestBuildOrderOverlap(queuedBuild, proposedBuild)
	end)

	assertEqual(removedCount, 1)
	assertEqual(#buildQueue, 1)
	assertEqual(buildQueue[1][1], corSolarID)
end

return { skip = skip, setup = setup, test = test, cleanup = cleanup }
