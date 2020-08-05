function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. mapname)
	end
	
	if n%300 == 0 then
		--SpawnCEGInRandomMapPos("rain", 0)
		SpawnCEGInPosition("fogdirty", 1490, 79, 4271)
		SpawnCEGInPosition("fogdirty", 5545, 219, 3359)
		SpawnCEGInPosition("fogdirty", 3365, 164, 3438)
		SpawnCEGInPosition("fogdirty", 5261, 252, 2582)
		SpawnCEGInPosition("fogdirty", 4039, 283, 4245)
	end

	if n%1200 == 0 then
		--SpawnCEGInRandomMapPos("rain", 0)
		SpawnCEGInPosition("fireflies", 774, 99, 4289)
		SpawnCEGInPosition("fireflies", 7299, 184, 3964)
		SpawnCEGInPosition("fireflies", 2933, 117, 4136)
	end
	
	
	
	
end