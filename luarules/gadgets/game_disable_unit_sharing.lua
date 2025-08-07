local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Disable Unit Sharing',
		desc    = 'Disable unit sharing when modoption is enabled',
		author  = 'Rimilel',
		date    = 'April 2024',
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

if not (Spring.GetModOptions().disable_unit_sharing
			-- unit market handles the restriction instead if enabled so that selling still works
			or Spring.GetModOptions().unit_market) then
	return false
end

function gadget:Initialize()
	-- Register with centralized transfer system
	if GG.BARTransfer then
		GG.BARTransfer.RegisterValidator("DisableUnitSharing", function(unitID, unitDefID, oldTeam, newTeam, reason)
			-- Block all sharing/transfer actions
			if GG.BARTransfer.IsTransferReason(reason) then
				return false
			end
			return true
		end)
	end
end

-- AllowUnitTransfer removed - validation now handled by centralized BARTransfer validator system
