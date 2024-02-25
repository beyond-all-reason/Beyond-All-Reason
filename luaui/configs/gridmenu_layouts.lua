local labGrids = {
	-- T1 bot
	armada_botlab = {
		"armada_constructionbot", "armada_lazarus", "armada_pawn", "armada_tick",                -- T1 con, rez bot, peewee, flea
		"armada_rocketeer", "armada_mace", "armada_centurion", "",                     -- rocko, hammer, warrior
		"", "", "armada_crossbow",                                         -- aa bot
	},

	corlab = {
		"corck", "cornecro", "corak", "",                      -- T1 con, rez bot, AK
		"corstorm", "corthud", "", "",                        -- storm, thud
		"", "", "corcrash",                                        -- aa bot
	},
	leglab = {
		"legck", "cornecro", "leggob", "",                      -- T1 con, rez bot, AK
		"legbal", "leglob", "legkark", "legcen",                        -- storm, thud
		"", "", "corcrash",                                        -- aa bot
	},
	-- T2 bot
	armada_advancedbotlab = {
		"armada_advancedconstructionbot", "armada_butler", "armada_sprinter", "armada_ghost",             -- T2 con, fark, zipper, spy
		"armada_compass", "armada_radarjammerbot", "armada_welder", "armada_gunslinger",             -- radar bot, jammer bot, zeus, maverick
		"armada_hound", "armada_sharpshooter", "armada_archangel", "armada_fatboy",            -- fido, sniper, AA bot, fatboi
	},

	coralab = {
		"corack", "corfast", "corpyro", "corspy",               -- T2 con, freaker, pyro, spy
		"corvoyr", "corspec", "corcan", "corhrk",              -- radar bot, jammer bot, can, dominator
		"cormort", "corroach", "coraak", "corsumo",             -- morty, skuttle, AA bot, sumo
	},
	legalab = {
		"legack", "corfast", "legstr", "corspy",               -- T2 con, freaker, strider, spy
		"corvoyr", "corspec", "leginfestor", "legsrail",              -- radar bot, jammer bot, infestor, dominator
		"legbart", "corroach", "legshot", "leginc",             -- belcher, skuttle, shotgun, sumo
	},
	-- T1 vehicle
	armada_vehicleplant = {
		"armada_constructionvehicle", "armada_groundhog", "armada_blitz", "armada_rover",        -- T1 con, minelayer, flash, scout
		"armada_stout", "armada_janus", "armada_shellshocker", "",          -- stumpy, janus, arty
		"armada_beaver", "armada_pincer", "armada_whistler", "",        -- amphib con, amphib tank, missile truck
	},

	corvp = {
		"corcv", "cormlv", "corgator", "corfav",       -- T1 con, minelayer, gator, scout
		"corraid", "corlevlr", "corwolv", "",         -- raider, leveler, art
		"cormuskrat", "corgarp", "cormist", "",       -- amphib con, amphib tank, missile truck
	},
	legvp = {
		"legcv", "", "leghades", "corfav",       -- T1 con, minelayer, gator, scout
		"leggat", "leghelios", "legbar", "",         -- raider, leveler, art
		"", "", "legrail", "",       -- amphib con, amphib tank, missile truck
	},
	-- T2 vehicle
	armada_advancedvehicleplant = {
		"armada_advancedconstructionvehicle", "armada_consul", "armada_bull", "armada_mauser",           -- T2 con, consul, bulldog, luger
		"armada_prophet", "armada_umbra", "armada_starlight", "armst",              -- radar, jammer, penetrator, gremlin
		"armada_jaguar", "armada_turtle", "armada_shredder", "armada_ambassador",           -- panther, triton, AA, merl
	},

	coravp = {
		"coracv", "corban", "correap", "cormart",              -- T2 con, banisher, reaper, pillager
		"corvrad", "coreter", "corgol", "cortrem",             -- radar, jammer, goli, tremor
		"corseal", "corparrow", "corsent", "corvroc",          -- croc, poison arrow, AA, diplomat
	},
	legavp = {
		"legacv", "legmrv", "legsco", "cormart",              -- T2 con, Quickshot, scorpion, pillager
		"corvrad", "coreter", "corgol", "leginf",             -- radar, jammer, goli, inferno
		"legfloat", "corban", "corsent", "corvroc",           -- croc, poison arrow, AA, diplomat
	},
	-- T1 air
	armada_aircraftplant = {
		"armada_constructionaircraft", "armada_falcon", "armada_banshee", "armada_stormbringer",           -- T1 con, fig, gunship, bomber
		"armada_blink", "armada_stork",                             -- radar, transport,
	},
	corap = {
		"corca", "corveng", "corbw", "corshad",              -- T1 con, fig, drone, bomber
		"corfink", "corvalk",                                -- radar, transport
	},
    legap = {
		"legca", "legfig", "legmos", "legkam",              -- T1 con, fig, drone, bomber
		"legcib", "corvalk",                                -- radar, transport
	},
	-- T2 air
	armada_advancedaircraftplant = {
		"armada_advancedconstructionaircraft", "armada_highwind", "armada_roughneck", "armada_blizzard",           -- T2 con, fig, gunship, bomber
		"armada_oracle", "armada_abductor", "armada_cormorant", "armada_cyclone2",                -- radar, transport, torpedo, heavy fighter (mod)
		"armada_liche", "armada_hornet", "armada_stiletto",                    -- liche, blade, stiletto
	},

	coraap = {
		"coraca", "corvamp", "corape", "corhurc",              -- T2 con, fig, gunship, bomber
		"corawac", "corseah", "cortitan", "corsfig2",                 -- radar, transport, torpedo, heavy fighter (mod)
		"corcrw","corcrwh",                                              -- krow
	},
	legaap = {
	"legaca","legionnaire","legvenator","",					--T2 con, defensive fig, interceptor
	"legmineb","legnap","legphoenix","cortitan",			--minebomber, napalmbomber, 'heavy bomber', torpedo
	"legfort","legstronghold","legwhisper",	""			--knockoff krow, (well armed)transport, radar
	},
	-- seaplanes
	armada_seaplaneplatform = {
		"armada_constructionseaplane", "armada_cyclone", "armada_sabre", "armada_tsunami",           -- seaplane con, fig, gunship, bomber
		"armada_horizon", "armada_puffin",                              -- radar, torpedo
	},

	corplat = {
		"corcsa", "corsfig", "corcut", "corsb",              -- seaplane con, fig, gunship, bomber
		"corhunt", "corseap",                                -- radar, torpedo
	},
	-- T1 boats
	armada_shipyard = {
		"armada_constructionship", "armada_grimreaper", "armada_dolphin", "",              -- T1 sea con, rez sub, decade
		"armada_ellysaw", "armada_corsair", "", "",                    -- frigate, destroyer, transport ("armada_convoy",)
		"armada_eel", "", "armada_skater",                            -- sub, PT boat
	},

	corsy = {
		"corcs", "correcl", "coresupp", "",               -- T1 sea con, rez sub, supporter, missile boat
		"corpship", "corroy", "", "",                    -- frigate, destroyer, transport ("cortship",)
		"corsub", "", "corpt",                            -- sub, missile boat
	},
	-- T2 boats
	armada_advancedshipyard = {
		"armada_advancedconstructionsub", "armada_voyager", "armada_paladin", "armada_longbow",         -- T2 con sub, naval engineer, cruiser, rocket ship
		"armada_haven", "armada_bermuda", "armada_dreadnought", "armada_epoch",        -- carrier, jammer, battleship, flagship
		"armada_barracuda", "armada_serpent", "armada_dragonslayer",                      -- sub killer, battlesub, AA
	},

	corasy = {
		"coracsub", "cormls", "corcrus", "cormship",              -- T2 con sub, naval engineer, cruiser, rocket ship
		"corcarry", "corsjam", "corbats", "corblackhy",            -- carrier, jammer, battleship, flagship
		"corshark", "corssub", "corarch",                          -- sub killer, battlesub, AA
	},
	-- amphibious labs
	armada_amphibiouscomplex = {
		"armada_beaver", "armada_decoycommander", "armada_pincer", "",
		"armada_turtle", "", "", "",
		"", "armada_crossbow", "armada_archangel",
	},

	coramsub = {
		"cormuskrat", "cortex_decoycommander", "corgarp", "",
		"corseal", "corparrow", "", "",
		"", "corcrash", "coraak",
	},
	-- hover labs
	armada_hovercraftplatform = {
		"armada_constructionhovercraft", "", "armada_seeker", "",
		"armada_crocodile", "armada_possum", "", "",
		"", "", "armada_sweeper",
	},

	corhp = {
		"corch", "", "corsh", "",
		"corsnap", "cormh", "corhal", "",
		"", "", "corah",
	},
	armada_navalhovercraftplatform = {
		"armada_constructionhovercraft", "", "armada_seeker", "",
		"armada_crocodile", "armada_possum", "", "",
		"", "", "armada_sweeper",
	},

	corfhp = {
		"corch", "", "corsh", "",
		"corsnap", "cormh", "corhal", "",
		"", "", "corah",
	},

	-- T3 labs
	armada_experimentalgantry = {
		"armada_marauder", "armada_razorback", "armada_vanguard", "armada_thor",
		"armada_titan", "armada_lunkhead"
	},

	corgant = {
		"corcat", "corkarg", "corshiva", "corkorg",
		"corjugg", "corsok"
	},
	leggant = {
		"corcat", "corkarg", "corshiva", "corkorg",
		"corjugg", "corsok", "legpede", "leegmech",
		"legkeres","",""
	}
}
local unitGrids = {
	-- Air assist drones
	armassistdrone = {
		{
			{ "armada_metalextractor", "armada_solarcollector", "armada_windturbine", },              -- mex, solar, wind
			{ "armada_energyconverter", "", "armada_navalmetalstorage", "armada_tidalgenerator"},             -- T1 converter, uw m storage, tidal
			{ "armada_energystorage", "armada_metalstorage", "armada_navalenergystorage", "armada_navalenergyconverter", }, -- e storage, m storage, uw e storage, floating converter
		},
		{
			{ "armada_sentry", "armada_harpoon", },                          -- LLT, offshore torp launcher
			{ "armada_nettle", "armada_navalnettle", },                          -- basic AA, floating AA
			{ "armada_anemone", },                                    -- coastal torp launcher
		},
		{
			{ "armada_radartower", "armada_beholder", "armada_dragonsteeth", },             -- radar, perimeter camera, dragon's teeth
			{ "armada_navalradar", "armada_sharksteeth", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "armada_botlab", "armada_vehicleplant", "armada_aircraftplant", "armada_shipyard", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "armada_hovercraftplatform", "armada_navalhovercraftplatform", },                          -- hover lab, floating hover lab
		}
	},

	corassistdrone = {
		{
			{ "cormex", "corsolar", "corwin", },                -- mex, solar, wind
			{ "cormakr", "", "coruwms", "cortide"},             -- T1 converter, uw m storage, tidal
			{ "corestor", "cormstor", "coruwes", "corfmkr",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "corllt", "cortl", },                          -- LLT, offshore torp launcher
			{ "corrl", "corfrt", },                          -- basic AA, floating AA
			{ "cordl", },                                    -- coastal torp launcher
		},
		{
			{ "corrad", "coreyes", "cordrag", },             -- radar, perimeter camera, dragon's teeth
			{ "corfrad", "corfdrag", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "corhp", "corfhp", },                          -- hover lab, floating hover lab
		}
	},
	legassistdrone = {
		{
			{ "legmex", "corsolar", "corwin", },                -- mex, solar, wind
			{ "cormakr", "", "coruwms", "cortide"},             -- T1.5 mex, uw m storage, tidal
			{ "corestor", "cormstor", "coruwes", "corfmkr",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "corllt", "cortl", },                          -- LLT, offshore torp launcher
			{ "corrl", "corfrt", },                          -- basic AA, floating AA
			{ "cordl", },                                    -- coastal torp launcher
		},
		{
			{ "corrad", "coreyes", "cordrag", },             -- radar, perimeter camera, dragon's teeth
			{ "corfrad", "corfdrag", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "corhp", "corfhp", },                          -- hover lab, floating hover lab
		}
	},
	-- Land assist drones (mini amphibs)
	armassistdrone_land = {
		{
			{ "armada_metalextractor", "armada_solarcollector", "armada_windturbine", },               -- mex, solar, wind
			{ "armada_energyconverter", "", "armada_navalmetalstorage", "armada_tidalgenerator"},            -- T1 converter, uw m storage, tidal
			{ "armada_energystorage", "armada_metalstorage", "armada_navalenergystorage", "armada_navalenergyconverter", }, -- e storage, m storage, uw e storage, floating converter
		},
		{
			{ "armada_sentry", "armada_harpoon", },                          -- LLT, offshore torp launcher
			{ "armada_nettle", "armada_navalnettle", },                          -- basic AA, floating AA
			{ "armada_anemone", },                                    -- coastal torp launcher
		},
		{
			{ "armada_radartower", "armada_beholder", "armada_dragonsteeth", },             -- radar, perimeter camera, dragon's teeth
			{ "armada_navalradar", "armada_sharksteeth", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "armada_botlab", "armada_vehicleplant", "armada_aircraftplant", "armada_shipyard", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "armada_hovercraftplatform", "armada_navalhovercraftplatform", },                          -- hover lab, floating hover lab
		}
	},

	corassistdrone_land = {
		{
			{ "cormex", "corsolar", "corwin", },                -- mex, solar, wind
			{ "cormakr", "", "coruwms", "cortide"},             -- T1 converter, uw m storage, tidal
			{ "corestor", "cormstor", "coruwes", "corfmkr",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "corllt", "cortl", },                          -- LLT, offshore torp launcher
			{ "corrl", "corfrt", },                          -- basic AA, floating AA
			{ "cordl", },                                    -- coastal torp launcher
		},
		{
			{ "corrad", "coreyes", "cordrag", },             -- radar, perimeter camera, dragon's teeth
			{ "corfrad", "corfdrag", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "corhp", "corfhp", },                          -- hover lab, floating hover lab
		}
	},
	legassistdrone_land = {
		{
			{ "legmex", "corsolar", "corwin", },                -- mex, solar, wind
			{ "cormakr", "", "coruwms", "cortide"},             -- T1.5 mex, uw m storage, tidal
			{ "corestor", "cormstor", "coruwes", "corfmkr",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "corllt", "cortl", },                          -- LLT, offshore torp launcher
			{ "corrl", "corfrt", },                          -- basic AA, floating AA
			{ "cordl", },                                    -- coastal torp launcher
		},
		{
			{ "corrad", "coreyes", "cordrag", },             -- radar, perimeter camera, dragon's teeth
			{ "corfrad", "corfdrag", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "corhp", "corfhp", },                          -- hover lab, floating hover lab
		}
	},
	-- Commanders
	armada_commander = {
		{
			{ "armada_metalextractor", "armada_solarcollector", "armada_windturbine", },              -- mex, solar, wind
			{ "armada_energyconverter", "", "armada_navalmetalstorage", "armada_tidalgenerator"},           -- T1 converter, uw m storage, tidal
			{ "armada_energystorage", "armada_metalstorage", "armada_navalenergystorage", "armada_navalenergyconverter", }, -- e storage, m storage, uw e storage, floating converter
		},
		{
			{ "armada_sentry", "armada_harpoon", },                          -- LLT, offshore torp launcher
			{ "armada_nettle", "armada_navalnettle", },                          -- basic AA, floating AA
			{ "armada_anemone", },                                    -- coastal torp launcher
		},
		{
			{ "armada_radartower", "armada_beholder", "armada_dragonsteeth", },             -- radar, perimeter camera, dragon's teeth
			{ "armada_navalradar", "armada_sharksteeth", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "armada_botlab", "armada_vehicleplant", "armada_aircraftplant", "armada_shipyard", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "armada_hovercraftplatform", "armada_navalhovercraftplatform", },                          -- hover lab, floating hover lab
		}
	},

	cortex_commander = {
		{
			{ "cormex", "corsolar", "corwin", },                -- mex, solar, wind
			{ "cormakr", "", "coruwms", "cortide"},             -- T1 converter, uw m storage, tidal
			{ "corestor", "cormstor", "coruwes", "corfmkr",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "corllt", "cortl", },                          -- LLT, offshore torp launcher
			{ "corrl", "corfrt", },                          -- basic AA, floating AA
			{ "cordl", },                                    -- coastal torp launcher
		},
		{
			{ "corrad", "coreyes", "cordrag", },             -- radar, perimeter camera, dragon's teeth
			{ "corfrad", "corfdrag", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "corhp", "corfhp", },                          -- hover lab, floating hover lab
		}
	},
	-- legion commanders
    legcom = {
		{
			{ "legmex", "corsolar", "corwin", },                -- mex, solar, wind
			{ "cormakr", "", "coruwms", "cortide"},             -- T1.5 mex, uw m storage, tidal
			{ "corestor", "cormstor", "coruwes", "corfmkr",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "corllt", "cortl", },                          -- LLT, offshore torp launcher
			{ "corrl", "corfrt", },                          -- basic AA, floating AA
			{ "cordl", },                                    -- coastal torp launcher
		},
		{
			{ "corrad", "coreyes", "cordrag", },             -- radar, perimeter camera, dragon's teeth
			{ "corfrad", "corfdrag", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "corhp", "corfhp", },                          -- hover lab, floating hover lab
		}
	},
	legcomlvl2 = {
		{
			{ "legmex", "corsolar", "corwin", },                -- mex, solar, wind
			{ "cormakr", "", "coruwms", "cortide"},             -- T1.5 mex, uw m storage, tidal
			{ "corestor", "cormstor", "coruwes", "corfmkr",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "corllt", "cortl", },                          -- LLT, offshore torp launcher
			{ "corrl", "corfrt", },                          -- basic AA, floating AA
			{ "cordl", },                                    -- coastal torp launcher
		},
		{
			{ "corrad", "coreyes", "cordrag", },             -- radar, perimeter camera, dragon's teeth
			{ "corfrad", "corfdrag", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "corhp", "corfhp", },                          -- hover lab, floating hover lab
		}
	},
	legcomlvl3 = {
		{
			{ "legmex", "corsolar", "corwin", },                -- mex, solar, wind
			{ "cormakr", "legmext15", "coruwms", "cortide", },  -- T1 converter, T1.5 mex, uw m storage, tidal
			{ "corestor", "cormstor", "coruwes", "corfmkr",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "corllt", "cortl", },                          -- LLT, offshore torp launcher
			{ "corrl", "corfrt", },                          -- basic AA, floating AA
			{ "cordl", },                                    -- coastal torp launcher
		},
		{
			{ "corrad", "coreyes", "cordrag", },             -- radar, perimeter camera, dragon's teeth
			{ "corfrad", "corfdrag", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "corhp", "corfhp", },                          -- hover lab, floating hover lab
		}
	},
	legcomlvl4 = {
		{
			{ "legmex", "corsolar", "corwin", },                -- mex, solar, wind
			{ "cormakr", "legmext15", "coruwms", "cortide", },  -- T1 converter, T1.5 mex, uw m storage, tidal
			{ "corestor", "cormstor", "coruwes", "corfmkr",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "corllt", "cortl", },                          -- LLT, offshore torp launcher
			{ "corrl", "corfrt", },                          -- basic AA, floating AA
			{ "cordl", },                                    -- coastal torp launcher
		},
		{
			{ "corrad", "coreyes", "cordrag", },             -- radar, perimeter camera, dragon's teeth
			{ "corfrad", "corfdrag", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "corhp", "corfhp", },                          -- hover lab, floating hover lab
		}
	},
	-- T1 bot con
	armada_constructionbot = {
		{
			{ "armada_metalextractor", "armada_solarcollector", "armada_windturbine", "armada_advancedsolarcollector", },  -- mex, solar, wind, adv. solar
			{ "armada_energyconverter", "armada_geothermalpowerplant", "armada_twilight", },               -- T1 converter, geo, twilight, (tidal)
			{ "armada_energystorage", "armada_metalstorage", },                       -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "armada_sentry", "armada_beamer", "armada_overwatch", "armada_dragonsclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armada_nettle", "armada_ferret", "armada_chainsaw", },              -- basic AA, ferret, chainsaw
			{ "armada_anemone", "armada_gauntlet", },                         -- coastal torp launcher, guardian
		},
		{
			{ "armada_radartower", "armada_beholder", "armada_dragonsteeth", "armada_sneakypete", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ },
			{ "armada_juno", },                                   -- juno
		},
		{
			{ "armada_botlab", "armada_vehicleplant", "armada_aircraftplant", "armada_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "armada_constructionturret", "armada_advancedbotlab", },                      -- nano, T2 lab
			{ "armada_hovercraftplatform", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	corck = {
		{
			{ "cormex", "corsolar", "corwin", "coradvsol", },   -- mex, solar, wind, adv. solar
			{ "cormakr", "corgeo", "corexp", },                 -- T1 converter, geo, exploiter, (tidal)
			{ "corestor", "cormstor", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "corllt", "corhllt", "corhlt", "cormaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", },                           -- coastal torp launcher, punisher
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ },
			{ "corjuno", },                                   -- juno
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "coralab", },                      -- nano, T2 lab
			{ "corhp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},
   legck = {
		{
			{ "legmex", "corsolar", "corwin", "coradvsol", },   -- mex, solar, wind, adv. solar
			{ "cormakr", "corgeo", "legmext15", },              -- T1 converter, geo, T1.5 legion mex, (tidal)
			{ "corestor", "cormstor", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "corllt", "legmg", "corhlt", "cormaw", },       -- LLT, machine gun, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", },                           -- coastal torp launcher, punisher
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ },
			{ "corjuno", },                                   -- juno
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "legalab", },                      -- nano, T2 lab
			{ "corhp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	-- T1 vehicle con
	armada_constructionvehicle = {
		{
			{ "armada_metalextractor", "armada_solarcollector", "armada_windturbine", "armada_advancedsolarcollector", },  -- mex, solar, wind, adv. solar
			{ "armada_energyconverter", "armada_geothermalpowerplant", "armada_twilight", },               -- T1 converter, geo, twilight, (tidal)
			{ "armada_energystorage", "armada_metalstorage", },                       -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "armada_sentry", "armada_beamer", "armada_overwatch", "armada_dragonsclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armada_nettle", "armada_ferret", "armada_chainsaw", },              -- basic AA, ferret, chainsaw
			{ "armada_anemone", "armada_gauntlet", },                         -- coastal torp launcher, guardian
		},
		{
			{ "armada_radartower", "armada_beholder", "armada_dragonsteeth", "armada_sneakypete", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ },
			{ "armada_juno", },                                   -- juno
		},
		{
			{ "armada_botlab", "armada_vehicleplant", "armada_aircraftplant", "armada_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "armada_constructionturret", "armada_advancedvehicleplant", },                       -- nano, T2 lab
			{ "armada_hovercraftplatform", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	corcv = {
		{
			{ "cormex", "corsolar", "corwin", "coradvsol", },   -- mex, solar, wind, adv. solar
			{ "cormakr", "corgeo", "corexp", },                 -- T1 converter, geo, exploiter, (tidal)
			{ "corestor", "cormstor", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "corllt", "corhllt", "corhlt", "cormaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", },                           -- coastal torp launcher, punisher
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ },
			{ "corjuno", },                                   -- juno
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "coravp", },                       -- nano, T2 lab
			{ "corhp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},
    legcv = {
		{
			{ "legmex", "corsolar", "corwin", "coradvsol", },   -- mex, solar, wind, adv. solar
			{ "cormakr", "corgeo", "legmext15", },              -- T1 converter, geo, T1.5 legion mex, (tidal)
			{ "corestor", "cormstor", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "corllt", "legmg", "corhlt", "cormaw", },     -- LLT, machine gun, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", },                           -- coastal torp launcher, punisher
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ },
			{ "corjuno", },                                   -- juno
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "coralab", },                      -- nano, T2 lab
			{ "corhp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},
	-- T1 air con
	armada_constructionaircraft = {
		{
			{ "armada_metalextractor", "armada_solarcollector", "armada_windturbine", "armada_advancedsolarcollector", },  -- mex, solar, wind, adv. solar
			{ "armada_energyconverter", "armada_geothermalpowerplant", "armada_twilight", },               -- T1 converter, geo, twilight, (tidal)
			{ "armada_energystorage", "armada_metalstorage", },                       -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "armada_sentry", "armada_beamer", "armada_overwatch", "armada_dragonsclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armada_nettle", "armada_ferret", "armada_chainsaw", },              -- basic AA, ferret, chainsaw
			{ "armada_anemone", "armada_gauntlet", },                         -- coastal torp launcher, guardian
		},
		{
			{ "armada_radartower", "armada_beholder", "armada_dragonsteeth", "armada_sneakypete", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "", "", "armasp", "armada_airrepairpad" },                  -- air repair pad, floating air repair pad
			{ "armada_juno", }									  -- juno
		},
		{
			{ "armada_botlab", "armada_vehicleplant", "armada_aircraftplant", "armada_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "armada_constructionturret", "armada_advancedaircraftplant", },                       -- nano, T2 lab
			{ "armada_hovercraftplatform", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	corca = {
		{
			{ "cormex", "corsolar", "corwin", "coradvsol", },   -- mex, solar, wind, adv. solar
			{ "cormakr", "corgeo", "corexp", },                 -- T1 converter, geo, exploiter, (tidal)
			{ "corestor", "cormstor", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "corllt", "corhllt", "corhlt", "cormaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", },                           -- coastal torp launcher, punisher
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "", "", "corasp", "corfasp" },                  -- air repair pad, floating air repair pad
			{ "corjuno", }									  -- juno
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "coraap", },                       -- nano, T2 lab
			{ "corhp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},
    legca = {
		{
			{ "legmex", "corsolar", "corwin", "coradvsol", },   -- mex, solar, wind, adv. solar
			{ "cormakr", "corgeo", "legmext15", },              -- T1 converter, geo, T1.5 legion mex, (tidal)
			{ "corestor", "cormstor", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "corllt", "legmg", "corhlt", "cormaw", },     -- LLT, machine gun, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", },                           -- coastal torp launcher, punisher
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ },
			{ "corjuno", },                                   -- juno
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "legaap", },                      -- nano, T2 lab
			{ "corhp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},
	-- T1 sea con
	armada_constructionship = {
		{
			{ "armada_metalextractor", "armada_tidalgenerator", },                         -- mex, tidal
			{ "armada_navalenergyconverter", "armada_geothermalpowerplant", },                         -- floating T1 converter, geo
			{ "armada_navalenergystorage", "armada_navalmetalstorage", },                        -- uw e stor, uw m stor
		},
		{
			{ "armada_harpoon", "armada_manta", "", "armada_dragonsclaw", },           -- offshore torp launcher, floating HLT
			{ "armada_navalnettle", },                                    -- floating AA
			{ "armada_anemone", "armada_gauntlet", },              			  -- coastal torp launcher, guardian, lightning turret
		},
		{
			{ "armada_navalradar", "armada_beholder","armada_sharksteeth", },             -- floating radar, perimeter camera, shark's teeth
			{ "", "armada_dragonsteeth", "armasp", "armada_airrepairpad"},                        	      -- dragon's teeth
		},
		{
			{ "armada_shipyard", "armada_vehicleplant", "armada_aircraftplant", "armada_botlab", },         -- shipyard, veh lab, air lab, bot lab
			{ "armada_constructionturretplat", "armada_advancedshipyard", },                   -- floating nano, T2 shipyard
			{ "armada_navalhovercraftplatform", "", "armada_amphibiouscomplex", "armada_seaplaneplatform", },         -- floating hover lab, amphibious lab, seaplane lab
		}
	},

	corcs = {
		{
			{ "cormex", "cortide", },                         -- mex, tidal
			{ "corfmkr", "corgeo", },                         -- floating T1 converter, geo
			{ "coruwes", "coruwms", },                        -- uw e stor, uw m stor
		},
		{
			{ "cortl", "corfhlt", "", "cormaw" },             -- offshore torp launcher, floating HLT
			{ "corfrt", },                                    -- floating AA
			{ "cordl", "corpun", },                 		  -- coastal torp launcher, punisher, flame turret
		},
		{
			{ "corfrad", "coreyes", "corfdrag", },            -- floating radar, perimeter camera, shark's teeth
			{ "", "cordrag", "corasp", "corfasp" },           -- dragon's teeth
		},
		{
			{ "corsy", "corvp", "corap", "corlab",  },        -- shipyard, vehicle lab, air lab, bot lab
			{ "cornanotcplat", "corasy", },                   -- floating nano, T2 shipyard
			{ "corfhp", "", "coramsub", "corplat",  },        -- floating hover, amphibious lab, seaplane lab
		}
	},

	-- Hover cons
	armada_constructionhovercraft = {
		{
			{ "armada_metalextractor", "armada_solarcollector", "armada_windturbine", "armada_advancedsolarcollector", },  -- mex, solar, wind, adv. solar
			{ "armada_energyconverter", "armada_geothermalpowerplant", "armada_twilight", "armada_tidalgenerator",  },   -- T1 converter, geo, twilight, (tidal)
			{ "armada_energystorage", "armada_metalstorage", "armada_navalenergystorage", "armada_navalenergyconverter", }, -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "armada_sentry", "armada_beamer", "armada_overwatch", "armada_dragonsclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armada_nettle", "armada_ferret", "armada_chainsaw", "armada_navalnettle",},     -- basic AA, ferret, chainsaw, floating AA
			{ "armada_anemone", "armada_gauntlet", "armada_harpoon", "armada_manta", },     -- coastal torp launcher, guardian, offshore torp launcher, floating HLT
		},
		{
			{ "armada_radartower", "armada_beholder", "armada_dragonsteeth", "armada_sneakypete", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "armada_navalradar", "armada_sharksteeth", },                       -- floating radar, shark's teeth
			{ "armada_juno", },                                   -- juno
		},
		{
			{ "armada_botlab", "armada_vehicleplant", "armada_aircraftplant", "armada_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "armada_constructionturret", "armada_advancedvehicleplant", "armada_constructionturretplat", "armada_advancedshipyard",  },    -- nano, T2 veh lab, floating nano, T2 shipyard
			{ "armada_hovercraftplatform", "armada_navalhovercraftplatform", "armada_amphibiouscomplex", "armada_seaplaneplatform", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	corch = {
		{
			{ "cormex", "corsolar", "corwin", "coradvsol", },   -- mex, solar, wind, adv. solar
			{ "cormakr", "corgeo", "corexp", "cortide", },      -- T1 converter, geo, exploiter, (tidal)
			{ "corestor", "cormstor", "coruwes", "corfmkr", },  -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "corllt", "corhllt", "corhlt", "cormaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", "cortl", "corfhlt", },       -- coastal torp launcher, punisher, offshore torp launcher, floating HLT
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "corfrad", "corfdrag", },                       -- floating radar, shark's teeth
			{ "corjuno", },                                   -- juno
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "coravp", "cornanotcplat", "corasy", },   -- nano, T2 veh lab, floating nano, T2 shipyard
			{ "corhp", "corfhp", "coramsub", "corplat", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		},
	},

	-- Seaplane cons
	armada_constructionseaplane = {
		{
			{ "armada_metalextractor", "armada_solarcollector", "armada_windturbine", "armada_advancedsolarcollector", },  -- mex, solar, wind, adv. solar
			{ "armada_energyconverter", "armada_geothermalpowerplant", "armada_twilight", "armada_tidalgenerator",  },   -- T1 converter, geo, twilight, (tidal)
			{ "armada_energystorage", "armada_metalstorage", "armada_navalenergystorage", "armada_navalenergyconverter", }, -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "armada_sentry", "armada_beamer", "armada_overwatch", "armada_dragonsclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armada_nettle", "armada_ferret", "armada_chainsaw", "armada_navalnettle",},     -- basic AA, ferret, chainsaw, floating AA
			{ "armada_anemone", "armada_gauntlet", "armada_harpoon", "armada_manta", },     -- coastal torp launcher, guardian, offshore torp launcher, floating HLT
		},
		{
			{ "armada_radartower", "armada_beholder", "armada_dragonsteeth", "armada_sneakypete", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "armada_navalradar", "armada_sharksteeth", "armasp", "armada_airrepairpad" },                       -- floating radar, shark's teeth
			{ "armada_juno", },                                   -- juno
		},
		{
			{ "armada_botlab", "armada_vehicleplant", "armada_aircraftplant", "armada_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "armada_constructionturret", "armada_constructionturretplat", },                -- nano, floating nano
			{ "armada_hovercraftplatform", "armada_navalhovercraftplatform", "armada_amphibiouscomplex", "armada_seaplaneplatform", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	corcsa = {
		{
			{ "cormex", "corsolar", "corwin", "coradvsol", },   -- mex, solar, wind, adv. solar
			{ "cormakr", "corgeo", "corexp", "cortide", },      -- T1 converter, geo, exploiter, (tidal)
			{ "corestor", "cormstor", "coruwes", "corfmkr", },  -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "corllt", "corhllt", "corhlt", "cormaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", "cortl", "corfhlt", },       -- coastal torp launcher, punisher, offshore torp launcher, floating HLT
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "corfrad", "corfdrag", "corasp", "corfasp" },                       -- floating radar, shark's teeth
			{ "corjuno", },                                   -- juno
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "cornanotcplat", },                -- nano, floating nano
			{ "corhp", "corfhp", "coramsub", "corplat", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	-- Amphibious vehicle cons
	armada_beaver = {
		{
			{ "armada_metalextractor", "armada_solarcollector", "armada_windturbine", "armada_advancedsolarcollector", },  -- mex, solar, wind, adv. solar
			{ "armada_energyconverter", "armada_geothermalpowerplant", "armada_twilight", "armada_tidalgenerator",  },   -- T1 converter, geo, twilight, (tidal)
			{ "armada_energystorage", "armada_metalstorage", "armada_navalenergystorage", "armada_navalenergyconverter", }, -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "armada_sentry", "armada_beamer", "armada_overwatch", "armada_dragonsclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armada_nettle", "armada_ferret", "armada_chainsaw", "armada_navalnettle",},     -- basic AA, ferret, chainsaw, floating AA
			{ "armada_anemone", "armada_gauntlet", "armada_harpoon2", "armada_manta", },     -- coastal torp launcher, guardian, offshore torp launcher, floating HLT
		},
		{
			{ "armada_radartower", "armada_beholder", "armada_dragonsteeth", "armada_sneakypete", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "armada_navalradar", "armada_sharksteeth", },                       -- floating radar, shark's teeth
			{ "armada_juno", },                                   -- juno
		},
		{
			{ "armada_botlab", "armada_vehicleplant", "armada_aircraftplant", "armada_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "armada_constructionturret", "armada_advancedvehicleplant", "armada_constructionturretplat", },      -- nano, T2 veh lab, floating nano
			{ "armada_hovercraftplatform", "armada_navalhovercraftplatform", "armada_amphibiouscomplex", "armada_seaplaneplatform", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	cormuskrat = {
		{
			{ "cormex", "corsolar", "corwin", "coradvsol", },   -- mex, solar, wind, adv. solar
			{ "cormakr", "corgeo", "corexp", "cortide", },      -- T1 converter, geo, exploiter, (tidal)
			{ "corestor", "cormstor", "coruwes", "corfmkr", },  -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "corllt", "corhllt", "corhlt", "cormaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", "corptl", "corfhlt", },       -- coastal torp launcher, punisher, offshore torp launcher, floating HLT
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "corfrad", "corfdrag", },                       -- floating radar, shark's teeth
			{ "corjuno", },                                   -- juno
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "coravp", "cornanotcplat", },      -- nano, T2 veh lab, floating nano
			{ "corhp", "corfhp", "coramsub", "corplat", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	--T2 bot cons
	armada_advancedconstructionbot = {
		{
			{ "armada_advancedmetalextractor", "armada_fusionreactor", "armada_advancedfusionreactor", "armada_prude", },             -- moho, fusion, afus, safe geo
			{ "armada_advancedenergyconverter", "armada_advancedgeothermalpowerplant", "armada_cloakablefusionreactor", "armada_shockwave" },                     -- T2 converter, T2 geo, cloaked fusion
			{ "armada_hardenedenergystorage", "armada_hardenedmetalstorage", },                           -- hardened energy storage, hardened metal storage
		},
		{
			{ "armada_pitbull", "armada_pulsar", "armada_rattlesnake", "armada_paralyzer", },        -- pop-up gauss, annihilator, pop-up artillery, EMP missile
			{ "armada_arbalest", "armada_mercury", "armada_citadel", },             -- flak, long-range AA, anti-nuke
			{ "armada_basilica", "armada_ragnarok", "armada_armageddon", },              -- LRPC, ICBM, lolcannon
		},
		{
			{ "armada_advancedradartower", "armada_pinpointer", "armada_fortificationwall", "armada_veil" },     -- adv radar, targeting facility, wall, adv jammer
			{ "armada_tracer", "armada_decoyfusionreactor", "armasp" },                     -- intrusion counter, decoy fusion, air repair pad
			{ "armada_keeper", },                                     -- shield
		},
		{
			{ "armada_botlab", },                                      -- T1 lab,
			{ "armada_experimentalgantry", "armada_advancedbotlab", },                         -- T3 lab, T2 lab
			{ },                                                --
		}
	},

	corack = {
		{
			{ "cormoho", "corfus", "corafus", },                -- moho, fusion, afus
			{ "cormmkr", "corageo", "cormexp", },               -- T2 converter, T2 geo, armed moho
			{ "coruwadves", "coruwadvms", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "corvipe", "cordoom", "cortoast", "cortron", },   -- pop-up gauss, DDM, pop-up artillery, tac nuke
			{ "corflak", "corscreamer", "corfmd", "corbhmth", }, -- flak, long-range AA, anti-nuke, cerberus
			{ "corint", "corbuzz", "corsilo", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "corarad", "cortarg", "corfort", "corshroud", },  -- adv radar, targeting facility, wall, adv jammer
			{ "corsd", "", "corasp" },                          -- intrusion counter, air repair pad
			{ "corgate", },                                     -- anti-nuke, shield
		},
		{
			{ "corlab", },                                      -- T1 lab,
			{ "corgant", "coralab", },                          -- T3 lab, T2 lab
			{ },                                                --
		}
	},

	legack = {
		{
			{ "cormoho", "corfus", "corafus", },                -- moho, fusion, afus
			{ "cormmkr", "corageo", "cormexp", },               -- T2 converter, T2 geo, armed moho
			{ "coruwadves", "coruwadvms", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "corvipe", "legbastion", "cortoast", "cortron", },   -- pop-up gauss, heavy defence, pop-up artillery, tac nuke
			{ "corflak", "corscreamer", "corfmd", "corbhmth", }, -- flak, long-range AA, anti-nuke, cerberus
			{ "corint", "legstarfall", "corsilo", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "corarad", "cortarg", "corfort", "corshroud", },  -- adv radar, targeting facility, wall, adv jammer
			{ "corsd", "", "corasp" },                          -- intrusion counter, air repair pad
			{ "corgate", },                                     -- anti-nuke, shield
		},
		{
			{ "leglab", },                                      -- T1 lab,
			{ "leggant", "legalab", },                          -- T3 lab, T2 lab
			{ },                                                --
		}
	},

	--T2 vehicle cons
	armada_advancedconstructionvehicle = {
		{
			{ "armada_advancedmetalextractor", "armada_fusionreactor", "armada_advancedfusionreactor", "armada_prude", },             -- moho, fusion, afus, safe geo
			{ "armada_advancedenergyconverter", "armada_advancedgeothermalpowerplant", "armada_cloakablefusionreactor", "armada_shockwave" },                     -- T2 converter, T2 geo, cloaked fusion
			{ "armada_hardenedenergystorage", "armada_hardenedmetalstorage", },                           -- hardened energy storage, hardened metal storage
		},
		{
			{ "armada_pitbull", "armada_pulsar", "armada_rattlesnake", "armada_paralyzer", },        -- pop-up gauss, annihilator, pop-up artillery, EMP missile
			{ "armada_arbalest", "armada_mercury", "armada_citadel", },             -- flak, long-range AA, anti-nuke
			{ "armada_basilica", "armada_ragnarok", "armada_armageddon", },              -- LRPC, ICBM, lolcannon
		},
		{
			{ "armada_advancedradartower", "armada_pinpointer", "armada_fortificationwall", "armada_veil",  },   -- adv radar, targeting facility, wall, adv jammer
			{ "armada_tracer", "armada_decoyfusionreactor", "armasp" },                     -- intrusion counter, decoy fusion, air repair pad
			{ "armada_keeper", },                                     -- shield
		},
		{
			{ "armada_vehicleplant", },                                       -- T1 lab,
			{ "armada_experimentalgantry", "armada_advancedvehicleplant", },                          -- T3 lab, T2 lab
			{ },                                                --
		}
	},

	coracv = {
		{
			{ "cormoho", "corfus", "corafus", },                -- moho, fusion, afus
			{ "cormmkr", "corageo", "cormexp", },               -- T2 converter, T2 geo, armed moho
			{ "coruwadves", "coruwadvms", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "corvipe", "cordoom", "cortoast", "cortron", },   -- pop-up gauss, DDM, pop-up artillery, tac nuke
			{ "corflak", "corscreamer", "corfmd", "corbhmth", }, -- flak, long-range AA, anti-nuke, cerberus
			{ "corint", "corbuzz", "corsilo", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "corarad", "cortarg", "corfort", "corshroud", },  -- adv radar, targeting facility, wall, adv jammer
			{ "corsd", "", "corasp" },                          -- intrusion counter, air repair pad
			{ "corgate", },                                     -- anti-nuke, shield
		},
		{
			{ "corvp", },                                       -- T1 lab,
			{ "corgant", "coravp", },                           -- T3 lab, T2 lab
			{ },                                                --
		}
	},

	legacv = {
		{
			{ "cormoho", "corfus", "corafus", },                -- moho, fusion, afus
			{ "cormmkr", "corageo", "cormexp", },               -- T2 converter, T2 geo, armed moho
			{ "coruwadves", "coruwadvms", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "corvipe", "legbastion", "cortoast", "cortron", },   -- pop-up gauss, heavy defence, pop-up artillery, tac nuke
			{ "corflak", "corscreamer", "corfmd", "corbhmth", }, -- flak, long-range AA, anti-nuke, cerberus
			{ "corint", "legstarfall", "corsilo", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "corarad", "cortarg", "corfort", "corshroud", },  -- adv radar, targeting facility, wall, adv jammer
			{ "corsd", "", "corasp" },                          -- intrusion counter, air repair pad
			{ "corgate", },                                     -- anti-nuke, shield
		},
		{
			{ "legvp", },                                       -- T1 lab,
			{ "leggant", "legavp", },                           -- T3 lab, T2 lab
			{ },                                                --
		}
	},

	--T2 air cons
	armada_advancedconstructionaircraft = {
		{
			{ "armada_advancedmetalextractor", "armada_fusionreactor", "armada_advancedfusionreactor", "armada_prude", },             -- moho, fusion, afus, safe geo
			{ "armada_advancedenergyconverter", "armada_advancedgeothermalpowerplant", "armada_cloakablefusionreactor", "armada_shockwave" },                     -- T2 converter, T2 geo, cloaked fusion
			{ "armada_hardenedenergystorage", "armada_hardenedmetalstorage", },                           -- hardened energy storage, hardened metal storage
		},
		{
			{ "armada_pitbull", "armada_pulsar", "armada_rattlesnake", "armada_paralyzer", },        -- pop-up gauss, annihilator, pop-up artillery, EMP missile
			{ "armada_arbalest", "armada_mercury", "armada_citadel", },             -- flak, long-range AA, anti-nuke
			{ "armada_basilica", "armada_ragnarok", "armada_armageddon", },              -- LRPC, ICBM, lolcannon
		},
		{
			{ "armada_advancedradartower", "armada_pinpointer", "armada_fortificationwall", "armada_veil",  },    -- adv radar, targeting facility, wall, adv jammer
			{ "armada_tracer", "armada_decoyfusionreactor", "armasp", "armada_airrepairpad" },           -- intrusion counter, decoy fusion, air repair pad, floating air repair pad
			{ "armada_keeper", },                                      -- shield
		},
		{
			{ "armada_aircraftplant", },                                       -- T1 lab,
			{ "armada_experimentalgantry", "armada_advancedaircraftplant", },                          -- T3 lab, T2 lab
			{ "armada_seaplaneplatform", },                                     -- seaplane lab (aircon only)
		}
	},

	coraca = {
		{
			{ "cormoho", "corfus", "corafus", },                -- moho, fusion, afus
			{ "cormmkr", "corageo", "cormexp","coruwageo", },               -- T2 converter, T2 geo, armed moho
			{ "coruwadves", "coruwadvms", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "corvipe", "cordoom", "cortoast", "cortron" },    -- pop-up gauss, DDM, pop-up artillery, tac nuke
			{ "corflak", "corscreamer", "corfmd", "corbhmth" }, -- flak, long-range AA, anti-nuke, cerberus
			{ "corint", "corbuzz", "corsilo" },                 -- LRPC, ICBM, lolcannon
		},
		{
			{ "corarad", "cortarg", "corfort", "corshroud" },   -- adv radar, targeting facility, wall, adv jammer
			{ "corsd", "", "corasp", "corfasp" },               -- intrusion counter, air repair pad, floating air repair pad
			{ "corgate", },                                     -- anti-nuke, shield
		},
		{
			{ "corap", },                                       -- T1 lab,
			{ "corgant", "coraap", },                           -- T3 lab, T2 lab
			{ "corplat", },                                     -- seaplane lab (aircon only)
		}
	},
	legaca = {
		{
			{ "cormoho", "corfus", "corafus", },                -- moho, fusion, afus
			{ "cormmkr", "corageo", "cormexp","coruwageo", },               -- T2 converter, T2 geo, armed moho
			{ "coruwadves", "coruwadvms", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "corvipe", "legbastion", "cortoast", "cortron", },   -- pop-up gauss, heavy defence, pop-up artillery, tac nuke
			{ "corflak", "corscreamer", "corfmd", "corbhmth", }, -- flak, long-range AA, anti-nuke, cerberus
			{ "corint", "legstarfall", "corsilo", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "corarad", "cortarg", "corfort", "corshroud", },  -- adv radar, targeting facility, wall, adv jammer
			{ "corsd", "", "corasp", "corfasp" },               -- intrusion counter, air repair pad, floating air repair pad
			{ "corgate", },                                     -- anti-nuke, shield
		},
		{
			{ "legap", },                                       -- T1 lab,
			{ "leggant", "legaap", },                           -- T3 lab, T2 lab
			{ "corplat", },                                     -- seaplane lab (aircon only)
		}
	},

	--T2 sub cons
	armada_advancedconstructionsub = {
		{
			{ "armada_navaladvancedmetalextractor", "armada_navalfusionreactor", },                       -- uw moho, uw fusion,
			{ "armada_navaladvancedenergyconverter", "armada_advancedgeothermalpowerplant" },                       -- floating T2 converter, adv geo powerplant
			{ "armada_hardenedenergystorage", "armada_hardenedmetalstorage", },                   -- uw e stor, uw metal stor
		},
		{
			{ "armada_moray", "armada_gorgon", },                        -- adv torp launcher, floating heavy platform
			{ "armada_navalarbalest", },                                   -- floating flak
			{ },                                               --
		},
		{
			{ "armada_advancedsonarstation", "armada_navalpinpointer" },                		   -- adv sonar, floating targeting facility
			{ "", "", "", "armada_airrepairpad" },                         -- Floating air repair pad
			{ },                                               --
		},
		{
			{ "armada_shipyard", },                                      -- T1 shipyard
			{ "armada_experimentalgantryuw", "armada_advancedshipyard", },                       -- amphibious gantry, T2 shipyard
			{ },                                               --
		}
	},

	coracsub = {
		{
			{ "coruwmme", "coruwfus", },                       -- uw moho, uw fusion,
			{ "coruwmmm", "coruwageo" },                       -- floating T2 converter, adv geo powerplant
			{ "coruwadves", "coruwadvms", },                   -- uw e stor, uw metal stor
		},
		{
			{ "coratl", "corfdoom", },                         -- adv torp launcher, floating heavy platform
			{ "corenaa", },                                    -- floating flak
			{ },                                               --
		},
		{
			{ "corason", "corfatf",  },                         -- adv sonar, floating targeting facility
			{ "", "", "", "corfasp" },                          -- Floating air repair pad
		},
		{
			{ "corsy", },                                      -- T1 shipyard
			{ "corgantuw", "corasy" },                         -- amphibious gantry, T2 shipyard
			{ },                                               --
		}
	},

	--minelayers
	armada_groundhog = {
		{
			{ }, --
			{ },            --
			{ },          --
		},
		{
			{ },                          --
			{ },                          --
			{ },                                    --
		},
		{
			{ "", "armada_beholder", "armada_dragonsteeth", },                  -- camera, dragon's teeth
			{ },                                        --
			{ "armada_lightmine", "armada_mediummine", "armada_heavymine", },    -- light mine, med mine, heavy mine
		},
		{
			{ },        --
			{ },                                             --
			{ },                          --
		}
	},

	cormlv = {
		{
			{ }, --
			{ },            --
			{ },          --
		},
		{
			{ },                          --
			{ },                          --
			{ },                                    --
		},
		{
			{ "", "coreyes", "cordrag", },                 -- camera, dragon's teeth
			{ },                                       --
			{ "cormine1", "cormine2", "cormine3", },   -- light mine, med mine, heavy mine
		},
		{
			{ },        --
			{ },                                             --
			{ },                          --
		}
	},

	--Decoy commanders
	armada_decoycommander = {
		{
			{ "armada_metalextractor", "armada_solarcollector", "armada_windturbine", },               -- mex, solar, wind
			{ "armada_energyconverter", "", "armada_navalmetalstorage", "armada_tidalgenerator"},              -- T1 converter, uw ms storage, tidal
			{ "armada_energystorage", "armada_metalstorage", "armada_navalenergystorage", "armada_navalenergyconverter", }, -- e storage, m storage, uw e storage, floating T1 converter
		},
		{
			{ "armada_sentry", },                                   -- LLT
			{ "armada_nettle", },                                    -- basic AA
			{ },                                             --
		},
		{
			{ "armada_radartower", },                                   -- radar
			{ },                                             --
			{ "armada_lightmine", "armada_mediummine", "armada_heavymine", },         -- light mine, med mine, heavy mine
		},
		{
			{ },                                             --
			{ },                                             -- empty row
			{ },                                             --
		}
	},

	cortex_decoycommander = {
		{
			{ "cormex", "corsolar", "corwin", },               -- mex, solar, wind
			{ "cormakr", "", "coruwms", cortide},              -- T1 converter, uw ms storage, tidal
			{ "corestor", "cormstor", "coruwes", "corfmkr", }, -- e storage, m storage, uw e storage, floating T1 converter
		},
		{
			{ "corllt", },                                   -- LLT
			{ "corrl", },                                    -- basic AA
			{ },                                             --
		},
		{
			{ "corrad", },                                   -- radar
			{ },                                             --
			{ "cormine1", "cormine2", "cormine3", },         -- light mine, med mine, heavy mine
		},
		{
			{ },                                             --
			{ },                                             -- empty row
			{ },                                             --
		}
	},

	--fark
	armada_butler = {
		{
			{ "armada_metalextractor", "armada_solarcollector", "armada_windturbine", },   -- mex, solar, wind
			{ "armada_energyconverter", },                        -- T1 converter
			{ },                                   --
		},
		{
			{ },                                   --
			{ },                                   --
			{ },                                   --
		},
		{
			{ "armada_compass", "armada_beholder", "armada_radarjammerbot", },  -- radar bot, perimeter camera, jammer bot
			{ },                                   --
			{ },                                   --
		},
		{
			{ },                                   --
			{ },                                   --
			{ },                                   --
		}
	},

	--freaker
	corfast = {
		{
			{ "cormex", "corsolar", },                                -- mex, solar
			{ },                                                      -- solar
			{ },                                                      --
		},
		{
			{ "corhllt", "corpyro", "cortoast", },                    -- HLLT, pyro, toaster
			{ "corflak", "cormadsam", "corcrash", "corak", },         -- flak, SAM, T1 aa bot, AK
			{ "cordl", "corroy", "cortermite", "coramph", },          -- coastal torp launcher, destroyer, termite, gimp
		},
		{
			{ "corarad", "coreyes", "corfort", "corshroud", },        -- adv radar, camera, wall, adv jammer
			{ },                                                      --
			{ "cormine2", },                                          -- med mine
		},
		{
			{ "corlab", "corck", },                                   -- bot lab, bot con
			{ "cornanotc", "corcs", },                                -- nano, sea con
			{ "cormando", },                                          -- commando
		}
	},

	--consul
	armada_consul = {
		{
			{ "armada_metalextractor", "armada_solarcollector", },                                -- mex, solar
			{ },                                                      --
			{ },                                                      --
		},
		{
			{ "armada_beamer", "armada_sprinter", "armada_rattlesnake", "armada_gunslinger", },          -- beamer, sprinter, ambusher, maverick
			{ "armada_arbalest", "armada_ferret", "armada_crossbow", "armada_pawn", },          -- flak, ferret, T1 aa bot, peewee
			{ "armada_anemone", "armada_corsair", "armada_webber", "armada_amphibiousbot", },             -- coastal torp launcher, destroyer, emp spider, platypus
		},
		{
			{ "armada_advancedradartower", "armada_beholder", "armada_fortificationwall", "armada_veil", },          -- adv radar, camera, wall, adv jammer
			{ },                                                      --
			{ "armada_mediummine" },                                           -- med. mine
		},
		{
			{ "armada_constructionvehicle", "armada_vehicleplant" },                             	 	  -- T1 veh con, vehicle lab
			{ "armada_constructionturret" },                                		  -- nano
			{ "armada_constructionship" },                                              -- sea con
		}
	},

	--commando
	cormando = {
		{
			{ }, --
			{ },            --
			{ },          --
		},
		{
			{ "cormaw", },                                           -- flame turret
			{ },                                                     --
			{ },                                                     --
		},
		{
			{ "corfink", "coreyes", "cordrag", "corjamt", },         -- scout plane, camera, dragon's teeth, jammer
			{ "corvalk", },                                          -- transport
			{ "cormine4" },                                          -- commando mine
		},
		{
			{ },        --
			{ },                                             --
			{ },                          --
		}
	},

	--corprinter
	corprinter = {
		{
			{'corsolar', 'cormex' },
			{ },
			{ },                          -- solar, mex
		},
		{
			{ },
			{ },
			{ },
		},
		{
			{ 'corrad','', 'corfort'},
			{ },
			{ },                          --radar, t2 wall
		},
		{
			{ },
			{ },
			{ },
		}
	},

	--naval engineers
	armada_voyager = {
		{
			{ "armada_metalextractor", "armada_tidalgenerator", },                               -- mex, tidal
			{ },                                                    --
			{ },                                                    --
		},
		{
			{ "armada_harpoon", "armada_gorgon", "armada_rattlesnake", "armada_manta", },         -- torp launcher, kraken, ambusher, fHLT
			{ "armada_navalarbalest", "armada_skater", "armada_amphibiousbot", },                    -- fl flak, PT boat, pelican
			{ "armada_dolphin", "armada_corsair", },                             -- decade, destroyer
		},
		{
			{ "armada_navalradar", "armada_advancedradartower", },                              -- fl radar, adv radar
			{ },                                                    --
			{ "armada_heavymine", },                                       -- naval mine
		},
		{
			{ "armada_shipyard", "armada_constructionship", },                                  -- shipyard, sea con
			{ "armada_constructionturretplat", },                                   -- fl nano
			{ },                                                    --
		}
	},

	cormls = {
		{
			{ "cormex", "cortide", },                              -- mex, tidal
			{ },                                                   --
			{ },                                                   --
		},
		{
			{ "cortl", "corfdoom", "cortoast", "corfhlt", },       -- torp launcher, fl DDM, toaster, fHLT
			{ "corenaa", "corpt", },                               -- fl flak, searcher
			{ "coresupp", "corroy", },                             -- supporter, destroyer
		},
		{
			{ "corfrad", "corarad", },                             -- fl radar, adv radar
			{ },                                                   --
			{ "corfmine3", },                                      -- naval mine
		},
		{
			{ "corsy", "corcs", },                                 -- shipyard, sea con
			{ "cornanotcplat", },                                  -- fl nano
			{ },                                                   --
		}
	},
}

return {
	LabGrids = labGrids,
	UnitGrids = unitGrids,
}
