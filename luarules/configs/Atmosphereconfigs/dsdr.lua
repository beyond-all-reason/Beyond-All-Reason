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
		SpawnCEGInPositionGround("fogdirty-red", 3298, 32, 2811)
		SpawnCEGInPositionGround("fogdirty-red", 6957, 32, 2772)
		SpawnCEGInPositionGround("fogdirty-red", 346, 32, 1550)
	end

--rare foggy cliffs
	if n%610 == 305 then
		SpawnCEGInPositionGround("fogdirty-red", 1799, 32, 440)
		SpawnCEGInPositionGround("fogdirty-red", 8569, 32, 535)
	end

--foggy canyon
	if n%300 == 100 then
		SpawnCEGInPositionGround("fogdirty-red", 5344, 32, 488)
		SpawnCEGInPositionGround("fogdirty-red", 5497, 32, 1299)
	end

--foggy canyon alt
	if n%310 == 250 then
		SpawnCEGInPositionGround("fogdirty-red", 5507, 0, 767)
		SpawnCEGInPositionGround("fogdirty-red", 5228, 0, 1589)
	end

-- fireflies
	if n%1500 == 0 then
		SpawnCEGInPositionGround("firefliesgreen", 6284, 32, 3187)
		SpawnCEGInPositionGround("firefliesgreen", 4813, 32, 3540)
	end

-- fireflies alt
	if n%1500 == 750 then
		SpawnCEGInPositionGround("firefliesgreen", 5980, 32, 112)
		SpawnCEGInPositionGround("firefliesgreen", 2547, 32, 3239)
	end

-- lightningstorms
	--local lightningsounds = {
	--"thunder1",
	--"thunder2",
	--"thunder3",
	--"thunder4",
	--"thunder5",
	--"thunder6",
	--}

	--if n%5000 == 2100 then
	--	SpawnCEGInRandomMapPos("lightningstrike", 0, _, _, _, lightningsounds[math.random(1,#lightningsounds)], 1)
	--end
	--if n%5300 == 2540 then
	--	SpawnCEGInRandomMapPos("lightningstrike", 0, _, _, _, lightningsounds[math.random(1,#lightningsounds)], 1)
	--end
	--if n%5700 == 2810 then
	--	SpawnCEGInRandomMapPos("lightningstrike", 0, _, _, _, lightningsounds[math.random(1,#lightningsounds)], 1)
	--end
	--if n%5900 == 3400 then
	--	SpawnCEGInRandomMapPos("lightningstrike", 0, _, _, _, lightningsounds[math.random(1,#lightningsounds)], 1)
	--end


end
