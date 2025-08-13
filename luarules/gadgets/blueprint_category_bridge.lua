local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name = "Blueprint Category Bridge",
        desc = "Provides blueprint category data to synced gadgets",
        author = "TeamTransfer System",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = 1,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local categoryCache = {}

local function QueryBlueprintCategory(unitDefID, queryType)
    if not unitDefID then return nil end
    
    local cached = categoryCache[unitDefID]
    if cached and cached[queryType] ~= nil then
        return cached[queryType]
    end
    
    SendToUnsynced("blueprint_category_query", unitDefID, queryType)
    
    return nil
end

local function HandleCategoryResult(unitDefID, queryType, result)
    if not unitDefID then return end
    
    if not categoryCache[unitDefID] then
        categoryCache[unitDefID] = {}
    end
    
    categoryCache[unitDefID][queryType] = result
end

local function IsMetalExtractor(unitDefID)
    local cached = categoryCache[unitDefID] and categoryCache[unitDefID]["isMetalExtractor"]
    if cached ~= nil then
        return cached
    end
    
    QueryBlueprintCategory(unitDefID, "isMetalExtractor")
    return nil
end

local function IsGeothermal(unitDefID)
    local cached = categoryCache[unitDefID] and categoryCache[unitDefID]["isGeothermal"]
    if cached ~= nil then
        return cached
    end
    
    QueryBlueprintCategory(unitDefID, "isGeothermal")
    return nil
end

local function GetUnitTier(unitDefID)
    local cached = categoryCache[unitDefID] and categoryCache[unitDefID]["getUnitTier"]
    if cached ~= nil then
        return cached
    end
    
    QueryBlueprintCategory(unitDefID, "getUnitTier")
    return 0
end

function gadget:Initialize()
    gadgetHandler:RegisterGlobal("blueprint_category_result", HandleCategoryResult)
    
    GG.BlueprintCategories = {
        IsMetalExtractor = IsMetalExtractor,
        IsGeothermal = IsGeothermal,
        GetUnitTier = GetUnitTier,
        QueryCategory = QueryBlueprintCategory
    }
    
    Spring.Log("BlueprintBridge", LOG.INFO, "Blueprint category bridge initialized")
end

function gadget:Shutdown()
    gadgetHandler:DeregisterGlobal("blueprint_category_result")
    GG.BlueprintCategories = nil
end
