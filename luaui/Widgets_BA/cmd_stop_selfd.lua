function widget:GetInfo()
  return {
    name      = "Stop means Stop",
    desc      = "Cancels Self D orders when unit is given a stop command",
    author    = "enotseulB",
    date      = "GPL v3 or later",
    license   = "Feb 2015",
    layer     = 0,
    enabled   = true  
  }
end

local CMD_STOP = CMD.STOP

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    if cmdID ~= CMD_STOP then return end
    if not unitID then return end
    if teamID ~= Spring.GetMyTeamID() then return end

    if (Spring.GetUnitSelfDTime(unitID) > 0) then
        Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, {})
    end 
end