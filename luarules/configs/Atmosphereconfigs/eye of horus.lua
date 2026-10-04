local gadget = gadget ---@type Gadget

function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

-- SND windy locations
	if n%1020 == 0 then
		SpawnCEGInPositionGround("noceg", 400, 500, 4000, _, _, _, "windy", 0.15)
	end

	if n%990 == 100 then
		SpawnCEGInPositionGround("noceg", 5900, 600, 3000, _, _, _, "windy", 0.15)
	end

	if n%1010 == 200 then
		SpawnCEGInPositionGround("noceg", 2000, 600, 7000, _, _, _, "windy", 0.15)
	end

	if n%980 == 300 then
		SpawnCEGInPositionGround("noceg", 3400, 600, 140, _, _, _, "windy", 0.15)
	end

-- SND water ocean 
	-- if n%960 == 20 then
	-- 	SpawnCEGInPositionGround("noceg", 2200, 0, 6000, _, _, _, "oceangentlesurf", 0.3)
	-- end

	-- if n%960 == 50 then
	-- 	SpawnCEGInPositionGround("noceg", 6000, 0, 1100, _, _, _, "oceangentlesurf", 0.3)
	-- end

-- SND geos Replaced by SFX_geovent.lua
	-- if n%120 == 0 then
	-- 	SpawnCEGInPositionGround("noceg", 290, 200, 140, _, _, _, "geoventshort", 0.15)
	-- end

	-- if n%120 == 30 then
	-- 	SpawnCEGInPositionGround("noceg", 71, 200, 4586, _, _, _, "geoventshort", 0.15)
	-- end

	-- if n%120 == 60 then
	-- 	SpawnCEGInPositionGround("noceg", 6077, 200, 2559, _, _, _, "geoventshort", 0.15)
	-- end

	-- if n%120 == 15 then
	-- 	SpawnCEGInPositionGround("noceg", 4008, 200, 7032, _, _, _, "geoventshort", 0.15)
	-- end

-- common foggy canyon	
	-- if n%700 == 0 then
	-- 	-- SpawnCEGInPositionGround("mistycloud", 4286, 300, 3100)
	-- 	-- SpawnCEGInPositionGround("mistycloud", 5083, 200, 4419)
	-- 	--SpawnCEGInPositionGround("fogdirty", 240, 100, 3655)
	-- end

-- rare foggy craters	
	if n%92 == 0 then

	SpawnCEGInRandomMapPosBelowY("dunecloud", 32, 270)
	-- 	--SpawnCEGInPositionGround("mistycloud", 2561, 220, 5925)
	-- 	--SpawnCEGInPositionGround("fogdirty", 7940, 100, 3538)
	end

-- alternate rare foggy cliffs	
	-- if n%620 == 300 then
	-- 	--SpawnCEGInPositionGround("fogdirty", 6983, 0, 2452)
	-- 	--SpawnCEGInPositionGround("fogdirty", 1580, 0, 1888)
	-- end

-- super rare foggy cliffs	
	-- if n%1000 == 400 then
	-- 	--SpawnCEGInPositionGround("fogdirty", 6060, 400, 141)
	-- 	--SpawnCEGInPositionGround("fogdirty", 2142, 400, 6910)
	-- end

-- mistyclouds	
	-- if n%1000 == 400 then
	-- 	--SpawnCEGInPositionGround("mistycloud", 5836, 500, 5343)
	-- end

	-- if n%1100 == 200 then
	-- 	--SpawnCEGInPositionGround("mistycloud", 2279, 400, 1951)
	-- end

-- pollen
	-- if n%600 == 0 then
	-- 	SpawnCEGInRandomMapPos("dustparticles", 50)
	-- end
		
end