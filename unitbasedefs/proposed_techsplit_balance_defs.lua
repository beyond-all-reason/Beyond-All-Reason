local function proposed_techsplit_balanceTweaks(name, uDef)
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
		uDef.weapondefs.armwar_laser.range = 280
		uDef.weapondefs.armwar_laser.damage.default = 110
		uDef.weapondefs.armwar_laser.damage.vtol = 18
	end

	if name == "corstorm" then
		uDef.speed = 45


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
	proposed_techsplit_balanceTweaks = proposed_techsplit_balanceTweaks,
}