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
-- transportercomspeedmodstrength = minimal amount of speed removal that kicks in as soon as a commander is loaded
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
		armap   = { "armatlas", "armhvytrans" },
		-- ARM T2 Air Plant
		armaap  = { "armdfly" },
		-- ARM Platform (no transports by default)
		armplat = {},
		-- COR T1 Air Plant
		corap   = { "corvalk", "corhvytrans" },
		-- COR T2 Air Plant
		coraap  = { "corseah" },
		-- COR Platform (no transports by default)
		corplat = {},
		-- Legion T1 Air Plant
		legap   = { "leglts", "legatrans" },
		-- Legion T2 Air Plant
		legaap  = { "legstronghold" },
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
			},
		},
		armatlas = {
			customparams = {
				loadtime            = 30,
				transporterseats    = 2,
				transportcegname    = "armada_ion",
			},
		},
		armhvytrans = {
			customparams = {
				loadtime            = 60,
				transporterseats    = 4,
				transportcegname    = "armada_ion",
			},
		},
		corseah = {
			customparams = {
				loadtime            = 90,
				transporterseats    = 6,
				transportcegname    = "cortex_grapple",
			},
		},
		corhvytrans = {
			customparams = {
				loadtime            = 60,
				transporterseats    = 4,
				transportcegname    = "cortex_grapple",
			},
		},
		corvalk = {
			customparams = {
				loadtime            = 30,
				transporterseats    = 2,
				transportcegname    = "cortex_grapple",
			},
		},
		legstronghold = {
			script = DEFAULT_WEAPONIZED_SCRIPT, -- has a weapon
			customparams = {
				loadtime            = 60,
				transporterseats    = 4,
				transportcegname    = "legion_grav_distort",
			},
		},
		legatrans = {
			customparams = {
				loadtime            = 60,
				transporterseats    = 4,
				transportcegname    = "legion_grav_distort",
			},
		},
		leglts = {
			customparams = {
				loadtime            = 30,
				transporterseats    = 2,
				transportcegname    = "legion_grav_distort",
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
	passengerSizes = {
		-- ARM Commanders
		armcom        = { passengercategory = 6 },
		armcomcon     = { passengercategory = 6 },
		armcomlvl2    = { passengercategory = 6 },
		armcomlvl3    = { passengercategory = 6 },
		armcomlvl4    = { passengercategory = 6 },
		armcomlvl5    = { passengercategory = 6 },
		armcomlvl6    = { passengercategory = 6 },
		armcomlvl7    = { passengercategory = 6 },
		armcomlvl8    = { passengercategory = 6 },
		armcomlvl9    = { passengercategory = 6 },
		armcomlvl10   = { passengercategory = 6 },
		armcomnew     = { passengercategory = 6 },
		-- ARM Bots T1
		armck         = { passengercategory = 2 },
		armflea       = { passengercategory = 0.5 },
		armham        = { passengercategory = 1.5 },
		armjeth       = { passengercategory = 1.5 },
		armpw         = { passengercategory = 1 },
		armrectr      = { passengercategory = 1 },
		armrock       = { passengercategory = 1.5 },
		armwar        = { passengercategory = 2 },
		-- ARM Bots T2
		armaak        = { passengercategory = 3 },   -- t2 aa bot
		armack        = { passengercategory = 2 },   -- t2 con
		armamph       = { passengercategory = 2 },   -- platy
		armaser       = { passengercategory = 2 },
		armdecom      = { passengercategory = 6 },   -- decoy com
		armdecomlvl3  = { passengercategory = 6 },
		armdecomlvl6  = { passengercategory = 6 },
		armdecomlvl10 = { passengercategory = 6 },
		armfark       = { passengercategory = 1 },   -- butler
		armfast       = { passengercategory = 2 },   -- sprinter
		armfboy       = { passengercategory = 6 },   -- fattie
		armfido       = { passengercategory = 3 },   -- hound
		armhack       = { passengercategory = 1 },
		armmark       = { passengercategory = 2 },   -- radar bot
		armmav        = { passengercategory = 3 },   -- maverick
		armsack       = { passengercategory = 1 },
		armscab       = { passengercategory = 6 },   -- mob anti
		armsnipe      = { passengercategory = 3 },   -- sniper
		armspid       = { passengercategory = 1.5 }, -- emp spider
		armsptk       = { passengercategory = 4 },   -- rocker spider
		armspy        = { passengercategory = 2 },   -- ghost
		armvader      = { passengercategory = 1 },   -- crawling bomb
		armzeus       = { passengercategory = 3 },   -- welder
		-- ARM Vehicles T1
		armart        = { passengercategory = 2 },
		armbeaver     = { passengercategory = 2 },   -- amphib con
		armcv         = { passengercategory = 2 },
		armfav        = { passengercategory = 0.5 },
		armflash      = { passengercategory = 1.5 }, -- blitz
		armjanus      = { passengercategory = 2 },
		armmlv        = { passengercategory = 1 },   -- minelayer
		armpincer     = { passengercategory = 2 },   -- amphib
		armsam        = { passengercategory = 2 },
		armstump      = { passengercategory = 2 },   -- stout
		-- ARM Vehicles T2
		armacv        = { passengercategory = 3 },
		armbull       = { passengercategory = 4 },
		armconsul     = { passengercategory = 2 },
		armcroc       = { passengercategory = 4 },   -- turtle
		armgremlin    = { passengercategory = 2 },
		armhacv       = { passengercategory = 4 },
		armjam        = { passengercategory = 2 },
		armlatnk      = { passengercategory = 2 },   -- jaguar
		armmanni      = { passengercategory = 6 },   -- starlight
		armmart       = { passengercategory = 4 },   -- luger/mauser
		armmerl       = { passengercategory = 6 },
		armsacv       = { passengercategory = 4 },
		armseer       = { passengercategory = 2 },
		armyork       = { passengercategory = 3 },   -- flak
		-- ARM Hovercraft
		armah         = { passengercategory = 3 },
		armanac       = { passengercategory = 3 },
		armch         = { passengercategory = 2 },
		armmh         = { passengercategory = 3 },
		armsh         = { passengercategory = 1.5 },
		-- ARM Buildings
		armbeamer     = { passengercategory = 4 },
		armllt        = { passengercategory = 4 },
		armnanotc     = { passengercategory = 2 },
		armnanotc2plat = { passengercategory = 6 },
		armnanotct2   = { passengercategory = 6 },
		armrad        = { passengercategory = 4 },
		armrl         = { passengercategory = 4 },
		-- ARM Assist Drone
		armassistdrone_land = { passengercategory = 1 },
		-- COR Commanders
		corcom        = { passengercategory = 6 },
		corcomcon     = { passengercategory = 6 },
		corcomlvl2    = { passengercategory = 6 },
		corcomlvl3    = { passengercategory = 6 },
		corcomlvl4    = { passengercategory = 6 },
		corcomlvl5    = { passengercategory = 6 },
		corcomlvl6    = { passengercategory = 6 },
		corcomlvl7    = { passengercategory = 6 },
		corcomlvl8    = { passengercategory = 6 },
		corcomlvl9    = { passengercategory = 6 },
		corcomlvl10   = { passengercategory = 6 },
		-- COR Bots T1
		corak         = { passengercategory = 1 },   -- grunt
		corck         = { passengercategory = 2 },
		corcrash      = { passengercategory = 1.5 }, -- aa bot
		cornecro      = { passengercategory = 1 },
		corstorm      = { passengercategory = 1.5 },
		corthud       = { passengercategory = 1.5 },
		-- COR Bots T2
		coraak        = { passengercategory = 3 },
		corack        = { passengercategory = 2 },
		coramph       = { passengercategory = 3 },   -- duck
		corcan        = { passengercategory = 3 },   -- sumo
		cordecom      = { passengercategory = 6 },
		cordecomlvl3  = { passengercategory = 6 },
		cordecomlvl6  = { passengercategory = 6 },
		cordecomlvl10 = { passengercategory = 6 },
		corfast       = { passengercategory = 1 },   -- freaker
		corhack       = { passengercategory = 1 },
		corhrk        = { passengercategory = 3 },
		cormando      = { passengercategory = 2 },   -- commando/paratrooper
		cormort       = { passengercategory = 3 },   -- sheldon
		corpyro       = { passengercategory = 2 },
		corroach      = { passengercategory = 1 },
		corsack       = { passengercategory = 1 },
		corsktl       = { passengercategory = 1.5 }, -- skuttle
		corspec       = { passengercategory = 2 },
		corspy        = { passengercategory = 2 },   -- spectre
		corsumo       = { passengercategory = 6 },   -- mammoth
		cortermite    = { passengercategory = 4 },
		corvoyr       = { passengercategory = 2 },
		-- COR Vehicles T1
		corcv         = { passengercategory = 2 },
		corfav        = { passengercategory = 0.5 },
		corgarp       = { passengercategory = 2 },   -- amphib
		corgator      = { passengercategory = 1.5 }, -- incisor
		corlevlr      = { passengercategory = 2 },
		cormist       = { passengercategory = 2 },
		cormlv        = { passengercategory = 2 },   -- minelayer
		cormuskrat    = { passengercategory = 2 },   -- amphib con
		corraid       = { passengercategory = 2 },
		corwolv       = { passengercategory = 2 },
		-- COR Vehicles T2
		coracv        = { passengercategory = 2 },
		corban        = { passengercategory = 4 },
		coreter       = { passengercategory = 2 },
		corgol        = { passengercategory = 6 },   -- tzar
		corhacv       = { passengercategory = 4 },
		cormabm       = { passengercategory = 6 },
		cormart       = { passengercategory = 4 },
		corparrow     = { passengercategory = 4 },
		corphantom    = { passengercategory = 2 },
		corprinter    = { passengercategory = 4 },
		correap       = { passengercategory = 4 },
		corsacv       = { passengercategory = 4 },
		corsala       = { passengercategory = 4 },   -- salamander
		corseal       = { passengercategory = 4 },   -- alligator
		corsent       = { passengercategory = 4 },
		corsiegebreaker = { passengercategory = 16 },
		cortrem       = { passengercategory = 6 },
		corvac        = { passengercategory = 3 },
		corvacct      = { passengercategory = 3 },
		corvrad       = { passengercategory = 2 },
		corvroc       = { passengercategory = 6 },
		-- COR Hovercraft
		corah         = { passengercategory = 3 },
		corch         = { passengercategory = 2 },
		corhal        = { passengercategory = 4 },
		cormh         = { passengercategory = 3 },
		corsh         = { passengercategory = 1.5 },
		corsnap       = { passengercategory = 3 },
		-- COR Buildings
		corhllt       = { passengercategory = 4 },
		corllt        = { passengercategory = 4 },
		cornanotc     = { passengercategory = 2 },
		cornanotc2plat = { passengercategory = 6 },
		cornanotct2   = { passengercategory = 6 },
		corrad        = { passengercategory = 4 },
		corrl         = { passengercategory = 4 },
		-- COR Assist Drone
		corassistdrone_land = { passengercategory = 1 },
		-- HATs
		cor_hat_fightnight = { passengercategory = 1 },
		cor_hat_hornet     = { passengercategory = 1 },
		cor_hat_hw         = { passengercategory = 1 },
		cor_hat_legfn      = { passengercategory = 1 },
		cor_hat_ptaq       = { passengercategory = 1 },
		cor_hat_viking     = { passengercategory = 1 },
		-- Legion Commanders
		legcom        = { passengercategory = 6 },
		legcomecon    = { passengercategory = 1 },
		legcomoff     = { passengercategory = 6 },
		legcomt2com   = { passengercategory = 6 },
		legcomt2def   = { passengercategory = 6 },
		legcomt2off   = { passengercategory = 6 },
		legcomlvl2    = { passengercategory = 6 },
		legcomlvl3    = { passengercategory = 6 },
		legcomlvl4    = { passengercategory = 6 },
		legcomlvl5    = { passengercategory = 6 },
		legcomlvl6    = { passengercategory = 6 },
		legcomlvl7    = { passengercategory = 6 },
		legcomlvl8    = { passengercategory = 6 },
		legcomlvl9    = { passengercategory = 6 },
		legcomlvl10   = { passengercategory = 6 },
		-- Legion Bots T1
		legaabot      = { passengercategory = 1 },
		legbal        = { passengercategory = 1 },
		legcen        = { passengercategory = 1 },
		leggob        = { passengercategory = 1 },
		legkark       = { passengercategory = 1 },
		leglob        = { passengercategory = 1 },
		legrezbot     = { passengercategory = 1 },
		-- Legion Bots T2
		legadvaabot   = { passengercategory = 1 },
		legajamk      = { passengercategory = 1 },
		legamph       = { passengercategory = 4 },
		legaradk      = { passengercategory = 1 },
		legaspy       = { passengercategory = 1 },
		legbart       = { passengercategory = 4 },
		legdecom      = { passengercategory = 6 },
		legdecomlvl3  = { passengercategory = 6 },
		legdecomlvl6  = { passengercategory = 6 },
		legdecomlvl10 = { passengercategory = 6 },
		leghrk        = { passengercategory = 4 },
		leginc        = { passengercategory = 4 },
		leginfestor   = { passengercategory = 4 },
		legshot       = { passengercategory = 1 },
		legsnapper    = { passengercategory = 1 },
		legsrail      = { passengercategory = 4 },
		legstr        = { passengercategory = 4 },
		-- Legion Vehicles T1
		legamphtank   = { passengercategory = 4 },
		legbar        = { passengercategory = 4 },
		leggat        = { passengercategory = 4 },
		leghades      = { passengercategory = 1 },
		leghelios     = { passengercategory = 1 },
		legmlv        = { passengercategory = 1 },
		legrail       = { passengercategory = 4 },
		legscout      = { passengercategory = 1 },
		-- Legion Vehicles T2
		legaheattank  = { passengercategory = 4 },
		legamcluster  = { passengercategory = 4 },
		legaskirmtank = { passengercategory = 4 },
		legavantinuke = { passengercategory = 4 },
		legavjam      = { passengercategory = 4 },
		legavrad      = { passengercategory = 4 },
		legavroc      = { passengercategory = 4 },
		legfloat      = { passengercategory = 4 },
		legfmg        = { passengercategory = 4 },
		leginf        = { passengercategory = 4 },
		legmed        = { passengercategory = 4 },
		legmrv        = { passengercategory = 1 },
		legvcarry     = { passengercategory = 4 },
		legvflak      = { passengercategory = 4 },
		-- Legion Hovercraft
		legah         = { passengercategory = 4 },
		legcar        = { passengercategory = 4 },
		legmh         = { passengercategory = 4 },
		legner        = { passengercategory = 4 },
		legsh         = { passengercategory = 4 },
		-- Legion Ships
		leganavybattleship = { passengercategory = 16 },
		-- Legion Constructors
		legack        = { passengercategory = 1 },
		legaceb       = { passengercategory = 1 },
		legacv        = { passengercategory = 4 },
		legafcv       = { passengercategory = 4 },
		legch         = { passengercategory = 4 },
		legck         = { passengercategory = 1 },
		legcv         = { passengercategory = 4 },
		leghack       = { passengercategory = 1 },
		leghacv       = { passengercategory = 4 },
		legotter      = { passengercategory = 4 },
		-- Legion Buildings
		leglht        = { passengercategory = 1 },
		legmg         = { passengercategory = 4 },
		legnanotc     = { passengercategory = 4 },
		legnanotct2   = { passengercategory = 4 },
		legnanotct2plat = { passengercategory = 4 },
		legrad        = { passengercategory = 1 },
		legrl         = { passengercategory = 4 },
		-- Legion T3
		leegmech      = { passengercategory = 4 },
		legerailtank  = { passengercategory = 16 },
		legeshotgunmech = { passengercategory = 4 },
		-- Legion Assist Drone
		legassistdrone_land = { passengercategory = 1 },
		-- Baby Units
		babyleggob    = { passengercategory = 1 },
		babyleglob    = { passengercategory = 1 },
		babylegshotg  = { passengercategory = 1 },
		-- Debug / Dummy
		dbg_sphere           = { passengercategory = 1 },
		dbg_sphere_fullmetal = { passengercategory = 1 },
		dummycom             = { passengercategory = 6 },
	},
}

