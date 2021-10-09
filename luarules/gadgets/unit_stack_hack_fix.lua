function gadget:GetInfo()
    return {
      name      = "Anti Stacking Hax",
      desc      = "123",
      author    = "Damgam",
      date      = "2021",
      layer     = -100,
      enabled   = true,
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

affectedUnits = {}
local affectedUnitTypes = {
    "armnanotc",
    "cornanotc",
}

local function CheckIfUnitIsAffected(unitName)
    for i = 1,#affectedUnitTypes do
        if unitName == affectedUnitTypes[i] then
            return true
        end
        if (string.find(unitName, "_scav")) then
            local scavUnitName = string.sub(unitName, 1, string.len(unitName)-5)
            if scavUnitName == affectedUnitTypes[i] then
                return true
            end
        end
    end
    return false
end


function gadget:UnitCreated(unitID, unitDefID)
    local unitName = UnitDefs[unitDefID].name
    if CheckIfUnitIsAffected(unitName) then
        --Spring.Echo("Added "..unitName)
        table.insert(affectedUnits, unitID)
    end
end

function gadget:UnitDestroyed(unitID, unitDefID)
    local unitName = UnitDefs[unitDefID].name
    if #affectedUnits > 0 then
        for i = 1,#affectedUnits do
            if affectedUnits[i] == unitID then
                --Spring.Echo("Removed "..unitName)
                table.remove(affectedUnits, i)
            end
        end
    end
end

function gadget:GameFrame(n)
    if #affectedUnits > 0 then
        for i = 1,#affectedUnits do
            local unitID = affectedUnits[i]
            local unitDefID = Spring.GetUnitDefID(unitID)
            local testRange = math.floor(((UnitDefs[unitDefID].xsize + UnitDefs[unitDefID].zsize)*0.5)*6)
            local nearestAlly = Spring.GetUnitNearestAlly(unitID, testRange)
            if nearestAlly then
                local nearestAllyName = UnitDefs[Spring.GetUnitDefID(nearestAlly)].name
                local nearestAllyCanMove = UnitDefs[Spring.GetUnitDefID(nearestAlly)].canMove
                if not nearestAllyCanMove then
                    if not Spring.GetUnitTransporter(unitID) then
                        local x,y,z = Spring.GetUnitPosition(unitID)
                        local ax,ay,az = Spring.GetUnitPosition(nearestAlly)
                        local r = math.random(1,3)
                        local movementTargetX = 0
                        local movementTargetZ = 0
                        
                        if r == 1 then
                            if x == ax or z == az then
                                movementTargetX = math.random(-testRange,testRange)
                                movementTargetZ = math.random(-testRange,testRange)
                            end
                        elseif r == 2 then
                            if x > ax then
                                movementTargetX = 5
                            end
                            if x < ax then
                                movementTargetX = -5
                            end
                        elseif r == 3 then
                            if z > az then
                                movementTargetZ = 5
                            end
                            if z < az then
                                movementTargetZ = -5
                            end
                        end
                        local movementTargetY = Spring.GetGroundHeight(x+movementTargetX, z+movementTargetZ)
                        local aboveMinWaterDepth = -(UnitDefs[unitDefID].minWaterDepth) > movementTargetY
                        local belowMaxWaterDepth = -(UnitDefs[unitDefID].maxWaterDepth) < movementTargetY
                        if aboveMinWaterDepth and belowMaxWaterDepth then
                            Spring.SetUnitPosition(unitID, x+movementTargetX, z+movementTargetZ)
                        end
                    end
                end
            end
        end
    end
end
