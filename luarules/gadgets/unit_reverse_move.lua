function gadget:GetInfo()
    return {
        name      = "AutoReverse Movement",
        desc      = "Units reverse intelligently instead of turning around. This aims at replacing the old gadget (that is default disabled) and allow tweaks that use a defined r speed to work. There is no schedule for an implementation into the base game as this has not been approved by anyone.",
        author    = "DoodVanDaag (LLM used)",
        date      = "2025",
        license   = "GPL",
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then return end

-- =============================
-- Localized functions/constants
-- =============================
local sqrt      = math.sqrt
local abs       = math.abs
local rad       = math.rad
local pi        = math.pi

-- local pairs     = pairs

-- Spring functions
local getUnitPosition      = Spring.GetUnitPosition
local getUnitHeading       = Spring.GetUnitHeading
local getHeadingFromVector = Spring.GetHeadingFromVector
local getUnitWeaponTarget  = Spring.GetUnitWeaponTarget
local getUnitMoveTypeData  = Spring.GetUnitMoveTypeData
local getUnitMaxRange      = Spring.GetUnitMaxRange
local getUnitStates        = Spring.GetUnitStates
local getGameFrame         = Spring.GetGameFrame
local getAllUnits          = Spring.GetAllUnits
local getUnitDefID         = Spring.GetUnitDefID
local getUnitTeam          = Spring.GetUnitTeam
local setUnitMoveGoal      = Spring.SetUnitMoveGoal
local setUnitVelocity      = Spring.SetUnitVelocity
local MoveCtrl_SetGMD      = Spring.MoveCtrl.SetGroundMoveTypeData

-- =============================
-- Config
-- =============================
local UPDATE_RATE = 3 -- every 3 frames
local minDistMult = 0.25
local maxDistMultSetTarget = 1.5
local maxDistMultAutoTarget = 1 -- (1 for ROAM, 0.5 for manoeuver, 0 for hold pos)
-- =============================
-- State
-- =============================
local unitStates = {} -- [unitID] = state

-- =============================
-- Utils
-- =============================
local function Normalize(x, y, z)
    local len = sqrt(x*x + y*y + z*z)
    if len == 0 then return 0,0,0 end
    return x/len, y/len, z/len
end

-- =============================
-- Target acquisition
-- =============================
local function GetTargetPos(unitID, state)
    local settarget, autotarget, notarget = 1, 2, 0
    local tx, ty, tz
    local ttype = notarget

    local targetList = GG.getUnitTargetList and GG.getUnitTargetList(unitID)
    if targetList then
        local ID = GG.getUnitTargetIndex and GG.getUnitTargetIndex(unitID) or 1
        local maybeID = targetList[ID].target
        if type(maybeID) == "table" then
            tx,ty,tz = maybeID[1],maybeID[2],maybeID[3]
        else
            tx,ty,tz = getUnitPosition(maybeID)
        end
        ttype = settarget
    end

    if not tx then
        local _,_,maybeID = getUnitWeaponTarget(unitID, 1)
        if maybeID then
            if type(maybeID) == "table" then
                tx,ty,tz = maybeID[1],maybeID[2],maybeID[3]
            else
                tx,ty,tz = getUnitPosition(maybeID)
            end
            ttype = autotarget
        end
    end

    if tx then
        local ux,uy,uz = getUnitPosition(unitID)
        local dist = sqrt((tx-ux)^2 + (tz-uz)^2)
        local range = getUnitMaxRange(unitID)
        local states = getUnitStates(unitID)
        local moveState = (states and states.movestate) or 0

        if (ttype==settarget and dist>maxDistMultSetTarget*range) or
           (ttype==autotarget and (dist>maxDistMultAutoTarget*moveState*range/2 or dist<minDistMult*range)) then
            tx = nil
            ttype = notarget
        end
    end

    local frame = getGameFrame()
    if tx then
        state.fallBackTarget = {tx,ty,tz, expire=frame+90}
    elseif state.fallBackTarget and frame <= (state.fallBackTarget.expire or 0) then
        tx,ty,tz = state.fallBackTarget[1], state.fallBackTarget[2], state.fallBackTarget[3]
    else
        state.fallBackTarget = nil
    end

    return tx and {tx,ty,tz} or nil
end

-- =============================
-- Movement decision
-- =============================
local function StopReversing(unitID, state)
    if state.reversing then
        MoveCtrl_SetGMD(unitID, "maxReverseSpeed", 0)
        state.reversing = false
    end
end

local function StartReversing(unitID, state)
    if not state.reversing then
        MoveCtrl_SetGMD(unitID, "maxReverseSpeed", UnitDefs[state.defID].speed)
        state.reversing = true
    end
end

local function CheckIfINeedToTurnAroundManually(unitID, state, pos)
    local delta = (state.curHeading - state.mHeading) % (2*pi)
    local aligned = (delta > pi/2 and delta < 3*pi/2)
    if (not aligned) or not state.stopped then
        MoveCtrl_SetGMD(unitID, "maxReverseSpeed", 0)
        MoveCtrl_SetGMD(unitID, "accRate", 0)
        local ux,uy,uz = getUnitPosition(unitID)
        local tx,ty,tz = pos[1] or ux, pos[2] or uy, pos[3] or uz
        local dtx,dty,dtz = Normalize(tx-ux, ty-uy, tz-uz)
        local mx,my,mz = state.lastmGoal[1] or ux, state.lastmGoal[2] or uy, state.lastmGoal[3] or uz
        local dmx,dmy,dmz = Normalize(mx-ux, my-uy, mz-uz)
        local vx,vy,vz,v = Spring.GetUnitVelocity(unitID)
        local brakeRate = (UnitDefs[state.defID].maxDec or 1) * 30
        v = v*30
        local ratio = v~=0 and ((v-brakeRate)/v) or 0
        state.fakeMoveGoal = {x=ux+dtx*16 - dmx*16, y=uy-dty*16 - dmy*16, z=uz+dtz*16 - dmz * 16}
        if v >= 0 and v <= 0.3*UnitDefs[state.defID].speed then
            setUnitVelocity(unitID, 0,0,0)
            state.stopped = true
        else
            setUnitVelocity(unitID, vx*ratio, vy*ratio, vz*ratio)
            state.stopped = false
        end
        if not aligned then
            setUnitMoveGoal(unitID, state.fakeMoveGoal.x, state.fakeMoveGoal.y, state.fakeMoveGoal.z, 8,0,true)
        end
    else
        MoveCtrl_SetGMD(unitID, "maxReverseSpeed", UnitDefs[state.defID].speed)
        MoveCtrl_SetGMD(unitID, "accRate", UnitDefs[state.defID].maxAcc)
    end
end

local function Decide(unitID, state, pos)
    if state.stHeading then
        if state.mHeading then
            local delta = (state.mHeading - state.stHeading) % (2*pi)
            if delta>pi/2 and delta<3/2*pi then
                StartReversing(unitID, state)
                if pos then CheckIfINeedToTurnAroundManually(unitID,state,pos) end
            else
                StopReversing(unitID,state)
            end
        else
            StopReversing(unitID,state)
        end
    else
        StopReversing(unitID,state)
    end
end

-- =============================
-- Lifecycle
-- =============================
function gadget:UnitCreated(unitID, unitDefID, teamID)
    local ud = UnitDefs[unitDefID]
    if ud and ud.canMove and ud.rSpeed > 0 and not ud.canFly then
        unitStates[unitID] = {
            stHeading = nil,
            mHeading = nil,
            curHeading = 2*pi*((getUnitHeading(unitID)+32768)/65536),
            reversing = false,
            fallBackTarget = nil,
            fakeMoveGoal = {},
            lastmGoal = {},
            defID = unitDefID,
        }
        StopReversing(unitID, unitStates[unitID])
    end
end

function gadget:UnitDestroyed(unitID)
    unitStates[unitID] = nil
end

-- =============================
-- Main loop
-- =============================
function gadget:GameFrame(f)
    if f % UPDATE_RATE == 0 then
        for unitID, state in pairs(unitStates) do
            local pos = GetTargetPos(unitID, state)

            if pos then
                local ux,uy,uz = getUnitPosition(unitID)
                local dirx, dirz = pos[1]-ux, pos[3]-uz
                state.stHeading = 2*pi*((getHeadingFromVector(dirx, dirz)+32768)/65536)
            else
                state.stHeading = nil
            end

            local data = getUnitMoveTypeData(unitID)
            if data and data.goalx then
                local goalx, goaly, goalz = data.goalx, data.goaly, data.goalz
                local fake = state.fakeMoveGoal
                local isFake = fake and fake.x and abs(goalx-fake.x)<1e-3 and abs(goaly-fake.y)<1e-3 and abs(goalz-fake.z)<1e-3

                local ux,uy,uz = getUnitPosition(unitID)
                if not isFake then
                    local dirx, dirz = goalx-ux, goalz-uz
                    state.lastmGoal = {goalx, goaly, goalz}
                    state.mHeading = 2*pi*((getHeadingFromVector(dirx, dirz)+32768)/65536)
                elseif state.lastmGoal then
                    local dirx, dirz = state.lastmGoal[1]-ux, state.lastmGoal[3]-uz
                    state.mHeading = 2*pi*((getHeadingFromVector(dirx, dirz)+32768)/65536)
                end
            end

            Decide(unitID, state, pos)
            state.lastTargetPos = pos
        end
    end

    for unitID, state in pairs(unitStates) do
        if state.reversing and state.lastTargetPos then
            state.curHeading = 2*pi*((getUnitHeading(unitID)+32768)/65536)
            CheckIfINeedToTurnAroundManually(unitID,state,state.lastTargetPos)
        else
            MoveCtrl_SetGMD(unitID,"accRate",UnitDefs[state.defID].maxAcc)
        end
    end
end

function gadget:Initialize()
    for _,v in pairs(getAllUnits()) do
        gadget:UnitCreated(v,getUnitDefID(v),getUnitTeam(v))
    end
end