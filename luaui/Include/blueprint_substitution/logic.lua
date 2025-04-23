-- luaui/Include/blueprint_substitution/logic.lua
-- Contains substitution logic and data, intended to be included by api_blueprint.lua widget
local defPath = "luaui/Include/blueprint_substitution/definitions.lua"
local BpDefs = VFS.Include(defPath)
if not BpDefs then
    error("Failed to load required blueprint definitions from: " .. defPath)
end

WG.BlueprintSubstitutionLogic = WG.BlueprintSubstitutionLogic or {}
local BlueprintSubLogic = WG.BlueprintSubstitutionLogic -- Local alias for convenience

BlueprintSubLogic.SIDES = BpDefs.SIDES

BpDefs.defineUnitCategories()

-- Load categories from the definitions file
BlueprintSubLogic.UNIT_CATEGORIES = BpDefs.UNIT_CATEGORIES
BlueprintSubLogic.categoryUnits = BpDefs.categoryUnits
BlueprintSubLogic.unitCategories = BpDefs.unitCategories
BlueprintSubLogic.equivalentUnits = {}
BlueprintSubLogic.MasterBuildingData = {}
BlueprintSubLogic.initialized = false

-- Precompute map for faster lookups
local unitNameToDefIDMap = {}
Spring.Log("BlueprintSubLogic", LOG.INFO, "Precomputing UnitDefs Name->ID map...")
for defID, def in pairs(UnitDefs) do
    if def and def.name then
        unitNameToDefIDMap[def.name:lower()] = defID
    end
end
Spring.Log("BlueprintSubLogic", LOG.INFO, "Finished precomputing Name->ID map.")

function BlueprintSubLogic.validateCategoryDefinitions()
    local categoryKeys = {}
    local duplicateCategories = {}

    for catKey in pairs(BlueprintSubLogic.UNIT_CATEGORIES) do
        if categoryKeys[catKey] then
            duplicateCategories[catKey] = true
        else
            categoryKeys[catKey] = true
        end
    end

    if next(duplicateCategories) then
        local dupes = {}
        for dupe in pairs(duplicateCategories) do
            table.insert(dupes, dupe)
        end
        local errorMsg = string.format("[BlueprintSubLogic ERROR] Found duplicate category keys: %s",
                                     table.concat(dupes, ", "))
        Spring.Log("BlueprintSubLogic", LOG.ERROR, errorMsg)
    end

    Spring.Log("BlueprintSubLogic", LOG.DEBUG, "Validating category definitions (Unit Assignments)...")

    local multiAssigned = {}
    local unitAssignments = {}

    for unitName, categoryName in pairs(BlueprintSubLogic.unitCategories) do
        unitAssignments[unitName] = unitAssignments[unitName] or {}
        table.insert(unitAssignments[unitName], categoryName)

        if #unitAssignments[unitName] > 1 then
            multiAssigned[unitName] = unitAssignments[unitName]
        end
    end

    local count = 0
    for unitName, categories in pairs(multiAssigned) do
        count = count + 1
        local msg = string.format("Unit '%s' is assigned to multiple categories: %s",
                                 unitName, table.concat(categories, ", "))
        Spring.Log("BlueprintSubLogic", LOG.WARNING, msg)
    end

    if count > 0 then
        Spring.Log("BlueprintSubLogic", LOG.WARNING, string.format("Found %d units with multiple category assignments (This may be intended)", count))
    else
        Spring.Log("BlueprintSubLogic", LOG.DEBUG, "No duplicate unit assignments found")
    end
end

function BlueprintSubLogic.generateEquivalentUnits()
    Spring.Log("BlueprintSubLogic", LOG.INFO, "Generating equivalent units...")
    local categoryUnits = BlueprintSubLogic.categoryUnits
    local equivalentUnits = BlueprintSubLogic.equivalentUnits

    for k in pairs(equivalentUnits) do equivalentUnits[k] = nil end

    local mappingCount = 0
    for _, sideUnits in pairs(categoryUnits) do
        local sideCount = 0
        for _ in pairs(sideUnits) do sideCount = sideCount + 1 end

        if sideCount > 1 then
            for fromSide, fromUnit in pairs(sideUnits) do
                if fromUnit then
                    local lowerFromUnit = fromUnit:lower()
                    if not equivalentUnits[lowerFromUnit] then 
                        equivalentUnits[lowerFromUnit] = {}
                        mappingCount = mappingCount + 1
                    end

                    for toSide, toUnit in pairs(sideUnits) do
                        if fromSide ~= toSide and toUnit then
                            equivalentUnits[lowerFromUnit][toSide] = toUnit:lower()
                        end
                    end
                end
            end
        end
    end
    Spring.Log("BlueprintSubLogic", LOG.INFO, string.format("Generated %d unit mappings.", mappingCount))
end

function BlueprintSubLogic.getSideFromUnitName(unitName)
    if not unitName then return nil end
    local lowerName = unitName:lower()

    for side, prefix in pairs(BlueprintSubLogic.SIDES) do
        if lowerName:find("^" .. prefix) then
            Spring.Log("BlueprintSubLogic", LOG.DEBUG, "Unit " .. lowerName .. " detected as side: " .. prefix)
            return prefix
        end
    end

    Spring.Log("BlueprintSubLogic", LOG.DEBUG, "No side detected for unit: " .. lowerName)

    return nil
end

BlueprintSubLogic.validateCategoryDefinitions()
BlueprintSubLogic.generateEquivalentUnits()

Spring.Log("BlueprintSubLogic", LOG.INFO, "Generating Master Building Data...")
local buildingCount = 0
for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef and unitDef.name and (unitDef.isBuilding or unitDef.isFactory or unitDef.speed == 0) and not unitDef.isFeature then
        local unitNameLower = unitDef.name:lower()
        local side = BlueprintSubLogic.getSideFromUnitName(unitNameLower)
        local categoryName = BlueprintSubLogic.unitCategories[unitNameLower] or "Misc"
        local translatedHumanName = unitDef.translatedHumanName or unitDef.name
        local equivalents = BlueprintSubLogic.equivalentUnits[unitNameLower] or {}

        BlueprintSubLogic.MasterBuildingData[unitNameLower] = {
            unitDefID = unitDefID,
            name = unitNameLower,
            translatedHumanName = translatedHumanName,
            side = side, 
            categoryName = categoryName,
            equivalents = equivalents
        }
        
        buildingCount = buildingCount + 1
    end
end
Spring.Log("BlueprintSubLogic", LOG.INFO, string.format("Generated Master Building Data for %d buildings.", buildingCount))

BlueprintSubLogic.initialized = true
Spring.Log("BlueprintSubLogic", LOG.INFO, "Substitution logic initialized and ready.")

function BlueprintSubLogic.analyzeBlueprintSides(blueprint)
    if not blueprint or not blueprint.units then
        return {
            unitCount = 0,
            primarySourceSide = nil,
            numSourceSides = 0,
            sourceSideInfo = "Empty",
            sideCounts = {}
        }
    end

    local sourceSidesFound = {}
    local sideCounts = {}
    local buildingUnitCount = 0

    for _, unit in ipairs(blueprint.units) do
        local unitDef = UnitDefs[unit.unitDefID]
        if unitDef and unitDef.name then
            local unitNameLower = unitDef.name:lower()
            local buildingData = BlueprintSubLogic.MasterBuildingData[unitNameLower]
            
            if buildingData and buildingData.side then
                buildingUnitCount = buildingUnitCount + 1
                local side = buildingData.side
                sourceSidesFound[side] = true
                sideCounts[side] = (sideCounts[side] or 0) + 1
            end
        end
    end

    local numSourceSides = 0
    local primarySourceSide = nil
    local maxCount = 0
    for side, _ in pairs(sourceSidesFound) do 
        numSourceSides = numSourceSides + 1 
        local count = sideCounts[side] or 0
        if count > maxCount then
            primarySourceSide = side
            maxCount = count
        end
    end
    
    local sourceSideInfo = "Empty/No Buildings"
    if buildingUnitCount > 0 then
        if primarySourceSide then
            sourceSideInfo = primarySourceSide
            if numSourceSides > 1 then
                sourceSideInfo = sourceSideInfo .. " (Mixed)" 
            end
        else
            sourceSideInfo = "Unknown Side Buildings"
        end
    end

    return {
        unitCount = #blueprint.units,
        buildingUnitCount = buildingUnitCount,
        primarySourceSide = primarySourceSide,
        numSourceSides = numSourceSides,
        sourceSideInfo = sourceSideInfo,
        sideCounts = sideCounts
    }
end


local function getSubstitutionStatusAndID(buildingData, targetSide, originalUnitDefID)
    if not buildingData then
        return "skipped_not_building", originalUnitDefID
    end

    if not buildingData.side or buildingData.side == targetSide then
        return "skipped_same_side", originalUnitDefID
    end

    -- Substitution needed
    local equivalentUnitName = buildingData.equivalents[targetSide]
    if not equivalentUnitName then
        return "failed_no_mapping", originalUnitDefID
    end

    local foundDefID = unitNameToDefIDMap[equivalentUnitName] 
    if not foundDefID then
        return "failed_lookup", originalUnitDefID
    end

    return "success", foundDefID
end

function BlueprintSubLogic.processBlueprintSubstitution(originalBlueprint, targetSide)
    Spring.Log("BlueprintSubLogic", LOG.DEBUG, string.format("Starting substitution for BUILDINGS ONLY. Source Side: %s, Target Side: %s, Units: %d",
                                 originalBlueprint.sourceInfo.primarySourceSide,
                                 targetSide,
                                 #originalBlueprint.units))

    local enrichedUnits = table.map(originalBlueprint.units, function(unit)
        local originalUnitDefID = unit.unitDefID
        local originalUnitDef = UnitDefs[originalUnitDefID]
        local unitNameLower = originalUnitDef and originalUnitDef.name:lower() or ("unknown_defid_" .. originalUnitDefID)
        
        local record = {
            blueprintUnitID = unit.blueprintUnitID,
            originalUnitDefID = originalUnitDefID,
            position = unit.position,
            facing = unit.facing,
            originalUnitName = unitNameLower,
            status = "unknown", 
            newUnitDefID = originalUnitDefID,
            translatedHumanName = "N/A",
            sourceSide = nil,
            equivalentUnitName = nil -- Store this temporarily for logging
        }

        local buildingData = BlueprintSubLogic.MasterBuildingData[unitNameLower]
        
        record.status, record.newUnitDefID = getSubstitutionStatusAndID(buildingData, targetSide, originalUnitDefID)
        

        if buildingData then
            record.sourceSide = buildingData.side
            record.translatedHumanName = buildingData.translatedHumanName
            record.equivalentUnitName = buildingData.equivalents[targetSide] -- Store for logging failure cases
        end

        Spring.Log("BlueprintSubLogic", LOG.DEBUG, string.format("Mapped unit %s: Status=%s", 
            record.originalUnitName, record.status))

        return record
    end)

    local initialAccumulator = {
        units = {},
        stats = {
            total = #originalBlueprint.units,
            success = 0,
            skipped = 0,
            failedNoMapping = 0,
            failedLookup = 0,
        }
    }

    local finalResult = table.reduce(enrichedUnits, function(acc, record)
        local shouldAddUnit = true

        if record.status == "success" then
            acc.stats.success = acc.stats.success + 1
        elseif record.status == "skipped_same_side" then
            acc.stats.skipped = acc.stats.skipped + 1
        elseif record.status == "skipped_not_building" then
             acc.stats.skipped = acc.stats.skipped + 1
        elseif record.status == "failed_no_mapping" then
            acc.stats.failedNoMapping = acc.stats.failedNoMapping + 1
            shouldAddUnit = false
            Spring.Log("BlueprintSubLogic", LOG.WARNING, string.format("No mapping found for BUILDING: %s (%s) when converting from %s to %s.",
                                         record.originalUnitName, record.translatedHumanName, record.sourceSide, targetSide))
        elseif record.status == "failed_lookup" then
            acc.stats.failedLookup = acc.stats.failedLookup + 1
            shouldAddUnit = false
            Spring.Log("BlueprintSubLogic", LOG.WARNING, string.format("Substitution FAILED for BUILDING: %s (%s). From %s to %s. Name '%s' not found in UnitDefs.",
                                             record.originalUnitName, record.translatedHumanName, record.sourceSide, targetSide, record.equivalentUnitName))
        end

        if shouldAddUnit then
             table.insert(acc.units, {
                blueprintUnitID = record.blueprintUnitID,
                unitDefID = record.newUnitDefID,
                position = record.position,
                facing = record.facing
        })
    end

        return acc
    end, initialAccumulator)

    local stats = finalResult.stats
    local substitutionFailed = (stats.failedNoMapping > 0 or stats.failedLookup > 0)

    local summaryMessage = string.format("Blueprint processed from %s to %s. Total Units: %d, Buildings Substituted: %d, Buildings Failed: %d, Other Units/Skipped: %d",
        originalBlueprint.sourceInfo.primarySourceSide,
        targetSide,
        stats.total,
        stats.success,
        stats.failedNoMapping + stats.failedLookup,
        stats.skipped
    )

    if substitutionFailed then
        summaryMessage = summaryMessage .. " (FAIL)"
    elseif stats.success > 0 then
        summaryMessage = summaryMessage .. " (OK)"
    end

    return {
        units = finalResult.units,
        stats = stats,
        substitutionFailed = substitutionFailed,
        summaryMessage = summaryMessage
    }
end

return BlueprintSubLogic 