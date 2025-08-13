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

-- Configuration will be accessed through pipeline system
local function GetTaxConfiguration()
    local modOptions = Spring.GetModOptions()
    return {
        baseTaxRate = modOptions.tax_resource_sharing_amount or 0,
        metalThreshold = modOptions.player_metal_send_threshold or 0,
        energyThreshold = modOptions.player_energy_send_threshold or 0
    }
end

local config = GetTaxConfiguration()

-- Early exit if no tax configured
if config.baseTaxRate == 0 then
    return false
end

local spIsCheatingEnabled = Spring.IsCheatingEnabled
local spGetTeamUnitCount = Spring.GetTeamUnitCount

-- Tax calculation with friendship threshold
local function CalculateEffectiveTax(amount, resourceType)
    local threshold = (resourceType == "metal") and config.metalThreshold or config.energyThreshold
    
    if threshold > 0 and amount <= threshold then
        -- Friendship modifier: half tax for small amounts
        return config.baseTaxRate * 0.5
    end
    
    return config.baseTaxRate
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
    local threshold = (transfer.resourceType == "metal") and config.metalThreshold or config.energyThreshold
    transfer.belowThreshold = transfer.amount <= threshold
    transfer.friendshipBonus = transfer.belowThreshold and effectiveTax < config.baseTaxRate
    
    return transfer
end

function gadget:Initialize()
    GG.TeamTransfer.RegisterResourceTransformPolicy("ResourceTax", 100, TaxTransformPolicy)
    
    GG.TeamTransfer.CalculateEffectiveTax = CalculateEffectiveTax
    GG.TeamTransfer.GetBaseTaxRate = function() return config.baseTaxRate end
    GG.TeamTransfer.GetThresholds = function() return config.metalThreshold, config.energyThreshold end
    
    Spring.Log("TeamTransfer", LOG.INFO, 
        string.format("Resource tax pipeline policy: %.1f%% (thresholds: metal=%.0f, energy=%.0f)", 
            config.baseTaxRate * 100, config.metalThreshold, config.energyThreshold))
end
