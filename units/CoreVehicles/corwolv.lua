return {
	corwolv = {
		acceleration = 0.011,
		brakerate = 0.0297,
		buildcostenergy = 2300,
		buildcostmetal = 150,
		buildpic = "CORWOLV.DDS",
		buildtime = 3254,
		canmove = true,
		category = "ALL TANK WEAPON NOTSUB NOTAIR NOTHOVER SURFACE",
		collisionvolumeoffsets = "0 1 -7",
		collisionvolumescales = "31 15 43",
		collisionvolumetype = "Box",
		corpse = "DEAD",
		description = "Light Mobile Artillery",
		energymake = 0.5,
		energyuse = 0.5,
		explodeas = "smallexplosiongeneric",
		footprintx = 2,
		footprintz = 2,
		hightrajectory = 1,
		idleautoheal = 5,
		idletime = 1800,
		leavetracks = true,
		maxdamage = 577,
		maxslope = 10,
		maxvelocity = 1.08,
		maxreversevelocity = 1.08*0.60,
		maxwaterdepth = 8,
		movementclass = "TANK2",
		name = "Wolverine",
		nochasecategory = "VTOL",
		objectname = "CORWOLV",
		pushresistant = true,
		seismicsignature = 0,
		selfdestructas = "smallExplosionGenericSelfd",
		sightdistance = 299,
		trackoffset = 6,
		trackstrength = 5,
		tracktype = "StdTank",
		trackwidth = 30,
		turninplace = true,
		turninplaceanglelimit = 110,
		turninplacespeedlimit = 1.2342,
		turnrate = 466,
		-- script = "BASICTANKSCRIPT.LUA",
		customparams = {
			bar_trackoffset = 6,
			bar_trackstrength = 5,
			bar_tracktype = "corwidetracks",
			bar_trackwidth = 28,
			description_long = "Wolverine is an artillery vehicle used to take down T1 defenses, especially High Laser Turrets. It can outrange all T1 defense towers except coastal defense plasma batteries. Shooting its plasma shells along a parabolic trajectory they are obviously helpless in close quarters combat.  Always keep them protected by Levelers/Insstigators, or your own defensive structures. Don't forget to have targets in your radar's range or scouted.",
			canareaattack = 1,
			--ANIMATION DATA
				--PIECENAMES HERE
					basename = "base",
					turretname = "turret",
					sleevename = "sleeves",
					cannon1name = "barrel1",
					flare1name = "flare1",
					cannon2name = "barrel2", --optional (replace with nil)
					flare2name = "flare2", --optional (replace with nil)
				--SFXs HERE
					firingceg = "barrelshot-tiny",
					driftratio = "1", --How likely will the unit drift when performing turns?
					rockstrength = "0.02", --Howmuch will its weapon make it rock ?
					rockspeed = "2", -- More datas about rock(honestly you can keep 2 and 1 as default here)
					rockrestorespeed = "1", -- More datas about rock(honestly you can keep 2 and 1 as default here)
					cobkickbackrestorespeed = "10", --How fast will the cannon come back in position?
					kickback = "-2", --How much will the cannon kickback
				--AIMING HERE
					cobturretyspeed = "200", --turretSpeed as seen in COB script
					cobturretxspeed = "200", --turretSpeed as seen in COB script
					restoretime = "3000", --restore delay as seen in COB script
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "0.947448730469 -6.45624659424 -0.712127685547",
				collisionvolumescales = "26.1215209961 9.12510681152 48.7677612305",
				collisionvolumetype = "Box",
				damage = 430,
				description = "Wolverine Wreckage",
				energy = 0,
				featurereclamate = "SMUDGE01",
				footprintx = 2,
				footprintz = 2,
				height = 0,
				hitdensity = 100,
				metal = 103,
				object = "CORWOLV_DEAD",
				reclaimable = true,
				seqnamereclamate = "TREE1RECLAMATE",
				world = "all",
			},
		},
		sfxtypes = { 
 			pieceExplosionGenerators = { 
				"deathceg3",
				"deathceg2",
			},
			explosiongenerators = {
				[1] = "custom:barrelshot-small",
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
			corwolv_gun = {
				accuracy = 275,
				areaofeffect = 113,
				avoidfeature = false,
				craterareaofeffect = 113,
				craterboost = 0,
				cratermult = 0,
				explosiongenerator = "custom:genericshellexplosion-small",
				gravityaffected = "true",
				hightrajectory = 1,
				impulseboost = 0.123,
				impulsefactor = 0.123,
				name = "LightArtillery",
				noselfdamage = true,
				range = 710,
				reloadtime = 3.33,
				soundhit = "xplomed2",
				soundhitwet = "splsmed",
				soundhitwetvolume = 0.5,
				soundstart = "cannhvy3",
				turret = true,
				weapontype = "Cannon",
				weaponvelocity = 365,
				damage = {
					bombers = 15,
					default = 150,
					fighters = 15,
					subs = 5,
					vtol = 15,
				},
			},
		},
		weapons = {
			[1] = {
				badtargetcategory = "VTOL",
				def = "CORWOLV_GUN",
				maindir = "0 0 1",
				maxangledif = 180,
				onlytargetcategory = "SURFACE",
			},
		},
	},
}
