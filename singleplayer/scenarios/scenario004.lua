local scenariodata = {
	index			= 3, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "tma20ffabarbs", -- no spaces, lowercase, this will be used to save the score
    version         = "1", -- increment this to keep the score when changing a mission
	title			= "One by One", -- can be anything
	author			= "Beherith", -- your name here
	imagepath		= "scenario004.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "You can hide behind radar jammers.", -- This text will be drawn over image
    summary         = [[Competition for resources has never been this intense. Eliminate all 7 of your enemies in a free-for-all battle.]],
	briefing 		= [[The Tycho Magnetic Anomaly 20 asteroid is very rich in resources, and has attracted the attention of your competition. There are a total of 7 enemy commanders on this map, all hell bent on destroying any opposition. Even cloaked Commanders emit a radar signature, but radar jammers can hide that as well. Armada's Sneaky Pete (Cloakable Radar Jammer Tower) can ensure that you dont fall victim to any surprise attacks.

Score:
    1. Speed: destroy all enemy Commanders as fast as possible.
    2. Efficiency: minimize the amount of metal and energy used.

Tips:
    1. Your enemies will also fight each other, goad them into doing your dirty work
    2. There are a large amount of resources in the center, but being too greedy might attract unwanted attention.
    3. Use radar jammers to cover your tracks and hide secretive mining outposts.
    4. Whenever an enemy gets eliminated, swoop in quickly to secure the spoils.
    5. Protect your commander at all costs, and keep an eye on which of your opponents seem the strongest
    6. Sieze any opportunity to score a kill on an enemy Commander, and try to kill at least one Commander before advancing your tech tree. Use the metal from the spoils to quickly tech up.
    ]],

	mapfilename		= "TMA20X 1.8", -- the name of the map to be displayed here, and which to play on, no .smf ending needed
	playerstartx	= "75%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "30%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 1800, -- par time in seconds
	parresources	= 1000000, -- par resource amount
	difficulty		= 6, -- Percieved difficulty at 'normal' level: integer 1-10
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
    unitlimits   = { -- table of unitdefname : maxnumberoftese units, 0 means disable it        -- dont use the one in startscript, put the disabled stuff here so we can show it in scenario window!
        --armavp = 0,
        --coravp = 0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff",
        scenarioid = "tma20ffabarbs",
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

	startscript		= [[
    [Game]
{
	[allyTeam4]
	{
		startrectright = 0.5202952;
		startrectbottom = 0.84501845;
		startrectleft = 0.44649449;
		numallies = 0;
		startrecttop = 0.75276756;
	}

	[allyTeam0]
	{
		startrectright = 0.83763838;
		startrectbottom = 0.41697419;
		startrectleft = 0.76383764;
		numallies = 0;
		startrecttop = 0.32472324;
	}

	[ai4]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbarIAnstable(2);
		ShortName = BARb;
		Team = 5;
		Version = stable;
	}

	[ai1]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbarIAnstable(7);
		ShortName = BARb;
		Team = 2;
		Version = stable;
	}

	[team1]
	{
		Side = Random;
        Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.09245676 0.67018342 0.32102555;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[ai2]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbarIAnstable(6);
		ShortName = BARb;
		Team = 3;
		Version = stable;
	}

	[ai5]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbarIAnstable(3);
		ShortName = BARb;
		Team = 6;
		Version = stable;
	}

	[allyTeam7]
	{
		startrectright = 0.27675277;
		startrectbottom = 0.59040588;
		startrectleft = 0.19188192;
		numallies = 0;
		startrecttop = 0.51291513;
	}

	[ai6]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbarIAnstable(4);
		ShortName = BARb;
		Team = 7;
		Version = stable;
	}

	[ai3]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbarIAnstable(5);
		ShortName = BARb;
		Team = 4;
		Version = stable;
	}

	[team3]
	{
		Side = Random;
        Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.42248935 0.36655921 0.43719065;
		AllyTeam = 6;
		TeamLeader = 0;
	}

	[allyTeam3]
	{
		Side = Random;
		startrectright = 0.29889297;
		startrectbottom = 0.79335791;
		startrectleft = 0.21771218;
		numallies = 0;
		startrecttop = 0.71955717;
	}

	[team2]
	{
		Side = Random;
        Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.68172985 0.2774331 0.7800824;
		AllyTeam = 7;
		TeamLeader = 0;
	}

	[team7]
	{
		Side = Random;
        Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.00364125 0.1067903 0.25523329;
		AllyTeam = 4;
		TeamLeader = 0;
	}

	[team6]
	{
		Side = Random;
        Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.90220386 0.76105046 0.12702972;
		AllyTeam = 3;
		TeamLeader = 0;
	}

	[team5]
	{
		Side = Random;
        Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.9550398 0.15294886 0.80874956;
		AllyTeam = 2;
		TeamLeader = 0;
	}

	[allyTeam6]
	{
		startrectright = 0.82656825;
		startrectbottom = 0.76014757;
		startrectleft = 0.74169737;
		numallies = 0;
		startrecttop = 0.66789663;
	}

	[team4]
	{
		Side = Random;
        Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.65895206 0.09406483 0.50522637;
		AllyTeam = 5;
		TeamLeader = 0;
	}

	[allyTeam5]
	{
		startrectright = 0.19557196;
		startrectbottom = 0.44649449;
		startrectleft = 0.12177122;
		numallies = 0;
		startrecttop = 0.34317344;
	}

	[allyTeam2]
	{
		startrectright = 0.40590408;
		startrectbottom = 0.24723248;
		startrectleft = 0.32103321;
		numallies = 0;
		startrecttop = 0.16236162;
	}

	[allyTeam1]
	{
		startrectright = 0.64944649;
		startrectbottom = 0.23985241;
		startrectleft = 0.57933581;
		numallies = 0;
		startrecttop = 0.16974171;
	}

	[team0]
	{
		Side = __PLAYERSIDE__;
		Handicap = __PLAYERHANDICAP__;
		RgbColor = 0.40148652 0.15398049 0.92516315;
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
	ishost = 1;
	numplayers = 1;
	numusers = 8;
	startpostype = 2;
	mapname =__MAPNAME__;
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
