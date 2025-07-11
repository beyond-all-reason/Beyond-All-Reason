local function proposed_unit_reworksTweaks(name, uDef)
	if name == "armsam" then
		uDef.collisionvolumetype = "ellipsoid"
		uDef.collisionvolumescales = "29 31 41"
		uDef.collisionvolumeoffsets = "0 3 -1"
	end
	if name == "cormist" then
		uDef.collisionvolumetype = "ellipsoid"
		uDef.collisionvolumescales = "32 31 43"
		uDef.collisionvolumeoffsets = "0 0 -2"
	end

	
	if name == "armmex" or name == "cormex" or name == "legmex" then
		uDef.health = uDef.health + 81
	end

	if name == "armck" or name == "corck" or name == "legck" then
		uDef.health = uDef.health + 90
	end

	if name == "armllt" or name == "corllt" or name == "leglht"
	or name == "armbeamer" or name == "corhllt"
	or name == "corhlt" or name == "armhlt" or name == "legmg"
	or name == "armguard" or name == "corpun" or name == "legguard"
	or name == "armdl" or name == "cordl" or name == "legctl" then
		uDef.buildtime = math.ceil(uDef.buildtime * 0.009) * 100	-- 0.9x buildtime
	end

	if uDef.customparams.subfolder and uDef.buildtime and (uDef.customparams.subfolder == "CorShips" or uDef.customparams.subfolder == "ArmShips") then
		uDef.buildtime = math.ceil(uDef.buildtime * 0.015) * 100	-- 1.5x buildtime
	end

	if name == "armfast" then
		uDef.metalcost = math.floor(uDef.metalcost *0.9)
		uDef.energycost = math.floor(uDef.energycost *0.9)
		uDef.buildtime = math.floor(uDef.buildtime *0.9)
	end

	if name == "cortermite" then
		uDef.metalcost = math.floor(uDef.metalcost *0.9)
		uDef.energycost = math.floor(uDef.energycost *0.9)
		uDef.buildtime = math.floor(uDef.buildtime *0.9)
		uDef.speed = 50
	end

	if name == "armepoch" then
		uDef.metalcost = math.floor(uDef.metalcost *1.15)
		uDef.energycost = math.floor(uDef.energycost *1.15)
		uDef.buildtime = math.floor(uDef.buildtime *1.15)
		uDef.weapondefs.heavyplasma.damage.default = 500
		uDef.weapondefs.heavyplasma.reloadtime = 3.5
		uDef.weapondefs.heavyplasma.areaofeffect = 160
		uDef.weapondefs.heavyplasma.burstrate = 0.8
		uDef.weapondefs.heavyplasma.explosiongenerator = "custom:genericshellexplosion-large-aoe"
		uDef.weapondefs.heavyplasma.impulsefactor = 1
	end
	if name == "corblackhy" then
		uDef.metalcost = math.floor(uDef.metalcost *1.15)
		uDef.energycost = math.floor(uDef.energycost *1.15)
		uDef.buildtime = math.floor(uDef.buildtime *1.15)
		uDef.weapondefs.heavyplasma.damage.default = 600
		uDef.weapondefs.heavyplasma.reloadtime = 5.5
		uDef.weapondefs.heavyplasma.areaofeffect = 240
		uDef.weapondefs.heavyplasma.burstrate = 0.8
		uDef.weapondefs.heavyplasma.explosiongenerator = "custom:genericshellexplosion-large-aoe"
		uDef.weapondefs.heavyplasma.impulsefactor = 1
	end
	if name == "corkorg" then
		uDef.speed = 37
	end

	if name == "armcom" or name == "corcom" or name == "legcom" then
		uDef.energymake = 30
	end

	if (uDef.customparams.subfolder == "ArmBuildings/LandFactories" 
	or uDef.customparams.subfolder == "CorBuildings/LandFactories" 
	or uDef.customparams.subfolder == "ArmBuildings/SeaFactories" 
	or uDef.customparams.subfolder == "CorBuildings/SeaFactories"
	or uDef.customparams.subfolder == "Legion/Labs")
	and uDef.customparams.techlevel == 1 then
		uDef.metalcost = uDef.metalcost - 150
		uDef.buildtime = uDef.buildtime - 1500
		uDef.energycost = uDef.energycost - 250
		uDef.workertime = 150
	end

	if name == "corak" then
		uDef.metalcost = 42
		uDef.energycost = 820
		uDef.buildtime = 1250
	end
	if name == "armflash" then
		uDef.speed = 101
	end

	if name == "armmanni" then
		uDef.energycost = 18500
	end
	if name == "armbull" then
		uDef.speed = 60
	end
	if name == "armlatnk" then
		uDef.weapondefs.lightning.damage.default = 22
		uDef.weapondefs.lightning.reloadtime = 1.5
		uDef.weapondefs.lightning.range = 300
	end
	if name == "corgol" then
		uDef.energycost = 28000
	end

	if name == "coraak" then
		uDef.script = "Units/coraak_clean.cob"
		uDef.health = 3200
		uDef.weapondefs = {
			coraabot_missile1 = {
				areaofeffect = 24,
				avoidfeature = false,
				burnblow = true,
				canattackground = false,
				castshadow = false,
				cegtag = "missiletrailaa",
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.15,
				explosiongenerator = "custom:genericshellexplosion-tiny-aa",
				firestarter = 70,
				fixedlauncher = true,
				flighttime = 1.9,
				impulsefactor = 0,
				metalpershot = 0,
				model = "cormissile.s3o",
				name = "Missiles",
				noselfdamage = true,
				range = 1300,
				reloadtime = 1.6,
				smokecolor = 0.5,
				smokeperiod = 6,
				smokesize = 6,
				smoketime = 12,
				smoketrail = true,
				smoketrailcastshadow = false,
				soundhit = "xplosml2",
				soundhitvolume = 7.5,
				soundhitwet = "splshbig",
				soundstart = "rocklit1",
				soundstartvolume = 7.5,
				startvelocity = 640,
				texture1 = "null",
				texture2 = "smoketrailaa",
				tolerance = 15000,
				tracks = true,
				turnrate = 30000,
				turret = true,
				weaponacceleration = 141,
				weapontimer = 5,
				weapontype = "MissileLauncher",
				weaponvelocity = 825,
				damage = {
					vtol = 250,
				},
			},
			botflak = {
				accuracy = 1000,
				areaofeffect = 140,
				avoidfeature = false,
				burnblow = true,
				canattackground = false,
				cegtag = "flaktrailaa",
				craterareaofeffect = 140,
				craterboost = 0,
				cratermult = 0,
				cylindertargeting = 2,
				edgeeffectiveness = 1,
				explosiongenerator = "custom:flak",
				impulsefactor = 0,
				name = "Heavy g2a flak cannon",
				noselfdamage = true,
				range = 775,
				reloadtime = 5.5,
				soundhit = "flakhit",
				soundhitwet = "splsmed",
				soundstart = "flakfire",
				stages = 0,
				turret = true,
				weapontimer = 1,
				weapontype = "Cannon",
				weaponvelocity = 1550,
				damage = {
					vtol = 300,
				},
				rgbcolor = {
					[1] = 1,
					[2] = 0.33,
					[3] = 0.7,
				},
			},
		}
		uDef.weapons = {
			[1] = {
				badtargetcategory = "LIGHTAIRSCOUT",
				def = "CORAABOT_MISSILE1",
				onlytargetcategory = "VTOL",
			},
			[2] = {
				badtargetcategory = "LIGHTAIRSCOUT",
				def = "BOTFLAK",
				onlytargetcategory = "VTOL",
			},
		}
	end
	if name == "armaak" then
		uDef.script = "Units/armaak_clean.cob"
		uDef.health = 2200
		uDef.weapondefs = {	
			longrangemissile = {
				areaofeffect = 24,
				avoidfeature = false,
				burnblow = true,
				canattackground = false,
				castshadow = false,
				cegtag = "missiletrailaa",
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.15,
				explosiongenerator = "custom:genericshellexplosion-tiny-aa",
				firestarter = 70,
				fixedlauncher = true,
				flighttime = 1.8,
				impulsefactor = 0,
				metalpershot = 0,
				model = "cormissile.s3o",
				name = "Long-Range Anti-Air Missile Launcher",
				noselfdamage = true,
				proximitypriority = -1,
				range = 1200,
				reloadtime = 1.5,
				smokecolor = 1,
				smokeperiod = 6,
				smokesize = 5.5,
				smoketime = 11,
				smoketrail = true,
				smoketrailcastshadow = false,
				soundhit = "xplosml2",
				soundhitvolume = 7.5,
				soundhitwet = "splssml",
				soundstart = "rocklit1",
				soundstartvolume = 7.5,
				startvelocity = 590,
				texture1 = "null",
				texture2 = "smoketrailaa3",
				tolerance = 15000,
				tracks = true,
				turnrate = 30000,
				turret = true,
				weaponacceleration = 150,
				weapontimer = 6,
				weapontype = "MissileLauncher",
				weaponvelocity = 1000,
				damage = {
					vtol = 150,
				},
			},
			shortrangemissile = {
				areaofeffect = 24,
				avoidfeature = false,
				burnblow = true,
				canattackground = false,
				castshadow = false,
				cegtag = "missiletrailaa",
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.15,
				explosiongenerator = "custom:genericshellexplosion-tiny-aa",
				firestarter = 70,
				fixedlauncher = true,
				flighttime = 1.85,
				impulsefactor = 0,
				metalpershot = 0,
				model = "cormissile.s3o",
				name = "Medium-Range Anti-Air Missile Launcher",
				noselfdamage = true,
				proximitypriority = 1,
				range = 880,
				reloadtime = 0.7,
				smokecolor = 1,
				smokeperiod = 6,
				smokesize = 2,
				smoketime = 11,
				smoketrail = true,
				smoketrailcastshadow = false,
				soundhit = "xplosml2",
				soundhitvolume = 7.5,
				soundhitwet = "splshbig",
				soundstart = "rocklit1",
				soundstartvolume = 7.5,
				startvelocity = 100,
				texture1 = "null",
				texture2 = "smoketrailaa",
				tolerance = 26000,
				tracks = true,
				turnrate = 30000,
				turret = true,
				weaponacceleration = 400,
				weapontimer = 5,
				weapontype = "MissileLauncher",
				weaponvelocity = 800,
				damage = {
					vtol = 100,
				},
			},
		}
		uDef.weapons = {
			[1] = {
				badtargetcategory = "NOTAIR LIGHTAIRSCOUT",
				def = "LONGRANGEMISSILE",
				onlytargetcategory = "VTOL",
			},
			[2] = {
				badtargetcategory = "NOTAIR LIGHTAIRSCOUT",
				def = "SHORTRANGEMISSILE",
				onlytargetcategory = "VTOL",
			},
		}
	end


	return uDef
end

return {
	proposed_unit_reworksTweaks = proposed_unit_reworksTweaks,
}
