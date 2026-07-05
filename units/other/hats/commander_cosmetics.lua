local units = {}
local def = {
    maxacc = 0,
	blocking = false,
	maxdec = 0,
	energycost = 10000,
	metalcost = 1000,
	buildpic = "ARMSTONE.DDS",
	buildtime = 10000,
	canattack = false,
	cancloak = true,
	canrepeat = false,
	capturable = true,
	cantbetransported = false,
	category = "OBJECT",
	collisionvolumeoffsets = "0 0 0",
	collisionvolumescales = "0.1 0.1 0.1",
	collisionvolumetype = "CylY",
	crushresistance = 2500,
	footprintx = 1,
	footprintz = 1,
	hidedamage = true,
	autoheal = 100000, --so it doesnt die
	mass = 0,
	health = 5600000,
	maxslope = 64,
	maxwaterdepth = 1000,
	movementclass = "NANO",
	reclaimable = false,
	repairable = false,
	script = "blank.cob", --"hats/hat.cob",
	seismicsignature = 0,
	sightdistance = 1,
	sonarstealth = true,
	stealth = true,
	upright = false,
	customparams = {
		nohealthbars = true,
		subfolder = "other/hats",
		decoration = 2,
	},
}

-- Fight Night - Grunt with boxing gloves
units["cor_hat_fightnight"] = table.copy(def)
units["cor_hat_fightnight"].objectname = "hats/cor_hat_fightnight.s3o"
units["cor_hat_fightnight"].customparams.normaltex = "unittextures/cor_normal.dds"

-- Hornet Hat - Pirate
units["cor_hat_hornet"] = table.copy(def)
units["cor_hat_hornet"].objectname = "hats/cor_hat_hornet.s3o"
units["cor_hat_hornet"].customparams.normaltex = "unittextures/cor_normal.dds"

-- Halloween Hat - Pumpkin
units["cor_hat_hw"] = table.copy(def)
units["cor_hat_hw"].objectname = "hats/cor_hat_hw.s3o"
units["cor_hat_hw"].customparams.normaltex = "unittextures/cor_normal.dds"

-- Legion Fight Night - Goblin with boxing gloves
units["cor_hat_legfn"] = table.copy(def)
units["cor_hat_legfn"].objectname = "hats/cor_hat_legfn.s3o"
units["cor_hat_legfn"].customparams.normaltex = "unittextures/cor_normal.dds"

-- PtaQ Hat - Gnome
units["cor_hat_ptaq"] = table.copy(def)
units["cor_hat_ptaq"].objectname = "hats/cor_hat_ptaq.s3o"
units["cor_hat_ptaq"].customparams.normaltex = "unittextures/cor_normal.dds"

-- Viking Hat
units["cor_hat_viking"] = table.copy(def)
units["cor_hat_viking"].objectname = "hats/cor_hat_viking.s3o"
units["cor_hat_viking"].customparams.normaltex = "unittextures/cor_normal.dds"

-- Nationwars 2026 Left Shoulder Pad - Armada EEC
units["arm_leftshoulder_nationwars_eec"] = table.copy(def)
units["arm_leftshoulder_nationwars_eec"].objectname = "hats/arm_leftshoulder_nationwars_eec.s3o"
units["arm_leftshoulder_nationwars_eec"].customparams.normaltex = "unittextures/arm_normal.dds"

-- Nationwars 2026 Left Shoulder Pad - Armada Germany
units["arm_leftshoulder_nationwars_ger"] = table.copy(def)
units["arm_leftshoulder_nationwars_ger"].objectname = "hats/arm_leftshoulder_nationwars_ger.s3o"
units["arm_leftshoulder_nationwars_ger"].customparams.normaltex = "unittextures/arm_normal.dds"

-- Nationwars 2026 Left Shoulder Pad - Armada USA
units["arm_leftshoulder_nationwars_us"] = table.copy(def)
units["arm_leftshoulder_nationwars_us"].objectname = "hats/arm_leftshoulder_nationwars_us.s3o"
units["arm_leftshoulder_nationwars_us"].customparams.normaltex = "unittextures/arm_normal.dds"

-- Nationwars 2026 Left Shoulder Pad - Cortex EEC
units["cor_leftshoulder_nationwars_eec"] = table.copy(def)
units["cor_leftshoulder_nationwars_eec"].objectname = "hats/cor_leftshoulder_nationwars_eec.s3o"
units["cor_leftshoulder_nationwars_eec"].customparams.normaltex = "unittextures/cor_normal.dds"

-- Nationwars 2026 Left Shoulder Pad - Cortex Germany
units["cor_leftshoulder_nationwars_ger"] = table.copy(def)
units["cor_leftshoulder_nationwars_ger"].objectname = "hats/cor_leftshoulder_nationwars_ger.s3o"
units["cor_leftshoulder_nationwars_ger"].customparams.normaltex = "unittextures/cor_normal.dds"

-- Nationwars 2026 Left Shoulder Pad - Cortex USA
units["cor_leftshoulder_nationwars_us"] = table.copy(def)
units["cor_leftshoulder_nationwars_us"].objectname = "hats/cor_leftshoulder_nationwars_us.s3o"
units["cor_leftshoulder_nationwars_us"].customparams.normaltex = "unittextures/cor_normal.dds"

return units