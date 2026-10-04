-- Infantry Simulator singleplayer challenge
-- Author: Zow

local scenariodata = {
    index           = 6, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
    scenarioid      = "twobarbspwakonly006", -- no spaces, lowercase, this will be used to save the score
    version         = "1", -- increment this to keep the score when changing a mission
    title           = "Infantry Simulator", -- can be anything
	author			= "Zow", -- your name here
    imagepath       = "scenario006.jpg", -- placed next to lua file, should be 3:1 ratio banner style
    imageflavor     = "You can resurrect your fallen infantry units", -- This text will be drawn over image
    summary         = [[Defeat two hostile but primitive Barbarians with nothing but your own primitive infantry.]],
    briefing        = [[Both you and your enemy may only make infantry units. Since you're up against a larger enemy, be sure to expand quickly and reclaim/resurrect effectively to maintain an advantage. Don't forget to raid the enemy!

Score:
    1. Speed: destroy the enemy Commanders as fast as possible.
    2. Efficiency: minimize the amount of metal and energy used.

Tips:
    1. Light laser towers are incredibly effective against small amounts of infantry.
    2. Resurrecting a fallen infantry unit will immediately add it to your army. Use this to stage epic comebacks.
    3. Infantry can be very effective at finding and killing enemy commanders. Be sure to take control of the wreck after killing the first one.
    4. Grunts have more range than Pawns, but less damage for their cost. Both have their strengths and weaknesses!
    ]],

    mapfilename     = "Red Comet Remake 1.8", -- the name of the map to be displayed here
    playerstartx    = "10%", -- X position of where player comm icon should be drawn, from top left of the map
    playerstarty    = "50%", -- Y position of where player comm icon should be drawn, from top left of the map
    partime         = 1800, -- par time in seconds
    parresources    = 1000000, -- par resource amount
    difficulty      = 7, -- Percieved difficulty at 'normal' level: integer 1-10
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
    losscondition   = "Death of your Commander",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberoftese units, 0 is disable it
        --armavp = 0,
        --coravp = 0,
        armaap=0,
        armalab=0,
        armap=0,
        armavp=0,
        armhp=0,
        armshltx=0,
        armvp=0,
        armflea=0,
        armham=0,
        armjeth=0,
        armrock=0,
        armwar=0,
        coraap=0,
        coralab=0,
        corap=0,
        coravp=0,
        corhp=0,
        corgant=0,
        corvp=0,
        corcrash=0,
        corstorm=0,
        corthud=0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff",
        scenarioid = "twobarbspwakonly006",
        disablefactionpicker = true, -- this is needed to prevent faction picking outside of the allowedsides
    },
    -- https://github.com/spring/spring/blob/105.0/doc/StartScriptFormat.txt
    startscript     = [[
[Game]
{
    [allyTeam0]
    {
        startrectright = 0.25;
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
        startrectleft = 0.75;
        numallies = 0;
        startrecttop = 0;
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
