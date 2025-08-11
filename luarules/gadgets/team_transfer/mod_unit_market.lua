-- Mod Option: Unit Market
-- Default: false (disabled)
-- Requires: Marketplace buildings for validation
-- Status: Mostly done but needs performance/UX work

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "mod_unit_market", 
        desc      = "Unit marketplace restrictions and requirements",
        author    = "Floris",
        date      = "September 2023",
        license   = "GNU GPL, v2 or later",
        layer     = 1,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

-- Mod Options (read at gadget load time)
local isMarketEnabled = Spring.GetModOptions().unit_market == "enabled"

-- Early exit if market disabled
if not isMarketEnabled then
    return false
end

local spIsCheatingEnabled = Spring.IsCheatingEnabled

-- Market building tracking
local marketplaces = {}
local isMarketplaceUnit = {}

-- Initialize marketplace unit definitions
for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.customParams and unitDef.customParams.marketplace then
        isMarketplaceUnit[unitDefID] = true
    end
end

-- Initialize team marketplace counts
local teams = Spring.GetTeamList()
for i = 1, #teams do
    marketplaces[teams[i]] = 0
end

-- Market validation functions
local function ValidateMarketResourceTransfer(oldTeam, newTeam, resourceType, amount)
    -- Market requires both teams to have marketplace buildings
    if (marketplaces[oldTeam] > 0 and marketplaces[newTeam] > 0) or spIsCheatingEnabled() then
        return true
    end
    return false
end

local function ValidateMarketUnitTransfer(unitID, unitDefID, oldTeam, newTeam, reason)
    -- Only apply marketplace requirement to SOLD transfers
    if reason ~= GG.TeamTransfer.REASON.SOLD then
        return true
    end
    
    -- Seller must have a marketplace
    return (marketplaces[oldTeam] > 0) or spIsCheatingEnabled()
end

-- Unit tracking for marketplace buildings
function gadget:UnitFinished(unitID, unitDefID, unitTeam)
    if isMarketplaceUnit[unitDefID] then
        marketplaces[unitTeam] = marketplaces[unitTeam] + 1
        Spring.Log("TeamTransfer", LOG.DEBUG, 
            string.format("Team %d built marketplace (total: %d)", unitTeam, marketplaces[unitTeam]))
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
    if isMarketplaceUnit[unitDefID] then
        marketplaces[unitTeam] = math.max(0, marketplaces[unitTeam] - 1)
        Spring.Log("TeamTransfer", LOG.DEBUG,
            string.format("Team %d lost marketplace (total: %d)", unitTeam, marketplaces[unitTeam]))
    end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
    if isMarketplaceUnit[unitDefID] then
        marketplaces[oldTeam] = math.max(0, marketplaces[oldTeam] - 1)
        marketplaces[newTeam] = marketplaces[newTeam] + 1
        Spring.Log("TeamTransfer", LOG.DEBUG,
            string.format("Marketplace transferred: team %d->%d", oldTeam, newTeam))
    end
end

-- Market transform policies for the pipeline system
local function MarketResourceTransformPolicy(transfer)
    if transfer.blocked then return transfer end
    
    -- Apply marketplace requirement
    if not ValidateMarketResourceTransfer(transfer.srcTeam, transfer.dstTeam, transfer.resourceType, transfer.amount) then
        transfer.blocked = true
        transfer.blockReason = "Market policy: Both teams must have marketplace buildings"
        transfer.marketViolation = true
    else
        -- Add market metadata for other policies to use
        transfer.marketApproved = true
        transfer.srcMarketplaces = marketplaces[transfer.srcTeam]
        transfer.dstMarketplaces = marketplaces[transfer.dstTeam]
        
        -- Example: Market could apply fees based on tax information from earlier policies
        if transfer.taxApplied and transfer.taxAmount and transfer.taxAmount > 100 then
            -- High-tax transfers get a market processing fee
            local marketFee = transfer.taxAmount * 0.1 -- 10% of tax as processing fee
            transfer.marketFee = marketFee
            transfer.finalAmount = (transfer.finalAmount or transfer.amount) - marketFee
            
            Spring.Log("TeamTransfer", LOG.DEBUG, 
                string.format("Market fee applied: %.1f (based on tax: %.1f)", marketFee, transfer.taxAmount))
        end
    end
    
    return transfer
end

local function MarketUnitTransformPolicy(transfer)
    if transfer.blocked then return transfer end
    
    -- Apply marketplace requirement for SOLD units
    if not ValidateMarketUnitTransfer(transfer.unitID, transfer.unitDefID, transfer.oldTeam, transfer.newTeam, transfer.reason) then
        transfer.blocked = true
        transfer.blockReason = "Market policy: Seller must have marketplace building"
        transfer.marketViolation = true
    else
        -- Add market metadata
        transfer.marketApproved = true
        if transfer.reason == GG.TeamTransfer.REASON.SOLD then
            transfer.isSale = true
            transfer.sellerMarketplaces = marketplaces[transfer.oldTeam]
        end
    end
    
    return transfer
end

-- Implementation: Register transform policies with TeamTransfer system
function gadget:Initialize()
    -- Register market policies in the transform pipeline (priority 200 - runs after tax/security)
    GG.TeamTransfer.RegisterResourceTransformPolicy("Market", 200, MarketResourceTransformPolicy)
    GG.TeamTransfer.RegisterUnitTransformPolicy("Market", 200, MarketUnitTransformPolicy)
    
    -- Initialize existing marketplace buildings
    for _, unitID in pairs(Spring.GetAllUnits()) do
        local unitDefID = Spring.GetUnitDefID(unitID)
        local unitTeam = Spring.GetUnitTeam(unitID)
        if unitDefID and unitTeam then
            gadget:UnitFinished(unitID, unitDefID, unitTeam)
        end
    end
    
    Spring.Log("TeamTransfer", LOG.INFO, "Unit market pipeline policies enabled - marketplace buildings required for trading")
end
