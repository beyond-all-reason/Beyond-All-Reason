
if not Spring.GetModOptions().map_atmosphere then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Map Atmosphere CEGs",
		desc = "123",
		author = "Damgam",
		date = "2020",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = true,
	}
end

local enableGenericConfig = Spring.GetModOptions().mapatmospherics or "enabled"

--if VFS.FileExists("luarules/configs/Atmosphereconfigs/" .. Game.mapName .. ".lua") then
--elseif enableGenericConfig ~= "disabled" then
--end

local currentMapname = Game.mapName:lower()
local mapList = VFS.DirList("luarules/configs/Atmosphereconfigs/", "*.lua")

Spring.Echo("[ATMOSPHERIC] Current map: "..currentMapname)
local mapFileName = ''	-- (Include at bottom of this file)
for i = 1,#mapList+1 do
	if i == #mapList+1 then
		Spring.Echo("[ATMOSPHERIC] No map config found. Turning off the gadget")
		return
	end
	mapFileName = string.sub(mapList[i], 36, string.len(mapList[i])-4):lower()
	if string.find(currentMapname, mapFileName) then
		Spring.Echo("[ATMOSPHERIC] Success! Map names match!: " ..mapFileName)
		break
	else
		--Spring.Echo("[ATMOSPHERIC] Map names don't match: " ..mapFileName)
	end
end


if not gadgetHandler:IsSyncedCode() then

	--[[
			Spring.SetSunLighting({ groundAmbientColor = { transitionred * gar, transitiongreen * gag, transitionblue * gab } })
		Spring.SetSunLighting({ unitAmbientColor = { transitionred * uar, transitiongreen * uag, transitionblue * uab } })
		Spring.SetSunLighting({ groundDiffuseColor = { transitionred * gdr, transitiongreen * gdg, transitionblue * gdb } })
		Spring.SetSunLighting({ unitDiffuseColor = { transitionred * udr, transitiongreen * udg, transitionblue * udb } })
		Spring.SetSunLighting({ groundSpecularColor = { transitionred * gsr, transitiongreen * gsg, transitionblue * gsb } })
		Spring.SetSunLighting({ unitSpecularColor = { transitionred * usr, transitiongreen * usg, transitionblue * usb } })

		Spring.SetAtmosphere({ skyColor = { transitionred * skycr, transitiongreen * skycg, transitionblue * skycb } })
		Spring.SetAtmosphere({ sunColor = { transitionred * suncr, transitiongreen * suncg, transitionblue * suncb } })
		Spring.SetAtmosphere({ cloudColor = { transitionred * clocr, transitiongreen * clocg, transitionblue * clocb } })
		Spring.SetAtmosphere({ fogColor = { transitionred * fogcr, transitiongreen * fogcg, transitionblue * fogcb } })

		Spring.SetSunLighting({ groundShadowDensity = transition * shadowdensity, modelShadowDensity = transition * shadowdensity })
	]]--


	local function GetLightingAndAtmosphere()  -- returns a table of the common parameters
		local res =  {
			lighting = {
				groundAmbientColor =  {gl.GetSun("ambient")},
				groundDiffuseColor =  {gl.GetSun("diffuse")},
				groundSpecularColor =  {gl.GetSun("specular")},

				unitAmbientColor =  {gl.GetSun("ambient","unit")},
				unitDiffuseColor =  {gl.GetSun("diffuse","unit")},
				unitSpecularColor =  {gl.GetSun("specular","unit")},

				groundShadowDensity = gl.GetSun("shadowDensity"),
				modelShadowDensity = gl.GetSun("shadowDensity","unit"),
			},
			atmosphere = {
				skyColor = {gl.GetAtmosphere("skyColor")},
				sunColor = {gl.GetAtmosphere("sunColor")},
				cloudColor = {gl.GetAtmosphere("cloudColor")},
				fogColor = {gl.GetAtmosphere("fogColor")},
				fogColor = {gl.GetAtmosphere("fogColor")},
				fogStart = gl.GetAtmosphere("fogStart"),
				fogEnd = gl.GetAtmosphere("fogEnd"),
			},
			sunDir = {gl.GetSun("pos")},
		}

		return res
	end

	local function SetLightingAndAtmosphere(lightandatmos)
		if lightandatmos.atmosphere then Spring.SetAtmosphere(lightandatmos.atmosphere) end
		if lightandatmos.lighting then Spring.SetSunLighting(lightandatmos.lighting) end
		if lightandatmos.sunDir then Spring.SetSunDirection(lightandatmos.sunDir[1], lightandatmos.sunDir[2], lightandatmos.sunDir[3] ) end
	end

	local atmosphere_lighting = {"atmosphere","lighting"}
	local atan2 = math.atan2
	local diag = math.diag
	local mix = math.mix
	local sin = math.sin
	local cos = math.cos
	-- Mix everything specified in A into B, if not specified in B, then replace with A
	local function MixLightingAndAtmosphere(a, b, mixfactor, target)
		if target == nil then target = b end
		for _,k in ipairs(atmosphere_lighting) do
			if a[k] and b[k] then
				local aa = a[k]
				local bb = b[k]
				for ka, va in pairs(aa) do
					if bb[ka] == nil then target[ka] = aa[ka]
					else
						if type(va) == 'table' then
							for i=1,#va do
								--Spring.Echo(k, ka, i, aa[ka][i],bb[ka][i], mixfactor )
								target[k][ka][i] = mix(aa[ka][i], bb[ka][i], mixfactor)
							end
						else
							target[k][ka] = mix(aa[ka], bb[ka], mixfactor)
						end
					end
				end
			end
		end
		if a['sunDir'] and b['sunDir'] then
			local asun = a['sunDir']
			local bsun = b['sunDir']
			local alength = 1.0 / diag(asun[1], asun[2], asun[3])
			local blength = 1.0 / diag(bsun[1], bsun[2], bsun[3])

			local aworldrot = atan2(asun[1]*alength, asun[3]*alength) --https://en.wikipedia.org/wiki/Atan2
			local bworldrot = atan2(bsun[1]*blength, bsun[3]*blength)

			--Spring.Echo(("Arot = %.2f, Brot = %.2f"):format(aworldrot, bworldrot))

			-- if close to 180 degrees, then rotate clockwise
			if (aworldrot - bworldrot) > math.pi - 0.1 then
				bworldrot = bworldrot + 2 * math.pi
			end

			if (bworldrot - aworldrot) > math.pi - 0.1 then
				bworldrot = bworldrot - 2 * math.pi
			end

			local aheight =   atan2(asun[2]*alength, diag(asun[1]*alength, asun[3]*alength))
			local bheight =   atan2(bsun[2]*blength, diag(bsun[1]*blength, bsun[3]*blength))

			local targetrot = mix(aworldrot, bworldrot, mixfactor)
			local targetheight = mix(aheight, bheight, mixfactor)

			if target['sunDir'] == nil then target['sunDir'] = {0,1,0} end
			target['sunDir'][1] = sin(targetrot) * cos(targetheight)
			target['sunDir'][2] = sin(targetheight)
			target['sunDir'][3] = cos(targetrot) * cos(targetheight)
			--Spring.Echo("sunDir", mixfactor, "targetrot",targetrot, "targetheight", targetheight, aworldrot ,  bworldrot)

		end
	end

	local initial_atmosphere_lighting = GetLightingAndAtmosphere()

	local initlight
	local endlight
	local mixedlight

	function gadget:GameFrame(n)
		if true then return end
		if initlight == nil then
			--Spring.Echo("Loaded Sun Conf for: " .. Game.mapName)
			initlight = GetLightingAndAtmosphere()
			endlight = GetLightingAndAtmosphere()
			mixedlight = GetLightingAndAtmosphere()
			endlight.sunDir[1] = -1 * endlight.sunDir[1]
			--endlight.sunDir[2] = 0.3 * endlight.sunDir[2]
			endlight.sunDir[3] = -1 * endlight.sunDir[3]
			local nightfactor = {0.3, 0.3, 0.45, 1.0}
			for _,k in ipairs(atmosphere_lighting) do
				for k2, v2 in pairs(endlight[k]) do
					if string.find(k2, "Color", nil, true) then
						for i =1, #v2 do
							endlight[k][k2][i] = endlight[k][k2][i] * nightfactor[i]
						end
					end
				end
			end
		end
		local dt = 300
		local tstart = 60

		if n > tstart then
			local tfloor = math.floor((n-tstart)/dt)
			local mixfac = ((n-tstart) % dt) / dt
			--mixfac = math.smoothstep(0,1,mixfac);
			--Spring.Echo(n,mixfac)
			if tfloor % 2 ==0 then
				MixLightingAndAtmosphere(initlight, endlight, mixfac, mixedlight)
			else
				MixLightingAndAtmosphere(endlight, initlight, mixfac, mixedlight)
			end
			SetLightingAndAtmosphere(mixedlight)
		end

	end

	local gar, gag, gab = gl.GetSun("ambient")
	local uar, uag, uab = gl.GetSun("ambient", "unit")
	local gdr, gdg, gdb = gl.GetSun("diffuse")
	local udr, udg, udb = gl.GetSun("diffuse", "unit")
	local gsr, gsg, gsb = gl.GetSun("specular")
	local usr, usg, usb = gl.GetSun("specular", "unit")

	local sundirx, sundiry, sundirz = gl.GetSun("pos")

	local skycr, skycg, skycb = gl.GetAtmosphere("skyColor")
	local suncr, suncg, suncb = gl.GetAtmosphere("sunColor")
	local clocr, clocg, clocb = gl.GetAtmosphere("cloudColor")
	local fogcr, fogcg, fogcb = gl.GetAtmosphere("fogColor")

	local fogstartdefault = gl.GetAtmosphere("fogStart")
	local fogenddefault = gl.GetAtmosphere("fogEnd")

	local transition, transitionblue, transitionstart, transitionend

	local shadowdensity = gl.GetSun("shadowDensity")
	local modelShadowDensity = gl.GetSun("shadowDensity")

	local function MapAtmosphereConfigSetSun(_, targetbrightness, transitionspeed, redlevel, greenlevel, bluelevel, sundir)
		--Spring.Echo("MapAtmosphereConfigSetSun", targetbrightness, transitionspeed, redlevel, greenlevel, bluelevel, sundir)
		local transitionspeedpercented = transitionspeed * 0.000333
		if not transition then
			transition = 1
		end
		if not transitionblue then
			transitionblue = 1
		end
		if not transitiongreen then
			transitiongreen = 1
		end
		if not transitionred then
			transitionred = 1
		end
		if not bluelevel then
			bluelevel = targetbrightness
		end
		if not greenlevel then
			greenlevel = targetbrightness
		end
		if not redlevel then
			redlevel = targetbrightness
		end

		if transition < targetbrightness then
			transition = transition + transitionspeedpercented
		elseif transition >= targetbrightness then
			transition = transition - transitionspeedpercented
		end

		if transitionblue < bluelevel then
			transitionblue = transitionblue + transitionspeedpercented
		elseif transitionblue >= bluelevel then
			transitionblue = transitionblue - transitionspeedpercented
		end

		if transitiongreen < greenlevel then
			transitiongreen = transitiongreen + transitionspeedpercented
		elseif transitiongreen >= greenlevel then
			transitiongreen = transitiongreen - transitionspeedpercented
		end

		if transitionred < redlevel then
			transitionred = transitionred + transitionspeedpercented
		elseif transitionred >= redlevel then
			transitionred = transitionred - transitionspeedpercented
		end

		if transition > 1 then
			transition = 1
		end
		if transitionblue > 1 then
			transitionblue = 1
		end
		if transitiongreen > 1 then
			transitiongreen = 1
		end
		if transitionred > 1 then
			transitionred = 1
		end
		if sundir then -- try to calculate an 'orbit', while attempting to
			local origworldrot = math.atan2(sundirx, sundirz)
			local origheight = math.atan2(sundirx, sundiry)

		end

		Spring.SetSunLighting({ groundAmbientColor = { transitionred * gar, transitiongreen * gag, transitionblue * gab } })
		Spring.SetSunLighting({ unitAmbientColor = { transitionred * uar, transitiongreen * uag, transitionblue * uab } })
		Spring.SetSunLighting({ groundDiffuseColor = { transitionred * gdr, transitiongreen * gdg, transitionblue * gdb } })
		Spring.SetSunLighting({ unitDiffuseColor = { transitionred * udr, transitiongreen * udg, transitionblue * udb } })
		Spring.SetSunLighting({ groundSpecularColor = { transitionred * gsr, transitiongreen * gsg, transitionblue * gsb } })
		Spring.SetSunLighting({ unitSpecularColor = { transitionred * usr, transitiongreen * usg, transitionblue * usb } })

		Spring.SetAtmosphere({ skyColor = { transitionred * skycr, transitiongreen * skycg, transitionblue * skycb } })
		Spring.SetAtmosphere({ sunColor = { transitionred * suncr, transitiongreen * suncg, transitionblue * suncb } })
		Spring.SetAtmosphere({ cloudColor = { transitionred * clocr, transitiongreen * clocg, transitionblue * clocb } })
		Spring.SetAtmosphere({ fogColor = { transitionred * fogcr, transitiongreen * fogcg, transitionblue * fogcb } })

		Spring.SetSunLighting({ groundShadowDensity = transition * shadowdensity, modelShadowDensity = transition * shadowdensity })
	end

	local function MapAtmosphereConfigSetFog(_, targetstart, targetend, transitionspeedstart, transitionspeedend)
		local transitionspeedpercentedstart = transitionspeedstart * 0.000333
		local transitionspeedpercentedend = transitionspeedend * 0.000333
		if not transitionstart then
			transitionstart = 1
		end
		if not transitionend then
			transitionend = 1
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
		gadgetHandler:AddSyncAction("GetLightingAndAtmosphere", GetLightingAndAtmosphere)
		gadgetHandler:AddSyncAction("SetLightingAndAtmosphere", SetLightingAndAtmosphere)
		gadgetHandler:AddSyncAction("MixLightingAndAtmosphere", MixLightingAndAtmosphere)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("MapAtmosphereConfigSetSun")
		gadgetHandler:RemoveSyncAction("MapAtmosphereConfigSetFog")
		gadgetHandler:RemoveSyncAction("SetLightingAndAtmosphere")
		gadgetHandler:RemoveSyncAction("GetLightingAndAtmosphere")
		gadgetHandler:RemoveSyncAction("MixLightingAndAtmosphere")
		SetLightingAndAtmosphere(initial_atmosphere_lighting)
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

	function SpawnCEGInRandomMapPosAvoidUnits(cegname, groundOffset, radius, sound, soundvolume)
		for y = 1,50 do
			local posx = math_random(0, mapsizeX)
			local posz = math_random(0, mapsizeZ)
			local posy = spGetGroundHeight(posx, posz) + (groundOffset or 0)
			local units = Spring.GetUnitsInCylinder(posx, posz, radius)
			if #units == 0 then
				spSpawnCEG(cegname, posx, posy, posz)
				if sound then
					Spring.PlaySoundFile(sound, soundvolume, posx, posy, posz, 'sfx')
				end
				break
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

	VFS.Include("luarules/configs/Atmosphereconfigs/" .. mapFileName .. ".lua")
end


