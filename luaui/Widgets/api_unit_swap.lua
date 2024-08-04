function widget:GetInfo()
	return {
		name = "Unit Swap API",
		desc = "-",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true
	}
end

---Creates a simple enum-like table, where for each entry, the key and value are the same. This allows syntax like
---ENUM.OPTION_ONE, while also having the value "OPTION_ONE" for serialization or printing.
---@param ... table a list of entries for the enum
---@return table
local function enum(...)
	local args = { ... }
	local result = {}
	for _, v in ipairs(args) do
		result[v] = v
	end
	return result
end

local factions = enum("arm", "cor", "leg")
local terrains = enum("ground", "water")

local function isFactionEnabled(faction)
	if faction == factions.leg then
		return Spring.GetModOptions().experimentallegionfaction or false
	else
		return true
	end
end

local factionSwapNames = {
	-- economy
	{ [factions.arm] = "armmstor", [factions.cor] = "cormstor", [factions.leg] = "legmstor" },
	{ [factions.arm] = "armestor", [factions.cor] = "corestor", [factions.leg] = "corestor" },

	{ [factions.arm] = "armmakr", [factions.cor] = "cormakr", [factions.leg] = "legeconv" },
	--todo: geo

	{ [factions.arm] = "armmex", [factions.cor] = "cormex", [factions.leg] = "legmex" },
	{ [factions.arm] = "armsolar", [factions.cor] = "corsolar", [factions.leg] = "legsolar" },
	{ [factions.arm] = "armwin", [factions.cor] = "corwin", [factions.leg] = "legwin" },
	{ [factions.arm] = "armadvsol", [factions.cor] = "coradvsol", [factions.leg] = "legadvsol" },

	{ [factions.arm] = "armuwes", [factions.cor] = "coruwes", [factions.leg] = "coruwes" },
	{ [factions.arm] = "armuwms", [factions.cor] = "coruwms", [factions.leg] = "coruwms" },

	{ [factions.arm] = "armfmkr", [factions.cor] = "corfmkr", [factions.leg] = "corfmkr" },

	{ [factions.arm] = "armtide", [factions.cor] = "cortide", [factions.leg] = "legtide" },

	-- combat
	{ [factions.arm] = "armdl", [factions.cor] = "cordl", [factions.leg] = "cordl" },
	{ [factions.arm] = "armguard", [factions.cor] = "corpun", [factions.leg] = "legcluster" },
	{ [factions.arm] = "armfhlt", [factions.cor] = "corfhlt", [factions.leg] = "corfhlt" },

	{ [factions.arm] = "armrl", [factions.cor] = "corrl", [factions.leg] = "legrl" },
	{ [factions.arm] = "armferret", [factions.cor] = "cormadsam", [factions.leg] = "legrhapsis" },
	{ [factions.arm] = "armcir", [factions.cor] = "corerad", [factions.leg] = "leglupara" },
	{ [factions.arm] = "armfrt", [factions.cor] = "corfrt", [factions.leg] = "corfrt" },

	{ [factions.arm] = "armllt", [factions.cor] = "corllt", [factions.leg] = "leglht" },
	{ [factions.arm] = "armbeamer", [factions.cor] = "corhllt" },
	{ [factions.arm] = "armhlt", [factions.cor] = "corhlt", [factions.leg] = "legmg" },
	{ [factions.arm] = "armclaw", [factions.cor] = "cormaw", [factions.leg] = "legdtr" },
	{ [factions.arm] = "armtl", [factions.cor] = "cortl", [factions.leg] = "cortl" },

	-- utility
	{ [factions.arm] = "armjuno", [factions.cor] = "corjuno", [factions.leg] = "corjuno" },

	{ [factions.arm] = "armasp", [factions.cor] = "corasp", [factions.leg] = "corasp" },
	{ [factions.arm] = "armfrad", [factions.cor] = "corfrad", [factions.leg] = "corfrad" },
	{ [factions.arm] = "armfdrag", [factions.cor] = "corfdrag", [factions.leg] = "corfdrag" },

	{ [factions.arm] = "armrad", [factions.cor] = "corrad", [factions.leg] = "legrad" },
	{ [factions.arm] = "armeyes", [factions.cor] = "coreyes", [factions.leg] = "coreyes" },
	{ [factions.arm] = "armdrag", [factions.cor] = "cordrag", [factions.leg] = "legdrag" },
	{ [factions.arm] = "armjamt", [factions.cor] = "corjamt", [factions.leg] = "legjam" },

	-- build
	{ [factions.arm] = "armhp", [factions.cor] = "corhp", [factions.leg] = "leghp" },
	{ [factions.arm] = "armfhp", [factions.cor] = "corfhp", [factions.leg] = "legfhp" },

	{ [factions.arm] = "armnanotc", [factions.cor] = "cornanotc", [factions.leg] = "cornanotc" },

	{ [factions.arm] = "armlab", [factions.cor] = "corlab", [factions.leg] = "leglab" },
	{ [factions.arm] = "armvp", [factions.cor] = "corvp", [factions.leg] = "legvp" },
	{ [factions.arm] = "armap", [factions.cor] = "corap", [factions.leg] = "legap" },
	{ [factions.arm] = "armsy", [factions.cor] = "corsy", [factions.leg] = "corsy" },

	{ [factions.arm] = "armamsub", [factions.cor] = "coramsub", [factions.leg] = "coramsub" },
	{ [factions.arm] = "armplat", [factions.cor] = "corplat", [factions.leg] = "corplat" },

	{ [factions.arm] = "armalab", [factions.cor] = "coralab", [factions.leg] = "legalab" },
	{ [factions.arm] = "armavp", [factions.cor] = "coravp", [factions.leg] = "legavp" },
	{ [factions.arm] = "armaap", [factions.cor] = "coraap", [factions.leg] = "legaap" },
	{ [factions.arm] = "armasy", [factions.cor] = "corasy", [factions.leg] = "corasy" },

	-- extra

	{ [factions.arm] = "armsonar", [factions.cor] = "corsonar" },
	{ [factions.arm] = "armptl", [factions.cor] = "corptl", [factions.leg] = "legptl" },

}

local terrainSwapNames = {
	{ [terrains.ground] = "armmakr", [terrains.water] = "armfmkr" },
	{ [terrains.ground] = "cormakr", [terrains.water] = "corfmkr" },
	{ [terrains.ground] = "armdrag", [terrains.water] = "armfdrag" },
	{ [terrains.ground] = "cordrag", [terrains.water] = "corfdrag" },
	{ [terrains.ground] = "armmstor", [terrains.water] = "armuwms" },
	{ [terrains.ground] = "armestor", [terrains.water] = "armuwes" },
	{ [terrains.ground] = "cormstor", [terrains.water] = "coruwms" },
	{ [terrains.ground] = "corestor", [terrains.water] = "coruwes" },
	{ [terrains.ground] = "armrl", [terrains.water] = "armfrt" },
	{ [terrains.ground] = "corrl", [terrains.water] = "corfrt" },
	{ [terrains.ground] = "armhp", [terrains.water] = "armfhp" },
	{ [terrains.ground] = "corhp", [terrains.water] = "corfhp" },
	{ [terrains.ground] = "armrad", [terrains.water] = "armfrad" },
	{ [terrains.ground] = "corrad", [terrains.water] = "corfrad" },
	{ [terrains.ground] = "armhlt", [terrains.water] = "armfhlt" },
	{ [terrains.ground] = "corhlt", [terrains.water] = "corfhlt" },
	{ [terrains.ground] = "armtarg", [terrains.water] = "armfatf" },
	{ [terrains.ground] = "cortarg", [terrains.water] = "corfatf" },
	{ [terrains.ground] = "armmmkr", [terrains.water] = "armuwmmm" },
	{ [terrains.ground] = "cormmkr", [terrains.water] = "coruwmmm" },
	{ [terrains.ground] = "armfus", [terrains.water] = "armuwfus" },
	{ [terrains.ground] = "corfus", [terrains.water] = "coruwfus" },
	{ [terrains.ground] = "armflak", [terrains.water] = "armfflak" },
	{ [terrains.ground] = "corflak", [terrains.water] = "corenaa" },
	{ [terrains.ground] = "armmoho", [terrains.water] = "armuwmme" },
	{ [terrains.ground] = "cormoho", [terrains.water] = "coruwmme" },
	{ [terrains.ground] = "armsolar", [terrains.water] = "armtide" },
	{ [terrains.ground] = "corsolar", [terrains.water] = "cortide" },
	{ [terrains.ground] = "armlab", [terrains.water] = "armsy" },
	{ [terrains.ground] = "corlab", [terrains.water] = "corsy" },
	{ [terrains.ground] = "armllt", [terrains.water] = "armtl" },
	{ [terrains.ground] = "corllt", [terrains.water] = "cortl" },
	{ [terrains.ground] = "armnanotc", [terrains.water] = "armnanotcplat" },
	{ [terrains.ground] = "cornanotc", [terrains.water] = "cornanotcplat" },
	{ [terrains.ground] = "armvp", [terrains.water] = "armamsub" },
	{ [terrains.ground] = "corvp", [terrains.water] = "coramsub" },
	{ [terrains.ground] = "armap", [terrains.water] = "armplat" },
	{ [terrains.ground] = "corap", [terrains.water] = "corplat" },
	{ [terrains.ground] = "armasp", [terrains.water] = "armfasp" },
	{ [terrains.ground] = "corasp", [terrains.water] = "corfasp" },
	{ [terrains.ground] = "armgeo", [terrains.water] = "armuwgeo" },
	{ [terrains.ground] = "armageo", [terrains.water] = "armuwageo" },
	{ [terrains.ground] = "corgeo", [terrains.water] = "coruwgeo" },
	{ [terrains.ground] = "corageo", [terrains.water] = "coruwageo" },
	--{ [terrains.ground] = "armllt", [terrains.water] = "armptl" },
	--{ [terrains.ground] = "corllt", [terrains.water] = "corptl" },
	{ [terrains.ground] = "leghp", [terrains.water] = "legfhp" },
	{ [terrains.ground] = "leglht", [terrains.water] = "legtl" },
	{ [terrains.ground] = "leghive", [terrains.water] = "legfhive" },
	{ [terrains.ground] = "legvp", [terrains.water] = "legamsub" },
}

local factionBuildableUnits = {}

local factionSwapIDs = {}
local terrainSwapIDs = {}

local factionSwapMap = {}
local terrainSwapMap = {}

local function traverseBuildOptions(unitDefID, visited)
	visited = visited or {}

	for _, buildUnitDefID in ipairs(UnitDefs[unitDefID].buildOptions) do
		if not visited[buildUnitDefID] then
			visited[buildUnitDefID] = true
			traverseBuildOptions(buildUnitDefID, visited)
		end
	end

	return visited
end

local function initializeFactionUnits()
	local startUnits = {
		[factions.cor] = UnitDefNames.corcom.id,
		[factions.arm] = UnitDefNames.armcom.id,
	}
	if isFactionEnabled(factions.leg) then
		startUnits[factions.leg] = UnitDefNames.legcom.id
	end

	for faction, startUnitDefID in pairs(startUnits) do
		factionBuildableUnits[faction] = traverseBuildOptions(startUnitDefID)
	end
end

local function initializeFactionSwapIDs()
	factionSwapIDs = table.map(factionSwapNames, function(group)
		return table.map(group, function(unitDefName, faction)
			if not isFactionEnabled(faction) then
				return nil
			end

			local unitDef = UnitDefNames[unitDefName]
			if unitDef then
				return unitDef.id
			else
				Spring.Echo("Could not find unit for faction swap: " .. unitDefName)
				return nil
			end
		end)
	end)
end

local function initializeTerrainSwapIDs()
	terrainSwapIDs = table.map(terrainSwapNames, function(group)
		return table.map(group, function(unitDefName)
			local unitDef = UnitDefNames[unitDefName]
			if unitDef then
				return unitDef.id
			else
				Spring.Echo("Could not find unit for terrain swap: " .. unitDefName)
			end
		end)
	end)
end

local function initializeFactionSwapMap()
	for groupIndex, group in ipairs(factionSwapIDs) do
		for _, unitDefID in pairs(group) do
			if factionSwapMap[unitDefID] ~= nil and factionSwapMap[unitDefID] ~= group then
				Spring.Echo("Faction swap collision detected: " .. UnitDefs[unitDefID].name .. " " .. table.toString(factionSwapNames[groupIndex]))
				Spring.Echo("--old group", table.toString(factionSwapMap[unitDefID]))
				Spring.Echo("--new group", table.toString(group))
			end
			factionSwapMap[unitDefID] = group
		end
	end
end

local function initializeTerrainSwapMap()
	for groupIndex, group in ipairs(terrainSwapIDs) do
		for _, unitDefID in pairs(group) do
			if terrainSwapMap[unitDefID] ~= nil and terrainSwapMap[unitDefID] ~= group then
				Spring.Echo("Terrain swap collision detected: " .. UnitDefs[unitDefID].name .. " " .. table.toString(terrainSwapNames[groupIndex]))
				Spring.Echo("--old group", table.toString(terrainSwapMap[unitDefID]))
				Spring.Echo("--new group", table.toString(group))
			end
			terrainSwapMap[unitDefID] = group
		end
	end
end

-- API

local function swapFaction(unitDefID, faction)
	local group = factionSwapMap[unitDefID]
	if group ~= nil then
		return group[faction]
	end
end

local function swapTerrain(unitDefID, terrain)
	local group = terrainSwapMap[unitDefID]
	if group ~= nil then
		return group[terrain]
	end
end

local function isUnitBuildableByFaction(unitDefID, faction)
	return factionBuildableUnits[faction] and factionBuildableUnits[faction][unitDefID] ~= nil
end

local function getEnabledFactions()
	local result = {}
	for faction in pairs(factions) do
		if isFactionEnabled(faction) then
			result[faction] = faction
		end
	end
	return result
end

function widget:Initialize()
	initializeFactionUnits()

	initializeFactionSwapIDs()
	initializeTerrainSwapIDs()

	initializeFactionSwapMap()
	initializeTerrainSwapMap()

	WG["api_unit_swap"] = {
		factions = factions,
		terrains = terrains,
		swapFaction = swapFaction,
		swapTerrain = swapTerrain,
		isUnitBuildableByFaction = isUnitBuildableByFaction,
		getEnabledFactions = getEnabledFactions,
	}
end

function widget:Shutdown()
	WG["api_unit_swap"] = nil
end
