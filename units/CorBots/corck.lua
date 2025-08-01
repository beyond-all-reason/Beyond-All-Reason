return {
	corck = {
		builddistance = 130,
		builder = true,
		buildpic = "CORCK.DDS",
		buildtime = 3550,
		canmove = true,
		collisionvolumeoffsets = "0 0 -1",
		collisionvolumescales = "25 31 25",
		collisionvolumetype = "CylY",
		corpse = "DEAD",
		energycost = 1750,
		energymake = 7,
		energystorage = 50,
		explodeas = "smallexplosiongeneric-builder",
		footprintx = 2,
		footprintz = 2,
		health = 750,
		idleautoheal = 5,
		idletime = 1800,
		maxacc = 0.5244,
		maxdec = 3.2775,
		maxslope = 20,
		maxwaterdepth = 25,
		metalcost = 120,
		movementclass = "BOT3",
		objectname = "Units/CORCK.s3o",
		script = "Units/CORCK.cob",
		seismicsignature = 0,
		selfdestructas = "smallExplosionGenericSelfd-builder",
		sightdistance = 299,
		speed = 34.5,
		terraformspeed = 450,
		turninplace = true,
		turninplaceanglelimit = 90,
		turninplacespeedlimit = 0.759,
		turnrate = 1201.75,
		upright = true,
		workertime = 85,
		buildoptions = {
			[1] = "corsolar",
			[2] = "coradvsol",
			[3] = "corwin",
			[4] = "corgeo",
			[5] = "cormstor",
			[6] = "corestor",
			[7] = "cormex",
			[8] = "corexp",
			[9] = "cormakr",
			[10] = "coralab",
			[11] = "corlab",
			[12] = "corvp",
			[13] = "corap",
			[14] = "corhp",
			[15] = "cornanotc",
			[16] = "coreyes",
			[17] = "corrad",
			[18] = "cordrag",
			[19] = "cormaw",
			[20] = "corllt",
			[21] = "corhllt",
			[22] = "corhlt",
			[23] = "corpun",
			[24] = "corrl",
			[25] = "cormadsam",
			[26] = "corerad",
			[27] = "cordl",
			[28] = "corjamt",
			[29] = "corjuno",
			[30] = "corsy",
		},
		customparams = {
			model_author = "Mr Bob",
			normaltex = "unittextures/cor_normal.dds",
			subfolder = "CorBots",
			unitgroup = "builder",
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "0 0 0",
				collisionvolumescales = "30 15 30",
				collisionvolumetype = "Box",
				damage = 454,
				featuredead = "HEAP",
				footprintx = 2,
				footprintz = 2,
				height = 20,
				metal = 73,
				object = "Units/corck_dead.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				collisionvolumescales = "35.0 4.0 6.0",
				collisionvolumetype = "cylY",
				damage = 277,
				footprintx = 2,
				footprintz = 2,
				height = 4,
				metal = 29,
				object = "Units/cor2X2F.s3o",
				reclaimable = true,
				resurrectable = 0,
			},
		},
		sfxtypes = {
			pieceexplosiongenerators = {
				[1] = "deathceg3-builder",
				[2] = "deathceg2-builder",
			},
		},
		sounds = {
			build = "nanlath2",
			canceldestruct = "cancel2",
			capture = "capture2",
			repair = "repair2",
			underattack = "warning1",
			working = "reclaim1",
			cant = {
				[1] = "cantdo4",
			},
			count = {
				[1] = "count6",
				[2] = "count5",
				[3] = "count4",
				[4] = "count3",
				[5] = "count2",
				[6] = "count1",
			},
			ok = {
				[1] = "kbcormov",
			},
			select = {
				[1] = "kbcorsel",
			},
		},
	},
}
