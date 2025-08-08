

local Resources = {}

function Resources.AllowResourceTransfer(oldTeam, newTeam, resourceType, amount)
    if not TeamTransfer.config.enabled then return true end
    if not TeamTransfer.config.allowResourceSharing then
        TeamTransfer.AddRefusal(oldTeam, "Resource sharing has been disabled")
        return false
    end
    if TeamTransfer.config.allowEnemyResourceSharing or Spring.AreTeamsAllied(oldTeam, newTeam) then
        return true
    end
    TeamTransfer.AddRefusal(oldTeam, "Cannot give resources to enemies")
    return false
end

function Resources.NetResourceTransfer(srcTeamID, dstTeamID, metalShare, energyShare)
    local any = false
    metalShare = tonumber(metalShare) or 0
    energyShare = tonumber(energyShare) or 0

    if metalShare > 0 then
        if Resources.AllowResourceTransfer(srcTeamID, dstTeamID, "metal", metalShare) then
            local _, mCurrent = Spring.GetTeamResources(srcTeamID, "metal")
            local amount = math.min(metalShare, mCurrent)
            if amount > 0 then
                Spring.ShareTeamResource(srcTeamID, dstTeamID, "metal", amount)
                any = true
            end
        end
    end
    if energyShare > 0 then
        if Resources.AllowResourceTransfer(srcTeamID, dstTeamID, "energy", energyShare) then
            local _, eCurrent = Spring.GetTeamResources(srcTeamID, "energy")
            local amount = math.min(energyShare, eCurrent)
            if amount > 0 then
                Spring.ShareTeamResource(srcTeamID, dstTeamID, "energy", amount)
                any = true
            end
        end
    end

    return any
end

function Resources.GiveEverythingTo(srcTeamID, dstTeamID)
    local any = false
    local mCur = select(1, Spring.GetTeamResources(srcTeamID, "metal")) or 0
    local eCur = select(1, Spring.GetTeamResources(srcTeamID, "energy")) or 0
    if mCur > 0 then
        if Resources.AllowResourceTransfer(srcTeamID, dstTeamID, "metal", mCur) then
            Spring.ShareTeamResource(srcTeamID, dstTeamID, "metal", mCur)
            any = true
        end
    end
    if eCur > 0 then
        if Resources.AllowResourceTransfer(srcTeamID, dstTeamID, "energy", eCur) then
            Spring.ShareTeamResource(srcTeamID, dstTeamID, "energy", eCur)
            any = true
        end
    end
    return any
end

return Resources