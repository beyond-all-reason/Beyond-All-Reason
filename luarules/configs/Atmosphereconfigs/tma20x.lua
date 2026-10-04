local gadget = gadget ---@type Gadget

function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

-- common foggy cliffs	
	if n%360 == 0 then
		SpawnCEGInPositionGround("fogdirty", 583, 0, 5978)
		SpawnCEGInPositionGround("fogdirty", 1183, 0, 8626)
		SpawnCEGInPositionGround("fogdirty", 9538, 0, 3735)
		SpawnCEGInPositionGround("fogdirty", 2789, 0, 3481)
		SpawnCEGInPositionGround("fogdirty", 2948, 0, 6443)
		SpawnCEGInPositionGround("fogdirty", 3253, 0, 5713)
		SpawnCEGInPositionGround("fogdirty", 5956, 75, 7442)
		SpawnCEGInPositionGround("fogdirty", 880, 0, 2916)
	end

-- alternate common foggy cliffs	
	if n%360 == 180 then
		SpawnCEGInPositionGround("fogdirty", 7526, 25, 8427)
		SpawnCEGInPositionGround("fogdirty", 2477, 0, 3812)
		SpawnCEGInPositionGround("fogdirty", 6237, 0, 6953)
		SpawnCEGInPositionGround("fogdirty", 6547, 0, 6482)
		SpawnCEGInPositionGround("fogdirty", 3216, 0, 9585)
		SpawnCEGInPositionGround("fogdirty", 602, 0, 5163)
		SpawnCEGInPositionGround("fogdirty", 2734, 75, 6912)
	end

-- alternate rare foggy cliffs	
	if n%620 == 300 then
		SpawnCEGInPositionGround("fogdirty", 9055, 0, 2254)
	end

-- super rare foggy cliffs	
	if n%1100 == 0 then
		SpawnCEGInPositionGround("fogdirty", 2839, 0, 6290)
		SpawnCEGInPositionGround("fogdirty", 3892, 0, 1194)
	end

-- pollen
	if n%150 == 0 then
		SpawnCEGInRandomMapPos("dustparticles", 50)
	end
		
end