local scenariodata = {
	index			= 2, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "threebarbscomet", -- no spaces, lowercase, this will be used to save the score
    version         = "1.0", -- increment this to keep the score when changing a mission
	title			= "Catch those rare Comets", -- can be anything
	author			= "Beherith", -- your name here
	imagepath		= "scenario003.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "", -- This text will be drawn over image
    summary         = [[Destroy three Barbarian AI's on large, metal rich flat map.]],
	briefing 		= [[This scenario is a true test of a players skill, only the very few top players can handle three Barbarian AI players on such a metal-rich map. If you win this scenario on at least Normal difficulty, dont forget to post your replay on our Discord server for bragging rights.

Tips:
- One of the three AI's will likely start with an Aircraft plant
- AI's expand very quickly, and you must prevent them from getting too much metal early on before they overwhelm you
- Early raids on the enemy's bases is key to keeping them on the back foot.
- The enemies randomly start with the Armada or Cortex factions.
- Keep up continous pressure, the moment you sit back, the enemy will overwhelm you!

Good luck, you will need all your skill here!
    ]],

	mapfilename		= "Comet Catcher Remake 1.8", -- the name of the map to be displayed here
	playerstartx	= "10%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "40%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 1800, -- par time in seconds
	parresources	= 1000000, -- par resource amount
	difficulty		= 10, -- Percieved difficulty at 'normal' level: integer 1-10
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
    unitlimits   = { -- table of unitdefname : maxnumberoftese units, 0 is disable it
        -- dont use the one in startscript, put the disabled stuff here so we can show it in scenario window!
        -- armavp = 0, -- disables arm advanced vehicle plant
        -- coravp = 0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff",
        scenarioid = "threebarbscomet",
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

	[ai1]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbarIAnstable(2);
		ShortName = BARb;
		Team = 2;
		Version = stable;
	}

	[team1]
	{
		Side = Random;
		Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.88436127 0.07208818 0.09521562;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[allyTeam1]
	{
		startrectright = 1;
		startrectbottom = 1;
		startrectleft = 0.88;
		numallies = 0;
		startrecttop = 0;
	}

	[team3]
	{
		Side = Random;
		Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.99150527 0.4589209 0.39213371;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[team0]
	{
		Side = __PLAYERSIDE__;
		Handicap = __PLAYERHANDICAP__;
		RgbColor = 0 0.50999999 0.77999997;
		AllyTeam = 0;
		TeamLeader = 0;
	}

	[team2]
	{
		Side = Random;
		Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.64580417 0.27604705 0.80884558;
		AllyTeam = 1;
		TeamLeader = 0;
	}

    [modoptions]
    {
        scenariooptions = __SCENARIOOPTIONS__;
    }


	[ai2]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbarIAnstable(3);
		ShortName = BARb;
		Team = 3;
		Version = stable;
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
	GameStartDelay = 5;
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
