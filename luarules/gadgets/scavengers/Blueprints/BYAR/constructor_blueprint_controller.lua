local scavConfig = VFS.Include('luarules/gadgets/scavengers/Configs/BYAR/config.lua')
local tiers = scavConfig.Tiers
local types = scavConfig.BlueprintTypes

local blueprintTypes = {
	Constructor = 1,
	Spawner = 2,
}

local dummyBlueprint = function()
	return {
		type = types.Land,
		tiers = { },
		radius = 0,
		buildings = { }
	}
end

local constructorBlueprints = {
	[types.Land] = {
		[tiers.T0] = { },
		[tiers.T1] = { },
		[tiers.T2] = { },
		[tiers.T3] = { },
		[tiers.T4] = { },
	},

	[types.Sea] = {
		[tiers.T0] = { },
		[tiers.T1] = { },
		[tiers.T2] = { },
		[tiers.T3] = { },
		[tiers.T4] = { },
	},
}

local spawnerBlueprints = {
	[types.Land] = {
		[tiers.T0] = { },
		[tiers.T1] = { },
		[tiers.T2] = { },
		[tiers.T3] = { },
		[tiers.T4] = { },
	},

	[types.Sea] = {
		[tiers.T0] = { },
		[tiers.T1] = { },
		[tiers.T2] = { },
		[tiers.T3] = { },
		[tiers.T4] = { },
	},
}


local blueprintsConfig = {
	[blueprintTypes.Constructor] = { directory = 'luarules/gadgets/scavengers/Blueprints/BYAR/Constructor/', table = constructorBlueprints },
	[blueprintTypes.Spawner] = { directory = 'luarules/gadgets/scavengers/Blueprints/BYAR/Spawner/', table = spawnerBlueprints },
}

local function populateBlueprints(blueprintType)
	local blueprintsDirectory = VFS.DirList(blueprintsConfig[blueprintType].directory, '*.lua')
	local blueprintTable = blueprintsConfig[blueprintType].table
	for _, blueprintFile in ipairs(blueprintsDirectory) do
		local fileContents = VFS.Include(blueprintFile)
		for _, blueprintFunction in ipairs(fileContents) do
			local blueprint = blueprintFunction()
			for _, tier in ipairs(blueprint.tiers) do
				table.insert(blueprintTable[blueprint.type][tier], blueprintFunction)
			end
		end

		Spring.Echo("[Scavengers] Loading blueprint file: " .. blueprintFile)
	end

	for _, type in pairs(types) do
		for _, tier in pairs(tiers) do
			if #blueprintTable[type][tier] == 0 then
				table.insert(blueprintTable[type][tier], dummyBlueprint)
			end
		end
	end
end

populateBlueprints(blueprintTypes.Constructor)
populateBlueprints(blueprintTypes.Spawner)

local getRandomBluePrint = function(blueprintType, tier, type)
	local blueprintTable = blueprintsConfig[blueprintType].table
	local blueprintList, blueprintFunction, blueprint

	blueprintList = blueprintTable[type][tier]
	blueprintFunction = blueprintList[math.random(1, #blueprintList)]
	blueprint = blueprintFunction()

	return blueprint
end

local getRandomConstructorLandBlueprint = function(tier)
	return getRandomBluePrint(blueprintTypes.Constructor, tier, types.Land)
end

local getRandomConstructorSeaBlueprint = function(tier)
	return getRandomBluePrint(blueprintTypes.Constructor, tier, types.Sea)
end

local getRandomSpawnerLandBlueprint = function(tier)
	return getRandomBluePrint(blueprintTypes.Spawner, tier, types.Land)
end

local getRandomSpawnerSeaBlueprint = function(tier)
	return getRandomBluePrint(blueprintTypes.Spawner, tier, types.Sea)
end

return {
	Constructor = {
		GetRandomLandBlueprint = getRandomConstructorLandBlueprint,
		GetRandomSeaBlueprint = getRandomConstructorSeaBlueprint,
	},
	Spawner = {
		GetRandomLandBlueprint = getRandomSpawnerLandBlueprint,
		GetRandomSeaBlueprint = getRandomSpawnerSeaBlueprint,
	},
}