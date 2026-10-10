local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function reclaimUnits(unitName, reclaimerTeam)
    local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

    -- Copying table as UnitKilled trigger with SpawnUnits with the same name could cause infinite loop.
    local trackedUnitIDs = table.copy(GG['MissionAPI'].trackedUnitIDs[unitName])
	for unitID in pairs(trackedUnitIDs) do
        if Spring.GetUnitIsDead(unitID) == false then
            if not reclaimerTeam then
                reclaimerTeam = Spring.GetUnitTeam(unitID)
            end
            local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
            Spring.AddTeamResource(reclaimerTeam, "metal", unitDef.metalCost) 
            -- We don't give energy from reclaims, but putting it here just in case someone needs it later.
            -- Spring.AddTeamResource(reclaimerTeam, "energy", unitDef.energyCost)
            GG['MissionAPI'].reclaimingUnits = true
            Spring.DestroyUnit(unitID, false, true)
            GG['MissionAPI'].reclaimingUnits = nil
        end
	end
end

return {
    {
	    type = 'ReclaimUnits',
	    parameters = {
	    	{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
	    	{ name = 'reclaimerTeam', required = false, type = ParameterTypes.TeamID },
	    },
	    actionFunction = reclaimUnits,
    },
}