function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. mapname)
	end

-- common foggy cliffs	
	if n%360 == 0 then
		SpawnCEGInPositionGround("fogdirty", 5437, 0, 3089)
		SpawnCEGInPositionGround("fogdirty", 3658, 0, 4861)
		SpawnCEGInPositionGround("fogdirty", 6594, 0, 1463)
		SpawnCEGInPositionGround("fogdirty", 7414, 0, 1930)
		SpawnCEGInPositionGround("fogdirty", 7224, 0, 5786)
		SpawnCEGInPositionGround("fogdirty", 3034, 0, 3736)
	end

-- rare foggy cliffs	
	if n%700 == 0 then
		SpawnCEGInPositionGround("fogdirty", 2861, 0, 659)
		SpawnCEGInPositionGround("fogdirty", 3687, 0, 4067)
		SpawnCEGInPositionGround("fogdirty", 248, 0, 7927)
		SpawnCEGInPositionGround("fogdirty", 1891, 0, 4373)
		SpawnCEGInPositionGround("fogdirty", 1050, 0, 2410)
	end

-- super rare foggy cliffs	
	if n%1100 == 0 then
		SpawnCEGInPositionGround("fogdirty", 4026, 0, 4667)
		SpawnCEGInPositionGround("fogdirty", 7104, 0, 2290)
	end

-- powerup heavy metal
	if n%900 == 0 then
		SpawnCEGInPositionGround("powerupwhite", 3447, 0, 4172)
		SpawnCEGInPositionGround("powerupwhite", 3582, 0, 4383)
		SpawnCEGInPositionGround("powerupwhite", 5076, 0, 3385)
		SpawnCEGInPositionGround("powerupwhite", 4937, 0, 3099)
		SpawnCEGInPositionGround("powerupwhite", 7530, 0, 272)
		SpawnCEGInPositionGround("powerupwhite", 7772, 0, 276)
		SpawnCEGInPositionGround("powerupwhite", 588, 0, 7937)
		SpawnCEGInPositionGround("powerupwhite", 814, 0, 8011)
	end

-- rare sandclouds
	if n%1900 == 800 then
		SpawnCEGInAreaGround("sandcloud", 154, 0, 165, 200)
		SpawnCEGInAreaGround("sandcloud", 7200, 0, 7200, 200)
	end
		
end