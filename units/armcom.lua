local wreck_metal = 2500
if (Spring.GetModOptions) then
    wreck_metal = Spring.GetModOptions().comm_wreck_metal or 2500
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

tablearmcom = {
		acceleration = 0.18,
		activatewhenbuilt = true,
		autoheal = 2,
		brakerate = 1.125,
		buildcostenergy = 26700,
		buildcostmetal = 2670,
		builddistance = 130,
		builder = true,
		shownanospray = false,
		buildpic = "ARMCOM.DDS",
		buildtime = 75000,
		cancapture = true,
		canmanualfire = true,
		canmove = true,
		capturespeed = 1800,
		category = "ALL WEAPON NOTSUB COMMANDER NOTSHIP NOTAIR NOTHOVER SURFACE CANBEUW",
		cloakcost = 100,
		cloakcostmoving = 1000,
		collisionvolumeoffsets = "0 -1 0",
		collisionvolumescales = "27 39 27",
		collisionvolumetype = "CylY",
		corpse = "DEAD",
		description = "Commander",
		energymake = 35,
		explodeas = "commanderExplosion",
		footprintx = 2,
		footprintz = 2,
		hidedamage = true,
		icontype = "armcommander",
		idleautoheal = 5,
		idletime = 1800,
		losemitheight = 40,
		mass = 5000,
		maxdamage = 3000,
		maxslope = 20,
		maxvelocity = 1.25,
		maxwaterdepth = 35,
		metalmake = 1.5,
		mincloakdistance = 50,
		movementclass = "AKBOT2",
		name = "Commander",
		nochasecategory = "ALL",
		objectname = "ARMCOM",
		pushresistant = true,
		radardistance = 700,
		radaremitheight = 40,
		reclaimable = false,
		script = "armcom_lus.lua",
		seismicsignature = 0,
		selfdestructas = "commanderexplosion",
		selfdestructcountdown = 5,
		showplayername = true,
		sightdistance = 450,
		sonardistance = 450,
		terraformspeed = 1500,
		turninplaceanglelimit = 140,
		turninplacespeedlimit = 0.825,
		turnrate = 1148,
		upright = true,
		workertime = 300,
		buildoptions = {
			[1] = "armsolar",
			[2] = "armwin",
			[3] = "armmstor",
			[4] = "armestor",
			[5] = "armmex",
			[6] = "armmakr",
			[7] = "armlab",
			[8] = "armvp",
			[9] = "armap",
			[10] = "armeyes",
			[11] = "armrad",
			[12] = "armdrag",
			[13] = "armllt",
			[14] = "armrl",
			[15] = "armdl",
			[16] = "armtide",
			[17] = "armuwms",
			[18] = "armuwes",
			[19] = "armuwmex",
			[20] = "armfmkr",
			[21] = "armsy",
			-- [22] = "armsonar",
			[22] = "armfdrag",
			[23] = "armtl",
			[24] = "armgplat",
			[25] = "armfrt",
			[26] = "armfrad",
			-- [28] = "seaplatform",
		},
		customparams = {
			--death_sounds = "commander",
			area_mex_def = "armmex",
			iscommander = true,
			paralyzemultiplier = 0.025,
		},
		featuredefs = {
			dead = {
				blocking = true,
				collisionvolumeoffsets = "0 0 0",
				collisionvolumescales = "47 10 47",
				collisionvolumetype = "CylY",
				damage = 10000,
				description = "Commander Wreckage",
				energy = 0,
				featuredead = "HEAP",
				featurereclamate = "SMUDGE01",
				footprintx = 2,
				footprintz = 2,
				height = 20,
				hitdensity = 100,
				metal = wreck_metal,
				object = "ARMCOM_DEAD",
				reclaimable = true,
				seqnamereclamate = "TREE1RECLAMATE",
			},
			heap = {
				blocking = false,
				category = "heaps",
				damage = 5000,
				description = "Commander Debris",
				energy = 0,
				featurereclamate = "SMUDGE01",
				footprintx = 2,
				footprintz = 2,
				height = 4,
				hitdensity = 100,
				metal = 1250,
				object = "2X2F",
                collisionvolumescales = "35.0 4.0 6.0",
                collisionvolumetype = "cylY",
				reclaimable = true,
				resurrectable = 0,
				seqnamereclamate = "TREE1RECLAMATE",
				world = "All Worlds",
			},
		},
		sfxtypes = { 
 			 pieceExplosionGenerators = { 
 				"deathceg3",
 				"deathceg4",
 			}, 
			explosiongenerators = {
				[1] = "custom:com_sea_laser_bubbles",
				[2] = "custom:barrelshot-medium",
			},
		},
		sounds = {
			build = "nanlath1",
			canceldestruct = "cancel2",
			capture = "capture1",
			cloak = "kloak1",
			repair = "repair1",
			uncloak = "kloak1un",
			underattack = "warning2",
			unitcomplete = "kcarmmov",
			working = "reclaim1",
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
				[1] = "kcarmmov",
			},
			select = {
				[1] = "kcarmsel",
			},
		},
		weapondefs = {
			disintegrator = {
				areaofeffect = 36,
				avoidfeature = false,
				avoidfriendly = false,
				avoidground = false,
				commandfire = true,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				--waterbounce = true, -- weapon will stick to the surface
				groundbounce = true,
				bounceRebound = 0, --stick the explosion to ground with 0 vertical component
				waterweapon = true, --dgun can pass trough water
				firesubmersed = false, -- but not _fire_ underwater
				energypershot = 500,
                cegTag = "dgunprojectile",
				explosiongenerator = "custom:expldgun",
				firestarter = 100,
				impulseboost = 0,
				impulsefactor = 0,
				name = "Disintegrator",
				noexplode = true,
				noselfdamage = true,
				range = 250,
				reloadtime = 0.9,
				soundhit = "xplomas2",
				soundhitwet = "sizzle",
				soundhitwetvolume = 0.5,
				soundstart = "disigun1",
				soundtrigger = true,
				tolerance = 10000,
				turret = true,
				weapontimer = 4.2,
				weapontype = "DGun",
				weaponvelocity = 300,
				damage = {
					default = 99999,
				},
			},
			armcomlaser = {
				areaofeffect = 12,
				avoidfeature = false,
				beamtime = 0.1,
				corethickness = 0.1,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				cylindertargeting = 1,
				edgeeffectiveness = 0.99,
				explosiongenerator = "custom:laserhit-small-red",
				firestarter = 70,
				impactonly = 1,
				impulseboost = 0,
				impulsefactor = 0,
				laserflaresize = 7,
				name = "J7Laser",
				noselfdamage = true,
				range = 300,
				reloadtime = 0.4,
				rgbcolor = "1 0 0",
				soundhitdry = "",
				soundhitwet = "sizzle",
				soundhitwetvolume = 0.5,
				soundstart = "lasrfir1",
				soundtrigger = 1,
				targetmoveerror = 0.05,
				thickness = 2,
				tolerance = 10000,
				turret = true,
				weapontype = "LaserCannon",
				weaponvelocity = 900,
				damage = {
					bombers = 180,
					default = 75,
					fighters = 110,
					subs = 5,
				},
			},
			armcomsealaser = {
				areaofeffect = 12,
				avoidfeature = false,
				beamtime = 0.3,
				corethickness = 0.4,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				cylindertargeting = 1,
				edgeeffectiveness = 1,
				explosiongenerator = "custom:laserhit-small-blue",
				firestarter = 35,
				firesubmersed = true,
				impactonly = 1,
				impulseboost = 0,
				impulsefactor = 0,
				intensity = 0.3,
				laserflaresize = 7,
				name = "J7NSLaser",
				noselfdamage = true,
				range = 260,
				reloadtime = 1,
				rgbcolor = "0.2 0.2 0.6",
				rgbcolor2 = "0.2 0.2 0.2",
				soundhitdry = "",
				soundhitwet = "sizzle",
				soundhitwetvolume = 0.5,
				soundstart = "uwlasrfir1",
				soundtrigger = 1,
				targetmoveerror = 0.05,
				thickness = 5,
				tolerance = 10000,
				turret = true,
				waterweapon = true,
				weapontype = "BeamLaser",
				weaponvelocity = 900,
				damage = {
					default = 125*0.5,
					subs = 75*0.25,
				},
			},
			repulsor = {
				avoidfeature = false,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				name = "PlasmaRepulsor",
				range = 50,
				soundhitwet = "sizzle",
				soundhitwetvolume = 0.5,
				weapontype = "Shield",
				damage = {
					default = 100,
				},
				shield = {
					alpha = 0.25,
					energyuse = 0,
					force = 2.5,
					intercepttype = 511,
					power = 1000,
					powerregen = 20,
					powerregenenergy = 0,
					radius = 30,
					repulser = false,
					smart = true,
					startingpower = 1000,
					visible = true,
					visiblehitframes = 70,
					badcolor = {
						[1] = 1,
						[2] = 0.2,
						[3] = 0.2,
						[4] = 0.25,
					},
					goodcolor = {
						[1] = 0.2,
						[2] = 1,
						[3] = 0.2,
						[4] = 0.2,
					},
				},
			},
		},
		weapons = {
			[1] = {
				def = "ARMCOMLASER",
				onlytargetcategory = "NOTSUB",
			},
			[12] = {
				badtargetcategory = "VTOL",
				def = "ARMCOMSEALASER",
			},
			[13] = {
				def = "DISINTEGRATOR",
				onlytargetcategory = "NOTSUB",
			},
			[14] = {
				def = "REPULSOR",
				onlytargetcategory = "NOTSUB",
			},
		},
	}


tablearmcom.weapondefs.armcomlaser2 = deepcopy(tablearmcom.weapondefs.armcomlaser)
tablearmcom.weapondefs.armcomlaser3 = deepcopy(tablearmcom.weapondefs.armcomlaser2)
tablearmcom.weapondefs.armcomlaser3.rgbcolor = "0.75 0.25 0"
tablearmcom.weapondefs.armcomlaser3.damage.default = 125
tablearmcom.weapondefs.armcomlaser4 = deepcopy(tablearmcom.weapondefs.armcomlaser3)
tablearmcom.weapondefs.armcomlaser5 = deepcopy(tablearmcom.weapondefs.armcomlaser4)
tablearmcom.weapondefs.armcomlaser6 = deepcopy(tablearmcom.weapondefs.armcomlaser5)
tablearmcom.weapondefs.armcomlaser6.rgbcolor = "0.5 0.5 0"
tablearmcom.weapondefs.armcomlaser6.damage.default = 150
tablearmcom.weapondefs.armcomlaser7 = deepcopy(tablearmcom.weapondefs.armcomlaser6)
tablearmcom.weapondefs.armcomlaser8 = deepcopy(tablearmcom.weapondefs.armcomlaser7)
tablearmcom.weapondefs.armcomlaser8.rgbcolor = "0.25 0.75 0"
tablearmcom.weapondefs.armcomlaser8.damage.default = 200
tablearmcom.weapondefs.armcomlaser9 = deepcopy(tablearmcom.weapondefs.armcomlaser8)
tablearmcom.weapondefs.armcomlaser10 = deepcopy(tablearmcom.weapondefs.armcomlaser9)
tablearmcom.weapondefs.armcomlaser10.rgbcolor = "0 1 0"
tablearmcom.weapondefs.armcomlaser10.damage.default = 250
tablearmcom.weapondefs.armcomlaser11 = deepcopy(tablearmcom.weapondefs.armcomlaser10)
for i = 1,11 do
tablearmcom.weapons[i] = deepcopy(tablearmcom.weapons[1])
end
tablearmcom.weapons[1].def = "ARMCOMLASER"
tablearmcom.weapons[2].def = "ARMCOMLASER2"
tablearmcom.weapons[3].def = "ARMCOMLASER3"
tablearmcom.weapons[4].def = "ARMCOMLASER4"
tablearmcom.weapons[5].def = "ARMCOMLASER5"
tablearmcom.weapons[6].def = "ARMCOMLASER6"
tablearmcom.weapons[7].def = "ARMCOMLASER7"
tablearmcom.weapons[8].def = "ARMCOMLASER8"
tablearmcom.weapons[9].def = "ARMCOMLASER9"
tablearmcom.weapons[10].def = "ARMCOMLASER10"
tablearmcom.weapons[11].def = "ARMCOMLASER11"	

tablearmcom.weapondefs.repulsor2 = deepcopy(tablearmcom.weapondefs.repulsor)
tablearmcom.weapondefs.repulsor2.shield.power = 1250
tablearmcom.weapondefs.repulsor3 = deepcopy(tablearmcom.weapondefs.repulsor2)
tablearmcom.weapondefs.repulsor3.shield.power = 1500
tablearmcom.weapondefs.repulsor4 = deepcopy(tablearmcom.weapondefs.repulsor3)
tablearmcom.weapondefs.repulsor4.shield.power = 2000
tablearmcom.weapondefs.repulsor5 = deepcopy(tablearmcom.weapondefs.repulsor4)
tablearmcom.weapondefs.repulsor5.shield.power = 2500
tablearmcom.weapondefs.repulsor6 = deepcopy(tablearmcom.weapondefs.repulsor5)
tablearmcom.weapondefs.repulsor6.shield.power = 3000
tablearmcom.weapondefs.repulsor7 = deepcopy(tablearmcom.weapondefs.repulsor6)
tablearmcom.weapondefs.repulsor7.shield.power = 4000
tablearmcom.weapondefs.repulsor8 = deepcopy(tablearmcom.weapondefs.repulsor7)
tablearmcom.weapondefs.repulsor9 = deepcopy(tablearmcom.weapondefs.repulsor8)
tablearmcom.weapondefs.repulsor10 = deepcopy(tablearmcom.weapondefs.repulsor9)
tablearmcom.weapondefs.repulsor11 = deepcopy(tablearmcom.weapondefs.repulsor10)

for i = 15,24 do
tablearmcom.weapons[i] = deepcopy(tablearmcom.weapons[14])
end

tablearmcom.weapons[14].def = "REPULSOR"	
tablearmcom.weapons[15].def = "REPULSOR2"		
tablearmcom.weapons[16].def = "REPULSOR3"		
tablearmcom.weapons[17].def = "REPULSOR4"	
tablearmcom.weapons[18].def = "REPULSOR5"	
tablearmcom.weapons[19].def = "REPULSOR6"	
tablearmcom.weapons[20].def = "REPULSOR7"	
tablearmcom.weapons[21].def = "REPULSOR8"	
tablearmcom.weapons[22].def = "REPULSOR9"	
tablearmcom.weapons[23].def = "REPULSOR10"	
tablearmcom.weapons[24].def = "REPULSOR11"	
		
tablearmcom.weapons[13].def = "DISINTEGRATOR"	

tablearmcom.weapons[12].def = "ARMCOMSEALASER"	

return { armcom = deepcopy(tablearmcom) }



