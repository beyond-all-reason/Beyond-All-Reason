return {
	corvipe = {
		buildangle = 8192,
		buildpic = "CORVIPE.DDS",
		buildtime = 15000,
		canrepeat = false,
		corpse = "DEAD",
		damagemodifier = 0.5,
		energycost = 14000,
		explodeas = "smallBuildingexplosiongeneric",
		footprintx = 3,
		footprintz = 3,
		health = 3000,
		idleautoheal = 5,
		idletime = 1800,
		maxacc = 0,
		maxdec = 0,
		maxslope = 10,
		maxwaterdepth = 0,
		metalcost = 730,
		nochasecategory = "MOBILE",
		objectname = "Units/CORVIPE.s3o",
		script = "Units/CORVIPE.cob",
		seismicsignature = 0,
		selfdestructas = "smallBuildingExplosionGenericSelfd",
		sightdistance = 546,
		usepiececollisionvolumes = 1,
		yardmap = "ooooooooo",
		customparams = {
			buildinggrounddecaldecayspeed = 30,
			buildinggrounddecalsizex = 4.7,
			buildinggrounddecalsizey = 4.7,
			buildinggrounddecaltype = "decals/corvipe_aoplane.dds",
			model_author = "Mr Bob",
			normaltex = "unittextures/cor_normal.dds",
			subfolder = "CorBuildings/LandDefenceOffence",
			techlevel = 2,
			unitgroup = "weapon",
			usebuildinggrounddecal = true,
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "-2.7282333374 -4.31274414048e-05 -3.87004852295",
				collisionvolumescales = "42.4275054932 38.4097137451 38.8498077393",
				collisionvolumetype = "Box",
				damage = 1631,
				featuredead = "HEAP",
				footprintx = 2,
				footprintz = 2,
				height = 20,
				metal = 380,
				object = "Units/corvipe_dead.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				collisionvolumescales = "35.0 4.0 6.0",
				collisionvolumetype = "cylY",
				damage = 408,
				footprintx = 2,
				footprintz = 2,
				height = 4,
				metal = 61,
				object = "Units/cor2X2F.s3o",
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
			cloak = "kloak2",
			uncloak = "kloak2un",
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
				[1] = "servmed1",
			},
			select = {
				[1] = "servmed1",
			},
		},
		weapondefs = {
			vipersabot = {
				areaofeffect = 24,
				avoidfeature = false,
				castshadow = true,
				cegtag = "missiletrailviper",
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.15,
				explosiongenerator = "custom:genericshellexplosion-medium-bomb",
				firestarter = 70,
				flighttime = 1.05,
				impulsefactor = 0.123,
				model = "cormissile3fast.s3o",
				name = "Heavy g2g sabot rocket launcher",
				noselfdamage = true,
				range = 730,
				reloadtime = 2,
				smokecolor = 0.8,
				smokeperiod = 10,
				smokesize = 10,
				smoketime = 33,
				smoketrail = true,
				smoketrailcastshadow = false,
				soundhit = "SabotHit",
				soundhitwet = "splshbig",
				soundstart = "SabotFire",
				startvelocity = 570,
				targetmoveerror = 0.2,
				texture1 = "null",
				texture2 = "railguntrail",
				tolerance = 8000,
				tracks = true,
				turnrate = 6000,
				turret = true,
				weaponacceleration = 400,
				weapontimer = 0.1,
				weapontype = "MissileLauncher",
				weaponvelocity = 950,
				customparams = {
					exclude_preaim = true,
					overrange_distance = 840,
					projectile_destruction_method = "descend",
				},
				damage = {
					default = 825,
					hvyboats = 577.5,
					subs = 5,
					vtol = 26,
				},
			},
		},
		weapons = {
			[1] = {
				badtargetcategory = "VTOL GROUNDSCOUT",
				def = "VIPERSABOT",
				onlytargetcategory = "SURFACE",
			},
		},
	},
}
