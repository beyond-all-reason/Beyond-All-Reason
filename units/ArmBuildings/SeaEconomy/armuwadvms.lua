return {
	armuwadvms = {
		buildangle = 5049,
		buildpic = "ARMUWADVMS.DDS",
		buildtime = 20400,
		canrepeat = false,
		category = "CANBEUW",
		collisionvolumeoffsets = "0 0 0",
		collisionvolumescales = "88 38 72",
		collisionvolumetype = "CylY",
		corpse = "DEAD",
		energycost = 11500,
		explodeas = "mediumBuildingexplosiongeneric",
		footprintx = 4,
		footprintz = 4,
		health = 10300,
		idleautoheal = 5,
		idletime = 1800,
		maxslope = 20,
		maxwaterdepth = 9999,
		metalcost = 750,
		metalstorage = 10000,
		objectname = "Units/ARMUWADVMS.s3o",
		script = "Units/ARMUWADVMS.cob",
		seismicsignature = 0,
		selfdestructas = "mediumBuildingExplosionGenericSelfd",
		sightdistance = 195,
		yardmap = "oooooooooooooooo",
		customparams = {
			buildinggrounddecaldecayspeed = 30,
			buildinggrounddecalsizex = 7,
			buildinggrounddecalsizey = 7,
			buildinggrounddecaltype = "decals/armuwadvms_aoplane.dds",
			model_author = "Cremuss",
			normaltex = "unittextures/Arm_normal.dds",
			removestop = true,
			removewait = true,
			subfolder = "ArmBuildings/SeaEconomy",
			techlevel = 2,
			unitgroup = "metal",
			usebuildinggrounddecal = true,
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "7.62939453125e-06 -3.51196289046e-05 -0.0",
				collisionvolumescales = "45.1519927979 49.1111297607 45.1520080566",
				collisionvolumetype = "Box",
				damage = 3720,
				featuredead = "HEAP",
				footprintx = 4,
				footprintz = 4,
				height = 9,
				metal = 458,
				object = "Units/armuwadvms_dead.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				collisionvolumescales = "85.0 14.0 6.0",
				collisionvolumetype = "cylY",
				damage = 1860,
				footprintx = 4,
				footprintz = 4,
				metal = 183,
				object = "Units/arm4X4A.s3o",
				reclaimable = true,
				resurrectable = 0,
			},
		},
		sfxtypes = {
			pieceexplosiongenerators = {
				[1] = "deathceg2",
				[2] = "deathceg3",
				[3] = "deathceg4",
			},
		},
		sounds = {
			canceldestruct = "cancel2",
			underattack = "warning1",
			count = {
				[1] = "count6",
				[2] = "count5",
				[3] = "count4",
				[4] = "count3",
				[5] = "count2",
				[6] = "count1",
			},
			select = {
				[1] = "stormtl1",
			},
		},
	},
}
