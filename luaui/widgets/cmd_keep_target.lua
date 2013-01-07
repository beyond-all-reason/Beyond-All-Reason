function widget:GetInfo()
  return {
    name      = "Keep Target",
    desc      = "Simple and slowest usage of target on the move",
    author    = "Google Frog",
    date      = "29 Sep 2011",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924

local function isValidType(ud)
	return ud and not (ud.isBomber or ud.isFactory)
end

function widget:CommandNotify(id, params, options)
    if id == CMD.SET_WANTED_MAX_SPEED then
        return false -- FUCK CMD.SET_WANTED_MAX_SPEED
    end
    if id == CMD.MOVE then
        local units = Spring.GetSelectedUnits()
        for i = 1, #units do
            local unitID = units[i]
			local unitDefID = Spring.GetUnitDefID(unitID)
			local ud = UnitDefs[unitDefID]
            if isValidType(ud) and Spring.ValidUnitID(unitID) then
                local cmd = Spring.GetCommandQueue(unitID, 1)
                if cmd and #cmd ~= 0 and cmd[1].id == CMD.ATTACK and #cmd[1].params == 1 and not cmd[1].options.internal then
					Spring.GiveOrderToUnit(unitID,CMD_UNIT_SET_TARGET,cmd[1].params,{})
                end
            end
        end
    elseif id ~= CMD_UNIT_SET_TARGET and id ~= CMD_UNIT_CANCEL_TARGET then
        local units = Spring.GetSelectedUnits()
        for i = 1, #units do
            local unitID = units[i]
            if isValidType(ud) and Spring.ValidUnitID(unitID) then
                Spring.GiveOrderToUnit(unitID,CMD_UNIT_CANCEL_TARGET,params,{})
            end
        end
    end
    return false
end