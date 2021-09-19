
if isSynced then
    newgroup = {}
    function gadget:GameFrame(n)
        if n%120 == 30 then
            createdunit = Spring.CreateUnit("armpw", 1000,1000,1000,0,0)
            unitID = createdunit
            ScenarioScript_AddUnitToGroup(unitID, newgroup)
        end

        if n%120 == 90 then
            ScenarioScript_RemoveUnitFromGroup(unitID, newgroup)
        end

        --if n%120 == 119 then
            --ScenarioScript_ClearGroupUnits(newgroup)
        --end
	end
else
    
end