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

["DesertTriad"] = {
  { spawnBox = {x1=1800, z1=3400, x2=3900, z2=3900}, unitNames = {["critter_gull"]=1} },
  { spawnBox = {x1=1800, z1=20, x2=3900, z2=120}, unitNames = {["critter_gull"]=1} },
},

["duck"] = {
  { spawnCircle = {x=800, z=700, r=200}, unitNames = {["critter_duck"]=2} },
},

["Epic-EE-CrossingGlade-v04"] = {
  { spawnCircle = {x=2000, z=2300, r=1000}, unitNames = {["critter_gull"]=3} },
  { spawnCircle = {x=1750, z=2560, r=250}, unitNames = {["critter_duck"]=3} },
  { spawnCircle = {x=2600, z=2080, r=250}, unitNames = {["critter_duck"]=5} },
},

["Frozen_Gauntlet_TNM03-V2"] = {
  { spawnCircle = {x=3250, z=2900, r=200}, unitNames = {["critter_pinguin"]=8} },
  { spawnCircle = {x=360, z=1800, r=250}, unitNames = {["critter_pinguin"]=8} },
},

["IslandParadiseV2"] = {
  { spawnBox = {x1=3950, z1=4440, x2=4150, z2=4950}, unitNames = {["critter_duck"]=4} },
  { spawnBox = {x1=3100, z1=800, x2=5000, z2=1500}, unitNames = {["critter_gull"]=2} },
  { spawnBox = {x1=3100, z1=6500, x2=5000, z2=8000}, unitNames = {["critter_gull"]=2} },
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
  { spawnBox = {x1=1500, z1=3700, x2=5400, z2=4000}, unitNames = {["critter_pinguin"]=10} },
},

["The Cold Place Remake"] = {
  { spawnBox = {x1=2700, z1=1800, x2=4500, z2=3200}, unitNames = {["critter_goldfish"]=10} },
  { spawnBox = {x1=1500, z1=3700, x2=5400, z2=4000}, unitNames = {["critter_pinguin"]=10} },
  { spawnCircle = {x=1500, z=2300, r=200}, unitNames = {["critter_pinguin"]=5} },
  { spawnCircle = {x=5400, z=2000, r=200}, unitNames = {["critter_pinguin"]=5} },
},

["The Cold Place Remake V2"] = {
  { spawnBox = {x1=2700, z1=1800, x2=4500, z2=3200}, unitNames = {["critter_goldfish"]=10} },
  { spawnBox = {x1=1500, z1=3700, x2=5400, z2=4000}, unitNames = {["critter_pinguin"]=10} },
  { spawnCircle = {x=1500, z=2300, r=200}, unitNames = {["critter_pinguin"]=5} },
  { spawnCircle = {x=5400, z=2000, r=200}, unitNames = {["critter_pinguin"]=5} },
},

["The Cold Place Remake V3c"] = {
  { spawnBox = {x1=2700, z1=1800, x2=4500, z2=3200}, unitNames = {["critter_goldfish"]=10} },
  { spawnBox = {x1=1500, z1=3700, x2=5400, z2=4000}, unitNames = {["critter_pinguin"]=10} },
  { spawnCircle = {x=1500, z=2300, r=200}, unitNames = {["critter_pinguin"]=5} },
  { spawnCircle = {x=5400, z=2000, r=200}, unitNames = {["critter_pinguin"]=5} },
},

--["trefoil"] = {
--{ spawnBox = {x1=5666, z1=4888, x2=8000, z2=6400}, unitNames = {["critter_goldfish"]=10} },
--{ spawnBox = {x1=3400, z1=300, x2=5000, z2=1500}, unitNames = {["critter_goldfish"]=10} },
--},

["Tropical"] = {
  { spawnCircle = {x=1000, z=5300, r=800}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=8100, z=5300, r=800}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=4600, z=5200, r=3500}, unitNames = {["critter_gull"]=2} },
  { spawnCircle = {x=4600, z=5200, r=500}, unitNames = {["critter_duck"]=2} },
},

["Tropical-v2"] = {
  { spawnCircle = {x=1000, z=5300, r=800}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=8100, z=5300, r=800}, unitNames = {["critter_goldfish"]=3} },
  { spawnCircle = {x=4600, z=5200, r=3500}, unitNames = {["critter_gull"]=2} },
  { spawnCircle = {x=4600, z=5200, r=500}, unitNames = {["critter_duck"]=2} },
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
