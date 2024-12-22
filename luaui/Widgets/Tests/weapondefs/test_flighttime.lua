function setup()
	Test.clearMap()

	Spring.SendCommands("editdefs 1")
	Spring.SendCommands("globallos")
	Spring.SendCommands("setspeed 5")
end

function cleanup()
	Test.clearMap()

	Spring.SendCommands("globallos")
	Spring.SendCommands("setspeed 1")
	Spring.SendCommands("editdefs 0")
end

function runDistanceTest(flightTime, shouldAlive)
	SyncedRun(function(locals)
		local flightTime = locals.flightTime
		for weaponDefID, weaponDef in pairs(WeaponDefs) do
			if weaponDef.name == "corbuzz_rflrpc" then
				weaponDef.flightTime = flightTime
				weaponDef.accuracy = 0
			end
			if weaponDef.name == "armrock_arm_bot_rocket" or weaponDef.name == "corstorm_cor_bot_rocket" then
				weaponDef.flightTime = flightTime
			end
		end
	end)

	local units, unitNames = SyncedRun(function(locals)
		local midX, midZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
		local units = {}
		local unitNames = {}
		local function createUnit(def, x, z, teamID)
			local x = midX + x
			local z = midZ + z
			local y = Spring.GetGroundHeight(x, z)
			local unitID = Spring.CreateUnit(def, x, y, z, "south", teamID)
			units[#units+1] = unitID
			unitNames[def] = unitID
			return unitID
		end

		createUnit("armafus", 100, -500, 0)
		createUnit("armafus", 200, -500, 0)
		createUnit("armafus", 300, -500, 0)
		createUnit("armafus", 400, -500, 0)
		createUnit("armtarg", 500, -500, 0)
		createUnit("armtarg", 600, -500, 0)
		createUnit("armtarg", 700, -500, 0)
		createUnit("corbuzz", 500, 0, 0)

		Spring.GiveOrderToUnitArray(units, CMD.FIRE_STATE, {0}, 0)

		createUnit("armarad", 900, 50, 0)
		for i=0, 5 do
			createUnit("armrock", 850 + i*50, 100, 0)
		end
		createUnit("corstorm", 1150, 100, 0)
		Spring.GiveOrderToUnitArray(units, CMD.MOVE_STATE, {0}, 0)

		createUnit("armarad", 400, Game.mapSizeZ/2.0-1200, 0)
		-- enemies
		createUnit("armpw", 1000, 550, 1)
		createUnit("armsolar", 0, Game.mapSizeZ/2.0-1200, 1)

		return units, unitNames
	end)

	Test.waitFrames(1)

	Spring.GiveOrderToUnit(unitNames["corbuzz"], CMD.ATTACK, {unitNames["armsolar"]}, 0)
	Spring.GiveOrderToUnit(unitNames["corstorm"], CMD.ATTACK, {unitNames["armpw"]}, 0)
	Spring.GiveOrderToUnit(unitNames["armrock"], CMD.ATTACK, {unitNames["armpw"]}, 0)

	Test.waitFrames(300)

	local isAlive = Spring.ValidUnitID(unitNames["armsolar"])
	local isAlive2 = Spring.ValidUnitID(unitNames["armpw"])

	assert(isAlive == shouldAlive)
	assert(isAlive2 == shouldAlive)
end

function test()
	runDistanceTest(30, true)
	Test.clearMap()
	runDistanceTest(0, false)
end
