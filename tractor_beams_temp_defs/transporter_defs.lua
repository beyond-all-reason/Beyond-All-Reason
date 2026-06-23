-- Tractor-beam transport unit defs, applied by alldefs_post when beta_tractorbeam is enabled.
-- Each transporter entry may contain top-level unitDef fields and a nested customparams table.
-- Non-listed transporters with transportcapacity get the generic defaults (script, model, etc.).
--
-- passengerSizes: per-unit raw transport weight, converted to (nseats, oversized) by alldefs_post.
-- Source: dood_suggested_setup/oversizetable.lua
-- Mapping rule: nseats = nearest lower power-of-2; oversized="1" if size = nseats*1.5; oversized="-1" if size = nseats*0.5

local DEFAULT_GENERIC_SCRIPT    = "units/generic_air_transport_lus.lua"
local DEFAULT_WEAPONIZED_SCRIPT = "units/weaponized_air_transport_lus.lua"

return {

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
		armcom        = { passengersize = 6 },
		armcomcon     = { passengersize = 6 },
		armcomlvl2    = { passengersize = 6 },
		armcomlvl3    = { passengersize = 6 },
		armcomlvl4    = { passengersize = 6 },
		armcomlvl5    = { passengersize = 6 },
		armcomlvl6    = { passengersize = 6 },
		armcomlvl7    = { passengersize = 6 },
		armcomlvl8    = { passengersize = 6 },
		armcomlvl9    = { passengersize = 6 },
		armcomlvl10   = { passengersize = 6 },
		armcomnew     = { passengersize = 6 },
		-- ARM Bots T1
		armck         = { passengersize = 2 },
		armflea       = { passengersize = 0.5 },
		armham        = { passengersize = 1.5 },
		armjeth       = { passengersize = 1.5 },
		armpw         = { passengersize = 1 },
		armrectr      = { passengersize = 1 },
		armrock       = { passengersize = 1.5 },
		armwar        = { passengersize = 2 },
		-- ARM Bots T2
		armaak        = { passengersize = 3 },   -- t2 aa bot
		armack        = { passengersize = 2 },   -- t2 con
		armamph       = { passengersize = 2 },   -- platy
		armaser       = { passengersize = 2 },
		armdecom      = { passengersize = 6 },   -- decoy com
		armdecomlvl3  = { passengersize = 6 },
		armdecomlvl6  = { passengersize = 6 },
		armdecomlvl10 = { passengersize = 6 },
		armfark       = { passengersize = 1 },   -- butler
		armfast       = { passengersize = 2 },   -- sprinter
		armfboy       = { passengersize = 6 },   -- fattie
		armfido       = { passengersize = 3 },   -- hound
		armhack       = { passengersize = 1 },
		armmark       = { passengersize = 2 },   -- radar bot
		armmav        = { passengersize = 3 },   -- maverick
		armsack       = { passengersize = 1 },
		armscab       = { passengersize = 6 },   -- mob anti
		armsnipe      = { passengersize = 3 },   -- sniper
		armspid       = { passengersize = 1.5 }, -- emp spider
		armsptk       = { passengersize = 4 },   -- rocker spider
		armspy        = { passengersize = 2 },   -- ghost
		armvader      = { passengersize = 1 },   -- crawling bomb
		armzeus       = { passengersize = 3 },   -- welder
		-- ARM Vehicles T1
		armart        = { passengersize = 2 },
		armbeaver     = { passengersize = 2 },   -- amphib con
		armcv         = { passengersize = 2 },
		armfav        = { passengersize = 0.5 },
		armflash      = { passengersize = 1.5 }, -- blitz
		armjanus      = { passengersize = 2 },
		armmlv        = { passengersize = 1 },   -- minelayer
		armpincer     = { passengersize = 2 },   -- amphib
		armsam        = { passengersize = 2 },
		armstump      = { passengersize = 2 },   -- stout
		-- ARM Vehicles T2
		armacv        = { passengersize = 3 },
		armbull       = { passengersize = 4 },
		armconsul     = { passengersize = 2 },
		armcroc       = { passengersize = 4 },   -- turtle
		armgremlin    = { passengersize = 2 },
		armhacv       = { passengersize = 4 },
		armjam        = { passengersize = 2 },
		armlatnk      = { passengersize = 2 },   -- jaguar
		armmanni      = { passengersize = 6 },   -- starlight
		armmart       = { passengersize = 4 },   -- luger/mauser
		armmerl       = { passengersize = 6 },
		armsacv       = { passengersize = 4 },
		armseer       = { passengersize = 2 },
		armyork       = { passengersize = 3 },   -- flak
		-- ARM Hovercraft
		armah         = { passengersize = 3 },
		armanac       = { passengersize = 3 },
		armch         = { passengersize = 2 },
		armmh         = { passengersize = 3 },
		armsh         = { passengersize = 1.5 },
		-- ARM Buildings
		armbeamer     = { passengersize = 4 },
		armllt        = { passengersize = 4 },
		armnanotc     = { passengersize = 2 },
		armnanotc2plat = { passengersize = 6 },
		armnanotct2   = { passengersize = 6 },
		armrad        = { passengersize = 4 },
		armrl         = { passengersize = 4 },
		-- ARM Assist Drone
		armassistdrone_land = { passengersize = 1 },
		-- COR Commanders
		corcom        = { passengersize = 6 },
		corcomcon     = { passengersize = 6 },
		corcomlvl2    = { passengersize = 6 },
		corcomlvl3    = { passengersize = 6 },
		corcomlvl4    = { passengersize = 6 },
		corcomlvl5    = { passengersize = 6 },
		corcomlvl6    = { passengersize = 6 },
		corcomlvl7    = { passengersize = 6 },
		corcomlvl8    = { passengersize = 6 },
		corcomlvl9    = { passengersize = 6 },
		corcomlvl10   = { passengersize = 6 },
		-- COR Bots T1
		corak         = { passengersize = 1 },   -- grunt
		corck         = { passengersize = 2 },
		corcrash      = { passengersize = 1.5 }, -- aa bot
		cornecro      = { passengersize = 1 },
		corstorm      = { passengersize = 1.5 },
		corthud       = { passengersize = 1.5 },
		-- COR Bots T2
		coraak        = { passengersize = 3 },
		corack        = { passengersize = 2 },
		coramph       = { passengersize = 3 },   -- duck
		corcan        = { passengersize = 3 },   -- sumo
		cordecom      = { passengersize = 6 },
		cordecomlvl3  = { passengersize = 6 },
		cordecomlvl6  = { passengersize = 6 },
		cordecomlvl10 = { passengersize = 6 },
		corfast       = { passengersize = 1 },   -- freaker
		corhack       = { passengersize = 1 },
		corhrk        = { passengersize = 3 },
		cormando      = { passengersize = 2 },   -- commando/paratrooper
		cormort       = { passengersize = 3 },   -- sheldon
		corpyro       = { passengersize = 2 },
		corroach      = { passengersize = 1 },
		corsack       = { passengersize = 1 },
		corsktl       = { passengersize = 1.5 }, -- skuttle
		corspec       = { passengersize = 2 },
		corspy        = { passengersize = 2 },   -- spectre
		corsumo       = { passengersize = 6 },   -- mammoth
		cortermite    = { passengersize = 4 },
		corvoyr       = { passengersize = 2 },
		-- COR Vehicles T1
		corcv         = { passengersize = 2 },
		corfav        = { passengersize = 0.5 },
		corgarp       = { passengersize = 2 },   -- amphib
		corgator      = { passengersize = 1.5 }, -- incisor
		corlevlr      = { passengersize = 2 },
		cormist       = { passengersize = 2 },
		cormlv        = { passengersize = 2 },   -- minelayer
		cormuskrat    = { passengersize = 2 },   -- amphib con
		corraid       = { passengersize = 2 },
		corwolv       = { passengersize = 2 },
		-- COR Vehicles T2
		coracv        = { passengersize = 2 },
		corban        = { passengersize = 4 },
		coreter       = { passengersize = 2 },
		corgol        = { passengersize = 6 },   -- tzar
		corhacv       = { passengersize = 4 },
		cormabm       = { passengersize = 6 },
		cormart       = { passengersize = 4 },
		corparrow     = { passengersize = 4 },
		corphantom    = { passengersize = 2 },
		corprinter    = { passengersize = 4 },
		correap       = { passengersize = 4 },
		corsacv       = { passengersize = 4 },
		corsala       = { passengersize = 4 },   -- salamander
		corseal       = { passengersize = 4 },   -- alligator
		corsent       = { passengersize = 4 },
		corsiegebreaker = { passengersize = 16 },
		cortrem       = { passengersize = 6 },
		corvac        = { passengersize = 3 },
		corvacct      = { passengersize = 3 },
		corvrad       = { passengersize = 2 },
		corvroc       = { passengersize = 6 },
		-- COR Hovercraft
		corah         = { passengersize = 3 },
		corch         = { passengersize = 2 },
		corhal        = { passengersize = 4 },
		cormh         = { passengersize = 3 },
		corsh         = { passengersize = 1.5 },
		corsnap       = { passengersize = 3 },
		-- COR Buildings
		corhllt       = { passengersize = 4 },
		corllt        = { passengersize = 4 },
		cornanotc     = { passengersize = 2 },
		cornanotc2plat = { passengersize = 6 },
		cornanotct2   = { passengersize = 6 },
		corrad        = { passengersize = 4 },
		corrl         = { passengersize = 4 },
		-- COR Assist Drone
		corassistdrone_land = { passengersize = 1 },
		-- HATs
		cor_hat_fightnight = { passengersize = 1 },
		cor_hat_hornet     = { passengersize = 1 },
		cor_hat_hw         = { passengersize = 1 },
		cor_hat_legfn      = { passengersize = 1 },
		cor_hat_ptaq       = { passengersize = 1 },
		cor_hat_viking     = { passengersize = 1 },
		-- Legion Commanders
		legcom        = { passengersize = 6 },
		legcomecon    = { passengersize = 1 },
		legcomoff     = { passengersize = 6 },
		legcomt2com   = { passengersize = 6 },
		legcomt2def   = { passengersize = 6 },
		legcomt2off   = { passengersize = 6 },
		legcomlvl2    = { passengersize = 6 },
		legcomlvl3    = { passengersize = 6 },
		legcomlvl4    = { passengersize = 6 },
		legcomlvl5    = { passengersize = 6 },
		legcomlvl6    = { passengersize = 6 },
		legcomlvl7    = { passengersize = 6 },
		legcomlvl8    = { passengersize = 6 },
		legcomlvl9    = { passengersize = 6 },
		legcomlvl10   = { passengersize = 6 },
		-- Legion Bots T1
		legaabot      = { passengersize = 1 },
		legbal        = { passengersize = 1 },
		legcen        = { passengersize = 1 },
		leggob        = { passengersize = 1 },
		legkark       = { passengersize = 1 },
		leglob        = { passengersize = 1 },
		legrezbot     = { passengersize = 1 },
		-- Legion Bots T2
		legadvaabot   = { passengersize = 1 },
		legajamk      = { passengersize = 1 },
		legamph       = { passengersize = 4 },
		legaradk      = { passengersize = 1 },
		legaspy       = { passengersize = 1 },
		legbart       = { passengersize = 4 },
		legdecom      = { passengersize = 6 },
		legdecomlvl3  = { passengersize = 6 },
		legdecomlvl6  = { passengersize = 6 },
		legdecomlvl10 = { passengersize = 6 },
		leghrk        = { passengersize = 4 },
		leginc        = { passengersize = 4 },
		leginfestor   = { passengersize = 4 },
		legshot       = { passengersize = 1 },
		legsnapper    = { passengersize = 1 },
		legsrail      = { passengersize = 4 },
		legstr        = { passengersize = 4 },
		-- Legion Vehicles T1
		legamphtank   = { passengersize = 4 },
		legbar        = { passengersize = 4 },
		leggat        = { passengersize = 4 },
		leghades      = { passengersize = 1 },
		leghelios     = { passengersize = 1 },
		legmlv        = { passengersize = 1 },
		legrail       = { passengersize = 4 },
		legscout      = { passengersize = 1 },
		-- Legion Vehicles T2
		legaheattank  = { passengersize = 4 },
		legamcluster  = { passengersize = 4 },
		legaskirmtank = { passengersize = 4 },
		legavantinuke = { passengersize = 4 },
		legavjam      = { passengersize = 4 },
		legavrad      = { passengersize = 4 },
		legavroc      = { passengersize = 4 },
		legfloat      = { passengersize = 4 },
		legfmg        = { passengersize = 4 },
		leginf        = { passengersize = 4 },
		legmed        = { passengersize = 4 },
		legmrv        = { passengersize = 1 },
		legvcarry     = { passengersize = 4 },
		legvflak      = { passengersize = 4 },
		-- Legion Hovercraft
		legah         = { passengersize = 4 },
		legcar        = { passengersize = 4 },
		legmh         = { passengersize = 4 },
		legner        = { passengersize = 4 },
		legsh         = { passengersize = 4 },
		-- Legion Ships
		leganavybattleship = { passengersize = 16 },
		-- Legion Constructors
		legack        = { passengersize = 1 },
		legaceb       = { passengersize = 1 },
		legacv        = { passengersize = 4 },
		legafcv       = { passengersize = 4 },
		legch         = { passengersize = 4 },
		legck         = { passengersize = 1 },
		legcv         = { passengersize = 4 },
		leghack       = { passengersize = 1 },
		leghacv       = { passengersize = 4 },
		legotter      = { passengersize = 4 },
		-- Legion Buildings
		leglht        = { passengersize = 1 },
		legmg         = { passengersize = 4 },
		legnanotc     = { passengersize = 4 },
		legnanotct2   = { passengersize = 4 },
		legnanotct2plat = { passengersize = 4 },
		legrad        = { passengersize = 1 },
		legrl         = { passengersize = 4 },
		-- Legion T3
		leegmech      = { passengersize = 4 },
		legerailtank  = { passengersize = 16 },
		legeshotgunmech = { passengersize = 4 },
		-- Legion Assist Drone
		legassistdrone_land = { passengersize = 1 },
		-- Baby Units
		babyleggob    = { passengersize = 1 },
		babyleglob    = { passengersize = 1 },
		babylegshotg  = { passengersize = 1 },
		-- Debug / Dummy
		dbg_sphere           = { passengersize = 1 },
		dbg_sphere_fullmetal = { passengersize = 1 },
		dummycom             = { passengersize = 6 },
	},
}
