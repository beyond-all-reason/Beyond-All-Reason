local rnd = math.random

-- USE LOWERCASE MAPNAMES (partial mapnames work too!)
local critterConfig = {

	["avalanche"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 4000, z2 = 4000 }, unitNames = { ["critter_penguin"] = rnd(4, 7) } },
	},

	["deeploria fields"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 10000, z2 = 10000 }, unitNames = { ["critter_goldfish"] = rnd(10, 25) } },
	},

	["calamity_v"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_goldfish"] = rnd(170, 240) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_gull"] = rnd(25, 45) } },
	},

	["center command"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8120, z2 = 8120 }, unitNames = { ["critter_gull"] = rnd(5, 15) } },
	},

	["centerrock"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_goldfish"] = rnd(220, 440) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_gull"] = rnd(6, 11) } },
		{ spawnCircle = { x = 1500, z = 7150, r = 1500 }, unitNames = { ["critter_gull"] = rnd(3, 5) } },
		{ spawnCircle = { x = 7333, z = 380, r = 1500 }, unitNames = { ["critter_gull"] = rnd(2, 3) } },
		{ spawnCircle = { x = 2950, z = 5500, r = 1600 }, unitNames = { ["critter_gull"] = rnd(2, 3) } },
		{ spawnCircle = { x = 4333, z = 3777, r = 2400 }, unitNames = { ["critter_gull"] = rnd(4, 6) } },
	},

	["crescent_bay"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 12200, z2 = 12200 }, unitNames = { ["critter_goldfish"] = rnd(20, 30) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 12200, z2 = 12200 }, unitNames = { ["critter_gull"] = rnd(10, 15) } },
		{ spawnCircle = { x = 1335, z = 6601, r = 100 }, unitNames = { ["critter_penguin"] = rnd(10, 15) } },
	},

	["downs_of_destruction"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_goldfish"] = rnd(70, 110) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_crab"] = rnd(1, 2) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_gull"] = rnd(7, 11) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_duck"] = rnd(4, 6) } },
	},

	["dworld"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 14300, z2 = 14300 }, unitNames = { ["critter_gull"] = rnd(16, 25) } },
	},

	["duck"] = {
		{ spawnCircle = { x = 800, z = 700, r = 200 }, unitNames = { ["critter_duck"] = rnd(2, 4) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 2000, z2 = 2000 }, unitNames = { ["critter_duck"] = rnd(2, 22) } },
	},

	["emain macha"] = {
		{ spawnCircle = { x = 40, z = 4700, r = 800 }, unitNames = { ["critter_duck"] = rnd(1, 2) } },
		{ spawnCircle = { x = 40, z = 4700, r = 1100 }, unitNames = { ["critter_gull"] = rnd(2, 3) } },
		{ spawnCircle = { x = 40, z = 4700, r = 1100 }, unitNames = { ["critter_goldfish"] = rnd(6, 10) } },
		{ spawnCircle = { x = 8100, z = 4700, r = 700 }, unitNames = { ["critter_duck"] = rnd(1, 2) } },
		{ spawnCircle = { x = 8100, z = 4700, r = 1100 }, unitNames = { ["critter_gull"] = rnd(2, 3) } },
		{ spawnCircle = { x = 8100, z = 4700, r = 1100 }, unitNames = { ["critter_goldfish"] = rnd(6, 10) } },
		{ spawnCircle = { x = 8100, z = 4700, r = 1100 }, unitNames = { ["critter_crab"] = rnd(1, 2) } },
	},

	["fallendell"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 5100, z2 = 5100 }, unitNames = { ["critter_gull"] = rnd(5, 10) } },
	},

	["flats and forests"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 12200, z2 = 12200 }, unitNames = { ["critter_gull"] = rnd(5, 15) } },
	},

	["folsomdam"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 10200, z2 = 7150 }, unitNames = { ["critter_gull"] = rnd(4, 7) } },
		{ spawnBox = { x1 = 2200, z1 = 50, x2 = 8800, z2 = 7150 }, unitNames = { ["critter_gull"] = rnd(6, 10) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 10200, z2 = 7150 }, unitNames = { ["critter_goldfish"] = rnd(70, 140) } },
		{ spawnCircle = { x = 6350, z = 6900, r = 260 }, unitNames = { ["critter_duck"] = rnd(0, 3) } },
		{ spawnCircle = { x = 4100, z = 4500, r = 230 }, unitNames = { ["critter_duck"] = rnd(0, 2) } },
	},

	["gecko isle"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8100, z2 = 9000 }, unitNames = { ["critter_gull"] = rnd(5, 10) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8100, z2 = 9000 }, unitNames = { ["critter_goldfish"] = rnd(5, 10) } },
	},

	["greenest fields"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8100, z2 = 8100 }, unitNames = { ["critter_gull"] = rnd(3, 8) } },
	},

	["hotlips"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 11200, z2 = 9150 }, unitNames = { ["critter_ant"] = rnd(20, 30) } },
	},

	["nuclear winter"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 10100, z2 = 6100 }, unitNames = { ["critter_penguin"] = rnd(9, 13) } },
	},

	["mariposa island"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 9000, z2 = 9000 }, unitNames = { ["critter_goldfish"] = rnd(10, 20) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 9000, z2 = 9000 }, unitNames = { ["critter_gull"] = rnd(10, 20) } },
	},

	["melting glacier"] = {
		{ spawnCircle = { x = 5200, z = 4000, r = 2400 }, unitNames = { ["critter_penguin"] = rnd(3, 15) }},
	},

	["mescaline"] = {
		{ spawnCircle = { x = 1933, z = 6080, r = 30 }, unitNames = { ["critter_goldfish"] = rnd(-5, 1) }, nowatercheck = true },
		{ spawnCircle = { x = 1933, z = 6080, r = 500 }, unitNames = { ["critter_gull"] = rnd(-3, 1) } },
		{ spawnCircle = { x = 7400, z = 970, r = 30 }, unitNames = { ["critter_goldfish"] = rnd(-5, 1) }, nowatercheck = true },
		{ spawnCircle = { x = 7400, z = 970, r = 500 }, unitNames = { ["critter_gull"] = rnd(-3, 1) } },
		{ spawnCircle = { x = 9450, z = 4200, r = 30 }, unitNames = { ["critter_goldfish"] = rnd(-5, 1) }, nowatercheck = true },
		{ spawnCircle = { x = 9450, z = 4200, r = 500 }, unitNames = { ["critter_gull"] = rnd(-3, 1) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 10200, z2 = 6100 }, unitNames = { ["critter_gull"] = rnd(7, 12) } },
	},

	["neurope"] = {
		{ spawnBox = { x1 = 14400, z1 = 20, x2 = 16200, z2 = 1250 }, unitNames = { ["critter_penguin"] = rnd(5, 10) } },
		{ spawnCircle = { x = 3950, z = 580, r = 600 }, unitNames = { ["critter_penguin"] = rnd(6, 14) } },
		{ spawnCircle = { x = 3950, z = 580, r = 850 }, unitNames = { ["critter_gull"] = rnd(0, 2) } },
		{ spawnCircle = { x = 1000, z = 650, r = 400 }, unitNames = { ["critter_penguin"] = rnd(0, 4) } },
		{ spawnCircle = { x = 1350, z = 2850, r = 1500 }, unitNames = { ["critter_gull"] = rnd(0, 3) } },
		{ spawnCircle = { x = 11650, z = 1100, r = 500 }, unitNames = { ["critter_penguin"] = rnd(0, 3) } },
		{ spawnBox = { x1 = 7400, z1 = 500, x2 = 9150, z2 = 1200 }, unitNames = { ["critter_penguin"] = rnd(0, 4) } },
		{ spawnBox = { x1 = 6150, z1 = 700, x2 = 8480, z2 = 1111 }, unitNames = { ["critter_penguin"] = rnd(0, 4) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 16200, z2 = 8150 }, unitNames = { ["critter_goldfish"] = rnd(100, 200) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 16200, z2 = 8150 }, unitNames = { ["critter_crab"] = rnd(0, 1) } },
		{ spawnBox = { x1 = 100, z1 = 100, x2 = 16200, z2 = 8150 }, unitNames = { ["critter_gull"] = rnd(15, 20) } },
	},

	["onyx cauldron"] = {
		--{ spawnBox = { x1 = 50, z1 = 50, x2 = 10000, z2 = 10000 }, unitNames = { ["critter_gull"] = rnd(5, 20) } },
		{ spawnCircle = { x = 4493, z = 3775, r = 120 }, unitNames = { ["critter_goldfish"] = rnd(-4, 1) }, nowatercheck = true },
		{ spawnCircle = { x = 3593, z = 775, r = 60 }, unitNames = { ["critter_goldfish"] = rnd(-4, 1) }, nowatercheck = true },
		{ spawnCircle = { x = 1933, z = 6080, r = 500 }, unitNames = { ["critter_gull"] = rnd(-3, 1) } },
		{ spawnCircle = { x = 6050, z = 2583, r = 30 }, unitNames = { ["critter_goldfish"] = rnd(-4, 1) }, nowatercheck = true },
		{ spawnCircle = { x = 7400, z = 970, r = 500 }, unitNames = { ["critter_gull"] = rnd(-3, 1) } },
		{ spawnCircle = { x = 7450, z = 4500, r = 60 }, unitNames = { ["critter_goldfish"] = rnd(-4, 1) }, nowatercheck = true },
		{ spawnCircle = { x = 7450, z = 4200, r = 500 }, unitNames = { ["critter_gull"] = rnd(-3, 1) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 10200, z2 = 6100 }, unitNames = { ["critter_gull"] = rnd(3, 8) } },
		{ spawnCircle = { x = 2833, z = 966, r = 450 }, unitNames = { ["critter_duck"] = rnd(0, 2) } },
		{ spawnCircle = { x = 7033, z = 5695, r = 450 }, unitNames = { ["critter_duck"] = rnd(0, 2) } },
	},

	["pawn retreat"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 10000, z2 = 10000 }, unitNames = { ["critter_gull"] = rnd(5, 20) } },
	},

	["paradise_lost"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 10200, z2 = 5050 }, unitNames = { ["critter_gull"] = rnd(15, 25) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 10200, z2 = 5050 }, unitNames = { ["critter_goldfish"] = rnd(100, 150) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 10200, z2 = 5050 }, unitNames = { ["critter_goldfish"] = rnd(0, 1) } },
	},


	["real europe"] = {
		{ spawnBox = { x1 = 50, z1 = 4000, x2 = 12250, z2 = 12250 }, unitNames = { ["critter_goldfish"] = rnd(220, 300) } },
		{ spawnCircle = { x = 2050, z = 2700, r = 2500 }, unitNames = { ["critter_gull"] = rnd(4, 7) } },
		{ spawnCircle = { x = 3000, z = 6700, r = 3300 }, unitNames = { ["critter_gull"] = rnd(8, 11) } },
		{ spawnCircle = { x = 7100, z = 6300, r = 4200 }, unitNames = { ["critter_gull"] = rnd(11, 18) } },
		{ spawnCircle = { x = 5200, z = 3000, r = 2500 }, unitNames = { ["critter_gull"] = rnd(5, 8) } },
		{ spawnCircle = { x = 7350, z = 8250, r = 2000 }, unitNames = { ["critter_gull"] = rnd(5, 8) } },
		{ spawnCircle = { x = 8500, z = 3650, r = 1550 }, unitNames = { ["critter_gull"] = rnd(2, 4) } },
		{ spawnCircle = { x = 11000, z = 1600, r = 2300 }, unitNames = { ["critter_penguin"] = rnd(8, 12) } },
		{ spawnCircle = { x = 11500, z = 3650, r = 1500 }, unitNames = { ["critter_penguin"] = rnd(6, 10) } },
		{ spawnCircle = { x = 6550, z = 100, r = 1600 }, unitNames = { ["critter_penguin"] = rnd(6, 10) } },
		{ spawnCircle = { x = 5080, z = 200, r = 850 }, unitNames = { ["critter_penguin"] = rnd(2, 4) } },
		{ spawnCircle = { x = 12222, z = 500, r = 1100 }, unitNames = { ["critter_penguin"] = rnd(2, 4) } },
		{ spawnCircle = { x = 7800, z = 1400, r = 200 }, unitNames = { ["critter_penguin"] = rnd(1, 2) } },
		{ spawnCircle = { x = 9666, z = 1444, r = 1050 }, unitNames = { ["critter_penguin"] = rnd(2, 4) } },
		{ spawnCircle = { x = 5333, z = 8666, r = 600 }, unitNames = { ["critter_duck"] = rnd(4, 6) } },
		{ spawnCircle = { x = 6633, z = 9595, r = 450 }, unitNames = { ["critter_duck"] = rnd(2, 3) } },
		{ spawnBox = { x1 = 9980, z1 = 8333, x2 = 12250, z2 = 9933 }, unitNames = { ["critter_ant"] = rnd(4, 6) } },
		{ spawnBox = { x1 = 5666, z1 = 11666, x2 = 12250, z2 = 12250 }, unitNames = { ["critter_ant"] = rnd(6, 10) } },
		{ spawnBox = { x1 = 1333, z1 = 10300, x2 = 5666, z2 = 12250 }, unitNames = { ["critter_ant"] = rnd(10, 16) } },
	},

	["ring atoll remake"] = {
		{ spawnBox = { x1 = 2000, z1 = 2000, x2 = 7200, z2 = 7200 }, unitNames = { ["critter_goldfish"] = rnd(5, 15) } },
		{ spawnBox = { x1 = 2000, z1 = 2000, x2 = 7200, z2 = 7200 }, unitNames = { ["critter_gull"] = rnd(5, 15) } },
		{ spawnBox = { x1 = 2000, z1 = 2000, x2 = 7200, z2 = 7200 }, unitNames = { ["critter_crab"] = rnd(5, 15) } },
	},

	["serene caldera"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 15000, z2 = 15000 }, unitNames = { ["critter_goldfish"] = rnd(100, 150) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 15000, z2 = 15000 }, unitNames = { ["critter_gull"] = rnd(15, 30) } },
	},

	["sulphur springs"] = {
		{ spawnCircle = { x = 4300, z = 8000, r = 2000 }, unitNames = { ["critter_ant"] = rnd(3, 10) } },
	},

	["supreme isthmus winter"] = {
		{ spawnCircle = { x = 3500, z = 8500, r = 400 }, unitNames = { ["critter_penguin"] = rnd(2, 4) } },
		{ spawnCircle = { x = 8800, z = 3800, r = 400 }, unitNames = { ["critter_penguin"] = rnd(2, 4) } },
		{ spawnCircle = { x = 990, z = 1900, r = 400 }, unitNames = { ["critter_penguin"] = rnd(3, 5) } },
		{ spawnCircle = { x = 11000, z = 10000, r = 400 }, unitNames = { ["critter_penguin"] = rnd(3, 5) } },
		{ spawnCircle = { x = 6200, z = 300, r = 400 }, unitNames = { ["critter_penguin"] = rnd(2, 4) } },
		{ spawnCircle = { x = 6000, z = 12000, r = 400 }, unitNames = { ["critter_penguin"] = rnd(2, 4) } },
		{ spawnCircle = { x = 5500, z = 6400, r = 400 }, unitNames = { ["critter_penguin"] = rnd(2, 4) } },
		{ spawnCircle = { x = 6600, z = 6200, r = 400 }, unitNames = { ["critter_penguin"] = rnd(2, 4) } },
		{ spawnCircle = { x = 4000, z = 4800, r = 400 }, unitNames = { ["critter_penguin"] = rnd(2, 4) } },
		{ spawnCircle = { x = 11800, z = 7300, r = 400 }, unitNames = { ["critter_penguin"] = rnd(2, 4) } },
	},

	["supreme crossing"] = {
		{ spawnCircle = { x = 5800, z = 6250, r = 1300 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 7500, z = 5200, r = 200 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 2350, z = 1950, r = 1300 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 850, z = 2850, r = 200 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 7000, z = 1450, r = 450 }, unitNames = { ["critter_duck"] = rnd(0, 3) } },
		{ spawnCircle = { x = 1220, z = 6720, r = 450 }, unitNames = { ["critter_duck"] = rnd(0, 3) } },
		{ spawnBox = { x1 = 100, z1 = 100, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_gull"] = rnd(7, 12) } },
		{ spawnBox = { x1 = 100, z1 = 100, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_goldfish"] = rnd(50, 100) } },
	},

	["supreme isthmus"] = {
		{ spawnCircle = { x = 8700, z = 9300, r = 2000 }, unitNames = { ["critter_goldfish"] = rnd(2, 10) } },
		{ spawnCircle = { x = 3200, z = 2500, r = 2000 }, unitNames = { ["critter_goldfish"] = rnd(2, 10) } },
		{ spawnCircle = { x = 9700, z = 3232, r = 500 }, unitNames = { ["critter_goldfish"] = rnd(1, 3) } },
		{ spawnCircle = { x = 2500, z = 9000, r = 500 }, unitNames = { ["critter_goldfish"] = rnd(1, 3) } },
		{ spawnCircle = { x = 6050, z = 6050, r = 800 }, unitNames = { ["critter_crab"] = rnd(2, 6) } },
		{ spawnBox = { x1 = 100, z1 = 100, x2 = 12150, z2 = 12150 }, unitNames = { ["critter_gull"] = rnd(10, 20) } },
	},

	["tabula_remake"] = {
		--{ spawnCircle = { x = 5440, z = 4700, r = 150 }, unitNames = { ["critter_ant"] = rnd(-3, 1) } },
		--{ spawnCircle = { x = 5900, z = 7000, r = 150 }, unitNames = { ["critter_ant"] = rnd(-3, 1) } },
		--{ spawnCircle = { x = 300, z = 6950, r = 220 }, unitNames = { ["critter_ant"] = rnd(-5, 5) } },
		--{ spawnBox = { x1 = 2280, z1 = 12, x2 = 2410, z2 = 250 }, unitNames = { ["critter_ant"] = rnd(-3, 1) } },
		{ spawnBox = { x1 = 6100, z1 = 1700, x2 = 6300, z2 = 2000 }, unitNames = { ["critter_duck"] = rnd(1, 3) } },
		{ spawnBox = { x1 = 1500, z1 = 6000, x2 = 1800, z2 = 6600 }, unitNames = { ["critter_duck"] = rnd(1, 3) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 7150 }, unitNames = { ["critter_gull"] = rnd(5, 8) } },
		{ spawnBox = { x1 = 1000, z1 = 4500, x2 = 3150, z2 = 8150 }, unitNames = { ["critter_gull"] = rnd(3, 4) } },
		{ spawnBox = { x1 = 5000, z1 = 50, x2 = 7050, z2 = 4650 }, unitNames = { ["critter_gull"] = rnd(3, 4) } },
		{ spawnBox = { x1 = 1700, z1 = 5750, x2 = 2600, z2 = 8150 }, unitNames = { ["critter_goldfish"] = rnd(4, 6) } },
		{ spawnBox = { x1 = 5500, z1 = 50, x2 = 6500, z2 = 1450 }, unitNames = { ["critter_goldfish"] = rnd(4, 6) } },
		{ spawnBox = { x1 = 1700, z1 = 5750, x2 = 2600, z2 = 8150 }, unitNames = { ["critter_crab"] = rnd(0, 1) } },
		{ spawnBox = { x1 = 5500, z1 = 50, x2 = 6500, z2 = 1450 }, unitNames = { ["critter_crab"] = rnd(0, 1) } },
	},

	["talus"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_gull"] = rnd(7, 12) } },
		{ spawnCircle = { x = 6555, z = 4155, r = 650 }, unitNames = { ["critter_gull"] = rnd(2, 4) } },
		{ spawnCircle = { x = 1600, z = 4044, r = 650 }, unitNames = { ["critter_gull"] = rnd(2, 4) } },
		{ spawnCircle = { x = 1310, z = 2065, r = 550 }, unitNames = { ["critter_gull"] = rnd(0, 1) } },
		{ spawnCircle = { x = 1310, z = 2065, r = 30 }, unitNames = { ["critter_goldfish"] = rnd(-2, 1) }, nowatercheck = true },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_goldfish"] = rnd(30, 50) } },
	},

	["tangerine"] = {
		{ spawnCircle = { x = 1400, z = 7500, r = 500 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 750, z = 7000, r = 500 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 400, z = 3150, r = 400 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 120, z = 4000, r = 500 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 7500, z = 750, r = 550 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 7750, z = 4400, r = 550 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 6000, z = 4000, r = 500 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 2000, z = 5100, r = 700 }, unitNames = { ["critter_gull"] = rnd(0, 3) } },
		{ spawnCircle = { x = 5200, z = 1300, r = 800 }, unitNames = { ["critter_gull"] = rnd(0, 3) } },
		{ spawnCircle = { x = 5500, z = 4500, r = 1100 }, unitNames = { ["critter_gull"] = rnd(0, 3) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_goldfish"] = rnd(40, 80) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_gull"] = rnd(14, 20) } },
	},

	["tempest"] = {
		{ spawnCircle = { x = 6500, z = 4450, r = 500 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 6700, z = 6000, r = 350 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 4300, z = 7777, r = 280 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 3800, z = 2550, r = 280 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 3850, z = 5600, r = 800 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 5300, z = 5100, r = 1100 }, unitNames = { ["critter_goldfish"] = rnd(0, 3) } },
		{ spawnCircle = { x = 5000, z = 2500, r = 1700 }, unitNames = { ["critter_gull"] = rnd(0, 3) } },
		{ spawnCircle = { x = 5000, z = 7500, r = 1700 }, unitNames = { ["critter_gull"] = rnd(0, 3) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_goldfish"] = rnd(33, 66) } },
	},

	["titan-v"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 9200, z2 = 6100 }, unitNames = { ["critter_ant"] = rnd(7, 14) } },
	},

	["trefoil"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_goldfish"] = rnd(15, 30) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_gull"] = rnd(5, 10) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 8150, z2 = 8150 }, unitNames = { ["critter_crab"] = rnd(1, 1) } },
	},

	["the cold place"] = {
		{ spawnCircle = { x = 5200, z = 6800, r = 700 }, unitNames = { ["critter_penguin"] = rnd(1, 3) } },
		{ spawnCircle = { x = 6600, z = 1500, r = 500 }, unitNames = { ["critter_penguin"] = rnd(1, 3) } },
		{ spawnCircle = { x = 1700, z = 3600, r = 500 }, unitNames = { ["critter_penguin"] = rnd(1, 3) } },
	},

	["Requiem Outpost"] = {
		{ spawnCircle = { x = 6144, z = 3072, r = 700 }, unitNames = { ["critter_ant"] = rnd(2, 5) } },
		{ spawnCircle = { x = 9144, z = 3072, r = 1400 }, unitNames = { ["critter_ant"] = rnd(2, 5) } },
	},

	["quicksilver"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 7000, z2 = 7000 }, unitNames = { ["critter_goldfish"] = rnd(20, 30) } },
		{ spawnBox = { x1 = 3681, z1 = 3717, x2 = 3804, z2 = 3858 }, unitNames = { ["critter_goldfish"] = rnd(1, 2) } },
		{ spawnBox = { x1 = 1000, z1 = 500, x2 = 6500, z2 = 2400 }, unitNames = { ["critter_gull"] = rnd(2, 4) } },
		{ spawnBox = { x1 = 500, z1 = 4300, x2 = 3500, z2 = 6700 }, unitNames = { ["critter_gull"] = rnd(2, 4) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 7000, z2 = 7000 }, unitNames = { ["critter_duck"] = rnd(1, 1) } },
		{ spawnBox = { x1 = 2300, z1 = 900, x2 = 3100, z2 = 1600 }, unitNames = { ["critter_crab"] = rnd(0, 1) } },
		{ spawnBox = { x1 = 5000, z1 = 5500, x2 = 5900, z2 = 6200 }, unitNames = { ["critter_crab"] = rnd(0, 1) } },
	},

	["tropical-v"] = {
		{ spawnCircle = { x = 1550, z = 4650, r = 400 }, unitNames = { ["critter_goldfish"] = rnd(0, 2) } },
		{ spawnCircle = { x = 1000, z = 5300, r = 800 }, unitNames = { ["critter_goldfish"] = rnd(0, 2) } },
		{ spawnCircle = { x = 1500, z = 5900, r = 700 }, unitNames = { ["critter_goldfish"] = rnd(0, 2) } },
		{ spawnCircle = { x = 7700, z = 5300, r = 700 }, unitNames = { ["critter_goldfish"] = rnd(0, 2) } },
		{ spawnCircle = { x = 7850, z = 4350, r = 800 }, unitNames = { ["critter_goldfish"] = rnd(0, 2) } },
		{ spawnCircle = { x = 4600, z = 5200, r = 3500 }, unitNames = { ["critter_gull"] = rnd(3, 5) } },
		{ spawnCircle = { x = 4600, z = 5200, r = 500 }, unitNames = { ["critter_duck"] = rnd(0, 2) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 9150, z2 = 10200 }, unitNames = { ["critter_goldfish"] = rnd(40, 80) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 9150, z2 = 10200 }, unitNames = { ["critter_gull"] = rnd(12, 20) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 9150, z2 = 10200 }, unitNames = { ["critter_crab"] = rnd(0, 1) } },
	},

	["throne v"] = {
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 12200, z2 = 12200 }, unitNames = { ["critter_goldfish"] = rnd(70, 140) } },
	},

	["tumult"] = {
		{ spawnBox = { x1 = 3450, z1 = 3490, x2 = 3660, z2 = 3720 }, unitNames = { ["critter_goldfish"] = rnd(5, 11) } },
		{ spawnBox = { x1 = 50, z1 = 50, x2 = 7150, z2 = 7150 }, unitNames = { ["critter_ant"] = rnd(5, 10) } },
	},

	["world in flames v"] = {
		{ spawnBox = { x1 = 50, z1 = 400, x2 = 16200, z2 = 7300 }, unitNames = { ["critter_goldfish"] = rnd(130, 170) } },
		{ spawnCircle = { x = 3800, z = 5200, r = 600 }, unitNames = { ["critter_goldfish"] = rnd(9, 13) } },	-- silent sea
		{ spawnCircle = { x = 12500, z = 5400, r = 600 }, unitNames = { ["critter_goldfish"] = rnd(9, 13) } },	-- indian ocean
		{ spawnCircle = { x = 14300, z = 3100, r = 600 }, unitNames = { ["critter_goldfish"] = rnd(9, 13) } },	-- philippine sea
		{ spawnCircle = { x = 7000, z = 2400, r = 600 }, unitNames = { ["critter_goldfish"] = rnd(9, 13) } },	-- atlantic ocean europe
		{ spawnCircle = { x = 5300, z = 2800, r = 600 }, unitNames = { ["critter_goldfish"] = rnd(9, 13) } },	-- atlantic ocean americas

		{ spawnBox = { x1 = 50, z1 = 7650, x2 = 16200, z2 = 8150 }, unitNames = { ["critter_penguin"] = rnd(14, 20) } },	-- antarctica
		{ spawnCircle = { x = 5050, z = 7450, r = 250 }, unitNames = { ["critter_penguin"] = rnd(7, 10) } },	-- antarctica colony 1
		{ spawnCircle = { x = 15300, z = 7500, r = 250 }, unitNames = { ["critter_penguin"] = rnd(4, 6) } },	-- antarctica colony 2

		{ spawnCircle = { x = 14300, z = 5150, r = 530 }, unitNames = { ["critter_ant"] = rnd(5, 7) } },	-- australia center
		{ spawnCircle = { x = 14600, z = 4350, r = 280 }, unitNames = { ["critter_ant"] = rnd(2, 3) } },	-- australia top

		{ spawnCircle = { x = 8900, z = 2400, r = 160 }, unitNames = { ["critter_duck"] = rnd(2, 3) } },	-- mediterranean sea
		{ spawnCircle = { x = 13400, z = 3400, r = 160 }, unitNames = { ["critter_duck"] = rnd(2, 3) } },	-- south china sea

		{ spawnCircle = { x = 3050, z = 2900, r = 700 }, unitNames = { ["critter_gull"] = rnd(2, 3) } },	-- california
		{ spawnCircle = { x = 4600, z = 3350, r = 1100 }, unitNames = { ["critter_gull"] = rnd(6, 10) } },	-- jamaica
		{ spawnCircle = { x = 13400, z = 4000, r = 1100 }, unitNames = { ["critter_gull"] = rnd(6, 10) } },	-- indonesia
		{ spawnCircle = { x = 7900, z = 1900, r = 700 }, unitNames = { ["critter_gull"] = rnd(3, 5) } },	-- english strait
		{ spawnCircle = { x = 8900, z = 2400, r = 900 }, unitNames = { ["critter_gull"] = rnd(4, 6) } },	-- mediterranean sea
		{ spawnCircle = { x = 10400, z = 2200, r = 700 }, unitNames = { ["critter_gull"] = rnd(2, 3) } },	-- captic sea
		{ spawnCircle = { x = 6000, z = 4700, r = 1100 }, unitNames = { ["critter_gull"] = rnd(3, 5) } },	-- brasil
		{ spawnCircle = { x = 9000, z = 4000, r = 1100 }, unitNames = { ["critter_gull"] = rnd(3, 5) } },	-- mid-west africa
		{ spawnCircle = { x = 10500, z = 4700, r = 700 }, unitNames = { ["critter_gull"] = rnd(2, 3) } },	-- madagascar
		{ spawnCircle = { x = 14000, z = 2400, r = 700 }, unitNames = { ["critter_gull"] = rnd(2, 3) } },	-- south korea
		{ spawnCircle = { x = 14000, z = 2400, r = 700 }, unitNames = { ["critter_gull"] = rnd(2, 3) } },	-- south korea
		{ spawnCircle = { x = 10400, z = 3500, r = 700 }, unitNames = { ["critter_gull"] = rnd(2, 3) } },	-- gulf
		{ spawnCircle = { x = 16000, z = 6000, r = 700 }, unitNames = { ["critter_gull"] = rnd(2, 3) } },	-- new zealand

	},

}

return critterConfig
