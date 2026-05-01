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

local unloadpad2x2 = {
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
		objectname = "Units/ARMFUS.s3o",
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
				object = "Units/armfus_dead.s3o",
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

	local unloadpad4x4 = deepcopy(unloadpad2x2)
	unloadpad4x4.footprintx = 4
	unloadpad4x4.footprintz = 4
	unloadpad4x4.yardmap = "oooo oooo oooo oooo"

	local unloadpad8x8 = deepcopy(unloadpad2x2)
	unloadpad8x8.footprintx = 8
	unloadpad8x8.footprintz = 8
	unloadpad8x8.yardmap = "oooooooo oooooooo oooooooo oooooooo oooooooo oooooooo oooooooo oooooooo"
	unloadpad8x8.objectname = "units/unloadpad8x8.s3o"

return {
	unloadpad2x2 = unloadpad2x2,
	unloadpad4x4 = unloadpad4x4,
	unloadpad8x8 = unloadpad8x8,
}

