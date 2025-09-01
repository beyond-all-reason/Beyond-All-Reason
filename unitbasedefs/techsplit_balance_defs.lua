local function techsplit_balanceTweaks(name, uDef)
	-- Cortex T1
	if name == "corthud" then 
		uDef.speed = 54
		uDef.weapondefs.arm_ham.range = 320
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
		uDef.health = 4640
		uDef.metalcost = 535
		uDef.energycost = 5700
		uDef.buildtime = 13700
		uDef.weapondefs.arm_laserh1.range = 750
		uDef.weapondefs.arm_laserh1.reloadtime = 2.9
	end

	if name == "corhlt" then
		uDef.health = 4640
		uDef.metalcost = 580
		uDef.energycost = 5700
		uDef.buildtime = 13800
		uDef.weapondefs.cor_laserh1.range = 750
		uDef.weapondefs.cor_laserh1.reloadtime = 1.8
	end

	if name == "armart" then
		uDef.speed = 70
		uDef.turnrate = 210
		uDef.maxacc = 0.018
		uDef.maxdec = 0.081
		uDef.weapondefs.tawf113_weapon.accuracy = 150
		uDef.weapondefs.tawf113_weapon.range = 830
		uDef.weapondefs.tawf113_weapon.damage = {
			default = 182,
			subs = 61,
			vtol = 20,
		}
		uDef.weapons[1].maxangledif = 30
	end

	if name == "corwolv" then
		uDef.speed = 70
		uDef.turnrate = 250
		uDef.maxacc = 0.015
		uDef.maxdec = 0.0675
		uDef.weapondefs.corwolv_gun.accuracy = 150
		uDef.weapondefs.corwolv_gun.range = 850
		uDef.weapondefs.corwolv_gun.damage = {
			default = 375,
			subs = 95,
			vtol = 38,
		}
		uDef.weapons[1].maxangledif = 30
	end

	if name == "armmart" then
		uDef.metalcost = 400
		uDef.energycost = 5500
		uDef.buildtime = 7500
		uDef.speed = 47
		uDef.turnrate = 120
		uDef.maxacc = 0.005
		uDef.health = 750
		uDef.weapondefs.arm_artillery = {
			accuracy = 75,
			areaofeffect = 60,
			avoidfeature = false,
			cegtag = "arty-medium",
			craterboost = 0,
			cratermult = 0,
			edgeeffectiveness = 0.65,
			explosiongenerator = "custom:genericshellexplosion-medium-bomb",
			gravityaffected = "true",
			mygravity = 0.12,
			hightrajectory = 1,
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
		uDef.weapons[1].maxangledif = 30
	end

	if name == "cormart" then
		uDef.metalcost = 600
		uDef.energycost = 6600
		uDef.buildtime = 6500
		uDef.speed = 45
		uDef.turnrate = 100
		uDef.maxacc = 0.005
		uDef.weapondefs.cor_artillery = {
			accuracy = 75,
			areaofeffect = 144,
			avoidfeature = false,
			cegtag = "arty-heavy",
			craterboost = 0,
			cratermult = 0,
			edgeeffectiveness = 0.65,
			explosiongenerator = "custom:genericshellexplosion-large-bomb",
			gravityaffected = "true",
			mygravity = 0.1,
			hightrajectory = 1,
			impulsefactor = 0.123,
			name = "PlasmaCannon",
			noselfdamage = true,
			range = 1050,
			reloadtime = 5,
			soundhit = "xplomed4",
			soundhitwet = "splsmed",
			soundstart = "cannhvy2",
			turret = true,
			weapontype = "Cannon",
			weaponvelocity = 349.5354,
			damage = {
				default = 1200,
				subs = 400,
				vtol = 120,
			},
		}
		uDef.weapons[1].maxangledif = 30
	end

	if name == "armfido" then
		uDef.speed = 74
		uDef.weapondefs.bfido.range = 500
		uDef.weapondefs.bfido.weaponvelocity = 400
	end

	if name == "cormort" then
		uDef.health = 800
		uDef.speed = 51
		uDef.weapondefs.cor_mort.range = 650
	end

	if name == "corhrk" then
		uDef.turnrate = 600
		uDef.weapondefs.corhrk_rocket.range = 900
		uDef.weapondefs.corhrk_rocket.weaponvelocity = 600
		uDef.weapondefs.corhrk_rocket.flighttime = 22
		uDef.weapondefs.corhrk_rocket.reloadtime = 0.4
		uDef.weapondefs.corhrk_rocket.turnrate = 30000
		uDef.weapondefs.corhrk_rocket.weapontimer = 4
		uDef.weapondefs.corhrk_rocket.stockpile = true
		uDef.weapondefs.corhrk_rocket.stockpiletime = 8
		uDef.weapondefs.corhrk_rocket.customparams.stockpilelimit = 2
		uDef.weapons[1].maxangledif = 60
		uDef.weapons[1].maindir = "0 0 1"
	end

	if name == "armsptk" then
		uDef.health = 450
		uDef.turnrate = 600
		uDef.weapondefs.adv_rocket.range = 775
		uDef.weapondefs.adv_rocket.trajectoryheight = 1
		uDef.weapondefs.adv_rocket.customparams.overrange_distance = 800
		uDef.weapondefs.adv_rocket.weapontimer = 8
		uDef.weapondefs.adv_rocket.flighttime  = 4
		uDef.weapons[1].maxangledif = 30
		uDef.weapons[1].maindir = "0 0 1"
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

	if name == "corban" then
		uDef.speed = 69
		uDef.turnrate = 500
		uDef.weapondefs.banisher.areaofeffect = 220
		uDef.weapondefs.banisher.range = 400
		uDef.weapondefs.banisher.damage = {
			default = 1320,
			subs = 660
		}
	end

	if name == "armcroc" then
		uDef.canmanualfire = true
		uDef.turnrate = 270
		uDef.weapondefs.armcl_missile.areaofeffect = 60
		uDef.weapondefs.armcl_missile.canattackground = true
		uDef.weapondefs.armcl_missile.cegtag = "missiletrailmedium-starburst"
		uDef.weapondefs.armcl_missile.commandfire = true
		uDef.weapondefs.armcl_missile.damage = {
			default = 300
		}
		uDef.weapondefs.armcl_missile.range = 650
		uDef.weapondefs.armcl_missile.reloadtime = 0.3
		uDef.weapondefs.armcl_missile.stockpile = true
		uDef.weapondefs.armcl_missile.stockpiletime = 8.5
		uDef.weapondefs.armcl_missile.texture2 = "null"
		uDef.weapondefs.armcl_missile.trajectoryheight = 0.45
		uDef.weapondefs.armcl_missile.customparams = {
			stockpilelimit = 3,
		}
		uDef.weapons[2] = {
			def = "ARMCL_MISSILE",
			onlytargetcategory = "SURFACE",
		}
	end

	if name == "correap" then 
		uDef.speed = 76
		uDef.turnrate = 250
		uDef.weapondefs.cor_reap.areaofeffect = 92
		uDef.weapondefs.cor_reap.damage = {
			default = 150,
			vtol = 48,
		}
		uDef.weapondefs.cor_reap.range = 305
	end

	if name == "armanac" then
		uDef.speed = 79
		uDef.weapondefs.armanac_weapon.areaofeffect = 52
		uDef.weapondefs.armanac_weapon.damage = {
			default = 185,
			vtol = 55,
		}
		uDef.weapondefs.armanac_weapon.weaponvelocity = 500
		uDef.weapondefs.armanac_weapon.range = 295
	end


	return uDef
end

return {
	techsplit_balanceTweaks = techsplit_balanceTweaks,
}
