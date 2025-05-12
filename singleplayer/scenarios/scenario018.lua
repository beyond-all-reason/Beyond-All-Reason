local scenariodata = {
	index			= 18, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "pinewoodfatboy018", -- no spaces, lowercase, this will be used to save the score
    version         = "1.0", -- increment this to keep the score when changing a mission
	title			= "One Robot Army", -- can be anything
	author			= "Beherith", -- your name here
	isnew 			= true,
	imagepath		= "scenario018.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "Gunslingers heal and gain experience quickly.", -- This text will be drawn over image
    summary         = [[You are left with a rogue force of a handful of units, and no base to take on the dreadful Cortex. Fatboy, Gunslinger, Welder and a minor foray of supporting units are your last hope.]],
	briefing 		= [[After a lost battle, your base is left crippled beyond repair, and you only have a few units remaining to take out the Cortex stronghold. Destroy the Cortex Commander with what you have left, while trying to keep all of your units alive. 
 
You start the game with Fatboy, Gunslinger, Welder, a Compass radar bot, some Ghost spies, and two Lazarus resurrections bots, and just enough energy to keep the spies cloaked, and the radar in working condition. 
 
The Cortex Commander also has his technology crippled, and does not have access to Tier 2 units, but if left to his devices, could amass a critical force of T1 units capable of overpowering your ragtag band. 

Our intelligence reports that Cortex have laid a minefield along the bridge, so be extremely cautious when approaching it. 
 
Tips:
 - Ghosts are cloakable, stealthy spies, that can be self-destructed for a large EMP blast to stun groups of units.
 - Fatboy has a very large range, and a huge area of effect, but is slow and hard to maneuver. Use Gunslinger to keep any smaller Tier 1 units away from him. 
 - Gunslinger will heal himself quickly after taking damage, and will gain extra HP and a faster reload time with experience gained from damaging enemy units. 
 - Welder is quite tanky, and can be used to absorb damage from any defenses. 
 - Compass has a very long line-of-sight, but is extremely fragile.
 - Lazarus can resurrect wrecked units, however, wrecks can be reduced to useless heaps by area-of-effect damage.
 - All mobile units can be ordered to Hold Position, to prevent them from moving to engage targets in their vision.
 - There may be useful wrecks on different areas of the map, that may assist you in your mission.
 
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

	mapfilename		= "Pinewood_Derby_V1", -- the name of the map to be displayed here
	playerstartx	= "10%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "25%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 1200, -- par time in seconds
	parresources	= 50000, -- par resource amount
	difficulty		= 5, -- Percieved difficulty at 'normal' level: integer 1-10
    defaultdifficulty = "Normal", -- an entry of the difficulty table
    difficulties    = { -- Array for sortedness, Keys are text that appears in selector (as well as in scoring!), values are handicap levels
        {name = "Beginner", playerhandicap = 50 , enemyhandicap = -50},
        {name = "Novice"  , playerhandicap = 25 , enemyhandicap = -25},
        {name = "Normal"  , playerhandicap = 0  , enemyhandicap = 0  },
        {name = "Hard"    , playerhandicap = 0, enemyhandicap = 50 },
        {name = "Brutal"  , playerhandicap = 0, enemyhandicap = 100 },
    },
    allowedsides     = {"Armada"}, --these are the permitted factions for this mission
	victorycondition= "Kill all enemy Commanders", -- This is plaintext, but should be reflected in startscript
	losscondition	= "Loss of all your units",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberoftese units, 0 is disable it
	-- dont use the one in startscript, put it here!
        coravp = 0,
		coralab = 0,
		corsy = 0,
		corhp = 0,
		corfhp = 0,
		corpun = 0,
		corap = 0,
    } ,
    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff",
        scenarioid = "pinewoodfatboy018", --must be present for scores
		disablefactionpicker = true, -- this is needed to prevent faction picking outside of the allowedsides
		unitloadout = {
			--{name = 'armcom', x = 5500, y = 198, z = 2500, rot = 0 , team = 1},
			--{name = 'armcom', x = 576, y = 198, z = 381, rot = 25658 , team = 0},
			{name = 'corllt', x = 944, y = 169, z = 2128, rot = 16384 , team = 1},
			{name = 'corllt', x = 1376, y = 83, z = 2016, rot = 16384 , team = 1},
			{name = 'corllt', x = 1312, y = 79, z = 2144, rot = 16384 , team = 1},
			{name = 'corrad', x = 1072, y = 179, z = 2560, rot = 16384 , team = 1},
			--{name = 'corca', x = 4795, y = 400, z = 2260, rot = 5578 , team = 1},
			{name = 'corllt', x = 752, y = 141, z = 2160, rot = 16384 , team = 1},
			{name = 'cordrag', x = 496, y = 92, z = 2160, rot = 16384 , team = 1},
			{name = 'corhlt', x = 800, y = 173, z = 2800, rot = 16384 , team = 1},
			{name = 'corrad', x = 928, y = 177, z = 2736, rot = 16384 , team = 1},
			{name = 'corexp', x = 1880, y = 237, z = 2808, rot = 16384 , team = 1},
			{name = 'cordrag', x = 1824, y = 236, z = 2672, rot = 16384 , team = 1},
			{name = 'cordrag', x = 1792, y = 236, z = 2784, rot = 16384 , team = 1},
			{name = 'cordrag', x = 1744, y = 226, z = 2880, rot = 16384 , team = 1},
			{name = 'cordrag', x = 1712, y = 222, z = 2928, rot = 16384 , team = 1},
			{name = 'cordrag', x = 1776, y = 235, z = 2832, rot = 16384 , team = 1},
			{name = 'corjamt', x = 1936, y = 239, z = 2880, rot = 16384 , team = 1},
			{name = 'corjamt', x = 1968, y = 237, z = 2752, rot = 16384 , team = 1},
			{name = 'corerad', x = 1872, y = 239, z = 2960, rot = 16384 , team = 1},
			{name = 'corerad', x = 1904, y = 238, z = 2688, rot = 16384 , team = 1},
			{name = 'corrad', x = 1792, y = 238, z = 2992, rot = 16384 , team = 1},
			--{name = 'coraca', x = 5892, y = 198, z = 2299, rot = 30645 , team = 1},
			{name = 'corfort', x = 5424, y = 199, z = 2400, rot = 16384 , team = 1},
			{name = 'corfort', x = 5392, y = 198, z = 2400, rot = 16384 , team = 1},
			{name = 'corfort', x = 5392, y = 198, z = 2432, rot = 16384 , team = 1},
			{name = 'corfort', x = 5424, y = 198, z = 2432, rot = 16384 , team = 1},
			{name = 'corfort', x = 5424, y = 198, z = 2464, rot = 16384 , team = 1},
			{name = 'corfort', x = 5392, y = 198, z = 2464, rot = 16384 , team = 1},
			{name = 'corfort', x = 5392, y = 198, z = 2496, rot = 16384 , team = 1},
			{name = 'corfort', x = 5424, y = 198, z = 2496, rot = 16384 , team = 1},
			{name = 'corfort', x = 5424, y = 198, z = 2528, rot = 16384 , team = 1},
			{name = 'corfort', x = 5392, y = 198, z = 2528, rot = 16384 , team = 1},
			{name = 'corfort', x = 5392, y = 198, z = 2560, rot = 16384 , team = 1},
			{name = 'corfort', x = 5424, y = 198, z = 2560, rot = 16384 , team = 1},
			{name = 'corfort', x = 5424, y = 198, z = 2592, rot = 16384 , team = 1},
			{name = 'corfort', x = 5392, y = 198, z = 2592, rot = 16384 , team = 1},
			{name = 'corfort', x = 5456, y = 198, z = 2560, rot = 16384 , team = 1},
			{name = 'corfort', x = 5488, y = 198, z = 2560, rot = 16384 , team = 1},
			{name = 'corfort', x = 5520, y = 198, z = 2560, rot = 16384 , team = 1},
			{name = 'corfort', x = 5552, y = 198, z = 2560, rot = 16384 , team = 1},
			{name = 'corfort', x = 5456, y = 198, z = 2592, rot = 16384 , team = 1},
			{name = 'corfort', x = 5488, y = 198, z = 2592, rot = 16384 , team = 1},
			{name = 'corfort', x = 5520, y = 198, z = 2592, rot = 16384 , team = 1},
			{name = 'corfort', x = 5552, y = 198, z = 2592, rot = 16384 , team = 1},
			{name = 'corfort', x = 5584, y = 198, z = 2592, rot = 16384 , team = 1},
			{name = 'corfort', x = 5584, y = 198, z = 2560, rot = 16384 , team = 1},
			{name = 'corfort', x = 5584, y = 198, z = 2528, rot = 16384 , team = 1},
			{name = 'corfort', x = 5584, y = 198, z = 2496, rot = 16384 , team = 1},
			{name = 'corfort', x = 5584, y = 198, z = 2464, rot = 16384 , team = 1},
			{name = 'corfort', x = 5584, y = 198, z = 2432, rot = 16384 , team = 1},
			{name = 'corfort', x = 5584, y = 199, z = 2400, rot = 16384 , team = 1},
			{name = 'corfort', x = 5616, y = 198, z = 2592, rot = 16384 , team = 1},
			{name = 'corfort', x = 5616, y = 198, z = 2560, rot = 16384 , team = 1},
			{name = 'corfort', x = 5616, y = 198, z = 2528, rot = 16384 , team = 1},
			{name = 'corfort', x = 5616, y = 198, z = 2496, rot = 16384 , team = 1},
			{name = 'corfort', x = 5616, y = 198, z = 2464, rot = 16384 , team = 1},
			{name = 'corfort', x = 5616, y = 198, z = 2432, rot = 16384 , team = 1},
			{name = 'corfort', x = 5616, y = 198, z = 2400, rot = 16384 , team = 1},
			{name = 'corfort', x = 5456, y = 198, z = 2432, rot = 16384 , team = 1},
			{name = 'corfort', x = 5488, y = 198, z = 2432, rot = 16384 , team = 1},
			{name = 'corfort', x = 5520, y = 199, z = 2432, rot = 16384 , team = 1},
			{name = 'corfort', x = 5552, y = 199, z = 2432, rot = 16384 , team = 1},
			{name = 'corfort', x = 5552, y = 199, z = 2400, rot = 16384 , team = 1},
			{name = 'corfort', x = 5520, y = 199, z = 2400, rot = 16384 , team = 1},
			{name = 'corfort', x = 5488, y = 199, z = 2400, rot = 16384 , team = 1},
			--{name = 'corca', x = 5493, y = 116, z = 689, rot = 18785 , team = 1},
			{name = 'corcom', x = 5500, y = 199, z = 2500, rot = 18785 , team = 1},
			{name = 'corfort', x = 5456, y = 199, z = 2400, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5360, y = 198, z = 2592, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5328, y = 198, z = 2592, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5392, y = 198, z = 2624, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5392, y = 198, z = 2656, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5616, y = 198, z = 2624, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5616, y = 198, z = 2656, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5648, y = 199, z = 2592, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5680, y = 199, z = 2592, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5648, y = 198, z = 2400, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5680, y = 198, z = 2400, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5616, y = 198, z = 2368, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5616, y = 198, z = 2336, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5392, y = 199, z = 2368, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5392, y = 198, z = 2336, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5360, y = 199, z = 2400, rot = 16384 , team = 1},
			{name = 'cordrag', x = 5328, y = 198, z = 2400, rot = 16384 , team = 1},
			{name = 'cormex', x = 5480, y = 198, z = 2712, rot = 16384 , team = 1},
			{name = 'cormex', x = 5752, y = 198, z = 2504, rot = 16384 , team = 1},
			{name = 'cormex', x = 5656, y = 198, z = 2200, rot = 16384 , team = 1},
			{name = 'cornanotc', x = 5816, y = 199, z = 2040, rot = 16384 , team = 1},
			{name = 'cornanotc', x = 5768, y = 199, z = 2040, rot = 16384 , team = 1},
			{name = 'cornanotc', x = 5448, y = 198, z = 2024, rot = 16384 , team = 1},
			{name = 'cornanotc', x = 5400, y = 198, z = 2024, rot = 16384 , team = 1},
			{name = 'corlab', x = 5440, y = 198, z = 1904, rot = 32767 , team = 1},
			{name = 'corvp', x = 5784, y = 198, z = 1912, rot = 32767 , team = 1},
			{name = 'coradvsol', x = 5488, y = 198, z = 2128, rot = 32767 , team = 1},
			{name = 'coradvsol', x = 5424, y = 198, z = 2128, rot = 32767 , team = 1},
			{name = 'coradvsol', x = 5360, y = 199, z = 2128, rot = 32767 , team = 1},
			{name = 'coradvsol', x = 5744, y = 199, z = 2144, rot = 32767 , team = 1},
			{name = 'coradvsol', x = 5808, y = 198, z = 2144, rot = 32767 , team = 1},
			{name = 'coradvsol', x = 5872, y = 198, z = 2144, rot = 32767 , team = 1},
			{name = 'corwin', x = 5256, y = 198, z = 2776, rot = 32767 , team = 1},
			{name = 'corwin', x = 5320, y = 198, z = 2776, rot = 32767 , team = 1},
			{name = 'corwin', x = 5384, y = 198, z = 2776, rot = 32767 , team = 1},
			{name = 'corwin', x = 5448, y = 198, z = 2776, rot = 32767 , team = 1},
			{name = 'corwin', x = 5512, y = 198, z = 2776, rot = 32767 , team = 1},
			{name = 'corwin', x = 5576, y = 198, z = 2776, rot = 32767 , team = 1},
			{name = 'corwin', x = 5640, y = 198, z = 2776, rot = 32767 , team = 1},
			{name = 'corwin', x = 5704, y = 198, z = 2776, rot = 32767 , team = 1},
			{name = 'corexp', x = 3704, y = 237, z = 1368, rot = 32767 , team = 1},
			{name = 'corwin', x = 5704, y = 198, z = 2840, rot = 32767 , team = 1},
			{name = 'corwin', x = 5640, y = 198, z = 2840, rot = 32767 , team = 1},
			{name = 'corwin', x = 5576, y = 198, z = 2840, rot = 32767 , team = 1},
			{name = 'corwin', x = 5512, y = 198, z = 2840, rot = 32767 , team = 1},
			{name = 'corwin', x = 5448, y = 198, z = 2840, rot = 32767 , team = 1},
			{name = 'corwin', x = 5384, y = 198, z = 2840, rot = 32767 , team = 1},
			{name = 'corrad', x = 3808, y = 234, z = 1232, rot = 32767 , team = 1},
			{name = 'corwin', x = 5320, y = 198, z = 2840, rot = 32767 , team = 1},
			{name = 'corwin', x = 5256, y = 198, z = 2840, rot = 32767 , team = 1},
			{name = 'corwin', x = 5256, y = 198, z = 2904, rot = 32767 , team = 1},
			{name = 'corllt', x = 3680, y = 239, z = 1728, rot = 32767 , team = 1},
			{name = 'corwin', x = 5320, y = 198, z = 2904, rot = 32767 , team = 1},
			{name = 'corwin', x = 5384, y = 198, z = 2904, rot = 32767 , team = 1},
			{name = 'corhlt', x = 3568, y = 238, z = 1648, rot = 32767 , team = 1},
			{name = 'corwin', x = 5448, y = 198, z = 2904, rot = 32767 , team = 1},
			{name = 'corwin', x = 5512, y = 198, z = 2904, rot = 32767 , team = 1},
			{name = 'corhlt', x = 3520, y = 240, z = 1472, rot = 32767 , team = 1},
			{name = 'corwin', x = 5576, y = 199, z = 2904, rot = 32767 , team = 1},
			{name = 'corwin', x = 5640, y = 198, z = 2904, rot = 32767 , team = 1},
			{name = 'corwin', x = 5704, y = 198, z = 2904, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3504, y = 131, z = 1776, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3472, y = 128, z = 1808, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3440, y = 128, z = 1840, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3424, y = 128, z = 1872, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3312, y = 128, z = 2000, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3280, y = 128, z = 2032, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3248, y = 124, z = 2064, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3488, y = 131, z = 1744, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3456, y = 128, z = 1776, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3440, y = 128, z = 1808, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3408, y = 128, z = 1840, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3296, y = 128, z = 1968, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3280, y = 128, z = 2000, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3248, y = 128, z = 2032, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3472, y = 129, z = 1712, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3440, y = 128, z = 1744, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3424, y = 128, z = 1776, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3392, y = 128, z = 1808, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3280, y = 128, z = 1936, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3248, y = 128, z = 1968, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3232, y = 128, z = 2000, rot = 32767 , team = 1},
			{name = 'cordrag', x = 3200, y = 129, z = 2032, rot = 32767 , team = 1},
			{name = 'cormex', x = 5880, y = 79, z = 616, rot = 32767 , team = 1},
			{name = 'cormex', x = 5896, y = 77, z = 264, rot = 32767 , team = 1},
			{name = 'cormex', x = 5000, y = 178, z = 568, rot = 32767 , team = 1},
			{name = 'corexp', x = 4472, y = 78, z = 952, rot = 32767 , team = 1},
			{name = 'corexp', x = 4136, y = 232, z = 200, rot = 32767 , team = 1},
			{name = 'corwin', x = 5736, y = 78, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 5672, y = 78, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 5608, y = 78, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 5544, y = 78, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 5480, y = 79, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 5416, y = 80, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 5352, y = 84, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 5288, y = 94, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 5224, y = 103, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 5160, y = 103, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 5096, y = 100, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 5032, y = 97, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 4904, y = 82, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 4840, y = 79, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 4776, y = 78, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 4712, y = 78, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 4648, y = 78, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 4584, y = 78, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 4520, y = 78, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 4456, y = 77, z = 104, rot = 32767 , team = 1},
			{name = 'corwin', x = 4520, y = 79, z = 168, rot = 32767 , team = 1},
			{name = 'corwin', x = 4584, y = 79, z = 168, rot = 32767 , team = 1},
			{name = 'corwin', x = 4648, y = 78, z = 168, rot = 32767 , team = 1},
			{name = 'corwin', x = 4712, y = 79, z = 168, rot = 32767 , team = 1},
			{name = 'corwin', x = 4776, y = 80, z = 168, rot = 32767 , team = 1},
			{name = 'corwin', x = 4840, y = 84, z = 168, rot = 32767 , team = 1},
			{name = 'corwin', x = 5288, y = 101, z = 168, rot = 32767 , team = 1},
			--{name = 'armca', x = 669, y = 199, z = 206, rot = -32576 , team = 0},
			{name = 'corwin', x = 5352, y = 90, z = 168, rot = 32767 , team = 1},
			{name = 'corwin', x = 5416, y = 82, z = 168, rot = 32767 , team = 1},
			{name = 'corwin', x = 5480, y = 79, z = 168, rot = 32767 , team = 1},
			{name = 'corwin', x = 5544, y = 78, z = 168, rot = 32767 , team = 1},
			{name = 'corwin', x = 5608, y = 78, z = 168, rot = 32767 , team = 1},
			{name = 'corwin', x = 5672, y = 78, z = 168, rot = 32767 , team = 1},
			{name = 'corwin', x = 5736, y = 78, z = 168, rot = 32767 , team = 1},
			{name = 'armadvsol', x = 752, y = 198, z = 656, rot = 32767 , team = 0},
			{name = 'corwin', x = 5736, y = 79, z = 232, rot = 32767 , team = 1},
			{name = 'armadvsol', x = 688, y = 199, z = 656, rot = 32767 , team = 0},
			{name = 'corwin', x = 5672, y = 78, z = 232, rot = 32767 , team = 1},
			{name = 'corwin', x = 5608, y = 78, z = 232, rot = 32767 , team = 1},
			{name = 'corwin', x = 5544, y = 79, z = 232, rot = 32767 , team = 1},
			{name = 'armadvsol', x = 624, y = 199, z = 656, rot = 32767 , team = 0},
			{name = 'corwin', x = 5480, y = 80, z = 232, rot = 32767 , team = 1},
			{name = 'corwin', x = 4776, y = 83, z = 232, rot = 32767 , team = 1},
			--{name = 'armestor', x = 760, y = 198, z = 600, rot = 32767 , team = 0},
			{name = 'corwin', x = 4712, y = 80, z = 232, rot = 32767 , team = 1},
			{name = 'corwin', x = 4648, y = 81, z = 232, rot = 32767 , team = 1},
			{name = 'corwin', x = 4584, y = 82, z = 232, rot = 32767 , team = 1},
			{name = 'armjamt', x = 688, y = 198, z = 592, rot = 32767 , team = 0},
			{name = 'armrad', x = 624, y = 199, z = 592, rot = 32767 , team = 0},
			{name = 'armadvsol', x = 624, y = 198, z = 544, rot = 32767 , team = 0},
			{name = 'armadvsol', x = 688, y = 198, z = 544, rot = 32767 , team = 0},
			{name = 'armadvsol', x = 752, y = 198, z = 544, rot = 32767 , team = 0},
			{name = 'armdrag', x = 768, y = 198, z = 704, rot = 32767 , team = 0},
			{name = 'armdrag', x = 736, y = 198, z = 704, rot = 32767 , team = 0},
			{name = 'armdrag', x = 704, y = 198, z = 704, rot = 32767 , team = 0},
			{name = 'armdrag', x = 672, y = 199, z = 704, rot = 32767 , team = 0},
			{name = 'armdrag', x = 640, y = 199, z = 704, rot = 32767 , team = 0},
			{name = 'armdrag', x = 608, y = 198, z = 704, rot = 32767 , team = 0},
			{name = 'armdrag', x = 576, y = 198, z = 672, rot = 32767 , team = 0},
			{name = 'armdrag', x = 576, y = 198, z = 640, rot = 32767 , team = 0},
			{name = 'armdrag', x = 576, y = 198, z = 608, rot = 32767 , team = 0},
			{name = 'armdrag', x = 576, y = 198, z = 576, rot = 32767 , team = 0},
			{name = 'armdrag', x = 576, y = 198, z = 544, rot = 32767 , team = 0},
			{name = 'armdrag', x = 576, y = 198, z = 512, rot = 32767 , team = 0},
			{name = 'armdrag', x = 608, y = 198, z = 480, rot = 32767 , team = 0},
			{name = 'armdrag', x = 640, y = 198, z = 480, rot = 32767 , team = 0},
			{name = 'armdrag', x = 672, y = 198, z = 480, rot = 32767 , team = 0},
			{name = 'armdrag', x = 704, y = 198, z = 480, rot = 32767 , team = 0},
			{name = 'armdrag', x = 736, y = 198, z = 480, rot = 32767 , team = 0},
			{name = 'armdrag', x = 768, y = 198, z = 480, rot = 32767 , team = 0},
			{name = 'armdrag', x = 800, y = 198, z = 512, rot = 32767 , team = 0},
			{name = 'armdrag', x = 800, y = 198, z = 544, rot = 32767 , team = 0},
			{name = 'armdrag', x = 800, y = 198, z = 576, rot = 32767 , team = 0},
			{name = 'armdrag', x = 800, y = 198, z = 608, rot = 32767 , team = 0},
			{name = 'armdrag', x = 800, y = 198, z = 640, rot = 32767 , team = 0},
			{name = 'armdrag', x = 800, y = 198, z = 672, rot = 32767 , team = 0},
			{name = 'armclaw', x = 576, y = 198, z = 704, rot = 32767 , team = 0},
			{name = 'armclaw', x = 576, y = 198, z = 480, rot = 32767 , team = 0},
			{name = 'armclaw', x = 800, y = 198, z = 480, rot = 32767 , team = 0},
			{name = 'armclaw', x = 800, y = 198, z = 704, rot = 32767 , team = 0},
			{name = 'armdrag', x = 16, y = 198, z = 848, rot = 32767 , team = 0},
			{name = 'armdrag', x = 48, y = 198, z = 848, rot = 32767 , team = 0},
			{name = 'armdrag', x = 80, y = 198, z = 848, rot = 32767 , team = 0},
			{name = 'armdrag', x = 112, y = 199, z = 848, rot = 32767 , team = 0},
			{name = 'armdrag', x = 144, y = 199, z = 848, rot = 32767 , team = 0},
			{name = 'armdrag', x = 176, y = 198, z = 848, rot = 32767 , team = 0},
			{name = 'armdrag', x = 208, y = 198, z = 848, rot = 32767 , team = 0},
			{name = 'armdrag', x = 240, y = 198, z = 848, rot = 32767 , team = 0},
			{name = 'armdrag', x = 272, y = 198, z = 848, rot = 32767 , team = 0},
			{name = 'armfboy', x = 326, y = 198, z = 741, rot = -3181 , team = 0},
			{name = 'armdrag', x = 304, y = 198, z = 848, rot = 32767 , team = 0},
			{name = 'armdrag', x = 336, y = 198, z = 848, rot = 32767 , team = 0},
			{name = 'armdrag', x = 368, y = 198, z = 848, rot = 32767 , team = 0},
			{name = 'armdrag', x = 400, y = 198, z = 848, rot = 32767 , team = 0},
			{name = 'armdrag', x = 432, y = 198, z = 848, rot = 32767 , team = 0},
			{name = 'armmav', x = 414, y = 198, z = 743, rot = 113 , team = 0},
			{name = 'armdrag', x = 832, y = 198, z = 848, rot = 32767 , team = 0},
			{name = 'armdrag', x = 864, y = 199, z = 848, rot = 32767 , team = 0},
			{name = 'armzeus', x = 511, y = 198, z = 700, rot = 5129 , team = 0},
			{name = 'armmark', x = 538, y = 198, z = 784, rot = 28873 , team = 0},
			{name = 'armrectr', x = 465, y = 198, z = 509, rot = -28531 , team = 0},
			{name = 'armrectr', x = 343, y = 199, z = 525, rot = 22301 , team = 0},
			{name = 'corllt', x = 4672, y = 396, z = 1792, rot = 32767 , team = 1},
			{name = 'corhllt', x = 4640, y = 391, z = 1920, rot = 32767 , team = 1},
			{name = 'corerad', x = 4880, y = 399, z = 1744, rot = 32767 , team = 1},
			{name = 'corerad', x = 4736, y = 398, z = 2064, rot = 32767 , team = 1},
			{name = 'corhlt', x = 3600, y = 74, z = 2384, rot = 32767 , team = 1},
			{name = 'corhlt', x = 2288, y = 235, z = 1744, rot = 32767 , team = 1},
			{name = 'corhlt', x = 2208, y = 195, z = 1392, rot = 32767 , team = 1},
			{name = 'corllt', x = 2208, y = 195, z = 1520, rot = 32767 , team = 1},
			{name = 'cordrag', x = 2320, y = 128, z = 816, rot = 32767 , team = 1},
			{name = 'cordrag', x = 2336, y = 128, z = 944, rot = 32767 , team = 1},
			{name = 'cordrag', x = 2352, y = 128, z = 1056, rot = 32767 , team = 1},
			{name = 'corrad', x = 2464, y = 238, z = 1440, rot = 32767 , team = 1},
			{name = 'armclaw', x = 464, y = 198, z = 848, rot = 32767 , team = 0},
			{name = 'armclaw', x = 800, y = 198, z = 848, rot = 32767 , team = 0},
			{name = 'cordl', x = 3296, y = 20, z = 2384, rot = 32767 , team = 1},
			{name = 'cordl', x = 3264, y = 25, z = 2528, rot = 32767 , team = 1},
			{name = 'cordl', x = 3216, y = 22, z = 2672, rot = 32767 , team = 1},
			{name = 'cordl', x = 3184, y = 25, z = 2800, rot = 32767 , team = 1},
			{name = 'cordl', x = 3152, y = 31, z = 2928, rot = 32767 , team = 1},
			{name = 'cordl', x = 3120, y = 28, z = 3024, rot = 32767 , team = 1},
			{name = 'cordl', x = 3952, y = 39, z = 608, rot = 32767 , team = 1},
			{name = 'cordl', x = 3920, y = 43, z = 720, rot = 32767 , team = 1},
			{name = 'cordl', x = 3856, y = 33, z = 832, rot = 32767 , team = 1},
			{name = 'armspy', x = 380, y = 198, z = 620, rot = 7963 , team = 0},
			{name = 'armspy', x = 500, y = 198, z = 631, rot = 14701 , team = 0},
			{name = 'armspy', x = 268, y = 198, z = 627, rot = 1521 , team = 0},
			{name = 'corgeo', x = 4816, y = 398, z = 1808, rot = 32767 , team = 1},
			--{name = 'coraca', x = 4745, y = 96, z = 1008, rot = -12630 , team = 1},
			{name = 'corvipe', x = 5464, y = 125, z = 1128, rot = 32767 , team = 1},
			{name = 'corflak', x = 4896, y = 180, z = 864, rot = 32767 , team = 1},
			{name = 'corhllt', x = 5056, y = 179, z = 864, rot = 32767 , team = 1},
			{name = 'corhllt', x = 5232, y = 149, z = 880, rot = 32767 , team = 1},
			{name = 'corhllt', x = 5360, y = 118, z = 944, rot = 32767 , team = 1},
			{name = 'corhllt', x = 5408, y = 154, z = 1264, rot = 32767 , team = 1},
			{name = 'corhllt', x = 5312, y = 178, z = 1376, rot = 32767 , team = 1},
			{name = 'corhllt', x = 5168, y = 169, z = 1456, rot = 32767 , team = 1},
			{name = 'corhllt', x = 5072, y = 156, z = 1472, rot = 32767 , team = 1},
			{name = 'corrad', x = 5088, y = 177, z = 720, rot = 32767 , team = 1},
			{name = 'mission_command_tower', x = 5500, y = 200, z = 2302, rot = 0 , team = 1},
		},
			
		featureloadout = {
			{name = 'cormlv_dead', x = 274, y = 199, z = 140, rot = 0 , scale = 1.0, resurrectas = "cormlv"},
		}
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
		Side = Cortex;
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
		scenariooptions = __SCENARIOOPTIONS__;
		startenergy = 7000;
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
