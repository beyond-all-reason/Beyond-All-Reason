local scenariodata = {
	index			= 1, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "supcrossingvsbarbs001", -- no spaces, lowercase, this will be used to save the score
    version         = "1", -- increment this to keep the score when changing a mission
	title			= "Outsmart the Barbarians", -- can be anything
	author			= "Beherith", -- your name here
	imagepath		= "scenario001.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "Rocks can contain a lot of metal...", -- This text will be drawn over image
    summary         = [[Three aggressive barbarians have landed in the top right corner of the map. Neutralize them.]],
briefing 		= [[Fortify your side of the crossing as soon as possible, before the hordes start moving across. All units can pass through the central shallow isthmus, with the notable exception of Tick. The shallow water connects the two seas, and control over the vast amount of metal they hold is key to victory.

Score:
    1. Speed: destroy the enemy Commanders as fast as possible.
    2. Efficiency: minimize the amount of metal and energy used.

Tips:
    1. The map contains many rocks, reclaim them for metal to quickly progress.
    ]],

	mapfilename		= "Supreme_Crossing_V1", -- the name of the map to be displayed here, and which to play on, no .smf ending needed
	playerstartx	= "25%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "75%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 3000, -- par time in seconds
	parresources	= 1000000, -- par resource amount
	difficulty		= 5, -- Percieved difficulty at 'normal' level: integer 1-10
    defaultdifficulty = "Normal", -- an entry of the difficulty table
    difficulties    = { -- Array for sortedness, Keys are text that appears in selector (as well as in scoring!), values are handicap levels
    -- handicap values range [-100 - +100], with 0 being regular resources
        {name = "Beginner", playerhandicap = 50, enemyhandicap=0},
        {name = "Novice"  , playerhandicap = 25, enemyhandicap=0},
        {name = "Normal"  , playerhandicap = 0, enemyhandicap=0},
        {name = "Hard"    , playerhandicap = 0,  enemyhandicap=25},
        {name = "Brutal" , playerhandicap = 0,  enemyhandicap=50},
    },
    allowedsides     = {"Armada","Cortex","Random"}, --these are the permitted factions for this mission
	victorycondition= "Kill all enemy Commanders", -- This is plaintext, but should be reflected in startscript
	losscondition	= "Death of your Commander",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberoftese units, 0 means disable it
        -- dont use the one in startscript, put the disabled stuff here so we can show it in scenario window!
        --armavp = 0,
        --coravp = 0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff",
        scenarioid = "supcrossingvsbarbs001",
		disablefactionpicker = true, -- this is needed to prevent faction picking outside of the allowedsides
    },
    -- https://github.com/spring/spring/blob/105.0/doc/StartScriptFormat.txt

    -- HOW TO MAKE THE START SCRIPT: Use Chobby's single player mode to set up your start script. When you launch a single player game, the start script is dumped into infolog.txt
    -- The following keys MUST be present in startscript below
    --  __SCENARIOOPTIONS__
    -- __PLAYERNAME__
    -- __BARVERSION__
    -- __MAPNAME__

    -- Optional keys:
    -- __ENEMYHANDICAP__
    -- __PLAYERSIDE__
    -- __PLAYERHANDICAP__
    -- __NUMRESTRICTIONS__
    -- __RESTRICTEDUNITS__

	startscript		= [[[Game]
{
    [allyTeam0]
    {
        startrectright = 0.36900368;
        startrectbottom = 0.84132844;
        startrectleft = 0.2509225;
        numallies = 0;
        startrecttop = 0.70479703;
    }

    [ai1]
    {
        Host = 0;
        IsFromDemo = 0;
        Name = BARbarIAnstable(2);
        ShortName = BARb;
        Team = 2;
        Version = stable;
    }

    [team1]
    {
        Handicap = __ENEMYHANDICAP__;
        RgbColor = 0.89999998 0.1 0.28999999;
        AllyTeam = 1;
        TeamLeader = 0;
    }

    [allyTeam1]
    {
        startrectright = 0.99631;
        startrectbottom = 0.34686348;
        startrectleft = 0.62730628;
        numallies = 0;
        startrecttop = 0;
    }

    [team3]
    {
        Handicap = __ENEMYHANDICAP__;
        RgbColor = 0.95999998 0.50999999 0.19;
        AllyTeam = 1;
        TeamLeader = 0;
    }

    [team0]
    {
        Side = __PLAYERSIDE__;
        Handicap = __PLAYERHANDICAP__;
        RgbColor = 0 0.50999999 0.77999997;
        AllyTeam = 0;
        TeamLeader = 0;
    }

    [team2]
    {
        Handicap = __ENEMYHANDICAP__;
        RgbColor = 1 0.88 0.1;
        AllyTeam = 1;
        TeamLeader = 0;
    }

    [modoptions]
    {
        scenariooptions = __SCENARIOOPTIONS__;
    }

    [ai2]
    {
        Host = 0;
        IsFromDemo = 0;
        Name = BARbarIAnstable(3);
        ShortName = BARb;
        Team = 3;
        Version = stable;
    }

    [ai0]
    {
        Host = 0;
        IsFromDemo = 0;
        Name = BARbarIAnstable(1);
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

    hostip = 127.0.0.1;
    hostport = 0;
    numplayers = 1;
    startpostype = 2;
    mapname = __MAPNAME__;
    ishost = 1;
    numusers = 4;
    gametype = __BARVERSION__;
    GameStartDelay = 3;
    myplayername = __PLAYERNAME__;
    nohelperais = 0;


	NumRestrictions=__NUMRESTRICTIONS__;

	[RESTRICT]
	{
        __RESTRICTEDUNITS__
	}
}
	]],

}

return scenariodata
