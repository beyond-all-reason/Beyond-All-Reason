local gadget = gadget ---@type Gadget

function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

-- random sandclouds
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 6000, 0, 5919, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 4770, 0, 6680, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 7160, 0, 5388, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 4700, 0, 7300, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 4140, 0, 7456, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 4610, 0, 8710, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 5562, 0, 8540, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 4560, 0, 10210, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 7120, 0, 9950, 50)
	end
	
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 50, 0, 50, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 2400, 0, 40, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 2400, 0, 1200, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 40, 0, 2200, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 13300, 0, 2500, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 2300, 0, 3300, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 1300, 0, 3900, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 50, 0, 4700, 50)
	end
	if n%400 == 200 then
		SpawnCEGInArea("mistycloud", 6, 0, 3400, 50)
	end
	
	-- if n%2000 == 1000 then
	-- 	SpawnCEGInArea("sandclouddense", 3200, 235, 1900, 1900)
	-- end
	
	-- if n%6000 == 3000 then
	-- 	SpawnCEGInArea("sandclouddensexl", 3200, 235, 1900, 500)
	-- end
	
end
