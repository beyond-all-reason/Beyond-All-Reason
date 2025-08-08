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

if not gadgetHandler:IsSyncedCode() then
	return false
end

if not (Spring.GetModOptions().disable_unit_sharing
			or Spring.GetModOptions().unit_market) then
	return false
end

function gadget:Initialize()
    GG.TeamTransfer.RegisterValidator("DisableUnitSharing", function(unitID, unitDefID, oldTeam, newTeam, reason)
        -- Block all sharing/transfer actions
        if GG.TeamTransfer.IsTransferReason(reason) then
            return false
        end
        return true
    end)
end
