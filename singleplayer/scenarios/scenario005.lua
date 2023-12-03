-- Steal Cortex's Tech! singleplayer challenge
-- Author: Zow

local scenariodata = {
	index			= 5, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "stealtech005", -- no spaces, lowercase, this will be used to save the score
    version         = "1", -- increment this to keep the score when changing a mission
	title			= "Steal Cortex's Tech!", -- can be anything
	author			= "Zow", -- your name here
	imagepath		= "scenario005.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "", -- This text will be drawn over image
    summary         = [[Your Armada commander lost the blueprints to most factories and units. Oops! But perhaps your Cortex enemy has a solution for you...]],
	briefing 		= [[In this challenge, most Armada combat units and factories are disabled. Use your Commander and static defenses to hold your frontline and your expansions. Find and resurrect an enemy constructor to build combat units. Resurrection Bots (Cortex Graverobber and Armada Lazarus) can resurrect and repair units, but cannot build structures. They are also stealthy, so they dont show up on the enemy's radar. Use your commander's d-gun wisely, as it completely destroys units, including their wrecks. Use terrain to your advantage when playing defensively.

Score:
	1. Speed: destroy the enemy Commander as fast as possible.
	2. Efficiency: minimize the amount of metal and energy used.

Tips:
	1. Light laser towers can be effective as a low cost option to hold a front line and expansions before you steal enemy tech.
	2. Send constructors to the front line to build turrets and other defensive structures!
	3. Nano towers can be a very effective source of repair in a large radius.
	4. You will be forced onto the Armada side. Try to get your hands on Cortex technology if possible!
    ]],

	mapfilename		= "BarR 1.1", -- the name of the map to be displayed here, and which to play on, no .smf ending needed
	playerstartx	= "85%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "85%", -- Y position of where player comm icon should be drawn, from top left of the map
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
    allowedsides     = {"Armada"}, --these are the permitted factions for this mission
	victorycondition= "Kill all enemy Commanders", -- This is plaintext, but should be reflected in startscript
	losscondition	= "Death of your Commander",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberoftese units, 0 means disable it
        --armavp = 0,
        --coravp = 0,
        armaap=0,
        armalab=0,
        armap=0,
        armavp=0,
        armhp=0,
        armshltx=0,
        armvp=0,
        armflea=0,
        armham=0,
        armjeth=0,
        armpw=0,
        armrock=0,
        armwar=0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff",
        scenarioid = "stealtech005",
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
        startrectright = 1;
        startrectbottom = 1;
        startrectleft = 0.75;
        numallies = 0;
        startrecttop = 0.75;
    }
    [team1]
    {
        Side = Cortex;
        Handicap = __ENEMYHANDICAP__;
        RgbColor = 0.89999998 0.1 0.28999999;
        AllyTeam = 1;
        TeamLeader = 0;
    }
    [allyTeam1]
    {
        startrectright = 0.25;
        startrectbottom = 0.25;
        startrectleft = 0;
        numallies = 0;
        startrecttop = 0;
    }
    [team0]
    {
        Side = __PLAYERSIDE__;
        Handicap = __PLAYERHANDICAP__;
        RgbColor = 0 0.50999999 0.77999997;
        AllyTeam = 0;
        TeamLeader = 0;
    }
    [modoptions]
    {
        scenariooptions = __SCENARIOOPTIONS__;
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

    // do not touch these, chobby will generate these from the unitlimits table
	NumRestrictions=__NUMRESTRICTIONS__;
	[RESTRICT]
	{
        __RESTRICTEDUNITS__
	}
}
	]],

}

return scenariodata
