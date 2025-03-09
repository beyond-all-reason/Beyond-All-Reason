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
	-- tax force enables this
	or (Spring.GetModOptions().tax_resource_sharing_amount or 0) ~= 0)
	-- unit market handles the restriction instead if enabled so that selling still works
	or Spring.GetModOptions().unit_market then
	return false
end


function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)

	if(capture) then
		return true
	end
	return false
end



