local function proposed_unit_reworksTweaks(name, uDef)

	if name == "armap" or name == "armlab" or name == "armfhp" or name == "armhp" or name == "armvp"
	or name == "corap" or name == "corlab" or name == "corfhp" or name == "corhp" or name == "corvp"
	then
		uDef.metalcost = math.ceil(uDef.metalcost * 0.08) * 10
		uDef.energycost = math.ceil(uDef.energycost * 0.08) * 10
		uDef.buildtime = math.ceil(uDef.buildtime * 0.008) * 100
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
		uDef.metalcost = uDef.metalcost - 300
		uDef.buildtime = uDef.buildtime * 1.5
		uDef.workertime = uDef.workertime * 2
	end

	if uDef.canmove and tonumber(uDef.customparams.techlevel) == 2 and uDef.energycost and uDef.metalcost and uDef.buildtime and not (name == "armavp" or name == "coravp" or name == "armalab" or name == "coralab" or name == "armaap" or name == "coraap" or name == "armasy" or name == "corasy") 
	or uDef.canmove and tonumber(uDef.customparams.techlevel) == 3 and uDef.energycost and uDef.metalcost and uDef.buildtime
	or uDef.customparams.subfolder == "ArmSeaplanes" or uDef.customparams.subfolder == "ArmSeaplanes" then
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
		uDef.energycost = 17500
		uDef.buildtime = 53800
	end

	if name == "corfus" then
		uDef.energymake = 825
		uDef.metalcost = 3500
		uDef.energycost = 21000
		uDef.buildtime = 58500
	end

	if name == "armckfus" then
		uDef.energymake = 750
		uDef.metalcost = 3650
		uDef.energycost = 21500
		uDef.buildtime = 65000
	end

	if name == "armmoho" or name == "armuwmme"
	or name == "cormoho" or name == "coruwmme"
	then
		--uDef.metalcost = math.ceil(uDef.metalcost * 0.12) * 10
		uDef.energycost = math.ceil(uDef.energycost * 0.012) * 100
		uDef.buildtime = math.ceil(uDef.buildtime * 0.0012) * 1000 
	end

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
		uDef.speed = 37
		uDef.weapondefs.cor_gol.reloadtime = 3.5
	end
	if name == "armfboy" then
		uDef.weapondefs.arm_fatboy_notalaser.edgeeffectiveness = 0.15
	end
	if name == "armmart" then
		uDef.weapondefs.arm_artillery.edgeeffectiveness = 0.15
		uDef.weapondefs.arm_artillery.accuracy = 0
	end
	if name == "cormart" then
		uDef.weapondefs.cor_artillery.edgeeffectiveness = 0.15
		uDef.weapondefs.cor_artillery.accuracy = 0
	end
	if name == "cormort" then
		uDef.energycost = 2800
		uDef.metalcost = 400
	end

	if name == "armrectr" or name == "cornecro" or name == "armconsul" or name == "armfark" or name == "corfast" then
		uDef.metalcost = math.ceil(uDef.metalcost * 1.1 / 5) * 5
	end

	return uDef
end

return {
	proposed_unit_reworksTweaks = proposed_unit_reworksTweaks,
}
