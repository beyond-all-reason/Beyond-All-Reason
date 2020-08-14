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
	local gar, gag, gab = gl.GetSun("ambient")
	local uar, uag, uab = gl.GetSun("ambient", "unit")
	local gdr, gdg, gdb = gl.GetSun("diffuse")
	local udr, udg, udb = gl.GetSun("diffuse", "unit")
	local gsr, gsg, gsb = gl.GetSun("specular")
	local usr, usg, usb = gl.GetSun("specular", "unit")
	local shadowdensity = gl.GetSun("shadowDensity")
	
	
	local function MapAtmosphereConfigSetSun(_, targetbrightness, transitionspeed, bluelevel)
		local transitionspeedpercented = transitionspeed*0.000333
		if not transition then
			transition = 1
		end
		if not transitionblue then
			transitionblue = 1
		end
		if not bluelevel then
			bluelevel = 0.40
		end
		
		if transition < targetbrightness then
			transition = transition + transitionspeedpercented
		elseif transition > targetbrightness then
			transition = transition - transitionspeedpercented
		end
		
		if transitionblue < targetbrightness then
			transitionblue = transitionblue + transitionspeedpercented
		elseif transitionblue > targetbrightness and transitionblue > bluelevel then
			transitionblue = transitionblue - transitionspeedpercented
		end
		
		if transition > 1 then
			transition = 1
		end
		if transitionblue > 1 then
			transitionblue = 1
		end
		
		-- if timeoftheday == "Day" then
			-- if transition < 1 then
				-- transition = transition + transitionspeedpercented
			-- end
			-- if transitionblue < 1 then
				-- transitionblue = transitionblue + transitionspeedpercented
			-- end
		-- elseif timeoftheday == "Night" then
			-- if transition > 0.15 then
				-- transition = transition - transitionspeedpercented
			-- end
			-- if transitionblue > 0.35 then
				-- transitionblue = transitionblue - transitionspeedpercented
			-- end
		-- end
		Spring.SetSunLighting({groundAmbientColor = {transition*gar,transition*gag,transitionblue*gab}})
		Spring.SetSunLighting({unitAmbientColor = {transition*uar,transition*uag,transitionblue*uab}})
		Spring.SetSunLighting({groundDiffuseColor = {transition*gdr,transition*gdg,transitionblue*gdb}})
		Spring.SetSunLighting({unitDiffuseColor = {transition*udr,transition*udg,transitionblue*udb}})
		Spring.SetSunLighting({groundSpecularColor = {transition*gsr,transition*gsg,transitionblue*gsb}})
		Spring.SetSunLighting({unitSpecularColor = {transition*usr,transition*usg,transitionblue*usb}})
		Spring.SetSunLighting({groundShadowDensity = transition*shadowdensity, modelShadowDensity = transition*shadowdensity})
	end
	
	function gadget:Initialize()
		gadgetHandler:AddSyncAction("MapAtmosphereConfigSetSun", MapAtmosphereConfigSetSun)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("MapAtmosphereConfigSetSun")
	end
else
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
end


