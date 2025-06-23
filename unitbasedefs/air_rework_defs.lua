local function airReworkTweaks(name, uDef)
	if name == "armhawk" then
		uDef.metalcost = 250
		uDef.energycost = 7600
		uDef.buildtime = uDef.buildtime * 1.35
		uDef.maxaileron = 0.02
		uDef.maxacc = 0.21
		--uDef.maxdec = 0.075
		uDef.speed = 250
		uDef.maxrudder = 0.014
		uDef.maxbank = 0.65
		uDef.health = 740
		uDef.sightdistance = 550
		uDef.cruisealtitude = 240
		uDef.weapondefs.armvtol_advmissile.proximitypriority = 0
		uDef.weapondefs.armvtol_advmissile.areaofeffect = 45
		uDef.weapondefs.armvtol_advmissile.impactonly = 0
		uDef.weapondefs.armvtol_advmissile.flighttime = 2.3
		uDef.weapondefs.armvtol_advmissile.range = 780
		uDef.weapondefs.armvtol_advmissile.reloadtime = 3.2
		uDef.weapondefs.armvtol_advmissile.startvelocity = 100
		uDef.weapondefs.armvtol_advmissile.tolerance = 100000
		uDef.weapondefs.armvtol_advmissile.turnrate = 37000
		uDef.weapondefs.armvtol_advmissile.weaponacceleration = 310
		uDef.weapondefs.armvtol_advmissile.smoketrail = true
		uDef.weapondefs.armvtol_advmissile.smokePeriod = 12
		uDef.weapondefs.armvtol_advmissile.smoketime = 24
		uDef.weapondefs.armvtol_advmissile.smokesize = 6
		uDef.weapondefs.armvtol_advmissile.cegtag = "missiletrailaa"
		uDef.weapondefs.armvtol_advmissile.explosiongenerator = "custom:genericshellexplosion-medium-bomb"
		uDef.weapondefs.armvtol_advmissile.damage = {
			default = 1,
			vtol = 500,
		}
	end
	if name == "armfig" then
		uDef.metalcost = 150
		uDef.energycost = 4500
		uDef.buildtime = 5000
		uDef.speed = 207
		uDef.maxacc = 0.2
		uDef.maxrudder = 0.013
		uDef.maxbank = 0.65
		uDef.health = 460
		uDef.sightdistance = 460
		uDef.cruisealtitude = 160
		--uDef.weapondefs.armvtol_missile.explosiongenerator = "custom:genericshellexplosion-tiny"
		--uDef.weapondefs.armvtol_missile.smokePeriod = 8
		--uDef.weapondefs.armvtol_missile.smoketime = 14
		--uDef.weapondefs.armvtol_missile.smokesize = 5.0
		--uDef.weapondefs.armvtol_missile.smokecolor = 0.66
		--uDef.weapondefs.armvtol_missile.cegtag = "missiletrailtiny"
		uDef.weapondefs.armvtol_missile.proximitypriority = 0
		uDef.weapondefs.armvtol_missile.flighttime = 1.7
		uDef.weapondefs.armvtol_missile.range = 550
		uDef.weapondefs.armvtol_missile.reloadtime = 1.3
		uDef.weapondefs.armvtol_missile.startvelocity = 110
		uDef.weapondefs.armvtol_missile.tolerance = 10000
		uDef.weapondefs.armvtol_missile.turnrate = 23000
		--uDef.weapondefs.armvtol_missile.name = "Light guided a2a/a2g missile launcher"
		uDef.weapondefs.armvtol_missile.weaponacceleration = 350
		--uDef.weapondefs.armvtol_missile.canattackground = true
		uDef.weapondefs.armvtol_missile.damage = {
			--default = 64,
			vtol = 200,
		}
		--uDef.weapons[1].onlytargetcategory = "NOTSUB"
	end
	if name == "armsfig2" then
		uDef.metalcost = 450
		uDef.energycost = 6500
		uDef.buildtime = 10000
		uDef.speed = 165
		uDef.maxacc = 0.2
		uDef.maxrudder = 0.016
		uDef.maxbank = 0.5
		--uDef.maxpitch = 0.02
		--uDef.maxelevator = 0.02
		uDef.health = 2700
		uDef.sightdistance = 460
		uDef.cruisealtitude = 160
		--uDef.turnradius = 128
		uDef.weapondefs.armsfig_weapon.proximitypriority = 0
		uDef.weapondefs.armsfig_weapon.flighttime = 1.4
		uDef.weapondefs.armsfig_weapon.range = 650
		uDef.weapondefs.armsfig_weapon.burst = 4
		uDef.weapondefs.armsfig_weapon.burstrate = 0.15
		uDef.weapondefs.armsfig_weapon.explosiongenerator = "custom:genericshellexplosion-medium-bomb"
		uDef.weapondefs.armsfig_weapon.smokePeriod = 7
		uDef.weapondefs.armsfig_weapon.smoketime = 48
		uDef.weapondefs.armsfig_weapon.smokesize = 10
		uDef.weapondefs.armsfig_weapon.smoketrail = true
		uDef.weapondefs.armsfig_weapon.areaofeffect = 245
		uDef.weapondefs.armsfig_weapon.reloadtime = 3
		uDef.weapondefs.armsfig_weapon.startvelocity = 180
		uDef.weapondefs.armsfig_weapon.tolerance = 1000
		uDef.weapondefs.armsfig_weapon.turnrate = 3600
		uDef.weapondefs.armsfig_weapon.weaponacceleration = 450
		uDef.weapondefs.armsfig_weapon.weaponvelocity = 1000
		uDef.weapondefs.armsfig_weapon.wobble = 5
		uDef.weapondefs.armsfig_weapon.dance = 30
		uDef.weapondefs.armsfig_weapon.damage = {
			default = 1,
			vtol = 180,
		}
	end
	if name == "corvamp" then
		uDef.metalcost = 240
		uDef.energycost = 7300
		uDef.buildtime = uDef.buildtime * 1.35
		uDef.maxaileron = 0.02
		uDef.maxacc = 0.21
		uDef.maxdec = 0.075
		uDef.speed = 275
		uDef.maxrudder = 0.014
		uDef.maxbank = 0.65
		uDef.health = 580
		uDef.sightdistance = 550
		uDef.cruisealtitude = 240
		uDef.weapondefs.corvtol_advmissile.impactonly = 0
		uDef.weapondefs.corvtol_advmissile.proximitypriority = 0
		uDef.weapondefs.corvtol_advmissile.areaofeffect = 32
		uDef.weapondefs.corvtol_advmissile.flighttime = 2.2
		uDef.weapondefs.corvtol_advmissile.range = 710
		uDef.weapondefs.corvtol_advmissile.reloadtime = 1.7
		uDef.weapondefs.corvtol_advmissile.startvelocity = 100
		uDef.weapondefs.corvtol_advmissile.tolerance = 100000
		uDef.weapondefs.corvtol_advmissile.turnrate = 37000
		uDef.weapondefs.corvtol_advmissile.weaponacceleration = 310
		uDef.weapondefs.corvtol_advmissile.smoketrail = true
		uDef.weapondefs.corvtol_advmissile.smokePeriod = 12
		uDef.weapondefs.corvtol_advmissile.smoketime = 24
		uDef.weapondefs.corvtol_advmissile.smokesize = 6
		uDef.weapondefs.corvtol_advmissile.cegtag = "missiletrailaa"
		uDef.weapondefs.corvtol_advmissile.explosiongenerator = "custom:genericshellexplosion-medium-bomb"
		uDef.weapondefs.corvtol_advmissile.damage = {
			default = 1,
			vtol = 300,
		}
	end
	if name == "corveng" then
		uDef.metalcost = 150
		uDef.energycost = 4500
		uDef.buildtime = 5000
		uDef.speed = 207
		uDef.maxacc = 0.2
		uDef.maxrudder = 0.013
		uDef.maxbank = 0.65
		uDef.health = 460
		uDef.sightdistance = 460
		uDef.cruisealtitude = 160
		--uDef.weapondefs.corvtol_missile.explosiongenerator = "custom:genericshellexplosion-tiny"
		--uDef.weapondefs.corvtol_missile.smokePeriod = 8
		--uDef.weapondefs.corvtol_missile.smoketime = 14
		--uDef.weapondefs.corvtol_missile.smokesize = 5.0
		--uDef.weapondefs.corvtol_missile.smokecolor = 0.66
		--uDef.weapondefs.corvtol_missile.cegtag = "missiletrailtiny"
		uDef.weapondefs.corvtol_missile.proximitypriority = 0
		uDef.weapondefs.corvtol_missile.flighttime = 1.7
		uDef.weapondefs.corvtol_missile.range = 550
		uDef.weapondefs.corvtol_missile.reloadtime = 1.3
		uDef.weapondefs.corvtol_missile.startvelocity = 110
		uDef.weapondefs.corvtol_missile.tolerance = 10000
		uDef.weapondefs.corvtol_missile.turnrate = 23000
		uDef.weapondefs.corvtol_missile.weaponacceleration = 350
		--uDef.weapondefs.corvtol_missile.canattackground = true
		--uDef.weapondefs.corvtol_missile.name = "Light guided a2a/a2g missile launcher"
		uDef.weapondefs.corvtol_missile.damage = {
			--default = 64,
			vtol = 200,
		}
		--uDef.weapons[1].onlytargetcategory = "NOTSUB"
	end
	if name == "corsfig2" then
		uDef.metalcost = 520
		uDef.energycost = 8000
		uDef.buildtime = 11000
		uDef.speed = 155
		uDef.maxacc = 0.2
		uDef.maxrudder = 0.016
		uDef.maxbank = 0.5
		--uDef.maxpitch = 0.02
		--uDef.maxelevator = 0.02
		uDef.health = 3000
		uDef.sightdistance = 460
		uDef.cruisealtitude = 160
		uDef.turnradius = 128
		uDef.weapondefs.corsfig_weapon.proximitypriority = -1
		uDef.weapondefs.corsfig_weapon.flighttime = 1.7
		uDef.weapondefs.corsfig_weapon.range = 680
		uDef.weapondefs.corsfig_weapon.areaofeffect = 220
		uDef.weapondefs.corsfig_weapon.edgeeffectiveness = 0.55
		uDef.weapondefs.corsfig_weapon.reloadtime = 6.1
		uDef.weapondefs.corsfig_weapon.startvelocity = 100
		uDef.weapondefs.corsfig_weapon.tolerance = 12500
		uDef.weapondefs.corsfig_weapon.turnrate = 19000
		uDef.weapondefs.corsfig_weapon.weaponacceleration = 250
		uDef.weapondefs.corsfig_weapon.cegtag = "missiletraillarge-red"
		uDef.weapondefs.corsfig_weapon.explosiongenerator = "custom:genericshellexplosion-large-bomb"
		uDef.weapondefs.corsfig_weapon.model = "banishermissile.s3o"
		uDef.weapondefs.corsfig_weapon.smoketrail = true
		uDef.weapondefs.corsfig_weapon.smokePeriod = 7
		uDef.weapondefs.corsfig_weapon.smoketime = 48
		uDef.weapondefs.corsfig_weapon.smokesize = 11.3
		uDef.weapondefs.corsfig_weapon.smokecolor = 0.82
		uDef.weapondefs.corsfig_weapon.soundhit = "corban_b"
		uDef.weapondefs.corsfig_weapon.soundhitwet = "splsmed"
		uDef.weapondefs.corsfig_weapon.soundstart = "corban_a"
		uDef.weapondefs.corsfig_weapon.texture1 = "null"
		uDef.weapondefs.corsfig_weapon.texture2 = "railguntrail"
		uDef.weapondefs.corsfig_weapon.weaponvelocity = 650
		uDef.weapondefs.corsfig_weapon.damage = {
			default = 1,
			vtol = 1000,
		}
	end
	if name == "armca" or name == "armaca" or name == "corca" or name == "corcsa" or name == "armcsa" or name == "coraca" then
		uDef.health = uDef.health * 1.5
		uDef.speed = uDef.speed * 0.75
		uDef.turnrate = uDef.turnrate * 1.5
		uDef.workertime = (uDef.workertime * 7 / 6) - (uDef.workertime * 7 / 6 - 5) % 5
		uDef.metalcost = uDef.metalcost * 7 / 6 - (uDef.metalcost * 7 / 6) % 1
	end
	if name == "armawac" then
		uDef.metalcost = uDef.metalcost * 1.15 + uDef.energycost / 70 * 0.15 - (uDef.metalcost * 1.15 + uDef.energycost / 70 * 0.15) % 1
		uDef.speed = uDef.speed * 0.76
		uDef.maxrudder = 0.015
		uDef.maxbank = 0.66
		uDef.health = 1040
		uDef.maxacc = 0.4
		uDef.maxdec = 0.01
		uDef.cruisealtitude = 270
	end
	if name == "armpeep" then
		uDef.metalcost = uDef.metalcost * 1.15 + uDef.energycost / 70 * 0.15 - (uDef.metalcost * 1.15 + uDef.energycost / 70 * 0.15) % 1
		uDef.health = 133
		uDef.speed = uDef.speed * 0.76
		uDef.maxrudder = 0.017
		uDef.maxbank = 0.66
		uDef.maxacc = 0.4
		uDef.cruisealtitude = 170
		uDef.sightdistance = uDef.sightdistance * 1.2
	end
	if name == "corawac" then
		uDef.metalcost = uDef.metalcost * 1.15 + uDef.energycost / 70 * 0.15 - (uDef.metalcost * 1.15 + uDef.energycost / 70 * 0.15) % 1
		uDef.speed = uDef.speed * 0.76
		uDef.maxrudder = 0.015
		uDef.maxbank = 0.66
		uDef.health = 1140
		uDef.maxacc = 0.4
		uDef.maxdec = 0.01
		uDef.cruisealtitude = 270
	end
	if name == "corfink" then
		uDef.metalcost = uDef.metalcost * 1.15 + uDef.energycost / 70 * 0.15 - (uDef.metalcost * 1.15 + uDef.energycost / 70 * 0.15) % 1
		uDef.health = 150
		uDef.speed = uDef.speed * 0.76
		uDef.maxrudder = 0.017
		uDef.maxbank = 0.66
		uDef.maxacc = 0.4
		uDef.cruisealtitude = 170
		uDef.sightdistance = uDef.sightdistance * 1.2
	end
	if name == "corhunt" then
		uDef.metalcost = uDef.metalcost * 1.15 + uDef.energycost / 70 * 0.15 - (uDef.metalcost * 1.15 + uDef.energycost / 70 * 0.15) % 1
		uDef.speed = uDef.speed * 0.76
		uDef.maxrudder = 0.015
		uDef.maxbank = 0.66
		uDef.maxacc = 0.4
		uDef.maxdec = 0.01
		uDef.cruisealtitude = 240
	end
	if name == "armsehak" then
		uDef.metalcost = uDef.metalcost * 1.15 + uDef.energycost / 70 * 0.15 - (uDef.metalcost * 1.15 + uDef.energycost / 70 * 0.15) % 1
		uDef.speed = uDef.speed * 0.76
		uDef.maxrudder = 0.015
		uDef.maxbank = 0.66
		uDef.maxacc = 0.4
		uDef.maxdec = 0.01
		uDef.cruisealtitude = 240
	end
	if name == "armatlas" or name == "corvalk" then
		uDef.health = uDef.health * 1.6
		uDef.speed = uDef.speed * 0.75
		uDef.turnrate = uDef.turnrate * 1.5
		uDef.buildtime = uDef.buildtime * 0.8
	end
	if name == "armbrawl" or name == "armkam" or name == "corape" then
		uDef.health = uDef.health * 1.3
		uDef.speed = uDef.speed * 0.85
		uDef.turnrate = uDef.turnrate * 1.5
		uDef.cruisealtitude = 100
		uDef.buildtime = uDef.buildtime * 0.8
	end
	if name == "armdfly" then
		uDef.speed = uDef.speed * 0.85
		uDef.health = uDef.health * 1.2
		uDef.turnrate = uDef.turnrate * 1.5
	end
	if name == "corseah" then
		uDef.speed = uDef.speed * 0.85
		uDef.health = uDef.health * 1.4
		uDef.turnrate = uDef.turnrate * 1.5
	end
	if name == "armkam" then
		uDef.weapondefs.med_emg.burstrate = 0.08
		uDef.weapondefs.med_emg.reloadtime = 1.15
		uDef.weapondefs.med_emg.areaofeffect = 24
	end
	if name == "armbrawl" then
		uDef.weapondefs.vtol_emg.damage = {
		default = 20,
		}
	end
	if name == "corcrwh" then
		uDef.health = uDef.health * 1.3
		uDef.speed = uDef.speed * 0.75
		--uDef.turnrate = uDef.turnrate * 1.5
	end
	if name == "corbw" then
		uDef.speed = uDef.speed * 0.85
		uDef.cruisealtitude = 80
	end
	if name == "armseap" or name == "corseap" then
		uDef.health = uDef.health * 1.3
		uDef.speed = uDef.speed * 0.75
		uDef.turnrate = uDef.turnrate * 1.5
	end
	if name == "armsaber" then
		uDef.health = uDef.health * 1.3
		uDef.speed = uDef.speed * 0.74
		--uDef.turnrate = uDef.turnrate * 1.5
		uDef.cruisealtitude = 100
		uDef.weapondefs.vtol_emg2.range = 740
		uDef.weapondefs.vtol_emg2.reloadtime = 3.1
		uDef.airStrafe = false
		uDef.weapondefs.vtol_emg2.damage = {
			default = 120,
			vtol = 20,
		}
	end
	if name == "corcut" then
		uDef.health = uDef.health * 1.75
		uDef.metalcost = 370
		uDef.energycost = 9500
		uDef.buildtime = 14500
		uDef.speed = uDef.speed * 0.66
		--uDef.turnrate = uDef.turnrate * 1.5
		uDef.cruisealtitude = 100
		uDef.weapondefs.vtol_rocket2.range = 690
		uDef.airStrafe = false
		uDef.weapondefs.vtol_rocket2.areaofeffect = 72
		uDef.weapondefs.vtol_rocket2.reloadtime = 9.5
		uDef.weapondefs.vtol_rocket2.sprayangle = 1700
		uDef.weapondefs.vtol_rocket2.burst = 4
		uDef.weapondefs.vtol_rocket2.burstrate = 0.15
		uDef.weapondefs.vtol_rocket2.explosiongenerator = "custom:genericshellexplosion-medium"
		uDef.weapondefs.vtol_rocket2.weaponvelocity = 550
		uDef.weapondefs.vtol_rocket2.damage = {
			default = 140,
			vtol = 28,
		}
	end
	if name == "armblade" then
		uDef.health = uDef.health * 1.1
		--uDef.speed = uDef.speed * 0.85
		uDef.turnrate = uDef.turnrate * 2
		uDef.cruisealtitude = 100
		uDef.weapondefs.vtol_sabot.areaofeffect = 64
		--uDef.weapondefs.vtol_sabot.reloadtime = 3.5
		uDef.weapondefs.vtol_sabot.range = 550
		uDef.weapondefs.vtol_sabot.startvelocity = 170
		--uDef.weapondefs.vtol_sabot.burst = 2
		--uDef.weapondefs.vtol_sabot.burstrate = 0.3
		--uDef.weapondefs.vtol_sabot.damage = {
		--	default = 350,
		--}
	end
	if name == "corape" then
		uDef.weapondefs.vtol_rocket.turnrate = 15000
		uDef.weapondefs.vtol_rocket.startvelocity = 120
		uDef.weapondefs.vtol_rocket.weaponacceleration = 260
		uDef.weapondefs.vtol_rocket.damage.default = 153
	end
	if name == "cortitan" or name == "corshad" or name == "armthund" or name == "armliche" or name == "armstil" or name == "armlance" then
		uDef.metalcost = uDef.metalcost * 1.15 + uDef.energycost / 70 * 0.15 - (uDef.metalcost * 1.15 + uDef.energycost / 70 * 0.15) % 1
		uDef.energycost = uDef.energycost * 1.2
		uDef.metalcost = uDef.metalcost * 1.2 - (uDef.metalcost * 1.2) % 1
		uDef.speed = uDef.speed * 0.73
		uDef.maxacc = math.max(uDef.maxacc * 1.3, 0.13)
		uDef.maxbank = 0.65
		uDef.maxdec = 0.013
		uDef.maxrudder = uDef.maxrudder * 2.2
		uDef.health = uDef.health * 1.6
		uDef.sightdistance = 550
		uDef.cruisealtitude = 200
	end

	if name == "corhurc" then
		uDef.metalcost = uDef.metalcost * 2
		uDef.energycost = uDef.energycost * 1.2
		uDef.speed = uDef.speed * 0.62
		uDef.maxbank = 0.5
		uDef.maxacc = uDef.maxacc * 1.3
		uDef.maxrudder = uDef.maxrudder * 2
		uDef.maxaileron = uDef.maxaileron * 0.7
		uDef.health = uDef.health * 2.3
		uDef.sightdistance = 520
		uDef.cruisealtitude = 240
		uDef.weapondefs.coradvbomb.burstrate = 0.26
		uDef.weapondefs.coradvbomb.damage = {
			default = 500
		}
	end
	if name == "armpnix" then
		uDef.metalcost = uDef.metalcost * 2
		uDef.energycost = uDef.energycost * 1.2
		uDef.speed = uDef.speed * 0.62
		uDef.maxbank = 0.5
		uDef.maxacc = uDef.maxacc * 1.3
		uDef.maxrudder = uDef.maxrudder * 2
		uDef.maxaileron = uDef.maxaileron * 0.7
		uDef.health = uDef.health * 2.3
		uDef.sightdistance = 520
		uDef.cruisealtitude = 240
		uDef.weapondefs.armadvbomb.burstrate = 0.35
		uDef.weapondefs.armadvbomb.burst = 6
		uDef.weapondefs.armadvbomb.areaofeffect = 220
	end
	if name == "corsb" or name == "armsb" then
		uDef.metalcost = uDef.metalcost * 1.25 + uDef.energycost / 70 * 0.25 - (uDef.metalcost * 1.25 + uDef.energycost / 70 * 0.25) % 1
		uDef.energycost = uDef.energycost * 1.2
		uDef.metalcost = uDef.metalcost * 1.2 - (uDef.metalcost * 1.2) % 1
		uDef.speed = uDef.speed * 0.85
		uDef.maxacc = 0.35
		uDef.maxdec = 0.035
		uDef.maxbank = 0.68
		uDef.maxrudder = uDef.maxrudder * 2.5
		uDef.health = uDef.health * 1.4
		uDef.maxdec = 0.014
		uDef.sightdistance = 720
		uDef.cruisealtitude = 200
		uDef.stealth = true
	end
	if name == "armaap" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "armsb"
		uDef.buildoptions[numBuildoptions + 2] = "armsfig2"
		uDef.buildoptions[numBuildoptions + 3] = "armsaber"
		uDef.buildoptions[numBuildoptions + 4] = "armseap"
	end
	if name == "coraap" then
		local numBuildoptions = #uDef.buildoptions
		uDef.buildoptions[numBuildoptions + 1] = "corsb"
		uDef.buildoptions[numBuildoptions + 2] = "corsfig2"
		uDef.buildoptions[numBuildoptions + 3] = "corcut"
		uDef.buildoptions[numBuildoptions + 4] = "corseap"
	end
	if name == "corplat" then
		uDef.buildoptions[5] = "corsfig2"
	end
	if name == "armplat" then
		uDef.buildoptions[5] = "armsfig2"
	end
	if name == "armrl" then
		uDef.weapondefs.armrl_missile.startvelocity = 111
		uDef.weapondefs.armrl_missile.flighttime = 2.6
	end
	if name == "armfrt" then
		uDef.weapondefs.armrl_missile.startvelocity = 111
		uDef.weapondefs.armrl_missile.flighttime = 2.6
		uDef.weapondefs.armrl_missile.weaponacceleration = 200
	end
	if name == "corfrt" then
		uDef.weapondefs.armrl_missile.startvelocity = 111
		uDef.weapondefs.armrl_missile.flighttime = 2.6
		uDef.weapondefs.armrl_missile.weaponacceleration = 200
	end
	if name == "corrl" then
		uDef.weapondefs.corrl_missile.startvelocity = 111
		uDef.weapondefs.corrl_missile.flighttime = 2.6
	end
	if name == "armferret" then
		uDef.weapondefs.ferret_missile.areaofeffect = 48
		uDef.weapondefs.ferret_missile.startvelocity = 120
		uDef.weapondefs.ferret_missile.weaponacceleration = 210
		uDef.weapondefs.ferret_missile.weaponvelocity = 1100
		uDef.metalcost = uDef.metalcost * 0.7
		uDef.energycost = uDef.energycost * 0.7
		uDef.health = 1000
	end
	if name == "cormadsam" then
		uDef.weapondefs.madsam_missile.areaofeffect = 48
		uDef.weapondefs.madsam_missile.startvelocity = 120
		uDef.weapondefs.madsam_missile.weaponacceleration = 210
		uDef.weapondefs.madsam_missile.weaponvelocity = 1100
		uDef.metalcost = uDef.metalcost * 0.7 - 0.5
		uDef.energycost = uDef.energycost * 0.7
		uDef.health = 2000
	end
	if name == "armmercury" then
		uDef.weapondefs.arm_advsam.startvelocity = 140
		uDef.weapondefs.arm_advsam.stockpile = false
		uDef.weapondefs.arm_advsam.reloadtime = 25
		uDef.weapondefs.arm_advsam.weaponacceleration = 760
		uDef.weapondefs.arm_advsam.energypershot = 0
		uDef.weapondefs.arm_advsam.flighttime = 2.5
		uDef.weapondefs.arm_advsam.damage.vtol = 1500
	end
	if name == "corscreamer" then
		uDef.weapondefs.cor_advsam.startvelocity = 140
		uDef.weapondefs.cor_advsam.stockpile = false
		uDef.weapondefs.cor_advsam.reloadtime = 25
		uDef.weapondefs.cor_advsam.weaponacceleration = 760
		uDef.weapondefs.cor_advsam.energypershot = 0
		uDef.weapondefs.cor_advsam.flighttime = 2.5
		uDef.weapondefs.cor_advsam.damage.vtol = 1500
	end
	if name == "armcir" then
		uDef.weapondefs.arm_cir.startvelocity = 100
		uDef.weapondefs.arm_cir.weaponvelocity = 1050
		uDef.weapondefs.arm_cir.flighttime = 2.7
	end
	if name == "corerad" then
		uDef.weapondefs.cor_erad.startvelocity = 100
		uDef.weapondefs.cor_erad.weaponvelocity = 1050
		uDef.weapondefs.cor_erad.flighttime = 2.7
	end
	if name == "armjeth" then
		uDef.weapondefs.armbot_missile.startvelocity = 130
		uDef.weapondefs.armbot_missile.weaponacceleration = 230
		uDef.weapondefs.armbot_missile.flighttime = 2.4
	end
	if name == "corcrash" then
		uDef.weapondefs.corbot_missile.startvelocity = 130
		uDef.weapondefs.corbot_missile.weaponacceleration = 230
		uDef.weapondefs.corbot_missile.flighttime = 2.4
	end
	if name == "armaak" then
		uDef.health = uDef.health * 2
		uDef.weapondefs.armaabot_missile1.range = 1300
		uDef.weapondefs.armaabot_missile1.reloadtime = 1.5
		uDef.weapondefs.armaabot_missile1.startvelocity = 130
		uDef.weapondefs.armaabot_missile1.weaponacceleration = 320
		uDef.weapondefs.armaabot_missile1.flighttime = 2.55
		uDef.weapondefs.armaabot_missile2.startvelocity = 110
		uDef.weapondefs.armaabot_missile2.weaponacceleration = 300
		uDef.weapondefs.armaabot_missile2.flighttime = 2.4
		uDef.weapondefs.armaabot_missile2.reloadtime = 1.4
		uDef.weapondefs.armaabot_missile2.range = 880
		uDef.weapons[5].def = ""
	end
	if name == "coraak" then
		uDef.health = uDef.health * 2
		uDef.weapondefs.coraabot_missile4.range = 1400
		uDef.weapondefs.coraabot_missile4.reloadtime = 1.6
		uDef.weapondefs.coraabot_missile4.startvelocity = 130
		uDef.weapondefs.coraabot_missile4.weaponacceleration = 320
		uDef.weapondefs.coraabot_missile4.flighttime = 2.55
		uDef.weapondefs.coraabot_missile3.range = 970
		uDef.weapondefs.coraabot_missile3.reloadtime = 1.2
		uDef.weapondefs.coraabot_missile3.startvelocity = 110
		uDef.weapondefs.coraabot_missile3.weaponacceleration = 300
		uDef.weapondefs.coraabot_missile3.flighttime = 2.4
		uDef.weapondefs.coraabot_missile2.range = 870
		uDef.weapondefs.coraabot_missile2.startvelocity = 100
		uDef.weapondefs.coraabot_missile2.weaponacceleration = 290
		uDef.weapondefs.coraabot_missile2.flighttime = 2.4
		uDef.weapondefs.coraabot_missile2.reloadtime = 1
		uDef.weapons[6].def = ""
	end
	if name == "armyork" then
		uDef.weapondefs.mobileflak.weaponvelocity = 1000
	end
	if name == "corsent" then
		uDef.weapondefs.mobileflak.weaponvelocity = 1000
	end
	if name == "armflak" then
		uDef.weapondefs.armflak_gun.weaponvelocity = 1100
		uDef.metalcost = uDef.metalcost * 0.9
		uDef.energycost = uDef.energycost * 0.9
	end
	if name == "corflak" then
		uDef.weapondefs.armflak_gun.weaponvelocity = 1100
		uDef.metalcost = uDef.metalcost * 0.9
		uDef.energycost = uDef.energycost * 0.9
	end
	if name == "armsam" then
		uDef.weapondefs.armtruck_missile.startvelocity = 135
		uDef.weapondefs.armtruck_missile.weaponacceleration = 230
	end
	if name == "cormist" then
		uDef.weapondefs.cortruck_missile.startvelocity = 135
		uDef.weapondefs.cortruck_missile.weaponacceleration = 230
	end
	if name == "corpt" then
		uDef.weapondefs.cortruck_missile.startvelocity = 135
		uDef.weapondefs.cortruck_missile.weaponacceleration = 250
		uDef.weapondefs.cortruck_missile.damage.vtol = 150
	end
	if name == "armpt" then
		uDef.weapondefs.aamissile.startvelocity = 140
		uDef.weapondefs.aamissile.weaponacceleration = 270
		uDef.weapondefs.aamissile.flighttime = 2.1
	end
	if name == "corenaa" then
		uDef.weapondefs.armflak_gun.weaponvelocity = 1100
	end
	if name == "armfflak" then
		uDef.weapondefs.armflak_gun.weaponvelocity = 1100
	end
	if name == "armlatnk" then
		uDef.weapondefs.armamph_missile.startvelocity = 150
		uDef.weapondefs.armamph_missile.weaponacceleration = 250
		uDef.weapondefs.armamph_missile.flighttime = 2
	end
	if name == "armamph" then
		uDef.weapondefs.armamph_missile.startvelocity = 150
		uDef.weapondefs.armamph_missile.weaponacceleration = 250
		uDef.weapondefs.armamph_missile.flighttime = 2
	end
	if name == "armmar" then
		uDef.weapondefs.armamph_missile.startvelocity = 150
		uDef.weapondefs.armamph_missile.weaponacceleration = 250
		uDef.weapondefs.armamph_missile.flighttime = 2
	end
	if name == "armaas" then
		uDef.weapondefs.ga2.startvelocity = 150
		uDef.weapondefs.ga2.weaponacceleration = 230
		uDef.weapondefs.ga2.flighttime = 2.5
		uDef.weapondefs.mobileflak.weaponvelocity = 1000
	end
	if name == "corarch" then
		uDef.weapondefs.ga2.startvelocity = 150
		uDef.weapondefs.ga2.weaponacceleration = 230
		uDef.weapondefs.ga2.flighttime = 2.5
		uDef.weapondefs.mobileflak.weaponvelocity = 1000
	end
	if uDef.sightdistance then
		uDef.airsightdistance = uDef.sightdistance * 1.3
	end

	return uDef
end

return {
	airReworkTweaks = airReworkTweaks,
}
