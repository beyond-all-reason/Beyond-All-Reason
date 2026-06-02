local function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

local unloadsize1 = {
		buildangle = 4096,
		buildpic = "ARMFUS.DDS",
		buildtime = 54000,
		canrepeat = false,
		collisionvolumeoffsets = "0 0 -2",
		collisionvolumescales = "91 57 59",
		collisionvolumetype = "Box",
		corpse = "DEAD",
		energycost = 18000,
		energymake = 750,
		energystorage = 2500,
		explodeas = "fusionExplosion",
		footprintx = 2,
		footprintz = 2,
		health = 3800,
		hidedamage = true,
		maxacc = 0,
		maxdec = 0,
		maxslope = 25,
		maxwaterdepth = 12,
		metalcost = 3350,
		objectname = "units/transportpads/unloadsize2.s3o",
		script = "Units/ARMFUS.cob",
		seismicsignature = 0,
		selfdestructas = "fusionExplosionSelfd",
		sightdistance = 273,
		yardmap = "oo oo",
		customparams = {
			buildinggrounddecaldecayspeed = 30,
			buildinggrounddecalsizex = 8,
			buildinggrounddecalsizey = 8,
			buildinggrounddecaltype = "decals/armfus_aoplane.dds",
			model_author = "Cremuss",
			normaltex = "unittextures/Arm_normal.dds",
			removestop = true,
			removewait = true,
			subfolder = "ArmBuildings/LandEconomy",
			techlevel = 2,
			unitgroup = "energy",
			restrictions_inclusion = "_nofusion_",
			usebuildinggrounddecal = true,
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "0.420112609863 0.0956184448242 -0.353080749512",
				collisionvolumescales = "98.7820892334 38.6634368896 65.8547515869",
				collisionvolumetype = "Box",
				damage = 2700,
				featuredead = "HEAP",
				footprintx = 5,
				footprintz = 4,
				height = 40,
				metal = 2603,
				object = "units/transportpads/unloadsize2.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				collisionvolumescales = "85.0 14.0 6.0",
				collisionvolumetype = "cylY",
				damage = 1350,
				footprintx = 4,
				footprintz = 4,
				height = 4,
				metal = 1041,
				object = "Units/arm4X4A.s3o",
				reclaimable = true,
				resurrectable = 0,
			},
		},
		sounds = {
			canceldestruct = "cancel2",
			underattack = "warning1",
			count = {
				[1] = "count6",
				[2] = "count5",
				[3] = "count4",
				[4] = "count3",
				[5] = "count2",
				[6] = "count1",
			},
			select = {
				[1] = "fusion1",
			},
		},
	}

	local unloadsize2 = deepcopy(unloadsize1)
	unloadsize2.footprintx = 3
	unloadsize2.footprintz = 3
	unloadsize2.yardmap = "ooo ooo ooo"
	unloadsize2.objectname = "units/transportpads/unloadsize2.s3o"
	local unloadsize4 = deepcopy(unloadsize1)
	unloadsize4.footprintx = 4
	unloadsize4.footprintz = 4
	unloadsize4.yardmap = "oooo oooo oooo oooo"
	unloadsize4.objectname = "units/transportpads/unloadsize4.s3o"
	local unloadsize6 = deepcopy(unloadsize1)
	unloadsize6.footprintx = 6
	unloadsize6.footprintz = 6
	unloadsize6.yardmap = "oooooo oooooo oooooo oooooo oooooo oooooo"
	unloadsize6.objectname = "units/transportpads/unloadsize6.s3o"
	local unloadsize8 = deepcopy(unloadsize1)
	unloadsize8.footprintx = 8
	unloadsize8.footprintz = 8
	unloadsize8.yardmap = "oooooooo oooooooo oooooooo oooooooo oooooooo oooooooo oooooooo oooooooo"
	unloadsize8.objectname = "units/transportpads/unloadsize8.s3o"

-- amphib variants: float on water surface (hover and amphib units are dropped at y=0 and sink/float naturally)
local unloadsize1_amphib = deepcopy(unloadsize1)
unloadsize1_amphib.maxwaterdepth = 10000
unloadsize1_amphib.floater = true
local unloadsize2_amphib = deepcopy(unloadsize2)
unloadsize2_amphib.maxwaterdepth = 10000
unloadsize2_amphib.floater = true
local unloadsize4_amphib = deepcopy(unloadsize4)
unloadsize4_amphib.maxwaterdepth = 10000
unloadsize4_amphib.floater = true
local unloadsize6_amphib = deepcopy(unloadsize6)
unloadsize6_amphib.maxwaterdepth = 10000
unloadsize6_amphib.floater = true
local unloadsize8_amphib = deepcopy(unloadsize8)
unloadsize8_amphib.maxwaterdepth = 10000
unloadsize8_amphib.floater = true

return {
	unloadsize1 = unloadsize1,
	unloadsize2 = unloadsize2,
	unloadsize4 = unloadsize4,
	unloadsize6 = unloadsize6,
	unloadsize8 = unloadsize8,
	unloadsize1_amphib = unloadsize1_amphib,
	unloadsize2_amphib = unloadsize2_amphib,
	unloadsize4_amphib = unloadsize4_amphib,
	unloadsize6_amphib = unloadsize6_amphib,
	unloadsize8_amphib = unloadsize8_amphib,
}

