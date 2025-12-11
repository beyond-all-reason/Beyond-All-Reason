-- luaui/Include/blueprint_substitution/reports.lua
-- Contains reporting functions for api_blueprint.lua

local REPORTS = {}

-- Store references passed in during include
local substitutionLogic = nil

-- Local data for reports
local sideTotals = {}
local sideComplete = {}
local uncategorizedUnits = {}

local function escapeCsvField(value)
    local str = tostring(value or "")
    if string.find(str, '[,\"\n]') then
        str = string.gsub(str, '"', '""')
        return '"' .. str .. '"'
    else
        return str
    end
end

-- Helper function to echo a table of lines in chunks
local function echoChunked(lines, chunkSize)
    chunkSize = chunkSize or 20 -- Default chunk size
    local numLines = #lines
    for i = 1, numLines, chunkSize do
        local chunkEnd = math.min(i + chunkSize - 1, numLines)
        local chunkLines = {}
        for j = i, chunkEnd do
            table.insert(chunkLines, lines[j])
        end
        Spring.Echo(table.concat(chunkLines, "\n"))
    end
end

function REPORTS.SetDependencies(subLogic)
    Spring.Log("BlueprintReports", "info", "Receiving dependencies via SetDependencies...")
    substitutionLogic = subLogic
    if not substitutionLogic then
        Spring.Log("BlueprintReports", "error", "Failed to receive necessary logic tables via SetDependencies!")
    else
        Spring.Log("BlueprintReports", "info", "Dependencies received successfully via SetDependencies.")
    end
end

-- ===================================================================
-- Reporting Functions
-- ===================================================================

function REPORTS.generateMappingReport()
    Spring.Echo("\n--- Blueprint Mapping Report Start (CSV Format) ---")
    local SIDES = substitutionLogic.SIDES
    local masterBuildingDataMinimal = substitutionLogic.MasterBuildingData
    local reportLines = {}

    -- Add Header
    table.insert(reportLines, table.concat({
        "Category", "DescName",
        "Side", "Tier", "Building", "Name", 
        "MetalCost", "EnergyCost", "BuildTime", "Health", "Speed", "HasWeapons", "HasBuildOptions", "ExtractsMetal", "EnergyMake", "RadarDist", "SonarDist", "SightDist", "CanFly", "Tooltip", 
        "Equiv_ARM", "Equiv_COR", "Equiv_LEG"
    }, ","))

    sideTotals = { [SIDES.ARMADA]=0, [SIDES.CORTEX]=0, [SIDES.LEGION]=0 } 
    sideComplete = { [SIDES.ARMADA]=0, [SIDES.CORTEX]=0, [SIDES.LEGION]=0 }
    uncategorizedUnits = { [SIDES.ARMADA]={}, [SIDES.CORTEX]={}, [SIDES.LEGION]={}, ["UNKNOWN"]={} } 

    -- Iterate the minimal data, but fetch details from UnitDefs
    for unitNameLower, buildingCoreData in pairs(masterBuildingDataMinimal) do
        local unitDef = UnitDefs[buildingCoreData.unitDefID]
        if unitDef then 
            -- Extract core data provided by logic.lua
            local categoryName = buildingCoreData.categoryName
            local translatedHumanName = buildingCoreData.translatedHumanName
            local side = buildingCoreData.side
            local name = buildingCoreData.name -- which is unitNameLower
            local equivalents = buildingCoreData.equivalents

            -- Fetch details directly from UnitDef
            local tooltip = unitDef.translatedTooltip or ""
            tooltip = tooltip:gsub("\n", " "):gsub("\t", " ")
            tooltip = tooltip:sub(1, 100)
            local tier = (unitDef.customParams and unitDef.customParams.techlevel) or "1"
            local isBuilding = "Yes" -- Assumed based on the loop in logic.lua
            local metalCost = unitDef.metalCost or 0
            local energyCost = unitDef.energyCost or 0
            local buildTime = unitDef.buildTime or 0
            local health = unitDef.health or 0
            local speed = 0 -- Buildings don't move
            local hasWeapons = (unitDef.weapons and #unitDef.weapons > 0) and "Yes" or "No"
            local hasBuildOptions = (unitDef.buildOptions and #unitDef.buildOptions > 0) and "Yes" or "No"
            local extractsMetal = unitDef.extractsMetal or 0 
            local energyMake = unitDef.energyMake or 0
            local radarDist = unitDef.radarDistance or 0
            local sonarDist = unitDef.sonarDistance or 0
            local sightDist = unitDef.losRadius or 0
            local canFly = false -- Buildings don't fly

            local equivArm = equivalents[SIDES.ARMADA] or ""
            local equivCor = equivalents[SIDES.CORTEX] or ""
            local equivLeg = equivalents[SIDES.LEGION] or ""

            local reportLine = table.concat({
                escapeCsvField(categoryName), escapeCsvField(translatedHumanName), 
                escapeCsvField(side or "???"), escapeCsvField(tier), escapeCsvField(isBuilding),
                escapeCsvField(name), 
                metalCost, energyCost, buildTime, 
                health, speed, escapeCsvField(hasWeapons), 
                escapeCsvField(hasBuildOptions), extractsMetal, energyMake,
                radarDist, sonarDist, sightDist, escapeCsvField(canFly), 
                escapeCsvField(tooltip),
                escapeCsvField(equivArm), escapeCsvField(equivCor), escapeCsvField(equivLeg)
            }, ",")
            
            -- Add line to table instead of echoing
            table.insert(reportLines, reportLine)

            -- Side totals logic remains the same, using 'side' derived earlier
            if side == SIDES.ARMADA or side == SIDES.CORTEX or side == SIDES.LEGION then
                sideTotals[side] = (sideTotals[side] or 0) + 1
                if categoryName ~= "Misc" then
                    sideComplete[side] = (sideComplete[side] or 0) + 1
                else
                    table.insert(uncategorizedUnits[side], reportLine) 
                end
            else
                table.insert(uncategorizedUnits["UNKNOWN"], reportLine) 
            end
        else
            Spring.Log("BlueprintReports", "warning", "[Mapping Report] Could not find UnitDef for ID: " .. tostring(buildingCoreData.unitDefID) .. " Name: " .. unitNameLower);
        end
    end

    table.insert(reportLines, "\n--- Mapping Report Summary (Buildings Only) ---")
    for side, total in pairs(sideTotals) do
        local complete = sideComplete[side] or 0
        local percentage = total > 0 and (complete / total * 100) or 0
        table.insert(reportLines, string.format("[Mapping Report Summary] %s: %d / %d buildings categorized (%.2f%%)", side, complete, total, percentage))
    end
    local unknownCount = #uncategorizedUnits["UNKNOWN"]
    if unknownCount > 0 then
        table.insert(reportLines, string.format("[Mapping Report Summary] Buildings with UNKNOWN side: %d", unknownCount))
    end
    table.insert(reportLines, "--- Blueprint Mapping Report End ---")

    echoChunked(reportLines)
end

function REPORTS.generateCategoryListReport()
    Spring.Echo("\n--- Blueprint Category List Start ---")

    local UNIT_CATEGORIES = substitutionLogic.UNIT_CATEGORIES
    local categoryUnits = substitutionLogic.categoryUnits
    local SIDES = substitutionLogic.SIDES

    local sortedCategories = {}
    for enumName, categoryName in pairs(UNIT_CATEGORIES) do
        table.insert(sortedCategories, {enum = enumName, cat = categoryName})
    end
    table.sort(sortedCategories, function(a,b) return a.cat < b.cat end)

    local reportLines = {}
    local header = string.format("Found %d defined categories:", #sortedCategories)
    table.insert(reportLines, header)
    Spring.Log("BlueprintReports", "info", "[Category List] " .. header)

    for _, entry in ipairs(sortedCategories) do
        local categoryName = entry.cat
        local sideUnits = categoryUnits[categoryName]
        table.insert(reportLines, string.format("\nCategory: %s (Enum: %s)", categoryName, entry.enum))
        if sideUnits then
            local armUnit = sideUnits[SIDES.ARMADA] or "(none)"
            local coreUnit = sideUnits[SIDES.CORTEX] or "(none)"
            local legionUnit = sideUnits[SIDES.LEGION] or "(none)"
            table.insert(reportLines, string.format("  ARMADA: %s", armUnit))
            table.insert(reportLines, string.format("  CORTEX: %s", coreUnit))
            table.insert(reportLines, string.format("  LEGION: %s", legionUnit))
        else
            table.insert(reportLines, "  (No side units defined for this category name)")
        end
    end

    table.insert(reportLines, "--- Blueprint Category List End ---")

    echoChunked(reportLines)
end

return REPORTS