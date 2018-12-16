local rnd = math.random
local ceil = math.ceil
local multiplier = rnd(1,100) / 100		-- use this if you want a bit of uniformity amongst multiple randoms


local critterConfig = {

["BarracudaBay"] = {
  { spawnCircle = {x=3050, z=3111, r=530}, unitNames = {["critter_gull"]=rnd(5,8)} },
  { spawnCircle = {x=3050, z=3111, r=800}, unitNames = {["critter_gull"]=rnd(4,7)} },
  { spawnBox = {x1=2000, z1=400, x2=2500, z2=800}, unitNames = {["critter_duck"]=rnd(0,3)} },
  { spawnBox = {x1=5200, z1=4200, x2=5600, z2=4700}, unitNames = {["critter_duck"]=rnd(1,3)} },
  { spawnCircle = {x=3222, z=5700, r=200}, unitNames = {["critter_duck"]=rnd(0,3)} },
  { spawnCircle = {x=540, z=1750, r=120}, unitNames = {["critter_duck"]=rnd(1,2)} },
  { spawnBox = {x1=50, z1=50, x2=6100, z2=6100}, unitNames = {["critter_goldfish"]=rnd(100,150)} },
  { spawnBox = {x1=150, z1=150, x2=6000, z2=6000}, unitNames = {["critter_gull"]=rnd(6,11)} },
},

["Calamity_V1"] = {
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_goldfish"]=rnd(170,240)} },
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_gull"]=rnd(25,45)} },
},

["Centre-command"] = {
  { spawnCircle = {x=1550, z=3000, r=500}, unitNames = {["critter_gull"]=rnd(1,3)} },
  { spawnCircle = {x=1550, z=3000, r=1450}, unitNames = {["critter_gull"]=rnd(1,3)} },
},

["CenterrockV12"] = {
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_goldfish"]=rnd(220,440)} },
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_gull"]=rnd(6,11)} },
  { spawnCircle = {x=1500, z=7150, r=1500}, unitNames = {["critter_gull"]=rnd(3,5)} },
  { spawnCircle = {x=7333, z=380, r=1500}, unitNames = {["critter_gull"]=rnd(2,3)} },
  { spawnCircle = {x=2950, z=5500, r=1600}, unitNames = {["critter_gull"]=rnd(2,3)} },
  { spawnCircle = {x=4333, z=3777, r=2400}, unitNames = {["critter_gull"]=rnd(4,6)} },
},

["Charlie in the Hills v2.1"] = {
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_goldfish"]=rnd(80,400)} },
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_gull"]=rnd(7,13)} },
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_duck"]=rnd(0,2)} },
  { spawnCircle = {x=4444, z=2500, r=500}, unitNames = {["critter_duck"]=rnd(0,2)} },
  { spawnCircle = {x=3700, z=2500, r=400}, unitNames = {["critter_duck"]=rnd(0,2)} },
  { spawnBox = {x1=3150, z1=5100, x2=5100, z2=6300}, unitNames = {["critter_duck"]=rnd(0,4)} },
  { spawnCircle = {x=6777, z=6888, r=260}, unitNames = {["critter_duck"]=rnd(0,2)} },
  { spawnCircle = {x=6766, z=1320, r=220}, unitNames = {["critter_duck"]=rnd(0,3)} },
},

--[[["Colorado_v1"] = {

},]]--

["Blindside_v2"] = {
  { spawnCircle = {x=4500, z=3800, r=3000}, unitNames = {["critter_penguin"]=rnd(2,5)} },
  { spawnCircle = {x=7200, z=3800, r=3000}, unitNames = {["critter_penguin"]=rnd(2,5)} },
  { spawnCircle = {x=10600, z=3800, r=3000}, unitNames = {["critter_penguin"]=rnd(2,5)} },
  { spawnCircle = {x=13300, z=3800, r=3000}, unitNames = {["critter_penguin"]=rnd(2,5)} },
  { spawnBox = {x1=1800, z1=650, x2=14700, z2=7400}, unitNames = {["critter_penguin"]=rnd(10,20)} },
  { spawnBox = {x1=50, z1=50, x2=16300, z2=8150}, unitNames = {["critter_goldfish"]=rnd(75,150)} },
l},
 
["Barbary Coves v2"] = {
  { spawnBox = {x1=50, z1=50, x2=9200, z2=8150}, unitNames = {["critter_goldfish"]=rnd(100,250)} },
  { spawnBox = {x1=50, z1=50, x2=9200, z2=8150}, unitNames = {["critter_gull"]=rnd(8,15)} },
  { spawnBox = {x1=50, z1=50, x2=9200, z2=8150}, unitNames = {["critter_duck"]=rnd(7,18)} },
  { spawnCircle = {x=1500, z=4100, r=130}, unitNames = {["critter_duck"]=rnd(0,2)} },
  { spawnCircle = {x=910, z=3400, r=200}, unitNames = {["critter_duck"]=rnd(0,3)} },
  { spawnCircle = {x=7200, z=4700, r=220}, unitNames = {["critter_duck"]=rnd(0,3)} },
  { spawnCircle = {x=5555, z=3333, r=220}, unitNames = {["critter_duck"]=rnd(0,3)} },
  { spawnCircle = {x=6050, z=200, r=200}, unitNames = {["critter_duck"]=rnd(0,3)} },
  { spawnCircle = {x=4100, z=7950, r=370}, unitNames = {["critter_duck"]=rnd(0,3)} },
  { spawnCircle = {x=8888, z=1700, r=1200}, unitNames = {["critter_duck"]=rnd(2,6)} },
  { spawnCircle = {x=8888, z=1700, r=550}, unitNames = {["critter_gull"]=rnd(0,3)} },
  { spawnCircle = {x=8888, z=1700, r=900}, unitNames = {["critter_gull"]=rnd(0,3)} },
l},


["DesertSiege_v2b"] = {
  { spawnBox = {x1=50, z1=50, x2=10200, z2=6100}, unitNames = {["critter_ant"]=rnd(6,10)} },
},

["DesertTriad"] = {
  { spawnBox = {x1=1800, z1=3400, x2=3900, z2=3900}, unitNames = {["critter_gull"]=1} },
  { spawnBox = {x1=1800, z1=20, x2=3900, z2=120}, unitNames = {["critter_gull"]=1} },
},

["Downs_of_Destruction_Fix"] = {
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_goldfish"]=rnd(70,110)} },
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_gull"]=rnd(7,11)} },
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_duck"]=rnd(4,6)} },
},

["Dust_Bowl_v1"] = {
  { spawnBox = {x1=50, z1=50, x2=12200, z2=8150}, unitNames = {["critter_ant"]=rnd(12,16)} },
  { spawnCircle = {x=6150, z=4760, r=350}, unitNames = {["critter_ant"]=rnd(10,14)} },
  { spawnCircle = {x=6150, z=4760, r=1300}, unitNames = {["critter_ant"]=rnd(7,10)} },
},

["Dworld_V1"] = {
  { spawnCircle = {x=12500, z=6100, r=400}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=5250, z=8950, r=330}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=3500, z=7700, r=270}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=2350, z=2220, r=300}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=9400, z=2250, r=200}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=10000, z=2375, r=200}, unitNames = {["critter_goldfish"]=rnd(0,2)} },
  { spawnCircle = {x=2550, z=900, r=150}, unitNames = {["critter_goldfish"]=rnd(0,2)} },
  { spawnCircle = {x=8850, z=11111, r=220}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnBox = {x1=50, z1=50, x2=14300, z2=14300}, unitNames = {["critter_goldfish"]=rnd(110,220)} },
  { spawnBox = {x1=50, z1=50, x2=14300, z2=14300}, unitNames = {["critter_gull"]=rnd(16,25)} },
  { spawnCircle = {x=10650, z=6450, r=550}, unitNames = {["critter_penguin"]=rnd(-5,3)} },
  { spawnCircle = {x=7500, z=7200, r=500}, unitNames = {["critter_penguin"]=rnd(-5,3)} },
  { spawnCircle = {x=4800, z=3850, r=500}, unitNames = {["critter_penguin"]=rnd(-5,2)} },
  { spawnCircle = {x=6500, z=3600, r=330}, unitNames = {["critter_penguin"]=rnd(-5,2)} },
  { spawnCircle = {x=5500, z=5500, r=330}, unitNames = {["critter_penguin"]=rnd(-5,2)} },
  { spawnCircle = {x=6570, z=3800, r=330}, unitNames = {["critter_penguin"]=rnd(-5,2)} },
  { spawnCircle = {x=7000, z=4200, r=330}, unitNames = {["critter_penguin"]=rnd(-5,2)} },
  { spawnCircle = {x=7970, z=9222, r=330}, unitNames = {["critter_penguin"]=rnd(-5,2)} },
  { spawnCircle = {x=3560, z=11500, r=300}, unitNames = {["critter_penguin"]=rnd(-5,2)} },
},
["Dworld Acidic"] = {
  { spawnBox = {x1=50, z1=50, x2=14300, z2=14300}, unitNames = {["critter_gull"]=rnd(16,25)} },
  { spawnCircle = {x=10650, z=6450, r=550}, unitNames = {["critter_penguin"]=rnd(-3,3)} },
  { spawnCircle = {x=7500, z=7200, r=500}, unitNames = {["critter_penguin"]=rnd(-3,3)} },
  { spawnCircle = {x=4800, z=3850, r=500}, unitNames = {["critter_penguin"]=rnd(-3,2)} },
  { spawnCircle = {x=6500, z=3600, r=330}, unitNames = {["critter_penguin"]=rnd(-3,2)} },
  { spawnCircle = {x=5500, z=5500, r=330}, unitNames = {["critter_penguin"]=rnd(-3,2)} },
  { spawnCircle = {x=6570, z=3800, r=330}, unitNames = {["critter_penguin"]=rnd(-3,2)} },
  { spawnCircle = {x=7000, z=4200, r=330}, unitNames = {["critter_penguin"]=rnd(-3,2)} },
  { spawnCircle = {x=7970, z=9222, r=330}, unitNames = {["critter_penguin"]=rnd(-3,2)} },
  { spawnCircle = {x=3560, z=11500, r=300}, unitNames = {["critter_penguin"]=rnd(-4,2)} },
},
["DworldV3"] = {
  { spawnCircle = {x=11850, z=7150, r=330}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=2000, z=7300, r=400}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=2400, z=2250, r=280}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=12000, z=2100, r=200}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=8400, z=13200, r=300}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=7200, z=1850, r=180}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnBox = {x1=50, z1=50, x2=14300, z2=14300}, unitNames = {["critter_goldfish"]=rnd(110,220)} },
  { spawnBox = {x1=50, z1=50, x2=14300, z2=14300}, unitNames = {["critter_gull"]=rnd(16,25)} },
  { spawnCircle = {x=10650, z=6450, r=550}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=4800, z=3850, r=500}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=6500, z=3600, r=330}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=5500, z=5500, r=500}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=6570, z=3800, r=330}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=7000, z=4200, r=330}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=4900, z=10400, r=400}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=7700, z=10400, r=400}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=7200, z=10050, r=360}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=4600, z=10600, r=400}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=8700, z=8800, r=400}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=5600, z=8800, r=400}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=8750, z=5600, r=500}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=9400, z=3900, r=450}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=9777, z=3666, r=450}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=7777, z=3750, r=450}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=9400, z=10400, r=450}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
},
["DworldDuo"] = {
  { spawnCircle = {x=11850, z=7150, r=330}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=2000, z=7300, r=400}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=2400, z=2250, r=280}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=12000, z=2100, r=200}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=8400, z=13200, r=300}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=7200, z=1850, r=180}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnBox = {x1=50, z1=50, x2=14300, z2=14300}, unitNames = {["critter_goldfish"]=rnd(110,200)} },
  { spawnBox = {x1=50, z1=50, x2=14300, z2=14300}, unitNames = {["critter_gull"]=rnd(16,22)} },
  { spawnCircle = {x=10650, z=6450, r=550}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=4800, z=3850, r=500}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=6500, z=3600, r=330}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=5500, z=5500, r=500}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=6570, z=3800, r=330}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=7000, z=4200, r=330}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=4900, z=10400, r=400}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=7700, z=10400, r=400}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=7200, z=10050, r=360}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=4600, z=10600, r=400}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=8700, z=8800, r=400}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=5600, z=8800, r=400}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=8750, z=5600, r=500}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=9400, z=3900, r=450}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=9777, z=3666, r=450}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=7777, z=3750, r=450}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
  { spawnCircle = {x=9400, z=10400, r=450}, unitNames = {["critter_penguin"]=rnd(-1,3)} },
},

["duck"] = {
  { spawnCircle = {x=800, z=700, r=200}, unitNames = {["critter_duck"]=rnd(2,4)} },
  { spawnBox = {x1=50, z1=50, x2=2000, z2=2000}, unitNames = {["critter_duck"]=rnd(2,22)} },
},
["duckfusionsfix"] = {
  { spawnCircle = {x=800, z=700, r=200}, unitNames = {["critter_duck"]=rnd(1,3)} },
  { spawnBox = {x1=50, z1=50, x2=2000, z2=2000}, unitNames = {["critter_duck"]=rnd(-2,6)} },
},

["Emain Macha"] = {
  { spawnCircle = {x=40, z=4700, r=800}, unitNames = {["critter_duck"]=rnd(1,2)} },
  { spawnCircle = {x=40, z=4700, r=1100}, unitNames = {["critter_gull"]=rnd(2,3)} },
  { spawnCircle = {x=40, z=4700, r=1100}, unitNames = {["critter_goldfish"]=rnd(6,10)} },
  { spawnCircle = {x=8100, z=4700, r=700}, unitNames = {["critter_duck"]=rnd(1,2)} },
  { spawnCircle = {x=8100, z=4700, r=1100}, unitNames = {["critter_gull"]=rnd(2,3)} },
  { spawnCircle = {x=8100, z=4700, r=1100}, unitNames = {["critter_goldfish"]=rnd(6,10)} },
},

["Epic-EE-CrossingGlade-v04"] = {
  { spawnCircle = {x=2000, z=2300, r=1000}, unitNames = {["critter_gull"]=rnd(1,3)} },
  { spawnCircle = {x=1750, z=2560, r=250}, unitNames = {["critter_duck"]=rnd(1,3)} },
  { spawnCircle = {x=2600, z=2080, r=250}, unitNames = {["critter_duck"]=rnd(2,6)} },
},

["FrozenFortress_v2"] = {
  { spawnCircle = {x=450, z=1200, r=290}, unitNames = {["critter_penguin"]=rnd(1,2)} },
  { spawnCircle = {x=6600, z=1100, r=160}, unitNames = {["critter_penguin"]=rnd(1,2)} },
  { spawnCircle = {x=9950, z=5850, r=190}, unitNames = {["critter_penguin"]=rnd(1,2)} },
  { spawnBox = {x1=50, z1=50, x2=10100, z2=8150}, unitNames = {["critter_penguin"]=rnd(12,20)} },
  { spawnBox = {x1=50, z1=50, x2=10100, z2=8150}, unitNames = {["critter_goldfish"]=rnd(100,150)} },
},

["FolsomDamDeluxeV4"] = {
  { spawnBox = {x1=50, z1=50, x2=10200, z2=7150}, unitNames = {["critter_gull"]=rnd(4,7)} },
  { spawnBox = {x1=2200, z1=50, x2=8800, z2=7150}, unitNames = {["critter_gull"]=rnd(6,10)} },
  { spawnBox = {x1=50, z1=50, x2=10200, z2=7150}, unitNames = {["critter_goldfish"]=rnd(70,140)} },
  { spawnCircle = {x=6350, z=6900, r=260}, unitNames = {["critter_duck"]=rnd(0,3)} },
  { spawnCircle = {x=4100, z=4500, r=230}, unitNames = {["critter_duck"]=rnd(0,2)} },
},

["Frozen_Gauntlet_TNM03-V2"] = {
  { spawnCircle = {x=3250, z=2900, r=200}, unitNames = {["critter_penguin"]=rnd(4,10)} },
  { spawnCircle = {x=360, z=1800, r=250}, unitNames = {["critter_penguin"]=rnd(4,10)} },
},

["Hotlips_Redux_V2"] = {
  { spawnBox = {x1=50, z1=50, x2=11200, z2=9150}, unitNames = {["critter_ant"]=rnd(20,30)} },
},

["Iceland_v1"] = {
  { spawnBox = {x1=750, z1=750, x2=7450, z2=7450}, unitNames = {["critter_penguin"]=rnd(30,40)} },
  { spawnBox = {x1=2900, z1=7100, x2=4100, z2=7900}, unitNames = {["critter_penguin"]=rnd(6,9)} },
  { spawnBox = {x1=4200, z1=250, x2=5200, z2=777}, unitNames = {["critter_penguin"]=rnd(4,6)} },
  { spawnCircle = {x=4550, z=3600, r=290}, unitNames = {["critter_penguin"]=rnd(5,8)} },
  { spawnCircle = {x=4150, z=3300, r=250}, unitNames = {["critter_penguin"]=rnd(4,6)} },
  { spawnCircle = {x=3650, z=4470, r=270}, unitNames = {["critter_penguin"]=rnd(4,6)} },
  { spawnCircle = {x=3970, z=4777, r=230}, unitNames = {["critter_penguin"]=rnd(4,6)} },
  { spawnCircle = {x=6450, z=4500, r=300}, unitNames = {["critter_penguin"]=rnd(4,7)} },
  { spawnCircle = {x=1750, z=3400, r=300}, unitNames = {["critter_penguin"]=rnd(4,7)} },
  { spawnCircle = {x=3250, z=2300, r=300}, unitNames = {["critter_penguin"]=rnd(4,7)} },
  { spawnCircle = {x=4850, z=5777, r=300}, unitNames = {["critter_penguin"]=rnd(4,7)} },
  { spawnCircle = {x=2600, z=5550, r=450}, unitNames = {["critter_penguin"]=rnd(4,7)} },
  { spawnCircle = {x=2840, z=6000, r=450}, unitNames = {["critter_penguin"]=rnd(3,5)} },
  { spawnCircle = {x=5450, z=2450, r=400}, unitNames = {["critter_penguin"]=rnd(4,6)} },
  { spawnCircle = {x=5344, z=2111, r=380}, unitNames = {["critter_penguin"]=rnd(3,5)} },
  { spawnCircle = {x=5232, z=1640, r=400}, unitNames = {["critter_penguin"]=rnd(2,3)} },
  { spawnCircle = {x=4550, z=3600, r=250}, unitNames = {["critter_goldfish"]=rnd(1,2)} },
  { spawnCircle = {x=4150, z=3300, r=250}, unitNames = {["critter_goldfish"]=rnd(1,2)} },
  { spawnCircle = {x=3800, z=4700, r=250}, unitNames = {["critter_goldfish"]=rnd(1,2)} },
  { spawnCircle = {x=6450, z=4500, r=250}, unitNames = {["critter_goldfish"]=rnd(1,2)} },
  { spawnCircle = {x=1750, z=3400, r=250}, unitNames = {["critter_goldfish"]=rnd(1,2)} },
  { spawnCircle = {x=3250, z=2300, r=250}, unitNames = {["critter_goldfish"]=rnd(1,2)} },
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_goldfish"]=rnd(140,180)} },
},

["IcySea-v2"] = {
  { spawnBox = {x1=50, z1=50, x2=10200, z2=10200}, unitNames = {["critter_penguin"]=rnd(20,40)} },
  { spawnBox = {x1=50, z1=50, x2=10200, z2=10200}, unitNames = {["critter_goldfish"]=rnd(200,300)} },
},

["LLTAComplexV2"] = {
  { spawnBox = {x1=4222, z1=30,   x2=5050, z2=1550}, unitNames = {["critter_ant"]=rnd(2,3)} },
  { spawnBox = {x1=2500, z1=1550, x2=6666, z2=2050}, unitNames = {["critter_ant"]=rnd(3,4)} },
  { spawnBox = {x1=1500, z1=2050, x2=7666, z2=3500}, unitNames = {["critter_ant"]=rnd(5,8)} },
  { spawnBox = {x1=2666, z1=3500, x2=6560, z2=5100}, unitNames = {["critter_ant"]=rnd(3,5)} },
},


["Lost_v2"] = {
  { spawnBox = {x1=50, z1=50, x2=10200, z2=8150}, unitNames = {["critter_ant"]=rnd(6,12)} },
},

["IslandParadiseV2"] = {
  { spawnBox = {x1=3950, z1=4440, x2=4150, z2=4950}, unitNames = {["critter_duck"]=rnd(2,4)} },
  { spawnBox = {x1=3100, z1=800, x2=5000, z2=1500}, unitNames = {["critter_gull"]=rnd(0,3)} },
  { spawnBox = {x1=3100, z1=6500, x2=5000, z2=8000}, unitNames = {["critter_gull"]=rnd(0,3)} },
},

["Nuclear_Winter_v1"] = {
  { spawnBox = {x1=50, z1=50, x2=10100, z2=6100}, unitNames = {["critter_penguin"]=rnd(9,13)} },
},

["Nuclear Winter v3"] = {
  { spawnBox = {x1=50, z1=50, x2=10100, z2=6100}, unitNames = {["critter_penguin"]=rnd(9,13)} },
},

["Melt_V2"] = {
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_penguin"]=rnd(8,14)} },
},


["Malibu Beach v1"] = {
  { spawnBox = {x1=50, z1=50, x2=10200, z2=5100}, unitNames = {["critter_goldfish"]=rnd(30,45)} },
},

["Mearth_v4"] = {
  { spawnBox = {x1=6000, z1=300, x2=10200, z2=2000}, unitNames = {["critter_penguin"]=rnd(3,6)} },
  { spawnBox = {x1=8400, z1=2000, x2=10200, z2=4200}, unitNames = {["critter_penguin"]=rnd(3,6)} },
  { spawnBox = {x1=50, z1=50, x2=10200, z2=15300}, unitNames = {["critter_goldfish"]=rnd(220,340)} },
  { spawnBox = {x1=50, z1=50, x2=6700, z2=15300}, unitNames = {["critter_gull"]=rnd(12,20)} },
  { spawnBox = {x1=6700, z1=4400, x2=10200, z2=9400}, unitNames = {["critter_gull"]=rnd(2,4)} },
  { spawnBox = {x1=7980, z1=9980, x2=8490, z2=10220}, unitNames = {["critter_ant"]=rnd(-15,3)*5} },
  { spawnBox = {x1=7980, z1=9980, x2=8490, z2=10220}, unitNames = {["critter_ant"]=rnd(3,6)} },
  { spawnCircle = {x=8700, z=11700, r=2000}, unitNames = {["critter_ant"]=rnd(4,12)} },
  { spawnCircle = {x=300, z=8450, r=3900}, unitNames = {["critter_gull"]=rnd(2,4)} },
  { spawnCircle = {x=800, z=13700, r=3400}, unitNames = {["critter_gull"]=rnd(1,2)} },
  { spawnCircle = {x=9900, z=6000, r=800}, unitNames = {["critter_gull"]=rnd(1,2)} },
  { spawnCircle = {x=4700, z=8600, r=200}, unitNames = {["critter_duck"]=rnd(0,3)} },
  { spawnCircle = {x=7333, z=7111, r=160}, unitNames = {["critter_duck"]=rnd(0,2)} },
  { spawnCircle = {x=3200, z=4300, r=200}, unitNames = {["critter_duck"]=rnd(0,2)} },
  { spawnCircle = {x=2333, z=2777, r=150}, unitNames = {["critter_duck"]=rnd(0,2)} },
  { spawnCircle = {x=3733, z=64330, r=170}, unitNames = {["critter_duck"]=rnd(0,2)} },
  { spawnCircle = {x=3877, z=12122, r=150}, unitNames = {["critter_duck"]=rnd(0,2)} },
  { spawnCircle = {x=6940, z=5633, r=150}, unitNames = {["critter_duck"]=rnd(1,2)} },
  { spawnCircle = {x=4800, z=14000, r=250}, unitNames = {["critter_duck"]=rnd(1,2)} },
  { spawnCircle = {x=4222, z=700, r=200}, unitNames = {["critter_duck"]=rnd(0,2)} },
  { spawnCircle = {x=2650, z=6888, r=140}, unitNames = {["critter_duck"]=rnd(0,2)} },
},

["Mescaline_V2"] = {
  { spawnCircle = {x=1933, z=6080, r=30}, unitNames = {["critter_goldfish"]=rnd(-5,1)}, nowatercheck=true },
  { spawnCircle = {x=1933, z=6080, r=500}, unitNames = {["critter_gull"]=rnd(-3,1)} },
  { spawnCircle = {x=7400, z=970, r=30}, unitNames = {["critter_goldfish"]=rnd(-5,1)}, nowatercheck=true },
  { spawnCircle = {x=7400, z=970, r=500}, unitNames = {["critter_gull"]=rnd(-3,1)} },
  { spawnCircle = {x=9450, z=4200, r=30}, unitNames = {["critter_goldfish"]=rnd(-5,1)}, nowatercheck=true },
  { spawnCircle = {x=9450, z=4200, r=500}, unitNames = {["critter_gull"]=rnd(-3,1)} },
  { spawnBox = {x1=50, z1=50, x2=10200, z2=6100}, unitNames = {["critter_gull"]=rnd(7,12)} },
},

["Mountain Pass V4"] = {
  { spawnBox = {x1=100, z1=100, x2=8150, z2=8150}, unitNames = {["critter_gull"]=rnd(7,12)} },
  { spawnBox = {x1=100, z1=100, x2=8150, z2=8150}, unitNames = {["critter_goldfish"]=rnd(40,70)} },
},

["neurope_a7"] = {
  { spawnBox = {x1=14400, z1=20, x2=16200, z2=1250}, unitNames = {["critter_penguin"]=rnd(5,10)} },
  { spawnCircle = {x=3950, z=580, r=600},  unitNames = {["critter_penguin"]=rnd(6,14)} },
  { spawnCircle = {x=3950, z=580, r=850}, unitNames = {["critter_gull"]=rnd(0,2)} },
  { spawnCircle = {x=1000, z=650, r=400}, unitNames = {["critter_penguin"]=rnd(0,4)} },
  { spawnCircle = {x=1350, z=2850, r=1500}, unitNames = {["critter_gull"]=rnd(0,3)} },
  { spawnCircle = {x=11650, z=1100, r=500}, unitNames = {["critter_penguin"]=rnd(0,3)} },
  { spawnBox = {x1=7400, z1=500, x2=9150, z2=1200}, unitNames = {["critter_penguin"]=rnd(0,4)} },
  { spawnBox = {x1=6150, z1=700, x2=8480, z2=1111}, unitNames = {["critter_penguin"]=rnd(0,4)} },
  { spawnBox = {x1=50, z1=50, x2=16200, z2=8150}, unitNames = {["critter_goldfish"]=rnd(100,200)} },
  { spawnBox = {x1=100, z1=100, x2=16200, z2=8150}, unitNames = {["critter_gull"]=rnd(15,20)} },
},

["Parched_mesa-v04"] = {
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_ant"]=rnd(7,14)} },
},

["Pearl Springs v2"] = {
  { spawnBox = {x1=50, z1=4000, x2=12250, z2=7100}, unitNames = {["critter_goldfish"]=rnd(50,100)} },
},


["Real Europe V4"] = {
  { spawnBox = {x1=50, z1=4000, x2=12250, z2=12250}, unitNames = {["critter_goldfish"]=rnd(220,300)} },
  { spawnCircle = {x=2050, z=2700, r=2500}, unitNames = {["critter_gull"]=rnd(4,7)} },
  { spawnCircle = {x=3000, z=6700, r=3300}, unitNames = {["critter_gull"]=rnd(8,11)} },
  { spawnCircle = {x=7100, z=6300, r=4200}, unitNames = {["critter_gull"]=rnd(11,18)} },
  { spawnCircle = {x=5200, z=3000, r=2500}, unitNames = {["critter_gull"]=rnd(5,8)} },
  { spawnCircle = {x=7350, z=8250, r=2000}, unitNames = {["critter_gull"]=rnd(5,8)} },
  { spawnCircle = {x=8500, z=3650, r=1550}, unitNames = {["critter_gull"]=rnd(2,4)} },
  { spawnCircle = {x=11000, z=1600, r=2300}, unitNames = {["critter_penguin"]=rnd(8,12)} },
  { spawnCircle = {x=11500, z=3650, r=1500}, unitNames = {["critter_penguin"]=rnd(6,10)} },
  { spawnCircle = {x=6550, z=100, r=1600}, unitNames = {["critter_penguin"]=rnd(6,10)} },
  { spawnCircle = {x=5080, z=200, r=850}, unitNames = {["critter_penguin"]=rnd(2,4)} },
  { spawnCircle = {x=12222, z=500, r=1100}, unitNames = {["critter_penguin"]=rnd(2,4)} },
  { spawnCircle = {x=7800, z=1400, r=200}, unitNames = {["critter_penguin"]=rnd(1,2)} },
  { spawnCircle = {x=9666, z=1444, r=1050}, unitNames = {["critter_penguin"]=rnd(2,4)} },
  { spawnCircle = {x=5333, z=8666, r=600}, unitNames = {["critter_duck"]=rnd(4,6)} },
  { spawnCircle = {x=6633, z=9595, r=450}, unitNames = {["critter_duck"]=rnd(2,3)} },
  { spawnBox = {x1=9980, z1=8333, x2=12250, z2=9933}, unitNames = {["critter_ant"]=rnd(4,6)} },
  { spawnBox = {x1=5666, z1=11666, x2=12250, z2=12250}, unitNames = {["critter_ant"]=rnd(6,10)} },
  { spawnBox = {x1=1333, z1=10300, x2=5666, z2=12250}, unitNames = {["critter_ant"]=rnd(10,16)} },
},

["Sparewood-v01"] = {
  { spawnBox = {x1=20, z1=2500, x2=700, z2=3350}, unitNames = {["critter_duck"]=rnd(3,5)} },
  { spawnBox = {x1=20, z1=880, x2=300, z2=1500}, unitNames = {["critter_duck"]=rnd(4,7)} },
  { spawnBox = {x1=100, z1=100, x2=4000, z2=4000}, unitNames = {["critter_gull"]=rnd(2,4)} },
},

["Supreme Battlefield"] = {
  { spawnCircle = {x=11500, z=12500, r=2700}, unitNames = {["critter_goldfish"]=rnd(3,10)} },
  { spawnCircle = {x=15000, z=10500, r=300}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=4700, z=3900, r=2700}, unitNames = {["critter_goldfish"]=rnd(3,10)} },
  { spawnCircle = {x=1700, z=5700, r=300}, unitNames = {["critter_goldfish"]=rnd(0,2)} },
  { spawnCircle = {x=13950, z=2900, r=900}, unitNames = {["critter_duck"]=rnd(0,3)} },
  { spawnCircle = {x=2450, z=13450, r=900}, unitNames = {["critter_duck"]=rnd(0,3)} },
  { spawnBox = {x1=100, z1=100, x2=16200, z2=16200}, unitNames = {["critter_gull"]=rnd(10,20)} },
  { spawnBox = {x1=100, z1=100, x2=16200, z2=16200}, unitNames = {["critter_goldfish"]=rnd(66,150)} },
},

["Small Supreme Battlefield V2"] = {
  { spawnCircle = {x=5800, z=6250, r=1300}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=7500, z=5200, r=200}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=2350, z=1950, r=1300}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=850, z=2850, r=200}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=7000, z=1450, r=450}, unitNames = {["critter_duck"]=rnd(0,3)} },
  { spawnCircle = {x=1220, z=6720, r=450}, unitNames = {["critter_duck"]=rnd(0,3)} },
  { spawnBox = {x1=100, z1=100, x2=8150, z2=8150}, unitNames = {["critter_gull"]=rnd(7,12)} },
  { spawnBox = {x1=100, z1=100, x2=8150, z2=8150}, unitNames = {["critter_goldfish"]=rnd(50,100)} },
},

["Tabula-v2"] = {
  { spawnBox = {x1=6100, z1=1700, x2=6300, z2=2000}, unitNames = {["critter_duck"]=rnd(1,3)} },
  { spawnBox = {x1=1500, z1=6000, x2=1800, z2=6600}, unitNames = {["critter_duck"]=rnd(1,3)} },
  { spawnBox = {x1=50, z1=50, x2=8150, z2=7150}, unitNames = {["critter_gull"]=rnd(5,8)} },
  { spawnBox = {x1=1000, z1=4500, x2=3150, z2=8150}, unitNames = {["critter_gull"]=rnd(3,4)} },
  { spawnBox = {x1=5000, z1=50, x2=7050, z2=4650}, unitNames = {["critter_gull"]=rnd(3,4)} },
  { spawnBox = {x1=1700, z1=5750, x2=2600, z2=8150}, unitNames = {["critter_goldfish"]=rnd(4,6)} },
  { spawnBox = {x1=5500, z1=50, x2=6500, z2=1450}, unitNames = {["critter_goldfish"]=rnd(4,6)} },
},

["Tabula-v4"] = {
  { spawnCircle = {x=5440, z=4700, r=150}, unitNames = {["critter_ant"]=rnd(-3,1)} },
  { spawnCircle = {x=5900, z=7000, r=150}, unitNames = {["critter_ant"]=rnd(-3,1)} },
  { spawnCircle = {x=300, z=6950, r=220}, unitNames = {["critter_ant"]=rnd(-5,5)} },
  { spawnBox = {x1=2280, z1=12, x2=2410, z2=250}, unitNames = {["critter_ant"]=rnd(-3,1)} },
  { spawnBox = {x1=6100, z1=1700, x2=6300, z2=2000}, unitNames = {["critter_duck"]=rnd(1,3)} },
  { spawnBox = {x1=1500, z1=6000, x2=1800, z2=6600}, unitNames = {["critter_duck"]=rnd(1,3)} },
  { spawnBox = {x1=50, z1=50, x2=8150, z2=7150}, unitNames = {["critter_gull"]=rnd(5,8)} },
  { spawnBox = {x1=1000, z1=4500, x2=3150, z2=8150}, unitNames = {["critter_gull"]=rnd(3,4)} },
  { spawnBox = {x1=5000, z1=50, x2=7050, z2=4650}, unitNames = {["critter_gull"]=rnd(3,4)} },
  { spawnBox = {x1=1700, z1=5750, x2=2600, z2=8150}, unitNames = {["critter_goldfish"]=rnd(4,6)} },
  { spawnBox = {x1=5500, z1=50, x2=6500, z2=1450}, unitNames = {["critter_goldfish"]=rnd(4,6)} },
},

["Talus"] = {
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_gull"]=rnd(7,12)} },
  { spawnCircle = {x=6555, z=4155, r=650}, unitNames = {["critter_gull"]=rnd(2,4)} },
  { spawnCircle = {x=1600, z=4044, r=650}, unitNames = {["critter_gull"]=rnd(2,4)} },
  { spawnCircle = {x=1310, z=2065, r=550}, unitNames = {["critter_gull"]=rnd(0,1)} },
  { spawnCircle = {x=1310, z=2065, r=30}, unitNames = {["critter_goldfish"]=rnd(-2,1)}, nowatercheck=true },
},

["Talus-wet"] = {
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_goldfish"]=rnd(40,60)} },
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_gull"]=rnd(7,11)} },
  { spawnCircle = {x=6555, z=4155, r=650}, unitNames = {["critter_gull"]=rnd(2,4)} },
  { spawnCircle = {x=1600, z=4044, r=650}, unitNames = {["critter_gull"]=rnd(2,4)} },
},

["Tangerine"] = {
  { spawnCircle = {x=1400, z=7500, r=500}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=750, z=7000, r=500}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=400, z=3150, r=400}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=120, z=4000, r=500}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=7500, z=750, r=550}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=7750, z=4400, r=550}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=6000, z=4000, r=500}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=2000, z=5100, r=700}, unitNames = {["critter_gull"]=rnd(0,3)} },
  { spawnCircle = {x=5200, z=1300, r=800}, unitNames = {["critter_gull"]=rnd(0,3)} },
  { spawnCircle = {x=5500, z=4500, r=1100}, unitNames = {["critter_gull"]=rnd(0,3)} },
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_goldfish"]=rnd(40,80)} },
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_gull"]=rnd(14,20)} },
},

["Tempest"] = {
  { spawnCircle = {x=6500, z=4450, r=500}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=6700, z=6000, r=350}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=4300, z=7777, r=280}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=3800, z=2550, r=280}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=3850, z=5600, r=800}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=5300, z=5100, r=1100}, unitNames = {["critter_goldfish"]=rnd(0,3)} },
  { spawnCircle = {x=5000, z=2500, r=1700}, unitNames = {["critter_gull"]=rnd(0,3)} },
  { spawnCircle = {x=5000, z=7500, r=1700}, unitNames = {["critter_gull"]=rnd(0,3)} },
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_goldfish"]=rnd(33,66)} },
},

["Ternion"] = {
  { spawnCircle = {x=1100, z=1400, r=600}, unitNames = {["critter_duck"]=rnd(1,3)} },
  { spawnCircle = {x=3000, z=5200, r=600}, unitNames = {["critter_duck"]=rnd(1,3)} },
  { spawnCircle = {x=5000, z=1500, r=600}, unitNames = {["critter_duck"]=rnd(1,3)} },
  { spawnCircle = {x=3333, z=1720, r=180}, unitNames = {["critter_goldfish"]=rnd(1,3)} },
  { spawnCircle = {x=4260, z=3800, r=180}, unitNames = {["critter_goldfish"]=rnd(1,3)} },
  { spawnCircle = {x=1920, z=3330, r=180}, unitNames = {["critter_goldfish"]=rnd(1,3)} },
  { spawnBox = {x1=50, z1=50, x2=6000, z2=6000}, unitNames = {["critter_goldfish"]=rnd(100,180)} },
  { spawnBox = {x1=50, z1=50, x2=6000, z2=6000}, unitNames = {["critter_gull"]=rnd(14,20)} },
  { spawnBox = {x1=50, z1=50, x2=6000, z2=6000}, unitNames = {["critter_duck"]=rnd(10,15)} },
},

["TheColdPlace"] = {
  { spawnBox = {x1=2700, z1=1800, x2=4500, z2=3200}, unitNames = {["critter_goldfish"]=rnd(6,12)} },
  { spawnBox = {x1=1500, z1=3700, x2=5400, z2=4000}, unitNames = {["critter_penguin"]=rnd(6,10)} },
},

["The Cold Place Remake"] = {
  { spawnBox = {x1=2700, z1=1800, x2=4500, z2=3200}, unitNames = {["critter_goldfish"]=rnd(6,12)} },
  { spawnBox = {x1=1500, z1=3700, x2=5400, z2=4000}, unitNames = {["critter_penguin"]=rnd(6,10)} },
  { spawnCircle = {x=1500, z=2300, r=200}, unitNames = {["critter_penguin"]=rnd(3,5)} },
  { spawnCircle = {x=5400, z=2000, r=200}, unitNames = {["critter_penguin"]=rnd(3,5)} },
},

["The Cold Place Remake V2"] = {
  { spawnBox = {x1=2700, z1=1800, x2=4500, z2=3200}, unitNames = {["critter_goldfish"]=rnd(6,12)} },
  { spawnBox = {x1=1500, z1=3700, x2=5400, z2=4000}, unitNames = {["critter_penguin"]=rnd(6,10)} },
  { spawnCircle = {x=1500, z=2300, r=200}, unitNames = {["critter_penguin"]=rnd(3,5)} },
  { spawnCircle = {x=5400, z=2000, r=200}, unitNames = {["critter_penguin"]=rnd(3,5)} },
},

["The Cold Place Remake V3c"] = {
  { spawnBox = {x1=2700, z1=1800, x2=4500, z2=3200}, unitNames = {["critter_goldfish"]=rnd(6,12)} },
  { spawnBox = {x1=1500, z1=3700, x2=5400, z2=4000}, unitNames = {["critter_penguin"]=rnd(6,10)} },
  { spawnCircle = {x=1500, z=2300, r=200}, unitNames = {["critter_penguin"]=rnd(3,5)} },
  { spawnCircle = {x=5400, z=2000, r=200}, unitNames = {["critter_penguin"]=rnd(3,5)} },
},

["Titan-v2"] = {
  { spawnBox = {x1=50, z1=50, x2=9200, z2=6100}, unitNames = {["critter_ant"]=rnd(7,14)} },
},

["Trefoil_v2"] = {
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_goldfish"]=rnd(30,45)} },
},

["Tropical"] = {
  { spawnCircle = {x=1550, z=4650, r=400}, unitNames = {["critter_goldfish"]=rnd(0,2)} },
  { spawnCircle = {x=1000, z=5300, r=800}, unitNames = {["critter_goldfish"]=rnd(0,2)} },
  { spawnCircle = {x=1500, z=5900, r=700}, unitNames = {["critter_goldfish"]=rnd(0,2)} },
  { spawnCircle = {x=7700, z=5300, r=700}, unitNames = {["critter_goldfish"]=rnd(0,2)} },
  { spawnCircle = {x=7850, z=4350, r=800}, unitNames = {["critter_goldfish"]=rnd(0,2)} },
  { spawnCircle = {x=4600, z=5200, r=3500}, unitNames = {["critter_gull"]=rnd(3,5)} },
  { spawnCircle = {x=4600, z=5200, r=500}, unitNames = {["critter_duck"]=rnd(0,2)} },
  { spawnBox = {x1=50, z1=50, x2=9150, z2=10200}, unitNames = {["critter_goldfish"]=rnd(40,80)} },
  { spawnBox = {x1=50, z1=50, x2=9150, z2=10200}, unitNames = {["critter_gull"]=rnd(10,18)} },
},

["Tropical-v2"] = {
  { spawnCircle = {x=1550, z=4650, r=400}, unitNames = {["critter_goldfish"]=rnd(0,2)} },
  { spawnCircle = {x=1000, z=5300, r=800}, unitNames = {["critter_goldfish"]=rnd(0,2)} },
  { spawnCircle = {x=1500, z=5900, r=700}, unitNames = {["critter_goldfish"]=rnd(0,2)} },
  { spawnCircle = {x=7700, z=5300, r=700}, unitNames = {["critter_goldfish"]=rnd(0,2)} },
  { spawnCircle = {x=7850, z=4350, r=800}, unitNames = {["critter_goldfish"]=rnd(0,2)} },
  { spawnCircle = {x=4600, z=5200, r=3500}, unitNames = {["critter_gull"]=rnd(3,5)} },
  { spawnCircle = {x=4600, z=5200, r=500}, unitNames = {["critter_duck"]=rnd(0,2)} },
  { spawnBox = {x1=50, z1=50, x2=9150, z2=10200}, unitNames = {["critter_goldfish"]=rnd(40,80)} },
  { spawnBox = {x1=50, z1=50, x2=9150, z2=10200}, unitNames = {["critter_gull"]=rnd(12,20)} },
},

["Throne v1"] = {
  { spawnBox = {x1=50, z1=50, x2=12200, z2=12200}, unitNames = {["critter_goldfish"]=rnd(70,140)} },
},

["Tumult"] = {
  { spawnBox = {x1=3450, z1=3490, x2=3660, z2=3720} , unitNames = {["critter_goldfish"]=rnd(5,11)} },
  { spawnBox = {x1=50, z1=50, x2=7150, z2=7150}, unitNames = {["critter_ant"]=rnd(5,10)} },
},

["Vernal 3way 0.6.1"] = {
  { spawnCircle = {x=rnd(1000,4000), z=rnd(1000,4000), r=300}, unitNames = {["critter_duck"]=6} },
  { spawnCircle = {x=rnd(1000,4000), z=rnd(1000,4000), r=300}, unitNames = {["critter_duck"]=6} },
  { spawnCircle = {x=rnd(1000,4000), z=rnd(1000,4000), r=300}, unitNames = {["critter_duck"]=6} },
  { spawnBox = {x1=100, z1=100, x2=5000, z2=5000}, unitNames = {["critter_duck"]=4} },
},

["World_FFA"] = {
  { spawnCircle = {x=7474, z=4343, r=210}, unitNames = {["critter_penguin"]=rnd(3,6)} },
  { spawnBox = {x1=1200, z1=13500, x2=16000, z2=16300}, unitNames = {["critter_penguin"]=rnd(30,40)} },
  { spawnBox = {x1=10400, z1=9085, x2=10550, z2=9500}, unitNames = {["critter_penguin"]=2} },
  { spawnBox = {x1=50, z1=50, x2=16300, z2=16300}, unitNames = {["critter_goldfish"]=rnd(190,350)} },
},
  
  
}

return critterConfig
