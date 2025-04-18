local gadget = gadget ---@type Gadget

function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

-- SpawnCEGInAreaGround(cegname, midposx, groundOffset, midposz, radius, damage, paralyzedamage, damageradius, sound, soundvolume)

-- SND water ocean 
	if n%1030 == 0 then
		SpawnCEGInPositionGround("noceg", 3800, 60, 3800, _, _, _, "oceangentlesurf", 0.3)
	end

	if n%1050 == 150 then
		SpawnCEGInPositionGround("noceg", 2700, 30, 1200, _, _, _, "oceangentlesurf", 0.3)
	end

	if n%1070 == 75 then
		SpawnCEGInPositionGround("noceg", 5500, 30, 5900, _, _, _, "oceangentlesurf", 0.3)
	end

	if n%1090 == 20 then
		SpawnCEGInPositionGround("noceg", 650, 100, 6550, _, _, _, "tropicalbeach", 0.3)
	end

	if n%1060 == 70 then
		SpawnCEGInPositionGround("noceg", 600, 100, 800, _, _, _, "tropicalbeach", 0.3)
	end

	if n%1080 == 50 then
		SpawnCEGInPositionGround("noceg", 6450, 100, 800, _, _, _, "tropicalbeach", 0.3)
	end

	if n%1100 == 90 then
		SpawnCEGInPositionGround("noceg", 6700, 100, 6700, _, _, _, "tropicalbeach", 0.3)
	end

-- SND windy locations
	if n%1260 == 0 then
		SpawnCEGInPositionGround("noceg", 1300, 500, 6000, _, _, _, "windy", 0.2)
	end

	if n%1320 == 100 then
		SpawnCEGInPositionGround("noceg", 5500, 500, 1150, _, _, _, "windy", 0.2)
	end

-- ## Atmosphere Functions
-- SendToUnsynced("MapAtmosphereConfigSetSun", red&green, transitionspeed, blue)
-- SendToUnsynced("MapAtmosphereConfigSetFog", targetfogstart, targetfogend, transitionspeedfogstart, transitionspeedfogend)

-- DayNight Cycle

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

end
