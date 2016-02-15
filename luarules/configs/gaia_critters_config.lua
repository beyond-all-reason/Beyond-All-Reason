local rnd = math.random
local critterConfig = {

["BarracudaBay"] = {
  { spawnBox = {x1=2000, z1=400, x2=2500, z2=800}, unitNames = {["critter_duck"]=5} },
  { spawnBox = {x1=5200, z1=4200, x2=5600, z2=4700}, unitNames = {["critter_duck"]=4} },
  { spawnCircle = {x=3250, z=4400, r=500}, unitNames = {["critter_goldfish"]=2} },
  { spawnCircle = {x=2800, z=1500, r=500}, unitNames = {["critter_goldfish"]=2} },
},

["Centre-command"] = {
  { spawnCircle = {x=1550, z=3000, r=500}, unitNames = {["critter_gull"]=3} },
  { spawnCircle = {x=1550, z=3000, r=1450}, unitNames = {["critter_gull"]=2} },
},

["Blindside_v2"] = {
  { spawnCircle = {x=4800, z=3800, r=3000}, unitNames = {["critter_penguin"]=2} },
  { spawnCircle = {x=7300, z=3800, r=3000}, unitNames = {["critter_penguin"]=2} },
  { spawnCircle = {x=10500, z=3800, r=3000}, unitNames = {["critter_penguin"]=2} },
  { spawnCircle = {x=13000, z=3800, r=3000}, unitNames = {["critter_penguin"]=2} },
l},
 
["DesertTriad"] = {
  { spawnBox = {x1=1800, z1=3400, x2=3900, z2=3900}, unitNames = {["critter_gull"]=1} },
  { spawnBox = {x1=1800, z1=20, x2=3900, z2=120}, unitNames = {["critter_gull"]=1} },
},

["Dworld_V1"] = {
  { spawnCircle = {x=12500, z=6100, r=400}, unitNames = {["critter_goldfish"]=5} },
  { spawnCircle = {x=5250, z=8950, r=330}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=3500, z=7700, r=270}, unitNames = {["critter_goldfish"]=1} },
  { spawnCircle = {x=2350, z=2220, r=300}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=9400, z=2250, r=200}, unitNames = {["critter_goldfish"]=2} },
  { spawnCircle = {x=10000, z=2375, r=200}, unitNames = {["critter_goldfish"]=1} },
  { spawnCircle = {x=2550, z=900, r=150}, unitNames = {["critter_goldfish"]=1} },
  { spawnCircle = {x=8850, z=11111, r=220}, unitNames = {["critter_goldfish"]=3} },
},
["DworldV3"] = {
  { spawnCircle = {x=11850, z=7150, r=330}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=2000, z=7300, r=400}, unitNames = {["critter_goldfish"]=4} },
  { spawnCircle = {x=2400, z=2250, r=280}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=12000, z=2100, r=200}, unitNames = {["critter_goldfish"]=2} },
  { spawnCircle = {x=8400, z=13200, r=300}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=7200, z=1850, r=180}, unitNames = {["critter_goldfish"]=2} },
},

["duck"] = {
  { spawnCircle = {x=800, z=700, r=200}, unitNames = {["critter_duck"]=2} },
  { spawnBox = {x1=50, z1=50, x2=2000, z2=2000}, unitNames = {["critter_duck"]=3} },
},
["duckfusionsfix"] = {
  { spawnCircle = {x=800, z=700, r=200}, unitNames = {["critter_duck"]=2} },
  { spawnBox = {x1=50, z1=50, x2=2000, z2=2000}, unitNames = {["critter_duck"]=3} },
},

["Epic-EE-CrossingGlade-v04"] = {
  { spawnCircle = {x=2000, z=2300, r=1000}, unitNames = {["critter_gull"]=3} },
  { spawnCircle = {x=1750, z=2560, r=250}, unitNames = {["critter_duck"]=3} },
  { spawnCircle = {x=2600, z=2080, r=250}, unitNames = {["critter_duck"]=5} },
},

["FrozenFortress_v2"] = {
  { spawnBox = {x1=50, z1=50, x2=10100, z2=8150}, unitNames = {["critter_penguin"]=6} },
},

["FolsomDamDeluxeV4"] = {
  { spawnBox = {x1=3580, z1=50, x2=6620, z2=2330}, unitNames = {["critter_goldfish"]=10} },
  { spawnBox = {x1=50, z1=50, x2=10200, z2=7150}, unitNames = {["critter_gull"]=10} },
  { spawnCircle = {x=6350, z=6900, r=260}, unitNames = {["critter_duck"]=2} },
  { spawnCircle = {x=4100, z=4500, r=230}, unitNames = {["critter_duck"]=1} },
},

["Frozen_Gauntlet_TNM03-V2"] = {
  { spawnCircle = {x=3250, z=2900, r=200}, unitNames = {["critter_penguin"]=8} },
  { spawnCircle = {x=360, z=1800, r=250}, unitNames = {["critter_penguin"]=8} },
},

["IslandParadiseV2"] = {
  { spawnBox = {x1=3950, z1=4440, x2=4150, z2=4950}, unitNames = {["critter_duck"]=4} },
  { spawnBox = {x1=3100, z1=800, x2=5000, z2=1500}, unitNames = {["critter_gull"]=2} },
  { spawnBox = {x1=3100, z1=6500, x2=5000, z2=8000}, unitNames = {["critter_gull"]=2} },
},

["Nuclear_Winter_v1"] = {
  { spawnBox = {x1=50, z1=50, x2=10100, z2=6100}, unitNames = {["critter_penguin"]=6} },
},

["Melt_V2"] = {
  { spawnBox = {x1=50, z1=50, x2=8150, z2=8150}, unitNames = {["critter_penguin"]=9} },
},

["Sparewood-v01"] = {
  { spawnBox = {x1=20, z1=2500, x2=700, z2=3350}, unitNames = {["critter_duck"]=4} },
  { spawnBox = {x1=20, z1=880, x2=300, z2=1500}, unitNames = {["critter_duck"]=6} },
  { spawnBox = {x1=100, z1=100, x2=4000, z2=4000}, unitNames = {["critter_gull"]=3} },
},

--["supreme islands"] = {
--{ spawnBox = {x1=800, z1=6300, x2=1600, z2=7000}, unitNames = {["critter_duck"]=8} },
--{ spawnBox = {x1=6560, z1=1200, x2=7160, z2=1600}, unitNames = {["critter_duck"]=8} },
--},

["Supreme Battlefield"] = {
  { spawnCircle = {x=11500, z=12500, r=2700}, unitNames = {["critter_goldfish"]=15} },
  { spawnCircle = {x=15000, z=10500, r=300}, unitNames = {["critter_goldfish"]=2} },
  { spawnCircle = {x=4700, z=3900, r=2700}, unitNames = {["critter_goldfish"]=16} },
  { spawnCircle = {x=1700, z=5700, r=300}, unitNames = {["critter_goldfish"]=1} },
  { spawnCircle = {x=13950, z=2900, r=900}, unitNames = {["critter_duck"]=3} },
  { spawnCircle = {x=2450, z=13450, r=900}, unitNames = {["critter_duck"]=3} },
  { spawnBox = {x1=100, z1=100, x2=16200, z2=16200}, unitNames = {["critter_gull"]=25} },
},

["Small Supreme Battlefield V2"] = {
  { spawnCircle = {x=5800, z=6250, r=1300}, unitNames = {["critter_goldfish"]=9} },
  { spawnCircle = {x=7500, z=5200, r=200}, unitNames = {["critter_goldfish"]=2} },
  { spawnCircle = {x=2350, z=1950, r=1300}, unitNames = {["critter_goldfish"]=10} },
  { spawnCircle = {x=850, z=2850, r=200}, unitNames = {["critter_goldfish"]=1} },
  { spawnCircle = {x=7000, z=1450, r=450}, unitNames = {["critter_duck"]=3} },
  { spawnCircle = {x=1220, z=6720, r=450}, unitNames = {["critter_duck"]=3} },
  { spawnBox = {x1=100, z1=100, x2=8150, z2=8150}, unitNames = {["critter_gull"]=15} },
},

["Tabula-v2"] = {
  { spawnBox = {x1=6100, z1=1700, x2=6300, z2=2000}, unitNames = {["critter_duck"]=4, ["critter_gull"]=1} },
  { spawnBox = {x1=1500, z1=6000, x2=1800, z2=6600}, unitNames = {["critter_duck"]=2, ["critter_gull"]=1} },
},

["Tabula-v4"] = {
  { spawnBox = {x1=6100, z1=1700, x2=6300, z2=2000}, unitNames = {["critter_duck"]=4, ["critter_gull"]=1} },
  { spawnBox = {x1=1500, z1=6000, x2=1800, z2=6600}, unitNames = {["critter_duck"]=2, ["critter_gull"]=1} },
  { spawnCircle = {x=6000, z=500, r=200}, unitNames = {["critter_goldfish"]=2} },
  { spawnCircle = {x=2200, z=6800, r=200}, unitNames = {["critter_goldfish"]=2} },
},

["Ternion"] = {
  { spawnCircle = {x=1100, z=1400, r=600}, unitNames = {["critter_duck"]=2} },
  { spawnCircle = {x=3000, z=5200, r=600}, unitNames = {["critter_duck"]=2} },
  { spawnCircle = {x=5000, z=1500, r=600}, unitNames = {["critter_duck"]=2} },
  { spawnCircle = {x=3333, z=1720, r=150}, unitNames = {["critter_goldfish"]=5} },
  { spawnCircle = {x=4260, z=3800, r=150}, unitNames = {["critter_goldfish"]=5} },
  { spawnCircle = {x=1920, z=3330, r=150}, unitNames = {["critter_goldfish"]=5} },
  { spawnBox = {x1=100, z1=100, x2=6000, z2=6000}, unitNames = {["critter_gull"]=3} },
},

["TheColdPlace"] = {
  { spawnBox = {x1=2700, z1=1800, x2=4500, z2=3200}, unitNames = {["critter_goldfish"]=10} },
  { spawnBox = {x1=1500, z1=3700, x2=5400, z2=4000}, unitNames = {["critter_penguin"]=10} },
},

["The Cold Place Remake"] = {
  { spawnBox = {x1=2700, z1=1800, x2=4500, z2=3200}, unitNames = {["critter_goldfish"]=10} },
  { spawnBox = {x1=1500, z1=3700, x2=5400, z2=4000}, unitNames = {["critter_penguin"]=10} },
  { spawnCircle = {x=1500, z=2300, r=200}, unitNames = {["critter_penguin"]=5} },
  { spawnCircle = {x=5400, z=2000, r=200}, unitNames = {["critter_penguin"]=5} },
},

["The Cold Place Remake V2"] = {
  { spawnBox = {x1=2700, z1=1800, x2=4500, z2=3200}, unitNames = {["critter_goldfish"]=10} },
  { spawnBox = {x1=1500, z1=3700, x2=5400, z2=4000}, unitNames = {["critter_penguin"]=10} },
  { spawnCircle = {x=1500, z=2300, r=200}, unitNames = {["critter_penguin"]=5} },
  { spawnCircle = {x=5400, z=2000, r=200}, unitNames = {["critter_penguin"]=5} },
},

["The Cold Place Remake V3c"] = {
  { spawnBox = {x1=2700, z1=1800, x2=4500, z2=3200}, unitNames = {["critter_goldfish"]=10} },
  { spawnBox = {x1=1500, z1=3700, x2=5400, z2=4000}, unitNames = {["critter_penguin"]=10} },
  { spawnCircle = {x=1500, z=2300, r=200}, unitNames = {["critter_penguin"]=5} },
  { spawnCircle = {x=5400, z=2000, r=200}, unitNames = {["critter_penguin"]=5} },
},

--["trefoil"] = {
--{ spawnBox = {x1=5666, z1=4888, x2=8000, z2=6400}, unitNames = {["critter_goldfish"]=10} },
--{ spawnBox = {x1=3400, z1=300, x2=5000, z2=1500}, unitNames = {["critter_goldfish"]=10} },
--},

["Tropical"] = {
  { spawnCircle = {x=1550, z=4650, r=400}, unitNames = {["critter_goldfish"]=1} },
  { spawnCircle = {x=1000, z=5300, r=800}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=1500, z=5900, r=700}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=7700, z=5300, r=700}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=7850, z=4350, r=800}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=4600, z=5200, r=3500}, unitNames = {["critter_gull"]=5} },
  { spawnCircle = {x=4600, z=5200, r=500}, unitNames = {["critter_duck"]=2} },
},

["Tropical-v2"] = {
  { spawnCircle = {x=1550, z=4650, r=400}, unitNames = {["critter_goldfish"]=1} },
  { spawnCircle = {x=1000, z=5300, r=800}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=1500, z=5900, r=700}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=7700, z=5300, r=700}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=7850, z=4350, r=800}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=4600, z=5200, r=3500}, unitNames = {["critter_gull"]=5} },
  { spawnCircle = {x=4600, z=5200, r=500}, unitNames = {["critter_duck"]=2} },
},

["Talus"] = {
  { spawnCircle = {x=4000, z=4000, r=3500}, unitNames = {["critter_gull"]=10} },
},

["Tempest"] = {
  { spawnCircle = {x=6500, z=4450, r=500}, unitNames = {["critter_goldfish"]=4} },
  { spawnCircle = {x=6700, z=6000, r=350}, unitNames = {["critter_goldfish"]=2} },
  { spawnCircle = {x=4300, z=7777, r=280}, unitNames = {["critter_goldfish"]=2} },
  { spawnCircle = {x=3800, z=2550, r=280}, unitNames = {["critter_goldfish"]=2} },
  { spawnCircle = {x=3850, z=5600, r=800}, unitNames = {["critter_goldfish"]=5} },
  { spawnCircle = {x=5300, z=5100, r=1100}, unitNames = {["critter_goldfish"]=5} },
  { spawnCircle = {x=5000, z=2500, r=1700}, unitNames = {["critter_gull"]=3} },
  { spawnCircle = {x=5000, z=7500, r=1700}, unitNames = {["critter_gull"]=3} },
},

["Tangerine"] = {
  { spawnCircle = {x=1400, z=7500, r=500}, unitNames = {["critter_goldfish"]=5} },
  { spawnCircle = {x=750, z=7000, r=500}, unitNames = {["critter_goldfish"]=2} },
  { spawnCircle = {x=400, z=3150, r=400}, unitNames = {["critter_goldfish"]=2} },
  { spawnCircle = {x=120, z=4000, r=500}, unitNames = {["critter_goldfish"]=2} },
  { spawnCircle = {x=7500, z=750, r=550}, unitNames = {["critter_goldfish"]=7} },
  { spawnCircle = {x=7750, z=4400, r=550}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=6000, z=4000, r=500}, unitNames = {["critter_goldfish"]=2} },
  { spawnCircle = {x=2000, z=5100, r=700}, unitNames = {["critter_gull"]=2} },
  { spawnCircle = {x=5200, z=1300, r=800}, unitNames = {["critter_gull"]=2} },
  { spawnCircle = {x=5500, z=4500, r=1100}, unitNames = {["critter_gull"]=3} },
},

--["tumult"] = {
--{ spawnBox = {x1=3440, z1=3440, x2=3680, z2=3780} , unitNames = {["critter_duck"]=3} },
--},

["Vernal 3way 0.6.1"] = {
  { spawnCircle = {x=rnd(1000,4000), z=rnd(1000,4000), r=300}, unitNames = {["critter_duck"]=6} },
  { spawnCircle = {x=rnd(1000,4000), z=rnd(1000,4000), r=300}, unitNames = {["critter_duck"]=6} },
  { spawnCircle = {x=rnd(1000,4000), z=rnd(1000,4000), r=300}, unitNames = {["critter_duck"]=6} },
  { spawnBox = {x1=100, z1=100, x2=5000, z2=5000}, unitNames = {["critter_duck"]=4} },
},

}

return critterConfig
