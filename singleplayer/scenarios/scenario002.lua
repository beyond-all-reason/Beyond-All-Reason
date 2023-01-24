local scenariodata = {
	index			= 999, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "dguntestscenario", -- no spaces, lowercase, this will be used to save the score
    version         = "1.0", -- increment this to keep the score when changing a mission
	title			= "DGunning the enemy Commander", -- can be anything
	author			= "Beherith", -- your name here
	imagepath		= "scenario002.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "In a 1v1 situation, the first to DGun dies.", -- This text will be drawn over image
    summary         = [[How Does DGunning enemy Commander work? Try it here.]],
	briefing 		= [[In order to preven unfair situations in multiplayer games when the victory conditions are to destroy all enemy Commanders, DGunning the last standing enemy Commander is forbidden. If the last enemy Commander is dgunned, the team who DGunned the last Commander loses, instead of the team who got DGunned.

    You will have to resort to other methods of killing the last commands.
    ]],

	mapfilename		= "BarR 1.1", -- the name of the map to be displayed here
	playerstartx	= "50%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "50%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 300, -- par time in seconds
	parresources	= 10000, -- par resource amount
	difficulty		= 1, -- Percieved difficulty at 'normal' level: integer 1-10
    defaultdifficulty = "Normal", -- an entry of the difficulty table
    difficulties    = { -- Array for sortedness, Keys are text that appears in selector (as well as in scoring!), values are handicap levels
        {name = "Normal"  , playerhandicap = 0, enemyhandicap=0},
    },
    allowedsides     = {"Armada","Cortex","Random"}, --these are the permitted factions for this mission
	victorycondition= "Kill all enemy Commanders", -- This is plaintext, but should be reflected in startscript
	losscondition	= "Death of your Commander",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberoftese units, 0 is disable it
	-- dont use the one in startscript, put it here!
        armavp = 0,
        coravp = 0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff",
        scenarioid = "dguntestscenario", --must be present for scores
		disablefactionpicker = true, -- this is needed to prevent faction picking outside of the allowedsides
    },
    -- https://github.com/spring/spring/blob/105.0/doc/StartScriptFormat.txt
	startscript		= [[ [Game]
{
	[allyTeam0]
	{
		startrectright = 0.42066422;
		startrectbottom = 0.50922507;
		startrectleft = 0.34317344;
		numallies = 0;
		startrecttop = 0.39852399;
	}

	[team1]
	{
        Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.28831697 0.75334734 0.74793065;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[team0]
	{
        Side = __PLAYERSIDE__;
        Handicap = __PLAYERHANDICAP__;
		RgbColor = 0.40995723 0.34172571 0.7648201;
		AllyTeam = 0;
		TeamLeader = 0;
	}

	[modoptions]
	{
        scenariooptions = __SCENARIOOPTIONS__;
	}

	[allyTeam1]
	{
		startrectright = 0.47232476;
		startrectbottom = 0.52767527;
		startrectleft = 0.41697419;
		numallies = 0;
		startrecttop = 0.39114392;
	}

	[ai0]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = SimpleAI(1);
		ShortName = SimpleAI;
		Team = 1;
		Version = <not-versioned>;
	}

	[player0]
	{
		IsFromDemo = 0;
		Name = __PLAYERNAME__;;
		Team = 0;
		rank = 0;
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

	NumRestrictions=__NUMRESTRICTIONS__;

	[RESTRICT]
	{
        __RESTRICTEDUNITS__
	}
}
	]],

}

return nil -- scenariodata
