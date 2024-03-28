return {
	critter_gull = {
		maxacc = 0.2,
		airstrafe = false,
		bankscale = 1,
		blocking = false,
		maxdec = 3.75,
		energycost = 1,
		metalcost = 0,
		builder = false,
		buildpic = "critters/critter_gull.DDS",
		buildtime = 10,
		canfly = true,
		canguard = true,
		canmove = true,
		canpatrol = true,
		canstop = "1",
		cantbetransported = true,
		capturable = false,
		category = "MOBILE NOTLAND NOTSUB VTOL NOTSHIP NOTHOVER",
		collide = false,
		collision = false,
		cruisealtitude = 200,
		explodeas = "TINYBUG_DEATH",
		footprintx = 1,
		footprintz = 1,
		hoverattack = true,
		idleautoheal = 0,
		mass = 125,
		maxbank = 0.2,
		health = 11,
		maxpitch = 0.2,
		speed = 54.0,
		objectname = "Critters/critter_gull.s3o",
		reclaimable = false,
		script = "Critters/critter_gull.lua",
		seismicsignature = 0,
		selfdestructcountdown = 0,
		sightdistance = 330,
		sonarstealth = true,
		stealth = true,
		turnradius = 5,
		turnrate = 500,
		upright = false,
		customparams = {
			paralyzemultiplier = 0,
			nohealthbars = true,
			subfolder = "other/critters",
		},
		
		
		
		
		weapondefs = {
		
		
		
		
			arm_pidr = {
				areaofeffect = 36,
				avoidfeature = false,
				avoidfriendly = false,
				burnblow = true,
				collidefriendly = false,
				craterareaofeffect = 12,
				craterboost = -0.9,
				cratermult = -0.9,
				edgeeffectiveness = 0.65,
				explosiongenerator = "custom:noexplosion",
				firestarter = 100,
				flighttime = 2,
				impulseboost = 0.123,
				impulsefactor = 2,
				name = "Biological Weaponry",
				noselfdamage = true,
				range = 50,
				rgbcolor = {1.0, 1.0, 1.0},
				reloadtime = 15,
				smoketrail = false,
				soundhit = "splslrg",
				soundhitwet = "splslrg",
				soundstart = "seacry3",
				startvelocity = 140,
				texture1 = "null",
				tolerance = 16000,
				tracks = false,
				turnrate = 32768,
				weaponacceleration = 40,
				weapontype = "MissileLauncher",
				weaponvelocity = 420,
				damage = {
					default = 10,
					subs = 5,
				},
			},
		
		
		
		
		
		
			med_emg = {
				accuracy = 13,
				areaofeffect = 16,
				avoidfeature = false,
				burst = 5,
				burstrate = 0.105,
				burnblow = false,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				duration = 0.035,
				edgeeffectiveness = 0.5,
				explosiongenerator = "blank",
				impulseboost = 0.123,
				impulsefactor = 0.123,
				intensity = 0.8,
				name = "Rapid-fire a2g machine guns",
				noselfdamage = true,
				ownerExpAccWeight = 2.0,
				range = 350,
				reloadtime = 1.47,
				rgbcolor = "1 0.95 0.4",
				--size = 2.25,
				soundhit = "bimpact3",
				soundhitwet = "splshbig",
				soundstart = "mgun3",
				sprayangle = 1024,
				thickness = 0.9,
				tolerance = 6000,
				turret = false,
				weapontype = "LaserCannon",
				weaponvelocity = 800,
				damage = {
					default = 11,
					vtol = 1,
				},
			},
		},
		weapons = {
			[1] = {
				badtargetcategory = "VTOL",
				def = "arm_pidr",
				onlytargetcategory = "SURFACE",
			},
		},
		
		
		
		
		
		
		
		
		
		
		
		
		
		
	},
}
