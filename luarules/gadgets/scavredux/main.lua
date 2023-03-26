mainConfig = VFS.Include('luarules/gadgets/scavredux/configs/main-config.lua')
positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")
nearbyCaptureLibrary = VFS.Include("luarules/utilities/damgam_lib/nearby_capture.lua")

local mRandom = math.random

function CreatePointOfInterest(x,z)
    table.insert(PointsOfInterestTable, {
        PosX = x,
        PosZ = z,
        Commander = nil,
        Structures = {},
        Defenders = {},
        Workers = {},
    })
end

function FindPointsOfInterestPositions()
    local a = 0
    repeat
        a = a + 1

        local x = mRandom(mainConfig.PointOfInterestMinDistance, Game.mapSizeX-mainConfig.PointOfInterestMinDistance)
        local z = mRandom(mainConfig.PointOfInterestMinDistance, Game.mapSizeX-mainConfig.PointOfInterestMinDistance)
        local y = Spring.GetGroundHeight(x,z)
        
        local canCreatePOI = positionCheckLibrary.FlatAreaCheck(x, y, z, mainConfig.PointOfInterestSize, 30, true)
        if canCreatePOI then
            canCreatePOI = positionCheckLibrary.VisibilityCheckEnemy(x, y, z, mainConfig.PointOfInterestMinDistance, ScavAllyTeamID, true, true, true)
        end
        if canCreatePOI then
            if #PointsOfInterestTable > 0 then
                for i = 1,#PointsOfInterestTable do
                    local pX = PointsOfInterestTable[i].PosX
                    local pZ = PointsOfInterestTable[i].PosZ
                    local pD = mainConfig.PointOfInterestMinDistance
                    if pX < x-pD and pX > x+pD and pZ < z-pD and pZ > z+pD then
                        CreatePointOfInterest(x,z)
                        break
                    end
                end
            else
                CreatePointOfInterest(x,z)
            end
        end
    until a > 1000 or #PointsOfInterestTable >= mainConfig.PointOfInterestMaxCount
end

function SpawnPointsOfInterest()
    

end

















function gadget:GameFrame(frame)
    if frame = 1 then
        FindPointsOfInterestPositions()
    end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)

end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)

end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)

end

function gadget:UnitGiven(unitID, unitDefID, unitNewTeam, unitOldTeam)

end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)

end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
    if damage then
        return damage
    else
        return 0
    end
end

function gadget:GameOver()
	gadgetHandler:RemoveGadget(self)
end