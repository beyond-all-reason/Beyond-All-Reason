local scenariodata = {
	index			= 7, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "acidicquarrybarbs", -- no spaces, lowercase, this will be used to save the score
    version         = "1", -- increment this to keep the score when changing a mission
	title			= "The Sky is the Limit", -- can be anything
	author			= "BasiC",
	imagepath		= "scenario007.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "Acidic water damages any unit coming into contact with it", -- This text will be drawn over image
    summary         = [[Acidic rains prevent any land or sea units, so you must take to the skies to defeat two enemy Commanders. The acidic environment also prevent use of the usual anti-air defensive turrets. Bomb your way to victory.]],
	briefing 		= [[
The environmental conditions prevent the use of your mainstay army options, so plan your aircraft raids on the enemy platforms wisely.


Tips:
 - Fighters are your only defense against enemy aircraft, and you will need them quickly.
 - Wind Generators are more vulnerable when built close together, as they damage adjacent units and structures when destroyed. Space them well [Hotkeys Z and X while building a grid of them]
 - Aircraft in general cost a lot of energy to build
 - The energy output of wind generators fluctuate, so it is recommended to build at least one Energy Storage building to smooth out the intermittent supply.
 - You can build Air Transports to ferry your Commander between the rocky pillars, but do so only when safe, as enemy fighters can easily shoot down a vulnerable Air Transport, instantly killing any transported unit
 - You can also transport Nano Turrets in Air Transports
 - Armada has access to Banshees, which are excellent early gunship aircraft
 - Armada can build Twilights, which are cloakable and stealthy metal extractors. These will be much more difficult to raid for the enemy, but when you run out of energy, their cloaking fields may fail until you restore your energy supplies


Scoring:
	1. Speed: destroy the enemy Commanders as fast as possible.
	2. Efficiency: minimize the amount of metal and energy used.
]],
	mapfilename		= "AcidicQuarry 5.16", -- the name of the map to be displayed here, and which to play on, no .smf ending needed
	playerstartx	= "15%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "75%", -- Y position of where player comm icon should be drawn, from top left of the map
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
		armcir = 0,
        armferret = 0,
        armflak = 0,
        armmercury = 0,
        armrl = 0,
        armalab = 0,
		armavp = 0,
		armhp = 0,
		armlab = 0,
		armshltx = 0,
		armvp = 0,
		corerad = 0,
		corflak = 0,
		cormadsam = 0,
		corrl = 0,
		corscreamer = 0,
		coralab = 0,
		coravp = 0,
		corgant = 0,
		corhp = 0,
		corlab = 0,
		corvp = 0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff",
        scenarioid = "acidicquarrybarbs",
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
	[allyTeam0]
	{
		startrectright = 1;
		startrectbottom = 0.2;
		startrectleft = 0;
		numallies = 0;
		startrecttop = 0;
	}
	[ai1]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbstable(2);
		ShortName = BARb;
		Team = 2;
		Version = stable;
	}
	[team1]
	{
	    Side = Random;
        Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.99706084 0.21503568 0.44135636;
		AllyTeam = 0;
		TeamLeader = 0;
	}
	[team0]
	{
        Side = __PLAYERSIDE__;
        Handicap = __PLAYERHANDICAP__;
		RgbColor = 0.90586215 0.60122037 0.24591541;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[allyTeam1]
	{
		startrectright = 1;
		startrectbottom = 1;
		startrectleft = 0;
		numallies = 0;
		startrecttop = 0.80000001;
	}

	[modoptions]
	{
		scenariooptions = __SCENARIOOPTIONS__;
	}

	[team2]
	{
	    Side = Random;
        Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.23227084 0.54822761 0.46437711;
		AllyTeam = 0;
		TeamLeader = 0;
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
	numusers = 3;
    gametype = __BARVERSION__;
	GameStartDelay = 5;
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
