-- luaui/Include/blueprint_substitution/logic.lua
-- Handles faction-based unit substitution logic for blueprints and build queues.

local BlueprintSubLogic = {}

local defPath = "luaui/Include/blueprint_substitution/definitions.lua"
local BpDefs = VFS.Include(defPath)

if not BpDefs then
    error("[BlueprintSubLogic] CRITICAL: Failed to load required blueprint definitions from: " .. defPath .. ". Substitution logic cannot initialize.")
end

BlueprintSubLogic.SIDES = BpDefs.SIDES
BpDefs.defineUnitCategories()

BlueprintSubLogic.UNIT_CATEGORIES = BpDefs.UNIT_CATEGORIES
BlueprintSubLogic.categoryUnits = BpDefs.categoryUnits
BlueprintSubLogic.unitCategories = BpDefs.unitCategories
BlueprintSubLogic.equivalentUnits = {}
BlueprintSubLogic.MasterBuildingData = {}

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
        for dupe in pairs(duplicateCategories) do table.insert(dupes, dupe) end
        Spring.Log("BlueprintSubLogic", LOG.ERROR, string.format("[BlueprintSubLogic ERROR] Found duplicate category keys: %s", table.concat(dupes, ", ")))
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
        Spring.Log("BlueprintSubLogic", LOG.WARNING, string.format("Unit '%s' is assigned to multiple categories: %s", unitName, table.concat(categories, ", ")))
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
            return prefix
        end
    end
    return nil
end

function BlueprintSubLogic.analyzeBlueprintSides(blueprint)
    if not blueprint or not blueprint.units then
        return {
            unitCount = 0,
            buildingUnitCount = 0,
            primarySourceSide = nil,
            numSourceSides = 0,
            sourceSideInfo = "Empty/No Units",
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
    if buildingUnitCount > 0 then 
        for side, count in pairs(sideCounts) do 
            if sourceSidesFound[side] then numSourceSides = numSourceSides + 1 end 
        if count > maxCount then
            primarySourceSide = side
            maxCount = count
            end
        end
    end
    
    local sourceSideInfo = "Empty/No Relevant Buildings"
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

BlueprintSubLogic.validateCategoryDefinitions()
BlueprintSubLogic.generateEquivalentUnits()

Spring.Log("BlueprintSubLogic", LOG.INFO, "Generating Master Building Data...")
local buildingCount = 0
if UnitDefs then 
    for unitDefID, unitDef in pairs(UnitDefs) do
        if unitDef and unitDef.name and (unitDef.isBuilding or unitDef.isFactory or unitDef.speed == 0) and not unitDef.isFeature then
            local unitNameLower = unitDef.name:lower()
            local side = BlueprintSubLogic.getSideFromUnitName(unitNameLower)
            local categoryName = BlueprintSubLogic.unitCategories[unitNameLower] or "Misc"
            local translatedHumanName = unitDef.translatedHumanName or unitDef.name
            local equivalents = BlueprintSubLogic.equivalentUnits[unitNameLower] or {}
            BlueprintSubLogic.MasterBuildingData[unitNameLower] = {
                unitDefID = unitDefID, name = unitNameLower, translatedHumanName = translatedHumanName,
                side = side, categoryName = categoryName, equivalents = equivalents
            }
            buildingCount = buildingCount + 1
        end
    end
end
Spring.Log("BlueprintSubLogic", LOG.INFO, string.format("Generated Master Building Data for %d buildings.", buildingCount))
Spring.Log("BlueprintSubLogic", LOG.INFO, "Internal data structures for substitution logic generated. Module ready to be used.")

local function _getActualSubstitutedUnitDefID(originalUnitDefID, targetSide)
    if not originalUnitDefID or not targetSide then
        return originalUnitDefID 
    end
    local originalUnitDef = UnitDefs[originalUnitDefID]
    if not (originalUnitDef and originalUnitDef.name) then
        Spring.Log("BlueprintSubLogic", LOG.DEBUG, string.format("_getActualSubstitutedUnitDefID: Original UnitDef for ID %s not found or has no name. Returning original.", tostring(originalUnitDefID)))
        return originalUnitDefID
    end
    local unitNameLower = originalUnitDef.name:lower()
    local buildingData = BlueprintSubLogic.MasterBuildingData[unitNameLower]
    if not buildingData then
        return originalUnitDefID
    end
    local equivalentUnitName = buildingData.equivalents[targetSide]
    if not equivalentUnitName then
        Spring.Log("BlueprintSubLogic", LOG.WARNING, string.format("_getActualSubstitutedUnitDefID: No mapping for unit '%s' to target side '%s'. OriginalDefID: %s", unitNameLower, targetSide, tostring(originalUnitDefID)))
        return originalUnitDefID
    end
    local foundDefID = unitNameToDefIDMap[equivalentUnitName] 
    if not foundDefID then
        Spring.Log("BlueprintSubLogic", LOG.WARNING, string.format("_getActualSubstitutedUnitDefID: Equivalent name '%s' for unit '%s' (target side '%s') not in UnitDefs map. OriginalDefID: %s", equivalentUnitName, unitNameLower, targetSide, tostring(originalUnitDefID)))
        return originalUnitDefID 
    end
    return foundDefID
end

local function _getBuildingSubstitutionOutcome(originalUnitDefID, buildingData, targetSide, sourceSideOrNil)
    local newUnitDefID = originalUnitDefID
    local status = "unknown"
    local equivalentUnitNameAttempted = nil
    if sourceSideOrNil and buildingData.side == targetSide then 
        status = "unchanged_same_side"
    else
        equivalentUnitNameAttempted = buildingData.equivalents[targetSide]
        if not equivalentUnitNameAttempted then
            status = "failed_no_mapping" 
            newUnitDefID = _getActualSubstitutedUnitDefID(originalUnitDefID, targetSide) 
        else
            newUnitDefID = _getActualSubstitutedUnitDefID(originalUnitDefID, targetSide) 
            if newUnitDefID == originalUnitDefID then 
                status = "failed_invalid_equivalent"
            else
                status = "substituted"
            end
        end
    end
    return { newUnitDefID = newUnitDefID, status = status, equivalentUnitNameAttempted = equivalentUnitNameAttempted }
end

local function _generateSubstitutionSummary(aggregatedStats, itemTypeString, sourceSide, targetSide)
    local stats = aggregatedStats 
    local substitutionActuallyFailed = (stats.failedNoMapping > 0 or stats.failedInvalidEquivalent > 0)
    local numFailedToMap = stats.failedNoMapping + stats.failedInvalidEquivalent
    stats.totalConsidered = stats.totalConsidered or 0
    stats.substituted = stats.substituted or 0
    stats.unchangedSameSide = stats.unchangedSameSide or 0
    stats.unchangedOther = stats.unchangedOther or 0
    stats.unchangedNotBuilding = stats.unchangedNotBuilding or 0
    local numSkippedOrUnchangedConsidered = stats.unchangedSameSide + stats.unchangedOther
    local message = string.format("%s processed from %s to %s. Items considered (buildings): %d, Substituted: %d, Failed to map: %d, Skipped/Unchanged (buildings): %d, Not buildings/commands: %d.",
        itemTypeString, sourceSide, targetSide, stats.totalConsidered, stats.substituted, 
        numFailedToMap, numSkippedOrUnchangedConsidered, stats.unchangedNotBuilding)
    if substitutionActuallyFailed then
        message = message .. string.format(" (FAIL - %d item(s) could not be mapped)", numFailedToMap)
    elseif stats.substituted > 0 then
        message = message .. " (OK)"
    elseif stats.totalConsidered > 0 then
        message = message .. string.format(" (No %s items substituted)", itemTypeString:lower())
    else
        message = message .. string.format(" (No relevant %s items to process for substitution)", itemTypeString:lower())
    end
    return message, substitutionActuallyFailed
end

function BlueprintSubLogic.getEquivalentUnitDefID(originalUnitDefID, targetSide)
    return _getActualSubstitutedUnitDefID(originalUnitDefID, targetSide)
end

function BlueprintSubLogic.processBlueprintSubstitution(originalBlueprint, targetSide)
    local sourceSide = originalBlueprint and originalBlueprint.sourceInfo and originalBlueprint.sourceInfo.primarySourceSide

    if not (originalBlueprint and originalBlueprint.units and targetSide and sourceSide) then
        Spring.Log("BlueprintSubLogic", LOG.ERROR, "processBlueprintSubstitution: Called with incomplete arguments (e.g., nil targetSide or sourceSide for a required substitution). Review caller logic.")
        local errorStats = {totalConsidered = 0, substituted = 0, failedNoMapping = 0, failedInvalidEquivalent = 0, unchangedSameSide = 0, unchangedOther = 0, unchangedNotBuilding = 0, hadMappingFailures = true}
        return { stats = errorStats, summaryMessage = "Internal error: Incomplete arguments for substitution.", substitutionFailed = true }
    end

    Spring.Log("BlueprintSubLogic", LOG.DEBUG, string.format("Processing blueprint substitution (in-place) from %s to %s for %d units.",
                                 tostring(sourceSide), tostring(targetSide), originalBlueprint and #originalBlueprint.units or 0))
    
    local aggregatedStats = {
        totalConsidered = 0, substituted = 0, failedNoMapping = 0, failedInvalidEquivalent = 0,
        unchangedSameSide = 0, unchangedOther = 0, unchangedNotBuilding = 0
    }
    for _, unit in ipairs(originalBlueprint.units) do
        local originalUnitDefID = unit.unitDefID
        if not (originalUnitDefID and originalUnitDefID > 0) then
            aggregatedStats.unchangedNotBuilding = aggregatedStats.unchangedNotBuilding + 1
        else
            aggregatedStats.totalConsidered = aggregatedStats.totalConsidered + 1
            local originalUnitDef = UnitDefs[originalUnitDefID]
            if not (originalUnitDef and originalUnitDef.name) then
                aggregatedStats.unchangedOther = aggregatedStats.unchangedOther + 1
            else
                local buildingData = BlueprintSubLogic.MasterBuildingData[originalUnitDef.name:lower()]
                if not buildingData then
                    aggregatedStats.unchangedOther = aggregatedStats.unchangedOther + 1
                else
                    local outcome = _getBuildingSubstitutionOutcome(originalUnitDefID, buildingData, targetSide, sourceSide)
                    unit.unitDefID = outcome.newUnitDefID 
                    if outcome.status == "substituted" then aggregatedStats.substituted = aggregatedStats.substituted + 1
                    elseif outcome.status == "failed_no_mapping" then aggregatedStats.failedNoMapping = aggregatedStats.failedNoMapping + 1
                    elseif outcome.status == "failed_invalid_equivalent" then aggregatedStats.failedInvalidEquivalent = aggregatedStats.failedInvalidEquivalent + 1
                    elseif outcome.status == "unchanged_same_side" then aggregatedStats.unchangedSameSide = aggregatedStats.unchangedSameSide + 1
                    else aggregatedStats.unchangedOther = aggregatedStats.unchangedOther + 1
                    end
                end
            end
        end
    end
    local summaryMsg, subFailed = _generateSubstitutionSummary(aggregatedStats, "Blueprint", sourceSide, targetSide)
    return { stats = aggregatedStats, summaryMessage = summaryMsg, substitutionFailed = subFailed }
end

function BlueprintSubLogic.processBuildQueueSubstitution(originalBuildQueue, sourceSide, targetSide)
    if not (originalBuildQueue and sourceSide and targetSide) then
        Spring.Log("BlueprintSubLogic", LOG.ERROR, "processBuildQueueSubstitution: Called with incomplete arguments (nil sourceSide or targetSide). Review caller logic.")
        local errorStats = {totalConsidered = 0, substituted = 0, failedNoMapping = 0, failedInvalidEquivalent = 0, unchangedSameSide = 0, unchangedOther = 0, unchangedNotBuilding = 0, hadMappingFailures = true}
        return { stats = errorStats, summaryMessage = "Internal error: Incomplete arguments for substitution.", substitutionFailed = true }
    end

    Spring.Log("BlueprintSubLogic", LOG.DEBUG, string.format("Processing build queue substitution (in-place) from %s to %s for %d items.",
                                 sourceSide, targetSide, #originalBuildQueue))
    
    local aggregatedStats = {
        totalConsidered = 0, substituted = 0, failedNoMapping = 0, failedInvalidEquivalent = 0,
        unchangedSameSide = 0, unchangedOther = 0, unchangedNotBuilding = 0
    }
    for _, bq_item in ipairs(originalBuildQueue) do
        if type(bq_item) == "table" and #bq_item >= 1 then
            local originalUnitDefID = bq_item[1]
            if originalUnitDefID and originalUnitDefID > 0 then
                aggregatedStats.totalConsidered = aggregatedStats.totalConsidered + 1
                local originalUnitDef = UnitDefs[originalUnitDefID]
                if originalUnitDef and originalUnitDef.name then
                    local buildingData = BlueprintSubLogic.MasterBuildingData[originalUnitDef.name:lower()]
                    if buildingData then
                        local outcome = _getBuildingSubstitutionOutcome(originalUnitDefID, buildingData, targetSide, sourceSide)
                        bq_item[1] = outcome.newUnitDefID 
                        if outcome.status == "substituted" then aggregatedStats.substituted = aggregatedStats.substituted + 1
                        elseif outcome.status == "failed_no_mapping" then aggregatedStats.failedNoMapping = aggregatedStats.failedNoMapping + 1
                        elseif outcome.status == "failed_invalid_equivalent" then aggregatedStats.failedInvalidEquivalent = aggregatedStats.failedInvalidEquivalent + 1
                        elseif outcome.status == "unchanged_same_side" then aggregatedStats.unchangedSameSide = aggregatedStats.unchangedSameSide + 1
                        else 
                            aggregatedStats.unchangedOther = aggregatedStats.unchangedOther + 1
                        end
                    else 
                        aggregatedStats.unchangedOther = aggregatedStats.unchangedOther + 1
                        Spring.Log("BlueprintSubLogic", LOG.DEBUG, string.format("processBuildQueueSubstitution: No MasterBuildingData for %s. Item not substituted.", originalUnitDef.name:lower()))
                    end
                else 
                    aggregatedStats.unchangedOther = aggregatedStats.unchangedOther + 1
                    Spring.Log("BlueprintSubLogic", LOG.DEBUG, string.format("processBuildQueueSubstitution: Item with DefID %s has no UnitDef or name. Item not substituted.", tostring(originalUnitDefID)))
                end
            else 
                aggregatedStats.unchangedNotBuilding = aggregatedStats.unchangedNotBuilding + 1
            end
        else 
            aggregatedStats.unchangedNotBuilding = aggregatedStats.unchangedNotBuilding + 1 
            Spring.Log("BlueprintSubLogic", LOG.WARNING, string.format("processBuildQueueSubstitution: Skipping malformed item: %s", tostring(bq_item)))
        end
    end
    local summaryMsg, subFailed = _generateSubstitutionSummary(aggregatedStats, "Build queue", sourceSide, targetSide)
    return { stats = aggregatedStats, summaryMessage = summaryMsg, substitutionFailed = subFailed }
end

return BlueprintSubLogic 