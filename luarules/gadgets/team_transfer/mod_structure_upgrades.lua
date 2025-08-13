-- Mod Option: Structure Upgrades (Mex and Geothermal)
-- Keep (Default) - Owner keeps ownership
-- Gift - Upgrader gets the structure
-- Sell - Upgrader automatically provides market-style transaction with cost

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "mod_structure_upgrade_ownership",
        desc      = "Structure upgrade ownership transfer policy for mex and geothermal",
        author    = "TeamTransfer System",
        date      = "2025", 
        license   = "GNU GPL, v2 or later",
        layer     = 3,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local function GetStructureUpgradeConfiguration()
    local modOptions = Spring.GetModOptions()
    return modOptions.structure_upgrade_ownership or modOptions.mex_upgrade_ownership or "keep"
end

local structureUpgradePolicy = GetStructureUpgradeConfiguration()

-- Early exit if using default keep behavior
if structureUpgradePolicy == "keep" then
    return false
end

-- Structure identification helpers using blueprint substitution system
local function IsMexUnit(unitDefID)
    -- Try blueprint bridge first, fallback to manual detection
    if GG.BlueprintCategories and GG.BlueprintCategories.IsMetalExtractor then
        local result = GG.BlueprintCategories.IsMetalExtractor(unitDefID)
        if result ~= nil then
            return result
        end
    end
    
    -- Fallback to manual detection
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return false end
    
    if unitDef.extractsMetal and unitDef.extractsMetal > 0 then
        return true
    end
    
    local categories = unitDef.category or ""
    if categories:find("MEX") or categories:find("METAL") then
        return true
    end
    
    return false
end

local function IsGeothermalUnit(unitDefID)
    -- Try blueprint bridge first, fallback to manual detection
    if GG.BlueprintCategories and GG.BlueprintCategories.IsGeothermal then
        local result = GG.BlueprintCategories.IsGeothermal(unitDefID)
        if result ~= nil then
            return result
        end
    end
    
    -- Fallback to manual detection
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return false end
    
    if unitDef.customParams and unitDef.customParams.geothermal then
        return true
    end
    
    if unitDef.needGeo then
        return true
    end
    
    return false
end

local function IsUpgradableStructure(unitDefID)
    return IsMexUnit(unitDefID) or IsGeothermalUnit(unitDefID)
end

local function GetStructureTier(unitDefID)
    -- Try blueprint bridge first, fallback to manual detection
    if GG.BlueprintCategories and GG.BlueprintCategories.GetUnitTier then
        local result = GG.BlueprintCategories.GetUnitTier(unitDefID)
        if result > 0 then
            return result
        end
    end
    
    -- Fallback to manual detection
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return 0 end
    
    if IsMexUnit(unitDefID) then
        local extractRate = unitDef.extractsMetal or 0
        if extractRate <= 2 then return 1 end
        if extractRate <= 4 then return 2 end
        return 3
    elseif IsGeothermalUnit(unitDefID) then
        local energyMake = unitDef.energyMake or 0
        local metalCost = unitDef.metalCost or 0
        
        if energyMake <= 25 or metalCost <= 500 then return 1 end
        return 2
    end
    
    return 0
end

local function GetStructureType(unitDefID)
    if IsMexUnit(unitDefID) then return "mex" end
    if IsGeothermalUnit(unitDefID) then return "geothermal" end
    return "unknown"
end

-- Upgrade tracking
local structureUpgradeData = {} -- [unitID] = {originalOwner, upgraderTeam, upgradeStartTime, structureType}

-- Structure upgrade event handlers
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if not IsUpgradableStructure(unitDefID) then return end
    
    local upgradeInfo = structureUpgradeData[unitID]
    if not upgradeInfo then return end
    
    -- Check if this was an upgrade (destroyer is a builder from different team)
    if attackerID and attackerTeam and attackerTeam ~= unitTeam then
        local attackerDef = attackerDefID and UnitDefs[attackerDefID]
        if attackerDef and attackerDef.isBuilder then
            -- This is an upgrade - handle according to policy
            HandleStructureUpgrade(unitID, unitDefID, unitTeam, attackerTeam, upgradeInfo)
        end
    end
    
    -- Clean up tracking data
    structureUpgradeData[unitID] = nil
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if not IsUpgradableStructure(unitDefID) then return end
    
    -- Track structure creation for upgrade detection
    local structureType = GetStructureType(unitDefID)
    structureUpgradeData[unitID] = {
        originalOwner = unitTeam,
        upgraderTeam = nil,
        upgradeStartTime = Spring.GetGameFrame(),
        structureType = structureType
    }
end

-- Structure upgrade policy implementation
function HandleStructureUpgrade(oldStructureID, oldStructureDefID, originalTeam, upgraderTeam, upgradeInfo)
    local structureType = upgradeInfo.structureType or GetStructureType(oldStructureDefID)
    
    if structureUpgradePolicy == "gift" then
        -- Transfer new structure to upgrader (handled by existing upgrade reclaimer gadgets)
        Spring.Log("TeamTransfer", LOG.INFO, 
            string.format("%s upgrade: team %d -> %d (GIFT policy)", structureType, originalTeam, upgraderTeam))
        
    elseif structureUpgradePolicy == "sell" then
        -- Calculate market-style cost and transfer resources
        local structureValue = CalculateStructureValue(oldStructureDefID)
        if structureValue > 0 then
            -- Deduct cost from upgrader, give to original owner
            local upgradeMetal = select(1, Spring.GetTeamResources(upgraderTeam, "metal"))
            local costToPay = math.min(structureValue, upgradeMetal)
            
            if costToPay > 0 then
                Spring.ShareTeamResource(upgraderTeam, originalTeam, "metal", costToPay)
                Spring.Log("TeamTransfer", LOG.INFO,
                    string.format("%s upgrade: team %d paid %d metal to team %d (SELL policy)", 
                        structureType, upgraderTeam, costToPay, originalTeam))
            end
        end
        
    elseif structureUpgradePolicy == "keep" then
        -- Original owner keeps the structure (default behavior)
        Spring.Log("TeamTransfer", LOG.DEBUG,
            string.format("%s upgrade: ownership kept by team %d (KEEP policy)", structureType, originalTeam))
    end
end

function CalculateStructureValue(structureDefID)
    local structureDef = UnitDefs[structureDefID]
    if not structureDef then return 0 end
    
    local baseCost = structureDef.metalCost or 0
    
    if IsMexUnit(structureDefID) then
        -- Mex value: base cost + extraction rate factor
        local extractRate = structureDef.extractsMetal or 0
        return baseCost + (extractRate * 100)
    elseif IsGeothermalUnit(structureDefID) then
        local energyMake = structureDef.energyMake or 0
        return baseCost + (energyMake * 10)
    end
    
    return baseCost
end

local function OnStructureUpgraded(unitID, unitDefID, oldTeam, newTeam)
    if not IsUpgradableStructure(unitDefID) then return end
    
    local upgradeInfo = structureUpgradeData[unitID]
    if upgradeInfo and upgradeInfo.originalOwner ~= newTeam then
        -- This structure was transferred - apply policy retroactively if needed
        if structureUpgradePolicy == "keep" and newTeam ~= upgradeInfo.originalOwner then
            -- Transfer back to original owner
            GG.TeamTransfer.TransferUnit(unitID, upgradeInfo.originalOwner, GG.TeamTransfer.REASON.UPGRADED)
        end
    end
end

-- Implementation: Register listener with TeamTransfer system
function gadget:Initialize()
    -- Register listener for structure transfers
    GG.TeamTransfer.RegisterUnitListener("StructureUpgrade_Policy", OnStructureUpgraded)
    
    local usingBlueprintBridge = GG.BlueprintCategories and GG.BlueprintCategories.IsMetalExtractor
    Spring.Log("TeamTransfer", LOG.INFO, "Structure upgrade ownership policy: " .. structureUpgradePolicy .. 
        (usingBlueprintBridge and " (using blueprint bridge)" or " (using fallback detection)"))
    
    -- Initialize tracking for existing structures
    for _, unitID in pairs(Spring.GetAllUnits()) do
        local unitDefID = Spring.GetUnitDefID(unitID)
        local unitTeam = Spring.GetUnitTeam(unitID)
        if unitDefID and unitTeam and IsUpgradableStructure(unitDefID) then
            gadget:UnitCreated(unitID, unitDefID, unitTeam, nil)
        end
    end
end

function gadget:Shutdown()
    GG.TeamTransfer.UnregisterUnitListener("StructureUpgrade_Policy")
end
