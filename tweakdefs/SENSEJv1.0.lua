-- SENSEJv1.0 - Competitive sensor normalization tweakdef for Beyond All Reason.
-- Paste a base64-encoded copy of this file into the `tweakdefs` modoption.

local function applyUnitChanges(unitName, changes)
	local unitDef = UnitDefs[unitName]
	if not unitDef then
		Spring.Echo("Sensor normalization tweakdef: missing UnitDef " .. unitName)
		return
	end

	for field, value in pairs(changes) do
		unitDef[field] = value
	end
end

-- T1 jammer towers: Armada baseline.
local t1JammerTower = {
	metalcost = 240,
	energycost = 8500,
	buildtime = 9950,
	radardistancejam = 500,
	energyupkeep = 40,
}

applyUnitChanges("armjamt", t1JammerTower)
applyUnitChanges("corjamt", t1JammerTower)
applyUnitChanges("legjam", t1JammerTower)

-- T2 radar bots: Cortex baseline.
local t2RadarBot = {
	metalcost = 99,
	energycost = 1350,
	buildtime = 5000,
	radardistance = 2200,
	speed = 45,
	health = 390,
	sightdistance = 925,
	maxacc = 0.05635,
	maxdec = 0.2,
	turnrate = 670.45001,
}

applyUnitChanges("armmark", t2RadarBot)
applyUnitChanges("corvoyr", t2RadarBot)
applyUnitChanges("legaradk", t2RadarBot)

-- T2 jammer bots: Armada baseline, with speed reduced to 40.5.
local t2JammerBot = {
	metalcost = 78,
	energycost = 1400,
	buildtime = 6000,
	radardistancejam = 450,
	energyupkeep = 80,
	speed = 40.5,
	health = 340,
	sightdistance = 380,
	maxacc = 0.138,
	maxdec = 0.5175,
	turnrate = 1201.75,
}

applyUnitChanges("armaser", t2JammerBot)
applyUnitChanges("corspec", t2JammerBot)
applyUnitChanges("legajamk", t2JammerBot)

-- T2 radar vehicles: Armada baseline, with Cortex speed (48).
local t2RadarVehicle = {
	metalcost = 125,
	energycost = 2000,
	buildtime = 7500,
	radardistance = 2300,
	speed = 48,
	health = 980,
	sightdistance = 900,
	maxacc = 0.04878,
	maxdec = 0.1,
	turnrate = 605,
}

applyUnitChanges("armseer", t2RadarVehicle)
applyUnitChanges("corvrad", t2RadarVehicle)
applyUnitChanges("legavrad", t2RadarVehicle)

-- T2 jammer vehicles: Cortex baseline, with speed increased to 48.
local t2JammerVehicle = {
	metalcost = 105,
	energycost = 1900,
	buildtime = 7500,
	radardistancejam = 450,
	energyupkeep = 80,
	speed = 48,
	health = 580,
	sightdistance = 330,
	maxacc = 0.03583,
	maxdec = 0.1,
	turnrate = 619.29999,
}

applyUnitChanges("armjam", t2JammerVehicle)
applyUnitChanges("coreter", t2JammerVehicle)
applyUnitChanges("legavjam", t2JammerVehicle)

-- T1 air scouts: Cortex Fink baseline, with health increased to 126.
local t1AirScout = {
	metalcost = 51,
	energycost = 1450,
	buildtime = 2400,
	radardistance = 1120,
	sightdistance = 835,
	speed = 360,
	health = 126,
	cruisealtitude = 110,
	maxacc = 0.1825,
	maxdec = 0.0125,
	maxaileron = 0.0144,
	maxbank = 0.8,
	maxelevator = 0.01065,
	maxpitch = 0.625,
	maxrudder = 0.00615,
	speedtofront = 0.06125,
	turnradius = 64,
	wingangle = 0.06315,
	wingdrag = 0.06,
}

applyUnitChanges("armpeep", t1AirScout)
applyUnitChanges("corfink", t1AirScout)

-- T2 radar/sonar planes: Cortex Condor baseline.
local t2AirScout = {
	metalcost = 180,
	energycost = 8300,
	buildtime = 16000,
	radardistance = 2400,
	sonardistance = 1200,
	sightdistance = 1250,
	speed = 321,
	health = 990,
	cruisealtitude = 110,
	maxacc = 0.1575,
	maxdec = 0.0375,
	maxaileron = 0.01366,
	maxbank = 0.8,
	maxelevator = 0.00991,
	maxpitch = 0.625,
	maxrudder = 0.00541,
	speedtofront = 0.06417,
	turnradius = 64,
	wingangle = 0.06241,
	wingdrag = 0.11,
}

applyUnitChanges("armawac", t2AirScout)
applyUnitChanges("corawac", t2AirScout)

-- T2 naval jammer ships: Armada Bermuda baseline.
-- Legion's hybrid radar/jammer ship is intentionally excluded.
local t2JammerShip = {
	metalcost = 310,
	energycost = 5000,
	buildtime = 20000,
	radardistancejam = 980,
	energyupkeep = 90,
	speed = 45,
	health = 1350,
	sightdistance = 390,
	maxacc = 0.04059,
	maxdec = 0.04059,
	turnrate = 405,
}

applyUnitChanges("armsjam", t2JammerShip)
applyUnitChanges("corsjam", t2JammerShip)

-- T1 floating radar/sonar towers: Armada baseline.
local t1FloatingRadar = {
	metalcost = 130,
	energycost = 1000,
	buildtime = 1800,
	radardistance = 2100,
	sonardistance = 900,
	health = 110,
	sightdistance = 760,
}

applyUnitChanges("armfrad", t1FloatingRadar)
applyUnitChanges("corfrad", t1FloatingRadar)
applyUnitChanges("legfrad", t1FloatingRadar)

-- T1 standalone sonar structures: Armada baseline.
local t1Sonar = {
	metalcost = 20,
	energycost = 450,
	buildtime = 910,
	sonardistance = 1200,
	health = 56,
	sightdistance = 515,
}

applyUnitChanges("armsonar", t1Sonar)
applyUnitChanges("corsonar", t1Sonar)

-- T2 land radar towers: Cortex baseline with manual cloak capability.
local t2RadarTower = {
	metalcost = 400,
	energycost = 14000,
	buildtime = 8000,
	radardistance = 3500,
	radaremitheight = 87,
	health = 500,
	sightdistance = 1000,
	cancloak = true,
	cloakcost = 50,
	cloakcostmoving = 50,
	mincloakdistance = 36,
}

applyUnitChanges("armarad", t2RadarTower)
applyUnitChanges("corarad", t2RadarTower)
applyUnitChanges("legarad", t2RadarTower)

-- T2 land jammer towers: Armada Veil baseline, normalized to a 2x2 footprint,
-- with the same manual cloak configuration as the T2 radar towers.
local t2JammerTower = {
	metalcost = 125,
	energycost = 19000,
	buildtime = 9100,
	radardistancejam = 760,
	energyupkeep = 125,
	health = 830,
	sightdistance = 155,
	footprintx = 2,
	footprintz = 2,
	yardmap = "oooo",
	cancloak = true,
	cloakcost = 50,
	cloakcostmoving = 50,
	mincloakdistance = 36,
}

applyUnitChanges("armveil", t2JammerTower)
applyUnitChanges("corshroud", t2JammerTower)
applyUnitChanges("legajam", t2JammerTower)

-- Juno structures and stockpiled missiles: reduced entry and operating costs.
local junoStructure = {
	metalcost = 500,
	energycost = 12000,
	buildtime = 20000,
}

local function applyJunoChanges(unitName)
	applyUnitChanges(unitName, junoStructure)

	local unitDef = UnitDefs[unitName]
	local weaponDef = unitDef and unitDef.weapondefs and unitDef.weapondefs.juno_pulse
	if not weaponDef then
		Spring.Echo("Sensor normalization tweakdef: missing Juno weapon for " .. unitName)
		return
	end

	weaponDef.metalpershot = 150
	weaponDef.energypershot = 8000
	weaponDef.stockpiletime = 75
	weaponDef.customparams = weaponDef.customparams or {}
	weaponDef.customparams.stockpilelimit = 5
end

applyJunoChanges("armjuno")
applyJunoChanges("corjuno")
applyJunoChanges("legjuno")

-- T2 advanced sonar towers: Cortex baseline, including 3x3 placement footprint.
local t2SonarTower = {
	metalcost = 160,
	energycost = 2400,
	buildtime = 6100,
	sonardistance = 1600,
	health = 2400,
	sightdistance = 210,
	footprintx = 3,
	footprintz = 3,
	yardmap = "ooooooooo",
	minwaterdepth = 24,
}

applyUnitChanges("armason", t2SonarTower)
applyUnitChanges("corason", t2SonarTower)
applyUnitChanges("leganavalsonarstation", t2SonarTower)

-- Cortex Forge combat engineer: load the existing extra unit when necessary,
-- add it to the T2 vehicle plant, and give it Dragon's Maw weapon behavior.
local function configureCorForge()
	if not UnitDefs.corforge then
		local loaded = VFS.Include("units/Scavengers/Vehicles/corforge.lua")
		if type(loaded) == "table" then
			UnitDefs.corforge = loaded.corforge
		end
	end

	local forge = UnitDefs.corforge
	local dragonMaw = UnitDefs.cormaw
	local vehiclePlant = UnitDefs.coravp
	if not forge or not dragonMaw or not vehiclePlant then
		Spring.Echo("Sensor normalization tweakdef: unable to configure corforge")
		return
	end

	local dragonMawWeapon = dragonMaw.weapondefs and dragonMaw.weapondefs.dmaw
	if not dragonMawWeapon then
		Spring.Echo("Sensor normalization tweakdef: Dragon's Maw weapon is missing")
		return
	end

	forge.weapondefs = forge.weapondefs or {}
	forge.weapons = forge.weapons or {}
	forge.weapondefs.flamethrower_ce = forge.weapondefs.flamethrower_ce or {}
	local forgeWeapon = forge.weapondefs.flamethrower_ce
	local combatFields = {
		"areaofeffect",
		"burst",
		"burstrate",
		"cegtag",
		"colormap",
		"edgeeffectiveness",
		"explosiongenerator",
		"firestarter",
		"flamegfxtime",
		"impulsefactor",
		"intensity",
		"proximitypriority",
		"range",
		"reloadtime",
		"rgbcolor",
		"rgbcolor2",
		"sizegrowth",
		"sprayangle",
		"targetmoveerror",
		"texture1",
		"tolerance",
		"weapontimer",
		"weaponvelocity",
	}
	for _, field in ipairs(combatFields) do
		forgeWeapon[field] = dragonMawWeapon[field]
	end
	forgeWeapon.range = 325
	forgeWeapon.damage = {
		commanders = 16.2,
		default = 10.8,
		subs = 2.7,
	}

	forge.weapons[1] = forge.weapons[1] or {}
	forge.weapons[1].def = "flamethrower_ce"
	forge.weapons[1].onlytargetcategory = "SURFACE"

	vehiclePlant.buildoptions = vehiclePlant.buildoptions or {}
	for _, unitName in ipairs(vehiclePlant.buildoptions) do
		if unitName == "corforge" then
			return
		end
	end
	table.insert(vehiclePlant.buildoptions, "corforge")
end

configureCorForge()
