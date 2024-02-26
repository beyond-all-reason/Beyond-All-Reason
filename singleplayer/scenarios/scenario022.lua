local scenariodata = {
	index			= 22, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "Begin06", -- no spaces, lowercase, this will be used to save the score and can be used gadget side
    version         = "1", -- increment this to reset the score when changing a mission, as scores are keyed by (scenarioid,version,difficulty)
	title			= "Supremacy", -- can be anything
	author			= "wilkubyk", -- your name here
	isnew = true,
	imagepath		= "scenario022.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "River Assault", -- This text will be drawn over image
    summary         = [[After a ferocious battle, Cortex Commander decided to join Armada forces. Unfortunately, other Cortex commanders discovered the intent of the treacherous plan and sent a mighty force to prevent it.]],
	briefing 		= [[You will start with some Lazarus (Resurrection and Repair Bots), that can resurrect units from their wrecks. Your Only hope is to hide your position and build mighty army to crush all opposing forces.
       
	!!! DO NOT UNDERESTIMATE YOUR ENEMY !!!
      
  While you will be fighting for life , don't forget to fortify your Ally too, since WE can't lose Cortex Command Tower. 
  
Reinforcements:
 - You and Your Ally will receive first contingency around 9th minute from the begin of mission 
 - Enemy will be getting Reinforcements every 8 and 20 minutes 
    
Tips:
 - Sharing is Caring! When you share limited units & buildings with your Ally this will strengthens economy and combat capabilities of both.
 - To gain access of your Ally units, build Decoy Commander and capture one of your Ally Constructor unit. 
 - Use Radar Jamming units to hide your presence from enemy Radar.
 - Resurrection bots will use Energy to resurrect units, at a flat cost of 75e per second while resurrecting.
 - You can issue Area-Resurrect and Area-Reclaim commands by right-click dragging
 - Repairing units does not cost any resources.
     
Scoring:
 - Time taken to finish the scenario
 - Resources spent to complete victory condition.
     
											     IMPORTANT CHANGE!!
	Beginner: Your Resources = +50%, Enemy Resources = -20%
	Novice:   Your Resources  = +25%, Enemy Resources= -10%
	Normal:   Your Resources   = 0,       Enemy Resources= 0
	Hard:     Your Resources   = -10%,  Enemy Resources= +25%
	Brutal:   Your Resources    = -20%,  Enemy Resources= +50%
]],

	mapfilename		= "Lake Carne v2", -- the name of the map to be displayed here, and which to play on, no .smf ending needed
	playerstartx	= "16%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "26%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 5400, -- par time in seconds (time a mission is expected to take on average)
	parresources	= 1500000, -- par resource amount (amount of metal one is expected to spend on mission)
	difficulty		= 10, -- Percieved difficulty at 'normal' level: integer 1-10
    defaultdifficulty = "Normal", -- an entry of the difficulty table
    difficulties    = { -- Array for sortedness, Keys are text that appears in selector (as well as in scoring!), values are handicap levels
    -- handicap values range [-100 - +100], with 0 being regular resources
    -- Currently difficulty modifier only affects the resource bonuses
         {name = "Beginner", playerhandicap = 50, enemyhandicap=-20},
         {name = "Novice"  , playerhandicap = 25, enemyhandicap=-10},
         {name = "Normal"  , playerhandicap = 0, enemyhandicap=0},
         {name = "Hard"    , playerhandicap = -10,  enemyhandicap=25},
         {name = "Brutal" , playerhandicap = -20,  enemyhandicap=50},
    },
    allowedsides     = {"Armada"}, --these are the permitted factions for this mission, choose from {"Armada", "Cortex", "Random"}
	victorycondition= "Kill all enemy builders", -- This is plaintext, but should be reflected in startscript
	losscondition	= "All builders or AI Command Tower",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberofthese units, 0 means disable it
        -- dont use the one in startscript, put the disabled stuff here so we can show it in scenario window!
        cortex_calamity = 0,
		cortex_basilisk = 0,
		cortex_advancedfusionreactor = 1,
		cortex_advancedenergyconverter = 6,
		cortex_apocalypse = 1,
		cortex_overseer = 10,
		cortex_catalyst = 2,
		cortex_screamer = 0,
		corsok = 0,
		armada_ragnarok = 0,
		armada_basilica = 0,
		armada_advancedfusionreactor = 1,
		armada_advancedenergyconverter = 6,
		armada_armageddon = 1,
		armada_keeper = 10,
		armada_mercury = 0,
		armada_paralyzer = 1,
		armada_lunkhead = 0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff", -- blank
        scenarioid = "Begin06", -- this MUST be present and identical to the one defined at start
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

			--{name = 'cortex_commander', x = 5444, y = 34, z = 4403, rot = 0 , team = 1},
			--{name = 'armada_commander', x = 700, y = 34, z = 716, rot = 0 , team = 0},
			{name = 'armada_solarcollector', x = 1112, y = 99, z = 1224, rot = -16384 , team = 0},
			{name = 'armada_solarcollector', x = 1272, y = 93, z = 1224, rot = -16384 , team = 0},
			{name = 'armada_solarcollector', x = 1350, y = 34, z = 218, rot = -16384 , team = 0},
			{name = 'armada_solarcollector', x = 1272, y = 34, z = 206, rot = -16384 , team = 0},
			{name = 'armada_lazarus', x = 1176, y = 100, z = 1414, rot = 12977 , team = 0},
			{name = 'armada_lazarus', x = 716, y = 34, z = 1290, rot = 12977 , team = 0},
			{name = 'armada_lazarus', x = 1265, y = 34, z = 898, rot = 12977 , team = 0},
			{name = 'armada_energyconverter', x = 1192, y = 95, z = 1224, rot = -16384 , team = 0},
			{name = "armada_dragonsteeth", x = 1856, y = 34, z = 240, rot = -16384 , team = 0},
			{name = "armada_dragonsteeth", x = 1296, y = 34, z = 16, rot = -16384 , team = 0},
			{name = "armada_dragonsteeth", x = 1312, y = 34, z = 64, rot = -16384 , team = 0},
			{name = "armada_dragonsteeth", x = 1328, y = 34, z = 112, rot = -16384 , team = 0},
			{name = "armada_dragonsteeth", x = 1344, y = 34, z = 160, rot = -16384 , team = 0},
			{name = "armada_dragonsteeth", x = 1392, y = 34, z = 176, rot = -16384 , team = 0},
			{name = "armada_dragonsteeth", x = 1408, y = 34, z = 224, rot = -16384 , team = 0},
			{name = "armada_dragonsteeth", x = 1840, y = 34, z = 16, rot = -16384 , team = 0},
			{name = "armada_dragonsteeth", x = 1856, y = 33, z = 64, rot = -16384 , team = 0},
			{name = "armada_dragonsteeth", x = 1840, y = 55, z = 128, rot = -16384 , team = 0},
			{name = "armada_dragonsteeth", x = 1856, y = 33, z = 176, rot = -16384 , team = 0},
			{name = 'cortex_advancedsolarcollector', x = 5120, y = 102, z = 4096, rot = -16384 , team = 1},
			{name = 'cortex_advancedsolarcollector', x = 5016, y = 100, z = 4097, rot = -16384 , team = 1},
			{name = 'cortex_energyconverter', x = 5320, y = 35, z = 4152, rot = -16384 , team = 1},
			{name = 'cortex_castro', x = 5136, y = 96, z = 4224, rot = -16384 , team = 1},
			{name = 'cortex_graverobber', x = 5281, y = 34, z = 4394, rot = -7263 , team = 1},
			{name = 'cortex_graverobber', x = 5915, y = 34, z = 4963, rot = -7263 , team = 1},
			{name = 'cortex_graverobber', x = 5707, y = 34, z = 4966, rot = -7263 , team = 1},
			{name = 'cortex_graverobber', x = 5427, y = 34, z = 4976, rot = -7263 , team = 1},
			{name = 'cortex_graverobber', x = 5968, y = 34, z = 4752, rot = -7263 , team = 1},
			{name = 'cortex_radarsonartower', x = 1160, y = -4, z = 4024, rot = 32767 , team = 3},
			{name = 'cortex_radarsonartower', x = 2696, y = -4, z = 3064, rot = 32767 , team = 3},
			{name = 'cortex_radarsonartower', x = 3416, y = -4, z = 2024, rot = 32767 , team = 2},
			{name = 'cortex_radarsonartower', x = 4776, y = -4, z = 1080, rot = 32767 , team = 2},
			{name = 'cortex_oasis2', x = 5164, y = -8, z = 615, rot = 10868 , team = 2},
			{name = 'cortex_oasis2', x = 846, y = -8, z = 4430, rot = -27437 , team = 3},
			{name = 'correcl', x = 176, y = -80, z = 4786, rot = 9073 , team = 3},
			{name = 'corblackhy', x = 650, y = 0, z = 4602, rot = -23614 , team = 3},
			{name = 'correcl', x = 5397, y = -80, z = 331, rot = -18068 , team = 2},
			{name = 'corblackhy', x = 5369, y = 0, z = 489, rot = -26161 , team = 2},
			{name = 'cortex_hardenedmetalstorage', x = 5216, y = -104, z = 160, rot = -16384 , team = 2},
			{name = 'cortex_hardenedenergystorage', x = 5224, y = -104, z = 232, rot = -16384 , team = 2},
			{name = 'cortex_navalfusionreactor', x = 5144, y = -104, z = 200, rot = -16384 , team = 2},
			{name = 'cortex_navalfusionreactor', x = 5304, y = -104, z = 184, rot = -16384 , team = 2},
			{name = 'cortex_navalfusionreactor', x = 5224, y = -104, z = 88, rot = -16384 , team = 2},
			{name = 'cortex_navalfusionreactor', x = 5224, y = -104, z = 312, rot = -16384 , team = 2},
			{name = 'cortex_navalbirdshot', x = 5088, y = 0, z = 720, rot = -16384 , team = 2},
			{name = 'cortex_advancedsonarstation', x = 5256, y = -104, z = 440, rot = -16384 , team = 2},
			{name = 'cortex_navalbirdshot', x = 5488, y = 0, z = 720, rot = -16384 , team = 2},
			{name = 'cortex_navalbirdshot', x = 4944, y = 0, z = 400, rot = -16384 , team = 2},
			{name = 'cortex_navalbirdshot', x = 5456, y = 0, z = 272, rot = -16384 , team = 2},
			{name = 'cortex_lamprey', x = 5320, y = -2, z = 616, rot = -16384 , team = 2},
			{name = 'cortex_lamprey', x = 5192, y = -2, z = 504, rot = -16384 , team = 2},
			{name = 'cortex_lamprey', x = 5560, y = -2, z = 744, rot = -16384 , team = 2},
			{name = 'cortex_lamprey', x = 5032, y = -2, z = 792, rot = -16384 , team = 2},
			{name = 'cortex_lamprey', x = 4872, y = -2, z = 408, rot = -16384 , team = 2},
			{name = 'cortex_devastator', x = 4800, y = -3, z = 432, rot = -16384 , team = 2},
			{name = 'cortex_devastator', x = 4976, y = -3, z = 880, rot = -16384 , team = 2},
			{name = 'cortex_devastator', x = 5552, y = -3, z = 848, rot = -16384 , team = 2},
			{name = 'corsjam', x = 5314, y = 0, z = 251, rot = 20439 , team = 2},
			{name = 'corsjam', x = 5580, y = 0, z = 303, rot = 1649 , team = 2},
			{name = 'cortex_lamprey', x = 5256, y = -2, z = 856, rot = -16384 , team = 2},
			{name = 'cortex_lamprey', x = 4904, y = -2, z = 664, rot = -16384 , team = 2},
			{name = 'cortex_navalpinpointer', x = 5344, y = -3, z = 32, rot = -16384 , team = 2},
			{name = 'cortex_navalpinpointer', x = 5408, y = -3, z = 32, rot = -16384 , team = 2},
			{name = 'cortex_navalpinpointer', x = 5408, y = -3, z = 160, rot = -16384 , team = 2},
			{name = 'cortex_lamprey', x = 5752, y = -2, z = 632, rot = -16384 , team = 2},
			{name = 'cortex_lamprey', x = 4856, y = -2, z = 296, rot = -16384 , team = 2},
			{name = 'correcl', x = 593, y = -80, z = 4691, rot = -8019 , team = 3},
			{name = 'cortex_sharksteeth', x = 4800, y = -3, z = 16, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4800, y = -3, z = 48, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4784, y = -3, z = 80, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4784, y = -3, z = 112, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4768, y = -3, z = 144, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4768, y = -3, z = 176, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4752, y = -3, z = 208, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4752, y = -3, z = 240, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4752, y = -3, z = 272, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4736, y = -3, z = 304, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4736, y = -3, z = 336, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4720, y = -3, z = 368, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4720, y = -3, z = 400, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4704, y = -3, z = 432, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4704, y = -3, z = 464, rot = -16384 , team = 2},
			{name = 'corarch', x = 5086, y = 0, z = 93, rot = 0 , team = 2},
			{name = 'corarch', x = 5684, y = 0, z = 555, rot = 0 , team = 2},
			{name = 'corarch', x = 5052, y = 0, z = 395, rot = 0 , team = 2},
			{name = 'corarch', x = 5398, y = 0, z = 665, rot = -15506 , team = 2},
			{name = 'cortex_sharksteeth', x = 4720, y = -3, z = 496, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4736, y = -3, z = 528, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4752, y = -3, z = 560, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4768, y = -3, z = 592, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4784, y = -3, z = 624, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4816, y = -3, z = 640, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4848, y = -3, z = 656, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4848, y = -3, z = 688, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4864, y = -3, z = 720, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4880, y = -3, z = 752, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4896, y = -3, z = 784, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4896, y = -3, z = 816, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4896, y = -3, z = 848, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4896, y = -3, z = 880, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4896, y = -3, z = 912, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4896, y = -3, z = 944, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4928, y = -3, z = 960, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4960, y = -3, z = 960, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 4992, y = -3, z = 960, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5024, y = -3, z = 960, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5056, y = -3, z = 944, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5088, y = -3, z = 928, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5120, y = -3, z = 912, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5152, y = -3, z = 912, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5184, y = -3, z = 896, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5216, y = -3, z = 896, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5248, y = -3, z = 912, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5280, y = -3, z = 912, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5312, y = -3, z = 928, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5344, y = -3, z = 944, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5376, y = -3, z = 944, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5408, y = -3, z = 944, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5440, y = -3, z = 944, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5472, y = -3, z = 944, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5504, y = -3, z = 944, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5536, y = -3, z = 944, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5568, y = -3, z = 944, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5600, y = -3, z = 944, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5632, y = -3, z = 944, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5648, y = -3, z = 912, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5680, y = -3, z = 896, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5712, y = -3, z = 880, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5728, y = -3, z = 848, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5744, y = -3, z = 816, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5760, y = -3, z = 784, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5776, y = -3, z = 752, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5792, y = -3, z = 720, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5808, y = -3, z = 688, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5840, y = -3, z = 688, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5872, y = -3, z = 688, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5904, y = -3, z = 672, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5936, y = -3, z = 672, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 5968, y = -3, z = 672, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 6000, y = -3, z = 672, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 6128, y = -3, z = 656, rot = -16384 , team = 2},
			{name = 'cortex_sharksteeth', x = 6096, y = -3, z = 656, rot = 0 , team = 2},
			{name = 'cortex_sharksteeth', x = 6064, y = -3, z = 656, rot = 0 , team = 2},
			{name = 'cortex_sharksteeth', x = 6032, y = -3, z = 656, rot = 0 , team = 2},
			{name = 'correcl', x = 5520, y = -45, z = 210, rot = -27465 , team = 2},
			{name = 'cortex_hardenedenergystorage', x = 344, y = -104, z = 4792, rot = 0 , team = 3},
			{name = 'cortex_hardenedmetalstorage', x = 352, y = -104, z = 4720, rot = 0 , team = 3},
			{name = 'cortex_navalfusionreactor', x = 344, y = -104, z = 4872, rot = 0 , team = 3},
			{name = 'cortex_navalfusionreactor', x = 424, y = -104, z = 4760, rot = 0 , team = 3},
			{name = 'cortex_navalfusionreactor', x = 264, y = -104, z = 4760, rot = 0 , team = 3},
			{name = 'cortex_navalfusionreactor', x = 344, y = -104, z = 4648, rot = 0 , team = 3},
			{name = 'cortex_lamprey', x = 792, y = -2, z = 4552, rot = 32767 , team = 3},
			{name = 'cortex_lamprey', x = 680, y = -2, z = 4440, rot = 32767 , team = 3},
			{name = 'cortex_advancedsonarstation', x = 568, y = -104, z = 4472, rot = 32767 , team = 3},
			{name = 'cortex_navalpinpointer', x = 48, y = -3, z = 4768, rot = 32767 , team = 3},
			{name = 'cortex_navalpinpointer', x = 48, y = -3, z = 4832, rot = 32767 , team = 3},
			{name = 'cortex_navalpinpointer', x = 48, y = -3, z = 4896, rot = 32767 , team = 3},
			{name = 'cortex_navalbirdshot', x = 416, y = 0, z = 4688, rot = 32767 , team = 3},
			{name = 'cortex_lamprey', x = 904, y = -2, z = 4952, rot = 32767 , team = 3},
			{name = 'cortex_lamprey', x = 1064, y = -2, z = 4776, rot = 32767 , team = 3},
			{name = 'cortex_lamprey', x = 1096, y = -2, z = 4408, rot = 32767 , team = 3},
			{name = 'cortex_lamprey', x = 968, y = -2, z = 4280, rot = 32767 , team = 3},
			{name = 'cortex_lamprey', x = 728, y = -2, z = 4184, rot = 32767 , team = 3},
			{name = 'cortex_lamprey', x = 440, y = -2, z = 4184, rot = 32767 , team = 3},
			{name = 'cortex_lamprey', x = 200, y = -2, z = 4216, rot = 32767 , team = 3},
			{name = 'cortex_devastator', x = 432, y = -3, z = 4112, rot = 32767 , team = 3},
			{name = 'cortex_devastator', x = 736, y = -3, z = 4112, rot = 32767 , team = 3},
			{name = 'cortex_devastator', x = 1040, y = -3, z = 4256, rot = 32767 , team = 3},
			{name = 'cortex_devastator', x = 1168, y = -3, z = 4416, rot = 32767 , team = 3},
			{name = 'cortex_devastator', x = 1136, y = -3, z = 4768, rot = 32767 , team = 3},
			{name = 'cortex_navalbirdshot', x = 960, y = 0, z = 4800, rot = 32767 , team = 3},
			{name = 'cortex_navalbirdshot', x = 1024, y = 0, z = 4464, rot = 32767 , team = 3},
			{name = 'cortex_navalbirdshot', x = 720, y = 0, z = 4256, rot = 32767 , team = 3},
			{name = 'cortex_navalbirdshot', x = 416, y = 0, z = 4272, rot = 32767 , team = 3},
			{name = 'cortex_navalbirdshot', x = 272, y = 0, z = 4832, rot = 32767 , team = 3},
			{name = 'corarch', x = 497, y = 0, z = 4870, rot = 0 , team = 3},
			{name = 'corarch', x = 227, y = 0, z = 4636, rot = 0 , team = 3},
			{name = 'corarch', x = 433, y = 0, z = 4377, rot = 0 , team = 3},
			{name = 'corarch', x = 880, y = 0, z = 4681, rot = 0 , team = 3},
			{name = 'corsjam', x = 587, y = 0, z = 4850, rot = -2450 , team = 3},
			{name = 'corsjam', x = 375, y = 0, z = 4572, rot = 20759 , team = 3},
			{name = 'cortex_sharksteeth', x = 16, y = -3, z = 4144, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 48, y = -3, z = 4144, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 80, y = -3, z = 4128, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 112, y = -3, z = 4128, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 144, y = -3, z = 4128, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 176, y = -3, z = 4128, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 208, y = -3, z = 4112, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 240, y = -3, z = 4112, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 272, y = -3, z = 4112, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 304, y = -3, z = 4096, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 336, y = -3, z = 4096, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 336, y = -3, z = 4064, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 352, y = -3, z = 4032, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 384, y = -3, z = 4032, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 416, y = -3, z = 4032, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 448, y = -3, z = 4032, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 480, y = -3, z = 4032, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 512, y = -3, z = 4032, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 512, y = -3, z = 4064, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 544, y = -3, z = 4096, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 560, y = -3, z = 4128, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 592, y = -3, z = 4128, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 608, y = -3, z = 4096, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 640, y = -3, z = 4080, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 672, y = -3, z = 4064, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 688, y = -3, z = 4032, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 720, y = -3, z = 4032, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 752, y = -3, z = 4032, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 784, y = -3, z = 4032, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 816, y = -3, z = 4032, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 832, y = -3, z = 4064, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 848, y = -3, z = 4096, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 880, y = -3, z = 4112, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 912, y = -3, z = 4112, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 944, y = -3, z = 4112, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 976, y = -3, z = 4112, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1008, y = -3, z = 4112, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1008, y = -3, z = 4144, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1008, y = -3, z = 4176, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1040, y = -3, z = 4176, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1072, y = -3, z = 4176, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1104, y = -3, z = 4192, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1120, y = -3, z = 4224, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1136, y = -3, z = 4256, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1152, y = -3, z = 4288, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1184, y = -3, z = 4304, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1216, y = -3, z = 4320, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1248, y = -3, z = 4336, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1248, y = -3, z = 4368, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1248, y = -3, z = 4400, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1248, y = -3, z = 4432, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1248, y = -3, z = 4464, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1248, y = -3, z = 4496, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1216, y = -3, z = 4512, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1200, y = -3, z = 4544, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1184, y = -3, z = 4576, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1184, y = -3, z = 4608, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1184, y = -3, z = 4640, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1184, y = -3, z = 4672, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1184, y = -3, z = 4704, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1216, y = -3, z = 4720, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1216, y = -3, z = 4752, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1216, y = -3, z = 4784, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1216, y = -3, z = 4816, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1248, y = -3, z = 4832, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1280, y = -3, z = 4864, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1296, y = -3, z = 4896, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1216, y = -3, z = 4848, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1184, y = -3, z = 4864, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1152, y = -3, z = 4880, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1120, y = -3, z = 4896, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1088, y = -3, z = 4912, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1056, y = -3, z = 4928, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1024, y = -3, z = 4944, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1008, y = -3, z = 4976, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 992, y = -3, z = 5008, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 960, y = -3, z = 5040, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 944, y = -3, z = 5072, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 944, y = -3, z = 5104, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1296, y = -3, z = 4928, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1296, y = -3, z = 4960, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1296, y = -3, z = 4992, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1296, y = -3, z = 5024, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1296, y = -3, z = 5056, rot = 32767 , team = 3},
			{name = 'cortex_sharksteeth', x = 1296, y = -3, z = 5088, rot = 32767 , team = 3},
			{name = 'cortex_lamprey', x = 1080, y = -2, z = 4984, rot = 32767 , team = 3},
			{name = "cortex_navaladvancedmetalextractor", x = 4880, y = -105, z = 176, rot = 0, team = 4},
			{name = "cortex_oasis", x = 5559, y = -8, z = 458, rot = 0, team = 4},
			{name = "cortex_oasis", x = 4251, y = -8, z = 1666, rot = -16384, team = 4},
			{name = "correcl", x = 6077, y = -81, z = 228, rot = 0, team = 4},
			{name = "corsjam", x = 5470, y = 0, z = 348, rot = 0, team = 4},
			{name = 'cortex_navalfusionreactor', x = 4939, y = -105, z = 115, rot = -16384 , team = 4},
			{name = 'cortex_navaladvancedenergyconverter', x = 4644, y = 0, z = 1202, rot = -16384 , team = 4},
			{name = "cortex_navaladvancedmetalextractor", x = 1248, y = -105, z = 4928, rot = 0, team = 5},
			{name = "corsjam", x = 429, y = 0, z = 4593, rot = 0, team = 5},
			{name = "correcl", x = 240, y = -80, z = 5062, rot = 0, team = 5},
			{name = "cortex_oasis", x = 539, y = -8, z = 4764, rot = -16384, team = 5},
			{name = "cortex_oasis", x = 1875, y = -8, z = 3398, rot = -16384, team = 5},
			{name = 'cortex_navalfusionreactor', x = 1143, y = -105, z = 5090, rot = -16384 , team = 5},
			{name = 'cortex_navaladvancedenergyconverter', x = 1467, y = 0, z = 3799, rot = -16384 , team = 5},
		},
		featureloadout = {
			-- Similarly to units, but these can also be resurrectable!
            -- You can /give cortex_commander_dead with cheats when making your scenario, but it might not contain the 'resurrectas' tag, so be careful to add it if needed
			 -- {name = 'cortex_commander_dead', x = 1125,y = 237, z = 734, rot = "0" , scale = 1.0, resurrectas = "cortex_commander"}, -- there is no need for this dead comm here, just an example
			{name = 'armada_lazarus_dead', x = 114, y = 34, z = 149, rot = 0 , scale = 1.0, resurrectas = "armada_lazarus"},
			{name = 'armada_sneakypete_dead', x = 1424, y = 34, z = 631, rot = 0 , scale = 1.0, resurrectas = "armada_sneakypete"},
			{name = 'armada_advancedsolarcollector_dead', x = 58, y = 34, z = 947, rot = 0 , scale = 1.0, resurrectas = "armada_advancedsolarcollector"},
			{name = 'armada_advancedsolarcollector_dead', x = 929, y = 34, z = 81, rot = 0 , scale = 1.0, resurrectas = "armada_advancedsolarcollector"},
			{name = 'armada_sneakypete_dead', x = 531, y = 34, z = 1265, rot = 0 , scale = 1.0, resurrectas = "armada_sneakypete"},
			{name = 'armada_constructionbot_dead', x = 1027, y = 101, z = 1053, rot = 0 , scale = 1.0, resurrectas = "armada_constructionbot"},
			{name = 'armada_lazarus_dead', x = 1917, y = 34, z = 175, rot = 0 , scale = 1.0, resurrectas = "armada_lazarus"},
			{name = 'armada_sneakypete_dead', x = 733, y = 34, z = 575, rot = 0 , scale = 1.0, resurrectas = "armada_sneakypete"},
			{name = 'armada_sneakypete_dead', x = 1972, y = 34, z = 903, rot = 0 , scale = 1.0, resurrectas = "armada_sneakypete"},
			{name = 'armada_sneakypete_dead', x = 530, y = 34, z = 1747, rot = 0 , scale = 1.0, resurrectas = "armada_sneakypete"},
			{name = 'armada_lazarus_dead', x = 91, y = 34, z = 1687, rot = 0 , scale = 1.0, resurrectas = "armada_lazarus"},
			{name = "armada_keeper_dead", x = 384, y = 34, z = 1456, rot = 0, scale = 1.0, resurrectas = "armada_keeper"},
			{name = "armada_advancedsolarcollector_dead", x = 64, y = 34, z = 688, rot = 0, scale = 1.0, resurrectas = "armada_advancedsolarcollector"},
			{name = "armada_advancedsolarcollector_dead", x = 192, y = 34, z = 464, rot = 0, scale = 1.0, resurrectas = "armada_advancedsolarcollector"},
			{name = "armada_advancedsolarcollector_dead", x = 656, y = 34, z = 448, rot = 0, scale = 1.0, resurrectas = "armada_advancedsolarcollector"},
			{name = "armada_advancedsolarcollector_dead", x = 640, y = 34, z = 96, rot = 0, scale = 1.0, resurrectas = "armada_advancedsolarcollector"},
			{name = "armada_advancedsolarcollector_dead", x = 272, y = 34, z = 208, rot = 0, scale = 1.0, resurrectas = "armada_advancedsolarcollector"},
			{name = "armada_advancedsolarcollector_dead", x = 637, y = 34, z = 268, rot = 0, scale = 1.0, resurrectas = "armada_advancedsolarcollector"},
			{name = "armada_advancedsolarcollector_dead", x = 912, y = 34, z = 268, rot = 0, scale = 1.0, resurrectas = "armada_advancedsolarcollector"},
			{name = "armada_advancedsolarcollector_dead", x = 416, y = 34, z = 96, rot = 0, scale = 1.0, resurrectas = "armada_advancedsolarcollector"},
			{name = "armada_cloakablefusionreactor_dead", x = 48, y = 34, z = 46, rot = 0, scale = 1.0, resurrectas = "armada_cloakablefusionreactor"},
			{name = "armada_beamer_dead", x = 272, y = 34, z = 1584, rot = 0, scale = 1.0, resurrectas = "armada_beamer"},
			{name = "armada_beamer_dead", x = 608, y = 34, z = 1584, rot = 0, scale = 1.0, resurrectas = "armada_beamer"},
			{name = "armada_beamer_dead", x = 1376, y = 34, z = 832, rot = 0, scale = 1.0, resurrectas = "armada_beamer"},
			{name = "armada_beamer_dead", x = 1696, y = 34, z = 528, rot = 0, scale = 1.0, resurrectas = "armada_beamer"},
			{name = "armada_pitbull_dead", x = 1556, y = 34, z = 695, rot = 0, scale = 1.0, resurrectas = "armada_pitbull"},
			{name = "armada_pitbull_dead", x = 414, y = 34, z = 1631, rot = 0, scale = 1.0, resurrectas = "armada_pitbull"},
			{name = "armada_keeper_dead", x = 432, y = 34, z = 304, rot = 0, scale = 1.0, resurrectas = "armada_keeper"},
			{name = "armada_keeper_dead", x = 1168, y = 34, z = 528, rot = 0, scale = 1.0, resurrectas = "armada_keeper"},
			{name = 'cortex_advancedsolarcollector_dead', x = 6088, y = 34, z = 5068, rot = 0 , scale = 1.0, resurrectas = "cortex_advancedsolarcollector"},
			{name = 'cortex_advancedsolarcollector_dead', x = 5740, y = 34, z = 5081, rot = 0 , scale = 1.0, resurrectas = "cortex_advancedsolarcollector"},
			{name = 'cortex_advancedsolarcollector_dead', x = 5533, y = 34, z = 5086, rot = 0 , scale = 1.0, resurrectas = "cortex_advancedsolarcollector"},
			{name = 'cortex_graverobber_dead', x = 5567, y = 34, z = 4905, rot = 0 , scale = 1.0, resurrectas = "cortex_graverobber"},
			{name = 'cortex_advancedsolarcollector_dead', x = 5937, y = 34, z = 5076, rot = 0 , scale = 1.0, resurrectas = "cortex_advancedsolarcollector"},
			{name = 'cortex_constructionbot_dead', x = 5173, y = 34, z = 4379, rot = 0 , scale = 1.0, resurrectas = "cortex_constructionbot"},
			{name = 'cortex_exploiter_dead', x = 4719, y = 34, z = 4687, rot = 0 , scale = 1.0, resurrectas = "cortex_exploiter"},
			{name = 'cortex_amphibiouscomplex_dead', x = 5760, y = -104, z = 208, rot = 0 , scale = 1.0, resurrectas = "cortex_amphibiouscomplex"},
			{name = 'cortex_amphibiouscomplex_dead', x = 96, y = -104, z = 4624, rot = 32767 , scale = 1.0, resurrectas = "cortex_amphibiouscomplex"},
			{name = 'cortex_metalextractor_dead', x = 736, y = -104, z = 4416, rot = 0 , scale = 1.0, resurrectas = "cortex_metalextractor"},
			{name = 'cortex_metalextractor_dead', x = 944, y = -104, z = 4176, rot = 0 , scale = 1.0, resurrectas = "cortex_metalextractor"},
			{name = 'cortex_metalextractor_dead', x = 5200, y = -104, z = 944, rot = -16384 , scale = 1.0, resurrectas = "cortex_metalextractor"},
			{name = 'cortex_metalextractor_dead', x = 5408, y = -104, z = 688, rot = -16384 , scale = 1.0, resurrectas = "cortex_metalextractor"},
			{name = 'cortex_exploiter_dead', x = 3337, y = 34, z = 3853, rot = 0 , scale = 1.0, resurrectas = "cortex_exploiter"},
			{name = 'cortex_graverobber_dead', x = 5042, y = 34, z = 4912, rot = 0 , scale = 1.0, resurrectas = "cortex_graverobber"},
			{name = 'cortex_exploiter_dead', x = 5627, y = 34, z = 3617, rot = 0 , scale = 1.0, resurrectas = "cortex_exploiter"},
			{name = 'cortex_exploiter_dead', x = 3950, y = 34, z = 4091, rot = 0 , scale = 1.0, resurrectas = "cortex_exploiter"},
			{name = 'cortex_exploiter_dead', x = 5710, y = 34, z = 4493, rot = 0 , scale = 1.0, resurrectas = "cortex_exploiter"},
			{name = 'cortex_advancedsolarcollector_dead', x = 6082, y = 34, z = 4834, rot = 0 , scale = 1.0, resurrectas = "cortex_advancedsolarcollector"},
			{name = 'cortex_exploiter_dead', x = 3866, y = 101, z = 5056, rot = 0 , scale = 1.0, resurrectas = "cortex_exploiter"},
			{name = 'cortex_exploiter_dead', x = 4319, y = 34, z = 3227, rot = 0 , scale = 1.0, resurrectas = "cortex_exploiter"},
			{name = 'cortex_exploiter_dead', x = 6024, y = 34, z = 2342, rot = 0 , scale = 1.0, resurrectas = "cortex_exploiter"},
			{name = "cortex_overseer_dead", x = 5248, y = 34, z = 4672, rot = 0, scale = 1.0, resurrectas = "cortex_overseer"},
			{name = "cortex_shroud_dead", x = 5808, y = 34, z = 4544, rot = 0, scale = 1.0, resurrectas = "cortex_shroud"},
			{name = "cortex_overseer_dead", x = 5792, y = 34, z = 4720, rot = 0, scale = 1.0, resurrectas = "cortex_overseer"},
			{name = "cortex_shroud_dead", x = 5120, y = 34, z = 4528, rot = 0, scale = 1.0, resurrectas = "cortex_shroud"},
			{name = "cortex_overseer_dead", x = 5792, y = 34, z = 4208, rot = 0, scale = 1.0, resurrectas = "cortex_overseer"},
			{name = "cortex_overseer_dead", x = 5280, y = 35, z = 4224, rot = 0, scale = 1.0, resurrectas = "cortex_overseer"},
			{name = "cortex_overseer_dead", x = 5520, y = 34, z = 4432, rot = 0, scale = 1.0, resurrectas = "cortex_overseer"},
			{name = "cortex_fusionreactor_dead", x = 6088, y = 34, z = 4952, rot = 0, scale = 1.0, resurrectas = "cortex_fusionreactor"},
			{name = "cortex_advancedsolarcollector_dead", x = 5632, y = 34, z = 5088, rot = 0, scale = 1.0, resurrectas = "cortex_advancedsolarcollector"},
			{name = "cortex_advancedsolarcollector_dead", x = 5840, y = 34, z = 5072, rot = 0, scale = 1.0, resurrectas = "cortex_advancedsolarcollector"},
			{name = "cortex_advancedsolarcollector_dead", x = 6016, y = 34, z = 5072, rot = 0, scale = 1.0, resurrectas = "cortex_advancedsolarcollector"},
			{name = "cortex_advancedsolarcollector_dead", x = 5424, y = 34, z = 5088, rot = 0, scale = 1.0, resurrectas = "cortex_advancedsolarcollector"},
			{name = "cortex_advancedsolarcollector_dead", x = 6080, y = 34, z = 4736, rot = 0, scale = 1.0, resurrectas = "cortex_advancedsolarcollector"},
			{name = "cortex_advancedsolarcollector_dead", x = 5328, y = 34, z = 5096, rot = 0, scale = 1.0, resurrectas = "cortex_advancedsolarcollector"},
			{name = "cortex_advancedsolarcollector_dead", x = 6098, y = 34, z = 4629, rot = 0, scale = 1.0, resurrectas = "cortex_advancedsolarcollector"},
			{name = "cortex_botlab_dead", x = 5504, y = 34, z = 4672, rot = 32767, scale = 1.0, resurrectas = "cortex_botlab"},
			{name = "cortex_scorpion_dead", x = 5704, y = 34, z = 4072, rot = 32767, scale = 1.0, resurrectas = "cortex_scorpion"},
			{name = "cortex_scorpion_dead", x = 4904, y = 34, z = 4616, rot = 16384, scale = 1.0, resurrectas = "cortex_scorpion"},
			{name = "cortex_twinguard_dead", x = 4962, y = 34, z = 4415, rot = 16384, scale = 1.0, resurrectas = "cortex_twinguard"},
			{name = "cortex_twinguard_dead", x = 5469, y = 34, z = 4075, rot = 32767, scale = 1.0, resurrectas = "cortex_twinguard"},
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
	
		[ai3]
		{
			Host = 0;
			IsFromDemo = 0;
			Name = InactiveAI(4);
			ShortName = NullAI;
			Team = 4;
			Version = 0.1;
		}

        [ai4]
		{
			Host = 0;
			IsFromDemo = 0;
			Name = InactiveAI(5);
			ShortName = NullAI;
			Team = 5;
			Version = 0.1;
		}


        [team4]
	    {
            Side = Cortex;
            Handicap = __ENEMYHANDICAP__;
            RgbColor = 0.99609375 0.546875 0;
            AllyTeam = 2;
            TeamLeader = 0;
            StartPosX = 5164;
            StartPosZ = 615;
	    }

        [team5]
	    {
            Side = Cortex;
            Handicap = __ENEMYHANDICAP__;
            RgbColor = 0.99609375 0.546875 0;
            AllyTeam = 2;
            TeamLeader = 0;
            StartPosX = 846;
            StartPosZ = 4430;
	    }

		[ai1]
		{
			Host = 0;
			IsFromDemo = 0;
			Name = BARbstable(2);
			ShortName = BARb;
			Team = 2;
			Version = stable;
		}
	
		[team1]
		{
			Side = Cortex;
			Handicap = __ENEMYHANDICAP__;
			RgbColor = 0.99609375 0.546875 0;
			AllyTeam = 0;
			TeamLeader = 0;
			StartPosX = 4888;
			StartPosZ = 3712;
		}
	
		[allyTeam2]
		{
			numallies = 0;
		}
	
		[allyTeam1]
		{
			numallies = 0;
		}
	
		[team3]
		{
			Side = Cortex;
			Handicap = __ENEMYHANDICAP__;
			RgbColor = 0.99609375 0.546875 0;
			AllyTeam = 2;
			TeamLeader = 0;
			StartPosX = 846;
			StartPosZ = 4430;
		}
	
		[team0]
		{
			Side = __PLAYERSIDE__;
			Handicap = __PLAYERHANDICAP__;
			RgbColor = 0.99609375 0.546875 0;
			AllyTeam = 0;
			TeamLeader = 0;
			StartPosX = 1176;
			StartPosZ = 1414;
		}
	
		[team2]
		{
			Side = Cortex;
			Handicap = __ENEMYHANDICAP__;
			RgbColor = 0.99609375 0.546875 0;
			AllyTeam = 2;
			TeamLeader = 0;
			StartPosX = 5164;
			StartPosZ = 615;
		}
	
		[modoptions]
		{
			deathmode = builders;
			maxunits = 2000;
			map_waterlevel = 150;
			startenergy = 1500;
			startmetal = 500;
			scenariooptions = __SCENARIOOPTIONS__;
		}
	
		[ai2]
		{
			Host = 0;
			IsFromDemo = 0;
			Name = BARbstable(3);
			ShortName = BARb;
			Team = 3;
			Version = stable;
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
		startpostype = 3;  // 0 fixed, 1 random, 2 choose in game, 3 choose before game (see StartPosX)
		mapname = __MAPNAME__;
		ishost = 1;
		numusers = 4;
		gametype = __BARVERSION__;
		GameStartDelay = 7; // seconds before game starts after loading/placement
		myplayername = __PLAYERNAME__;
		nohelperais = 0;
	}
	]],

}

return scenariodata
