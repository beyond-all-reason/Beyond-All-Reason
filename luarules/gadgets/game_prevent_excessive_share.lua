
function gadget:GetInfo()
	return {
		name      = 'Prevent Excessive Share',
		desc      = 'Prevents sharing more resources than the receiver can hold',
		author    = 'Niobium',
		date      = 'April 2012',
		license   = 'GNU GPL, v2 or later',
		layer     = 0,
		enabled   = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

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
    
    -- Allow anything we don't explictly block
    return true
end
