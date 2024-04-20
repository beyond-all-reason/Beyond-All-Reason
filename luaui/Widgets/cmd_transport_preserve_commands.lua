function widget:GetInfo()
	return {
		name    = "Preserve Commands",
		desc    = "Preserves a unit's command queue after it has been transported",
		author  = "Jazcash",
		date    = "October 2023",
		license = "idklmao",
		layer   = 0,
		enabled = true
	}
end

local orders = {}
local distToIgnore = 500 -- any initial commands outside of this distance from the unload point will be ignored, to stop units walking back to their origin

---------------------------------------------------------------

function widget:UnitLoaded(unitID)
	orders[unitID] = Spring.GetUnitCommands(unitID, -1)
end


function widget:UnitUnloaded(unitID)
	if (orders[unitID] and #orders[unitID]) then
		local newOrders = {}

		for i, command in ipairs(orders[unitID]) do
			if (#command.params >= 3) then
				local x, y, z = Spring.GetUnitPosition(unitID)
				local distFromCmd = math.distance3d(x, y, z, command.params[1], command.params[2], command.params[3])
				if (distFromCmd <= distToIgnore) then
					table.insert(newOrders, { command.id, command.params, command.options })
				end
			end
		end

		Spring.GiveOrderArrayToUnitArray({ unitID }, newOrders)

		orders[unitID] = nil
	end
end


---------------------------------------------------------------
--- Housekeeping to manage the widget state
---------------------------------------------------------------

local function maybeRemoveSelf()
	if Spring.IsReplay() or Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0) then
		widgetHandler:RemoveWidget()
	end
end

function widget:Initialize()
	maybeRemoveSelf()
end

function widget:GameStart()
	maybeRemoveSelf()
end

function widget:PlayerChanged()
	maybeRemoveSelf()
end

---------------------------------------------------------------
