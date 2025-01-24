local function proposed_unit_reworksTweaks(name, uDef)

		
		if name == "armsolar" then
			uDef.buildtime = 2600
		end
		if name == "armwin" then
			uDef.metalcost = 40
		end
		if name == "corwin" then
			uDef.metalcost = 43
			uDef.health = 220
		end
		if name == "armtide" then
			uDef.energycost = 200
		end
		if name == "armadvsol" then
			uDef.metalcost = 350
		end
		if name == "corcv" then
			uDef.workertime = 95
		end
		if name == "corca" then
			uDef.workertime = 65
		end
		if name == "corck" then
			uDef.workertime = 85
		end
		if name == "cormuskrat" then
			uDef.workertime = 85
		end
		if name == "coracv" then
			uDef.workertime = 265
		end
		if name == "corack" then
			uDef.workertime = 190
		end
		if name == "coraca" then
			uDef.workertime = 105
		end
		if name == "corch" then
			uDef.workertime = 115
		end
		if name == "corexp" then
			uDef.buildtime = 2900
		end



		if name == "corgator" then
			uDef.buildtime = 2200
			uDef.sightdistance = 330
		end
		if name == "armflash" then
			uDef.sightdistance = 350
			uDef.health = 725
		end
		if name == "armflea" then
			uDef.metalcost = 20
			uDef.energycost = 300
			uDef.sightdistance = 500
		end
		if name == "armpw" then
			uDef.metalcost = 54
			uDef.energycost = 870
			uDef.health = 370
		end
		if name == "corak" then
			uDef.metalcost = 48
			uDef.energycost = 840
			uDef.turnrate = 1200
			uDef.maxacc = 0.4
			uDef.maxdec = 0.7
			--uDef.health = 300
		end
		if name == "armfav" then
			uDef.health = 103
		end
		if name == "corfav" then
			uDef.health = 87
		end

		if name == "corbw" then
			uDef.weapondefs.bladewing_lyzer.reloadtime = 1.4
		end
		if name == "armkam" then
			uDef.health = 560
		end
		if name == "armthund" then
			uDef.weapondefs.armbomb.burstrate = 0.25
		end

	return uDef
end

return {
	proposed_unit_reworksTweaks = proposed_unit_reworksTweaks,
}
