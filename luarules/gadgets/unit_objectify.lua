--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
    return {
        name      = "Objectify",
        desc      = "makes units neutral and stealthy when unit has customparam: objectify",
        author    = "Bluestone, Floris",
        date      = "Feb 2015",
        license   = "Bacon",
        layer     = 0,
        enabled   = true  --  loaded by default?
    }
end

-- make them neutral, radar stealthy, not appear on the minimap
-- make them vulnerable while being built
-- would be good if they were omitted from area attacks but this is not currently possible
-- specified as non-repairable in unitdef (dragonteeth are now an exception and are repairable)


local isObject = {}
for udefID,def in ipairs(UnitDefs) do
    if def.customParams and def.customParams.objectify then
        isObject[udefID] = true
    end
end

if gadgetHandler:IsSyncedCode() then

    function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
        if isObject[unitDefID] and Spring.ValidUnitID(unitID) then
            Spring.SetUnitStealth(unitID, true)
            Spring.SetUnitSonarStealth(unitID, true)
            Spring.SetUnitNeutral(unitID, true)
            Spring.SetUnitBlocking(unitID, true, true, true, true, true, true, false) -- set as crushable
        end
    end

    function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
        if isObject[unitDefID] and not paralyzer then
            local health,maxHealth,_,_,buildProgress = Spring.GetUnitHealth(unitID)
            if buildProgress and maxHealth and buildProgress < 0.99 then
                return (damage/100)*maxHealth, nil
            end
        end
        return damage, nil
    end


else --UNSYNCED


    local CMD_MOVE = CMD.MOVE
    local spGetMouseState = Spring.GetMouseState
    local spTraceScreenRay = Spring.TraceScreenRay
    local spGetUnitDefID = Spring.GetUnitDefID

    function gadget:DefaultCommand()
		local mx,my = spGetMouseState()
		local s,uID = spTraceScreenRay(mx,my)
        if s ~= "unit" then return end
		-- make sure a command given on top of a objectified unit is a move command
        if isObject[spGetUnitDefID(uID)] then
            if select(4, Spring.GetUnitHealth(uID)) == 1 then
                return CMD_MOVE
            end
        end
        return
    end

end

