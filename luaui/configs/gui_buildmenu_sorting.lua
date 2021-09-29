local UDN = UnitDefNames

local unitOrderTable = {

-- UNITS

   --BOTS
   [UDN["armck"].id] = 00100,
   [UDN["corck"].id] = 00105,
   [UDN["armrectr"].id] = 00110,
   [UDN["cornecro"].id] = 00115,

   [UDN["armflea"].id] = 00120,
   [UDN["armpw"].id] = 00125,
   [UDN["corak"].id] = 00130,
   [UDN["armrock"].id] = 00135,
   [UDN["corstorm"].id] = 00140,
   [UDN["armham"].id] = 00145,
   [UDN["corthud"].id] = 00150,
   [UDN["armwar"].id] = 00155,
   [UDN["corkark"].id] = 00160, --new

   [UDN["armjeth"].id] = 00175,
   [UDN["corcrash"].id] = 00180,

   -- BOTS T2
   [UDN["armack"].id] = 00200,
   [UDN["corack"].id] = 00205,
   [UDN["armfark"].id] = 00210,
   [UDN["corfast"].id] = 00215,
   [UDN["armdecom"].id] = 00220,
   [UDN["cordecom"].id] = 00225,
   
   [UDN["cormando"].id] = 00227,

   [UDN["armspy"].id] = 00230,
   [UDN["corspy"].id] = 00235,
   [UDN["armmark"].id] = 00245,
   [UDN["corvoyr"].id] = 00250,
   [UDN["armaser"].id] = 00255,
   [UDN["corspec"].id] = 00260,

   [UDN["armspid"].id] = 00262,

   [UDN["armvader"].id] = 00265,
   [UDN["corroach"].id] = 00270,
   [UDN["corsktl"].id] = 00275,
   [UDN["armfast"].id] = 00280,
   [UDN["corpyro"].id] = 00285,
   [UDN["armfido"].id] = 00290,
   [UDN["cormort"].id] = 00295,

   [UDN["armzeus"].id] = 00300,
   [UDN["corhrk"].id] = 00305,
   [UDN["armmav"].id] = 00310,
   [UDN["corcan"].id] = 00315,
   [UDN["armsnipe"].id] = 00320,
   [UDN["corsumo"].id] = 00325,
   [UDN["armsptk"].id] = 00330,
   [UDN["cortermite"].id] = 00335,
   [UDN["armfboy"].id] = 00345,

   [UDN["armamph"].id] = 00355,
   [UDN["coramph"].id] = 00360,
   [UDN["armaak"].id] = 00365,
   [UDN["coraak"].id] = 00370,
   [UDN["armscab"].id] = 00375,

   

   -- BOTS T3
   [UDN["armmar"].id] = 00400,
   [UDN["corcat"].id] = 00405,
   [UDN["armraz"].id] = 00410,
   [UDN["corkarg"].id] = 00415,
   [UDN["armvang"].id] = 00420,
   [UDN["corshiva"].id] = 00425,
   [UDN["armthor"].id] = 00430,
   [UDN["corkorg"].id] = 00435,
   [UDN["armbanth"].id] = 00440,
   [UDN["corjugg"].id] = 00445,
   [UDN["armlun"].id] = 00440, --hover
   [UDN["corsok"].id] = 00445, --hover

-- BUILDINGS

   --ECO METAL MEX
   [UDN["armmex"].id] = 10000,
   [UDN["cormex"].id] = 10050,
   [UDN["armamex"].id] = 10100,
   [UDN["corexp"].id] = 10150,

   [UDN["armmoho"].id] = 10200,
   [UDN["cormoho"].id] = 10250,
   [UDN["cormexp"].id] = 10300,

   --ECO ENERGY CONVERTERS
   [UDN["armmakr"].id] = 10500,
   [UDN["cormakr"].id] = 10550,
   [UDN["armmmkr"].id] = 10600,
   [UDN["cormmkr"].id] = 10650,

   --ECO METAL STORAGE
   [UDN["armmstor"].id] = 10800,
   [UDN["cormstor"].id] = 10850,
   [UDN["armuwadvms"].id] = 10900,
   [UDN["coruwadvms"].id] = 10950,

   --ECO NRG GENS
   [UDN["armwin"].id] = 11000,
   [UDN["corwin"].id] = 11020, 
   [UDN["armwint2"].id] = 11040, --scavengers
   [UDN["corwint2"].id] = 11050, --scavengers
   [UDN["armsolar"].id] = 11070,
   [UDN["corsolar"].id] = 11080,
   [UDN["armadvsol"].id] = 11100,
   [UDN["coradvsol"].id] = 11150,

   --ECO NRG GEOS
   [UDN["armgeo"].id] = 11200,
   [UDN["corgeo"].id] = 11250,
   [UDN["armgmm"].id] = 11300,
   [UDN["corageo"].id] = 11350,
   [UDN["armageo"].id] = 11400,
   [UDN["corbhmth"].id] = 11450,

   --ECO NRG FUSIONS
   [UDN["armdf"].id] = 11500,
   [UDN["armfus"].id] = 11525,
   [UDN["armckfus"].id] = 11550,
   [UDN["corfus"].id] = 11600,
   [UDN["armafus"].id] = 11700,
   [UDN["corafus"].id] = 11750,

   --ECO NRG STORAGE
   [UDN["armestor"].id] = 11800,
   [UDN["corestor"].id] = 11850,
   [UDN["armuwadves"].id] = 11900,
   [UDN["coruwadves"].id] = 11950,

   --CONSTRUCTION
   [UDN["armnanotc"].id] = 12000,
   [UDN["cornanotc"].id] = 12050,

   [UDN["armasp"].id] = 12060,
   [UDN["corasp"].id] = 12070,

   [UDN["armlab"].id] = 12100,
   [UDN["corlab"].id] = 12125,
   [UDN["armvp"].id] = 12150,
   [UDN["corvp"].id] = 12175,
   [UDN["armap"].id] = 12200,
   [UDN["corap"].id] = 12225,
   [UDN["armhp"].id] = 12250,
   [UDN["corhp"].id] = 12275,

   [UDN["armalab"].id] = 12400,
   [UDN["coralab"].id] = 12425,
   [UDN["armavp"].id] = 12450,
   [UDN["coravp"].id] = 12475,
   [UDN["armaap"].id] = 12500,
   [UDN["coraap"].id] = 12525,
   [UDN["armshltx"].id] = 12550,
   [UDN["corgant"].id] = 12575,
   [UDN["armapt3"].id] = 12700, --scavengers
   [UDN["corapt3"].id] = 12725, --scavengers


   --UTILITIES
   [UDN["armeyes"].id] = 13000,
   [UDN["coreyes"].id] = 13050,
   [UDN["armrad"].id] = 13100,
   [UDN["corrad"].id] = 13150,
   [UDN["armarad"].id] = 13200,
   [UDN["corarad"].id] = 13250,
   [UDN["armjamt"].id] = 13300,
   [UDN["corjamt"].id] = 13350,
   [UDN["armveil"].id] = 13400,
   [UDN["corshroud"].id] = 13450,
   [UDN["armjuno"].id] = 13500,
   [UDN["corjuno"].id] = 13550,

   [UDN["armsd"].id] = 13600,
   [UDN["corsd"].id] = 13625,
   [UDN["armtarg"].id] = 13650,
   [UDN["cortarg"].id] = 13675,
   [UDN["armgate"].id] = 13700,
   [UDN["corgate"].id] = 13725,



   --DEFENSES LAND
   [UDN["armdrag"].id] = 14000,
   [UDN["cordrag"].id] = 14050,
   [UDN["corscavdrag"].id] = 14060, --scavengers
   [UDN["armfort"].id] = 14060,
   [UDN["corfort"].id] = 14070,
   [UDN["corscavfort"].id] = 14080,
   [UDN["armclaw"].id] = 14100,
   [UDN["corscavdtl"].id] = 14110, --scavengers
   [UDN["cormaw"].id] = 14150,
   [UDN["corscavdtf"].id] = 14110, --scavengers
   [UDN["corscavdtm"].id] = 14120, --scavengers

   --MINES
   [UDN["armmine1"].id] = 14124,
   [UDN["cormine1"].id] = 14128,
   [UDN["armmine2"].id] = 14132,
   [UDN["cormine2"].id] = 14136,
   [UDN["cormine4"].id] = 14140, --cormando
   [UDN["armmine3"].id] = 14144,
   [UDN["cormine3"].id] = 14148,

   [UDN["armllt"].id] = 14200,
   [UDN["corllt"].id] = 14250,
   [UDN["armbeamer"].id] = 14300,
   [UDN["corhllt"].id] = 14350,
   [UDN["corhllllt"].id] = 14375, --scavengers
   [UDN["armhlt"].id] = 14400,
   [UDN["corhlt"].id] = 14450,
   [UDN["armguard"].id] = 14500,
   [UDN["corpun"].id] = 14550,

   [UDN["armpb"].id] = 14600,
   [UDN["corvipe"].id] = 14650,
   [UDN["armamb"].id] = 14700,
   [UDN["cortoast"].id] = 14750,
   [UDN["armanni"].id] = 14800,
   [UDN["cordoom"].id] = 14850,

   [UDN["armbrtha"].id] = 14855,
   [UDN["corint"].id] = 14860,
   [UDN["armminivulc"].id] = 14865, --scavengers
   [UDN["corminibuzz"].id] = 14870, --scavengers
   [UDN["armpwcannon"].id] = 14875, --scavengers
   [UDN["armvulc"].id] = 14880,
   [UDN["corbuzz"].id] = 14885,

   --DEFENSES AA
   [UDN["armrl"].id] = 15000,
   [UDN["corrl"].id] = 15050,
   [UDN["armferret"].id] = 15100,
   [UDN["cormadsam"].id] = 15150,
   [UDN["armcir"].id] = 15200,
   [UDN["corerad"].id] = 15250,

   [UDN["armflak"].id] = 15300,
   [UDN["corflak"].id] = 15350,
   [UDN["armmercury"].id] = 15400,
   [UDN["corscreamer"].id] = 15450,

   --DEFENSES MISSILE LAUNCHERS
   [UDN["armemp"].id] = 16500,
   [UDN["cortron"].id] = 16550,
   [UDN["armamd"].id] = 16600,
   [UDN["corfmd"].id] = 16650,
   [UDN["armsilo"].id] = 18000,
   [UDN["corsilo"].id] = 18050,

   --DEFENSES TO WATER
   [UDN["armdl"].id] = 15500,
   [UDN["cordl"].id] = 15550,

   --WATER ECO NRG CONVERTERS
   [UDN["armfmkr"].id] = 20000,
   [UDN["corfmkr"].id] = 20050,
   [UDN["armuwmmm"].id] = 20060,
   [UDN["coruwmmm"].id] = 20070,

   --WATER ECO METAL STORAGE
   [UDN["armuwms"].id] = 20100,
   [UDN["coruwms"].id] = 20150,

   --WATER ECO METAL STORAGE
   [UDN["armuwms"].id] = 20200,
   [UDN["coruwms"].id] = 20250,

   --WATER ECO NRG GENS
   [UDN["armtide"].id] = 20300,
   [UDN["cortide"].id] = 20350,

   --WATER ECO NRG FUSIONS
   [UDN["armuwfus"].id] = 20500,
   [UDN["coruwfus"].id] = 20550,

   --WATER ECO NRG STORAGE
   [UDN["armuwes"].id] = 20700,
   [UDN["coruwes"].id] = 20750,

   --WATER CONSTRUCTION
   [UDN["armnanotcplat"].id] = 21000,
   [UDN["cornanotcplat"].id] = 21050,

   [UDN["armsy"].id] = 21100,
   [UDN["corsy"].id] = 21150,
   [UDN["armasy"].id] = 21160,
   [UDN["corasy"].id] = 21170,
   [UDN["armfhp"].id] = 21200,
   [UDN["corfhp"].id] = 21250,
   [UDN["armamsub"].id] = 21300,
   [UDN["coramsub"].id] = 21350,
   [UDN["armplat"].id] = 21400,
   [UDN["corplat"].id] = 21450,

   [UDN["armshltxuw"].id] = 21500,
   [UDN["corgantuw"].id] = 21550,

   --WATER MINES
   [UDN["armfmine3"].id] = 21600,
   [UDN["corfmine3"].id] = 21650,

   --WATER UTILITIES
   [UDN["armfrad"].id] = 22000,
   [UDN["corfrad"].id] = 22050,
   [UDN["armason"].id] = 22100,
   [UDN["corason"].id] = 22150,
   [UDN["armfatf"].id] = 22200,
   [UDN["corfatf"].id] = 22250,

   --WATER DEFENSES LAND
   [UDN["armfdrag"].id] = 23000,
   [UDN["corfdrag"].id] = 23050,
   [UDN["armfhlt"].id] = 23100,
   [UDN["corfhlt"].id] = 23250,
   [UDN["armkraken"].id] = 23300,
   [UDN["corfdoom"].id] = 23350,

   --WATER DEFENSES AA
   [UDN["armfrt"].id] = 25500,
   [UDN["corfrt"].id] = 25550,
   [UDN["armfflak"].id] = 25600,
   [UDN["corenaa"].id] = 25650,

   --WATER DEFENSES NAVAL
   [UDN["armptl"].id] = 26000,
   [UDN["corptl"].id] = 26050,
   [UDN["armtl"].id] = 26100,
   [UDN["cortl"].id] = 26150,
   [UDN["armatl"].id] = 26200,
   [UDN["coratl"].id] = 26250,
}

for unitDefID, unitDef in pairs(UnitDefs) do
   --Spring.Echo(UnitDefs[unitDefID].name)
   if unitOrderTable[unitDefID] then
      local orderValue = unitOrderTable[unitDefID]
      if UnitDefs[unitDefID].name then
         local unitName = UnitDefs[unitDefID].name
         local unitNameScav = unitName .. "_scav"
         if UDN[unitNameScav] then
            local unitDefIDScav = UDN[unitNameScav].id
            unitOrderTable[unitDefIDScav] = orderValue
         end
      end
   end
end

return unitOrderTable