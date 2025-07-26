return {
	legamphlab = {
		maxacc = 0,
		maxdec = 0,
		energycost = 5600,
		metalcost = 1200,
		builder = true,
		buildpic = "legamphlab.DDS",
		buildtime = 11400,
		canmove = true,
		collisionvolumeoffsets = "0 5 0",
		collisionvolumescales = "98 60 91",
		collisionvolumetype = "Box",
		corpse = "DEAD",
		energystorage = 160,
		explodeas = "largeBuildingExplosionGeneric",
		footprintx = 6,
		footprintz = 6,
		idleautoheal = 5,
		idletime = 1800,
		health = 2800,
		maxslope = 10,
		minwaterdepth = 25,
		objectname = "Units/legamphlab.s3o",
		script = "Units/legamphlab.cob",
		seismicsignature = 0,
		selfdestructas = "largeBuildingExplosionGenericSelfd",
		sightdistance = 240,
		terraformspeed = 750,
		workertime = 150,
		yardmap = "oooooo oooooo oeeeeo oeeeeo oeeeeo oeeeeo",
	-- 	yardmap = [[h
    -- oo oo oo oo oo oo
    -- oo oo oo oo oo oo
    -- oo oo oo oo oo oo
    -- oo oo oo oo oo oo
    -- oe ee ee ee ee eo
    -- oe ee ee ee ee eo
    -- oe ee ee ee ee eo
    -- oe ee ee ee ee eo
    -- oe ee ee ee ee eo
    -- oe ee ee ee ee eo
    -- oe ee ee ee ee eo
    -- oe ee ee ee ee eo
    -- ]],
		buildoptions = {
			[1] = "legotter",
			[2] = "legamphtank",
			[3] = "legfloat",
			[4] = "legamph",
			[5] = "legaabot",
			[6] = "legadvaabot",
			[7] = "legdecom",
		},
		customparams = {
			usebuildinggrounddecal = true,
			buildinggrounddecaltype = "decals/legamphlab_aoplane.dds",
			buildinggrounddecalsizey = 9,
			buildinggrounddecalsizex = 9,
			buildinggrounddecaldecayspeed = 30,
			unitgroup = 'builder',
			model_author = "ZephyrSkies, Tharsis",
			normaltex = "unittextures/leg_normal.dds",
			subfolder = "Legion/Labs",
		},
		featuredefs = {
			dead = {
				blocking = false,
				category = "corpses",
				collisionvolumeoffsets = "0 0 0",
				collisionvolumescales = "96 44 89",
				collisionvolumetype = "Box",
				damage = 1500,
				footprintx = 7,
				footprintz = 7,
				height = 5,
				metal = 800,
				object = "Units/legamphlab_dead.s3o",
				reclaimable = true,
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
