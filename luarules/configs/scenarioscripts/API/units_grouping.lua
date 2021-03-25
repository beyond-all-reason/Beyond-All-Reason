

function ScenarioScript_AddUnitToGroup(unitID, groupname)
    if groupname then
        table.insert(groupname, unitID)
        Spring.Echo("Added Unit: "..unitID.." to group")
    else
        Spring.Echo("Failed to add unit, invalid group")
    end
end

function ScenarioScript_RemoveUnitFromGroup(unitID, groupname)
    for i = 1,#groupname do
        if groupname[i] == unitID then
            table.remove(groupname, j)
            removedunitfromgroup = true
        end
        if removedunitfromgroup then
            Spring.Echo("Removed Unit: "..unitID.." from group")
            break
        else
            Spring.Echo("Failed to remove unit from group, no such unit located in that group")
        end
    end
end

function ScenarioScript_ClearGroupUnits(groupname)
    groupname = {}
    Spring.Echo("Cleared unit group")
end


function ScenarioScript_GiveOrderToGroup(groupname)
    Spring.Echo("SoonTM")
end