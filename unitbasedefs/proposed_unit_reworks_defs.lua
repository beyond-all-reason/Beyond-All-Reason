local function proposed_unit_reworksTweaks(name, uDef)
	if name == "corshiva" then
		uDef.weapondefs.shiva_gun.impulsefactor = 0.8
		uDef.weapondefs.shiva_rocket.impulsefactor = 0.8
	end
	if name == "cortrem" then
		uDef.weapondefs.tremor_spread_fire.impulsefactor = 0.8
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
		uDef.weapondefs.shocker_low.impulsefactor = 0.8
		uDef.weapondefs.shocker_high.impulsefactor = 0.8
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
		uDef.weapondefs.arm_fatboy_notalaser.impulsefactor = 0.8
	end
		
	if name == "corgol" then
		uDef.weapondefs.cor_gol.impulsefactor = 0.8
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
		uDef.weapondefs.exp_heavyrocket.impulsefactor = 0.6
	end
		
	if name == "corban" then
		uDef.weapondefs.banisher.impulsefactor = 0.9
	end
		
	if name == "corparrow" then
		uDef.weapondefs.cor_parrow.impulsefactor = 0.7
	end
		
	if name == "corvroc" then
		uDef.weapondefs.cortruck_rocket.impulsefactor = 0.8
	end
		
	if name == "armmerl" then
		uDef.weapondefs.armtruck_rocket.impulsefactor = 0.8
	end
		
	if name == "corhrk" then
		uDef.weapondefs.corhrk_rocket.impulsefactor = 0.8
	end
		
	if name == "cortoast" then
		uDef.weapondefs.cortoast_gun.impulsefactor = 0.7
	end
		
	if name == "armamb" then
		uDef.weapondefs.armamb_gun.impulsefactor = 0.7
	end

	if name == "corpun" then
		uDef.weapondefs.plasma.impulsefactor = 0.7
	end
		
	if name == "armguard" then
		uDef.weapondefs.plasma.impulsefactor = 0.7
	end

	if name == "corbhmth" then
		uDef.weapondefs.corbhmth_weapon.impulsefactor = 0.8
	end

	if name == "armmine1" or name == "cormine1" then
		uDef.cloakcost = 1
		uDef.metalcost = 7
		uDef.buildtime = 100
	end
	if name == "armmine2" or name == "cormine2" then
		uDef.cloakcost = 2
		uDef.metalcost = 25
		uDef.buildtime = 300
	end
	if name == "armmine3" or name == "cormine3" then
		uDef.cloakcost = 6
		uDef.metalcost = 50
		uDef.energycost = 2800
		uDef.buildtime = 700
	end
	if name == "armfmine3" or name == "corfmine3" then
		uDef.cloakcost = 4
		uDef.metalcost = 32
		uDef.buildtime = 400
	end

	if name == "cormando" then
		uDef.buildoptions = {
			[1] = "corvalk",
			[2] = "corfink",
			[3] = "cormine2",
			[4] = "cormaw",
			[5] = "cordrag",
			[6] = "coreyes",
			[7] = "corjamt",
		}
	end

	if name == "corsktl" then
		uDef.mass = 800
		uDef.cantbetransported = nil
		uDef.script = "Units/CORSKTL2.cob"
		uDef.energycost = 42000
		uDef.cloakcost = 15
		uDef.cloakcostmoving = 40
		uDef.weapondefs.crawl_dummy.cylinderTargeting = 128
		uDef.weapondefs.crawl_dummy.range = 42 
	end


	if name == "corroach" then
		uDef.script = "Units/CORROACH2.cob"
		uDef.weapondefs.crawl_dummy.cylinderTargeting = 128
		uDef.weapondefs.crawl_dummy.range = 42 
		uDef.speed = 76
		uDef.mass = 749
	end
	if name == "armvader" then
		uDef.script = "Units/ARMVADER2.cob"
		uDef.weapondefs.crawl_dummy.cylinderTargeting = 128
		uDef.weapondefs.crawl_dummy.range = 42
		uDef.mass = 749
	end
	
	if uDef.metalcost and uDef.health and uDef.canmove == true and uDef.mass == nil then
		local healthmass = math.ceil(uDef.health/6)
		uDef.mass = math.max(uDef.metalcost, healthmass)
		if uDef.metalcost < healthmass then
			Spring.Echo(name, uDef.mass, uDef.metalcost, uDef.mass - uDef.metalcost)
		end
	end

	if name == "armroy" then
		uDef.weapondefs.depthcharge.turnrate = 9000
	end
	if name == "corroy" then
		uDef.weapondefs.depthcharge.turnrate = 9000
	end

	return uDef
end

return {
	proposed_unit_reworksTweaks = proposed_unit_reworksTweaks,
}
