function setup()
	Test.clearMap()

	Test.levelHeightMap()

	Spring.SendCommands("globallos")
	Spring.SendCommands("setspeed 5")
end

function cleanup()
	Spring.SendCommands("globallos")
	Spring.SendCommands("setspeed 1")

	Test.clearMap()
end

function runCritterTest()
	local WAIT_FRAMES = 204 -- enough to trigger critter cleanup/restoring by gaia_critters
	local unitName = 'armpw'
	local critterName = 'critter_crab'
	local isCritter = {}
	for udefID, def in ipairs(UnitDefs) do
		if string.find(def.name, "critter_") then
			isCritter[udefID] = true
		end
	end

	local midX, midZ = Game.mapSizeX / 2, Game.mapSizeZ / 2

	local function countAliveCritters()
		local allUnits = Spring.GetAllUnits()
		local alive = 0
		for _, unitID in pairs(allUnits) do
			local defID = Spring.GetUnitDefID(unitID)
			if isCritter[defID] then
				alive = alive + 1
			end
		end
		return alive
	end

	local function destroyNonCritters()
		local unitDefID = UnitDefNames[unitName].id
		SyncedRun(function(locals)
			local unitDefID = locals.unitDefID
			local allUnits = Spring.GetAllUnits()
			for _, unitID in pairs(allUnits) do
				local defID = Spring.GetUnitDefID(unitID)
				if defID == unitDefID then
					Spring.DestroyUnit(unitID, false, true, nil, true)
				end
			end
		end, 500)
	end

	-- 1. Create critters

	SyncedRun(function(locals)
		local GaiaTeamID  = Spring.GetGaiaTeamID()
		local critterName = locals.critterName
		local midX, midZ  = locals.midX, locals.midZ

		local function createUnit(def, x, z, teamID)
			x = midX + x
			z = midZ + z
			local y = Spring.GetGroundHeight(x, z) + 40
			Spring.CreateUnit(def, x, y, z, "south", teamID)
		end
	
		for i = 0, 5 do
			for j = 0, 5 do
				createUnit(critterName, 850 + i*50, 100 + j*50, GaiaTeamID)
			end
		end
	end, 400, {
		critterName = critterName,
		midX = midX,
		midZ = midZ,
	})


	assertSuccessBefore(5, 5, function()
		return #Spring.GetAllUnits() == 36
	end)

	assert(countAliveCritters() == 36)


	-- 2. Create lots of units so critters will be cleaned up

SyncedRun(function(locals)
	local midX, midZ = locals.midX, locals.midZ
	local unitName   = locals.unitName
	local spCreateUnit = Spring.CreateUnit

	local function createUnit(def, x, z, teamID)
		x = midX + x
		z = midZ + z
		local y = Spring.GetGroundHeight(x, z) + 40
		spCreateUnit(def, x, y, z, "south", teamID)
	end

	for i = 1, 60 do
		for j = 1, 60 do
			createUnit(unitName, -2000 + i * 50, -1500 + j * 50, 0)
		end
	end
end, 500, {
	midX = midX,
	midZ = midZ,
	unitName = unitName,
})


	local GaiaTeamID = Spring.GetGaiaTeamID()

	assertSuccessBefore(30, 10, function()
  	  return #Spring.GetAllUnits() >= 3600
	end)


	Test.waitFrames(WAIT_FRAMES)

	assert(countAliveCritters() < 36)


	-- 3. Destroy non critters so critters will be restored

	destroyNonCritters()

	assertSuccessBefore(15, 5, function()
		return Spring.GetTeamUnitCount(0) == 0
	end)

	Test.waitFrames(WAIT_FRAMES - (Spring.GetGameFrame() % WAIT_FRAMES))

	assert(countAliveCritters() == 36)
end

function test()
	runCritterTest()
end
