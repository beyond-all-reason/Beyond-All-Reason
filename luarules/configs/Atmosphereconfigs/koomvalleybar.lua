local gadget = gadget ---@type Gadget

function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

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
		SpawnCEGInPositionGround("fogdirty", 6191, 32, 5656)
		SpawnCEGInPositionGround("fogdirty", 9123, 64, 1569)
		SpawnCEGInPositionGround("fogdirty", 2140, 32, 4752)
	end

-- rare foggy cliffs	
	if n%380 == 150 then
		SpawnCEGInPositionGround("fogdirty", 6139, 32, 2550)
		SpawnCEGInPositionGround("fogdirty", 2256, 32, 4227)
		SpawnCEGInPositionGround("fogdirty", 3994, 0, 7976)

	end

-- -- mistyclouds	
	-- if n%1200 == 550 then
	-- 	SpawnCEGInPositionGround("mistycloud", 9076, 150, 6829)
	-- end

-- -- rare sanddune dust	
-- 	if n%450 == 0 then
-- 		SpawnCEGInPositionGround("dunecloud", 4542, 0, 5326)
-- 	end

-- alternate rare foggy cliffs	
	if n%620 == 300 then
		SpawnCEGInPositionGround("fogdirty", 10965, 32, 4792)
		SpawnCEGInPositionGround("fogdirty", 10910, 16, 1254)
		SpawnCEGInPositionGround("fogdirty", 810, 0, 6156)
	end

-- super rare foggy cliffs	
	if n%1000 == 400 then
		SpawnCEGInPositionGround("fogdirty", 6022, 16, 4232)
		SpawnCEGInPositionGround("fogdirty", 9535, 32, 6993)
	end

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