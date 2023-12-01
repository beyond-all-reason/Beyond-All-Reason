function widget:GetInfo()
    return {
        name	= "Preserve Commands After Transport",
        desc	= "Preserves a unit's build queue after it has been transported, ignores non-build commands",
        author  = "Jazcash",
        date 	= "October 2023",
        license	= "idklmao",
        layer 	= 0,
        enabled	= true
    }
end

local orders = {}

function widget:Initialize()
    if Spring.IsReplay() then
        widgetHandler:RemoveWidget()
    end
end

function widget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
    orders[unitID] = Spring.GetUnitCommands(unitID, -1)
end

function widget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
    if (orders[unitID] and #orders[unitID]) then
        local newOrders = {}
        local firstBuildCmd = false

        for i, command in ipairs(orders[unitID]) do
            if (command.id < 0 and firstBuildCmd == false) then
                firstBuildCmd = true
            end
            if (firstBuildCmd == true) then
                table.insert(newOrders, {command.id, command.params, command.options})
            end
        end

        Spring.GiveOrderArrayToUnitArray({ unitID }, newOrders)

        orders[unitID] = nil
    end
end
