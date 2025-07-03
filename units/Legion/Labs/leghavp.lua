return {
	leghavp = {
		maxacc = 0,
		maxdec = 0,
		buildangle = 2048,
		energycost = 3600,
		metalcost = 1440,
		builder = true,
		buildpic = "LEGVP.DDS",
		buildtime = 14400,
		canmove = true,
		collisionvolumeoffsets = "0 19 0",
		collisionvolumescales = "101 53 106",
		collisionvolumetype = "Box",
		corpse = "DEAD",
		energystorage = 200,
		explodeas = "largeBuildingexplosiongeneric",
		footprintx = 6,
		footprintz = 6,
		idleautoheal = 5,
		idletime = 1800,
		levelground = true,
		health = 3000,
		maxslope = 15,
		maxwaterdepth = 0,
		metalstorage = 200,
		objectname = "Units/LEGAMPHLAB.s3o",
		radardistance = 50,
		script = "Units/LEGAMPHLAB.cob",
		seismicsignature = 0,
		selfdestructas = "largeBuildingexplosiongenericSelfd",
		sightdistance = 279,
		terraformspeed = 500,
		workertime = 400,
		yardmap = [[h
    oo oo oo oo oo oo
    oo oo oo oo oo oo
    oo oo oo oo oo oo
    oo oo oo oo oo oo
    oe ee ee ee oo oo
    oe ee ee ee oo oo
    oe ee ee ee oo oo
    oe ee ee ee oo oo
    oe ee ee ee oo oo
    oe ee ee ee oo oo
    oe ee ee ee oo oo
    oe ee ee ee oo oo
    ]],
		buildoptions = {
			[1] = "leghacv",
			[2] = "legotter",
			[3] = "legamphtank",
			[4] = "legmlv",
			[5] = "legmrv",
			[6] = "legfloat",
			[7] = "legaskirmtank",
			[8] = "legamcluster",
			[9] = "legvcarry",
		},
		customparams = {
			usebuildinggrounddecal = true,
			buildinggrounddecaltype = "decals/legamphlab_aoplane.dds",
			buildinggrounddecalsizey = 9,
			buildinggrounddecalsizex = 9,
			buildinggrounddecaldecayspeed = 30,
			unitgroup = 'builder',
			model_author = "Protar/Ghoulish",
			normaltex = "unittextures/leg_normal.dds",
			subfolder = "Legion/Labs",
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "0 -13 0",
				collisionvolumescales = "101 40 106",
				collisionvolumetype = "BOX",
				damage = 1590,
				featuredead = "HEAP",
				footprintx = 6,
				footprintz = 6,
				height = 20,
				metal = 940,
				object = "Units/legamphlab_dead.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				damage = 795,
				footprintx = 6,
				footprintz = 6,
				height = 4,
				metal = 376,
				object = "Units/cor7X7B.s3o",
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
			unitcomplete = "unitready",
			count = {
				[1] = "count6",
				[2] = "count5",
				[3] = "count4",
				[4] = "count3",
				[5] = "count2",
				[6] = "count1",
			},
			select = {
				[1] = "vehplantselect",
			},
		},
	},
}
