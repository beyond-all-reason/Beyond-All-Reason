
function ScenarioScript_GiveOrderToUnit(unitID, pat)

end


--[[local CMD_STOP = CMD.STOP
Spring.DestroyUnit(unitID, false, true)
function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
    if cmdID ~= CMD_STOP then return end
    if not unitID then return end
    if teamID ~= Spring.GetMyTeamID() then return end

    if (Spring.GetUnitSelfDTime(unitID) > 0) then
        Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, {})
    end 
end]]--
