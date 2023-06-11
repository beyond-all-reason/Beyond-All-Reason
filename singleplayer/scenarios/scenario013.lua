local scenariodata = {
	index			= 13, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "shoretoshorevsbarb013", -- no spaces, lowercase, this will be used to save the score
    version         = "1.0", -- increment this to keep the score when changing a mission
	title			= "Testing the Waters", -- can be anything
	author			= "Beherith", -- your name here
	imagepath		= "scenario013.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "Shipyards can be assisted by all constructors", -- This text will be drawn over image
    summary         = [[Test your skill in naval and aircraft warfare on one of the widest maps. You must defeat a single enemy, who like you, is still quite new to naval combat..]],
	briefing 		= [[Naval battles in BAR are focused on the interaction between ships, submarines, hovercraft, aircraft and occasionally, amphibious units.
 
 
Tips:
 
 ‣  The Cortex Duck (Tier 2 Bot) amphibous bot armed with a short-range laser, and a torpedo launcher. It is the only amphibous unit capable of firing while underwater.
 
 ‣  The Armada Platypus (Tier 2 Bot) has a short range laser, and an Anti-Aircraft missile, and can provide excellent raiding and support while swimming above the water.
 
 ‣  Some Experimental Gantry (Tier 3) units are amphibious, and some stand tall enough to fire their weapons at surface targets while in water.
 
 ‣  Large maps provide great incentives to use Nuclear Missiles, so take care to defend yourself with either: Land nuclear missile defence or a mobile form of it.
 
 ‣  Aircraft carriers can repair aircraft while at sea, and even have an anti-nuclear missile.
 
 ‣  Flagships offer the highest concentration of ranged firepower possible.
 
 ‣  Torpedo bombers can quickly dispose of any fleet without sufficient anti-air cover.
 
 
Scoring:

 ‣  Time taken to destroy all enemy units
 ‣  Resources spent to kill the enemy commander

    ]],

	mapfilename		= "Shore_to_Shore_V3", -- the name of the map to be displayed here
	playerstartx	= "5%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "50%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 1800, -- par time in seconds
	parresources	= 1000000, -- par resource amount
	difficulty		= 1, -- Percieved difficulty at 'normal' level: integer 1-10
    defaultdifficulty = "Normal", -- an entry of the difficulty table
    difficulties    = { -- Array for sortedness, Keys are text that appears in selector (as well as in scoring!), values are handicap levels
        {name = "Beginner", playerhandicap = 50 , enemyhandicap = 0},
        {name = "Novice"  , playerhandicap = 25 , enemyhandicap = 0},
        {name = "Normal"  , playerhandicap = 0  , enemyhandicap = 0},
        {name = "Hard"    , playerhandicap = 0, enemyhandicap = 50},
        {name = "Brutal"  , playerhandicap = 0, enemyhandicap = 100},
    },
    allowedsides     = {"Armada","Cortex","Random"}, --these are the permitted factions for this mission
	victorycondition= "Kill all construction units", -- This is plaintext, but should be reflected in startscript
	losscondition	= "Lose all of your construction units",  -- This is plaintext, but should be reflected in startscript
     unitlimits   = { -- table of unitdefname : maxnumberoftese units, 0 is disable it
	-- dont use the one in startscript, put it here!
        --armavp = 0,
        --coravp = 0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff",
        scenarioid = "shoretoshorevsbarb013", --must be present for scores
		disablefactionpicker = true, -- this is needed to prevent faction picking outside of the allowedsides
    },
    -- https://github.com/spring/spring/blob/105.0/doc/StartScriptFormat.txt
	startscript		= [[

[Game]
{
	[allyTeam0]
	{
		startrectright = 0.12;
		startrectbottom = 1;
		startrectleft = 0;
		numallies = 0;
		startrecttop = 0;
	}

	[team1]
	{
		Side = Random;
        Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.89999998 0.2 0.08999999;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[team0]
	{
        Side = __PLAYERSIDE__;
		Handicap = __PLAYERHANDICAP__;
		Handicap = 0;
		RgbColor = 0 0.20999999 0.97999997;
		AllyTeam = 0;
		TeamLeader = 0;
	}

	[modoptions]
	{
		deathmode = builders;
        scenariooptions = __SCENARIOOPTIONS__;
	}

	[allyTeam1]
	{
		startrectright = 1;
		startrectbottom = 1;
		startrectleft = 0.88;
		numallies = 0;
		startrecttop = 0;
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
	numusers = 2;
	gametype = __BARVERSION__;
	GameStartDelay = 5;
	myplayername = __PLAYERNAME__;
	nohelperais = 0;
}
	]],

}

return scenariodata
