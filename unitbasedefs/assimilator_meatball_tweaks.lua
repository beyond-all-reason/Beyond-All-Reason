local function AssimilatorMeatballTweaks(name, uDef)

		if name == "armmeatball" then
				-- +5000 health (8000 -> 13000)
				uDef.health = 13000
				-- +400 sonar and less LoS (800 -> 700)
				uDef.sonardistance = 400
				uDef.sightdistance = 700
				--slower turnrate 1212 -> 606
				uDef.turnrate = 606
				-- Add light and heavy mines to build options
				uDef.weapondefs = {
					lrpc = {
					accuracy = 1500,
					areaofeffect = 75,
					avoidfeature = false,
					avoidfriendly = false,
					cegtag = "arty-large",
					collidefriendly = false,
					craterareaofeffect = 116,
					craterboost = 0.1,
					cratermult = 0.1,
					edgeeffectiveness = 0.15,
					explosiongenerator = "custom:genericshellexplosion-medium",
					gravityaffected = "true",
					heightboostfactor = 8,
					impulsefactor = 0.5,
					leadbonus = 0,
					model = "artshell-large.s3o",
					name = "g2g plasma cannon",
					noselfdamage = true,
					range = 900,
					reloadtime = 0.3,
					soundhit = "xplomed2",
					soundhitwet = "splshbig",
					soundstart = "KroGun1",
					soundhitvolume = 38,
					soundstartvolume = 24,
					turret = true,
					weapontype = "Cannon",
					weaponvelocity = 300,
					damage = {
						default = 200,
					},
				},

	coax_depthcharge = {
				avoidfeature = false,
				avoidfriendly = false,
				avoidground = false,
				bouncerebound = 0.6,
				bounceslip = 0.6,
				burnblow = true,
				collidefriendly = false,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.15,
				explosiongenerator = "custom:genericshellexplosion-small-uw",
				flighttime = 1.75,
				gravityaffected = "true",
				groundbounce = true,
				impulsefactor = 0.123,
				model = "cordepthcharge.s3o",
				mygravity = 0.2,
				name = "Depthcharge launcher",
				noselfdamage = true,
				numbounce = 1,
				range = 550,
				reloadtime = 1.5,
				soundhit = "xplodep2",
				soundhitvolume = 3,
				soundhitwet = "splsmed",
				soundhitwetvolume = 12,
				soundstart = "torpedo1",
				startvelocity = 190,
				tracks = true,
				trajectoryheight = 0.6,
				turnrate = 64000,
				turret = true,
				waterweapon = true,
				weaponacceleration = 75,
				weapontype = "TorpedoLauncher",
				weaponvelocity = 300,
				damage = {
					default = 225,
				},
		},
				}
				uDef.weapons = {
					[1] = {
					badtargetcategory = "GROUNDSCOUT",
					def = "lrpc",
					onlytargetcategory = "SURFACE",
					},
					[2] = {
					badtargetcategory = "NOTSUB",
					def = "COAX_DEPTHCHARGE",
					onlytargetcategory = "NOTHOVER",
					},
				}
		end

		if name == "armassimilator" then
				uDef.health = 10000
				uDef.sightdistance = 470
				uDef.airsightdistance = 900
				uDef.nochasecategory = "VTOL"
				--uDef.movementclass = "HBOT4"
				uDef.weapondefs = {
				machinegun = {
				accuracy = 50,
				areaofeffect = 25,
				avoidfriendly = false,
				avoidfeature = false,
				collidefriendly = false,
				collidefeature = true,
				beamtime = 0.09,
				corethickness = 0.45,
				duration = 0.09,
				explosiongenerator = "custom:genericshellexplosion-tiny-aa",
				energypershot = 0,
				falloffrate = 0,
				firestarter = 50,
				interceptedbyshieldtype = 4,
				minintensity = "1",
				name = "scav rapid fire plasma gun",
				range = 550,
				reloadtime = 0.1,
				weapontype = "LaserCannon",
				rgbcolor = "1 0 0",
				rgbcolor2 = "1 1 1",
				soundtrigger = true,
				soundstart = "tgunshipfire",
				texture1 = "shot",
				texture2 = "empty",
				thickness = 7.5,
				tolerance = 1000,
				turret = true,
				weaponvelocity = 1000,
				customparams = {
					--isupgraded = isupgraded,
					--damagetype = "ehbotkarganneth",
				},
				damage = {
					default = 40,
					vtol = 25,
				},
			},
		arm_advsam = {
				areaofeffect = 425,
				avoidfeature = false,
				avoidfriendly = false,
				burnblow = true,
				canattackground = false,
				castshadow = false,
				cegtag = "missiletrailaa-large",
				collidefriendly = false,
				craterareaofeffect = 425,
				craterboost = 0,
				cratermult = 0,
				edgeeffectiveness = 0.75,
				energypershot = 1500,
				explosiongenerator = "custom:genericshellexplosion-huge-aa",
				firestarter = 90,
				flighttime = 10,
				impulsefactor = 0,
				metalpershot = 0,
				model = "corscreamermissile.s3o",
				name = "Heavy long-range g2a guided missile launcher",
				noselfdamage = true,
				proximitypriority = -1,
				range = 1000,
				reloadtime = 4,
				smokecolor = 0.9,
				smokeperiod = 2,
				smokesize = 6,
				smoketime = 20,
				smoketrail = true,
				smoketrailcastshadow = false,
				soundhit = "impact",
				soundhitvolume = 8,
				soundhitwet = "splslrg",
				soundstart = "aarocket",
				soundstartvolume = 8,
				sprayangle = 10000,
				startvelocity = 10,
				stockpile = true,
				stockpiletime = 38,
				texture1 = "null",
				texture2 = "smoketrailaaflak",
				tolerance = 10000,
				tracks = true,
				trajectoryheight = 0.50,
				turnrate = 99000,
				turret = true,
				weaponacceleration = 200,
				weapontype = "MissileLauncher",
				weaponvelocity = 600,
				customparams = {
					stockpilelimit = 2,
				},
				damage = {
					vtol = 750,
				},
			},
		}
			uDef.weapons ={

	[1] = {
				badtargetcategory = "LIGHTAIRSCOUT GROUNDSCOUT",
				def = "machinegun",
				onlytargetcategory = "NOTSUB",
			},
	[2] = {
				badtargetcategory = "NOTAIR LIGHTAIRSCOUT",
				def = "ARM_ADVSAM",
				onlytargetcategory = "VTOL",
			},
				}
	end
	if name == "armshltxuw" then
	for index in pairs(uDef.buildoptions) do
			if 	uDef.buildoptions[index]=="armassimilator"  then
				uDef.buildoptions[index] = nil
			end
		end
	end

	return uDef
end

return {
	AssimilatorMeatballTweaks = AssimilatorMeatballTweaks,
}
