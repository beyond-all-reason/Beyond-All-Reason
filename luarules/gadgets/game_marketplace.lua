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

function gadget:AllowResourceTransfer(oldTeam, newTeam, type, amount)
    if (marketplaces[oldTeam] > 0 and marketplaces[newTeam] > 0) or spIsCheatingEnabled() then
        return true
    end

    return false
end

function gadget:Initialize()
	-- Register with centralized transfer system
	if GG.BARTransfer then
		GG.BARTransfer.RegisterValidator("MarketplaceRequired", function(unitID, unitDefID, oldTeam, newTeam, reason)
			if oldTeam == newTeam then
				return true
			end

			-- Only validate sharing/transfer actions
			if not GG.BARTransfer.IsTransferReason(reason) then
				return true
			end

			if (marketplaces[oldTeam] > 0 and marketplaces[newTeam] > 0) or spIsCheatingEnabled() then
				return true
			end

			return false
		end)
	end
end


function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	if isMarketPlace[unitDefID] then
		marketplaces[teamID] = marketplaces[teamID] and marketplaces[teamID] - 1 or 0
	end
end
gadget.UnitTaken = gadget.UnitDestroyed

function gadget:UnitFinished(unitID, unitDefID, teamID)
	if isMarketPlace[unitDefID] then
		marketplaces[teamID] = marketplaces[teamID] and marketplaces[teamID] + 1 or 1
	end
end
gadget.UnitGiven = gadget.UnitFinished

function gadget:Initialize()
	for ct, unitID in pairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeam = Spring.GetUnitTeam(unitID)
		gadget:UnitFinished(unitID, unitDefID, unitTeam)
	end
end
