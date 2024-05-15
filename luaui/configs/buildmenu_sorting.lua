local unitOrderTable = {
-- UNITS
	--CONSTRUCTORS
	['armada_constructionbot']          = 001100, --BOTS
	['cortex_constructionbot']          = 001110,
	['legck']          = 001115,

	['armada_constructionvehicle']          = 001120, --VEH
	['cortex_constructionvehicle']          = 001130,
	['legcv']          = 001135,
	['armada_beaver']      = 001140,
	['cortex_muskrat']     = 001150,

	['armada_constructionaircraft']          = 001160, --AIR
	['cortex_constructionaircraft']          = 001165,
	['legca']          = 001166,

	['legassistdrone'] = 001167,
	['armada_assistdrone'] = 001168, --ASSISTDRONES
	['cortex_assistdrone'] = 001169,

	['armada_constructionseaplane']         = 001170, --SEAPLANES
	['cortex_constructionseaplane']         = 001175,

	['armada_constructionship']          = 001180, --SHIPS
	['cortex_constructionship']          = 001190,

	['armada_constructionhovercraft']          = 002000, --HOVER
	['cortex_constructionhovercraft']          = 002050,

	['armada_lazarus']       = 002100, --REZ BOTS
	['cortex_graverobber']       = 002150,

	['armada_groundhog']         = 002200, --MINELAYERS
	['cortex_trapper']         = 002250,

	['armada_grimreaper']        = 002300, --REZ SUBS
	['cortex_deathcavalry']        = 002350,

	['armada_advancedconstructionbot']         = 002400,
	['cortex_advancedconstructionbot']         = 002450,
	['legack']         = 002455,

	['armada_advancedconstructionvehicle']         = 002500,
	['cortex_advancedconstructionvehicle']         = 002550,
	['legacv']         = 002555,

	['armada_advancedconstructionaircraft']         = 002600,
	['cortex_advancedconstructionaircraft']         = 002650,
	['legaca']         = 002660,

	['armada_advancedconstructionsub']       = 002700,
	['cortex_advancedconstructionsub']       = 002750,

	--NANO SUPPORT
	['armada_butler']        = 003100, --BOTS
	['cortex_twitcher']        = 003200,

	['armada_consul']      = 003300, --VEH
	['cortex_printer']     = 003325, --VEH
	['cortex_2printer']		   = 003326, --VEH
	['cortex_3printer']       = 003327, --VEH
	['cortex_forge']       = 003350, --VEH

	['armada_voyager']         = 003400, --SHIP
	['cortex_pathfinder']         = 003500, --SHIP

	['armada_decoycommander']       = 003600, --SUPPORT COMS
	['cortex_decoycommander']       = 003700,

	['cortex_commando']       = 003800, --COMMANDO

	['armada_ghost']         = 003900, --SPIES
	['cortex_spectre']         = 004000,

	-- AIR SCOUTS LAND UNARMED
	['armada_blink']        = 004030, --AIR
	['cortex_finch']        = 004040,
	['armada_horizon']       = 004050, --SEAPLANES
	['cortex_watcher']        = 004060,
	['armada_oracle']        = 004050,
	['cortex_condor']        = 004060,

	-- SCOUTS/UTILITY LAND
	['armada_compass']        = 004100,
	['cortex_augur']        = 004110,
	['armada_radarjammerbot']        = 004120,
	['cortex_deceiver']        = 004130,

	['armada_prophet']        = 004200,
	['cortex_omen']        = 004210,
	['armada_umbra']         = 004220,
	['cortex_obscurer']        = 004230,

	['armada_bermuda']        = 004250,
	['cortex_phantasm']        = 004260,

	-- AIRCRAFT
	['armada_falcon']         = 004300, --FIGHTERS
	['cortex_valiant']        = 004305,
	['legfig']         = 004306,
	['armada_highwind']        = 004310, --FIGHTERS T2
	['cortex_nighthawk']        = 004315,
	['legionnaire']    = 004316,
	['legvenator']     = 004317,
	['armada_cyclone2']       = 004316, -- T2 Heavy Fighter (air rework mod)
	['cortex_bat2']       = 004317,

	['armada_banshee']         = 004320, --GUNSHIPS
	['legmos']         = 004322,
	['armada_sabre']       = 004325,
	['cortex_cutlass']         = 004330,
	['legstronghold']  = 004331,

	['armada_roughneck']       = 004335, --GUNSHIPS T2
	['cortex_wasp']         = 004340,
	['armada_hornet']       = 004345,
	['cortex_dragonold']         = 004348,
	['cortex_dragon']         = 004347,
	['legfort']        = 004349,

	['armada_stormbringer']       = 004350, --BOMBERS
	['cortex_whirlwind']        = 004355,
	['legcib']         = 004356,
	['legkam']         = 004357,
	['armada_tsunami']          = 004360,
	['cortex_dambuster']          = 004365,
	['legphoenix']     = 004366,

	['armada_blizzard']        = 004370, --BOMBERS T2
	['cortex_hailstorm']        = 004380,
	['legnap']         = 004381,
	['legmineb']       = 004382,
	['legphoenix']     = 004383,
	['armada_liche']       = 004385,
	['armada_stiletto']        = 004390,

	-- SCOUTS LAND ARMED
	['armada_tick']        = 004400, --BOTS

	['armada_rover']         = 004410, --VEH
	['cortex_rascal']         = 004420,

	['armada_seeker']          = 004500, --HOVER
	['cortex_goon']          = 004510,

	-- EMP
	['cortex_shuriken']          = 004800, --EMP
	['armada_webber']        = 004810, --EMP

	-- T1 LAND ATTACK
	['armada_pawn']          = 005000, --FAST
	['cortex_grunt']          = 005010,
	['leggob']		   = 005015,
	['leglob']         = 005016,
	['armada_blitz']       = 005020,
	['cortex_incisor']       = 005030,
	['leghades']	   = 005031,
	['legcen']		   = 005032,

	['armada_janus']       = 005200, --MAIN BATTLE
	['cortex_pounder']       = 005210,
	['armada_stout']       = 005220,
	['cortex_brute']        = 005230,
	['armada_crocodile']        = 005240,
	['cortex_cayman']        = 005250,
	['leghelios']	   = 005251,
	['leggat']		   = 005252,

	['armada_rocketeer']        = 005300, --ROCKETS
	['cortex_aggravator']       = 005310,
	['legbal']		   = 005311,

	['armada_mace']         = 005400, --ARTILLERY
	['cortex_thug']        = 005410,
	['armada_shellshocker']         = 005420,
	['cortex_wolverine']        = 005430,
	['armada_possum']          = 005420,
	['cortex_mangonel']          = 005430,
	['legbar']         = 005440,

	['armada_centurion']         = 005600, --STRONK
	['legkark']        = 005610,

	['armada_whistler']         = 005800, --LAND + AA
	['cortex_lasher']        = 005810,
	['legrail']		   = 005811,

	['armada_pincer']      = 005900, --LAND + AMPHIBIOUS
	['cortex_garpike']        = 005910,

	-- T2 LAND ATTACK
	['armada_gremlin']     = 006005,

	['armada_sprinter']        = 006100, --FAST
	['legstr']         = 006105,
	['cortex_fiend']        = 006110,
	['armada_jaguar']       = 006120,
	['cortex_torch']       = 006125,
	['legmrv']         = 006130,

	['armada_welder']        = 006300, --MAIN BATTLE
	['armada_gunslinger']         = 006310,
	['armada_bull']        = 006320,
	['cortex_heattiger']      = 006325,
	['cortex_tiger']        = 006330,
	['legsco']         = 006335,
	['armada_starlight']       = 006340,
	['cortex_lasertiger']     = 006350,

	['cortex_arbiter']         = 006400, --ROCKETS
	['armada_ambassador']        = 006410,
	['cortex_negotiator']        = 006420,
	['armada_ambassador']        = 006430,
	['cortex_banisher']         = 006440,

	['armada_hound']        = 006500, --ARTILLERY
	['cortex_sheldon']        = 006510,
	['legbart']        = 006515,
	['legvcarry']      = 006516,
	['armada_mauser']        = 006520,
	['cortex_quaker']        = 006530,
	['cortex_tremor']        = 006540,
	['leginf']         = 006550,

	['armada_recluse']        = 006600, --ALL-TERRAIN
	['cortex_termite']     = 006610,
	['leginfestor']   = 006614,
	['legsrail']       = 006615,

	['armada_fatboy']        = 006700, --STRONK
	['cortex_sumo']         = 006710,
	['legshot']        = 006715,
	['armada_sharpshooter']       = 006720,
	['cortex_mammoth']        = 006730,
	['cortex_tzar']         = 006740,
	['leginc']         = 006750,

	['armada_tumbleweed']       = 006810, --AMPHIBIOUS KAMIKAZE BOMBS
	['cortex_bedbug']       = 006820,
	['cortex_skuttle']        = 006830,

	['armada_amphibiousbot']        = 006900, --LAND + AMPHIBIOUS
	['cortex_duck']        = 006910,
	['armada_turtle']        = 006920,
	['cortex_alligator']        = 006930,
	['cortex_salamander']        = 006935,
	['cortex_poisonarrow']      = 006940,
	['legfloat']       = 006941,

   -- T2 HOVER
   ['cortex_halberd']         = 006950,

	--T3 LAND ATTACK
	['armada_marauder']         = 007000,
	['cortex_catapult']         = 007010,
	['armada_razorback']         = 007020,
	['cortex_karganeth']        = 007030,
	['armada_vanguard']        = 007040,
	['cortex_shiva']       = 007050,
	['legkeres']	   = 007051,
	['legpede']        = 007055,
	['armada_thor']        = 007060,
	['leegmech']       = 007065,
	['cortex_juggernaut']        = 007070,
	['armada_titan']       = 007080,
	['cortex_behemoth']        = 007090,

	--T3 HOVER
	['armada_lunkhead']         = 007100, --hover
	['cortex_cataphract']         = 007110, --hover

	--T4 LAND ATTACK (SCAVS)
	['armada_meatball']    = 007200,
	['armada_lunchbox']    = 007210,
	['armada_assimilator'] = 007220,

	['armada_pawnt4']        = 007300,
   ['cortex_epicgrunt']        = 007310,
	['armada_recluset4']      = 007320,
	['cortex_demon']     = 007330,
	['cortex_epickarganeth'] = 007340,
	['cortex_thermite'] = 007341,

	['armada_epictumbleweed']     = 007400,
	['armada_ratte']     = 007410,
	['cortex_epictzar']       = 007420,

	['armada_epicstormbringer']     = 007500,
	['armada_flyingepoch']    = 007510,
	['cortex_flyingblackhydra']  = 007520,
	['cortex_epicdragon']       = 007530,

	-- LAND AA
	['armada_crossbow']        = 008000,
	['cortex_trasher']       = 008010,
	['armada_archangel']         = 008020,
	['cortex_manticore']         = 008030,

	['armada_shredder']        = 008200,
	['cortex_fury']        = 008210,

	['armada_sweeper']          = 008300,
	['cortex_birdeater']          = 008310,

	-- -- T2 AA
	-- ['armada_archangel']         = 008500,
	-- ['cortex_manticore']         = 008510,

	-- ['armada_shredder']        = 008520,
	-- ['cortex_fury']        = 008530,

	-- ['armada_highwind']        = 008540,
	-- ['cortex_nighthawk']        = 008550,

	-- WATER SCOUTS
	['armada_skater']          = 009000, --SCOUTS AA
	['cortex_supporter']       = 009010,

	-- T1 WATER ATTACK
	['armada_dolphin']      = 009100, --FAST
	['cortex_herring']          = 009110,

	['armada_ellysaw']       = 009200, --MAIN BATTLE
	['cortex_riptide']       = 009210,
	['armada_corsair']         = 009220,
	['cortex_oppressor']         = 009230,

	-- T2 WATER ATTACK
	['armada_maelstrom']       = 009280, --ANTISWARM
	['cortex_brimstone']       = 009290,

	['armada_paladin']        = 009300, --MAIN BATTLE
	['cortex_buccaneer']        = 009310,

	['armada_longbow']       = 009340, --ROCKETS
	['cortex_messenger']       = 009350,

	['armada_dronecarrier']  = 009360, --DRONE CARRIERS
	['cortex_dronecarrier']  = 009361,

	['armada_dreadnought']        = 009370, --STRONK
	['cortex_despot']        = 009380,

	['armada_epoch']       = 009400, --FLAGSHIPS
	['cortex_blackhydra']     = 009410,

	['armada_epicdolphin']    = 009450, --SCAV SHIPS
	['cortex_epicsupporter']     = 009460,
	['armada_epicellysaw']     = 009470,
	['cortex_basiliskship']       = 009480,

	-- T1 AA
	['armada_cyclone']        = 009500,
	['cortex_bat']        = 009510,

	-- T2 AA
	['armada_dragonslayer']         = 009600,
	['cortex_arrowstorm']        = 009610,

	-- UNDERWATER ATTACK
	['armada_puffin']        = 009800,
	['cortex_monsoon']        = 009810,
	['armada_eel']         = 009820,
	['cortex_orca']         = 009830,

	['armada_cormorant']       = 009900,
	['cortex_angler']       = 009910,
	['armada_barracuda']        = 009920,
	['cortex_predator']       = 009930,
	['armada_serpent']        = 009940,
	['cortex_kraken']        = 009950,

	['armada_epicserpent']      = 009960,
	['armada_epicskater']        = 009962,

	-- TRANSPORTS
	['armada_stork']       = 010500,
	['cortex_hercules']        = 010510,

	['armada_convoy']       = 010540,
	['cortex_coffin']       = 010550,

	['armada_bearer']       = 010560,
	['cortex_caravan']       = 010570,

	['cortex_intruder']        = 010600,

	['armada_abductor']        = 010610,
	['cortex_skyhook']        = 010620,

	-- ANTINUKES
	['armada_umbrella']        = 020000,
	['cortex_saviour']        = 020010,

	['armada_haven']       = 020100,
	['armada_supportship']	   = 020101,
	['armada_haven2']      = 020105,
	['cortex_oasis']       = 020110,
	['cortex_supportship']    = 020111,
	['cortex_oasis2']      = 020115,

-- BUILDINGS
   --ECO METAL MEX
   ['armada_metalextractor']         = 100000,
   ['cortex_metalextractor']         = 100050,
   ['legmex']         = 100060,
   ['armada_twilight']        = 100100,
   ['cortex_exploiter']         = 100150,
   ['legmext15']      = 100160,

   ['armada_advancedmetalextractor']        = 100200,
   ['cortex_advancedmetalextractor']        = 100250,
   ['legmext2']       = 100260,
   ['armada_shockwave']   = 100290,
   ['cortex_advancedexploiter']        = 100300,

   --ECO ENERGY CONVERTERS
   ['armada_energyconverter']        = 100500,
   ['cortex_energyconverter']        = 100550,
   ['armada_advancedenergyconverter']        = 100600,
   ['cortex_advancedenergyconverter']        = 100650,

   --ECO METAL STORAGE
   ['armada_metalstorage']       = 100800,
   ['cortex_metalstorage']       = 100850,
   ['armada_hardenedmetalstorage']     = 100900,
   ['cortex_hardenedmetalstorage']     = 100950,

   --ECO NRG GENS
   ['armada_windturbine']         = 101000,
   ['cortex_windturbine']         = 101020,
   ['armada_advancedwindturbine']       = 101040, --scavengers
   ['cortex_advancedwindturbine']       = 101050, --scavengers
   ['armada_solarcollector']       = 101070,
   ['cortex_solarcollector']       = 101080,
   ['armada_advancedsolarcollector']      = 101100,
   ['cortex_advancedsolarcollector']      = 101150,

   --ECO NRG GEOS
   ['armada_geothermalpowerplant']         = 101200,
   ['armada_underwatergeothermalpowerplant']       = 101201,
   ['cortex_geothermalpowerplant']         = 101250,
   --['cortex_underwatergeothermalpowerplant']       = 101251,
   ['armada_prude']         = 101300,
   ['cortex_advancedgeothermalpowerplant']        = 101350,
   ['cortex_advancedunderwatergeothermalpowerplant']      = 101351,
   ['armada_advancedgeothermalpowerplant']        = 101400,
   ['armada_advancedunderwatergeothermalpowerplant']      = 101401,
   ['cortex_cerberus']       = 101450,

   --ECO NRG FUSIONS
   ['armada_fusionreactor']         = 101525,
   ['armada_cloakablefusionreactor']       = 101550,
   ['cortex_fusionreactor']         = 101600,
   ['armada_advancedfusionreactor']        = 101700,
   ['cortex_advancedfusionreactor']        = 101750,

   --ECO NRG STORAGE
   ['armada_energystorage']       = 101800,
   ['cortex_energystorage']       = 101850,
   ['armada_hardenedenergystorage']     = 101900,
   ['cortex_hardenedenergystorage']     = 101950,

   --NANOS
   ['armada_constructionturret']      = 102000,
   ['cortex_constructionturret']      = 102050,

   --FACTORIES
   ['armada_botlab']         = 102100,
   ['cortex_botlab']         = 102125,
   ['leglab']         = 102126,
   ['armada_vehicleplant']          = 102150,
   ['cortex_vehicleplant']          = 102175,
   ['legvp']          = 102176,
   ['armada_aircraftplant']          = 102200,
   ['cortex_aircraftplant']          = 102225,
   ['legap']          = 102230,
   ['armada_hovercraftplatform']          = 102250,
   ['cortex_hovercraftplatform']          = 102275,

   ['armada_advancedbotlab']        = 102400,
   ['cortex_advancedbotlab']        = 102425,
   ['legalab']        = 102426,
   ['armada_advancedvehicleplant']         = 102450,
   ['cortex_advancedvehicleplant']         = 102475,
   ['legavp']         = 102477,
   ['armada_advancedaircraftplant']         = 102500,
   ['cortex_advancedaircraftplant']         = 102525,
   ['legaap']         = 102530,
   ['armada_experimentalgantry']       = 102550,
   ['cortex_experimentalgantry']        = 102575,
   ['leggant']        = 102576,
   ['armada_experimentalaircraftplant']        = 102700, --scavengers
   ['cortex_experimentalaircraftplant']        = 102725, --scavengers

   --UTILITIES
   ['armada_airrepairpad']         = 102800, --AIR REPAIR PADS
   ['cortex_airrepairpad']         = 102825,

   ['armada_beholder']        = 103000,
   ['cortex_beholder']        = 103050,
   ['armada_radartower']         = 103100,
   ['cortex_radartower']         = 103150,
   ['armada_advancedradartower']        = 103200,
   ['cortex_advancedradartower']        = 103250,
   ['armada_sneakypete']        = 103300,
   ['cortex_castro']        = 103350,
   ['armada_veil']        = 103400,
   ['cortex_shroud']      = 103450,
   ['armada_juno']        = 103500,
   ['cortex_juno']        = 103550,

   ['armada_tracer']          = 103600,
   ['cortex_nemesis']          = 103625,
   ['armada_pinpointer']        = 103650,
   ['cortex_pinpointer']        = 103675,
   ['armada_keeper']        = 103700,
   ['cortex_overseer']        = 103725,
   ['armada_decoyfusionreactor']          = 103750, --Fake Fusion

   --DEFENSES LAND (WALLS)
   ['armada_dragonsteeth']        = 104000,
   ['cortex_dragonsteeth']        = 104100,
   ['cortex_scavdragonsteeth']    = 104205, --scavengers
   ['armada_fortificationwall']        = 104300,
   ['cortex_fortificationwall']        = 104400,
   ['cortex_scavfortificationwall']    = 104505, --scavengers
   ['armada_dragonsclaw']        = 104600,
   ['armada_dragonsfury']       = 104650,
   ['cortex_scavdragonsclaw']     = 104705, --scavengers
   ['cortex_dragonsmaw']         = 104800,
   ['cortex_dragonsrage']       = 104850,
   ['cortex_scavdragonsmaw']     = 104905, --scavengers
   ['cortex_scavmissilewall']     = 104915, --scavengers

   --MINES
   ['armada_lightmine']       = 105100,
   ['cortex_lightmine']       = 105200,
   ['armada_mediummine']       = 105300,
   ['cortex_mediummine']       = 105400,
   ['cortex_mediumminecommando']       = 105500, --cortex_commando
   ['armada_heavymine']       = 105600,
   ['cortex_heavymine']       = 105700,

   --DEFENSES LAND T1
   ['armada_sentry']         = 106100,
   ['cortex_guard']         = 106200,
   ['armada_beamer']      = 106300,
   ['cortex_twinguard']        = 106400,
   ['cortex_quadguard']      = 106500, --scavengers
   ['armada_overwatch']         = 106600,
   ['cortex_warden']         = 106700,
   ['legdefcarryt1']  = 106800,
   ['armada_gauntlet']       = 106800,
   ['cortex_agitator']         = 106900,

   --DEFENSES LAND T2
   ['legmg']          = 107000, --land/AA machinegun
   ['armada_pitbull']          = 107100,
   ['cortex_scorpion']        = 107200,
   ['armada_rattlesnake']         = 107300,
   ['cortex_persecutor']       = 107400,
   ['armada_pulsar']        = 107500,
   ['cortex_bulwark']        = 107600,
   ['legbastion']     = 107650,
   ['armada_epicpulsar']      = 107700, --scavengers
   ['cortex_epicbulwark']      = 107800, --scavengers

   --DEFENSES LAND LRPC
   ['armada_basilica']       = 110100,
   ['cortex_basilisk']         = 110200,
   ['armada_miniragnarok']    = 120100, --scavengers
   ['cortex_minicalamity']    = 120200, --scavengers
   ['legministarfall']= 120250, --scavengers
   ['armada_ragnarok']        = 120300,
   ['cortex_calamity']        = 120400,
   ['legstarfall']    = 120450,
   ['armada_pawnlauncher']     = 120500, --scavengers

   --DEFENSES AA
   ['armada_nettle']          = 130100,
   ['cortex_thistle']          = 130200,
   ['armada_ferret']      = 130300,
   ['cortex_sam']      = 130400,
   ['armada_chainsaw']         = 130500,
   ['cortex_eradicator']        = 130600,

   ['armada_arbalest']        = 153000,
   ['cortex_birdshot']        = 153500,
   ['armada_mercury']     = 154000,
   ['cortex_screamer']    = 154500,

   --DEFENSES TO WATER
   ['armada_anemone']          = 155000,
   ['cortex_jellyfish']          = 155500,

   --DEFENSES MISSILE LAUNCHERS
   ['armada_paralyzer']         = 165000,
   ['cortex_catalyst']        = 165500,
   ['armada_citadel']         = 166000,
   ['cortex_prevailer']         = 166500,
   ['armada_armageddon']        = 180000,
   ['cortex_apocalypse']        = 180500,

   --WATER ECO METAL
   ['armada_navaladvancedmetalextractor']       = 200000,
   ['cortex_navaladvancedmetalextractor']       = 200100,

   --WATER ECO NRG CONVERTERS
   ['armada_navalenergyconverter']        = 200400,
   ['cortex_navalenergyconverter']        = 200500,
   ['armada_navaladvancedenergyconverter']       = 200600,
   ['cortex_navaladvancedenergyconverter']       = 200700,

   --WATER ECO METAL STORAGE
   ['armada_navalmetalstorage']        = 201000,
   ['cortex_navalmetalstorage']        = 201500,

   --WATER ECO NRG GENS
   ['armada_tidalgenerator']        = 203000,
   ['cortex_tidalgenerator']        = 203100,

   --WATER ECO NRG GEOS
   ['armada_underwatergeothermalpowerplant']       = 204000,
   ['cortex_underwatergeothermalpowerplant']       = 204100,
   ['armada_advancedgeothermalpowerplant']       = 204500,
   ['cortex_advancedunderwatergeothermalpowerplant']       = 204600,

   --WATER ECO NRG FUSIONS
   ['armada_navalfusionreactor']       = 205000,
   ['cortex_navalfusionreactor']       = 205500,

   --WATER ECO NRG STORAGE
   ['armada_navalenergystorage']        = 207000,
   ['cortex_navalenergystorage']        = 207500,

   --WATER CONSTRUCTION
   ['armada_navalconstructionturret']  = 210000,
   ['cortex_navalconstructionturret']  = 210500,

   ['armada_shipyard']          = 211100,
   ['cortex_shipyard']          = 211200,
   ['armada_navalhovercraftplatform']         = 212100,
   ['cortex_navalhovercraftplatform']         = 212200,
   ['armada_amphibiouscomplex']       = 213100,
   ['cortex_amphibiouscomplex']       = 213200,
   ['armada_seaplaneplatform']        = 214100,
   ['cortex_seaplaneplatform']        = 214200,
   	--T2
   ['armada_advancedshipyard']         = 215000,
   ['cortex_advancedshipyard']         = 215100,
   	--T3
   ['armada_experimentalgantryuw']     = 216100,
   ['cortex_underwaterexperimentalgantry']      = 216200,

   --WATER MINES
   ['armada_heavymine']      = 217100,
   ['cortex_navalheavymine']      = 217200,

   --WATER UTILITIES
   ['armada_floatingairrepairpad']        = 220000,
   ['cortex_floatingairrepairpad']        = 220050,
   ['armada_navalradarsonar']        = 220100,
   ['cortex_radarsonartower']        = 220150,
   ['armada_advancedsonarstation']        = 220200,
   ['cortex_advancedsonarstation']        = 220250,
   ['armada_navalpinpointer']        = 220400,
   ['cortex_navalpinpointer']        = 220450,

   --WATER DEFENSES LAND
   ['armada_sharksteeth']       = 230100,
   ['cortex_sharksteeth']       = 230200,
   ['armada_manta']        = 230300,
   ['cortex_coral']        = 230400,
   ['armada_gorgon']      = 230500,
   ['cortex_devastator']       = 230600,

   --WATER DEFENSES AA
   ['armada_navalnettle']         = 255100,
   ['cortex_slingshot']         = 255200,
   ['armada_navalarbalest']       = 255300,
   ['cortex_navalbirdshot']        = 255400,

   --WATER DEFENSES NAVAL
   ['armada_harpoon2']         = 260100,
   ['cortex_oldurchin']         = 260200,
   ['armada_harpoon']          = 260300,
   ['cortex_urchin']          = 260400,
   ['armada_moray']         = 260500,
   ['cortex_lamprey']         = 260600,
}

local newUnitOrder = {}
for id, value in pairs(unitOrderTable) do
	if UnitDefNames[id] then
		newUnitOrder[UnitDefNames[id].id] = value
	else
		Spring.Echo("WARNING: luaui/configs/buildmenu_sorting.lua: UnitDef '"..id.."' doesnt exist!")
	end
end
unitOrderTable = newUnitOrder
newUnitOrder = nil

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.isscavenger then
		local counterpartId = UnitDefNames[unitDef.customParams.fromunit].id
		if unitOrderTable[counterpartId] then
			unitOrderTable[unitDefID] = unitOrderTable[counterpartId]
		end
	end
end

return unitOrderTable
