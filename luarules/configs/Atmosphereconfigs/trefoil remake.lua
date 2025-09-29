local gadget = gadget ---@type Gadget

function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

-- SND water ocean 
	if n%830 == 0 then
		SpawnCEGInPositionGround("noceg", 4000, 0, 1200, _, _, _, "tropicalbeach", 0.9)
	end

	if n%840 == 150 then
		SpawnCEGInPositionGround("noceg", 1400, 0, 5500, _, _, _, "tropicalbeach", 0.9)
	end

	if n%850 == 75 then
		SpawnCEGInPositionGround("noceg", 6800, 0, 5600, _, _, _, "tropicalbeach", 0.9)
	end

	if n%860 == 20 then
		SpawnCEGInPositionGround("noceg", 3200, 0, 3400, _, _, _, "oceangentlesurf", 0.9)
	end

	if n%860 == 50 then
		SpawnCEGInPositionGround("noceg", 5100, 0, 1400, _, _, _, "oceangentlesurf", 0.9)
	end

	if n%860 == 80 then
		SpawnCEGInPositionGround("noceg", 4130, 0, 5000, _, _, _, "oceangentlesurf", 0.9)
	end

-- common foggy cliffs	
	if n%360 == 0 then
		SpawnCEGInPositionGround("fogdirty", 1723, 0, 4129)
		SpawnCEGInPositionGround("fogdirty", 2967, 0, 1935)
		SpawnCEGInPositionGround("fogdirty", 4038, 0, 7229)
	end

-- rare foggy cliffs	
	if n%380 == 150 then
		SpawnCEGInPositionGround("fogdirty", 2967, 0, 5905)
		SpawnCEGInPositionGround("fogdirty", 1158, 0, 2340)
		SpawnCEGInPositionGround("fogdirty", 7009, 0, 3937)

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
		SpawnCEGInPositionGround("fogdirty", 1125, 0, 4042)
		SpawnCEGInPositionGround("fogdirty", 5081, 0, 5634)
		SpawnCEGInPositionGround("fogdirty", 2631, 0, 6591)
	end

-- fireflies
	if n%1400 == 0 then
		SpawnCEGInPositionGround("firefliesgreen", 2925, 32, 6919)
		SpawnCEGInPositionGround("firefliesgreen", 7098, 32, 2288)
		SpawnCEGInPositionGround("firefliesgreen", 1186, 32, 3014)
		SpawnCEGInPositionGround("firefliesgreen", 4771, 32, 7017)
	end

-- pollen
	if n%150 == 0 then
		SpawnCEGInRandomMapPos("dustparticles", 50)
	end
		
end