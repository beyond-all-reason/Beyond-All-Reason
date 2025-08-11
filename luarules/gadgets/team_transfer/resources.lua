local Resources = {}

-- Allow/gate resource transfers. Keep permissive by default; validators in other gadgets can block.
-- Deprecated: gating now via TeamTransfer.RegisterResourceValidator

-- Atomically handle resource shares from engine (NETMSG_{SHARE,AISHARE})
function Resources.NetResourceTransfer(srcTeamID, dstTeamID, metalShare, energyShare)
    local any = false
    local m = tonumber(metalShare) or 0
    local e = tonumber(energyShare) or 0

    if m > 0 and GG.TeamTransfer.ValidateResourceTransfer(srcTeamID, dstTeamID, "metal", m) then
        local _, cur = Spring.GetTeamResources(srcTeamID, "metal")
        local amt = math.min(m, cur or 0)
        if amt > 0 then
            Spring.ShareTeamResource(srcTeamID, dstTeamID, "metal", amt)
            GG.TeamTransfer.NotifyResourceTransfer(srcTeamID, dstTeamID, "metal", amt)
            any = true
        end
    end

    if e > 0 and GG.TeamTransfer.ValidateResourceTransfer(srcTeamID, dstTeamID, "energy", e) then
        local _, cur = Spring.GetTeamResources(srcTeamID, "energy")
        local amt = math.min(e, cur or 0)
        if amt > 0 then
            Spring.ShareTeamResource(srcTeamID, dstTeamID, "energy", amt)
            GG.TeamTransfer.NotifyResourceTransfer(srcTeamID, dstTeamID, "energy", amt)
            any = true
        end
    end

    return any
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

-- Simple single-resource transfer helper used by unified API
function Resources.TransferResource(oldTeam, newTeam, resourceType, amount)
    if amount <= 0 then return false end
    if not GG.TeamTransfer.ValidateResourceTransfer(oldTeam, newTeam, resourceType, amount) then return false end
    Spring.ShareTeamResource(oldTeam, newTeam, resourceType, amount)
    GG.TeamTransfer.NotifyResourceTransfer(oldTeam, newTeam, resourceType, amount)
    return true
end

return Resources