--

-- Tractor-beam transport unit defs, applied by alldefs_post when beta_tractorbeam is enabled.
-- Each transporter entry may contain top-level unitDef fields and a nested customparams table.
-- Non-listed transporters with transportcapacity get the generic defaults (script, model, etc.).
--
-- passengerCategories: per-unit passenger category sizes, used to compute nseats and oversized tag for each unitDef.
-- Source: dood_suggested_setup/oversizetable.lua
-- The transports have power of two sized slots; a transporter of size = k will always have 
-- any combination of (2^n) sizes possible (ie size = 5 can be 4+1, 2+2+1, 2+1+1+1, 1+1+1+1+1)
-- GDT asked for 3 categories of units: S, M, L (+untransportable)
-- I'm subdividing this into Tiny, Very-Light, Light, Medium-Light, Medium-Heavy, Heavy, Very-Heavy, Commanders (+untransportable)
-- because even as a "no-op" the disctinction seems intuitive for ticks vs pawns, or mammoth vs bull...

-- SMALL: nSeats = 1 -> one seat inside transport
	-- Tiny (category 0.5)= 1 + undersized tag: counts as 0.5 weight
	-- Very Light (category 1) = 1 / no tag: counts as 1 weight
	-- Light (category 1.5) = 1 + oversized: counts as 1.5 weight
-- MEDIUM: nSeats = 2 -> two seats inside transport
	-- Medium Light (category 2) = 2 / no tag: counts as 2 weight
	-- Medium Heavy (category 3) = 2 + oversized: counts as 3 weight
-- LARGE: nSeats = 4 -> four seats inside transport
	-- Heavy (category 4) = 4 / no tag: counts as 4 weight
	-- Very Heavy (category 6) = 4 + oversized: counts as 6 weight
    -- Commanders: nSeats = 4 -> four seats inside transport; counts as 6 weight + special case of triggering at least the "commander loaded" speed nerf
-- UNTRANSPORTABLE...
-- the concept of weight DOES NOT apply on transportability, but can be used to compute various types of nerfs (ie. speed)

-- 3 additional tags are available per unitDef:
-- transporterspeedmodmode = 
	-- 0: no speed nerf, default value; 
	-- 1: apply a (1 - (usedSeats/transporterSeats) * transporterspeedmodstrength) modifier to the transporter speed, acc rate, turn rate, cruise alt
	-- 2: apply a (1 - ((usedWeight - transporterSeats)/(0.5 * transporterSeats) * transporterspeedmodstrength
-- transporterspeedmodstrength = amount of speed removed from the transport (ratio) depending on speedmodmode
-- transportercomspeedmodstrength = minimal amount of speed removal that kicks in as soon as a commander is loaded (finalspeedMod = math.min(speedMod, comSpeedMod))
-- Unless transporterSpeedModMode is set to 2, the previous "subcategories" are just équivalent to the S, M, L categories they belong to

-- For a 4 seats transport, holding a very heavy unit, "speedmodmode = 2", "speedmodstrength = 0.3"
	-- speedMod = 1-(((6 - 4)/(0.5 * 4))*0.3) = 0.7
-- same case but within a 6 seats transport:
	-- speedMod = 1 - ((( 6 - 6 ) / (0.5 * 6)) * 0.3 = 0.0
-- this time a tiny + 2 light + 1 mediumheavy + 1 very light:
	-- total weight = 0.5 + 3 + 3 + 1 = 7.5
	-- speedMod = 1 - ((( 7.5 - 6 ) / (0.5 * 6)) * 0.3 = 0.85


local DEFAULT_GENERIC_SCRIPT    = "units/generic_air_transport_lus.lua"
local DEFAULT_WEAPONIZED_SCRIPT = "units/weaponized_air_transport_lus.lua"

return {
	-- Gadget settings
	-- customizable constants for the gadget.
	ALLOW_ENEMY_LOAD_MODE = 2, 	-- Stunned only
	LOAD_RADIUS = 128,			-- elmos XZ; transporter must be within this range to fire PerformLoad
	UNLOAD_RADIUS = 32, 		-- elmos XZ; transporter must be within this range to fire PerformUnload

    -- -------------------------------------------------------------------------
	-- LAB BUILDOPTIONS
	-- Per-factory explicit list of transports when beta_tractorbeam is active.
	-- All known transporters are stripped from the factory's buildoptions first,
	-- then only the ones listed here are re-added in order.
	-- A factory not listed here is left completely untouched.
	-- An empty list {} removes all transports from that factory.
	-- -------------------------------------------------------------------------
	labBuildoptions = {
		-- ARM T1 Air Plant
		armap                 = { "armatlas", "armhvytrans" },  -- Aircraft Plant | Produces Tech 1 Aircraft
		-- ARM T2 Air Plant
		armaap                = { "armdfly" },               -- Advanced Aircraft Plant | Produces Tech 2 Aircraft
		-- ARM Platform (no transports by default)
		armplat               = {},                          -- Seaplane Platform | Builds Seaplanes
		-- COR T1 Air Plant
		corap                 = { "corvalk", "corhvytrans" },  -- Aircraft Plant | Produces Tech 1 Aircraft
		-- COR T2 Air Plant
		coraap                = { "corseah" },               -- Advanced Aircraft Plant | Produces Tech 2 Aircraft
		-- COR Platform (no transports by default)
		corplat               = {},                          -- Seaplane Platform | Builds Seaplanes
		-- Legion T1 Air Plant
		legap                 = { "leglts", "legatrans" },   -- Legion Drone Plant | Drone Plant
		-- Legion T2 Air Plant
		legaap                = { "legstronghold" },         -- Legion Advanced Aircraft Plant | Advanced Aircraft Plant
	},

	-- -------------------------------------------------------------------------
	-- TRANSPORTER DEFAULTS
	-- Fields applied to every unit in the transporters table before per-unit
	-- overrides are merged in.  objectname is computed in alldefs_post since it
	-- depends on the unit name at runtime.
	-- -------------------------------------------------------------------------
	transporterDefaults = {
		transportcapacity     = 1000,
		transportsize         = 1000,
		transportunloadmethod = 0,
		transportmass         = 100000,
		holdsteady            = true,
		releaseheld           = true,
		loadingRadius         = 512,
		unloadSpread          = 0,
		script                = DEFAULT_GENERIC_SCRIPT,
	},

	-- -------------------------------------------------------------------------
	-- TRANSPORTERS
	-- Per-unit overrides applied on top of the generic beta_tractorbeam block.
	-- Fields at root level override top-level unitDef fields.
	-- Fields inside customparams{} are merged into uDef.customparams.
	-- -------------------------------------------------------------------------
	transporters = {
		armdfly = {
			script = DEFAULT_WEAPONIZED_SCRIPT, -- has a weapon
			customparams = {
				loadtime            = 60,
				transporterseats    = 4,
				transportcegname    = "armada_ion",
				transportercomspeedmodstrength = 0.33,
			},
		},
		armatlas = {
			customparams = {
				loadtime            = 30,
				transporterseats    = 1,
				transportcegname    = "armada_ion",
				transportercomspeedmodstrength = 0,
			},
		},
		armhvytrans = {
			customparams = {
				loadtime            = 60,
				transporterseats    = 4,
				transportcegname    = "armada_ion",
				transportercomspeedmodstrength = 0,
			},
		},
		corseah = {
			customparams = {
				loadtime            = 60,
				transporterseats    = 4,
				transportcegname    = "cortex_grapple",
				transportercomspeedmodstrength = 0.33,
			},
		},
		corhvytrans = {
			customparams = {
				loadtime            = 60,
				transporterseats    = 4,
				transportcegname    = "cortex_grapple",
				transportercomspeedmodstrength = 0,
			},
		},
		corvalk = {
			customparams = {
				loadtime            = 30,
				transporterseats    = 1,
				transportcegname    = "cortex_grapple",
				transportercomspeedmodstrength = 0,
			},
		},
		legstronghold = {
			script = DEFAULT_WEAPONIZED_SCRIPT, -- has a weapon
			customparams = {
				loadtime            = 60,
				transporterseats    = 4,
				transportcegname    = "legion_grav_distort",
				transportercomspeedmodstrength = 0.33,
			},
		},
		legatrans = {
			customparams = {
				loadtime            = 60,
				transporterseats    = 4,
				transportcegname    = "legion_grav_distort",
				transportercomspeedmodstrength = 0,
			},
		},
		leglts = {
			customparams = {
				loadtime            = 30,
				transporterseats    = 1,
				transportcegname    = "legion_grav_distort",
				transportercomspeedmodstrength = 0,
			},
		},
	},

	-- -------------------------------------------------------------------------
	-- PASSENGER SIZES
	-- Raw float size per unit.  alldefs_post converts these to integer nseats
	-- (nearest lower power-of-2) and sets customparams.oversized = "1" (1.5×)
	-- or oversized = "-1" (0.5×) when the raw size is not an exact power-of-2.
	-- Source: dood_suggested_setup/oversizetable.lua
	-- -------------------------------------------------------------------------
	passengerSizes = { -- none in the vanilla settings: purely weight based
	}
}

