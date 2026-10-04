local gadget = gadget ---@type Gadget

function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

-- SND windy locations
	if n%1020 == 0 then
		SpawnCEGInPositionGround("noceg", 6200, 500, 900, _, _, _, "windy_mountains", 0.15)
	end

	if n%990 == 100 then
		SpawnCEGInPositionGround("noceg", 3200, 600, 2300, _, _, _, "windy_mountains", 0.15)
	end

	if n%1010 == 200 then
		SpawnCEGInPositionGround("noceg", 6200, 600, 2900, _, _, _, "windy_mountains", 0.15)
	end

	if n%980 == 300 then
		SpawnCEGInPositionGround("noceg", 3000, 600, 5400, _, _, _, "windy_mountains", 0.15)
	end

-- SND water ocean 
	-- if n%960 == 20 then
	-- 	SpawnCEGInPositionGround("noceg", 2200, 0, 6000, _, _, _, "oceangentlesurf", 0.3)
	-- end

	-- if n%960 == 50 then
	-- 	SpawnCEGInPositionGround("noceg", 6000, 0, 1100, _, _, _, "oceangentlesurf", 0.3)
	-- end

-- SND geos Replaced by SFX_geovent.lua
	-- if n%120 == 0 then
	-- 	SpawnCEGInPositionGround("noceg", 4300, 200, 5400, _, _, _, "geoventshort", 0.15)
	-- end

	-- if n%120 == 30 then
	-- 	SpawnCEGInPositionGround("noceg", 6000, 200, 3900, _, _, _, "geoventshort", 0.15)
	-- end

	-- if n%120 == 60 then
	-- 	SpawnCEGInPositionGround("noceg", 3400, 200, 2150, _, _, _, "geoventshort", 0.15)
	-- end

	-- if n%120 == 15 then
	-- 	SpawnCEGInPositionGround("noceg", 6000, 200, 580, _, _, _, "geoventshort", 0.15)
	-- end

	-- if n%120 == 45 then
	-- 	SpawnCEGInPositionGround("noceg", 766, 200, 7276, _, _, _, "geoventshort", 0.15)
	-- end

	-- if n%120 == 75 then
	-- 	SpawnCEGInPositionGround("noceg", 8460, 200, 2012, _, _, _, "geoventshort", 0.15)
	-- end

-- common foggy canyon	
	if n%700 == 0 then
		SpawnCEGInPositionGround("mistycloud", 4286, 300, 3100)
		SpawnCEGInPositionGround("mistycloud", 5083, 200, 4419)
		--SpawnCEGInPositionGround("fogdirty", 240, 100, 3655)
	end

-- rare foggy cliffs	
	if n%440 == 150 then
		SpawnCEGInPositionGround("mistycloud", 5550, 200, 1237)
		SpawnCEGInPositionGround("mistycloud", 2561, 220, 5925)
		--SpawnCEGInPositionGround("fogdirty", 7940, 100, 3538)
	end

-- alternate rare foggy cliffs	
	if n%620 == 300 then
		--SpawnCEGInPositionGround("fogdirty", 6983, 0, 2452)
		--SpawnCEGInPositionGround("fogdirty", 1580, 0, 1888)
	end

-- super rare foggy cliffs	
	if n%1000 == 400 then
		--SpawnCEGInPositionGround("fogdirty", 6060, 400, 141)
		--SpawnCEGInPositionGround("fogdirty", 2142, 400, 6910)
	end

-- mistyclouds	
	if n%1000 == 400 then
		--SpawnCEGInPositionGround("mistycloud", 5836, 500, 5343)
	end

	if n%1100 == 200 then
		--SpawnCEGInPositionGround("mistycloud", 2279, 400, 1951)
	end

-- pollen
	if n%600 == 0 then
		SpawnCEGInRandomMapPos("dustparticles", 50)
	end
		
end