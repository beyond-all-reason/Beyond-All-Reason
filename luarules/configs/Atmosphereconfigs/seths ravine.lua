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

-- SND windy locations
	if n%500 == 0 then
		SpawnCEGInRandomMapPosBelowY("noceg", 300, 75, _, _, _, "windy", 0.27)
	end

-- low middle foggy cliffs	
	if n%420 == 0 then
		-- SpawnCEGInPositionGround("fogdirty-brown", 4090, 100, 3116)
		SpawnCEGInAreaGround("fogdirty-brown", 4118, 100, 3150, 300)
	end

-- canyon middle foggy cliffs	
	if n%380 == 150 then
		SpawnCEGInPositionGround("fogdirty-brown", 3553, 0, 3428)
	end

	if n%390 == 160 then
		SpawnCEGInPositionGround("fogdirty-brown", 4551, 0, 2788)
	end

-- -- mistyclouds	
	if n%21 == 0 then
		--SpawnCEGInRandomMapPosBelowY("mistycloudbrownmistxl", 145, 50)
		SpawnCEGInRandomMapPosPresetY("mistycloudbrownmistxl", 145)
	end

local windgustsounds = {
	"windgust2",
	"windgust1",
	"windgust3",
}

-- -- rare sanddune dust
	if n%75 == 11 then
		local r = math.random(1,4)
		if r == 1 then
			SpawnCEGInAreaGround("dunecloud", 2940, 28, 2460, 750, _, _, _, windgustsounds[math.random(1,#windgustsounds)], 0.30)
			SpawnCEGInAreaGround("dunecloud", 5180, 28, 3720, 750, _, _, _, windgustsounds[math.random(1,#windgustsounds)], 0.30)
		end
	end

-- alternate rare foggy cliffs	
	-- if n%620 == 300 then
	-- 	SpawnCEGInPositionGround("fogdirty", 9585, 0, 304)
	-- 	SpawnCEGInPositionGround("fogdirty", 275, 0, 6675)
	-- 	SpawnCEGInPositionGround("fogdirty", 10163, 0, 1763)
	-- end

-- super rare foggy cliffs	
	if n%1440 == 0 then
		SpawnCEGInAreaGround("firefliespurple", 3262, 20, 2400, 75, _, _, _, "magicalhum", 0.26)
	end

	if n%1500 == 770 then
		SpawnCEGInAreaGround("firefliespurple", 4988, 20, 3809, 75, _, _, _, "magicalhum", 0.26)
	end

-- fireflies
	-- if n%1400 == 0 then
	-- 	SpawnCEGInPositionGround("firefliesgreen", 3423, 32, 5559)
	-- 	SpawnCEGInPositionGround("firefliesgreen", 7079, 32, 4449)
	-- 	SpawnCEGInPositionGround("fireflies", 9561, 32, 1072)
	-- 	SpawnCEGInPositionGround("fireflies", 223, 32, 249)
	-- end

-- pollen
	if n%150 == 0 then
		SpawnCEGInRandomMapPos("dustparticles", 50)

	end

	-- if n%1270 == 100 then
	-- 	SpawnCEGInPositionGround("noceg", 9400, 700, 800, _, _, _, "windy", 0.35)
	-- end

	-- if n%1130 == 200 then
	-- 	SpawnCEGInPositionGround("noceg", 660, 600, 6700, _, _, _, "windy", 0.35)
	-- end

	-- if n%1200 == 300 then
	-- 	SpawnCEGInPositionGround("noceg", 9700, 600, 6560, _, _, _, "windy", 0.35)
	-- end

-- SND dam hum
	-- if n%820 == 0 then
	-- 	SpawnCEGInPositionGround("noceg", 5115, 100, 4095, _, _, _, "humheavy", 0.7)
	-- end

	-- if n%840 == 120 then
	-- 	SpawnCEGInPositionGround("noceg", 5115, 100, 3078, _, _, _, "humheavy", 0.7)
	-- end

-- SND water ocean gentle
	-- if n%1330 == 0 then
	-- 	SpawnCEGInPositionGround("noceg", 6400, 100, 8500, _, _, _, "oceangentlesurf", 0.35)
	-- end

	-- if n%1230 == 300 then
	-- 	SpawnCEGInPositionGround("noceg", 3971, 100, 5586, _, _, _, "oceangentlesurf", 0.35)
	-- end

	-- if n%1160 == 35 then
	-- 	SpawnCEGInPositionGround("noceg", 5101, 300, 1455, _, _, _, "tropicalbeach", 0.5)
	-- end

-- SND hive airbursts
 --    if n%15 == 5 then
	-- 	SpawnCEGInRandomMapPosBelowY("ventairburst", 400, -50, _, _, _, "ventair", 0.45)
	-- end	
		
end