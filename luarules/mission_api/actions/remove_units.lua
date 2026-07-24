local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function removeUnits(unitName, selfDestruct, despawn, reclaim, reclaimerTeam)
    local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

    -- Copying table as UnitKilled trigger with SpawnUnits with the same name could cause infinite loop.
    local trackedUnitIDs = table.copy(GG['MissionAPI'].trackedUnitIDs[unitName])
	for unitID in pairs(trackedUnitIDs) do
        if Spring.GetUnitIsDead(unitID) == false then
            if reclaim then
                if not reclaimerTeam then reclaimerTeam = Spring.GetUnitTeam(unitID) end
                local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
                if unitDef and unitDef.metalCost then
                    Spring.AddTeamResource(reclaimerTeam, "metal", unitDef.metalCost)
                end
                -- if unitDef and unitDef.energyCost then -- We don't give energy from reclaims, but putting it here just in case someone needs it later.
                --     Spring.AddTeamResource(reclaimerTeam, "energy", unitDef.energyCost)
                -- end
            end
            Spring.DestroyUnit(unitID, selfDestruct, despawn)
        end
	end 
end

local function destroyUnits(unitName)
    local selfDestruct = false
    local despawn = false
    local reclaim = false
    removeUnits(unitName, selfDestruct, despawn, reclaim, nil)
end

local function selfDestructUnits(unitName)
    local selfDestruct = true
    local despawn = false
    local reclaim = false
    removeUnits(unitName, selfDestruct, despawn, reclaim, nil)
end

local function reclaimUnits(unitName, reclaimerTeam)
    local selfDestruct = false
    local despawn = true
    local reclaim = true
    removeUnits(unitName, selfDestruct, despawn, reclaim, reclaimerTeam)
end

local function despawnUnits(unitName)
    local selfDestruct = false
    local despawn = true
    local reclaim = false
    removeUnits(unitName, selfDestruct, despawn, reclaim, nil)
end

return {
    {
	    type = 'DestroyUnits',
	    parameters = {
	    	{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
	    },
	    actionFunction = destroyUnits,
    },
    {
	    type = 'SelfDestructUnits',
	    parameters = {
	    	{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
	    },
	    actionFunction = selfDestructUnits,
    },
    {
	    type = 'ReclaimUnits',
	    parameters = {
	    	{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
	    	{ name = 'reclaimerTeam', required = false, type = ParameterTypes.TeamID },
	    },
	    actionFunction = reclaimUnits,
    },
    {
	    type = 'DespawnUnits',
	    parameters = {
	    	{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
	    },
	    actionFunction = despawnUnits,
    },
}