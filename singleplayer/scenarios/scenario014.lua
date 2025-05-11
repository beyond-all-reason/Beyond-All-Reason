local scenariodata = {
	index			= 14, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "pinewoodvsbarb014", -- no spaces, lowercase, this will be used to save the score
    version         = "1.0", -- increment this to keep the score when changing a mission
	title			= "A Safe Haven", -- can be anything
	author			= "Beherith", -- your name here
	imagepath		= "scenario014.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "Build a shipyard from the shores.", -- This text will be drawn over image
    summary         = [[An enemy Commander has landed on the southeast corner of the map, neutralize it and destroy every last unit to claim all the resources of this world.]],
	briefing 		= [[The map is split in two by a river, which is passable on both sides by hovercraft and amphibious units. The central bridge can be easily defended from the outcrops on the top. Make sure to set up some light defences on your end of the bridge as soon as possible. The mountain ranges will provide adequate cover against long-range plasma cannons.
 
 
Tips:
 
 ‣  Start by building the initial 3 Metal Extractors, then 2 Solar Generators, and a Bot Lab
 
 ‣  Make sure to send a few attack units early on to secure the bridge
 
 ‣  Watch out for amphibous units or hovercraft making their way across the river
 
 ‣  After securing the bridge and claiming the metal on the western side of the river, you should have sufficient resources to advance your technology to Tier 2.
 
 ‣  The map doesnt contain very much contested resources, so you should be free to take the Metal Extractors on your side of the map
 
 
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

	mapfilename		= "Pinewood_Derby_V1", -- the name of the map to be displayed here
	playerstartx	= "10%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "25%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 1200, -- par time in seconds
	parresources	= 100000, -- par resource amount
	difficulty		= 2, -- Percieved difficulty at 'normal' level: integer 1-10
    defaultdifficulty = "Normal", -- an entry of the difficulty table
    difficulties    = { -- Array for sortedness, Keys are text that appears in selector (as well as in scoring!), values are handicap levels
        {name = "Beginner", playerhandicap = 50 , enemyhandicap = -50},
        {name = "Novice"  , playerhandicap = 25 , enemyhandicap = -25},
        {name = "Normal"  , playerhandicap = 0  , enemyhandicap = 0  },
        {name = "Hard"    , playerhandicap = 0, enemyhandicap = 50 },
        {name = "Brutal"  , playerhandicap = 0, enemyhandicap = 100 },
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
        scenarioid = "pinewoodvsbarb014", --must be present for scores
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
	GameStartDelay = 3;
    myplayername = __PLAYERNAME__;
	nohelperais = 0;
}
	]],

}

return scenariodata -- scenariodata
