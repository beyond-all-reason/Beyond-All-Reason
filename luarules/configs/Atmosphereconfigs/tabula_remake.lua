local gadget = gadget ---@type Gadget

function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

-- SND windy locations
	if n%950 == 0 then
		SpawnCEGInPositionGround("noceg", 2000, 500, 2100, _, _, _, "windy", 0.2)
	end

	if n%990 == 100 then
		SpawnCEGInPositionGround("noceg", 6000, 600, 4900, _, _, _, "windy", 0.2)
	end

-- SND water ocean 
	if n%960 == 20 then
		SpawnCEGInPositionGround("noceg", 2200, 0, 6000, _, _, _, "oceangentlesurf", 0.3)
	end

	if n%960 == 50 then
		SpawnCEGInPositionGround("noceg", 6000, 0, 1100, _, _, _, "oceangentlesurf", 0.3)
	end

-- SND geos Replaced by SFX_geovent.lua
	-- if n%120 == 0 then
	-- 	SpawnCEGInPositionGround("noceg", 4138, 200, 4972, _, _, _, "geoventshort", 0.3)
	-- end

	-- if n%120 == 30 then
	-- 	SpawnCEGInPositionGround("noceg", 2848, 200, 6945, _, _, _, "geoventshort", 0.3)
	-- end

	-- if n%120 == 60 then
	-- 	SpawnCEGInPositionGround("noceg", 5558, 200, 6976, _, _, _, "geoventshort", 0.3)
	-- end

	-- if n%120 == 15 then
	-- 	SpawnCEGInPositionGround("noceg", 4031, 200, 2190, _, _, _, "geoventshort", 0.3)
	-- end

	-- if n%120 == 45 then
	-- 	SpawnCEGInPositionGround("noceg", 2606, 200, 200, _, _, _, "geoventshort", 0.3)
	-- end

	-- if n%120 == 75 then
	-- 	SpawnCEGInPositionGround("noceg", 5361, 200, 224, _, _, _, "geoventshort", 0.3)
	-- end

-- common foggy cliffs	
	if n%360 == 0 then
		SpawnCEGInPositionGround("fogdirty", 5673, 64, 2100)
		SpawnCEGInPositionGround("fogdirty", 2488, 64, 5117)
		SpawnCEGInPositionGround("fogdirty", 240, 100, 3655)
	end

-- rare foggy cliffs	
	if n%380 == 150 then
		SpawnCEGInPositionGround("fogdirty", 3231, 100, 5328)
		SpawnCEGInPositionGround("fogdirty", 1051, 100, 5485)
		SpawnCEGInPositionGround("fogdirty", 7940, 100, 3538)
	end

-- alternate rare foggy cliffs	
	if n%620 == 300 then
		SpawnCEGInPositionGround("fogdirty", 6983, 0, 2452)
		SpawnCEGInPositionGround("fogdirty", 1580, 0, 1888)
	end

-- super rare foggy cliffs	
	if n%1000 == 400 then
		SpawnCEGInPositionGround("fogdirty", 6060, 400, 141)
		SpawnCEGInPositionGround("fogdirty", 2142, 400, 6910)
	end

-- mistyclouds	
	if n%1000 == 400 then
		SpawnCEGInPositionGround("mistycloud", 5836, 500, 5343)
	end

	if n%1100 == 200 then
		SpawnCEGInPositionGround("mistycloud", 2279, 400, 1951)
	end

-- fireflies
	if n%1400 == 0 then
		SpawnCEGInPositionGround("fireflies", 2050, 32, 4850)
		SpawnCEGInPositionGround("fireflies", 6136, 32, 2334)
	end

-- pollen
	if n%500 == 0 then
		SpawnCEGInRandomMapPos("dustparticles", 50)
	end
		
end