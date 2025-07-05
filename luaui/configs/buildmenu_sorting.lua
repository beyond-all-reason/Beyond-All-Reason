---@type table<string, number>
local unitOrderTable = {
-- UNITS
	--CONSTRUCTORS
	['armck']          = 001100, --BOTS
	['corck']          = 001110,
	['legck']          = 001115,

	['armcv']          = 001120, --VEH
	['corcv']          = 001130,
	['legcv']          = 001135,
	['armbeaver']      = 001140,
	['cormuskrat']     = 001150,
	['legotter']       = 001155,

	['armca']          = 001160, --AIR
	['corca']          = 001165,
	['legca']          = 001166,

	['legassistdrone'] = 001167,
	['armassistdrone'] = 001168, --ASSISTDRONES
	['corassistdrone'] = 001169,

	['armcsa']         = 001170, --SEAPLANES
	['corcsa']         = 001175,

	['armcs']          = 001180, --SHIPS
	['corcs']          = 001190,

	['armch']          = 002000, --HOVER
	['corch']          = 002050,
	['legch']          = 002060,

	['armrectr']       = 002100, --REZ BOTS
	['cornecro']       = 002150,
	['legrezbot']      = 002151,

	['armmlv']         = 002200, --MINELAYERS
	['cormlv']         = 002250,
	['legmlv']         = 002250,

	['armrecl']        = 002300, --REZ SUBS
	['correcl']        = 002350,

	['armack']         = 002400,
	['corack']         = 002450,
	['legack']         = 002455,

	['armacv']         = 002500,
	['coracv']         = 002550,
	['legacv']         = 002555,

	['armaca']         = 002600,
	['coraca']         = 002650,
	['legaca']         = 002660,

	['armacsub']       = 002700,
	['coracsub']       = 002750,

	--NANO SUPPORT
	['armfark']        = 003100, --BOTS
	['corfast']        = 003200,
	['legaceb']        = 003250,

	['armconsul']      = 003300, --VEH
	['legafcv']        = 003305, --VEH
	['corprinter']     = 003325, --VEH
	['corvac']		   = 003326, --VEH
	['corvacct']       = 003327, --VEH
	['corforge']       = 003350, --VEH

	['armmls']         = 003400, --SHIP
	['cormls']         = 003500, --SHIP

	['armdecom']       = 003600, --SUPPORT COMS
	['legdecom']       = 003650,
	['cordecom']       = 003700,

	['cormando']       = 003800, --COMMANDO

	['armspy']         = 003900, --SPIES
	['corspy']         = 004000,
	['legaspy']         = 004001,
	['corphantom']     = 004010,

	-- AIR SCOUTS LAND UNARMED
	['armpeep']        = 004030, --AIR
	['corfink']        = 004040,
	['armsehak']       = 004050, --SEAPLANES
	['corhunt']        = 004060,
	['armawac']        = 004050,
	['corawac']        = 004060,
	['legwhisper']     = 004061,

	-- SCOUTS/UTILITY LAND
	['armmark']        = 004100,
	['corvoyr']        = 004110,
	['legaradk']       = 004115,
	['armaser']        = 004120,
	['corspec']        = 004130,
	['legajamk']       = 004135,

	['armseer']        = 004200,
	['corvrad']        = 004210,
	['armjam']         = 004220,
	['coreter']        = 004230,
	['legavrad']       = 004221,
	['legavjam']       = 004222,

	['armsjam']        = 004250,
	['corsjam']        = 004260,

	-- AIRCRAFT
	['armfig']         = 004300, --FIGHTERS
	['corveng']        = 004305,
	['legfig']         = 004306,
	['armhawk']        = 004310, --FIGHTERS T2
	['corvamp']        = 004315,
	['legionnaire']    = 004316,
	['legafigdef']     = 004316,
	['legvenator']     = 004317,
	['armsfig2']       = 004316, -- T2 Heavy Fighter (air rework mod)
	['corsfig2']       = 004317,

	['armkam']         = 004320, --GUNSHIPS
	['legmos']         = 004322,
	['armsaber']       = 004325,
	['corcut']         = 004330,
	['legstronghold']  = 004331,

	['armbrawl']       = 004335, --GUNSHIPS T2
	['corape']         = 004340,
	['armblade']       = 004345,
	['corcrw']         = 004348,
	['corcrwh']         = 004347,
	['legfort']        = 004349,

	['armthund']       = 004350, --BOMBERS
	['corshad']        = 004355,
	['legcib']         = 004356,
	['legkam']         = 004357,
	['armsb']          = 004360,
	['corsb']          = 004365,
	--['legphoenix']     = 004366,

	['armpnix']        = 004370, --BOMBERS T2
	['corhurc']        = 004380,
	['legnap']         = 004381,
	['legmineb']       = 004382,
	['legphoenix']     = 004383,
	['armliche']       = 004385,
	['armstil']        = 004390,

	-- SCOUTS LAND ARMED
	['armflea']        = 004400, --BOTS

	['armfav']         = 004410, --VEH
	['corfav']         = 004420,
	['legscout']       = 004430,

	['armsh']          = 004500, --HOVER
	['corsh']          = 004510,
	['legsh']          = 004520,

	-- EMP
	['corbw']          = 004800, --EMP
	['armspid']        = 004810, --EMP

	-- T1 LAND ATTACK
	['armpw']          = 005000, --FAST
	['corak']          = 005010,
	['leggob']		   = 005015,
	['leglob']         = 005016,
	['armflash']       = 005020,
	['corgator']       = 005030,
	['leghades']	   = 005031,
	['legcen']		   = 005032,

	['armjanus']       = 005200, --MAIN BATTLE
	['corlevlr']       = 005210,
	['armstump']       = 005220,
	['corraid']        = 005230,
	['leghelios']	   = 005231,
	['leggat']		   = 005232,
	['armanac']        = 005240,
	['corsnap']        = 005250,
	['legner']         = 005255,

	['armrock']        = 005300, --ROCKETS
	['corstorm']       = 005310,
	['legbal']		   = 005311,

	['armham']         = 005400, --ARTILLERY
	['cormug']		   = 005405,
	['corthud']        = 005410,
	['armart']         = 005420,
	['corwolv']        = 005430,
	['legbar']         = 005435,
	['armmh']          = 005440,
	['cormh']          = 005450,
	['legmh']         = 005460,


	['armwar']         = 005600, --STRONK
	['legkark']        = 005610,
	['corkark']        = 005620,

	['armsam']         = 005800, --LAND + AA
	['cormist']        = 005810,
	['legrail']		   = 005811,

	['armpincer']      = 005900, --LAND + AMPHIBIOUS
	['corgarp']        = 005910,
	['legamphtank']    = 005920,

	-- T2 LAND ATTACK
	['armgremlin']     = 006005,

	['armfast']        = 006100, --FAST
	['legstr']         = 006105,
	['corpyro']        = 006110,
	['armlatnk']       = 006120,
	['cortorch']       = 006125,
	['legmrv']         = 006130,

	['armzeus']        = 006300, --MAIN BATTLE
	['armmav']         = 006310,
	['armbull']        = 006320,
	['corftiger']      = 006325,
	['correap']        = 006330,
	['legaskirmtank']         = 006335,
	['armmanni']       = 006340,
	['corgatreap']     = 006350,

	['corhrk']         = 006400, --ROCKETS
	['leghrk']         = 006410,
	['corvroc']        = 006420,
	['armmerl']        = 006430,
	['legavroc']       = 006435,
	['corban']         = 006440,
	['legmed']         = 006450,

	['armfido']        = 006500, --ARTILLERY
	['cormort']        = 006510,
	['legbart']        = 006515,
	['legvcarry']      = 006516,
	['armmart']        = 006520,
	['cormart']        = 006530,
	['legamcluster']   = 006535,
	['cortrem']        = 006540,
	['leginf']         = 006550,

	['armsptk']        = 006600, --ALL-TERRAIN
	['cortermite']     = 006610,
	['leginfestor']    = 006614,
	['legsrail']       = 006615,
	['legsrailt4']     = 006616,

	['armfboy']        = 006700, --STRONK
	['corcan']         = 006710,
	['legshot']        = 006715,
	['armsnipe']       = 006720,
	['cordeadeye']     = 006725,
	['corsumo']        = 006730,
	['corgol']         = 006740,
	['leginc']         = 006750,
	['legaheattank']   = 006760,

	['armvader']       = 006810, --AMPHIBIOUS KAMIKAZE BOMBS
	['corroach']       = 006820,
	['legsnapper']       = 006825,
	['corsktl']        = 006830,

	['armamph']        = 006900, --LAND + AMPHIBIOUS
	['coramph']        = 006910,
	['legamph']        = 006915,
	['armcroc']        = 006920,
	['corseal']        = 006930,
	['corsala']        = 006935,
	['corparrow']      = 006940,
	['legfloat']       = 006941,

   -- T2 HOVER
   ['corhal']         = 006950,

	--T3 LAND ATTACK
	['armmar']         		= 007000,
	['legjav']         		= 007005,
	['corcat']         		= 007010,
	['legbunk']        		= 007015,
	['armraz']         		= 007020,
	['corkarg']        		= 007030,
	['armvang']        		= 007040,
	['legeallterrainmech']  = 007041,
	['legelrpcmech']       	= 007042,
	['corshiva']       		= 007050,
	['legkeres']	   		= 007051,
	['legerailtank']   		= 007052,
	['legpede']        		= 007055,
	['armthor']        		= 007060,
	['legeshotgunmech']		= 007065,
	['leegmech']			= 007066,
	['corkorg']        		= 007070,
	['legeheatraymech'] 	= 007071,
	['armbanth']       		= 007080,
	['corjugg']        		= 007090,

	--T3 HOVER
	['armlun']         = 007100, --hover
	['corsok']         = 007110, --hover
	['legehovertank']  = 007111, --hover

	--T4 LAND ATTACK (SCAVS)
	['armmeatball']    = 007200,
	['armlunchbox']    = 007210,
	['armassimilator'] = 007220,

	['armpwt4']        = 007300,
    ['corakt4']        = 007310,
    ['leggobt3']       = 007315,
	['armsptkt4']      = 007320,
	['cordemon']     = 007330,
	['corkarganetht4'] = 007340,
	['corthermite'] = 007341,

	['armvadert4']     = 007400,
	['armrattet4']     = 007410,
	['corgolt4']       = 007420,

	['armthundt4']     = 007500,
	['armfepocht4']    = 007510,
	['corfblackhyt4']  = 007520,
	['legmost3']       = 007525,
	['corcrwt4']       = 007530,
	['legfortt4']       = 007540,

	-- LAND AA
	['armjeth']        = 008000,
	['corcrash']       = 008010,
	['legaabot']       = 008011,
	['armaak']         = 008020,
	['coraak']         = 008030,
	['legadvaabot']    = 008031,

	['armyork']        = 008200,
	['corsent']        = 008210,
	['legvflak']        = 008220,

	['armah']          = 008300,
	['corah']          = 008310,
	['legah']         = 008320,

	-- -- T2 AA
	-- ['armaak']         = 008500,
	-- ['coraak']         = 008510,

	-- ['armyork']        = 008520,
	-- ['corsent']        = 008530,

	-- ['armhawk']        = 008540,
	-- ['corvamp']        = 008550,

	-- WATER SCOUTS
	['armpt']          = 009000, --SCOUTS AA
	['coresupp']       = 009010,
	['legpontus']       = 009015,

	-- T1 WATER ATTACK
	['armdecade']      = 009100, --FAST
	['corpt']          = 009110,
	['legvelite']      = 009120,

	['armpship']       = 009200, --MAIN BATTLE
	['corpship']       = 009210,
	['leghastatus']    = 009210,
	['armroy']         = 009220,
	['corroy']         = 009230,

	-- T2 WATER ATTACK
	['armlship']       = 009280, --ANTISWARM
	['corfship']       = 009290,

	['armcrus']        = 009300, --MAIN BATTLE
	['corcrus']        = 009310,

	['armmship']       = 009340, --ROCKETS
	['cormship']       = 009350,

	['armdronecarry']  = 009360, --DRONE CARRIERS
	['cordronecarry']  = 009361,
	['armdtrident']  = 009362, --DEPTH CHARGE DRONE CARRIERS
	['corsentinel']  = 009363,

	['armbats']        = 009370, --STRONK
	['corbats']        = 009380,

	['armepoch']       = 009400, --FLAGSHIPS
	['corblackhy']     = 009410,

	['armdecadet3']    = 009450, --SCAV SHIPS
	['coresuppt3']     = 009460,
	['armpshipt3']     = 009470,
	['corslrpc']       = 009480,

	-- T1 AA
	['armsfig']        = 009500,
	['corsfig']        = 009510,

	-- T2 AA
	['armaas']         = 009600,
	['corarch']        = 009610,

	-- UNDERWATER ATTACK
	['armseap']        = 009800,
	['corseap']        = 009810,
	['armsub']         = 009820,
	['corsub']         = 009830,

	['armlance']       = 009900,
	['cortitan']       = 009910,
	['legatorpbomber'] = 009915,
	['armsubk']        = 009920,
	['corshark']       = 009930,
	['armserp']        = 009940,
	['corssub']        = 009941,
	['coronager']      = 009950,
	['armexcalibur']   = 009951,
	['cordesolator']   = 009952,
	['armseadragon']   = 009953,


	['armserpt3']      = 009960,
	['armptt2']        = 009962,

	-- TRANSPORTS
	['armatlas']       = 010500,
	['corvalk']        = 010505,
	['corhvytrans']      = 010510,
	['armhvytrans']      = 010515,
	['leglts']      = 010520,
	['legatrans']      = 010525,

	['armtship']       = 010540,
	['cortship']       = 010550,

	['armthovr']       = 010560,
	['corthovr']       = 010570,

	['corintr']        = 010600,

	['armdfly']        = 010610,
	['corseah']        = 010620,

	-- ANTINUKES
	['armscab']        = 020000,
	['cormabm']        = 020010,

	['armcarry']       = 020100,
	['armantiship']	   = 020101,
	['corcarry']       = 020110,
	['corantiship']    = 020111,

-- BUILDINGS
   --ECO METAL MEX
   ['armmex']         = 100000,
   ['cormex']         = 100050,
   ['legmex']         = 100060,
   ['armamex']        = 100100,
   ['corexp']         = 100150,
   ['legmext15']      = 100160,

   ['armmoho']        = 100200,
   ['cormoho']        = 100250,
   ['legmoho']       = 100260,
   ['armshockwave']   = 100290,
   ['cormexp']        = 100300,
   ['legmohocon']     = 100310,

   --ECO ENERGY CONVERTERS
   ['armmakr']        = 100500,
   ['cormakr']        = 100550,
   ['legeconv']       = 100550,
   ['armmmkr']        = 100600,
   ['cormmkr']        = 100650,
   ['legadveconv']    = 100651,

   --ECO METAL STORAGE
   ['armmstor']       = 100800,
   ['cormstor']       = 100850,
   ['legmstor']       = 100860,
   ['armuwadvms']     = 100900,
   ['coruwadvms']     = 100950,
   ['legamstor']      = 100960,

   --ECO NRG GENS
   ['armwin']         = 101000,
   ['corwin']         = 101020,
   ['legwin']         = 101060,
   ['armwint2']       = 101040, --scavengers
   ['corwint2']       = 101050, --scavengers
   ['legwint2']       = 101060, --scavengers
   ['armsolar']       = 101070,
   ['corsolar']       = 101080,
   ['legsolar']       = 101090,
   ['armadvsol']      = 101100,
   ['coradvsol']      = 101150,
   ['legadvsol']      = 101170,

   --ECO NRG GEOS
   ['armgeo']         = 101200,
   --['armuwgeo']       = 101201,
   ['corgeo']         = 101250,
   --['coruwgeo']       = 101251,
   ['leggeo']         = 101275,
   ['armgmm']         = 101300,
   ['legageo']        = 101325,
   ['corageo']        = 101350,
   --['coruwageo']      = 101351,
   ['armageo']        = 101400,
   --['armuwageo']      = 101401,
   ['corbhmth']       = 101450,
   ['legrampart']       = 101475,

   --ECO NRG FUSIONS
   ['armfus']         = 101525,
   ['armckfus']       = 101550,
   ['corfus']         = 101600,
   ['legfus']         = 101650,
   ['armafus']        = 101700,
   ['corafus']        = 101750,
   ['legafus'] 		  = 101780,

   --ECO NRG STORAGE
   ['armestor']       = 101800,
   ['corestor']       = 101850,
   ['legestor']       = 101875,
   ['armuwadves']     = 101900,
   ['coruwadves']     = 101950,
   ['legadvestore']   = 101951,

   --NANOS
   ['armnanotc']      = 102010,
   ['cornanotc']      = 102020,
   ['legnanotc']      = 102030,
   ['armnanotct2']      = 102010,
   ['cornanotct2']      = 102020,
   ['legnanotct2']      = 102030,

   --FACTORIES
   ['armlab']         = 102100,
   ['corlab']         = 102125,
   ['leglab']         = 102126,
   ['armvp']          = 102150,
   ['corvp']          = 102175,
   ['legvp']          = 102176,
   ['armap']          = 102200,
   ['corap']          = 102225,
   ['legap']          = 102230,
   ['armhp']          = 102250,
   ['corhp']          = 102275,
   ['leghp']          = 102278,

   ['armalab']        = 102400,
   ['coralab']        = 102425,
   ['legalab']        = 102426,
   ['armavp']         = 102450,
   ['coravp']         = 102475,
   ['legavp']         = 102477,
   ['armaap']         = 102500,
   ['coraap']         = 102525,
   ['legaap']         = 102530,
   ['armshltx']       = 102550,
   ['corgant']        = 102575,
   ['leggant']        = 102576,
   ['armapt3']        = 102700, --scavengers
   ['corapt3']        = 102725, --scavengers

   --UTILITIES
   ['armasp']         = 102800, --AIR REPAIR PADS
   ['corasp']         = 102825,
   ['corfasp']         = 102826,

   ['armeyes']        = 103000,
   ['coreyes']        = 103050,
   ['legeyes']        = 103075,
   ['armrad']         = 103100,
   ['corrad']         = 103150,
   ['legrad']         = 103160,
   ['armarad']        = 103200,
   ['corarad']        = 103250,
   ['legarad']        = 103251,
   ['armjamt']        = 103300,
   ['corjamt']        = 103350,
   ['legjam']         = 103360,
   ['armveil']        = 103400,
   ['corshroud']      = 103450,
   ['legajam']        = 103451,
   ['armjuno']        = 103500,
   ['corjuno']        = 103550,
   ['legjuno']        = 103551,

   ['armsd']          = 103600,
   ['corsd']          = 103625,
   ['legsd']          = 103626,
   ['armtarg']        = 103650,
   ['cortarg']        = 103675,
   ['legtarg']        = 103676,
   ['armgate']        = 103700,
   ['legdeflector']   = 103701,
   ['corgate']        = 103725,
   ['armdf']          = 103750, --Fake Fusion

   --DEFENSES LAND (WALLS)
   ['armdrag']        = 104000,
   ['cordrag']        = 104100,
   ['corscavdrag']    = 104205, --scavengers
   ['legdrag'] 	      = 104206, --exscavengers
   ['armfort']        = 104300,
   ['corfort']        = 104400,
   ['corscavfort']    = 104505, --scavengers
   ['legforti']       = 104506, --exscavengers
   ['armclaw']        = 104600,
   ['armlwall']       = 104650,
   ['legdtr']     	  = 104704, --legion
   ['corscavdtl']     = 104705, --scavengers
   ['legdtl']         = 104706, --exscavengers
   ['cormaw']         = 104800,
   ['cormwall']       = 104850,
   ['legrwall']       = 104875,
   ['corscavdtf']     = 104905, --scavengers
   ['legdtf']         = 104906, --exscavengers
   ['corscavdtm']     = 104915, --scavengers
   ['legdtm']         = 104916, --exscavengers

   --MINES
   ['armmine1']       = 105100,
   ['cormine1']       = 105200,
   ['legmine1']       = 105250,
   ['armmine2']       = 105300,
   ['cormine2']       = 105400,
   ['legmine2']       = 105450,
   ['cormine4']       = 105500, --cormando
   ['armmine3']       = 105600,
   ['cormine3']       = 105700,
   ['legmine3']       = 105750,

   --DEFENSES LAND T1
   ['armllt']         = 106100,
   ['corllt']         = 106200,
   ['leglht']         = 106250,
   ['armbeamer']      = 106300,
   ['corhllt']        = 106400,
   ['corhllllt']      = 106500, --scavengers
   ['armhlt']         = 106600,
   ['corhlt']         = 106700,
   ['leghive']  = 106800,
   ['armguard']       = 106800,
   ['corpun']         = 106900,
   ['legcluster']         = 106950,

   --DEFENSES LAND T2
   ['legmg']          = 107000, --land/AA machinegun
   ['armpb']          = 107100,
   ['corvipe']        = 107200,
   ['legbombard']     = 107250,
   ['legapopupdef']   = 107251,
   ['armamb']         = 107300,
   ['cortoast']       = 107400,
   ['legacluster']	  = 107450,
   ['armanni']        = 107500,
   ['cordoom']        = 107600,
   ['legbastion']     = 107650,
   ['armannit3']      = 107700, --scavengers
   ['cordoomt3']      = 107800, --scavengers

   --DEFENSES LAND LRPC
   ['armbrtha']       = 110100,
   ['corint']         = 110200,
   ['leglrpc']		  = 110300,
   ['armminivulc']    = 120100, --scavengers
   ['corminibuzz']    = 120200, --scavengers
   ['legministarfall']= 120250, --scavengers
   ['armvulc']        = 120300,
   ['corbuzz']        = 120400,
   ['legstarfall']    = 120450,
   ['armbotrail']     = 120500, --scavengers

   --DEFENSES AA
   ['armrl']          = 130100,
   ['corrl']          = 130200,
   ['legrl']          = 130250,
   ['armferret']      = 130300,
   ['cormadsam']      = 130400,
   ['legrhapsis']      = 130450,
   ['armcir']         = 130500,
   ['corerad']        = 130600,
   ['leglupara']        = 130700,

   ['armflak']        = 153000,
   ['corflak']        = 153500,
   ['legflak']        = 153600,
   ['armmercury']     = 154000,
   ['corscreamer']    = 154500,
   ['leglraa']    	  = 154600,

   --DEFENSES TO WATER
   ['armdl']          = 155000,
   ['cordl']          = 155500,
   ['legctl']         = 155501,

   --DEFENSES MISSILE LAUNCHERS
   ['armemp']         = 165000,
   ['cortron']        = 165500,
   ['legperdition']   = 165600,
   ['armamd']         = 166000,
   ['legabm']         = 166250,
   ['corfmd']         = 166500,
   ['armsilo']        = 180000,
   ['corsilo']        = 180500,
   ['legsilo']        = 180600,

   --WATER ECO METAL
   ['armuwmme']       = 200000,
   ['coruwmme']       = 200100,

   --WATER ECO NRG CONVERTERS
   ['armfmkr']        = 200400,
   ['corfmkr']        = 200500,
   ['legfeconv']        = 200550,
   ['armuwmmm']       = 200600,
   ['coruwmmm']       = 200700,

   --WATER ECO METAL STORAGE
   ['armuwms']        = 201000,
   ['coruwms']        = 201500,
   ['leguwmstore']    = 201501,

   --WATER ECO NRG GENS
   ['armtide']        = 203000,
   ['cortide']        = 203100,
   ['legtide']        = 203200,

   --WATER ECO NRG GEOS
   ['armuwgeo']       = 204000,
   ['coruwgeo']       = 204100,
   ['leguwgeo']       = 204101,
   ['armuwageo']      = 204500,
   ['coruwageo']      = 204600,

   --WATER ECO NRG FUSIONS
   ['armuwfus']       = 205000,
   ['coruwfus']       = 205500,

   --WATER ECO NRG STORAGE
   ['armuwes']        = 207000,
   ['coruwes']        = 207500,
   ['leguwestore']    = 207501,

   --WATER CONSTRUCTION
   ['armnanotcplat']  = 210000,
   ['cornanotcplat']  = 210500,
   ['legnanotcplat']  = 210550,

   ['armsy']          = 211100,
   ['corsy']          = 211200,
   ['legjim']          = 211300,
   ['armfhp']         = 212100,
   ['corfhp']         = 212200,
   ['legfhp']         = 212250,
   ['armamsub']       = 213100,
   ['coramsub']       = 213200,
   ['legamphlab']       = 213250,
   ['armplat']        = 214100,
   ['corplat']        = 214200,
   	--T2
   ['armasy']         = 215000,
   ['corasy']         = 215100,
   	--T3
   ['armshltxuw']     = 216100,
   ['corgantuw']      = 216200,

   --WATER MINES
   ['armfmine3']      = 217100,
   ['corfmine3']      = 217200,

   --WATER UTILITIES
   ['armfasp']        = 220000,
   ['corfasp']        = 220050,
   ['armfrad']        = 220100,
   ['legfrad']        = 220101,
   ['corfrad']        = 220150,
   ['armason']        = 220200,
   ['corason']        = 220250,
   ['armfatf']        = 220400,
   ['corfatf']        = 220450,

   --WATER DEFENSES LAND
   ['armfdrag']       = 230100,
   ['corfdrag']       = 230200,
   ['legfdrag']       = 230250,
   ['armfhlt']        = 230300,
   ['corfhlt']        = 230400,
   ['legfmg']        = 230401,
   ['legfhive']        = 230450,
   ['armkraken']      = 230500,
   ['corfdoom']       = 230600,

   --WATER DEFENSES AA
   ['armfrt']         = 255100,
   ['corfrt']         = 255200,
   ['legfrl']         = 255200,
   ['armfflak']       = 255300,
   ['corenaa']        = 255400,

   --WATER DEFENSES NAVAL
   ['armtl']          = 260300,
   ['cortl']          = 260400,
   ['legtl']          = 260401,
   ['armatl']         = 260500,
   ['coratl']         = 260600,
}

---@type table<string, number>
local newUnitOrder = {}
for id, value in pairs(unitOrderTable) do
	if UnitDefNames[id] then
		newUnitOrder[UnitDefNames[id].id] = value
	end
end
unitOrderTable = newUnitOrder

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.isscavenger then
		local counterpartId = UnitDefNames[unitDef.customParams.fromunit].id
		if unitOrderTable[counterpartId] then
			unitOrderTable[unitDefID] = unitOrderTable[counterpartId]
		end
	end
end

return unitOrderTable
