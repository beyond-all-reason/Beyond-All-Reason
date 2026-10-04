local scenariodata = {
	index			= 12, --  integer, sort order, MUST BE EQUAL TO FILENAME NUMBER
	scenarioid		= "avalanchemines012", -- no spaces, lowercase, this will be used to save the score and can be used gadget side
    version         = "1", -- increment this to reset the score when changing a mission, as scores are keyed by (scenarioid,version,difficulty)
	title			= "Mines, all mine!", -- can be anything

	author			= "Beherith", -- your name here
	imagepath		= "scenario012.jpg", -- placed next to lua file, should be 3:1 ratio banner style
	imageflavor		= "Mines explode on the slightest touch", -- This text will be drawn over image
    summary         = [[The Armada are amassing reinforcements at a rally point near one of your stealthy outposts. You do not have any technology except for minelayers and scouts. Lay mines around the area, and then you must distract and draw these forces onto minefields, without allowing Armada to detect and destroy your base of operations.]],
	briefing 		= [[
Tips:
 - Mines automatically detonate if an enemy gets within range of it, or if it is destroyed.
 - Mines can be manually detonated immediately by self-destructing them (Ctrl + D).
 - Use scout vehicles to lure enemy units onto minefields.
 - Minelayers are stealthy, thus do not show up on the enemy radar. They also have a short range radar jammer, to hide any mines under construction.
 - Mines are also stealthy, and automatically cloak once built, becoming undetectable by the enemy.
 - Keeping mines cloaked costs energy, and running out of energy can result in them losing their cloaks temporarily.
 - Minelayers have a large area-of-effect mine-clearing weapon, which they can activate by force-firing at the ground.
 - All cloaked units (even mines) will lose their cloaking if they get too close to an enemy unit.
 - You can build walls of Dragon’s Teeth to funnel enemy units onto minefields.

Scoring:
 - Lure and destroy the enemy forces as quickly as you can
 - Be efficient by using the least amount of resources to dispatch the enemy forces

 ]],

	mapfilename		= "Avalanche 3.4", -- the name of the map to be displayed here, and which to play on, no .smf ending needed
	playerstartx	= "85%", -- X position of where player comm icon should be drawn, from top left of the map
	playerstarty	= "85%", -- Y position of where player comm icon should be drawn, from top left of the map
	partime 		= 600, -- par time in seconds (time a mission is expected to take on average)
	parresources	= 10000, -- par resource amount (amount of metal one is expected to spend on mission)
	difficulty		= 2, -- Percieved difficulty at 'normal' level: integer 1-10
    defaultdifficulty = "Normal", -- an entry of the difficulty table
    difficulties    = { -- Array for sortedness, Keys are text that appears in selector (as well as in scoring!), values are handicap levels
    -- handicap values range [-100 - +100], with 0 being regular resources
    -- Currently difficulty modifier only affects the resource bonuses
        {name = "Beginner", playerhandicap = 50 , enemyhandicap = 0},
        {name = "Novice"  , playerhandicap = 25 , enemyhandicap = 0},
        {name = "Normal"  , playerhandicap = 0  , enemyhandicap = 0},
        {name = "Hard"    , playerhandicap = -25, enemyhandicap = 0},
        {name = "Brutal"  , playerhandicap = -50, enemyhandicap = 0},
    },
    allowedsides     = {"Cortex"}, --these are the permitted factions for this mission, choose from {"Armada", "Cortex", "Random"}
	victorycondition= "Kill all Armada reinforcements", -- This is plaintext, but should be reflected in startscript
	losscondition	= "Lose all your units",  -- This is plaintext, but should be reflected in startscript
    unitlimits   = { -- table of unitdefname : maxnumberofthese units, 0 means disable it
        -- dont use the one in startscript, put the disabled stuff here so we can show it in scenario window!
        --armavp = 0,
        --coravp = 0,
		corcv = 0,
		corgator = 0,
		corraid = 0,
		cormist = 0,
		corwolv = 0,
		corlevlr = 0,
		corgarp = 0,
		cormuskrat = 0,
    } ,

    scenariooptions = { -- this will get lua->json->base64 and passed to scenariooptions in game
        myoption = "dostuff", -- blank
        scenarioid = "avalanchemines012", -- this MUST be present and identical to the one defined at start
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


{name = 'corvp', x = 3656, y = 323, z = 3528, rot = 0 , team = 0},
{name = 'cormex', x = 3848, y = 322, z = 3832, rot = 0 , team = 0},
{name = 'cormlv', x = 3542, y = 320, z = 3633, rot = -16384 , team = 0},
{name = 'cormex', x = 3880, y = 325, z = 3432, rot = 0 , team = 0},
{name = 'cormlv', x = 3466, y = 322, z = 3271, rot = -16384 , team = 0},
{name = 'cormlv', x = 3513, y = 321, z = 3557, rot = -16384 , team = 0},
{name = 'corfav', x = 3514, y = 322, z = 3449, rot = -16384 , team = 0},
{name = 'corfav', x = 3575, y = 321, z = 3543, rot = -16384 , team = 0},
{name = 'corfav', x = 3582, y = 319, z = 3628, rot = -16384 , team = 0},
{name = 'corfav', x = 3512, y = 322, z = 3409, rot = -16384 , team = 0},
{name = 'corfav', x = 3566, y = 322, z = 3375, rot = -16384 , team = 0},
{name = 'cormex', x = 3464, y = 324, z = 3160, rot = 0 , team = 0},
{name = 'corrad', x = 3696, y = 324, z = 3392, rot = 0 , team = 0},
--{name = 'corestor', x = 3776, y = 321, z = 3552, rot = 0 , team = 0},
{name = 'coradvsol', x = 3824, y = 319, z = 3680, rot = 0 , team = 0},
{name = 'coradvsol', x = 3760, y = 321, z = 3680, rot = 0 , team = 0},
{name = 'coradvsol', x = 3696, y = 319, z = 3680, rot = 0 , team = 0},
{name = 'coradvsol', x = 3696, y = 321, z = 3744, rot = 0 , team = 0},
{name = 'coradvsol', x = 3760, y = 320, z = 3744, rot = 0 , team = 0},
{name = 'coradvsol', x = 3824, y = 319, z = 3744, rot = 0 , team = 0},
{name = 'corrad', x = 1065, y = 325, z = 4047, rot = 0 , team = 0},
{name = 'corjamt', x = 3680, y = 323, z = 3424, rot = 0 , team = 0},
{name = 'cordrag', x = 4080, y = 326, z = 3120, rot = 0 , team = 0},
{name = 'cordrag', x = 4048, y = 326, z = 3120, rot = 0 , team = 0},
{name = 'cordrag', x = 4016, y = 325, z = 3120, rot = 0 , team = 0},
{name = 'cordrag', x = 3984, y = 325, z = 3120, rot = 0 , team = 0},
{name = 'cordrag', x = 3952, y = 325, z = 3120, rot = 0 , team = 0},
{name = 'cordrag', x = 3920, y = 325, z = 3120, rot = 0 , team = 0},
{name = 'cordrag', x = 3888, y = 325, z = 3120, rot = 0 , team = 0},
{name = 'cordrag', x = 3856, y = 325, z = 3120, rot = 0 , team = 0},
{name = 'cordrag', x = 3824, y = 324, z = 3120, rot = 0 , team = 0},
{name = 'cordrag', x = 3568, y = 324, z = 3120, rot = 0 , team = 0},
{name = 'cordrag', x = 3536, y = 325, z = 3120, rot = 0 , team = 0},
{name = 'cordrag', x = 3504, y = 324, z = 3120, rot = 0 , team = 0},
{name = 'cordrag', x = 3472, y = 324, z = 3120, rot = 0 , team = 0},
{name = 'cordrag', x = 3440, y = 323, z = 3120, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 323, z = 3120, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 323, z = 3152, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 323, z = 3184, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 323, z = 3216, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 323, z = 3248, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 323, z = 3280, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 322, z = 3312, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 322, z = 3344, rot = 0 , team = 0},
{name = 'cormine1', x = 3768, y = 323, z = 3080, rot = 0 , team = 0},
{name = 'cormine1', x = 3704, y = 323, z = 3080, rot = 0 , team = 0},
{name = 'cormine1', x = 3640, y = 323, z = 3080, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 304, z = 3664, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 300, z = 3696, rot = 0 , team = 0},
{name = 'cormine1', x = 3336, y = 323, z = 3320, rot = 0 , team = 0},
{name = 'cormine1', x = 3240, y = 323, z = 3320, rot = 0 , team = 0},
{name = 'cormine1', x = 3240, y = 319, z = 3400, rot = 0 , team = 0},
{name = 'cormine1', x = 3240, y = 309, z = 3480, rot = 0 , team = 0},
{name = 'cormine1', x = 3240, y = 293, z = 3560, rot = 0 , team = 0},
{name = 'cormine1', x = 3240, y = 275, z = 3640, rot = 0 , team = 0},
{name = 'cormine1', x = 3336, y = 282, z = 3640, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 296, z = 3728, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 284, z = 3760, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 274, z = 3792, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 272, z = 3824, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 271, z = 3856, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 271, z = 3888, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 269, z = 3920, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 265, z = 3952, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 261, z = 3984, rot = 0 , team = 0},
{name = 'corrad', x = 3853, y = 683, z = 122, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 263, z = 4016, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 265, z = 4048, rot = 0 , team = 0},
{name = 'cordrag', x = 3408, y = 270, z = 4080, rot = 0 , team = 0},
{name = 'armstump', x = 907, y = 144, z = 3084, rot = 0 , team = 1},
{name = 'armstump', x = 948, y = 144, z = 3084, rot = 0 , team = 1},
{name = 'armstump', x = 989, y = 144, z = 3084, rot = 0 , team = 1},
{name = 'armstump', x = 1029, y = 144, z = 3083, rot = 0 , team = 1},
{name = 'armstump', x = 1070, y = 144, z = 3084, rot = 0 , team = 1},
{name = 'armstump', x = 917, y = 143, z = 3123, rot = 0 , team = 1},
{name = 'armstump', x = 957, y = 144, z = 3123, rot = 0 , team = 1},
{name = 'armstump', x = 998, y = 144, z = 3123, rot = 0 , team = 1},
{name = 'armstump', x = 1038, y = 144, z = 3122, rot = 0 , team = 1},
{name = 'armstump', x = 1078, y = 144, z = 3123, rot = 0 , team = 1},
{name = 'armstump', x = 905, y = 142, z = 3162, rot = 0 , team = 1},
{name = 'armstump', x = 945, y = 143, z = 3162, rot = 0 , team = 1},
{name = 'armstump', x = 987, y = 144, z = 3162, rot = 0 , team = 1},
{name = 'armstump', x = 1027, y = 145, z = 3161, rot = 0 , team = 1},
{name = 'armstump', x = 1068, y = 145, z = 3162, rot = 0 , team = 1},
{name = 'armstump', x = 913, y = 143, z = 3201, rot = 0 , team = 1},
{name = 'armstump', x = 953, y = 144, z = 3202, rot = 0 , team = 1},
{name = 'armstump', x = 994, y = 145, z = 3202, rot = 0 , team = 1},
{name = 'armstump', x = 1034, y = 146, z = 3201, rot = 0 , team = 1},
{name = 'armstump', x = 1074, y = 146, z = 3202, rot = 0 , team = 1},
{name = 'armpw', x = 2208, y = 327, z = 1459, rot = 0 , team = 1},
{name = 'armpw', x = 2240, y = 327, z = 1459, rot = 0 , team = 1},
{name = 'armpw', x = 2272, y = 328, z = 1459, rot = 0 , team = 1},
{name = 'armpw', x = 2304, y = 329, z = 1459, rot = 0 , team = 1},
{name = 'armpw', x = 2336, y = 330, z = 1459, rot = 0 , team = 1},
{name = 'armpw', x = 2368, y = 332, z = 1459, rot = 0 , team = 1},
{name = 'armpw', x = 2400, y = 335, z = 1459, rot = 0 , team = 1},
{name = 'armpw', x = 2432, y = 338, z = 1459, rot = 0 , team = 1},
{name = 'armpw', x = 2464, y = 341, z = 1459, rot = 0 , team = 1},
{name = 'armpw', x = 2496, y = 345, z = 1459, rot = 0 , team = 1},
{name = 'armpw', x = 2208, y = 327, z = 1491, rot = 0 , team = 1},
{name = 'armpw', x = 2240, y = 327, z = 1491, rot = 0 , team = 1},
{name = 'armpw', x = 2272, y = 327, z = 1491, rot = 0 , team = 1},
{name = 'armpw', x = 2304, y = 328, z = 1491, rot = 0 , team = 1},
{name = 'armpw', x = 2336, y = 329, z = 1491, rot = 0 , team = 1},
{name = 'armpw', x = 2368, y = 331, z = 1491, rot = 0 , team = 1},
{name = 'armpw', x = 2400, y = 334, z = 1491, rot = 0 , team = 1},
{name = 'armpw', x = 2432, y = 336, z = 1491, rot = 0 , team = 1},
{name = 'armpw', x = 2464, y = 339, z = 1491, rot = 0 , team = 1},
{name = 'armpw', x = 2496, y = 343, z = 1491, rot = 0 , team = 1},
{name = 'armpw', x = 2208, y = 325, z = 1523, rot = 0 , team = 1},
{name = 'armpw', x = 2240, y = 327, z = 1523, rot = 0 , team = 1},
{name = 'armpw', x = 2272, y = 327, z = 1523, rot = 0 , team = 1},
{name = 'armpw', x = 2304, y = 328, z = 1523, rot = 0 , team = 1},
{name = 'armpw', x = 2336, y = 329, z = 1523, rot = 0 , team = 1},
{name = 'armpw', x = 2368, y = 331, z = 1523, rot = 0 , team = 1},
{name = 'armpw', x = 2400, y = 332, z = 1523, rot = 0 , team = 1},
{name = 'armpw', x = 2432, y = 333, z = 1523, rot = 0 , team = 1},
{name = 'armpw', x = 2464, y = 336, z = 1523, rot = 0 , team = 1},
{name = 'armpw', x = 2496, y = 340, z = 1523, rot = 0 , team = 1},
{name = 'armpw', x = 2208, y = 327, z = 1555, rot = 0 , team = 1},
{name = 'armpw', x = 2240, y = 327, z = 1555, rot = 0 , team = 1},
{name = 'armpw', x = 2272, y = 327, z = 1555, rot = 0 , team = 1},
{name = 'armpw', x = 2304, y = 327, z = 1555, rot = 0 , team = 1},
{name = 'armpw', x = 2336, y = 329, z = 1555, rot = 0 , team = 1},
{name = 'armpw', x = 2368, y = 330, z = 1555, rot = 0 , team = 1},
{name = 'armpw', x = 2400, y = 331, z = 1555, rot = 0 , team = 1},
{name = 'armpw', x = 2432, y = 332, z = 1555, rot = 0 , team = 1},
{name = 'armpw', x = 2464, y = 334, z = 1555, rot = 0 , team = 1},
{name = 'armpw', x = 2496, y = 337, z = 1555, rot = 0 , team = 1},
{name = 'armpw', x = 2208, y = 328, z = 1587, rot = 0 , team = 1},
{name = 'armpw', x = 2240, y = 327, z = 1587, rot = 0 , team = 1},
{name = 'armpw', x = 2272, y = 327, z = 1587, rot = 0 , team = 1},
{name = 'armpw', x = 2304, y = 328, z = 1587, rot = 0 , team = 1},
{name = 'armpw', x = 2336, y = 328, z = 1587, rot = 0 , team = 1},
{name = 'armpw', x = 2368, y = 329, z = 1587, rot = 0 , team = 1},
{name = 'armpw', x = 2400, y = 330, z = 1587, rot = 0 , team = 1},
{name = 'armpw', x = 2432, y = 331, z = 1587, rot = 0 , team = 1},
{name = 'armpw', x = 2464, y = 332, z = 1587, rot = 0 , team = 1},
{name = 'armpw', x = 2496, y = 334, z = 1587, rot = 0 , team = 1},
{name = 'armpw', x = 2208, y = 327, z = 1619, rot = 0 , team = 1},
{name = 'armpw', x = 2240, y = 327, z = 1619, rot = 0 , team = 1},
{name = 'armpw', x = 2272, y = 327, z = 1619, rot = 0 , team = 1},
{name = 'armpw', x = 2304, y = 327, z = 1619, rot = 0 , team = 1},
{name = 'armpw', x = 2336, y = 328, z = 1619, rot = 0 , team = 1},
{name = 'armpw', x = 2368, y = 328, z = 1619, rot = 0 , team = 1},
{name = 'armpw', x = 2400, y = 329, z = 1619, rot = 0 , team = 1},
{name = 'armpw', x = 2432, y = 329, z = 1619, rot = 0 , team = 1},
{name = 'armpw', x = 2464, y = 329, z = 1619, rot = 0 , team = 1},
{name = 'armpw', x = 2496, y = 332, z = 1619, rot = 0 , team = 1},
{name = 'armpw', x = 2208, y = 327, z = 1651, rot = 0 , team = 1},
{name = 'armpw', x = 2240, y = 327, z = 1651, rot = 0 , team = 1},
{name = 'armpw', x = 2272, y = 327, z = 1651, rot = 0 , team = 1},
{name = 'armpw', x = 2304, y = 327, z = 1651, rot = 0 , team = 1},
{name = 'armpw', x = 2336, y = 327, z = 1651, rot = 0 , team = 1},
{name = 'armpw', x = 2368, y = 328, z = 1651, rot = 0 , team = 1},
{name = 'armpw', x = 2400, y = 326, z = 1651, rot = 0 , team = 1},
{name = 'armpw', x = 2432, y = 329, z = 1651, rot = 0 , team = 1},
{name = 'armpw', x = 2464, y = 330, z = 1651, rot = 0 , team = 1},
{name = 'armpw', x = 2496, y = 331, z = 1651, rot = 0 , team = 1},
{name = 'armpw', x = 2208, y = 326, z = 1683, rot = 0 , team = 1},
{name = 'armpw', x = 2240, y = 327, z = 1683, rot = 0 , team = 1},
{name = 'armpw', x = 2272, y = 327, z = 1683, rot = 0 , team = 1},
{name = 'armpw', x = 2304, y = 327, z = 1683, rot = 0 , team = 1},
{name = 'armpw', x = 2336, y = 326, z = 1683, rot = 0 , team = 1},
{name = 'armpw', x = 2368, y = 327, z = 1683, rot = 0 , team = 1},
{name = 'armpw', x = 2400, y = 327, z = 1683, rot = 0 , team = 1},
{name = 'armpw', x = 2432, y = 328, z = 1683, rot = 0 , team = 1},
{name = 'armpw', x = 2464, y = 328, z = 1683, rot = 0 , team = 1},
{name = 'armpw', x = 2496, y = 329, z = 1683, rot = 0 , team = 1},
{name = 'armpw', x = 2208, y = 325, z = 1715, rot = 0 , team = 1},
{name = 'armpw', x = 2240, y = 326, z = 1715, rot = 0 , team = 1},
{name = 'armpw', x = 2272, y = 327, z = 1715, rot = 0 , team = 1},
{name = 'armpw', x = 2304, y = 326, z = 1715, rot = 0 , team = 1},
{name = 'armpw', x = 2336, y = 326, z = 1715, rot = 0 , team = 1},
{name = 'armpw', x = 2368, y = 327, z = 1715, rot = 0 , team = 1},
{name = 'armpw', x = 2400, y = 327, z = 1715, rot = 0 , team = 1},
{name = 'armpw', x = 2432, y = 327, z = 1715, rot = 0 , team = 1},
{name = 'armpw', x = 2464, y = 328, z = 1715, rot = 0 , team = 1},
{name = 'armpw', x = 2496, y = 328, z = 1715, rot = 0 , team = 1},
{name = 'armpw', x = 2208, y = 325, z = 1747, rot = 0 , team = 1},
{name = 'armpw', x = 2240, y = 326, z = 1747, rot = 0 , team = 1},
{name = 'armpw', x = 2272, y = 326, z = 1747, rot = 0 , team = 1},
{name = 'armpw', x = 2304, y = 326, z = 1747, rot = 0 , team = 1},
{name = 'armpw', x = 2336, y = 326, z = 1747, rot = 0 , team = 1},
{name = 'armpw', x = 2368, y = 326, z = 1747, rot = 0 , team = 1},
{name = 'armpw', x = 2400, y = 327, z = 1747, rot = 0 , team = 1},
{name = 'armpw', x = 2432, y = 327, z = 1747, rot = 0 , team = 1},
{name = 'armpw', x = 2464, y = 328, z = 1747, rot = 0 , team = 1},
{name = 'armpw', x = 2496, y = 328, z = 1747, rot = 0 , team = 1},
{name = 'armflash', x = 3310, y = 595, z = 391, rot = 0 , team = 1},
{name = 'armflash', x = 3342, y = 593, z = 391, rot = 0 , team = 1},
{name = 'armflash', x = 3374, y = 592, z = 391, rot = 0 , team = 1},
{name = 'armflash', x = 3406, y = 594, z = 391, rot = 0 , team = 1},
{name = 'armflash', x = 3438, y = 593, z = 391, rot = 0 , team = 1},
{name = 'armflash', x = 3470, y = 594, z = 391, rot = 0 , team = 1},
{name = 'armflash', x = 3502, y = 593, z = 391, rot = 0 , team = 1},
{name = 'armflash', x = 3534, y = 592, z = 391, rot = 0 , team = 1},
{name = 'armflash', x = 3310, y = 595, z = 423, rot = 0 , team = 1},
{name = 'armflash', x = 3342, y = 594, z = 423, rot = 0 , team = 1},
{name = 'armflash', x = 3374, y = 592, z = 423, rot = 0 , team = 1},
{name = 'armflash', x = 3406, y = 593, z = 423, rot = 0 , team = 1},
{name = 'armflash', x = 3438, y = 593, z = 423, rot = 0 , team = 1},
{name = 'armflash', x = 3470, y = 593, z = 423, rot = 0 , team = 1},
{name = 'armflash', x = 3502, y = 593, z = 423, rot = 0 , team = 1},
{name = 'armflash', x = 3534, y = 592, z = 423, rot = 0 , team = 1},
{name = 'armflash', x = 3310, y = 595, z = 455, rot = 0 , team = 1},
{name = 'armflash', x = 3342, y = 594, z = 455, rot = 0 , team = 1},
{name = 'armflash', x = 3374, y = 593, z = 455, rot = 0 , team = 1},
{name = 'armflash', x = 3406, y = 593, z = 455, rot = 0 , team = 1},
{name = 'armflash', x = 3438, y = 593, z = 455, rot = 0 , team = 1},
{name = 'armflash', x = 3470, y = 593, z = 455, rot = 0 , team = 1},
{name = 'armflash', x = 3502, y = 593, z = 455, rot = 0 , team = 1},
{name = 'armflash', x = 3534, y = 593, z = 455, rot = 0 , team = 1},
{name = 'armflash', x = 3310, y = 594, z = 487, rot = 0 , team = 1},
{name = 'armflash', x = 3342, y = 593, z = 487, rot = 0 , team = 1},
{name = 'armflash', x = 3374, y = 593, z = 487, rot = 0 , team = 1},
{name = 'armflash', x = 3406, y = 593, z = 487, rot = 0 , team = 1},
{name = 'armflash', x = 3438, y = 593, z = 487, rot = 0 , team = 1},
{name = 'armflash', x = 3470, y = 593, z = 487, rot = 0 , team = 1},
{name = 'armflash', x = 3502, y = 594, z = 487, rot = 0 , team = 1},
{name = 'armflash', x = 3534, y = 593, z = 487, rot = 0 , team = 1},
{name = 'armflash', x = 3310, y = 594, z = 519, rot = 0 , team = 1},
{name = 'armflash', x = 3342, y = 593, z = 519, rot = 0 , team = 1},
{name = 'armflash', x = 3374, y = 592, z = 519, rot = 0 , team = 1},
{name = 'armflash', x = 3406, y = 593, z = 519, rot = 0 , team = 1},
{name = 'armflash', x = 3438, y = 593, z = 519, rot = 0 , team = 1},
{name = 'armflash', x = 3470, y = 593, z = 519, rot = 0 , team = 1},
{name = 'armflash', x = 3502, y = 594, z = 519, rot = 0 , team = 1},
{name = 'armflash', x = 3534, y = 594, z = 519, rot = 0 , team = 1},
{name = 'armflash', x = 3310, y = 593, z = 551, rot = 0 , team = 1},
{name = 'armflash', x = 3342, y = 593, z = 551, rot = 0 , team = 1},
{name = 'armflash', x = 3374, y = 593, z = 551, rot = 0 , team = 1},
{name = 'armflash', x = 3406, y = 593, z = 551, rot = 0 , team = 1},
{name = 'armflash', x = 3438, y = 593, z = 551, rot = 0 , team = 1},
{name = 'armflash', x = 3470, y = 593, z = 551, rot = 0 , team = 1},
{name = 'armflash', x = 3502, y = 594, z = 551, rot = 0 , team = 1},
{name = 'armflash', x = 3534, y = 593, z = 551, rot = 0 , team = 1},
{name = 'armflash', x = 3310, y = 593, z = 583, rot = 0 , team = 1},
{name = 'armflash', x = 3342, y = 593, z = 583, rot = 0 , team = 1},
{name = 'cornanotc', x = 3771, y = 321, z = 3614, rot = 0 , team = 0},
 
		},
		featureloadout = {
			-- Similarly to units, but these can also be resurrectable!
            -- You can /give corcom_dead with cheats when making your scenario, but it might not contain the 'resurrectas' tag, so be careful to add it if needed
			 -- {name = 'corcom_dead', x = 1125,y = 237, z = 734, rot = "0" , scale = 1.0, resurrectas = "corcom"}, -- there is no need for this dead comm here, just an example
            -- {name = 'armack_dead',  x = 1320,  y = 89,  z = 460,  rot = -928 , resurrectas = 'armack',  team = 0},

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

	startscript		= [[
[Game]
{
    [allyTeam0]
    {
        startrectright = 1;
        startrectbottom = 1;
        startrectleft = 0.76999998;
        startrecttop = 0.76999998;
        numallies = 0;
    }

    [team1]
    {
		Side = Armada;
        Handicap = __ENEMYHANDICAP__;
        Handicap = 0;
        RgbColor = 0.1 0.2 0.9;
        AllyTeam = 1;
        TeamLeader = 0;
    }

    [team0]
    {
        Side = __PLAYERSIDE__;
        Handicap = __PLAYERHANDICAP__;
        RgbColor = 0.9 0.2 0.1;
        AllyTeam = 0;
        TeamLeader = 0;
    }

    [modoptions]
    {
        deathmode = killall;
        scenariooptions = __SCENARIOOPTIONS__;
        startenergy = 7000;
    }

    [allyTeam1]
    {
        startrectright = 0.23;
        startrectbottom = 0.23;
        startrectleft = 0;
        startrecttop = 0;
        numallies = 0;
    }

    [ai0]
    {
        Host = 0;
        IsFromDemo = 0;
        Name = NullAI0.1(1);
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

return scenariodata

--[[
 [Game]
{
	[allyTeam0]
	{
		startrectright = 0.98892993;
		startrectbottom = 1;
		startrectleft = 0.7896679;
		numallies = 0;
		startrecttop = 0.80811805;
	}

	[team1]
	{
		Side = Armada;
		Handicap = 0;
		RgbColor = 0.59871912 0.25364691 0.36091965;
		AllyTeam = 1;
		TeamLeader = 0;
	}

	[team0]
	{
		Side = Cortex;
		Handicap = 0;
		RgbColor = 0.65360999 0.77162737 0.15025288;
		AllyTeam = 0;
		TeamLeader = 0;
	}

	[modoptions]
	{
	}

	[allyTeam1]
	{
		startrectright = 0.22509223;
		startrectbottom = 0.23247233;
		startrectleft = 0.02583026;
		numallies = 0;
		startrecttop = 0.03321033;
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
		Name = [teh]Behe_Chobby3;
		Team = 0;
		rank = 0;
	}

	hostip = 127.0.0.1;
	hostport = 0;
	numplayers = 1;
	startpostype = 2;
	mapname = Stronghold V4;
	ishost = 1;
	numusers = 2;
	gametype = Beyond All Reason test-15839-d0c313f;
	GameStartDelay = 5;
	myplayername = [teh]Behe_Chobby3;
	nohelperais = 0;
}

]]--
