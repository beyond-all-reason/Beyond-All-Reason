local scenariodata = {
	index			= 19, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "glaciergoliath018", -- no spaces, lowercase, this will be used to save the score
    version         = "1.0", -- increment this to keep the score when changing a mission
	title			= "David vs. Goliath", -- can be anything
	author			= "Beherith", -- your name here
	isnew 			= true,
	imagepath		= "scenario019.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "Scour the map for hidden treasures", -- This text will be drawn over image
    summary         = [[Only a few units remain, Tzar, Tiger, Negotiator and a few supporting roles. Navigate your way through this glacier pass without building a base, and destroy the waves of Armada Tier 1 units to get to their Commander.]],
	briefing 		= [[You only have a couple of vehicles to navigate the treacherous Glacer Pass, straight through an Armada base. Luckily this Armada Commander does not have much useful technology at his disposal. 
 
Intelligence reports mines around the walled entrance to the main Armada base, enter cautiously, or use the massive area of effect damage of the Tzar to clear mines.
 
You will not be able to construct a base in this mission at all.  
 
Tips:
 - Spectre are cloakable, stealthy spies, that can be self-destructed for a large EMP blast to stun groups of units.
 - Tzar has a very large range, and a huge area of effect, but is slow and hard to maneuver. Use Tigers to keep any smaller Tier 1 units away from it.
 - Negotiator, while slow, has an enormous range, and can take out anything foolish enough to stand still.
 - Graverobbers can resurrect wrecked units, however, wrecks can be reduced to useless heaps by area-of-effect damage.
 - There may be useful wrecks on different areas of the map, that can assist you in your mission.
 
Scoring:
 - Time taken to complete the scenario
 - Resources spent to destroy all enemy units.
 
The difficulty modifier will change the amount of resources you and the enemy receive from metal and energy production structures:
 - Beginner: You +50%, enemy -50%
 - Novice: You +25%, enemy -25%
 - Normal: Regular resources for both sides
 - Hard: Regular resources for you, +50% for the enemy
 - Brutal: Regular resources for you, +100% for the enemy
    ]],

	mapfilename		= "Glacier Pass 1.2", -- the name of the map to be displayed here
	playerstartx	= "80%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "80%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 1800, -- par time in seconds
	parresources	= 50000, -- par resource amount
	difficulty		= 6, -- Percieved difficulty at 'normal' level: integer 1-10
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
	losscondition	= "Loss of all your units",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberoftese units, 0 is disable it
	-- dont use the one in startscript, put it here!
        armck = 0,
		armcv = 0,
		armmlv = 0,
		armbeaver = 0,
		armlab = 1,
		armvp = 1,
		armap = 0,
		armhp = 0,
		armfhp = 0,
		armrectr = 0,
    } ,
    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        --myoption = "dostuff",
        scenarioid = "glaciergoliath018", --must be present for scores
		disablefactionpicker = true, -- this is needed to prevent faction picking outside of the allowedsides
		unitloadout = {
			-- {name = 'corcom', x = 872, y = 1103, z = 1443, rot = 25860 , team = 1},
			-- {name = 'armcom', x = 4062, y = 1064, z = 3609, rot = 0 , team = 0},
			-- {name = 'corca', x = 4400, y = 1108, z = 4251, rot = 10273 , team = 0},
			{name = 'coradvsol', x = 4160, y = 1121, z = 4192, rot = -16384 , team = 0},
			{name = 'coradvsol', x = 4224, y = 1116, z = 4192, rot = -16384 , team = 0},
			{name = 'coradvsol', x = 4288, y = 1111, z = 4192, rot = -16384 , team = 0},
			--{name = 'corestor', x = 4160, y = 1126, z = 4256, rot = -16384 , team = 0},
			{name = 'corrad', x = 4208, y = 1123, z = 4240, rot = -16384 , team = 0},
			{name = 'corjamt', x = 4208, y = 1123, z = 4272, rot = -16384 , team = 0},
			{name = 'coradvsol', x = 4288, y = 1115, z = 4256, rot = -16384 , team = 0},
			{name = 'coradvsol', x = 4160, y = 1126, z = 4320, rot = -16384 , team = 0},
			{name = 'coradvsol', x = 4224, y = 1122, z = 4320, rot = -16384 , team = 0},
			{name = 'coradvsol', x = 4288, y = 1116, z = 4320, rot = -16384 , team = 0},
			{name = 'corfort', x = 4112, y = 1121, z = 4144, rot = -16384 , team = 0},
			{name = 'corfort', x = 4112, y = 1124, z = 4176, rot = -16384 , team = 0},
			{name = 'corfort', x = 4112, y = 1129, z = 4208, rot = -16384 , team = 0},
			{name = 'corfort', x = 4112, y = 1129, z = 4240, rot = -16384 , team = 0},
			{name = 'corfort', x = 4112, y = 1129, z = 4272, rot = -16384 , team = 0},
			{name = 'corfort', x = 4112, y = 1130, z = 4304, rot = -16384 , team = 0},
			{name = 'corfort', x = 4112, y = 1130, z = 4336, rot = -16384 , team = 0},
			{name = 'corfort', x = 4112, y = 1136, z = 4368, rot = -16384 , team = 0},
			{name = 'corfort', x = 4144, y = 1128, z = 4368, rot = -16384 , team = 0},
			{name = 'corfort', x = 4176, y = 1124, z = 4368, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4080, y = 1133, z = 4304, rot = -16384 , team = 0},
			{name = 'corfort', x = 4208, y = 1122, z = 4368, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4048, y = 1136, z = 4304, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4016, y = 1136, z = 4304, rot = -16384 , team = 0},
			{name = 'corfort', x = 4240, y = 1121, z = 4368, rot = -16384 , team = 0},
			{name = 'corfort', x = 4272, y = 1119, z = 4368, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4176, y = 1124, z = 4400, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4176, y = 1124, z = 4432, rot = -16384 , team = 0},
			{name = 'corfort', x = 4304, y = 1119, z = 4368, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4176, y = 1124, z = 4464, rot = -16384 , team = 0},
			{name = 'corfort', x = 4336, y = 1119, z = 4368, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4272, y = 1120, z = 4400, rot = -16384 , team = 0},
			{name = 'corfort', x = 4336, y = 1116, z = 4336, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4272, y = 1120, z = 4432, rot = -16384 , team = 0},
			{name = 'corfort', x = 4336, y = 1114, z = 4304, rot = -16384 , team = 0},
			{name = 'corfort', x = 4336, y = 1112, z = 4272, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4272, y = 1119, z = 4464, rot = -16384 , team = 0},
			{name = 'corfort', x = 4336, y = 1110, z = 4240, rot = -16384 , team = 0},
			{name = 'corfort', x = 4336, y = 1107, z = 4208, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4368, y = 1112, z = 4304, rot = -16384 , team = 0},
			{name = 'corfort', x = 4336, y = 1106, z = 4176, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4400, y = 1112, z = 4304, rot = -16384 , team = 0},
			{name = 'corfort', x = 4336, y = 1102, z = 4144, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4432, y = 1112, z = 4304, rot = -16384 , team = 0},
			{name = 'corfort', x = 4304, y = 1107, z = 4144, rot = -16384 , team = 0},
			{name = 'corfort', x = 4272, y = 1108, z = 4144, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4368, y = 1103, z = 4208, rot = -16384 , team = 0},
			{name = 'corfort', x = 4240, y = 1111, z = 4144, rot = -16384 , team = 0},
			{name = 'corfort', x = 4208, y = 1113, z = 4144, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4400, y = 1102, z = 4208, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4432, y = 1099, z = 4208, rot = -16384 , team = 0},
			{name = 'corfort', x = 4176, y = 1117, z = 4144, rot = -16384 , team = 0},
			{name = 'corfort', x = 4144, y = 1119, z = 4144, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4272, y = 1105, z = 4112, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4272, y = 1100, z = 4080, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4272, y = 1097, z = 4048, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4176, y = 1112, z = 4112, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4176, y = 1110, z = 4080, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4176, y = 1105, z = 4048, rot = -16384 , team = 0},
			{name = 'cormaw', x = 4112, y = 1116, z = 4096, rot = -16384 , team = 0},
			{name = 'cormaw', x = 4080, y = 1121, z = 4144, rot = -16384 , team = 0},
			{name = 'cormaw', x = 4080, y = 1139, z = 4368, rot = -16384 , team = 0},
			{name = 'cormaw', x = 4112, y = 1136, z = 4400, rot = -16384 , team = 0},
			{name = 'cormaw', x = 4336, y = 1120, z = 4400, rot = -16384 , team = 0},
			{name = 'cormaw', x = 4368, y = 1118, z = 4368, rot = -16384 , team = 0},
			{name = 'cormaw', x = 4368, y = 1101, z = 4144, rot = -16384 , team = 0},
			{name = 'cormaw', x = 4336, y = 1100, z = 4112, rot = -16384 , team = 0},
			{name = 'corhlt', x = 4224, y = 1102, z = 4048, rot = -16384 , team = 0},
			{name = 'corhlt', x = 4416, y = 1108, z = 4256, rot = -16384 , team = 0},
			{name = 'corhlt', x = 4016, y = 1130, z = 4256, rot = -16384 , team = 0},
			{name = 'corhlt', x = 4224, y = 1121, z = 4448, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4080, y = 1131, z = 4208, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4048, y = 1130, z = 4208, rot = -16384 , team = 0},
			{name = 'cordrag', x = 4016, y = 1127, z = 4208, rot = -16384 , team = 0},
			{name = 'corgol', x = 3960, y = 1086, z = 3923, rot = -27407 , team = 0},
			{name = 'correap', x = 3866, y = 1098, z = 4025, rot = 20908 , team = 0},
			{name = 'corvrad', x = 3882, y = 1094, z = 3947, rot = 23521 , team = 0},
			{name = 'coreter', x = 4013, y = 1101, z = 4038, rot = 19007 , team = 0},
			{name = 'cornecro', x = 3874, y = 1119, z = 4207, rot = 24246 , team = 0},
			{name = 'cornecro', x = 3792, y = 1116, z = 4201, rot = 19920 , team = 0},
			-- {name = 'armca', x = 1567, y = 1035, z = 2520, rot = -24106 , team = 1},
			{name = 'armmex', x = 952, y = 1101, z = 1592, rot = -16384 , team = 1},
			{name = 'armmex', x = 744, y = 1104, z = 1496, rot = -16384 , team = 1},
			{name = 'armmex', x = 760, y = 1101, z = 1864, rot = -16384 , team = 1},
			{name = 'corvroc', x = 3977, y = 1108, z = 4094, rot = 26479 , team = 0},
			{name = 'armcom', x = 597, y = 1109, z = 777, rot = 25306 , team = 1},
			{name = 'armfort', x = 544, y = 1112, z = 656, rot = -16384 , team = 1},
			{name = 'armfort', x = 512, y = 1107, z = 656, rot = -16384 , team = 1},
			{name = 'armfort', x = 512, y = 1110, z = 688, rot = -16384 , team = 1},
			{name = 'armfort', x = 544, y = 1114, z = 688, rot = -16384 , team = 1},
			{name = 'armfort', x = 544, y = 1116, z = 720, rot = -16384 , team = 1},
			{name = 'armfort', x = 512, y = 1113, z = 720, rot = -16384 , team = 1},
			{name = 'armfort', x = 512, y = 1115, z = 752, rot = -16384 , team = 1},
			{name = 'armfort', x = 544, y = 1118, z = 752, rot = -16384 , team = 1},
			{name = 'armfort', x = 544, y = 1118, z = 784, rot = -16384 , team = 1},
			{name = 'armfort', x = 512, y = 1113, z = 784, rot = -16384 , team = 1},
			{name = 'armfort', x = 512, y = 1112, z = 816, rot = -16384 , team = 1},
			{name = 'armfort', x = 544, y = 1118, z = 816, rot = -16384 , team = 1},
			{name = 'armfort', x = 544, y = 1117, z = 848, rot = -16384 , team = 1},
			{name = 'armfort', x = 512, y = 1111, z = 848, rot = -16384 , team = 1},
			{name = 'armfort', x = 576, y = 1111, z = 688, rot = -16384 , team = 1},
			{name = 'armfort', x = 608, y = 1102, z = 688, rot = -16384 , team = 1},
			{name = 'armfort', x = 640, y = 1089, z = 688, rot = -16384 , team = 1},
			{name = 'armfort', x = 672, y = 1074, z = 688, rot = -16384 , team = 1},
			{name = 'armfort', x = 704, y = 1059, z = 688, rot = -16384 , team = 1},
			{name = 'armfort', x = 736, y = 1047, z = 688, rot = -16384 , team = 1},
			{name = 'armfort', x = 736, y = 1055, z = 656, rot = -16384 , team = 1},
			{name = 'armfort', x = 704, y = 1068, z = 656, rot = -16384 , team = 1},
			{name = 'armfort', x = 672, y = 1080, z = 656, rot = -16384 , team = 1},
			{name = 'armfort', x = 640, y = 1093, z = 656, rot = -16384 , team = 1},
			{name = 'armfort', x = 608, y = 1103, z = 656, rot = -16384 , team = 1},
			{name = 'armfort', x = 576, y = 1111, z = 656, rot = -16384 , team = 1},
			{name = 'armfort', x = 704, y = 1056, z = 720, rot = -16384 , team = 1},
			{name = 'armfort', x = 736, y = 1043, z = 720, rot = -16384 , team = 1},
			{name = 'armfort', x = 736, y = 1045, z = 752, rot = -16384 , team = 1},
			{name = 'armfort', x = 704, y = 1058, z = 752, rot = -16384 , team = 1},
			{name = 'armfort', x = 704, y = 1065, z = 784, rot = -16384 , team = 1},
			{name = 'armfort', x = 736, y = 1053, z = 784, rot = -16384 , team = 1},
			{name = 'armfort', x = 736, y = 1065, z = 816, rot = -16384 , team = 1},
			{name = 'armfort', x = 704, y = 1075, z = 816, rot = -16384 , team = 1},
			{name = 'armfort', x = 704, y = 1087, z = 848, rot = -16384 , team = 1},
			{name = 'armfort', x = 736, y = 1079, z = 848, rot = -16384 , team = 1},
			{name = 'armfort', x = 736, y = 1093, z = 880, rot = -16384 , team = 1},
			{name = 'armfort', x = 704, y = 1100, z = 880, rot = -16384 , team = 1},
			{name = 'armfort', x = 672, y = 1107, z = 880, rot = -16384 , team = 1},
			{name = 'armfort', x = 640, y = 1114, z = 880, rot = -16384 , team = 1},
			{name = 'armfort', x = 608, y = 1119, z = 880, rot = -16384 , team = 1},
			{name = 'armfort', x = 576, y = 1119, z = 880, rot = -16384 , team = 1},
			{name = 'armfort', x = 544, y = 1114, z = 880, rot = -16384 , team = 1},
			{name = 'armfort', x = 512, y = 1109, z = 880, rot = -16384 , team = 1},
			{name = 'armfort', x = 512, y = 1108, z = 912, rot = -16384 , team = 1},
			{name = 'armfort', x = 544, y = 1111, z = 912, rot = -16384 , team = 1},
			{name = 'armfort', x = 576, y = 1115, z = 912, rot = -16384 , team = 1},
			{name = 'armfort', x = 608, y = 1120, z = 912, rot = -16384 , team = 1},
			{name = 'armfort', x = 640, y = 1118, z = 912, rot = -16384 , team = 1},
			{name = 'armfort', x = 672, y = 1115, z = 912, rot = -16384 , team = 1},
			{name = 'armfort', x = 704, y = 1112, z = 912, rot = -16384 , team = 1},
			{name = 'armfort', x = 736, y = 1106, z = 912, rot = -16384 , team = 1},
			{name = 'armdrag', x = 480, y = 1099, z = 624, rot = -16384 , team = 1},
			{name = 'armdrag', x = 768, y = 1060, z = 624, rot = -16384 , team = 1},
			{name = 'armdrag', x = 768, y = 1114, z = 944, rot = -16384 , team = 1},
			{name = 'armdrag', x = 480, y = 1106, z = 944, rot = -16384 , team = 1},
			{name = 'armdrag', x = 464, y = 1099, z = 656, rot = -16384 , team = 1},
			{name = 'armdrag', x = 432, y = 1095, z = 656, rot = -16384 , team = 1},
			{name = 'armdrag', x = 400, y = 1092, z = 656, rot = -16384 , team = 1},
			{name = 'armdrag', x = 512, y = 1104, z = 624, rot = -16384 , team = 1},
			{name = 'armdrag', x = 512, y = 1101, z = 592, rot = -16384 , team = 1},
			{name = 'armdrag', x = 512, y = 1098, z = 560, rot = -16384 , team = 1},
			{name = 'armdrag', x = 736, y = 1066, z = 624, rot = -16384 , team = 1},
			{name = 'armdrag', x = 736, y = 1079, z = 592, rot = -16384 , team = 1},
			{name = 'armdrag', x = 736, y = 1091, z = 560, rot = -16384 , team = 1},
			{name = 'armdrag', x = 768, y = 1047, z = 656, rot = -16384 , team = 1},
			{name = 'armdrag', x = 800, y = 1044, z = 656, rot = -16384 , team = 1},
			{name = 'armdrag', x = 832, y = 1048, z = 656, rot = -16384 , team = 1},
			{name = 'armdrag', x = 512, y = 1108, z = 944, rot = -16384 , team = 1},
			{name = 'armdrag', x = 512, y = 1107, z = 976, rot = -16384 , team = 1},
			{name = 'armdrag', x = 512, y = 1107, z = 1008, rot = -16384 , team = 1},
			{name = 'armdrag', x = 480, y = 1107, z = 912, rot = -16384 , team = 1},
			{name = 'armdrag', x = 448, y = 1105, z = 912, rot = -16384 , team = 1},
			{name = 'armdrag', x = 416, y = 1102, z = 912, rot = -16384 , team = 1},
			{name = 'armdrag', x = 736, y = 1116, z = 944, rot = -16384 , team = 1},
			{name = 'armdrag', x = 736, y = 1119, z = 976, rot = -16384 , team = 1},
			{name = 'armdrag', x = 736, y = 1116, z = 1008, rot = -16384 , team = 1},
			{name = 'armdrag', x = 768, y = 1103, z = 912, rot = -16384 , team = 1},
			{name = 'armdrag', x = 800, y = 1102, z = 912, rot = -16384 , team = 1},
			{name = 'armdrag', x = 832, y = 1104, z = 912, rot = -16384 , team = 1},
			{name = 'armllt', x = 3520, y = 1103, z = 2368, rot = -16384 , team = 1},
			{name = 'armllt', x = 3728, y = 1097, z = 2336, rot = -16384 , team = 1},
			{name = 'armllt', x = 3920, y = 1092, z = 2352, rot = -16384 , team = 1},
			{name = 'armllt', x = 4144, y = 1094, z = 2400, rot = -16384 , team = 1},
			{name = 'armllt', x = 4384, y = 1090, z = 2464, rot = -16384 , team = 1},
			{name = 'armrad', x = 4224, y = 1089, z = 2112, rot = -16384 , team = 1},
			{name = 'armdrag', x = 4240, y = 1093, z = 2432, rot = -16384 , team = 1},
			{name = 'armdrag', x = 3632, y = 1099, z = 2368, rot = -16384 , team = 1},
			{name = 'armdrag', x = 3376, y = 1112, z = 2368, rot = -16384 , team = 1},
			{name = 'armferret', x = 3768, y = 1091, z = 2184, rot = -16384 , team = 1},
			{name = 'armferret', x = 4232, y = 1094, z = 2232, rot = -16384 , team = 1},
			{name = 'armferret', x = 4536, y = 1080, z = 2136, rot = -16384 , team = 1},
			{name = 'armlab', x = 976, y = 1101, z = 1760, rot = 0 , team = 1},
			{name = 'armnanotc', x = 872, y = 1100, z = 1640, rot = 0 , team = 1},
			{name = 'armnanotc', x = 824, y = 1100, z = 1640, rot = 0 , team = 1},
			{name = 'armwin', x = 584, y = 1102, z = 1512, rot = 0 , team = 1},
			{name = 'armwin', x = 520, y = 1101, z = 1512, rot = 0 , team = 1},
			{name = 'armwin', x = 456, y = 1099, z = 1512, rot = 0 , team = 1},
			{name = 'armwin', x = 456, y = 1097, z = 1576, rot = 0 , team = 1},
			{name = 'armwin', x = 520, y = 1099, z = 1576, rot = 0 , team = 1},
			{name = 'armwin', x = 584, y = 1100, z = 1576, rot = 0 , team = 1},
			{name = 'armwin', x = 584, y = 1099, z = 1640, rot = 0 , team = 1},
			{name = 'armwin', x = 520, y = 1097, z = 1640, rot = 0 , team = 1},
			{name = 'armwin', x = 456, y = 1096, z = 1640, rot = 0 , team = 1},
			{name = 'armwin', x = 456, y = 1095, z = 1704, rot = 0 , team = 1},
			{name = 'armwin', x = 520, y = 1096, z = 1704, rot = 0 , team = 1},
			{name = 'armwin', x = 584, y = 1098, z = 1704, rot = 0 , team = 1},
			{name = 'armwin', x = 584, y = 1097, z = 1768, rot = 0 , team = 1},
			{name = 'armwin', x = 520, y = 1096, z = 1768, rot = 0 , team = 1},
			{name = 'armwin', x = 456, y = 1094, z = 1768, rot = 0 , team = 1},
			{name = 'armwin', x = 456, y = 1094, z = 1832, rot = 0 , team = 1},
			{name = 'armwin', x = 520, y = 1095, z = 1832, rot = 0 , team = 1},
			{name = 'armwin', x = 584, y = 1097, z = 1832, rot = 0 , team = 1},
			{name = 'armvp', x = 856, y = 1115, z = 4240, rot = 16384 , team = 1},
			{name = 'armnanotc', x = 696, y = 1108, z = 4216, rot = 16384 , team = 1},
			{name = 'armnanotc', x = 696, y = 1107, z = 4264, rot = 16384 , team = 1},
			{name = 'armmex', x = 808, y = 1112, z = 4376, rot = 16384 , team = 1},
			{name = 'armmex', x = 1048, y = 1125, z = 4456, rot = 16384 , team = 1},
			{name = 'armmex', x = 760, y = 1112, z = 4136, rot = 16384 , team = 1},
			{name = 'armwin', x = 632, y = 1101, z = 4344, rot = 16384 , team = 1},
			{name = 'armwin', x = 568, y = 1096, z = 4344, rot = 16384 , team = 1},
			{name = 'armwin', x = 504, y = 1090, z = 4344, rot = 16384 , team = 1},
			{name = 'armwin', x = 440, y = 1084, z = 4408, rot = 16384 , team = 1},
			{name = 'armwin', x = 504, y = 1090, z = 4408, rot = 16384 , team = 1},
			{name = 'armmex', x = 2344, y = 893, z = 744, rot = 16384 , team = 1},
			{name = 'armwin', x = 568, y = 1095, z = 4408, rot = 16384 , team = 1},
			{name = 'armwin', x = 632, y = 1100, z = 4408, rot = 16384 , team = 1},
			{name = 'armwin', x = 632, y = 1098, z = 4472, rot = 16384 , team = 1},
			{name = 'armwin', x = 568, y = 1092, z = 4472, rot = 16384 , team = 1},
			{name = 'armrad', x = 2000, y = 901, z = 896, rot = 16384 , team = 1},
			{name = 'armwin', x = 504, y = 1086, z = 4472, rot = 16384 , team = 1},
			{name = 'armwin', x = 440, y = 1077, z = 4472, rot = 16384 , team = 1},
			{name = 'armllt', x = 2400, y = 895, z = 848, rot = 16384 , team = 1},
			{name = 'armwin', x = 440, y = 1074, z = 4536, rot = 16384 , team = 1},
			{name = 'armllt', x = 2368, y = 889, z = 992, rot = 16384 , team = 1},
			{name = 'armwin', x = 504, y = 1083, z = 4536, rot = 16384 , team = 1},
			{name = 'armwin', x = 568, y = 1090, z = 4536, rot = 16384 , team = 1},
			{name = 'armllt', x = 2384, y = 924, z = 1168, rot = 16384 , team = 1},
			{name = 'armwin', x = 632, y = 1095, z = 4536, rot = 16384 , team = 1},
			{name = 'armwin', x = 632, y = 1092, z = 4600, rot = 16384 , team = 1},
			{name = 'armwin', x = 568, y = 1085, z = 4600, rot = 16384 , team = 1},
			{name = 'armwin', x = 504, y = 1080, z = 4600, rot = 16384 , team = 1},
			{name = 'armwin', x = 440, y = 1073, z = 4600, rot = 16384 , team = 1},
			{name = 'armwin', x = 440, y = 1071, z = 4664, rot = 16384 , team = 1},
			{name = 'armwin', x = 504, y = 1076, z = 4664, rot = 16384 , team = 1},
			{name = 'armwin', x = 568, y = 1079, z = 4664, rot = 16384 , team = 1},
			{name = 'armwin', x = 632, y = 1085, z = 4664, rot = 16384 , team = 1},
			{name = 'armfort', x = 2704, y = 1189, z = 3696, rot = 16384 , team = 1},
			{name = 'armfort', x = 2720, y = 1154, z = 3728, rot = 16384 , team = 1},
			{name = 'armfort', x = 2752, y = 1142, z = 3760, rot = 16384 , team = 1},
			{name = 'armfort', x = 2768, y = 1145, z = 3792, rot = 16384 , team = 1},
			{name = 'armfort', x = 2800, y = 1131, z = 3824, rot = 16384 , team = 1},
			{name = 'armfort', x = 2816, y = 1110, z = 3856, rot = 16384 , team = 1},
			{name = 'armfort', x = 2848, y = 1113, z = 3888, rot = 16384 , team = 1},
			{name = 'armfort', x = 2864, y = 1101, z = 3920, rot = 16384 , team = 1},
			{name = 'armfort', x = 2896, y = 1121, z = 3952, rot = 16384 , team = 1},
			{name = 'armfort', x = 2912, y = 1130, z = 3984, rot = 16384 , team = 1},
			{name = 'armfort', x = 2928, y = 1134, z = 4016, rot = 16384 , team = 1},
			{name = 'armfort', x = 2960, y = 1167, z = 4048, rot = 16384 , team = 1},
			{name = 'armfort', x = 2976, y = 1177, z = 4080, rot = 16384 , team = 1},
			{name = 'armfort', x = 3008, y = 1165, z = 4112, rot = 16384 , team = 1},
			{name = 'armhlt', x = 2416, y = 963, z = 1296, rot = 16384 , team = 1},
			{name = 'armfort', x = 3024, y = 1163, z = 4144, rot = 16384 , team = 1},
			{name = 'armfort', x = 3056, y = 1163, z = 4176, rot = 16384 , team = 1},
			{name = 'armfort', x = 3072, y = 1164, z = 4208, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2560, y = 767, z = 880, rot = 16384 , team = 1},
			{name = 'armfort', x = 3104, y = 1188, z = 4240, rot = 16384 , team = 1},
			{name = 'armfort', x = 3120, y = 1214, z = 4272, rot = 16384 , team = 1},
			{name = 'armfort', x = 3136, y = 1221, z = 4240, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2560, y = 807, z = 1120, rot = 16384 , team = 1},
			{name = 'armfort', x = 3120, y = 1195, z = 4208, rot = 16384 , team = 1},
			{name = 'armfort', x = 3088, y = 1179, z = 4176, rot = 16384 , team = 1},
			{name = 'armfort', x = 3072, y = 1206, z = 4144, rot = 16384 , team = 1},
			{name = 'armfort', x = 3040, y = 1192, z = 4112, rot = 16384 , team = 1},
			{name = 'armfort', x = 3024, y = 1209, z = 4080, rot = 16384 , team = 1},
			{name = 'armfort', x = 2992, y = 1204, z = 4048, rot = 16384 , team = 1},
			{name = 'armfort', x = 2976, y = 1183, z = 4016, rot = 16384 , team = 1},
			{name = 'armfort', x = 2944, y = 1159, z = 3984, rot = 16384 , team = 1},
			{name = 'armfort', x = 2928, y = 1155, z = 3952, rot = 16384 , team = 1},
			{name = 'armfort', x = 2896, y = 1132, z = 3920, rot = 16384 , team = 1},
			{name = 'armwin', x = 2184, y = 917, z = 1032, rot = 16384 , team = 1},
			{name = 'armfort', x = 2880, y = 1144, z = 3888, rot = 16384 , team = 1},
			{name = 'armfort', x = 2848, y = 1143, z = 3856, rot = 16384 , team = 1},
			{name = 'armfort', x = 2832, y = 1157, z = 3824, rot = 16384 , team = 1},
			{name = 'armwin', x = 2120, y = 923, z = 1032, rot = 16384 , team = 1},
			{name = 'armfort', x = 2800, y = 1177, z = 3792, rot = 16384 , team = 1},
			{name = 'armfort', x = 2784, y = 1179, z = 3760, rot = 16384 , team = 1},
			{name = 'armwin', x = 2120, y = 935, z = 1096, rot = 16384 , team = 1},
			{name = 'armfort', x = 2752, y = 1165, z = 3728, rot = 16384 , team = 1},
			{name = 'armwin', x = 2184, y = 929, z = 1096, rot = 16384 , team = 1},
			{name = 'armfort', x = 2736, y = 1186, z = 3696, rot = 16384 , team = 1},
			{name = 'armwin', x = 2184, y = 937, z = 1160, rot = 16384 , team = 1},
			{name = 'armwin', x = 2120, y = 942, z = 1160, rot = 16384 , team = 1},
			{name = 'armwin', x = 2120, y = 955, z = 1224, rot = 16384 , team = 1},
			{name = 'armwin', x = 2184, y = 945, z = 1224, rot = 16384 , team = 1},
			{name = 'armrad', x = 1984, y = 993, z = 1360, rot = 16384 , team = 1},
			{name = 'armrad', x = 800, y = 1110, z = 4512, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2608, y = 685, z = 528, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2624, y = 692, z = 560, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2640, y = 696, z = 592, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2656, y = 694, z = 624, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2672, y = 691, z = 656, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2688, y = 686, z = 688, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2704, y = 681, z = 720, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2720, y = 675, z = 752, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2720, y = 669, z = 1264, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2704, y = 676, z = 1296, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2672, y = 685, z = 1328, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2656, y = 698, z = 1360, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2640, y = 710, z = 1392, rot = 16384 , team = 1},
			{name = 'armdrag', x = 2624, y = 716, z = 1424, rot = 16384 , team = 1},
			{name = 'armjamt', x = 784, y = 1101, z = 1760, rot = 16384 , team = 1},
			{name = 'armrad', x = 672, y = 1102, z = 1616, rot = 16384 , team = 1},
			{name = 'armrad', x = 784, y = 1102, z = 1584, rot = 16384 , team = 1},
			{name = 'armllt', x = 1184, y = 1092, z = 2880, rot = 16384 , team = 1},
			{name = 'armllt', x = 1040, y = 1089, z = 2976, rot = 16384 , team = 1},
			{name = 'armllt', x = 896, y = 1094, z = 3120, rot = 16384 , team = 1},
			{name = 'armllt', x = 816, y = 1099, z = 3248, rot = 16384 , team = 1},
			{name = 'armllt', x = 720, y = 1097, z = 3376, rot = 16384 , team = 1},
			{name = 'armllt', x = 656, y = 1102, z = 3584, rot = 16384 , team = 1},
			{name = 'armllt', x = 672, y = 1107, z = 3760, rot = 16384 , team = 1},
			{name = 'armllt', x = 720, y = 1106, z = 3872, rot = 16384 , team = 1},
			{name = 'armllt', x = 864, y = 1112, z = 4016, rot = 16384 , team = 1},
			{name = 'armllt', x = 992, y = 1117, z = 4096, rot = 16384 , team = 1},
			{name = 'armllt', x = 1152, y = 1119, z = 4208, rot = 16384 , team = 1},
			{name = 'armllt', x = 1344, y = 1120, z = 4304, rot = 16384 , team = 1},
			{name = 'armllt', x = 1456, y = 1126, z = 4320, rot = 16384 , team = 1},
			{name = 'armfort', x = 16, y = 1023, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 48, y = 1024, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 80, y = 1031, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 112, y = 1040, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 144, y = 1048, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 176, y = 1055, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 208, y = 1064, z = 1968, rot = 16384 , team = 1},
			{name = 'armhlt', x = 1088, y = 1108, z = 4160, rot = 16384 , team = 1},
			{name = 'armfort', x = 240, y = 1077, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 272, y = 1090, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 304, y = 1093, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 336, y = 1093, z = 1968, rot = 16384 , team = 1},
			{name = 'armhlt', x = 768, y = 1110, z = 3920, rot = 16384 , team = 1},
			{name = 'armfort', x = 368, y = 1094, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 400, y = 1096, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 432, y = 1099, z = 1968, rot = 16384 , team = 1},
			{name = 'armhlt', x = 672, y = 1100, z = 3440, rot = 16384 , team = 1},
			{name = 'armfort', x = 464, y = 1099, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 496, y = 1100, z = 1968, rot = 16384 , team = 1},
			{name = 'armhlt', x = 848, y = 1097, z = 3152, rot = 16384 , team = 1},
			{name = 'armfort', x = 528, y = 1099, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 560, y = 1099, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 592, y = 1099, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 592, y = 1100, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 560, y = 1100, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 528, y = 1100, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 496, y = 1100, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 464, y = 1099, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 432, y = 1099, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 400, y = 1098, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 368, y = 1094, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 336, y = 1092, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 304, y = 1088, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 272, y = 1085, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 240, y = 1084, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 208, y = 1063, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 176, y = 1055, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 144, y = 1046, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 112, y = 1036, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 80, y = 1026, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 48, y = 1019, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 16, y = 1019, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1088, y = 1098, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1120, y = 1099, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1152, y = 1099, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1184, y = 1099, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1216, y = 1097, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1248, y = 1097, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1280, y = 1097, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1312, y = 1096, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1344, y = 1094, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1376, y = 1093, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1408, y = 1091, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1440, y = 1090, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1472, y = 1088, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1504, y = 1086, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1536, y = 1085, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1568, y = 1083, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1600, y = 1081, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1632, y = 1081, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1664, y = 1080, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1696, y = 1081, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1728, y = 1083, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1760, y = 1086, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1792, y = 1090, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1824, y = 1094, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1856, y = 1100, z = 1968, rot = 16384 , team = 1},
			{name = 'armfort', x = 1856, y = 1105, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1824, y = 1096, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1792, y = 1088, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1760, y = 1084, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1728, y = 1082, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1696, y = 1079, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1664, y = 1078, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1632, y = 1078, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1600, y = 1078, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1568, y = 1080, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1536, y = 1082, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1504, y = 1084, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1472, y = 1085, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1440, y = 1087, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1408, y = 1089, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1376, y = 1091, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1344, y = 1092, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1312, y = 1094, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1280, y = 1095, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1248, y = 1096, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1216, y = 1096, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1184, y = 1098, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1152, y = 1098, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1120, y = 1098, z = 2000, rot = 16384 , team = 1},
			{name = 'armfort', x = 1088, y = 1097, z = 2000, rot = 16384 , team = 1},
			{name = 'armpb', x = 712, y = 1102, z = 1992, rot = 16384 , team = 1},
			{name = 'armpb', x = 968, y = 1099, z = 1992, rot = 16384 , team = 1},
			{name = 'armflak', x = 1232, y = 1103, z = 1520, rot = 16384 , team = 1},
			{name = 'armflak', x = 1264, y = 1105, z = 1776, rot = 16384 , team = 1},
			{name = 'armflak', x = 368, y = 1092, z = 1840, rot = 16384 , team = 1},
			{name = 'armflak', x = 1216, y = 1088, z = 1168, rot = 16384 , team = 1},
			{name = 'armpb', x = 552, y = 1109, z = 952, rot = 16384 , team = 1},
			{name = 'armpb', x = 696, y = 1119, z = 952, rot = 16384 , team = 1},
			{name = 'corspy', x = 3807, y = 1113, z = 4143, rot = 20165 , team = 0},
			{name = 'corspy', x = 3891, y = 1108, z = 4123, rot = 17985 , team = 0},
			{name = 'corspy', x = 3924, y = 1098, z = 4045, rot = 17072 , team = 0},
			{name = 'armllt', x = 4800, y = 996, z = 2448, rot = 16384 , team = 1},
			{name = 'armllt', x = 4608, y = 1069, z = 2464, rot = 16384 , team = 1},
			{name = 'armgeo', x = 1488, y = 1048, z = 2448, rot = 16384 , team = 1},
					
		},
			
		featureloadout = {
			{name = 'armrectr_dead', x = 5000, y = 815, z = 2444, rot = 0 , scale = 1.0, resurrectas = "armrectr"},
			{name = 'armflea_dead', x = 4982, y = 834, z = 2413, rot = 0 , scale = 1.0, resurrectas = "armflea"},
			{name = 'armpb_dead', x = 4133, y = 1013, z = 1214, rot = 0 , scale = 1.0, resurrectas = "armpb"},
			{name = 'armflea_dead', x = 4925, y = 902, z = 2418, rot = 0 , scale = 1.0, resurrectas = "armflea"},
			{name = 'armflea_dead', x = 4914, y = 910, z = 2491, rot = 0 , scale = 1.0, resurrectas = "armflea"},
			{name = 'armrectr_dead', x = 5042, y = 631, z = 183, rot = 0 , scale = 1.0, resurrectas = "armrectr"},
			{name = 'armrectr_dead', x = 4948, y = 650, z = 194, rot = 0 , scale = 1.0, resurrectas = "armrectr"},
			{name = 'armrad_dead', x = 4257, y = 1066, z = 1710, rot = 0 , scale = 1.0, resurrectas = "armrad"},
			{name = 'armpb_dead', x = 3744, y = 994, z = 1784, rot = 0 , scale = 1.0, resurrectas = "armpb"},
			{name = 'corgeo_dead', x = 2767, y = 1156, z = 3027, rot = 0 , scale = 1.0, resurrectas = "corgeo"},
			{name = 'armmlv_dead', x = 426, y = 1079, z = 2926, rot = 0 , scale = 1.0, resurrectas = "armmlv"},
			{name = 'armpb_dead', x = 4015, y = 1013, z = 1560, rot = 0 , scale = 1.0, resurrectas = "armpb"},
		}
    },
    -- https://github.com/spring/spring/blob/105.0/doc/StartScriptFormat.txt
	startscript		= [[
[Game]
{
	[allyTeam0]
	{
		startrectright = 0.89298892;
		startrectbottom = 0.83025831;
		startrectleft = 0.74169737;
		numallies = 0;
		startrecttop = 0.68634689;
	}

	[team1]
	{
		Side = Armada;
		Handicap = __ENEMYHANDICAP__;
		RgbColor = 0.0 0.3 0.8;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[team0]
	{
		Side = __PLAYERSIDE__;
        Handicap = __PLAYERHANDICAP__;
		RgbColor = 1.0 0.1 0.0;
		AllyTeam = 0;
		TeamLeader = 0;
	}

	[modoptions]
	{
		scenariooptions = __SCENARIOOPTIONS__;
		startenergy = 7000;
	}


	[allyTeam1]
	{
		startrectright = 0.25461257;
		startrectbottom = 0.34317344;
		startrectleft = 0.08487085;
		numallies = 0;
		startrecttop = 0.14760149;
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
