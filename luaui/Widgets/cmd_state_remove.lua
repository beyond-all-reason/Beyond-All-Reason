local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "State Remover",
		desc      = "Removes 'return fire' and 'roam' states",
		author    = "Google Frog",
		date      = "Oct 2, 2009",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = false
	}
end

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitDefID = Spring.GetUnitDefID
local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_MOVE_STATE = CMD.MOVE_STATE

local excludedUnitsMovestate = {}
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.deathExplosion == "nanoboom" then	-- still nice to have on nanos so they will assist ally
		excludedUnitsMovestate[uDefID] = true
	end
end

function widget:CommandNotify(id, params, options)

	if id == CMD_FIRE_STATE then
		if params[1] == 1 then
			local units = spGetSelectedUnits()
			for i=1,#units do
				spGiveOrderToUnit(units[i], CMD_FIRE_STATE, { 2 }, 0)
			end
			return true
		end
	end

	if id == CMD_MOVE_STATE then
		if params[1] == 2 then
			local units = spGetSelectedUnits()
			for i=1, #units do
				if excludedUnitsMovestate[spGetUnitDefID(units[i])] == nil then
					spGiveOrderToUnit(units[i], CMD_MOVE_STATE, { 0 }, 0)
				else
					spGiveOrderToUnit(units[i], CMD_MOVE_STATE, { 2 }, 0)
				end
			end
			return true
		end
	end

end
