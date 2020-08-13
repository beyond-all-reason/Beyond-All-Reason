function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. mapname)
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

-- Lightningstorm clusters
local lightningsounds = {
	"thunder1",
	"thunder2",
	"thunder3",
	"thunder4",
	"thunder5",
	"thunder6",
	}  

if n %6400 == 0 then
    local thunderstormcenterx = math.random(0, mapsizeX)
    local thunderstormcenterz = math.random(0, mapsizeZ)
    local thunderstormradius = 1000
    thunderstormxmin = thunderstormcenterx - thunderstormradius
    thunderstormxmax = thunderstormcenterx + thunderstormradius
    thunderstormzmin = thunderstormcenterz - thunderstormradius
    thunderstormzmax = thunderstormcenterz + thunderstormradius
    SpawnCEGInPositionGround("rain", thunderstormcenterx, 0, thunderstormcenterz, _, _, _, "rainlight", 1)
end

if n%6400 < 1060 then
       local r = math.random(0,100)
       if r == 0 then
            local posx = math.random(thunderstormxmin, thunderstormxmax)
            local posz = math.random(thunderstormzmin, thunderstormzmax)
            SpawnCEGInPositionGround("lightningstrikegreen", posx, 0, posz, 100, 1000, 128, lightningsounds[math.random(1,#lightningsounds)], 1)
       end
end

-- common foggy cliffs	
	if n%360 == 0 then
		SpawnCEGInPositionGround("fogdirty-green", 1490, 32, 4271)
		SpawnCEGInPositionGround("fogdirty-green", 5545, 32, 3359)
		SpawnCEGInPositionGround("fogdirty-green", 3365, 32, 3438)
		SpawnCEGInPositionGround("fogdirty-green", 5261, 32, 2582)
		SpawnCEGInPositionGround("fogdirty-green", 4039, 32, 4245)
		SpawnCEGInPositionGround("fogdirty-green", 5626, 32, 4687)
		SpawnCEGInPositionGround("fogdirty-green", 2913, 32, 5769)
		SpawnCEGInPositionGround("fogdirty-green", 360, 32, 2558)
	end

-- rare foggy cliffs	
	if n%700 == 0 then
		SpawnCEGInPositionGround("fogdirty-green", 624, 32, 565)
		SpawnCEGInPositionGround("fogdirty-green", 7201, 32, 5743)
	end

-- common fireflies
	if n%1000 == 0 then
		SpawnCEGInPositionGround("fireflies", 774, 32, 4289)
		SpawnCEGInPositionGround("fireflies", 7299, 32, 3964)
		SpawnCEGInPositionGround("fireflies", 2933, 32, 4136)
	end

-- rare fireflies
	if n%2200 == 0 then
		SpawnCEGInPositionGround("fireflies", 3362, 32, 3494)
		SpawnCEGInPositionGround("fireflies", 943, 32, 3381)
	end

-- random rain
	if n%3200 == 1600 then
		SpawnCEGInRandomMapPos("rain", 0, _, _, _, "rainlight", 1)
	end

-- random lightning
	if n%7000 == 600 then
		SpawnCEGInRandomMapPos("lightningstormgreen", 0, _, _, _, "distantthunder", 0.85)
	end
	
-- lightningstorms
  

	if n%6400 == 4900 then
		SpawnCEGInRandomMapPos("lightningstrikegreen", 0, 100, 1000, 128, lightningsounds[math.random(1,#lightningsounds)], 1)
	end
	if n%6400 == 4625 then
		SpawnCEGInRandomMapPos("lightningstrikegreen", 0, 100, 1000, 128, lightningsounds[math.random(1,#lightningsounds)], 1)
	end
	if n%6400 == 5150 then
		SpawnCEGInRandomMapPos("lightningstrikegreen", 0, 100, 1000, 128, lightningsounds[math.random(1,#lightningsounds)], 1)
	end
	if n%6400 == 5210 then
		SpawnCEGInRandomMapPos("lightningstrikegreen", 0, 100, 1000, 128, lightningsounds[math.random(1,#lightningsounds)], 1)
	end
	if n%6400 == 5610 then
		SpawnCEGInRandomMapPos("lightningstrikegreen", 0, 100, 1000, 128, lightningsounds[math.random(1,#lightningsounds)], 1)
	end
	
end