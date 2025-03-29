local widget = widget ---@type Widget

function widget:GetInfo()
	return {
	name      = "Scavenger Blueprint Generator",
	desc      = "Generates Lua blueprint code from selected units",
	author    = "Damgam",
	date      = "2020",
	license   = "GNU GPL, v2 or later",
	layer     = 0,
	enabled   = true,
	}
end

local outputFile = "blueprints_temp.txt"
local blueprintCounter, ruinCounter = 0, 0
local scavSuffix = "_scav"

local types = {
	blueprint = 1,
	ruin = 2,
}

local centerposx = {}
local centerposy = {}
local centerposz = {}
local blueprintposx = 0
local blueprintposz = 0
local blueprintCenterX, blueprintCenterY, blueprintCenterZ
local blueprintRadius = 0

local function getBlueprintCenter()
	local selectedunits = Spring.GetSelectedUnits()

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

local function generateCode(type)
	local selectedUnits = Spring.GetSelectedUnits()

	getBlueprintCenter()

	local file = io.open(outputFile, "a")
	local blueprintName = type == types.blueprint and "blueprint" .. blueprintCounter or "ruin" .. ruinCounter
	local blueprintType = blueprintCenterY > 0 and "Land" or "Sea"
	local buildings = {}

	for _, unitID in ipairs(selectedUnits) do
		local unitDirection = Spring.GetUnitBuildFacing(unitID)
		local xOffset = math.ceil(centerposx[unitID]-blueprintCenterX)
		local zOffset = math.ceil(centerposz[unitID]-blueprintCenterZ)
		blueprintRadius = math.max(blueprintRadius, xOffset, zOffset)

		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitName = UnitDefs[unitDefID].name

		if type == types.blueprint then
			if not string.find(unitName, scavSuffix) then
				unitName = unitName .. scavSuffix
			end
		end

		local unitDef = UnitDefNames[unitName]
		if type == types.blueprint and (unitName == "armdrag_scav" or unitName == "cordrag_scav" or unitName == "armclaw_scav" or unitName == "cormaw_scav" or unitName == "corscavdrag_scav" or unitName == "corscavdtf_scav" or unitName == "corscavdtl_scav" or unitName == "corscavdtm_scav") then
			table.insert(buildings, { buildTime = unitDef.buildTime, blueprintText = "\t\t\t{ unitDefID = BPWallOrPopup('scav', 1), xOffset = " .. xOffset .. ", zOffset = " .. zOffset .. ", direction = " .. unitDirection .. "},\n" })
		elseif type == types.blueprint and (unitName == "armfort_scav" or unitName == "corfort_scav") then
			table.insert(buildings, { buildTime = unitDef.buildTime, blueprintText = "\t\t\t{ unitDefID = BPWallOrPopup('scav', 2), xOffset = " .. xOffset .. ", zOffset = " .. zOffset .. ", direction = " .. unitDirection .. "},\n" })
		else
			table.insert(buildings, { buildTime = unitDef.buildTime, blueprintText = "\t\t\t{ unitDefID = UnitDefNames." .. unitName .. ".id, xOffset = " .. xOffset .. ", zOffset = " .. zOffset .. ", direction = " .. unitDirection .. "},\n" })
		end
	end

	if type == types.blueprint then
		table.sort(buildings, function(b1, b2)
				return b1.buildTime < b2.buildTime
			end
		)
	end

	file:write("\n")
	file:write("local function " .. blueprintName .. "()", "\n")
	file:write("\treturn {", "\n")
	file:write("\t\ttype = types." .. blueprintType .. ",", "\n")

	if type == types.blueprint then
		file:write("\t\ttiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, tiers.T4 },", "\n")
	end

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

	if type == types.blueprint then
		blueprintCounter = blueprintCounter + 1
	else
		ruinCounter = ruinCounter + 1
	end

	Spring.Echo(blueprintName .. " written to " .. outputFile)
end

function widget:TextCommand(command)
	if command == "scavblpcon" then
		generateCode(types.blueprint)
	elseif command == "scavblpruin" then
		generateCode(types.ruin)
	end
end

function widget:Initialize()
	-- Clear file to avoid junk buildup
	local file = io.open(outputFile, "w")
	file:close()
end
