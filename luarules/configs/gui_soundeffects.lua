local LootboxSoundEffects = {
        BaseSoundSelectType = "arm-bld-select",
        --BaseSoundMovementType = "blanksound",
        BaseSoundWeaponType = "arm-bld-nrg-fusion",
}

local LootboxNanoSoundEffects = {
        BaseSoundSelectType = "arm-bld-select-small",
        --BaseSoundMovementType = "blanksound",
        BaseSoundWeaponType = "conalt-medium",
}

GUIUnitSoundEffects = {
	-- ARMADA COMMANDER
	armada_commander = {
		BaseSoundSelectType = "arm-com-sel",
		BaseSoundMovementType = { "arm-com-ok-1", "arm-com-ok-2", "arm-com-ok-3", "arm-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},

	armada_decoycommander = {
		BaseSoundSelectType = "arm-com-sel",
		BaseSoundMovementType = { "arm-com-ok-1", "arm-com-ok-2", "arm-com-ok-3", "arm-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},

	-- ARMADA T1 BUILDINGS

	armada_radartower = {
		BaseSoundSelectType = "arm-bld-select-small",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-radar",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	armada_navalradarsonar = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-radar-sonar",
	},

	armada_sonarstation = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-small",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	armada_sneakypete = {
		BaseSoundSelectType = "arm-bld-select-small",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "jammer",
	},

	armada_metalextractor = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-mex",
        BaseSoundActivate   = "mexon",
        BaseSoundDeactivate = "mexoff",
	},

	armada_twilight = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "cloak",
        BaseSoundActivate   = "mexon",
        BaseSoundDeactivate = "mexoff",
	},

	armada_energyconverter = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker",
        BaseSoundActivate   = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},

	armada_navalenergyconverter = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker",
        BaseSoundActivate   = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},

	armada_windturbine = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-windgen",
	},

	armada_tidalgenerator = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrghum",
	},

	armada_solarcollector = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-solar-alt",
		BaseSoundActivate   = "arm-bld-solar-activate",
		BaseSoundDeactivate = "arm-bld-solar-deactivate",
	},

	armada_advancedsolarcollector = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-solar-alt-adv",
	},

	armada_geothermalpowerplant = {
		BaseSoundSelectType = "arm-bld-select-medium",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-geo",
	},

	armada_metalstorage = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage",
	},

	armada_navalmetalstorage = {
		BaseSoundSelectType = "arm-sub-small-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-metal",
	},

	armada_energystorage = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage",
	},

	armada_navalenergystorage = {
		BaseSoundSelectType = "arm-sub-small-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-nrg",
	},

	armada_constructionturret = {
		BaseSoundSelectType = "arm-bld-select-small",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-small",
	},

	armada_navalconstructionturret = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-small",
	},

	armada_sharksteeth = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall-water",
	},

	armada_dragonsteeth = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall",
	},

	armada_beholder = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "cloak",
	},

	armada_sentry = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-small",
	},

	armada_overwatch = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-medium",
	},

	armada_manta = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-medium",
	},

	armada_beamer = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "beamer",
	},

	armada_nettle = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-small",
	},

	armada_navalnettle = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-small",
	},

	armada_harpoon = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-small",
	},

	armada_harpoon2 = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-small",
	},

	armada_anemone = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-small",
	},

	armada_dragonsclaw = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "lightning",
	},

	armada_ferret = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-medium",
	},

	armada_scumbag = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-medium",
	},

	armada_chainsaw = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-medium",
	},

	armada_gauntlet = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arty-medium",
	},

	armada_juno = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "bld-juno",
	},

	-- ARMADA T2 BUILDINGS

	armada_advancedradartower = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-radar-alt-t2",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	armada_veil = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "jammer-t2",
	},

	armada_advancedsonarstation = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-sonar-t2",
	},

	armada_pinpointer = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "targeting",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	armada_navalpinpointer = {
		BaseSoundSelectType = "arm-bld-select-large-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "targeting",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	armada_advancedmetalextractor = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metal-t2",
        BaseSoundActivate   = "mohorun1",
        BaseSoundDeactivate = "mohooff1",
	},

	armada_shockwave = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "emp-rocket",
        BaseSoundActivate   = "mohorun1",
        BaseSoundDeactivate = "mohooff1",
	},

	armada_navaladvancedmetalextractor = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metal-t2",
        BaseSoundActivate   = "mohorun1",
        BaseSoundDeactivate = "mohooff1",
	},

	armada_advancedenergyconverter = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker-t2",
        BaseSoundActivate   = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},

	armada_navaladvancedenergyconverter = {
		BaseSoundSelectType = "arm-bld-select-large-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker-t2",
        BaseSoundActivate   = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},

	armada_hardenedmetalstorage = {
		BaseSoundSelectType = "arm-bld-metal-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-metal",
	},

	armada_hardenedenergystorage = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-nrg",
	},

	armada_prude = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-geo-t2-safe",
	},

	armada_advancedgeothermalpowerplant = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-geo-t2-explo",
	},

	armada_fusionreactor = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion",
	},

	armada_cloakablefusionreactor = {
		BaseSoundSelectType = "cloak",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion",
	},

	armada_decoyfusionreactor = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion-decoy",
	},

	armada_advancedfusionreactor = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion-adv",
	},

	armada_navalfusionreactor = {
		BaseSoundSelectType = "arm-bld-select-large-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion-uw",
	},

	armada_fortificationwall = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall-t2",
	},

	armada_arbalest = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "flak",
	},

	armada_navalarbalest = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "flak",
	},

	armada_gorgon = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "plasma-large",
	},

	armada_mercury = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-large",
	},

	armada_pitbull = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "plasma-large-alt",
	},

	armada_rattlesnake = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arty-large",
	},

	armada_moray = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-medium",
	},

	armada_citadel = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "nuke-anti",
	},

	armada_paralyzer = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "emp-rocket",
	},

	armada_tracer = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-ics",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	armada_keeper = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-shield",
	},

	armada_aurora = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-shield",
	},

	armada_armageddon = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "nuke",
	},

	armada_pulsar = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-large",
	},

	armada_basilica = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "lrpc",
	},

	armada_ragnarok = {
		BaseSoundSelectType = "lrpc",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lolcannon",
	},


	-- ARMADA FACTORIES

	armada_botlab = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lab",
	},

	armada_advancedbotlab = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lab-t2",
	},

	armada_vehicleplant = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-vp",
	},

	armada_advancedvehicleplant = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-vp-t2",
	},

	armada_aircraftplant = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-ap",
	},

	armada_seaplaneplatform = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-sp",
	},

	armada_advancedaircraftplant = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-ap-t2",
	},

	armada_shipyard = {
		BaseSoundSelectType   = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType   = "arm-bld-factory-water",
	},

	armada_advancedshipyard = {
		BaseSoundSelectType   = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType   = "arm-bld-factory-water-t2",
	},

	armada_amphibiouscomplex = {
		BaseSoundSelectType   = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType   = "arm-bld-factory-t2-uw",
	},

	armada_hovercraftplatform = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-factory-hover",
	},

	armada_navalhovercraftplatform = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-factory-hover-water",
	},

	armada_airrepairpad = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-repairpad",
	},

	armada_experimentalgantry = {
		BaseSoundSelectType = "arm-bld-factory-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-gant-t3-sel",
	},

	armada_experimentalgantryuw = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-gant-t3-sel",
	},

	-- ARMADA MINES

	armada_lightmine = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-small",
	},

	armada_mediummine = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-medium",
	},

	armada_heavymine = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-large",
	},

	armada_heavymine = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-large-water",
	},

	-- ARMADA HOVERCRAFT

	armada_seeker = {
		BaseSoundSelectType = "arm-hov-small-sel",
		BaseSoundMovementType = "arm-hov-small-ok",
		--BaseSoundMovementVol = 0.6,
		BaseSoundWeaponType = "laser-tiny",
	},
	armada_possum = {
		BaseSoundSelectType = "arm-hov-small-sel",
		BaseSoundMovementType = "arm-hov-small-ok",
		BaseSoundWeaponType = "rocket-small",
	},
	armada_constructionhovercraft = {
		BaseSoundSelectType = "arm-hov-small-sel",
		BaseSoundMovementType = "arm-hov-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armada_sweeper = {
		BaseSoundSelectType = "arm-hov-small-sel",
		BaseSoundMovementType = "arm-hov-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	armada_crocodile = {
		BaseSoundSelectType = "arm-hov-small-sel",
		BaseSoundMovementType = "arm-hov-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	armada_bearer = {
		BaseSoundSelectType = "arm-hov-large-sel",
		BaseSoundMovementType = "arm-hov-large-ok",
		BaseSoundWeaponType = "transport-large",
	},
	armada_lunkhead = {
		BaseSoundSelectType = "arm-hov-large-sel",
		BaseSoundMovementType = "arm-hov-large-ok",
		BaseSoundWeaponType = "laser-large",
	},

	-- ARMADA T1 BOTS

	armada_tick = {
		BaseSoundSelectType = "arm-bot-tiny-sel",
		BaseSoundMovementType = "arm-bot-tiny-ok",
		BaseSoundWeaponType = "laser-tiny",
	},
	armada_pawn = {
		BaseSoundSelectType = "arm-bot-tiny-sel",
		BaseSoundMovementType = "arm-bot-tiny-ok",
		BaseSoundWeaponType = "fastemgalt-small",
	},
	armada_mace = {
		BaseSoundSelectType = "arm-bot-small-sel",
		BaseSoundMovementType = "arm-bot-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	armada_rocketeer = {
		BaseSoundSelectType = "arm-bot-small-sel",
		BaseSoundMovementType = "arm-bot-small-ok",
		BaseSoundWeaponType = "rocketalt-small",
	},
	armada_crossbow = {
		BaseSoundSelectType = "arm-bot-small-sel",
		BaseSoundMovementType = "arm-bot-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	armada_centurion = {
		BaseSoundSelectType = "arm-bot-medium-sel",
		BaseSoundMovementType = "arm-bot-medium-alt-ok",
		BaseSoundWeaponType = "laser-medium",
	},
	armada_constructionbot = {
		BaseSoundSelectType = "arm-bot-small-sel",
		BaseSoundMovementType = "arm-bot-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armada_lazarus = {
		BaseSoundSelectType = "arm-bot-tiny-sel",
		BaseSoundMovementType = "arm-bot-tiny-ok",
		BaseSoundWeaponType = "rez-small",
	},

	-- ARMADA T2 BOTS

	armada_tumbleweed = {
		BaseSoundSelectType = "arm-bot-tiny-sel",
		BaseSoundMovementType = "arm-bot-tiny-ok",
		BaseSoundWeaponType = "bomb",
	},
	armada_radarjammerbot = {
		BaseSoundSelectType = "arm-bot-small-sel",
		BaseSoundMovementType = "arm-bot-small-ok",
		BaseSoundWeaponType = "jammer",
	},
	armada_compass = {
		BaseSoundSelectType = "arm-bot-small-sel",
		BaseSoundMovementType = "arm-bot-small-ok",
		BaseSoundWeaponType = "radar-t2",
	},
	armada_ghost = {
		BaseSoundSelectType = "arm-bot-small-sel",
		BaseSoundMovementType = "arm-bot-small-ok",
		BaseSoundWeaponType = "cloak",
	},
	armada_webber = {
		BaseSoundSelectType = "arm-bot-at-sel",
		BaseSoundMovementType = "arm-bot-at-ok",
		BaseSoundWeaponType = "emp-laser",
	},
	armada_sprinter = {
		BaseSoundSelectType = "arm-bot-medium-sel",
		BaseSoundMovementType = "arm-bot-medium-ok",
		BaseSoundWeaponType = "fastemg-medium",
	},
	armada_butler = {
		BaseSoundSelectType = "arm-bot-medium-sel",
		BaseSoundMovementType = "arm-bot-medium-alt-ok",
		BaseSoundWeaponType = "con-assist",
	},
	armada_amphibiousbot = {
		BaseSoundSelectType = "arm-bot-medium-amph-sel",
		BaseSoundMovementType = "arm-bot-medium-amph-ok",
		BaseSoundWeaponType = "laser-small",
	},
	armada_hound = {
		BaseSoundSelectType = "arm-bot-medium-sel",
		BaseSoundMovementType = "arm-bot-medium-alt-ok",
		BaseSoundWeaponType = "plasma-medium-alt",
	},
	armada_welder = {
		BaseSoundSelectType = "arm-bot-large-ok",
		BaseSoundMovementType = "arm-bot-large-sel",
		BaseSoundWeaponType = "lightning",
	},
	armada_advancedconstructionbot = {
		BaseSoundSelectType = "arm-bot-medium-sel",
		BaseSoundMovementType = "arm-bot-medium-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	armada_recluse = {
		BaseSoundSelectType = "arm-bot-at-sel",
		BaseSoundMovementType = "arm-bot-at-ok",
		BaseSoundWeaponType = "rocket-large",
	},
	armada_archangel = {
		BaseSoundSelectType = "arm-bot-large-ok",
		BaseSoundMovementType = "arm-bot-large-sel",
		BaseSoundWeaponType = "aarocket-medium-flak",
	},
	armada_sharpshooter = {
		BaseSoundSelectType = "arm-bot-medium-stealth-sel",
		BaseSoundMovementType = "arm-bot-medium-stealth-ok",
		BaseSoundWeaponType = "sniper",
	},
	armada_gunslinger = {
		BaseSoundSelectType = "arm-bot-large-sel",
		BaseSoundMovementType = "arm-bot-large-ok",
		BaseSoundWeaponType = "plasma-medium",
	},
	armada_umbrella = {
		BaseSoundSelectType = "arm-bot-at-sel",
		BaseSoundMovementType = "arm-bot-at-ok",
		BaseSoundWeaponType = "nuke-anti",
	},
	armada_fatboy = {
		BaseSoundSelectType = "arm-bot-huge-sel",
		BaseSoundMovementType = "arm-bot-huge-ok",
		BaseSoundWeaponType = "plasma-large",
	},

	-- ARMADA T3 BOTS

	armada_marauder = {
		BaseSoundSelectType = "arm-bot-huge-sel",
		BaseSoundMovementType = "arm-bot-huge-ok",
		BaseSoundWeaponType = "plasma-large-alt",
	},
	armada_vanguard = {
		BaseSoundSelectType = "arm-bot-t3-sel",
		BaseSoundMovementType = "arm-bot-t3-ok",
		BaseSoundWeaponType = "lrpc",
	},
	armada_razorback = {
		BaseSoundSelectType = "arm-bot-t3-sel",
		BaseSoundMovementType = "arm-bot-t3-ok-alt",
		BaseSoundWeaponType = "laser-large",
	},
	armada_titan = {
		BaseSoundSelectType = "arm-banth-sel",
		BaseSoundMovementType = "arm-banth-ok",
		BaseSoundWeaponType = "arty-medium",
	},
	armada_thor = {
		BaseSoundSelectType = "arm-bot-t3-sel",
		BaseSoundMovementType = "arm-tnk-largealt-ok",
		BaseSoundWeaponType = "lightning",
	},

	-- ARMADA T1 VEHICLES

	armada_rover = {
		BaseSoundSelectType = "arm-veh-tiny-sel",
		BaseSoundMovementType = "arm-veh-tiny-ok",
		BaseSoundWeaponType = "laser-tiny",
	},
	armada_blitz = {
		BaseSoundSelectType = "arm-veh-small-sel",
		BaseSoundMovementType = "arm-veh-small-ok",
		BaseSoundWeaponType = "fastemg-small",
	},
	armada_shellshocker = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "arty-small",
	},
	armada_whistler = {
		BaseSoundSelectType = "arm-veh-small-sel",
		BaseSoundMovementType = "arm-veh-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	armada_pincer = {
		BaseSoundSelectType = "arm-tnk-small-amph-sel",
		BaseSoundMovementType = "arm-tnk-small-amph-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	armada_stout = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	armada_janus = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "rocket-medium",
	},
	armada_constructionvehicle = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armada_beaver = {
		BaseSoundSelectType = "arm-tnk-small-amph-sel",
		BaseSoundMovementType = "arm-tnk-small-amph-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armada_groundhog = {
		BaseSoundSelectType = "arm-veh-tiny-sel",
		BaseSoundMovementType = "arm-veh-tiny-ok",
		BaseSoundWeaponType = "mine-small",
	},

	-- ARMADA T2 VEHICLES

	armada_umbra = {
		BaseSoundSelectType = "arm-veh-small-sel",
		BaseSoundMovementType = "arm-veh-small-ok",
		BaseSoundWeaponType = "jammer",
	},
	armada_prophet = {
		BaseSoundSelectType = "arm-veh-small-sel",
		BaseSoundMovementType = "arm-veh-small-ok",
		BaseSoundWeaponType = "radar",
	},
	armada_gremlin = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "cloak",
	},
	armada_consul = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "con-assist",
	},
	armada_mauser = {
		BaseSoundSelectType = "arm-tnk-medium-sel",
		BaseSoundMovementType = "arm-tnk-medium-ok",
		BaseSoundWeaponType = "arty-medium",
	},
	armada_jaguar = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "lightning",
	},
	armada_shredder = {
		BaseSoundSelectType = "arm-tnk-medium-sel",
		BaseSoundMovementType = "arm-tnk-medium-ok",
		BaseSoundWeaponType = "flak",
	},
	armada_turtle = {
		BaseSoundSelectType = "arm-tnk-medium-sel",
		BaseSoundMovementType = "arm-tnk-medium-ok",
		BaseSoundWeaponType = "plasma-medium",
	},
	armada_advancedconstructionvehicle = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	armada_ambassador = {
		BaseSoundSelectType = "arm-tnk-medium-sel",
		BaseSoundMovementType = "arm-tnk-medium-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	armada_bull = {
		BaseSoundSelectType = "arm-tnk-large-sel",
		BaseSoundMovementType = "arm-tnk-large-ok",
		BaseSoundWeaponType = "plasma-medium",
	},
	armada_starlight = {
		BaseSoundSelectType = "arm-tnk-large-sel",
		BaseSoundMovementType = "arm-tnk-largealt-ok",
		BaseSoundWeaponType = "laser-large",
	},

	-- ARMADA SHIPS-SUBS

	armada_dolphin = {
		BaseSoundSelectType = "arm-shp-small-sel",
		BaseSoundMovementType = "arm-shp-small-ok",
		BaseSoundWeaponType = "fastemg-small",
	},
	armada_skater = {
		BaseSoundSelectType = "arm-shp-small-sel",
		BaseSoundMovementType = "arm-shp-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	armada_constructionship = {
		BaseSoundSelectType = "arm-shp-medium-sel",
		BaseSoundMovementType = "arm-shp-medium-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armada_grimreaper = {
		BaseSoundSelectType = "arm-sub-small-sel",
		BaseSoundMovementType = "arm-sub-small-ok",
		BaseSoundWeaponType = "rez-small",
	},
	armada_convoy = {
		BaseSoundSelectType = "arm-shp-medium-sel",
		BaseSoundMovementType = "arm-shp-medium-ok",
		BaseSoundWeaponType = "transport-large",
	},
	armada_ellysaw = {
		BaseSoundSelectType = "arm-shp-medium-sel",
		BaseSoundMovementType = "arm-shp-medium-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	armada_eel = {
		BaseSoundSelectType = "arm-sub-small-sel",
		BaseSoundMovementType = "arm-sub-small-ok",
		BaseSoundWeaponType = "torpedo-small",
	},
	armada_corsair = {
		BaseSoundSelectType = "arm-shp-medium-sel",
		BaseSoundMovementType = "arm-shp-medium-ok",
		BaseSoundWeaponType = "plasma-medium-torpedo",
	},
	armada_bermuda = {
		BaseSoundSelectType = "arm-shp-small-sel",
		BaseSoundMovementType = "arm-shp-small-ok",
		BaseSoundWeaponType = "jammer",
	},
	armada_voyager = {
		BaseSoundSelectType = "arm-shp-small-sel",
		BaseSoundMovementType = "arm-shp-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armada_advancedconstructionsub = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		BaseSoundMovementType = "arm-sub-medium-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	armada_barracuda = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		BaseSoundMovementType = "arm-sub-medium-ok",
		BaseSoundWeaponType = "torpedo-medium",
	},
	armada_dragonslayer = {
		BaseSoundSelectType = "arm-shp-medium-sel",
		BaseSoundMovementType = "arm-shp-medium-ok",
		BaseSoundWeaponType = "flak",
	},
	armada_paladin = {
		BaseSoundSelectType = "arm-shp-large-sel",
		BaseSoundMovementType = "arm-shp-large-ok",
		BaseSoundWeaponType = "plasma-medium-torpedo",
	},
	armada_haven = {
		BaseSoundSelectType = "arm-shp-large-sel",
		BaseSoundMovementType = "arm-shp-large-ok",
		BaseSoundWeaponType = "radar-support",
	},
	armada_serpent = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		BaseSoundMovementType = "arm-sub-medium-ok",
		BaseSoundWeaponType = "torpedo-medium",
	},
	armada_longbow = {
		BaseSoundSelectType = "arm-shp-large-sel",
		BaseSoundMovementType = "arm-shp-large-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	armada_dreadnought = {
		BaseSoundSelectType = "arm-shp-large-sel",
		BaseSoundMovementType = "arm-shp-large-ok",
		BaseSoundWeaponType = "plasma-large",
	},
	armada_epoch = {
		BaseSoundSelectType = "arm-shp-huge-sel",
		BaseSoundMovementType = "arm-shp-huge-ok",
		BaseSoundWeaponType = "plasma-huge",
	},

	-- ARMADA AIRCRAFT

	armada_blink = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "radar",
	},
	armada_stork = {
		BaseSoundSelectType = "arm-air-transport-small-sel",
		BaseSoundMovementType = "arm-air-transport-small-ok",
		BaseSoundWeaponType = "transport-large",
	},
	armada_falcon = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "aarocket-air",
	},
	armada_cyclone = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "aarocket-air",
	},
	armada_constructionaircraft = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armada_horizon = {
		BaseSoundSelectType = "arm-air-gunship-alt-sel",
		BaseSoundMovementType = "arm-air-gunship-alt-ok",
		BaseSoundWeaponType = "radar",
	},
	armada_banshee = {
		BaseSoundSelectType = "arm-air-gunship-alt-sel",
		BaseSoundMovementType = "arm-air-gunship-alt-ok",
		BaseSoundWeaponType = "fastemg-small",
	},
	armada_stormbringer = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-small",
	},
	armada_constructionseaplane = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armada_sabre = {
		BaseSoundSelectType = "arm-air-gunship-sel",
		BaseSoundMovementType = "arm-air-gunship-ok",
		BaseSoundWeaponType = "laser-medium",
	},
	armada_tsunami = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-small",
	},
	armada_puffin = {
		BaseSoundSelectType = "arm-air-gunship-sel",
		BaseSoundMovementType = "arm-air-gunship-ok",
		BaseSoundWeaponType = "air-bomb-small-torp",
	},
	armada_highwind = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "aarocket-air",
	},
	armada_oracle = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "radar",
	},
	armada_blizzard = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-large",
	},
	armada_stiletto = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-large-emp",
	},
	armada_advancedconstructionaircraft = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	armada_roughneck = {
		BaseSoundSelectType = "arm-air-gunship-alt-sel",
		BaseSoundMovementType = "arm-air-gunship-alt-ok",
		BaseSoundWeaponType = "fastemg-medium",
	},
	armada_abductor = {
		BaseSoundSelectType = "arm-air-transport-large-sel",
		BaseSoundMovementType = "arm-air-transport-large-ok",
		BaseSoundWeaponType = "transport-large",
	},
	armada_cormorant = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-large-torp",
	},
	armada_hornet = {
		BaseSoundSelectType = "arm-air-gunship-sel",
		BaseSoundMovementType = "arm-air-gunship-ok",
		BaseSoundWeaponType = "rocket-large",
	},
	armada_liche = {
		BaseSoundSelectType = "arm-air-large-sel",
		BaseSoundMovementType = "arm-air-large-ok",
		BaseSoundWeaponType = "air-bomb-large-nuclear",
	},

	-- CORTEX COMMANDER
	cortex_commander = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},

	cortex_decoycommander = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},

	-- CORTEX T1 BUILDINGS

	cortex_radartower = {
		BaseSoundSelectType = "arm-bld-select-small",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-radar",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	cortex_radarsonartower = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-radar-sonar",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	cortex_sonarstation = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-small",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	cortex_castro = {
		BaseSoundSelectType = "arm-bld-select-small",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "jammer",
	},

	cortex_metalextractor = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-mex",
        BaseSoundActivate   = "mexon",
        BaseSoundDeactivate = "mexoff",
	},

	cortex_exploiter = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-small-cor",
        BaseSoundActivate   = "mexon",
        BaseSoundDeactivate = "mexoff",
	},

	coramex = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "cloak",
        BaseSoundActivate   = "mexon",
        BaseSoundDeactivate = "mexoff",
	},

	cortex_energyconverter = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker",
        BaseSoundActivate = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},

	cortex_navalenergyconverter = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker",
        BaseSoundActivate = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},

	cortex_windturbine = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-windgen",
	},

	cortex_tidalgenerator = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrghum",
	},

	cortex_solarcollector = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-solar-alt",
		BaseSoundActivate = "cor-bld-solar-activate",
		BaseSoundDeactivate = "cor-bld-solar-deactivate",
	},

	cortex_advancedsolarcollector = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-solar-alt-adv",
	},

	cortex_geothermalpowerplant = {
		BaseSoundSelectType = "arm-bld-select-medium",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-geo",
	},

	cortex_metalstorage = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage",
	},

	cortex_navalmetalstorage = {
		BaseSoundSelectType = "arm-sub-small-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-metal",
	},

	cortex_energystorage = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage",
	},

	cortex_navalenergystorage = {
		BaseSoundSelectType = "arm-sub-small-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-nrg",
	},

	cortex_constructionturret = {
		BaseSoundSelectType = "arm-bld-select-small",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-small",
	},

	cortex_navalconstructionturret = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-small",
	},

	cortex_sharksteeth = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall-water",
	},

	cortex_dragonsteeth = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall",
	},

	cortex_beholder = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "cloak",
	},

	cortex_guard = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-small",
	},

	cortex_twinguard = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-small-cor",
	},

	cortex_warden = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-medium",
	},

	cortex_coral = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-medium",
	},

	cortex_thistle = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-small",
	},

	cortex_slingshot = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-small",
	},

	cortex_urchin = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-small",
	},

	cortex_oldurchin = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-small",
	},

	cortex_jellyfish = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-small",
	},

	cortex_dragonsmaw = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "flame-alt",
	},

	cortex_sam = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-medium",
	},

	cortex_janitor = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-medium",
	},

	cortex_eradicator = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-medium",
	},

	cortex_agitator = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arty-medium",
	},

	cortex_juno = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "bld-juno",
	},

	-- CORTEX T2 BUILDINGS

	cortex_advancedradartower = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-radar-alt-t2",
        BaseSoundActivate = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	cortex_shroud = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "jammer-t2",
	},

	cortex_advancedsonarstation = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-sonar-t2",
	},

	cortex_pinpointer = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "targeting",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	cortex_navalpinpointer = {
		BaseSoundSelectType = "arm-bld-select-large-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "targeting",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	cortex_advancedmetalextractor = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metal-t2",
        BaseSoundActivate   = "mohorun1",
        BaseSoundDeactivate = "mohooff1",
	},
    cortex_advancedexploiter = {
        BaseSoundSelectType = "arm-bld-metal",
        --BaseSoundMovementType = "",
        BaseSoundWeaponType = "laser-large",
        BaseSoundActivate   = "mohorun1",
        BaseSoundDeactivate = "mohooff1",
    },

	cortex_navaladvancedmetalextractor = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metal-t2",
        BaseSoundActivate   = "mohorun1",
        BaseSoundDeactivate = "mohooff1",
	},

	cortex_advancedenergyconverter = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker-t2",
        BaseSoundActivate   = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},

	cortex_navaladvancedenergyconverter = {
		BaseSoundSelectType = "arm-bld-select-large-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker-t2",
        BaseSoundActivate   = "cor-bld-mm-t2-activate",
        BaseSoundDeactivate = "cor-bld-mm-t2-deactivate",
	},

	cortex_hardenedmetalstorage = {
		BaseSoundSelectType = "arm-bld-metal-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-metal",
	},

	cortex_hardenedenergystorage = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-nrg",
	},

	cortex_cerberus = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-geo-t2-safe",
	},

	cortex_advancedgeothermalpowerplant = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-geo-t2-explo",
	},

	cortex_fusionreactor = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion",
	},

	cortex_advancedfusionreactor = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion-adv",
	},

	cortex_navalfusionreactor = {
		BaseSoundSelectType = "arm-bld-select-large-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion-uw",
	},

	cortex_fortificationwall = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall-t2",
	},

	cortex_birdshot = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "flak",
	},

	cortex_navalbirdshot = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "flak",
	},

	cortex_devastator = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-large",
	},

	cortex_screamer = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-large",
	},

	cortex_scorpion = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "rocket-large",
	},

	cortex_persecutor = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arty-large",
	},

	cortex_lamprey = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-medium",
	},

	cortex_prevailer = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "nuke-anti",
	},

	cortex_catalyst = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "rocketalt-large",
	},

	cortex_nemesis = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-ics",
        BaseSoundActivate = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	cortex_overseer = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-shield",
	},

	cortex_atoll = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-shield",
	},

	cortex_apocalypse = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "nuke",
	},

	cortex_bulwark = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-large",
	},

	cortex_basilisk = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "lrpc",
	},

	cortex_calamity = {
		BaseSoundSelectType = "lrpc",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lolcannon",
	},


	-- CORTEX FACTORIES

	cortex_botlab = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lab",
	},

	cortex_advancedbotlab = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lab-t2",
	},

	cortex_vehicleplant = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-vp",
	},

	cortex_advancedvehicleplant = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-vp-t2",
	},

	cortex_aircraftplant = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-ap",
	},

	cortex_advancedaircraftplant = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-ap-t2",
	},

	cortex_shipyard = {
		BaseSoundSelectType   = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType   = "arm-bld-factory-water",
	},

	cortex_advancedshipyard = {
		BaseSoundSelectType   = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType   = "arm-bld-factory-water-t2",
	},

	cortex_amphibiouscomplex = {
		BaseSoundSelectType   = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType   = "arm-bld-factory-t2-uw",
	},

	cortex_hovercraftplatform = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-factory-hover",
	},

	cortex_navalhovercraftplatform = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-factory-hover-water",
	},

	cortex_seaplaneplatform = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-sp",
	},

	cortex_airrepairpad = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-repairpad",
	},

	cortex_experimentalgantry = {
		BaseSoundSelectType = "arm-bld-factory-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-gant-t3-sel",
	},

	cortex_underwaterexperimentalgantry = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-gant-t3-sel",
	},

	-- CORTEX MINES

	cortex_lightmine = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-small",
	},

	cortex_mediummine = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-medium",
	},

	cortex_heavymine = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-large",
	},

	cortex_mediumminecommando = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-large",
	},

	cortex_navalheavymine = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-large-water",
	},

	-- CORTEX HOVERCRAFT

	cortex_goon = {
		BaseSoundSelectType = "cor-hov-small-sel",
		BaseSoundMovementType = "cor-hov-small-ok",
		--BaseSoundMovementVol = 0.6,
		BaseSoundWeaponType = "laser-tiny",
	},
	cortex_mangonel = {
		BaseSoundSelectType = "cor-hov-small-sel",
		BaseSoundMovementType = "cor-hov-small-ok",
		BaseSoundWeaponType = "rocket-small",
	},
	cortex_constructionhovercraft = {
		BaseSoundSelectType = "cor-hov-small-sel",
		BaseSoundMovementType = "cor-hov-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	cortex_birdeater = {
		BaseSoundSelectType = "cor-hov-small-sel",
		BaseSoundMovementType = "cor-hov-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	cortex_cayman = {
		BaseSoundSelectType = "cor-hov-small-sel",
		BaseSoundMovementType = "cor-hov-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	cortex_halberd = {
		BaseSoundSelectType = "cor-hov-large-sel",
		BaseSoundMovementType = "cor-hov-large-ok",
		BaseSoundWeaponType = "laser-medium",
	},
	cortex_caravan = {
		BaseSoundSelectType = "cor-hov-large-sel",
		BaseSoundMovementType = "cor-hov-large-ok",
		BaseSoundWeaponType = "transport-large",
	},
	cortex_cataphract = {
		BaseSoundSelectType = "cor-hov-large-sel",
		BaseSoundMovementType = "cor-hov-large-ok",
		BaseSoundWeaponType = "laser-large",
	},

	-- CORTEX T1 BOTS

	cortex_grunt = {
		BaseSoundSelectType = "cor-bot-tiny-sel",
		BaseSoundMovementType = "cor-bot-tiny-ok",
		BaseSoundWeaponType = "laser-small-cor",
	},
	cortex_thug = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	cortex_aggravator = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "rocketalt-small",
	},
	cortex_trasher = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	cortex_constructionbot = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	cortex_graverobber = {
		BaseSoundSelectType = "cor-bot-tiny-sel",
		BaseSoundMovementType = "cor-bot-tiny-ok",
		BaseSoundWeaponType = "rez-small",
	},

	-- CORTEX T2 BOTS

	cortex_bedbug = {
		BaseSoundSelectType = "cor-bot-tiny-sel",
		BaseSoundMovementType = "cor-bot-tiny-ok",
		BaseSoundWeaponType = "bomb",
	},
	cortex_deceiver = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "jammer",
	},
	cortex_augur = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "radar-t2",
	},
	cortex_spectre = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "cloak",
	},
	cortex_fiend = {
		BaseSoundSelectType = "cor-bot-medium-sel",
		BaseSoundMovementType = "cor-bot-medium-ok",
		BaseSoundWeaponType = "flame-alt",
	},
	cortex_twitcher = {
		BaseSoundSelectType = "cor-bot-medium-sel",
		BaseSoundMovementType = "cor-bot-medium-ok",
		BaseSoundWeaponType = "con-assist",
	},
	cortex_duck = {
		BaseSoundSelectType = "cor-bot-medium-amph-sel",
		BaseSoundMovementType = "cor-bot-medium-amph-ok",
		BaseSoundWeaponType = "laser-medium",
	},
	cortex_sheldon = {
		BaseSoundSelectType = "cor-bot-medium-sel",
		BaseSoundMovementType = "cor-bot-medium-ok",
		BaseSoundWeaponType = "arty-medium",
	},
	cortex_advancedconstructionbot = {
		BaseSoundSelectType = "cor-bot-medium-sel",
		BaseSoundMovementType = "cor-bot-medium-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	cortex_skuttle = {
		BaseSoundSelectType = "cor-bot-at-sel",
		BaseSoundMovementType = "cor-bot-at-ok",
		BaseSoundWeaponType = "bomb",
	},
	cortex_sumo = {
		BaseSoundSelectType = "cor-bot-large-sel",
		BaseSoundMovementType = "cor-bot-large-ok",
		BaseSoundWeaponType = "laser-medium",
	},
	cortex_arbiter = {
		BaseSoundSelectType = "cor-bot-medium-sel",
		BaseSoundMovementType = "cor-bot-medium-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	cortex_manticore = {
		BaseSoundSelectType = "cor-bot-large-ok",
		BaseSoundMovementType = "cor-bot-large-sel",
		BaseSoundWeaponType = "aarocket-medium-flak",
	},
	cortex_termite = {
		BaseSoundSelectType = "cor-bot-at-sel",
		BaseSoundMovementType = "cor-bot-at-ok",
		BaseSoundWeaponType = "heatray",
	},
	cortex_commando = {
		BaseSoundSelectType = "cor-bot-medium-stealth-sel",
		BaseSoundMovementType = "cor-bot-medium-stealth-ok",
		BaseSoundWeaponType = "plasma-medium",
	},
	cortex_mammoth = {
		BaseSoundSelectType = "cor-bot-huge-sel",
		BaseSoundMovementType = "cor-bot-huge-ok",
		BaseSoundWeaponType = "laser-large",
	},

	-- CORTEX T3 BOTS

	cortex_shiva = {
		BaseSoundSelectType = "cor-bot-huge-sel",
		BaseSoundMovementType = "cor-bot-huge-ok",
		BaseSoundWeaponType = "plasma-large-alt",
	},
	cortex_karganeth = {
		BaseSoundSelectType = "cor-bot-t3-at-sel",
		BaseSoundMovementType = "cor-bot-t3-at-ok",
		BaseSoundWeaponType = "lrpc",
	},
	cortex_catapult = {
		BaseSoundSelectType = "cor-bot-t3-sel",
		BaseSoundMovementType = "cor-bot-t3-ok",
		BaseSoundWeaponType = "laser-large",
	},
	cortex_behemoth = {
		BaseSoundSelectType = "cor-jugg-sel",
		BaseSoundMovementType = "cor-jugg-ok",
		BaseSoundWeaponType = "oranges-gun",
	},
	cortex_juggernaut = {
		BaseSoundSelectType = "cor-korg-sel",
		BaseSoundMovementType = { "cor-korg-ok1", "cor-korg-ok2", "cor-korg-ok3", },
		BaseSoundWeaponType = "heatray-xl",
	},
	cortex_demon = {
		BaseSoundSelectType = "cor-bot-huge-sel",
		BaseSoundMovementType = "cor-bot-huge-ok",
		BaseSoundWeaponType = "flame-alt",
	},

	-- CORTEX T1 VEHICLES

	cortex_rascal = {
		BaseSoundSelectType = "cor-veh-tiny-sel",
		BaseSoundMovementType = "cor-veh-tiny-ok",
		BaseSoundWeaponType = "laser-tiny",
	},
	cortex_incisor = {
		BaseSoundSelectType = "cor-veh-small-sel",
		BaseSoundMovementType = "cor-veh-small-ok",
		BaseSoundWeaponType = "laser-small-cor",
	},
	cortex_wolverine = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "arty-small",
	},
	cortex_lasher = {
		BaseSoundSelectType = "cor-veh-small-sel",
		BaseSoundMovementType = "cor-veh-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	cortex_garpike = {
		BaseSoundSelectType = "cor-tnk-small-amph-sel",
		BaseSoundMovementType = "cor-tnk-small-amph-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	cortex_brute = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	cortex_pounder = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "rocket-medium",
	},
	cortex_constructionvehicle = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	cortex_muskrat = {
		BaseSoundSelectType = "cor-tnk-small-amph-sel",
		BaseSoundMovementType = "cor-tnk-small-amph-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	cortex_trapper = {
		BaseSoundSelectType = "cor-veh-tiny-sel",
		BaseSoundMovementType = "cor-veh-tiny-ok",
		BaseSoundWeaponType = "mine-small",
	},

	-- CORTEX T2 VEHICLES

	cortex_obscurer = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "jammer",
	},
	cortex_omen = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "radar",
	},
	cortex_quaker = {
		BaseSoundSelectType = "cor-tnk-medium-sel",
		BaseSoundMovementType = "cor-tnk-medium-ok",
		BaseSoundWeaponType = "arty-medium",
	},
	cortex_fury = {
		BaseSoundSelectType = "cor-tnk-medium-sel",
		BaseSoundMovementType = "cor-tnk-medium-ok",
		BaseSoundWeaponType = "flak",
	},
	cortex_alligator = {
		BaseSoundSelectType = "cor-tnk-medium-amph-sel",
		BaseSoundMovementType = "cor-tnk-medium-amph-ok",
		BaseSoundWeaponType = "plasma-medium",
	},
	cortex_advancedconstructionvehicle = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	cortex_negotiator = {
		BaseSoundSelectType = "cor-tnk-medium-sel",
		BaseSoundMovementType = "cor-tnk-medium-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	cortex_tiger = {
		BaseSoundSelectType = "cor-tnk-large-sel",
		BaseSoundMovementType = "cor-tnk-large-ok",
		BaseSoundWeaponType = "plasma-medium",
	},
	cortex_banisher = {
		BaseSoundSelectType = "cor-tnk-large-sel",
		BaseSoundMovementType = "cor-tnk-large-ok",
		BaseSoundWeaponType = "arty-large",
	},
	cortex_poisonarrow = {
		BaseSoundSelectType = "cor-tnk-medium-amph-sel",
		BaseSoundMovementType = "cor-tnk-medium-amph-ok",
		BaseSoundWeaponType = "plasma-large",
	},
	cortex_saviour = {
		BaseSoundSelectType = "cor-tnk-large-sel",
		BaseSoundMovementType = "cor-tnk-large-ok",
		BaseSoundWeaponType = "nuke-anti",
	},
	cortex_intruder = {
		BaseSoundSelectType = "cor-tnk-large-sel",
		BaseSoundMovementType = "cor-tnk-large-ok",
		BaseSoundWeaponType = "transport-large",
	},
	cortex_tzar = {
		BaseSoundSelectType = "cor-tnk-huge-sel",
		BaseSoundMovementType = "cor-tnk-huge-ok",
		BaseSoundWeaponType = "plasma-large",
	},
	cortex_tremor = {
		BaseSoundSelectType = "cor-tnk-huge-sel",
		BaseSoundMovementType = "cor-tnk-huge-ok",
		BaseSoundWeaponType = "arty-large",
	},
	corsala = {
		BaseSoundSelectType = "cor-tnk-medium-amph-sel",
		BaseSoundMovementType = "cor-tnk-medium-amph-ok",
		BaseSoundWeaponType = "heatray",
	},
	cortex_2printer = {
		BaseSoundSelectType = "cor-tnk-large-sel",
		BaseSoundMovementType = "cor-tnk-large-ok",
		BaseSoundWeaponType = "con-assist",
	},
	-- FUN MODE - made possible by Teifion and Basic
	-- cortex_rascal = {
	-- BaseSoundSelectType   = "cor-veh-tiny-sel",
	-- BaseSoundMovementType = "cor-veh-tiny-ok",
	-- BaseSoundWeaponType   = "laser-small",
	-- },
	-- cortex_tzar = {
	-- BaseSoundSelectType   = "cor-tnk-large-sel",
	-- BaseSoundMovementType = "cor-tnk-large-ok",
	-- BaseSoundWeaponType   = "plasma-huge",
	-- },

	-- CORTEX SHIPS-SUBS

	cortex_supporter = {
		BaseSoundSelectType = "cor-shp-small-sel",
		BaseSoundMovementType = "cor-shp-small-ok",
		BaseSoundWeaponType = "fastemg-small",
	},
	cortex_herring = {
		BaseSoundSelectType = "cor-shp-small-sel",
		BaseSoundMovementType = "cor-shp-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	cortex_constructionship = {
		BaseSoundSelectType = "cor-shp-medium-sel",
		BaseSoundMovementType = "cor-shp-medium-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	cortex_deathcavalry = {
		BaseSoundSelectType = "cor-sub-small-sel",
		BaseSoundMovementType = "cor-sub-small-ok",
		BaseSoundWeaponType = "rez-small",
	},
	cortex_coffin = {
		BaseSoundSelectType = "cor-shp-medium-sel",
		BaseSoundMovementType = "cor-shp-medium-ok",
		BaseSoundWeaponType = "transport-large",
	},
	cortex_riptide = {
		BaseSoundSelectType = "cor-shp-medium-sel",
		BaseSoundMovementType = "cor-shp-medium-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	cortex_orca = {
		BaseSoundSelectType = "cor-sub-small-sel",
		BaseSoundMovementType = "cor-sub-small-ok",
		BaseSoundWeaponType = "torpedo-small",
	},
	cortex_oppressor = {
		BaseSoundSelectType = "cor-shp-medium-sel",
		BaseSoundMovementType = "cor-shp-medium-ok",
		BaseSoundWeaponType = "plasma-medium-torpedo",
	},
	cortex_phantasm = {
		BaseSoundSelectType = "cor-shp-small-sel",
		BaseSoundMovementType = "cor-shp-small-ok",
		BaseSoundWeaponType = "jammer",
	},
	cortex_pathfinder = {
		BaseSoundSelectType = "cor-shp-small-sel",
		BaseSoundMovementType = "cor-shp-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	cortex_advancedconstructionsub = {
		BaseSoundSelectType = "cor-sub-medium-sel",
		BaseSoundMovementType = "cor-sub-medium-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	cortex_predator = {
		BaseSoundSelectType = "cor-sub-medium-sel",
		BaseSoundMovementType = "cor-sub-medium-ok",
		BaseSoundWeaponType = "torpedo-medium",
	},
	cortex_arrowstorm = {
		BaseSoundSelectType = "cor-shp-medium-sel",
		BaseSoundMovementType = "cor-shp-medium-ok",
		BaseSoundWeaponType = "flak",
	},
	cortex_buccaneer = {
		BaseSoundSelectType = "cor-shp-large-sel",
		BaseSoundMovementType = "cor-shp-large-ok",
		BaseSoundWeaponType = "plasma-medium-torpedo",
	},
	cortex_oasis = {
		BaseSoundSelectType = "cor-shp-large-sel",
		BaseSoundMovementType = "cor-shp-large-ok",
		BaseSoundWeaponType = "radar-support",
	},
	cortex_kraken = {
		BaseSoundSelectType = "cor-sub-medium-sel",
		BaseSoundMovementType = "cor-sub-medium-ok",
		BaseSoundWeaponType = "torpedo-medium",
	},
	cortex_messenger = {
		BaseSoundSelectType = "cor-shp-large-sel",
		BaseSoundMovementType = "cor-shp-large-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	cortex_despot = {
		BaseSoundSelectType = "cor-shp-large-sel",
		BaseSoundMovementType = "cor-shp-large-ok",
		BaseSoundWeaponType = "plasma-large",
	},
	cortex_blackhydra = {
		BaseSoundSelectType = "cor-shp-huge-sel",
		BaseSoundMovementType = "cor-shp-huge-ok",
		BaseSoundWeaponType = "plasma-huge",
	},

	-- CORTEX AIRCRAFT

	cortex_finch = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "radar",
	},
	cortex_shuriken = {
		BaseSoundSelectType = "cor-air-tiny-sel",
		BaseSoundMovementType = "cor-air-tiny-ok",
		BaseSoundWeaponType = "emp-laser",
	},
	cortex_hercules = {
		BaseSoundSelectType = "arm-air-transport-small-sel",
		BaseSoundMovementType = "arm-air-transport-small-ok",
		BaseSoundWeaponType = "transport-large",
	},
	cortex_valiant = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "aarocket-air",
	},
	cortex_bat = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "aarocket-air",
	},
	cortex_constructionaircraft = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	cortex_watcher = {
		BaseSoundSelectType = "arm-air-gunship-alt-sel",
		BaseSoundMovementType = "arm-air-gunship-alt-ok",
		BaseSoundWeaponType = "radar",
	},
	corkam = {
		BaseSoundSelectType = "arm-air-gunship-alt-sel",
		BaseSoundMovementType = "arm-air-gunship-alt-ok",
		BaseSoundWeaponType = "fastemg-small",
	},
	cortex_whirlwind = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-small",
	},
	cortex_constructionseaplane = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	cortex_cutlass = {
		BaseSoundSelectType = "arm-air-gunship-sel",
		BaseSoundMovementType = "arm-air-gunship-ok",
		BaseSoundWeaponType = "laser-medium",
	},
	cortex_dambuster = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-small",
	},
	cortex_monsoon = {
		BaseSoundSelectType = "arm-air-gunship-sel",
		BaseSoundMovementType = "arm-air-gunship-ok",
		BaseSoundWeaponType = "air-bomb-small-torp",
	},
	cortex_nighthawk = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "aarocket-air",
	},
	cortex_condor = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "radar",
	},
	cortex_hailstorm = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-large",
	},
	cortex_advancedconstructionaircraft = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	cortex_wasp = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	cortex_skyhook = {
		BaseSoundSelectType = "arm-air-transport-large-sel",
		BaseSoundMovementType = "arm-air-transport-large-ok",
		BaseSoundWeaponType = "transport-large",
	},
	cortex_angler = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-large-torp",
	},
	cortex_dragonold = {
		BaseSoundSelectType = "cor-air-gunship-large-sel",
		BaseSoundMovementType = "cor-air-gunship-large-ok",
		BaseSoundWeaponType = "laser-large",
	},
	cortex_dragon = {
		BaseSoundSelectType = "cor-air-gunship-large-sel",
		BaseSoundMovementType = "cor-air-gunship-large-ok",
		BaseSoundWeaponType = "laser-large",
	},

	-- LEGION COMMANDER
	legcom = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "fastemg-small",
	},
	legcomlvl2 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "fastemg-small",
	},
	legcomlvl3 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "fastemg-small",
	},
	legcomlvl4 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "fastemg-small",
	},

	-- LEGION T1 BUILDINGS
	legmex = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-mex",
        BaseSoundActivate   = "mexon",
        BaseSoundDeactivate = "mexoff",
	},
	legmext15 = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-mex",
        BaseSoundActivate   = "mexon",
        BaseSoundDeactivate = "mexoff",
	},
	legdefcarryt1 = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-repairpad",
	},
	legmg = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "fastemg-medium",
	},

	-- LEGION T2 BUILDINGS

	legstarfall = {
		BaseSoundSelectType = "lrpc",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lolcannon",
	},

	legbastion = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-large",
	},


	-- LEGION FACTORIES
	leglab = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lab",
	},
	legalab = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lab-t2",
	},
	legvp = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-vp",
	},
	legavp = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-vp-t2",
	},
	legap = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-ap",
	},
	legaap = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-ap-t2",
	},
	leggant = {
		BaseSoundSelectType = "arm-bld-factory-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-gant-t3-sel",
	},

	-- LEGION T1 BOTS
	legck = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	leggob = {
		BaseSoundSelectType = "arm-bot-tiny-sel",
		BaseSoundMovementType = "arm-bot-tiny-ok",
		BaseSoundWeaponType = "fastemgalt-small",
	},
	leglob = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	legcen = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "plasma-medium",
	},
	legbal = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "rocketalt-small",
	},
	legkark = {
		BaseSoundSelectType = "arm-bot-medium-sel",
		BaseSoundMovementType = "arm-bot-medium-alt-ok",
		BaseSoundWeaponType = "heatray",
	},

	-- LEGION T2 BOTS
	legack = {
		BaseSoundSelectType = "cor-bot-medium-sel",
		BaseSoundMovementType = "cor-bot-medium-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	leginfestor = {
		BaseSoundSelectType = "cor-bot-at-sel",
		BaseSoundMovementType = "cor-bot-at-ok",
		BaseSoundWeaponType = "heatray",
	},




	leginc = {
		BaseSoundSelectType = "cor-bot-huge-sel",
		BaseSoundMovementType = "cor-bot-huge-ok",
		BaseSoundWeaponType = "flame-alt",
	},
	legstr = {
		BaseSoundSelectType = "cor-bot-medium-sel",
		BaseSoundMovementType = "cor-bot-medium-ok",
		BaseSoundWeaponType = "fastemg-medium",
	},
	legbart = {
		BaseSoundSelectType = "cor-bot-medium-sel",
		BaseSoundMovementType = "cor-bot-medium-ok",
		BaseSoundWeaponType = "flame-alt",
	},
	legsrail = {
		BaseSoundSelectType = "cor-bot-t3-at-sel",
		BaseSoundMovementType = "cor-bot-t3-at-ok",
		BaseSoundWeaponType = "lrpc",
	},
	legshot = {
		BaseSoundSelectType = "cor-bot-large-sel",
		BaseSoundMovementType = "cor-bot-large-ok",
		BaseSoundWeaponType = "plasma-large",
	},
	-- LEGION T3 BOTS
	legpede = {
		BaseSoundSelectType = "cor-bot-t3-at-sel",
		BaseSoundMovementType = "cor-bot-t3-at-ok",
		BaseSoundWeaponType = "lrpc",
	},
	leegmech = {
		BaseSoundSelectType = "cor-bot-huge-sel",
		BaseSoundMovementType = "cor-bot-huge-ok",
		BaseSoundWeaponType = "plasma-large-alt",
	},
	legkeres = {
		BaseSoundSelectType = "cor-tnk-huge-sel",
		BaseSoundMovementType = "cor-tnk-huge-ok",
		BaseSoundWeaponType = "plasma-large",
	},

	-- LEGION T1 VEHICLES
	legcv = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	leghelios = {
		BaseSoundSelectType = "cor-veh-small-sel",
		BaseSoundMovementType = "cor-veh-small-ok",
		BaseSoundWeaponType = "heatray",
	},
	leghades = {
		BaseSoundSelectType = "arm-veh-small-sel",
		BaseSoundMovementType = "arm-veh-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	legbar = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "flame-alt",
	},
	legrail = {
		BaseSoundSelectType = "cor-veh-small-sel",
		BaseSoundMovementType = "cor-veh-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	leggat = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "fastemg-medium",
	},
	-- LEGION T2 VEHICLES
	legacv = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	legvcarry = {
		BaseSoundSelectType = "arm-tnk-medium-sel",
		BaseSoundMovementType = "arm-tnk-medium-ok",
		BaseSoundWeaponType = "arm-bld-repairpad",
	},
	leginf = {
		BaseSoundSelectType = "cor-tnk-huge-sel",
		BaseSoundMovementType = "cor-tnk-huge-ok",
		BaseSoundWeaponType = "flame-alt",
	},
	legsco = {
		BaseSoundSelectType = "cor-tnk-huge-sel",
		BaseSoundMovementType = "cor-tnk-huge-ok",
		BaseSoundWeaponType = "plasma-large",
	},
	legmrv = {
		BaseSoundSelectType = "cor-tnk-medium-sel",
		BaseSoundMovementType = "cor-tnk-medium-ok",
		BaseSoundWeaponType = "plasma-medium",
	},
	legfloat = {
		BaseSoundSelectType = "cor-tnk-medium-amph-sel",
		BaseSoundMovementType = "cor-tnk-medium-amph-ok",
		BaseSoundWeaponType = "plasma-large",
	},
	-- LEGION T3 VEHICLES

	-- LEGION AIRCRAFT
	legca = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	legfig = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "aarocket-air",
	},
	legmos = {
		BaseSoundSelectType = "arm-air-gunship-alt-sel",
		BaseSoundMovementType = "arm-air-gunship-alt-ok",
		BaseSoundWeaponType = "fastemg-small",
	},
	legkam = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-small",
	},
	legcib = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "bld-juno",
	},
	legaca = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	legnap = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "flame-alt",
	},
	legmineb = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "mine-large",
	},
	legfort = {
		BaseSoundSelectType = "cor-air-gunship-large-sel",
		BaseSoundMovementType = "cor-air-gunship-large-ok",
		BaseSoundWeaponType = "plasma-huge",
	},
	legstronghold = {
		BaseSoundSelectType = "arm-air-transport-large-sel",
		BaseSoundMovementType = "arm-air-transport-large-ok",
		BaseSoundWeaponType = "fastemg-medium",--transport-large ?
	},
	legwhisper = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "radar",
	},
	legionnaire = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "aarocket-air",
	},
	legvenator = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "aarocket-air",
	},
	legphoenix = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-large",
	},



	--Various Random Units

	freefusion = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion-adv",
	},

	armada_missioncommandtower = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-geo-t2-explo",
	},

	corscavdrag = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall",
	},
	corscavdtf = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "flame-alt",
	},
	corscavdtl = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "lightning",
	},
	corscavdtm = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "rocketalt-large",
	},
	corscavfort = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall-t2",
	},
	cortex_epictzar = {
		BaseSoundSelectType = "cor-tnk-huge-sel",
		BaseSoundMovementType = "cor-tnk-huge-ok",
		BaseSoundWeaponType = "plasma-huge",
	},
	cortex_thermite = {
		BaseSoundSelectType = "cor-bot-t3-at-sel",
		BaseSoundMovementType = "cor-bot-t3-at-ok",
		BaseSoundWeaponType = "heatray-xl",
	},



	armada_navalmetalextractor = {},
	cortex_navalmetalextractor = {},
	armada_gunplatform = {},
	cortex_gunplatform = {},
	dbg_sphere = {},
	dbg_sphere_fullmetal = {},
	chip = {},
	dice = {},
	meteor = {},
	nuketestorg = {},
	nuketest = {},
	nuketestcor = {},
	nuketestcororg = {},
	xmasball1_1 = {},
	xmasball1_2 = {},
	xmasball1_3 = {},
	xmasball1_4 = {},
	xmasball1_5 = {},
	xmasball1_6 = {},
	xmasball2_1 = {},
	xmasball2_2 = {},
	xmasball2_3 = {},
	xmasball2_4 = {},
	xmasball2_5 = {},
	xmasball2_6 = {},
	armada_tombstone = {},
	cortex_tombstone = {},
	resourcecheat = {},

	scavempspawner = {},
	scavtacnukespawner = {},
	lootdroppod_gold = {},
	lootdroppod_printer = {},
	scavengerdroppod = {},
	scavengerdroppodfriendly = {},
	scavempspawner = {},
	scavtacnukespawner = {},


	lootboxbronze		= LootboxSoundEffects,
	lootboxsilver		= LootboxSoundEffects,
	lootboxgold			= LootboxSoundEffects,
	lootboxplatinum		= LootboxSoundEffects,
	lootboxnano_t1_var1	= LootboxNanoSoundEffects,
	lootboxnano_t1_var2	= LootboxNanoSoundEffects,
	lootboxnano_t1_var3	= LootboxNanoSoundEffects,
	lootboxnano_t1_var4	= LootboxNanoSoundEffects,
	lootboxnano_t2_var1	= LootboxNanoSoundEffects,
	lootboxnano_t2_var2	= LootboxNanoSoundEffects,
	lootboxnano_t2_var3	= LootboxNanoSoundEffects,
	lootboxnano_t2_var4	= LootboxNanoSoundEffects,
	lootboxnano_t3_var1	= LootboxNanoSoundEffects,
	lootboxnano_t3_var2	= LootboxNanoSoundEffects,
	lootboxnano_t3_var3	= LootboxNanoSoundEffects,
	lootboxnano_t3_var4	= LootboxNanoSoundEffects,
	lootboxnano_t4_var1	= LootboxNanoSoundEffects,
	lootboxnano_t4_var2	= LootboxNanoSoundEffects,
	lootboxnano_t4_var3	= LootboxNanoSoundEffects,
	lootboxnano_t4_var4	= LootboxNanoSoundEffects,


	cortex_navalgeothermalpowerplant = cortex_geothermalpowerplant,
	cortex_advancednavalgeothermalpowerplant = cortex_advancedgeothermalpowerplant,
	armada_geothermalpowerplant = armada_geothermalpowerplant,
	armada_advancedgeothermalpowerplant = armada_advancedgeothermalpowerplant,

}

local scavCopies = {}
for _, udef in pairs(UnitDefs) do
	if GUIUnitSoundEffects[udef.name] then
		scavCopies[udef.name .. "_scav"] = GUIUnitSoundEffects[udef.name]
	end
end
table.mergeInPlace(GUIUnitSoundEffects, scavCopies)

for _, udef in pairs(UnitDefs) do
	if (not GUIUnitSoundEffects[udef.name]) and string.find(udef.name, "raptor") then
		--Spring.Echo("[RESPONSEDOUND FALLBACK]: Raptor", udef.name)
		GUIUnitSoundEffects[udef.name] = {}
	elseif not GUIUnitSoundEffects[udef.name] then
		if string.find(udef.name, "arm") then
			--Spring.Echo("[RESPONSEDOUND FALLBACK]: ARMADA", udef.name)
			GUIUnitSoundEffects[udef.name] = {
				BaseSoundSelectType = "arm-bot-small-sel",
				BaseSoundMovementType = "arm-bot-tiny-ok",
			}
		elseif string.find(udef.name, "cor") then
			--Spring.Echo("[RESPONSEDOUND FALLBACK]: CORTEX", udef.name)
			GUIUnitSoundEffects[udef.name] = {
				BaseSoundSelectType = "cor-bot-small-sel",
				BaseSoundMovementType = "cor-bot-medium-ok",
			}
		else
			if math.random(0,1) == 0 then
				--Spring.Echo("[RESPONSEDOUND FALLBACK]: OTHER, RANDOM ARMADA", udef.name)
				GUIUnitSoundEffects[udef.name] = {
					BaseSoundSelectType = "arm-bot-small-sel",
					BaseSoundMovementType = "arm-bot-tiny-ok",
				}
			else
				--Spring.Echo("[RESPONSEDOUND FALLBACK]: OTHER, RANDOM CORTEX", udef.name)
				GUIUnitSoundEffects[udef.name] = {
					BaseSoundSelectType = "cor-bot-small-sel",
					BaseSoundMovementType = "cor-bot-medium-ok",
				}
			end
		end
	end
end
