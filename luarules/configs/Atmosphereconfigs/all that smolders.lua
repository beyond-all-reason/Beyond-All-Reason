local gadget = gadget ---@type Gadget

function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

-- random sandclouds
	if n%400 == 200 then
		SpawnCEGInArea("sandcloud_sparse", 3300, 200, 2800, 2500)
	end
	if n%400 == 200 then
		SpawnCEGInArea("sandcloud_sparse", 2300, 200, 5100, 1000)
	end
	if n%400 == 200 then
		SpawnCEGInArea("sandcloud_sparse", 500, 200, 7700, 2500)
	end
	
	-- if n%2000 == 1000 then
	-- 	SpawnCEGInArea("sandclouddense", 3200, 235, 1900, 1900)
	-- end
	
	-- if n%6000 == 3000 then
	-- 	SpawnCEGInArea("sandclouddensexl", 3200, 235, 1900, 500)
	-- end
	
end