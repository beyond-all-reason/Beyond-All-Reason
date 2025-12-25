local widget = widget ---@type Widget

function widget:GetInfo()
	return {
	name      = "Ruins Blueprint Generator",
	desc      = "Generates Lua blueprint code from selected units",
	author    = "Damgam",
	date      = "2020",
	license   = "GNU GPL, v2 or later",
	layer     = 0,
	enabled   = true,
	}
end


-- Localized functions for performance
local mathCeil = math.ceil
local tableInsert = table.insert

-- Localized Spring API for performance
local spGetSelectedUnits = Spring.GetSelectedUnits

local outputFile = "ruins_blueprints_temp.txt"
local blueprintCounter = 0

local types = {
	blueprint = 1,
}

local centerposx = {}
local centerposy = {}
local centerposz = {}
local blueprintposx = 0
local blueprintposz = 0
local blueprintCenterX, blueprintCenterY, blueprintCenterZ
local blueprintRadius = 0

local function getBlueprintCenter()
	local selectedunits = spGetSelectedUnits()

	for i = 1, #selectedunits do
		local unit = selectedunits[i]
		centerposx[unit], centerposy[unit], centerposz[unit] = Spring.GetUnitPosition(unit)
		blueprintposx = blueprintposx + centerposx[unit]
		blueprintposz = blueprintposz + centerposz[unit]
	end

	blueprintCenterX = blueprintposx / #selectedunits
	blueprintCenterZ = blueprintposz / #selectedunits
	blueprintCenterY = Spring.GetGroundHeight(blueprintCenterX, blueprintCenterZ)
end

local function clearValues()
	blueprintposx = 0
	blueprintposz = 0
	centerposx = {}
	centerposy = {}
	centerposz = {}
	blueprintRadius = 0
end

local unitOverrides = {
	-- Armada Walls
	["armdrag"] = "BPWallOrPopup('arm', 1, 'land')",
	["armclaw"] = "BPWallOrPopup('arm', 1, 'land')",
	["armfdrag"] = "BPWallOrPopup('arm', 1, 'sea')",
	["armfort"] = "BPWallOrPopup('arm', 2, 'land')",
	["armlwall"] = "BPWallOrPopup('arm', 2, 'land')",

	-- Cortex Walls
	["cordrag"] = "BPWallOrPopup('cor', 1, 'land')",
	["cormaw"] = "BPWallOrPopup('cor', 1, 'land')",
	["corfdrag"] = "BPWallOrPopup('cor', 1, 'sea')",
	["corfort"] = "BPWallOrPopup('cor', 2, 'land')",
	["cormwall"] = "BPWallOrPopup('cor', 2, 'land')",

	-- Legion Walls
	["legdrag"] = "BPWallOrPopup('leg', 1, 'land')",
	["legdtr"] = "BPWallOrPopup('leg', 1, 'land')",
	["legfdrag"] = "BPWallOrPopup('leg', 1, 'sea')",
	["legforti"] = "BPWallOrPopup('leg', 2, 'land')",
	["legrwall"] = "BPWallOrPopup('leg', 2, 'land')",

	-- Scavenger Walls
	["corscavdrag"] = "BPWallOrPopup('scav', 1, 'land')",
	["corscavdtf"] = "BPWallOrPopup('scav', 1, 'land')",
	["corscavdtl"] = "BPWallOrPopup('scav', 1, 'land')",
	["corscavdtm"] = "BPWallOrPopup('scav', 1, 'land')",
	["corscavfort"] = "BPWallOrPopup('scav', 1, 'land')",
}

local function generateCode(type)
	local selectedUnits = spGetSelectedUnits()

	getBlueprintCenter()

	local file = io.open(outputFile, "a")
	local blueprintName = "blueprint" .. blueprintCounter
	local blueprintType = blueprintCenterY > 0 and "Land" or "Sea"
	local buildings = {}

	for _, unitID in ipairs(selectedUnits) do
		local unitDirection = Spring.GetUnitBuildFacing(unitID)
		local xOffset = mathCeil(centerposx[unitID]-blueprintCenterX)
		local zOffset = mathCeil(centerposz[unitID]-blueprintCenterZ)
		blueprintRadius = math.max(blueprintRadius, xOffset, zOffset)

		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitName = UnitDefs[unitDefID].name

		local unitDef = UnitDefNames[unitName]
		if unitOverrides[unitName] then
			tableInsert(buildings, { buildTime = unitDef.buildTime, blueprintText = "\t\t\t{ unitDefID = " .. unitOverrides[unitName] .. ", xOffset = " .. xOffset .. ", zOffset = " .. zOffset .. ", direction = " .. unitDirection .. "},\n" })
		else
			tableInsert(buildings, { buildTime = unitDef.buildTime, blueprintText = "\t\t\t{ unitDefID = UnitDefNames." .. unitName .. ".id, xOffset = " .. xOffset .. ", zOffset = " .. zOffset .. ", direction = " .. unitDirection .. "},\n" })
		end
	end

	table.sort(buildings, function(b1, b2)
			return b1.buildTime < b2.buildTime
		end
	)

	file:write("\n")
	file:write("local function " .. blueprintName .. "()", "\n")
	file:write("\treturn {", "\n")
	file:write("\t\ttype = types." .. blueprintType .. ",", "\n")

	file:write("\t\ttiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, tiers.T4 },", "\n")

	file:write("\t\tradius = " .. blueprintRadius .. ",", "\n")
	file:write("\t\tbuildings = {", "\n")

	for _, building in ipairs(buildings) do
		file:write(building.blueprintText)
	end

	file:write("\t\t},", "\n")
	file:write("\t}", "\n")
	file:write("end", "\n")
	file:close()

	clearValues()

	blueprintCounter = blueprintCounter + 1

	Spring.Echo(blueprintName .. " written to " .. outputFile)
end

function widget:TextCommand(command)
	if command == "ruinblueprint" then
		generateCode(types.blueprint)
	end
end

function widget:Initialize()
	-- Clear file to avoid junk buildup
	local file = io.open(outputFile, "w")
	file:close()
end
