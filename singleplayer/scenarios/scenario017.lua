local scenariodata = {
	index			= 17, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "archsimkatshelpers017", -- no spaces, lowercase, this will be used to save the score
    version         = "1.0", -- increment this to keep the score when changing a mission
	title			= "A Helping Hand", -- can be anything
	author			= "Beherith", -- your name here
	isnew = true,
	imagepath		= "scenario017.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "Construction units and Nano turrets can assist in building anything.", -- This text will be drawn over image
    summary         = [[You and a team of two other Commanders are tasked with destroying all other Commanders on the enemy team.]],
	briefing 		= [[Three enemy Commanders are also gaining a foothold in this area. The map is made up of three main lanes, you must push through your lane to destroy all of them. Two friendly Commanders have joined in the fight with you, and while they arent the brightest bulbs, they will make holding your portion of the map easier. 
 
Tips:
 - Almost all units can pass the shallow water separating the lanes on the map. 
 - Wind on this map is both tempting and treacherous, as it can attain high velocites, but can also die down at a moments notice. 
 - You can buffer the variable energy production from wind generators with energy storage structures, or augment them with Solar generators. 
 - The enemy may send aircraft against you early on, so make sure to make some light anti-air defense in your base. 
 
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

	mapfilename		= "Archsimkats_Valley_V1", -- the name of the map to be displayed here
	playerstartx	= "10%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "50%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 1500, -- par time in seconds
	parresources	= 50000, -- par resource amount
	difficulty		= 1, -- Percieved difficulty at 'normal' level: integer 1-10
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
	losscondition	= "Loss of all allied Commanders",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberoftese units, 0 is disable it
	-- dont use the one in startscript, put it here!
        --armavp = 0,
        --coravp = 0,
    } ,
    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff",
        scenarioid = "archsimkatshelpers017", --must be present for scores
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
		startrectright = 0.15258856;
		startrectbottom = 1;
		startrectleft = 0;
		numallies = 0;
		startrecttop = 0;
	}

	[ai1]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = SimpleAI(2);
		ShortName = SimpleAI;
		Team = 2;
		Version = <not-versioned>;
	}

	[team5]
	{
		Side = Cortex;
		Handicap = __PLAYERHANDICAP__;
		RgbColor = 0.67000002 1 0.75999999;
		AllyTeam = 0;
		TeamLeader = 0;
	}

	[team1]
	{
		Side = Cortex;
		Handicap = __ENEMYHANDICAP__;
		RgbColor = 1 0.07 0.02;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[allyTeam1]
	{
		startrectright = 0.99455041;
		startrectbottom = 1;
		startrectleft = 0.87738419;
		numallies = 0;
		startrecttop = 0.0027248;
	}

	[team0]
	{
		Side = __PLAYERSIDE__;
		Handicap = __PLAYERHANDICAP__;
		RgbColor = 0 0.31999999 1;
		AllyTeam = 0;
		TeamLeader = 0;
	}

	[team4]
	{
		Side = Armada;
		Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.88884443 0.13659751 0.49673188;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[team2]
	{
		Side = Armada;
		Handicap = __PLAYERHANDICAP__;
		RgbColor = 0.27959639 0.94332623 0.44443226;
		AllyTeam = 0;
		TeamLeader = 0;
	}

	[team3]
	{
		Side = Random;
		Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.52105546 0.41664141 0.00789964;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[ai2]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = SimpleAI(3);
		ShortName = SimpleAI;
		Team = 3;
		Version = <not-versioned>;
	}


	[ai4]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = SimpleAI  (1);
		ShortName = SimpleAI;
		Team = 5;
	}

	[ai3]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = SimpleAI(1);
		ShortName = SimpleAI;
		Team = 4;
		Version = <not-versioned>;
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
	
	[modoptions]
	{
		scenariooptions = __SCENARIOOPTIONS__;
	}
	
	[mapoptions]
	{
		waterlevel=0;
	}
	
	
	NumRestrictions=__NUMRESTRICTIONS__;

	[RESTRICT]
	{
        __RESTRICTEDUNITS__
	}
	
	
	hostip = 127.0.0.1;
	hostport = 0;
	numplayers = 1;
	startpostype = 2;
	mapname = __MAPNAME__;
	ishost = 1;
	numusers = 6;
	gametype = __BARVERSION__;
	nohelperais = 0;
	GameStartDelay = 5;
	myplayername = __PLAYERNAME__;
}


	]],

}

return scenariodata -- scenariodata
