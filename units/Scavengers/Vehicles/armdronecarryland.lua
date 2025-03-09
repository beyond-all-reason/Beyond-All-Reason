return {
	armdronecarryland = {
		maxacc = 0.007,
		activatewhenbuilt = true,
		maxdec = 0.022,
		buildangle = 16384,
		energycost = 12500,
		metalcost = 1250,
		buildpic = "ARMDRONECARRY.DDS",
		buildtime = 20000,
		canmove = true,
		canreclaim = false,
		canrepair = false,
		collisionvolumeoffsets = "0 25 -3",
		collisionvolumescales = "48 57 142",
		collisionvolumetype = "Box",
		corpse = "DEAD",
		energymake = 25,
		energystorage = 1500,
		energyupkeep = 25,
		explodeas = "hugeexplosiongeneric",
		footprintx = 6,
		footprintz = 6,
		idleautoheal = 15,
		idletime = 600,
		sightemitheight = 56,
		mass = 10000,
		health = 3500,
		maxslope = 12,
		speed = 30.0,
		movementclass = "HTANK5",
		nochasecategory = "VTOL",
		objectname = "Units/ARMDRONECARRYLAND.s3o",
		radardistance = 1500,
		radaremitheight = 56,
		script = "Units/ARMDRONECARRYLAND.cob",
		seismicsignature = 0,
		selfdestructas = "hugeexplosiongenericSelfD",
		sightdistance = 700,
		turninplace = true,
		turninplaceanglelimit = 90,
		turninplacespeedlimit = 1.0,
		turnrate = 120,
		customparams = {
			model_author = "Odin",
			normaltex = "unittextures/Arm_normal.dds",
			subfolder = "Scavengers/vehicles",
			techlevel = 3,
			inheritxpratemultiplier = 1,
			childreninheritxp = "DRONE",
			parentsinheritxp = "DRONE",
			disable_when_no_air = true,
		},
		featuredefs = {
			dead = {
				blocking = false,
				category = "corpses",
				collisionvolumeoffsets = "-0.0550308227539 1.52587890767e-06 4.55026245117",
				collisionvolumescales = "61.8225860596 60.9250030518 154.450805664",
				collisionvolumetype = "Box",
				damage = 9168,
				featuredead = "HEAP",
				footprintx = 6,
				footprintz = 6,
				height = 4,
				metal = 700,
				object = "Units/armdronecarry_dead.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				damage = 4032,
				footprintx = 2,
				footprintz = 2,
				height = 4,
				metal = 350,
				object = "Units/arm6X6C.s3o",
				reclaimable = true,
				resurrectable = 0,
			},
		},
		sfxtypes = {
			explosiongenerators = {
				[1] = "custom:radarpulse_t1_slow",
				[2] = "custom:waterwake-large",
				[3] = "custom:bowsplash-huge",
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
				[1] = "sharmsel",
			},
		},
		weapondefs = {
			plasma = {
				areaofeffect = 4,
				avoidfeature = false,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.15,
				explosiongenerator = "",--"custom:genericshellexplosion-medium",
				gravityaffected = "true",
				hightrajectory = 1,
				impulsefactor = 0.123,
				name = "HeavyCannon",
				noselfdamage = true,
				range = 1200,
				reloadtime = 2.5,
				size = 0,
				soundhit = "",--"xplomed2",
				soundhitwet = "",--"splssml",
				soundstart = "",--"cannhvy1",
				turret = true,
				weapontype = "Cannon",
				weaponvelocity = 800,
				damage = {
					default = 0,
				},
				customparams = {
					carried_unit = "armdrone",     --Name of the unit spawned by this carrier unit.
					-- carried_unit2... 			Currently not implemented, but planned.
					engagementrange = 1200,
					--spawns_surface = "SEA",    -- "LAND" or "SEA". The SEA option has not been tested currently.
					spawnrate = 7, 				--Spawnrate roughly in seconds.
					maxunits = 16,				--Will spawn units until this amount has been reached.
					energycost = 750,--650,			--Custom spawn cost. Remove this or set = nil to inherit the cost from the carried_unit unitDef. Cost inheritance is currently not working.
					metalcost = 30,--29,			--Custom spawn cost. Remove this or set = nil to inherit the cost from the carried_unit unitDef. Cost inheritance is currently not working.
					controlradius = 1300,			--The spawned units should stay within this radius. Unfinished behavior may cause exceptions. Planned: radius = 0 to disable radius limit.
					decayrate = 6,
					attackformationspread = 120,	--Used to spread out the drones when attacking from a docked state. Distance between each drone when spreading out.
					attackformationoffset = 30,	--Used to spread out the drones when attacking from a docked state. Distance from the carrier when they start moving directly to the target. Given as a percentage of the distance to the target.
					carrierdeaththroe = "control",
					dockingarmor = 0.2,
					dockinghealrate = 24,
					docktohealthreshold = 50,
					enabledocking = true,		--If enabled, docking behavior is used. Currently docking while moving or stopping, and undocking while attacking. Unfinished behavior may cause exceptions.
					dockingHelperSpeed = 5,
					dockingpieces = "11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27",
					dockingradius = 300,			--The range at which the units snap to the carrier unit when docking.
				}
			},
		},
		weapons = {
			[1] = {
				badtargetcategory = "VTOL",
				def = "PLASMA",
				onlytargetcategory = "SURFACE",
			},
		},
	},
}
