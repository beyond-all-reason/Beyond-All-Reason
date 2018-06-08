return {
	armrecl = {
		autoheal = 2,
		buildcostenergy = 3000,
		buildcostmetal = 210,
		builddistance = 140,
		builder = true,
		shownanospray = false,
		buildpic = "ARMRECL.DDS",
		buildtime = 0.75 * 1.5 * 5500,
		canassist = false,
		canmove = true,
		canresurrect = true,
		category = "ALL UNDERWATER NOWEAPON NOTAIR NOTHOVER",
		collisionvolumeoffsets = "0 0 2",
		collisionvolumescales = "38 17 50",
		collisionvolumetype = "box",
		description = "Ressurection Sub",
		explodeas = "smallexplosiongeneric-uw",
		footprintx = 3,
		footprintz = 3,
		icontype = "sea",
		idleautoheal = 3,
		idletime = 300,
		maxdamage = 450,
		minwaterdepth = 15,
		movementclass = "UBOAT33X3",
		name = "Grim Reaper",
		objectname = "ARMRECL",
		seismicsignature = 0,
		selfdestructas = "smallexplosiongenericSelfd-uw",
		sightdistance = 300,
		sonardistance = 50,
		terraformspeed = 2250,

		waterline = 17,
		workertime = 150,
		reclaimspeed = 100,
		
		--move
		acceleration = 2.20/30,
		brakerate = 2.2/30,
		maxvelocity = 2.20,
		turninplace = true,
		turninplaceanglelimit = 90,
		turninplacespeedlimit = 0.64*2.20,
		turnrate = 350,
		--end move
		
		customparams = {
			
		},
		sfxtypes = { 
 			pieceExplosionGenerators = { 
				"deathceg2-builder",
				"deathceg3-builder",
				"deathceg4-builder",
			},
		},
		sounds = {
			build = "nanlath1",
			canceldestruct = "cancel2",
			capture = "capture1",
			repair = "repair1",
			underattack = "warning1",
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
				[1] = "sucormov",
			},
			select = {
				[1] = "sucorsel",
			},
		},
	},
}
