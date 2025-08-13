local gadget = gadget

function gadget:GetInfo()
    return {
        name      = "TeamTransfer Reclaim Income Tax",
        desc      = "Applies tax to reclaim income from allied sources",
        author    = "TeamTransfer System",
        date      = "2024",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local baseTaxRate = 0.25
local metalThreshold = 1000
local energyThreshold = 5000

local function CalculateEffectiveTax(amount, threshold)
    if amount <= threshold then
        return 0
    end
    
    local taxableAmount = amount - threshold
    return taxableAmount * baseTaxRate
end

local function TaxReclaimIncomePolicy(income)
    if income.reclaimingTeam == income.sourceTeam then
        return income
    end
    
    if not Spring.AreTeamsAllied(income.reclaimingTeam, income.sourceTeam) then
        return income
    end
    
    local threshold = (income.resourceType == 0) and metalThreshold or energyThreshold
    local taxAmount = CalculateEffectiveTax(income.amount, threshold)
    
    if taxAmount > 0 then
        income.finalAmount = income.amount - taxAmount
        income.taxAmount = taxAmount
        
        local resourceName = (income.resourceType == 0) and "metal" or "energy"
        Spring.Log("TeamTransfer", LOG.INFO, 
            string.format("Applied %.1f%% tax to %s reclaim: %.1f -> %.1f (tax: %.1f)", 
                baseTaxRate * 100, resourceName, income.amount, income.finalAmount, taxAmount))
    end
    
    return income
end

function gadget:Initialize()
    GG.ReclaimIncome.RegisterIncomeTransformPolicy("ReclaimTax", 100, TaxReclaimIncomePolicy)
    
    Spring.Log("TeamTransfer", LOG.INFO, 
        string.format("Reclaim income tax policy: %.1f%% (thresholds: metal=%.0f, energy=%.0f)", 
            baseTaxRate * 100, metalThreshold, energyThreshold))
end
