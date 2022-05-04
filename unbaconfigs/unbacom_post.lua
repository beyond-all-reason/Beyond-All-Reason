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
				tablecom.weapondefs[lowername.."laser3"].rgbcolor = "0.75 0.25 0"
			elseif i == 6 then
				tablecom.weapondefs[lowername.."laser6"].rgbcolor = "0.5 0.5 0"
			elseif i == 8 then
				tablecom.weapondefs[lowername.."laser8"].rgbcolor = "0.25 0.75 0"
			elseif i == 10 then
				tablecom.weapondefs[lowername.."laser10"].rgbcolor = "0 1 0"
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
			if i == 3 then
				tablecom.weapondefs[lowername.."sealaser3"].rgbcolor = "0.75 0.25 0"
			elseif i == 6 then
				tablecom.weapondefs[lowername.."sealaser6"].rgbcolor = "0.5 0.5 0"
			elseif i == 8 then
				tablecom.weapondefs[lowername.."sealaser8"].rgbcolor = "0.25 0.75 0"
			elseif i == 10 then
				tablecom.weapondefs[lowername.."sealaser10"].rgbcolor = "0 1 0"
			end
		end
	end

	--------------------------------------------
	---					COR					 ---
	--------------------------------------------
	if name == "corcom" then	
			--Weapon: Laser
		tablecom.weapondefs[lowername.."laser2"] = table.copy(tablecom.weapondefs[lowername.."laser"])
		tablecom.weapondefs[lowername.."laser"].weapontype = "BeamLaser"

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
			Spring.Echo("correloadtime:",corReloadTime[1])
			if i == 3 then
				tablecom.weapondefs[lowername.."laser3"].rgbcolor = "0.75 0.25 0"
			elseif i == 6 then
				tablecom.weapondefs[lowername.."laser6"].rgbcolor = "0.5 0.5 0"
			elseif i == 8 then
				tablecom.weapondefs[lowername.."laser8"].rgbcolor = "0.25 0.75 0"
			elseif i == 10 then
				tablecom.weapondefs[lowername.."laser10"].rgbcolor = "0 1 0"
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
			if i == 3 then
				tablecom.weapondefs[lowername.."sealaser3"].rgbcolor = "0.75 0.25 0"
			elseif i == 6 then
				tablecom.weapondefs[lowername.."sealaser6"].rgbcolor = "0.5 0.5 0"
			elseif i == 8 then
				tablecom.weapondefs[lowername.."sealaser8"].rgbcolor = "0.25 0.75 0"
			elseif i == 10 then
				tablecom.weapondefs[lowername.."sealaser10"].rgbcolor = "0 1 0"
			end
		end
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
--[[	for i = 2,7 do
		I = tostring(i)
		H = tostring(i-1)
		tablecom.weapondefs["repulsor"..I] = table.copy(tablecom.weapondefs["repulsor"..H])
		tablecom.weapondefs["repulsor"..I].shield.power = ShieldPower[i]
	end
	for i = 23,29 do
		tablecom.weapons[i] = {
				def = "REPULSOR"..tostring(i-22),
				}
	end]]
	for i = 30,30 do
            tablecom.weapons[i] = {
                def = "DISINTEGRATOR",
                onlytargetcategory = "NOTSUB",
				}
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
		tablecom.featuredefs["dead"..tostring(i)].resurrectable = 1
	end
	UnitDefs[name] = tablecom
end
