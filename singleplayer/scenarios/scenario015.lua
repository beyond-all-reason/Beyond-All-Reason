local scenariodata = {
	index			= 15, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "thronekoth015", -- no spaces, lowercase, this will be used to save the score
    version         = "1.0", -- increment this to keep the score when changing a mission
	title			= "King of the Hill", -- can be anything
	author			= "Beherith", -- your name here
	isnew = true,
	imagepath		= "scenario015.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "Its cold and lonely up here", -- This text will be drawn over image
    summary         = [[7 enemy Commanders are allied against you, at the top of Throne. Destroy all of them to keep your crown.]],
	briefing 		= [[The seven outcroppings on the edge of Throne all occupied by enemy Commanders. They will send early scouting forces, and if left to expand too much, will advance in technology rapidly. The third level is secured for you with the most basic defences, and some light anti-air.
 
 
Tips:
 
 ‣  Secure at least the third level as soon as possible, and expand very quickly to claim all the metal on it. 
 
 ‣  Wind is an excellent source of energy on this map.
 
 ‣  The enemies arent the sharpest knife in the drawer, but will pose a threat if left to expand to the second level. 
 
 ‣  Reduce the difficulty of the scenario if you find it too hard. 
 
 
Scoring:
 
 ‣  Time taken to complete the scenario
 ‣  Resources spent to destroy all enemy units.
  
 
The difficulty modifier will change the amount of resources you and the enemy can use:
 
 ‣  Beginner: You +50%, enemy -50%
 ‣  Novice: You +25%, enemy -25%
 ‣  Normal: Regular resources for both sides
 ‣  Hard: Regular resources for you, +50% for the enemy
 ‣  Brutal: Regular resources for you, +100% for the enemy

    ]],

	mapfilename		= "Throne_V8", -- the name of the map to be displayed here
	playerstartx	= "50%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "50%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 1800, -- par time in seconds
	parresources	= 1000000, -- par resource amount
	difficulty		= 3, -- Percieved difficulty at 'normal' level: integer 1-10
    defaultdifficulty = "Normal", -- an entry of the difficulty table
    difficulties    = { -- Array for sortedness, Keys are text that appears in selector (as well as in scoring!), values are handicap levels
        {name = "Beginner", playerhandicap = 50 , enemyhandicap = -50},
        {name = "Novice"  , playerhandicap = 25 , enemyhandicap = -25},
        {name = "Normal"  , playerhandicap = 0  , enemyhandicap = 0  },
        {name = "Hard"    , playerhandicap = 0, enemyhandicap = 50 },
        {name = "Brutal"  , playerhandicap = 0, enemyhandicap = 100 },
    },
    allowedsides     = {"Cortex"}, --these are the permitted factions for this mission
	victorycondition= "Kill all enemy Commanders", -- This is plaintext, but should be reflected in startscript
	losscondition	= "Loss of your Commander",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberoftese units, 0 is disable it
	-- dont use the one in startscript, put it here!
        --armavp = 0,
        --coravp = 0,
    } ,
	

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff",
        scenarioid = "thronekoth015", --must be present for scores
		disablefactionpicker = true, -- this is needed to prevent faction picking outside of the allowedsides
		unitloadout = {
			{name = 'corrad', x = 5760, y = 751, z = 5616, rot = 0 , team = 7},
			{name = 'coradvsol', x = 5760, y = 753, z = 5664, rot = 0 , team = 7},
			{name = 'cormaw', x = 5264, y = 531, z = 4928, rot = 0 , team = 7},
			{name = 'cormadsam', x = 5640, y = 578, z = 6472, rot = 0 , team = 7},
			{name = 'cormaw', x = 5520, y = 535, z = 4736, rot = 0 , team = 7},
			{name = 'cormadsam', x = 7064, y = 565, z = 5576, rot = 0 , team = 7},
			{name = 'cormaw', x = 7344, y = 552, z = 5408, rot = 0 , team = 7},
			{name = 'cormaw', x = 7360, y = 554, z = 5696, rot = 0 , team = 7},
			{name = 'cormadsam', x = 5512, y = 556, z = 4952, rot = 0 , team = 7},
			{name = 'cormaw', x = 5712, y = 565, z = 6784, rot = 0 , team = 7},
			{name = 'cormaw', x = 5408, y = 561, z = 6656, rot = 0 , team = 7},
			{name = 'corcom', x = 6068, y = 755, z = 5565, rot = -688 , team = 7},
			{name = 'armcom', x = 1405, y = 85, z = 2774, rot = 0 , team = 0},
			{name = 'corcom', x = 5334, y = 88, z = 844, rot = 0 , team = 1},
			{name = 'armcom', x = 10114, y = 86, z = 2076, rot = 0 , team = 2},
			{name = 'corcom', x = 11342, y = 89, z = 6616, rot = 0 , team = 3},
			{name = 'armcom', x = 8995, y = 87, z = 10831, rot = 0 , team = 4},
			{name = 'armcom', x = 4417, y = 88, z = 11187, rot = -11476 , team = 5},
			{name = 'corcom', x = 903, y = 87, z = 7821, rot = 0 , team = 6},
		}
    },
    -- https://github.com/spring/spring/blob/105.0/doc/StartScriptFormat.txt
	startscript		= [[

[game]
{
	[allyteam1]
	{
		numallies=0;
	}
	[ai2]
	{
		[options]
		{
		}
		host=7;
		name=Bot4;
		version=<not-versioned>;
		isfromdemo=0;
		team=2;
		shortname=SimpleAI;
	}
	[ai4]
	{
		[options]
		{
		}
		host=7;
		name=Bot6;
		version=<not-versioned>;
		isfromdemo=0;
		team=4;
		shortname=SimpleAI;
	}

	[team1]
	{
		rgbcolor=1 0 0.478431;
		allyteam=0;
		startposx=4473;
		side=Random;
		startposz=11133;
		teamleader=7;
		handicap=__ENEMYHANDICAP__;
	}
	[team4]
	{
		rgbcolor=0.384314 0 0.498039;
		allyteam=0;
		startposx=836;
		side=Random;
		startposz=7791;
		teamleader=7;
		handicap=__ENEMYHANDICAP__;
	}
	[team7]
	{
		rgbcolor=0.690196 0.207843 0.792157;
		allyteam=1;
		startposx=6095;
		side=__PLAYERSIDE__;
		startposz=5579;
		teamleader=7;
		handicap=__PLAYERHANDICAP__;
	}
	[ai0]
	{
		[options]
		{
		}
		host=7;
		name=Bot2;
		version=<not-versioned>;
		isfromdemo=0;
		team=0;
		shortname=SimpleAI;
	}
	[team3]
	{
		rgbcolor=0.611765 1 0.498039;
		allyteam=0;
		startposx=8995;
		side=Random;
		startposz=10887;
		teamleader=7;
		handicap=__ENEMYHANDICAP__;
	}
	[allyteam0]
	{
		numallies=0;
	}
	[ai3]
	{
		[options]
		{
		}
		host=7;
		name=Bot5;
		version=<not-versioned>;
		isfromdemo=0;
		team=3;
		shortname=SimpleAI;
	}
	[ai6]
		{
		[options]
		{
		}
		host=7;
		name=Bot8;
		version=<not-versioned>;
		isfromdemo=0;
		team=6;
		shortname=SimpleAI;
	}
	[player7]
	{
		spectator=0;
		name=__PLAYERNAME__;
		countrycode=;
		isfromdemo=0;
		team=7;
		rank=0;
	}
	[ai5]
	{
		[options]
		{
		}
		host=7;
		name=Bot7;
		version=<not-versioned>;
		isfromdemo=0;
		team=5;
		shortname=SimpleAI;
	}
	[team6]
	{
		rgbcolor=0.301961 0.498039 0;
		allyteam=0;
		startposx=1524;
		side=Random;
		startposz=2777;
		teamleader=7;
		handicap=__ENEMYHANDICAP__;
	}
	[team2]
	{
		rgbcolor=0 0.729412 1;
		allyteam=0;
		startposx=5210;
		side=Random;
		startposz=909;
		teamleader=7;
		handicap=__ENEMYHANDICAP__;
	}
	[team0]
	{
		rgbcolor=0.509804 0.498039 1;
		allyteam=0;
		startposx=11354;
		side=Random;
		startposz=6660;
		teamleader=7;
		handicap=__ENEMYHANDICAP__;
	}
	[ai1]
	{
		[options]
		{
		}
		host=7;
		name=Bot3;
		version=<not-versioned>;
		isfromdemo=0;
		team=1;
		shortname=SimpleAI;
	}
	[team5]
	{
		rgbcolor=1 0.631373 0.498039;
		allyteam=0;
		startposx=10076;
		side=Random;
		startposz=2089;
		teamleader=7;
		handicap=__ENEMYHANDICAP__;
	}
	
	[modoptions]
	{
		scenariooptions = __SCENARIOOPTIONS__;
	}
	
	[mapoptions]
	{
		roads=1;
		waterlevel=0;
		waterdamage=0;
	}
	
	
	NumRestrictions=__NUMRESTRICTIONS__;

	[RESTRICT]
	{
        __RESTRICTEDUNITS__
	}
	
	numplayers=1;
	myplayername=__PLAYERNAME__;
	gametype=__BARVERSION__;
	ishost=1;
	hostip=;
	mapname=__MAPNAME__;
	startpostype=3;
	GameStartDelay = 5;
	hostport=0;
	numusers=8;
}

	]],

}

return scenariodata -- scenariodata
