local scenariodata = {
	index			= 10, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "strongholdkilltraitor010", -- no spaces, lowercase, this will be used to save the score and can be used gadget side
    version         = "1", -- increment this to reset the score when changing a mission, as scores are keyed by (scenarioid,version,difficulty)
	title			= "Keep your secrets", -- can be anything

	author			= "Beherith", -- your name here
	imagepath		= "scenario010.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "The captured Cortex Commander", -- This text will be drawn over image
    summary         = [[Armada have captured and taken a Cortex Commander hostage, and intend to steal Cortex technology and infiltrate your ranks. Foil their plans by any means necessary to neutralize this threat]],
	briefing 		= [[
Your intelligence reports state that the captured commander is still being held, but his programming has been compromised. To minimize the risk of our technology being stolen. A small forward position has been established on the map, which is hidden with radar jammers for now. You do not have much time before the enemy discovers your presence, so you must liquidate the captured Commander as fast as possible.

Tips:
 - If this scenario seems difficult, try it at a lower difficulty override
 - The enemy will expand rapidly, and the map is particularly resource rich
 - The enemy might send early aircraft raids, so your forward base has been equipped with anti-air turrets
 - The enemy base is very heavily defended with both Tier 2 ground defences and and anti-air.

Scoring:
 - Time taken to complete the scenario
 - Resources spent to get a confirmed kill on the captured commander.
 ]],

	mapfilename		= "Stronghold V4", -- the name of the map to be displayed here, and which to play on, no .smf ending needed
	playerstartx	= "85%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "85%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 3000, -- par time in seconds (time a mission is expected to take on average)
	parresources	= 1000000, -- par resource amount (amount of metal one is expected to spend on mission)
	difficulty		= 4, -- Percieved difficulty at 'normal' level: integer 1-10
    defaultdifficulty = "Normal", -- an entry of the difficulty table
    difficulties    = { -- Array for sortedness, Keys are text that appears in selector (as well as in scoring!), values are handicap levels
    -- handicap values range [-100 - +100], with 0 being regular resources
    -- Currently difficulty modifier only affects the resource bonuses
        {name = "Beginner", playerhandicap = 50, enemyhandicap=-50},
        {name = "Novice"  , playerhandicap = 25, enemyhandicap=-25},
        {name = "Normal"  , playerhandicap = 0, enemyhandicap=0},
        {name = "Hard"    , playerhandicap = 0,  enemyhandicap=50},
        {name = "Brutal" , playerhandicap = 0,  enemyhandicap=100},
    },
    allowedsides     = {"Cortex"}, --these are the permitted factions for this mission, ch0ose from {"Armada", "Cortex", "Random"}
	victorycondition= "Kill the Cortex Commander", -- This is plaintext, but should be reflected in startscript
	losscondition	= "Death of your Commander",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberofthese units, 0 means disable it
        -- dont use the one in startscript, put the disabled stuff here so we can show it in scenario window!
        --armavp = 0,
        --coravp = 0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff", -- blank
        scenarioid = "strongholdkilltraitor010", -- this MUST be present and identical to the one defined at start
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


			{name = 'corcom', x = 6930, y = 534, z = 7623, rot = -7963 , team = 0},
			{name = 'corsolar', x = 7080, y = 534, z = 7512, rot = -16384 , team = 0},
			{name = 'corsolar', x = 7080, y = 534, z = 7592, rot = -16384 , team = 0},
			{name = 'corsolar', x = 7080, y = 534, z = 7672, rot = -16384 , team = 0},
			{name = 'armfort', x = 752, y = 534, z = 576, rot = -16384 , team = 1},
			{name = 'armfort', x = 720, y = 534, z = 576, rot = 0 , team = 1},
			{name = 'armfort', x = 688, y = 534, z = 576, rot = 0 , team = 1},
			{name = 'armfort', x = 688, y = 534, z = 544, rot = 0 , team = 1},
			{name = 'armfort', x = 784, y = 534, z = 576, rot = -16384 , team = 1},
			{name = 'armfort', x = 784, y = 534, z = 544, rot = -16384 , team = 1},
			{name = 'armfort', x = 784, y = 534, z = 512, rot = -16384 , team = 1},
			{name = 'armfort', x = 784, y = 534, z = 480, rot = -16384 , team = 1},
			{name = 'armfort', x = 784, y = 534, z = 448, rot = -16384 , team = 1},
			{name = 'armfort', x = 752, y = 534, z = 448, rot = -16384 , team = 1},
			{name = 'armfort', x = 720, y = 534, z = 448, rot = -16384 , team = 1},
			{name = 'armfort', x = 688, y = 534, z = 448, rot = -16384 , team = 1},
			{name = 'armfort', x = 688, y = 534, z = 480, rot = -16384 , team = 1},
			{name = 'armfort', x = 688, y = 534, z = 512, rot = -16384 , team = 1},
			{name = 'armgate', x = 1040, y = 534, z = 832, rot = -16384 , team = 1},
			{name = 'corlab', x = 6944, y = 534, z = 7504, rot = 32767 , team = 0},
			{name = 'cormex', x = 7176, y = 534, z = 7320, rot = 32767 , team = 0},
			{name = 'cormex', x = 7224, y = 534, z = 7784, rot = 32767 , team = 0},
			{name = 'cormex', x = 7416, y = 397, z = 6712, rot = 32767 , team = 0},
			{name = 'cormex', x = 6616, y = 534, z = 7544, rot = 32767 , team = 0},
			{name = 'cornanotc', x = 6888, y = 534, z = 7752, rot = 32767 , team = 0},
			{name = 'cornanotc', x = 6968, y = 534, z = 7752, rot = 32767 , team = 0},
			{name = 'cormex', x = 7640, y = 397, z = 6216, rot = 32767 , team = 0},
			{name = 'cornanotc', x = 7032, y = 534, z = 7752, rot = 32767 , team = 0},
			{name = 'cormex', x = 7928, y = 397, z = 6504, rot = 32767 , team = 0},
			{name = 'corrad', x = 7712, y = 397, z = 6576, rot = 32767 , team = 0},
			{name = 'corjamt', x = 7648, y = 397, z = 6496, rot = 32767 , team = 0},
			{name = 'corjamt', x = 7184, y = 534, z = 7552, rot = 32767 , team = 0},
			{name = 'cormadsam', x = 7848, y = 397, z = 6328, rot = 32767 , team = 0},
			{name = 'cormadsam', x = 7704, y = 397, z = 6328, rot = 32767 , team = 0},
			{name = 'cormadsam', x = 7544, y = 397, z = 6328, rot = 32767 , team = 0},
			{name = 'corjamt', x = 6800, y = 534, z = 7552, rot = 32767 , team = 0},
			{name = 'corjamt', x = 6944, y = 534, z = 7280, rot = 32767 , team = 0},
			{name = 'corrad', x = 7024, y = 534, z = 7312, rot = 32767 , team = 0},
			{name = 'coradvsol', x = 6816, y = 534, z = 7808, rot = 32767 , team = 0},
			{name = 'coradvsol', x = 6880, y = 534, z = 7808, rot = 32767 , team = 0},
			{name = 'coradvsol', x = 6944, y = 534, z = 7808, rot = 32767 , team = 0},
			{name = 'coradvsol', x = 7008, y = 534, z = 7808, rot = 32767 , team = 0},
			{name = 'cormadsam', x = 7288, y = 534, z = 7448, rot = 32767 , team = 0},
			{name = 'cormadsam', x = 7288, y = 534, z = 7656, rot = 32767 , team = 0},
			{name = 'coradvsol', x = 7072, y = 534, z = 7808, rot = 32767 , team = 0},
			{name = 'cormadsam', x = 6696, y = 534, z = 7672, rot = 32767 , team = 0},
			{name = 'corhlt', x = 6624, y = 534, z = 7504, rot = 32767 , team = 0},
			{name = 'corhlt', x = 6720, y = 534, z = 7408, rot = 32767 , team = 0},
			--{name = 'corestor', x = 7696, y = 397, z = 6480, rot = 32767 , team = 0},
			{name = 'cordrag', x = 6480, y = 534, z = 7568, rot = 32767 , team = 0},
			{name = 'cordrag', x = 6496, y = 534, z = 7536, rot = 32767 , team = 0},
			{name = 'cordrag', x = 6544, y = 534, z = 7472, rot = 32767 , team = 0},
			{name = 'cordrag', x = 6576, y = 534, z = 7440, rot = 32767 , team = 0},
			{name = 'cordrag', x = 6624, y = 534, z = 7376, rot = 32767 , team = 0},
			{name = 'cordrag', x = 6640, y = 534, z = 7344, rot = 32767 , team = 0},
			{name = 'cordrag', x = 6688, y = 534, z = 7280, rot = 32767 , team = 0},
			{name = 'cordrag', x = 6720, y = 534, z = 7248, rot = 32767 , team = 0},
			{name = 'cordrag', x = 6736, y = 534, z = 7216, rot = 32767 , team = 0},
			{name = 'armmex', x = 936, y = 533, z = 488, rot = 32767 , team = 1},
			{name = 'armmex', x = 1448, y = 534, z = 680, rot = 32767 , team = 1},
			{name = 'armmex', x = 968, y = 534, z = 968, rot = 32767 , team = 1},
			{name = 'armmex', x = 728, y = 397, z = 1560, rot = 32767 , team = 1},
			{name = 'armmex', x = 216, y = 397, z = 1704, rot = 32767 , team = 1},
			{name = 'armmex', x = 552, y = 397, z = 2072, rot = 32767 , team = 1},
			{name = 'armrad', x = 480, y = 397, z = 1824, rot = 32767 , team = 1},
			{name = 'armcir', x = 768, y = 397, z = 1728, rot = 32767 , team = 1},
			{name = 'armcir', x = 672, y = 397, z = 2112, rot = 32767 , team = 1},
			{name = 'armcir', x = 224, y = 397, z = 2176, rot = 32767 , team = 1},
			{name = 'armcir', x = 448, y = 397, z = 2224, rot = 32767 , team = 1},
			{name = 'armferret', x = 344, y = 397, z = 2200, rot = 32767 , team = 1},
			{name = 'armferret', x = 584, y = 397, z = 2200, rot = 32767 , team = 1},
			{name = 'armferret', x = 792, y = 397, z = 1976, rot = 32767 , team = 1},
			{name = 'armcir', x = 2128, y = 534, z = 576, rot = 32767 , team = 1},
			{name = 'armcir', x = 2128, y = 534, z = 496, rot = 32767 , team = 1},
			{name = 'armpb', x = 1976, y = 534, z = 728, rot = 32767 , team = 1},
			{name = 'armpb', x = 1848, y = 531, z = 856, rot = 32767 , team = 1},
			{name = 'armpb', x = 1704, y = 531, z = 1000, rot = 32767 , team = 1},
			{name = 'armpb', x = 1528, y = 533, z = 1192, rot = 32767 , team = 1},
			{name = 'armamb', x = 1400, y = 534, z = 1240, rot = 32767 , team = 1},
			{name = 'armanni', x = 1744, y = 534, z = 912, rot = 32767 , team = 1},
			{name = 'armdrag', x = 1744, y = 534, z = 592, rot = 32767 , team = 1},
			{name = 'armdrag', x = 1744, y = 534, z = 624, rot = 32767 , team = 1},
			{name = 'armdrag', x = 1744, y = 534, z = 656, rot = 32767 , team = 1},
			{name = 'armdrag', x = 1712, y = 534, z = 656, rot = 32767 , team = 1},
			{name = 'armdrag', x = 1680, y = 534, z = 656, rot = 32767 , team = 1},
			{name = 'armdrag', x = 1680, y = 534, z = 624, rot = 32767 , team = 1},
			{name = 'armdrag', x = 1680, y = 534, z = 592, rot = 32767 , team = 1},
			{name = 'armdrag', x = 1712, y = 534, z = 592, rot = 32767 , team = 1},
			{name = 'armdrag', x = 880, y = 535, z = 608, rot = 32767 , team = 1},
			{name = 'armdrag', x = 880, y = 534, z = 640, rot = 32767 , team = 1},
			{name = 'armdrag', x = 880, y = 534, z = 672, rot = 32767 , team = 1},
			{name = 'armdrag', x = 912, y = 534, z = 672, rot = 32767 , team = 1},
			{name = 'armdrag', x = 944, y = 534, z = 672, rot = 32767 , team = 1},
			{name = 'armdrag', x = 944, y = 535, z = 640, rot = 32767 , team = 1},
			{name = 'armdrag', x = 944, y = 535, z = 608, rot = 32767 , team = 1},
			{name = 'armdrag', x = 912, y = 535, z = 608, rot = 32767 , team = 1},
			{name = 'armnanotc', x = 1096, y = 535, z = 568, rot = 32767 , team = 1},
			{name = 'armnanotc', x = 1288, y = 534, z = 568, rot = 32767 , team = 1},
			{name = 'armlab', x = 1184, y = 534, z = 704, rot = 0 , team = 1},
			--{name = 'armestor', x = 1080, y = 535, z = 440, rot = 0 , team = 1},
			{name = 'armadvsol', x = 1152, y = 534, z = 384, rot = 0 , team = 1},
			{name = 'armadvsol', x = 1216, y = 534, z = 384, rot = 0 , team = 1},
			{name = 'armadvsol', x = 1216, y = 534, z = 448, rot = 0 , team = 1},
			{name = 'armadvsol', x = 1152, y = 534, z = 448, rot = 0 , team = 1},
			--{name = 'armestor', x = 1080, y = 535, z = 376, rot = 0 , team = 1},
			{name = 'coreyes', x = 1716, y = 534, z = 621, rot = 0 , team = 0},
			{name = 'coreyes', x = 909, y = 535, z = 635, rot = 0 , team = 0},
			{name = 'armfort', x = 816, y = 534, z = 608, rot = 0 , team = 1},
			{name = 'armanni', x = 1584, y = 534, z = 1072, rot = 0 , team = 1},
			{name = 'armfort', x = 784, y = 534, z = 608, rot = 0 , team = 1},
			{name = 'armfort', x = 752, y = 534, z = 608, rot = 0 , team = 1},
			{name = 'armfort', x = 720, y = 534, z = 608, rot = 0 , team = 1},
			{name = 'armfort', x = 688, y = 534, z = 608, rot = 0 , team = 1},
			{name = 'armfort', x = 656, y = 534, z = 608, rot = 0 , team = 1},
			{name = 'armfort', x = 816, y = 534, z = 576, rot = 0 , team = 1},
			{name = 'armfort', x = 816, y = 535, z = 544, rot = 0 , team = 1},
			{name = 'armfort', x = 816, y = 535, z = 512, rot = 0 , team = 1},
			{name = 'armfort', x = 816, y = 535, z = 480, rot = 0 , team = 1},
			{name = 'armfort', x = 816, y = 535, z = 448, rot = 0 , team = 1},
			{name = 'armfort', x = 816, y = 535, z = 416, rot = 0 , team = 1},
			{name = 'armfort', x = 784, y = 534, z = 416, rot = 0 , team = 1},
			{name = 'armfort', x = 752, y = 534, z = 416, rot = 0 , team = 1},
			{name = 'armfort', x = 720, y = 534, z = 416, rot = 0 , team = 1},
			{name = 'armfort', x = 688, y = 534, z = 416, rot = 0 , team = 1},
			{name = 'armfort', x = 656, y = 534, z = 416, rot = 0 , team = 1},
			{name = 'armfort', x = 656, y = 534, z = 448, rot = 0 , team = 1},
			{name = 'armfort', x = 656, y = 534, z = 480, rot = 0 , team = 1},
			{name = 'armfort', x = 656, y = 534, z = 512, rot = 0 , team = 1},
			{name = 'armfort', x = 656, y = 534, z = 544, rot = 0 , team = 1},
			{name = 'armfort', x = 656, y = 534, z = 576, rot = 0 , team = 1},
			{name = 'cormadsam', x = 7016, y = 534, z = 7080, rot = 0 , team = 0},
			{name = 'corrad', x = 6752, y = 534, z = 7616, rot = 0 , team = 0},
			{name = 'armflak', x = 1072, y = 534, z = 1568, rot = 0 , team = 1},
			{name = 'armflak', x = 768, y = 397, z = 1856, rot = 0 , team = 1},
			{name = 'armflak', x = 1680, y = 534, z = 368, rot = 0 , team = 1},
			{name = 'armap', x = 440, y = 397, z = 1568, rot = 0 , team = 1},
			{name = 'armnanotc', x = 456, y = 397, z = 1768, rot = 0 , team = 1},
			{name = 'armdrag', x = 848, y = 534, z = 640, rot = 0 , team = 1},
			{name = 'armdrag', x = 816, y = 534, z = 640, rot = 0 , team = 1},
			{name = 'armdrag', x = 784, y = 534, z = 640, rot = 0 , team = 1},
			{name = 'armdrag', x = 752, y = 534, z = 640, rot = 0 , team = 1},
			{name = 'armdrag', x = 720, y = 534, z = 640, rot = 0 , team = 1},
			{name = 'armdrag', x = 688, y = 534, z = 640, rot = 0 , team = 1},
			{name = 'armdrag', x = 656, y = 534, z = 640, rot = 0 , team = 1},
			{name = 'armdrag', x = 624, y = 534, z = 640, rot = 0 , team = 1},
			{name = 'armdrag', x = 624, y = 534, z = 608, rot = 0 , team = 1},
			{name = 'armdrag', x = 624, y = 534, z = 576, rot = 0 , team = 1},
			{name = 'armdrag', x = 624, y = 534, z = 544, rot = 0 , team = 1},
			{name = 'armdrag', x = 624, y = 534, z = 512, rot = 0 , team = 1},
			{name = 'armdrag', x = 624, y = 534, z = 480, rot = 0 , team = 1},
			{name = 'armdrag', x = 624, y = 534, z = 448, rot = 0 , team = 1},
			{name = 'armdrag', x = 624, y = 534, z = 416, rot = 0 , team = 1},
			{name = 'armdrag', x = 624, y = 534, z = 384, rot = 0 , team = 1},
			{name = 'armdrag', x = 656, y = 534, z = 384, rot = 0 , team = 1},
			{name = 'armdrag', x = 688, y = 534, z = 384, rot = 0 , team = 1},
			{name = 'armdrag', x = 720, y = 534, z = 384, rot = 0 , team = 1},
			{name = 'armdrag', x = 752, y = 534, z = 384, rot = 0 , team = 1},
			{name = 'armdrag', x = 784, y = 534, z = 384, rot = 0 , team = 1},
			{name = 'armdrag', x = 816, y = 534, z = 384, rot = 0 , team = 1},
			{name = 'armdrag', x = 848, y = 535, z = 384, rot = 0 , team = 1},
			{name = 'armdrag', x = 848, y = 535, z = 416, rot = 0 , team = 1},
			{name = 'armdrag', x = 848, y = 535, z = 448, rot = 0 , team = 1},
			{name = 'armdrag', x = 848, y = 535, z = 480, rot = 0 , team = 1},
			{name = 'armdrag', x = 848, y = 535, z = 512, rot = 0 , team = 1},
			{name = 'armbeamer', x = 592, y = 534, z = 672, rot = 0 , team = 1},
			{name = 'armdrag', x = 848, y = 535, z = 544, rot = 0 , team = 1},
			{name = 'armdrag', x = 848, y = 535, z = 576, rot = 0 , team = 1},
			{name = 'armdrag', x = 848, y = 535, z = 608, rot = 0 , team = 1},
			{name = 'armbeamer', x = 880, y = 535, z = 352, rot = 0 , team = 1},
			{name = 'armbeamer', x = 592, y = 534, z = 352, rot = 0 , team = 1},
			{name = 'armfort', x = 1632, y = 533, z = 1056, rot = -16384 , team = 1},
			{name = 'armfort', x = 1632, y = 529, z = 1088, rot = -16384 , team = 1},
			{name = 'armfort', x = 1632, y = 520, z = 1120, rot = -16384 , team = 1},
			{name = 'armfort', x = 1600, y = 529, z = 1120, rot = 32767 , team = 1},
			{name = 'armfort', x = 1568, y = 533, z = 1120, rot = 32767 , team = 1},
			{name = 'armfort', x = 1536, y = 534, z = 1120, rot = 32767 , team = 1},
			{name = 'armfort', x = 1536, y = 534, z = 1088, rot = 16384 , team = 1},
			{name = 'armfort', x = 1536, y = 534, z = 1056, rot = 16384 , team = 1},
			{name = 'armfort', x = 1536, y = 534, z = 1024, rot = 16384 , team = 1},
			{name = 'armfort', x = 1568, y = 534, z = 1024, rot = 0 , team = 1},
			{name = 'armfort', x = 1600, y = 534, z = 1024, rot = 0 , team = 1},
			{name = 'armfort', x = 1632, y = 534, z = 1024, rot = 0 , team = 1},
			{name = 'armfort', x = 1792, y = 533, z = 896, rot = -16384 , team = 1},
			{name = 'armfort', x = 1792, y = 529, z = 928, rot = -16384 , team = 1},
			{name = 'armfort', x = 1792, y = 520, z = 960, rot = -16384 , team = 1},
			{name = 'armfort', x = 1760, y = 529, z = 960, rot = 32767 , team = 1},
			{name = 'armfort', x = 1728, y = 533, z = 960, rot = 32767 , team = 1},
			{name = 'armfort', x = 1696, y = 533, z = 960, rot = 32767 , team = 1},
			{name = 'armfort', x = 1696, y = 534, z = 928, rot = 16384 , team = 1},
			{name = 'armfort', x = 1696, y = 534, z = 896, rot = 16384 , team = 1},
			{name = 'armfort', x = 1696, y = 534, z = 864, rot = 16384 , team = 1},
			{name = 'armfort', x = 1728, y = 534, z = 864, rot = 0 , team = 1},
			{name = 'armfort', x = 1760, y = 534, z = 864, rot = 0 , team = 1},
			{name = 'armfort', x = 1792, y = 534, z = 864, rot = 0 , team = 1},
			{name = 'armsolar', x = 1384, y = 534, z = 440, rot = 0 , team = 1},
			{name = 'armsolar', x = 1464, y = 534, z = 440, rot = 0 , team = 1},
			{name = 'armsolar', x = 1544, y = 534, z = 440, rot = 0 , team = 1},
			{name = 'armsolar', x = 1544, y = 534, z = 360, rot = 0 , team = 1},
			{name = 'armsolar', x = 1464, y = 534, z = 360, rot = 0 , team = 1},
			{name = 'armsolar', x = 1384, y = 534, z = 360, rot = 0 , team = 1},
			{name = 'armwin', x = 264, y = 397, z = 1432, rot = 0 , team = 1},
			{name = 'armwin', x = 344, y = 397, z = 1432, rot = 0 , team = 1},
			{name = 'armwin', x = 344, y = 397, z = 1352, rot = 0 , team = 1},
			{name = 'armwin', x = 264, y = 397, z = 1352, rot = 0 , team = 1},
			{name = 'armwin', x = 264, y = 397, z = 1272, rot = 0 , team = 1},
			{name = 'armwin', x = 344, y = 397, z = 1272, rot = 0 , team = 1},
			{name = 'armwin', x = 344, y = 397, z = 1192, rot = 0 , team = 1},
			{name = 'armwin', x = 264, y = 397, z = 1192, rot = 0 , team = 1},
			{name = 'armwin', x = 264, y = 397, z = 1112, rot = 0 , team = 1},
			{name = 'armwin', x = 344, y = 399, z = 1112, rot = 0 , team = 1},
			{name = 'armwin', x = 344, y = 400, z = 1032, rot = 0 , team = 1},
			{name = 'armwin', x = 264, y = 397, z = 1032, rot = 0 , team = 1},
			{name = 'cormaw', x = 6656, y = 534, z = 7312, rot = 0 , team = 0},
			{name = 'cormaw', x = 6592, y = 534, z = 7408, rot = 0 , team = 0},
			{name = 'cormaw', x = 6512, y = 534, z = 7504, rot = 0 , team = 0},
			{name = 'armpb', x = 1272, y = 534, z = 1400, rot = 0 , team = 1},
			{name = 'corcom', x = 735, y = 534, z = 513, rot = 8469 , team = 1},

		},
		featureloadout = {
			-- Similarly to units, but these can also be resurrectable!
            -- You can /give corcom_dead with cheats when making your scenario, but it might not contain the 'resurrectas' tag, so be careful to add it if needed
			 -- {name = 'corcom_dead', x = 1125,y = 237, z = 734, rot = "0" , scale = 1.0, resurrectas = "corcom"}, -- there is no need for this dead comm here, just an example
            -- {name = 'armack_dead',  x = 1320,  y = 89,  z = 460,  rot = -928 , resurrectas = 'armack',  team = 0},

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
        Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.3758504 0.75682863 0.91179775;
		AllyTeam = 1;
		TeamLeader = 0;
        StartPosX = 1000;
        StartPosZ = 1000;
	}

	[team0]
	{
        Side = __PLAYERSIDE__;
		Handicap = __PLAYERHANDICAP__;
		RgbColor = 0.79311622 0.1523652 0.04604363;
		AllyTeam = 0;
		TeamLeader = 0;
        StartPosX = 7000;
        StartPosZ = 7000;
	}

	[modoptions]
	{
	  scenariooptions = __SCENARIOOPTIONS__;
	  startenergy = 7000;
	  ruins = enabled;
	}

	[allyTeam1]
	{
		numallies = 0;
	}

	[ai0]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = Enemy;
		ShortName = BARb;
		Team = 1;
        Version = stable;
	}

	[player0]
	{
		IsFromDemo = 0;
        Name = __PLAYERNAME__;
		Team = 0;
		rank = 0;
	}

	NumRestrictions=__NUMRESTRICTIONS__;

	[RESTRICT]
	{
        __RESTRICTEDUNITS__
	}

	hostip = 127.0.0.1;
	hostport = 0;
	numplayers = 1;
	startpostype = 3; // 0 fixed, 1 random, 2 choose in game, 3 choose before game (see StartPosX)
	mapname = Stronghold V4;
	ishost = 1; //
	//numusers = 2;
    gametype = __BARVERSION__;
    GameStartDelay = 10;  // seconds before game starts after loading/placement
    myplayername = __PLAYERNAME__;
	nohelperais = 0;
}
	]],

}

return scenariodata

--[[
 [Game]
{
	[allyTeam0]
	{
		startrectright = 0.98892993;
		startrectbottom = 1;
		startrectleft = 0.7896679;
		numallies = 0;
		startrecttop = 0.80811805;
	}

	[team1]
	{
		Side = Armada;
		Handicap = 0;
		RgbColor = 0.59871912 0.25364691 0.36091965;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[team0]
	{
		Side = Cortex;
		Handicap = 0;
		RgbColor = 0.65360999 0.77162737 0.15025288;
		AllyTeam = 0;
		TeamLeader = 0;
	}

	[modoptions]
	{
		startenergy = 7000;
	}

	[allyTeam1]
	{
		startrectright = 0.22509223;
		startrectbottom = 0.23247233;
		startrectleft = 0.02583026;
		numallies = 0;
		startrecttop = 0.03321033;
	}

	[ai0]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbstable(1);
		ShortName = BARb;
		Team = 1;
		Version = stable;
	}

	[player0]
	{
		IsFromDemo = 0;
		Name = [teh]Behe_Chobby3;
		Team = 0;
		rank = 0;
	}

	hostip = 127.0.0.1;
	hostport = 0;
	numplayers = 1;
	startpostype = 2;
	mapname = Stronghold V4;
	ishost = 1;
	numusers = 2;
	gametype = Beyond All Reason test-15839-d0c313f;
	GameStartDelay = 5;
	myplayername = [teh]Behe_Chobby3;
	nohelperais = 0;
}

]]--
