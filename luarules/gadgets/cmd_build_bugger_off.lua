local gadget = gadget ---@type gadget

function gadget:GetInfo()
    return {
        name    = "Builder buggeroff",
        desc    = "Enables busy builders and moving units to buggeroff",
        author  = "Flameink",
        date    = "March 7, 2025",
        version = "1.0",
        license = "GNU GPL, v2 or later",
        layer   = 0,
        enabled = true   --  loaded by default?
    }
end

local debugLog = false

function print(Message)
   if debugLog then
        Spring.Echo(Message)
    end
end

local shouldNotBuggeroff = {}
local cachedUnitDefs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.speed == 0 or unitDef.isBuilding or unitDef.isFactory then
        shouldNotBuggeroff[unitDefID] = true
    end
    cachedUnitDefs[unitDefID] = { radius = unitDef.radius, isBuilder = unitDef.isBuilder}
end

if gadgetHandler:IsSyncedCode() then

    local function closestPointOnCircle(cx, cz, radius, tx, tz)
        local dx = tx - cx
        local dz = tz - cz
        local dist = math.diag(dx, dz)
        if dist == 0 then
            -- Target is exactly at center; choose arbitrary point on circle
            return cx + radius, cz
        end
        local scale = radius / dist
        local closestX = cx + dx * scale
        local closestZ = cz + dz * scale
        return closestX, closestZ
    end

    local function WillBeNearTarget(unitID, tx, ty, tz, frames, maxDistance)
        local ux, uy, uz = Spring.GetUnitPosition(unitID)
        if not ux then return false end
        
        local vx, vy, vz = Spring.GetUnitVelocity(unitID)
        if not vx then return false end
        
        -- Predict future position
        local futureX = ux + vx * seconds * Game.gameSpeed
        local futureY = uy + vy * frames
        local futureZ = uz + vz * frames
        
        -- Compute distance to target
        local dx = futureX - tx
        local dy = futureY - ty
        local dz = futureZ - tz
        return math.diag(dx, dy, dz) <= maxDistance
    end

    local function isInTargetArea(interferingUnitID, x, y, z, radius)
        local ux, uy, uz = Spring.GetUnitPosition(interferingUnitID)
        if not ux then return false end
        return math.diag(ux - x, uz - z) <= radius
    end
    
    local slowUpdateBuilders = {}
    local watchedBuilders = {}
    local builderRadiusOffsets = {}

    local FAST_UPDATE_RADIUS        = 300
    -- builders take about this much to enter build stance; determined empirically
    local BUILDER_DELAY_SECONDS = 3.3
    local BUILDER_BUILD_RADIUS      = 200
    local SEARCH_RADIUS_OFFSET      = 200

    local function shouldIssueBuggeroff(unitTeam, builderTeam, interferingUnitID, x, y, z, radius)
        if Spring.AreTeamsAllied(unitTeam, builderTeam) == false and unitTeam ~= builderTeam then
            return false
        end
        if shouldNotBuggeroff[Spring.GetUnitDefID(interferingUnitID)] then
            return false
        end
        if WillBeNearTarget(interferingUnitID, x, y, z, BUILDER_DELAY_FRAME_COUNT, radius) then
            return true
        end
        if isInTargetArea(interferingUnitID, x, y, z, radius) then
            return true
        end
        return false
    end

    local function getFirstCommand(unitID)
        local unitCommands = Spring.GetUnitCommands(unitID, -1)
        if unitCommands == nil then
            return nil
        end
        if next(unitCommands) == nil then
            return nil
        end
        return unitCommands[1]
    end

    local function distance(pos1, x2, z2)
        local x1, z1 = pos1[1], pos1[3]
        local dx, dz = x2 - x1, z2 - z1
        return math.diag(dx, dz)
    end


    function gadget:GameFrame(frame)
        if frame % 10 ~= 0 then
            return
        end
        for builderID, _ in pairs(watchedBuilders) do

            local firstCommand = getFirstCommand(builderID)
            local targetID     = Spring.GetUnitIsBuilding(builderID)
            local isBuilding   = false
            if targetID then
                isBuilding = true
            end

            local x, y, z = Spring.GetUnitPosition(builderID)
            if firstCommand == nil or firstCommand.id > -1 or isBuilding then
                print("Clearing watched builder fast")
                watchedBuilders[builderID]      = nil
                builderRadiusOffsets[builderID] = nil
            elseif distance(firstCommand.params, x, z) > FAST_UPDATE_RADIUS then
                print("Too far, demoting to slow")
                watchedBuilders[builderID]    = nil
                slowUpdateBuilders[builderID] = true -- Do distance checks less frequently
            elseif distance(firstCommand.params, x, z) > BUILDER_BUILD_RADIUS then
                -- Check distance frequently once you're closer
            else
                local cmdID           = firstCommand.id
                local cmdParams       = firstCommand.params
                local builtUnitDefID  = cmdID * -1
                local builderTeam     = Spring.GetUnitTeam(builderID)
                local buggerOffRadius = cachedUnitDefs[builtUnitDefID].radius + builderRadiusOffsets[builderID]

                -- Get list of units to check
                local targetX, targetY, targetZ = cmdParams[1], cmdParams[2], cmdParams[3]
                local searchRadius     = cachedUnitDefs[builtUnitDefID].radius + SEARCH_RADIUS_OFFSET
                local x1, x2, z1, z2   = targetX - searchRadius, targetX + searchRadius, targetZ - searchRadius, targetZ + searchRadius
                local interferingUnits = Spring.GetUnitsInRectangle(x1, z1, x2, z2)

                -- Escalate the radius every update. We want to send units away the minimum distance, but  
                -- if there are many units in the way, they may cause a traffic jam and need to clear more room.
                builderRadiusOffsets[builderID] = builderRadiusOffsets[builderID] + 5 

                for i = 1, #interferingUnits do
                    local interferingUnitID = interferingUnits[i]
                    if builderID ~= interferingUnitID then
                        local unitPosition = {Spring.GetUnitPosition(interferingUnitID)}
                        local unitTeam     = Spring.GetUnitTeam(interferingUnitID)
        
                        if shouldIssueBuggeroff(unitTeam, builderTeam, interferingUnitID, targetX, targetY, targetZ, buggerOffRadius) then
                            local sendX, sendZ = closestPointOnCircle(targetX, targetZ, buggerOffRadius, unitPosition[1], unitPosition[3])
                            Spring.GiveOrderToUnit(interferingUnitID, CMD.INSERT, {0, CMD.MOVE, CMD.OPT_INTERNAL, sendX, targetY, sendZ}, CMD.OPT_ALT )
                        end    
                    end
                end
            end
        end
        if frame % 100 ~= 0 then
            return
        end
        for builderID, _ in pairs(slowUpdateBuilders) do
            local firstCommand = getFirstCommand(builderID)
            local x, y, z = Spring.GetUnitPosition(builderID)
            if firstCommand == nil or firstCommand.id > -1 or isBuilding then
                print("Clearing watched builder slow")
                slowUpdateBuilders[builderID] = nil
                builderRadiusOffsets[builderID] = nil
            elseif distance(firstCommand.params, x, z) <= FAST_UPDATE_RADIUS then
                print("Promote to fast")
                slowUpdateBuilders[builderID] = nil
                watchedBuilders[builderID] = true
            end

        end

    end

    function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
        local orderedUnit = unitID

        local unitDefID = Spring.GetUnitDefID(orderedUnit)
        if cachedUnitDefs[unitDefID].isBuilder then
            watchedBuilders[orderedUnit] = true
            builderRadiusOffsets[orderedUnit] = 1
        end
        return true

    end
end
