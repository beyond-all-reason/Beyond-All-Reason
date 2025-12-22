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

	-- build critter lookup
	local isCritter = {}
	for udefID, def in ipairs(UnitDefs) do
		if string.find(def.name, "critter_") then
			isCritter[udefID] = true
		end
	end

	local midX, midZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local GaiaTeamID = Spring.GetGaiaTeamID()

	-- helper: count living critters
	local function countAliveCritters()
		local alive = 0
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			local defID = Spring.GetUnitDefID(unitID)
			if isCritter[defID] then
				alive = alive + 1
			end
		end
		return alive
	end

	-------------------------------------------------------
	-- 1. Create critters
	-------------------------------------------------------

	SyncedRun(function(locals)
		local GaiaTeamID = Spring.GetGaiaTeamID()
		local critterName = locals.critterName
		local midX, midZ = locals.midX, locals.midZ

		local function createUnit(def, x, z)
			x = midX + x
			z = midZ + z
			local y = Spring.GetGroundHeight(x, z) + 40
			Spring.CreateUnit(def, x, y, z, "south", GaiaTeamID)
		end

		for i = 0, 5 do
			for j = 0, 5 do
				createUnit(critterName, 850 + i * 50, 100 + j * 50)
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

	-------------------------------------------------------
	-- 2. Create pressure units (tracked explicitly)
	-------------------------------------------------------

	local pressureUnits = {}

	SyncedRun(function(locals)
		local midX, midZ = locals.midX, locals.midZ
		local unitName = locals.unitName
		local pressureUnits = locals.pressureUnits
		local spCreateUnit = Spring.CreateUnit

		local function createUnit(def, x, z)
			x = midX + x
			z = midZ + z
			local y = Spring.GetGroundHeight(x, z) + 40
			local unitID = spCreateUnit(def, x, y, z, "south", 0)
			if unitID then
				pressureUnits[#pressureUnits + 1] = unitID
			end
		end

		for i = 1, 60 do
			for j = 1, 60 do
				createUnit(unitName, -2000 + i * 50, -1500 + j * 50)
			end
		end
	end, 500, {
		midX = midX,
		midZ = midZ,
		unitName = unitName,
		pressureUnits = pressureUnits,
	})

	assertSuccessBefore(30, 10, function()
	local aliveCount = 0
	for _, unitID in ipairs(pressureUnits) do
		if Spring.ValidUnitID(unitID) then
			aliveCount = aliveCount + 1
		end
	end
	-- consider success if most units spawned
	return aliveCount >= 3500
end)


	Test.waitFrames(WAIT_FRAMES)

	assert(countAliveCritters() < 36)

	-------------------------------------------------------
	-- 3. Destroy pressure units only
	-------------------------------------------------------

	local function destroyPressureUnits()
		SyncedRun(function(locals)
			for _, unitID in ipairs(locals.pressureUnits) do
				if Spring.ValidUnitID(unitID) then
					Spring.DestroyUnit(unitID, false, true, nil, true)
				end
			end
		end, 500, {
			pressureUnits = pressureUnits,
		})
	end

	destroyPressureUnits()

	assertSuccessBefore(15, 5, function()
		for _, unitID in ipairs(pressureUnits) do
			if Spring.ValidUnitID(unitID) then
				return false
			end
		end
		return true
	end)

	-------------------------------------------------------
	-- 4. Wait for critter restore tick
	-------------------------------------------------------

	Test.waitFrames(WAIT_FRAMES - (Spring.GetGameFrame() % WAIT_FRAMES))

	assert(countAliveCritters() == 36)
end

function test()
	runCritterTest()
end
