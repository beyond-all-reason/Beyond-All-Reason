TransportAnimator = {}

local SIG_WATCH           = 2 -- signal to stop the WatchBeam thread when cargo state changes
TransportAnimator.SIG_LOAD = 4 -- signal to kill all in-flight Load threads (used by ReorganizeAndLoad)


-- helper to move/rotate a piece to a world-space position/rotation
-- simplified: no scaling nor parent piece transforms taken into account
local function rotationMatrixX(rx)
    local c, s = math.cos(rx), math.sin(rx)
    return { {1,0,0}, {0,c,-s}, {0,s,c} }
end

local function rotationMatrixY(ry)
    local c, s = math.cos(ry), math.sin(ry)
    return { {c,0,s}, {0,1,0}, {-s,0,c} }
end

local function rotationMatrixZ(rz)
    local c, s = math.cos(rz), math.sin(rz)
    return { {c,-s,0}, {s,c,0}, {0,0,1} }
end

local function multiplyMatrices(a, b)
    local r = {}
    for i = 1, 3 do
        r[i] = {}
        for j = 1, 3 do
            r[i][j] = 0
            for k = 1, 3 do r[i][j] = r[i][j] + a[i][k] * b[k][j] end
        end
    end
    return r
end

local function applyRotation(m, vx, vy, vz)
    return m[1][1]*vx + m[1][2]*vy + m[1][3]*vz,
           m[2][1]*vx + m[2][2]*vy + m[2][3]*vz,
           m[3][1]*vx + m[3][2]*vy + m[3][3]*vz
end

local function transposeMatrix(m)
    return {
        { m[1][1], m[2][1], m[3][1] },
        { m[1][2], m[2][2], m[3][2] },
        { m[1][3], m[2][3], m[3][3] },
    }
end

local function shortAngle(a)
    a = a % (2 * math.pi)
    if a > math.pi then a = a - 2 * math.pi end
    return a
end

-- converts a world-space position and rotation into the transporter's unit-local space
local function WorldToUnitSpace(wsX, wsY, wsZ, wsRX, wsRY, wsRZ, ux, uy, uz, urx, ury, urz)
    if not ux then
        ux, uy, uz    = SpGetUnitPosition(unitID)
        urx, ury, urz = SpGetUnitRotation(unitID)
    end
    local dx, dy, dz = wsX - ux, wsY - uy, wsZ - uz
    local unitRot = multiplyMatrices(
        rotationMatrixY(-ury),
        multiplyMatrices(rotationMatrixX(-urx), rotationMatrixZ(-urz))
    )
    local usX, usY, usZ = applyRotation(transposeMatrix(unitRot), dx, dy, dz)
    return usX, usY, usZ,
           shortAngle(wsRX - urx),
           shortAngle(ury - wsRY),
           shortAngle(urz - wsRZ)
end
local defaultPiecePos  = {} -- [pieceID] = {x,y,z} rest position in unit-local space, cached on first use

-- move and rotate a slot piece to match a world-space position/rotation, converting through unit-local space
local function MovePieceWS(pce, wsX, wsY, wsZ, wsRX, wsRY, wsRZ, speed, tHeight, ux, uy, uz, urx, ury, urz, t)
    local usX, usY, usZ, usRX, usRY, usRZ = WorldToUnitSpace(wsX, wsY, wsZ, wsRX, wsRY, wsRZ, ux, uy, uz, urx, ury, urz)
    -- Move() offsets are relative to the piece's own rest position, not the unit origin.
    -- Subtract the rest position so the piece ends up at the correct unit-local coordinates.
    if not defaultPiecePos[pce] then
        local dpx, dpy, dpz = Spring.GetUnitPiecePosition(unitID, pce)
        defaultPiecePos[pce] = { dpx, dpy, dpz }
    end
    local dp = defaultPiecePos[pce]
    Move(pce, 1, (usX + (1-t) * dp[1]),           speed)
    Move(pce, 2, usY - tHeight - (1-t) * dp[2], speed)
    Move(pce, 3, usZ - (1-t) * dp[3],           speed)
    Turn(pce, 1, usRX, speed)
    Turn(pce, 2, usRY, speed)
    Turn(pce, 3, usRZ, speed)
end

local loadTime, ratio, ratioY, cegScaleFactor, cegName
local progress         = {}
local beamsBySlotID    = {}

local cachedFrame = -1
local cUX, cUY, cUZ, cURX, cURY, cURZ

-- returns transporter position and rotation, memoized per game frame to avoid redundant API calls
local function getTransporterState() -- caching helper: get the position only once per frame when multiple threads are running.
    local f = SpGetGameFrame()
    if f ~= cachedFrame then
        cUX, cUY, cUZ    = SpGetUnitPosition(unitID)
        cURX, cURY, cURZ = SpGetUnitRotation(unitID)
        cachedFrame = f
    end
    return cUX, cUY, cUZ, cURX, cURY, cURZ
end

-- zero out all transforms on a slot piece (called after animation completes or is aborted)
local function resetSlot(slotID) -- Instantly move slot to its default pos/rotation
    Move(slotID, 1, 0)  Move(slotID, 2, 0)  Move(slotID, 3, 0)
    Turn(slotID, 1, 0)  Turn(slotID, 2, 0)  Turn(slotID, 3, 0)
end

-- returns true if a unit is no longer valid or has been marked dead
local function isDead(id) -- helper to check if a unit is dead or invalid.
    return not SpValidUnitID(id) or SpGetUnitIsDead(id)
end

-- initialise loadTime, CEG params, velocity damping ratios, easing curve, and beam pieces from setup
function TransportAnimator.Init(setup)
    loadTime       = setup.loadTime
    cegScaleFactor = setup.cegScaleFactor
    cegName        = setup.cegName

    local def    = UnitDefs[unitDefID]
    local vmax   = def.speed
    local a      = math.max(0.01, def.maxAcc)
    local vmax_y = def.verticalSpeed
    -- velocity damping ratio: tuned to unit speed and acceleration so the aircraft slows to near-stop during
    -- load/unload; applied as ratio^2 per 66ms tick in WatchBeams
    ratio  = (0.20 * vmax)   / (0.20 * vmax   + a)
    ratioY = (0.05 * vmax_y) / (0.05 * vmax_y + a)

    -- pre-compute cosine ease-in-out curve for each frame in [0, loadTime]
    for f = 0, loadTime do
        progress[f] = (-math.cos(math.pi * f / loadTime) + 1) / 2
    end

    -- resolve beam piece name strings from setup into piece IDs, keyed by slot piece ID
    if setup.beams then
        for slotName, beamNames in pairs(setup.beams) do
            local slotID = piece(slotName)
            beamsBySlotID[slotID] = {}
            for i, bname in ipairs(beamNames) do
                beamsBySlotID[slotID][i] = piece(bname)
            end
        end
    end
end

-- called when cargo count changes: toggles dontLand move type and starts/stops the beam-watch thread
function TransportAnimator.HasCargo(hasCargo)
    Signal(SIG_WATCH)
    SpMoveCtrl.SetGunshipMoveTypeData(unitID, "dontLand", hasCargo)
    if hasCargo then
        StartThread(TransportAnimator.WatchBeams)
    end
end

-- instantly position the slot piece at load height without animation; used when restoring from save/load
function TransportAnimator.Snap(teeData)
    teeData.beamPieces = beamsBySlotID[teeData.slotID]
    Move(teeData.slotID, 1, 0)
    Move(teeData.slotID, 2, -teeData.height)
    Move(teeData.slotID, 3, 0)
    Turn(teeData.slotID, 1, 0)
    Turn(teeData.slotID, 2, 0)
    Turn(teeData.slotID, 3, 0)
end

-- per-frame loop: damps transporter velocity during active animations and spawns tractor-beam CEGs
function TransportAnimator.WatchBeams()
    SetSignalMask(SIG_WATCH)
    while true do
        if (cargo.loadingCount + cargo.unloadingCount) > 0 then
            local vx, vy, vz = SpGetUnitVelocity(unitID)
            SpSetUnitVelocity(unitID, vx * ratio * ratio, vy * ratioY * ratioY, vz * ratio * ratio)
        end
        for teeID, teeData in pairs(cargo.transportees) do
            if teeData.beamPieces then
                for _, beamPiece in ipairs(teeData.beamPieces) do
                    local lpx, lpy, lpz = SpGetUnitPiecePosDir(unitID, beamPiece)
                    if teeData.loading then
                        -- tee is attached to slot: use actual slot world position as beam target
                        local tpx, tpy, tpz = SpGetUnitPiecePosDir(unitID, teeData.slotID)
                        SpSpawnCEG(cegName,
                            tpx, tpy + teeData.height, tpz,
                            (lpx - tpx) * cegScaleFactor,
                            (lpy - (tpy + teeData.height)) * cegScaleFactor,
                            (lpz - tpz) * cegScaleFactor,
                            1, 0)
                    elseif teeData.wbX then
                        -- unloading: tee is detached and moved via MoveCtrl, use cached position
                        SpSpawnCEG(cegName,
                            teeData.wbX, teeData.wbY + teeData.height, teeData.wbZ,
                            (lpx - teeData.wbX) * cegScaleFactor,
                            (lpy - (teeData.wbY + teeData.height)) * cegScaleFactor,
                            (lpz - teeData.wbZ) * cegScaleFactor,
                            1, 0)
                    else
                        -- idle: simple downward beam from the anchor piece
                        SpSpawnCEG(cegName,
                            lpx, lpy, lpz,
                            0, -10, 0,
                            1, 0)
                    end
                end
            end
        end
        Sleep(66)
    end
end

-- Load logic for attaching and moving the transportee
function TransportAnimator.Load(teeData, doAnim)
    SetSignalMask(TransportAnimator.SIG_LOAD)
    teeData.beamPieces = beamsBySlotID[teeData.slotID]
    CargoHandler.BeginLoading(cargo)

    local teePosX, teePosY, teePosZ = SpGetUnitPosition(teeData.id)
    local teeRotX, teeRotY, teeRotZ = SpGetUnitRotation(teeData.id)

    MovePieceWS(teeData.slotID, teePosX, teePosY, teePosZ, teeRotX, teeRotY, teeRotZ, nil, 0, nil, nil, nil, nil, nil, nil, 0) -- snap slot to transportee position at start of load anim
    SpUnitAttach(unitID, teeData.id, teeData.slotID)
    local count = CargoHandler.Register(teeData.id, teeData, cargo)
    if count == 1 then TransportAnimator.HasCargo(true) end

    local aborted = false
    if doAnim ~= false then
        for f = 0, loadTime - 1 do
            local t = progress[f]
            teeData.animProgress = t -- keep track of the progress for Killed() script
            local terX, terY, terZ, terRX, terRY, terRZ = getTransporterState()

            local cwx = t * terX   + (1 - t) * teePosX
            local cwy = t * terY   + (1 - t) * teePosY
            local cwz = t * terZ   + (1 - t) * teePosZ
            teeData.loading = true -- flag for WatchBeams; tee is attached so slot pos is authoritative

            MovePieceWS(teeData.slotID,
                cwx, cwy, cwz,
                teeRotX + t * shortAngle(terRX - teeRotX),
                teeRotY + t * shortAngle(terRY - teeRotY),
                teeRotZ + t * shortAngle(terRZ - teeRotZ),
                nil, teeData.height * t,
                terX, terY, terZ, terRX, terRY, terRZ, t)
            Sleep(33)
            if isDead(teeData.id) then aborted = true ; break end
        end
        -- clear loading flag
        teeData.loading = nil
        teeData.wbX = nil
    end
    resetSlot(teeData.slotID)
    if not aborted then -- finished the anim smoothly
        teeData.animProgress = 1
        Move(teeData.slotID, 2, -teeData.height)
    else -- something went wrong (unit was killed?)
        teeData.animProgress = nil
        local count = CargoHandler.Unregister(teeData.id, cargo)
        if count == 0 then TransportAnimator.HasCargo(false) end
    end
    CargoHandler.EndLoading(cargo)
end

-- Unload logic for detaching and moving the transportee.
-- When doAnim == false, the unit is only detached in-place with no position change.
function TransportAnimator.Unload(teeData, goalX, goalY, goalZ, doAnim)
    CargoHandler.BeginUnloading(cargo)
    SpUnitDetach(teeData.id)

    if doAnim ~= false then
        -- offset goal by the slot's world-space offset from unit center, so the tee drops from the slot's actual position
        local px, py, pz    = SpGetUnitPiecePosDir(unitID, teeData.slotID)
        local terX, _, terZ = SpGetUnitPosition(unitID)
        goalX = goalX + (px - terX)
        goalZ = goalZ + (pz - terZ)
        goalY = SpGetGroundHeight(goalX, goalZ)

        SpMoveCtrl.Enable(teeData.id) -- unlike Load(), Unload moves the unit via movectrl after detaching
        local startRX, startRY, startRZ       = SpGetUnitRotation(teeData.id)
        local initTerRX, initTerRY, initTerRZ = SpGetUnitRotation(unitID)
        local teeDefID = SpGetUnitDefID(teeData.id)
        local goalRX, goalRY, goalRZ
        if UnitDefs[teeDefID] and UnitDefs[teeDefID].upright then
            goalRX, goalRY, goalRZ = 0, startRY, 0
        else
            local nx, ny, nz = SpGetGroundNormal(goalX, goalZ)
            goalRX = math.atan2(-nz, ny)
            goalRY = startRY
            goalRZ = math.atan2(nx, ny)
        end

        local aborted = false
        for f = 0, loadTime - 1 do
            local t = progress[f]
            teeData.animProgress = 1 - t -- keep track of our progress for Killed() script
            local spx, spy, spz = SpGetUnitPiecePosDir(unitID, teeData.slotID)
            local cpx = t * goalX + (1 - t) * spx
            local cpy = t * goalY + (1 - t) * spy
            local cpz = t * goalZ + (1 - t) * spz
            teeData.wbX = cpx -- cache transportee position
            teeData.wbY = cpy
            teeData.wbZ = cpz
            SpMoveCtrl.SetPosition(teeData.id, cpx, cpy, cpz)

            local terRX, terRY, terRZ = SpGetUnitRotation(unitID)
            -- track transporter rotation changes so the tee's start-rotation follows the carrier during animation
            local fromRX = startRX + shortAngle(terRX - initTerRX)
            local fromRY = startRY + shortAngle(terRY - initTerRY)
            local fromRZ = startRZ + shortAngle(terRZ - initTerRZ)
            SpMoveCtrl.SetRotation(teeData.id,
                goalRX * t + fromRX * (1 - t),
                goalRY * t + fromRY * (1 - t),
                goalRZ * t + fromRZ * (1 - t))
            Sleep(33)
            if isDead(teeData.id) then aborted = true ; break end
        end
        teeData.wbX = nil ; teeData.wbY = nil ; teeData.wbZ = nil -- invalidate cache

        if not aborted then -- unload anim completed, ensure unit is at final position/rotation
            SpMoveCtrl.SetPosition(teeData.id, goalX, goalY, goalZ)
            SpMoveCtrl.SetRotation(teeData.id, goalRX, goalRY, goalRZ)
            SpMoveCtrl.Disable(teeData.id)
        end
    end

    resetSlot(teeData.slotID)
    local count = CargoHandler.Unregister(teeData.id, cargo)
    if count == 0 then TransportAnimator.HasCargo(false) end
    CargoHandler.EndUnloading(cargo)
end
