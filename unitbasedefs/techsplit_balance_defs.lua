local function techsplit_balanceTweaks(name, uDef)
	-- Cortex T1
	if name == "corthud" then
		uDef.metalcost = 280
		uDef.energycost = 2300
		uDef.buildtime = 4200
		uDef.health = 2200
		uDef.speed = 54
		uDef.weapondefs.arm_ham = {
				burst = 2,
				burstrate = 0.2,
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
				turret = true,
				weapontype = "Cannon",
				weaponvelocity = 286,
				damage = {
					default = 150,
					vtol = 31,
				},
			}
	end

	if name == "armwar" then
		uDef.speed = 60
		uDef.weapondefs.armwar_laser.range = 300
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
		uDef.weapondefs.armlaserh1.range = 750
	end

	if name == "corhlt" then
		uDef.weapondefs.corlaserh1.range = 750
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
			impulsefactor = 3.6,
			name = "Light g2g gauss cannon (low trajectory)",
			noselfdamage = true,
			predictboost = 0.4,
			range = 380,
			reloadtime = 1.73333,
			soundhit = "xplomed3",
			soundhitwet = "splshbig",
			soundstart = "cannon1",
			turret = true,
			weapontype = "Cannon",
			weaponvelocity = 500,
			damage = {
				default = 52,
				vtol = 11,
			},
		}

	if name == "armmart" then
		uDef.weapondefs.arm_artillery.range = 
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
