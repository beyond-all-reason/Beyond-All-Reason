local gadget = gadget ---@type Gadget

function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

	-- if n%25600 < 12800 then
	-- 	SendToUnsynced("MapAtmosphereConfigSetSun", 1, 2, 1)
	-- else
	-- 	SendToUnsynced("MapAtmosphereConfigSetSun", 0.1, 2, 0.2)
	-- end

local lightningsounds = {
	"thunder1",
	"thunder2",
	"thunder3",
	"thunder4",
	"thunder5",
	"thunder6",
	}  

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
	-- if n%20 == 0 then
	-- 	SpawnCEGInRandomMapPosBelowY("fogdirty-brown-brown", 16, 100)
	-- end

-- clouds
	if n%630 == 100 then
		SpawnCEGInRandomMapPosPresetY("mistycloud", 2100)
	end
	if n%630 == 130 then
		SpawnCEGInRandomMapPosPresetY("mistycloud", 2025)
	end
	if n%630 == 165 then
		SpawnCEGInRandomMapPosPresetY("mistycloud", 2100)
	end
	if n%630 == 225 then
		SpawnCEGInRandomMapPosPresetY("mistycloud", 2150)
	end
	if n%630 == 255 then
		SpawnCEGInRandomMapPosPresetY("mistycloud", 2150)
	end
	if n%1260 == 325 then
		SpawnCEGInRandomMapPosPresetY("thickcloud", 2650)
	end

-- common foggy cliffs	
	if n%360 == 0 then
		--SpawnCEGInPosition("fogdirty-brown", 5437, 212, 3089)
		SpawnCEGInPosition("fogdirty", 3658, 179, 4861)
		SpawnCEGInPosition("fogdirty-brown", 6594, 93, 1463)
		SpawnCEGInPosition("fogdirty-brown", 7414, 317, 1930)
		SpawnCEGInPosition("fogdirty-brown", 7224, 384, 5786)
		--SpawnCEGInPosition("fogdirty-brown", 3034, 32, 3736)
	end

-- rare foggy cliffs	
	if n%700 == 0 then
		SpawnCEGInPosition("fogdirty-brown", 2861, 407, 659)
		SpawnCEGInPosition("fogdirty-brown", 3687, 383, 4067)
		SpawnCEGInPosition("fogdirty-brown", 248, 150, 7927)
		SpawnCEGInPosition("fogdirty-brown", 1891, 255, 4373)
		SpawnCEGInPosition("fogdirty-brown", 1050, 450, 2410)
	end

-- super rare foggy cliffs	
	--if n%1100 == 0 then
	--	SpawnCEGInPosition("fogdirty-brown", 4026, 672, 4667)
	--	SpawnCEGInPosition("fogdirty-brown", 7104, 569, 2290)
	--end

-- powerup heavy metal
	if n%900 == 0 then
		SpawnCEGInPosition("powerupwhite", 3447, 525, 4172)
		SpawnCEGInPosition("powerupwhite", 3582, 496, 4383)
		SpawnCEGInPosition("powerupwhite", 5076, 523, 3385)
		SpawnCEGInPosition("powerupwhite", 4937, 513, 3099)
		SpawnCEGInPosition("powerupwhite", 7530, 210, 272)
		SpawnCEGInPosition("powerupwhite", 7772, 206, 276)
		SpawnCEGInPosition("powerupwhite", 588, 156, 7937)
		SpawnCEGInPosition("powerupwhite", 814, 144, 8011)
	end

-- light rain
	if n%6400 == 5370 then
		SpawnCEGInRandomMapPos("rainlight", 0, _, _, _, "rainlight", 0.5)
	end

-- Thunderstorm Darkness Cycle

	if n%6400 < 4800 then
		SendToUnsynced("MapAtmosphereConfigSetSun", 1, 2, 1, 1, 1)
	else
		SendToUnsynced("MapAtmosphereConfigSetSun", 0.5, 3, 0.5, 0.5, 0.5)
	end

	if n %6400 == 5400 then
	    local thunderstormcenterx = math.random(100, (mapsizeX-100))
	    local thunderstormcenterz = math.random(100, (mapsizeZ-100))
	    local thunderstormradius = 675
	    thunderstormxmin = thunderstormcenterx - thunderstormradius
	    thunderstormxmax = thunderstormcenterx + thunderstormradius
	    thunderstormzmin = thunderstormcenterz - thunderstormradius
	    thunderstormzmax = thunderstormcenterz + thunderstormradius
	    SpawnCEGInPositionGround("rainlight", thunderstormcenterx, 0, thunderstormcenterz, _, _, _, "rainlight", 0.7)
	    SpawnCEGInPosition("noceg", thunderstormcenterx, 1000, thunderstormcenterz, _, _, _, "distantthunder", 0.4)
	end

	if n%6400 > 5400 then
		if n%30 == 0 then
	       local r = math.random(0,4)
	       if r == 0 then
	            local posx = math.random(thunderstormxmin, thunderstormxmax)
	            local posz = math.random(thunderstormzmin, thunderstormzmax)
	            SpawnCEGInPositionGround("lightningstrike", posx, 0, posz, _, _, _, lightningsounds[math.random(1,#lightningsounds)], 1)
	       end
	    end 
	end



-- rare sandclouds
	-- if n%1900 == 800 then
	-- 	SpawnCEGInAreaGround("sandcloud", 610, 0, 470, 200)
	-- 	SpawnCEGInAreaGround("sandcloud", 7400, 0, 7400, 200)
	-- end
		
end