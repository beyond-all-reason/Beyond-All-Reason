function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

-- SND windy locations
	if n%960 == 0 then
		SpawnCEGInPositionGround("noceg", 700, 500, 800, _, _, _, "windy", 0.5)
	end

	if n%870 == 100 then
		SpawnCEGInPositionGround("noceg", 9400, 600, 800, _, _, _, "windy", 0.5)
	end

	if n%930 == 200 then
		SpawnCEGInPositionGround("noceg", 660, 500, 6700, _, _, _, "windy", 0.5)
	end

	if n%900 == 300 then
		SpawnCEGInPositionGround("noceg", 9700, 600, 6560, _, _, _, "windy", 0.5)
	end

-- SND dam hum
	if n%830 == 0 then
		SpawnCEGInPositionGround("noceg", 5115, 0, 4095, _, _, _, "humheavy", 0.95)
	end

	if n%830 == 120 then
		SpawnCEGInPositionGround("noceg", 5115, 0, 3078, _, _, _, "humheavy", 0.95)
	end

-- common foggy cliffs	
	if n%360 == 0 then
		SpawnCEGInPositionGround("fogdirty", 9809, 0, 3968)
		SpawnCEGInPositionGround("fogdirty", 6297, 100, 4140)
		SpawnCEGInPositionGround("fogdirty", 6320, 100, 3177)
	end

-- rare foggy cliffs	
	if n%380 == 150 then
		SpawnCEGInPositionGround("fogdirty", 265, 0, 1718)
		SpawnCEGInPositionGround("fogdirty", 3919, 100, 4140)
		SpawnCEGInPositionGround("fogdirty", 3896, 100, 3164)

	end

-- -- mistyclouds	
	if n%1200 == 550 then
		SpawnCEGInPositionGround("mistycloud", 9076, 150, 6829)
	end

-- -- rare sanddune dust	
-- 	if n%450 == 0 then
-- 		SpawnCEGInPositionGround("dunecloud", 4542, 0, 5326)
-- 	end

-- alternate rare foggy cliffs	
	if n%620 == 300 then
		SpawnCEGInPositionGround("fogdirty", 9585, 0, 304)
		SpawnCEGInPositionGround("fogdirty", 275, 0, 6675)
		SpawnCEGInPositionGround("fogdirty", 10163, 0, 1763)
	end

-- super rare foggy cliffs	
	if n%1000 == 400 then
		SpawnCEGInPositionGround("fogdirty", 1125, 0, 4042)
		SpawnCEGInPositionGround("fogdirty", 5081, 0, 5634)
		SpawnCEGInPositionGround("fogdirty", 2631, 0, 6591)
	end

-- fireflies
	if n%1400 == 0 then
		SpawnCEGInPositionGround("firefliesgreen", 3423, 32, 5559)
		SpawnCEGInPositionGround("firefliesgreen", 7079, 32, 4449)
		SpawnCEGInPositionGround("fireflies", 9561, 32, 1072)
		SpawnCEGInPositionGround("fireflies", 223, 32, 249)
	end

-- pollen
	if n%150 == 0 then
		SpawnCEGInRandomMapPos("dustparticles", 50)
	end
		
end