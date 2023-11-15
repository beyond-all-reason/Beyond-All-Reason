function widget:GetInfo()
    return {
        name	= "Preserve Commands",
        desc	= "Preserves a unit's command queue after it has been transported",
        author  = "Jazcash",
        date 	= "October 2023",
        license	= "idklmao",
        layer 	= 0,
        enabled	= true
    }
end

local orders = {}
local ignoreInitialMoveCommands = true

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
        local noMoreInitialMoveCommands = false

        for i, command in ipairs(orders[unitID]) do
            if (noMoreInitialMoveCommands == false and command.id ~= CMD.MOVE) then
                noMoreInitialMoveCommands = true
            end
            if (ignoreInitialMoveCommands == false or (ignoreInitialMoveCommands and noMoreInitialMoveCommands)) then
                newOrders[i] = {command.id, command.params, command.options}
            end
        end

        Spring.GiveOrderArrayToUnitArray({ unitID }, newOrders)

        orders[unitID] = nil
    end
end
