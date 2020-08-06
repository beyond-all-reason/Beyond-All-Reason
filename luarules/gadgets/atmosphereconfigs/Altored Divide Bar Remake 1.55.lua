function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. mapname)
	end

-- common foggy cliffs	
	if n%360 == 0 then
		SpawnCEGInPosition("fogdirty", 1490, 79, 4271)
		SpawnCEGInPosition("fogdirty", 5545, 219, 3359)
		SpawnCEGInPosition("fogdirty", 3365, 164, 3438)
		SpawnCEGInPosition("fogdirty", 5261, 252, 2582)
		SpawnCEGInPosition("fogdirty", 4039, 283, 4245)
		SpawnCEGInPosition("fogdirty", 5626, 315, 4687)
		SpawnCEGInPosition("fogdirty", 2913, 332, 5769)
		SpawnCEGInPosition("fogdirty", 360, 120, 2558)
	end

-- rare foggy cliffs	
	if n%700 == 0 then
		SpawnCEGInPosition("fogdirty", 624, 145, 565)
		SpawnCEGInPosition("fogdirty", 7201, 270, 5743)
	end

-- common fireflies
	if n%1000 == 0 then
		SpawnCEGInPosition("fireflies", 774, 99, 4289)
		SpawnCEGInPosition("fireflies", 7299, 184, 3964)
		SpawnCEGInPosition("fireflies", 2933, 117, 4136)
	end

-- rare fireflies
	if n%2200 == 0 then
		SpawnCEGInPosition("fireflies", 3362, 146, 3494)
		SpawnCEGInPosition("fireflies", 943, 81, 3381)
	end

-- random rain
	if n%3200 == 1600 then
		SpawnCEGInRandomMapPos("rain", 0)
	end
	
	
	
	
end