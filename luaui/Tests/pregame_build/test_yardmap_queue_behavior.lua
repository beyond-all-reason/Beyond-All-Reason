local WAIT_FRAMES = 5
local SOLAR_OFFSET = 6 * Game.squareSize

local function getBuildCommands(unitID)
	local buildCommands = {}
	for _, command in ipairs(Spring.GetUnitCommands(unitID, -1) or {}) do
		if command.id < 0 then
			buildCommands[#buildCommands + 1] = command
		end
	end
	return buildCommands
end

local function giveBuildOrder(builderID, build)
	Spring.GiveOrderToUnit(builderID, -build[1], { build[2], build[3], build[4], build[5] }, { "shift" })
	Test.waitFrames(WAIT_FRAMES)
end

function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
	Test.levelHeightMap()
end

function cleanup()
	Test.clearMap()
end

function test()
	local yardmapAware = Spring.TestBuildOrderOverlap and Game.useYardmapsForQueuedBuildOverlap ~= false
	local solarID = UnitDefNames.armsolar.id
	local teamID = Spring.GetMyTeamID()
	local x = Game.mapSizeX * 0.5
	local z = Game.mapSizeZ * 0.5
	local y = Spring.GetGroundHeight(x, z)
	local bx, by, bz = Spring.Pos2BuildPos(solarID, x, y, z, 0)
	local queuedBuild = { solarID, bx, by, bz, 0 }
	local cases = {
		{
			name = "slight footprint overlap without a yardmap conflict",
			proposedBuild = { solarID, bx + SOLAR_OFFSET, by, bz + SOLAR_OFFSET, 0 },
			overlaps = false,
			cancels = false,
			expectedBuildCommands = 2,
			expectedLegacyBuildCommands = 1,
		},
		{
			name = "slight footprint overlap with a yardmap conflict",
			proposedBuild = { solarID, bx + SOLAR_OFFSET, by, bz, 0 },
			overlaps = true,
			cancels = false,
			expectedBuildCommands = 1,
			expectedLegacyBuildCommands = 1,
		},
		{
			name = "yardmap conflict inside the cancel region",
			proposedBuild = { solarID, bx, by, bz, 0 },
			overlaps = true,
			cancels = true,
			expectedBuildCommands = 0,
			expectedLegacyBuildCommands = 0,
		},
	}

	for _, case in ipairs(cases) do
		if Spring.TestBuildOrderOverlap then
			local overlaps, cancels = Spring.TestBuildOrderOverlap(queuedBuild, case.proposedBuild)
			local expectedOverlaps = case.overlaps
			local expectedCancels = case.cancels
			if not yardmapAware then
				expectedOverlaps = case.expectedLegacyBuildCommands < 2
				expectedCancels = case.expectedLegacyBuildCommands == 0
			end
			assertEqual(overlaps, expectedOverlaps, case.name .. ": engine overlap classification")
			assertEqual(cancels, expectedCancels, case.name .. ": engine cancellation classification")
		end

		Test.clearMap()
		local builderX = bx - 1500
		local builderID = SyncedRun(function(locals)
			return Spring.CreateUnit("armck", locals.builderX, locals.by, locals.bz, 0, locals.teamID)
		end)
		assert(builderID, case.name .. ": failed to create builder")

		giveBuildOrder(builderID, queuedBuild)
		assertEqual(#getBuildCommands(builderID), 1, case.name .. ": initial build command")

		giveBuildOrder(builderID, case.proposedBuild)
		local expectedBuildCommands = yardmapAware and case.expectedBuildCommands or case.expectedLegacyBuildCommands
		assertEqual(#getBuildCommands(builderID), expectedBuildCommands, case.name .. ": in-game command queue")
	end
end
