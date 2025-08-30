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
		uDef.buildtime = uDef.buildtime * 2
		uDef.workertime = uDef.workertime * 2
	end

	if uDef.customparams.techlevel == 2 
	and not (uDef.canfly == 1
	or name == "armaap" or name == "armalab" or name == "armasy" or name == "armavp"
	or name == "coraap" or name == "coralab" or name == "corasy" or name == "coravp")
	then
		uDef.buildtime = math.ceil(uDef.buildtime * 0.012) * 100
	end

	if name == "armadvsol" or name == "coradvsol" then
		uDef.energymake = 80
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

	if name == "armmoho" or name == "armuwmme"
	or name == "cormoho" or name == "coruwmme"
	then
		uDef.metalcost = uDef.metalcost + 120
		uDef.energycost = uDef.energycost + 1620
	end






	return uDef
end

return {
	proposed_unit_reworksTweaks = proposed_unit_reworksTweaks,
}
