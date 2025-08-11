-- Mod Option: T2 Mex Upgrades
-- Keep (Default) - Owner keeps ownership
-- Gift - Upgrader gets the mex
-- Sell - Upgrader automatically provides market-style transaction with cost
-- TODO: Integrate with unit_mex_upgrade_reclaimer.lua logic

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "mod_mex_upgrade_ownership",
        desc      = "Mex upgrade ownership transfer policy",
        author    = "TBD",
        date      = "2024", 
        license   = "GNU GPL, v2 or later",
        layer     = 3,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

-- Mod Options (read at gadget load time)
local mexUpgradePolicy = Spring.GetModOptions().mex_upgrade_ownership or "keep"

-- Early exit if using default keep behavior
if mexUpgradePolicy == "keep" then
    return false
end

-- Mex identification helpers
local function IsMexUnit(unitDefID)
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return false end
    
    -- Check if unit extracts metal
    if unitDef.extractsMetal and unitDef.extractsMetal > 0 then
        return true
    end
    
    -- Check category
    local categories = unitDef.category or ""
    if categories:find("MEX") or categories:find("METAL") then
        return true
    end
    
    return false
end

local function GetMexTier(unitDefID)
    local unitDef = UnitDefs[unitDefID]
    if not unitDef then return 0 end
    
    -- Simple heuristic: higher extraction rate = higher tier
    local extractRate = unitDef.extractsMetal or 0
    if extractRate <= 2 then return 1 end
    if extractRate <= 4 then return 2 end
    return 3
end

-- Upgrade tracking
local mexUpgradeData = {} -- [unitID] = {originalOwner, upgraderTeam, upgradeStartTime}

-- Mex upgrade event handlers
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    if not IsMexUnit(unitDefID) then return end
    
    local upgradeInfo = mexUpgradeData[unitID]
    if not upgradeInfo then return end
    
    -- Check if this was an upgrade (destroyer is a builder from different team)
    if attackerID and attackerTeam and attackerTeam ~= unitTeam then
        local attackerDef = attackerDefID and UnitDefs[attackerDefID]
        if attackerDef and attackerDef.isBuilder then
            -- This is an upgrade - handle according to policy
            HandleMexUpgrade(unitID, unitDefID, unitTeam, attackerTeam, upgradeInfo)
        end
    end
    
    -- Clean up tracking data
    mexUpgradeData[unitID] = nil
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    if not IsMexUnit(unitDefID) then return end
    
    -- Track mex creation for upgrade detection
    mexUpgradeData[unitID] = {
        originalOwner = unitTeam,
        upgraderTeam = nil,
        upgradeStartTime = Spring.GetGameFrame()
    }
end

-- Mex upgrade policy implementation
function HandleMexUpgrade(oldMexID, oldMexDefID, originalTeam, upgraderTeam, upgradeInfo)
    if mexUpgradePolicy == "gift" then
        -- Transfer new mex to upgrader (handled by existing unit_mex_upgrade_reclaimer.lua)
        Spring.Log("TeamTransfer", LOG.INFO, 
            string.format("Mex upgrade: team %d -> %d (GIFT policy)", originalTeam, upgraderTeam))
        
    elseif mexUpgradePolicy == "sell" then
        -- Calculate market-style cost and transfer resources
        local mexValue = CalculateMexValue(oldMexDefID)
        if mexValue > 0 then
            -- Deduct cost from upgrader, give to original owner
            local upgradeMetal = select(1, Spring.GetTeamResources(upgraderTeam, "metal"))
            local costToPay = math.min(mexValue, upgradeMetal)
            
            if costToPay > 0 then
                Spring.ShareTeamResource(upgraderTeam, originalTeam, "metal", costToPay)
                Spring.Log("TeamTransfer", LOG.INFO,
                    string.format("Mex upgrade: team %d paid %d metal to team %d (SELL policy)", 
                        upgraderTeam, costToPay, originalTeam))
            end
        end
        
    elseif mexUpgradePolicy == "keep" then
        -- Original owner keeps the mex (default behavior)
        Spring.Log("TeamTransfer", LOG.DEBUG,
            string.format("Mex upgrade: ownership kept by team %d (KEEP policy)", originalTeam))
    end
end

function CalculateMexValue(mexDefID)
    local mexDef = UnitDefs[mexDefID]
    if not mexDef then return 0 end
    
    -- Simple value calculation: base cost + extraction rate factor
    local baseCost = mexDef.metalCost or 0
    local extractRate = mexDef.extractsMetal or 0
    
    return baseCost + (extractRate * 100) -- Rough approximation
end

-- Mex upgrade listener for new mexes
local function OnMexUpgraded(unitID, unitDefID, oldTeam, newTeam)
    if not IsMexUnit(unitDefID) then return end
    
    local upgradeInfo = mexUpgradeData[unitID]
    if upgradeInfo and upgradeInfo.originalOwner ~= newTeam then
        -- This mex was transferred - apply policy retroactively if needed
        if mexUpgradePolicy == "keep" and newTeam ~= upgradeInfo.originalOwner then
            -- Transfer back to original owner
            GG.TeamTransfer.TransferUnit(unitID, upgradeInfo.originalOwner, GG.TeamTransfer.REASON.UPGRADED)
        end
    end
end

-- Implementation: Register listener with TeamTransfer system
function gadget:Initialize()
    -- Register listener for mex transfers
    GG.TeamTransfer.RegisterUnitListener("MexUpgrade_Policy", OnMexUpgraded)
    
    Spring.Log("TeamTransfer", LOG.INFO, "Mex upgrade ownership policy: " .. mexUpgradePolicy)
    
    -- Initialize tracking for existing mexes
    for _, unitID in pairs(Spring.GetAllUnits()) do
        local unitDefID = Spring.GetUnitDefID(unitID)
        local unitTeam = Spring.GetUnitTeam(unitID)
        if unitDefID and unitTeam and IsMexUnit(unitDefID) then
            gadget:UnitCreated(unitID, unitDefID, unitTeam, nil)
        end
    end
end

function gadget:Shutdown()
    GG.TeamTransfer.UnregisterUnitListener("MexUpgrade_Policy")
end
