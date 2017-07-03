function gadget:GetInfo()
	return {
		name = "ARMSUB SURFACING Testing gadget",
		desc = "Makes On/Off button act as a selector for Surface/Sub modes",
		author = "[Fx]Doo",
		date = "1st of July 2017",
		license = "Free",
		layer = 0,
		enabled = true
	}
end


if (gadgetHandler:IsSyncedCode()) then
    UW = {}
    SURF = {}
    function gadget:UnitFinished(unitID) -- add UW[unitID] and SURF[unitID] upon creation
        unitDefID = Spring.GetUnitDefID(unitID)
        unitName = UnitDefs[unitDefID].name
        if unitName == "armsubexp" then
            UW[unitID] = true
        end
        if unitName == "armsubsurface" then
            SURF[unitID] = true
        end
    end

    function gadget:GameFrame(f)
        for unitID, under in pairs(UW) do -- check all UW submarines
            if not Spring.GetUnitIsActive(unitID) == true then -- Check if they changed state
                -- Gather stats of an UW sub that has been turned off
                local x,y,z = Spring.GetUnitPosition(unitID)
                local rx, ry, rz = Spring.GetUnitRotation(unitID)
                local team = Spring.GetUnitTeam(unitID)
                local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth(unitID)
                local expert = Spring.GetUnitExperience(unitID)
                local vx, vy, vz = Spring.GetUnitVelocity(unitID)
                Spring.DestroyUnit(unitID, false, true) -- destroy it
                UW[unitID] = nil -- clear UW[unitID] entry
                newID = Spring.CreateUnit("armsubsurface", x,y,z, "n", team) --Create newID (surface)
                -- Reapply stats
                Spring.SetUnitRotation(newID, rx,ry,rz)
                Spring.SetUnitHealth(newID, health, captureProgress, paralyzeDamage, buildProgress)
                Spring.SetUnitExperience(newID, expert)
                Spring.SetUnitVelocity(newID, vx, vy, vz)

                Spring.AddUnitDamage(newID, 835*1.09, 835*1.05, -1, -2) -- Apply an EMP (simulates animation delay)
                -- Spring.Echo("added damages")
                SURF[newID] = true -- add SURF[newID] entry
            end
        end
        for unitID, under in pairs(SURF) do -- check all SURF submarines
            if not Spring.GetUnitIsActive(unitID) == false then-- Check if they changed state
                -- Gather stats of an SURF sub that has been turned on
                local x,y,z = Spring.GetUnitPosition(unitID)
                local rx, ry, rz = Spring.GetUnitRotation(unitID)
                local team = Spring.GetUnitTeam(unitID)
                local health, maxHealth, paralyzeDamage, captureProgress, buildProgress = Spring.GetUnitHealth(unitID)
                local expert = Spring.GetUnitExperience(unitID)
                local vx, vy, vz = Spring.GetUnitVelocity(unitID)
                Spring.DestroyUnit(unitID, false, true)-- destroy it
                SURF[unitID] = nil-- clear UW[unitID] entry
                newID = Spring.CreateUnit("armsubexp", x,y,z, "n", team)--Create newID (surface)
                -- Reapply stats
                Spring.SetUnitRotation(newID, rx,ry,rz)
                Spring.SetUnitHealth(newID, health, captureProgress, paralyzeDamage, buildProgress)
                Spring.SetUnitExperience(newID, expert)
                Spring.SetUnitVelocity(newID, vx, vy, vz)
                Spring.AddUnitDamage(newID, 835*1.09, 835*1.05, -1, -2) -- Apply an EMP (simulates animation delay)
                -- Spring.Echo("added damages")
                UW[newID] = true -- add UW[newID] entry
            end
        end
    end

    function gadget:UnitDestroyed(unitID) -- Clear UW[unitID] and SURF[unitID] upon death
        if UW[unitID] then
            UW[unitID] = nil
        end
        if SURF[unitID] then
            UW[unitID] = nil
        end
    end
end