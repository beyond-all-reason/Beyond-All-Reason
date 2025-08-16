local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Prevent Excessive Share',
		desc    = 'Prevents sharing more resources or units than the receiver can hold',
		author  = 'Niobium',
		date    = 'April 2012',
		license = 'GNU GPL, v2 or later',
		layer   = 2, -- after 'Tax Resource Sharing'
		enabled = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

local spIsCheatingEnabled = Spring.IsCheatingEnabled
local spGetTeamUnitCount = Spring.GetTeamUnitCount

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
-- Deprecated: centralized in TeamTransfer resource validators/processors

function gadget:Initialize()
    GG.TeamTransfer.RegisterResourceTransferProcessor("PreventExcessiveShare/ClampToMax", function(senderTeamId, receiverTeamId, resourceType, amount)
        local resourceName = (resourceType == 'm' or resourceType == 'metal') and 'metal' or ((resourceType == 'e' or resourceType == 'energy') and 'energy' or nil)
        if not resourceName then return amount end
        local rCur, rStor, _, _, _, rShare = Spring.GetTeamResources(receiverTeamId, resourceName)
        local maxShare = rStor * rShare - rCur
        return math.max(0, math.min(amount, maxShare))
    end)
end
