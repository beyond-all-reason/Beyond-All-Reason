local UDN = UnitDefNames

local unitOrderTable = {
-- UNITS
	--CONSTRUCTORS
	[UDN["armck"].id]          = 000100, --BOTS
	[UDN["corck"].id]          = 000110,

	[UDN["armcv"].id]          = 000120, --VEH
	[UDN["corcv"].id]          = 000130,
	[UDN["armbeaver"].id]      = 000140,
	[UDN["cormuskrat"].id]     = 000150,

	[UDN["armca"].id]          = 000160, --AIR
	[UDN["corca"].id]          = 000165,

	[UDN["armassistdrone"].id] = 000168, --ASSISTDRONES
	[UDN["corassistdrone"].id] = 000169,

	[UDN["armcsa"].id]         = 000170, --SEAPLANES
	[UDN["corcsa"].id]         = 000175,

	[UDN["armcs"].id]          = 000180, --SHIPS
	[UDN["corcs"].id]          = 000190,

	[UDN["armch"].id]          = 000200, --HOVER
	[UDN["corch"].id]          = 000210,

	[UDN["armrectr"].id]       = 000300, --REZ BOTS
	[UDN["cornecro"].id]       = 000310,

	[UDN["armmlv"].id]         = 000350, --MINELAYERS
	[UDN["cormlv"].id]         = 000360,

	[UDN["armrecl"].id]        = 000400, --REZ SUBS
	[UDN["correcl"].id]        = 000410,

	[UDN["armack"].id]         = 000500,
	[UDN["corack"].id]         = 000510,

	[UDN["armacv"].id]         = 000600,
	[UDN["coracv"].id]         = 000610,

	[UDN["armaca"].id]         = 000700,
	[UDN["coraca"].id]         = 000710,

	[UDN["armacsub"].id]       = 000800,
	[UDN["coracsub"].id]       = 000810,

	--NANO SUPPORT
	[UDN["armfark"].id]        = 001000, --BOTS
	[UDN["corfast"].id]        = 001010,

	[UDN["armconsul"].id]      = 001020, --VEH

	[UDN["armmls"].id]         = 001030, --SHIP
	[UDN["cormls"].id]         = 001040, --SHIP

	[UDN["armdecom"].id]       = 001050, --SUPPORT COMS
	[UDN["cordecom"].id]       = 001060,

	[UDN["cormando"].id]       = 001070, --COMMANDO

	[UDN["armspy"].id]         = 001100, --SPIES
	[UDN["corspy"].id]         = 001110,

	-- AIR SCOUTS LAND UNARMED
	[UDN["armpeep"].id]        = 004030, --AIR
	[UDN["corfink"].id]        = 004040,
	[UDN["armsehak"].id]       = 004050, --SEAPLANES
	[UDN["corhunt"].id]        = 004060,
	[UDN["armawac"].id]        = 004050,
	[UDN["corawac"].id]        = 004060,

	-- SCOUTS/UTILITY LAND
	[UDN["armmark"].id]        = 004100,
	[UDN["corvoyr"].id]        = 004110,
	[UDN["armaser"].id]        = 004120,
	[UDN["corspec"].id]        = 004130,

	[UDN["armseer"].id]        = 004200,
	[UDN["corvrad"].id]        = 004210,
	[UDN["armjam"].id]         = 004220,
	[UDN["coreter"].id]        = 004230,

	[UDN["armsjam"].id]        = 004250,
	[UDN["corsjam"].id]        = 004260,

	-- AIRCRAFT
	[UDN["armfig"].id]         = 004300, --FIGHTERS
	[UDN["corveng"].id]        = 004305,
	[UDN["armhawk"].id]        = 004310, --FIGHTERS T2
	[UDN["corvamp"].id]        = 004315,

	[UDN["armkam"].id]         = 004320, --GUNSHIPS
	[UDN["armsaber"].id]       = 004325,
	[UDN["corcut"].id]         = 004330,

	[UDN["armbrawl"].id]       = 004335, --GUNSHIPS T2
	[UDN["corape"].id]         = 004340,
	[UDN["armblade"].id]       = 004345,
	[UDN["corcrw"].id]         = 004348,

	[UDN["armthund"].id]       = 004350, --BOMBERS
	[UDN["corshad"].id]        = 004355,
	[UDN["armsb"].id]          = 004360,
	[UDN["corsb"].id]          = 004365,

	[UDN["armpnix"].id]        = 004370, --BOMBERS T2
	[UDN["corhurc"].id]        = 004380,
	[UDN["armliche"].id]       = 004385,
	[UDN["armstil"].id]        = 004390,

	-- SCOUTS LAND ARMED
	[UDN["armflea"].id]        = 004400, --BOTS

	[UDN["armfav"].id]         = 004410, --VEH
	[UDN["corfav"].id]         = 004420,

	[UDN["armsh"].id]          = 004500, --HOVER
	[UDN["corsh"].id]          = 004510,

	-- EMP
	[UDN["corbw"].id]          = 004800, --EMP
	[UDN["armspid"].id]        = 004810, --EMP

	-- T1 LAND ATTACK
	[UDN["armpw"].id]          = 005000, --FAST
	[UDN["corak"].id]          = 005010,
	[UDN["armflash"].id]       = 005020,
	[UDN["corgator"].id]       = 005030,

	[UDN["armjanus"].id]       = 005200, --MAIN BATTLE
	[UDN["corlevlr"].id]       = 005210,
	[UDN["armstump"].id]       = 005220,
	[UDN["corraid"].id]        = 005230,
	[UDN["armanac"].id]        = 005240,
	[UDN["corsnap"].id]        = 005250,

	[UDN["armrock"].id]        = 005300, --ROCKETS
	[UDN["corstorm"].id]       = 005310,

	[UDN["armham"].id]         = 005400, --ARTILLERY
	[UDN["corthud"].id]        = 005410,
	[UDN["armart"].id]         = 005420,
	[UDN["corwolv"].id]        = 005430,
	[UDN["armmh"].id]          = 005420,
	[UDN["cormh"].id]          = 005430,

	[UDN["armwar"].id]         = 005600, --STRONK
	[UDN["corkark"].id]        = 005610,

	[UDN["armsam"].id]         = 005800, --LAND + AA
	[UDN["cormist"].id]        = 005810,

	[UDN["armpincer"].id]      = 005900, --LAND + AMPHIBIOUS
	[UDN["corgarp"].id]        = 005910,

	-- T2 LAND ATTACK
	[UDN["armgremlin"].id]     = 006005,

	[UDN["armfast"].id]        = 006100, --FAST
	[UDN["corpyro"].id]        = 006110,
	[UDN["armlatnk"].id]       = 006120,

	[UDN["armzeus"].id]        = 006300, --MAIN BATTLE
	[UDN["armmav"].id]         = 006310,
	[UDN["armbull"].id]        = 006320,
	[UDN["correap"].id]        = 006330,
	[UDN["armmanni"].id]       = 006340,
	[UDN["corgatreap"].id]     = 006350,

	[UDN["corhrk"].id]         = 006400, --ROCKETS
	[UDN["armmerl"].id]        = 006410,
	[UDN["corvroc"].id]        = 006420,
	[UDN["armmerl"].id]        = 006430,
	[UDN["corban"].id]         = 006440,

	[UDN["armfido"].id]        = 006500, --ARTILLERY
	[UDN["cormort"].id]        = 006510,
	[UDN["armmart"].id]        = 006520,
	[UDN["cormart"].id]        = 006530,
	[UDN["cortrem"].id]        = 006540,

	[UDN["armsptk"].id]        = 006600, --ALL-TERRAIN
	[UDN["cortermite"].id]     = 006610,

	[UDN["armfboy"].id]        = 006700, --STRONK
	[UDN["corcan"].id]         = 006710,
	[UDN["armsnipe"].id]       = 006720,
	[UDN["corsumo"].id]        = 006730,
	[UDN["corgol"].id]         = 006740,

	[UDN["armvader"].id]       = 006810, --AMPHIBIOUS KAMIKAZE BOMBS
	[UDN["corroach"].id]       = 006820,
	[UDN["corsktl"].id]        = 006830,

	[UDN["armamph"].id]        = 006900, --LAND + AMPHIBIOUS
	[UDN["coramph"].id]        = 006910,
	[UDN["armcroc"].id]        = 006920,
	[UDN["corseal"].id]        = 006930,
	[UDN["corparrow"].id]      = 006940,

	--T3 LAND ATTACK
	[UDN["armmar"].id]         = 007000,
	[UDN["corcat"].id]         = 007010,
	[UDN["armraz"].id]         = 007020,
	[UDN["corkarg"].id]        = 007030,
	[UDN["armvang"].id]        = 007040,
	[UDN["corshiva"].id]       = 007050,
	[UDN["armthor"].id]        = 007060,
	[UDN["corkorg"].id]        = 007070,
	[UDN["armbanth"].id]       = 007080,
	[UDN["corjugg"].id]        = 007090,

	--T3 HOVER
	[UDN["armlun"].id]         = 007100, --hover
	[UDN["corsok"].id]         = 007110, --hover

	--T4 LAND ATTACK (SCAVS)
	[UDN["armmeatball"].id]    = 007200,
	[UDN["armlunchbox"].id]    = 007210,
	[UDN["armassimilator"].id] = 007220,

	[UDN["armpwt4"].id]        = 007300,
	[UDN["armsptkt4"].id]      = 007310,
	[UDN["cordemont4"].id]     = 007320,
	[UDN["corkarganetht4"].id] = 007330,

	[UDN["armvadert4"].id]     = 007400,
	[UDN["armrattet4"].id]     = 007410,
	[UDN["corgolt4"].id]       = 007420,

	[UDN["armthundt4"].id]     = 007500,
	[UDN["armfepocht4"].id]    = 007510,
	[UDN["corfblackhyt4"].id]  = 007520,
	[UDN["corcrwt4"].id]       = 007530,

	-- LAND AA
	[UDN["armjeth"].id]        = 008000,
	[UDN["corcrash"].id]       = 008010,
	[UDN["armaak"].id]         = 008020,
	[UDN["coraak"].id]         = 008030,

	[UDN["armyork"].id]        = 008200,
	[UDN["corsent"].id]        = 008210,

	[UDN["armah"].id]          = 008300,
	[UDN["corah"].id]          = 008310,

	-- -- T2 AA
	-- [UDN["armaak"].id]         = 008500,
	-- [UDN["coraak"].id]         = 008510,

	-- [UDN["armyork"].id]        = 008520,
	-- [UDN["corsent"].id]        = 008530,

	-- [UDN["armhawk"].id]        = 008540,
	-- [UDN["corvamp"].id]        = 008550,

	-- WATER SCOUTS
	[UDN["armpt"].id]          = 009000, --SCOUTS AA
	[UDN["coresupp"].id]       = 009010,

	-- T1 WATER ATTACK
	[UDN["armdecade"].id]      = 009100, --FAST
	[UDN["corpt"].id]          = 009110,

	[UDN["armpship"].id]       = 009200, --MAIN BATTLE
	[UDN["corpship"].id]       = 009210,
	[UDN["armroy"].id]         = 009220,
	[UDN["corroy"].id]         = 009230,

	-- T2 WATER ATTACK
	[UDN["armcrus"].id]        = 009300, --MAIN BATTLE
	[UDN["corcrus"].id]        = 009310,

	[UDN["armmship"].id]       = 009340, --ROCKETS
	[UDN["cormship"].id]       = 009350,

	[UDN["armbats"].id]        = 009370, --STRONK
	[UDN["corbats"].id]        = 009380,

	[UDN["armepoch"].id]       = 009400, --FLAGSHIPS
	[UDN["corblackhy"].id]     = 009410,

	[UDN["armdecadet3"].id]    = 009450, --SCAV SHIPS
	[UDN["coresuppt3"].id]     = 009460,
	[UDN["armpshipt3"].id]     = 009470,
	[UDN["corslrpc"].id]       = 009480,

	-- T1 AA
	[UDN["armsfig"].id]        = 009500,
	[UDN["corsfig"].id]        = 009510,

	-- T2 AA
	[UDN["armaas"].id]         = 009600,
	[UDN["corarch"].id]        = 009610,

	-- UNDERWATER ATTACK
	[UDN["armseap"].id]        = 009800,
	[UDN["corseap"].id]        = 009810,
	[UDN["armsub"].id]         = 009820,
	[UDN["corsub"].id]         = 009830,

	[UDN["armlance"].id]       = 009900,
	[UDN["cortitan"].id]       = 009910,
	[UDN["armsubk"].id]        = 009920,
	[UDN["corshark"].id]       = 009930,
	[UDN["armserp"].id]        = 009940,
	[UDN["corssub"].id]        = 009950,

	[UDN["armserpt3"].id]      = 009960,
	[UDN["armptt2"].id]        = 009962,

	-- TRANSPORTS
	[UDN["armatlas"].id]       = 010500,
	[UDN["corvalk"].id]        = 010510,

	[UDN["armtship"].id]       = 010540,
	[UDN["cortship"].id]       = 010550,

	[UDN["armthovr"].id]       = 010560,
	[UDN["corthovr"].id]       = 010570,

	[UDN["corintr"].id]        = 010600,

	[UDN["armdfly"].id]        = 010610,
	[UDN["corseah"].id]        = 010620,

	-- ANTINUKES
	[UDN["armscab"].id]        = 020000,
	[UDN["cormabm"].id]        = 020010,

	[UDN["armcarry"].id]       = 020100,
	[UDN["corcarry"].id]       = 020110,

-- BUILDINGS
   --ECO METAL MEX
   [UDN["armmex"].id]         = 100000,
   [UDN["cormex"].id]         = 100050,
   [UDN["armamex"].id]        = 100100,
   [UDN["corexp"].id]         = 100150,

   [UDN["armmoho"].id]        = 100200,
   [UDN["cormoho"].id]        = 100250,
   [UDN["cormexp"].id]        = 100300,

   --ECO ENERGY CONVERTERS
   [UDN["armmakr"].id]        = 100500,
   [UDN["cormakr"].id]        = 100550,
   [UDN["armmmkr"].id]        = 100600,
   [UDN["cormmkr"].id]        = 100650,

   --ECO METAL STORAGE
   [UDN["armmstor"].id]       = 100800,
   [UDN["cormstor"].id]       = 100850,
   [UDN["armuwadvms"].id]     = 100900,
   [UDN["coruwadvms"].id]     = 100950,

   --ECO NRG GENS
   [UDN["armwin"].id]         = 101000,
   [UDN["corwin"].id]         = 101020, 
   [UDN["armwint2"].id]       = 101040, --scavengers
   [UDN["corwint2"].id]       = 101050, --scavengers
   [UDN["armsolar"].id]       = 101070,
   [UDN["corsolar"].id]       = 101080,
   [UDN["armadvsol"].id]      = 101100,
   [UDN["coradvsol"].id]      = 101150,

   --ECO NRG GEOS
   [UDN["armgeo"].id]         = 101200,
   [UDN["corgeo"].id]         = 101250,
   [UDN["armgmm"].id]         = 101300,
   [UDN["corageo"].id]        = 101350,
   [UDN["armageo"].id]        = 101400,
   [UDN["corbhmth"].id]       = 101450,

   --ECO NRG FUSIONS
   [UDN["armfus"].id]         = 101525,
   [UDN["armckfus"].id]       = 101550,
   [UDN["corfus"].id]         = 101600,
   [UDN["armafus"].id]        = 101700,
   [UDN["corafus"].id]        = 101750,

   --ECO NRG STORAGE
   [UDN["armestor"].id]       = 101800,
   [UDN["corestor"].id]       = 101850,
   [UDN["armuwadves"].id]     = 101900,
   [UDN["coruwadves"].id]     = 101950,

   --NANOS
   [UDN["armnanotc"].id]      = 102000,
   [UDN["cornanotc"].id]      = 102050,

   --FACTORIES
   [UDN["armlab"].id]         = 102100,
   [UDN["corlab"].id]         = 102125,
   [UDN["armvp"].id]          = 102150,
   [UDN["corvp"].id]          = 102175,
   [UDN["armap"].id]          = 102200,
   [UDN["corap"].id]          = 102225,
   [UDN["armhp"].id]          = 102250,
   [UDN["corhp"].id]          = 102275,

   [UDN["armalab"].id]        = 102400,
   [UDN["coralab"].id]        = 102425,
   [UDN["armavp"].id]         = 102450,
   [UDN["coravp"].id]         = 102475,
   [UDN["armaap"].id]         = 102500,
   [UDN["coraap"].id]         = 102525,
   [UDN["armshltx"].id]       = 102550,
   [UDN["corgant"].id]        = 102575,
   [UDN["armapt3"].id]        = 102700, --scavengers
   [UDN["corapt3"].id]        = 102725, --scavengers

   --UTILITIES
   [UDN["armasp"].id]         = 102800, --AIR REPAIR PADS
   [UDN["corasp"].id]         = 102825,

   [UDN["armeyes"].id]        = 103000,
   [UDN["coreyes"].id]        = 103050,
   [UDN["armrad"].id]         = 103100,
   [UDN["corrad"].id]         = 103150,
   [UDN["armarad"].id]        = 103200,
   [UDN["corarad"].id]        = 103250,
   [UDN["armjamt"].id]        = 103300,
   [UDN["corjamt"].id]        = 103350,
   [UDN["armveil"].id]        = 103400,
   [UDN["corshroud"].id]      = 103450,
   [UDN["armjuno"].id]        = 103500,
   [UDN["corjuno"].id]        = 103550,

   [UDN["armsd"].id]          = 103600,
   [UDN["corsd"].id]          = 103625,
   [UDN["armtarg"].id]        = 103650,
   [UDN["cortarg"].id]        = 103675,
   [UDN["armgate"].id]        = 103700,
   [UDN["corgate"].id]        = 103725,
   [UDN["armdf"].id]          = 103750, --Fake Fusion

   --DEFENSES LAND
   [UDN["armdrag"].id]        = 104000,
   [UDN["cordrag"].id]        = 104050,
   [UDN["corscavdrag"].id]    = 104060, --scavengers
   [UDN["armfort"].id]        = 104060,
   [UDN["corfort"].id]        = 104070,
   [UDN["corscavfort"].id]    = 104080, --scavengers
   [UDN["armclaw"].id]        = 104100,
   [UDN["corscavdtl"].id]     = 104110, --scavengers
   [UDN["cormaw"].id]         = 104150,
   [UDN["corscavdtf"].id]     = 104110, --scavengers
   [UDN["corscavdtm"].id]     = 104120, --scavengers

   --MINES
   [UDN["armmine1"].id]       = 104124,
   [UDN["cormine1"].id]       = 104128,
   [UDN["armmine2"].id]       = 104132,
   [UDN["cormine2"].id]       = 104136,
   [UDN["cormine4"].id]       = 104140, --cormando
   [UDN["armmine3"].id]       = 104144,
   [UDN["cormine3"].id]       = 104148,

   [UDN["armllt"].id]         = 104200,
   [UDN["corllt"].id]         = 104250,
   [UDN["armbeamer"].id]      = 104300,
   [UDN["corhllt"].id]        = 104350,
   [UDN["corhllllt"].id]      = 104375, --scavengers
   [UDN["armhlt"].id]         = 104400,
   [UDN["corhlt"].id]         = 104450,
   [UDN["armguard"].id]       = 104500,
   [UDN["corpun"].id]         = 104550,

   [UDN["armpb"].id]          = 104600,
   [UDN["corvipe"].id]        = 104650,
   [UDN["armamb"].id]         = 104700,
   [UDN["cortoast"].id]       = 104750,
   [UDN["armanni"].id]        = 104800,
   [UDN["cordoom"].id]        = 104850,

   [UDN["armbrtha"].id]       = 104855,
   [UDN["corint"].id]         = 104860,
   [UDN["armminivulc"].id]    = 148650, --scavengers
   [UDN["corminibuzz"].id]    = 148700, --scavengers
   [UDN["armbotrail"].id]     = 148750, --scavengers
   [UDN["armvulc"].id]        = 148800,
   [UDN["corbuzz"].id]        = 148850,

   --DEFENSES AA
   [UDN["armrl"].id]          = 150000,
   [UDN["corrl"].id]          = 150500,
   [UDN["armferret"].id]      = 151000,
   [UDN["cormadsam"].id]      = 151500,
   [UDN["armcir"].id]         = 152000,
   [UDN["corerad"].id]        = 152500,

   [UDN["armflak"].id]        = 153000,
   [UDN["corflak"].id]        = 153500,
   [UDN["armmercury"].id]     = 154000,
   [UDN["corscreamer"].id]    = 154500,

   --DEFENSES MISSILE LAUNCHERS
   [UDN["armemp"].id]         = 165000,
   [UDN["cortron"].id]        = 165500,
   [UDN["armamd"].id]         = 166000,
   [UDN["corfmd"].id]         = 166500,
   [UDN["armsilo"].id]        = 180000,
   [UDN["corsilo"].id]        = 180500,

   --DEFENSES TO WATER
   [UDN["armdl"].id]          = 155000,
   [UDN["cordl"].id]          = 155500,

   --WATER ECO METAL
   [UDN["armuwmme"].id]       = 200000,
   [UDN["coruwmme"].id]       = 200100,

   --WATER ECO NRG CONVERTERS
   [UDN["armfmkr"].id]        = 200400,
   [UDN["corfmkr"].id]        = 200500,
   [UDN["armuwmmm"].id]       = 200600,
   [UDN["coruwmmm"].id]       = 200700,

   --WATER ECO METAL STORAGE
   [UDN["armuwms"].id]        = 201000,
   [UDN["coruwms"].id]        = 201500,

   --WATER ECO NRG GENS
   [UDN["armtide"].id]        = 203000,
   [UDN["cortide"].id]        = 203500,

   --WATER ECO NRG FUSIONS
   [UDN["armuwfus"].id]       = 205000,
   [UDN["coruwfus"].id]       = 205500,

   --WATER ECO NRG STORAGE
   [UDN["armuwes"].id]        = 207000,
   [UDN["coruwes"].id]        = 207500,

   --WATER CONSTRUCTION
   [UDN["armnanotcplat"].id]  = 210000,
   [UDN["cornanotcplat"].id]  = 210500,

   [UDN["armsy"].id]          = 211000,
   [UDN["corsy"].id]          = 211500,
   [UDN["armasy"].id]         = 211600,
   [UDN["corasy"].id]         = 211700,
   [UDN["armfhp"].id]         = 212000,
   [UDN["corfhp"].id]         = 212500,
   [UDN["armamsub"].id]       = 213000,
   [UDN["coramsub"].id]       = 213500,
   [UDN["armplat"].id]        = 214000,
   [UDN["corplat"].id]        = 214500,

   [UDN["armshltxuw"].id]     = 215000,
   [UDN["corgantuw"].id]      = 215500,

   --WATER MINES
   [UDN["armfmine3"].id]      = 216000,
   [UDN["corfmine3"].id]      = 216500,

   --WATER UTILITIES
   [UDN["armfrad"].id]        = 220000,
   [UDN["corfrad"].id]        = 220500,
   [UDN["armason"].id]        = 221000,
   [UDN["corason"].id]        = 221500,
   [UDN["armfatf"].id]        = 222000,
   [UDN["corfatf"].id]        = 222500,

   --WATER DEFENSES LAND
   [UDN["armfdrag"].id]       = 230000,
   [UDN["corfdrag"].id]       = 230500,
   [UDN["armfhlt"].id]        = 231000,
   [UDN["corfhlt"].id]        = 232500,
   [UDN["armkraken"].id]      = 233000,
   [UDN["corfdoom"].id]       = 233500,

   --WATER DEFENSES AA
   [UDN["armfrt"].id]         = 255000,
   [UDN["corfrt"].id]         = 255500,
   [UDN["armfflak"].id]       = 256000,
   [UDN["corenaa"].id]        = 256500,

   --WATER DEFENSES NAVAL
   [UDN["armptl"].id]         = 260000,
   [UDN["corptl"].id]         = 260500,
   [UDN["armtl"].id]          = 261000,
   [UDN["cortl"].id]          = 261500,
   [UDN["armatl"].id]         = 262000,
   [UDN["coratl"].id]         = 262500,
}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.isscavenger then
		local counterpartId = UnitDefNames[unitDef.customParams.fromunit].id
		if unitOrderTable[counterpartId] then
			unitOrderTable[unitDefID] = unitOrderTable[counterpartId]
		end
	end
end

return unitOrderTable