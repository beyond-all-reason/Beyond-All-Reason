local function techsplit_balanceTweaks(name, uDef)
	-- Cortex T1
	if name == "corthud" then
		uDef.metalcost = 280
		uDef.energycost = 2300
		uDef.buildtime = 4200
		uDef.health = 2200
		uDef.speed = 54
		uDef.maxacc = 0.14
		uDef.maxdec = 0.8
		uDef.weapondefs.arm_ham = {
			areaofeffect = 51,
			avoidfeature = false,
			craterareaofeffect = 0,
			craterboost = 0,
			cratermult = 0,
			edgeeffectiveness = 0.15,
			explosiongenerator = "custom:genericshellexplosion-small",
			gravityaffected = "true",
			impulsefactor = 0.9,
			name = "PlasmaCannon",
			noselfdamage = true,
			predictboost = 0.6,
			range = 330,
			reloadtime = 2.5,
			soundhit = "xplomed3",
			soundhitwet = "splshbig",
			soundstart = "cannon1",
			stages = 12,
			turret = true,
			weapontype = "Cannon",
			weaponvelocity = 286,
			damage = {
				default = 300,
				vtol = 60,
			},
		}
	end

	if name == "armwar" then
		uDef.speed = 60
		uDef.weapondefs.armwar_laser.range = 280
	end

	if name == "corstorm" then
		uDef.speed = 45
		uDef.weapondefs.cor_bot_rocket.range = 600
		uDef.health = 590
	end

	if name == "armrock" then
		uDef.speed = 50
		uDef.weapondefs.arm_bot_rocket.range = 575
		uDef.health = 575
	end

	if name == "armhlt" then
		uDef.metalcost = 535
		uDef.energycost = 5700
		uDef.buildtime = 13700
		uDef.weapondefs.arm_laserh1.range = 750
	end

	if name == "corhlt" then
		uDef.metalcost = 580
		uDef.energycost = 5700
		uDef.buildtime = 13800
		uDef.weapondefs.cor_laserh1.range = 750
	end

	if name == "armpw" then
		uDef.speed = 90
		uDef.health = 300
	end

	if name == "armart" then
		uDef.speed = 70
		uDef.metalcost = 270
		uDef.energycost = 4400
		uDef.buildtime = 6000
		uDef.turnrate = 210
		uDef.maxacc = 0.018
		uDef.maxdec = 0.081
		uDef.weapondefs.tawf113_weapon.range = 830
		uDef.weapondefs.tawf113_weapon.damage = {
			default = 364,
			subs = 122,
			vtol = 40,
		}
	end

	if name == "corwolv" then
		uDef.speed = 70
		uDef.metalcost = 340
		uDef.energycost = 5000
		uDef.buildtime = 7100
		uDef.turnrate = 250
		uDef.maxacc = 0.015
		uDef.maxdec = 0.0675
		uDef.weapondefs.corwolv_gun.range = 805
		uDef.weapondefs.corwolv_gun.damage = {
			default = 775,
			subs = 195,
			vtol = 78,
		}
	end

	if name == "armham" then
		uDef.weapondefs.arm_ham = {
			areaofeffect = 36,
			avoidfeature = false,
			craterareaofeffect = 0,
			craterboost = 0,
			cratermult = 0,
			edgeeffectiveness = 0.15,
			explosiongenerator = "custom:genericshellexplosion-small",
			gravityaffected = "true",
			impulsefactor = 0.128,
			paralyzer = true,
			paralyzetime = 2,
			name = "Light g2g EMP cannon (low trajectory)",
			noselfdamage = true,
			predictboost = 0.4,
			range = 380,
			reloadtime = 1.73333,
			rgbcolor = "0.7 0.7 1",
			soundhit = "xplomed3",
			soundhitwet = "splshbig",
			soundstart = "cannon1",
			turret = true,
			weapontype = "Cannon",
			weaponvelocity = 500,
			damage = {
				default = 315,
			},
		}
		uDef.weapons[1] = {
				def = "ARM_HAM",
				onlytargetcategory = "EMPABLE",
			}
	end

	if name == "armmart" then
		uDef.metalcost = 400
		uDef.speed = 47
		uDef.turnrate = 120
		
		uDef.health = 750
		uDef.weapondefs.arm_artillery = {
			accuracy = 600,
			areaofeffect = 60,
			avoidfeature = false,
			cegtag = "arty-medium",
			craterboost = 0,
			cratermult = 0,
			edgeeffectiveness = 0.65,
			explosiongenerator = "custom:genericshellexplosion-medium-bomb",
			gravityaffected = "true",
			mygravity = 0.12,
			hightrajectory = true,
			impulsefactor = 0.123,
			name = "Long-range g2g plasma cannon",
			noselfdamage = true,
			predictboost = 0.0,
			range = 1140,
			reloadtime = 3.05,
			soundhit = "xplomed4",
			soundhitwet = "splsmed",
			soundstart = "cannhvy2",
			turret = true,
			weapontype = "Cannon",
			weaponvelocity = 355.28,
			damage = {
				default = 488,
				subs = 122,
				vtol = 49,
			},
		}
		uDef.weapons[1].maxangledif = 90
	end

	if name == "corshiva" then
		uDef.canmanualfire = true
		uDef.weapondefs.shiva_rocket.stockpile = true
		uDef.weapondefs.shiva_rocket.stockpiletime = 28
		uDef.weapondefs.shiva_rocket.commandfire = true
		uDef.weapondefs.shiva_rocket.areaofeffect = 180
		uDef.weapondefs.shiva_rocket.customparams = {
			stockpilelimit = 2,
		}
		uDef.weapondefs.shiva_rocket.reloadtime = 0.3
		uDef.weapons[2] = {
			def = "SHIVA_ROCKET",
			onlytargetcategory = "SURFACE",
		}
	end

	return uDef
end

return {
	techsplit_balanceTweaks = techsplit_balanceTweaks,
}
