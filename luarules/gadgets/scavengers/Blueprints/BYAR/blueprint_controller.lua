local blueprintConfig = VFS.Include('luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
local tiers = blueprintConfig.Tiers
local types = blueprintConfig.BlueprintTypes

local blueprintTypes = {
	Constructor = 1,
	Spawner     = 2,
	Ruin        = 3,
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

local ruinBlueprints = {
	[types.Land] = { },
	[types.Sea] = { },
}


local blueprintsConfig = {
	[blueprintTypes.Constructor] = { table = constructorBlueprints, tiered = true,  directory = 'luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/Blueprints/', },
	[blueprintTypes.Spawner] =     { table = spawnerBlueprints,     tiered = true,  directory = 'luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/Blueprints/', },
	[blueprintTypes.Ruin] =        { table = ruinBlueprints,        tiered = false, directory = 'luarules/gadgets/scavengers/Ruins/' .. Game.gameShortName .. '/', }
}

local function insertDummyBlueprints(blueprintType)
	local blueprintTable = blueprintsConfig[blueprintType].table

	for _, type in pairs(types) do
		if blueprintsConfig[blueprintType].tiered then
			for _, tier in pairs(tiers) do
				if #blueprintTable[type][tier] == 0 then
					table.insert(blueprintTable[type][tier], dummyBlueprint)
				end
			end
		else
			if #blueprintTable[type] == 0 then
				table.insert(blueprintTable[type], dummyBlueprint)
			end
		end
	end
end

local function populateBlueprints(blueprintType)
	local blueprintsDirectory = VFS.DirList(blueprintsConfig[blueprintType].directory, '*.lua')
	local blueprintTable = blueprintsConfig[blueprintType].table

	for _, blueprintFile in ipairs(blueprintsDirectory) do
		local fileContents = VFS.Include(blueprintFile)

		for _, blueprintFunction in ipairs(fileContents) do
			local blueprint = blueprintFunction()

			if blueprintsConfig[blueprintType].tiered then
				for _, tier in ipairs(blueprint.tiers) do
					table.insert(blueprintTable[blueprint.type][tier], blueprintFunction)
				end
			else
				table.insert(blueprintTable[blueprint.type], blueprintFunction)
			end
		end

		--Spring.Echo("[Scavengers] Loading blueprint file: " .. blueprintFile)
	end

	insertDummyBlueprints(blueprintType)
end

populateBlueprints(blueprintTypes.Constructor)
populateBlueprints(blueprintTypes.Spawner)
populateBlueprints(blueprintTypes.Ruin)

local getRandomBluePrint = function(blueprintType, tier, type)
	local blueprintTable = blueprintsConfig[blueprintType].table
	local blueprintList, blueprintFunction, blueprint

	if tier ~= nil then
		blueprintList = blueprintTable[type][tier]
	else
		blueprintList = blueprintTable[type]
	end

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

local getRandomLandRuin = function()
	return getRandomBluePrint(blueprintTypes.Ruin, nil, types.Land)
end

local getRandomSeaRuin = function()
	return getRandomBluePrint(blueprintTypes.Ruin, nil, types.Sea)
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
	Ruin = {
		GetRandomLandBlueprint = getRandomLandRuin,
		GetRandomSeaBlueprint = getRandomSeaRuin,
	},
}
