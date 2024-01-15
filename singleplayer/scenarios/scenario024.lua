local scenariodata = {
	index			= 24, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "benchmark_pathfinding", -- no spaces, lowercase, this will be used to save the score
    version         = "1.0", -- increment this to keep the score when changing a mission
	title			= "Benchmark pathfinding", -- can be anything
	author			= "Beherith, AKU", -- your name here
	isnew 			= true,
	imagepath		= "scenario023.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "Units will act automatically during the benchmark", -- This text will be drawn over image
    summary         = [[Pathfinding benchmark.]],
	briefing 		= [[Pathfinding benchmark. The average Sim, Draw and Update times are shown on screen. The game will automatically center the camera over the units, do not move the camera while the benchmark is running, and do not interact with the units. The game will return after printing the results to screen and infolog, and submitting them to the server. Amount of units at the end of testing depends of setting: 
	1 unit spawn rate ~700 units; 
	3 unit spawn rate ~2000 units; 
	10 unit spawn rate ~7000 units; 
	15 unit spawn rate ~10000 units
		
	A total of 2000 simulation frames are tested. 
	
	The internal command to run a benchmark of various units against each other needs cheating enabled, and is the following:

	/luarules fightertest [unitname1] [unitname2] [maxunits] [spawnstep] [spawnradius] 
	For this benchmark, it is

	/luarules armcv armck 11000 1 12000

	]],

	mapfilename		= "Jade Empress 1.3", -- the name of the map to be displayed here
	playerstartx	= "10%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "10%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 180, -- par time in seconds
	parresources	= 1, -- par resource amount
	difficulty		= 15, -- Percieved difficulty at 'normal' level: integer 1-10
    defaultdifficulty = "3 unit spawn rate", -- an entry of the difficulty table
    difficulties    = { -- Array for sortedness, Keys are text that appears in selector (as well as in scoring!), values are handicap levels
		{name = "1 unit spawn rate", playerhandicap = "armcv armck 11000 1 12000" , enemyhandicap = 0},
		{name = "3 unit spawn rate", playerhandicap = "armcv armck 11000 3 12000" , enemyhandicap = 0},
		{name = "10 unit spawn rate", playerhandicap = "armcv armck 11000 10 12000" , enemyhandicap = 0},
		{name = "15 unit spawn rate", playerhandicap = "armcv armck 11000 15 12000" , enemyhandicap = 0},
    },
    allowedsides     = {""}, --these are the permitted factions for this mission
	victorycondition= "None", -- This is plaintext, but should be reflected in startscript
	losscondition	= "None",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = {},
    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        --myoption = "dostuff",
        scenarioid = "benchmark_pathfinding", --must be present for scores
		disablefactionpicker = true, -- this is needed to prevent faction picking outside of the allowedsides
		benchmarkcommand = "luarules fightertest armcv armck 11000 1 12000", -- make sure the matches the debugcommands identically named modoption's info
		benchmarkframes = 2000,
		-- quiteforce sucks, does not end the game. 
		--unitloadout = {},	
		--featureloadout = {},
    },
    -- https://github.com/spring/spring/blob/105.0/doc/StartScriptFormat.txt
	startscript		= [[

	[Game]
{
	[allyTeam0]
	{
		startrectright = 0.17;
		startrectbottom = 1;
		startrectleft = 0;
		numallies = 0;
		startrecttop = 0;
	}

	[team1]
	{
		Side = Cortex;
		Handicap = 0;
		RgbColor = 0.99609375 0.546875 0;
		AllyTeam = 1;
		TeamLeader = 0;
        StartPosX = 100;
        StartPosZ = 800;
	}

	[team0]
	{
		Side = Armada;
		Handicap = 0;
		RgbColor = 0.99609375 0.546875 0;
		AllyTeam = 0;
		TeamLeader = 0;
        StartPosX = 800;
        StartPosZ = 100;
	}

	[modoptions]
	{
        scenariooptions = __SCENARIOOPTIONS__;
		maxunits = 11000;
		debugcommands = 1:cheat|15:luarules fightertest __PLAYERHANDICAP__|25:deselect|2015:screenshot|2016:luarules fightertest;
	}
	
	[allyTeam1]
	{
		startrectright = 1;
		startrectbottom = 1;
		startrectleft = 0.82999998;
		numallies = 0;
		startrecttop = 0;
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
	
	NumRestrictions=__NUMRESTRICTIONS__;

	[RESTRICT]
	{
        __RESTRICTEDUNITS__
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
	FixedRNGSeed = 123123;
}
	]],
}

return scenariodata -- scenariodata
