function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. mapname)
	end

-- random sandclouds
	if n%400 == 200 then
		--SpawnCEGInRandomMapPos("rain", 0)
		SpawnCEGInArea("sandcloud", 3200, 235, 1900, 1500)
	end
	
	if n%2000 == 1000 then
		--SpawnCEGInRandomMapPos("rain", 0)
		SpawnCEGInArea("sandclouddense", 3200, 235, 1900, 1900)
	end
	
	if n%6000 == 3000 then
		--SpawnCEGInRandomMapPos("rain", 0)
		SpawnCEGInArea("sandclouddensexl", 3200, 235, 1900, 500)
	end
	
end