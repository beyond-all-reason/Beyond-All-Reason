function UnbaCom_Post(name)
	local lowername = string.lower(name)
	local uppername = string.upper(name)
	local tablecom = deepcopy(UnitDefs[name])
		tablecom.autoheal = 2
		tablecom.power = CommanderPower
		tablecom.weapondefs[lowername.."laser"].weapontype = "LaserCannon"
		tablecom.weapons = {}
		tablecom.script = lowername.."_lus.lua"
		tablecom.objectname = "UNBA"..uppername..".3DO"
			--Weapon: Laser
		tablecom.weapondefs[lowername.."laser2"] = deepcopy(tablecom.weapondefs[lowername.."laser"])
		tablecom.weapondefs[lowername.."laser"].weapontype = "BeamLaser"
		tablecom.weapondefs[lowername.."laser2"].damage.default = Damages[2]
		tablecom.weapondefs[lowername.."laser2"].range = Range[2]
		tablecom.weapondefs[lowername.."laser2"].areaofeffect = AOE[2]
		tablecom.weapondefs[lowername.."laser2"].reloadtime = ReloadTime[2]
	for i = 3,11 do
		I = tostring(i)
		H = tostring(i-1)
		tablecom.weapondefs[lowername.."laser"..I] = deepcopy(tablecom.weapondefs[lowername.."laser"..H])
		tablecom.weapondefs[lowername.."laser"..I].damage.default = Damages[i]
		tablecom.weapondefs[lowername.."laser"..I].range = Range[i]
		tablecom.weapondefs[lowername.."laser"..I].areaofeffect = AOE[i]
		tablecom.weapondefs[lowername.."laser"..I].reloadtime = ReloadTime[i]
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

	for i = 1,11 do
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
	tablecom.weapondefs[lowername.."sealaser2"] = deepcopy(tablecom.weapondefs[lowername.."sealaser"])
		tablecom.weapondefs[lowername.."sealaser2"].damage.default = Damages21[2]
		tablecom.weapondefs[lowername.."sealaser2"].damage.subs = Damages22[2]*Damages21[2]
		tablecom.weapondefs[lowername.."sealaser2"].range = Range2[2]
		tablecom.weapondefs[lowername.."sealaser2"].areaofeffect = AOE2[2]
		tablecom.weapondefs[lowername.."sealaser2"].reloadtime = ReloadTime2[2]
	for i = 3,11 do
		I = tostring(i)
		H = tostring(i-1)
		tablecom.weapondefs[lowername.."sealaser"..I] = deepcopy(tablecom.weapondefs[lowername.."sealaser"..H])
		tablecom.weapondefs[lowername.."sealaser"..I].damage.default = Damages21[i]
		tablecom.weapondefs[lowername.."sealaser"..I].damage.subs = Damages22[i] * Damages21[i]
		tablecom.weapondefs[lowername.."sealaser"..I].range = Range2[i]
		tablecom.weapondefs[lowername.."sealaser"..I].areaofeffect = AOE2[i]
		tablecom.weapondefs[lowername.."sealaser"..I].reloadtime = ReloadTime2[i]
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

	for i = 12,22 do
		if i - 11 == 1 then
			tablecom.weapons[12] = {
					def = uppername.."SEALASER",
					badtargetcategory = "VTOL",
					}
		else
			tablecom.weapons[i] = {
					def = uppername.."SEALASER"..tostring(i-11),
					badtargetcategory = "VTOL",
					}
		end
	end
	for i = 2,7 do
		I = tostring(i)
		H = tostring(i-1)
		tablecom.weapondefs["repulsor"..I] = deepcopy(tablecom.weapondefs["repulsor"..H])
		tablecom.weapondefs["repulsor"..I].shield.power = ShieldPower[i]
	end
	for i = 23,29 do
		tablecom.weapons[i] = {
				def = "REPULSOR"..tostring(i-22),
				}
	end
	tablecom.weapons[30] ={
					def = "DISINTEGRATOR",
					onlytargetcategory = "NOTSUB",
				}
	if name == "armcom" then
		tablecom.buildoptions = ArmDefsBuildOptions
	else
		tablecom.buildoptions = CoreDefsBuildOptions
	end
	for i = 1,11 do
		tablecom.featuredefs["dead"..tostring(i)] = deepcopy(tablecom.featuredefs.dead)
		tablecom.featuredefs["heap"..tostring(i)] = deepcopy(tablecom.featuredefs.heap)
		tablecom.featuredefs["dead"..tostring(i)].metal = tablecom.featuredefs["dead"].metal * WreckMetal[i]
		tablecom.featuredefs["heap"..tostring(i)].metal = tablecom.featuredefs["heap"].metal * WreckMetal[i]
		tablecom.featuredefs["dead"..tostring(i)].featuredead = "heap"..tostring(i)
		tablecom.featuredefs["dead"..tostring(i)].resurrectable = 1
	end
	UnitDefs[name] = tablecom
end