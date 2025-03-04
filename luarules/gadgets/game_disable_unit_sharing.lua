function gadget:GetInfo()
	return {
		name    = 'Unit Sharing Control',
		desc    = 'Controls unit sharing based on modoption settings',
		author  = 'Rimilel',
		date    = 'May 2024',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

local unitSharingMode = Spring.GetModOptions().unit_sharing_mode or "enabled"
local unitMarketEnabled = Spring.GetModOptions().unit_market

-- If unit sharing is fully enabled and unit market isn't handling restrictions, disable this gadget
if unitSharingMode == "enabled" and not unitMarketEnabled then
	return false
end

local function isT2Constructor(unitDef)
	if not unitDef then return false end

	return not unitDef.isFactory
			and #(unitDef.buildOptions or {}) > 0
			and unitDef.customParams.techlevel == "2"
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	-- Always allow capture
	if capture then
		return true
	end

	-- If unit market is handling this unit, allow the transfer
	if unitMarketEnabled then
		if Spring.GetUnitRulesParam(unitID, "unitPrice") then
			return true
		end
	end

	-- Check sharing mode
	if unitSharingMode == "disabled" then
		return false
	elseif unitSharingMode == "t2cons_only" then
		return isT2Constructor(UnitDefs[unitDefID])
	end

	return true
end
