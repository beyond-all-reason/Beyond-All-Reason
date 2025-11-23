local function proposed_unit_reworksTweaks(name, uDef)

	if name == "armfhp" or name == "armhp" or name == "corfhp" or name == "corhp"
	then
		uDef.metalcost = uDef.metalcost - 80
		uDef.energycost = uDef.energycost - 750
		uDef.buildtime = uDef.buildtime - 800
	end

	if name == "armap" or name == "corap" 
	then
		uDef.metalcost = uDef.metalcost - 60
		uDef.buildtime = uDef.buildtime - 300
	end

	if name == "armnanotc" or name == "armnanotcplat" 
	or name == "cornanotc" or name == "cornanotcplat"
	then
		uDef.metalcost = 250
		uDef.energycost = 3000
	end

	if name == "armaap" or name == "armalab" or name == "armasy" or name == "armavp"
	or name == "coraap" or name == "coralab" or name == "corasy" or name == "coravp"
	then
		uDef.metalcost = uDef.metalcost - 400
		uDef.buildtime = uDef.buildtime * 1.5
		uDef.workertime = 600
	end
	if name == "coravp"	then --makes corveh same metalcost as other t2 land facs
		uDef.metalcost = uDef.metalcost + 100
	end

	if uDef.canmove and tonumber(uDef.customparams.techlevel) == 2 and uDef.energycost and uDef.metalcost and uDef.buildtime and not (name == "armavp" or name == "coravp" or name == "armalab" or name == "coralab" or name == "armaap" or name == "coraap" or name == "armasy" or name == "corasy" or name == "armfido" or name == "armmav" or name == "armvader" or name == "corroach" ) 
	or uDef.canmove and tonumber(uDef.customparams.techlevel) == 3 and uDef.energycost and uDef.metalcost and uDef.buildtime
	or uDef.customparams.subfolder == "ArmSeaplanes" or uDef.customparams.subfolder == "CorSeaplanes" then
		uDef.buildtime = 1.1* uDef.buildtime + (uDef.metalcost*60 + uDef.energycost) / 20  
		if uDef.buildtime < 20000 then
			uDef.buildtime = math.ceil(uDef.buildtime * 0.002) * 500
		elseif uDef.buildtime < 100000 then
			uDef.buildtime = math.ceil(uDef.buildtime * 0.001) * 1000
		else
			uDef.buildtime = math.ceil(uDef.buildtime * 0.0001) * 10000
		end
	end

	if name == "armadvsol" or name == "coradvsol" then
		uDef.energymake = 80
	end

	if name == "armageo" or name == "corageo" then
		uDef.buildtime = math.ceil(uDef.buildtime * 0.0015) * 1000
	end

	if name == "armfus" then
		uDef.energymake = 750
		uDef.metalcost = 3350
		uDef.energycost = 18000
		uDef.buildtime = 54000
	end

	if name == "corfus" then
		uDef.energymake = 850
		uDef.metalcost = 3600
		uDef.energycost = 22000
		uDef.buildtime = 59000
	end

	if name == "armckfus" then
		uDef.energymake = 750
		uDef.metalcost = 3650
		uDef.energycost = 22000
		uDef.buildtime = 65000
		uDef.cloakcost = 75
	end

	--if name == "armmoho" or name == "armuwmme"
	--or name == "cormoho" or name == "coruwmme"
	--then
		--uDef.metalcost = math.ceil(uDef.metalcost * 0.12) * 10
	--	uDef.energycost = math.ceil(uDef.energycost * 0.012) * 100
	--	uDef.buildtime = math.ceil(uDef.buildtime * 0.0012) * 1000 
	--end

	if name == "armamsub" or name == "coramsub" then
		uDef.workertime = 300
	end

	if name == "armplat" or name == "corplat" then
		uDef.workertime = 300
	end

	if name == "armshltxuw" or name == "armshltx" or name == "corgantuw" or name == "corgant" then
		uDef.workertime = 1800
	end
	
	if name == "corgol" then
		uDef.speed = 39
		uDef.weapondefs.cor_gol.reloadtime = 3.5
	end
	if name == "armfboy" then
		uDef.weapondefs.arm_fatboy_notalaser.edgeeffectiveness = 0.15
		uDef.weapondefs.arm_fatboy_notalaser.areaofeffect = 300
		uDef.energycost = 15000
	end
	--if name == "armmart" then
	--	uDef.weapondefs.arm_artillery.edgeeffectiveness = 0.15
	--	uDef.weapondefs.arm_artillery.accuracy = 0
	--end
	--if name == "cormart" then
	--	uDef.weapondefs.cor_artillery.edgeeffectiveness = 0.15
	--	uDef.weapondefs.cor_artillery.accuracy = 0
	--end
	if name == "cormort" then
		uDef.energycost = 2800
		uDef.metalcost = 400
	end

	if name == "armconsul" or name == "armfark" or name == "corfast" or name == "armmls" or name == "cormls"then
		uDef.metalcost = math.ceil(uDef.metalcost * 1.1 / 5) * 5
	end

	if name == "armspy" or name == "corspy" then
		uDef.buildtime = 12000
	end

	if name == "armbats" or name == "corbats" or name == "corcan" then
		uDef.health = math.ceil(uDef.health * 0.11) * 10
	end

	if name == "corgator" then
		uDef.buildtime = 2300
		uDef.energycost = 1100
		uDef.speed = 85
		uDef.weapondefs.gator_laserx.reloadtime = 0.8
	end

	if name == "armflash" then
		uDef.weapondefs.emgx.weaponvelocity = 600
		uDef.weapondefs.emgx.flighttime = 0.4
	end
	if name == "armpw" then
		uDef.weapondefs.emg.weaponvelocity = 600
		uDef.weapondefs.emg.flighttime = 0.4
	end
	if name == "armfav" then
		uDef.weapondefs.arm_laser.reloadtime = 1
	end
	if name == "corfav" then
		uDef.weapondefs.cor_laser.reloadtime = 1.1
	end
	if name == "corlevlr" then
		uDef.weapondefs.corlevlr_weapon.flighttime = 0.47
	end
	if name == "armkam" then
		uDef.weapondefs.emg.weaponvelocity = 1000
		uDef.weapondefs.emg.areaofeffect = 40
	end

	return uDef
end

return {
	proposed_unit_reworksTweaks = proposed_unit_reworksTweaks,
}
