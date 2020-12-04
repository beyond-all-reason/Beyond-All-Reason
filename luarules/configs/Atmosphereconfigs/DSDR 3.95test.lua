function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end
	
	if n%5 == 0 then
		--SpawnCEGInRandomMapPos("rain", 0)
	end
	
	local lightningsounds = {
	"thunder1",
	"thunder2",
	"thunder3",
	"thunder4",
	"thunder5",
	"thunder6",
	}    

	if n%30 == 0 then
		SpawnCEGInPositionGround("lightningstrike", 3298, 0, 2811, _, 10, 256, lightningsounds[math.random(1,#lightningsounds)], 1)
	end
	
	-- if n%5000 == 2100 then
		-- SpawnCEGInRandomMapPos("lightningstrike", 0, lightningsounds[math.random(1,#lightningsounds)], 1)
	-- end
	-- if n%5300 == 2540 then
		-- SpawnCEGInRandomMapPos("lightningstrike", 0, lightningsounds[math.random(1,#lightningsounds)], 1)
	-- end
	-- if n%5700 == 2810 then
		-- SpawnCEGInRandomMapPos("lightningstrike", 0, lightningsounds[math.random(1,#lightningsounds)], 1)
	-- end
	-- if n%5900 == 3400 then
		-- SpawnCEGInRandomMapPos("lightningstrike", 0, lightningsounds[math.random(1,#lightningsounds)], 1)
	-- end
	
	
end