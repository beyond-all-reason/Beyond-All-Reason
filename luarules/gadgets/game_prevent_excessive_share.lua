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
function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)
	-- Spring uses 'm' and 'e' instead of the full names that we need, so we need to convert the resourceType
	-- We also check for 'metal' or 'energy' incase Spring decides to use those in a later version
	local resourceName
	if (resourceType == 'm') or (resourceType == 'metal') then
		resourceName = 'metal'
	elseif (resourceType == 'e') or (resourceType == 'energy') then
		resourceName = 'energy'
	else
		-- We don't handle whatever this resource is, allow it
		return true
	end

	-- Calculate the maximum amount the receiver can receive
	local rCur, rStor, rPull, rInc, rExp, rShare = Spring.GetTeamResources(receiverTeamId, resourceName)
	local maxShare = rStor * rShare - rCur

	-- Is the sender trying to send more than the maximum? Block it, possibly sending a reduced amount instead
	if amount > maxShare then
		if maxShare > 0 then
			Spring.ShareTeamResource(senderTeamId, receiverTeamId, resourceName, maxShare)
		end
		return false
	end

	return true
end

function gadget:Initialize()
    if GG.TeamTransfer then
        GG.TeamTransfer.RegisterValidator("PreventExcessiveShare", function(unitID, unitDefID, oldTeam, newTeam, reason)
			-- Only validate sharing/transfer actions
            if not GG.TeamTransfer.IsTransferReason(reason) then
				return true
			end

			local unitCount = spGetTeamUnitCount(newTeam)
			if spIsCheatingEnabled() or unitCount < Spring.GetTeamMaxUnits(newTeam) then
				return true
			end
			return false
		end)
	end
end
