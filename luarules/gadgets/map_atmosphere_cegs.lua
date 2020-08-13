mapname = Game.mapName
mapsizeX = Game.mapSizeX
mapsizeZ = Game.mapSizeZ
spSCEG = Spring.SpawnCEG
mathrandom = math.random
spGroundHeight = Spring.GetGroundHeight


function gadget:GetInfo()
    return {
      name      = "Map Atmosphere CEGs",
      desc      = "123",
      author    = "Damgam",
      date      = "2020",
      layer     = -100,
      enabled   = true,
    }
end

if (not gadgetHandler:IsSyncedCode()) then
	return false
end

function SpawnCEGInPosition(cegname, posx, posy, posz, damage, paralyzetime, damageradius, sound, soundvolume)
	spSCEG(cegname, posx, posy, posz)
	if sound then
		Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
	end
	if damage or paralyzetime then
		local units = Spring.GetUnitsInCylinder(posx, posz, damageradius)
		for i = 1,#units do
			local uhealth, umaxhealth, uparalyze = Spring.GetUnitHealth(units[i])
			if damage then
				--Spring.Echo("Damaged")
				if uhealth > damage then
					Spring.SetUnitHealth(units[i], uhealth - damage)
				else
					Spring.DestroyUnit(units[i])
				end
			end
			if paralyzetime then
				--Spring.Echo("Paralyzed")
				local paralyzemult = paralyzetime*0.025
				if uparalyze <= umaxhealth then
					local paralyzedamage = (umaxhealth-uparalyze)+(umaxhealth*paralyzemult)
					Spring.SetUnitHealth(units[i], {paralyze = paralyzedamage})
				else
					local paralyzedamage = (umaxhealth*paralyzemult)+uparalyze
					Spring.SetUnitHealth(units[i], {paralyze = paralyzedamage})
				end
			end
		end
	end	
end

function SpawnCEGInPositionGround(cegname, posx, groundOffset, posz, damage, paralyzetime, damageradius, sound, soundvolume)
	local posy = spGroundHeight(posx, posz) + (groundOffset or 0)
	spSCEG(cegname, posx, posy, posz)
	if sound then
		Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
	end
	if damage or paralyzetime then
		local units = Spring.GetUnitsInCylinder(posx, posz, damageradius)
		for i = 1,#units do
			local uhealth, umaxhealth, uparalyze = Spring.GetUnitHealth(units[i])
			if damage then
				--Spring.Echo("Damaged")
				if uhealth > damage then
					Spring.SetUnitHealth(units[i], uhealth - damage)
				else
					Spring.DestroyUnit(units[i])
				end
			end
			if paralyzetime then
				--Spring.Echo("Paralyzed")
				local paralyzemult = paralyzetime*0.025
				if uparalyze <= umaxhealth then
					local paralyzedamage = (umaxhealth-uparalyze)+(umaxhealth*paralyzemult)
					Spring.SetUnitHealth(units[i], {paralyze = paralyzedamage})
				else
					local paralyzedamage = (umaxhealth*paralyzemult)+uparalyze
					Spring.SetUnitHealth(units[i], {paralyze = paralyzedamage})
				end
			end
		end
	end	
end

function SpawnCEGInArea(cegname, midposx, posy, midposz, radius, damage, paralyzetime, damageradius, sound, soundvolume)
	local posx = midposx+mathrandom(-radius,radius)
	local posz = midposz+mathrandom(-radius,radius)
	spSCEG(cegname, posx, posy, posz)
	if sound then
		Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
	end
	if damage or paralyzetime then
		local units = Spring.GetUnitsInCylinder(posx, posz, damageradius)
		for i = 1,#units do
			local uhealth, umaxhealth, uparalyze = Spring.GetUnitHealth(units[i])
			if damage then
				--Spring.Echo("Damaged")
				if uhealth > damage then
					Spring.SetUnitHealth(units[i], uhealth - damage)
				else
					Spring.DestroyUnit(units[i])
				end
			end
			if paralyzetime then
				--Spring.Echo("Paralyzed")
				local paralyzemult = paralyzetime*0.025
				if uparalyze <= umaxhealth then
					local paralyzedamage = (umaxhealth-uparalyze)+(umaxhealth*paralyzemult)
					Spring.SetUnitHealth(units[i], {paralyze = paralyzedamage})
				else
					local paralyzedamage = (umaxhealth*paralyzemult)+uparalyze
					Spring.SetUnitHealth(units[i], {paralyze = paralyzedamage})
				end
			end
		end
	end	
end

function SpawnCEGInAreaGround(cegname, midposx, groundOffset, midposz, radius, damage, paralyzetime, damageradius, sound, soundvolume)
	local posx = midposx+mathrandom(-radius,radius)
	local posz = midposz+mathrandom(-radius,radius)
	local posy = spGroundHeight(posx, posz) + (groundOffset or 0)
	spSCEG(cegname, posx, posy, posz)
	if sound then
		Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
	end
	if damage or paralyzetime then
		local units = Spring.GetUnitsInCylinder(posx, posz, damageradius)
		for i = 1,#units do
			local uhealth, umaxhealth, uparalyze = Spring.GetUnitHealth(units[i])
			if damage then
				--Spring.Echo("Damaged")
				if uhealth > damage then
					Spring.SetUnitHealth(units[i], uhealth - damage)
				else
					Spring.DestroyUnit(units[i])
				end
			end
			if paralyzetime then
				--Spring.Echo("Paralyzed")
				local paralyzemult = paralyzetime*0.025
				if uparalyze <= umaxhealth then
					local paralyzedamage = (umaxhealth-uparalyze)+(umaxhealth*paralyzemult)
					Spring.SetUnitHealth(units[i], {paralyze = paralyzedamage})
				else
					local paralyzedamage = (umaxhealth*paralyzemult)+uparalyze
					Spring.SetUnitHealth(units[i], {paralyze = paralyzedamage})
				end
			end
		end
	end	
end

function SpawnCEGInRandomMapPos(cegname, groundOffset, damage, paralyzetime, damageradius, sound, soundvolume)
	local posx = mathrandom(0,mapsizeX)
	local posz = mathrandom(0,mapsizeZ)
	local posy = spGroundHeight(posx, posz) + (groundOffset or 0)
	spSCEG(cegname, posx, posy, posz)
	if sound then
		Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
	end
	if damage or paralyzetime then
		local units = Spring.GetUnitsInCylinder(posx, posz, damageradius)
		for i = 1,#units do
			local uhealth, umaxhealth, uparalyze = Spring.GetUnitHealth(units[i])
			if damage then
				--Spring.Echo("Damaged")
				if uhealth > damage then
					Spring.SetUnitHealth(units[i], uhealth - damage)
				else
					Spring.DestroyUnit(units[i])
				end
			end
			if paralyzetime then
				--Spring.Echo("Paralyzed")
				local paralyzemult = paralyzetime*0.025
				if uparalyze <= umaxhealth then
					local paralyzedamage = (umaxhealth-uparalyze)+(umaxhealth*paralyzemult)
					Spring.SetUnitHealth(units[i], {paralyze = paralyzedamage})
				else
					local paralyzedamage = (umaxhealth*paralyzemult)+uparalyze
					Spring.SetUnitHealth(units[i], {paralyze = paralyzedamage})
				end
			end
		end
	end	
end

function SpawnCEGInRandomMapPosBelowY(cegname, groundOffset, spawnOnlyBelowY, damage, paralyzetime, damageradius, sound, soundvolume)
	for i = 1,100 do
		local posx = mathrandom(0,mapsizeX)
		local posz = mathrandom(0,mapsizeZ)
		local groundposy = spGroundHeight(posx, posz)
		local posy = spGroundHeight(posx, posz) + (groundOffset or 0)
		if groundposy <= spawnOnlyBelowY then
			spSCEG(cegname, posx, posy, posz)
			if sound then
				Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
			end
			break
		end
	end
	if damage or paralyzetime then
		local units = Spring.GetUnitsInCylinder(posx, posz, damageradius)
		for i = 1,#units do
			local uhealth, umaxhealth, uparalyze = Spring.GetUnitHealth(units[i])
			if damage then
				--Spring.Echo("Damaged")
				if uhealth > damage then
					Spring.SetUnitHealth(units[i], uhealth - damage)
				else
					Spring.DestroyUnit(units[i])
				end
			end
			if paralyzetime then
				--Spring.Echo("Paralyzed")
				local paralyzemult = paralyzetime*0.025
				if uparalyze <= umaxhealth then
					local paralyzedamage = (umaxhealth-uparalyze)+(umaxhealth*paralyzemult)
					Spring.SetUnitHealth(units[i], {paralyze = paralyzedamage})
				else
					local paralyzedamage = (umaxhealth*paralyzemult)+uparalyze
					Spring.SetUnitHealth(units[i], {paralyze = paralyzedamage})
				end
			end
		end
	end	
end

function SpawnCEGInRandomMapPosPresetY(cegname, posy, damage, paralyzetime, damageradius, sound, soundvolume)
	local posx = mathrandom(0,mapsizeX)
	local posz = mathrandom(0,mapsizeZ)
	spSCEG(cegname, posx, posy, posz)
	if sound then
		Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
	end
	if damage or paralyzetime then
		local units = Spring.GetUnitsInCylinder(posx, posz, damageradius)
		for i = 1,#units do
			local uhealth, umaxhealth, uparalyze = Spring.GetUnitHealth(units[i])
			if damage then
				--Spring.Echo("Damaged")
				if uhealth > damage then
					Spring.SetUnitHealth(units[i], uhealth - damage)
				else
					Spring.DestroyUnit(units[i])
				end
			end
			if paralyzetime then
				--Spring.Echo("Paralyzed")
				local paralyzemult = paralyzetime*0.025
				if uparalyze <= umaxhealth then
					local paralyzedamage = (umaxhealth-uparalyze)+(umaxhealth*paralyzemult)
					Spring.SetUnitHealth(units[i], {paralyze = paralyzedamage})
				else
					local paralyzedamage = (umaxhealth*paralyzemult)+uparalyze
					Spring.SetUnitHealth(units[i], {paralyze = paralyzedamage})
				end
			end
		end
	end	
end

VFS.Include("luarules/configs/Atmosphereconfigs/" .. mapname .. ".lua")



