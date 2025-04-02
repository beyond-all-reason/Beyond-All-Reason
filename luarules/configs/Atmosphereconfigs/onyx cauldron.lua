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

--foggy mountains
	if n%300 == 100 then
		SpawnCEGInPositionGround("fogdirty", 5, 0, 6604)
		SpawnCEGInPositionGround("fogdirty", 25, 32, 6789)

		SpawnCEGInPositionGround("fogdirty", 5, 0, 7004)
		SpawnCEGInPositionGround("fogdirty", 25, 32, 7589)
		--
		SpawnCEGInPositionGround("fogdirty", 814, 0, 7504)
		SpawnCEGInPositionGround("fogdirty", 773, 32, 8189)

		SpawnCEGInPositionGround("fogdirty", 2214, 0, 7504)
		SpawnCEGInPositionGround("fogdirty", 2173, 32, 8189)

		SpawnCEGInPositionGround("fogdirty", 8111, 0, 887)
		SpawnCEGInPositionGround("fogdirty", 8189, 32, 773 )

		SpawnCEGInPositionGround("fogdirty", 2814, 0, 7504)
		SpawnCEGInPositionGround("fogdirty", 2773, 32, 8189)

		SpawnCEGInPositionGround("fogdirty", 8111, 0, 2887)
		SpawnCEGInPositionGround("fogdirty", 8189, 32, 2773)

		SpawnCEGInPositionGround("fogdirty", 5914, 0, 7504)
		SpawnCEGInPositionGround("fogdirty", 5873, 32, 8189)

		SpawnCEGInPositionGround("fogdirty", 8111, 0, 5187)
		SpawnCEGInPositionGround("fogdirty", 8189, 32, 5373)

		SpawnCEGInPositionGround("fogdirty", 5114, 0, 7504)
		SpawnCEGInPositionGround("fogdirty", 5273, 32, 8189)

		SpawnCEGInPositionGround("fogdirty", 7608, 0, 8111)
		SpawnCEGInPositionGround("fogdirty", 7721, 32, 8189)

		SpawnCEGInPositionGround("fogdirty", 7814, 0, 7504)
		SpawnCEGInPositionGround("fogdirty", 7773, 32, 8189)

		SpawnCEGInPositionGround("fogdirty", 8111, 0, 7887)
		SpawnCEGInPositionGround("fogdirty", 8189, 32, 7773)
		--
		SpawnCEGInPositionGround("fogdirty", 3321, 0, 87)
		SpawnCEGInPositionGround("fogdirty", 3173, 32, 73)

		SpawnCEGInPositionGround("fogdirty", 1, 0, 1887)
		SpawnCEGInPositionGround("fogdirty", 9, 32, 1973)

		SpawnCEGInPositionGround("fogdirty", 21, 0, 4587)
		SpawnCEGInPositionGround("fogdirty", 79, 32, 4873)

		SpawnCEGInPositionGround("fogdirty", 31, 0, 3587)
		SpawnCEGInPositionGround("fogdirty", 99, 32, 3673)

		SpawnCEGInRandomMapPosBelowY("fogdirty", 30, 500)
		SpawnCEGInRandomMapPosBelowY("fogdirty", 40, 500)
		SpawnCEGInRandomMapPosBelowY("fogdirty", 50, 500)
		SpawnCEGInRandomMapPosBelowY("fogdirty", 60, 500)
	end	

-- random rain
	-- if n%3400 == 1600 then
	-- 	SpawnCEGInRandomMapPosBelowY("rain", 0, 250, _, _, _, "rainlight", 1)
	-- end

end