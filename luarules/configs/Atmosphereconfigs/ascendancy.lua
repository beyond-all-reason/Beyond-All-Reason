function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

-- SND windy locations
	if n%1150 == 0 then
		SpawnCEGInPositionGround("noceg", 2200, 500, 4200, _, _, _, "windy", 0.2)
	end

	if n%1270 == 100 then
		SpawnCEGInPositionGround("noceg", 10000, 600, 4000, _, _, _, "windy", 0.2)
	end

-- SND geos Replaced by SFX_geovent.lua
	-- if n%120 == 5 then
	-- 	SpawnCEGInPositionGround("noceg", 6181, 200, 7267, _, _, _, "geoventshort", 0.4)
	-- end

	-- if n%120 == 35 then
	-- 	SpawnCEGInPositionGround("noceg", 4113, 200, 6741, _, _, _, "geoventshort", 0.4)
	-- end

	-- if n%120 == 65 then
	-- 	SpawnCEGInPositionGround("noceg", 8227, 200, 6652, _, _, _, "geoventshort", 0.4)
	-- end

	-- if n%120 == 20 then
	-- 	SpawnCEGInPositionGround("noceg", 4200, 200, 1355, _, _, _, "geoventshort", 0.4)
	-- end

	-- if n%120 == 50 then
	-- 	SpawnCEGInPositionGround("noceg", 6218, 200, 892, _, _, _, "geoventshort", 0.4)
	-- end

	-- if n%120 == 80 then
	-- 	SpawnCEGInPositionGround("noceg", 8220, 200, 1442, _, _, _, "geoventshort", 0.4)
	-- end

	-- if n%120 == 95 then
	-- 	SpawnCEGInPositionGround("noceg", 6050, 200, 4204, _, _, _, "geoventshort", 0.4)
	-- end

-- ## Atmosphere CEG Functions

-- SpawnCEGInPosition (cegname, posx, posy, posz, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInPositionGround(cegname, posx, groundOffset, posz, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInArea(cegname, midposx, posy, midposz, radius, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInAreaGround(cegname, midposx, groundOffset, midposz, radius, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInRandomMapPos(cegname, groundOffset, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInRandomMapPosBelowY(cegname, groundOffset, spawnOnlyBelowY, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInRandomMapPosPresetY(cegname, posy, damage, paralyzedamage, damageradius, sound, soundvolume)

-- Use _ for damage, paralyzedamage, damageradius if you want to disable

-- common foggy cliffs	
	if n%360 == 0 then
		SpawnCEGInPositionGround("fogdirty", 5600, 0, 128)
		SpawnCEGInPositionGround("fogdirty", 5900, 0, 150)
		SpawnCEGInPositionGround("fogdirty", 6530, 0, 220)
		SpawnCEGInPositionGround("fogdirty", 5090, 0, 250)
		SpawnCEGInPositionGround("fogdirty", 6765, 0, 390)
		SpawnCEGInPositionGround("fogdirty", 12058, 0, 71)
		SpawnCEGInPositionGround("fogdirty", 6190, 0, 520)
		SpawnCEGInPositionGround("fogdirty", 5690, 0, 590)
		SpawnCEGInPositionGround("fogdirty", 7152, 0, 2285)
		SpawnCEGInPositionGround("fogdirty", 5063, 0, 2270)
		SpawnCEGInPositionGround("fogdirty", 380, 0, 554)
	end

-- rare foggy cliffs	
	-- if n%380 == 150 then
		-- SpawnCEGInPositionGround("fogdirty", 6139, 32, 2550)
		-- SpawnCEGInPositionGround("fogdirty", 2256, 32, 4227)
		-- SpawnCEGInPositionGround("fogdirty", 3994, 0, 7976)

	-- end

-- -- mistyclouds	
	-- if n%1200 == 550 then
	-- 	SpawnCEGInPositionGround("mistycloud", 9076, 150, 6829)
	-- end

-- -- rare sanddune dust	
-- 	if n%450 == 0 then
-- 		SpawnCEGInPositionGround("dunecloud", 4542, 0, 5326)
-- 	end

-- alternate rare foggy cliffs	
	-- if n%620 == 300 then
		-- SpawnCEGInPositionGround("fogdirty", 10965, 32, 4792)
		-- SpawnCEGInPositionGround("fogdirty", 10910, 16, 1254)
		-- SpawnCEGInPositionGround("fogdirty", 810, 0, 6156)
	-- end

-- super rare foggy cliffs	
	-- if n%1000 == 400 then
		-- SpawnCEGInPositionGround("fogdirty", 6022, 16, 4232)
		-- SpawnCEGInPositionGround("fogdirty", 9535, 32, 6993)
	-- end

-- fireflies
	-- if n%1400 == 0 then
	-- 	SpawnCEGInPositionGround("firefliesgreen", 3423, 32, 5559)
	-- 	SpawnCEGInPositionGround("firefliesgreen", 7079, 32, 4449)
	-- 	SpawnCEGInPositionGround("fireflies", 9561, 32, 1072)
	-- 	SpawnCEGInPositionGround("fireflies", 223, 32, 249)
	-- end

-- pollen
	if n%300 == 0 then
		SpawnCEGInRandomMapPos("dustparticles", 50)
	end
		
end