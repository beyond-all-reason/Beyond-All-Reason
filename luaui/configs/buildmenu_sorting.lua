local unitOrderTable = {
-- UNITS
	--CONSTRUCTORS
	['armada_constructionbot']          = 001100, --BOTS
	['cortex_constructionbot']          = 001110,
	['legck']          = 001115,

	['armada_constructionvehicle']          = 001120, --VEH
	['corcv']          = 001130,
	['legcv']          = 001135,
	['armada_beaver']      = 001140,
	['cormuskrat']     = 001150,

	['armada_constructionaircraft']          = 001160, --AIR
	['cortex_constructionaircraft']          = 001165,
	['legca']          = 001166,

	['legassistdrone'] = 001167,
	['armassistdrone'] = 001168, --ASSISTDRONES
	['corassistdrone'] = 001169,

	['armada_constructionseaplane']         = 001170, --SEAPLANES
	['corcsa']         = 001175,

	['armada_constructionship']          = 001180, --SHIPS
	['corcs']          = 001190,

	['armada_constructionhovercraft']          = 002000, --HOVER
	['corch']          = 002050,

	['armada_lazarus']       = 002100, --REZ BOTS
	['cortex_graverobber']       = 002150,

	['armada_groundhog']         = 002200, --MINELAYERS
	['cormlv']         = 002250,

	['armada_grimreaper']        = 002300, --REZ SUBS
	['correcl']        = 002350,

	['armada_advancedconstructionbot']         = 002400,
	['cortex_advancedconstructionbot']         = 002450,
	['legack']         = 002455,

	['armada_advancedconstructionvehicle']         = 002500,
	['coracv']         = 002550,
	['legacv']         = 002555,

	['armada_advancedconstructionaircraft']         = 002600,
	['cortex_advancedconstructionaircraft']         = 002650,
	['legaca']         = 002660,

	['armada_advancedconstructionsub']       = 002700,
	['coracsub']       = 002750,

	--NANO SUPPORT
	['armada_butler']        = 003100, --BOTS
	['cortex_twitcher']        = 003200,

	['armada_consul']      = 003300, --VEH
	['corprinter']     = 003325, --VEH
	['corvac']		   = 003326, --VEH
	['corvacct']       = 003327, --VEH
	['corforge']       = 003350, --VEH

	['armada_voyager']         = 003400, --SHIP
	['cormls']         = 003500, --SHIP

	['armada_decoycommander']       = 003600, --SUPPORT COMS
	['cortex_decoycommander']       = 003700,

	['cortex_commando']       = 003800, --COMMANDO

	['armada_ghost']         = 003900, --SPIES
	['cortex_spectre']         = 004000,

	-- AIR SCOUTS LAND UNARMED
	['armada_blink']        = 004030, --AIR
	['corfink']        = 004040,
	['armada_horizon']       = 004050, --SEAPLANES
	['corhunt']        = 004060,
	['armada_oracle']        = 004050,
	['cortex_condor']        = 004060,

	-- SCOUTS/UTILITY LAND
	['armada_compass']        = 004100,
	['cortex_augur']        = 004110,
	['armada_radarjammerbot']        = 004120,
	['cortex_deceiver']        = 004130,

	['armada_prophet']        = 004200,
	['corvrad']        = 004210,
	['armada_umbra']         = 004220,
	['coreter']        = 004230,

	['armada_bermuda']        = 004250,
	['corsjam']        = 004260,

	-- AIRCRAFT
	['armada_falcon']         = 004300, --FIGHTERS
	['cortex_valiant']        = 004305,
	['legfig']         = 004306,
	['armada_highwind']        = 004310, --FIGHTERS T2
	['cortex_nighthawk']        = 004315,
	['legionnaire']    = 004316,
	['legvenator']     = 004317,
	['armada_cyclone2']       = 004316, -- T2 Heavy Fighter (air rework mod)
	['corsfig2']       = 004317,

	['armada_banshee']         = 004320, --GUNSHIPS
	['legmos']         = 004322,
	['armada_sabre']       = 004325,
	['corcut']         = 004330,
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
	['corsb']          = 004365,
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
	['corfav']         = 004420,

	['armada_seeker']          = 004500, --HOVER
	['corsh']          = 004510,

	-- EMP
	['cortex_shuriken']          = 004800, --EMP
	['armada_webber']        = 004810, --EMP

	-- T1 LAND ATTACK
	['armada_pawn']          = 005000, --FAST
	['cortex_grunt']          = 005010,
	['leggob']		   = 005015,
	['leglob']         = 005016,
	['armada_blitz']       = 005020,
	['corgator']       = 005030,
	['leghades']	   = 005031,
	['legcen']		   = 005032,

	['armada_janus']       = 005200, --MAIN BATTLE
	['corlevlr']       = 005210,
	['armada_stout']       = 005220,
	['corraid']        = 005230,
	['armada_crocodile']        = 005240,
	['corsnap']        = 005250,
	['leghelios']	   = 005251,
	['leggat']		   = 005252,

	['armada_rocketeer']        = 005300, --ROCKETS
	['cortex_aggravator']       = 005310,
	['legbal']		   = 005311,

	['armada_mace']         = 005400, --ARTILLERY
	['cortex_thug']        = 005410,
	['armada_shellshocker']         = 005420,
	['corwolv']        = 005430,
	['armada_possum']          = 005420,
	['cormh']          = 005430,
	['legbar']         = 005440,

	['armada_centurion']         = 005600, --STRONK
	['legkark']        = 005610,

	['armada_whistler']         = 005800, --LAND + AA
	['cormist']        = 005810,
	['legrail']		   = 005811,

	['armada_pincer']      = 005900, --LAND + AMPHIBIOUS
	['corgarp']        = 005910,

	-- T2 LAND ATTACK
	['armada_gremlin']     = 006005,

	['armada_sprinter']        = 006100, --FAST
	['legstr']         = 006105,
	['cortex_fiend']        = 006110,
	['armada_jaguar']       = 006120,
	['cortorch']       = 006125,
	['legmrv']         = 006130,

	['armada_welder']        = 006300, --MAIN BATTLE
	['armada_gunslinger']         = 006310,
	['armada_bull']        = 006320,
	['corftiger']      = 006325,
	['correap']        = 006330,
	['legsco']         = 006335,
	['armada_starlight']       = 006340,
	['corgatreap']     = 006350,

	['cortex_arbiter']         = 006400, --ROCKETS
	['armada_ambassador']        = 006410,
	['corvroc']        = 006420,
	['armada_ambassador']        = 006430,
	['corban']         = 006440,

	['armada_hound']        = 006500, --ARTILLERY
	['cortex_sheldon']        = 006510,
	['legbart']        = 006515,
	['legvcarry']      = 006516,
	['armada_mauser']        = 006520,
	['cormart']        = 006530,
	['cortrem']        = 006540,
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
	['corgol']         = 006740,
	['leginc']         = 006750,

	['armada_tumbleweed']       = 006810, --AMPHIBIOUS KAMIKAZE BOMBS
	['cortex_bedbug']       = 006820,
	['cortex_skuttle']        = 006830,

	['armada_amphibiousbot']        = 006900, --LAND + AMPHIBIOUS
	['cortex_duck']        = 006910,
	['armada_turtle']        = 006920,
	['corseal']        = 006930,
	['corsala']        = 006935,
	['corparrow']      = 006940,
	['legfloat']       = 006941,

   -- T2 HOVER
   ['corhal']         = 006950,

	--T3 LAND ATTACK
	['armada_marauder']         = 007000,
	['cortex_catapult']         = 007010,
	['armada_razorback']         = 007020,
	['corkarg']        = 007030,
	['armada_vanguard']        = 007040,
	['corshiva']       = 007050,
	['legkeres']	   = 007051,
	['legpede']        = 007055,
	['armada_thor']        = 007060,
	['leegmech']       = 007065,
	['corkorg']        = 007070,
	['armada_titan']       = 007080,
	['corjugg']        = 007090,

	--T3 HOVER
	['armada_lunkhead']         = 007100, --hover
	['corsok']         = 007110, --hover

	--T4 LAND ATTACK (SCAVS)
	['armmeatball']    = 007200,
	['armada_lunchbox']    = 007210,
	['armassimilator'] = 007220,

	['armada_pawnt4']        = 007300,
   ['cortex_gruntt4']        = 007310,
	['armada_recluset4']      = 007320,
	['cordemon']     = 007330,
	['corkarganetht4'] = 007340,
	['corthermite'] = 007341,

	['armada_tumbleweedt4']     = 007400,
	['armrattet4']     = 007410,
	['corgolt4']       = 007420,

	['armada_stormbringert4']     = 007500,
	['armfepocht4']    = 007510,
	['corfblackhyt4']  = 007520,
	['cortex_dragont4']       = 007530,

	-- LAND AA
	['armada_crossbow']        = 008000,
	['cortex_trasher']       = 008010,
	['armada_archangel']         = 008020,
	['cortex_manticore']         = 008030,

	['armada_shredder']        = 008200,
	['corsent']        = 008210,

	['armada_sweeper']          = 008300,
	['corah']          = 008310,

	-- -- T2 AA
	-- ['armada_archangel']         = 008500,
	-- ['cortex_manticore']         = 008510,

	-- ['armada_shredder']        = 008520,
	-- ['corsent']        = 008530,

	-- ['armada_highwind']        = 008540,
	-- ['cortex_nighthawk']        = 008550,

	-- WATER SCOUTS
	['armada_skater']          = 009000, --SCOUTS AA
	['coresupp']       = 009010,

	-- T1 WATER ATTACK
	['armada_dolphin']      = 009100, --FAST
	['corpt']          = 009110,

	['armada_ellysaw']       = 009200, --MAIN BATTLE
	['corpship']       = 009210,
	['armada_corsair']         = 009220,
	['corroy']         = 009230,

	-- T2 WATER ATTACK
	['armada_lightningship']       = 009280, --ANTISWARM
	['corfship']       = 009290,
	
	['armada_paladin']        = 009300, --MAIN BATTLE
	['corcrus']        = 009310,

	['armada_longbow']       = 009340, --ROCKETS
	['cormship']       = 009350,
	
	['armada_dronecarrier']  = 009360, --DRONE CARRIERS
	['cortex_dronecarrier']  = 009361,

	['armada_dreadnought']        = 009370, --STRONK
	['corbats']        = 009380,

	['armada_epoch']       = 009400, --FLAGSHIPS
	['corblackhy']     = 009410,

	['armada_dolphint3']    = 009450, --SCAV SHIPS
	['coresuppt3']     = 009460,
	['armada_ellysawt3']     = 009470,
	['corslrpc']       = 009480,

	-- T1 AA
	['armada_cyclone']        = 009500,
	['corsfig']        = 009510,

	-- T2 AA
	['armada_dragonslayer']         = 009600,
	['corarch']        = 009610,

	-- UNDERWATER ATTACK
	['armada_puffin']        = 009800,
	['corseap']        = 009810,
	['armada_eel']         = 009820,
	['corsub']         = 009830,

	['armada_cormorant']       = 009900,
	['cortex_angler']       = 009910,
	['armada_barracuda']        = 009920,
	['corshark']       = 009930,
	['armada_serpent']        = 009940,
	['corssub']        = 009950,

	['armada_serpentt3']      = 009960,
	['armada_skatert2']        = 009962,

	-- TRANSPORTS
	['armada_stork']       = 010500,
	['cortex_hercules']        = 010510,

	['armada_convoy']       = 010540,
	['cortship']       = 010550,

	['armada_bearer']       = 010560,
	['corthovr']       = 010570,

	['cortex_intruder']        = 010600,

	['armada_abductor']        = 010610,
	['cortex_skyhook']        = 010620,

	-- ANTINUKES
	['armada_umbrella']        = 020000,
	['cormabm']        = 020010,

	['armada_haven']       = 020100,
	['armada_t2supportship']	   = 020101,
	['armada_haven2']      = 020105,
	['cortex_oasis']       = 020110,
	['corantiship']    = 020111,
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
   ['armada_windturbinet2']       = 101040, --scavengers
   ['cortex_advancedwindturbine']       = 101050, --scavengers
   ['armada_solarcollector']       = 101070,
   ['cortex_solarcollector']       = 101080,
   ['armada_advancedsolarcollector']      = 101100,
   ['cortex_advancedsolarcollector']      = 101150,

   --ECO NRG GEOS
   ['armada_geothermalpowerplant']         = 101200,
   ['armada_geothermalpowerplant']       = 101201,
   ['cortex_geothermalpowerplant']         = 101250,
   --['cortex_navalgeothermalpowerplant']       = 101251,
   ['armada_prude']         = 101300,
   ['cortex_advancedgeothermalpowerplant']        = 101350,
   ['cortex_advancednavalgeothermalpowerplant']      = 101351,
   ['armada_advancedgeothermalpowerplant']        = 101400,
   ['armada_advancedgeothermalpowerplant']      = 101401,
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
   ['armada_aircraftplantt3']        = 102700, --scavengers
   ['cortex_experimentalaircraftplant']        = 102725, --scavengers

   --UTILITIES
   ['armasp']         = 102800, --AIR REPAIR PADS
   ['cortex_airrepairpad']         = 102825,
   ['cortex_floatingairrepairpad']         = 102826,

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
   ['corscavdrag']    = 104205, --scavengers
   ['armada_fortificationwall']        = 104300,
   ['cortex_fortificationwall']        = 104400,
   ['corscavfort']    = 104505, --scavengers
   ['armada_dragonsclaw']        = 104600,
   ['armlwall']       = 104650,
   ['corscavdtl']     = 104705, --scavengers
   ['cortex_dragonsmaw']         = 104800,
   ['cormwall']       = 104850,
   ['corscavdtf']     = 104905, --scavengers
   ['corscavdtm']     = 104915, --scavengers

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
   ['corhllllt']      = 106500, --scavengers
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
   ['cortex_calamity']        = 107600,
   ['legbastion']     = 107650,
   ['armada_pulsart3']      = 107700, --scavengers
   ['cortex_calamityt3']      = 107800, --scavengers

   --DEFENSES LAND LRPC
   ['armada_basilica']       = 110100,
   ['cortex_basilisk']         = 110200,
   ['armminivulc']    = 120100, --scavengers
   ['corminibuzz']    = 120200, --scavengers
   ['legministarfall']= 120250, --scavengers
   ['armada_ragnarok']        = 120300,
   ['cortex_calamity']        = 120400,
   ['legstarfall']    = 120450,
   ['armbotrail']     = 120500, --scavengers

   --DEFENSES AA
   ['armada_nettle']          = 130100,
   ['cortex_thistle']          = 130200,
   ['armada_ferret']      = 130300,
   ['cortex_sam']      = 130400,
   ['armada_chainsaw']         = 130500,
   ['cortex_eradicator']        = 130600,

   ['armada_arbalest']        = 153000,
   ['corflak']        = 153500,
   ['armada_mercury']     = 154000,
   ['cortex_screamer']    = 154500,

   --DEFENSES TO WATER
   ['armada_anemone']          = 155000,
   ['cortex_jellyfish']          = 155500,

   --DEFENSES MISSILE LAUNCHERS
   ['armada_paralyzer']         = 165000,
   ['cortex_catalyst']        = 165500,
   ['armada_citadel']         = 166000,
   ['corfmd']         = 166500,
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
   ['armada_geothermalpowerplant']       = 204000,
   ['cortex_navalgeothermalpowerplant']       = 204100,
   ['armada_advancedgeothermalpowerplant']       = 204500,
   ['cortex_advancednavalgeothermalpowerplant']       = 204600,

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
   ['armada_airrepairpad']        = 220000,
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
