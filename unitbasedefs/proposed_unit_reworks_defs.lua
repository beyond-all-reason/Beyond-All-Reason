local function proposed_unit_reworksTweaks(name, uDef)

	if tonumber(uDef.customparams.techlevel) == 2 and uDef.energycost and uDef.metalcost and uDef.buildtime and not (name == "armavp" or name == "coravp" or name == "armalab" or name == "coralab" or name == "armaap" or name == "coraap") then
		uDef.energycost = math.ceil((uDef.energycost + (uDef.energycost + uDef.metalcost * 60) * 0.05) * 0.002) * 500
		uDef.buildtime = math.ceil(uDef.buildtime * 0.013 / 5) * 500
	end
	if name == "armmoho" or name == "cormoho" or name == "cormexp" then
		uDef.metalcost = uDef.metalcost + 50
	end
	if name == "armageo" or name == "corageo" then
		uDef.metalcost = uDef.metalcost + 200
	end
	if name == "armavp" or name == "coravp" or name == "armalab" or name == "coralab" or name == "armaap" or name == "coraap" or name == "armasy" or name == "corasy" then
		uDef.metalcost = uDef.metalcost - 1000
		uDef.workertime = 400
	end
	if name == "armvp" or name == "corvp" or name == "armlab" or name == "corlab" or name == "armsy" or name == "corsy"then
		uDef.metalcost = uDef.metalcost - 50
		uDef.buildtime = uDef.buildtime - 1500
		uDef.energycost = uDef.energycost - 280
	end
	if name == "armap" or name == "corap" or name == "armhp" or name == "corhp" or name == "armfhp" or name == "corfhp" then
		uDef.metalcost = uDef.metalcost - 100
		uDef.buildtime = uDef.buildtime - 600
		uDef.energycost = uDef.energycost - 100
	end

	if tonumber(uDef.customparams.techlevel) == 1 and uDef.customparams.subfolder and uDef.buildtime and (uDef.customparams.subfolder == "CorShips" or uDef.customparams.subfolder == "ArmShips") then
		uDef.buildtime = math.ceil(uDef.buildtime * 0.015) * 100
	end

	if name == "armnanotc" or name == "cornanotc" or name == "armnanotcplat" or name == "cornanotcplat" then
		uDef.metalcost = uDef.metalcost + 40
		uDef.corpse = "DEAD"
		uDef.explodeas = "mediumBuildingExplosionGeneric"
		uDef.selfdestructas = "mediumBuildingExplosionGenericSelfd"
		uDef.featuredefs = {
			dead = {
				blocking = false,
				category = "heaps",
				collisionvolumescales = "35.0 4.0 6.0",
				collisionvolumetype = "cylY",
				damage = uDef.health,
				energy = 0,
				featurereclamate = "SMUDGE01",
				footprintx = 2,
				footprintz = 2,
				height = 4,
				hitdensity = 100,
				metal = math.floor(uDef.metalcost*0.6),
				object = "Units/cor2X2C.s3o",
				reclaimable = true,
				resurrectable = 0,
				seqnamereclamate = "TREE1RECLAMATE",
				world = "All Worlds",
			},
		}
	end
	
	if name == "corafus" or  name == "armafus" then
		uDef.metalcost = 12000
		uDef.energycost = 84000
		uDef.buildtime = 240000
	end
	if name == "armacv" or name == "coracv" or name == "armack" or name == "corack" or name == "armaca" or name == "coraca" then
		uDef.workertime = math.ceil(uDef.workertime * 0.13) * 10
	end

	if name == "armshltx" or name == "corgant" or name == "armshltxuw" or name == "corgantuw" then
		uDef.workertime = 2000
	end
	if tonumber(uDef.customparams.techlevel) == 3 and uDef.energycost and uDef.metalcost and uDef.buildtime then
		uDef.energycost = math.ceil((uDef.energycost) * 0.00105) * 1000
		uDef.metalcost = math.ceil(uDef.metalcost * 0.0105) * 100
		uDef.buildtime = math.ceil(uDef.buildtime * 0.0016) * 1000
	end
	return uDef
end

return {
	proposed_unit_reworksTweaks = proposed_unit_reworksTweaks,
}
