local scavConfig = VFS.Include('luarules/gadgets/scavengers/Configs/BYAR/config.lua')
local tiers = scavConfig.Tiers
local types = scavConfig.BlueprintTypes

local dummyBlueprint = function()
	return {
		type = types.Land,
		tiers = { },
		radius = 0,
		buildings = { }
	}
end

local blueprints = {
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

-- local blueprintsDirectory = VFS.DirList('luarules/gadgets/scavengers/Blueprints/' .. Game.gameShortName .. '/Constructor/','*.lua')
local blueprintsDirectory = {
	'luarules/gadgets/scavengers/Blueprints/BYAR/Constructor/damgam_bases.lua',
	'luarules/gadgets/scavengers/Blueprints/BYAR/Constructor/Damgam_Basic_Sea.lua',
	'luarules/gadgets/scavengers/Blueprints/BYAR/Constructor/damgam_ecoStuff.lua',
}
for _, blueprintFile in ipairs(blueprintsDirectory) do
	local fileContents = VFS.Include(blueprintFile)
	for _, blueprintFunction in ipairs(fileContents) do
		local blueprint = blueprintFunction()
		for _, tier in ipairs(blueprint.tiers) do
			table.insert(blueprints[blueprint.type][tier], blueprintFunction)
		end
	end

	Spring.Echo("[Scavengers] Loading constructor blueprint file: " .. blueprintFile)
end

for _, blueprintType in pairs(types) do
	for _, tier in pairs(tiers) do
		if #blueprints[blueprintType][tier] == 0 then
			table.insert(blueprints[blueprintType][tier], dummyBlueprint)
		end
	end
end

local getRandomBluePrint = function(tier, type)
	local blueprintList, blueprintFunction, blueprint

	if type == types.Land then
		blueprintList = blueprints[types.Land][tier]
	elseif type == types.Sea then
		blueprintList = blueprints[types.Sea][tier]
	end

	blueprintFunction = blueprintList[math.random(1, #blueprintList)]
	blueprint = blueprintFunction()

	return blueprint
end

local getRandomLandBlueprint = function(tier)
	return getRandomBluePrint(tier, types.Land)
end

local getRandomSeaBlueprint = function(tier)
	return getRandomBluePrint(tier, types.Sea)
end

return {
	GetRandomLandBlueprint = getRandomLandBlueprint,
	GetRandomSeaBlueprint = getRandomSeaBlueprint,
}