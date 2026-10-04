local function skyshiftUnitTweaks(name, uDef)

---------------------------------------------
			--------------------
			---ARMADA AIR T1 ---
			--------------------
---------------------------------------------
	if name == "armca" then
		uDef.health = 720
	end

	if name == "armpeep" then
		uDef.acceleration = 0.8
		uDef.blocking = false
		uDef.maxdec = 0.8
		uDef.energycost = 1550
		uDef.metalcost = 52
		uDef.buildpic = "ARMPEEP.DDS"
		uDef.buildtime = 2800
		uDef.canfly = true
		uDef.canmove = true
		uDef.category = "ALL MOBILE NOTLAND NOTSUB VTOL NOWEAPON NOTSHIP NOTHOVER LIGHTAIRSCOUT"
		uDef.collide = false
		uDef.cruisealtitude = 280
		uDef.explodeas = "tinyExplosionGeneric"
		uDef.footprintx = 2
		uDef.footprintz = 2
		uDef.idleautoheal = 5
		uDef.idletime = 1800
		uDef.maxacc = 0.8
		uDef.maxaileron = 0.03
		uDef.maxbank = 0.9
		uDef.health = 89
		uDef.maxelevator = 0.01065
		uDef.maxpitch = 0.625
		uDef.maxrudder = 0.025
		uDef.maxslope = 10
		uDef.speed = 200.0
		uDef.maxwaterdepth = 0
		uDef.objectname = "Units/ARMPEEP.s3o"
		uDef.radardistance = 2850
		uDef.script = "Units/ARMPEEP.cob"
		uDef.seismicsignature = 0
		uDef.selfdestructas = "tinyExplosionGenericSelfd"
		uDef.selfdestructcountdown = 1
		uDef.sightdistance = 1200
		uDef.speedtofront = 0.06417
		uDef.turnradius = 2
		uDef.turnrate = 1500
		uDef.usesmoothmesh = true
		uDef.wingangle = 0.06315
		uDef.wingdrag = 0.0575
	end

	if name == "armfig" then
		uDef.acceleration = 0.6
		uDef.airsightdistance = 950
		uDef.airstrafe = false
		uDef.blocking = false
		uDef.maxdec = 0.4
		uDef.buildcostenergy = 1100
		uDef.buildcostmetal = 95
		uDef.buildpic = "ARMFIG.DDS"
		uDef.buildtime = 3500
		uDef.canfly = true
		uDef.canmove = true
		uDef.category = "ALL MOBILE WEAPON NOTSUB NOTLAND VTOL NOTSHIP NOTHOVER EMPABLE"
		uDef.collide = true
		uDef.cruisealtitude = 150
		uDef.explodeas = "smallExplosionGenericAir"
		uDef.footprintx = 2
		uDef.footprintz = 2
		uDef.health = 370
		uDef.hoverattack = false
		uDef.maxacc = 0.8
		uDef.maxaileron = 0.03
		uDef.maxbank = 0.9
		uDef.maxelevator = 0.05
		uDef.maxpitch = 0.625
		uDef.maxrudder = 0.012
		uDef.maxslope = 10
		uDef.speed = 315
		uDef.maxwaterdepth = 0
		uDef.nochasecategory = "NOTAIR"
		uDef.objectname = "Units/ARMFIG.s3o"
		uDef.script = "Units/ARMFIG.cob"
		uDef.seismicsignature = 0
		uDef.selfdestructas = "smallExplosionGenericAir"
		uDef.sightdistance = 350
		uDef.speedtofront = 0.08
		uDef.turnradius = 5
		uDef.turnrate = 850
		uDef.usesmoothmesh = true
		uDef.wingangle = 0.06315
		uDef.wingdrag = 0.185
		uDef.weapondefs = {
		emg = {
				areaofeffect = 2,
				avoidfeature = false,
				avoidfriendly = true,
				burst = 6,
				burstrate = 0.08,
				canattackground = false,
				collidefriendly = false,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				cylindertargeting = 10,
				edgeeffectiveness = 0,
				explosiongenerator = "custom:plasmahit-small",
				firestarter = 0,
				impulseboost = 0.123,
				impulsefactor = 0.123,
				metalpershot = 0,
				name = "Rapid-fire close-quarters g2g plasma guns",
				noselfdamage = true,
				range = 240,
				reloadtime = 0.5,
				rgbcolor = "1 0.95 0.4",
				size = 1.75,
				soundhitwet = "splshbig",
				soundstart = "flashemg",
				sprayangle = 900,
				tolerance = 60000,
				turret = true,
				weapontype = "Cannon",
				weaponvelocity = 500,
				damage = {
					default = 7,
				},
			},
		}
		uDef.weapons = {
			[1] = {
				badtargetcategory = "NOTAIR",
				def = "EMG",
				onlytargetcategory = "VTOL",
			},
		}
	end

	if name == "armthund" then
		uDef.acceleration = 0.3
		uDef.maxdec = 0.3
		uDef.energycost = 2400
		uDef.metalcost = 220
		uDef.buildpic = "ARMTHUND.DDS"
		uDef.buildtime = 4780
		uDef.canfly = true
		uDef.canmove = true
		uDef.category = "ALL MOBILE WEAPON NOTLAND NOTSUB VTOL NOTSHIP NOTHOVER EMPABLE"
		uDef.collide = false
		uDef.cruisealtitude = 210
		uDef.explodeas = "mediumexplosiongeneric"
		uDef.footprintx = 3
		uDef.footprintz = 3
		uDef.idleautoheal = 5
		uDef.idletime = 1800
		uDef.maxacc = 0.7
		uDef.maxaileron = 0.02
		uDef.maxbank = 0.9
		uDef.health = 2160
		uDef.maxelevator = 0.015
		uDef.maxpitch = 0.14
		uDef.maxrudder = 0.02
		uDef.maxslope = 10
		uDef.speed = 175
		uDef.maxwaterdepth = 0
		uDef.noautofire = true
		uDef.nochasecategory = "MOBILE"
		uDef.objectname = "Units/ARMTHUND.s3o"
		uDef.script = "Units/ARMTHUND.cob"
		uDef.seismicsignature = 0
		uDef.selfdestructas = "mediumExplosionGenericSelfd"
		uDef.sightdistance = 195
		uDef.speedtofront = 0.07
		uDef.turnradius = 4
		uDef.turnrate = 800
		uDef.usesmoothmesh = true
		uDef.wingangle = 0.06315
		uDef.wingdrag = 0.135
		uDef.weapondefs = {
			armbomb = {
				accuracy = 500,
				areaofeffect = 110,
				avoidfeature = false,
				burst = 9,
				burstrate = 0.35,
				collidefriendly = false,
				commandfire = true,
				craterboost = 0,
				cratermult = 0,
				craterareaofeffect = 110,
				edgeeffectiveness = 0.55,
				explosiongenerator = "custom:genericshellexplosion-medium-bomb",
				gravityaffected = "true",
				impulseboost = 0.5,
				impulsefactor = 0.5,
				model = "airbomb.s3o",
				name = "Light a2g impulse warheads",
				noselfdamage = true,
				range = 1000,
				reloadtime = 10,
				soundhit = "bombssml1",
				soundhitwet = "splsmed",
				soundstart = "bombrel",
				sprayangle = 7000,
				tolerance = 100000,
				turret = true,
				weaponType = "AircraftBomb",
				damage = {
					default = 75,
				},
			},
		}
		uDef.weapons = {
			[1] = {
				def = "ARMBOMB",
				onlytargetcategory = "NOTSUB",
			},
		}
	end

	if name == "armkam" then
		uDef.acceleration = 0.7
		uDef.airstrafe = false
		uDef.blocking = false
		uDef.energycost = 2600
		uDef.metalcost = 240
		uDef.buildpic = "ARMKAM.DDS"
		uDef.buildtime = 5050
		uDef.canfly = true
		uDef.canmove = true
		uDef.category = "ALL WEAPON NOTSUB VTOL NOTHOVER EMPABLE"
		uDef.collide = true
		uDef.cruisealtitude = 150
		uDef.explodeas = "smallExplosionGeneric"
		uDef.footprintx = 2
		uDef.footprintz = 2
		uDef.hoverattack = false
		uDef.idleautoheal = 5
		uDef.idletime = 1800
		uDef.health = 1320
		uDef.maxacc = 0.065
		uDef.maxbank = 0.8
		uDef.maxdec = 0.5
		uDef.maxslope = 10
		uDef.maxpitch = 0.45
		uDef.maxrudder = 0.014
		uDef.maxwaterdepth = 0
		uDef.speed = 220
		uDef.nochasecategory = "NOTAIR"
		uDef.objectname = "Units/ARMKAM.s3o"
		uDef.script = "Units/ARMKAM.cob"
		uDef.seismicsignature = 0
		uDef.selfdestructas = "smallExplosionGenericSelfd"
		uDef.sightdistance = 520
		uDef.turninplaceanglelimit = 360
		uDef.turnradius = 5
		uDef.turnrate = 300
		uDef.weapondefs = {
			med_emg = {
				accuracy = 13,
				areaofeffect = 280,
				avoidfeature = false,
				avoidfriendly = false,
				burst = 2,
				burstrate = 0.05,
				burnblow = true,
				collidefriendly = false,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				dance = 75,
				edgeeffectiveness = 0.5,
				explosiongenerator = "custom:flak",
				flightTime = 2.8,
				impulseboost = 0.123,
				impulsefactor = 0.123,
				intensity = 0.8,
				model = "cormissile.s3o",
				name = "Rapid-fire a2g machine guns",
				noselfdamage = true,
				ownerExpAccWeight = 2.0,
				range = 900,
				reloadtime = 2.5,
				smokePeriod = 4,
				smoketime = 16,
				smoketrail = true,
				smokesize = 1.8,
				smokecolor = 0.55,
				soundhit = "flakhit2",
				soundhitwet = "splshbig",
				soundstart = "rocklit1",
				sprayangle = 10000,
				texture1 = "null",
				texture2 = "smoketrail",
				tracks = true,
				tolerance = 10000,
				turnrate = 5000,
				turret = true,
				weaponacceleration = 250,
				weapontype = "MissileLauncher",
				weaponvelocity = 500,
				wobble = 75,
				damage = {
					default = 1,
					vtol = 110,
				},
			},
		}
		uDef.weapons = {
			[1] = {
				badtargetcategory = "NOTAIR",
				def = "med_emg",
				onlytargetcategory = "VTOL",
			},
		}
	end

	if name == "armsfig" then
		uDef.acceleration = 0.35
		uDef.airsightdistance = 950
		uDef.airstrafe = false
		uDef.blocking = false
		uDef.maxdec = 0.1
		uDef.energycost = 440
		uDef.metalcost = 40
		uDef.buildpic = "ARMSFIG.DDS"
		uDef.buildtime = 5500
		uDef.canfly = true
		uDef.canmove = true
		uDef.cansubmerge = true
		uDef.category = "ALL NOTLAND MOBILE WEAPON NOTSUB VTOL NOTSHIP NOTHOVER EMPABLE"
		uDef.collide = false
		uDef.cruisealtitude = 35
		uDef.explodeas = "smallExplosionGenericAir"
		uDef.footprintx = 2
		uDef.footprintz = 2
		uDef.maxacc = 0.2075
		uDef.maxaileron = 0.01403
		uDef.maxbank = 0.8
		uDef.health = 75
		uDef.maxelevator = 0.01028
		uDef.maxpitch = 0.625
		uDef.maxrudder = 0.00578
		uDef.maxslope = 10
		uDef.maxwaterdepth = 0
		uDef.speed = 340
		uDef.objectname = "Units/ARMSFIG.s3o"
		uDef.script = "Units/ARMSFIG.cob"
		uDef.seismicsignature = 0
		uDef.selfdestructas = "smallExplosionGenericAir"
		uDef.sightdistance = 230
		uDef.speedtofront = 0.07
		uDef.turnradius = 55
		uDef.turnrate = 750
		uDef.usesmoothmesh = true
		uDef.wingangle = 0.06278
		uDef.wingdrag = 0.235
		uDef.weapondefs = {
			arm_laser = {
				accuracy = 16,
				areaofeffect = 16,
				avoidfeature = false,
				burnblow = false,
				burst = 2,
				burstrate = 0.2,
				collidefriendly = false,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				duration = 0.035,
				edgeeffectiveness = 0.5,
				explosiongenerator = "blank",
				impulseboost = 0.123,
				impulsefactor = 0.123,
				intensity = 0.8,
				name = "Rapid-fire machine guns",
				noselfdamage = true,
				ownerExpAccWeight = 2.0,
				range = 195,
				reloadtime = 1.2,
				rgbcolor = "0.95 0.45 0.08",
				soundhit = "bimpact3",
				soundhitwet = "splshbig",
				soundstart = "lasrfir1",
				thickness = 0.9,
				tolerance = 12000,
				turret = true,
				weapontype = "LaserCannon",
				weaponvelocity = 800,
				damage = {
					default = 12,
				},
			},
		}
		uDef.weapons = {
			[1] = {
				def = "ARM_LASER",
				onlytargetcategory = "NOTSUB",
			},
		}
	end

---------------------------------------------
			--------------------
			---ARMADA AIR T2 ---
			--------------------
---------------------------------------------




---------------------------------------------
			--------------------
			---CORTEX AIR T1 ---
			--------------------
---------------------------------------------


	if name == "corfink" then
		uDef.acceleration = 0.6
		uDef.blocking = false
		uDef.maxdec = 0.6
		uDef.energycost = 1450
		uDef.metalcost = 51
		uDef.buildpic = "CORFINK.DDS"
		uDef.buildtime = 2400
		uDef.canfly = true
		uDef.canmove = true
		uDef.category = "ALL MOBILE NOTLAND NOTSUB VTOL NOWEAPON NOTSHIP NOTHOVER LIGHTAIRSCOUT"
		uDef.collide = false
		uDef.cruisealtitude = 280
		uDef.explodeas = "tinyExplosionGeneric"
		uDef.footprintx = 2
		uDef.footprintz = 2
		uDef.idleautoheal = 5
		uDef.idletime = 1800
		uDef.maxacc = 0.8
		uDef.maxaileron = 0.0144
		uDef.maxbank = 0.9
		uDef.health = 100
		uDef.maxelevator = 0.01065
		uDef.maxpitch = 0.625
		uDef.maxrudder = 0.025
		uDef.maxslope = 10
		uDef.speed = 205.0
		uDef.maxwaterdepth = 0
		uDef.objectname = "Units/CORFINK.s3o"
		uDef.radardistance = 2800
		uDef.script = "Units/CORFINK.cob"
		uDef.seismicsignature = 0
		uDef.selfdestructas = "tinyExplosionGenericSelfd"
		uDef.selfdestructcountdown = 1
		uDef.sightdistance = 1200
		uDef.speedtofront = 0.06125
		uDef.turnradius = 2
		uDef.turnrate = 1500
		uDef.usesmoothmesh = true
		uDef.wingangle = 0.06315
		uDef.wingdrag = 0.06
	end

	if name == "corca" then
		uDef.health = 720
	end

	if name == "corveng" then
		uDef.acceleration = 0.45
		uDef.airsightdistance = 950
		uDef.airstrafe = false
		uDef.blocking = false
		uDef.maxdec = 0.45
		uDef.energycost = 1100
		uDef.metalcost = 80
		uDef.buildpic = "CORVENG.DDS"
		uDef.buildtime = 3330
		uDef.canfly = true
		uDef.canmove = true
		uDef.category = "ALL MOBILE WEAPON VTOL NOTLAND NOTSUB NOTSHIP NOTHOVER"
		uDef.collide = false
		uDef.cruisealtitude = 150
		uDef.explodeas = "smallExplosionGenericAir"
		uDef.footprintx = 2
		uDef.footprintz = 2
		uDef.health = 345
		uDef.hoverattack = false
		uDef.maxacc = 0.8
		uDef.maxaileron = 0.03
		uDef.maxbank = 0.9
		uDef.maxelevator = 0.05
		uDef.maxpitch = 0.625
		uDef.maxrudder = 0.012
		uDef.maxslope = 10
		uDef.speed = 305
		uDef.maxwaterdepth = 0
		uDef.nochasecategory = "NOTAIR"
		uDef.objectname = "Units/CORVENG.s3o"
		uDef.script = "Units/CORVENG.cob"
		uDef.seismicsignature = 0
		uDef.selfdestructas = "smallExplosionGenericAir"
		uDef.sightdistance = 210
		uDef.speedtofront = 0.08
		uDef.turnradius = 20
		uDef.turnrate = 600
		uDef.usesmoothmesh = true
		uDef.wingangle = 0.06315
		uDef.wingdrag = 0.165
		uDef.weapondefs = {
			gator_laser = {
				areaofeffect = 2,
				avoidfeature = false,
				avoidfriendly = true,
				beamtime = 0.1,
				beamtt1 = 1,
				canattackground = false,
				corethickness = 0.18,
				collidefriendly = false,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.15,
				explosiongenerator = "custom:laserhit-small-red",
				firestarter = 0,
				impactonly = 1,
				impulseboost = 0,
				impulsefactor = 0,
				laserflaresize = 4.4,
				metalpershot = 0,
				name = "Laser",
				noselfdamage = true,
				range = 300,
				reloadtime = 0.9,
				rgbcolor = "1 0 0",
				soundhitdry = "",
				soundhitwet = "sizzle",
				soundstart = "lasrlit3",
				soundtrigger = 1,
				targetmoveerror = 0.12,
				thickness = 2.2,
				tolerance = 10000,
				turret = true,
				weapontype = "BeamLaser",
				weaponvelocity = 2000,
				damage = {
					default = 37,
				},
			},
		}
		uDef.weapons = {
			[1] = {
				badtargetcategory = "NOTAIR",
				def = "GATOR_LASER",
				onlytargetcategory = "VTOL",
			},
		}
	end

	if name == "corshad" then
		uDef.acceleration = 0.045
		uDef.blocking = false
		uDef.maxdec = 0.045
		uDef.energycost = 2400
		uDef.metalcost = 220
		uDef.buildpic = "CORSHAD.DDS"
		uDef.buildtime = 5050
		uDef.canfly = true
		uDef.canmove = true
		uDef.category = "ALL MOBILE WEAPON NOTLAND VTOL NOTSUB NOTSHIP NOTHOVER EMPABLE"
		uDef.collide = true
		uDef.cruisealtitude = 210
		uDef.explodeas = "mediumexplosiongeneric"
		uDef.footprintx = 3
		uDef.footprintz = 3
		uDef.idleautoheal = 5
		uDef.idletime = 1800
		uDef.maxacc = 0.07
		uDef.maxaileron = 0.02
		uDef.maxbank = 0.9
		uDef.health = 2520
		uDef.maxelevator = 0.015
		uDef.maxpitch = 0.14
		uDef.maxrudder = 0.02
		uDef.maxslope = 10
		uDef.speed = 170
		uDef.maxwaterdepth = 0
		uDef.noautofire = true
		uDef.nochasecategory = "VTOL"
		uDef.objectname = "Units/CORSHAD.s3o"
		uDef.script = "Units/CORSHAD.cob"
		uDef.seismicsignature = 0
		uDef.selfdestructas = "mediumExplosionGenericSelfd"
		uDef.sightdistance = 169
		uDef.speedtofront = 0.065
		uDef.turnradius = 4
		uDef.turnrate = 800
		uDef.usesmoothmesh = true
		uDef.wingangle = 0.06296
		uDef.wingdrag = 0.145
		uDef.weapondefs = {
			corbomb = {
				accuracy = 500,
				areaofeffect = 190,
				avoidfeature = false,
				collidefriendly = false,
				commandfire = false,
				craterareaofeffect = 168,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.1,
				explosiongenerator = "custom:genericshellexplosion-medium-bomb",
				gravityaffected = "true",
				impulseboost = 0.3,
				impulsefactor = 0.3,
				model = "airbomb.s3o",
				name = "Medium a2g incinerating warheads",
				noselfdamage = true,
				range = 1280,
				reloadtime = 10,
				soundhit = "bombssml1",
				soundhitwet = "splslrg",
				soundstart = "bombrel",
				weapontype = "AircraftBomb",
				damage = {
					default = 300,
				},
			},
		}
		uDef.weapons = {
			[1] = {
				badtargetcategory = "MOBILE",
				def = "CORBOMB",
				onlytargetcategory = "NOTSUB",
			},
		}
	end

	if name == "corbw" then
		uDef.acceleration = 0.5
		uDef.blocking = false
		uDef.maxdec = 0.4
		uDef.energycost = 700
		uDef.metalcost = 50
		uDef.buildpic = "CORBW.DDS"
		uDef.buildtime = 2070
		uDef.canfly = true
		uDef.canmove = true
		uDef.cantbetransported = false
		uDef.category = "ALL WEAPON VTOL NOTSUB NOTHOVER EMPABLE"
		uDef.collide = true
		uDef.cruisealtitude = 35
		uDef.explodeas = "tinyExplosionGeneric"
		uDef.footprintx = 2
		uDef.footprintz = 2
		uDef.hoverattack = false
		uDef.icontype = "air"
		uDef.idleautoheal = 5
		uDef.idletime = 1800
		uDef.health = 80
		uDef.maxaileron = 0.03
		uDef.maxacc = 0.7
		uDef.maxbank = 0.65
		uDef.maxelevator = 0.08
		uDef.maxpitch = 0.60
		uDef.maxrudder = 0.012
		uDef.maxslope = 10
		uDef.speed = 330
		uDef.maxwaterdepth = 0
		uDef.nochasecategory = "COMMANDER"
		uDef.objectname = "Units/CORBW.s3o"
		uDef.script = "Units/CORBW.cob"
		uDef.seismicsignature = 0
		uDef.selfdestructas = "tinyExplosionGenericSelfd"
		uDef.sightdistance = 364
		uDef.turninplaceanglelimit = 360
		uDef.turnradius = 38
		uDef.turnrate = 400
		uDef.upright = false
		uDef.usesmoothmesh = 0
		uDef.weapondefs = {
			bladewing_lyzer = {
				areaofeffect = 8,
				avoidfeature = false,
				avoidfriendly = false,
				--beamdecay = 0.5,
				beamtime = 0.25,
				beamttl = 1,
				collidefriendly = false,
				corethickness = 0.12,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				cylindertargeting = 1,
				duration = 0.01,
				edgeeffectiveness = 0.15,
				explosiongenerator = "custom:laserhit-emp",
				impactonly = 1,
				impulseboost = 0,
				impulsefactor = 0,
				laserflaresize = 6.6,
				name = "Light EMP laser",
				noselfdamage = true,
				paralyzer = false,
				--paralyzetime = 7,
				range = 220,
				reloadtime = 0.5,
				rgbcolor = "0.95 0.45 0.08",
				soundhitdry = "",
				soundhitwet = "sizzle",
				soundstart = "hackshot",
				soundtrigger = 1,
				targetmoveerror = 0.3,
				thickness = 1.4,
				tolerance = 10000,
				turret = true,
				weapontype = "BeamLaser",
				weaponvelocity = 800,
				damage = {
					default = 11,
				},
			},
		}
		uDef.weapons = {
			[1] = {
				def = "BLADEWING_LYZER",
				onlytargetcategory = "NOTSUB",
			},
		}
	end

	if name == "corcut" then
		uDef.acceleration = 1
		uDef.airstrafe = false
		uDef.blocking = false
		uDef.maxdec = 0.85
		uDef.energycost = 2600
		uDef.metalcost = 240
		uDef.buildpic = "CORCUT.DDS"
		uDef.buildtime = 9470
		uDef.canfly = true
		uDef.canmove = true
		uDef.cansubmerge = true
		uDef.category = "ALL MOBILE WEAPON VTOL NOTLAND NOTSUB NOTSHIP NOTHOVER EMPABLE"
		uDef.collide = true
		uDef.cruisealtitude = 150
		uDef.explodeas = "mediumexplosiongeneric"
		uDef.footprintx = 3
		uDef.footprintz = 3
		uDef.hoverattack = false
		uDef.idleautoheal = 5
		uDef.idletime = 1800
		uDef.health = 1600
		uDef.maxacc = 0.065
		uDef.maxbank = 0.8
		uDef.maxdec = 0.85
		uDef.maxpitch = 0.45
		uDef.maxrudder = 0.014
		uDef.maxslope = 10
		uDef.maxwaterdepth = 0
		uDef.speed = 215
		uDef.nochasecategory = "NOTAIR"
		uDef.objectname = "Units/CORCUT.s3o"
		uDef.script = "Units/CORCUT.cob"
		uDef.seismicsignature = 0
		uDef.selfdestructas = "mediumExplosionGenericSelfd"
		uDef.sightdistance = 595
		uDef.turninplaceanglelimit = 360
		uDef.turnradius = 6
		uDef.turnrate = 300
		uDef.weapondefs = {
			med_emg = {
				areaofeffect = 90,
				avoidfeature = false,
				burnblow = true,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.15,
				explosiongenerator = "custom:genericshellexplosion-small",
				impulseboost = 0.123,
				impulsefactor = 0.123,
				name = "LongRangeCannon",
				noselfdamage = true,
				range = 900,
				reloadtime = 1.2,
				rgbcolor = "0.8 0.8 0.1",
				size = 3,
				soundhit = "xplosml3",
				soundhitwet = "splshbig",
				soundstart = "canlite3",
				soundtrigger = true,
				tolerance = 10000,
				turret = true,
				weapontype = "Cannon",
				weaponvelocity = 450,
				damage = {
					default = 1,
					vtol = 190,
				},
			},
		}
		uDef.weapons = {
			[1] = {
				badtargetcategory = "NOTAIR",
				def = "MED_EMG",
				onlytargetcategory = "VTOL",
			},
		}
	end

---------------------------------------------
			--------------------
			---CORTEX AIR T2 ---
			--------------------
---------------------------------------------









---------------------------------------------
			--------------------
			----GROUND UNITS----
			--------------------
---------------------------------------------


	if name == "armwar" or name == "armham" or name == "armflea" or name == "armpw" or name == "armstump" or name == "armfav" or name == "armart" or name == "armflash" or name == "armpincer" or name == "armjanus" or name == "armcom" or name == "armllt" or name == "armbeamer" or name == "armhlt" or name == "armclaw" or name == "armguard" or name == "corstorm" or name == "corthud" or name == "corak" or name == "corlevlr" or name == "corgarp" or name == "corwolv" or name == "corraid" or name == "corgator" or name == "corfav" or name == "corllt" or name == "corhlt" or name == "corhllt" or name == "cormaw" or name == "corpun" or name == "corpship" or name == "corroy" or name == "coresupp" or name == "armroy" or name == "armpship" or name == "armdecade" or name == "armfhlt" or name == "corfhlt" then
		for weapons, weaponDef in pairs(uDef.weapondefs) do
			if weaponDef.damage and weaponDef.damage.default then
				weaponDef.damage.vtol = weaponDef.damage.default
			end
		end
	end

	if name == "armsam" then
		uDef.energycost = 1350
		uDef.buildtime = 2000
		uDef.nochasecategory = "NOTAIR"
		uDef.speed = 70
		uDef.weapondefs.armtruck_missile.reloadtime = 3
		uDef.weapondefs.armtruck_missile.damage.default = 1
		uDef.weapons = {
			[1] = {
				badtargetcategory = "NOTAIR LIGHTAIRSCOUT",
				def = "ARMTRUCK_MISSILE",
				onlytargetcategory = "VTOL",
			},
		}
	end

	if name == "cormist" then
		uDef.energycost = 1400
		uDef.buildtime = 2000
		uDef.nochasecategory = "NOTAIR"
		uDef.speed = 70
		uDef.weapondefs.cortruck_missile.damage.default = 1
		uDef.weapondefs.cortruck_missile.damage.vtol = 130
		uDef.weapons = {
			[1] = {
				badtargetcategory = "NOTAIR LIGHTAIRSCOUT",
				def = "CORTRUCK_MISSILE",
				onlytargetcategory = "VTOL",
			},
		}
	end










---------------------------------------------
			--------------------
			----BUILDOPTIONS----
			--------------------
---------------------------------------------
	if name == "armap" then
		uDef.buildoptions[7] = "armsfig"
	end

	if name == "corap" then
		uDef.buildoptions[7] = "corcut"
	end

	return uDef

end








--[[

local function skyshiftWeaponTweaks(name, wDef)

		--wDef.damage.vtol = wDef.damage.default

	return wDef

end
]]
return {
	skyshiftUnitTweaks = skyshiftUnitTweaks,
	--skyshiftWeaponTweaks = skyshiftWeaponTweaks,
	}
