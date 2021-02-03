function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

-- DayNight Cycle

	if n%18000 < 14000 then
		SendToUnsynced("MapAtmosphereConfigSetSun", 1, 0.8, 1)
	else
		SendToUnsynced("MapAtmosphereConfigSetSun", 0.5, 0.8, 0.65)
	end

-- common foggy cliffs
	if n%360 == 0 then
		SpawnCEGInPositionGround("fogdirty", 6249, 0, 2938)
		SpawnCEGInPositionGround("fogdirty", 1029, 0, 3715)
	end

-- rare foggy cliffs
	if n%600 == 0 then
		SpawnCEGInPositionGround("fogdirty", 4270, 0, 2025)
		SpawnCEGInPositionGround("fogdirty", 2477, 0, 3812)
		SpawnCEGInPositionGround("fogdirty", 1495, 0, 5994)
	end

-- alternate rare foggy cliffs
	if n%620 == 300 then
		SpawnCEGInPositionGround("fogdirty", 6231, 0, 3595)
		SpawnCEGInPositionGround("fogdirty", 5047, 0, 5487)
		SpawnCEGInPositionGround("fogdirty", 2349, 0, 1752)
	end

-- super rare foggy cliffs
	if n%1100 == 0 then
		SpawnCEGInPositionGround("fogdirty", 2839, 0, 6290)
		SpawnCEGInPositionGround("fogdirty", 3892, 0, 1194)
	end

-- fireflies
	if n%800 == 0 then
		SpawnCEGInPositionGround("firefliesgreen", 3576, 50, 1415)
		SpawnCEGInPositionGround("firefliesgreen", 3173, 50, 6021)
	end

-- pollen
	if n%150 == 0 then
		SpawnCEGInRandomMapPos("dustparticles", 50)
	end

-- rare rain
	if n%7800 == 5000 then
		SpawnCEGInRandomMapPos("rain", 0, _, _, _, "rainlight", 1)
	end

-- very rare rain
	if n%12800 == 9000 then
		SpawnCEGInRandomMapPos("rainlight", 0, _, _, _, "rainlight", 1)
	end

end
