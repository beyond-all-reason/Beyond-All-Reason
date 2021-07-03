local landBases = VFS.Include('luarules/gadgets/scavengers/Blueprints/BYAR/Constructor/damgam_bases.lua')
local basicSeaBases = VFS.Include('luarules/gadgets/scavengers/Blueprints/BYAR/Constructor/Damgam_Basic_Sea.lua')
local landEco = VFS.Include('luarules/gadgets/scavengers/Blueprints/BYAR/Constructor/damgam_ecoStuff.lua')

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
	},
}

local seaBlueprintLists = {
	[tiers.T0] = {
		basicSeaBases.T1SeaBase1,
		basicSeaBases.T2SeaBase2,
		basicSeaBases.T3SeaBase3,
		basicSeaBases.T1SeaBase4,
		basicSeaBases.T1SeaBase5,
		basicSeaBases.T1seaBase6,
		basicSeaBases.T1SeaBase7,
		basicSeaBases.T1SeaBase8,
	},

	[tiers.T1] = {
		basicSeaBases.T1SeaBase1,
		basicSeaBases.T2SeaBase2,
		basicSeaBases.T3SeaBase3,
		basicSeaBases.T1SeaBase4,
		basicSeaBases.T1SeaBase5,
		basicSeaBases.T1seaBase6,
		basicSeaBases.T1SeaBase7,
		basicSeaBases.T1SeaBase8,
		landEco.T1Energy1,
		landEco.T1Energy2,
		landEco.T1Energy3,
		landEco.T1Energy4,
		landEco.T1Energy5,
		landEco.T1Energy6,
		landEco.T2Wind1,
	},

	[tiers.T2] = {
		basicSeaBases.T1SeaBase1,
		basicSeaBases.T2SeaBase2,
		basicSeaBases.T3SeaBase3,
		basicSeaBases.T1SeaBase4,
		basicSeaBases.T1SeaBase5,
		basicSeaBases.T1seaBase6,
		basicSeaBases.T1SeaBase7,
		basicSeaBases.T1SeaBase8,
		basicSeaBases.T2SeaBase1,
		basicSeaBases.T2SeaBase2,
		basicSeaBases.T2SeaBase3,
		basicSeaBases.T2SeaBase4,
		basicSeaBases.T2SeaBase5,
		basicSeaBases.T2SeaFactory1,
		basicSeaBases.T2SeaFactory2,
		basicSeaBases.T2SeaFactory3,
		basicSeaBases.T2SeaFactory4,
		basicSeaBases.T2SeaFactory5,
		landEco.T2Energy1,
		landEco.T2Energy2,
		landEco.T2Energy3,
		landEco.T2Energy4,
		landEco.T2Wind1,
	},

	[tiers.T3] = {
		basicSeaBases.T1SeaBase1,
		basicSeaBases.T2SeaBase2,
		basicSeaBases.T3SeaBase3,
		basicSeaBases.T1SeaBase4,
		basicSeaBases.T1SeaBase5,
		basicSeaBases.T1seaBase6,
		basicSeaBases.T1SeaBase7,
		basicSeaBases.T1SeaBase8,
		basicSeaBases.T2SeaBase1,
		basicSeaBases.T2SeaBase2,
		basicSeaBases.T2SeaBase3,
		basicSeaBases.T2SeaBase4,
		basicSeaBases.T2SeaBase5,
		basicSeaBases.T2SeaFactory1,
		basicSeaBases.T2SeaFactory2,
		basicSeaBases.T2SeaFactory3,
		basicSeaBases.T2SeaFactory4,
		basicSeaBases.T2SeaFactory5,
		basicSeaBases.T3SeaFactory1,
		landEco.T2ResourcesBase1,
		landEco.T2ResourcesBase2,
		landEco.T2EnergyBase1,
		landEco.T2MetalBase1,
		landEco.T2ResourceBase3,
		landEco.T2EnergyBase2,
		landEco.T2Wind1,
	},

	[tiers.T4] = {
		basicSeaBases.T1SeaBase1,
		basicSeaBases.T2SeaBase2,
		basicSeaBases.T3SeaBase3,
		basicSeaBases.T1SeaBase4,
		basicSeaBases.T1SeaBase5,
		basicSeaBases.T1seaBase6,
		basicSeaBases.T1SeaBase7,
		basicSeaBases.T1SeaBase8,
		basicSeaBases.T2SeaBase1,
		basicSeaBases.T2SeaBase2,
		basicSeaBases.T2SeaBase3,
		basicSeaBases.T2SeaBase4,
		basicSeaBases.T2SeaBase5,
		basicSeaBases.T2SeaFactory1,
		basicSeaBases.T2SeaFactory2,
		basicSeaBases.T2SeaFactory3,
		basicSeaBases.T2SeaFactory4,
		basicSeaBases.T2SeaFactory5,
		basicSeaBases.T3SeaFactory1,
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