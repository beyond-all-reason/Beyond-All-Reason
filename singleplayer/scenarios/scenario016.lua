local scenariodata = {
	index			= 16, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "neuropeww225", -- no spaces, lowercase, this will be used to save the score
    version         = "1.0", -- increment this to keep the score when changing a mission
	title			= "World War XXV", -- can be anything
	author			= "Beherith", -- your name here
	isnew = true,
	imagepath		= "scenario016.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "Neurope has experienced quite the geological shift", -- This text will be drawn over image
    summary         = [[Multiple allegiances have formed around continental Neurope, and you must retake the entire continental area from the northwest island]],
	briefing 		= [[One large alliance of three commanders controls the center of the continent, the other is formed between the east, southeast and southwest. The northern and central territories have attempted to remain neutral, but are gearing up for battle. 
 
You will start on the northwestern large island, and the northern resource rich island is still unclaimed according to our scouting reports. 
 
Tips:
 - The northwest sea contains abundant metal, and tidal forces are strong for generating energy.
 - The northern island should be occupied as soon as possible, start off with a Vehicle or Bot factory to secure your starting island, then make and Aircraft plant and use transports to ferry constructors to the island. 
 - Initially, the warring factions will be occupied with each other, but may send early aircraft and hovercraft scouts to your location. 
 - Aircraft carriers offer protection from nuclear warheads.
 
 
Scoring:
 - Time taken to complete the scenario
 - Resources spent to destroy all enemy units.
 
The difficulty modifier will change the amount of resources you and the enemy receive from metal and energy structures:
 - Beginner: You +50%, enemy -50%
 - Novice: You +25%, enemy -25%
 - Normal: Regular resources for both sides
 - Hard: Regular resources for you, +50% for the enemy
 - Brutal: Regular resources for you, +100% for the enemy
    ]],

	mapfilename		= "Neurope_Remake 4.2", -- the name of the map to be displayed here
	playerstartx	= "5%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "10%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 3000, -- par time in seconds
	parresources	= 10000000, -- par resource amount
	difficulty		= 5, -- Percieved difficulty at 'normal' level: integer 1-10
    defaultdifficulty = "Normal", -- an entry of the difficulty table
    difficulties    = { -- Array for sortedness, Keys are text that appears in selector (as well as in scoring!), values are handicap levels
        {name = "Beginner", playerhandicap = 50 , enemyhandicap = -50},
        {name = "Novice"  , playerhandicap = 25 , enemyhandicap = -25},
        {name = "Normal"  , playerhandicap = 0  , enemyhandicap = 0  },
        {name = "Hard"    , playerhandicap = 0, enemyhandicap = 50 },
        {name = "Brutal"  , playerhandicap = 0, enemyhandicap = 100 },
    },
    allowedsides     = {"Armada","Cortex","Random"}, --these are the permitted factions for this mission
	victorycondition= "Kill all enemy Commanders", -- This is plaintext, but should be reflected in startscript
	losscondition	= "Loss of your Commander",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberoftese units, 0 is disable it
	-- dont use the one in startscript, put it here!
        --armavp = 0,
        --coravp = 0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff",
        scenarioid = "neuropeww225", --must be present for scores
		disablefactionpicker = true, -- this is needed to prevent faction picking outside of the allowedsides
		--unitloadout = {
		--	{name = 'corrad', x = 5760, y = 751, z = 5616, rot = 0 , team = 7},
		--}
    },
    -- https://github.com/spring/spring/blob/105.0/doc/StartScriptFormat.txt
	startscript		= [[

 [Game]
{
	[allyTeam0]
	{
		numallies = 0;
	}

	[ai4]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbstable(1);
		ShortName = BARb;
		Team = 5;
		Version = stable;
	}

	[ai1]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbstable(4);
		ShortName = BARb;
		Team = 2;
		Version = stable;
	}

	[team1] // Finland
	{
		Side = Random;
		Handicap = __ENEMYHANDICAP__;
		StartPosX = 10300;
		StartPosZ = 3000;
		RgbColor = 1 0 1;
		AllyTeam = 3;
		TeamLeader = 0;
	}

	[ai2]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbstable(3);
		ShortName = BARb;
		Team = 3;
		Version = stable;
	}

	[ai5]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbstable(5);
		ShortName = BARb;
		Team = 6;
		Version = stable;
	}

	[ai6]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbstable(8);
		ShortName = BARb;
		Team = 7;
		Version = stable;
	}

	[ai3]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbstable(6);
		ShortName = BARb;
		Team = 4;
		Version = stable;
	}

	[team3] // france
	{
		Side = Cortex;
		Handicap = __ENEMYHANDICAP__;
		StartPosX = 2000;
		StartPosZ = 6200;
		RgbColor = 0.7764706 0.34117648 0.21176471;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[allyTeam3]
	{
		numallies = 0;
	}

	[team2] // Germany
	{
		Side = Armada;
		Handicap = __ENEMYHANDICAP__;
		StartPosX = 5000;
		StartPosZ = 4100;
		RgbColor = 0 0 1;
		AllyTeam = 2;
		TeamLeader = 0;
	}

	[team7] //romania
	{
		Side = Random;
		Handicap = __ENEMYHANDICAP__;
		StartPosX = 10200;
		StartPosZ = 5100;
		RgbColor = 0.61960787 0 0.70980394;
		AllyTeam = 3;
		TeamLeader = 0;
	}

	[ai7]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbstable(2);
		ShortName = BARb;
		Team = 8;
		Version = stable;
	}

	[team6] // polad
	{
		Side = Armada;
		Handicap = __ENEMYHANDICAP__;
		StartPosX = 7500;
		StartPosZ = 4400;
		RgbColor = 0.24313726 0.61960787 1;
		AllyTeam = 2;
		TeamLeader = 0;
	}

	[team5] //russia
	{
		Side = Cortex;
		Handicap = __ENEMYHANDICAP__;
		StartPosX = 13200;
		StartPosZ = 4400;
		RgbColor = 0.52549022 0.09803922 0.06666667;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[team4] //italy
	{
		Side = Armada;
		Handicap = __ENEMYHANDICAP__;
		StartPosX = 5800;
		StartPosZ = 7600;
		RgbColor = 0.09019608 0.15686275 0.50196081;
		AllyTeam = 2;
		TeamLeader = 0;
	}

	[allyTeam2]
	{
		numallies = 0;
	}

	[allyTeam1]
	{
		numallies = 0;
	}

	[team0]
	{
		Side = __PLAYERSIDE__;
		Handicap = __PLAYERHANDICAP__;
		RgbColor = 0.07450981 0.96470588 0.07450981;
		AllyTeam = 0;
		TeamLeader = 0;
		StartPosX = 1300;
		StartPosZ = 2900;
	}

	[team8] //bulgaria
	{
		Side = Cortex;
		Handicap = __ENEMYHANDICAP__;
		StartPosX = 8600;
		StartPosZ = 7500;
		RgbColor = 0.85490197 0.05490196 0.01960784;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[ai0]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbstable(7);
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
	
	[modoptions]
	{
        scenariooptions = __SCENARIOOPTIONS__;
	}
	NumRestrictions=__NUMRESTRICTIONS__;
	[RESTRICT]
	{
        __RESTRICTEDUNITS__
	}
	hostip = 127.0.0.1;
	hostport = 0;
	ishost = 1;
	GameStartDelay = 5;
	numplayers = 1;
	numusers = 9;
	startpostype = 3; // 0 fixed, 1 random, 2 choose in game, 3 choose before game (see StartPosX)
	mapname = __MAPNAME__;
	myplayername = __PLAYERNAME__;
	nohelperais = 0;
	gametype = __BARVERSION__;
}

	]],

}

return scenariodata -- scenariodata
