local gadget = gadget ---@type Gadget

function gadget:GameFrame(n)
	if n == 31 then
		Spring.Echo("Loaded atmosphere CEGs config for map: " .. Game.mapName)
	end

	-- DayNight Cycle

	if n%10000 < 6600 then
		SendToUnsynced("MapAtmosphereConfigSetSun", 1, 0.5, 1)
	else
		SendToUnsynced("MapAtmosphereConfigSetSun", 0.75, 0.5, 0.75)
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

-- SND hive airbursts
    if n%860 == 450 then
		SpawnCEGInAreaGround("ventairburst", 1814, 0, 5628, 75, _, _, _, "ventair", 0.45)
	end	

	if n%880 == 100 then
		SpawnCEGInAreaGround("ventairburst", 3229, 0, 6260, 60, _, _, _, "ventair", 0.46)
	end	

	if n%900 == 690 then
		SpawnCEGInAreaGround("ventairburst", 2327, 0, 2510, 80, _, _, _, "ventair", 0.47)
	end	

	if n%890 == 785 then
		SpawnCEGInAreaGround("ventairburst", 4083, 0, 6433, 100, _, _, _, "ventair", 0.46)
	end

	if n%870 == 235 then
		SpawnCEGInAreaGround("ventairburst", 4176, 0, 2049, 225, _, _, _, "ventair", 0.45)
	end	

	if n%1010 == 500 then
		SpawnCEGInAreaGround("ventairburst", 5786, 0, 5602, 75, _, _, _, "ventair", 0.46)
	end	

	if n%820 == 810 then
		SpawnCEGInAreaGround("ventairburst", 5869, 0, 6072, 125, _, _, _, "ventair", 0.47)
	end		

-- SND windy locations
	if n%1160 == 0 then
		--SpawnCEGInPositionGround("noceg", 3500, 700, 800, _, _, _, "windy_mountains", 0.35)
		SpawnCEGInRandomMapPosBelowY("noceg", 400, 300, _, _, _, "windy_mountains", 0.50)
	end

	if n%1270 == 300 then
		--SpawnCEGInPositionGround("noceg", 2500, 700, 6800, _, _, _, "windy_mountains", 0.35)
		SpawnCEGInRandomMapPosBelowY("noceg", 400, 300, _, _, _, "windy_mountains", 0.49)
	end

	if n%1130 == 600 then
		SpawnCEGInRandomMapPosBelowY("noceg", 400, 400, _, _, _, "windy_mountains", 0.50)
	end

	-- if n%1200 == 300 then
	-- 	SpawnCEGInPositionGround("noceg", 9700, 600, 6560, _, _, _, "windy", 0.35)
	-- end

-- distant thunder

if n%2000 == 0 then
		SpawnCEGInRandomMapPosBelowY("noceg", 800, 400, _, _, _, "distantthunder", 0.62)
	end

-- fireflies	
	if n%200 == 0 then
		SpawnCEGInRandomMapPosBelowY("firefliespurple", 32, 200)
	end

	if n%275 == 0 then
		SpawnCEGInRandomMapPosBelowY("firefliespurple", 32, 150)
	end

	if n%320 == 0 then
		SpawnCEGInRandomMapPosBelowY("firefliespurple", 32, 130)
	end

-- rare foggy cliffs	
	if n%750 == 0 then
		SpawnCEGInPositionGround("mistycloudpurplemist", 4120, 64, 6410)
	end

	if n%800 == 450 then
		SpawnCEGInPositionGround("mistycloudpurplemist", 4168, 64, 2204)
	end

	if n%800 == 650 then
		SpawnCEGInPositionGround("mistycloudpurplemist", 5816, 64, 5584)
	end

	if n%800 == 750 then
		SpawnCEGInPositionGround("mistycloudpurplemistxl", 7695, 64, 4840)
	end

-- super rare large foggy cliffs

	if n%1700 == 1000 then
		SpawnCEGInPositionGround("mistycloudpurplemistxl", 7289, 10, 963)
	end

	if n%1800 == 300 then
		SpawnCEGInPositionGround("mistycloudpurplemistxl", 673, 10, 815)
	end

	if n%1800 == 1500 then
		SpawnCEGInPositionGround("mistycloudpurplemistxl", 1599, 10, 4985)
	end
		
end