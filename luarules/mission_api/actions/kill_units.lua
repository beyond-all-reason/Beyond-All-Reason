local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function killUnits(unitName, selfDestruct, despawn, reclaim, killerTeam)
    local tracking = GG['MissionAPI'].Modules.Tracking
	if tracking.IsUnitNameUntracked(unitName) then return end

    local trackedUnitIDs = table.copy(GG['MissionAPI'].trackedUnitIDs[unitName])
	for unitID in pairs(trackedUnitIDs) do
        if reclaim then
            local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
            if unitDef and unitDef.metalCost then
                Spring.AddTeamResource(killerTeam, "metal", unitDef.metalCost)
            end
            -- if unitDef and unitDef.energyCost then -- We don't give energy from reclaims, but putting it here just in case someone needs it later.
            --     Spring.AddTeamResource(killerTeam, "energy", unitDef.energyCost)
            -- end
        end
        if selfDestruct then
            killerTeam = Spring.GetUnitTeam(unitID)
        end
        Spring.DestroyUnit(unitID, selfDestruct, despawn, killerTeam)
	end
end

local function destroyUnits(unitName, killerTeam)
    local selfDestruct = false
    local despawn = false
    local reclaim = false
    killUnits(unitName, selfDestruct, despawn, reclaim, killerTeam)
end

local function selfDestructUnits(unitName)
    local selfDestruct = true
    local despawn = false
    local reclaim = false
    killUnits(unitName, selfDestruct, despawn, reclaim, nil)
end

local function reclaimUnits(unitName, killerTeam)
    local selfDestruct = false
    local despawn = true
    local reclaim = true
    killUnits(unitName, selfDestruct, despawn, reclaim, killerTeam)
end

local function despawnUnits(unitName)
    local selfDestruct = false
    local despawn = true
    local reclaim = false
    killUnits(unitName, selfDestruct, despawn, reclaim, nil)
end

return {
    {
	    type = 'DestroyUnits',
	    parameters = {
	    	{ name = 'unitName', required = true, type = ParameterTypes.UnitName },
	    	{ name = 'killerTeam', required = false, type = ParameterTypes.TeamID },
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
	    	{ name = 'killerTeam', required = true, type = ParameterTypes.TeamID },
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