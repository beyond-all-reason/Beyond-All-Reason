local function proposed_unit_reworksTweaks(name, uDef)

	if name == "armrock" or name == "corstorm" then
		uDef.speed = uDef.speed + 4.3
		uDef.turnrate = 900
		uDef.buildtime = math.ceil(uDef.buildtime * 1.15 / 100) * 100
	end
	
	if name == "armwar" then
		uDef.metalcost = 200
		uDef.energycost = 2300
		uDef.turnrate = 650
		uDef.health = 1500
		uDef.speed = 50
		uDef.weapondefs.armwar_laser.range = 290
		uDef.weapondefs.armwar_laser.damage.default = 40
	end

	if name == "armham" then
		uDef.speed = 47
		uDef.weapondefs.arm_ham.areaofeffect = 48
		uDef.weapondefs.arm_ham.reloadtime = 1.8
	end
	if name == "corthud" then
		uDef.health = 1200
		uDef.buildtime = 2300
		uDef.weapondefs.arm_ham.areaofeffect = 48
		uDef.weapondefs.arm_ham.reloadtime = 1.8
	end


	if name == "armart" then
		uDef.speed = 56 --was 54
		uDef.weapondefs.tawf113_weapon.weaponvelocity = 400
		uDef.weapondefs.tawf113_weapon.mygravity = nil
		uDef.weapondefs.tawf113_weapon.areaofeffect = 100 --75
		uDef.weapondefs.tawf113_weapon.range = 730 --710
		uDef.weapondefs.tawf113_weapon.impulsefactor = 0.7
		uDef.weapondefs.tawf113_weapon.damage.default = 210
	end
	if name == "corwolv" then
		uDef.speed = 50 --was 48
		uDef.weapondefs.corwolv_gun.weaponvelocity = 400
		uDef.weapondefs.corwolv_gun.mygravity = nil
		uDef.weapondefs.corwolv_gun.range = 730 --710
		uDef.weapondefs.corwolv_gun.areaofeffect = 140 --113
		uDef.weapondefs.corwolv_gun.impulsefactor = 0.7
		uDef.weapondefs.corwolv_gun.damage.default = 320
		uDef.health = 850
	end

	if name == "armmart" then
		uDef.metalcost = 260 --320
		uDef.speed = 48 --was 60
		uDef.weapondefs.arm_artillery.edgeeffectiveness = 0.15
		uDef.weapondefs.arm_artillery.accuracy = 0
		uDef.weapondefs.arm_artillery.reloadtime = 3.4 --3.05
		uDef.weapondefs.arm_artillery.damage.default = 300 --260. DPS 85 -> 91
	end
	if name == "cormart" then
		uDef.metalcost = 320 --400
		uDef.speed = 46 -- was 58
		uDef.weapondefs.cor_artillery.edgeeffectiveness = 0.15
		uDef.weapondefs.cor_artillery.accuracy = 0
		uDef.weapondefs.cor_artillery.reloadtime = 6.4 --5
		uDef.weapondefs.cor_artillery.damage.default = 580 --420. DPS 84 -> 90
	end

	if name == "armsam" then
		uDef.weapondefs.armtruck_missile.flighttime = 1.6
		uDef.weapondefs.armtruck_missile.tracks = true
		uDef.weapondefs.armtruck_missile.turnrate = 10000
		uDef.weapondefs.armtruck_missile.damage.default = 55
		--uDef.weapondefs.armtruck_missile.range = 525
		uDef.weapondefs.armtruck_missile.weaponvelocity = 550
	end
	if name == "cormist" then
		uDef.weapondefs.cortruck_missile.tracks = true
		--uDef.weapondefs.cortruck_missile.range = 550
		uDef.weapondefs.cortruck_missile.turnrate = 10000
		uDef.weapondefs.cortruck_missile.damage.default = 40
		uDef.weapondefs.cortruck_missile.flighttime = 1.6
		uDef.weapondefs.cortruck_missile.weaponvelocity = 550		
	end

	if name == "armjanus" then
		uDef.weapondefs.janus_rocket.edgeeffectiveness = 0.55
		uDef.weapondefs.janus_rocket.impulsefactor = 1
		uDef.speed = 56
		uDef.turnrate = 300
	end

	if name == "armllt" then
		uDef.buildtime = uDef.buildtime - 900
		uDef.health = uDef.health - 180
		uDef.weapondefs.arm_lightlaser.range = uDef.weapondefs.arm_lightlaser.range - 10
		uDef.weapondefs.arm_lightlaser.energypershot = 15		
		uDef.weapondefs.arm_lightlaser.reloadtime = 0.5
	end
	if name == "corllt" then
		uDef.buildtime = uDef.buildtime - 900
		uDef.health = uDef.health - 180
		uDef.weapondefs.cor_lightlaser.range = uDef.weapondefs.cor_lightlaser.range - 10
		uDef.weapondefs.cor_lightlaser.energypershot = 15
		uDef.weapondefs.cor_lightlaser.reloadtime = 0.5
	end
	if name == "corhllt" then
		uDef.health = 1500
		uDef.weapondefs.hllt_bottom.range = 425
		uDef.weapondefs.hllt_bottom.reloadtime = 0.5
		uDef.weapondefs.hllt_top.reloadtime = 0.5
	end
	if name == "armbeamer" then
		uDef.health = 1100
		uDef.weapondefs.armbeamer_weapon.damage.default = 28
	end
	if name == "armclaw" then
		uDef.health = 1600
	end
	if name == "cormaw" then
		uDef.health = 1900
	end
	if name == "corhlt" then
		uDef.weapondefs.cor_laserh1.range = 660
		uDef.health = 2600
	end
	if name == "armhlt" then
		uDef.weapondefs.arm_laserh1.range = 660
		uDef.health = 2400
	end
	if name == "armpb" then
		uDef.weapondefs.armpb_weapon.range = 600
		uDef.weapondefs.armpb_weapon.damage = 
			{
				default = 330,
				vtol = 80,
			}
		uDef.weapondefs.armpb_weapon.reloadtime = 0.8
		--uDef.weapondefs.armpb_weapon.areaofeffect = 36		
		uDef.weapondefs.armpb_weapon.impulsefactor = 1.1
		uDef.weapondefs.armpb_weapon.targetmoveerror = 0
		uDef.metalcost = 470
		uDef.energycost = 7000
		uDef.buildtime = 12000
		uDef.damagemodifier = 0.33
		uDef.health = 2500
	end
	if name == "corvipe" then
		uDef.weapondefs.vipersabot.range = 600
		uDef.weapondefs.vipersabot.areaofeffect = 48
		uDef.weapondefs.vipersabot.targetmoveerror = 0
		uDef.metalcost = 500
		uDef.energycost = 6000
		uDef.buildtime = 12000
		uDef.damagemodifier = 0.33
		uDef.health = 2700
	end

	if name == "armaap" or name == "armalab" or name == "armasy" or name == "armavp"
	or name == "coraap" or name == "coralab" or name == "corasy" or name == "coravp"
	or name == "legaap" or name == "legalab" or name == "legadvshipyard" or name == "legavp"
	then
		uDef.metalcost = uDef.metalcost - 300
		uDef.energycost = uDef.energycost + 7000
	end

	if name == "armap" or name == "armlab" or name == "armsy" or name == "armvp"
	or name == "corap" or name == "corlab" or name == "corsy" or name == "corvp"
	or name == "legap" or name == "leglab" or name == "legsy" or name == "legvp"
	then
		uDef.energycost = uDef.energycost + 150
	end

	if name == "armcom" or name == "corcom" or name == "legcom" then
		uDef.energymake = 50
		uDef.metalmake = 2.5
		uDef.speed = 38
	end

	if name == "armmex" or name == "cormex" or name == "legmex" then
		uDef.energycost = uDef.energycost + 100
	end

	if name == "armck" or name == "corck" or name == "legck" 
	or name == "armcv" or name == "corcv" or name == "legcv" 
	or name == "armca" or name == "corca" or name == "legca" 
	then
		uDef.energycost = uDef.energycost + 200
	end


	return uDef
end

return {
	proposed_unit_reworksTweaks = proposed_unit_reworksTweaks,
}
