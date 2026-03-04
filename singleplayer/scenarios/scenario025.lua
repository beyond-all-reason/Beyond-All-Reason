local scenariodata = {
	index           = 25, -- integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid      = "firstcontact025", -- no spaces, lowercase, used to save score
	version         = "1", -- increment this to reset the score when changing a mission
	title           = "First Contact", -- can be anything
	author          = "BAR Team",
	imagepath       = "scenario025.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor     = "Hold the crossing at all costs.",
	summary         = [[An enemy Commander has crossed the river and is establishing a forward base. Destroy their forces within 10 minutes before they consolidate.]],
	briefing        = [[An enemy has established a foothold on the far side of the Supreme Crossing. You have ten minutes to eliminate their Commander and all supporting forces before they bring up reinforcements we cannot stop.

Strategy:
  ‣  Secure the metal deposits along the isthmus early — resources will be scarce.
  ‣  Build defensive turrets near the narrow crossing to blunt incoming attacks.
  ‣  Push across and eliminate the enemy Commander before time runs out.

Scoring:
  ‣  Speed: destroy all enemy forces as fast as possible.
  ‣  Efficiency: minimise resources spent during the mission.
	]],

	mapfilename     = "Supreme_Crossing_V1",
	playerstartx    = "25%",
	playerstarty    = "75%",
	partime         = 480,      -- par time in seconds
	parresources    = 800000,   -- par resource amount
	difficulty      = 4,
	defaultdifficulty = "Normal",
	difficulties    = {
		{ name = "Beginner", playerhandicap = 50, enemyhandicap =  0 },
		{ name = "Novice",   playerhandicap = 25, enemyhandicap =  0 },
		{ name = "Normal",   playerhandicap =  0, enemyhandicap =  0 },
		{ name = "Hard",     playerhandicap =  0, enemyhandicap = 25 },
		{ name = "Brutal",   playerhandicap =  0, enemyhandicap = 50 },
	},
	allowedsides    = { "Armada" },
	victorycondition = "Destroy the enemy Commander within 10 minutes",
	losscondition    = "Time runs out, or your Commander is destroyed",
	unitlimits       = {},

	scenariooptions = {
		scenarioid         = "firstcontact025", -- MUST match scenarioid above
		disablefactionpicker = true,
		missionscript      = "scenarios/missions/scenario025_mission.lua",

		unitloadout = {
			-- Player (team 0) starting forces
			{ name = 'armcom',   x = 2157, y = 154, z = 6976, rot = 16384, team = 0 },
			{ name = 'armck',    x = 2100, y = 154, z = 6850, rot = 16384, team = 0 },
			{ name = 'armck',    x = 2200, y = 154, z = 7050, rot = 16384, team = 0 },
			{ name = 'armsolar', x = 2040, y = 154, z = 6800, rot = 16384, team = 0 },
			{ name = 'armwin',   x = 1990, y = 154, z = 7100, rot = 16384, team = 0 },
			{ name = 'armwin',   x = 2040, y = 154, z = 7100, rot = 16384, team = 0 },
			{ name = 'armmex',   x = 2050, y = 154, z = 6970, rot = 16384, team = 0 },
			{ name = 'armmex',   x = 1760, y = 154, z = 7740, rot = 16384, team = 0 },

			-- Enemy (team 1) starting forces — forward base across the crossing
			{ name = 'corcom',   x = 4800, y = 52,  z = 3600, rot = -16384, team = 1 },
			{ name = 'corck',    x = 4750, y = 52,  z = 3200, rot = -16384, team = 1 },
			{ name = 'corck',    x = 4800, y = 52,  z = 3000, rot = -16384, team = 1 },
			{ name = 'corsolar', x = 5000, y = 52,  z = 3200, rot =      0, team = 1 },
			{ name = 'corwin',   x = 4950, y = 52,  z = 3300, rot =      0, team = 1 },
			{ name = 'cormex',   x = 5040, y = 52,  z = 2540, rot =      0, team = 1 },
			{ name = 'cormex',   x = 5650, y = 52,  z = 2480, rot =      0, team = 1 },
			{ name = 'corllt',   x = 4900, y = 52,  z = 3380, rot = -16384, team = 1 },
		},
		featureloadout = {},
	},

	-- https://github.com/spring/spring/blob/105.0/doc/StartScriptFormat.txt
	startscript = [[[GAME]
{
	[allyTeam0]
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
		RgbColor = 0.59311622 0.61523652 0.54604363;
		AllyTeam = 0;
		TeamLeader = 0;
		StartPosX = 1657;
		StartPosZ = 2836;
	}

	[team1]
	{
		Side = Cortex;
		Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.63758504 0.35682863 0.61179775;
		AllyTeam = 1;
		TeamLeader = 0;
		StartPosX = 4200;
		StartPosZ = 1400;
	}

	[ai0]
	{
		Host = 0;
		IsFromDemo = 0;
		Name = SimpleAI (2);
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
		deathmode = own_com;
		scenariooptions = __SCENARIOOPTIONS__;
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
}
	]],
}

return scenariodata
