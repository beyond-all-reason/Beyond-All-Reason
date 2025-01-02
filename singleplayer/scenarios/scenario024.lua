--[[ 
    Benchmark Pathfinding Scenario Data
    This scenario configures a pathfinding benchmark that spawns a significant number of units
    and measures performance. It includes multiple spawn rate options and a short automated test
    sequence. The results are displayed on-screen and stored for reference.

    * index: unique numeric index, must match the file name.
    * scenarioid: internal ID for saving or scoring data.
    * version: scenario revision for tracking.
    * title: displayed scenario name.
    * author: scenario authors.
    * imagepath, imageflavor: for scenario selection visuals.
    * summary, briefing: textual descriptions.
    * mapfilename: name of the map used.
    * difficulties: array of selectable difficulty settings, each with unique parameters.

    Future Enhancements:
      - Additional difficulty tiers
      - Extended briefing with advanced usage instructions
      - Additional spawn rate options
      - Automatic submission of results to external servers
--]]

local scenariodata = {
    index             = 24,                     -- Must match filename number
    scenarioid        = "benchmark_pathfinding",-- Used to save or track scenario scores
    version           = "1.0",                  -- Scenario version
    title             = "Benchmark pathfinding",-- Displayed scenario name
    author            = "Beherith, AKU",        -- Authors
    isnew             = true,                   -- Indicates if scenario is new in UI
    imagepath         = "scenario023.jpg",      -- 3:1 ratio banner image
    imageflavor       = "Units will act automatically during the benchmark",
    summary           = [[Pathfinding benchmark.]],
    briefing          = [[
Pathfinding benchmark measuring performance. The game auto-centers the camera over the units; 
avoid camera movement or in-game interaction while the benchmark runs. 
On completion, results appear on-screen, log to infolog, and optionally upload to the server. 
Number of units at test end depends on chosen spawn rate:
- 1 unit spawn rate: ~700 units 
- 3 unit spawn rate: ~2,000 units
- 10 unit spawn rate: ~7,000 units
- 15 unit spawn rate: ~10,000 units

Benchmark runs for 2,000 simulation frames.

Internal dev command example (cheats required):
    /luarules fightertest armcv armck 11000 1 12000

Used for mass spawning and testing. 
    ]],

    mapfilename       = "Jade Empress 1.3",
    playerstartx      = "10%",
    playerstarty      = "10%",
    partime           = 180,   -- par time in seconds
    parresources      = 1,     -- par resource amount
    difficulty        = 15,    -- perceived normal difficulty 1-10
    defaultdifficulty = "3 unit spawn rate",

    -- Various difficulty presets, controlling spawn rate.
    difficulties = {
        { name = "1 unit spawn rate",  playerhandicap = "armcv armck 11000 1 12000",  enemyhandicap = 0 },
        { name = "3 unit spawn rate",  playerhandicap = "armcv armck 11000 3 12000",  enemyhandicap = 0 },
        { name = "10 unit spawn rate", playerhandicap = "armcv armck 11000 10 12000", enemyhandicap = 0 },
        { name = "15 unit spawn rate", playerhandicap = "armcv armck 11000 15 12000", enemyhandicap = 0 },
    },

    allowedsides      = { "" },  -- restricted to single side
    victorycondition  = "None",  -- textual or placeholder
    losscondition     = "None",
    unitlimits        = {},

    scenariooptions = {
        scenarioid        = "benchmark_pathfinding",
        disablefactionpicker = true,
        benchmarkcommand  = "luarules fightertest armcv armck 11000 1 12000",
        benchmarkframes   = 2000,
        -- Could add more parameters in future expansions if needed.
    },

    startscript = [[
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

return scenariodata
