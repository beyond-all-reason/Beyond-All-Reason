function UnbaCom_Post(name)
	local lowername = string.lower(name)
	local uppername = string.upper(name)
	local tablecom = table.copy(UnitDefs[name])
	tablecom.autoheal = 2
	tablecom.power = CommanderPower
	tablecom.weapondefs[lowername.."laser"].weapontype = "LaserCannon"
	tablecom.weapons = {}
	tablecom.script = "scripts/Units/unbacom/unba"..lowername.."_lus.lua"
	tablecom.objectname = "Units/"..uppername..".S3O"



	--------------------------------------------
	---					ARM					 ---
	--------------------------------------------
	if name == "armcom" then
			--Weapon: Laser
		tablecom.weapondefs[lowername.."laser2"] = table.copy(tablecom.weapondefs[lowername.."laser"])
		tablecom.weapondefs[lowername.."laser"].weapontype = "BeamLaser"
		tablecom.weapondefs[lowername.."laser"].damage.default = armDamages[1]

		tablecom.weapondefs[lowername.."laser2"].damage.default = armDamages[2]
		tablecom.weapondefs[lowername.."laser2"].range = armRange[2]
		tablecom.weapondefs[lowername.."laser2"].areaofeffect = armAOE[2]
		tablecom.weapondefs[lowername.."laser2"].reloadtime = armReloadTime[2]
		for i = 3,18 do
			I = tostring(i)
			H = tostring(i-1)
			tablecom.weapondefs[lowername.."laser"..I] = table.copy(tablecom.weapondefs[lowername.."laser"..H])
			tablecom.weapondefs[lowername.."laser"..I].damage.default = armDamages[i]
			tablecom.weapondefs[lowername.."laser"..I].range = armRange[i]
			tablecom.weapondefs[lowername.."laser"..I].areaofeffect = armAOE[i]
			tablecom.weapondefs[lowername.."laser"..I].reloadtime = armReloadTime[i]
			if i == 3 then
				tablecom.weapondefs[lowername.."laser3"].rgbcolor = "0.7 0.3 0"				
			elseif i == 4 then
				tablecom.weapondefs[lowername.."laser4"].rgbcolor = "0.55 0.45 0"				
			elseif i == 5 then
				tablecom.weapondefs[lowername.."laser5"].rgbcolor = "0.4 0.6 0"				
			elseif i == 6 then
				tablecom.weapondefs[lowername.."laser6"].rgbcolor = "0.25 0.75 0"				
			elseif i == 7 then
				tablecom.weapondefs[lowername.."laser7"].rgbcolor = "0.1 0.9 0"				
			elseif i == 8 then
				tablecom.weapondefs[lowername.."laser8"].rgbcolor = "0 0.95 0.05"				
			elseif i == 9 then
				tablecom.weapondefs[lowername.."laser9"].rgbcolor = "0 0.8 0.2"				
			elseif i == 10 then
				tablecom.weapondefs[lowername.."laser10"].rgbcolor = "0 0.65 0.35"				
			elseif i == 11 then
				tablecom.weapondefs[lowername.."laser11"].rgbcolor = "0 0.5 0.5"				
			elseif i == 12 then
				tablecom.weapondefs[lowername.."laser12"].rgbcolor = "0 0.35 0.65"				
			elseif i == 13 then
				tablecom.weapondefs[lowername.."laser13"].rgbcolor = "0 0.2 0.8"				
			elseif i == 14 then
				tablecom.weapondefs[lowername.."laser14"].rgbcolor = "0 0.05 0.95"				
			elseif i == 15 then
				tablecom.weapondefs[lowername.."laser15"].rgbcolor = "0 0 1"				
			elseif i == 16 then
				tablecom.weapondefs[lowername.."laser16"].rgbcolor = "0.15 0 1"				
			elseif i == 17 then
				tablecom.weapondefs[lowername.."laser17"].rgbcolor = "0.3 0 1"				
			elseif i == 18 then
				tablecom.weapondefs[lowername.."laser18"].rgbcolor = "0.45 0 1"
			end
		end

		for i = 1,18 do
			if i == 1 then
				tablecom.weapons[1] = {
						def = uppername.."LASER",
						onlytargetcategory = "NOTSUB",
						}
			else
				tablecom.weapons[i] = {
						def = uppername.."LASER"..tostring(i),
						onlytargetcategory = "NOTSUB",
						}
			end
		end
			--Weapon: SeaLaser
		tablecom.weapondefs[lowername.."sealaser2"] = table.copy(tablecom.weapondefs[lowername.."sealaser"])
		tablecom.weapondefs[lowername.."sealaser2"].damage.default = armDamages19[2]
		tablecom.weapondefs[lowername.."sealaser2"].damage.subs = armDamages20[2]*armDamages19[2]
		tablecom.weapondefs[lowername.."sealaser2"].range = armRange2[2]
		tablecom.weapondefs[lowername.."sealaser2"].areaofeffect = armAOE2[2]
		tablecom.weapondefs[lowername.."sealaser2"].reloadtime = armReloadTime2[2]
		for i = 3,18 do
			I = tostring(i)
			H = tostring(i-1)
			tablecom.weapondefs[lowername.."sealaser"..I] = table.copy(tablecom.weapondefs[lowername.."sealaser"..H])
			tablecom.weapondefs[lowername.."sealaser"..I].damage.default = armDamages19[i]
			tablecom.weapondefs[lowername.."sealaser"..I].damage.subs = armDamages20[i] * armDamages19[i]
			tablecom.weapondefs[lowername.."sealaser"..I].range = armRange2[i]
			tablecom.weapondefs[lowername.."sealaser"..I].areaofeffect = armAOE2[i]
			tablecom.weapondefs[lowername.."sealaser"..I].reloadtime = armReloadTime2[i]
		end
		---Weapon: EMP
		tablecom.weapons[30] = {
                def = "DISINTEGRATOR",
                onlytargetcategory = "NOTSUB",
				}
	--[[
		tablecom.weapons[31] = {
                def = "DISINTEGRATOR2",
                onlytargetcategory = "NOTSUB",
				}
		tablecom.weapons[32] = {
                def = "DISINTEGRATOR3",
                onlytargetcategory = "NOTSUB",
				}
		]]
		tablecom.weapondefs["disintegrator"].areaofeffect = 275
		tablecom.weapondefs["disintegrator"].edgeeffectiveness = 0.25
		tablecom.weapondefs["disintegrator"].explosiongenerator = "custom:genericshellexplosion-large-lightning"
		tablecom.weapondefs["disintegrator"].model = "airbomb.s3o"
		tablecom.weapondefs["disintegrator"].name = "EMP Grenade"
		tablecom.weapondefs["disintegrator"].paralyzer = true
		tablecom.weapondefs["disintegrator"].paralyzetime = 7
		tablecom.weapondefs["disintegrator"].range = 450
		tablecom.weapondefs["disintegrator"].reloadtime = 10
		tablecom.weapondefs["disintegrator"].soundhit = "EMGPULS1"
		tablecom.weapondefs["disintegrator"].soundhitwet = "splsslrg"
		tablecom.weapondefs["disintegrator"].soundstart = "bombrel"
		tablecom.weapondefs["disintegrator"].weapontype = "Cannon"
		tablecom.weapondefs["disintegrator"].weaponvelocity = 200
		tablecom.weapondefs["disintegrator"].energypershot = 1200
		tablecom.weapondefs["disintegrator"].damage[1] = 10000
		tablecom.weapondefs["disintegrator"].noexplode = false
		tablecom.weapondefs["disintegrator"].groundbounce = false
		tablecom.weapondefs["disintegrator"].groundrebound = 1
		tablecom.weapondefs["disintegrator"].cratermult = 0
		tablecom.weapondefs["disintegrator"].cegtag = nil		
		tablecom.weapondefs["disintegrator"].customparams[1] = nil
		tablecom.weapondefs["disintegrator"].customparams[2] = nil
		tablecom.weapondefs["disintegrator"].customparams[3] = nil
		tablecom.weapondefs["disintegrator"].customparams[4] = "0.5 0.5 1"
		tablecom.weapondefs["disintegrator"].customparams.expl_light_mult = 1.2
		tablecom.weapondefs["disintegrator"].customparams.expl_light_radius_mult = 0.9
		tablecom.weapondefs["disintegrator"].customparams.expl_light_life_mult = 1.55
		tablecom.weapondefs["disintegrator"].customparams.expl_light_heat_life_mult = "1.6"
		tablecom.weapondefs["disintegrator"].avoidfeature = false
		tablecom.weapondefs["disintegrator"].avoidfriendly = false
		tablecom.weapondefs["disintegrator"].avoidground = false
		tablecom.weapondefs["disintegrator"].bouncerebound = 0
		tablecom.weapondefs["disintegrator"].commandfire = true
		tablecom.weapondefs["disintegrator"].craterboost = 0
		tablecom.weapondefs["disintegrator"].cratermult = 0
		tablecom.weapondefs["disintegrator"].impulseboost = 0.001
		tablecom.weapondefs["disintegrator"].impulsefactor = 0.001
		tablecom.weapondefs["disintegrator"].soundtrigger = true
		tablecom.weapondefs["disintegrator"].turret = true
		tablecom.weapondefs["disintegrator"].waterweapon = true		


--[[		
		tablecom.weapondefs["disintegrator2"] = table.copy(tablecom.weapondefs["disintegrator"])
		tablecom.weapondefs["disintegrator2"].paralyzetime = 8
		tablecom.weapondefs["disintegrator2"].areaofeffect = 300
		tablecom.weapondefs["disintegrator2"].energypershot = 2500
		tablecom.weapondefs["disintegrator2"].weaponvelocity = 400
		tablecom.weapondefs["disintegrator2"].range = 700
		tablecom.weapondefs["disintegrator2"].customparams.expl_light_mult = 1.8
		tablecom.weapondefs["disintegrator2"].customparams.expl_light_radius_mult = 1.3
		tablecom.weapondefs["disintegrator2"].customparams.expl_light_life_mult = 2
		
		tablecom.weapondefs["disintegrator3"] = table.copy(tablecom.weapondefs["disintegrator2"])
		tablecom.weapondefs["disintegrator3"].paralyzetime = 9
		tablecom.weapondefs["disintegrator3"].areaofeffect = 400
		tablecom.weapondefs["disintegrator3"].energypershot = 5000
		tablecom.weapondefs["disintegrator3"].weaponvelocity = 600
		tablecom.weapondefs["disintegrator3"].range = 1000
		tablecom.weapondefs["disintegrator3"].customparams.expl_light_mult = 2.4
		tablecom.weapondefs["disintegrator3"].customparams.expl_light_radius_mult = 1.7
		tablecom.weapondefs["disintegrator3"].customparams.expl_light_life_mult = 2.45
	]]	
	end

	--------------------------------------------
	---					COR					 ---
	--------------------------------------------
	if name == "corcom" then	
			--Weapon: Laser
		tablecom.weapondefs[lowername.."laser2"] = table.copy(tablecom.weapondefs[lowername.."laser"])
		tablecom.weapondefs[lowername.."laser"].weapontype = "BeamLaser"
		tablecom.weapondefs[lowername.."laser"].damage.default = corDamages[1]

		tablecom.weapondefs[lowername.."laser2"].damage.default = corDamages[2]
		tablecom.weapondefs[lowername.."laser2"].range = corRange[2]
		tablecom.weapondefs[lowername.."laser2"].areaofeffect = corAOE[2]
		tablecom.weapondefs[lowername.."laser2"].reloadtime = corReloadTime[2]
		for i = 3,18 do
			I = tostring(i)
			H = tostring(i-1)
			tablecom.weapondefs[lowername.."laser"..I] = table.copy(tablecom.weapondefs[lowername.."laser"..H])
			tablecom.weapondefs[lowername.."laser"..I].damage.default = corDamages[i]
			tablecom.weapondefs[lowername.."laser"..I].range = corRange[i]
			tablecom.weapondefs[lowername.."laser"..I].areaofeffect = corAOE[i]
			tablecom.weapondefs[lowername.."laser"..I].reloadtime = corReloadTime[i]
			if i == 3 then
				tablecom.weapondefs[lowername.."laser3"].rgbcolor = "0.7 0.3 0"				
			elseif i == 4 then
				tablecom.weapondefs[lowername.."laser4"].rgbcolor = "0.55 0.45 0"				
			elseif i == 5 then
				tablecom.weapondefs[lowername.."laser5"].rgbcolor = "0.4 0.6 0"				
			elseif i == 6 then
				tablecom.weapondefs[lowername.."laser6"].rgbcolor = "0.25 0.75 0"				
			elseif i == 7 then
				tablecom.weapondefs[lowername.."laser7"].rgbcolor = "0.1 0.9 0"				
			elseif i == 8 then
				tablecom.weapondefs[lowername.."laser8"].rgbcolor = "0 0.95 0.05"				
			elseif i == 9 then
				tablecom.weapondefs[lowername.."laser9"].rgbcolor = "0 0.8 0.2"				
			elseif i == 10 then
				tablecom.weapondefs[lowername.."laser10"].rgbcolor = "0 0.65 0.35"				
			elseif i == 11 then
				tablecom.weapondefs[lowername.."laser11"].rgbcolor = "0 0.5 0.5"				
			elseif i == 12 then
				tablecom.weapondefs[lowername.."laser12"].rgbcolor = "0 0.35 0.65"				
			elseif i == 13 then
				tablecom.weapondefs[lowername.."laser13"].rgbcolor = "0 0.2 0.8"				
			elseif i == 14 then
				tablecom.weapondefs[lowername.."laser14"].rgbcolor = "0 0.05 0.95"				
			elseif i == 15 then
				tablecom.weapondefs[lowername.."laser15"].rgbcolor = "0 0 1"				
			elseif i == 16 then
				tablecom.weapondefs[lowername.."laser16"].rgbcolor = "0.15 0 1"				
			elseif i == 17 then
				tablecom.weapondefs[lowername.."laser17"].rgbcolor = "0.3 0 1"				
			elseif i == 18 then
				tablecom.weapondefs[lowername.."laser18"].rgbcolor = "0.45 0 1"
			end
		end

		for i = 1,18 do
			if i == 1 then
				tablecom.weapons[1] = {
						def = uppername.."LASER",
						onlytargetcategory = "NOTSUB",
						}
			else
				tablecom.weapons[i] = {
						def = uppername.."LASER"..tostring(i),
						onlytargetcategory = "NOTSUB",
						}
			end
		end
			--Weapon: SeaLaser
		tablecom.weapondefs[lowername.."sealaser2"] = table.copy(tablecom.weapondefs[lowername.."sealaser"])
		tablecom.weapondefs[lowername.."sealaser2"].damage.default = corDamages19[2]
		tablecom.weapondefs[lowername.."sealaser2"].damage.subs = corDamages20[2]*corDamages19[2]
		tablecom.weapondefs[lowername.."sealaser2"].range = corRange2[2]
		tablecom.weapondefs[lowername.."sealaser2"].areaofeffect = corAOE2[2]
		tablecom.weapondefs[lowername.."sealaser2"].reloadtime = corReloadTime2[2]
		for i = 3,18 do
			I = tostring(i)
			H = tostring(i-1)
			tablecom.weapondefs[lowername.."sealaser"..I] = table.copy(tablecom.weapondefs[lowername.."sealaser"..H])
			tablecom.weapondefs[lowername.."sealaser"..I].damage.default = corDamages19[i]
			tablecom.weapondefs[lowername.."sealaser"..I].damage.subs = corDamages20[i] * corDamages19[i]
			tablecom.weapondefs[lowername.."sealaser"..I].range = corRange2[i]
			tablecom.weapondefs[lowername.."sealaser"..I].areaofeffect = corAOE2[i]
			tablecom.weapondefs[lowername.."sealaser"..I].reloadtime = corReloadTime2[i]
		end
		for i = 30,30 do
            tablecom.weapons[i] = {
            def = "DISINTEGRATOR",
            onlytargetcategory = "NOTSUB",
			}
		end
	
		tablecom.weapondefs["disintegrator"].reloadtime = 10
		tablecom.weapondefs["disintegrator"].energypershot = 1200
		tablecom.weapondefs["disintegrator"].damage = {
												default = 99999,
												scavboss = 1000,
												commanders = 500,
											}

		
	end

--------------------------------


	for i = 19,29 do
		if i - 18 == 1 then
			tablecom.weapons[19] = {
					def = uppername.."SEALASER",
					badtargetcategory = "VTOL",
					}
		else
			tablecom.weapons[i] = {
					def = uppername.."SEALASER"..tostring(i-18),
					badtargetcategory = "VTOL",
					}
		end
	end

	if name == "armcom" then
		tablecom.buildoptions = ArmDefsBuildOptions
	else
		tablecom.buildoptions = CorDefsBuildOptions
	end
	for i = 1,18 do
		tablecom.featuredefs["dead"..tostring(i)] = table.copy(tablecom.featuredefs.dead)
		tablecom.featuredefs["heap"..tostring(i)] = table.copy(tablecom.featuredefs.heap)
		tablecom.featuredefs["dead"..tostring(i)].metal = tablecom.featuredefs["dead"].metal * WreckMetal[i]
		tablecom.featuredefs["heap"..tostring(i)].metal = tablecom.featuredefs["heap"].metal * WreckMetal[i]
		tablecom.featuredefs["dead"..tostring(i)].featuredead = "heap"..tostring(i)
		tablecom.featuredefs["dead"..tostring(i)].resurrectable = 0
	end
	tablecom.featuredefs["dead"].resurrectable = 0
	UnitDefs[name] = tablecom
	
end
