local labGrids = {
	-- T1 bot
	armada_botlab = {
		"armada_constructionbot", "armada_lazarus", "armada_pawn", "armada_tick",                -- T1 con, rez bot, peewee, flea
		"armada_rocketeer", "armada_mace", "armada_centurion", "",                     -- rocko, hammer, warrior
		"", "", "armada_crossbow",                                         -- aa bot
	},

	cortex_botlab = {
		"cortex_constructionbot", "cortex_graverobber", "cortex_grunt", "",                      -- T1 con, rez bot, AK
		"cortex_aggravator", "cortex_thug", "", "",                        -- storm, thud
		"", "", "cortex_trasher",                                        -- aa bot
	},
	leglab = {
		"legck", "cortex_graverobber", "leggob", "",                      -- T1 con, rez bot, AK
		"legbal", "leglob", "legkark", "legcen",                        -- storm, thud
		"", "", "cortex_trasher",                                        -- aa bot
	},
	-- T2 bot
	armada_advancedbotlab = {
		"armada_advancedconstructionbot", "armada_butler", "armada_sprinter", "armada_ghost",             -- T2 con, fark, zipper, spy
		"armada_compass", "armada_radarjammerbot", "armada_welder", "armada_gunslinger",             -- radar bot, jammer bot, zeus, maverick
		"armada_hound", "armada_sharpshooter", "armada_archangel", "armada_fatboy",            -- fido, sniper, AA bot, fatboi
	},

	cortex_advancedbotlab = {
		"cortex_advancedconstructionbot", "cortex_twitcher", "cortex_fiend", "cortex_spectre",               -- T2 con, freaker, pyro, spy
		"cortex_augur", "cortex_deceiver", "cortex_sumo", "cortex_arbiter",              -- radar bot, jammer bot, can, dominator
		"cortex_sheldon", "cortex_bedbug", "cortex_manticore", "cortex_mammoth",             -- morty, skuttle, AA bot, sumo
	},
	legalab = {
		"legack", "cortex_twitcher", "legstr", "cortex_spectre",               -- T2 con, freaker, strider, spy
		"cortex_augur", "cortex_deceiver", "leginfestor", "legsrail",              -- radar bot, jammer bot, infestor, dominator
		"legbart", "cortex_bedbug", "legshot", "leginc",             -- belcher, skuttle, shotgun, sumo
	},
	-- T1 vehicle
	armada_vehicleplant = {
		"armada_constructionvehicle", "armada_groundhog", "armada_blitz", "armada_rover",        -- T1 con, minelayer, flash, scout
		"armada_stout", "armada_janus", "armada_shellshocker", "",          -- stumpy, janus, arty
		"armada_beaver", "armada_pincer", "armada_whistler", "",        -- amphib con, amphib tank, missile truck
	},

	cortex_vehicleplant = {
		"cortex_constructionvehicle", "cortex_trapper", "cortex_incisor", "cortex_rascal",       -- T1 con, minelayer, gator, scout
		"cortex_brute", "cortex_pounder", "cortex_wolverine", "",         -- raider, leveler, art
		"cortex_muskrat", "cortex_garpike", "cortex_lasher", "",       -- amphib con, amphib tank, missile truck
	},
	legvp = {
		"legcv", "", "leghades", "cortex_rascal",       -- T1 con, minelayer, gator, scout
		"leggat", "leghelios", "legbar", "",         -- raider, leveler, art
		"", "", "legrail", "",       -- amphib con, amphib tank, missile truck
	},
	-- T2 vehicle
	armada_advancedvehicleplant = {
		"armada_advancedconstructionvehicle", "armada_consul", "armada_bull", "armada_mauser",           -- T2 con, consul, bulldog, luger
		"armada_prophet", "armada_umbra", "armada_starlight", "armst",              -- radar, jammer, penetrator, gremlin
		"armada_jaguar", "armada_turtle", "armada_shredder", "armada_ambassador",           -- panther, triton, AA, merl
	},

	cortex_advancedvehicleplant = {
		"cortex_advancedconstructionvehicle", "cortex_banisher", "cortex_tiger", "cortex_quaker",              -- T2 con, banisher, reaper, pillager
		"cortex_omen", "cortex_obscurer", "cortex_tzar", "cortex_tremor",             -- radar, jammer, goli, tremor
		"cortex_alligator", "cortex_poisonarrow", "cortex_fury", "cortex_negotiator",          -- croc, poison arrow, AA, diplomat
	},
	legavp = {
		"legacv", "legmrv", "legsco", "cortex_quaker",              -- T2 con, Quickshot, scorpion, pillager
		"cortex_omen", "cortex_obscurer", "cortex_tzar", "leginf",             -- radar, jammer, goli, inferno
		"legfloat", "cortex_banisher", "cortex_fury", "cortex_negotiator",           -- croc, poison arrow, AA, diplomat
	},
	-- T1 air
	armada_aircraftplant = {
		"armada_constructionaircraft", "armada_falcon", "armada_banshee", "armada_stormbringer",           -- T1 con, fig, gunship, bomber
		"armada_blink", "armada_stork",                             -- radar, transport,
	},
	cortex_aircraftplant = {
		"cortex_constructionaircraft", "cortex_valiant", "cortex_shuriken", "cortex_whirlwind",              -- T1 con, fig, drone, bomber
		"corfink", "cortex_hercules",                                -- radar, transport
	},
    legap = {
		"legca", "legfig", "legmos", "legkam",              -- T1 con, fig, drone, bomber
		"legcib", "cortex_hercules",                                -- radar, transport
	},
	-- T2 air
	armada_advancedaircraftplant = {
		"armada_advancedconstructionaircraft", "armada_highwind", "armada_roughneck", "armada_blizzard",           -- T2 con, fig, gunship, bomber
		"armada_oracle", "armada_abductor", "armada_cormorant", "armada_cyclone2",                -- radar, transport, torpedo, heavy fighter (mod)
		"armada_liche", "armada_hornet", "armada_stiletto",                    -- liche, blade, stiletto
	},

	cortex_advancedaircraftplant = {
		"cortex_advancedconstructionaircraft", "cortex_nighthawk", "cortex_wasp", "cortex_hailstorm",              -- T2 con, fig, gunship, bomber
		"cortex_condor", "cortex_skyhook", "cortex_angler", "cortex_bat2",                 -- radar, transport, torpedo, heavy fighter (mod)
		"cortex_dragonold","cortex_dragon",                                              -- krow
	},
	legaap = {
	"legaca","legionnaire","legvenator","",					--T2 con, defensive fig, interceptor
	"legmineb","legnap","legphoenix","cortex_angler",			--minebomber, napalmbomber, 'heavy bomber', torpedo
	"legfort","legstronghold","legwhisper",	""			--knockoff krow, (well armed)transport, radar
	},
	-- seaplanes
	armada_seaplaneplatform = {
		"armada_constructionseaplane", "armada_cyclone", "armada_sabre", "armada_tsunami",           -- seaplane con, fig, gunship, bomber
		"armada_horizon", "armada_puffin",                              -- radar, torpedo
	},

	cortex_seaplaneplatform = {
		"cortex_constructionseaplane", "cortex_bat", "cortex_cutlass", "cortex_dambuster",              -- seaplane con, fig, gunship, bomber
		"cortex_watcher", "cortex_monsoon",                                -- radar, torpedo
	},
	-- T1 boats
	armada_shipyard = {
		"armada_constructionship", "armada_grimreaper", "armada_dolphin", "",              -- T1 sea con, rez sub, decade
		"armada_ellysaw", "armada_corsair", "", "",                    -- frigate, destroyer, transport ("armada_convoy",)
		"armada_eel", "", "armada_skater",                            -- sub, PT boat
	},

	cortex_shipyard = {
		"cortex_constructionship", "cortex_deathcavalry", "cortex_supporter", "",               -- T1 sea con, rez sub, supporter, missile boat
		"cortex_riptide", "cortex_oppressor", "", "",                    -- frigate, destroyer, transport ("cortex_coffin",)
		"cortex_orca", "", "cortex_herring",                            -- sub, missile boat
	},
	-- T2 boats
	armada_advancedshipyard = {
		"armada_advancedconstructionsub", "armada_voyager", "armada_paladin", "armada_longbow",         -- T2 con sub, naval engineer, cruiser, rocket ship
		"armada_haven", "armada_bermuda", "armada_dreadnought", "armada_epoch",        -- carrier, jammer, battleship, flagship
		"armada_barracuda", "armada_serpent", "armada_dragonslayer",                      -- sub killer, battlesub, AA
	},

	cortex_advancedshipyard = {
		"cortex_advancedconstructionsub", "cortex_pathfinder", "cortex_buccaneer", "cortex_messenger",              -- T2 con sub, naval engineer, cruiser, rocket ship
		"cortex_oasis", "cortex_phantasm", "cortex_despot", "cortex_blackhydra",            -- carrier, jammer, battleship, flagship
		"cortex_predator", "cortex_kraken", "cortex_arrowstorm",                          -- sub killer, battlesub, AA
	},
	-- amphibious labs
	armada_amphibiouscomplex = {
		"armada_beaver", "armada_decoycommander", "armada_pincer", "",
		"armada_turtle", "", "", "",
		"", "armada_crossbow", "armada_archangel",
	},

	cortex_amphibiouscomplex = {
		"cortex_muskrat", "cortex_decoycommander", "cortex_garpike", "",
		"cortex_alligator", "cortex_poisonarrow", "", "",
		"", "cortex_trasher", "cortex_manticore",
	},
	-- hover labs
	armada_hovercraftplatform = {
		"armada_constructionhovercraft", "", "armada_seeker", "",
		"armada_crocodile", "armada_possum", "", "",
		"", "", "armada_sweeper",
	},

	cortex_hovercraftplatform = {
		"cortex_constructionhovercraft", "", "cortex_goon", "",
		"cortex_cayman", "cortex_mangonel", "cortex_halberd", "",
		"", "", "cortex_birdeater",
	},
	armada_navalhovercraftplatform = {
		"armada_constructionhovercraft", "", "armada_seeker", "",
		"armada_crocodile", "armada_possum", "", "",
		"", "", "armada_sweeper",
	},

	cortex_navalhovercraftplatform = {
		"cortex_constructionhovercraft", "", "cortex_goon", "",
		"cortex_cayman", "cortex_mangonel", "cortex_halberd", "",
		"", "", "cortex_birdeater",
	},

	-- T3 labs
	armada_experimentalgantry = {
		"armada_marauder", "armada_razorback", "armada_vanguard", "armada_thor",
		"armada_titan", "armada_lunkhead"
	},

	cortex_experimentalgantry = {
		"cortex_catapult", "cortex_karganeth", "cortex_shiva", "cortex_juggernaut",
		"cortex_behemoth", "cortex_cataphract"
	},
	leggant = {
		"cortex_catapult", "cortex_karganeth", "cortex_shiva", "cortex_juggernaut",
		"cortex_behemoth", "cortex_cataphract", "legpede", "leegmech",
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
			{ "armada_navalradarsonar", "armada_sharksteeth", },                      -- floating radar, shark's teeth
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
			{ "cortex_metalextractor", "cortex_solarcollector", "cortex_windturbine", },                -- mex, solar, wind
			{ "cortex_energyconverter", "", "cortex_navalmetalstorage", "cortex_tidalgenerator"},             -- T1 converter, uw m storage, tidal
			{ "cortex_energystorage", "cortex_metalstorage", "cortex_navalenergystorage", "cortex_navalenergyconverter",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "cortex_guard", "cortex_urchin", },                          -- LLT, offshore torp launcher
			{ "cortex_thistle", "cortex_slingshot", },                          -- basic AA, floating AA
			{ "cortex_jellyfish", },                                    -- coastal torp launcher
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", },             -- radar, perimeter camera, dragon's teeth
			{ "cortex_radarsonartower", "cortex_sharksteeth", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "cortex_botlab", "cortex_vehicleplant", "cortex_aircraftplant", "cortex_shipyard", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "cortex_hovercraftplatform", "cortex_navalhovercraftplatform", },                          -- hover lab, floating hover lab
		}
	},
	legassistdrone = {
		{
			{ "legmex", "cortex_solarcollector", "cortex_windturbine", },                -- mex, solar, wind
			{ "cortex_energyconverter", "", "cortex_navalmetalstorage", "cortex_tidalgenerator"},             -- T1.5 mex, uw m storage, tidal
			{ "cortex_energystorage", "cortex_metalstorage", "cortex_navalenergystorage", "cortex_navalenergyconverter",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "cortex_guard", "cortex_urchin", },                          -- LLT, offshore torp launcher
			{ "cortex_thistle", "cortex_slingshot", },                          -- basic AA, floating AA
			{ "cortex_jellyfish", },                                    -- coastal torp launcher
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", },             -- radar, perimeter camera, dragon's teeth
			{ "cortex_radarsonartower", "cortex_sharksteeth", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "leglab", "legvp", "legap", "cortex_shipyard", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "cortex_hovercraftplatform", "cortex_navalhovercraftplatform", },                          -- hover lab, floating hover lab
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
			{ "armada_navalradarsonar", "armada_sharksteeth", },                      -- floating radar, shark's teeth
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
			{ "cortex_metalextractor", "cortex_solarcollector", "cortex_windturbine", },                -- mex, solar, wind
			{ "cortex_energyconverter", "", "cortex_navalmetalstorage", "cortex_tidalgenerator"},             -- T1 converter, uw m storage, tidal
			{ "cortex_energystorage", "cortex_metalstorage", "cortex_navalenergystorage", "cortex_navalenergyconverter",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "cortex_guard", "cortex_urchin", },                          -- LLT, offshore torp launcher
			{ "cortex_thistle", "cortex_slingshot", },                          -- basic AA, floating AA
			{ "cortex_jellyfish", },                                    -- coastal torp launcher
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", },             -- radar, perimeter camera, dragon's teeth
			{ "cortex_radarsonartower", "cortex_sharksteeth", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "cortex_botlab", "cortex_vehicleplant", "cortex_aircraftplant", "cortex_shipyard", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "cortex_hovercraftplatform", "cortex_navalhovercraftplatform", },                          -- hover lab, floating hover lab
		}
	},
	legassistdrone_land = {
		{
			{ "legmex", "cortex_solarcollector", "cortex_windturbine", },                -- mex, solar, wind
			{ "cortex_energyconverter", "", "cortex_navalmetalstorage", "cortex_tidalgenerator"},             -- T1.5 mex, uw m storage, tidal
			{ "cortex_energystorage", "cortex_metalstorage", "cortex_navalenergystorage", "cortex_navalenergyconverter",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "cortex_guard", "cortex_urchin", },                          -- LLT, offshore torp launcher
			{ "cortex_thistle", "cortex_slingshot", },                          -- basic AA, floating AA
			{ "cortex_jellyfish", },                                    -- coastal torp launcher
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", },             -- radar, perimeter camera, dragon's teeth
			{ "cortex_radarsonartower", "cortex_sharksteeth", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "leglab", "legvp", "legap", "cortex_shipyard", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "cortex_hovercraftplatform", "cortex_navalhovercraftplatform", },                          -- hover lab, floating hover lab
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
			{ "armada_navalradarsonar", "armada_sharksteeth", },                      -- floating radar, shark's teeth
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
			{ "cortex_metalextractor", "cortex_solarcollector", "cortex_windturbine", },                -- mex, solar, wind
			{ "cortex_energyconverter", "", "cortex_navalmetalstorage", "cortex_tidalgenerator"},             -- T1 converter, uw m storage, tidal
			{ "cortex_energystorage", "cortex_metalstorage", "cortex_navalenergystorage", "cortex_navalenergyconverter",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "cortex_guard", "cortex_urchin", },                          -- LLT, offshore torp launcher
			{ "cortex_thistle", "cortex_slingshot", },                          -- basic AA, floating AA
			{ "cortex_jellyfish", },                                    -- coastal torp launcher
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", },             -- radar, perimeter camera, dragon's teeth
			{ "cortex_radarsonartower", "cortex_sharksteeth", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "cortex_botlab", "cortex_vehicleplant", "cortex_aircraftplant", "cortex_shipyard", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "cortex_hovercraftplatform", "cortex_navalhovercraftplatform", },                          -- hover lab, floating hover lab
		}
	},
	-- legion commanders
    legcom = {
		{
			{ "legmex", "cortex_solarcollector", "cortex_windturbine", },                -- mex, solar, wind
			{ "cortex_energyconverter", "", "cortex_navalmetalstorage", "cortex_tidalgenerator"},             -- T1.5 mex, uw m storage, tidal
			{ "cortex_energystorage", "cortex_metalstorage", "cortex_navalenergystorage", "cortex_navalenergyconverter",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "cortex_guard", "cortex_urchin", },                          -- LLT, offshore torp launcher
			{ "cortex_thistle", "cortex_slingshot", },                          -- basic AA, floating AA
			{ "cortex_jellyfish", },                                    -- coastal torp launcher
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", },             -- radar, perimeter camera, dragon's teeth
			{ "cortex_radarsonartower", "cortex_sharksteeth", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "leglab", "legvp", "legap", "cortex_shipyard", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "cortex_hovercraftplatform", "cortex_navalhovercraftplatform", },                          -- hover lab, floating hover lab
		}
	},
	legcomlvl2 = {
		{
			{ "legmex", "cortex_solarcollector", "cortex_windturbine", },                -- mex, solar, wind
			{ "cortex_energyconverter", "", "cortex_navalmetalstorage", "cortex_tidalgenerator"},             -- T1.5 mex, uw m storage, tidal
			{ "cortex_energystorage", "cortex_metalstorage", "cortex_navalenergystorage", "cortex_navalenergyconverter",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "cortex_guard", "cortex_urchin", },                          -- LLT, offshore torp launcher
			{ "cortex_thistle", "cortex_slingshot", },                          -- basic AA, floating AA
			{ "cortex_jellyfish", },                                    -- coastal torp launcher
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", },             -- radar, perimeter camera, dragon's teeth
			{ "cortex_radarsonartower", "cortex_sharksteeth", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "leglab", "legvp", "legap", "cortex_shipyard", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "cortex_hovercraftplatform", "cortex_navalhovercraftplatform", },                          -- hover lab, floating hover lab
		}
	},
	legcomlvl3 = {
		{
			{ "legmex", "cortex_solarcollector", "cortex_windturbine", },                -- mex, solar, wind
			{ "cortex_energyconverter", "legmext15", "cortex_navalmetalstorage", "cortex_tidalgenerator", },  -- T1 converter, T1.5 mex, uw m storage, tidal
			{ "cortex_energystorage", "cortex_metalstorage", "cortex_navalenergystorage", "cortex_navalenergyconverter",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "cortex_guard", "cortex_urchin", },                          -- LLT, offshore torp launcher
			{ "cortex_thistle", "cortex_slingshot", },                          -- basic AA, floating AA
			{ "cortex_jellyfish", },                                    -- coastal torp launcher
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", },             -- radar, perimeter camera, dragon's teeth
			{ "cortex_radarsonartower", "cortex_sharksteeth", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "leglab", "legvp", "legap", "cortex_shipyard", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "cortex_hovercraftplatform", "cortex_navalhovercraftplatform", },                          -- hover lab, floating hover lab
		}
	},
	legcomlvl4 = {
		{
			{ "legmex", "cortex_solarcollector", "cortex_windturbine", },                -- mex, solar, wind
			{ "cortex_energyconverter", "legmext15", "cortex_navalmetalstorage", "cortex_tidalgenerator", },  -- T1 converter, T1.5 mex, uw m storage, tidal
			{ "cortex_energystorage", "cortex_metalstorage", "cortex_navalenergystorage", "cortex_navalenergyconverter",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "cortex_guard", "cortex_urchin", },                          -- LLT, offshore torp launcher
			{ "cortex_thistle", "cortex_slingshot", },                          -- basic AA, floating AA
			{ "cortex_jellyfish", },                                    -- coastal torp launcher
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", },             -- radar, perimeter camera, dragon's teeth
			{ "cortex_radarsonartower", "cortex_sharksteeth", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "leglab", "legvp", "legap", "cortex_shipyard", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "cortex_hovercraftplatform", "cortex_navalhovercraftplatform", },                          -- hover lab, floating hover lab
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

	cortex_constructionbot = {
		{
			{ "cortex_metalextractor", "cortex_solarcollector", "cortex_windturbine", "cortex_advancedsolarcollector", },   -- mex, solar, wind, adv. solar
			{ "cortex_energyconverter", "cortex_geothermalpowerplant", "cortex_exploiter", },                 -- T1 converter, geo, exploiter, (tidal)
			{ "cortex_energystorage", "cortex_metalstorage", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "cortex_guard", "cortex_twinguard", "cortex_warden", "cortex_dragonsmaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "cortex_thistle", "cortex_sam", "cortex_eradicator", },             -- basic AA, SAM, eradicator
			{ "cortex_jellyfish", "cortex_agitator", },                           -- coastal torp launcher, punisher
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", "cortex_castro", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ },
			{ "cortex_juno", },                                   -- juno
		},
		{
			{ "cortex_botlab", "cortex_vehicleplant", "cortex_aircraftplant", "cortex_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "cortex_constructionturret", "cortex_advancedbotlab", },                      -- nano, T2 lab
			{ "cortex_hovercraftplatform", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},
   legck = {
		{
			{ "legmex", "cortex_solarcollector", "cortex_windturbine", "cortex_advancedsolarcollector", },   -- mex, solar, wind, adv. solar
			{ "cortex_energyconverter", "cortex_geothermalpowerplant", "legmext15", },              -- T1 converter, geo, T1.5 legion mex, (tidal)
			{ "cortex_energystorage", "cortex_metalstorage", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "cortex_guard", "legmg", "cortex_warden", "cortex_dragonsmaw", },       -- LLT, machine gun, HLT, flame turret
			{ "cortex_thistle", "cortex_sam", "cortex_eradicator", },             -- basic AA, SAM, eradicator
			{ "cortex_jellyfish", "cortex_agitator", },                           -- coastal torp launcher, punisher
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", "cortex_castro", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ },
			{ "cortex_juno", },                                   -- juno
		},
		{
			{ "leglab", "legvp", "legap", "cortex_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "cortex_constructionturret", "legalab", },                      -- nano, T2 lab
			{ "cortex_hovercraftplatform", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
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

	cortex_constructionvehicle = {
		{
			{ "cortex_metalextractor", "cortex_solarcollector", "cortex_windturbine", "cortex_advancedsolarcollector", },   -- mex, solar, wind, adv. solar
			{ "cortex_energyconverter", "cortex_geothermalpowerplant", "cortex_exploiter", },                 -- T1 converter, geo, exploiter, (tidal)
			{ "cortex_energystorage", "cortex_metalstorage", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "cortex_guard", "cortex_twinguard", "cortex_warden", "cortex_dragonsmaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "cortex_thistle", "cortex_sam", "cortex_eradicator", },             -- basic AA, SAM, eradicator
			{ "cortex_jellyfish", "cortex_agitator", },                           -- coastal torp launcher, punisher
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", "cortex_castro", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ },
			{ "cortex_juno", },                                   -- juno
		},
		{
			{ "cortex_botlab", "cortex_vehicleplant", "cortex_aircraftplant", "cortex_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "cortex_constructionturret", "cortex_advancedvehicleplant", },                       -- nano, T2 lab
			{ "cortex_hovercraftplatform", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},
    legcv = {
		{
			{ "legmex", "cortex_solarcollector", "cortex_windturbine", "cortex_advancedsolarcollector", },   -- mex, solar, wind, adv. solar
			{ "cortex_energyconverter", "cortex_geothermalpowerplant", "legmext15", },              -- T1 converter, geo, T1.5 legion mex, (tidal)
			{ "cortex_energystorage", "cortex_metalstorage", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "cortex_guard", "legmg", "cortex_warden", "cortex_dragonsmaw", },     -- LLT, machine gun, HLT, flame turret
			{ "cortex_thistle", "cortex_sam", "cortex_eradicator", },             -- basic AA, SAM, eradicator
			{ "cortex_jellyfish", "cortex_agitator", },                           -- coastal torp launcher, punisher
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", "cortex_castro", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ },
			{ "cortex_juno", },                                   -- juno
		},
		{
			{ "leglab", "legvp", "legap", "cortex_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "cortex_constructionturret", "cortex_advancedbotlab", },                      -- nano, T2 lab
			{ "cortex_hovercraftplatform", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
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
			{ "", "", "armada_airrepairpad", "armada_airrepairpad" },                  -- air repair pad, floating air repair pad
			{ "armada_juno", }									  -- juno
		},
		{
			{ "armada_botlab", "armada_vehicleplant", "armada_aircraftplant", "armada_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "armada_constructionturret", "armada_advancedaircraftplant", },                       -- nano, T2 lab
			{ "armada_hovercraftplatform", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	cortex_constructionaircraft = {
		{
			{ "cortex_metalextractor", "cortex_solarcollector", "cortex_windturbine", "cortex_advancedsolarcollector", },   -- mex, solar, wind, adv. solar
			{ "cortex_energyconverter", "cortex_geothermalpowerplant", "cortex_exploiter", },                 -- T1 converter, geo, exploiter, (tidal)
			{ "cortex_energystorage", "cortex_metalstorage", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "cortex_guard", "cortex_twinguard", "cortex_warden", "cortex_dragonsmaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "cortex_thistle", "cortex_sam", "cortex_eradicator", },             -- basic AA, SAM, eradicator
			{ "cortex_jellyfish", "cortex_agitator", },                           -- coastal torp launcher, punisher
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", "cortex_castro", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "", "", "cortex_airrepairpad", "cortex_floatingairrepairpad" },                  -- air repair pad, floating air repair pad
			{ "cortex_juno", }									  -- juno
		},
		{
			{ "cortex_botlab", "cortex_vehicleplant", "cortex_aircraftplant", "cortex_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "cortex_constructionturret", "cortex_advancedaircraftplant", },                       -- nano, T2 lab
			{ "cortex_hovercraftplatform", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},
    legca = {
		{
			{ "legmex", "cortex_solarcollector", "cortex_windturbine", "cortex_advancedsolarcollector", },   -- mex, solar, wind, adv. solar
			{ "cortex_energyconverter", "cortex_geothermalpowerplant", "legmext15", },              -- T1 converter, geo, T1.5 legion mex, (tidal)
			{ "cortex_energystorage", "cortex_metalstorage", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "cortex_guard", "legmg", "cortex_warden", "cortex_dragonsmaw", },     -- LLT, machine gun, HLT, flame turret
			{ "cortex_thistle", "cortex_sam", "cortex_eradicator", },             -- basic AA, SAM, eradicator
			{ "cortex_jellyfish", "cortex_agitator", },                           -- coastal torp launcher, punisher
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", "cortex_castro", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ },
			{ "cortex_juno", },                                   -- juno
		},
		{
			{ "leglab", "legvp", "legap", "cortex_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "cortex_constructionturret", "legaap", },                      -- nano, T2 lab
			{ "cortex_hovercraftplatform", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
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
			{ "armada_navalradarsonar", "armada_beholder","armada_sharksteeth", },             -- floating radar, perimeter camera, shark's teeth
			{ "", "armada_dragonsteeth", "armada_airrepairpad", "armada_airrepairpad"},                        	      -- dragon's teeth
		},
		{
			{ "armada_shipyard", "armada_vehicleplant", "armada_aircraftplant", "armada_botlab", },         -- shipyard, veh lab, air lab, bot lab
			{ "armada_navalconstructionturret", "armada_advancedshipyard", },                   -- floating nano, T2 shipyard
			{ "armada_navalhovercraftplatform", "", "armada_amphibiouscomplex", "armada_seaplaneplatform", },         -- floating hover lab, amphibious lab, seaplane lab
		}
	},

	cortex_constructionship = {
		{
			{ "cortex_metalextractor", "cortex_tidalgenerator", },                         -- mex, tidal
			{ "cortex_navalenergyconverter", "cortex_geothermalpowerplant", },                         -- floating T1 converter, geo
			{ "cortex_navalenergystorage", "cortex_navalmetalstorage", },                        -- uw e stor, uw m stor
		},
		{
			{ "cortex_urchin", "cortex_coral", "", "cortex_dragonsmaw" },             -- offshore torp launcher, floating HLT
			{ "cortex_slingshot", },                                    -- floating AA
			{ "cortex_jellyfish", "cortex_agitator", },                 		  -- coastal torp launcher, punisher, flame turret
		},
		{
			{ "cortex_radarsonartower", "cortex_beholder", "cortex_sharksteeth", },            -- floating radar, perimeter camera, shark's teeth
			{ "", "cortex_dragonsteeth", "cortex_airrepairpad", "cortex_floatingairrepairpad" },           -- dragon's teeth
		},
		{
			{ "cortex_shipyard", "cortex_vehicleplant", "cortex_aircraftplant", "cortex_botlab",  },        -- shipyard, vehicle lab, air lab, bot lab
			{ "cortex_navalconstructionturret", "cortex_advancedshipyard", },                   -- floating nano, T2 shipyard
			{ "cortex_navalhovercraftplatform", "", "cortex_amphibiouscomplex", "cortex_seaplaneplatform",  },        -- floating hover, amphibious lab, seaplane lab
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
			{ "armada_navalradarsonar", "armada_sharksteeth", },                       -- floating radar, shark's teeth
			{ "armada_juno", },                                   -- juno
		},
		{
			{ "armada_botlab", "armada_vehicleplant", "armada_aircraftplant", "armada_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "armada_constructionturret", "armada_advancedvehicleplant", "armada_navalconstructionturret", "armada_advancedshipyard",  },    -- nano, T2 veh lab, floating nano, T2 shipyard
			{ "armada_hovercraftplatform", "armada_navalhovercraftplatform", "armada_amphibiouscomplex", "armada_seaplaneplatform", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	cortex_constructionhovercraft = {
		{
			{ "cortex_metalextractor", "cortex_solarcollector", "cortex_windturbine", "cortex_advancedsolarcollector", },   -- mex, solar, wind, adv. solar
			{ "cortex_energyconverter", "cortex_geothermalpowerplant", "cortex_exploiter", "cortex_tidalgenerator", },      -- T1 converter, geo, exploiter, (tidal)
			{ "cortex_energystorage", "cortex_metalstorage", "cortex_navalenergystorage", "cortex_navalenergyconverter", },  -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "cortex_guard", "cortex_twinguard", "cortex_warden", "cortex_dragonsmaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "cortex_thistle", "cortex_sam", "cortex_eradicator", },             -- basic AA, SAM, eradicator
			{ "cortex_jellyfish", "cortex_agitator", "cortex_urchin", "cortex_coral", },       -- coastal torp launcher, punisher, offshore torp launcher, floating HLT
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", "cortex_castro", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "cortex_radarsonartower", "cortex_sharksteeth", },                       -- floating radar, shark's teeth
			{ "cortex_juno", },                                   -- juno
		},
		{
			{ "cortex_botlab", "cortex_vehicleplant", "cortex_aircraftplant", "cortex_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "cortex_constructionturret", "cortex_advancedvehicleplant", "cortex_navalconstructionturret", "cortex_advancedshipyard", },   -- nano, T2 veh lab, floating nano, T2 shipyard
			{ "cortex_hovercraftplatform", "cortex_navalhovercraftplatform", "cortex_amphibiouscomplex", "cortex_seaplaneplatform", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
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
			{ "armada_navalradarsonar", "armada_sharksteeth", "armada_airrepairpad", "armada_airrepairpad" },                       -- floating radar, shark's teeth
			{ "armada_juno", },                                   -- juno
		},
		{
			{ "armada_botlab", "armada_vehicleplant", "armada_aircraftplant", "armada_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "armada_constructionturret", "armada_navalconstructionturret", },                -- nano, floating nano
			{ "armada_hovercraftplatform", "armada_navalhovercraftplatform", "armada_amphibiouscomplex", "armada_seaplaneplatform", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	cortex_constructionseaplane = {
		{
			{ "cortex_metalextractor", "cortex_solarcollector", "cortex_windturbine", "cortex_advancedsolarcollector", },   -- mex, solar, wind, adv. solar
			{ "cortex_energyconverter", "cortex_geothermalpowerplant", "cortex_exploiter", "cortex_tidalgenerator", },      -- T1 converter, geo, exploiter, (tidal)
			{ "cortex_energystorage", "cortex_metalstorage", "cortex_navalenergystorage", "cortex_navalenergyconverter", },  -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "cortex_guard", "cortex_twinguard", "cortex_warden", "cortex_dragonsmaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "cortex_thistle", "cortex_sam", "cortex_eradicator", },             -- basic AA, SAM, eradicator
			{ "cortex_jellyfish", "cortex_agitator", "cortex_urchin", "cortex_coral", },       -- coastal torp launcher, punisher, offshore torp launcher, floating HLT
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", "cortex_castro", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "cortex_radarsonartower", "cortex_sharksteeth", "cortex_airrepairpad", "cortex_floatingairrepairpad" },                       -- floating radar, shark's teeth
			{ "cortex_juno", },                                   -- juno
		},
		{
			{ "cortex_botlab", "cortex_vehicleplant", "cortex_aircraftplant", "cortex_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "cortex_constructionturret", "cortex_navalconstructionturret", },                -- nano, floating nano
			{ "cortex_hovercraftplatform", "cortex_navalhovercraftplatform", "cortex_amphibiouscomplex", "cortex_seaplaneplatform", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
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
			{ "armada_navalradarsonar", "armada_sharksteeth", },                       -- floating radar, shark's teeth
			{ "armada_juno", },                                   -- juno
		},
		{
			{ "armada_botlab", "armada_vehicleplant", "armada_aircraftplant", "armada_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "armada_constructionturret", "armada_advancedvehicleplant", "armada_navalconstructionturret", },      -- nano, T2 veh lab, floating nano
			{ "armada_hovercraftplatform", "armada_navalhovercraftplatform", "armada_amphibiouscomplex", "armada_seaplaneplatform", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	cortex_muskrat = {
		{
			{ "cortex_metalextractor", "cortex_solarcollector", "cortex_windturbine", "cortex_advancedsolarcollector", },   -- mex, solar, wind, adv. solar
			{ "cortex_energyconverter", "cortex_geothermalpowerplant", "cortex_exploiter", "cortex_tidalgenerator", },      -- T1 converter, geo, exploiter, (tidal)
			{ "cortex_energystorage", "cortex_metalstorage", "cortex_navalenergystorage", "cortex_navalenergyconverter", },  -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "cortex_guard", "cortex_twinguard", "cortex_warden", "cortex_dragonsmaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "cortex_thistle", "cortex_sam", "cortex_eradicator", },             -- basic AA, SAM, eradicator
			{ "cortex_jellyfish", "cortex_agitator", "cortex_oldurchin", "cortex_coral", },       -- coastal torp launcher, punisher, offshore torp launcher, floating HLT
		},
		{
			{ "cortex_radartower", "cortex_beholder", "cortex_dragonsteeth", "cortex_castro", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "cortex_radarsonartower", "cortex_sharksteeth", },                       -- floating radar, shark's teeth
			{ "cortex_juno", },                                   -- juno
		},
		{
			{ "cortex_botlab", "cortex_vehicleplant", "cortex_aircraftplant", "cortex_shipyard", },         -- bot lab, veh lab, air lab, shipyard
			{ "cortex_constructionturret", "cortex_advancedvehicleplant", "cortex_navalconstructionturret", },      -- nano, T2 veh lab, floating nano
			{ "cortex_hovercraftplatform", "cortex_navalhovercraftplatform", "cortex_amphibiouscomplex", "cortex_seaplaneplatform", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
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
			{ "armada_tracer", "armada_decoyfusionreactor", "armada_airrepairpad" },                     -- intrusion counter, decoy fusion, air repair pad
			{ "armada_keeper", },                                     -- shield
		},
		{
			{ "armada_botlab", },                                      -- T1 lab,
			{ "armada_experimentalgantry", "armada_advancedbotlab", },                         -- T3 lab, T2 lab
			{ },                                                --
		}
	},

	cortex_advancedconstructionbot = {
		{
			{ "cortex_advancedmetalextractor", "cortex_fusionreactor", "cortex_advancedfusionreactor", },                -- moho, fusion, afus
			{ "cortex_advancedenergyconverter", "cortex_advancedgeothermalpowerplant", "cortex_advancedexploiter", },               -- T2 converter, T2 geo, armed moho
			{ "cortex_hardenedenergystorage", "cortex_hardenedmetalstorage", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "cortex_scorpion", "cortex_bulwark", "cortex_persecutor", "cortex_catalyst", },   -- pop-up gauss, DDM, pop-up artillery, tac nuke
			{ "cortex_birdshot", "cortex_screamer", "cortex_prevailer", "cortex_cerberus", }, -- flak, long-range AA, anti-nuke, cerberus
			{ "cortex_basilisk", "cortex_calamity", "cortex_apocalypse", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "cortex_advancedradartower", "cortex_pinpointer", "cortex_fortificationwall", "cortex_shroud", },  -- adv radar, targeting facility, wall, adv jammer
			{ "cortex_nemesis", "", "cortex_airrepairpad" },                          -- intrusion counter, air repair pad
			{ "cortex_overseer", },                                     -- anti-nuke, shield
		},
		{
			{ "cortex_botlab", },                                      -- T1 lab,
			{ "cortex_experimentalgantry", "cortex_advancedbotlab", },                          -- T3 lab, T2 lab
			{ },                                                --
		}
	},

	legack = {
		{
			{ "cortex_advancedmetalextractor", "cortex_fusionreactor", "cortex_advancedfusionreactor", },                -- moho, fusion, afus
			{ "cortex_advancedenergyconverter", "cortex_advancedgeothermalpowerplant", "cortex_advancedexploiter", },               -- T2 converter, T2 geo, armed moho
			{ "cortex_hardenedenergystorage", "cortex_hardenedmetalstorage", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "cortex_scorpion", "legbastion", "cortex_persecutor", "cortex_catalyst", },   -- pop-up gauss, heavy defence, pop-up artillery, tac nuke
			{ "cortex_birdshot", "cortex_screamer", "cortex_prevailer", "cortex_cerberus", }, -- flak, long-range AA, anti-nuke, cerberus
			{ "cortex_basilisk", "legstarfall", "cortex_apocalypse", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "cortex_advancedradartower", "cortex_pinpointer", "cortex_fortificationwall", "cortex_shroud", },  -- adv radar, targeting facility, wall, adv jammer
			{ "cortex_nemesis", "", "cortex_airrepairpad" },                          -- intrusion counter, air repair pad
			{ "cortex_overseer", },                                     -- anti-nuke, shield
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
			{ "armada_tracer", "armada_decoyfusionreactor", "armada_airrepairpad" },                     -- intrusion counter, decoy fusion, air repair pad
			{ "armada_keeper", },                                     -- shield
		},
		{
			{ "armada_vehicleplant", },                                       -- T1 lab,
			{ "armada_experimentalgantry", "armada_advancedvehicleplant", },                          -- T3 lab, T2 lab
			{ },                                                --
		}
	},

	cortex_advancedconstructionvehicle = {
		{
			{ "cortex_advancedmetalextractor", "cortex_fusionreactor", "cortex_advancedfusionreactor", },                -- moho, fusion, afus
			{ "cortex_advancedenergyconverter", "cortex_advancedgeothermalpowerplant", "cortex_advancedexploiter", },               -- T2 converter, T2 geo, armed moho
			{ "cortex_hardenedenergystorage", "cortex_hardenedmetalstorage", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "cortex_scorpion", "cortex_bulwark", "cortex_persecutor", "cortex_catalyst", },   -- pop-up gauss, DDM, pop-up artillery, tac nuke
			{ "cortex_birdshot", "cortex_screamer", "cortex_prevailer", "cortex_cerberus", }, -- flak, long-range AA, anti-nuke, cerberus
			{ "cortex_basilisk", "cortex_calamity", "cortex_apocalypse", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "cortex_advancedradartower", "cortex_pinpointer", "cortex_fortificationwall", "cortex_shroud", },  -- adv radar, targeting facility, wall, adv jammer
			{ "cortex_nemesis", "", "cortex_airrepairpad" },                          -- intrusion counter, air repair pad
			{ "cortex_overseer", },                                     -- anti-nuke, shield
		},
		{
			{ "cortex_vehicleplant", },                                       -- T1 lab,
			{ "cortex_experimentalgantry", "cortex_advancedvehicleplant", },                           -- T3 lab, T2 lab
			{ },                                                --
		}
	},

	legacv = {
		{
			{ "cortex_advancedmetalextractor", "cortex_fusionreactor", "cortex_advancedfusionreactor", },                -- moho, fusion, afus
			{ "cortex_advancedenergyconverter", "cortex_advancedgeothermalpowerplant", "cortex_advancedexploiter", },               -- T2 converter, T2 geo, armed moho
			{ "cortex_hardenedenergystorage", "cortex_hardenedmetalstorage", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "cortex_scorpion", "legbastion", "cortex_persecutor", "cortex_catalyst", },   -- pop-up gauss, heavy defence, pop-up artillery, tac nuke
			{ "cortex_birdshot", "cortex_screamer", "cortex_prevailer", "cortex_cerberus", }, -- flak, long-range AA, anti-nuke, cerberus
			{ "cortex_basilisk", "legstarfall", "cortex_apocalypse", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "cortex_advancedradartower", "cortex_pinpointer", "cortex_fortificationwall", "cortex_shroud", },  -- adv radar, targeting facility, wall, adv jammer
			{ "cortex_nemesis", "", "cortex_airrepairpad" },                          -- intrusion counter, air repair pad
			{ "cortex_overseer", },                                     -- anti-nuke, shield
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
			{ "armada_tracer", "armada_decoyfusionreactor", "armada_airrepairpad", "armada_airrepairpad" },           -- intrusion counter, decoy fusion, air repair pad, floating air repair pad
			{ "armada_keeper", },                                      -- shield
		},
		{
			{ "armada_aircraftplant", },                                       -- T1 lab,
			{ "armada_experimentalgantry", "armada_advancedaircraftplant", },                          -- T3 lab, T2 lab
			{ "armada_seaplaneplatform", },                                     -- seaplane lab (aircon only)
		}
	},

	cortex_advancedconstructionaircraft = {
		{
			{ "cortex_advancedmetalextractor", "cortex_fusionreactor", "cortex_advancedfusionreactor", },                -- moho, fusion, afus
			{ "cortex_advancedenergyconverter", "cortex_advancedgeothermalpowerplant", "cortex_advancedexploiter","cortex_advancednavalgeothermalpowerplant", },               -- T2 converter, T2 geo, armed moho
			{ "cortex_hardenedenergystorage", "cortex_hardenedmetalstorage", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "cortex_scorpion", "cortex_bulwark", "cortex_persecutor", "cortex_catalyst" },    -- pop-up gauss, DDM, pop-up artillery, tac nuke
			{ "cortex_birdshot", "cortex_screamer", "cortex_prevailer", "cortex_cerberus" }, -- flak, long-range AA, anti-nuke, cerberus
			{ "cortex_basilisk", "cortex_calamity", "cortex_apocalypse" },                 -- LRPC, ICBM, lolcannon
		},
		{
			{ "cortex_advancedradartower", "cortex_pinpointer", "cortex_fortificationwall", "cortex_shroud" },   -- adv radar, targeting facility, wall, adv jammer
			{ "cortex_nemesis", "", "cortex_airrepairpad", "cortex_floatingairrepairpad" },               -- intrusion counter, air repair pad, floating air repair pad
			{ "cortex_overseer", },                                     -- anti-nuke, shield
		},
		{
			{ "cortex_aircraftplant", },                                       -- T1 lab,
			{ "cortex_experimentalgantry", "cortex_advancedaircraftplant", },                           -- T3 lab, T2 lab
			{ "cortex_seaplaneplatform", },                                     -- seaplane lab (aircon only)
		}
	},
	legaca = {
		{
			{ "cortex_advancedmetalextractor", "cortex_fusionreactor", "cortex_advancedfusionreactor", },                -- moho, fusion, afus
			{ "cortex_advancedenergyconverter", "cortex_advancedgeothermalpowerplant", "cortex_advancedexploiter","cortex_advancednavalgeothermalpowerplant", },               -- T2 converter, T2 geo, armed moho
			{ "cortex_hardenedenergystorage", "cortex_hardenedmetalstorage", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "cortex_scorpion", "legbastion", "cortex_persecutor", "cortex_catalyst", },   -- pop-up gauss, heavy defence, pop-up artillery, tac nuke
			{ "cortex_birdshot", "cortex_screamer", "cortex_prevailer", "cortex_cerberus", }, -- flak, long-range AA, anti-nuke, cerberus
			{ "cortex_basilisk", "legstarfall", "cortex_apocalypse", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "cortex_advancedradartower", "cortex_pinpointer", "cortex_fortificationwall", "cortex_shroud", },  -- adv radar, targeting facility, wall, adv jammer
			{ "cortex_nemesis", "", "cortex_airrepairpad", "cortex_floatingairrepairpad" },               -- intrusion counter, air repair pad, floating air repair pad
			{ "cortex_overseer", },                                     -- anti-nuke, shield
		},
		{
			{ "legap", },                                       -- T1 lab,
			{ "leggant", "legaap", },                           -- T3 lab, T2 lab
			{ "cortex_seaplaneplatform", },                                     -- seaplane lab (aircon only)
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

	cortex_advancedconstructionsub = {
		{
			{ "cortex_navaladvancedmetalextractor", "cortex_navalfusionreactor", },                       -- uw moho, uw fusion,
			{ "cortex_navaladvancedenergyconverter", "cortex_advancednavalgeothermalpowerplant" },                       -- floating T2 converter, adv geo powerplant
			{ "cortex_hardenedenergystorage", "cortex_hardenedmetalstorage", },                   -- uw e stor, uw metal stor
		},
		{
			{ "cortex_lamprey", "cortex_devastator", },                         -- adv torp launcher, floating heavy platform
			{ "cortex_navalbirdshot", },                                    -- floating flak
			{ },                                               --
		},
		{
			{ "cortex_advancedsonarstation", "cortex_navalpinpointer",  },                         -- adv sonar, floating targeting facility
			{ "", "", "", "cortex_floatingairrepairpad" },                          -- Floating air repair pad
		},
		{
			{ "cortex_shipyard", },                                      -- T1 shipyard
			{ "cortex_underwaterexperimentalgantry", "cortex_advancedshipyard" },                         -- amphibious gantry, T2 shipyard
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

	cortex_trapper = {
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
			{ "", "cortex_beholder", "cortex_dragonsteeth", },                 -- camera, dragon's teeth
			{ },                                       --
			{ "cortex_lightmine", "cortex_mediummine", "cortex_heavymine", },   -- light mine, med mine, heavy mine
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
			{ "cortex_metalextractor", "cortex_solarcollector", "cortex_windturbine", },               -- mex, solar, wind
			{ "cortex_energyconverter", "", "cortex_navalmetalstorage", cortex_tidalgenerator},              -- T1 converter, uw ms storage, tidal
			{ "cortex_energystorage", "cortex_metalstorage", "cortex_navalenergystorage", "cortex_navalenergyconverter", }, -- e storage, m storage, uw e storage, floating T1 converter
		},
		{
			{ "cortex_guard", },                                   -- LLT
			{ "cortex_thistle", },                                    -- basic AA
			{ },                                             --
		},
		{
			{ "cortex_radartower", },                                   -- radar
			{ },                                             --
			{ "cortex_lightmine", "cortex_mediummine", "cortex_heavymine", },         -- light mine, med mine, heavy mine
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
	cortex_twitcher = {
		{
			{ "cortex_metalextractor", "cortex_solarcollector", },                                -- mex, solar
			{ },                                                      -- solar
			{ },                                                      --
		},
		{
			{ "cortex_twinguard", "cortex_fiend", "cortex_persecutor", },                    -- HLLT, pyro, toaster
			{ "cortex_birdshot", "cortex_sam", "cortex_trasher", "cortex_grunt", },         -- flak, SAM, T1 aa bot, AK
			{ "cortex_jellyfish", "cortex_oppressor", "cortex_termite", "cortex_duck", },          -- coastal torp launcher, destroyer, termite, gimp
		},
		{
			{ "cortex_advancedradartower", "cortex_beholder", "cortex_fortificationwall", "cortex_shroud", },        -- adv radar, camera, wall, adv jammer
			{ },                                                      --
			{ "cortex_mediummine", },                                          -- med mine
		},
		{
			{ "cortex_botlab", "cortex_constructionbot", },                                   -- bot lab, bot con
			{ "cortex_constructionturret", "cortex_constructionship", },                                -- nano, sea con
			{ "cortex_commando", },                                          -- commando
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
	cortex_commando = {
		{
			{ }, --
			{ },            --
			{ },          --
		},
		{
			{ "cortex_dragonsmaw", },                                           -- flame turret
			{ },                                                     --
			{ },                                                     --
		},
		{
			{ "corfink", "cortex_beholder", "cortex_dragonsteeth", "cortex_castro", },         -- scout plane, camera, dragon's teeth, jammer
			{ "cortex_hercules", },                                          -- transport
			{ "cortex_mediumminecommando" },                                          -- commando mine
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
			{'cortex_solarcollector', 'cortex_metalextractor' },
			{ },
			{ },                          -- solar, mex
		},
		{
			{ },
			{ },
			{ },
		},
		{
			{ 'cortex_radartower','', 'cortex_fortificationwall'},
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
			{ "armada_navalradarsonar", "armada_advancedradartower", },                              -- fl radar, adv radar
			{ },                                                    --
			{ "armada_heavymine", },                                       -- naval mine
		},
		{
			{ "armada_shipyard", "armada_constructionship", },                                  -- shipyard, sea con
			{ "armada_navalconstructionturret", },                                   -- fl nano
			{ },                                                    --
		}
	},

	cortex_pathfinder = {
		{
			{ "cortex_metalextractor", "cortex_tidalgenerator", },                              -- mex, tidal
			{ },                                                   --
			{ },                                                   --
		},
		{
			{ "cortex_urchin", "cortex_devastator", "cortex_persecutor", "cortex_coral", },       -- torp launcher, fl DDM, toaster, fHLT
			{ "cortex_navalbirdshot", "cortex_herring", },                               -- fl flak, searcher
			{ "cortex_supporter", "cortex_oppressor", },                             -- supporter, destroyer
		},
		{
			{ "cortex_radarsonartower", "cortex_advancedradartower", },                             -- fl radar, adv radar
			{ },                                                   --
			{ "cortex_navalheavymine", },                                      -- naval mine
		},
		{
			{ "cortex_shipyard", "cortex_constructionship", },                                 -- shipyard, sea con
			{ "cortex_navalconstructionturret", },                                  -- fl nano
			{ },                                                   --
		}
	},
}

return {
	LabGrids = labGrids,
	UnitGrids = unitGrids,
}
