local landBases = VFS.Include('luarules/gadgets/scavengers/Blueprints/BYAR/Constructor/damgam_bases.lua')

local tiers = {
	T0 = 0,
	T1 = 1,
	T2 = 2,
	T3 = 3,
	T4 = 4,
}

local blueprintTypes = {
	Land = 1,
	Sea = 2,
}

local landBlueprintLists = {
	[tiers.T0] = {
		landBases.RedBase2,--for testing, remove
	},

	[tiers.T1] = {
		landBases.RedBase2,
		landBases.BlueBase2,
	},

	[tiers.T2] = {
		landBases.RedBase1,
		landBases.RedBase2,
		landBases.BlueBase1,
		landBases.BlueBase2,
	},

	[tiers.T3] = {
		landBases.RedBase1,
		landBases.RedBase2,
		landBases.BlueBase1,
		landBases.BlueBase2,
	},

	[tiers.T4] = {
		landBases.RedBase2, --for testing, remove
	},
}

local seaBlueprintLists = {
	[tiers.T0] = {
	},

	[tiers.T1] = {
	},

	[tiers.T2] = {
	},

	[tiers.T3] = {
	},

	[tiers.T4] = {
	},
}

local getRandomBluePrint = function(tier, type)
	local blueprintList, blueprintFunction, blueprint

	if type == blueprintTypes.Land then
		blueprintList = landBlueprintLists[tier]
	elseif type == blueprintTypes.Sea then
		blueprintList = seaBlueprintLists[tier]
	end

	blueprintFunction = blueprintList[math.random(1, #blueprintList)]
	blueprint = blueprintFunction()

	return blueprint
end

local getRandomLandBlueprint = function(tier)
	return getRandomBluePrint(tier, blueprintTypes.Land)
end

local getRandomSeaBlueprint = function(tier)
	return getRandomBluePrint(tier, blueprintTypes.Sea)
end

return {
	Tiers = tiers,
	GetRandomLandBlueprint = getRandomLandBlueprint,
	GetRandomSeaBlueprint = getRandomSeaBlueprint,
}