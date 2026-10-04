local scenariodata = {
	index			= 11, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "SpeedMetalSnipe011", -- no spaces, lowercase, this will be used to save the score and can be used gadget side
    version         = "1", -- increment this to reset the score when changing a mission, as scores are keyed by (scenarioid,version,difficulty)
	title			= "Tick Tock", -- can be anything
	author			= "Zow", -- your name here
	imagepath		= "scenario011.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "Enemy Behemoths", -- This text will be drawn over image
    summary         = [[On the metal-rich Speed Metal road, you find yourself face to face with an enemy Cortex commander and its four pet Behemoths.]],
	briefing 		= [[You've been tasked to defeat an enemy who is rumored to have four of the tankiest units in the game: the Cortex Behemoth. While they are slow, they spell almost certain doom for your base should they reach it. Your intelligence team has snuck dragon eyes into the enemy base and along the long Speed Metal road to report on the position of these beasts, but are otherwise defenseless against them. Perhaps you must snipe the enemy commander to demoralize their army...

Tips:
 - On Speed Metal, metal extractors can be built anywhere and have a rather high output. Wind generators are by far the best energy source here, being consistently set to the maximum possible wind (25 e/s).
 - You start with a dozen dragon eyes and enough energy to keep them cloaked. Use this to tell how much time you have before the enemy Behemoths reach your base.
 - Since most land options will likely be blocked by the garguantuan Behemoths, consider using air options to infiltrate. Armada has two main air assault options: the Banshee, a more mobile light gunship with a machine gun weapon, and the Stormbringer, a traditional bomber that drops 5 bombs in a line. If you choose to make bombers, be sure to send air scouts before them to scout out the enemy.
 - The Stork air transport may be used to drop units to the enemy base, but be careful as the enemy has light anti-air turrets that will shoot mediocre drop attempts down.
 - As a last ditch attempt, the commander may attempt to D-gun the Behemoths, which will one tap them. Be wary that if your commander dies, you lose!

Scoring:
 - Time taken to complete the scenario
 - Resources spent to kill the enemy commander
 ]],

	mapfilename		= "SpeedMetal BAR V2", -- the name of the map to be displayed here, and which to play on, no .smf ending needed
	playerstartx	= "5%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "45%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 300, -- par time in seconds (time a mission is expected to take on average)
	parresources	= 8000, -- par resource amount (amount of metal one is expected to spend on mission)
	difficulty		= 8, -- Percieved difficulty at 'normal' level: integer 1-10
    defaultdifficulty = "Normal", -- an entry of the difficulty table
    difficulties    = { -- Array for sortedness, Keys are text that appears in selector (as well as in scoring!), values are handicap levels
    -- handicap values range [-100 - +100], with 0 being regular resources
    -- Currently difficulty modifier only affects the resource bonuses
        {name = "Beginner", playerhandicap = 50, enemyhandicap=0},
        {name = "Novice"  , playerhandicap = 25, enemyhandicap=0},
        {name = "Normal"  , playerhandicap = 0, enemyhandicap=0},
        {name = "Hard"    , playerhandicap = 0,  enemyhandicap=25},
        {name = "Brutal" , playerhandicap = 0,  enemyhandicap=50},
    },
    allowedsides     = {"Armada"}, --these are the permitted factions for this mission, ch0ose from {"Armada", "Cortex", "Random"}
	victorycondition= "Kill the Enemy Commander", -- This is plaintext, but should be reflected in startscript
	losscondition	= "Death of your Commander",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberofthese units, 0 means disable it
        -- dont use the one in startscript, put the disabled stuff here so we can show it in scenario window!
        --armavp = 0,
        --coravp = 0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff", -- blank
        scenarioid = "SpeedMetalSnipe011", -- this MUST be present and identical to the one defined at start
		disablefactionpicker = true, -- this is needed to prevent faction picking outside of the allowedsides

        unitloadout = {
			-- You can specify units that you wish to spawn here, they only show up once game starts,
			-- You can create these lists easily using the feature/unit dumper by using dbg_feature_dumper.lua widget pinned to the #challenges channel on discord
			-- Set up a skirmish like your scenario, so the team ID's will be correct
			-- Then using /globallos and cheats, add as many units as you wish
			-- The type /luaui dumpunits
			-- Fish out the dumped units from your infolog.txt and add them here
			-- Note: If you have ANY units in loadout, then there will be no initial units spawned for anyone, so you have to take care of that
			-- so you must spawn the initial commanders then!

            {name = 'corcom', x = 12330, y = 118, z = 1000, rot = 0 , team = 1},
            {name = 'corjugg', x = 13150, y = 118, z = 182, rot = 0 , team = 1},
            {name = 'corjugg', x = 13150, y = 118, z = 644, rot = 0 , team = 1},
            {name = 'corjugg', x = 13150, y = 118, z = 1378, rot = 0 , team = 1},
            {name = 'corjugg', x = 13150, y = 118, z = 1861, rot = 0 , team = 1},
            {name = 'armcom', x = 1044, y = 118, z = 1000, rot = 0 , team = 0},
            {name = 'coreyes', x = 550, y = 118, z = 1000, rot = 0 , team = 1},
            {name = 'armsolar', x = 936, y = 118, z = 984, rot = -16384 , team = 0},
            {name = 'armsolar', x = 936, y = 118, z = 1064, rot = -16384 , team = 0},
            {name = 'armsolar', x = 856, y = 118, z = 984, rot = -16384 , team = 0},
            {name = 'armsolar', x = 776, y = 118, z = 984, rot = -16384 , team = 0},
            {name = 'armeyes', x = 2013, y = 118, z = 809, rot = 0 , team = 0},
            {name = 'armsolar', x = 696, y = 118, z = 984, rot = -16384 , team = 0},
            {name = 'armeyes', x = 2005, y = 118, z = 1232, rot = 0 , team = 0},
            {name = 'armeyes', x = 5968, y = 118, z = 807, rot = 0 , team = 0},
            {name = 'armsolar', x = 856, y = 118, z = 1064, rot = -16384 , team = 0},
            {name = 'armeyes', x = 5955, y = 118, z = 1242, rot = 0 , team = 0},
            {name = 'armeyes', x = 7335, y = 118, z = 812, rot = 0 , team = 0},
            {name = 'armeyes', x = 7347, y = 118, z = 1229, rot = 0 , team = 0},
            {name = 'armsolar', x = 776, y = 118, z = 1064, rot = -16384 , team = 0},
            {name = 'armeyes', x = 11308, y = 118, z = 819, rot = 0 , team = 0},
            {name = 'armeyes', x = 11304, y = 118, z = 1231, rot = 0 , team = 0},
            {name = 'armsolar', x = 696, y = 118, z = 1064, rot = -16384 , team = 0},
            {name = 'armeyes', x = 13285, y = 118, z = 67, rot = 0 , team = 0},
            {name = 'armeyes', x = 13280, y = 118, z = 704, rot = 0 , team = 0},
            {name = 'armeyes', x = 13279, y = 118, z = 1342, rot = 0 , team = 0},
            {name = 'armeyes', x = 13284, y = 118, z = 1984, rot = 0 , team = 0},
            {name = 'corllt', x = 11488, y = 118, z = 732, rot = 0 , team = 1},
            {name = 'corllt', x = 11485, y = 118, z = 474, rot = 0 , team = 1},
            {name = 'corllt', x = 11484, y = 118, z = 219, rot = 0 , team = 1},
            {name = 'corllt', x = 11486, y = 118, z = 1312, rot = 0 , team = 1},
            {name = 'corllt', x = 11484, y = 118, z = 1563, rot = 0 , team = 1},
            {name = 'corllt', x = 11485, y = 118, z = 1824, rot = 0 , team = 1},
            {name = 'corrl', x = 11608, y = 118, z = 600, rot = -16384 , team = 1},
            {name = 'corrl', x = 11608, y = 118, z = 360, rot = -16384 , team = 1},
            {name = 'corrl', x = 11608, y = 118, z = 1448, rot = -16384 , team = 1},
            {name = 'corrl', x = 11608, y = 118, z = 1688, rot = -16384 , team = 1},
            {name = 'corrad', x = 11600, y = 118, z = 1568, rot = -16384 , team = 1},
            {name = 'corrad', x = 11600, y = 118, z = 480, rot = -16384 , team = 1},
            {name = 'armllt', x = 7201, y = 118, z = 1020, rot = 0 , team = 0},
		},
		featureloadout = {
			-- Similarly to units, but these can also be resurrectable!
            -- You can /give corcom_dead with cheats when making your scenario, but it might not contain the 'resurrectas' tag, so be careful to add it if needed
			 -- {name = 'corcom_dead', x = 1125,y = 237, z = 734, rot = "0" , scale = 1.0, resurrectas = "corcom"}, -- there is no need for this dead comm here, just an example
		}
    },
    -- Full Documentation for start script here:
    -- https://github.com/spring/spring/blob/105.0/doc/StartScriptFormat.txt

    -- HOW TO MAKE THE START SCRIPT: Use Chobby's single player mode to set up your start script. When you launch a single player game, the start script is dumped into infolog.txt
    -- ModOptions: You can also set modoptions in chobby, and they will get dumped into the infolog's start script too, or just set then in chobby and copy paste them into the [modoptions] tag. as below
    -- The following keys MUST be present in startscript below
    --  scenariooptions = __SCENARIOOPTIONS__;
    -- Name = __PLAYERNAME__;
    -- myplayername = __PLAYERNAME__;
    -- gametype = __BARVERSION__;
    -- mapname =__MAPNAME__;

    -- Optional keys:
    -- __ENEMYHANDICAP__
    -- __PLAYERSIDE__
    -- __PLAYERHANDICAP__
    -- __NUMRESTRICTIONS__
    -- __RESTRICTEDUNITS__

	startscript		= [[[GAME]
{
	[allyTeam0]
	{
		numallies = 0;
	}
	[team1]
	{
		Side = Cortex;
        Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.63758504 0.35682863 0.61179775;
		AllyTeam = 1;
		TeamLeader = 0;
        StartPosX = 5000;
        StartPosZ = 1400;
	}
	[team0]
	{
        Side = __PLAYERSIDE__;
		Handicap = __PLAYERHANDICAP__;
		RgbColor = 0.59311622 0.61523652 0.54604363;
		AllyTeam = 0;
		TeamLeader = 0;
        StartPosX = 1200;
        StartPosZ = 800;
	}
	[modoptions]
	{
        scenariooptions = __SCENARIOOPTIONS__;
	}
	[allyTeam1]
	{
		numallies = 0;
	}
	[ai0]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = BARbarIAnstable;
		ShortName = BARb;
		Team = 1;
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
	startpostype = 3; // 0 fixed, 1 random, 2 choose in game, 3 choose before game (see StartPosX)
    mapname = __MAPNAME__;
	ishost = 1;
	numusers = 2;
    gametype = __BARVERSION__;
    GameStartDelay = 5;  // seconds before game starts after loading/placement
    myplayername = __PLAYERNAME__;
	nohelperais = 0;
}
	]],

}

return scenariodata
