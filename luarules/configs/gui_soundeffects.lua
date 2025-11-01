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
	armcom = {
		BaseSoundSelectType = "arm-com-sel",
		BaseSoundMovementType = { "arm-com-ok-1", "arm-com-ok-2", "arm-com-ok-3", "arm-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	armcomlvl2 = {
		BaseSoundSelectType = "arm-com-sel",
		BaseSoundMovementType = { "arm-com-ok-1", "arm-com-ok-2", "arm-com-ok-3", "arm-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	armcomlvl3 = {
		BaseSoundSelectType = "arm-com-sel",
		BaseSoundMovementType = { "arm-com-ok-1", "arm-com-ok-2", "arm-com-ok-3", "arm-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	armcomlvl4 = {
		BaseSoundSelectType = "arm-com-sel",
		BaseSoundMovementType = { "arm-com-ok-1", "arm-com-ok-2", "arm-com-ok-3", "arm-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	armcomlvl5 = {
		BaseSoundSelectType = "arm-com-sel",
		BaseSoundMovementType = { "arm-com-ok-1", "arm-com-ok-2", "arm-com-ok-3", "arm-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	armcomlvl6 = {
		BaseSoundSelectType = "arm-com-sel",
		BaseSoundMovementType = { "arm-com-ok-1", "arm-com-ok-2", "arm-com-ok-3", "arm-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	armcomlvl7 = {
		BaseSoundSelectType = "arm-com-sel",
		BaseSoundMovementType = { "arm-com-ok-1", "arm-com-ok-2", "arm-com-ok-3", "arm-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	armcomlvl8 = {
		BaseSoundSelectType = "arm-com-sel",
		BaseSoundMovementType = { "arm-com-ok-1", "arm-com-ok-2", "arm-com-ok-3", "arm-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	armcomlvl9 = {
		BaseSoundSelectType = "arm-com-sel",
		BaseSoundMovementType = { "arm-com-ok-1", "arm-com-ok-2", "arm-com-ok-3", "arm-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	armcomlvl10 = {
		BaseSoundSelectType = "arm-com-sel",
		BaseSoundMovementType = { "arm-com-ok-1", "arm-com-ok-2", "arm-com-ok-3", "arm-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	armdecom = {
		BaseSoundSelectType = "arm-com-sel",
		BaseSoundMovementType = { "arm-com-ok-1", "arm-com-ok-2", "arm-com-ok-3", "arm-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},

	-- ARMADA T1 BUILDINGS

	armrad = {
		BaseSoundSelectType = "arm-bld-select-small",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-radar",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	armfrad = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-radar-sonar",
	},

	armsonar = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-small",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	armjamt = {
		BaseSoundSelectType = "arm-bld-select-small",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "jammer",
	},

	armmex = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-mex",
        BaseSoundActivate   = "mexon",
        BaseSoundDeactivate = "mexoff",
	},

	armamex = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "cloak",
        BaseSoundActivate   = "mexon",
        BaseSoundDeactivate = "mexoff",
	},

	armmakr = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker",
        BaseSoundActivate   = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},

	armfmkr = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker",
        BaseSoundActivate   = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},

	armwin = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-windgen",
	},

	armtide = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrghum",
	},

	armsolar = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-solar-alt",
		BaseSoundActivate   = "arm-bld-solar-activate",
		BaseSoundDeactivate = "arm-bld-solar-deactivate",
	},

	armadvsol = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-solar-alt-adv",
	},

	armgeo = {
		BaseSoundSelectType = "arm-bld-select-medium",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-geo",
	},

	armmstor = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage",
	},

	armuwms = {
		BaseSoundSelectType = "arm-sub-small-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-metal",
	},

	armestor = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage",
	},

	armuwes = {
		BaseSoundSelectType = "arm-sub-small-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-nrg",
	},

	armnanotc = {
		BaseSoundSelectType = "arm-bld-select-small",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-small",
	},

	armnanotcplat = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-small",
	},
	armnanotct2 = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-small",
	},
	armrespawn = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-medium",
	},
	armnanotc2plat = {
		BaseSoundSelectType = "arm-bld-select-large-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-small",
	},

	armfdrag = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall-water",
	},

	armdrag = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall",
	},

	armeyes = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "cloak",
	},

	armllt = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-small",
	},

	armhlt = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-medium",
	},

	armfhlt = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-medium",
	},

	armbeamer = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "beamer",
	},

	armrl = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-small",
	},

	armfrt = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-small",
	},

	armtl = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-small",
	},

	armdl = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-small",
	},

	armclaw = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "lightning",
	},

	armferret = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-medium",
	},

	armfrock = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-medium",
	},

	armcir = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-medium",
	},

	armguard = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arty-medium",
	},

	armjuno = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "bld-juno",
	},
	legjuno = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "bld-juno",
	},

	-- ARMADA T2 BUILDINGS

	armarad = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-radar-alt-t2",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	armveil = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "jammer-t2",
	},

	armason = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-sonar-t2",
	},

	armtarg = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "targeting",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	armfatf = {
		BaseSoundSelectType = "arm-bld-select-large-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "targeting",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	armmoho = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metal-t2",
        BaseSoundActivate   = "mohorun1",
        BaseSoundDeactivate = "mohooff1",
	},

	armshockwave = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "emp-rocket",
        BaseSoundActivate   = "mohorun1",
        BaseSoundDeactivate = "mohooff1",
	},

	armuwmme = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metal-t2",
        BaseSoundActivate   = "mohorun1",
        BaseSoundDeactivate = "mohooff1",
	},

	armmmkr = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker-t2",
        BaseSoundActivate   = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},

	armuwmmm = {
		BaseSoundSelectType = "arm-bld-select-large-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker-t2",
        BaseSoundActivate   = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},

	armuwadvms = {
		BaseSoundSelectType = "arm-bld-metal-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-metal",
	},

	armuwadves = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-nrg",
	},

	armgmm = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-geo-t2-safe",
	},

	armageo = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-geo-t2-explo",
	},

	armfus = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion",
	},

	armckfus = {
		BaseSoundSelectType = "cloak",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion",
	},

	armdf = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion-decoy",
	},

	armafus = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion-adv",
	},

	armuwfus = {
		BaseSoundSelectType = "arm-bld-select-large-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion-uw",
	},

	armfort = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall-t2",
	},

	armlwall = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "lightning",
	},

	armflak = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "flak",
	},

	armfflak = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "flak",
	},

	armkraken = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "plasma-large",
	},

	armmercury = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-large",
	},

	armpb = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "plasma-large-alt",
	},

	armamb = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arty-large",
	},

	armatl = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-medium",
	},

	armamd = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "nuke-anti",
	},

	armemp = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "emp-rocket",
	},

	armsd = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-ics",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	armgate = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-shield",
	},

	armgatet3 = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-shield",
	},

	armfgate = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-shield",
	},

	armsilo = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "nuke",
	},

	armanni = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-large",
	},

	armbrtha = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "lrpc",
	},

	armvulc = {
		BaseSoundSelectType = "lrpc",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lolcannon",
	},


	-- ARMADA FACTORIES

	armlab = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lab",
	},

	armalab = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lab-t2",
	},

	armvp = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-vp",
	},

	armavp = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-vp-t2",
	},

	armap = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-ap",
	},

	armplat = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-sp",
	},

	armaap = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-ap-t2",
	},

	armsy = {
		BaseSoundSelectType   = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType   = "arm-bld-factory-water",
	},

	armasy = {
		BaseSoundSelectType   = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType   = "arm-bld-factory-water-t2",
	},

	armamsub = {
		BaseSoundSelectType   = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType   = "arm-bld-factory-t2-uw",
	},

	armhp = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-factory-hover",
	},

	armfhp = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-factory-hover-water",
	},

	armshltx = {
		BaseSoundSelectType = "arm-bld-factory-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-gant-t3-sel",
	},

	armshltxuw = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-gant-t3-sel",
	},

	-- ARMADA MINES

	armmine1 = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-small",
	},

	armmine2 = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-medium",
	},

	armmine3 = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-large",
	},

	armfmine3 = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-large-water",
	},

	-- ARMADA HOVERCRAFT

	armsh = {
		BaseSoundSelectType = "arm-hov-small-sel",
		BaseSoundMovementType = "arm-hov-small-ok",
		--BaseSoundMovementVol = 0.6,
		BaseSoundWeaponType = "laser-tiny",
	},
	armmh = {
		BaseSoundSelectType = "arm-hov-small-sel",
		BaseSoundMovementType = "arm-hov-small-ok",
		BaseSoundWeaponType = "rocket-small",
	},
	armch = {
		BaseSoundSelectType = "arm-hov-small-sel",
		BaseSoundMovementType = "arm-hov-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armah = {
		BaseSoundSelectType = "arm-hov-small-sel",
		BaseSoundMovementType = "arm-hov-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	armanac = {
		BaseSoundSelectType = "arm-hov-small-sel",
		BaseSoundMovementType = "arm-hov-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	armlun = {
		BaseSoundSelectType = "arm-hov-large-sel",
		BaseSoundMovementType = "arm-hov-large-ok",
		BaseSoundWeaponType = "laser-large",
	},

	-- ARMADA T1 BOTS

	armflea = {
		BaseSoundSelectType = "arm-bot-tiny-sel",
		BaseSoundMovementType = "arm-bot-tiny-ok",
		BaseSoundWeaponType = "laser-tiny",
	},
	armpw = {
		BaseSoundSelectType = "arm-bot-tiny-sel",
		BaseSoundMovementType = "arm-bot-tiny-ok",
		BaseSoundWeaponType = "fastemgalt-small",
	},
	armham = {
		BaseSoundSelectType = "arm-bot-small-sel",
		BaseSoundMovementType = "arm-bot-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	armrock = {
		BaseSoundSelectType = "arm-bot-small-sel",
		BaseSoundMovementType = "arm-bot-small-ok",
		BaseSoundWeaponType = "rocketalt-small",
	},
	armjeth = {
		BaseSoundSelectType = "arm-bot-small-sel",
		BaseSoundMovementType = "arm-bot-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	armwar = {
		BaseSoundSelectType = "arm-bot-medium-sel",
		BaseSoundMovementType = "arm-bot-medium-alt-ok",
		BaseSoundWeaponType = "laser-medium",
	},
	armck = {
		BaseSoundSelectType = "arm-bot-small-sel",
		BaseSoundMovementType = "arm-bot-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armrectr = {
		BaseSoundSelectType = "arm-bot-tiny-sel",
		BaseSoundMovementType = "arm-bot-tiny-ok",
		BaseSoundWeaponType = "rez-small",
	},

	-- ARMADA T2 BOTS

	armvader = {
		BaseSoundSelectType = "arm-bot-tiny-sel",
		BaseSoundMovementType = "arm-bot-tiny-ok",
		BaseSoundWeaponType = "bomb",
	},
	armaser = {
		BaseSoundSelectType = "arm-bot-small-sel",
		BaseSoundMovementType = "arm-bot-small-ok",
		BaseSoundWeaponType = "jammer",
	},
	armmark = {
		BaseSoundSelectType = "arm-bot-small-sel",
		BaseSoundMovementType = "arm-bot-small-ok",
		BaseSoundWeaponType = "radar-t2",
	},
	armspy = {
		BaseSoundSelectType = "arm-bot-small-sel",
		BaseSoundMovementType = "arm-bot-small-ok",
		BaseSoundWeaponType = "cloak",
	},
	armspid = {
		BaseSoundSelectType = "arm-bot-at-sel",
		BaseSoundMovementType = "arm-bot-at-ok",
		BaseSoundWeaponType = "emp-laser",
	},
	armfast = {
		BaseSoundSelectType = "arm-bot-medium-sel",
		BaseSoundMovementType = "arm-bot-medium-ok",
		BaseSoundWeaponType = "fastemg-medium",
	},
	armfark = {
		BaseSoundSelectType = "arm-bot-medium-sel",
		BaseSoundMovementType = "arm-bot-medium-alt-ok",
		BaseSoundWeaponType = "con-assist",
	},
	armamph = {
		BaseSoundSelectType = "arm-bot-medium-amph-sel",
		BaseSoundMovementType = "arm-bot-medium-amph-ok",
		BaseSoundWeaponType = "laser-small",
	},
	armfido = {
		BaseSoundSelectType = "arm-bot-medium-sel",
		BaseSoundMovementType = "arm-bot-medium-alt-ok",
		BaseSoundWeaponType = "plasma-medium-alt",
	},
	armzeus = {
		BaseSoundSelectType = "arm-bot-large-ok",
		BaseSoundMovementType = "arm-bot-large-sel",
		BaseSoundWeaponType = "lightning",
	},
	armack = {
		BaseSoundSelectType = "arm-bot-medium-sel",
		BaseSoundMovementType = "arm-bot-medium-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	armsptk = {
		BaseSoundSelectType = "arm-bot-at-sel",
		BaseSoundMovementType = "arm-bot-at-ok",
		BaseSoundWeaponType = "rocket-large",
	},
	armaak = {
		BaseSoundSelectType = "arm-bot-large-ok",
		BaseSoundMovementType = "arm-bot-large-sel",
		BaseSoundWeaponType = "aarocket-medium-flak",
	},
	armsnipe = {
		BaseSoundSelectType = "arm-bot-medium-stealth-sel",
		BaseSoundMovementType = "arm-bot-medium-stealth-ok",
		BaseSoundWeaponType = "sniper",
	},
	armmav = {
		BaseSoundSelectType = "arm-bot-large-sel",
		BaseSoundMovementType = "arm-bot-large-ok",
		BaseSoundWeaponType = "plasma-medium",
	},
	armscab = {
		BaseSoundSelectType = "arm-bot-at-sel",
		BaseSoundMovementType = "arm-bot-at-ok",
		BaseSoundWeaponType = "nuke-anti",
	},
	armfboy = {
		BaseSoundSelectType = "arm-bot-huge-sel",
		BaseSoundMovementType = "arm-bot-huge-ok",
		BaseSoundWeaponType = "plasma-large",
	},

	-- ARMADA T3 BOTS

	armmar = {
		BaseSoundSelectType = "arm-bot-huge-sel",
		BaseSoundMovementType = "arm-bot-huge-ok",
		BaseSoundWeaponType = "plasma-large-alt",
	},
	armvang = {
		BaseSoundSelectType = "arm-bot-t3-sel",
		BaseSoundMovementType = "arm-bot-t3-ok",
		BaseSoundWeaponType = "lrpc",
	},
	armraz = {
		BaseSoundSelectType = "arm-bot-t3-sel",
		BaseSoundMovementType = "arm-bot-t3-ok-alt",
		BaseSoundWeaponType = "laser-large",
	},
	armbanth = {
		BaseSoundSelectType = "arm-banth-sel",
		BaseSoundMovementType = "arm-banth-ok",
		BaseSoundWeaponType = "arty-medium",
	},
	armthor = {
		BaseSoundSelectType = "arm-bot-t3-sel",
		BaseSoundMovementType = "arm-tnk-largealt-ok",
		BaseSoundWeaponType = "lightning",
	},

	-- ARMADA T1 VEHICLES

	armfav = {
		BaseSoundSelectType = "arm-veh-tiny-sel",
		BaseSoundMovementType = "arm-veh-tiny-ok",
		BaseSoundWeaponType = "laser-tiny",
	},
	armflash = {
		BaseSoundSelectType = "arm-veh-small-sel",
		BaseSoundMovementType = "arm-veh-small-ok",
		BaseSoundWeaponType = "fastemg-small",
	},
	armart = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "arty-small",
	},
	armsam = {
		BaseSoundSelectType = "arm-veh-small-sel",
		BaseSoundMovementType = "arm-veh-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	armpincer = {
		BaseSoundSelectType = "arm-tnk-small-amph-sel",
		BaseSoundMovementType = "arm-tnk-small-amph-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	armstump = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	armjanus = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "rocket-medium",
	},
	armcv = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armbeaver = {
		BaseSoundSelectType = "arm-tnk-small-amph-sel",
		BaseSoundMovementType = "arm-tnk-small-amph-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armmlv = {
		BaseSoundSelectType = "arm-veh-tiny-sel",
		BaseSoundMovementType = "arm-veh-tiny-ok",
		BaseSoundWeaponType = "mine-small",
	},

	-- ARMADA T2 VEHICLES

	armjam = {
		BaseSoundSelectType = "arm-veh-small-sel",
		BaseSoundMovementType = "arm-veh-small-ok",
		BaseSoundWeaponType = "jammer",
	},
	armseer = {
		BaseSoundSelectType = "arm-veh-small-sel",
		BaseSoundMovementType = "arm-veh-small-ok",
		BaseSoundWeaponType = "radar",
	},
	armgremlin = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "cloak",
	},
	armconsul = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "con-assist",
	},
	armmart = {
		BaseSoundSelectType = "arm-tnk-medium-sel",
		BaseSoundMovementType = "arm-tnk-medium-ok",
		BaseSoundWeaponType = "arty-medium",
	},
	armlatnk = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "lightning",
	},
	armyork = {
		BaseSoundSelectType = "arm-tnk-medium-sel",
		BaseSoundMovementType = "arm-tnk-medium-ok",
		BaseSoundWeaponType = "flak",
	},
	armcroc = {
		BaseSoundSelectType = "arm-tnk-medium-sel",
		BaseSoundMovementType = "arm-tnk-medium-ok",
		BaseSoundWeaponType = "plasma-medium",
	},
	armacv = {
		BaseSoundSelectType = "arm-tnk-small-sel",
		BaseSoundMovementType = "arm-tnk-small-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	armmerl = {
		BaseSoundSelectType = "arm-tnk-medium-sel",
		BaseSoundMovementType = "arm-tnk-medium-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	armbull = {
		BaseSoundSelectType = "arm-tnk-large-sel",
		BaseSoundMovementType = "arm-tnk-large-ok",
		BaseSoundWeaponType = "plasma-medium",
	},
	armmanni = {
		BaseSoundSelectType = "arm-tnk-large-sel",
		BaseSoundMovementType = "arm-tnk-largealt-ok",
		BaseSoundWeaponType = "laser-large",
	},

	-- ARMADA SHIPS-SUBS

	armdecade = {
		BaseSoundSelectType = "arm-shp-small-sel",
		BaseSoundMovementType = "arm-shp-small-ok",
		BaseSoundWeaponType = "fastemg-small",
	},
	armpt = {
		BaseSoundSelectType = "arm-shp-small-sel",
		BaseSoundMovementType = "arm-shp-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	armcs = {
		BaseSoundSelectType = "arm-shp-medium-sel",
		BaseSoundMovementType = "arm-shp-medium-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armrecl = {
		BaseSoundSelectType = "arm-sub-small-sel",
		BaseSoundMovementType = "arm-sub-small-ok",
		BaseSoundWeaponType = "rez-small",
	},
	armpship = {
		BaseSoundSelectType = "arm-shp-medium-sel",
		BaseSoundMovementType = "arm-shp-medium-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	armsub = {
		BaseSoundSelectType = "arm-sub-small-sel",
		BaseSoundMovementType = "arm-sub-small-ok",
		BaseSoundWeaponType = "torpedo-small",
	},
	armroy = {
		BaseSoundSelectType = "arm-shp-medium-sel",
		BaseSoundMovementType = "arm-shp-medium-ok",
		BaseSoundWeaponType = "plasma-medium-torpedo",
	},
	armsjam = {
		BaseSoundSelectType = "arm-shp-small-sel",
		BaseSoundMovementType = "arm-shp-small-ok",
		BaseSoundWeaponType = "jammer",
	},
	armmls = {
		BaseSoundSelectType = "arm-shp-small-sel",
		BaseSoundMovementType = "arm-shp-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armacsub = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		BaseSoundMovementType = "arm-sub-medium-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	armsubk = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		BaseSoundMovementType = "arm-sub-medium-ok",
		BaseSoundWeaponType = "torpedo-medium",
	},
	armexcalibur = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		BaseSoundMovementType = "arm-sub-medium-ok",
		BaseSoundWeaponType = "laser-large",
	},
	armaas = {
		BaseSoundSelectType = "arm-shp-medium-sel",
		BaseSoundMovementType = "arm-shp-medium-ok",
		BaseSoundWeaponType = "flak",
	},
	armcrus = {
		BaseSoundSelectType = "arm-shp-large-sel",
		BaseSoundMovementType = "arm-shp-large-ok",
		BaseSoundWeaponType = "plasma-medium-torpedo",
	},
	armantiship = {
		BaseSoundSelectType = "arm-shp-large-sel",
		BaseSoundMovementType = "arm-shp-large-ok",
		BaseSoundWeaponType = "radar-support",
	},
	armserp = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		BaseSoundMovementType = "arm-sub-medium-ok",
		BaseSoundWeaponType = "torpedo-medium",
	},
	armseadragon = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		BaseSoundMovementType = "arm-sub-medium-ok",
		BaseSoundWeaponType = "nuke",
	},
	armmship = {
		BaseSoundSelectType = "arm-shp-large-sel",
		BaseSoundMovementType = "arm-shp-large-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	armbats = {
		BaseSoundSelectType = "arm-shp-large-sel",
		BaseSoundMovementType = "arm-shp-large-ok",
		BaseSoundWeaponType = "plasma-large",
	},
	armepoch = {
		BaseSoundSelectType = "arm-shp-huge-sel",
		BaseSoundMovementType = "arm-shp-huge-ok",
		BaseSoundWeaponType = "plasma-huge",
	},

	-- ARMADA AIRCRAFT

	armpeep = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "radar",
	},
	armatlas = {
		BaseSoundSelectType = "arm-air-transport-small-sel",
		BaseSoundMovementType = "arm-air-transport-small-ok",
		BaseSoundWeaponType = "transport-large",
	},
	armhvytrans = {
		BaseSoundSelectType = "arm-air-transport-small-sel",
		BaseSoundMovementType = "arm-air-transport-small-ok",
		BaseSoundWeaponType = "transport-large",
	},
	armfig = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "aarocket-air",
	},
	armsfig = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "aarocket-air",
	},
	armca = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armassistdrone = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armsehak = {
		BaseSoundSelectType = "arm-air-gunship-alt-sel",
		BaseSoundMovementType = "arm-air-gunship-alt-ok",
		BaseSoundWeaponType = "radar",
	},
	armkam = {
		BaseSoundSelectType = "arm-air-gunship-alt-sel",
		BaseSoundMovementType = "arm-air-gunship-alt-ok",
		BaseSoundWeaponType = "fastemg-small",
	},
	armthund = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-small",
	},
	armcsa = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	armsaber = {
		BaseSoundSelectType = "arm-air-gunship-sel",
		BaseSoundMovementType = "arm-air-gunship-ok",
		BaseSoundWeaponType = "laser-medium",
	},
	armsb = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-small",
	},
	armseap = {
		BaseSoundSelectType = "arm-air-gunship-sel",
		BaseSoundMovementType = "arm-air-gunship-ok",
		BaseSoundWeaponType = "air-bomb-small-torp",
	},
	armhawk = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "aarocket-air",
	},
	armawac = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "radar",
	},
	armpnix = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-large",
	},
	armstil = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-large-emp",
	},
	armaca = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	armbrawl = {
		BaseSoundSelectType = "arm-air-gunship-alt-sel",
		BaseSoundMovementType = "arm-air-gunship-alt-ok",
		BaseSoundWeaponType = "fastemg-medium",
	},
	armdfly = {
		BaseSoundSelectType = "arm-air-transport-large-sel",
		BaseSoundMovementType = "arm-air-transport-large-ok",
		BaseSoundWeaponType = "transport-large",
	},
	armlance = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-large-torp",
	},
	armblade = {
		BaseSoundSelectType = "arm-air-gunship-sel",
		BaseSoundMovementType = "arm-air-gunship-ok",
		BaseSoundWeaponType = "rocket-large",
	},
	armliche = {
		BaseSoundSelectType = "arm-air-large-sel",
		BaseSoundMovementType = "arm-air-large-ok",
		BaseSoundWeaponType = "air-bomb-large-nuclear",
	},

	-- CORTEX COMMANDER
	corcom = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	corcomlvl2 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	corcomlvl3 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	corcomlvl4 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	corcomlvl5 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	corcomlvl6 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	corcomlvl7 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	corcomlvl8 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	corcomlvl9 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	corcomlvl10 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},
	cordecom = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "laser-tiny",
	},

	-- CORTEX T1 BUILDINGS

	corrad = {
		BaseSoundSelectType = "arm-bld-select-small",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-radar",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	corfrad = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-radar-sonar",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	corsonar = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-small",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	corjamt = {
		BaseSoundSelectType = "arm-bld-select-small",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "jammer",
	},

	cormex = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-mex",
        BaseSoundActivate   = "mexon",
        BaseSoundDeactivate = "mexoff",
	},

	corexp = {
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

	cormakr = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker",
        BaseSoundActivate = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},

	corfmkr = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker",
        BaseSoundActivate = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},

	corwin = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-windgen",
	},

	cortide = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrghum",
	},

	corsolar = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-solar-alt",
		BaseSoundActivate = "cor-bld-solar-activate",
		BaseSoundDeactivate = "cor-bld-solar-deactivate",
	},

	coradvsol = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-solar-alt-adv",
	},

	corgeo = {
		BaseSoundSelectType = "arm-bld-select-medium",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-geo",
	},

	cormstor = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage",
	},

	coruwms = {
		BaseSoundSelectType = "arm-sub-small-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-metal",
	},

	corestor = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage",
	},

	coruwes = {
		BaseSoundSelectType = "arm-sub-small-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-nrg",
	},

	cornanotc = {
		BaseSoundSelectType = "arm-bld-select-small",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-small",
	},

	cornanotcplat = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-small",
	},

	cornanotct2 = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-small",
	},
	cornanotc2plat = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-small",
	},

	correspawn = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-small",
	},

	corfdrag = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall-water",
	},

	cordrag = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall",
	},

	coreyes = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "cloak",
	},

	corllt = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-small",
	},

	corhllt = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-small-cor",
	},

	corhlt = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-medium",
	},

	corfhlt = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-medium",
	},

	corrl = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-small",
	},

	legrl = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-small",
	},

	corfrt = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-small",
	},

	cortl = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-small",
	},

	cordl = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-small",
	},

	cormaw = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "flame-alt",
	},

	cormaw = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "flame-alt",
	},

	cormadsam = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-medium",
	},

	corfrock = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-medium",
	},

	corerad = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-medium",
	},

	corpun = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arty-medium",
	},

	corjuno = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "bld-juno",
	},

	-- CORTEX T2 BUILDINGS

	corarad = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-radar-alt-t2",
        BaseSoundActivate = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	corshroud = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "jammer-t2",
	},

	corason = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-sonar-t2",
	},

	cortarg = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "targeting",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	corfatf = {
		BaseSoundSelectType = "arm-bld-select-large-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "targeting",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	cormoho = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metal-t2",
        BaseSoundActivate   = "mohorun1",
        BaseSoundDeactivate = "mohooff1",
	},
    cormexp = {
        BaseSoundSelectType = "arm-bld-metal",
        --BaseSoundMovementType = "",
        BaseSoundWeaponType = "laser-large",
        BaseSoundActivate   = "mohorun1",
        BaseSoundDeactivate = "mohooff1",
    },

	coruwmme = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metal-t2",
        BaseSoundActivate   = "mohorun1",
        BaseSoundDeactivate = "mohooff1",
	},

	cormmkr = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker-t2",
        BaseSoundActivate   = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},

	coruwmmm = {
		BaseSoundSelectType = "arm-bld-select-large-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker-t2",
        BaseSoundActivate   = "cor-bld-mm-t2-activate",
        BaseSoundDeactivate = "cor-bld-mm-t2-deactivate",
	},

	coruwadvms = {
		BaseSoundSelectType = "arm-bld-metal-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-metal",
	},

	coruwadves = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-nrg",
	},

	corbhmth = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-geo-t2-safe",
	},

	corageo = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-geo-t2-explo",
	},

	corfus = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion",
	},

	corafus = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion-adv",
	},

	coruwfus = {
		BaseSoundSelectType = "arm-bld-select-large-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion-uw",
	},

	corfort = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall-t2",
	},

	cormwall = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-large",
	},

	corflak = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "flak",
	},

	corenaa = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "flak",
	},

	corfdoom = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-large",
	},

	corscreamer = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-large",
	},

	corvipe = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "rocket-large",
	},

	cortoast = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arty-large",
	},

	coratl = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-medium",
	},

	corfmd = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "nuke-anti",
	},

	cortron = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "rocketalt-large",
	},

	corsd = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-ics",
        BaseSoundActivate = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},

	corgate = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-shield",
	},

	corgatet3 = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-shield",
	},

	corfgate = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-shield",
	},

	corsilo = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "nuke",
	},

	cordoom = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-large",
	},

	corint = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "lrpc",
	},

	corbuzz = {
		BaseSoundSelectType = "lrpc",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lolcannon",
	},


	-- CORTEX FACTORIES

	corlab = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lab",
	},

	coralab = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lab-t2",
	},

	corvp = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-vp",
	},

	coravp = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-vp-t2",
	},

	corap = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-ap",
	},

	coraap = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-ap-t2",
	},

	corsy = {
		BaseSoundSelectType   = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType   = "arm-bld-factory-water",
	},

	corasy = {
		BaseSoundSelectType   = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType   = "arm-bld-factory-water-t2",
	},

	coramsub = {
		BaseSoundSelectType   = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType   = "arm-bld-factory-t2-uw",
	},

	corhp = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-factory-hover",
	},

	corfhp = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-factory-hover-water",
	},

	corplat = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-sp",
	},

	corgant = {
		BaseSoundSelectType = "arm-bld-factory-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-gant-t3-sel",
	},

	corgantuw = {
		BaseSoundSelectType = "arm-sub-medium-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-gant-t3-sel",
	},

	-- CORTEX MINES

	cormine1 = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-small",
	},

	cormine2 = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-medium",
	},

	cormine3 = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-large",
	},

	cormine4 = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-large",
	},

	corfmine3 = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-large-water",
	},

	-- CORTEX HOVERCRAFT

	corsh = {
		BaseSoundSelectType = "cor-hov-small-sel",
		BaseSoundMovementType = "cor-hov-small-ok",
		--BaseSoundMovementVol = 0.6,
		BaseSoundWeaponType = "laser-tiny",
	},
	cormh = {
		BaseSoundSelectType = "cor-hov-small-sel",
		BaseSoundMovementType = "cor-hov-small-ok",
		BaseSoundWeaponType = "rocket-small",
	},
	corch = {
		BaseSoundSelectType = "cor-hov-small-sel",
		BaseSoundMovementType = "cor-hov-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	corah = {
		BaseSoundSelectType = "cor-hov-small-sel",
		BaseSoundMovementType = "cor-hov-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	corsnap = {
		BaseSoundSelectType = "cor-hov-small-sel",
		BaseSoundMovementType = "cor-hov-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	corhal = {
		BaseSoundSelectType = "cor-hov-large-sel",
		BaseSoundMovementType = "cor-hov-large-ok",
		BaseSoundWeaponType = "laser-medium",
	},
	corsok = {
		BaseSoundSelectType = "cor-hov-large-sel",
		BaseSoundMovementType = "cor-hov-large-ok",
		BaseSoundWeaponType = "laser-large",
	},

	-- CORTEX T1 BOTS

	corak = {
		BaseSoundSelectType = "cor-bot-tiny-sel",
		BaseSoundMovementType = "cor-bot-tiny-ok",
		BaseSoundWeaponType = "laser-small-cor",
	},
	corthud = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	corstorm = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "rocketalt-small",
	},
	corcrash = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	corck = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	cornecro = {
		BaseSoundSelectType = "cor-bot-tiny-sel",
		BaseSoundMovementType = "cor-bot-tiny-ok",
		BaseSoundWeaponType = "rez-small",
	},
	corkark = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "heatray",
	},

	-- CORTEX T2 BOTS

	corroach = {
		BaseSoundSelectType = "cor-bot-tiny-sel",
		BaseSoundMovementType = "cor-bot-tiny-ok",
		BaseSoundWeaponType = "bomb",
	},
	corspec = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "jammer",
	},
	corvoyr = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "radar-t2",
	},
	corspy = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "cloak",
	},
	corpyro = {
		BaseSoundSelectType = "cor-bot-medium-sel",
		BaseSoundMovementType = "cor-bot-medium-ok",
		BaseSoundWeaponType = "flame-alt",
	},
	corfast = {
		BaseSoundSelectType = "cor-bot-medium-sel",
		BaseSoundMovementType = "cor-bot-medium-ok",
		BaseSoundWeaponType = "con-assist",
	},
	coramph = {
		BaseSoundSelectType = "cor-bot-medium-amph-sel",
		BaseSoundMovementType = "cor-bot-medium-amph-ok",
		BaseSoundWeaponType = "laser-medium",
	},
	cormort = {
		BaseSoundSelectType = "cor-bot-medium-sel",
		BaseSoundMovementType = "cor-bot-medium-ok",
		BaseSoundWeaponType = "arty-medium",
	},
	corack = {
		BaseSoundSelectType = "cor-bot-medium-sel",
		BaseSoundMovementType = "cor-bot-medium-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	corsktl = {
		BaseSoundSelectType = "cor-bot-at-sel",
		BaseSoundMovementType = "cor-bot-at-ok",
		BaseSoundWeaponType = "bomb",
	},
	corcan = {
		BaseSoundSelectType = "cor-bot-large-sel",
		BaseSoundMovementType = "cor-bot-large-ok",
		BaseSoundWeaponType = "laser-medium",
	},
	corhrk = {
		BaseSoundSelectType = "cor-bot-medium-sel",
		BaseSoundMovementType = "cor-bot-medium-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	coraak = {
		BaseSoundSelectType = "cor-bot-large-ok",
		BaseSoundMovementType = "cor-bot-large-sel",
		BaseSoundWeaponType = "aarocket-medium-flak",
	},
	cortermite = {
		BaseSoundSelectType = "cor-bot-at-sel",
		BaseSoundMovementType = "cor-bot-at-ok",
		BaseSoundWeaponType = "heatray",
	},
	cormando = {
		BaseSoundSelectType = "cor-bot-medium-stealth-sel",
		BaseSoundMovementType = "cor-bot-medium-stealth-ok",
		BaseSoundWeaponType = "plasma-medium",
	},
	corsumo = {
		BaseSoundSelectType = "cor-bot-huge-sel",
		BaseSoundMovementType = "cor-bot-huge-ok",
		BaseSoundWeaponType = "laser-large",
	},

	-- CORTEX T3 BOTS

	corshiva = {
		BaseSoundSelectType = "cor-bot-huge-sel",
		BaseSoundMovementType = "cor-bot-huge-ok",
		BaseSoundWeaponType = "plasma-large-alt",
	},
	corkarg = {
		BaseSoundSelectType = "cor-bot-t3-at-sel",
		BaseSoundMovementType = "cor-bot-t3-at-ok",
		BaseSoundWeaponType = "lrpc",
	},
	corcat = {
		BaseSoundSelectType = "cor-bot-t3-sel",
		BaseSoundMovementType = "cor-bot-t3-ok",
		BaseSoundWeaponType = "laser-large",
	},
	corjugg = {
		BaseSoundSelectType = "cor-jugg-sel",
		BaseSoundMovementType = "cor-jugg-ok",
		BaseSoundWeaponType = "oranges-gun",
	},
	corkorg = {
		BaseSoundSelectType = "cor-korg-sel",
		BaseSoundMovementType = { "cor-korg-ok1", "cor-korg-ok2", "cor-korg-ok3", },
		BaseSoundWeaponType = "heatray-xl",
	},
	cordemon = {
		BaseSoundSelectType = "cor-bot-huge-sel",
		BaseSoundMovementType = "cor-bot-huge-ok",
		BaseSoundWeaponType = "flame-alt",
	},

	-- CORTEX T1 VEHICLES

	corfav = {
		BaseSoundSelectType = "cor-veh-tiny-sel",
		BaseSoundMovementType = "cor-veh-tiny-ok",
		BaseSoundWeaponType = "laser-tiny",
	},
	corgator = {
		BaseSoundSelectType = "cor-veh-small-sel",
		BaseSoundMovementType = "cor-veh-small-ok",
		BaseSoundWeaponType = "laser-small-cor",
	},
	corwolv = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "arty-small",
	},
	cormist = {
		BaseSoundSelectType = "cor-veh-small-sel",
		BaseSoundMovementType = "cor-veh-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	corgarp = {
		BaseSoundSelectType = "cor-tnk-small-amph-sel",
		BaseSoundMovementType = "cor-tnk-small-amph-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	corraid = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	corlevlr = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "rocket-medium",
	},
	corcv = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	cormuskrat = {
		BaseSoundSelectType = "cor-tnk-small-amph-sel",
		BaseSoundMovementType = "cor-tnk-small-amph-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	cormlv = {
		BaseSoundSelectType = "cor-veh-tiny-sel",
		BaseSoundMovementType = "cor-veh-tiny-ok",
		BaseSoundWeaponType = "mine-small",
	},

	-- CORTEX T2 VEHICLES

	coreter = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "jammer",
	},
	corvrad = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "radar",
	},
	cormart = {
		BaseSoundSelectType = "cor-tnk-medium-sel",
		BaseSoundMovementType = "cor-tnk-medium-ok",
		BaseSoundWeaponType = "arty-medium",
	},
	corsent = {
		BaseSoundSelectType = "cor-tnk-medium-sel",
		BaseSoundMovementType = "cor-tnk-medium-ok",
		BaseSoundWeaponType = "flak",
	},
	corseal = {
		BaseSoundSelectType = "cor-tnk-medium-amph-sel",
		BaseSoundMovementType = "cor-tnk-medium-amph-ok",
		BaseSoundWeaponType = "plasma-medium",
	},
	coracv = {
		BaseSoundSelectType = "cor-tnk-small-sel",
		BaseSoundMovementType = "cor-tnk-small-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	corvroc = {
		BaseSoundSelectType = "cor-tnk-medium-sel",
		BaseSoundMovementType = "cor-tnk-medium-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	correap = {
		BaseSoundSelectType = "cor-tnk-large-sel",
		BaseSoundMovementType = "cor-tnk-large-ok",
		BaseSoundWeaponType = "plasma-medium",
	},
	corsiegebreaker = {
		BaseSoundSelectType = "cor-tnk-large-sel",
		BaseSoundMovementType = "cor-tnk-large-ok",
		BaseSoundWeaponType = "laser-large",
	},
	corban = {
		BaseSoundSelectType = "cor-tnk-large-sel",
		BaseSoundMovementType = "cor-tnk-large-ok",
		BaseSoundWeaponType = "arty-large",
	},
	corparrow = {
		BaseSoundSelectType = "cor-tnk-medium-amph-sel",
		BaseSoundMovementType = "cor-tnk-medium-amph-ok",
		BaseSoundWeaponType = "plasma-large",
	},
	cormabm = {
		BaseSoundSelectType = "cor-tnk-large-sel",
		BaseSoundMovementType = "cor-tnk-large-ok",
		BaseSoundWeaponType = "nuke-anti",
	},
	corgol = {
		BaseSoundSelectType = "cor-tnk-huge-sel",
		BaseSoundMovementType = "cor-tnk-huge-ok",
		BaseSoundWeaponType = "plasma-large",
	},
	cortrem = {
		BaseSoundSelectType = "cor-tnk-huge-sel",
		BaseSoundMovementType = "cor-tnk-huge-ok",
		BaseSoundWeaponType = "arty-large",
	},
	corsala = {
		BaseSoundSelectType = "cor-tnk-medium-amph-sel",
		BaseSoundMovementType = "cor-tnk-medium-amph-ok",
		BaseSoundWeaponType = "heatray",
	},
	corvac = {
		BaseSoundSelectType = "cor-tnk-large-sel",
		BaseSoundMovementType = "cor-tnk-large-ok",
		BaseSoundWeaponType = "con-assist",
	},
	corphantom = {
		BaseSoundSelectType = "cor-tnk-medium-amph-sel",
		BaseSoundMovementType = "cor-tnk-medium-amph-ok",
		BaseSoundWeaponType = "cloak",
	},
	-- FUN MODE - made possible by Teifion and Basic
	-- corfav = {
	-- BaseSoundSelectType   = "cor-veh-tiny-sel",
	-- BaseSoundMovementType = "cor-veh-tiny-ok",
	-- BaseSoundWeaponType   = "laser-small",
	-- },
	-- corgol = {
	-- BaseSoundSelectType   = "cor-tnk-large-sel",
	-- BaseSoundMovementType = "cor-tnk-large-ok",
	-- BaseSoundWeaponType   = "plasma-huge",
	-- },

	-- CORTEX SHIPS-SUBS

	coresupp = {
		BaseSoundSelectType = "cor-shp-small-sel",
		BaseSoundMovementType = "cor-shp-small-ok",
		BaseSoundWeaponType = "fastemg-small",
	},
	corpt = {
		BaseSoundSelectType = "cor-shp-small-sel",
		BaseSoundMovementType = "cor-shp-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	corcs = {
		BaseSoundSelectType = "cor-shp-medium-sel",
		BaseSoundMovementType = "cor-shp-medium-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	correcl = {
		BaseSoundSelectType = "cor-sub-small-sel",
		BaseSoundMovementType = "cor-sub-small-ok",
		BaseSoundWeaponType = "rez-small",
	},
	corpship = {
		BaseSoundSelectType = "cor-shp-medium-sel",
		BaseSoundMovementType = "cor-shp-medium-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	corsub = {
		BaseSoundSelectType = "cor-sub-small-sel",
		BaseSoundMovementType = "cor-sub-small-ok",
		BaseSoundWeaponType = "torpedo-small",
	},
	corroy = {
		BaseSoundSelectType = "cor-shp-medium-sel",
		BaseSoundMovementType = "cor-shp-medium-ok",
		BaseSoundWeaponType = "plasma-medium-torpedo",
	},
	corsjam = {
		BaseSoundSelectType = "cor-shp-small-sel",
		BaseSoundMovementType = "cor-shp-small-ok",
		BaseSoundWeaponType = "jammer",
	},
	cormls = {
		BaseSoundSelectType = "cor-shp-small-sel",
		BaseSoundMovementType = "cor-shp-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	coracsub = {
		BaseSoundSelectType = "cor-sub-medium-sel",
		BaseSoundMovementType = "cor-sub-medium-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	corshark = {
		BaseSoundSelectType = "cor-sub-medium-sel",
		BaseSoundMovementType = "cor-sub-medium-ok",
		BaseSoundWeaponType = "torpedo-medium",
	},
	cordesolator = {
		BaseSoundSelectType = "cor-sub-medium-sel",
		BaseSoundMovementType = "cor-sub-medium-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	corarch = {
		BaseSoundSelectType = "cor-shp-medium-sel",
		BaseSoundMovementType = "cor-shp-medium-ok",
		BaseSoundWeaponType = "flak",
	},
	corcrus = {
		BaseSoundSelectType = "cor-shp-large-sel",
		BaseSoundMovementType = "cor-shp-large-ok",
		BaseSoundWeaponType = "plasma-medium-torpedo",
	},
	corantiship = {
		BaseSoundSelectType = "cor-shp-large-sel",
		BaseSoundMovementType = "cor-shp-large-ok",
		BaseSoundWeaponType = "radar-support",
	},
	corssub = {
		BaseSoundSelectType = "cor-sub-medium-sel",
		BaseSoundMovementType = "cor-sub-medium-ok",
		BaseSoundWeaponType = "torpedo-medium",
	},
	cordesolator = {
		BaseSoundSelectType = "cor-sub-medium-sel",
		BaseSoundMovementType = "cor-sub-medium-ok",
		BaseSoundWeaponType = "nuke",
	},
	cormship = {
		BaseSoundSelectType = "cor-shp-large-sel",
		BaseSoundMovementType = "cor-shp-large-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	corbats = {
		BaseSoundSelectType = "cor-shp-large-sel",
		BaseSoundMovementType = "cor-shp-large-ok",
		BaseSoundWeaponType = "plasma-large",
	},
	corblackhy = {
		BaseSoundSelectType = "cor-shp-huge-sel",
		BaseSoundMovementType = "cor-shp-huge-ok",
		BaseSoundWeaponType = "plasma-huge",
	},

	-- CORTEX AIRCRAFT

	corfink = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "radar",
	},
	corbw = {
		BaseSoundSelectType = "cor-air-tiny-sel",
		BaseSoundMovementType = "cor-air-tiny-ok",
		BaseSoundWeaponType = "emp-laser",
	},
	corvalk = {
		BaseSoundSelectType = "arm-air-transport-small-sel",
		BaseSoundMovementType = "arm-air-transport-small-ok",
		BaseSoundWeaponType = "transport-large",
	},
	corhvytrans = {
		BaseSoundSelectType = "arm-air-transport-small-sel",
		BaseSoundMovementType = "arm-air-transport-small-ok",
		BaseSoundWeaponType = "transport-large",
	},
	corveng = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "aarocket-air",
	},
	corsfig = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "aarocket-air",
	},
	corca = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	corassistdrone = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	corhunt = {
		BaseSoundSelectType = "arm-air-gunship-alt-sel",
		BaseSoundMovementType = "arm-air-gunship-alt-ok",
		BaseSoundWeaponType = "radar",
	},
	corkam = {
		BaseSoundSelectType = "arm-air-gunship-alt-sel",
		BaseSoundMovementType = "arm-air-gunship-alt-ok",
		BaseSoundWeaponType = "fastemg-small",
	},
	corshad = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-small",
	},
	corcsa = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	corcut = {
		BaseSoundSelectType = "arm-air-gunship-sel",
		BaseSoundMovementType = "arm-air-gunship-ok",
		BaseSoundWeaponType = "laser-medium",
	},
	corsb = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-small",
	},
	corseap = {
		BaseSoundSelectType = "arm-air-gunship-sel",
		BaseSoundMovementType = "arm-air-gunship-ok",
		BaseSoundWeaponType = "air-bomb-small-torp",
	},
	corvamp = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "aarocket-air",
	},
	corawac = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "radar",
	},
	corhurc = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-large",
	},
	coraca = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	corape = {
		BaseSoundSelectType = "arm-air-medium-sel",
		BaseSoundMovementType = "arm-air-medium-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	corseah = {
		BaseSoundSelectType = "arm-air-transport-large-sel",
		BaseSoundMovementType = "arm-air-transport-large-ok",
		BaseSoundWeaponType = "transport-large",
	},
	cortitan = {
		BaseSoundSelectType = "arm-air-bomber-sel",
		BaseSoundMovementType = "arm-air-bomber-ok",
		BaseSoundWeaponType = "air-bomb-large-torp",
	},
	corcrw = {
		BaseSoundSelectType = "cor-air-gunship-large-sel",
		BaseSoundMovementType = "cor-air-gunship-large-ok",
		BaseSoundWeaponType = "laser-large",
	},
	corcrwh = {
		BaseSoundSelectType = "cor-air-gunship-large-sel",
		BaseSoundMovementType = "cor-air-gunship-large-ok",
		BaseSoundWeaponType = "laser-large",
	},

	-- LEGION COMMANDER

	legdecom = {
		BaseSoundSelectType = { "leg-com-sel-1", "leg-com-sel-2", "leg-com-sel-3", },
		BaseSoundMovementType = { "leg-com-ok-1", "leg-com-ok-2", },
		BaseSoundWeaponType = "fastemg-small",
	},
	legdecomlvl3 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "fastemg-small",
	},
	legdecomlvl6 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "fastemg-small",
	},
	legdecomlvl10 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "fastemg-small",
	},
	legcom = {
		BaseSoundSelectType = { "leg-com-sel-1", "leg-com-sel-2", "leg-com-sel-3", },
		BaseSoundMovementType = { "leg-com-ok-1", "leg-com-ok-2", },
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
	legcomlvl5 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "fastemg-small",
	},
	legcomlvl6 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "fastemg-small",
	},
	legcomlvl7 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "fastemg-small",
	},
	legcomlvl8 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "fastemg-small",
	},
	legcomlvl9 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "fastemg-small",
	},
	legcomlvl10 = {
		BaseSoundSelectType = "cor-com-sel",
		BaseSoundMovementType = { "cor-com-ok-1", "cor-com-ok-2", "cor-com-ok-3", "cor-com-ok-4", },
		BaseSoundWeaponType = "fastemg-small",
	},

	-- LEGION T1 BUILDINGS

	legdrag = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall",
	},
	legdtf = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "flame-alt",
	},
	legdtl = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "lightning",
	},
	legdtm = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "rocketalt-large",
	},

	legeyes = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "cloak",
	},

	legnanotc = {
		BaseSoundSelectType = "arm-bld-select-small",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-small",
	},

	legnanotcbase = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-medium",
	},

	legnanotct2 = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-medium",
	},

	legnanotcplat = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-small",
	},

	legnanotct2plat = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "conalt-medium",
	},

	legwin = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-windgen",
	},
	legfmkr = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker",
        BaseSoundActivate = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},
	legfdrag = {
		BaseSoundSelectType = "arm-bld-select",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall-water",
	},

	legtide = {
		BaseSoundSelectType = "arm-bld-select-small-water",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrghum",
	},

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
	leghive = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-repairpad",
	},
	legfdefcarryt1 = {
		BaseSoundSelectType = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-repairpad",
	},
	legmg = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "fastemg-medium",
	},
	legtl = {
		BaseSoundSelectType = "arm-bld-defense-action-water-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "torpedo-small",
	},
	legrhapsis = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		BaseSoundWeaponType = "aarocket-medium",
	},
	leglupara = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		BaseSoundWeaponType = "aarocket-medium-flak",
	},
	legrad = {
		BaseSoundSelectType = "arm-bld-select-small",
		BaseSoundWeaponType = "arm-bld-radar",
        BaseSoundActivate   = "cmd-on",
        BaseSoundDeactivate = "cmd-off",
	},
	legjam = {
		BaseSoundSelectType = "arm-bld-select-small",
		BaseSoundWeaponType = "jammer",
	},
	legcluster = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		BaseSoundWeaponType = "arty-medium",
	},
	legdtr = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "plasma-small",
	},
	leglht = {
		BaseSoundSelectType = "arm-bld-defense-action-t1",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "heatray",
	},
	legmstor = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-metal",
	},
	legestor = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage",
	},
	legeconv = {
		BaseSoundSelectType = "arm-bld-metal",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-metalmaker",
        BaseSoundActivate = "arm-bld-mm-activate",
        BaseSoundDeactivate = "arm-bld-mm-deactivate",
	},
	leggeo = {
		BaseSoundSelectType = "arm-bld-select-medium",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-geo",
	},
	legageo = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-geo-t2-explo",
	},
	legrampart = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "nuke-anti",
	},
	legabm = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "nuke-anti",
	},


	-- LEGION T2 BUILDINGS

	legstarfall = {
		BaseSoundSelectType = "lrpc",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-lolcannon",
	},

	legperdition = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "rocketalt-large",
	},
	legbombard = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "plasma-large-alt",
	},

	legbastion = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "laser-large",
	},
	legflak = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-medium-flak",
	},
	leglrpc = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		BaseSoundWeaponType = "lrpc",
	},
	legacluster = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		BaseSoundWeaponType = "arty-large",
	},
	legamstor = {
		BaseSoundSelectType = "arm-bld-metal-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-storage-metal",
	},
	leglraa = {
		BaseSoundSelectType = "arm-bld-defense-action-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "aarocket-large",
	},

	legrwall = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "sniper",
	},

	legforti = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-wall-t2",
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
	legamsub = {
		BaseSoundSelectType   = "arm-bld-factory-t2",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType   = "arm-bld-factory-t2-uw",
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
	leghp = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-factory-hover",
	},
	legfhp = {
		BaseSoundSelectType = "arm-bld-factory",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-factory-hover-water",
	},


	legsolar = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-solar-alt",
		BaseSoundActivate   = "arm-bld-solar-activate",
		BaseSoundDeactivate = "arm-bld-solar-deactivate",
	},
	legadvsol = {
		BaseSoundSelectType = "arm-bld-nrghum",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-solar-alt-adv",
	},

	-- LEGION T1 BOTS
	legck = {
		BaseSoundSelectType = "leg-bot-con-sel",
		BaseSoundMovementType = "leg-bot-con-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	leggob = {
		BaseSoundSelectType = "leg-bot-tiny-sel",
		BaseSoundMovementType = "leg-bot-tiny-ok",
		BaseSoundWeaponType = "fastemgalt-small",
	},
	leglob = {
		BaseSoundSelectType = "leg-bot-small-sel",
		BaseSoundMovementType = "leg-bot-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	legcen = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "plasma-medium",
	},
	legbal = {
		BaseSoundSelectType = "leg-bot-medium-sel",
		BaseSoundMovementType = "leg-bot-medium-ok",
		BaseSoundWeaponType = "rocketalt-small",
	},
	legkark = {
		BaseSoundSelectType = "leg-bot-medium-sel",
		BaseSoundMovementType = "leg-bot-medium-ok",
		BaseSoundWeaponType = "heatray",
	},

	-- LEGION T2 BOTS
	legack = {
		BaseSoundSelectType = "leg-bot-medium-sel",
		BaseSoundMovementType = "leg-bot-medium-ok",
		BaseSoundWeaponType = "conalt-medium",
	},
	leginfestor = {
		BaseSoundSelectType = "cor-bot-at-sel",
		BaseSoundMovementType = "cor-bot-at-ok",
		BaseSoundWeaponType = "heatray",
	},
	legaceb = {
		BaseSoundSelectType = "leg-bot-aceb-sel",
		BaseSoundMovementType = "leg-bot-aceb-ok",
		BaseSoundWeaponType = "con-assist",
	},
	leginc = {
		BaseSoundSelectType = "leg-bot-medium-sel",
		BaseSoundMovementType = "leg-bot-medium-ok",
		BaseSoundWeaponType = "flame-alt",
	},
	legstr = {
		BaseSoundSelectType = "leg-bot-medium-sel",
		BaseSoundMovementType = "leg-bot-medium-ok",
		BaseSoundWeaponType = "fastemg-medium",
	},
	legbart = {
		BaseSoundSelectType = "leg-bot-medium-sel",
		BaseSoundMovementType = "leg-bot-medium-ok",
		BaseSoundWeaponType = "flame-alt",
	},
	legsrail = {
		BaseSoundSelectType = "cor-bot-t3-at-sel",
		BaseSoundMovementType = "cor-bot-t3-at-ok",
		BaseSoundWeaponType = "sniper",
	},
	legsrailt4 = {
		BaseSoundSelectType = "cor-bot-t3-at-sel",
		BaseSoundMovementType = "cor-bot-t3-at-ok",
		BaseSoundWeaponType = "sniper",
	},
	legshot = {
		BaseSoundSelectType = "cor-bot-large-sel",
		BaseSoundMovementType = "cor-bot-large-ok",
		BaseSoundWeaponType = "plasma-large",
	},
	legsnapper = {
		BaseSoundSelectType = "cor-bot-tiny-sel",
		BaseSoundMovementType = "cor-bot-tiny-ok",
		BaseSoundWeaponType = "bomb",
	},
	leghrk = {
		BaseSoundSelectType = "leg-bot-medium-sel",
		BaseSoundMovementType = "leg-bot-medium-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	legaspy = {
		BaseSoundSelectType = "cor-bot-small-sel",
		BaseSoundMovementType = "cor-bot-small-ok",
		BaseSoundWeaponType = "cloak",
	},
	legajamk = {
		BaseSoundSelectType = "leg-bot-small-sel",
		BaseSoundMovementType = "leg-bot-small-ok",
		BaseSoundWeaponType = "jammer",
	},
	legaradk = {
		BaseSoundSelectType = "leg-bot-small-sel",
		BaseSoundMovementType = "leg-bot-small-ok",
		BaseSoundWeaponType = "radar-t2",
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
	legehovertank = {
		BaseSoundSelectType = "cor-hov-large-sel",
		BaseSoundMovementType = "cor-hov-large-ok",
		BaseSoundWeaponType = "laser-large",
	},
	leggobt3 = {
		BaseSoundSelectType = "cor-bot-huge-sel",
		BaseSoundMovementType = "cor-bot-large-ok",
		BaseSoundWeaponType = "plasma-large",
	},
	legjav = {
		BaseSoundSelectType = "arm-bot-huge-sel",
		BaseSoundMovementType = "arm-bot-huge-ok",
		BaseSoundWeaponType = "fastemg-medium",
	},
	legbunk = {
		BaseSoundSelectType = "arm-bot-huge-sel",
		BaseSoundMovementType = "arm-bot-huge-ok",
		BaseSoundWeaponType = "plasma-large",
	},

	-- LEGION T1 VEHICLES
	legcv = {
		BaseSoundSelectType = "leg-veh-small-sel",
		BaseSoundMovementType = "leg-veh-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	legotter = {
		BaseSoundSelectType = "cor-tnk-small-amph-sel",
		BaseSoundMovementType = "cor-tnk-small-amph-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	leghelios = {
		BaseSoundSelectType = "leg-veh-small-sel",
		BaseSoundMovementType = "leg-veh-small-ok",
		BaseSoundWeaponType = "helios-weapon-type",
	},
	leghades = {
		BaseSoundSelectType = "leg-veh-tiny-sel",
		BaseSoundMovementType = "leg-veh-tiny-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	legbar = {
		BaseSoundSelectType = "leg-bar-medium-sel",
		BaseSoundMovementType = "leg-bar-medium-ok",
		BaseSoundWeaponType = "flame-alt",
	},
	legrail = {
		BaseSoundSelectType = "leg-rail-small-sel",
		BaseSoundMovementType = "leg-rail-small-ok",
		BaseSoundWeaponType = "lance-weapon-type",
	},
	legerailtank = {
		BaseSoundSelectType = "cor-tnk-huge-sel",
		BaseSoundMovementType = "cor-tnk-huge-ok",
		BaseSoundWeaponType = "lance-weapon-type",
	},
	leggat = {
		BaseSoundSelectType = "leg-veh-small-sel",
		BaseSoundMovementType = "leg-veh-small-ok",
		BaseSoundWeaponType = "fastemg-medium",
	},
	legmlv = {
		BaseSoundSelectType = "leg-veh-tiny-sel",
		BaseSoundMovementType = "leg-veh-tiny-ok",
		BaseSoundWeaponType = "mine-small",
	},
	legscout = {
		BaseSoundSelectType = "leg-veh-tiny-sel",
		BaseSoundMovementType = "leg-veh-tiny-ok",
		BaseSoundWeaponType = "fastemg-small",
	},
	legamphtank = {
		BaseSoundSelectType = "arm-tnk-small-amph-sel",
		BaseSoundMovementType = "arm-tnk-small-amph-ok",
		BaseSoundWeaponType = "plasma-small",
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
	legmed = {
		BaseSoundSelectType = "cor-tnk-large-sel",
		BaseSoundMovementType = "cor-tnk-large-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	legavroc = {
		BaseSoundSelectType = "cor-tnk-medium-sel",
		BaseSoundMovementType = "cor-tnk-medium-ok",
		BaseSoundWeaponType = "rocketalt-large",
	},
	legaheattank = {
		BaseSoundSelectType = "cor-tnk-large-sel",
		BaseSoundMovementType = "cor-tnk-large-ok",
		BaseSoundWeaponType = "heatray",
	},
	legamcluster = {
		BaseSoundSelectType = "cor-tnk-medium-sel",
		BaseSoundMovementType = "cor-tnk-medium-ok",
		BaseSoundWeaponType = "arty-large",
	},
	legvflak = {
		BaseSoundSelectType = "leg-veh-small-sel",
		BaseSoundMovementType = "leg-veh-small-ok",
		BaseSoundWeaponType = "flak",
	},
	legaskirmtank = {
		BaseSoundSelectType = "cor-tnk-medium-sel",
		BaseSoundMovementType = "cor-tnk-medium-ok",
		BaseSoundWeaponType = "plasma-medium-alt",
	},


	-- LEGION T3 UNITS

	legeheatraymech = {
		BaseSoundSelectType = "leg-t3u-mech-sel",
		BaseSoundMovementType = { "leg-t3u-mech-ok-1", "leg-t3u-mech-ok-2", },
		BaseSoundWeaponType = "heatray4burn",
	},
	legeshotgunmech = {

		BaseSoundSelectType = "arm-banth-sel",
		BaseSoundMovementType = "arm-bot-t3-ok",
		BaseSoundWeaponType = "plasma-large",
	},
	legelrpcmech = {

		BaseSoundSelectType = "arm-banth-sel",
		BaseSoundMovementType = "arm-bot-t3-ok",
		BaseSoundWeaponType = "lrpc",
	},
	legeallterrainmech = {
		BaseSoundSelectType = "cor-bot-t3-at-sel",
		BaseSoundMovementType = "cor-bot-t3-at-ok",
		BaseSoundWeaponType = "lrpc",
	},



	-- LEGION AIRCRAFT
	legca = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	legassistdrone = {
		BaseSoundSelectType = "arm-air-small-sel",
		BaseSoundMovementType = "arm-air-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	legatrans = {
		BaseSoundSelectType = "arm-air-transport-small-sel",
		BaseSoundMovementType = "arm-air-transport-small-ok",
		BaseSoundWeaponType = "transport-large",
	},
	leglts = {
		BaseSoundSelectType = "arm-air-transport-small-sel",
		BaseSoundMovementType = "arm-air-transport-small-ok",
		BaseSoundWeaponType = "transport-large",
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
	legdrone = {
		BaseSoundSelectType = "arm-air-gunship-alt-sel",
		BaseSoundMovementType = "arm-air-gunship-alt-ok",
		BaseSoundWeaponType = "fastemg-small",
	},
	legheavydrone = {
		BaseSoundSelectType = "arm-air-gunship-alt-sel",
		BaseSoundMovementType = "arm-air-gunship-alt-ok",
		BaseSoundWeaponType = "helios-weapon-type",
	},
	legmost3 = {
		BaseSoundSelectType = "cor-air-gunship-large-sel",
		BaseSoundMovementType = "cor-air-gunship-large-ok",
		BaseSoundWeaponType = "rocketalt-large",
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
	legfortt4 = {
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
	legafigdef = {
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
	legsilo = {
		BaseSoundSelectType = "arm-bld-defense-action-t3",
		BaseSoundWeaponType = "nuke",
	},
	legmoho = {
		BaseSoundSelectType = "arm-bld-select-large",
		BaseSoundWeaponType = "arm-bld-metal-t2",
        BaseSoundActivate   = "mohorun1",
        BaseSoundDeactivate = "mohooff1",
	},
	legmohobp = {
		BaseSoundSelectType = "arm-bld-select-large",
		BaseSoundWeaponType = "conalt-small",
        BaseSoundActivate   = "mohorun1",
        BaseSoundDeactivate = "mohooff1",
	},


	-- LEGION HOVERCRAFT

	legsh = {
		BaseSoundSelectType = "arm-hov-small-sel",
		BaseSoundMovementType = "arm-hov-small-ok",
		--BaseSoundMovementVol = 0.6,
		BaseSoundWeaponType = "laser-tiny",
	},
	legmh = {
		BaseSoundSelectType = "arm-hov-small-sel",
		BaseSoundMovementType = "arm-hov-small-ok",
		BaseSoundWeaponType = "rocket-small",
	},
	legch = {
		BaseSoundSelectType = "arm-hov-small-sel",
		BaseSoundMovementType = "arm-hov-small-ok",
		BaseSoundWeaponType = "conalt-small",
	},
	legah = {
		BaseSoundSelectType = "arm-hov-small-sel",
		BaseSoundMovementType = "arm-hov-small-ok",
		BaseSoundWeaponType = "aarocket-small",
	},
	legner = {
		BaseSoundSelectType = "arm-hov-small-sel",
		BaseSoundMovementType = "arm-hov-small-ok",
		BaseSoundWeaponType = "plasma-small",
	},
	legcar = {
		BaseSoundSelectType = "arm-hov-large-sel",
		BaseSoundMovementType = "arm-hov-large-ok",
		BaseSoundWeaponType = "fastemg-medium",
	},

	-- LEGION MINES

	legmine1 = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-small",
	},

	legmine2 = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-medium",
	},

	legmine3 = {
		BaseSoundSelectType = "arm-mine-sel",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "mine-large",
	},



	--Various Random Units

	freefusion = {
		BaseSoundSelectType = "arm-bld-select-large",
		--BaseSoundMovementType = "",
		BaseSoundWeaponType = "arm-bld-nrg-fusion-adv",
	},

	mission_command_tower = {
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
	corgolt4 = {
		BaseSoundSelectType = "cor-tnk-huge-sel",
		BaseSoundMovementType = "cor-tnk-huge-ok",
		BaseSoundWeaponType = "plasma-huge",
	},
	corthermite = {
		BaseSoundSelectType = "cor-bot-t3-at-sel",
		BaseSoundMovementType = "cor-bot-t3-at-ok",
		BaseSoundWeaponType = "heatray-xl",
	},


	armgplat = {},
	corgplat = {},
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
	armstone = {},
	corstone = {},
	legstone = {},
	resourcecheat = {},

	scavempspawner = {},
	scavtacnukespawner = {},
	lootdroppod_gold = {},
	lootdroppod_printer = {},
	scavbeacon_t1 = {},
	scavbeacon_t2 = {},
	scavbeacon_t3 = {},
	scavbeacon_t4 = {},
	scavengerdroppodfriendly = {},
	scavmist = {},
	scavmistxl = {},
	scavmistxxl = {},


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


	coruwgeo = corgeo,
	coruwageo = corageo,
	armuwgeo = armgeo,
	armuwageo = armageo,

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
