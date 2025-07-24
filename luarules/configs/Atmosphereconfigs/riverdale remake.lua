local gadget = gadget ---@type Gadget

function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

-- ## Atmosphere Functions
-- SpawnCEGInPosition (cegname, posx, posy, posz, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInPositionGround(cegname, posx, groundOffset, posz, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInArea(cegname, midposx, posy, midposz, radius, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInAreaGround(cegname, midposx, groundOffset, midposz, radius, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInRandomMapPos(cegname, groundOffset, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInRandomMapPosBelowY(cegname, groundOffset, spawnOnlyBelowY, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInRandomMapPosPresetY(cegname, posy, damage, paralyzedamage, damageradius, sound, soundvolume)

-- Use _ for damage, paralyzedamage, damageradius if you want to disable

-- common foggy cliffs	
	if n%540 == 0 then
		SpawnCEGInPositionGround("fogdirty", 374, 32, 6318)
		--SpawnCEGInPositionGround("fogdirty", 3785, 219, 1594)
		SpawnCEGInPositionGround("fogdirty", 346, 32, 1550)
	end

--rare foggy cliffs	
	if n%610 == 305 then
		SpawnCEGInPositionGround("fogdirty", 208, 32, 6630)
		SpawnCEGInPositionGround("fogdirty", 2919, 32, 6133)
		SpawnCEGInPositionGround("fogdirty", 529, 32, 9794)
		SpawnCEGInPositionGround("fogdirty", 5544, 32, 2730)
	end

--foggy canyon	
	if n%300 == 100 then
		SpawnCEGInPositionGround("fogdirty", 814, 0, 7504)
		SpawnCEGInPositionGround("fogdirty", 773, 32, 8189)
		SpawnCEGInPositionGround("fogdirty", 887, 0, 9111)
	end	

--foggy canyon alt
	if n%310 == 250 then
		SpawnCEGInPositionGround("fogdirty", 757, 0, 7800)		
		SpawnCEGInPositionGround("fogdirty", 776, 0, 8615)
	end	

-- common fireflies
	if n%1000 == 0 then
		SpawnCEGInPositionGround("fireflies", 3110, 32, 1950)
		SpawnCEGInPositionGround("fireflies", 1061, 32, 3479)
	end

-- rare fireflies
	if n%1800 == 0 then
		SpawnCEGInPositionGround("firefliesgreen", 1627, 32, 4932)
		SpawnCEGInPositionGround("firefliesgreen", 5600, 32, 6159)
		SpawnCEGInPositionGround("firefliesgreen", 207, 32, 7963)
		SpawnCEGInPositionGround("firefliesgreen", 5540, 32, 8472)
	end

-- random rain
	if n%3400 == 1600 then
		SpawnCEGInRandomMapPos("rain", 0, _, _, _, "rainlight", 1)
	end
	
	
	
	
end