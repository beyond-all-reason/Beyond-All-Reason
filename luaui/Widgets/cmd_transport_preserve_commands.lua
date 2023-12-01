function widget:GetInfo()
    return {
        name	= "Preserve Commands",
        desc	= "Preserves a unit's command queue after it has been transported",
        author  = "Jazcash",
        date 	= "October 2023",
        license	= "idklmao",
        layer 	= 0,
        enabled	= false
    }
end

local orders = {}
local distToIgnore = 400 -- any initial commands outside of this distance from the unload point will be ignored, to stop units walking back to their origin

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
        local cmdInsideDist = false

        for i, command in ipairs(orders[unitID]) do
            if (#command.params >= 3) then
                local x, y, z = Spring.GetUnitPosition(unitID)
                local unloadedPos = { x = x, y = y, z = z }
                local cmdPos = { x = command.params[1], y = command.params[2], z = command.params[3] }
                local distFromCmd = distance(unloadedPos, cmdPos)
                if (distFromCmd <= distToIgnore) then
                    cmdInsideDist = true
                end
            end
            if (cmdInsideDist == true) then
                table.insert(newOrders, {command.id, command.params, command.options})
            end
        end

        Spring.GiveOrderArrayToUnitArray({ unitID }, newOrders)

        orders[unitID] = nil
    end
end

function distance(pos1, pos2)
	local xd = pos1.x - pos2.x
	local yd = pos1.z - pos2.z
	local dist = math.sqrt(xd*xd + yd*yd)
	return dist
end
