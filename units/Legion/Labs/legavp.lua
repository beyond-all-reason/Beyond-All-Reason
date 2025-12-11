return {
	legavp = {
		maxacc = 0,
		maxdec = 0,
		buildangle = 1024,
		energycost = 16000,
		metalcost = 2800,
		builder = true,
		buildpic = "LEGAVP.DDS",
		buildtime = 18500,
		canmove = true,
		collisionvolumeoffsets = "0 0 5",
		collisionvolumescales = "144 70 144",
		collisionvolumetype = "Box",
		corpse = "DEAD",
		energystorage = 200,
		explodeas = "largeBuildingexplosiongeneric",
		footprintx = 9,
		footprintz = 9,
		idleautoheal = 5,
		idletime = 1800,
		levelground = false,
		health = 5100,
		maxslope = 15,
		maxwaterdepth = 0,
		metalstorage = 200,
		objectname = "Units/LEGAVP.s3o",
		radardistance = 50,
		script = "Units/LEGAVP.cob",
		seismicsignature = 0,
		selfdestructas = "largeBuildingExplosionGenericSelfd",
		sightdistance = 286,
		terraformspeed = 1000,
		workertime = 300,
		yardmap = [[h
        oo oo oo oo oo oo oo oo oo
        oo oo oo oo oo oo oo oo oo
        oo oo oo oo oo oo oo oo oo
        oo oo oo oo oo oo oo oo oo
        oo oo oo oo oo oo oo oo oo
        oo oo oo oo oo oo oo oo oo
        oo oo oo oo oo oo oo oo oo
        oo oo oo oo oo oo oo oo oo
        oo oo oo oo oo oo oo oo oo
        oo oo oe ee ee ee eo oo oo
        oo oo oe ee ee ee eo oo oo
        oo oo oe ee ee ee eo oo oo
        oo oo oe ee ee ee eo oo oo
        oo oo oe ee ee ee eo oo oo
        oo oo oe ee ee ee eo oo oo
        oo oo oe ee ee ee eo oo oo
        oo oo oe ee ee ee eo oo oo
        oo oo oe ee ee ee eo oo oo
        ]],
		buildoptions = {
			"legacv",
			"legmrv",
			"legaskirmtank",
			"legfloat",
			"legaheattank",
			"legmed",
			"legamcluster",
			"legvcarry",
			"legavroc",
			"leginf",
			"legvflak",
			"cormabm",
			"legavjam",
			"legavrad",
			"legafcv"
		},
		customparams = {
			usebuildinggrounddecal = false,
			buildinggrounddecaltype = "decals/legavp_aoplane.dds",
			buildinggrounddecalsizey = 12,
			buildinggrounddecalsizex = 12,
			buildinggrounddecaldecayspeed = 0.01,
			unitgroup = 'buildert2',
			model_author = "ZephyrSkies",
			normaltex = "unittextures/leg_normal.dds",
			subfolder = "Legion/Labs",
			techlevel = 2,
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "0 0 5",
				collisionvolumescales = "144 70 144",
				collisionvolumetype = "Box",
				damage = 2777,
				featuredead = "HEAP",
				footprintx = 6,
				footprintz = 6,
				height = 20,
				metal = 1721,
				object = "Units/legavp_dead.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				damage = 1389,
				footprintx = 6,
				footprintz = 6,
				height = 4,
				metal = 860,
				object = "Units/cor6X6C.s3o",
				reclaimable = true,
				resurrectable = 0,
			},
		},
		sfxtypes = {
			explosiongenerators = {
				[1] = "custom:WhiteLight",
			},
			pieceexplosiongenerators = {
				[1] = "deathceg3",
				[2] = "deathceg4",
			},
		},
		sounds = {
			canceldestruct = "cancel2",
			underattack = "warning1",
			unitcomplete = "untdone",
			count = {
				[1] = "count6",
				[2] = "count5",
				[3] = "count4",
				[4] = "count3",
				[5] = "count2",
				[6] = "count1",
			},
			select = {
				[1] = "pvehactv",
			},
		},
	},
}
