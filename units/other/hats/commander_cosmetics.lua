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
	autoheal = 100000, --so it doesn't die
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

-- Halloween Hat - Witch
units.arm_hat_halloween_witch = table.copy(def)
units.arm_hat_halloween_witch.objectname = "hats/arm_hat_halloween_witch.s3o"
units.arm_hat_halloween_witch.customparams.normaltex = "unittextures/arm_normal.dds"

-- Halloween Necklace - Witch Broom
units.arm_necklace_halloween_broom = table.copy(def)
units.arm_necklace_halloween_broom.objectname = "hats/arm_necklace_halloween_broom.s3o"
units.arm_necklace_halloween_broom.customparams.normaltex = "unittextures/arm_normal.dds"

-- Halloween Hat - Fred Mask
units.cor_hat_halloween_mask = table.copy(def)
units.cor_hat_halloween_mask.objectname = "hats/cor_hat_halloween_mask.s3o"
units.cor_hat_halloween_mask.customparams.normaltex = "unittextures/cor_normal.dds"

-- Halloween Hat - Pumpkin
units.cor_hat_halloween_pumpkin = table.copy(def)
units.cor_hat_halloween_pumpkin.objectname = "hats/cor_hat_halloween_pumpkin.s3o"
units.cor_hat_halloween_pumpkin.customparams.normaltex = "unittextures/cor_normal.dds"

-- Halloween Hat - Legion Mask
units.leg_hat_halloween_mask = table.copy(def)
units.leg_hat_halloween_mask.objectname = "hats/leg_hat_halloween_mask.s3o"
units.leg_hat_halloween_mask.customparams.normaltex = "unittextures/leg_normal.dds"

-- Xmas Hat - Santa
units.arm_hat_xmas_santa = table.copy(def)
units.arm_hat_xmas_santa.objectname = "hats/arm_hat_xmas_santa.s3o"
units.arm_hat_xmas_santa.customparams.normaltex = "unittextures/arm_normal.dds"

-- Xmas Necklace - Santa Bag
units.arm_necklace_xmas_santabag = table.copy(def)
units.arm_necklace_xmas_santabag.objectname = "hats/arm_necklace_xmas_santabag.s3o"
units.arm_necklace_xmas_santabag.customparams.normaltex = "unittextures/arm_normal.dds"

-- Xmas Hat - Reindeer
units.cor_hat_xmas_reindeer = table.copy(def)
units.cor_hat_xmas_reindeer.objectname = "hats/cor_hat_xmas_reindeer.s3o"
units.cor_hat_xmas_reindeer.customparams.normaltex = "unittextures/cor_normal.dds"

-- Fight Night - Grunt with boxing gloves
units.cor_hat_fightnight = table.copy(def)
units.cor_hat_fightnight.objectname = "hats/cor_hat_fightnight.s3o"
units.cor_hat_fightnight.customparams.normaltex = "unittextures/cor_normal.dds"

-- Pirate
units.cor_hat_pirate = table.copy(def)
units.cor_hat_pirate.objectname = "hats/cor_hat_pirate.s3o"
units.cor_hat_pirate.customparams.normaltex = "unittextures/cor_normal.dds"

-- Legion Fight Night - Goblin with boxing gloves
units.cor_hat_legfn = table.copy(def)
units.cor_hat_legfn.objectname = "hats/cor_hat_legfn.s3o"
units.cor_hat_legfn.customparams.normaltex = "unittextures/cor_normal.dds"

-- PtaQ Hat - Gnome
units.cor_hat_gnome = table.copy(def)
units.cor_hat_gnome.objectname = "hats/cor_hat_gnome.s3o"
units.cor_hat_gnome.customparams.normaltex = "unittextures/cor_normal.dds"

-- Viking Hat
units.cor_hat_viking = table.copy(def)
units.cor_hat_viking.objectname = "hats/cor_hat_viking.s3o"
units.cor_hat_viking.customparams.normaltex = "unittextures/cor_normal.dds"

-- Nationwars 2026 Left Shoulder Pad - Armada EEC
units.arm_leftshoulder_nationwars_eec = table.copy(def)
units.arm_leftshoulder_nationwars_eec.objectname = "hats/arm_leftshoulder_nationwars_eec.s3o"
units.arm_leftshoulder_nationwars_eec.customparams.normaltex = "unittextures/arm_normal.dds"

-- Nationwars 2026 Left Shoulder Pad - Armada Germany
units.arm_leftshoulder_nationwars_ger = table.copy(def)
units.arm_leftshoulder_nationwars_ger.objectname = "hats/arm_leftshoulder_nationwars_ger.s3o"
units.arm_leftshoulder_nationwars_ger.customparams.normaltex = "unittextures/arm_normal.dds"

-- Nationwars 2026 Left Shoulder Pad - Armada USA
units.arm_leftshoulder_nationwars_us = table.copy(def)
units.arm_leftshoulder_nationwars_us.objectname = "hats/arm_leftshoulder_nationwars_us.s3o"
units.arm_leftshoulder_nationwars_us.customparams.normaltex = "unittextures/arm_normal.dds"

-- Nationwars 2026 Left Shoulder Pad - Cortex EEC
units.cor_leftshoulder_nationwars_eec = table.copy(def)
units.cor_leftshoulder_nationwars_eec.objectname = "hats/cor_leftshoulder_nationwars_eec.s3o"
units.cor_leftshoulder_nationwars_eec.customparams.normaltex = "unittextures/cor_normal.dds"

-- Nationwars 2026 Left Shoulder Pad - Cortex Germany
units.cor_leftshoulder_nationwars_ger = table.copy(def)
units.cor_leftshoulder_nationwars_ger.objectname = "hats/cor_leftshoulder_nationwars_ger.s3o"
units.cor_leftshoulder_nationwars_ger.customparams.normaltex = "unittextures/cor_normal.dds"

-- Nationwars 2026 Left Shoulder Pad - Cortex USA
units.cor_leftshoulder_nationwars_us = table.copy(def)
units.cor_leftshoulder_nationwars_us.objectname = "hats/cor_leftshoulder_nationwars_us.s3o"
units.cor_leftshoulder_nationwars_us.customparams.normaltex = "unittextures/cor_normal.dds"

return units
