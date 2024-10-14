local function proposed_unit_reworksTweaks(name, uDef)
	if name == "corshiva" then
		uDef.weapondefs.shiva_gun.impulsefactor = 1
		uDef.weapondefs.shiva_rocket.impulsefactor = 1
	end
	if name == "cortrem" then
		uDef.weapondefs.tremor_spread_fire.impulsefactor = 1
		uDef.weapondefs.tremor_spread_fire.edgeeffectiveness = 0.15
	end
		
	if name == "armbrtha" then
		uDef.weapondefs.lrpc.impulsefactor = 1
		uDef.weapondefs.lrpc.model = nil
		uDef.weapondefs.lrpc.name = "Long-range plasma cannon"
	end
			
	if name == "corint" then
		uDef.weapondefs.lrpc.impulsefactor = 1
		uDef.weapondefs.lrpc.model = nil
		uDef.weapondefs.lrpc.name = "Long-range plasma cannon"
	end
		
	if name == "armvang" then
		uDef.weapondefs.shocker_low.impulsefactor = 1
		uDef.weapondefs.shocker_high.impulsefactor = 1
	end
		
	if name == "armvulc" then
		uDef.weapondefs.rflrpc.impulsefactor = 1
		uDef.weapondefs.rflrpc.areaofeffect = 135
		uDef.weapondefs.rflrpc.edgeeffectiveness = 0.15
		uDef.weapondefs.rflrpc.reloadtime = 0.6
		uDef.weapondefs.rflrpc.energypershot = 15000
		uDef.weapondefs.rflrpc.name = "Rapid-fire long-range plasma cannon"
		uDef.weapondefs.rflrpc.damage = {
			default = 1625,
			shields = 812,
			subs = 500,
		}
	end
		
	if name == "corbuzz" then
		uDef.weapondefs.rflrpc.impulsefactor = 1
		uDef.weapondefs.rflrpc.areaofeffect = 157
		uDef.weapondefs.rflrpc.edgeeffectiveness = 0.15
		uDef.weapondefs.rflrpc.reloadtime = 0.75
		uDef.weapondefs.rflrpc.energypershot = 18000
		uDef.weapondefs.rflrpc.name = "Rapid-fire long-range plasma cannon"
		uDef.weapondefs.rflrpc.damage = {
			default = 2000,
			shields = 1000,
			subs = 600,
		}
	end
		
	if name == "armfboy" then
		uDef.weapondefs.arm_fatboy_notalaser.impulsefactor = 1
	end
		
	if name == "corgol" then
		uDef.weapondefs.cor_gol.impulsefactor = 1
	end
	if name == "armmav" then
		uDef.weapondefs.armmav_weapon.impulsefactor = 1
	end
		
	if name == "armsilo" then
		uDef.weapondefs.nuclear_missile.impulsefactor = 1
	end
		
	if name == "corsilo" then
		uDef.weapondefs.crblmssl.impulsefactor = 1
	end
	if name == "cortron" then
		uDef.weapondefs.cortron_weapon.impulsefactor = 1
	end
		
	if name == "corcat" then
		uDef.weapondefs.exp_heavyrocket.impulsefactor = 1
	end
		
	if name == "corban" then
		uDef.weapondefs.banisher.impulsefactor = 1
	end
		
	if name == "corparrow" then
		uDef.weapondefs.cor_parrow.impulsefactor = 1
	end
		
	if name == "corvroc" then
		uDef.weapondefs.cortruck_rocket.impulsefactor = 1
	end
		
	if name == "armmerl" then
		uDef.weapondefs.armtruck_rocket.impulsefactor = 1
	end
		
	if name == "corhrk" then
		uDef.weapondefs.corhrk_rocket.impulsefactor = 1
	end
		
	if name == "cortoast" then
		uDef.weapondefs.cortoast_gun.impulsefactor = 1
	end
		
	if name == "armamb" then
		uDef.weapondefs.armamb_gun.impulsefactor = 1
	end
	if name == "corpun" then
		uDef.weapondefs.plasma.impulsefactor = 1
	end
		
	if name == "armguard" then
		uDef.weapondefs.plasma.impulsefactor = 1
	end

	if name == "corbhmth" then
		uDef.weapondefs.corbhmth_weapon.impulsefactor = 1
	end

	return uDef
end

return {
	proposed_unit_reworksTweaks = proposed_unit_reworksTweaks,
}
