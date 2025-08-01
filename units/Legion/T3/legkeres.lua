return {
	legkeres = {
		acceleration = 0.02,
		brakerate = 0.04,
		buildcostenergy = 57000,
		buildcostmetal = 2600,
		buildpic = "LEGKERES.DDS",
		buildtime = 60000,
		canmove = true,
		cantbetransported = true,
		collisionvolumeoffsets = "0 -2 0",
		collisionvolumescales = "52 34 64",
		collisionvolumetype = "Box",
		corpse = "DEAD",
		explodeas = "explosiont3",
		footprintx = 5,
		footprintz = 5,
		idleautoheal = 5,
		idletime = 1800,
		leavetracks = true,
		maxdamage = 21000,
		maxslope = 16,
		speed = 48.0,
		maxwaterdepth = 20,
		movementclass = "HTANK4",
		nochasecategory = "VTOL",
		objectname = "Units/LEGKERES.s3o",
		script = "Units/LEGKERES.cob",
		seismicsignature = 0,
		selfdestructas = "explosiont3xl",
		name = "Keres",
		sightdistance = 650,
		trackoffset = 16,
		trackstrength = 7,
		tracktype = "armacv_tracks",
		trackwidth = 70,
		turninplace = true,
		turninplaceanglelimit = 90,
		turninplacespeedlimit = 1.7,
		turnrate = 220,
		customparams = {
			unitgroup = "weapon",
			normaltex = "unittextures/leg_normal.dds",
			paralyzemultiplier = 0.5,
			model_author = "EnderRobo",
			techlevel = 3,
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "0 0 0",
				collisionvolumescales = "52 30 64",
				collisionvolumetype = "Box",
				damage = 20000,
				featuredead = "HEAP",
				footprintx = 4,
				footprintz = 4,
				height = 25,
				metal = 1500,
				object = "Units/legkeres_dead.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				collisionvolumeoffsets = "-1.01699066162 -0.66435255127 0.0775146484375",
				collisionvolumescales = "23.8865509033 22.2328948975 29.3510131836",
				collisionvolumetype = "Box",
				damage = 8000,
				footprintx = 5,
				footprintz = 5,
				height = 4,
				metal = 800,
				object = "Units/cor4X4C.s3o",
				reclaimable = true,
				resurrectable = 0,
			},
		},
		sfxtypes = {
			explosiongenerators = {
				[1] = "custom:barrelshot-small",
				[2] = "custom:barrelshot-tiny",
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
				[1] = "tcormove",
			},
			select = {
				[1] = "tcorsel",
			},
		},
		weapondefs = {
			legkeres_cannon = {
				areaofeffect = 200,
				avoidfeature = false,
				burnblow = true,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.9,
				explosiongenerator = "custom:genericshellexplosion-large",
				impulsefactor = 2.4,
				name = "Heavy riot cannon",
				noselfdamage = true,
				range = 450,
				reloadtime = 1.7,
				rgbcolor = "1 0.7 0.25",
				soundhit = "xplomed1",
				soundhitwet = "splslrg",
				soundstart = "largegun",
				soundhitvolume = 14,
				soundstartvolume = 13.0,
				separation = 2.0,
				nogap = false,
				size = 4,
				sizeDecay = 0.06,
				stages = 9,
				alphaDecay = 0.10,
				turret = true,
				weapontype = "Cannon",
				weaponvelocity = 650,
				damage = {
					bombers = 50,
					default = 400,
					fighters = 50,
					subs = 150,
					vtol = 50,
				},
			},
			legkeres_gatling = {
				accuracy = 2,
				areaofeffect = 16,
				avoidfeature = false,
				burst = 6,
				burstrate = 0.066,
				burnblow = false,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				duration = 0.038,
				edgeeffectiveness = 0.85,
				explosiongenerator = "custom:plasmahit-sparkonly",
				fallOffRate = 0.2,
				firestarter = 0,
				impulsefactor = 1.5,
				intensity = 0.8,
				name = "Heavy rotary cannon",
				noselfdamage = true,
				ownerExpAccWeight = 4.0,
				proximitypriority = 1,
				range = 481,
				reloadtime = 0.4,
				rgbcolor = "1 0.95 0.4",
				soundhit = "bimpact3",
				soundhitwet = "splshbig",
				soundstart = "mgun6",
				soundstartvolume = 4.5,
				soundtrigger = true,
				sprayangle = 1200,
				texture1 = "shot",
				texture2 = "empty",
				thickness = 2.0,
				tolerance = 6000,
				turret = true,
				weapontype = "LaserCannon",
				weaponvelocity = 900,
				damage = {
					default = 10,
				},
			},
		},
		weapons = {
			[1] = {
				def = "LEGKERES_CANNON",
				onlytargetcategory = "SURFACE",
			},
			[2] = {
				badtargetcategory = "NOTSUB",
				burstcontrolwhenoutofarc = 2,
				def = "LEGKERES_GATLING",
				fastautoretargeting = true,
				onlytargetcategory = "SURFACE",
				slaveTo = 1,
			},
			[3] = {
				badtargetcategory = "NOTSUB",
				burstcontrolwhenoutofarc = 2,
				def = "LEGKERES_GATLING",
				fastautoretargeting = true,
				onlytargetcategory = "SURFACE",
				slaveTo = 1,
			},
		},
	},
}
