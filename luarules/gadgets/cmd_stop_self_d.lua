function gadget:GetInfo()
  return {
    name      = "Stop Self D",
    desc      = "Cancels Self D orders when unit is given a stop command",
    author    = "enotseulB",
    date      = "GPL v3 or later",
    license   = "Feb 2015",
    layer     = 0,
    enabled   = true  
  }
end

if (gadgetHandler:IsSyncedCode()) then

local CMD_STOP = CMD.STOP

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
    if cmdID~=CMD_STOP then return true end
    if not unitID then return true end

    if (Spring.GetUnitSelfDTime(unitID) > 0) then
        Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, {})
    end 
    return true
end

end