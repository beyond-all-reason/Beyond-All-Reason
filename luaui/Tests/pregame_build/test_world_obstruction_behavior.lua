local WAIT_FRAMES = 5
local SOLAR_OFFSET = 6 * Game.squareSize
local TERRAIN_RAISE = 200

local function getBuildCommandCount(unitID)
	local count = 0
	for _, command in ipairs(Spring.GetUnitCommands(unitID, -1) or {}) do
		if command.id < 0 then
			count = count + 1
		end
	end
	return count
end

local function createUnit(unitName, x, y, z)
	local unitID = SyncedProxy.Spring.CreateUnit(unitName, x, y, z, 0, Spring.GetMyTeamID())
	return unitID
end

local function createBuilder(x, y, z)
	return SyncedProxy.Spring.CreateUnit("armck", x, y, z, 0, Spring.GetMyTeamID())
end

local function queueBuild(builderID, build)
	Spring.GiveOrderToUnit(builderID, -build[1], { build[2], build[3], build[4], build[5] }, { "shift" })
	Test.waitFrames(WAIT_FRAMES)
	return getBuildCommandCount(builderID)
end

local function raiseTerrain(x, z)
	SyncedProxy.Spring.LevelHeightMap(x, z, x, z, TERRAIN_RAISE)
	SyncedProxy.Spring.RebuildSmoothMesh(x - 32, z - 32, x + 32, z + 32)
	Test.waitFrames(WAIT_FRAMES)
end

local function findUnit(unitDefID, x, z, radius, excludedUnitID)
	for _, unitID in ipairs(Spring.GetUnitsInCylinder(x, z, radius) or {}) do
		if unitID ~= excludedUnitID and Spring.GetUnitDefID(unitID) == unitDefID then
			return unitID
		end
	end
	return nil
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
	Test.restoreHeightMap()
end

function test()
	local yardmapAware = Spring.TestBuildOrderOverlap and Game.useYardmapsForQueuedBuildOverlap ~= false
	local solarID = UnitDefNames.armsolar.id
	local centerX = Game.mapSizeX * 0.5
	local centerZ = Game.mapSizeZ * 0.5
	local centerY = Spring.GetGroundHeight(centerX, centerZ)
	local bx, by, bz = Spring.Pos2BuildPos(solarID, centerX, centerY, centerZ, 0)
	local proposedConflict = { solarID, bx + SOLAR_OFFSET, by, bz, 0 }
	local proposedCompatible = { solarID, bx + SOLAR_OFFSET, by, bz + SOLAR_OFFSET, 0 }

	for _, placementCase in ipairs({
		{ name = "with yardmap overlap", build = proposedConflict, expectedCommands = 0 },
		{ name = "without yardmap overlap", build = proposedCompatible, expectedCommands = 1 },
	}) do
		Test.clearMap()
		local obstructionID = createUnit("armsolar", bx, by, bz)
		assert(obstructionID, "completed building: failed to create obstruction")
		local builderID = createBuilder(bx - 1500, by, bz)
		assert(builderID, "completed building: failed to create builder")
		assertEqual(queueBuild(builderID, placementCase.build), placementCase.expectedCommands, "completed building, " .. placementCase.name)
	end

	for _, placementCase in ipairs({
		{ name = "with yardmap overlap", build = proposedConflict, expectedCommands = 1 },
		{
			name = "without yardmap overlap",
			build = proposedCompatible,
			expectedCommands = yardmapAware and 2 or 1,
		},
	}) do
		Test.clearMap()
		local builderID = createBuilder(bx - 96, by, bz)
		assert(builderID, "building under construction: failed to create builder")
		assertEqual(queueBuild(builderID, { solarID, bx, by, bz, 0 }), 1, "initial active build command")
		local nanoframeID
		Test.waitUntil(function()
			nanoframeID = findUnit(solarID, bx, bz, 32, builderID)
			return nanoframeID ~= nil
		end, 150)
		local _, _, _, _, buildProgress = Spring.GetUnitHealth(nanoframeID)
		assert(buildProgress and buildProgress < 1, "expected an active solar nanoframe")
		assertEqual(queueBuild(builderID, placementCase.build), placementCase.expectedCommands, "building under construction, " .. placementCase.name)
	end

	Test.clearMap()
	local mobileUnitID = createUnit("armck", bx, by, bz)
	assert(mobileUnitID, "mobile unit: failed to create obstruction")
	local builderID = createBuilder(bx - 1500, by, bz)
	assert(builderID, "mobile unit: failed to create builder")
	assertEqual(queueBuild(builderID, { solarID, bx, by, bz, 0 }), 1, "mobile unit inside proposed footprint")

	for _, terrainCase in ipairs({
		{
			name = "terrain obstruction on an occupied yardmap cell",
			x = bx,
			z = bz,
		},
		{
			name = "terrain obstruction on an open yardmap cell",
			x = bx - 4 * Game.squareSize,
			z = bz - 4 * Game.squareSize,
		},
	}) do
		Test.clearMap()
		Test.levelHeightMap()
		raiseTerrain(terrainCase.x, terrainCase.z)
		builderID = createBuilder(bx - 1500, by, bz)
		assert(builderID, terrainCase.name .. ": failed to create builder")
		assertEqual(queueBuild(builderID, { solarID, bx, by, bz, 0 }), 0, terrainCase.name)
	end
end
