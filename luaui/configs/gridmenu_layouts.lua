local labGrids = {
	-- T1 bot
	armlab = {
		"armck", "armrectr", "armpw", "armflea",                -- T1 con, rez bot, peewee, flea
		"armrock", "armham", "armwar", "",                     -- rocko, hammer, warrior
		"", "", "armjeth",                                         -- aa bot
	},

	corlab = {
		"corck", "cornecro", "corak", "",                      -- T1 con, rez bot, AK
		"corstorm", "corthud", "", "",                        -- storm, thud
		"", "", "corcrash",                                        -- aa bot
	},
	leglab = {
		"legck", "legrezbot", "leggob", "",                      -- T1 con, rez bot, AK
		"legbal", "leglob", "legkark", "legcen",                        -- storm, thud
		"", "", "legaabot",                                        -- aa bot
	},
	-- T2 bot
	armalab = {
		"armack", "armfark", "armfast", "armspy",             -- T2 con, fark, zipper, spy
		"armmark", "armaser", "armzeus", "armmav",             -- radar bot, jammer bot, zeus, maverick
		"armfido", "armsnipe", "armaak", "armfboy",            -- fido, sniper, AA bot, fatboi
	},

	coralab = {
		"corack", "corfast", "corpyro", "corspy",               -- T2 con, freaker, pyro, spy
		"corvoyr", "corspec", "corcan", "corhrk",              -- radar bot, jammer bot, can, dominator
		"cormort", "corroach", "coraak", "corsumo",             -- morty, skuttle, AA bot, sumo
	},
	legalab = {
		-- page1
		"legack", "legaceb", "legstr", "legaspy",               -- T2 con, proteus, hoplite, spy
		"legaradk", "legajamk", "legshot", "leghrk",             -- radar bot, jammer bot, phalanx, Thanatos
		"legbart", "legsrail", "legadvaabot", "leginc",        -- belcher, railgun, AA bot, incinerator
		-- page2
		"legamph", "leginfestor", "legsnapper", "corsktl",     -- amphbious bot, infestor, snapper, skuttle
		"legdecom",					                           -- decoycom
	},
	-- T1 vehicle
	armvp = {
		"armcv", "armmlv", "armflash", "armfav",        -- T1 con, minelayer, flash, scout
		"armstump", "armjanus", "armart", "",          -- stumpy, janus, arty
		"armbeaver", "armpincer", "armsam", "",        -- amphib con, amphib tank, missile truck
	},

	corvp = {
		"corcv", "cormlv", "corgator", "corfav",       -- T1 con, minelayer, gator, scout
		"corraid", "corlevlr", "corwolv", "",         -- raider, leveler, art
		"cormuskrat", "corgarp", "cormist", "",       -- amphib con, amphib tank, missile truck
	},
	legvp = {
		"legcv", "legmlv", "leghades", "legscout",       -- T1 con, minelayer, gator, scout
		"leghelios", "leggat", "legbar", "",         -- raider, leveler, art
		"legotter", "legamphtank", "legrail", "",       -- amphib con, amphib tank, missile truck
	},
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
	legavp = {
		-- page1
		"legacv", "legafcv", "legaskirmtank", "legamcluster",	-- T2 con, medusa, gladiator, cleaver
		"legavrad", "legavjam", "legaheattank", "leginf",        -- radar, jammer, prometheus, inferno
		"legmrv", "legfloat", "legvflak", "legmed",            -- Quickshot, new triton, AA, boreas
		-- page2
		"legvcarry", "legavroc", "cormabm",					-- mantis, chiron, veh antinuke
	},
	-- T1 air
	armap = {
		"armca", "armfig", "armkam", "armthund",           -- T1 con, fig, gunship, bomber
		"armpeep", "armatlas", "armhvytrans",                -- radar, light transport, medium transport
	},
	corap = {
		"corca", "corveng", "corbw", "corshad",              -- T1 con, fig, drone, bomber
		"corfink", "corvalk", "corhvytrans",                 -- radar, light transport, medium transport
	},
    legap = {
		"legca", "legfig", "legmos", "legkam",              -- T1 con, fig, drone, bomber
		"legcib", "leglts", "legatrans",                -- radar, light transport, medium transport
	},
	-- T2 air
	armaap = {
		"armaca", "armhawk", "armbrawl", "armpnix",           -- T2 con, fig, gunship, bomber
		"armawac", "armdfly", "armlance", "armsfig2",                -- radar, transport, torpedo, heavy fighter (mod)
		"armliche", "armblade", "armstil",                    -- liche, blade, stiletto
	},

	coraap = {
		"coraca", "corvamp", "corape", "corhurc",              -- T2 con, fig, gunship, bomber
		"corawac", "corseah", "cortitan", "corsfig2",                 -- radar, transport, torpedo, heavy fighter (mod)
		"corcrw","corcrwh",                                              -- krow
	},
	legaap = {
		"legaca", "legafigdef", "legvenator", "legphoenix",					--T2 con, defensive fig, interceptor, phoenix
		"legwhisper", "legstronghold", "legatorpbomber", "",			--radar, transport(gunship), torpedo,
		"legfort", "", "legmineb", ""			--flying fort, empty, minebomber
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
		"armcs", "armrecl", "armdecade", "",              -- T1 sea con, rez sub, decade
		"armpship", "armroy", "", "",                    -- frigate, destroyer, transport ("armtship",)
		"armsub", "", "armpt",                            -- sub, PT boat
	},

	corsy = {
		"corcs", "correcl", "coresupp", "",               -- T1 sea con, rez sub, supporter, missile boat
		"corpship", "corroy", "", "",                    -- frigate, destroyer, transport ("cortship",)
		"corsub", "", "corpt",                            -- sub, missile boat
	},
	-- T2 boats
	armasy = {
		"armacsub", "armmls", "armcrus", "armmship",         -- T2 con sub, naval engineer, cruiser, rocket ship
		"armcarry", "armsjam", "armbats", "armepoch",        -- carrier, jammer, battleship, flagship
		"armsubk", "armserp", "armaas",                      -- sub killer, battlesub, AA
	},

	corasy = {
		"coracsub", "cormls", "corcrus", "cormship",              -- T2 con sub, naval engineer, cruiser, rocket ship
		"corcarry", "corsjam", "corbats", "corblackhy",            -- carrier, jammer, battleship, flagship
		"corshark", "corssub", "corarch",                          -- sub killer, battlesub, AA
	},
	-- amphibious labs
	armamsub = {
		"armbeaver", "armdecom", "armpincer", "",
		"armcroc", "", "", "",
		"", "armjeth", "armaak",
	},

	coramsub = {
		"cormuskrat", "cordecom", "corgarp", "",
		"corseal", "corparrow", "", "",
		"", "corcrash", "coraak",
	},

	legamphlab = {
		"legotter", "legdecom", "legamphtank", "", 		-- amphibious con, decoy com, t1 amphibious tank, idk
		"",         "legfloat", "legamph",            "", 		-- idk, t2 floating tank, idk, idk
		"",         "legaabot", "legadvaabot",      "",		-- idk, t1 aa bot, t2 aa bot, idk
	},
	-- hover labs
	armhp = {
		"armch", "", "armsh", "",              -- hover con, seeker
		"armanac", "armmh", "", "",            -- crocodile, possum
		"", "", "armah",                       -- hover AA
	},

	corhp = {
		"corch", "", "corsh", "",              -- hover con, goon
		"corsnap", "cormh", "corhal", "",      -- cayman, mangonel, halberd
		"", "", "corah",                       -- hover AA
	},

		leghp = {
		"legch", "", "legsh", "",              -- hover con, glaucus
		"legner", "legmh", "legcar", "",       -- nereus, salacia, cardea
		"", "", "legah",                       -- hover AA
	},
	-- naval hover labs
	armfhp = {
		"armch", "", "armsh", "",
		"armanac", "armmh", "", "",
		"", "", "armah",
	},

	corfhp = {
		"corch", "", "corsh", "",
		"corsnap", "cormh", "corhal", "",
		"", "", "corah",
	},

	legfhp = {
		"legch", "", "legsh", "",              -- hover con, glaucus
		"legner", "legmh", "legcar", "",       -- nereus, salacia, cardea
		"", "", "legah",                       -- hover AA
	},
	-- T3 labs
	armshltx = {
		"armmar", "armraz", "armvang", "armthor",        -- marauder, razorback, vanguard, thor
		"armbanth", "armlun",                            -- titan, lunkhead
	},
	corgant = {
		"corcat", "corkarg", "corshiva", "corkorg",      -- catapult, Karganeth, shiva, juggernaut
		"corjugg", "corsok",                             -- behemoth, cataphract
	},
	leggant = {
		"legjav", "legkeres", "legeallterrainmech", "legeheatraymech",        -- javelin, keres, myrmidon, sol invictus
		"legelrpcmech", "legehovertank", "legeshotgunmech", "legerailtank",   -- astraeus, charybdis, praetorian, daedalus
	},
	-- T3 underwater labs
	armshltxuw = {
		"armbantha", "armmar", "armcroc", "armlun",                 -- titan, marauder, turtle, lunkhead
	},

	corgantuw = {
		"corkorg", "corshiva", "corsala", "corparrow",              -- juggernaut, shiva, salamander, poison arrow
		"corsok",                                                   -- cataphract
	},
}
local unitGrids = {
	-- Air assist drones
	armassistdrone = {
		{
			{ "armmex", "armsolar", "armwin", },              -- mex, solar, wind
			{ "armmakr", "", "armuwms", "armtide"},             -- T1 converter, uw m storage, tidal
			{ "armestor", "armmstor", "armuwes", "armfmkr", }, -- e storage, m storage, uw e storage, floating converter
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
			{ "legmex", "legsolar", "legwin", },                -- mex, solar, wind
			{ "legeconv", "", "leguwmstore", "legtide"},             -- T1.5 mex, uw m storage, tidal
			{ "legestor", "legmstor", "leguwestore", "legfeconv",  }, -- e storage, m sotrage, uw e storage, floating converter
			{ "legeconv", "", "leguwmstore", "legtide"},             -- T1.5 mex, uw m storage, tidal
			{ "legestor", "legmstor", "leguwestore", "legfeconv",  }, -- e storage, m sotrage, uw e storage, floating converter
			{ "legeconv", "", "leguwmstore", "legtide"},             -- T1.5 mex, uw m storage, tidal
			{ "legestor", "legmstor", "leguwestore", "legfeconv",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "leglht", "legtl", },                          -- LLT, offshore torp launcher
			{ "legrl", "legfrl", },                          -- basic AA, floating AA
			{ "legctl", },                                    -- coastal torp launcher
		},
		{
			{ "legrad", "legeyes", "legdrag", },             -- radar, perimeter camera, dragon's teeth
			{ "legfrad", "legfdrag", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "leghp", "legfhp", },                          -- hover lab, floating hover lab
		}
	},
	-- Land assist drones (mini amphibs)
	armassistdrone_land = {
		{
			{ "armmex", "armsolar", "armwin", },               -- mex, solar, wind
			{ "armmakr", "", "armuwms", "armtide"},            -- T1 converter, uw m storage, tidal
			{ "armestor", "armmstor", "armuwes", "armfmkr", }, -- e storage, m storage, uw e storage, floating converter
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
			{ "legmex", "legsolar", "legwin", },                -- mex, solar, wind
			{ "legeconv", "", "leguwmstore", "legtide"},             -- T1.5 mex, uw m storage, tidal
			{ "legestor", "legmstor", "leguwestore", "legfeconv",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "leglht", "legtl", },                          -- LLT, offshore torp launcher
			{ "legrl", "legfrl", },                          -- basic AA, floating AA
			{ "legctl", },                                    -- coastal torp launcher
		},
		{
			{ "legrad", "legeyes", "legdrag", },             -- radar, perimeter camera, dragon's teeth
			{ "legfrad", "legfdrag", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "leghp", "legfhp", },                          -- hover lab, floating hover lab
		}
	},
	-- Commanders
	armcom = {
		{
			{ "armmex", "armsolar", "armwin", },              -- mex, solar, wind
			{ "armmakr", "", "armuwms", "armtide"},           -- T1 converter, uw m storage, tidal
			{ "armestor", "armmstor", "armuwes", "armfmkr", }, -- e storage, m storage, uw e storage, floating converter
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
	armcomlvl2 = {
		{
			{ "armmex", "armsolar", "armwin", },              -- mex, solar, wind
			{ "armmakr", "", "armuwms", "armtide"},           -- T1 converter, uw m storage, tidal
			{ "armestor", "armmstor", "armuwes", "armfmkr", }, -- e storage, m storage, uw e storage, floating converter
		},
		{
			{ "armllt", "armbeamer", "armhlt", "", },  		  -- LLT, beamer, HLT
			{ "armrl", "armferret", "armcir", "armfrt",},     -- basic AA, ferret, chainsaw, floating AA
			{ "armdl", "armguard", "armtl", "armfrock"},               -- coastal torp launcher, guardian, offshore torp launcher, floating HLT
		},
		{
			{ "armrad", "armeyes", "armdrag", },             -- radar, perimeter camera, dragon's teeth
			{ "armfrad", "armfdrag", },                      -- floating radar, shark's teeth
			{ "", "armmine1", "armmine2", "armmine3", },     -- empty, Lmine, Mmine, Hmine
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "armhp", "armfhp", },                          -- hover lab, floating hover lab
		}
	},
	armcomlvl3 = {
		{
			{ "armmex", "armsolar", "armwin", "armadvsol", },  -- mex, solar, wind, adv. solar
			{ "armmakr", "armgeo", "armamex", "armtide",  },   -- T1 converter, geo, twilight, (tidal)
			{ "armestor", "armmstor", "armuwes", "armfmkr", }, -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "armllt", "armbeamer", "armhlt", "armclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armrl", "armferret", "", "armfrt",},     -- basic AA, ferret, chainsaw, floating AA
			{ "armdl", "armguard", "armtl", "armfrock"},     -- coastal torp launcher, guardian, offshore torp launcher, floating HLT
		},
		{
			{ "armrad", "armeyes", "armdrag", "armjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "armfrad", "armfdrag", },                       -- floating radar, shark's teeth
			{ "armjuno", "armmine1", "armmine2", "armmine3", },-- juno, Lmine, Mmine, Hmine
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "", "armnanotcplat", },      -- nano, empty, floating nano
			{ "armhp", "armfhp", "", "armdecom",},      -- hover lab, floating hover lab, empty, decoy commander
		}
	},
	armcomlvl4 = {
		{
			{ "armmex", "armsolar", "armwin", "armadvsol", },  -- mex, solar, wind, adv. solar
			{ "armmakr", "armgeo", "armamex", "armtide",  },   -- T1 converter, geo, twilight, (tidal)
			{ "armestor", "armmstor", "armuwes", "armfmkr", }, -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "armpb", "armbeamer", "armhlt", "armclaw", },  -- pitbull, beamer, HLT, lightning turret
			{ "armrl", "armferret", "armcir", "armfrt",},     -- basic AA, ferret, chainsaw, floating AA
			{ "armdl", "armamb", "armtl", },     -- coastal torp launcher, rattlesnake, offshore torp launcher,
		},
		{
			{ "armrad", "armeyes", "armdrag", "armjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "armfrad", "armfdrag", },                       -- floating radar, shark's teeth
			{ "armjuno", "armmine1", "armmine2", "armmine3", },-- juno, Lmine, Mmine, Hmine
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "", "armnanotcplat", },      -- nano, empty, floating nano
			{ "armhp", "armfhp", "", "armdecom",},      -- hover lab, floating hover lab, empty, decoy commander
		}
	},
	armcomlvl5 = {
		{
			{ "armmoho", "armfus", "armafus", "armadvsol", },             -- moho, fusion, afus, advsolar
			{ "armmmkr", "armageo", "armamex", "armtide" },      -- T2 converter, T2 geo, twilight, tidal
			{ "armuwadves", "armuwadvms", "armuwmme", "armuwmmm",},--hardened energy storage, hardened metal storage, uw t2 metal extract, floating adv Econverter
		},
		{
			{ "armpb", "armanni", "armamb", "armclaw", },        -- pop-up gauss, annihilator, pop-up artillery, dragonclaw
			{ "armflak", "armmercury", "armbeamer", "armfflak", },-- flak, long-range AA, beamer, floating flak
			{ "armdl", "", "armatl", },              	-- coastal torpedo launcher, empty, adv torpedo launcher
		},
		{
			{ "armarad", "armeyes", "armfort", "armjamt" },     -- adv radar, camera, t2 wall, cloak jammer
			{ "armfrad", "armfdrag", "armdrag", "armasp" },    -- intrusion counter, decoy fusion, air repair pad
			{ "armjuno", "armmine1", "armmine2", "armmine3", },-- juno, Lmine, Mmine, Hmine
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "", "armnanotcplat", },      -- nano, empty, floating nano
			{ "armhp", "armfhp", "", "armdecom",},      -- hover lab, floating hover lab, empty, decoy commander
		}
	},
	armcomlvl6 = {
		{
			{ "armmoho", "armfus", "armafus", "armadvsol", },             -- moho, fusion, afus, advsolar
			{ "armmmkr", "armageo", "armamex", "armtide" },      -- T2 converter, T2 geo, twilight, tidal
			{ "armuwadves", "armuwadvms", "armuwmme", "armuwmmm",},--hardened energy storage, hardened metal storage, uw t2 metal extract, floating adv Econverter
		},
		{
			{ "armpb", "armanni", "armamb", "armclaw", },        -- pop-up gauss, annihilator, pop-up artillery, dragonclaw
			{ "armflak", "armmercury", "armbeamer", "armfflak", },-- flak, long-range AA, beamer, floating flak
			{ "armdl", "", "armatl", },              	-- coastal torpedo launcher, empty, adv torpedo launcher
		},
		{
			{ "armarad", "armeyes", "armfort", "armjamt" },     -- adv radar, camera, t2 wall, cloak jammer
			{ "armfrad", "armfdrag", "armdrag", "armasp" },    -- intrusion counter, decoy fusion, air repair pad
			{ "armjuno", "armmine1", "armmine2", "armmine3", },-- juno, Lmine, Mmine, Hmine
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "", "armnanotcplat", },      -- nano, empty, floating nano
			{ "armhp", "armfhp", "", "armdecom",},      -- hover lab, floating hover lab, empty, decoy commander
		}
	},
	armcomlvl7 = {
		{
			{ "armmoho", "armfus", "armafus", "armadvsol", },             -- moho, fusion, afus, advsolar
			{ "armmmkr", "armageo", "armamex", "armtide" },      -- T2 converter, T2 geo, twilight, tidal
			{ "armuwadves", "armuwadvms", "armuwmme", "armuwmmm",},--hardened energy storage, hardened metal storage, uw t2 metal extract, floating adv Econverter
		},
		{
			{ "armpb", "armanni", "armamb", "armclaw", },        -- pop-up gauss, annihilator, pop-up artillery, dragonclaw
			{ "armflak", "armmercury", "armbeamer", "armfflak", },-- flak, long-range AA, beamer, floating flak
			{ "armdl", "", "armatl", },              	-- coastal torpedo launcher, empty, adv torpedo launcher
		},
		{
			{ "armarad", "armeyes", "armfort", "armjamt" },     -- adv radar, camera, t2 wall, cloak jammer
			{ "armfrad", "armfdrag", "armdrag", "armasp" },    -- intrusion counter, decoy fusion, air repair pad
			{ "armjuno", "armmine1", "armmine2", "armmine3", },-- juno, Lmine, Mmine, Hmine
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "", "armnanotcplat", },      -- nano, empty, floating nano
			{ "armhp", "armfhp", "", "armdecom",},      -- hover lab, floating hover lab, empty, decoy commander
		}
	},
	armcomlvl8 = {
		{
			{ "armmoho", "armfus", "armafus", "armadvsol", },             -- moho, fusion, afus, advsolar
			{ "armmmkr", "armageo", "armamex", "armtide" },      -- T2 converter, T2 geo, twilight, tidal
			{ "armuwadves", "armuwadvms", "armuwmme", "armuwmmm",},--hardened energy storage, hardened metal storage, uw t2 metal extract, floating adv Econverter
		},
		{
			{ "armpb", "armanni", "armamb", "armclaw", },        -- pop-up gauss, annihilator, pop-up artillery, dragonclaw
			{ "armflak", "armmercury", "armbeamer", "armfflak", },-- flak, long-range AA, beamer, floating flak
			{ "armdl", "", "armatl", },              	-- coastal torpedo launcher, empty, adv torpedo launcher
		},
		{
			{ "armarad", "armeyes", "armfort", "armjamt" },     -- adv radar, camera, t2 wall, cloak jammer
			{ "armfrad", "armfdrag", "armdrag", "armasp" },    -- intrusion counter, decoy fusion, air repair pad
			{ "armjuno", "armmine1", "armmine2", "armmine3", },-- juno, Lmine, Mmine, Hmine
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "", "armnanotcplat", },      -- nano, empty, floating nano
			{ "armhp", "armfhp", "", "armdecom",},      -- hover lab, floating hover lab, empty, decoy commander
		}
	},
	armcomlvl9 = {
		{
			{ "armmoho", "armfus", "armafus", "armadvsol", },             -- moho, fusion, afus, advsolar
			{ "armmmkr", "armageo", "armamex", "armtide" },      -- T2 converter, T2 geo, twilight, tidal
			{ "armuwadves", "armuwadvms", "armuwmme", "armuwmmm",},--hardened energy storage, hardened metal storage, uw t2 metal extract, floating adv Econverter
		},
		{
			{ "armpb", "armanni", "armamb", "armclaw", },        -- pop-up gauss, annihilator, pop-up artillery, dragonclaw
			{ "armflak", "armmercury", "armbeamer", "armfflak", },-- flak, long-range AA, beamer, floating flak
			{ "armdl", "", "armatl", },              	-- coastal torpedo launcher, empty, adv torpedo launcher
		},
		{
			{ "armarad", "armeyes", "armfort", "armjamt" },     -- adv radar, camera, t2 wall, cloak jammer
			{ "armfrad", "armfdrag", "armdrag", "armasp" },    -- intrusion counter, decoy fusion, air repair pad
			{ "armjuno", "armmine1", "armmine2", "armmine3", },-- juno, Lmine, Mmine, Hmine
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "", "armnanotcplat", },      -- nano, empty, floating nano
			{ "armhp", "armfhp", "", "armdecom",},      -- hover lab, floating hover lab, empty, decoy commander
		}
	},
	armcomlvl10 = {
		{
			{ "armmoho", "armfus", "armafus", "armadvsol", },             -- moho, fusion, afus, advsolar
			{ "armmmkr", "armageo", "armamex", "armtide" },      -- T2 converter, T2 geo, twilight, tidal
			{ "armuwadves", "armuwadvms", "armuwmme", "armuwmmm",},--hardened energy storage, hardened metal storage, uw t2 metal extract, floating adv Econverter
		},
		{
			{ "armpb", "armanni", "armamb", "armclaw", },        -- pop-up gauss, annihilator, pop-up artillery, dragonclaw
			{ "armflak", "armmercury", "armbeamer", "armfflak", },-- flak, long-range AA, beamer, floating flak
			{ "armdl", "", "armatl", },              	-- coastal torpedo launcher, adv torpedo launcher, lolcannon
		},
		{
			{ "armarad", "armeyes", "armfort", "armjamt" },     -- adv radar, camera, t2 wall, cloak jammer
			{ "armfrad", "armfdrag", "armdrag", "armasp" },    -- intrusion counter, decoy fusion, air repair pad
			{ "armjuno", "armmine1", "armmine2", "armmine3", },-- juno, Lmine, Mmine, Hmine
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "", "armnanotcplat", },      -- nano, empty, floating nano
			{ "armhp", "armfhp", "", "armdecom",},      -- hover lab, floating hover lab, empty, decoy commander
		}
	},
	corcom = {
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
	corcomlvl2 = {
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
			{ "corrad", "coreyes", "legdrag", },             -- radar, perimeter camera, dragon's teeth
			{ "corfrad", "corfdrag", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "corhp", "corfhp", },                          -- hover lab, floating hover lab
		}
	},
	corcomlvl3 = {
		{
			{ "cormex", "corsolar", "corwin", "coradvsol", },   -- mex, solar, wind, adv. solar
			{ "cormakr", "corgeo", "corexp", "cortide", },      -- T1 converter, geo, exploiter, (tidal)
			{ "corestor", "cormstor", "coruwes", "corfmkr", },  -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "corllt", "corhllt", "corhlt", "cormaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", "cortl", "", },       -- coastal torp launcher, punisher, offshore torp launcher, floating HLT
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "corfrad", "corfdrag", },                       -- floating radar, shark's teeth
			{ "corjuno", },                                   -- juno
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "", "cornanotcplat", },      -- nano, floating nano
			{ "corhp", "corfhp", "", "corplat", },    -- hover lab, floating hover lab, seaplane lab
		}
	},
	corcomlvl4 = {
		{
			{ "cormex", "corsolar", "corwin", "coradvsol", },   -- mex, solar, wind, adv. solar
			{ "cormakr", "corgeo", "corexp", "cortide", },      -- T1 converter, geo, exploiter, (tidal)
			{ "corestor", "cormstor", "coruwes", "corfmkr", },  -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "corllt", "corhllt", "corhlt", "cormaw", },     -- LLT, Double LLT, HLT, flame turret
			{ "corrl", "cormadsam", "corerad", },             -- basic AA, SAM, eradicator
			{ "cordl", "corpun", "cortl", "", },       -- coastal torp launcher, punisher, offshore torp launcher, floating HLT
		},
		{
			{ "corrad", "coreyes", "cordrag", "corjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "corfrad", "corfdrag", },                       -- floating radar, shark's teeth
			{ "corjuno", },                                   -- juno
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "", "cornanotcplat", },      -- nano, floating nano
			{ "corhp", "corfhp", "", "corplat", },    -- hover lab, floating hover lab, seaplane lab
		}
	},
	corcomlvl5 = {
		{
			{ "cormoho", "corfus", "corwin", "coradvsol",},  -- moho, fusion, afus, adv solar
			{ "cormmkr", "corageo", "cormexp", "cortide" }, -- T2 converter, T2 geo, armed moho, tidal generator
			{ "coruwadves", "coruwadvms", "coruwmme","coruwmmm",}, -- hardened energy storage, hardened metal storage, uw metal extractor, floating metalmaker
		},
		{
			{ "corvipe", "cordoom", "cortoast", "cormaw", },   -- pop-up gauss, DDM, pop-up artillery, dragon maw
			{ "corflak", "corscreamer", "corhllt", "cornaa", }, -- flak, long-range AA, twin guard, floating flak
			{ "cordl", "", "coratl", },                			-- coastal torpedo launcher, empty, adv torpedo launcher
		},
		{
			{ "corarad", "coreyes", "corfort", "corshroud", },  -- adv radar, camera, t2wall, adv jammer
			{ "corfrad", "corfdrag", "cordrag", "" },     --floating radar, floating dragteeth, drag teeth, air repair pad
			{ "corjuno", },                                     -- juno
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "", "cornanotcplat", },      -- nano, floating nano
			{ "corhp", "corfhp", "", "corplat", },    -- hover lab, floating hover lab, seaplane lab
		}
	},
	corcomlvl6 = {
		{
			{ "cormoho", "corfus", "corwin", "coradvsol",},  -- moho, fusion, afus, adv solar
			{ "cormmkr", "corageo", "cormexp", "cortide" }, -- T2 converter, T2 geo, armed moho, tidal generator
			{ "coruwadves", "coruwadvms", "coruwmme","coruwmmm",}, -- hardened energy storage, hardened metal storage, uw metal extractor, floating metalmaker
		},
		{
			{ "corvipe", "cordoom", "cortoast", "cormaw", },   -- pop-up gauss, DDM, pop-up artillery, dragon maw
			{ "corflak", "corscreamer", "corhllt", "cornaa", }, -- flak, long-range AA, twin guard, floating flak
			{ "cordl", "", "coratl", },                			-- coastal torpedo launcher, empty, adv torpedo launcher
		},
		{
			{ "corarad", "coreyes", "corfort", "corshroud", },  -- adv radar, camera, t2wall, adv jammer
			{ "corfrad", "corfdrag", "cordrag", "" },     --floating radar, floating dragteeth, drag teeth, air repair pad
			{ "corjuno", },                                     -- juno
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "", "cornanotcplat", },      -- nano, floating nano
			{ "corhp", "corfhp", "", "corplat", },    -- hover lab, floating hover lab, seaplane lab
		}
	},
	corcomlvl7 = {
		{
			{ "cormoho", "corfus", "corwin", "coradvsol",},  -- moho, fusion, afus, adv solar
			{ "cormmkr", "corageo", "cormexp", "cortide" }, -- T2 converter, T2 geo, armed moho, tidal generator
			{ "coruwadves", "coruwadvms", "coruwmme","coruwmmm",}, -- hardened energy storage, hardened metal storage, uw metal extractor, floating metalmaker
		},
		{
			{ "corvipe", "cordoom", "cortoast", "cormaw", },   -- pop-up gauss, DDM, pop-up artillery, dragon maw
			{ "corflak", "corscreamer", "corhllt", "cornaa", }, -- flak, long-range AA, twin guard, floating flak
			{ "cordl", "", "coratl", },                			-- coastal torpedo launcher, empty, adv torpedo launcher
		},
		{
			{ "corarad", "coreyes", "corfort", "corshroud", },  -- adv radar, camera, t2wall, adv jammer
			{ "corfrad", "corfdrag", "cordrag", "" },     --floating radar, floating dragteeth, drag teeth, air repair pad
			{ "corjuno", },                                     -- juno
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "", "cornanotcplat", },      -- nano, floating nano
			{ "corhp", "corfhp", "", "corplat", },    -- hover lab, floating hover lab, seaplane lab
		}
	},
	corcomlvl8 = {
		{
			{ "cormoho", "corfus", "corwin", "coradvsol",},  -- moho, fusion, afus, adv solar
			{ "cormmkr", "corageo", "cormexp", "cortide" }, -- T2 converter, T2 geo, armed moho, tidal generator
			{ "coruwadves", "coruwadvms", "coruwmme","coruwmmm",}, -- hardened energy storage, hardened metal storage, uw metal extractor, floating metalmaker
		},
		{
			{ "corvipe", "cordoom", "cortoast", "cormaw", },   -- pop-up gauss, DDM, pop-up artillery, dragon maw
			{ "corflak", "corscreamer", "corhllt", "cornaa", }, -- flak, long-range AA, twin guard, floating flak
			{ "cordl", "", "coratl", },                			-- coastal torpedo launcher, empty, adv torpedo launcher
		},
		{
			{ "corarad", "coreyes", "corfort", "corshroud", },  -- adv radar, camera, t2wall, adv jammer
			{ "corfrad", "corfdrag", "cordrag", "" },     --floating radar, floating dragteeth, drag teeth, air repair pad
			{ "corjuno", },                                     -- juno
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "", "cornanotcplat", },      -- nano, floating nano
			{ "corhp", "corfhp", "", "corplat", },    -- hover lab, floating hover lab, seaplane lab
		}
	},
	corcomlvl9 = {
		{
			{ "cormoho", "corfus", "corwin", "coradvsol",},  -- moho, fusion, afus, adv solar
			{ "cormmkr", "corageo", "cormexp", "cortide" }, -- T2 converter, T2 geo, armed moho, tidal generator
			{ "coruwadves", "coruwadvms", "coruwmme","coruwmmm",}, -- hardened energy storage, hardened metal storage, uw metal extractor, floating metalmaker
		},
		{
			{ "corvipe", "cordoom", "cortoast", "cormaw", },   -- pop-up gauss, DDM, pop-up artillery, dragon maw
			{ "corflak", "corscreamer", "corhllt", "cornaa", }, -- flak, long-range AA, twin guard, floating flak
			{ "cordl", "", "coratl", },                			-- coastal torpedo launcher, empty, adv torpedo launcher
		},
		{
			{ "corarad", "coreyes", "corfort", "corshroud", },  -- adv radar, camera, t2wall, adv jammer
			{ "corfrad", "corfdrag", "cordrag", "" },     --floating radar, floating dragteeth, drag teeth, air repair pad
			{ "corjuno", },                                     -- juno
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "", "cornanotcplat", },      -- nano, floating nano
			{ "corhp", "corfhp", "", "corplat", },    -- hover lab, floating hover lab, seaplane lab
		}
	},
	corcomlvl10 = {
		{
			{ "cormoho", "corfus", "corwin", "coradvsol",},  -- moho, fusion, afus, adv solar
			{ "cormmkr", "corageo", "cormexp", "cortide" }, -- T2 converter, T2 geo, armed moho, tidal generator
			{ "coruwadves", "coruwadvms", "coruwmme","coruwmmm",}, -- hardened energy storage, hardened metal storage, uw metal extractor, floating metalmaker
		},
		{
			{ "corvipe", "cordoom", "cortoast", "cormaw", },   -- pop-up gauss, DDM, pop-up artillery, dragon maw
			{ "corflak", "corscreamer", "corhllt", "cornaa", }, -- flak, long-range AA, twin guard, floating flak
			{ "cordl", "", "coratl", },                			-- coastal torpedo launcher, empty, adv torpedo launcher
		},
		{
			{ "corarad", "coreyes", "corfort", "corshroud", },  -- adv radar, camera, t2wall, adv jammer
			{ "corfrad", "corfdrag", "cordrag", "" },     --floating radar, floating dragteeth, drag teeth, air repair pad
			{ "corjuno", },                                     -- juno
		},
		{
			{ "corlab", "corvp", "corap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "cornanotc", "", "cornanotcplat", },      -- nano, floating nano
			{ "corhp", "corfhp", "", "corplat", },    -- hover lab, floating hover lab, seaplane lab
		}
	},

	-- legion commanders
    legcom = {
		{
			{ "legmex", "legsolar", "legwin", },                -- mex, solar, wind
			{ "legeconv", "", "leguwmstore", "legtide"},             -- T1.5 mex, uw m storage, tidal
			{ "legestor", "legmstor", "leguwestore", "legfeconv",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "leglht", "legtl", },                          -- LLT, offshore torp launcher
			{ "legrl", "legfrl", },                          -- basic AA, floating AA
			{ "legctl", },                                    -- coastal torp launcher
		},
		{
			{ "legrad", "legeyes", "legdrag", },             -- radar, perimeter camera, dragon's teeth
			{ "legfrad", "legfdrag", },                      -- floating radar, shark's teeth
			{ },                                             -- empty
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "leghp", "legfhp", },                          -- hover lab, floating hover lab
		}
	},
	legcomlvl2 = {
		{
			{ "legmex", "legsolar", "legwin", },                -- mex, solar, wind
			{ "legeconv", "", "leguwmstore", "legtide"},             -- T1.5 mex, uw m storage, tidal
			{ "legestor", "legmstor", "leguwestore", "legfeconv",  }, -- e storage, m sotrage, uw e storage, floating converter
		},
		{
			{ "leglht", "legtl", "leggob", "leglob",},       -- LLT, offshore torp launcher, goblin, lobber
			{ "legrl", "legfrl", "legrail", "legbar",},             -- basic AA, floating AA, blank, barrage
			{ "legctl", },                                    -- coastal torp launcher
		},
		{
			{ "legrad", "legeyes", "legdrag", },             -- radar, perimeter camera, dragon's teeth
			{ "legfrad", "legfdrag", },                      -- floating radar, shark's teeth
			{ },                                            -- empty
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ },                                             -- empty row
			{ "leghp", "legfhp", },                          -- hover lab, floating hover lab
		}
	},
	legcomlvl3 = {
		{
			{ "legmex", "legsolar", "legwin", "legadvsol", },   -- mex, solar, wind, adv. solar
			{ "legeconv", "leggeo", "legmext15", "legtide", },   -- T1 converter, geo, T1.5 legion mex, (tidal)
			{ "legestor", "legmstor", "leguwestore", "legfeconv", },  -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "leggat", "legbar", "legkark", "legcen", },     -- decurion, barrage, karkinos, centaur
			{ "legrl", "legrail", "legmg", "legdtr", },       -- basic AA, lance, cacophony, dragon maw
			{ "legctl", "leghive", "legtl", "", },-- coastal torp launcher, hive, offshore torp launcher, dragon tail
		},
		{
			{ "legavrad", "legeyes", "legdrag", "legavjam", }, -- radar bot, perimeter camera, dragon's teeth, jammer bot
			{ "legfrad", "legfdrag",},                       -- floating radar, shark's teeth
			{ "legjuno", "legrad", "legstronghold"},         -- juno, radar, t2 transport
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "legnanotc", "leginfestor", "legnanotcplat",}, -- nano, infestor, floating nano
			{ "leghp", "legfhp", },                          -- hover lab, floating hover lab
		}
	},
	legcomlvl4 = {
		{
			{ "legmex", "legsolar", "legwin", "legadvsol", },   -- mex, solar, wind, adv. solar
			{ "legeconv", "leggeo", "legmext15", "legtide", },   -- T1 converter, geo, T1.5 legion mex, (tidal)
			{ "legestor", "legmstor", "leguwestore", "legfeconv", },  -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "leggat", "legbart", "legshot", "legstr", },     	-- decurion, belcher, phalanx, strider
			{ "legvflak", "legmed", "legmg", "legdtr", },       	-- aa vehicle, medusa, cacophony, dragon maw
			{ "legctl", "legvcarry", "coratl", "", },		-- coastal torp launcher, mantis, offshore torp launcher, dragon tail
		},
		{
			{ "legavrad", "legeyes", "legforti", "legavjam", }, -- radar bot, perimeter camera, t2 wall, jammer bot
			{ "legfrad", "legfdrag", "legdrag", ""},    -- floating radar, sharks teeth, dragons teeth, air repair pad
			{ "legjuno", "legarad", "legstronghold"},         -- juno, radar, t2 transport
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "legnanotc", "leginfestor", "legnanotcplat",}, -- nano, infestor, floating nano
			{ "leghp", "legfhp", },                          -- hover lab, floating hover lab
		}
	},
	legcomlvl5 = {
		{
			{ "legmoho", "legfus", "legwin", "legadvsol", },   		-- adv mex, fusion, wind, adv. solar
			{ "legadveconv", "leggeo", "", "legtide", },   			-- adv metalmaker, adv geo, empty, tidal generator
			{ "legadvestore", "legamstor", "coruwmme", "coruwmmm", },-- hardened energy storage, hardened metal storage,
		},
		{
			{ "legaheattank", "leginf", "legshot", "legstr", },     	-- decurion, belcher, phalanx, strider
			{ "legvflak", "legmed", "legmg", "legdtr", },       	-- aa vehicle, medusa, cacophony, dragon maw
			{ "legctl", "legvcarry", "coratl", "", },		-- coastal torp launcher, mantis, offshore torp launcher, dragon tail
		},
		{
			{ "legavrad", "legeyes", "legforti", "legavjam", }, -- radar bot, perimeter camera, t2 wall, jammer bot
			{ "legfrad", "legfdrag", "legdrag", ""},    -- floating radar, sharks teeth, dragons teeth, air repair pad
			{ "legjuno", "legarad", "legstronghold"},         -- juno, radar, t2 transport
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "legnanotc", "leginfestor", "legnanotcplat",}, -- nano, infestor, floating nano
			{ "leghp", "legfhp", },                          -- hover lab, floating hover lab
		}
	},
	legcomlvl6 = {
		{
			{ "legmoho", "legfus", "legwin", "legadvsol", },   		-- adv mex, fusion, wind, adv. solar
			{ "legadveconv", "leggeo", "", "legtide", },   			-- adv metalmaker, adv geo, empty, tidal generator
			{ "legadvestore", "legamstor", "coruwmme", "coruwmmm", },-- hardened energy storage, hardened metal storage,
		},
		{
			{ "legaheattank", "leginf", "legshot", "legmrv", },     	-- decurion, belcher, phalanx, quickshot
			{ "legvflak", "legmed", "legmg", "legkeres", },       	-- aa vehicle, medusa, cacophony, keres
			{ "legctl", "legvcarry", "coratl", "legdtr", },		-- coastal torp launcher, mantis, offshore torp launcher, dragon tail
		},
		{
			{ "legavrad", "legeyes", "legforti", "legajam", }, -- radar bot, perimeter camera, t2 wall, jammer bot
			{ "legfrad", "legfdrag", "legdrag", ""},    -- floating radar, sharks teeth, dragons teeth, air repair pad
			{ "legjuno", "legarad", "legstronghold"},         -- juno, radar, t2 transport
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "legnanotc", "leginfestor", "legnanotcplat",}, -- nano, infestor, floating nano
			{ "leghp", "legfhp", },                          -- hover lab, floating hover lab
		}
	},
	legcomlvl7 = {
		{
			{ "legmoho", "legfus", "legwin", "legadvsol", },   		-- adv mex, fusion, wind, adv. solar
			{ "legadveconv", "leggeo", "", "legtide", },   			-- adv metalmaker, adv geo, empty, tidal generator
			{ "legadvestore", "legamstor", "coruwmme", "coruwmmm", },-- hardened energy storage, hardened metal storage,
		},
		{
			{ "legaheattank", "leginf", "legshot", "legmrv", },     	-- decurion, belcher, phalanx, quickshot
			{ "corsent", "legmed", "legmg", "legkeres", },       	-- aa vehicle, medusa, cacophony, keres
			{ "legctl", "legvcarry", "coratl", "legdtr", },		-- coastal torp launcher, mantis, offshore torp launcher, dragon tail
		},
		{
			{ "legavrad", "legeyes", "legforti", "legavjam", }, -- radar bot, perimeter camera, t2 wall, jammer bot
			{ "legfrad", "legfdrag", "legdrag", ""},    -- floating radar, sharks teeth, dragons teeth, air repair pad
			{ "legjuno", "legarad", "legstronghold"},         -- juno, radar, t2 transport
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "legnanotc", "leginfestor", "legnanotcplat",}, -- nano, infestor, floating nano
			{ "leghp", "legfhp", },                          -- hover lab, floating hover lab
		}
	},
	legcomlvl8 = {
		{
			{ "legmoho", "legfus", "legwin", "legadvsol", },   		-- adv mex, fusion, wind, adv. solar
			{ "legadveconv", "leggeo", "", "legtide", },   			-- adv metalmaker, adv geo, empty, tidal generator
			{ "legadvestore", "legamstor", "coruwmme", "coruwmmm", },-- hardened energy storage, hardened metal storage,
		},
		{
			{ "legaheattank", "leginf", "legshot", "legmrv", },     	-- decurion, belcher, phalanx, quickshot
			{ "legvflak", "legmed", "legmg", "legkeres", },       	-- aa vehicle, medusa, cacophony, keres
			{ "legctl", "legvcarry", "coratl", "legdtr", },		-- coastal torp launcher, mantis, offshore torp launcher, dragon tail
		},
		{
			{ "legavrad", "legeyes", "legforti", "legavjam", }, -- radar bot, perimeter camera, t2 wall, jammer bot
			{ "legfrad", "legfdrag", "legdrag", ""},    -- floating radar, sharks teeth, dragons teeth, air repair pad
			{ "legjuno", "legarad", "legstronghold"},         -- juno, radar, t2 transport
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "legnanotc", "leginfestor", "legnanotcplat",}, -- nano, infestor, floating nano
			{ "leghp", "legfhp", },                          -- hover lab, floating hover lab
		}
	},
	legcomlvl9 = {
		{
			{ "legmoho", "legfus", "legwin", "legadvsol", },   		-- adv mex, fusion, wind, adv. solar
			{ "legadveconv", "leggeo", "", "legtide", },   			-- adv metalmaker, adv geo, empty, tidal generator
			{ "legadvestore", "legamstor", "coruwmme", "coruwmmm", },-- hardened energy storage, hardened metal storage,
		},
		{
			{ "legaheattank", "leginf", "legshot", "legmrv", },     	-- decurion, belcher, phalanx, quickshot
			{ "legvflak", "legmed", "legmg", "legkeres", },       	-- aa vehicle, medusa, cacophony, keres
			{ "legctl", "legvcarry", "coratl", "legeshotgunmech", },		-- coastal torp launcher, mantis, offshore torp launcher, praetorian
		},
		{
			{ "legavrad", "legeyes", "legforti", "legavjam", }, -- radar bot, perimeter camera, t2 wall, jammer bot
			{ "legfrad", "legfdrag", "legdrag", ""},    -- floating radar, sharks teeth, dragons teeth, air repair pad
			{ "legjuno", "legarad", "legstronghold"},         -- juno, radar, t2 transport
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "legnanotc", "leginfestor", "legnanotcplat",}, -- nano, infestor, floating nano
			{ "leghp", "legfhp", },                          -- hover lab, floating hover lab
		}
	},
	legcomlvl10 = {
		{
			{ "legmoho", "legfus", "legwin", "legadvsol", },   		-- adv mex, fusion, wind, adv. solar
			{ "legadveconv", "leggeo", "", "legtide", },   			-- adv metalmaker, adv geo, empty, tidal generator
			{ "legadvestore", "legamstor", "coruwmme", "coruwmmm", },-- hardened energy storage, hardened metal storage,
		},
		{
			{ "legaheattank", "leginf", "legshot", "legmrv", },     	-- decurion, belcher, phalanx, quickshot
			{ "legvflak", "legmed", "legmg", "legkeres", },       	-- aa vehicle, medusa, cacophony, keres
			{ "legctl", "legvcarry", "coratl", "legeshotgunmech", },		-- coastal torp launcher, mantis, offshore torp launcher, praetorian
		},
		{
			{ "legavrad", "legeyes", "legforti", "legavjam", }, -- radar bot, perimeter camera, t2 wall, jammer bot
			{ "legfrad", "legfdrag", "legdrag", ""},    -- floating radar, sharks teeth, dragons teeth, air repair pad
			{ "legjuno", "legarad", "legstronghold"},         -- juno, radar, t2 transport
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },        -- bot lab, veh lab, air lab, shipyard
			{ "legnanotc", "leginfestor", "legnanotcplat",}, -- nano, infestor, floating nano
			{ "leghp", "legfhp", },                          -- hover lab, floating hover lab
		}
	},
	-- T1 bot con
	armck = {
		{
			{ "armmex", "armsolar", "armwin", "armadvsol", },  -- mex, solar, wind, adv. solar
			{ "armmakr", "armgeo", "armamex", },               -- T1 converter, geo, twilight, (tidal)
			{ "armestor", "armmstor", },                       -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "armllt", "armbeamer", "armhlt", "armclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armrl", "armferret", "armcir", },              -- basic AA, ferret, chainsaw
			{ "armdl", "armguard", },                         -- coastal torp launcher, guardian
		},
		{
			{ "armrad", "armeyes", "armdrag", "armjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ },
			{ "armjuno", },                                   -- juno
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "armalab", },                      -- nano, T2 lab
			{ "armhp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
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
			{ "legmex", "legsolar", "legwin", "legadvsol", },   -- mex, solar, wind, adv. solar
			{ "legeconv", "leggeo", "legmext15", },              -- T1 converter, geo, T1.5 legion mex, (tidal)
			{ "legestor", "legmstor", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "leglht", "legmg", "leghive", "legdtr", },     	-- LLT, machine gun, hive, riot turret
			{ "legrl", "legrhapsis", "leglupara", },            -- basic AA, SAM, eradicator
			{ "legctl", "legcluster", },                        -- coastal torp launcher, punisher
		},
		{
			{ "legrad", "legeyes", "legdrag", "legjam", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "", "", "", "" },                  --  
			{ "legjuno", },                                   -- juno
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "legnanotc", "legalab", },                      -- nano, T2 lab
			{ "leghp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	-- T1 vehicle con
	armcv = {
		{
			{ "armmex", "armsolar", "armwin", "armadvsol", },  -- mex, solar, wind, adv. solar
			{ "armmakr", "armgeo", "armamex", },               -- T1 converter, geo, twilight, (tidal)
			{ "armestor", "armmstor", },                       -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "armllt", "armbeamer", "armhlt", "armclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armrl", "armferret", "armcir", },              -- basic AA, ferret, chainsaw
			{ "armdl", "armguard", },                         -- coastal torp launcher, guardian
		},
		{
			{ "armrad", "armeyes", "armdrag", "armjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ },
			{ "armjuno", },                                   -- juno
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "armavp", },                       -- nano, T2 lab
			{ "armhp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
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
			{ "legmex", "legsolar", "legwin", "legadvsol", },   -- mex, solar, wind, adv. solar
			{ "legeconv", "leggeo", "legmext15", },              -- T1 converter, geo, T1.5 legion mex, (tidal)
			{ "legestor", "legmstor", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "leglht", "legmg", "leghive", "legdtr", },     	-- LLT, machine gun, hive, riot turret
			{ "legrl", "legrhapsis", "leglupara", },             -- basic AA, SAM, eradicator
			{ "legctl", "legcluster", },                           -- coastal torp launcher, punisher
		},
		{
			{ "legrad", "legeyes", "legdrag", "legjam", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "", "", "", "" },                  --  
			{ "legjuno", },                                   -- juno
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "legnanotc", "coralab", },                      -- nano, T2 lab
			{ "leghp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},
	-- T1 air con
	armca = {
		{
			{ "armmex", "armsolar", "armwin", "armadvsol", },  -- mex, solar, wind, adv. solar
			{ "armmakr", "armgeo", "armamex", },               -- T1 converter, geo, twilight, (tidal)
			{ "armestor", "armmstor", },                       -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "armllt", "armbeamer", "armhlt", "armclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armrl", "armferret", "armcir", },              -- basic AA, ferret, chainsaw
			{ "armdl", "armguard", },                         -- coastal torp launcher, guardian
		},
		{
			{ "armrad", "armeyes", "armdrag", "armjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "", "", "", "" },                  --  
			{ "armjuno", }									  -- juno
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "armaap", },                       -- nano, T2 lab
			{ "armhp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
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
			{ "", "", "", "" },                  --  
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
			{ "legmex", "legsolar", "legwin", "legadvsol", },   -- mex, solar, wind, adv. solar
			{ "legeconv", "leggeo", "legmext15", },              -- T1 converter, geo, T1.5 legion mex, (tidal)
			{ "legestor", "legmstor", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "leglht", "legmg", "leghive", "legdtr", },     	-- LLT, machine gun, hive, riot turret
			{ "legrl", "legrhapsis", "leglupara", },             -- basic AA, SAM, eradicator
			{ "legctl", "legcluster", },                           -- coastal torp launcher, punisher
		},
		{
			{ "legrad", "legeyes", "legdrag", "legjam", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "", "", "", "" },                  --  
			{ "legjuno", },                                   -- juno
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "legnanotc", "legaap", },                      -- nano, T2 lab
			{ "leghp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},
	-- T1 sea con
	armcs = {
		{
			{ "armmex", "armtide", },                         -- mex, tidal
			{ "armfmkr", "armgeo", },                         -- floating T1 converter, geo
			{ "armuwes", "armuwms", },                        -- uw e stor, uw m stor
		},
		{
			{ "armtl", "armfhlt", "", "armclaw", },           -- offshore torp launcher, floating HLT
			{ "armfrt", },                                    -- floating AA
			{ "armdl", "armguard", },              			  -- coastal torp launcher, guardian, lightning turret
		},
		{
			{ "armfrad", "armeyes","armfdrag", },             -- floating radar, perimeter camera, shark's teeth
			{ "", "armdrag", "", ""},                        	      -- dragon's teeth
		},
		{
			{ "armsy", "armvp", "armap", "armlab", },         -- shipyard, veh lab, air lab, bot lab
			{ "armnanotcplat", "armasy", },                   -- floating nano, T2 shipyard
			{ "armfhp", "", "armamsub", "armplat", },         -- floating hover lab, amphibious lab, seaplane lab
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
			{ "", "cordrag", "", "" },           -- dragon's teeth
		},
		{
			{ "corsy", "corvp", "corap", "corlab",  },        -- shipyard, vehicle lab, air lab, bot lab
			{ "cornanotcplat", "corasy", },                   -- floating nano, T2 shipyard
			{ "corfhp", "", "coramsub", "corplat",  },        -- floating hover, amphibious lab, seaplane lab
		}
	},

	-- Hover cons
	armch = {
		{
			{ "armmex", "armsolar", "armwin", "armadvsol", },  -- mex, solar, wind, adv. solar
			{ "armmakr", "armgeo", "armamex", "armtide",  },   -- T1 converter, geo, twilight, (tidal)
			{ "armestor", "armmstor", "armuwes", "armfmkr", }, -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "armllt", "armbeamer", "armhlt", "armclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armrl", "armferret", "armcir", "armfrt",},     -- basic AA, ferret, chainsaw, floating AA
			{ "armdl", "armguard", "armtl", "armfhlt", },     -- coastal torp launcher, guardian, offshore torp launcher, floating HLT
		},
		{
			{ "armrad", "armeyes", "armdrag", "armjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "armfrad", "armfdrag", },                       -- floating radar, shark's teeth
			{ "armjuno", },                                   -- juno
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "armavp", "armnanotcplat", "armasy",  },    -- nano, T2 veh lab, floating nano, T2 shipyard
			{ "armhp", "armfhp", "armamsub", "armplat", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
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

	legch = {
		{
			{ "legmex", "legsolar", "legwin", "legadvsol", },   -- mex, solar, wind, adv. solar
			{ "legeconv", "leggeo", "legmext15", "legtide", },              -- T1 converter, geo, T1.5 legion mex, (tidal)
			{ "legestor", "legmstor", "leguwestore", "legfeconv", },  -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "leglht", "legmg", "leghive", "legdtr", },     	-- LLT, machine gun, hive, riot turret
			{ "legrl", "legrhapsis", "leglupara", "legfrl" },             -- basic AA, rhapsis, t1.5 flak, floating AA
			{ "legctl", "legcluster", "legtl", "legfmg", },       -- coastal torp launcher, amputator, offshore torp launcher, floating HLT
		},
		{
			{ "legrad", "legeyes", "legdrag", "legjam", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "legfrad", "legfdrag", },                       -- floating radar, shark's teeth
			{ "legjuno", },                                   -- juno
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "legnanotc", "legavp", "legnanotcplat", "corasy", },      -- nano, T2 veh lab, floating nano
			{ "leghp", "legfhp", "legamphlab", "corplat", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	-- Seaplane cons
	armcsa = {
		{
			{ "armmex", "armsolar", "armwin", "armadvsol", },  -- mex, solar, wind, adv. solar
			{ "armmakr", "armgeo", "armamex", "armtide",  },   -- T1 converter, geo, twilight, (tidal)
			{ "armestor", "armmstor", "armuwes", "armfmkr", }, -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "armllt", "armbeamer", "armhlt", "armclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armrl", "armferret", "armcir", "armfrt",},     -- basic AA, ferret, chainsaw, floating AA
			{ "armdl", "armguard", "armtl", "armfhlt", },     -- coastal torp launcher, guardian, offshore torp launcher, floating HLT
		},
		{
			{ "armrad", "armeyes", "armdrag", "armjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "armfrad", "armfdrag", "", "" },                       -- floating radar, shark's teeth
			{ "armjuno", },                                   -- juno
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "armnanotcplat", },                -- nano, floating nano
			{ "armhp", "armfhp", "armamsub", "armplat", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
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
			{ "corfrad", "corfdrag", "", "" },                       -- floating radar, shark's teeth
			{ "corjuno", },                                   -- juno
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
			{ "armmex", "armsolar", "armwin", "armadvsol", },  -- mex, solar, wind, adv. solar
			{ "armmakr", "armgeo", "armamex", "armtide",  },   -- T1 converter, geo, twilight, (tidal)
			{ "armestor", "armmstor", "armuwes", "armfmkr", }, -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "armllt", "armbeamer", "armhlt", "armclaw", },  -- LLT, beamer, HLT, lightning turret
			{ "armrl", "armferret", "armcir", "armfrt",},     -- basic AA, ferret, chainsaw, floating AA
			{ "armdl", "armguard", "armtl", "armfhlt", },     -- coastal torp launcher, guardian, offshore torp launcher, floating HLT
		},
		{
			{ "armrad", "armeyes", "armdrag", "armjamt", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "armfrad", "armfdrag", },                       -- floating radar, shark's teeth
			{ "armjuno", },                                   -- juno
		},
		{
			{ "armlab", "armvp", "armap", "armsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "armnanotc", "armavp", "armnanotcplat", },      -- nano, T2 veh lab, floating nano
			{ "armhp", "armfhp", "armamsub", "armplat", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
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
			{ "cordl", "corpun", "cortl", "corfhlt", },       -- coastal torp launcher, punisher, offshore torp launcher, floating HLT
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

    legotter = {
		{
			{ "legmex", "legsolar", "legwin", "legadvsol", },   -- mex, solar, wind, adv. solar
			{ "legeconv", "leggeo", "legmext15", "legtide", },              -- T1 converter, geo, T1.5 legion mex, (tidal)
			{ "legestor", "legmstor", "leguwestore", "legfeconv", },  -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "leglht", "legmg", "corhlt", "legdtr", },     -- LLT, machine gun, HLT, flame turret
			{ "legrl", "legrhapsis", "leglupara", "legfrl" },             -- basic AA, SAM, eradicator, floating AA
			{ "legctl", "legcluster", "legtl", "legfmg", },       -- coastal torp launcher, punisher, offshore torp launcher, floating HLT
		},
		{
			{ "legrad", "legeyes", "legdrag", "legjam", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "legfrad", "legfdrag", },                       -- floating radar, shark's teeth
			{ "legjuno", },                                   -- juno
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "legnanotc", "legavp", "legnanotcplat", },      -- nano, T2 veh lab, floating nano
			{ "leghp", "legfhp", "legamphlab", "corplat", },    -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	--T2 bot cons
	armack = {
		{
			{ "armmoho", "armfus", "armafus", "armgmm", },             -- moho, fusion, afus, safe geo
			{ "armmmkr", "armageo", "armckfus", "armshockwave" },                     -- T2 converter, T2 geo, cloaked fusion
			{ "armuwadves", "armuwadvms", },                           -- hardened energy storage, hardened metal storage
		},
		{
			{ "armpb", "armanni", "armamb", "armemp", },        -- pop-up gauss, annihilator, pop-up artillery, EMP missile
			{ "armflak", "armmercury", "armamd", },             -- flak, long-range AA, anti-nuke
			{ "armbrtha", "armvulc", "armsilo", },              -- LRPC, ICBM, lolcannon
		},
		{
			{ "armarad", "armtarg", "armfort", "armveil" },     -- adv radar, targeting facility, wall, adv jammer
			{ "armsd", "armdf", "" },                     -- intrusion counter, decoy fusion, air repair pad
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
			{ "corsd", "", "" },                          -- intrusion counter, air repair pad
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
			{ "legmoho", "legfus", "legafus", },                -- moho, fusion, afus
			{ "legadveconv", "legageo", "cormexp", },               -- T2 converter, T2 geo, armed moho
			{ "legadvestore", "legamstor", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "legapopupdef", "legbastion", "legacluster", "legperdition", },   -- pop-up gauss, heavy defence, pop-up artillery, tac nuke
			{ "legflak", "leglraa", "legabm", "legrampart", }, -- flak, long-range AA, anti-nuke, cerberus
			{ "leglrpc", "legstarfall", "legsilo", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "legarad", "legtarg", "legforti", "legajam", },  -- adv radar, targeting facility, wall, adv jammer
			{ "legsd", "", "", },               -- intrusion counter,  
			{ "legdeflector", },                                     -- anti-nuke, shield
		},
		{
			{ "leglab", },                                       -- T1 lab,
			{ "leggant", "legalab", },                           -- T3 lab, T2 lab
			{ },                                     -- seaplane lab (aircon only)
		}
	},

	--T2 vehicle cons
	armacv = {
		{
			{ "armmoho", "armfus", "armafus", "armgmm", },             -- moho, fusion, afus, safe geo
			{ "armmmkr", "armageo", "armckfus", "armshockwave" },                     -- T2 converter, T2 geo, cloaked fusion
			{ "armuwadves", "armuwadvms", },                           -- hardened energy storage, hardened metal storage
		},
		{
			{ "armpb", "armanni", "armamb", "armemp", },        -- pop-up gauss, annihilator, pop-up artillery, EMP missile
			{ "armflak", "armmercury", "armamd", },             -- flak, long-range AA, anti-nuke
			{ "armbrtha", "armvulc", "armsilo", },              -- LRPC, ICBM, lolcannon
		},
		{
			{ "armarad", "armtarg", "armfort", "armveil",  },   -- adv radar, targeting facility, wall, adv jammer
			{ "armsd", "armdf", "" },                     -- intrusion counter, decoy fusion, air repair pad
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
			{ "cormoho", "corfus", "corafus", },                -- moho, fusion, afus
			{ "cormmkr", "corageo", "cormexp", },               -- T2 converter, T2 geo, armed moho
			{ "coruwadves", "coruwadvms", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "corvipe", "cordoom", "cortoast", "cortron", },   -- pop-up gauss, DDM, pop-up artillery, tac nuke
			{ "corflak", "corscreamer", "corfmd", "corbhmth", }, -- flak, long-range AA, anti-nuke, cerberus
			{ "leglrpc", "corbuzz", "corsilo", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "corarad", "cortarg", "corfort", "corshroud", },  -- adv radar, targeting facility, wall, adv jammer
			{ "corsd", "", "" },                          -- intrusion counter, air repair pad
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
			{ "legmoho", "legfus", "legafus", },                -- moho, fusion, afus
			{ "legadveconv", "legageo", "cormexp", },               -- T2 converter, T2 geo, armed moho
			{ "legadvestore", "legamstor", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "legapopupdef", "legbastion", "legacluster", "legperdition", },   -- pop-up gauss, heavy defence, pop-up artillery, tac nuke
			{ "legflak", "leglraa", "legabm", "legrampart", }, -- flak, long-range AA, anti-nuke, cerberus
			{ "leglrpc", "legstarfall", "legsilo", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "legarad", "legtarg", "legforti", "legajam", },  -- adv radar, targeting facility, wall, adv jammer
			{ "legsd", "", "", },               -- intrusion counter,  
			{ "legdeflector", },                                     -- anti-nuke, shield
		},
		{
			{ "legvp", },                                       -- T1 lab,
			{ "leggant", "legavp", },                           -- T3 lab, T2 lab
			{ },                                     -- seaplane lab (aircon only)
		}
	},

	--T2 air cons
	armaca = {
		{
			{ "armmoho", "armfus", "armafus", "armgmm", },             -- moho, fusion, afus, safe geo
			{ "armmmkr", "armageo", "armckfus", "armshockwave" },                     -- T2 converter, T2 geo, cloaked fusion
			{ "armuwadves", "armuwadvms", },                           -- hardened energy storage, hardened metal storage
		},
		{
			{ "armpb", "armanni", "armamb", "armemp", },        -- pop-up gauss, annihilator, pop-up artillery, EMP missile
			{ "armflak", "armmercury", "armamd", },             -- flak, long-range AA, anti-nuke
			{ "armbrtha", "armvulc", "armsilo", },              -- LRPC, ICBM, lolcannon
		},
		{
			{ "armarad", "armtarg", "armfort", "armveil",  },    -- adv radar, targeting facility, wall, adv jammer
			{ "armsd", "armdf", "", "" },           -- intrusion counter, decoy fusion,  
			{ "armgate", },                                      -- shield
		},
		{
			{ "armap", },                                       -- T1 lab,
			{ "armshltx", "armaap", },                          -- T3 lab, T2 lab
			{ "armplat", },                                     -- seaplane lab (aircon only)
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
			{ "corsd", "", "", "" },               -- intrusion counter,  
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
			{ "legmoho", "legfus", "legafus", },                -- moho, fusion, afus
			{ "legadveconv", "legageo", "cormexp","coruwageo", },               -- T2 converter, T2 geo, armed moho
			{ "legadvestore", "legamstor", },                    -- hardened energy storage, hardened metal storage,
		},
		{
			{ "legapopupdef", "legbastion", "legacluster", "legperdition", },   -- pop-up gauss, heavy defence, pop-up artillery, tac nuke
			{ "legflak", "leglraa", "legabm", "legrampart", }, -- flak, long-range AA, anti-nuke, cerberus
			{ "leglrpc", "legstarfall", "legsilo", },                -- LRPC, ICBM, lolcannon
		},
		{
			{ "legarad", "legtarg", "legforti", "legajam", },  -- adv radar, targeting facility, wall, adv jammer
			{ "legsd", "", "", "", },               -- intrusion counter,  
			{ "legdeflector", },                                     -- anti-nuke, shield
		},
		{
			{ "legap", },                                       -- T1 lab,
			{ "leggant", "legaap", },                           -- T3 lab, T2 lab
			{ "corplat", },                                     -- seaplane lab (aircon only)
		}
	},

	--T2 sub cons
	armacsub = {
		{
			{ "armuwmme", "armuwfus", },                       -- uw moho, uw fusion,
			{ "armuwmmm", "armuwageo" },                       -- floating T2 converter, adv geo powerplant
			{ "armuwadves", "armuwadvms", },                   -- uw e stor, uw metal stor
		},
		{
			{ "armatl", "armkraken", },                        -- adv torp launcher, floating heavy platform
			{ "armfflak", },                                   -- floating flak
			{ },                                               --
		},
		{
			{ "armason", "armfatf" },                		   -- adv sonar, floating targeting facility
			{ "", "", "", "armfasp" },                         -- 
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
			{ "", "", "", "" },                          -- 
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
			{ "", "armeyes", "armdrag", },                  -- camera, dragon's teeth
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

	legmlv = {
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
			{ "", "legeyes", "legdrag", },                 -- camera, dragon's teeth
			{ },                                       --
			{ "legmine1", "legmine2", "legmine3", },   -- light mine, med mine, heavy mine
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
			{ "armmex", "armsolar", "armwin", },               -- mex, solar, wind
			{ "armmakr", "", "armuwms", "armtide"},              -- T1 converter, uw ms storage, tidal
			{ "armestor", "armmstor", "armuwes", "armfmkr", }, -- e storage, m storage, uw e storage, floating T1 converter
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
			{ "cormex", "corsolar", "corwin", },               -- mex, solar, wind
			{ "cormakr", "", "coruwms", "cortide" },           -- T1 converter, uw ms storage, tidal
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

	legdecom = {
		{
			{ "legmex", "legsolar", "legwin", },               -- mex, solar, wind
			{ "legeconv", "", "leguwmstore", "legtide" },           -- T1 converter, uw ms storage, tidal
			{ "legestor", "legmstor", "leguwestore", "legfeconv", }, -- e storage, m storage, uw e storage, floating T1 converter
		},
		{
			{ "leglht", },                                   -- LLT
			{ "legrl", },                                    -- basic AA
			{ },                                             --
		},
		{
			{ "legrad", },                                   -- radar
			{ },                                             --
			{ "legmine1", "legmine2", "legmine3", },         -- light mine, med mine, heavy mine
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
			{ "armmex", "armsolar", "armwin", },   -- mex, solar, wind
			{ "armmakr", },                        -- T1 converter
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

	--proteus
	legaceb = {
		{
			{ "legmex", "legsolar", },                                -- 0.5 mex, solar
			{ },                                                      --
			{ },                                                      --
		},
		{
			{ "legdtr", "legstr", "legacluster", },               -- dragon's jaw, strider, t2 cluster arty
			{ "legflak", "legrhapsis", "legaabot", "leggob", },    -- Ravager Flak, Rhapsis, T1 aa bot, Goblin
			{ "legctl", "legfloat", },               				-- coastal torp launcher, triton
		},
		{
			{ "legarad", "legeyes", "legforti", "legajam", },        -- adv radar, camera, wall, adv jammer
			{ },                                                      --
			{ },                                          			  -- med mine
		},
		{
			{ "leglab", "legck", },                                   -- bot lab, bot con
			{ "legnanotc", "legch", },                                -- nano, hover con (for now)
			{ },                                      				  --
		}
	},

	--aceso
    legafcv = {
		{
			{ "legmex", "legsolar", "legwin", "legadvsol", },   -- mex, solar, wind, adv. solar
			{ "legeconv", "leggeo", "legmext15", },              -- T1 converter, geo, T1.5 legion mex, (tidal)
			{ "legestor", "legmstor", },                        -- e storage, m storage, (uw e stor), (fl. T1 converter)
		},
		{
			{ "leglht", "legmg", "", "legdtr", },     			-- LLT, machine gun, HLT, flame turret
			{ "legrl", "legrhapsis", "leglupara", },             -- basic AA, SAM, eradicator
			{ "legctl", "legcluster", },                           -- coastal torp launcher, punisher
		},
		{
			{ "legrad", "legeyes", "legdrag", "legjam", },   -- radar, perimeter camera, dragon's teeth, jammer
			{ "", "", "", "" },                  --  
			{ "legjuno", },                                   -- juno
		},
		{
			{ "leglab", "legvp", "legap", "corsy", },         -- bot lab, veh lab, air lab, shipyard
			{ "legnanotc", "coralab", },                      -- nano, T2 lab
			{ "leghp", },                                     -- hover lab, floating hover lab, amphibious lab, seaplane lab
		}
	},

	--consul
	armconsul = {
		{
			{ "armmex", "armsolar", },                                -- mex, solar
			{ },                                                      --
			{ },                                                      --
		},
		{
			{ "armbeamer", "armfast", "armamb", "armmav", },          -- beamer, sprinter, ambusher, maverick
			{ "armflak", "armferret", "armjeth", "armpw", },          -- flak, ferret, T1 aa bot, peewee
			{ "armdl", "armroy", "armspid", "armamph", },             -- coastal torp launcher, destroyer, emp spider, platypus
		},
		{
			{ "armarad", "armeyes", "armfort", "armveil", },          -- adv radar, camera, wall, adv jammer
			{ },                                                      --
			{ "armmine2" },                                           -- med. mine
		},
		{
			{ "armcv", "armvp" },                             	 	  -- T1 veh con, vehicle lab
			{ "armnanotc" },                                		  -- nano
			{ "armcs" },                                              -- sea con
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
	armmls = {
		{
			{ "armmex", "armtide", },                               -- mex, tidal
			{ },                                                    --
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

unitGrids["dummycom"] = unitGrids["armcom"]

if Spring.GetModOptions().experimentalextraunits or Spring.GetModOptions().scavunitsforplayers then
	for _, builder in pairs({"armaca", "coraca", "legaca", "armack", "corack", "legack", "armacv", "coracv", "legacv"}) do
		local faction = builder:sub(1, 3)
		unitGrids[builder][1][3][3] =  faction .. "wint2"
		unitGrids[builder][4][1][2] = faction .. "apt3"
		unitGrids[builder][4][1][3] = faction .. "nanotct2"
	end
	unitGrids["armacsub"][4][1][3] = "armnanotc2plat"
	unitGrids["coracsub"][4][1][3] = "cornanotc2plat"
	
end

if Spring.Utilities.Gametype.IsScavengers() or Spring.GetModOptions().forceallunits then
	local scavLabGrids = {}
	local scavUnitGrids = {}
	for unitName, content in pairs(labGrids) do
		local scavContent = {}
		if #content > 0 then
			for i = 1,#content do
				if content[i] and content[i] ~= "" then
					scavContent[i] = content[i] .. "_scav"
				end
			end
		end
		scavLabGrids[unitName .. "_scav"] = scavContent
	end

	for unitName, content in pairs(unitGrids) do
		local scavContent = {}
		if content and #content > 0 then
			for i = 1,#content do
				if content[i] and #content[i] > 0 then
					scavContent[i] = {}
					for j = 1,#content[i] do
						if content[i][j] and #content[i][j] > 0 then
							scavContent[i][j] = {}
							for k = 1,#content[i][j] do
								if content[i][j][k] then
									scavContent[i][j][k] = {}
									if #content[i][j][k] > 0 then
										scavContent[i][j][k] = content[i][j][k] .. "_scav"
									end
								end
							end
						end
					end
				end
			end
		end
		scavUnitGrids[unitName .. "_scav"] = scavContent
	end
	table.mergeInPlace(labGrids, scavLabGrids)
	table.mergeInPlace(unitGrids, scavUnitGrids)
end

return {
	LabGrids = labGrids,
	UnitGrids = unitGrids,
}
