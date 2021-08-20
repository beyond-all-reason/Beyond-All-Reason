function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

-- SND water ocean 
	-- if n%830 == 0 then
	-- 	SpawnCEGInPositionGround("noceg", 4000, 0, 1200, _, _, _, "tropicalbeach", 0.9)
	-- end

	-- if n%840 == 150 then
	-- 	SpawnCEGInPositionGround("noceg", 1400, 0, 5500, _, _, _, "tropicalbeach", 0.9)
	-- end

	-- if n%850 == 75 then
	-- 	SpawnCEGInPositionGround("noceg", 6800, 0, 5600, _, _, _, "tropicalbeach", 0.9)
	-- end

	if n%860 == 20 then
		SpawnCEGInPositionGround("noceg", 2200, 0, 6000, _, _, _, "oceangentlesurf", 0.9)
	end

	if n%860 == 50 then
		SpawnCEGInPositionGround("noceg", 6000, 0, 1100, _, _, _, "oceangentlesurf", 0.9)
	end

	-- if n%860 == 80 then
	-- 	SpawnCEGInPositionGround("noceg", 4130, 0, 5000, _, _, _, "oceangentlesurf", 0.9)
	-- end

-- SND geos
	if n%560 == 0 then
		SpawnCEGInPositionGround("noceg", 4138, 200, 4972, _, _, _, "geovent", 0.4)
	end

	if n%560 == 30 then
		SpawnCEGInPositionGround("noceg", 2848, 200, 6945, _, _, _, "geovent", 0.4)
	end

	if n%560 == 60 then
		SpawnCEGInPositionGround("noceg", 5558, 200, 6976, _, _, _, "geovent", 0.4)
	end

	if n%560 == 15 then
		SpawnCEGInPositionGround("noceg", 4031, 200, 2190, _, _, _, "geovent", 0.4)
	end

	if n%560 == 45 then
		SpawnCEGInPositionGround("noceg", 2606, 200, 200, _, _, _, "geovent", 0.4)
	end

	if n%560 == 75 then
		SpawnCEGInPositionGround("noceg", 5361, 200, 224, _, _, _, "geovent", 0.4)
	end

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

-- -- sanddune dust	
-- 	if n%200 == 0 then
-- 		SpawnCEGInPositionGround("dunecloud", 3940, 0, 3755)
-- 	end

-- -- rare sanddune dust	
-- 	if n%450 == 0 then
-- 		SpawnCEGInPositionGround("dunecloud", 4542, 0, 5326)
-- 	end

-- alternate rare foggy cliffs	
	if n%620 == 300 then
		SpawnCEGInPositionGround("fogdirty", 6983, 0, 2452)
		SpawnCEGInPositionGround("fogdirty", 1580, 0, 1888)
		SpawnCEGInPositionGround("fogdirty", 6016, 0, 1200)
	end

-- super rare foggy cliffs	
	if n%1000 == 400 then
		SpawnCEGInPositionGround("fogdirty", 6060, 400, 141)
		SpawnCEGInPositionGround("fogdirty", 2142, 400, 6910)
		-- SpawnCEGInPositionGround("fogdirty", 2631, 0, 6591)
	end

-- fireflies
	if n%1400 == 0 then
		SpawnCEGInPositionGround("firefliesgreen", 2050, 32, 4850)
		SpawnCEGInPositionGround("firefliesgreen", 6136, 32, 2334)
		-- SpawnCEGInPositionGround("firefliesgreen", 1186, 32, 3014)
		-- SpawnCEGInPositionGround("firefliesgreen", 4771, 32, 7017)
	end

-- pollen
	if n%500 == 0 then
		SpawnCEGInRandomMapPos("dustparticles", 50)
	end
		
end