local scenariodata = {
	index			= 8, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "Fallendellheadstart008", -- no spaces, lowercase, this will be used to save the score and can be used gadget side
    version         = "1", -- increment this to reset the score when changing a mission, as scores are keyed by (scenarioid,version,difficulty)
	title			= "A Head Start", -- can be anything
	author			= "Beherith", -- your name here
	imagepath		= "scenario008.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "Your starting base", -- This text will be drawn over image
    summary         = [[An enemy Commander has set up operations on Fallendell, where you already have a strong presence. Prevent him from taking further territory.]],
	briefing 		= [[You will start with a small base of operations, and a considerable amount of resources. Use your initial scouting units to locate the enemy commander and liquidate him before he gains a foothold.
 
 
Tips:
 
 ‣  Construction Turrets will assist in the construction of any unit or building within their build radius.
 
 ‣  The enemy Commander will try to expand to get more resources, stop him as soon as you feel ready for it
 
 ‣  Continue building a farm of Wind Generators on the hill where they can be easily protected
 
 ‣  Build attacking units immediately or use your advantage to build a Tier 2 Bot Lab for advanced units
  
 
Scoring:
  
 ‣  Time taken to complete the scenario
 ‣  Resources spent to get a confirmed kill on all enemy units.
 
 ]],

	mapfilename		= "Fallendell_V4", -- the name of the map to be displayed here, and which to play on, no .smf ending needed
	playerstartx	= "20%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "20%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 3000, -- par time in seconds (time a mission is expected to take on average)
	parresources	= 1000000, -- par resource amount (amount of metal one is expected to spend on mission)
	difficulty		= 1, -- Percieved difficulty at 'normal' level: integer 1-10
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
    allowedsides     = {"Armada"}, --these are the permitted factions for this mission, ch0ose from {"Armada", "Cortex", "Random"}
	victorycondition= "Kill all enemy construction units", -- This is plaintext, but should be reflected in startscript
	losscondition	= "Lose all of your construction units",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberofthese units, 0 means disable it
        -- dont use the one in startscript, put the disabled stuff here so we can show it in scenario window!
        --armavp = 0,
        --coravp = 0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff", -- blank
        scenarioid = "Fallendellheadstart008", -- this MUST be present and identical to the one defined at start
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

            {name = 'corcom', x = 5393, y = 52, z = 2270, rot = -8148 , team = 1},
            {name = 'armcom', x = 1657, y = 154, z = 836, rot = 22554 , team = 0},
            {name = 'cormex', x = 5816, y = 4, z = 3032, rot = 0 , team = 1},
            {name = 'armmex', x = 1048, y = 154, z = 952, rot = 16384 , team = 0},
            {name = 'cormex', x = 5992, y = 4, z = 2808, rot = 0 , team = 1},
            {name = 'armmex', x = 1288, y = 154, z = 984, rot = 16384 , team = 0},
            {name = 'armsolar', x = 1032, y = 154, z = 888, rot = 16384 , team = 0},
            {name = 'armmex', x = 1176, y = 154, z = 680, rot = 16384 , team = 0},
            {name = 'armwin', x = 1080, y = 154, z = 792, rot = 16384 , team = 0},
            {name = 'armwin', x = 1032, y = 154, z = 792, rot = 16384 , team = 0},
            {name = 'cormex', x = 5944, y = 51, z = 2040, rot = 0 , team = 1},
            {name = 'armwin', x = 984, y = 154, z = 792, rot = 16384 , team = 0},
            {name = 'armwin', x = 984, y = 154, z = 744, rot = 16384 , team = 0},
            {name = 'corsolar', x = 5688, y = 52, z = 2168, rot = -16384 , team = 1},
            {name = 'armwin', x = 1032, y = 154, z = 744, rot = 16384 , team = 0},
            {name = 'armwin', x = 1080, y = 154, z = 744, rot = 16384 , team = 0},
            {name = 'corlab', x = 5696, y = 52, z = 2000, rot = 32767 , team = 1},
            {name = 'armlab', x = 1280, y = 154, z = 832, rot = 16384 , team = 0},
            {name = 'armflea', x = 1180, y = 161, z = 1137, rot = -16814 , team = 0},
            {name = 'corwin', x = 5784, y = 52, z = 2008, rot = 32767 , team = 1},
            {name = 'armck', x = 2294, y = 52, z = 2245, rot = 7150 , team = 0},
            {name = 'corwin', x = 5784, y = 52, z = 1864, rot = 32767 , team = 1},
            {name = 'corwin', x = 5816, y = 52, z = 2120, rot = 0 , team = 1},
            {name = 'armllt', x = 992, y = 157, z = 1008, rot = 16384 , team = 0},
            {name = 'armck', x = 243, y = 4, z = 2187, rot = -7164 , team = 0},
            {name = 'corsolar', x = 5640, y = 52, z = 1864, rot = -16384 , team = 1},
            {name = 'armllt', x = 1424, y = 154, z = 624, rot = 16384 , team = 0},
            {name = 'armpw', x = 1399, y = 154, z = 773, rot = -22048 , team = 0},
            {name = 'armwin', x = 1352, y = 154, z = 648, rot = 16384 , team = 0},
            {name = 'armwin', x = 1304, y = 154, z = 648, rot = 16384 , team = 0},
            {name = 'armpw', x = 1397, y = 154, z = 846, rot = 30828 , team = 0},
            {name = 'armwin', x = 1256, y = 154, z = 648, rot = 16384 , team = 0},
            {name = 'armmex', x = 2472, y = 101, z = 248, rot = 16384 , team = 0},
            {name = 'armpw', x = 1389, y = 154, z = 915, rot = 30522 , team = 0},
            {name = 'armwin', x = 1256, y = 154, z = 600, rot = 16384 , team = 0},
            {name = 'armmex', x = 1288, y = 52, z = 1368, rot = 16384 , team = 0},
            {name = 'armwin', x = 1304, y = 154, z = 600, rot = 16384 , team = 0},
            {name = 'armck', x = 1048, y = 154, z = 842, rot = -15558 , team = 0},
            {name = 'corwin', x = 5912, y = 52, z = 1864, rot = 16384 , team = 1},
            {name = 'armwin', x = 1352, y = 154, z = 600, rot = 16384 , team = 0},
            {name = 'armllt', x = 2576, y = 101, z = 320, rot = 16384 , team = 0},
            {name = 'cormakr', x = 5704, y = 52, z = 1832, rot = 32767 , team = 1},
            {name = 'armllt', x = 1296, y = 52, z = 1456, rot = 16384 , team = 0},
            {name = 'armck', x = 1385, y = 154, z = 611, rot = -25716 , team = 0},
            {name = 'armck', x = 1082, y = 155, z = 538, rot = 1161 , team = 0},
            {name = 'cormakr', x = 5960, y = 53, z = 2120, rot = 16384 , team = 1},
            {name = 'cormakr', x = 5640, y = 52, z = 1720, rot = 32767 , team = 1},
            {name = 'armck', x = 3359, y = 52, z = 769, rot = 15796 , team = 0},
            {name = 'armnanotc', x = 1160, y = 154, z = 776, rot = 16384 , team = 0},
            {name = 'armmex', x = 2248, y = 52, z = 2264, rot = 16384 , team = 0},
            {name = 'corsolar', x = 5576, y = 52, z = 2008, rot = -16384 , team = 1},
            {name = 'armpw', x = 1396, y = 154, z = 699, rot = -17280 , team = 0},
            {name = 'armwin', x = 1352, y = 208, z = 216, rot = 16384 , team = 0},
            {name = 'armllt', x = 2368, y = 52, z = 2336, rot = 16384 , team = 0},
            {name = 'corhlt', x = 5280, y = 70, z = 2016, rot = -16384 , team = 1},
            {name = 'armmex', x = 392, y = 5, z = 2088, rot = 16384 , team = 0},
            {name = 'cormex', x = 5112, y = 101, z = 1544, rot = 0 , team = 1},
            {name = 'armwin', x = 1304, y = 208, z = 216, rot = 16384 , team = 0},
            {name = 'armnanotc', x = 1160, y = 154, z = 856, rot = 16384 , team = 0},
            {name = 'corsolar', x = 5288, y = 52, z = 2136, rot = 0 , team = 1},
            {name = 'armrad', x = 2352, y = 52, z = 2224, rot = 16384 , team = 0},
            {name = 'armnanotc', x = 1160, y = 154, z = 936, rot = 16384 , team = 0},
            {name = 'armwin', x = 1256, y = 208, z = 216, rot = 16384 , team = 0},
            {name = 'armmex', x = 168, y = 4, z = 2280, rot = 16384 , team = 0},
            {name = 'armwin', x = 1208, y = 208, z = 216, rot = 16384 , team = 0},
            {name = 'armllt', x = 336, y = 5, z = 2240, rot = 16384 , team = 0},
            {name = 'corwin', x = 6120, y = 52, z = 1864, rot = 16384 , team = 1},
            {name = 'armwin', x = 1160, y = 209, z = 216, rot = 16384 , team = 0},
            {name = 'cormex', x = 5048, y = 101, z = 1320, rot = 0 , team = 1},
            {name = 'armflea', x = 1147, y = 160, z = 1131, rot = -10036 , team = 0},
            {name = 'armflea', x = 1203, y = 164, z = 1155, rot = -7163 , team = 0},
            {name = 'armrad', x = 208, y = 4, z = 2144, rot = 16384 , team = 0},
            {name = 'armflea', x = 1249, y = 162, z = 1142, rot = -14099 , team = 0},
            {name = 'armwin', x = 1112, y = 209, z = 216, rot = 16384 , team = 0},
            {name = 'cormstor', x = 5992, y = 52, z = 1864, rot = -16384 , team = 1},
            {name = 'armrad', x = 1328, y = 154, z = 928, rot = 16384 , team = 0},
            {name = 'armmex', x = 3096, y = 52, z = 728, rot = 16384 , team = 0},
            {name = 'armllt', x = 1408, y = 157, z = 1088, rot = 16384 , team = 0},
            {name = 'armrl', x = 1304, y = 155, z = 520, rot = 16384 , team = 0},
            {name = 'armrl', x = 1128, y = 155, z = 1016, rot = 16384 , team = 0},
            {name = 'corak', x = 5697, y = 52, z = 1720, rot = -29165 , team = 1},
            {name = 'armrl', x = 920, y = 154, z = 856, rot = 16384 , team = 0},
            --{name = 'armestor', x = 1096, y = 154, z = 664, rot = 16384 , team = 0},
            {name = 'corthud', x = 5744, y = 52, z = 1790, rot = -32739 , team = 1},
            {name = 'armmex', x = 3480, y = 52, z = 776, rot = 16384 , team = 0},
            {name = 'corrad', x = 5296, y = 53, z = 2368, rot = 0 , team = 1},
            {name = 'corak', x = 5698, y = 52, z = 1998, rot = 32767 , team = 1},

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
        Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.63758504 0.35682863 0.61179775;
		AllyTeam = 1;
		TeamLeader = 0;
        StartPosX = 5000;
        StartPosZ = 1400;
	}

	[team0]
	{
        Side = __PLAYERSIDE__;
		Handicap = __PLAYERHANDICAP__;
		RgbColor = 0.59311622 0.61523652 0.54604363;
		AllyTeam = 0;
		TeamLeader = 0;
        StartPosX = 1200;
        StartPosZ = 800;
	}

	[modoptions]
	{
        deathmode = builders;
        scenariooptions = __SCENARIOOPTIONS__;
        startenergy = 7000;
	}

	[allyTeam1]
	{
		numallies = 0;
	}

	[ai0]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = SimpleAI  (2);
		ShortName = SimpleAI;
		Team = 1;
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
    GameStartDelay = 5;  // seconds before game starts after loading/placement
    myplayername = __PLAYERNAME__;
	nohelperais = 0;
}
	]],

}

return scenariodata

