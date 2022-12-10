local scenariodata = {
	index			= 20, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "FortressAssault", -- no spaces, lowercase, this will be used to save the score and can be used gadget side
    version         = "1", -- increment this to reset the score when changing a mission, as scores are keyed by (scenarioid,version,difficulty)
	title			= "Fortress Assault", -- can be anything
	author			= "Watch The Fort", -- your name here
	imagepath		= "scenario020.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "", -- This text will be drawn over image
    summary         = [[An abandoned enemy base lies nearby, though its defences still work. Destroy it, Commander!]],
	briefing 		= [[The enemy is purely defending, so you won't have to worry about any incoming attacks.
There are multiple approaches to the base, with some more defended than others.]],

	mapfilename		= "Death Valley v1", -- the name of the map to be displayed here, and which to play on, no .smf ending needed
	playerstartx	= "19%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "87%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 1200, -- par time in seconds (time a mission is expected to take on average)
	parresources	= 1000000, -- par resource amount (amount of metal one is expected to spend on mission)
	difficulty		= 0, -- Percieved difficulty at 'normal' level: integer 1-10
    defaultdifficulty = "Normal", -- an entry of the difficulty table
    difficulties    = { -- Array for sortedness, Keys are text that appears in selector (as well as in scoring!), values are handicap levels
    -- handicap values range [-100 - +100], with 0 being regular resources
    -- Currently difficulty modifier only affects the resource bonuses
        -- {name = "Beginner", playerhandicap = 50, enemyhandicap=0},
        -- {name = "Novice"  , playerhandicap = 25, enemyhandicap=0},
        {name = "Normal"  , playerhandicap = 0, enemyhandicap=0},
        -- {name = "Hard"    , playerhandicap = 0,  enemyhandicap=25},
        -- {name = "Brutal" , playerhandicap = 0,  enemyhandicap=50},
    },
    allowedsides     = {"Armada"}, --these are the permitted factions for this mission, choose from {"Armada", "Cortex", "Random"}
	victorycondition= "Kill all enemy factories", -- This is plaintext, but should be reflected in startscript
	losscondition	= "Loss of all your builders and factories",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberofthese units, 0 means disable it
        -- dont use the one in startscript, put the disabled stuff here so we can show it in scenario window!
        --armavp = 0,
        --coravp = 0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff", -- blank
        scenarioid = "FortressAssault", -- this MUST be present and identical to the one defined at start
		disablefactionpicker = true, -- this is needed to prevent faction picking outside of the allowedsides

        unitloadout = {
			-- You can specify units that you wish to spawn here, they only show up once game starts,
			-- You can create these lists easily using the feature/unit dumper by using dbg_feature_dumper.lua widget pinned to the #challenges channel on discord
			-- Set up a skirmish like your scenario, so the team ID's will be correct
			-- Then using /globallos and cheats, add as many units as you wish
			-- The type /luaui dumpunits
			-- Fish out the dumped units from your infolog.txt and add them here
			-- Note: If you have ANY units in loadout, then there will be no initial units spawned for anyone, so you have to take care of that
			-- so you must spawn the initial commanders then!

			{name = 'armcom', x = 552, y = 8, z = 6767, rot = 0 , team = 0, neutral = false},
			{name = 'cormex', x = 3680, y = 6, z = 720, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 3344, y = 6, z = 528, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 3440, y = 6, z = 1072, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 3024, y = 6, z = 1808, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 4320, y = 6, z = 1632, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 4240, y = 6, z = 2736, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 5024, y = 6, z = 2528, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 5392, y = 6, z = 2064, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 5664, y = 6, z = 1776, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 5872, y = 6, z = 2144, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 5152, y = 6, z = 832, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 2656, y = 7, z = 224, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 288, y = 6, z = 272, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 160, y = 6, z = 1024, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 592, y = 6, z = 816, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 5984, y = 6, z = 6144, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 5552, y = 6, z = 6368, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 5584, y = 6, z = 5824, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 2016, y = 6, z = 2304, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 1856, y = 6, z = 2096, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 1440, y = 77, z = 400, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 1376, y = 76, z = 96, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 4704, y = 77, z = 6784, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 4768, y = 76, z = 7072, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 4288, y = 6, z = 5072, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 4128, y = 6, z = 4864, rot = 0 , team = 1, neutral = false},
			{name = 'corllt', x = 2080, y = 150, z = 624, rot = 32767 , team = 1, neutral = false},
			{name = 'corllt', x = 2128, y = 139, z = 1040, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1728, y = 120, z = 352, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1728, y = 119, z = 384, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1744, y = 127, z = 416, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1744, y = 125, z = 448, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1760, y = 128, z = 480, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1760, y = 126, z = 512, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1760, y = 120, z = 544, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1776, y = 121, z = 576, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1856, y = 104, z = 1264, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1872, y = 107, z = 1232, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1872, y = 105, z = 1200, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1888, y = 105, z = 1168, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1888, y = 102, z = 1136, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1904, y = 103, z = 1104, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1904, y = 101, z = 1072, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1920, y = 104, z = 1040, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1920, y = 104, z = 1008, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1696, y = 100, z = 720, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1712, y = 100, z = 752, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1744, y = 101, z = 784, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1760, y = 100, z = 816, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1792, y = 100, z = 848, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1808, y = 99, z = 880, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1840, y = 99, z = 912, rot = 32767 , team = 1, neutral = false},
			{name = 'corhllt', x = 336, y = 7, z = 640, rot = 32767 , team = 1, neutral = false},
			{name = 'corhllt', x = 5712, y = 7, z = 6128, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3504, y = 7, z = 2720, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3248, y = 16, z = 2576, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4080, y = 12, z = 3072, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3888, y = 7, z = 2960, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3376, y = 8, z = 2656, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3984, y = 8, z = 3008, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3536, y = 7, z = 2752, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3280, y = 9, z = 2592, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4112, y = 22, z = 3088, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3920, y = 7, z = 2976, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3408, y = 7, z = 2672, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4016, y = 7, z = 3024, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3568, y = 7, z = 2768, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3312, y = 9, z = 2608, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4144, y = 39, z = 3104, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3952, y = 7, z = 2992, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3440, y = 7, z = 2688, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4048, y = 8, z = 3040, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3344, y = 8, z = 2640, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3472, y = 7, z = 2704, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3824, y = 7, z = 2912, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3856, y = 7, z = 2928, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3184, y = 56, z = 2560, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3216, y = 35, z = 2560, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4176, y = 72, z = 3120, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4192, y = 105, z = 3152, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3152, y = 83, z = 2560, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3120, y = 102, z = 2560, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4208, y = 7, z = 2592, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4208, y = 8, z = 2624, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4176, y = 8, z = 2624, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4144, y = 7, z = 2624, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4144, y = 7, z = 2592, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4144, y = 7, z = 2560, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4176, y = 7, z = 2560, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4208, y = 7, z = 2560, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3648, y = 7, z = 2304, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3648, y = 7, z = 2336, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3616, y = 7, z = 2336, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3584, y = 8, z = 2336, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3584, y = 7, z = 2304, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3584, y = 7, z = 2272, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3616, y = 8, z = 2272, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3648, y = 7, z = 2272, rot = 32767 , team = 1, neutral = false},
			{name = 'corlab', x = 4656, y = 7, z = 2112, rot = -16384 , team = 1, neutral = false},
			{name = 'corlab', x = 3680, y = 7, z = 1520, rot = 0 , team = 1, neutral = false},
			{name = 'coradvsol', x = 96, y = 7, z = 624, rot = 0 , team = 1, neutral = false},
			{name = 'coradvsol', x = 5520, y = 7, z = 6128, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3744, y = 180, z = 6064, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3760, y = 165, z = 6096, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3776, y = 160, z = 6128, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3792, y = 149, z = 6160, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3808, y = 140, z = 6192, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3872, y = 139, z = 6320, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3888, y = 138, z = 6352, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3888, y = 136, z = 6384, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3904, y = 138, z = 6416, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3904, y = 134, z = 6448, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3920, y = 138, z = 6480, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3920, y = 138, z = 6512, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3856, y = 134, z = 6640, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3824, y = 133, z = 6672, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3808, y = 138, z = 6704, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3792, y = 143, z = 6736, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3776, y = 167, z = 6768, rot = 0 , team = 1, neutral = false},
			{name = 'corllt', x = 4112, y = 138, z = 6000, rot = 0 , team = 1, neutral = false},
			{name = 'corllt', x = 4208, y = 142, z = 6544, rot = 0 , team = 1, neutral = false},
			{name = 'corrl', x = 4600, y = 66, z = 6136, rot = 0 , team = 1, neutral = false},
			{name = 'corrl', x = 2152, y = 142, z = 840, rot = 0 , team = 1, neutral = false},
			{name = 'corfhp', x = 4736, y = -4, z = 1208, rot = 0 , team = 1, neutral = false},
			{name = 'corsolar', x = 6104, y = 8, z = 40, rot = 0 , team = 1, neutral = false},
			{name = 'corsolar', x = 5992, y = 7, z = 40, rot = 0 , team = 1, neutral = false},
			{name = 'corsolar', x = 5992, y = 7, z = 152, rot = 0 , team = 1, neutral = false},
			{name = 'corsolar', x = 6104, y = 7, z = 152, rot = 0 , team = 1, neutral = false},
			{name = 'corrl', x = 3976, y = 7, z = 2312, rot = 0 , team = 1, neutral = false},
			{name = 'corrl', x = 3432, y = 8, z = 2104, rot = 0 , team = 1, neutral = false},
			{name = 'corrl', x = 4488, y = 8, z = 2712, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3744, y = 7, z = 1488, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3744, y = 7, z = 1520, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3744, y = 7, z = 1552, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3616, y = 7, z = 1552, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3616, y = 7, z = 1520, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3616, y = 7, z = 1488, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3616, y = 7, z = 1456, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3648, y = 8, z = 1456, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3680, y = 7, z = 1456, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3712, y = 7, z = 1456, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3744, y = 7, z = 1456, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4720, y = 7, z = 2080, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4720, y = 7, z = 2112, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4720, y = 7, z = 2144, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4720, y = 7, z = 2176, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4688, y = 7, z = 2176, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4656, y = 7, z = 2176, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4624, y = 7, z = 2176, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4624, y = 7, z = 2048, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4656, y = 7, z = 2048, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4688, y = 7, z = 2048, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4720, y = 7, z = 2048, rot = 0 , team = 1, neutral = false},
			{name = 'coraap', x = 5392, y = 7, z = 576, rot = 0 , team = 1, neutral = false},
			{name = 'cornanotc', x = 5304, y = 7, z = 552, rot = 0 , team = 1, neutral = false},
			{name = 'cornanotc', x = 5304, y = 8, z = 600, rot = 0 , team = 1, neutral = false},
			{name = 'cornanotc', x = 5480, y = 7, z = 600, rot = 0 , team = 1, neutral = false},
			{name = 'cornanotc', x = 5480, y = 7, z = 552, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5440, y = 7, z = 640, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 5408, y = 7, z = 640, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 5376, y = 7, z = 640, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 5344, y = 8, z = 640, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 5344, y = 7, z = 512, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5376, y = 7, z = 512, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5408, y = 7, z = 512, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5440, y = 7, z = 512, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5280, y = 7, z = 640, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 5264, y = 7, z = 608, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5264, y = 7, z = 576, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5264, y = 7, z = 544, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5280, y = 7, z = 512, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5504, y = 7, z = 512, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5520, y = 7, z = 544, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5520, y = 7, z = 576, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5520, y = 7, z = 608, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5504, y = 7, z = 640, rot = 0 , team = 1, neutral = false},
			{name = 'cormaw', x = 5312, y = 8, z = 640, rot = 0 , team = 1, neutral = false},
			{name = 'cormaw', x = 5472, y = 7, z = 640, rot = 0 , team = 1, neutral = false},
			{name = 'cormaw', x = 5312, y = 7, z = 512, rot = 0 , team = 1, neutral = false},
			{name = 'cormaw', x = 5472, y = 7, z = 512, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 5680, y = 6, z = 656, rot = 0 , team = 1, neutral = false},
			{name = 'cormex', x = 5280, y = 6, z = 304, rot = 0 , team = 1, neutral = false},
			{name = 'corsolar', x = 5352, y = 7, z = 824, rot = 0 , team = 1, neutral = false},
			{name = 'corsolar', x = 5464, y = 8, z = 824, rot = 0 , team = 1, neutral = false},
			{name = 'corsolar', x = 5464, y = 7, z = 936, rot = 0 , team = 1, neutral = false},
			{name = 'corsolar', x = 5352, y = 7, z = 936, rot = 0 , team = 1, neutral = false},
			{name = 'corsolar', x = 3816, y = 7, z = 1032, rot = 0 , team = 1, neutral = false},
			{name = 'corsolar', x = 3928, y = 7, z = 1032, rot = 0 , team = 1, neutral = false},
			{name = 'corsolar', x = 3928, y = 7, z = 1144, rot = 0 , team = 1, neutral = false},
			{name = 'corsolar', x = 3816, y = 7, z = 1144, rot = 0 , team = 1, neutral = false},
			{name = 'coradvsol', x = 5536, y = 7, z = 288, rot = 0 , team = 1, neutral = false},
			{name = 'corrad', x = 3456, y = 384, z = 4864, rot = 0 , team = 1, neutral = false},
			{name = 'corrad', x = 1472, y = 384, z = 3664, rot = 0 , team = 1, neutral = false},
			{name = 'corrad', x = 4688, y = 385, z = 3488, rot = 0 , team = 1, neutral = false},
			{name = 'corrad', x = 4016, y = 384, z = 7104, rot = 0 , team = 1, neutral = false},
			{name = 'corrad', x = 2704, y = 384, z = 2304, rot = 0 , team = 1, neutral = false},
			{name = 'corrad', x = 2112, y = 384, z = 80, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 2144, y = 384, z = 80, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 2144, y = 383, z = 112, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 2112, y = 384, z = 112, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 2080, y = 383, z = 112, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 2080, y = 383, z = 80, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 2080, y = 382, z = 48, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 2112, y = 384, z = 48, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 2144, y = 386, z = 48, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 2736, y = 384, z = 2304, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 2736, y = 384, z = 2336, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 2704, y = 383, z = 2336, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 2672, y = 381, z = 2336, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 2672, y = 383, z = 2304, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 2672, y = 383, z = 2272, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 2704, y = 384, z = 2272, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 2736, y = 383, z = 2272, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4720, y = 385, z = 3488, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4720, y = 386, z = 3520, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4688, y = 385, z = 3520, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4656, y = 385, z = 3520, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4656, y = 385, z = 3488, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4656, y = 385, z = 3456, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4688, y = 385, z = 3456, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4720, y = 385, z = 3456, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4048, y = 384, z = 7104, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4048, y = 384, z = 7136, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4016, y = 385, z = 7136, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3984, y = 385, z = 7136, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3984, y = 384, z = 7104, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3984, y = 384, z = 7072, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4016, y = 384, z = 7072, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4048, y = 384, z = 7072, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3488, y = 383, z = 4864, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3488, y = 384, z = 4896, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3456, y = 384, z = 4896, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3424, y = 383, z = 4896, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3424, y = 383, z = 4864, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3424, y = 383, z = 4832, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3456, y = 383, z = 4832, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3488, y = 382, z = 4832, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 1504, y = 385, z = 3664, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 1504, y = 384, z = 3696, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 1472, y = 384, z = 3696, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1440, y = 384, z = 3696, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 1440, y = 384, z = 3664, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 1440, y = 384, z = 3632, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 1472, y = 384, z = 3632, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 1504, y = 385, z = 3632, rot = 0 , team = 1, neutral = false},
			{name = 'corllt', x = 2096, y = 7, z = 2912, rot = 0 , team = 1, neutral = false},
			{name = 'corllt', x = 4016, y = 8, z = 4288, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4048, y = 8, z = 4288, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4048, y = 8, z = 4320, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4016, y = 8, z = 4320, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3984, y = 7, z = 4320, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3984, y = 7, z = 4288, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3984, y = 7, z = 4256, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4016, y = 8, z = 4256, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4048, y = 8, z = 4256, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 2128, y = 7, z = 2912, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 2128, y = 7, z = 2944, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 2096, y = 7, z = 2944, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 2064, y = 7, z = 2944, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 2064, y = 7, z = 2912, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 2064, y = 7, z = 2880, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 2096, y = 7, z = 2880, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 2128, y = 7, z = 2880, rot = 0 , team = 1, neutral = false},
			{name = 'corrl', x = 376, y = 7, z = 680, rot = 0 , team = 1, neutral = false},
			{name = 'corrl', x = 5672, y = 7, z = 6088, rot = 0 , team = 1, neutral = false},
			{name = 'corvp', x = 3192, y = 7, z = 824, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3232, y = 7, z = 896, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3136, y = 7, z = 896, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3136, y = 7, z = 752, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3232, y = 7, z = 752, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3264, y = 7, z = 896, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3296, y = 7, z = 896, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3264, y = 7, z = 752, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3296, y = 7, z = 752, rot = -16384 , team = 1, neutral = false},
			{name = 'corhllt', x = 3344, y = 7, z = 832, rot = -16384 , team = 1, neutral = false},
			{name = 'corllt', x = 4752, y = 7, z = 2112, rot = -16384 , team = 1, neutral = false},
			{name = 'corllt', x = 3680, y = 7, z = 1424, rot = 0 , team = 1, neutral = false},
			{name = 'corllt', x = 3376, y = 8, z = 2384, rot = 0 , team = 1, neutral = false},
			{name = 'corllt', x = 3664, y = 7, z = 2576, rot = 0 , team = 1, neutral = false},
			{name = 'corllt', x = 3952, y = 7, z = 2768, rot = 0 , team = 1, neutral = false},
			{name = 'corllt', x = 4240, y = 10, z = 2944, rot = 0 , team = 1, neutral = false},
			{name = 'corhlt', x = 3616, y = 8, z = 2304, rot = 0 , team = 1, neutral = false},
			{name = 'corhlt', x = 4176, y = 7, z = 2592, rot = 0 , team = 1, neutral = false},
			{name = 'corhllt', x = 3920, y = 7, z = 2480, rot = 0 , team = 1, neutral = false},
			{name = 'cormadsam', x = 5656, y = 7, z = 408, rot = 0 , team = 1, neutral = false},
			{name = 'corllt', x = 5600, y = 7, z = 1104, rot = 0 , team = 1, neutral = false},
			{name = 'corllt', x = 5952, y = 7, z = 1104, rot = 0 , team = 1, neutral = false},
			{name = 'corllt', x = 4736, y = 7, z = 528, rot = -16384 , team = 1, neutral = false},
			{name = 'corllt', x = 4736, y = 7, z = 176, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4768, y = 7, z = 176, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4768, y = 7, z = 208, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4736, y = 7, z = 208, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4704, y = 7, z = 208, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4704, y = 7, z = 176, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4704, y = 7, z = 144, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4736, y = 7, z = 144, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4768, y = 7, z = 144, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4768, y = 7, z = 528, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4768, y = 7, z = 560, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4736, y = 7, z = 560, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4704, y = 7, z = 560, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4704, y = 7, z = 528, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4704, y = 7, z = 496, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4736, y = 7, z = 496, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4768, y = 7, z = 496, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 5632, y = 7, z = 1104, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 5632, y = 7, z = 1136, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 5600, y = 7, z = 1136, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 5568, y = 7, z = 1136, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 5568, y = 7, z = 1104, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5568, y = 7, z = 1072, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5600, y = 7, z = 1072, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 5632, y = 7, z = 1072, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 5984, y = 7, z = 1104, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 5984, y = 7, z = 1136, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 5952, y = 7, z = 1136, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 5920, y = 7, z = 1136, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 5920, y = 7, z = 1104, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5920, y = 7, z = 1072, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 5952, y = 7, z = 1072, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 5984, y = 7, z = 1072, rot = -16384 , team = 1, neutral = false},
			{name = 'corfdrag', x = 4656, y = -3, z = 1152, rot = -16384 , team = 1, neutral = false},
			{name = 'corfdrag', x = 4656, y = -3, z = 1184, rot = -16384 , team = 1, neutral = false},
			{name = 'corfdrag', x = 4656, y = -3, z = 1216, rot = -16384 , team = 1, neutral = false},
			{name = 'corfdrag', x = 4656, y = -3, z = 1248, rot = -16384 , team = 1, neutral = false},
			{name = 'corfdrag', x = 4816, y = -3, z = 1248, rot = -16384 , team = 1, neutral = false},
			{name = 'corfdrag', x = 4816, y = -3, z = 1216, rot = -16384 , team = 1, neutral = false},
			{name = 'corfdrag', x = 4816, y = -3, z = 1184, rot = -16384 , team = 1, neutral = false},
			{name = 'corfdrag', x = 4816, y = -3, z = 1152, rot = -16384 , team = 1, neutral = false},
			{name = 'cornanotcplat', x = 4616, y = 0, z = 1208, rot = -16384 , team = 1, neutral = false},
			{name = 'cornanotcplat', x = 4856, y = 0, z = 1208, rot = -16384 , team = 1, neutral = false},
			{name = 'corfdrag', x = 4624, y = -3, z = 1248, rot = -16384 , team = 1, neutral = false},
			{name = 'corfdrag', x = 4592, y = -3, z = 1248, rot = -16384 , team = 1, neutral = false},
			{name = 'corfdrag', x = 4848, y = -3, z = 1248, rot = -16384 , team = 1, neutral = false},
			{name = 'corfdrag', x = 4880, y = -3, z = 1248, rot = -16384 , team = 1, neutral = false},
			{name = 'corrad', x = 4224, y = 7, z = 2000, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4256, y = 7, z = 2000, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4256, y = 7, z = 2032, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 4224, y = 7, z = 2032, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4192, y = 7, z = 2032, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4192, y = 7, z = 2000, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4192, y = 7, z = 1968, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 4224, y = 7, z = 1968, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 4256, y = 7, z = 1968, rot = -16384 , team = 1, neutral = false},
			{name = 'corfrt', x = 5072, y = -4, z = 1376, rot = -16384 , team = 1, neutral = false},
			{name = 'corfrt', x = 4480, y = -4, z = 992, rot = -16384 , team = 1, neutral = false},
			{name = 'corwin', x = 5880, y = 7, z = 1496, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5880, y = 7, z = 1624, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5880, y = 7, z = 1752, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5944, y = 7, z = 1496, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5944, y = 7, z = 1624, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5880, y = 7, z = 1816, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5944, y = 7, z = 1752, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6072, y = 7, z = 1688, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5880, y = 7, z = 1880, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6072, y = 7, z = 1560, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6072, y = 7, z = 1432, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6008, y = 7, z = 1880, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6008, y = 7, z = 1688, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5944, y = 7, z = 1880, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6072, y = 7, z = 1816, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6008, y = 7, z = 1560, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6008, y = 7, z = 1432, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6072, y = 7, z = 1880, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6008, y = 7, z = 1944, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5944, y = 7, z = 1688, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6008, y = 7, z = 1816, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5944, y = 7, z = 1560, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5944, y = 7, z = 1432, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6008, y = 7, z = 1752, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6008, y = 7, z = 1496, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5944, y = 7, z = 1944, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6008, y = 7, z = 1624, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5944, y = 7, z = 1816, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6072, y = 7, z = 1944, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5880, y = 9, z = 1944, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5880, y = 7, z = 1560, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5880, y = 7, z = 1688, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 5880, y = 7, z = 1432, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6072, y = 7, z = 1752, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6072, y = 7, z = 1496, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 6072, y = 7, z = 1624, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4392, y = 7, z = 72, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4328, y = 7, z = 72, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4264, y = 7, z = 72, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4200, y = 7, z = 72, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4136, y = 7, z = 72, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4072, y = 8, z = 72, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4008, y = 7, z = 72, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3944, y = 7, z = 72, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3880, y = 7, z = 72, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3816, y = 7, z = 72, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3752, y = 8, z = 72, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3688, y = 8, z = 72, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3688, y = 7, z = 136, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3752, y = 7, z = 136, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3816, y = 7, z = 136, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3880, y = 7, z = 136, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3944, y = 7, z = 136, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4008, y = 7, z = 136, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4072, y = 7, z = 136, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4136, y = 7, z = 136, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4200, y = 7, z = 136, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4264, y = 7, z = 136, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4328, y = 7, z = 136, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4392, y = 7, z = 136, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4392, y = 7, z = 200, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4328, y = 7, z = 200, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4264, y = 7, z = 200, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4200, y = 7, z = 200, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4136, y = 7, z = 200, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4072, y = 7, z = 200, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4008, y = 7, z = 200, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3944, y = 7, z = 200, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3880, y = 7, z = 200, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3816, y = 7, z = 200, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3752, y = 7, z = 200, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3688, y = 7, z = 200, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3688, y = 7, z = 264, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3752, y = 7, z = 264, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3816, y = 7, z = 264, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3880, y = 7, z = 264, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 3944, y = 7, z = 264, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4008, y = 7, z = 264, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4072, y = 7, z = 264, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4136, y = 7, z = 264, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4200, y = 7, z = 264, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4264, y = 7, z = 264, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4328, y = 7, z = 264, rot = 32767 , team = 1, neutral = false},
			{name = 'corwin', x = 4392, y = 7, z = 264, rot = 32767 , team = 1, neutral = false},
			--{name = 'corestor', x = 6000, y = 7, z = 2032, rot = 32767 , team = 1, neutral = false},
			--{name = 'corestor', x = 3616, y = 7, z = 160, rot = 32767 , team = 1, neutral = false},
			{name = 'coradvsol', x = 5776, y = 7, z = 528, rot = 32767 , team = 1, neutral = false},
			{name = 'corexp', x = 5808, y = 6, z = 256, rot = 0 , team = 1, neutral = false},
			{name = 'cormstor', x = 5781, y = 7, z = 6285, rot = 0 , team = 1, neutral = false},
			{name = 'cormstor', x = 382, y = 7, z = 939, rot = 0 , team = 1, neutral = false},
			{name = 'coradvsol', x = 896, y = 7, z = 2112, rot = 0 , team = 1, neutral = false},
			{name = 'cormakr', x = 952, y = 7, z = 2104, rot = -16384 , team = 1, neutral = false},
			{name = 'cormakr', x = 952, y = 8, z = 2152, rot = -16384 , team = 1, neutral = false},
			{name = 'cormakr', x = 904, y = 7, z = 2168, rot = 32767 , team = 1, neutral = false},
			{name = 'cormakr', x = 856, y = 7, z = 2168, rot = 32767 , team = 1, neutral = false},
			{name = 'cormakr', x = 840, y = 7, z = 2120, rot = 16384 , team = 1, neutral = false},
			{name = 'cormakr', x = 840, y = 7, z = 2072, rot = 16384 , team = 1, neutral = false},
			{name = 'cormakr', x = 888, y = 7, z = 2056, rot = 0 , team = 1, neutral = false},
			{name = 'cormakr', x = 936, y = 7, z = 2056, rot = 0 , team = 1, neutral = false},
			{name = 'coradvsol', x = 5328, y = 7, z = 4944, rot = 0 , team = 1, neutral = false},
			{name = 'cormakr', x = 5384, y = 7, z = 4936, rot = -16384 , team = 1, neutral = false},
			{name = 'cormakr', x = 5384, y = 8, z = 4984, rot = -16384 , team = 1, neutral = false},
			{name = 'cormakr', x = 5336, y = 7, z = 5000, rot = 32767 , team = 1, neutral = false},
			{name = 'cormakr', x = 5288, y = 7, z = 5000, rot = 32767 , team = 1, neutral = false},
			{name = 'cormakr', x = 5272, y = 7, z = 4952, rot = 16384 , team = 1, neutral = false},
			{name = 'cormakr', x = 5272, y = 7, z = 4904, rot = 16384 , team = 1, neutral = false},
			{name = 'cormakr', x = 5320, y = 7, z = 4888, rot = 0 , team = 1, neutral = false},
			{name = 'cormakr', x = 5368, y = 7, z = 4888, rot = 0 , team = 1, neutral = false},
			{name = 'cormakr', x = 4648, y = 7, z = 2216, rot = 0 , team = 1, neutral = false},
			{name = 'cormakr', x = 4696, y = 7, z = 2216, rot = 0 , team = 1, neutral = false},
			{name = 'cormakr', x = 4648, y = 7, z = 2008, rot = 0 , team = 1, neutral = false},
			{name = 'cormakr', x = 4696, y = 7, z = 2008, rot = 0 , team = 1, neutral = false},
			{name = 'cormakr', x = 3784, y = 7, z = 1480, rot = 0 , team = 1, neutral = false},
			{name = 'cormakr', x = 3784, y = 7, z = 1528, rot = 0 , team = 1, neutral = false},
			{name = 'cormakr', x = 3576, y = 7, z = 1528, rot = 0 , team = 1, neutral = false},
			{name = 'cormakr', x = 3576, y = 7, z = 1480, rot = 0 , team = 1, neutral = false},
			--{name = 'corestor', x = 3184, y = 7, z = 912, rot = 0 , team = 1, neutral = false},
			--{name = 'corestor', x = 3184, y = 7, z = 736, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3232, y = 7, z = 928, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3232, y = 7, z = 960, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3200, y = 7, z = 960, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3168, y = 7, z = 960, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3136, y = 7, z = 960, rot = 32767 , team = 1, neutral = false},
			{name = 'cordrag', x = 3136, y = 7, z = 928, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3232, y = 7, z = 720, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3136, y = 7, z = 720, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3136, y = 7, z = 688, rot = 16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3168, y = 7, z = 688, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3200, y = 7, z = 688, rot = 0 , team = 1, neutral = false},
			{name = 'cordrag', x = 3232, y = 7, z = 688, rot = 0 , team = 1, neutral = false},
			{name = 'cornanotc', x = 3272, y = 7, z = 856, rot = -16384 , team = 1, neutral = false},
			{name = 'cornanotc', x = 3272, y = 7, z = 792, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3312, y = 7, z = 784, rot = -16384 , team = 1, neutral = false},
			{name = 'cordrag', x = 3312, y = 7, z = 864, rot = -16384 , team = 1, neutral = false},
		},
		featureloadout = {
			-- Similarly to units, but these can also be resurrectable!
            -- You can /give corcom_dead with cheats when making your scenario, but it might not contain the 'resurrectas' tag, so be careful to add it if needed
			 -- {name = 'corcom_dead', x = 1125,y = 237, z = 734, rot = "0" , scale = 1.0, resurrectas = "corcom"}, -- there is no need for this dead comm here, just an example
		}
    },
    -- Full Documentation for start script here:
    -- https://github.com/spring/spring/blob/105.0/doc/StartScriptFormat.txt

    -- HOW TO MAKE THE START SCRIPT: Use Chobby's single player mode to set up your start script. When you launch a single player game, the start script is dumped into infolog.txt
    -- ModOptions: You can also set modoptions in chobby, and they will get dumped into the infolog's start script too, or just set then in chobby and copy paste them into the [modoptions] tag. as below
    -- The following keys MUST be present in startscript below
    --  scenariooptions = __SCENARIOOPTIONS__;
    -- Name = __PLAYERNAME__;
    -- myplayername = __PLAYERNAME__;
    -- gametype = __BARVERSION__;
    -- mapname =__MAPNAME__;

    -- Optional keys:
    -- __ENEMYHANDICAP__
    -- __PLAYERSIDE__
    -- __PLAYERHANDICAP__
    -- __NUMRESTRICTIONS__
    -- __RESTRICTEDUNITS__

	startscript		= [[[GAME]
{
	[allyTeam0]
	{
		numallies = 0;
	}

	[team1]
	{
		Side = Cortex;
		Handicap = 0;
		RgbColor = 0.99609375 0.546875 0;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[team0]
	{
		Side = __PLAYERSIDE__;
		Handicap = 0;
		RgbColor = 0.99609375 0.546875 0;
		AllyTeam = 0;
		TeamLeader = 0;
		StartPosX = 550;
        StartPosZ = 6760;
	}

	[modoptions]
	{
		deathmode = builders;
		scenariooptions = __SCENARIOOPTIONS__;
	}

	[allyTeam1]
	{
		numallies = 0;
	}

	[ai0]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = InactiveAI(1);
		ShortName = NullAI;
		Team = 1;
		Version = 0.1;
	}

	[player0]
	{
		IsFromDemo = 0;
		Name = __PLAYERNAME__;
		Team = 0;
		rank = 0;
	}

	hostip = 127.0.0.1;
	hostport = 0;
	numplayers = 1;
	startpostype = 3;
	mapname = __MAPNAME__;
	ishost = 1;
	numusers = 2;
	gametype = __BARVERSION__;
	GameStartDelay = 5;
	myplayername = __PLAYERNAME__;
	nohelperais = 0;
}
	]],

}

return scenariodata
