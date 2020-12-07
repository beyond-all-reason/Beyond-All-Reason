function gadget:GetInfo()
	return {
		name = "Map Atmosphere CEGs",
		desc = "123",
		author = "Damgam",
		date = "2020",
		layer = -100,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then

	local gar, gag, gab = gl.GetSun("ambient")
	local uar, uag, uab = gl.GetSun("ambient", "unit")
	local gdr, gdg, gdb = gl.GetSun("diffuse")
	local udr, udg, udb = gl.GetSun("diffuse", "unit")
	local gsr, gsg, gsb = gl.GetSun("specular")
	local usr, usg, usb = gl.GetSun("specular", "unit")

	local skycr, skycg, skycb = gl.GetAtmosphere("skyColor")
	local suncr, suncg, suncb = gl.GetAtmosphere("sunColor")
	local clocr, clocg, clocb = gl.GetAtmosphere("cloudColor")
	local fogcr, fogcg, fogcb = gl.GetAtmosphere("fogColor")

	local fogstartdefault = gl.GetAtmosphere("fogStart")
	local fogenddefault = gl.GetAtmosphere("fogEnd")

	local transition, transitionblue, transitionstart, transitionend

	local shadowdensity = gl.GetSun("shadowDensity")

	local function MapAtmosphereConfigSetSun(_, targetbrightness, transitionspeed, bluelevel)
		local transitionspeedpercented = transitionspeed * 0.000333
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

		Spring.SetSunLighting({ groundAmbientColor = { transition * gar, transition * gag, transitionblue * gab } })
		Spring.SetSunLighting({ unitAmbientColor = { transition * uar, transition * uag, transitionblue * uab } })
		Spring.SetSunLighting({ groundDiffuseColor = { transition * gdr, transition * gdg, transitionblue * gdb } })
		Spring.SetSunLighting({ unitDiffuseColor = { transition * udr, transition * udg, transitionblue * udb } })
		Spring.SetSunLighting({ groundSpecularColor = { transition * gsr, transition * gsg, transitionblue * gsb } })
		Spring.SetSunLighting({ unitSpecularColor = { transition * usr, transition * usg, transitionblue * usb } })

		Spring.SetAtmosphere({ skyColor = { transition * skycr, transition * skycg, transitionblue * skycb } })
		Spring.SetAtmosphere({ sunColor = { transition * suncr, transition * suncg, transitionblue * suncb } })
		Spring.SetAtmosphere({ cloudColor = { transition * clocr, transition * clocg, transitionblue * clocb } })
		Spring.SetAtmosphere({ fogColor = { transition * fogcr, transition * fogcg, transitionblue * fogcb } })

		Spring.SetSunLighting({ groundShadowDensity = transition * shadowdensity, modelShadowDensity = transition * shadowdensity })
	end

	local function MapAtmosphereConfigSetFog(_, targetstart, targetend, transitionspeedstart, transitionspeedend)
		local transitionspeedpercentedstart = transitionspeedstart * 0.000333
		local transitionspeedpercentedend = transitionspeedend * 0.000333
		if not transitionstart then
			transitionstart = fogstartdefault or 1
		end
		if not transitionend then
			transitionend = fogenddefault or 1
		end

		if transitionstart < targetstart then
			transitionstart = transitionstart + transitionspeedpercentedstart
		elseif transitionstart > targetstart then
			transitionstart = transitionstart - transitionspeedpercentedstart
		end

		if transitionend < targetend then
			transitionend = transitionend + transitionspeedpercentedend
		elseif transitionend > targetend then
			transitionend = transitionend - transitionspeedpercentedend
		end

		Spring.SetAtmosphere({ fogStart = transitionstart * fogstartdefault })
		Spring.SetAtmosphere({ fogEnd = transitionend * fogenddefault })
	end

	function gadget:TextCommand(msg)
		if string.sub(msg, 1, 18) == "atmosplaysoundfile" then
			Spring.PlaySoundFile(string.sub(msg, 20), 0.85, 'ui')
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("MapAtmosphereConfigSetSun", MapAtmosphereConfigSetSun)
		gadgetHandler:AddSyncAction("MapAtmosphereConfigSetFog", MapAtmosphereConfigSetFog)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("MapAtmosphereConfigSetSun")
		gadgetHandler:RemoveSyncAction("MapAtmosphereConfigSetFog")
	end


else
	-- SYNCED

	-- used in map configs
	mapsizeX = Game.mapSizeX
	mapsizeZ = Game.mapSizeZ

	local math_random = math.random
	local spSpawnCEG = Spring.SpawnCEG
	local spGetGroundHeight = Spring.GetGroundHeight


	function AtmosSendMessage(_, msg)
		if Script.LuaUI("GadgetAddMessage") then
			Script.LuaUI.GadgetAddMessage(msg)
		end
	end

	function AtmosSendVoiceMessage(filedirectory)
		Spring.SendCommands("atmosplaysoundfile " .. filedirectory)
	end

	function SpawnCEGInPosition(cegname, posx, posy, posz, damage, paralyzetime, damageradius, sound, soundvolume)
		spSpawnCEG(cegname, posx, posy, posz)
		if sound then
			Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
		end
		if damage or paralyzetime then
			local units = Spring.GetUnitsInCylinder(posx, posz, damageradius)
			for i = 1, #units do
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
					local paralyzemult = paralyzetime * 0.025
					if uparalyze <= umaxhealth then
						local paralyzedamage = (umaxhealth - uparalyze) + (umaxhealth * paralyzemult)
						Spring.SetUnitHealth(units[i], { paralyze = paralyzedamage })
					else
						local paralyzedamage = (umaxhealth * paralyzemult) + uparalyze
						Spring.SetUnitHealth(units[i], { paralyze = paralyzedamage })
					end
				end
			end
		end
	end

	function SpawnCEGInPositionGround(cegname, posx, groundOffset, posz, damage, paralyzetime, damageradius, sound, soundvolume)
		local posy = spGetGroundHeight(posx, posz) + (groundOffset or 0)
		spSpawnCEG(cegname, posx, posy, posz)
		if sound then
			Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
		end
		if damage or paralyzetime then
			local units = Spring.GetUnitsInCylinder(posx, posz, damageradius)
			for i = 1, #units do
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
					local paralyzemult = paralyzetime * 0.025
					if uparalyze <= umaxhealth then
						local paralyzedamage = (umaxhealth - uparalyze) + (umaxhealth * paralyzemult)
						Spring.SetUnitHealth(units[i], { paralyze = paralyzedamage })
					else
						local paralyzedamage = (umaxhealth * paralyzemult) + uparalyze
						Spring.SetUnitHealth(units[i], { paralyze = paralyzedamage })
					end
				end
			end
		end
	end

	function SpawnCEGInArea(cegname, midposx, posy, midposz, radius, damage, paralyzetime, damageradius, sound, soundvolume)
		local posx = midposx + math_random(-radius, radius)
		local posz = midposz + math_random(-radius, radius)
		spSpawnCEG(cegname, posx, posy, posz)
		if sound then
			Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
		end
		if damage or paralyzetime then
			local units = Spring.GetUnitsInCylinder(posx, posz, damageradius)
			for i = 1, #units do
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
					local paralyzemult = paralyzetime * 0.025
					if uparalyze <= umaxhealth then
						local paralyzedamage = (umaxhealth - uparalyze) + (umaxhealth * paralyzemult)
						Spring.SetUnitHealth(units[i], { paralyze = paralyzedamage })
					else
						local paralyzedamage = (umaxhealth * paralyzemult) + uparalyze
						Spring.SetUnitHealth(units[i], { paralyze = paralyzedamage })
					end
				end
			end
		end
	end

	function SpawnCEGInAreaGround(cegname, midposx, groundOffset, midposz, radius, damage, paralyzetime, damageradius, sound, soundvolume)
		local posx = midposx + math_random(-radius, radius)
		local posz = midposz + math_random(-radius, radius)
		local posy = spGetGroundHeight(posx, posz) + (groundOffset or 0)
		spSpawnCEG(cegname, posx, posy, posz)
		if sound then
			Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
		end
		if damage or paralyzetime then
			local units = Spring.GetUnitsInCylinder(posx, posz, damageradius)
			for i = 1, #units do
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
					local paralyzemult = paralyzetime * 0.025
					if uparalyze <= umaxhealth then
						local paralyzedamage = (umaxhealth - uparalyze) + (umaxhealth * paralyzemult)
						Spring.SetUnitHealth(units[i], { paralyze = paralyzedamage })
					else
						local paralyzedamage = (umaxhealth * paralyzemult) + uparalyze
						Spring.SetUnitHealth(units[i], { paralyze = paralyzedamage })
					end
				end
			end
		end
	end

	function SpawnCEGInRandomMapPos(cegname, groundOffset, damage, paralyzetime, damageradius, sound, soundvolume)
		local posx = math_random(0, mapsizeX)
		local posz = math_random(0, mapsizeZ)
		local posy = spGetGroundHeight(posx, posz) + (groundOffset or 0)
		spSpawnCEG(cegname, posx, posy, posz)
		if sound then
			Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
		end
		if damage or paralyzetime then
			local units = Spring.GetUnitsInCylinder(posx, posz, damageradius)
			for i = 1, #units do
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
					local paralyzemult = paralyzetime * 0.025
					if uparalyze <= umaxhealth then
						local paralyzedamage = (umaxhealth - uparalyze) + (umaxhealth * paralyzemult)
						Spring.SetUnitHealth(units[i], { paralyze = paralyzedamage })
					else
						local paralyzedamage = (umaxhealth * paralyzemult) + uparalyze
						Spring.SetUnitHealth(units[i], { paralyze = paralyzedamage })
					end
				end
			end
		end
	end

	function SpawnCEGInRandomMapPosBelowY(cegname, groundOffset, spawnOnlyBelowY, damage, paralyzetime, damageradius, sound, soundvolume)
		for i = 1, 100 do
			local posx = math_random(0, mapsizeX)
			local posz = math_random(0, mapsizeZ)
			local groundposy = spGetGroundHeight(posx, posz)
			local posy = spGetGroundHeight(posx, posz) + (groundOffset or 0)
			if groundposy <= spawnOnlyBelowY then
				spSpawnCEG(cegname, posx, posy, posz)
				if sound then
					Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
				end
				break
			end
		end
		if damage or paralyzetime then
			local posx = math_random(0, mapsizeX)
			local posz = math_random(0, mapsizeZ)
			local units = Spring.GetUnitsInCylinder(posx, posz, damageradius)
			for i = 1, #units do
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
					local paralyzemult = paralyzetime * 0.025
					if uparalyze <= umaxhealth then
						local paralyzedamage = (umaxhealth - uparalyze) + (umaxhealth * paralyzemult)
						Spring.SetUnitHealth(units[i], { paralyze = paralyzedamage })
					else
						local paralyzedamage = (umaxhealth * paralyzemult) + uparalyze
						Spring.SetUnitHealth(units[i], { paralyze = paralyzedamage })
					end
				end
			end
		end
	end

	function SpawnCEGInRandomMapPosPresetY(cegname, posy, damage, paralyzetime, damageradius, sound, soundvolume)
		local posx = math_random(0, mapsizeX)
		local posz = math_random(0, mapsizeZ)
		spSpawnCEG(cegname, posx, posy, posz)
		if sound then
			Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
		end
		if damage or paralyzetime then
			local units = Spring.GetUnitsInCylinder(posx, posz, damageradius)
			for i = 1, #units do
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
					local paralyzemult = paralyzetime * 0.025
					if uparalyze <= umaxhealth then
						local paralyzedamage = (umaxhealth - uparalyze) + (umaxhealth * paralyzemult)
						Spring.SetUnitHealth(units[i], { paralyze = paralyzedamage })
					else
						local paralyzedamage = (umaxhealth * paralyzemult) + uparalyze
						Spring.SetUnitHealth(units[i], { paralyze = paralyzedamage })
					end
				end
			end
		end
	end

	VFS.Include("luarules/configs/Atmosphereconfigs/" .. Game.mapName .. ".lua")
end


