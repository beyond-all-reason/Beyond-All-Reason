return {
	armsjam = {
		activatewhenbuilt = true,
		buildpic = "ARMSJAM.DDS",
		buildtime = 17000,
		canmove = true,
		collisionvolumeoffsets = "0 0 0",
		collisionvolumescales = "28 32 64",
		collisionvolumetype = "Box",
		corpse = "DEAD",
		energycost = 5000,
		energyupkeep = 90,
		explodeas = "mediumexplosiongeneric",
		floater = true,
		footprintx = 3,
		footprintz = 3,
		health = 1350,
		idleautoheal = 5,
		idletime = 1800,
		maxacc = 0.04059,
		maxdec = 0.04059,
		metalcost = 310,
		minwaterdepth = 6,
		movementclass = "BOAT3",
		nochasecategory = "MOBILE",
		objectname = "Units/ARMSJAM.s3o",
		onoffable = true,
		radardistancejam = 980,
		script = "Units/ARMSJAM.cob",
		seismicsignature = 0,
		selfdestructas = "mediumexplosiongenericSelfd",
		sightdistance = 390,
		speed = 45,
		turninplace = true,
		turninplaceanglelimit = 90,
		turnrate = 405,
		waterline = 0,
		customparams = {
			model_author = "FireStorm",
			normaltex = "unittextures/Arm_normal.dds",
			off_on_stun = "true",
			subfolder = "ArmShips/T2",
			techlevel = 2,
			unitgroup = "util",
		},
		featuredefs = {
			dead = {
				blocking = false,
				category = "corpses",
				collisionvolumeoffsets = "-0.304229736328 -7.05566407078e-07 -0.0",
				collisionvolumescales = "28.1084594727 19.4736785889 64.0",
				collisionvolumetype = "Box",
				damage = 612,
				featuredead = "HEAP",
				footprintx = 4,
				footprintz = 4,
				height = 40,
				metal = 55,
				object = "Units/armsjam_dead.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				collisionvolumescales = "85.0 14.0 6.0",
				collisionvolumetype = "cylY",
				damage = 4032,
				footprintx = 2,
				footprintz = 2,
				height = 4,
				metal = 27.5,
				object = "Units/arm4X4A.s3o",
				reclaimable = true,
				resurrectable = 0,
			},
		},
		sfxtypes = {
			explosiongenerators = {
				[1] = "custom:waterwake-tiny",
			},
			pieceexplosiongenerators = {
				[1] = "deathceg2",
				[2] = "deathceg3",
				[3] = "deathceg4",
			},
		},
		sounds = {
			canceldestruct = "cancel2",
			underattack = "warning1",
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
				[1] = "sharmmov",
			},
			select = {
				[1] = "radjam1",
			},
		},
	},
}
