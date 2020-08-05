function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. mapname)
	end

-- common foggy cliffs	
	if n%360 == 0 then
		SpawnCEGInPosition("fogdirty", 5437, 212, 3089)
		SpawnCEGInPosition("fogdirty", 3658, 179, 4861)
		SpawnCEGInPosition("fogdirty", 6594, 93, 1463)
		SpawnCEGInPosition("fogdirty", 7414, 317, 1930)
		SpawnCEGInPosition("fogdirty", 7224, 384, 5786)
		SpawnCEGInPosition("fogdirty", 3034, 32, 3736)
	end

-- rare foggy cliffs	
	if n%700 == 0 then
		SpawnCEGInPosition("fogdirty", 2861, 407, 659)
		SpawnCEGInPosition("fogdirty", 3687, 383, 4067)
		SpawnCEGInPosition("fogdirty", 248, 150, 7927)
		SpawnCEGInPosition("fogdirty", 1891, 255, 4373)
		SpawnCEGInPosition("fogdirty", 1050, 450, 2410)
	end

-- super rare foggy cliffs	
	if n%1100 == 0 then
		SpawnCEGInPosition("fogdirty", 4026, 672, 4667)
		SpawnCEGInPosition("fogdirty", 7104, 569, 2290)
	end

-- powerup heavy metal
	if n%900 == 0 then
		SpawnCEGInPosition("powerupwhite", 3447, 525, 4172)
		SpawnCEGInPosition("powerupwhite", 3582, 496, 4383)
		SpawnCEGInPosition("powerupwhite", 5076, 523, 3385)
		SpawnCEGInPosition("powerupwhite", 4937, 513, 3099)
		SpawnCEGInPosition("powerupwhite", 7530, 210, 272)
		SpawnCEGInPosition("powerupwhite", 7772, 206, 276)
		SpawnCEGInPosition("powerupwhite", 588, 156, 7937)
		SpawnCEGInPosition("powerupwhite", 814, 144, 8011)
	end

-- rare sandclouds
	if n%1900 == 800 then
		SpawnCEGInAreaGround("sandcloud", 154, 0, 165, 200)
		SpawnCEGInAreaGround("sandcloud", 7200, 0, 7200, 200)
	end
		
end