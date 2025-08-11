if Spring.GetModOptions().marketplace ~= "enabled" then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "marketplaces",
        desc      = "restrict resource sharing unless both parties involved have a marktplace type unit",
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

local spIsCheatingEnabled = Spring.IsCheatingEnabled

local marketplaces = {}

local isMarketPlace = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.marketplace and unitDef.customParams.marketplace then
		isMarketPlace[unitDefID] = true
	end
end

local teams = Spring.GetTeamList()
for i=1,#teams do
	marketplaces[teams[i]] = 0
end

-- Deprecated: centralized in TeamTransfer resource validators

function gadget:Initialize()
    -- Resource sharing requires both sides to have a marketplace
    GG.TeamTransfer.RegisterResourceValidator("MarketplaceRequired", function(oldTeam, newTeam, resourceType, amount)
        if (marketplaces[oldTeam] > 0 and marketplaces[newTeam] > 0) or spIsCheatingEnabled() then
            return true
        end
        return false
    end)

    -- Prevent SOLD unit transfers unless seller has a marketplace (example unit-side validator)
    GG.TeamTransfer.RegisterUnitValidator("MarketplaceRequiredForSold", function(unitID, unitDefID, oldTeam, newTeam, reason)
        if reason ~= GG.TeamTransfer.REASON.SOLD then return true end
        return (marketplaces[oldTeam] > 0) or spIsCheatingEnabled()
    end)

	for ct, unitID in pairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeam = Spring.GetUnitTeam(unitID)
		gadget:UnitFinished(unitID, unitDefID, unitTeam)
	end
end
