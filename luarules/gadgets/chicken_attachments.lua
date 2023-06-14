function gadget:GetInfo()
    return {
        name = "Unit Attachments",
        desc = "Allows to attach structures to other structures, merging their healthbars",
        author = "Damgam",
        date = "2023",
        license = "GNU GPL, v2 or later",
        layer = 0,
        enabled = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local unitAttachments = {
    [UnitDefNames["chicken_hive"].id] = {
        { unitType = "chicken_antinuke",   posx = 0, posz = 0, dir = 0 },
    },
}

local deleteAttachments = {}
local unitAttachedTo = {}


function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID,
                               attackerDefID, attackerTeam)
    if unitAttachedTo[unitID] and (not paralyzer) then
        local h, mh = Spring.GetUnitHealth(unitAttachedTo[unitID])
        if h and mh then
            Spring.SetUnitHealth(unitAttachedTo[unitID], h - damage)
        end
        damage = 0
    end
    return damage, 1
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID)
    for attachment, attachedTo in pairs(unitAttachedTo) do
        if unitAttachedTo[attachment] == unitID then
            table.insert(deleteAttachments, attachment)
        end
    end
    if #deleteAttachments > 0 then
        for i = 1, #deleteAttachments do
            if deleteAttachments[i] then
                unitAttachedTo[deleteAttachments[i]] = nil
                Spring.DestroyUnit(deleteAttachments[i], false, true)
            end
        end
        deleteAttachments = {}
    end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if unitAttachments[unitDefID] then
        for i = 1, #unitAttachments[unitDefID] do
            local unitType = unitAttachments[unitDefID][i].unitType
            local posx = unitAttachments[unitDefID][i].posx
            local posz = unitAttachments[unitDefID][i].posz
            local dir = unitAttachments[unitDefID][i].dir or 0
            local bx, by, bz = Spring.GetUnitPosition(unitID)
            local attachmentID = Spring.CreateUnit(unitType, bx + posx, by, bz + posz, dir, unitTeam)
            if attachmentID then
                Spring.SetUnitBlocking(attachmentID, false, false)
                unitAttachedTo[attachmentID] = unitID
            end
        end
    end
end

function gadget:GameFrame(frame)
    for attachment, attachedTo in pairs(unitAttachedTo) do
        local h, mh = Spring.GetUnitHealth(attachedTo)
        if h and mh then
            Spring.SetUnitMaxHealth(attachment, mh)
            Spring.SetUnitHealth(attachment, h)
        end
    end
end
