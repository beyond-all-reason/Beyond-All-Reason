local wreck_metal = 2500
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
--Stats Table:
VFS.Include("unbaconfigs/stats.lua")
VFS.Include("unbaconfigs/buildoptions.lua")
	tablearmcom = {
		acceleration = 0.18,
		activatewhenbuilt = true,
		autoheal = 5,
		brakerate = 1.125,
		buildcostenergy = 26000,
		buildcostmetal = 2700,
		builddistance = 145,
		builder = true,
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
		energymake = 25,
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
		movementclass = "COMMANDERKBOT",
		name = "Commander",
		nochasecategory = "ALL",
		objectname = "ARMCOM",
		pushresistant = true,
		radardistance = 700,
		radaremitheight = 40,
		reclaimable = false,
		seismicsignature = 0,
		selfdestructas = "commanderexplosion",
		selfdestructcountdown = 5,
		shownanospray = false,
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
			[22] = "armfdrag",
			[23] = "armtl",
			[24] = "armfrt",
			[25] = "armfrad",
		},
		customparams = {
			area_mex_def = "armmex",
			iscommander = true,
			model_author = "FireStorm",
			paralyzemultiplier = 0.025,
			subfolder = "",
			techlevel = 2,
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
				metal = "2500",
				object = "ARMCOM_DEAD",
				reclaimable = true,
				seqnamereclamate = "TREE1RECLAMATE",
			},
			heap = {
				blocking = false,
				category = "heaps",
				collisionvolumescales = "35.0 4.0 6.0",
				collisionvolumetype = "cylY",
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
				reclaimable = true,
				resurrectable = 0,
				seqnamereclamate = "TREE1RECLAMATE",
				world = "All Worlds",
			},
		},
		sfxtypes = {
			explosiongenerators = {
				[1] = "custom:com_sea_laser_bubbles",
				[2] = "custom:barrelshot-medium",
			},
			pieceexplosiongenerators = {
				[1] = "deathceg3",
				[2] = "deathceg4",
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
				name = "Light close-quarters g2g/g2a laser",
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
				weapontype = "BeamLaser",
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
				name = "Light underwater-combat laser",
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
					default = 150,
					subs = 75,
				},
			},
			disintegrator = {
				areaofeffect = 36,
				avoidfeature = false,
				avoidfriendly = false,
				avoidground = false,
				bouncerebound = 0,
				cegtag = "dgunprojectile",
				commandfire = true,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				energypershot = 500,
				explosiongenerator = "custom:expldgun",
				firestarter = 100,
				firesubmersed = false,
				groundbounce = true,
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
				waterweapon = true,
				weapontimer = 4.2,
				weapontype = "DGun",
				weaponvelocity = 300,
				customparams = {
					expl_light_heat_radius_mult = 2.8,
					expl_light_heat_strength_mult = 0.66,
					expl_light_mult = 0.35,
					expl_light_radius_mult = 1.15,
				},
				damage = {
					default = 99999,
				},
			},
			repulsor1 = {
				avoidfeature = false,
				craterareaofeffect = 0,
				craterboost = 0,
				cratermult = 0,
				name = "Plasma repulsor",
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
					intercepttype = 479,
					power = 1000,
					powerregen = 20,
					powerregenenergy = 0,
					radius = 30,
					repulser = false,
					smart = true,
					startingpower = 1000,
					visible = false,
					visiblehitframes = 0,
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
			[2] = {
				badtargetcategory = "VTOL",
				def = "ARMCOMSEALASER",
			},
			[3] = {
				def = "DISINTEGRATOR",
				onlytargetcategory = "NOTSUB",
			},
		},
	}
if (Spring.GetModOptions) and Spring.GetModOptions().unba and Spring.GetModOptions().unba == "enabled" then
	tablearmcom.autoheal = 2
	tablearmcom.power = CommanderPower
	tablearmcom.weapondefs.armcomlaser.weapontype = "LaserCannon"
	tablearmcom.weapons = {}
	tablearmcom.script = "armcom_lus.lua"
	tablearmcom.objectname = "UNBAARMCOM.3DO"
		--Weapon: Laser
	tablearmcom.weapondefs.armcomlaser2 = deepcopy(tablearmcom.weapondefs.armcomlaser)
	tablearmcom.weapondefs.armcomlaser.weapontype = "BeamLaser"
	tablearmcom.weapondefs.armcomlaser2.damage.default = Damages[2]
	tablearmcom.weapondefs.armcomlaser2.range = Range[2]
	tablearmcom.weapondefs.armcomlaser2.areaofeffect = AOE[2]
	tablearmcom.weapondefs.armcomlaser2.reloadtime = ReloadTime[2]
for i = 3,11 do
	I = tostring(i)
	H = tostring(i-1)
	tablearmcom.weapondefs["armcomlaser"..I] = deepcopy(tablearmcom.weapondefs["armcomlaser"..H])
	tablearmcom.weapondefs["armcomlaser"..I].damage.default = Damages[i]
	tablearmcom.weapondefs["armcomlaser"..I].range = Range[i]
	tablearmcom.weapondefs["armcomlaser"..I].areaofeffect = AOE[i]
	tablearmcom.weapondefs["armcomlaser"..I].reloadtime = ReloadTime[i]
	if i == 3 then
		tablearmcom.weapondefs.armcomlaser3.rgbcolor = "0.75 0.25 0"
	elseif i == 6 then
		tablearmcom.weapondefs.armcomlaser6.rgbcolor = "0.5 0.5 0"
	elseif i == 8 then
		tablearmcom.weapondefs.armcomlaser8.rgbcolor = "0.25 0.75 0"
	elseif i == 10 then
		tablearmcom.weapondefs.armcomlaser10.rgbcolor = "0 1 0"
	end
end

for i = 1,11 do
	if i == 1 then
		tablearmcom.weapons[1] = {
				def = "ARMCOMLASER",
				onlytargetcategory = "NOTSUB",
				}
	else
		tablearmcom.weapons[i] = {
				def = "ARMCOMLASER"..tostring(i),
				onlytargetcategory = "NOTSUB",
				}
	end
end
	--Weapon: SeaLaser
tablearmcom.weapondefs.armcomsealaser2 = deepcopy(tablearmcom.weapondefs.armcomsealaser)
	tablearmcom.weapondefs["armcomsealaser2"].damage.default = Damages21[2]
	tablearmcom.weapondefs["armcomsealaser2"].damage.subs = Damages22[2]*Damages21[2]
	tablearmcom.weapondefs["armcomsealaser2"].range = Range2[2]
	tablearmcom.weapondefs["armcomsealaser2"].areaofeffect = AOE2[2]
	tablearmcom.weapondefs["armcomsealaser2"].reloadtime = ReloadTime2[2]
for i = 3,11 do
	I = tostring(i)
	H = tostring(i-1)
	tablearmcom.weapondefs["armcomsealaser"..I] = deepcopy(tablearmcom.weapondefs["armcomsealaser"..H])
	tablearmcom.weapondefs["armcomsealaser"..I].damage.default = Damages21[i]
	tablearmcom.weapondefs["armcomsealaser"..I].damage.subs = Damages22[i] * Damages21[i]
	tablearmcom.weapondefs["armcomsealaser"..I].range = Range2[i]
	tablearmcom.weapondefs["armcomsealaser"..I].areaofeffect = AOE2[i]
	tablearmcom.weapondefs["armcomsealaser"..I].reloadtime = ReloadTime2[i]
	if i == 3 then
		tablearmcom.weapondefs.armcomsealaser3.rgbcolor = "0.75 0.25 0"
	elseif i == 6 then
		tablearmcom.weapondefs.armcomsealaser6.rgbcolor = "0.5 0.5 0"
	elseif i == 8 then
		tablearmcom.weapondefs.armcomsealaser8.rgbcolor = "0.25 0.75 0"
	elseif i == 10 then
		tablearmcom.weapondefs.armcomsealaser10.rgbcolor = "0 1 0"
	end
end

for i = 12,22 do
	if i - 11 == 1 then
		tablearmcom.weapons[12] = {
				def = "ARMCOMSEALASER",
				badtargetcategory = "VTOL",
				}
	else
		tablearmcom.weapons[i] = {
				def = "ARMCOMSEALASER"..tostring(i-11),
				badtargetcategory = "VTOL",
				}
	end
end

	--Weapon: Shield

for i = 2,7 do
	I = tostring(i)
	H = tostring(i-1)
	tablearmcom.weapondefs["repulsor"..I] = deepcopy(tablearmcom.weapondefs["repulsor"..H])
	tablearmcom.weapondefs["repulsor"..I].shield.power = ShieldPower[i]
end

for i = 23,29 do
	tablearmcom.weapons[i] = {
			def = "REPULSOR"..tostring(i-22),
			}
end
	
tablearmcom.weapons[30] ={
				def = "DISINTEGRATOR",
				onlytargetcategory = "NOTSUB",
			}
tablearmcom.buildoptions = ArmDefsBuildOptions
for i = 1,11 do
	tablearmcom.featuredefs["dead"..tostring(i)] = deepcopy(tablearmcom.featuredefs.dead)
	tablearmcom.featuredefs["heap"..tostring(i)] = deepcopy(tablearmcom.featuredefs.heap)
	tablearmcom.featuredefs["dead"..tostring(i)].metal = tablearmcom.featuredefs["dead"].metal * WreckMetal[i]
	tablearmcom.featuredefs["heap"..tostring(i)].metal = tablearmcom.featuredefs["heap"].metal * WreckMetal[i]
	tablearmcom.featuredefs["dead"..tostring(i)].featuredead = "heap"..tostring(i)
	tablearmcom.featuredefs["dead"..tostring(i)].resurrectable = 1
end
end
return { armcom = deepcopy(tablearmcom) }
