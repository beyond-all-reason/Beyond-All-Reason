local scenariodata = {
	index			= 9, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "Tundrabackfromthedead009", -- no spaces, lowercase, this will be used to save the score and can be used gadget side
    version         = "1", -- increment this to reset the score when changing a mission, as scores are keyed by (scenarioid,version,difficulty)
	title			= "Back from the Dead", -- can be anything
	author			= "Beherith", -- your name here
	imagepath		= "scenario009.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "All is not lost", -- This text will be drawn over image
    summary         = [[After a ferocious battle, you are left with only a handful of Rezzer's, tasked to resurrect your army. Beware though, it seems that you might not be alone with this goal]],
	briefing 		= [[You will start with some Graverobbers (Resurrection and Repair Bots), that can resurrect units from their wrecks, though they are unable to resurrect units that have been destroyed beyond repair into just heaps of metal. While Graverobbers cannot build any units on their own, your only hope is to find the wrecks of some construction bots and rebuild everything anew. Units that are resurrected, become active with 0 health, but Graverobbers will continue to repair them back to full health. Graverobbers can also reclaim wrecks from the battlefield for their metal very rapidly, if needed.

Tips:
 - Resurrection bots will use Energy to resurrect units, at a flat cost of 75e per second while resurrecting.
 - You can issue Area-Resurrect and Area-Reclaim commands by right-click dragging
 - Repairing units does not cost any resources.
 - Wrecks of units contain about 60% of their original metal cost, so resurrecting them will be more cost effective, but also slower.
 - Reclaiming is much faster than resurrecting, and can also help you fund your economy very rapidly
 - Resurrect Construction Units and a Factory as soon as possible!
 - There can also be neutral units among the wreckage, these will only return fire if attacked.
 - You can capture neutral (or enemy) units and structures with Commanders and Decoy Commanders

Scoring:
 - Time taken to complete the scenario
 - Resources spent to get a confirmed kill on all enemy units.
 ]],

	mapfilename		= "Tundra_V2", -- the name of the map to be displayed here, and which to play on, no .smf ending needed
	playerstartx	= "15%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "15%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 2000, -- par time in seconds (time a mission is expected to take on average)
	parresources	= 1000000, -- par resource amount (amount of metal one is expected to spend on mission)
	difficulty		= 3, -- Percieved difficulty at 'normal' level: integer 1-10
    defaultdifficulty = "Normal", -- an entry of the difficulty table
    difficulties    = { -- Array for sortedness, Keys are text that appears in selector (as well as in scoring!), values are handicap levels
    -- handicap values range [-100 - +100], with 0 being regular resources
    -- Currently difficulty modifier only affects the resource bonuses
        {name = "Beginner", playerhandicap = 50, enemyhandicap=0},
        {name = "Novice"  , playerhandicap = 25, enemyhandicap=0},
        {name = "Normal"  , playerhandicap = 0, enemyhandicap=0},
        {name = "Hard"    , playerhandicap = 0,  enemyhandicap=25},
        {name = "Brutal" , playerhandicap = 0,  enemyhandicap=50},
    },
    allowedsides     = {"Cortex"}, --these are the permitted factions for this mission, ch0ose from {"Armada", "Cortex", "Random"}
	victorycondition= "Kill all construction units", -- This is plaintext, but should be reflected in startscript
	losscondition	= "Lose all of your construction units",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberofthese units, 0 means disable it
        -- dont use the one in startscript, put the disabled stuff here so we can show it in scenario window!
        --armavp = 0,
        --coravp = 0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff", -- blank
        scenarioid = "Tundrabackfromthedead009", -- this MUST be present and identical to the one defined at start
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


            {name = 'armadvsol', x = 6704, y = 90, z = 7184, rot = -16384 , team = 1},
            {name = 'armadvsol', x = 6704, y = 90, z = 7248, rot = -16384 , team = 1},
            {name = 'armadvsol', x = 6704, y = 90, z = 7312, rot = -16384 , team = 1},
            {name = 'armadvsol', x = 6704, y = 90, z = 7376, rot = -16384 , team = 1},
            {name = 'armadvsol', x = 6768, y = 90, z = 7184, rot = -16384 , team = 1},
            {name = 'armrectr', x = 6338, y = 91, z = 7203, rot = -28093 , team = 1},
            {name = 'armrectr', x = 6396, y = 90, z = 7203, rot = -24876 , team = 1},
            {name = 'armrectr', x = 6449, y = 90, z = 7203, rot = 32287 , team = 1},
            {name = 'armrectr', x = 6511, y = 90, z = 7185, rot = -27573 , team = 1},
            {name = 'armrectr', x = 6511, y = 90, z = 7209, rot = -29780 , team = 1},
            {name = 'coradvsol', x = 1312, y = 90, z = 944, rot = -16384 , team = 0},
            {name = 'coradvsol', x = 1376, y = 89, z = 816, rot = -16384 , team = 0},
            {name = 'coradvsol', x = 1376, y = 90, z = 1008, rot = -16384 , team = 0},
            {name = 'coradvsol', x = 1376, y = 90, z = 1072, rot = -16384 , team = 0},
            {name = 'coradvsol', x = 1376, y = 90, z = 880, rot = -16384 , team = 0},
            {name = 'coradvsol', x = 1376, y = 90, z = 944, rot = -16384 , team = 0},
            {name = 'cornecro', x = 1443, y = 90, z = 1233, rot = -19970 , team = 0},
            {name = 'cornecro', x = 1556, y = 90, z = 1238, rot = -21582 , team = 0},
            {name = 'cornecro', x = 1670, y = 90, z = 1246, rot = -14935 , team = 0},
            {name = 'cornecro', x = 1770, y = 90, z = 1226, rot = 13024 , team = 0},
            {name = 'cornecro', x = 1903, y = 93, z = 1203, rot = 15314 , team = 0},

		},
		featureloadout = {
			-- Similarly to units, but these can also be resurrectable!
            -- You can /give corcom_dead with cheats when making your scenario, but it might not contain the 'resurrectas' tag, so be careful to add it if needed
			 -- {name = 'corcom_dead', x = 1125,y = 237, z = 734, rot = "0" , scale = 1.0, resurrectas = "corcom"}, -- there is no need for this dead comm here, just an example
             {name = 'armack_dead',  x = 1320,  y = 89,  z = 460,  rot = -928 , resurrectas = 'armack',  team = 0},
{name = 'armadvsol_dead',  x = 6768,  y = 90,  z = 7248,  rot = -16384 , resurrectas = 'armadvsol',  team = 1},
{name = 'armadvsol_dead',  x = 6768,  y = 90,  z = 7312,  rot = -16384 , resurrectas = 'armadvsol',  team = 1},
{name = 'armadvsol_dead',  x = 6768,  y = 90,  z = 7376,  rot = -16384 , resurrectas = 'armadvsol',  team = 1},
{name = 'armbeamer_dead',  x = 6272,  y = 92,  z = 6848,  rot = -16384 , resurrectas = 'armbeamer',  team = 1},
{name = 'armbeamer_dead',  x = 6496,  y = 90,  z = 6848,  rot = -16384 , resurrectas = 'armbeamer',  team = 1},
{name = 'armbeamer_dead',  x = 6672,  y = 89,  z = 6832,  rot = -16384 , resurrectas = 'armbeamer',  team = 1},
{name = 'armbeamer_dead',  x = 6848,  y = 91,  z = 6832,  rot = -16384 , resurrectas = 'armbeamer',  team = 1},
{name = 'armck_dead',  x = 5629,  y = 128,  z = 7599,  rot = -1055 , resurrectas = 'armck',  team = 1},
{name = 'armck_dead',  x = 6207,  y = 92,  z = 7342,  rot = -17568 , resurrectas = 'armck',  team = 1},
{name = 'armck_dead',  x = 6472,  y = 90,  z = 7249,  rot = 10199 , resurrectas = 'armck',  team = 1},
{name = 'armck_dead',  x = 6661,  y = 90,  z = 7204,  rot = 25148 , resurrectas = 'armck',  team = 1},
{name = 'armck_dead',  x = 6721,  y = 90,  z = 6852,  rot = 18051 , resurrectas = 'armck',  team = 1},
{name = 'armestor_dead',  x = 6744,  y = 90,  z = 7112,  rot = -16384 , resurrectas = 'armestor',  team = 1},
{name = 'armlab_dead',  x = 6464,  y = 89,  z = 7312,  rot = -16384 , resurrectas = 'armlab',  team = 1},
{name = 'armllt_dead',  x = 5600,  y = 127,  z = 7520,  rot = -16384 , resurrectas = 'armllt',  team = 1},
{name = 'armllt_dead',  x = 5616,  y = 126,  z = 7424,  rot = -16384 , resurrectas = 'armllt',  team = 1},
{name = 'armllt_dead',  x = 5616,  y = 128,  z = 7280,  rot = -16384 , resurrectas = 'armllt',  team = 1},
{name = 'armllt_dead',  x = 5616,  y = 129,  z = 7728,  rot = -16384 , resurrectas = 'armllt',  team = 1},
{name = 'armllt_dead',  x = 5632,  y = 131,  z = 7120,  rot = -16384 , resurrectas = 'armllt',  team = 1},
{name = 'armllt_dead',  x = 5712,  y = 133,  z = 6992,  rot = -16384 , resurrectas = 'armllt',  team = 1},
{name = 'armllt_dead',  x = 6016,  y = 107,  z = 7136,  rot = -16384 , resurrectas = 'armllt',  team = 1},
{name = 'armllt_dead',  x = 6016,  y = 110,  z = 6976,  rot = -16384 , resurrectas = 'armllt',  team = 1},
{name = 'armllt_dead',  x = 6160,  y = 95,  z = 6848,  rot = -16384 , resurrectas = 'armllt',  team = 1},
{name = 'armllt_dead',  x = 6384,  y = 90,  z = 6832,  rot = -16384 , resurrectas = 'armllt',  team = 1},
{name = 'armllt_dead',  x = 6576,  y = 90,  z = 6832,  rot = -16384 , resurrectas = 'armllt',  team = 1},
{name = 'armllt_dead',  x = 6752,  y = 89,  z = 6832,  rot = -16384 , resurrectas = 'armllt',  team = 1},
{name = 'armllt_dead',  x = 6928,  y = 110,  z = 6832,  rot = -16384 , resurrectas = 'armllt',  team = 1},
{name = 'armmex_dead',  x = 6456,  y = 85,  z = 7608,  rot = -16384 , resurrectas = 'armmex',  team = 1},
{name = 'armmex_dead',  x = 6472,  y = 90,  z = 7160,  rot = -16384 , resurrectas = 'armmex',  team = 1},
{name = 'armmex_dead',  x = 6728,  y = 90,  z = 7448,  rot = -16384 , resurrectas = 'armmex',  team = 1},
{name = 'armmoho_dead',  x = 1432,  y = 89,  z = 680,  rot = -16384 , resurrectas = 'armmoho',  team = 0},
{name = 'armnanotc_dead',  x = 6568,  y = 89,  z = 7320,  rot = -16384 , resurrectas = 'armnanotc',  team = 1},
{name = 'armnanotc_dead',  x = 6568,  y = 90,  z = 7208,  rot = -16384 , resurrectas = 'armnanotc',  team = 1},
{name = 'armnanotc_dead',  x = 6568,  y = 90,  z = 7272,  rot = -16384 , resurrectas = 'armnanotc',  team = 1},
{name = 'armrad_dead',  x = 6128,  y = 95,  z = 7312,  rot = -16384 , resurrectas = 'armrad',  team = 1},
{name = 'armrad_dead',  x = 6288,  y = 91,  z = 7280,  rot = -16384 , resurrectas = 'armrad',  team = 1},
{name = 'armwin_dead',  x = 6552,  y = 88,  z = 7544,  rot = -16384 , resurrectas = 'armwin',  team = 1},
{name = 'armwin_dead',  x = 6552,  y = 88,  z = 7592,  rot = -16384 , resurrectas = 'armwin',  team = 1},
{name = 'armwin_dead',  x = 6600,  y = 88,  z = 7592,  rot = -16384 , resurrectas = 'armwin',  team = 1},
{name = 'armwin_dead',  x = 6600,  y = 89,  z = 7544,  rot = -16384 , resurrectas = 'armwin',  team = 1},
{name = 'armwin_dead',  x = 6648,  y = 89,  z = 7544,  rot = -16384 , resurrectas = 'armwin',  team = 1},
{name = 'armwin_dead',  x = 6648,  y = 89,  z = 7592,  rot = -16384 , resurrectas = 'armwin',  team = 1},
{name = 'armwin_dead',  x = 6696,  y = 89,  z = 7544,  rot = -16384 , resurrectas = 'armwin',  team = 1},
{name = 'armwin_dead',  x = 6696,  y = 89,  z = 7592,  rot = -16384 , resurrectas = 'armwin',  team = 1},
{name = 'armwin_dead',  x = 6744,  y = 89,  z = 7544,  rot = -16384 , resurrectas = 'armwin',  team = 1},
{name = 'armwin_dead',  x = 6744,  y = 89,  z = 7592,  rot = -16384 , resurrectas = 'armwin',  team = 1},
{name = 'armwin_dead',  x = 6792,  y = 89,  z = 7592,  rot = -16384 , resurrectas = 'armwin',  team = 1},
{name = 'armwin_dead',  x = 6792,  y = 90,  z = 7544,  rot = -16384 , resurrectas = 'armwin',  team = 1},
{name = 'coradvsol_dead',  x = 1312,  y = 89,  z = 816,  rot = -16384 , resurrectas = 'coradvsol',  team = 0},
{name = 'coradvsol_dead',  x = 1312,  y = 89,  z = 880,  rot = -16384 , resurrectas = 'coradvsol',  team = 0},
{name = 'coradvsol_dead',  x = 1312,  y = 90,  z = 1008,  rot = -16384 , resurrectas = 'coradvsol',  team = 0},
{name = 'coradvsol_dead',  x = 1312,  y = 90,  z = 1072,  rot = -16384 , resurrectas = 'coradvsol',  team = 0},
{name = 'corck_dead',  x = 1500,  y = 89,  z = 1427,  rot = -29942 , resurrectas = 'corck',  team = 0},
{name = 'corck_dead',  x = 1554,  y = 89,  z = 794,  rot = -13057 , resurrectas = 'corck',  team = 0},
{name = 'corck_dead',  x = 1857,  y = 91,  z = 1016,  rot = -19032 , resurrectas = 'corck',  team = 0},
{name = 'corck_dead',  x = 1902,  y = 91,  z = 917,  rot = -24128 , resurrectas = 'corck',  team = 0},
{name = 'corck_dead',  x = 2060,  y = 98,  z = 1322,  rot = 25705 , resurrectas = 'corck',  team = 0},
{name = 'corestor_dead',  x = 1440,  y = 89,  z = 832,  rot = -16384 , resurrectas = 'corestor',  team = 0},
{name = 'corexp_dead',  x = 1496,  y = 90,  z = 1784,  rot = -16384 , resurrectas = 'corexp',  team = 0},
{name = 'corexp_dead',  x = 1896,  y = 91,  z = 2296,  rot = -16384 , resurrectas = 'corexp',  team = 0},
{name = 'corexp_dead',  x = 3048,  y = 131,  z = 920,  rot = -16384 , resurrectas = 'corexp',  team = 0},
{name = 'corexp_dead',  x = 3368,  y = 131,  z = 1032,  rot = -16384 , resurrectas = 'corexp',  team = 0},
{name = 'corexp_dead',  x = 3448,  y = 131,  z = 1688,  rot = -16384 , resurrectas = 'corexp',  team = 0},
{name = 'corexp_dead',  x = 3592,  y = 131,  z = 808,  rot = -16384 , resurrectas = 'corexp',  team = 0},
{name = 'corlab_dead',  x = 1536,  y = 90,  z = 1008,  rot = 0 , resurrectas = 'corlab',  team = 0},
{name = 'corllt_dead',  x = 1280,  y = 106,  z = 1408,  rot = -16384 , resurrectas = 'corllt',  team = 0},
{name = 'corllt_dead',  x = 1456,  y = 90,  z = 1392,  rot = -16384 , resurrectas = 'corllt',  team = 0},
{name = 'corllt_dead',  x = 1680,  y = 90,  z = 1392,  rot = -16384 , resurrectas = 'corllt',  team = 0},
{name = 'corllt_dead',  x = 1872,  y = 91,  z = 1360,  rot = -16384 , resurrectas = 'corllt',  team = 0},
{name = 'corllt_dead',  x = 2032,  y = 98,  z = 1184,  rot = -16384 , resurrectas = 'corllt',  team = 0},
{name = 'corllt_dead',  x = 2048,  y = 83,  z = 560,  rot = -16384 , resurrectas = 'corllt',  team = 0},
{name = 'corllt_dead',  x = 2048,  y = 90,  z = 768,  rot = -16384 , resurrectas = 'corllt',  team = 0},
{name = 'corllt_dead',  x = 2048,  y = 97,  z = 976,  rot = -16384 , resurrectas = 'corllt',  team = 0},
{name = 'cormaw_dead',  x = 2048,  y = 98,  z = 1072,  rot = -16384 , resurrectas = 'cormaw',  team = 0},
{name = 'cormex_dead',  x = 1512,  y = 89,  z = 680,  rot = 0 , resurrectas = 'cormex',  team = 0},
{name = 'cormex_dead',  x = 1688,  y = 90,  z = 1048,  rot = 0 , resurrectas = 'cormex',  team = 0},
{name = 'cormex_dead',  x = 1720,  y = 85,  z = 584,  rot = 0 , resurrectas = 'cormex',  team = 0},
{name = 'cornanotc_dead',  x = 1576,  y = 89,  z = 872,  rot = -16384 , resurrectas = 'cornanotc',  team = 0},
{name = 'cornanotc_dead',  x = 1672,  y = 89,  z = 872,  rot = -16384 , resurrectas = 'cornanotc',  team = 0},
{name = 'cornanotc_dead',  x = 1768,  y = 89,  z = 872,  rot = -16384 , resurrectas = 'cornanotc',  team = 0},

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
        StartPosX = 7000;
        StartPosZ = 7000;
	}

	[team0]
	{
        Side = __PLAYERSIDE__;
		Handicap = __PLAYERHANDICAP__;
		RgbColor = 0.79311622 0.1523652 0.04604363;
		AllyTeam = 0;
		TeamLeader = 0;
        StartPosX = 1300;
        StartPosZ = 1300;
	}

	[modoptions]
	{
        deathmode = builders;
        scenariooptions = __SCENARIOOPTIONS__;
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
    mapname = __MAPNAME__;
	ishost = 1;
	numusers = 2;
    gametype = __BARVERSION__;
    GameStartDelay = 10;  // seconds before game starts after loading/placement
    myplayername = __PLAYERNAME__;
	nohelperais = 0;
}
	]],

}

return scenariodata

