local blueprintConfig = VFS.Include('luarules/gadgets/ruins/Blueprints/' .. Game.gameShortName .. '/blueprint_tiers.lua')
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


local blueprintsConfig = {
	[1] = { table = constructorBlueprints, tiered = true,  directory = 'luarules/gadgets/ruins/Blueprints/' .. Game.gameShortName .. '/Blueprints/', },
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
	local blueprintsDirectory = VFS.DirList(blueprintsConfig[1].directory, '*.lua')
	local blueprintTable = blueprintsConfig[1].table

	for _, blueprintFile in ipairs(blueprintsDirectory) do
		local fileContents = VFS.Include(blueprintFile)

		for _, blueprintFunction in ipairs(fileContents) do
			local blueprint = blueprintFunction()

			if blueprintsConfig[1].tiered then
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

populateBlueprints(1)

local getRandomBluePrint = function(blueprintType, tier, type)
	local blueprintTable = blueprintsConfig[1].table
	local blueprintList, blueprintFunction, blueprint

	blueprintList = blueprintTable[type][tier]

	blueprintFunction = blueprintList[math.random(1, #blueprintList)]
	blueprint = blueprintFunction()

	return blueprint
end

local getRandomConstructorLandBlueprint = function(tier)
	return getRandomBluePrint(1, tier, types.Land)
end

local getRandomConstructorSeaBlueprint = function(tier)
	return getRandomBluePrint(1, tier, types.Sea)
end

return {
	GetRandomLandBlueprint = getRandomConstructorLandBlueprint,
	GetRandomSeaBlueprint = getRandomConstructorSeaBlueprint,
}
