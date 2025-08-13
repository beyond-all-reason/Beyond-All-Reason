local Resources = {}

-- Include dependencies
local Pipeline = VFS.Include("LuaRules/Gadgets/team_transfer/pipeline.lua")

-- Core resource transfer function that processes through pipeline
Resources.ProcessResourceTransfer = function(srcTeamID, dstTeamID, resourceType, amount, source)
    if amount <= 0 then return 0 end
    
    local transfer = {
        srcTeam = srcTeamID,
        dstTeam = dstTeamID,
        resourceType = resourceType,
        amount = amount,
        finalAmount = amount,
        blocked = false,
        source = source or "manual",
    }
    
    transfer = Pipeline.RunResourceTransformPipeline(transfer)
    
    if transfer.blocked then return 0 end
    
    local _, cur = Spring.GetTeamResources(srcTeamID, resourceType)
    local availableAmount = math.min(transfer.finalAmount, cur or 0)
    if availableAmount > 0 then
        Spring.ShareTeamResource(srcTeamID, dstTeamID, resourceType, availableAmount)
        return availableAmount
    end
    
    return 0
end

-- Simple transfer (external API)
Resources.TransferResource = function(oldTeam, newTeam, resourceType, amount)
    local transferredAmount = Resources.ProcessResourceTransfer(oldTeam, newTeam, resourceType, amount, "api")
    return transferredAmount > 0
end

-- Network transfer handler for engine (NETMSG_{SHARE,AISHARE})
-- Note: Notifications are handled externally by the API layer
Resources.NetResourceTransfer = function(srcTeamID, dstTeamID, metalShare, energyShare)
    local metalAmount = Resources.ProcessResourceTransfer(srcTeamID, dstTeamID, "metal", tonumber(metalShare) or 0, "network")
    local energyAmount = Resources.ProcessResourceTransfer(srcTeamID, dstTeamID, "energy", tonumber(energyShare) or 0, "network")
    
    return (metalAmount > 0) or (energyAmount > 0)
end

-- Move all resources from one team to another (used for GiveEverythingTo)
function Resources.GiveEverythingTo(srcTeamID, dstTeamID)
    local m = select(1, Spring.GetTeamResources(srcTeamID, "metal")) or 0
    local e = select(1, Spring.GetTeamResources(srcTeamID, "energy")) or 0
    if m > 0 and GG.TeamTransfer.ValidateResourceTransfer(srcTeamID, dstTeamID, "metal", m) then
        Spring.ShareTeamResource(srcTeamID, dstTeamID, "metal", m)
        GG.TeamTransfer.NotifyResourceTransfer(srcTeamID, dstTeamID, "metal", m)
    end
    if e > 0 and GG.TeamTransfer.ValidateResourceTransfer(srcTeamID, dstTeamID, "energy", e) then
        Spring.ShareTeamResource(srcTeamID, dstTeamID, "energy", e)
        GG.TeamTransfer.NotifyResourceTransfer(srcTeamID, dstTeamID, "energy", e)
    end
    return true
end


return Resources