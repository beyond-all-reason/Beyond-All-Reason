local labGrids = {
	-- T1 bot is default
	-- T2 bot
	armalab = {
		"armack", "armfark", "armspy", "armfast",              -- T2 con, fark, spy, zipper
		"armmark", "armaser", "armzeus", "armmav",             -- radar bot, jammer bot, zeus, maverick
		"armfido", "armsnipe", "armaak", "armfboy",            -- fido, sniper, AA bot, fatboi
	},

	coralab = {
		"corack", "corfast", "corspy", "corpyro",              -- T2 con, freaker, spy, pyro
		"corvoyr", "corspec", "corcan", "corhrk",              -- radar bot, jammer bot, can, dominator
		"cormort", "corsktl", "coraak", "corsumo",             -- morty, skuttle, AA bot, sumo
	},
	-- T1 vehicle is default
	-- T2 vehicle
	armavp = {
		"armacv", "armconsul", "armbull", "armmart",           -- T2 con, consul, bulldog, luger
		"armseer", "armjam", "armmanni", "armst",              -- radar, jammer, penetrator, gremlin
		"armlatnk", "armcroc", "armyork", "armmerl",           -- panther, triton, AA, merl
	},

	coravp = {
		"coracv", "corban", "correap", "cormart",              -- T2 con, banisher, reaper, pillager
		"corvrad", "coreter", "corgol", "cortrem",             -- radar, jammer, goli, tremor
		"corseal", "corparrow", "corsent", "corvroc",          -- croc, poison arrow, AA, diplomat
	},
	-- T1 air
	armap = {
		"armca", "armfig", "armkam", "armthund",           -- T1 con, fig, gunship, bomber
		"armpeep", "armatlas",                             -- radar, transport,
	},

	corap = {
		"corca", "corveng", "corbw", "corshad",              -- T1 con, fig, drone, bomber
		"corfink", "corvalk",                                -- radar, transport
	},
	-- T2 air
	armaap = {
		"armaca", "armhawk", "armbrawl", "armpnix",           -- T2 con, fig, gunship, bomber
		"armawac", "armdfly", "armlance", "armliche",         -- radar, transport, torpedo, liche
		"armblade", "armstil",                                -- blade, stiletto
	},

	coraap = {
		"coraca", "corvamp", "corape", "corhurc",              -- T2 con, fig, gunship, bomber
		"corawac", "corseah", "cortitan", "corcrw",            -- radar, transport, torpedo, krow
	},
	-- seaplanes
	armplat = {
		"armcsa", "armsfig", "armsaber", "armsb",           -- seaplane con, fig, gunship, bomber
		"armsehak", "armseap",                              -- radar, torpedo
	},

	corplat = {
		"corcsa", "corsfig", "corcut", "corsb",              -- seaplane con, fig, gunship, bomber
		"corhunt", "corseap",                                -- radar, torpedo
	},
	-- T1 boats
	armsy = {
		"armcs", "armrecl", "armdecade", "armpt",            -- T1 sea con, rez sub, decade, PT boat
		"armpship", "armroy", "armsub", "armtship",          -- frigate, destroyer, sub, transport
	},

	corsy = {
		"corcs", "correcl", "coresupp", "corpt",              -- T1 sea con, rez sub, supporter, missile boat
		"corpship", "corroy", "corsub", "cortship",           -- frigate, destroyer, sub, transport
	},
	-- T2 boats
	armasy = {
		"armacsub", "armmls", "armcrus", "armmship",         -- T2 con sub, naval engineer, cruiser, rocket ship
		"armcarry", "armsjam", "armbats", "armepoch",        -- carrier, jammer, battleship, flagship
		"armsubk", "armserp", "armaas",                      -- sub killer, battlesub, AA
	},

	corasy = {
		"coracsub", "cormls", "corcrus", "cormmship",              -- T2 con sub, naval engineer, cruiser, rocket ship
		"corcarry", "corsjam", "corbats", "corblackhy",            -- carrier, jammer, battleship, flagship
		"corshark", "corssub", "corarch",                          -- sub killer, battlesub, AA
	}
}
local unitGrids = {
	-- Commanders
	armcom = {
		{
			{ "armmex", "armmakr", "armmstor", },            -- mex, T1 converter, m storage
			{ "armsolar", "armwin", "armuwes", },            -- solar, wind, uw e storage
			{ "armestor", "armtide", "armfmkr", "armuwms", }, -- e storage, tidal, floating converter, uw m storage
		},
		{
			{ "armllt", "armtl", },                          -- LLT, offshore torp launcher
			{ "armrl", "armfrt", },                          -- basic AA, floating AA
			{ "armdl", },                                    -- coastal torp launcher
		},
		{
			{ "armrad", "armeyes", "armdrag", },             -- radar, perimeter camera, dragon's teeth
			{ "armfrad", "armfdrag", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "armhp", "armfhp", },                          -- hover lab, floating hover lab
		}
	},

	corcom = {
		{
			{ "cormex", "cormakr", "cormstor", },            -- mex, T1 converter, m storage
			{ "corsolar", "corwin", "coruwes", },            -- solar, wind, uw e storage
			{ "corestor", "cortide", "corfmkr", "coruwms", }, -- e storage, tidal, floating converter, uw m storage
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

	-- T1 bot con
	armck = {
		{
			{ "armmex", "armmakr", "armmstor", "armamex", },  -- mex, T1 converter, m storage, twilight
			{ "armsolar", "armwin", "armadvsol", "armgeo", }, -- solar, wind, adv solar, T1 geo
			{ "armestor", },                                  -- e storage
		},
		{
			{ "armllt", "armbeamer", "armhlt", "armclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armrl", "armferret", "armcir", },              -- basic AA, ferret, chainsaw
			{ "armdl", "armguard", },                         -- coastal torp launcher, guardian
		},
		{
			{ "armrad", "armeyes", "armdrag", "armjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "armjuno", },                                   -- juno, air repair pad aircon only
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "armalab", },                      -- nano, T2 lab
			{ "armhp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	corck = {
		{
			{ "cormex", "cormakr", "cormstor", "corexp", },   -- mex, T1 converter, m storage, exploiter
			{ "corsolar", "corwin", "coradvsol", "corgeo", }, -- solar, wind, adv solar, T1 geo
			{ "corestor", },                                  -- e storage
		},
		{
			{ "corllt", "corhllt", "corhlt", "cormaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", },                           -- coastal torp launcher, punisher
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "corjuno", },                                   -- juno, air repair pad aircon only
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "coralab", },                      -- nano, T2 lab
			{ "corhp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	-- T1 vehicle con
	armcv = {
		{
			{ "armmex", "armmakr", "armmstor", "armamex", },  -- mex, T1 converter, m storage, twilight
			{ "armsolar", "armwin", "armadvsol", "armgeo", }, -- solar, wind, adv solar, T1 geo
			{ "armestor", },                                  -- e storage
		},
		{
			{ "armllt", "armbeamer", "armhlt", "armclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armrl", "armferret", "armcir", },              -- basic AA, ferret, chainsaw
			{ "armdl", "armguard", },                         -- coastal torp launcher, guardian
		},
		{
			{ "armrad", "armeyes", "armdrag", "armjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "armjuno", },                                   -- juno, air repair pad aircon only
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "armavp", },                       -- nano, T2 lab
			{ "armhp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	corcv = {
		{
			{ "cormex", "cormakr", "cormstor", "corexp", },   -- mex, T1 converter, m storage, exploiter
			{ "corsolar", "corwin", "coradvsol", "corgeo", }, -- solar, wind, adv solar, T1 geo
			{ "corestor", },                                  -- e storage
		},
		{
			{ "corllt", "corhllt", "corhlt", "cormaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", },                           -- coastal torp launcher, punisher
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "corjuno", },                                   -- juno, air repair pad aircon only
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "coravp", },                       -- nano, T2 lab
			{ "corhp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	-- T1 air con
	armca = {
		{
			{ "armmex", "armmakr", "armmstor", "armamex", },  -- mex, T1 converter, m storage, twilight
			{ "armsolar", "armwin", "armadvsol", "armgeo", }, -- solar, wind, adv solar, T1 geo
			{ "armestor", },                                  -- e storage
		},
		{
			{ "armllt", "armbeamer", "armhlt", "armclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armrl", "armferret", "armcir", },              -- basic AA, ferret, chainsaw
			{ "armdl", "armguard", },                         -- coastal torp launcher, guardian
		},
		{
			{ "armrad", "armeyes", "armdrag", "armjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "armjuno", "armasp", },                         -- juno, air repair pad aircon only
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "armaap", },                       -- nano, T2 lab
			{ "armhp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	corca = {
		{
			{ "cormex", "cormakr", "cormstor", "corexp", },   -- mex, T1 converter, m storage, exploiter
			{ "corsolar", "corwin", "coradvsol", "corgeo", }, -- solar, wind, adv solar, T1 geo
			{ "corestor", },                                  -- e storage
		},
		{
			{ "corllt", "corhllt", "corhlt", "cormaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", },                           -- coastal torp launcher, punisher
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "corjuno", "corasp", },                         -- juno, air repair pad aircon only
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "coraap", },                       -- nano, T2 lab
			{ "corhp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	-- T1 sea con
	armcs = {
		{
			{ "armmex", "armfmkr", "armuwms", },             -- mex, floating T1 converter, uw metal storage
			{ "armtide", "armuwes", "armgeo", },              -- tidal, uw e storage, geo
			{ },                                              -- empty row
		},
		{
			{ "armtl", "armfhlt", },                          -- offshore torp launcher, floating HLT
			{ "armfrt", },                                    -- floating AA
			{ "armdl", "armguard", "armclaw", },              -- coastal torp launcher, guardian, lightning turret
		},
		{
			{ "armfrad", "armfdrag", },                       -- floating radar, shark's teeth
			{ "armeyes", "armdrag", },                        -- perimeter camera, dragon's teeth
		},
		{
			{ "armsy", "armfhp", "armamsub", "armplat", },    -- shipyard, floating hover, amphibious lab, seaplane lab
			{ "armnanotcplat", "armasy", },                   -- floating nano, T2 shipyard
			{ "armlab", "armvp", "armap", },                  -- bot lab, vehicle lab, air lab
		}
	},

	corcs = {
		{
			{ "cormex", "corfmkr", "coruwms", },             -- mex, floating T1 converter, uw metal storage
			{ "cortide", "coruwes", "corgeo", },              -- tidal, uw e storage, geo
			{ },                                              -- empty row
		},
		{
			{ "cortl", "corfhlt", },                          -- offshore torp launcher, floating HLT
			{ "corfrt", },                                    -- floating AA
			{ "cordl", "corpun", "cormaw", },                 -- coastal torp launcher, punisher, flame turret
		},
		{
			{ "corfrad", "corfdrag", },                       -- floating radar, shark's teeth
			{ "coreyes", "cordrag", },                        -- perimeter camera, dragon's teeth
		},
		{
			{ "corsy", "corfhp", "coramsub", "corplat", },    -- shipyard, floating hover, amphibious lab, seaplane lab
			{ "cornanotcplat", "corasy", },                   -- floating nano, T2 shipyard
			{ "corlab", "corvp", "corap", },                  -- bot lab, vehicle lab, air lab
		}
	},

	-- Hover cons
	armch = {
		{
			{ "armmex", "armmakr", "armmstor", "armamex", },  -- mex, T1 converter, m storage, twilight
			{ "armsolar", "armwin", "armadvsol", "armgeo", }, -- solar, wind, adv solar, T1 geo
			{ "armestor", "armtide", "armfmkr", "armuwms", }, -- e storage, tidal, floating converter, uw m storage, uw e storage (next page)
		},
		{
			{ "armllt", "armbeamer", "armhlt", "armclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armrl", "armferret", "armcir", "armfrt",},     -- basic AA, ferret, chainsaw, floating AA
			{ "armdl", "armguard", "armtl", "armfhlt", },     -- coastal torp launcher, guardian, offshore torp launcher, floating HLT
		},
		{
			{ "armrad", "armeyes", "armdrag", "armjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "armjuno", },                                   -- juno, air repair pad aircon only
			{ "armfrad", "armfdrag", },                       -- floating radar, shark's teeth
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "armnanotcplat", },                -- nano, floating nano
			{ "armhp", "armfhp", "armamsub", "armplat", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	corch = {
		{
			{ "cormex", "cormakr", "cormstor", "corexp", },   -- mex, T1 converter, m storage, exploiter
			{ "corsolar", "corwin", "coradvsol", "corgeo", }, -- solar, wind, adv solar, T1 geo
			{ "corestor", "cortide", "corfmkr", "coruwms", }, -- e storage, tidal, floating converter, uw m storage, uw e storage (next page)
		},
		{
			{ "corllt", "corhllt", "corhlt", "cormaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", "cortl", "corfhlt", },       -- coastal torp launcher, punisher, offshore torp launcher, floating HLT
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "corjuno", },                                   -- juno, air repair pad aircon only
			{ "corfrad", "corfdrag", },                       -- floating radar, shark's teeth
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "cornanotcplat", },                -- nano, floating nano
			{ "corhp", "corfhp", "coramsub", "corplat", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	-- Seaplane cons
	armcsa = {
		{
			{ "armmex", "armmakr", "armmstor", "armamex", },  -- mex, T1 converter, m storage, twilight
			{ "armsolar", "armwin", "armadvsol", "armgeo", }, -- solar, wind, adv solar, T1 geo
			{ "armestor", "armtide", "armfmkr", "armuwms", }, -- e storage, tidal, floating converter, uw m storage, uw e storage (next page)
		},
		{
			{ "armllt", "armbeamer", "armhlt", "armclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armrl", "armferret", "armcir", "armfrt",},     -- basic AA, ferret, chainsaw, floating AA
			{ "armdl", "armguard", "armtl", "armfhlt", },     -- coastal torp launcher, guardian, offshore torp launcher, floating HLT
		},
		{
			{ "armrad", "armeyes", "armdrag", "armjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "armjuno", },                                   -- juno, air repair pad aircon only
			{ "armfrad", "armfdrag", },                       -- floating radar, shark's teeth
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "armnanotcplat", },                -- nano, floating nano
			{ "armhp", "armfhp", "armamsub", "armplat", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	corcsa = {
		{
			{ "cormex", "cormakr", "cormstor", "corexp", },   -- mex, T1 converter, m storage, exploiter
			{ "corsolar", "corwin", "coradvsol", "corgeo", }, -- solar, wind, adv solar, T1 geo
			{ "corestor", "cortide", "corfmkr", "coruwms", }, -- e storage, tidal, floating converter, uw m storage, uw e storage (next page)
		},
		{
			{ "corllt", "corhllt", "corhlt", "cormaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", "cortl", "corfhlt", },       -- coastal torp launcher, punisher, offshore torp launcher, floating HLT
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "corjuno", },                                   -- juno, air repair pad aircon only
			{ "corfrad", "corfdrag", },                       -- floating radar, shark's teeth
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "cornanotcplat", },                -- nano, floating nano
			{ "corhp", "corfhp", "coramsub", "corplat", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	-- Amphibious vehicle cons
	armbeaver = {
		{
			{ "armmex", "armmakr", "armmstor", "armamex", },  -- mex, T1 converter, m storage, twilight
			{ "armsolar", "armwin", "armadvsol", "armgeo", }, -- solar, wind, adv solar, T1 geo
			{ "armestor", "armtide", "armfmkr", "armuwms", }, -- e storage, tidal, floating converter, uw m storage, uw e storage (next page)
		},
		{
			{ "armllt", "armbeamer", "armhlt", "armclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armrl", "armferret", "armcir", "armfrt",},     -- basic AA, ferret, chainsaw, floating AA
			{ "armdl", "armguard", "armptl", "armfhlt", },     -- coastal torp launcher, guardian, offshore torp launcher, floating HLT
		},
		{
			{ "armrad", "armeyes", "armdrag", "armjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "armjuno", },                                   -- juno, air repair pad aircon only
			{ "armfrad", "armfdrag", },                       -- floating radar, shark's teeth
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "armnanotcplat", "armavp", },      -- nano, floating nano, T2 veh lab
			{ "armhp", "armfhp", "armamsub", "armplat", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	cormuskrat = {
		{
			{ "cormex", "cormakr", "cormstor", "corexp", },   -- mex, T1 converter, m storage, exploiter
			{ "corsolar", "corwin", "coradvsol", "corgeo", }, -- solar, wind, adv solar, T1 geo
			{ "corestor", "cortide", "corfmkr", "coruwms", }, -- e storage, tidal, floating converter, uw m storage, uw e storage (next page)
		},
		{
			{ "corllt", "corhllt", "corhlt", "cormaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", "corptl", "corfhlt", },       -- coastal torp launcher, punisher, offshore torp launcher, floating HLT
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "corjuno", },                                   -- juno, air repair pad aircon only
			{ "corfrad", "corfdrag", },                       -- floating radar, shark's teeth
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "cornanotcplat", "coravp", },      -- nano, floating nano, T2 veh lab
			{ "corhp", "corfhp", "coramsub", "corplat", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	--T2 bot cons
	armack = {
		{
			{ "armmoho", "armmmkr", "armuwadvms", },            -- moho, T2 converter, hardened metal storage
			{ "armfus", "armafus", "armuwadves", "armckfus", }, -- fusion, afus, hardened energy storage, cloaked fusion
			{ "armageo", "armgmm", },                           -- T2 geo, safe geo
		},
		{
			{ "armpb", "armanni", "armamb", "armemp", },        -- pop-up gauss, annihilator, pop-up artillery, EMP missile
			{ "armflak", "armmercury", "armamd", },             -- flak, long-range AA, anti-nuke
			{ "armbrtha", "armvulc", "armsilo", },              -- LRPC, ICBM, lolcannon
		},
		{
			{ "armarad", "armtarg", "armfort", "armveil",  },   -- adv radar, targeting facility, wall, adv jammer
			{ "armsd", "armasp", "armdf", },                    -- intrusion counter, air repair pad, decoy fusion
			{ "armgate", },                                     -- shield
		},
		{
			{ "armlab", },                                      -- T1 lab,
			{ "armshltx", "armalab", },                         -- T3 lab, T2 lab
			{ },                                                --
		}
	},

	corack = {
		{
			{ "cormoho", "cormmkr", "coruwadvms", "cormexp", }, -- moho, T2 converter, hardened metal storage, exploiter (cor)
			{ "corfus", "corafus", "coruwadves", },             -- fusion, afus, hardened energy storage,
			{ "corageo", "corbhmth", },                         -- T2 geo, behemoth
		},
		{
			{ "corvipe", "cordoom", "cortoast", "cortron", },   -- pop-up gauss, DDM, pop-up artillery, tac nuke
			{ "corflak", "corscreamer", "corfmd", },            -- flak, long-range AA
			{ "corint", "corbuzz", "corsilo", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "corarad", "cortarg", "corfort", "corshroud", },  -- adv radar, targeting facility, wall, adv jammer
			{ "corsd", "corasp", },                             -- intrusion counter, air repair pad
			{ "corgate", },                                     -- anti-nuke, shield
		},
		{
			{ "corlab", },                                      -- T1 lab,
			{ "corgant", "coralab", },                          -- T3 lab, T2 lab
			{ },                                                --
		}
	},

	--T2 vehicle cons
	armacv = {
		{
			{ "armmoho", "armmmkr", "armuwadvms", },            -- moho, T2 converter, hardened metal storage
			{ "armfus", "armafus", "armuwadves", "armckfus", }, -- fusion, afus, hardened energy storage, cloaked fusion
			{ "armageo", "armgmm", },                           -- T2 geo, safe geo
		},
		{
			{ "armpb", "armanni", "armamb", "armemp", },        -- pop-up gauss, annihilator, pop-up artillery, EMP missile
			{ "armflak", "armmercury", "armamd", },             -- flak, long-range AA, anti-nuke
			{ "armbrtha", "armvulc", "armsilo", },              -- LRPC, ICBM, lolcannon
		},
		{
			{ "armarad", "armtarg", "armfort", "armveil",  },   -- adv radar, targeting facility, wall, adv jammer
			{ "armsd", "armasp", "armdf", },                    -- intrusion counter, air repair pad, decoy fusion
			{ "armgate", },                                     -- shield
		},
		{
			{ "armvp", },                                       -- T1 lab,
			{ "armshltx", "armavp", },                          -- T3 lab, T2 lab
			{ },                                                --
		}
	},

	coracv = {
		{
			{ "cormoho", "cormmkr", "coruwadvms", "cormexp", }, -- moho, T2 converter, hardened metal storage, exploiter (cor)
			{ "corfus", "corafus", "coruwadves", },             -- fusion, afus, hardened energy storage,
			{ "corageo", "corbhmth", },                         -- T2 geo, behemoth
		},
		{
			{ "corvipe", "cordoom", "cortoast", "cortron", },   -- pop-up gauss, DDM, pop-up artillery, tac nuke
			{ "corflak", "corscreamer", "corfmd", },            -- flak, long-range AA
			{ "corint", "corbuzz", "corsilo", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "corarad", "cortarg", "corfort", "corshroud", },  -- adv radar, targeting facility, wall, adv jammer
			{ "corsd", "corasp", },                             -- intrusion counter, air repair pad
			{ "corgate", },                                     -- anti-nuke, shield
		},
		{
			{ "corvp", },                                       -- T1 lab,
			{ "corgant", "coravp", },                           -- T3 lab, T2 lab
			{ },                                                --
		}
	},

	--T2 air cons
	armaca = {
		{
			{ "armmoho", "armmmkr", "armuwadvms", },            -- moho, T2 converter, hardened metal storage
			{ "armfus", "armafus", "armuwadves", "armckfus", }, -- fusion, afus, hardened energy storage, cloaked fusion
			{ "armageo", "armgmm", },                           -- T2 geo, safe geo
		},
		{
			{ "armpb", "armanni", "armamb", "armemp", },        -- pop-up gauss, annihilator, pop-up artillery, EMP missile
			{ "armflak", "armmercury", "armamd", },             -- flak, long-range AA, anti-nuke
			{ "armbrtha", "armvulc", "armsilo", },              -- LRPC, ICBM, lolcannon
		},
		{
			{ "armarad", "armtarg", "armfort", "armveil",  },    -- adv radar, targeting facility, wall, adv jammer
			{ "armsd", "armasp", "armdf", },                    -- intrusion counter, air repair pad, decoy fusion
			{ "armgate", },                                     -- shield
		},
		{
			{ "armap", },                                       -- T1 lab,
			{ "armshltx", "armaap", },                          -- T3 lab, T2 lab
			{ "armplat", },                                     -- seaplane lab (aircon only)
		}
	},

	coraca = {
		{
			{ "cormoho", "cormmkr", "coruwadvms", "cormexp", }, -- moho, T2 converter, hardened metal storage, exploiter (cor)
			{ "corfus", "corafus", "coruwadves", },             -- fusion, afus, hardened energy storage,
			{ "corageo", "corbhmth", },                         -- T2 geo, behemoth
		},
		{
			{ "corvipe", "cordoom", "cortoast", "cortron", },   -- pop-up gauss, DDM, pop-up artillery, tac nuke
			{ "corflak", "corscreamer", "corfmd", },            -- flak, long-range AA
			{ "corint", "corbuzz", "corsilo", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "corarad", "cortarg", "corfort", "corshroud", },  -- adv radar, targeting facility, wall, adv jammer
			{ "corsd", "corasp", },                             -- intrusion counter, air repair pad
			{ "corgate", },                                     -- anti-nuke, shield
		},
		{
			{ "corap", },                                       -- T1 lab,
			{ "corgant", "coraap", },                           -- T3 lab, T2 lab
			{ "corplat", },                                     -- seaplane lab (aircon only)
		}
	},

	--T2 sub cons
	armacsub = {
		{
			{ "armuwmme", "armuwmmm", "armuwadvms", },         -- uw moho, floating T2 converter, uw metal stor
			{ "armuwfus", "armuwadves", },                     -- uw fusion, uw e stor
			{ },                                               --
		},
		{
			{ "armatl", "armkraken", },                        -- adv torp launcher, floating heavy platform
			{ "armfflak", },                                   -- floating flak
			{ },                                               --
		},
		{
			{ "armason", "armfatf", },                         -- adv sonar, floating targeting facility
			{ },                                               --
			{ },                                               --
		},
		{
			{ "armsy", },                                      -- T1 shipyard
			{ "armshltxuw", "armasy", },                       -- amphibious gantry, T2 shipyard
			{ },                                               --
		}
	},

	coracsub = {
		{
			{ "coruwmme", "coruwmmm", "coruwadvms", },         -- uw moho, floating T2 converter, uw metal stor
			{ "coruwfus", "coruwadves", },                     -- uw fusion, uw e stor
			{ },                                               --
		},
		{
			{ "coratl", "corfdoom", },                         -- adv torp launcher, floating heavy platform
			{ "corenaa", },                                    -- floating flak
			{ },                                               --
		},
		{
			{ "corason", "corfatf", },                         -- adv sonar, floating targeting facility
			{ },                                               --
		},
		{
			{ "corsy", },                                      -- T1 shipyard
			{ "corgantuw", "corasy" },                         -- amphibious gantry, T2 shipyard
			{ },                                               --
		}
	},

	--minelayers
	armmlv = {
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
			{ "armeyes", "armdrag", },                  -- camera, dragon's teeth
			{ },                                        --
			{ "armmine1", "armmine2", "armmine3", },    -- light mine, med mine, heavy mine
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
			{ "coreyes", "cordrag", },                 -- camera, dragon's teeth
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
	armdecom = {
		{
			{ "armmex", "armmakr", "armmstor", },            -- mex, T1 converter, m storage
			{ "armsolar", "armwin", "armuwes", },            -- solar, wind, uw e storage
			{ "armestor", "armtide", "armfmkr", "armuwms", }, -- e storage, tidal, floating converter, uw m storage
		},
		{
			{ "armllt", },                                   -- LLT
			{ "armrl", },                                    -- basic AA
			{ },                                             --
		},
		{
			{ "armrad", },                                   -- radar
			{ },                                             --
			{ "armmine1", "armmine2", "armmine3", },         -- light mine, med mine, heavy mine
		},
		{
			{ },                                             --
			{ },                                             -- empty row
			{ },                                             --
		}
	},

	cordecom = {
		{
			{ "cormex", "cormakr", "cormstor", },            -- mex, T1 converter, m storage
			{ "corsolar", "corwin", "coruwes", },            -- solar, wind, uw e storage
			{ "corestor", "cortide", "corfmkr", "coruwms", }, -- e storage, tidal, floating converter, uw m storage
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
	armfark = {
		{
			{ "armmex", "armmakr", },              -- mex, t1 converter
			{ "armsolar", "armwin", },             -- solar, wind
			{ },                                   --
		},
		{
			{ },                                   --
			{ },                                   --
			{ },                                   --
		},
		{
			{ "armmark", "armeyes", "armaser", },  -- radar bot, perimeter camera, jammer bot
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
			{ "cormex", },                                            -- mex
			{ "corsolar", },                                          -- solar
			{ },                                                      --
		},
		{
			{ "corhllt", "corpyro", "cortoast", },                    -- HLLT, pyro, toaster
			{ "corflak", "cormadsam", "corcrash", "corak", },         -- flak, SAM, T1 aa bot, AK
			{ "cordl", "corroy", "coramph", },                        -- coastal torp launcher, destroyer, gimp
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
	armconsul = {
		{
			{ "armmex", },                                            -- mex
			{ "armsolar", },                                          -- solar
			{ },                                                      --
		},
		{
			{ "armbeamer", "armfido", "armamb", "armmav", },          -- beamer, fido, ambusher, maverick
			{ "armflak", "armferret", "armjeth", "armpw", },          -- flak, ferret, T1 aa bot, peewee
			{ "armdl", "armroy", "armsptk", },                        -- coastal torp launcher, destroyer, missile spider
		},
		{
			{ "armarad", "armeyes", "armfort", "armveil", },          -- adv radar, camera, wall, adv jammer
			{ },                                                      --
			{ "armmine2" },                                           -- med. mine
		},
		{
			{ "armvp", "armcv", },                                    -- vehicle lab, T1 veh con
			{ "armnanotc", "armcs", },                                -- nano, sea con
			{ },                                                      --
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

	--naval engineers
	armmls = {
		{
			{ "armmex", },                                          -- mex
			{ "armtide", },                                         -- tidal
			{ },                                                    --
		},
		{
			{ "armtl", "armkraken", "armamb", "armfhlt", },         -- torp launcher, kraken, ambusher, fHLT
			{ "armfflak", "armpt", "armamph", },                    -- fl flak, PT boat, pelican
			{ "armdecade", "armroy", },                             -- decade, destroyer
		},
		{
			{ "armfrad", "armarad", },                              -- fl radar, adv radar
			{ },                                                    --
			{ "armfmine3", },                                       -- naval mine
		},
		{
			{ "armsy", "armcs", },                                  -- shipyard, sea con
			{ "armnanotcplat", },                                   -- fl nano
			{ },                                                    --
		}
	},

	cormls = {
		{
			{ "cormex", },                                         -- mex
			{ "cortide", },                                        -- tidal
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