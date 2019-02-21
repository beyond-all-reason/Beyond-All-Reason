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
	tablecorcom = {
		acceleration = 0.18,
		activatewhenbuilt = true,
		autoheal = 5,
		brakerate = 1.125,
		buildcostenergy = 26000,
		buildcostmetal = 2700,
		builddistance = 145,
		builder = true,
		buildpic = "CORCOM.DDS",
		buildtime = 75000,
		cancapture = true,
		canmanualfire = true,
		canmove = true,
		capturespeed = 1800,
		category = "ALL WEAPON COMMANDER NOTSUB NOTSHIP NOTAIR NOTHOVER SURFACE CANBEUW",
		cloakcost = 100,
		cloakcostmoving = 1000,
		collisionvolumeoffsets = "0 -1 -6",
		collisionvolumescales = "27 39 27",
		collisionvolumetype = "CylY",
		corpse = "DEAD",
		description = "Commander",
		energymake = 25,
		explodeas = "commanderexplosion",
		footprintx = 2,
		footprintz = 2,
		hidedamage = true,
		icontype = "corcommander",
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
		objectname = "CORCOM",
		pushresistant = true,
		radardistance = 700,
		radaremitheight = 40,
		reclaimable = false,
		seismicsignature = 0,
		selfdestructas = "commanderExplosion",
		selfdestructcountdown = 5,
		shownanospray = false,
		showplayername = true,
		sightdistance = 450,
		sonardistance = 450,
		terraformspeed = 1500,
		turninplaceanglelimit = 140,
		turninplacespeedlimit = 0.825,
		turnrate = 1133,
		upright = true,
		workertime = 300,
		buildoptions = {
			[1] = "corsolar",
			[2] = "corwin",
			[3] = "cormstor",
			[4] = "corestor",
			[5] = "cormex",
			[6] = "cormakr",
			[7] = "corlab",
			[8] = "corvp",
			[9] = "corap",
			[10] = "coreyes",
			[11] = "corrad",
			[12] = "cordrag",
			[13] = "corllt",
			[14] = "corrl",
			[15] = "cordl",
			[16] = "cortide",
			[17] = "coruwms",
			[18] = "coruwes",
			[19] = "coruwmex",
			[20] = "corfmkr",
			[21] = "corsy",
			[22] = "corfdrag",
			[23] = "cortl",
			[24] = "corfrt",
			[25] = "corfrad",
		},
		customparams = {
			area_mex_def = "cormex",
			iscommander = true,
			model_author = "Mr Bob",
			paralyzemultiplier = 0.025,
			subfolder = "",
			techlevel = 2,
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "0 0 0",
				collisionvolumescales = "35 12 54",
				collisionvolumetype = "cylY",
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
				object = "CORCOM_DEAD",
				reclaimable = true,
				seqnamereclamate = "TREE1RECLAMATE",
				world = "All Worlds",
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
				object = "2X2C",
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
			build = "nanlath2",
			canceldestruct = "cancel2",
			capture = "capture2",
			cloak = "kloak2",
			repair = "repair2",
			uncloak = "kloak2un",
			underattack = "warning2",
			unitcomplete = "kccorsel",
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
				[1] = "kcormov",
			},
			select = {
				[1] = "kccorsel",
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
				laserflaresize = 5,
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
				corethickness = 0.1,
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
				laserflaresize = 5,
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
	tablecorcom.autoheal = 2
	tablecorcom.power = CommanderPower
	tablecorcom.weapondefs.armcomlaser.weapontype = "LaserCannon"
	tablecorcom.weapons = {}
	tablecorcom.script = "corcom_lus.lua"
	tablecorcom.objectname = "UNBACORCOM.3DO"
		--Weapon: Laser
	tablecorcom.weapondefs.armcomlaser2 = deepcopy(tablecorcom.weapondefs.armcomlaser)
	tablecorcom.weapondefs.armcomlaser.weapontype = "BeamLaser"
	tablecorcom.weapondefs.armcomlaser2.damage.default = Damages[2]
	tablecorcom.weapondefs.armcomlaser2.range = Range[2]
	tablecorcom.weapondefs.armcomlaser2.areaofeffect = AOE[2]
	tablecorcom.weapondefs.armcomlaser2.reloadtime = ReloadTime[2]
for i = 3,11 do
	I = tostring(i)
	H = tostring(i-1)
	tablecorcom.weapondefs["armcomlaser"..I] = deepcopy(tablecorcom.weapondefs["armcomlaser"..H])
	tablecorcom.weapondefs["armcomlaser"..I].damage.default = Damages[i]
	tablecorcom.weapondefs["armcomlaser"..I].range = Range[i]
	tablecorcom.weapondefs["armcomlaser"..I].areaofeffect = AOE[i]
	tablecorcom.weapondefs["armcomlaser"..I].reloadtime = ReloadTime[i]
	if i == 3 then
		tablecorcom.weapondefs.armcomlaser3.rgbcolor = "0.75 0.25 0"
	elseif i == 6 then
		tablecorcom.weapondefs.armcomlaser6.rgbcolor = "0.5 0.5 0"
	elseif i == 8 then
		tablecorcom.weapondefs.armcomlaser8.rgbcolor = "0.25 0.75 0"
	elseif i == 10 then
		tablecorcom.weapondefs.armcomlaser10.rgbcolor = "0 1 0"
	end
end

for i = 1,11 do
	if i == 1 then
		tablecorcom.weapons[1] = {
				def = "ARMCOMLASER",
				onlytargetcategory = "NOTSUB",
				}
	else
		tablecorcom.weapons[i] = {
				def = "ARMCOMLASER"..tostring(i),
				onlytargetcategory = "NOTSUB",
				}
	end
end
	--Weapon: SeaLaser
tablecorcom.weapondefs.armcomsealaser2 = deepcopy(tablecorcom.weapondefs.armcomsealaser)
	tablecorcom.weapondefs["armcomsealaser2"].damage.default = Damages21[2]
	tablecorcom.weapondefs["armcomsealaser2"].damage.subs = Damages22[2]*Damages21[2]
	tablecorcom.weapondefs["armcomsealaser2"].range = Range2[2]
	tablecorcom.weapondefs["armcomsealaser2"].areaofeffect = AOE2[2]
	tablecorcom.weapondefs["armcomsealaser2"].reloadtime = ReloadTime2[2]
for i = 3,11 do
	I = tostring(i)
	H = tostring(i-1)
	tablecorcom.weapondefs["armcomsealaser"..I] = deepcopy(tablecorcom.weapondefs["armcomsealaser"..H])
	tablecorcom.weapondefs["armcomsealaser"..I].damage.default = Damages21[i]
	tablecorcom.weapondefs["armcomsealaser"..I].damage.subs = Damages22[i] * Damages21[i]
	tablecorcom.weapondefs["armcomsealaser"..I].range = Range2[i]
	tablecorcom.weapondefs["armcomsealaser"..I].areaofeffect = AOE2[i]
	tablecorcom.weapondefs["armcomsealaser"..I].reloadtime = ReloadTime2[i]
	if i == 3 then
		tablecorcom.weapondefs.armcomsealaser3.rgbcolor = "0.75 0.25 0"
	elseif i == 6 then
		tablecorcom.weapondefs.armcomsealaser6.rgbcolor = "0.5 0.5 0"
	elseif i == 8 then
		tablecorcom.weapondefs.armcomsealaser8.rgbcolor = "0.25 0.75 0"
	elseif i == 10 then
		tablecorcom.weapondefs.armcomsealaser10.rgbcolor = "0 1 0"
	end
end

for i = 12,22 do
	if i - 11 == 1 then
		tablecorcom.weapons[12] = {
				def = "ARMCOMSEALASER",
				badtargetcategory = "VTOL",
				}
	else
		tablecorcom.weapons[i] = {
				def = "ARMCOMSEALASER"..tostring(i-11),
				badtargetcategory = "VTOL",
				}
	end
end

	--Weapon: Shield

for i = 2,7 do
	I = tostring(i)
	H = tostring(i-1)
	tablecorcom.weapondefs["repulsor"..I] = deepcopy(tablecorcom.weapondefs["repulsor"..H])
	tablecorcom.weapondefs["repulsor"..I].shield.power = ShieldPower[i]
end

for i = 23,29 do
	tablecorcom.weapons[i] = {
			def = "REPULSOR"..tostring(i-22),
			}
end
	
tablecorcom.weapons[30] ={
				def = "DISINTEGRATOR",
				onlytargetcategory = "NOTSUB",
			}
tablecorcom.buildoptions = CoreDefsBuildOptions
for i = 1,11 do
	tablecorcom.featuredefs["dead"..tostring(i)] = deepcopy(tablecorcom.featuredefs.dead)
	tablecorcom.featuredefs["heap"..tostring(i)] = deepcopy(tablecorcom.featuredefs.heap)
	tablecorcom.featuredefs["dead"..tostring(i)].metal = tablecorcom.featuredefs["dead"].metal * WreckMetal[i]
	tablecorcom.featuredefs["heap"..tostring(i)].metal = tablecorcom.featuredefs["heap"].metal * WreckMetal[i]
	tablecorcom.featuredefs["dead"..tostring(i)].featuredead = "heap"..tostring(i)
	tablecorcom.featuredefs["dead"..tostring(i)].resurrectable = 1
end
end
return { corcom = deepcopy(tablecorcom) }

