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
		-- ARM Commanders -- Large; Commanders
		armcom                = { passengercategory = 6 },   -- Armada Commander | Commander
		armcomcon             = { passengercategory = 6 },
		armcomlvl2            = { passengercategory = 6 },   -- Armada Commander Level 2 | Commander
		armcomlvl3            = { passengercategory = 6 },   -- Armada Commander Level 3 | Defensive specialist that shares experience with turrets
		armcomlvl4            = { passengercategory = 6 },   -- Armada Commander Level 4 | Defensive specialist that shares experience with turrets
		armcomlvl5            = { passengercategory = 6 },   -- Armada Commander Level 5 | Defensive specialist that shares experience with turrets
		armcomlvl6            = { passengercategory = 6 },   -- Armada Commander Level 6 | Defensive specialist that shares experience with turrets
		armcomlvl7            = { passengercategory = 6 },   -- Armada Commander Level 7 | Defensive specialist that shares experience with turrets
		armcomlvl8            = { passengercategory = 6 },   -- Armada Commander Level 8 | Defensive specialist that shares experience with turrets
		armcomlvl9            = { passengercategory = 6 },   -- Armada Commander Level 9 | Defensive specialist that shares experience with turrets
		armcomlvl10           = { passengercategory = 6 },   -- Armada Commander Level 10 | Defensive specialist that shares experience with turrets
		armcomnew             = { passengercategory = 6 },
		-- ARM Bots T1
		armck                 = { passengercategory = 2 },   -- Construction Bot | Tech 1 Constructor
		armflea               = { passengercategory = 0.5 }, -- Tick | Fast Scout Bot
		armham                = { passengercategory = 1.5 }, -- Mace | Light Plasma Bot
		armjeth               = { passengercategory = 1.5 }, -- Crossbow | Amphibious Anti-air Bot
		armpw                 = { passengercategory = 1 },   -- Pawn | Fast Infantry Bot
		armrectr              = { passengercategory = 1 },   -- Lazarus | Stealthy Rez / Repair / Reclaim Bot
		armrock               = { passengercategory = 1.5 }, -- Rocketeer | Rocket Bot - good vs. static defenses
		armwar                = { passengercategory = 2 },   -- Centurion | Anti-Swarm Bot
		-- ARM Bots T2
		armaak                = { passengercategory = 3 },   -- Archangel | Advanced Amphibious Anti-Air Bot
		armack                = { passengercategory = 2 },   -- Advanced Construction Bot | Tech 2 Constructor
		armamph               = { passengercategory = 2 },   -- Platypus | Amphibious Bot
		armaser               = { passengercategory = 2 },   -- Smuggler | Radar Jammer Bot
		armdecom              = { passengercategory = 6 },   -- Commander | Decoy Commander
		armdecomlvl3          = { passengercategory = 6 },
		armdecomlvl6          = { passengercategory = 6 },
		armdecomlvl10         = { passengercategory = 6 },
		armfark               = { passengercategory = 1 },   -- Butler | Fast Assist / Repair Bot
		armfast               = { passengercategory = 2 },   -- Sprinter | Fast Raider Bot
		armfboy               = { passengercategory = 6 },   -- Fatboy | Heavy Plasma Bot
		armfido               = { passengercategory = 3 },   -- Hound | Mortar / Skirmish Bot
		armhack               = { passengercategory = 1 },   -- Butler | Experimental Combat Engineer
		armmark               = { passengercategory = 2 },   -- Compass | Radar Bot
		armmav                = { passengercategory = 3 },   -- Gunslinger | Skirmish Bot. Auto-Repair. Range increases with experience
		armsack               = { passengercategory = 1 },
		armscab               = { passengercategory = 6 },   -- Umbrella | Mobile All-Terrain Anti-Nuke
		armsnipe              = { passengercategory = 3 },   -- Sharpshooter | Sniper Bot
		armspid               = { passengercategory = 1.5 }, -- Webber | All-Terrain EMP and Reclaiming Spider
		armsptk               = { passengercategory = 4 },   -- Recluse | All-Terrain Rocket Spider
		armspy                = { passengercategory = 2 },   -- Ghost | Radar-Invisible Spy Bot
		armvader              = { passengercategory = 1 },   -- Tumbleweed | Amphibious Rolling Bomb
		armzeus               = { passengercategory = 3 },   -- Welder | Assault Bot
		-- ARM Vehicles T1
		armart                = { passengercategory = 2 },   -- Shellshocker | Light Artillery Vehicle
		armbeaver             = { passengercategory = 2 },   -- Beaver | Amphibious Construction Vehicle
		armcv                 = { passengercategory = 2 },   -- Construction Vehicle | Tech 1 Constructor
		armfav                = { passengercategory = 0.5 }, -- Rover | Light Scout Vehicle
		armflash              = { passengercategory = 1.5 }, -- Blitz | Fast Assault Tank
		armjanus              = { passengercategory = 2 },   -- Janus | Twin Medium Rocket Launcher
		armmlv                = { passengercategory = 1 },   -- Groundhog | Stealthy Minelayer / Minesweeper
		armpincer             = { passengercategory = 2 },   -- Pincer | Light Amphibious Tank
		armsam                = { passengercategory = 2 },   -- Whistler | Missile Truck
		armstump              = { passengercategory = 2 },   -- Stout | Medium Assault Tank
		-- ARM Vehicles T2
		armacv                = { passengercategory = 3 },   -- Advanced Construction Vehicle | Tech 2 Constructor
		armbull               = { passengercategory = 4 },   -- Bull | Heavy Assault Tank
		armconsul             = { passengercategory = 2 },   -- Consul | Combat Engineer
		armcroc               = { passengercategory = 4 },   -- Turtle | Heavy Amphibious Tank
		armgremlin            = { passengercategory = 2 },   -- Gremlin | Stealth Tank
		armhacv               = { passengercategory = 4 },   -- Consul | Experimental Combat Engineer
		armjam                = { passengercategory = 2 },   -- Umbra | Radar Jammer Vehicle
		armlatnk              = { passengercategory = 2 },   -- Jaguar | Lightning Tank
		armmanni              = { passengercategory = 6 },   -- Starlight | Mobile Tachyon Weapon
		armmart               = { passengercategory = 4 },   -- Mauser | Mobile Artillery
		armmerl               = { passengercategory = 6 },   -- Ambassador | Stealthy Rocket Launcher - good vs. static defense
		armsacv               = { passengercategory = 4 },
		armseer               = { passengercategory = 2 },   -- Prophet | Radar Vehicle
		armyork               = { passengercategory = 3 },   -- Shredder | Anti-Air Flak Vehicle
		-- ARM Hovercraft
		armah                 = { passengercategory = 3 },   -- Sweeper | Anti-Air Hovercraft
		armanac               = { passengercategory = 3 },   -- Crocodile | Hovertank
		armch                 = { passengercategory = 2 },   -- Construction Hovercraft | Tech 1 Constructor
		armmh                 = { passengercategory = 3 },   -- Possum | Hovercraft Rocket Launcher
		armsh                 = { passengercategory = 1.5 }, -- Seeker | Fast Attack Hovercraft
		-- ARM Buildings
		armbeamer             = { passengercategory = 4 },   -- Beamer | Beam Laser Turret
		armllt                = { passengercategory = 4 },   -- Sentry | Light Laser Tower
		armnanotc             = { passengercategory = 2 },   -- Construction Turret | Assist & Repair in large radius
		armnanotc2plat        = { passengercategory = 6 },   -- Advanced Construction Turret | Assist & Repair in larger radius
		armnanotct2           = { passengercategory = 6 },   -- Advanced Construction Turret | Assist & Repair in larger radius
		armrad                = { passengercategory = 4 },   -- Radar Tower | Early Warning System
		armrl                 = { passengercategory = 4 },   -- Nettle | Light Anti-air Tower
		-- ARM Assist Drone
		armassistdrone_land   = { passengercategory = 1 },   -- Assist Vehicle | Portable Buildpower
		-- COR Commanders
		corcom                = { passengercategory = 6 },   -- Cortex Commander | Commander
		corcomcon             = { passengercategory = 6 },
		corcomlvl2            = { passengercategory = 6 },   -- Cortex Commander Level 2 | Commander
		corcomlvl3            = { passengercategory = 6 },   -- Cortex Commander Level 3 | Specialized in frontline warfare
		corcomlvl4            = { passengercategory = 6 },   -- Cortex Commander Level 4 | Specialized in frontline warfare
		corcomlvl5            = { passengercategory = 6 },   -- Cortex Commander Level 5 | Specialized in frontline warfare
		corcomlvl6            = { passengercategory = 6 },   -- Cortex Commander Level 6 | Specialized in frontline warfare
		corcomlvl7            = { passengercategory = 6 },   -- Cortex Commander Level 7 | Specialized in frontline warfare
		corcomlvl8            = { passengercategory = 6 },   -- Cortex Commander Level 8 | Specialized in frontline warfare
		corcomlvl9            = { passengercategory = 6 },   -- Cortex Commander Level 9 | Specialized in frontline warfare
		corcomlvl10           = { passengercategory = 6 },   -- Cortex Commander Level 10 | Specialized in frontline warfare
		-- COR Bots T1
		corak                 = { passengercategory = 1 },   -- Grunt | Fast Infantry Bot
		corck                 = { passengercategory = 2 },   -- Construction Bot | Tech 1 Constructor
		corcrash              = { passengercategory = 1.5 }, -- Trasher | Amphibious Anti-air Bot
		cornecro              = { passengercategory = 1 },   -- Graverobber | Stealthy Rez / Reclaim / Repair Bot
		corstorm              = { passengercategory = 1.5 }, -- Aggravator | Rocket Bot - good vs. static defenses
		corthud               = { passengercategory = 1.5 }, -- Thug | Light Plasma Bot
		-- COR Bots T2
		coraak                = { passengercategory = 3 },   -- Manticore | Heavy Amphibious Anti-Air Bot
		corack                = { passengercategory = 2 },   -- Advanced Construction Bot | Tech 2 Constructor
		coramph               = { passengercategory = 3 },   -- Duck | Amphibious Bot
		corcan                = { passengercategory = 3 },   -- Sumo | Armored Assault Bot
		cordecom              = { passengercategory = 6 },   -- Commander | Decoy Commander
		cordecomlvl3          = { passengercategory = 6 },
		cordecomlvl6          = { passengercategory = 6 },
		cordecomlvl10         = { passengercategory = 6 },
		corfast               = { passengercategory = 1 },   -- Twitcher | Combat Engineer
		corhack               = { passengercategory = 1 },   -- Twitcher | Experimental Combat Engineer
		corhrk                = { passengercategory = 3 },   -- Arbiter | Heavy Rocket Bot
		cormando              = { passengercategory = 2 },   -- Commando | Stealthy Paratrooper Bot
		cormort               = { passengercategory = 3 },   -- Sheldon | Mobile Mortar Bot
		corpyro               = { passengercategory = 2 },   -- Fiend | Fast Assault Bot
		corroach              = { passengercategory = 1 },   -- Bedbug | Amphibious Crawling Bomb
		corsack               = { passengercategory = 1 },
		corsktl               = { passengercategory = 1.5 }, -- Skuttle | Advanced Amphibious Crawling Bomb
		corspec               = { passengercategory = 2 },   -- Deceiver | Radar Jammer Bot
		corspy                = { passengercategory = 2 },   -- Spectre | Radar-Invisible Spy Bot
		corsumo               = { passengercategory = 6 },   -- Mammoth | Heavily Armored Assault Bot
		cortermite            = { passengercategory = 4 },   -- Termite | Heavy All-terrain Assault Spider
		corvoyr               = { passengercategory = 2 },   -- Augur | Radar Bot
		-- COR Vehicles T1
		corcv                 = { passengercategory = 2 },   -- Construction Vehicle | Tech 1 Constructor
		corfav                = { passengercategory = 0.5 }, -- Rascal | Light Scout Vehicle
		corgarp               = { passengercategory = 2 },   -- Garpike | Light Amphibious Tank
		corgator              = { passengercategory = 1.5 }, -- Incisor | Light Tank
		corlevlr              = { passengercategory = 2 },   -- Pounder | Anti-Swarm Tank
		cormist               = { passengercategory = 2 },   -- Lasher | Missile Truck
		cormlv                = { passengercategory = 2 },   -- Trapper | Stealthy Minelayer / Minesweeper
		cormuskrat            = { passengercategory = 2 },   -- Muskrat | Amphibious Construction Vehicle
		corraid               = { passengercategory = 2 },   -- Brute | Medium Assault Tank
		corwolv               = { passengercategory = 2 },   -- Wolverine | Light Mobile Artillery
		-- COR Vehicles T2
		coracv                = { passengercategory = 2 },   -- Advanced Construction Vehicle | Tech 2 Constructor
		corban                = { passengercategory = 4 },   -- Banisher | Heavy Missile Tank
		coreter               = { passengercategory = 2 },   -- Obscurer | Radar Jammer Vehicle
		corgol                = { passengercategory = 6 },   -- Tzar | Very Heavy Assault Tank
		corhacv               = { passengercategory = 4 },   -- Printer | Experimental Combat Engineer
		cormabm               = { passengercategory = 6 },   -- Saviour | Mobile Anti-Nuke
		cormart               = { passengercategory = 4 },   -- Quaker | Mobile Artillery
		corparrow             = { passengercategory = 4 },   -- Poison Arrow | Very Heavy Amphibious Tank
		corphantom            = { passengercategory = 2 },   -- Phantom | Amphibious Stealth Scout
		corprinter            = { passengercategory = 4 },   -- Printer | Armored Field Engineer
		correap               = { passengercategory = 4 },   -- Tiger | Heavy Assault Tank
		corsacv               = { passengercategory = 4 },
		corsala               = { passengercategory = 4 },   -- Salamander | Medium Heat Ray Amphibious Tank
		corseal               = { passengercategory = 4 },   -- Alligator | Medium Amphibious Tank
		corsent               = { passengercategory = 4 },   -- Fury | Anti-Air Flak Vehicle
		corsiegebreaker       = { passengercategory = 16 },  -- Siegebreaker | Heavy Long Range Destroyer
		cortrem               = { passengercategory = 6 },   -- Tremor | Heavy Artillery Vehicle
		corvac                = { passengercategory = 3 },   -- Printer | Armored Field Engineer. 200 BP and +25 E. Can repair/reclaim while moving
		corvacct              = { passengercategory = 3 },
		corvrad               = { passengercategory = 2 },   -- Omen | Radar Vehicle
		corvroc               = { passengercategory = 6 },   -- Negotiator | Stealthy Rocket Launcher - good vs. static defense
		-- COR Hovercraft
		corah                 = { passengercategory = 3 },   -- Birdeater | Anti-Air Hovercraft
		corch                 = { passengercategory = 2 },   -- Construction Hovercraft | Tech 1 Constructor
		corhal                = { passengercategory = 4 },   -- Halberd | Assault Hovertank
		cormh                 = { passengercategory = 3 },   -- Mangonel | Hovercraft Rocket Launcher
		corsh                 = { passengercategory = 1.5 }, -- Goon | Fast Attack Hovercraft
		corsnap               = { passengercategory = 3 },   -- Cayman | Hovertank
		-- COR Buildings
		corhllt               = { passengercategory = 4 },   -- Twin Guard | Anti-Swarm Double Guard
		corllt                = { passengercategory = 4 },   -- Guard | Light Laser Tower
		cornanotc             = { passengercategory = 2 },   -- Construction Turret | Assist & Repair in large radius
		cornanotc2plat        = { passengercategory = 6 },   -- Advanced Construction Turret | Assist & Repair in larger radius
		cornanotct2           = { passengercategory = 6 },   -- Advanced Construction Turret | Assist & Repair in larger radius
		corrad                = { passengercategory = 4 },   -- Radar Tower | Early Warning System
		corrl                 = { passengercategory = 4 },   -- Thistle | Light Anti-air Tower
		-- COR Assist Drone
		corassistdrone_land   = { passengercategory = 1 },   -- Assist Vehicle | Portable Buildpower
		-- HATs
		cor_hat_fightnight    = { passengercategory = 1 },   -- #1 Grunt | The legendary Fight Night Trophy
		cor_hat_hornet        = { passengercategory = 1 },   -- Hornet's Tricorn | A weathered yet dapper tricorn
		cor_hat_hw            = { passengercategory = 1 },   -- Spooky Pumpkin | Spooky Fight Night Trophy
		cor_hat_legfn         = { passengercategory = 1 },   -- #1 Goblin | The Legendary Legion Fight Night Trophy
		cor_hat_ptaq          = { passengercategory = 1 },   -- PtaQ's Hat | The finest bonnet in all of Gnomedom
		cor_hat_viking        = { passengercategory = 1 },   -- Viking Helmet | A fierce Viking helmet
		-- Legion Commanders
		legcom                = { passengercategory = 6 },   -- Legion Commander | Commander
		legcomecon            = { passengercategory = 1 },   -- Economy Commander | Improved Resource Generation and Build Power / Range
		legcomoff             = { passengercategory = 6 },   -- Offensive Commander | Improved Weapon and Speed
		legcomt2com           = { passengercategory = 6 },   -- Combat Commander | Increased Size, Health, and Weapon Count, but Moves Slowly
		legcomt2def           = { passengercategory = 6 },   -- Tactical Defense Commander | Improved Resource Generation with EMP Grenade and Plasma Shield
		legcomt2off           = { passengercategory = 6 },   -- Tactical Offense Commander | Improved Speed, Able to Build Units, Short-Range Jammer, Survives Falls
		legcomlvl2            = { passengercategory = 6 },   -- Legion Commander Level 2 | Commander
		legcomlvl3            = { passengercategory = 6 },   -- Legion Commander Level 3 | Legion Commander and mobile rapid assault factory
		legcomlvl4            = { passengercategory = 6 },   -- Legion Commander Level 4 | Legion Commander and mobile rapid assault factory
		legcomlvl5            = { passengercategory = 6 },   -- Legion Commander Level 5 | Legion Commander and mobile rapid assault factory
		legcomlvl6            = { passengercategory = 6 },   -- Legion Commander Level 6 | Legion Commander and mobile rapid assault factory
		legcomlvl7            = { passengercategory = 6 },   -- Legion Commander Level 7 | Legion Commander and mobile rapid assault factory
		legcomlvl8            = { passengercategory = 6 },   -- Legion Commander Level 8 | Legion Commander and mobile rapid assault factory
		legcomlvl9            = { passengercategory = 6 },   -- Legion Commander Level 9 | Legion Commander and mobile rapid assault factory
		legcomlvl10           = { passengercategory = 6 },   -- Legion Commander Level 10 | Legion Commander and mobile rapid assault factory
		-- Legion Bots T1
		legaabot              = { passengercategory = 1 },   -- Toxotai | Amphibious Anti-Air Bot
		legbal                = { passengercategory = 1 },   -- Ballista | Medium Rocket Bot
		legcen                = { passengercategory = 1 },   -- Phobos | Fast Assault Bot
		leggob                = { passengercategory = 1 },   -- Goblin | Light Skirmish Bot
		legkark               = { passengercategory = 1 },   -- Karkinos | Medium Dual-Weapon Infantry Bot
		leglob                = { passengercategory = 1 },   -- Satyr | Light Plasma Bot
		legrezbot             = { passengercategory = 1 },   -- Zagreus | Stealthy Resurrection / Repair / Reclaim Bot
		-- Legion Bots T2
		legadvaabot           = { passengercategory = 1 },   -- Aquilon | Heavy Amphibious Anti-Air Bot
		legajamk              = { passengercategory = 1 },   -- Tiresias | Mobile Jammer Bot
		legamph               = { passengercategory = 4 },   -- Telchine | Advanced Amphibious Assault Bot/Coast Guard
		legaradk              = { passengercategory = 1 },   -- Euclid | Mobile Radar Bot
		legaspy               = { passengercategory = 1 },   -- Eidolon | Stealthy Invisible Spy Bot
		legbart               = { passengercategory = 4 },   -- Belcher | Napalm / Skirmish Bot
		legdecom              = { passengercategory = 6 },   -- Legion Commander | Decoy Commander
		legdecomlvl3          = { passengercategory = 6 },
		legdecomlvl6          = { passengercategory = 6 },
		legdecomlvl10         = { passengercategory = 6 },
		leghrk                = { passengercategory = 4 },   -- Thanatos | Salvo Rocket Bot
		leginc                = { passengercategory = 4 },   -- Incinerator | (barely) Mobile Heavy Heat Ray
		leginfestor           = { passengercategory = 4 },   -- Infestor | Infesting All-Terrain Spider Assault Bot
		legshot               = { passengercategory = 1 },   -- Phalanx | Shielded Riot Defence Bot
		legsnapper            = { passengercategory = 1 },   -- Snapper | Amphibious Screwdrive Bomb
		legsrail              = { passengercategory = 4 },   -- Arquebus | All-Terrain Heavy Railgun
		legstr                = { passengercategory = 4 },   -- Hoplite | Fast Raider Bot
		-- Legion Vehicles T1
		legamphtank           = { passengercategory = 4 },   -- Cetus | Light Amphibious Tank
		legbar                = { passengercategory = 4 },   -- Barrage | Napalm Artillery
		leggat                = { passengercategory = 4 },   -- Decurion | Armored Assault Tank
		leghades              = { passengercategory = 1 },   -- Alaris | Fast Assault Tank
		leghelios             = { passengercategory = 1 },   -- Helios | Skirmisher Tank
		legmlv                = { passengercategory = 1 },   -- Sapper | Stealthy Minelayer / Minesweeper
		legrail               = { passengercategory = 4 },   -- Lance | Long-range Skirmisher / Anti-air
		legscout              = { passengercategory = 1 },   -- Wheelie | Light Scout Vehicle
		-- Legion Vehicles T2
		legaheattank          = { passengercategory = 4 },   -- Prometheus | Heavy Assault Heatray Tank
		legamcluster          = { passengercategory = 4 },   -- Cleaver | Mobile Cluster Artillery Vehicle
		legaskirmtank         = { passengercategory = 4 },   -- Gladiator | Medium Burst-Fire Skirmisher Tank
		legavantinuke         = { passengercategory = 4 },   -- Hera | Mobile Anti-nuke Vehicle
		legavjam              = { passengercategory = 4 },   -- Cicero | Mobile Radar Jammer Vehicle
		legavrad              = { passengercategory = 4 },   -- Pheme | Mobile Radar Vehicle
		legavroc              = { passengercategory = 4 },   -- Boreas | Stealthy Mobile Rocket Launcher
		legfloat              = { passengercategory = 4 },   -- Triton | Heavy Convertible Tank/Boat
		legfmg                = { passengercategory = 4 },   -- Gelasma | Heavy Land/Air Floating Gatling Gun Turret
		leginf                = { passengercategory = 4 },   -- Inferno | Long-Range Burst-Fire Napalm Artillery Vehicle
		legmed                = { passengercategory = 4 },   -- Medusa | Heavy Long-Range Salvo Rocket Tank
		legmrv                = { passengercategory = 1 },   -- Quickshot | Fast Burst-Fire Raiding Vehicle
		legvcarry             = { passengercategory = 4 },   -- Mantis | Mobile Drone Carrier Truck (Drones cost 15m 500E each)
		legvflak              = { passengercategory = 4 },   -- Charon | Anti-Air Minigun Truck
		-- Legion Hovercraft
		legah                 = { passengercategory = 4 },   -- Alpheus | Anti-Air Hovercraft
		legcar                = { passengercategory = 4 },   -- Cardea | Shotgun Hovertank
		legmh                 = { passengercategory = 4 },   -- Salacia | Hovercraft Rocket Launcher
		legner                = { passengercategory = 4 },   -- Nereus | Hovertank
		legsh                 = { passengercategory = 4 },   -- Glaucus | Fast Attack Hovercraft
		-- Legion Ships
		leganavybattleship    = { passengercategory = 16 },  -- Scylla | Hybrid Cross-Terrain Battleship
		-- Legion Constructors
		legack                = { passengercategory = 1 },   -- Advanced Construction Bot | Tech 2 Constructor
		legaceb               = { passengercategory = 1 },   -- Proteus | All-Terrain Combat Engineer
		legacv                = { passengercategory = 4 },   -- Advanced Construction Vehicle | Tech 2 Constructor
		legafcv               = { passengercategory = 4 },   -- Aceso | Light Construction Buggy
		legch                 = { passengercategory = 4 },   -- Construction Hovercraft | Tech 1 Constructor
		legck                 = { passengercategory = 1 },   -- Legion Construction Bot | Tech 1 Constructor
		legcv                 = { passengercategory = 4 },   -- Legion Construction Vehicle | Tech 1 Constructor
		leghack               = { passengercategory = 1 },   -- Prometheus | Experimental Combat Engineer
		leghacv               = { passengercategory = 4 },   -- Aceso | Experimental Combat Engineer
		legotter              = { passengercategory = 4 },   -- Otter | Amphibious Construction Vehicle
		-- Legion Buildings
		leglht                = { passengercategory = 1 },   -- Pharos | Light Heat Ray Tower
		legmg                 = { passengercategory = 4 },   -- Cacophony | Heavy Land/Air Gatling Gun Turret
		legnanotc             = { passengercategory = 4 },   -- Construction Turret | Assist & Repair in large radius
		legnanotct2           = { passengercategory = 4 },   -- Advanced Construction Turret | Assist & Repair in larger radius
		legnanotct2plat       = { passengercategory = 4 },   -- Advanced Construction Turret | Assist & Repair in larger radius
		legrad                = { passengercategory = 1 },   -- Radar Tower | Early Warning System
		legrl                 = { passengercategory = 4 },   -- Bramble | Light Anti-Air Tower
		-- Legion T3
		leegmech              = { passengercategory = 4 },   -- Praetorian | Armored Assault Mech
		legerailtank          = { passengercategory = 16 },  -- Daedalus | Experimental Rail Accelerator Tank
		legeshotgunmech       = { passengercategory = 4 },   -- Praetorian | Multi-Weapon Shotgun Assault Mech
		-- Legion Assist Drone
		legassistdrone_land   = { passengercategory = 1 },   -- Assist Vehicle | Portable Buildpower
		-- Baby Units
		babyleggob            = { passengercategory = 1 },
		babyleglob            = { passengercategory = 1 },
		babylegshotg          = { passengercategory = 1 },
		-- Debug / Dummy
		dbg_sphere            = { passengercategory = 1 },   -- dbg_sphere | debug sphere
		dbg_sphere_fullmetal  = { passengercategory = 1 },   -- dbg_sphere | debug sphere
		dummycom              = { passengercategory = 6 },
	},
}

