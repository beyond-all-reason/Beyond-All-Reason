local function lateGameRebalanceTweaks(name, unitDef)
	local weapondefs = unitDef.weapondefs

	if name == "armamb" then
		weapondefs.armamb_gun.reloadtime = 2
		weapondefs.armamb_gun_high.reloadtime = 7.7
	end
	if name == "cortoast" then
		weapondefs.cortoast_gun.reloadtime = 2.35
		weapondefs.cortoast_gun_high.reloadtime = 8.8
	end
	if name == "armpb" then
		weapondefs.armpb_weapon.reloadtime = 1.7
		weapondefs.armpb_weapon.range = 700
	end
	if name == "corvipe" then
		weapondefs.vipersabot.reloadtime = 2.1
		weapondefs.vipersabot.range = 700
	end
	if name == "armanni" then
		unitDef.metalcost = 4000
		unitDef.energycost = 85000
		unitDef.buildtime = 59000
	end
	if name == "corbhmth" then
		unitDef.metalcost = 3600
		unitDef.energycost = 40000
		unitDef.buildtime = 70000
	end
	if name == "armbrtha" then
		unitDef.metalcost = 5000
		unitDef.energycost = 71000
		unitDef.buildtime = 94000
	end
	if name == "corint" then
		unitDef.metalcost = 5100
		unitDef.energycost = 74000
		unitDef.buildtime = 103000
	end
	if name == "armvulc" then
		unitDef.metalcost = 75600
		unitDef.energycost = 902400
		unitDef.buildtime = 1680000
	end
	if name == "corbuzz" then
		unitDef.metalcost = 73200
		unitDef.energycost = 861600
		unitDef.buildtime = 1680000
	end
	if name == "armmar" then
		unitDef.metalcost = 1070
		unitDef.energycost = 23000
		unitDef.buildtime = 28700
	end
	if name == "armraz" then
		unitDef.metalcost = 4200
		unitDef.energycost = 75000
		unitDef.buildtime = 97000
	end
	if name == "armthor" then
		unitDef.metalcost = 9450
		unitDef.energycost = 255000
		unitDef.buildtime = 265000
	end
	if name == "corshiva" then
		unitDef.metalcost = 1800
		unitDef.energycost = 26500
		unitDef.buildtime = 35000
		unitDef.speed = 50.8
		weapondefs.shiva_rocket.tracks = true
		weapondefs.shiva_rocket.turnrate = 7500
	end
	if name == "corkarg" then
		unitDef.metalcost = 2625
		unitDef.energycost = 60000
		unitDef.buildtime = 79000
	end
	if name == "cordemon" then
		unitDef.metalcost = 6300
		unitDef.energycost = 94500
		unitDef.buildtime = 94500
	end
	if name == "armstil" then
		unitDef.health = 1300
		weapondefs.stiletto_bomb.burst = 3
		weapondefs.stiletto_bomb.burstrate = 0.2333
		weapondefs.stiletto_bomb.damage = {
			default = 3000
		}
	end
	if name == "armlance" then
		unitDef.health = 1750
	end
	if name == "cortitan" then
		unitDef.health = 1800
	end
	if name == "armyork" then
		weapondefs.mobileflak.reloadtime = 0.8333
	end
	if name == "corsent" then
		weapondefs.mobileflak.reloadtime = 0.8333
	end
	if name == "armaas" then
		weapondefs.mobileflak.reloadtime = 0.8333
	end
	if name == "corarch" then
		weapondefs.mobileflak.reloadtime = 0.8333
	end
	if name == "armflak" then
		weapondefs.armflak_gun.reloadtime = 0.6
	end
	if name == "corflak" then
		weapondefs.armflak_gun.reloadtime = 0.6
	end
	if name == "armmercury" then
		weapondefs.arm_advsam.reloadtime = 11
		weapondefs.arm_advsam.stockpile = false
	end
	if name == "corscreamer" then
		weapondefs.cor_advsam.reloadtime = 11
		weapondefs.cor_advsam.stockpile = false
	end
	if name == "armfig" then
		unitDef.metalcost = 77
		unitDef.energycost = 3100
		unitDef.buildtime = 3700
	end
	if name == "armsfig" then
		unitDef.metalcost = 95
		unitDef.energycost = 4750
		unitDef.buildtime = 5700
	end
	if name == "armhawk" then
		unitDef.metalcost = 155
		unitDef.energycost = 6300
		unitDef.buildtime = 9800
	end
	if name == "corveng" then
		unitDef.metalcost = 77
		unitDef.energycost = 3000
		unitDef.buildtime = 3600
	end
	if name == "corsfig" then
		unitDef.metalcost = 95
		unitDef.energycost = 4850
		unitDef.buildtime = 5400
	end
	if name == "corvamp" then
		unitDef.metalcost = 150
		unitDef.energycost = 5250
		unitDef.buildtime = 9250
	end
end

return {
	Tweaks = lateGameRebalanceTweaks,
}