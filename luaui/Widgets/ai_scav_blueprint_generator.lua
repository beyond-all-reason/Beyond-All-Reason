function widget:GetInfo()
	return {
	name      = "Scavenger Blueprint Generator",
	desc      = "AAA",
	author    = "Damgam",
	date      = "2020",
	license   = "who cares?",
	layer     = 0,
	enabled   = true, --enabled by default
	}
end

local outputFile = "blueprints_temp.txt"
local counter = 0

local centerposx = {}
local centerposz = {}
local centerposy = {}
local blueprintposx = 0
local blueprintposz = 0
local blpcenterpositionx, blpcenterpositiony, blpcenterpositionz
local blueprintRadius = 0

local function getBlueprintCenter()
	local selectedunits = Spring.GetSelectedUnits()

	for i = 1, #selectedunits do
		local unit = selectedunits[i]
		centerposx[unit], centerposy[unit], centerposz[unit] = Spring.GetUnitPosition(unit)
		blueprintposx = blueprintposx + centerposx[unit]
		blueprintposz = blueprintposz + centerposz[unit]
	end

	blpcenterpositionx = blueprintposx / #selectedunits
	blpcenterpositionz = blueprintposz / #selectedunits
	blpcenterpositiony = Spring.GetGroundHeight(blpcenterpositionx, blpcenterpositionz)
end

local function clearValues()
	blueprintposx = 0
	blueprintposz = 0
	centerposx = {}
	centerposy = {}
	centerposz = {}
end

local function generateConstructorBlueprint()
	local selectedUnits = Spring.GetSelectedUnits()

	getBlueprintCenter()

	local file = io.open(outputFile, "a")
	local blueprintName = "blueprint" .. counter
	local blueprintType = blpcenterpositiony > 0 and "Land" or "Sea"
	local buildingsText = ""

	for _, unitID in ipairs(selectedUnits) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitDefName = UnitDefs[unitDefID].name
		local unitDirection = Spring.GetUnitBuildFacing(unitID)
		local xOffset = math.ceil(centerposx[unitID]-blpcenterpositionx)
		local zOffset = math.ceil(centerposz[unitID]-blpcenterpositionz)
		local radius = math.ceil(math.sqrt(xOffset * xOffset + zOffset * zOffset))

		blueprintRadius = math.max(radius, blueprintRadius)
		buildingsText = buildingsText .. "\t\t\t{ unitDefName = " .. unitDefName .. ", xOffset = " .. xOffset .. ", zOffset = " .. zOffset .. ", direction = " .. unitDirection .. "},\n"
	end

	file:write("\n\n")
	file:write("local function " .. blueprintName .. "()", "\n")
	file:write("\treturn {", "\n")
	file:write("\t\ttype = types." .. blueprintType .. ",", "\n")
	file:write("\t\ttiers = { tiers.T0, tiers.T1, tiers.T2, tiers.T3, tiers.T4 },", "\n")
	file:write("\t\tradius = " .. blueprintRadius .. ",", "\n")
	file:write("\t\tbuildings = {", "\n")
	file:write(buildingsText)
	file:write("\t\t},", "\n")
	file:write("\t}", "\n")
	file:write("end", "\n")

	clearValues()
	counter = counter + 1

	Spring.Echo(blueprintName .. " written to " .. outputFile)
end

local function generateSpawnerBlueprint(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	local unitDefName = UnitDefs[unitDefID].name
	local unitIDFacing = Spring.GetUnitBuildFacing(unitID)
	local posx = math.ceil(centerposx[unitID]-blpcenterpositionx)
	local posz = math.ceil(centerposz[unitID]-blpcenterpositionz)
	local unitDefNameString = [["]]

	-- Spring.CreateUnit("corrad"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
	Spring.Echo("Spring.CreateUnit("..unitDefNameString..unitDefName..unitDefNameString.."..nameSuffix, posx+("..posx.."), posy, posz+("..posz.."), "..unitIDFacing..",GaiaTeamID)")
end

local function generateRuinBlueprint(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	local unitDefName = UnitDefs[unitDefID].name
	local unitIDFacing = Spring.GetUnitBuildFacing(unitID)
	local posx = math.ceil(centerposx[unitID]-blpcenterpositionx)
	local posz = math.ceil(centerposz[unitID]-blpcenterpositionz)
	local unitDefNameString = [["]]

	-- Spring.CreateUnit("corrad"..nameSuffix, posx, posy, posz, math.random(0,3),GaiaTeamID)
	Spring.Echo("SpawnRuin("..unitDefNameString..unitDefName..unitDefNameString..", posx+("..posx.."), posy, posz+("..posz.."), "..unitIDFacing..")")
end

function widget:TextCommand(command)
	if command == "scavblpcon" then
			generateConstructorBlueprint()
	elseif command == "scavblpspawn" then
		local selectedunits = Spring.GetSelectedUnits()
		getBlueprintCenter()
		Spring.Echo(" ")
		Spring.Echo("Spawner Blueprint: ")
		for i = 1,#selectedunits do
			generateSpawnerBlueprint(selectedunits[i])
		end
		Spring.Echo(" ")
		Spring.Echo("BLUEPRINT GENERATED")
		Spring.Echo("BLUEPRINT GENERATED")
		Spring.Echo("BLUEPRINT GENERATED")
		Spring.Echo("")
		clearValues()
	elseif command == "scavblpruin" then
		local selectedunits = Spring.GetSelectedUnits()
		getBlueprintCenter()
		Spring.Echo(" ")
		Spring.Echo("Ruin Blueprint: ")
		for i = 1,#selectedunits do
			generateRuinBlueprint(selectedunits[i])
		end
		Spring.Echo(" ")
		Spring.Echo("BLUEPRINT GENERATED")
		Spring.Echo("BLUEPRINT GENERATED")
		Spring.Echo("BLUEPRINT GENERATED")
		Spring.Echo("")
		clearValues()
	end
end

function widget:Initialize()
	-- Clear file to avoid junk buildup
	local file = io.open(outputFile, "w")
	file:close()
end