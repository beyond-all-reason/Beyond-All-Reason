local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Disable Unit Dancing',
		desc    = 'Disable unit dancing for increased immersion.',
		author  = 'uBdead',
		date    = 'Jun, 2025',
		license = 'GNU GPL, v2 or later',
		layer   = -1,
		enabled = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg == 'dancingDisabled' then
		--Spring.Echo("[Disable Unit Dancing] Unit dancing has been disabled.")
		GG.DancingDisabled = true
	elseif msg == 'dancingEnabled' then
		--Spring.Echo("[Disable Unit Dancing] Unit dancing has been re-enabled.")
		GG.DancingDisabled = false
	end
end
