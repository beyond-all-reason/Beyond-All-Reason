local function techsplit_balanceTweaks(name, uDef)

	if name == "corgol" then 
		uDef.speed = 37
		uDef.weapondefs.cor_gol.damage = {
			default = 1600,
			subs = 356,
			vtol = 98,
		}
		uDef.weapondefs.cor_gol.reloadtime = 4
		uDef.weapondefs.cor_gol.range = 700
		uDef.customparams.techlevel = 3
	end

	if name == "armfboy" then
		uDef.customparams.techlevel = 3
	end

	if name == "armshltx" then
		uDef.buildoptions[7] = "armfboy"
	end

	if name == "corgant" then
		uDef.buildoptions[8] = "corgol"
	end

	if name == "coravp" then 
		uDef.buildoptions[5] = ""
	end

	if name == "armalab" then
		uDef.buildoptions[10] = ""
	end

	if name == "armhlt" then
		uDef.health = 4640
		uDef.metalcost = 535
		uDef.energycost = 5700
		uDef.buildtime = 13700
		uDef.weapondefs.arm_laserh1.range = 750
		uDef.weapondefs.arm_laserh1.reloadtime = 2.9
		uDef.weapondefs.arm_laserh1.damage = {
			commanders = 801,
			default = 534,
			vtol = 48,
		}
	end

    if name == "armfhlt" then
		uDef.health = 7600
		uDef.metalcost = 570
		uDef.energycost = 7520
		uDef.buildtime = 11700
		uDef.weapondefs.armfhlt_laser.range = 750
		uDef.weapondefs.armfhlt_laser.reloadtime = 1.45
		uDef.weapondefs.armfhlt_laser.damage = {
			commanders = 414,
			default = 290,
			vtol = 71,
		}
	end

	if name == "corhlt" then
		uDef.health = 4640
		uDef.metalcost = 580
		uDef.energycost = 5700
		uDef.buildtime = 13800
		uDef.weapondefs.cor_laserh1.range = 750
		uDef.weapondefs.cor_laserh1.reloadtime = 1.8
		uDef.weapondefs.cor_laserh1.damage = {
			commanders = 540,
			default = 360,
			vtol = 41,
		}
	end

    if name == "corfhlt" then
		uDef.health = 7340
		uDef.metalcost = 580
		uDef.energycost = 7520
		uDef.buildtime = 13800
		uDef.weapondefs.corfhlt_laser.range = 750
		uDef.weapondefs.corfhlt_laser.reloadtime = 1.5
		uDef.weapondefs.corfhlt_laser.damage = {
			commanders = 482,
			default = 319,
			vtol = 61,
		}
	end

	return uDef
end

return {
	techsplit_balanceTweaks = techsplit_balanceTweaks,
}
