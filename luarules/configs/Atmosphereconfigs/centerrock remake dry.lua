local gadget = gadget ---@type Gadget

function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

	-- DayNight Cycle

	-- if n%18000 < 9000 then
	-- 	SendToUnsynced("MapAtmosphereConfigSetSun", 1, 1, 1)
	-- else
	-- 	SendToUnsynced("MapAtmosphereConfigSetSun", 0.45, 1, 0.1)
	-- end

-- ## Atmosphere Functions
-- SpawnCEGInPosition (cegname, posx, posy, posz, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInPositionGround(cegname, posx, groundOffset, posz, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInArea(cegname, midposx, posy, midposz, radius, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInAreaGround(cegname, midposx, groundOffset, midposz, radius, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInRandomMapPos(cegname, groundOffset, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInRandomMapPosBelowY(cegname, groundOffset, spawnOnlyBelowY, damage, paralyzedamage, damageradius, sound, soundvolume)
-- SpawnCEGInRandomMapPosPresetY(cegname, posy, damage, paralyzedamage, damageradius, sound, soundvolume)

-- Use _ for damage, paralyzedamage, damageradius if you want to disable

-- common foggy canyon	
	if n%20 == 0 then
		SpawnCEGInRandomMapPosBelowY("fogdirty-brown", 16, 800)
	end

-- clouds
	if n%18000 > 500 and n%18000 < 9500 then
		if n%660 == 100 then
			SpawnCEGInRandomMapPosPresetY("mistycloud", 2100)
		end
		if n%660 == 130 then
			SpawnCEGInRandomMapPosPresetY("mistycloud", 2025)
		end
		if n%660 == 165 then
			SpawnCEGInRandomMapPosPresetY("mistycloud", 2100)
		end
		if n%660 == 225 then
			SpawnCEGInRandomMapPosPresetY("mistycloud", 2150)
		end
		if n%660 == 255 then
			SpawnCEGInRandomMapPosPresetY("mistycloud", 2150)
		end
	end

-- common foggy cliffs	
	if n%360 == 0 then
		--SpawnCEGInPositionGround("fogdirty-brown", 5437, 0, 3089)
		SpawnCEGInPositionGround("fogdirty-brown", 3400, 0, 4800)
		SpawnCEGInPositionGround("fogdirty-brown", 6594, 0, 1463)
		SpawnCEGInPositionGround("fogdirty-brown", 7414, 0, 1930)
		SpawnCEGInPositionGround("fogdirty-brown", 7224, 0, 5786)
		--SpawnCEGInPositionGround("fogdirty-brown", 3034, 0, 3736)
	end

-- rare foggy cliffs	
	if n%700 == 0 then
		SpawnCEGInPositionGround("fogdirty-brown", 2861, 0, 659)
		SpawnCEGInPositionGround("fogdirty-brown", 3687, 0, 4067)
		SpawnCEGInPositionGround("fogdirty-brown", 248, 0, 7927)
		SpawnCEGInPositionGround("fogdirty-brown", 1891, 0, 4373)
		SpawnCEGInPositionGround("fogdirty-brown", 1050, 0, 2410)
	end

-- super rare foggy cliffs	
	-- if n%1100 == 0 then
	-- 	SpawnCEGInPositionGround("fogdirty-brown", 4026, 0, 4667)
	-- 	SpawnCEGInPositionGround("fogdirty-brown", 7104, 0, 2290)
	-- end

-- powerup heavy metal
	if n%900 == 0 then
		SpawnCEGInPositionGround("powerupwhite", 3447, 0, 4172)
		SpawnCEGInPositionGround("powerupwhite", 3582, 0, 4383)
		SpawnCEGInPositionGround("powerupwhite", 5076, 0, 3385)
		SpawnCEGInPositionGround("powerupwhite", 4937, 0, 3099)
		SpawnCEGInPositionGround("powerupwhite", 7530, 0, 272)
		SpawnCEGInPositionGround("powerupwhite", 7772, 0, 276)
		SpawnCEGInPositionGround("powerupwhite", 588, 0, 7937)
		SpawnCEGInPositionGround("powerupwhite", 814, 0, 8011)
	end

-- rare sandclouds
	-- if n%1900 == 800 then
	-- 	SpawnCEGInAreaGround("sandcloud", 610, 0, 470, 200)
	-- 	SpawnCEGInAreaGround("sandcloud", 7400, 0, 7400, 200)
	-- end
		
end