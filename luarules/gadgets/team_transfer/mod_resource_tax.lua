-- Mod Options: Resource Sharing Tax & Player Metal Send Threshold
-- Resource Sharing Tax (0-100): Applied to manual + auto overflow
-- Player Metal Send Threshold: Reduces tax for small amounts (friendship modifier)

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "mod_resource_tax_and_threshold",
        desc      = "Resource sharing tax with friendship threshold modifiers",
        author    = "Rimilel",
        date      = "April 2024", 
        license   = "GNU GPL, v2 or later",
        layer     = 1,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

-- Mod Options (read at gadget load time)
local baseTaxRate = Spring.GetModOptions().tax_resource_sharing_amount or 0
local metalThreshold = Spring.GetModOptions().player_metal_send_threshold or 0
local energyThreshold = Spring.GetModOptions().player_energy_send_threshold or 0

-- Early exit if no tax configured
if baseTaxRate == 0 then
    return false
end

local spIsCheatingEnabled = Spring.IsCheatingEnabled
local spGetTeamUnitCount = Spring.GetTeamUnitCount

-- Tax calculation with friendship threshold
local function CalculateEffectiveTax(amount, resourceType)
    local threshold = (resourceType == "metal") and metalThreshold or energyThreshold
    
    if threshold > 0 and amount <= threshold then
        -- Friendship modifier: half tax for small amounts
        return baseTaxRate * 0.5
    end
    
    return baseTaxRate
end

-- Resource tax validation (currently just logs, actual tax applied in teammates.lua)
local function ValidateResourceTax(oldTeam, newTeam, resourceType, amount)
    local effectiveTax = CalculateEffectiveTax(amount, resourceType)
    
    if effectiveTax > 0 then
        Spring.Log("TeamTransfer", LOG.DEBUG, 
            string.format("Resource transfer: %s %.1f from team %d to %d (tax: %.1f%%)", 
                resourceType, amount, oldTeam, newTeam, effectiveTax * 100))
    end
    
    return true -- Always allow, just log tax info
end

-- Command restrictions related to tax policy
function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
    -- Disallow reclaiming allied units for metal (prevents tax avoidance)
    if (cmdID == CMD.RECLAIM and #cmdParams >= 1) then
        local targetID = cmdParams[1]
        if targetID >= Game.maxUnits then
            return true
        end
        
        local targetTeam = Spring.GetUnitTeam(targetID)
        if unitTeam ~= targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
            return false
        end
    -- Also block guarding allied units that can reclaim
    elseif (cmdID == CMD.GUARD and #cmdParams >= 1) then
        local targetID = cmdParams[1]
        local targetTeam = Spring.GetUnitTeam(targetID)
        local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]

        if (unitTeam ~= targetTeam) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
            -- Block guarding allied reclaimers to prevent tax circumvention
            if targetUnitDef and targetUnitDef.canReclaim then
                return false
            end
        end
    end
    return true
end

-- Tax transform policy for the pipeline system
local function TaxTransformPolicy(transfer)
    if transfer.blocked then return transfer end
    
    local effectiveTax = CalculateEffectiveTax(transfer.amount, transfer.resourceType)
    
    -- Add tax metadata to transfer object
    transfer.effectiveTax = effectiveTax
    transfer.taxAmount = transfer.amount * effectiveTax
    transfer.finalAmount = transfer.amount * (1 - effectiveTax)
    transfer.taxApplied = true
    
    -- Add threshold information for other policies
    local threshold = (transfer.resourceType == "metal") and metalThreshold or energyThreshold
    transfer.belowThreshold = transfer.amount <= threshold
    transfer.friendshipBonus = transfer.belowThreshold and effectiveTax < baseTaxRate
    
    return transfer
end

-- Implementation: Register transform policy in the pipeline
function gadget:Initialize()
    -- Register tax policy in the transform pipeline (priority 100 - runs early)
    GG.TeamTransfer.RegisterResourceTransformPolicy("ResourceTax", 100, TaxTransformPolicy)
    
    -- Keep compatibility functions for teammates.lua
    GG.TeamTransfer.CalculateEffectiveTax = CalculateEffectiveTax
    GG.TeamTransfer.GetBaseTaxRate = function() return baseTaxRate end
    GG.TeamTransfer.GetThresholds = function() return metalThreshold, energyThreshold end
    
    Spring.Log("TeamTransfer", LOG.INFO, 
        string.format("Resource tax pipeline policy: %.1f%% (thresholds: metal=%.0f, energy=%.0f)", 
            baseTaxRate * 100, metalThreshold, energyThreshold))
end
