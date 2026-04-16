local function factoryCostsTest(name, unitDef)
	if name == "armmoho" or name == "cormoho" or name == "cormexp" then
		unitDef.metalcost = unitDef.metalcost + 50
		unitDef.energycost = unitDef.energycost + 2000
	end
	if name == "armageo" or name == "corageo" then
		unitDef.metalcost = unitDef.metalcost + 100
		unitDef.energycost = unitDef.energycost + 4000
	end
	if name == "armavp" or name == "coravp" or name == "armalab" or name == "coralab" or name == "armaap" or name == "coraap" or name == "armasy" or name == "corasy" then
		unitDef.metalcost = unitDef.metalcost - 1000
		unitDef.workertime = 600
		unitDef.buildtime = unitDef.buildtime * 2
	end
	if name == "armvp" or name == "corvp" or name == "armlab" or name == "corlab" or name == "armsy" or name == "corsy" then
		unitDef.metalcost = unitDef.metalcost - 50
		unitDef.buildtime = unitDef.buildtime - 1500
		unitDef.energycost = unitDef.energycost - 280
	end
	if name == "armap" or name == "corap" or name == "armhp" or name == "corhp" or name == "armfhp" or name == "corfhp" or name == "armplat" or name == "corplat" then
		unitDef.metalcost = unitDef.metalcost - 100
		unitDef.buildtime = unitDef.buildtime - 600
		unitDef.energycost = unitDef.energycost - 100
	end
	if name == "armshltx" or name == "corgant" or name == "armshltxuw" or name == "corgantuw" then
		unitDef.workertime = 2000
		unitDef.buildtime = unitDef.buildtime * 1.33
	end

	local customparams = unitDef.customparams

	if tonumber(customparams.techlevel) == 2 and unitDef.energycost and unitDef.metalcost and unitDef.buildtime and not (name == "armavp" or name == "coravp" or name == "armalab" or name == "coralab" or name == "armaap" or name == "coraap" or name == "armasy" or name == "corasy") then
		unitDef.buildtime = math.ceil(unitDef.buildtime * 0.015 / 5) * 500
	end
	if tonumber(customparams.techlevel) == 3 and unitDef.energycost and unitDef.metalcost and unitDef.buildtime then
		unitDef.buildtime = math.ceil(unitDef.buildtime * 0.0015) * 1000
	end

	if name == "armnanotc" or name == "cornanotc" or name == "armnanotcplat" or name == "cornanotcplat" then
		unitDef.metalcost = unitDef.metalcost + 40
	end
end

return {
	Tweaks = factoryCostsTest,
}