local gadget = gadget ---@type Gadget

function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

-- ## Atmosphere Functions
-- SendToUnsynced("MapAtmosphereConfigSetSun", red&green, transitionspeed, blue)
-- SendToUnsynced("MapAtmosphereConfigSetFog", targetfogstart, targetfogend, transitionspeedfogstart, transitionspeedfogend)

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
		SpawnCEGInPositionGround("fogdirty-green", 1900, 32, 1257)
		SpawnCEGInPositionGround("fogdirty-green", 757, 32, 1554)		
		SpawnCEGInPositionGround("fogdirty-green", 4608, 32, 1413)
		SpawnCEGInPositionGround("fogdirty-green", 5459, 32, 1650)
		SpawnCEGInPositionGround("fogdirty-green", 4536, 32, 4716)
		SpawnCEGInPositionGround("fogdirty-green", 4730, 32, 5542)
		SpawnCEGInPositionGround("fogdirty-green", 1757, 32, 4540)
		SpawnCEGInPositionGround("fogdirty-green", 1295, 32, 5537)
	end

	if n%360 == 180 then
		SpawnCEGInPositionGround("fogdirty-green", 1382, 32, 1824)
		SpawnCEGInPositionGround("fogdirty-green", 4582, 32, 1805)
		SpawnCEGInPositionGround("fogdirty-green", 5704, 32, 4257)
		SpawnCEGInPositionGround("fogdirty-green", 478, 32, 4262)
	end

-- rare foggy cliffs	
	if n%700 == 0 then
		SpawnCEGInPositionGround("fogdirty-green", 3038, 32, 3031)
		SpawnCEGInPositionGround("fogdirty-green", 1487, 32, 3747)
		SpawnCEGInPositionGround("fogdirty-green", 3575, 32, 4326)
		SpawnCEGInPositionGround("fogdirty-green", 3015, 32, 1447)
		SpawnCEGInPositionGround("fogdirty-green", 798, 32, 2852)
		SpawnCEGInPositionGround("fogdirty-green", 4634, 32, 2453)
		SpawnCEGInPositionGround("fogdirty-green", 2983, 32, 5636)
		SpawnCEGInPositionGround("fogdirty-green", 3433, 32, 3686)
	end

-- common fireflies
	if n%1800 == 0 then
		SpawnCEGInPositionGround("firefliesgreen", 2259, 0, 3987)
		SpawnCEGInPositionGround("firefliesgreen", 5599, 0, 4069)
		SpawnCEGInPositionGround("firefliesgreen", 588, 0, 3758)
	end

-- rare rain
	if n%6800 == 5000 then
		SpawnCEGInRandomMapPos("rainlight-acid", 0, 15, _, 750, "rainlight", 0.5)
	end

	if n%6800 == 4300 then
		SpawnCEGInRandomMapPos("rainlight-acid", 0, 15, _, 750, "rainlight", 0.5)
	end

	if n%500 == 10 then
		SpawnCEGInRandomMapPos("rainverylight-acid", 0, 15, _, 750, "rainlight", 0.5)
	end

-- -- random rain
-- 	if n%3200 == 1600 then
-- 		SpawnCEGInRandomMapPos("rain", 0, _, _, _, "rainlight", 1)
-- 	end

-- -- random lightning
-- 	if n%7000 == 600 then
-- 		SpawnCEGInRandomMapPos("lightningstormgreen", 0, _, _, _, "distantthunder", 0.85)
-- 	end
	
	
end