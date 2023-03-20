local gadgetEnabled = Spring.GetModOptions().experimentalimprovedtransports

function gadget:GetInfo()
    return {
        name = "Instant Unload",
        desc = "Allows Flood load & unload",
        author = "aZaremoth, unload support added by MaDDoX",
        date = "March, 2015",
        license = "Public Domain, or the least-restrictive license your country allows.",
        layer = 1,
        enabled = gadgetEnabled,
    }
end
------------------------------------------------------------------------
include("LuaRules/Configs/customcmds.h.lua")
--- [Deprecated] new lua core is added)
--VFS.Include("LuaRules/Utilities/utilities_emul.lua")
--VFS.Include("LuaRules/Utilities/ClampPosition.lua")
VFS.Include("gamedata/taptools.lua")


if gadgetHandler:IsSyncedCode() then

--------------------------------------------------------------------------------
--region  SYNCED
--------------------------------------------------------------------------------

--local GiveClampedOrderToUnit = Spring.Utilities.GiveClampedOrderToUnit
local CMD_INSERT 		= CMD.INSERT
local CMD_MOVE			= CMD.MOVE
local CMD_REMOVE        = CMD.REMOVE
local CMD_STOP			= CMD.STOP
local CMD_GUARD			= CMD.GUARD
local CMD_LOAD_ONTO		= CMD.LOAD_ONTO
local CMD_SET_WANTED_MAX_SPEED = CMD.SET_WANTED_MAX_SPEED   -- 70
local CMD_UNLOAD_UNIT   = 81 --CMD.UNLOAD_UNIT   --81
local CMD_UNLOAD_UNITS  = 80 --CMD.UNLOAD_UNITS  --80
local CMD_LOAD_UNITS	= CMD.LOAD_UNITS
local CMD_OPT_INTERNAL 	= CMD.OPT_INTERNAL

local loadtheseunits = {}               --// { [passengerUnitID] = transportID, ... }
    --- Whenever an unload is registered, this table holds which transports are moving towards unload range
local transportstounload = {}             --// { [transportID]={ x, y, z, r }, ... } || r == nil  =>  unload click
local passengermovingtoload = {}
local transportmovingtoload = {}          --// { [transportID]={{x, y, z, r, f}, ...} || f = frame after when it should be tracked
    --- 'Assignable' changes after a load command is registered, transportcapacity only changes after actual loading
local currentassignablecapacity = {}    --// { [transportID] = number, ...} should be made global in Initialize()
local currenttransportcapacity = {}
local unitisintransport = {}
local passengers = {}                   --// [transportID]={ passengerUID1 = true, passengerUID2 = true, ... }
local passengerscount = {}
local queueMovePassengers = {}      --// { [unitID] = frame, ... }
local queuedMoveCommands = {}       --// { unitID=unitID, shift=shift, pos={x,y,z}}

local spGetAllUnits = Spring.GetAllUnits
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID    = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local spUnitAttach = Spring.UnitAttach
local spUnitDetach = Spring.UnitDetach
local spUnitDetachFromAir = Spring.UnitDetachFromAir
local spSetUnitLoadingTransport = Spring.SetUnitLoadingTransport
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder

local mcSetPosition         = Spring.MoveCtrl.SetPosition
local mcDisable             = Spring.MoveCtrl.Disable
local mcEnable              = Spring.MoveCtrl.Enable

local rand = math.random
local unloadScatterDist = 30 -- Max scatter move distance after unit is unloaded

local function sqr (x)
    return math.pow(x, 2)
end

function gadget:Initialize()
    _G.currentassignablecapacity = currentassignablecapacity
    _G.passengerscount = passengerscount   --// making it global for unsynced access via SYNCED table
    local allUnits = spGetAllUnits()
    for i = 1, #allUnits do
        local unitID    = allUnits[i]
        local unitDefID = spGetUnitDefID(unitID)
        gadget:UnitCreated(unitID, unitDefID)
    end
end

local unitTransportCapacity = {}
local unitCantBeTransported = {}
local unitLoadingRadius = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isTransport then
		unitTransportCapacity[unitDefID] = unitDef.transportCapacity
	end
	unitCantBeTransported[unitDefID] = unitDef.cantBeTransported
	unitLoadingRadius[unitDefID] = unitDef.loadingRadius
end

function gadget:UnitCreated(unitID, unitDefID) --, team, builderID
    unitisintransport[unitID] = false
    passengermovingtoload[unitID] = false
    if not unitTransportCapacity[unitDefID] then
        return
	end
    local transportcapacity = unitTransportCapacity[unitDefID]
    if transportcapacity == nil then
        transportcapacity = 0
    end
    currenttransportcapacity[unitID] = transportcapacity
    currentassignablecapacity[unitID] = transportcapacity
    if not passengerscount[unitID] then
        passengerscount[unitID] = 0
    end
    --_G.currentassignablecapacity = currentassignablecapacity
    --Spring.Echo("Assignable capacity table count: "..pairs_len(currentassignablecapacity))
    transportmovingtoload[unitID] = nil
end

-- Does this unit has available transport capacity?
local function hasAssignableCapacity(unitID)
    --Spring.Echo("Current assignable capacity: ",tostring(currentassignablecapacity[unitID]))
    return currentassignablecapacity[unitID] and tonumber(currentassignablecapacity[unitID]) > 0
end

local function hasCurrentCapacity(unitID)
    return currenttransportcapacity[unitID] and tonumber(currenttransportcapacity[unitID]) > 0
end

local function CancelLoad(unitID)
    for pUnitID, transporterID in pairs(loadtheseunits) do
        if pUnitID == unitID                            -- passenger received STOP/MOVE
                or transporterID == unitID then         -- transporter received STOP/MOVE
            currentassignablecapacity[transporterID] = currentassignablecapacity[transporterID] + 1
            -- Spring.Echo(currentassignablecapacity[transporterID])
            loadtheseunits[pUnitID] = nil
        end
    end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
    local transportcapacity = unitTransportCapacity[unitDefID] or 0
    local loadingradius = unitLoadingRadius[unitDefID]

    --Spring.Echo("CMD ID: "..cmdID.." for unit: "..unitID)

    if transportstounload[unitID] ~= nil
            and cmdID ~= CMD_SET_WANTED_MAX_SPEED and cmdID ~= 1 then   -- 1 == CMD_INSERT (+others)
        --Spring.Echo("Unload canceled by cmdID: "..cmdID)
        transportstounload[unitID] = nil
        --currentassignablecapacity[unitID] = currentassignablecapacity[unitID] + 1
    end

    --if cmdID ~= CMD_SET_WANTED_MAX_SPEED and cmdID ~= 1 then -- 1 == CMD_INSERT (+others) then
    -- If transporter or unit to be loaded is moved or stop, cancel load
    if cmdID == CMD_MOVE or cmdID == CMD_STOP then
        --TODO: Fix this. It's a mess..
        --if loadtheseunits[unitID] ~= nil then
        --    --Spring.Echo("Canceling passenger load of "..unitID)
        --    CancelLoad(unitID)
        --end
        --if transportmovingtoload[unitID] then
        --    if spGetGameFrame() > transportmovingtoload[unitID] then
        --        --Spring.Echo("Canceling transporter load of "..unitID)
        --        transportmovingtoload[unitID] = loadingradius --TODO: test; was nil
        --        CancelLoad(unitID)
        --    end
        --end
    end

    if cmdID == CMD_UNLOAD_UNITS or cmdID == CMD_UNLOAD_UNIT then
        --Spring.Echo(DebugiTable(cmdParams))
        local x, y, z = cmdParams[1], cmdParams[2], cmdParams[3] -- x, y, z position of click
        -- Set radius when cmdID == UNLOAD_UNITS (area unload)
        transportstounload[unitID] = { x = x, y = y, z = z, r = (cmdID == CMD_UNLOAD_UNITS and cmdParams[4] or nil) }
        --Spring.Echo("Added ttu: "..unitID)
        return true
    -- Any command issued between issue-unload and actual unload has to update currentassignablecapacity
    end

    if cmdID == CMD_LOAD_ONTO then -- (76) LOAD ONTO a TRANSPORT, checks if can be transported
        local transportID = cmdParams[1]            --Spring.Echo("load command registered")

        if canBeTransported[unitDefID] and hasAssignableCapacity(transportID)
                and not unitisintransport[unitID] and not loadtheseunits[unitID] then
            Spring.GiveOrderToUnit(unitID, CMD_GUARD, {transportID}, {})
            loadtheseunits[unitID] = transportID
            currentassignablecapacity[transportID] = currentassignablecapacity[transportID] - 1
            --Spring.Echo("Current assignable capacity: "..currentassignablecapacity[transportID])
            passengermovingtoload[unitID] = true
        else
            return false
        end
    end

    -- LOAD UNITS     // check if it's a transporter
    if cmdID == CMD_LOAD_UNITS and transportcapacity > 0 then   --(75)
        if hasCurrentCapacity(unitID) and hasAssignableCapacity(unitID) then
            local MyTeam = spGetUnitTeam(unitID)
            local movetype = (spGetUnitMoveTypeData(unitID)).name
            local tx, ty, tz = spGetUnitPosition(unitID) -- transport position
            local x = cmdParams[1] -- x is passenger's unitID if only oneclicked, or the x-position of center of the load circle
            local y = cmdParams[2] -- y-position of center of the load circle
            local z = cmdParams[3] -- z-position of center of the load circle
            local r = cmdParams[4] -- radius of the load circle
            --Spring.Echo("Load | Move Type: "..movetype)
            ------------------------------------BUNKER----------------------------------------------------
            if movetype == [[static]] then --is it a bunker?
                if (r == nil) then	-------- load a single unit
                    local xTeam = spGetUnitTeam(x)
                    if canBeTransported[spGetUnitDefID(x)] and xTeam == MyTeam
                            and currentassignablecapacity[unitID] > 0 and (unitisintransport[x] == false)
                            and (loadtheseunits[x] == nil) then
                        loadtheseunits[x] = unitID
                        currentassignablecapacity[unitID] = (currentassignablecapacity[unitID] - 1)
                        -- Spring.Echo(currentassigablecapacity[unitID])
                        passengermovingtoload[x] = true
                        spGiveOrderToUnit(x, CMD_MOVE, {tx,ty,tz}, {})
                    end
                else -------- load multiple units
                    local UnitsAroundCommand = Spring.GetUnitsInCylinder(x,z,r)
                    for _,cUnitID in ipairs(UnitsAroundCommand) do -- check all units in transport pick-up >c<ircle
                        local cTeam = spGetUnitTeam(cUnitID)
                        if ((cUnitID ~= unitID) and (cTeam == MyTeam)) then
                            local cUnitDefID = spGetUnitDefID(cUnitID)
                            if not unitCantBeTransported[cUnitDefID]
                                    and (currentassignablecapacity[unitID] > 0)
                                    and (unitisintransport[cUnitID] == false)
                                    and (loadtheseunits[cUnitID] == nil) then
                                loadtheseunits[cUnitID] = unitID
                                currentassignablecapacity[unitID] = (currentassignablecapacity[unitID] - 1)
                                -- Spring.Echo(currentassigablecapacity[unitID])
                                passengermovingtoload[cUnitID] = true
                                spGiveOrderToUnit(cUnitID, CMD_MOVE, {tx,ty,tz}, {})
                                --							Spring.GiveOrderToUnit(unitID, CMD_WAIT, {}, {})
                            end
                        end
                    end
                end
                ------------------------------------MOBILE----------------------------------------------------
            else
                transportmovingtoload[unitID] = { x = x, y = y, z = z, r = r, f = spGetGameFrame()+1 }   -- start tracking it in f frames
                -- load single unit
                if r == nil then
                    local xTeam = spGetUnitTeam(x)
                    if canBeTransported[spGetUnitDefID(x)]
                            and xTeam == MyTeam and currentassignablecapacity[unitID] > 0
                            and not unitisintransport[x] and loadtheseunits[x] == nil then
                        loadtheseunits[x] = unitID
                        currentassignablecapacity[unitID] = currentassignablecapacity[unitID] - 1
                        --Spring.Echo("New current assignablecapacity: "..currentassignablecapacity[unitID])
                        passengermovingtoload[x] = true
                        local px, py, pz = spGetUnitPosition(x) -- passenger position
                        queuedMoveCommands[#queuedMoveCommands+1] = { unitID=unitID,
                                                                      shift=cmdOptions.shift,
                                                                      pos={x=px,y=py,z=pz}
                        }
                        --if cmdOptions.shift then
                        --    spGiveOrderToUnit(unitID, CMD_INSERT, {-1, CMD_MOVE, CMD_OPT_INTERNAL, px,py,pz }, {"alt"} )
                        --else
                        --    spGiveOrderToUnit(unitID, CMD_MOVE, {px,py,pz}, {})
                        --end
                    end
                else
                    -- load multiple units
                    local UnitsAroundCommand = spGetUnitsInCylinder(x,z,r)
                    --GiveOrderToUnit(unitID,CMD_INSERT,{-1,CMD_CAPTURE,CMD_OPT_INTERNAL+1,unitID2},{"alt"});
                    --GiveOrderToUnit(unitID,CMD_INSERT,{cmd.tag,CMD_CAPTURE,CMD_OPT_INTERNAL+1,unitID2},{});
                    --GiveOrderToUnit(unitID,CMD_INSERT,{0,CMD_STOP,0},{"alt"});
                    queuedMoveCommands[#queuedMoveCommands+1] = { unitID=unitID,
                                                                  --shift=cmdOptions.shift,
                                                                  pos={x=x,y=y,z=z}
                                                                }
                    for _,cUnitID in ipairs(UnitsAroundCommand) do -- check all units in transport pick-up >c<ircle
                        local cTeam = spGetUnitTeam(cUnitID)
                        if (cUnitID ~= unitID) and (cTeam == MyTeam) then
                            local cUnitDefID = spGetUnitDefID(cUnitID)
                            if canBeTransported[cUnitDefID]
                                    and currentassignablecapacity[unitID] > 0
                                    and not unitisintransport[cUnitID]
                                    and not loadtheseunits[cUnitID] then
                                loadtheseunits[cUnitID] = unitID
                                currentassignablecapacity[unitID] = currentassignablecapacity[unitID] - 1
                                -- Spring.Echo(currentassigablecapacity[unitID])
                                passengermovingtoload[cUnitID] = true
                                spGiveOrderToUnit(unitID, CMD_REMOVE, {CMD_MOVE}, {"alt"})
                                spGiveOrderToUnit(cUnitID, CMD_MOVE, {x,y,z}, {})
                            end
                        end
                    end
                end
            end
            return true
        else
            return false end
    end

    return true

end

function gadget:UnitIdle(unitID, unitDefID, unitTeam)
    for mpUnitID, _ in pairs(passengermovingtoload) do -- remove arrived passengers
        if (unitID == mpUnitID) then
            passengermovingtoload[mpUnitID] = false	-- passenger arrived at pick-up point or was stopped
        end
    end
    --local unloadData = transportstounload[unitID] -- = data.x, .y, .z
    --if unloadData then
    --    local sqrDistanceFromTarget = Distance2D(unitID, unloadData.x, unloadData.z)
    --    Spring.Echo("Stuck transport dist from target: "..sqrDistanceFromTarget)
    --end
end

function gadget:UnitDestroyed(unitID, unitDefID, team, attacker)
    local transporterID = loadtheseunits[unitID]
    if transporterID then
        currentassignablecapacity[transporterID] = (currentassignablecapacity[transporterID] + 1)	-- remove dead unit from assigned units list
    end
    loadtheseunits[unitID] = nil
    transportstounload[unitID] = nil
    passengermovingtoload[unitID] = nil
    passengerscount[unitID] = nil
    for pUnitID, tunitID in pairs(loadtheseunits) do	-- check if transporter was killed
        if (unitID == tunitID) then
            loadtheseunits[pUnitID] = nil
            transportmovingtoload[unitID] = nil
        end
    end
end

local function ShowUnit (unitID, enable)
    Spring.SetUnitNoDraw (unitID, not enable)
    Spring.SetUnitNoSelect (unitID, not enable)
    Spring.SetUnitNoMinimap (unitID, not enable)
    return
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
    ---- Let's ignore naval transports
    --local transportuDef = UnitDefs[transportID]
    --local minUnloadDistance = tonumber(transportuDef.customParams.minunloaddistance)
    --if not minUnloadDistance or minUnloadDistance < 1 then
    --    return
    --end
    unitisintransport[unitID] = true
    if passengers[transportID] == nil then
        passengers[transportID] = {}
    end
    passengers[transportID][unitID] = true
    if currenttransportcapacity[transportID] then
        currenttransportcapacity[transportID] = currenttransportcapacity[transportID] - 1
    else
        --Spring.Echo("current transport capacity not initialized for "..transportID)
    end
    if passengerscount[transportID] then
        passengerscount[transportID] = passengerscount[transportID]+1
    end
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
    unitisintransport[unitID] = false
    if passengers[transportID] then
        passengers[transportID][unitID] = nil
    end
    --Spring.Echo("New count after unload: "..pairs_len(passengers[transportID]) or "nil")
    if not currenttransportcapacity[transportID] or not currentassignablecapacity[transportID] then
        return
    end
    currenttransportcapacity[transportID] = (currenttransportcapacity[transportID] + 1)
    currentassignablecapacity[transportID] = (currentassignablecapacity[transportID] + 1)
    if passengerscount[transportID] then
        passengerscount[transportID] = passengerscount[transportID]-1
    end


    local transportToUnload = transportstounload[transportID]   --transport to unload

    if transportToUnload == nil then
        return end

    --Spring.SetUnitPosition ( unitID, ttu.x, ttu.z )
    --Spring.Echo("Unload registered, assignable capacity: "..currentassignablecapacity[transportID])
    ShowUnit(unitID, false)
    -- We have to punt the move control by 10 frames after unload, or else it twitches and fails.
    -- PS.: This was found by shameless trial and error. No idea if it's an engine bug or expected behavior.
    queueMovePassengers[#queueMovePassengers +1]={ unitID = unitID, frame = spGetGameFrame()+10,
                                                   clickPos = { x = transportToUnload.x, y = transportToUnload.y, z = transportToUnload.z, r = transportToUnload.r }}
    -- If transport is empty now, nil it from table
    if pairs_len(passengers[transportID]) <= 0 then
        transportstounload[transportID] = nil end
end

function gadget:GameFrame(f)
    for i, data in ipairs(queueMovePassengers) do
        local unitID = tonumber(data.unitID)
        local frame = tonumber(data.frame)
        local clickPos = data.clickPos
        if f >= frame and Spring.ValidUnitID(unitID) then
            local px, py, pz = spGetUnitPosition(unitID)
            if px ~= nil and py ~= nil and pz ~= nil then
                mcEnable(unitID)
                -- Issue a move command instead of setting offset position directly (or units might get stuck)
                mcSetPosition( unitID, px, clickPos.y, pz) -- clickPos.y || px
                mcDisable(unitID)
                local scatpx = px + rand(-unloadScatterDist,unloadScatterDist)
                local scatpz = pz + rand(-unloadScatterDist,unloadScatterDist)
                local scatpy = Spring.GetGroundHeight(scatpx, scatpz)
                if scatpy < 0 then scatpy = 0 end
                spGiveOrderToUnit(unitID, CMD_MOVE, { scatpx, py, scatpz }, {})
                Spring.SpawnCEG("scav-spawnexplo",scatpx,scatpy,scatpz,0,0,0)
                ShowUnit(unitID, true)
                table.remove(queueMovePassengers, i)
                scatpy = nil
            end
        end
    end
    -- Process Transports to Unload
    if f % 2 < .1 then
        --for unitID, data in pairs(transportstounload) do -- remove arrived passengers
        --    local sqrDistanceFromTarget = Distance2D(unitID, data.x, data.z)
        --    Spring.Echo("Distance 2D: "..tostring(sqrDistanceFromTarget) or "nil")
        --    if (unitID == unitID and isnumber(sqrDistanceFromTarget) and sqrDistanceFromTarget < 160000) then
        --        Spring.Echo("Transport "..mtUnitID.." arrived")
        --        transportmovingtoload[mtUnitID] = nil	-- transport arrived at pick-up point or was stopped
        --    end
        --end
        for transpUID, data in pairs(transportstounload) do
            local tx, ty, tz = spGetUnitPosition(transpUID)
            local transportuDef = UnitDefs[spGetUnitDefID(transpUID)]
            local sqrDistToTarget = Distance2D(transpUID, data.x, data.z)
            --Spring.Echo("Distance 2D: "..tostring(sqrDistToTarget) or "nil")
            if sqrDistToTarget < 6000 then
                -- Re-issue unload command here, to prevent air transports getting stuck
                spGiveOrderToUnit(transpUID, CMD_UNLOAD_UNIT, { data.x, data.y, data.z }, {})
                --local minUnloadDistance = tonumber(transportuDef.loadingRadius) / 2 or 150
                local minUnloadDistance = transportuDef.customParams.unloaddistance or 100
                --local minUnloadDistance = 100
                if (minUnloadDistance) then
                    local distance = math.sqrt(sqr(tx- data.x) + sqr(ty- data.y) + sqr(tz- data.z))
                    --Spring.Echo("current/min: "..distance.." / "..minUnloadDistance)
                    if distance <= tonumber(minUnloadDistance) then
                        -- actually unload all (for now) units
                        if passengers[transpUID] and pairs_len(passengers[transpUID])>0 then
                            --table.insert(passengers[transportID], unitID)
                            for passengerUID in pairs(passengers[transpUID]) do
                                spSetUnitLoadingTransport(passengerUID, transpUID) --disable collision temporarily
                                if transportuDef.isAirUnit then
                                    spUnitDetachFromAir(passengerUID)
                                else
                                    spUnitDetach(passengerUID)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    -- Process Units to be Loaded
    if f % 32 > .1 then
        for passengerUID, transpUID in pairs(loadtheseunits) do ----// { [passengerUnitID] = transportID, ... }
        local x, y, z = spGetUnitPosition(transpUID) -- transport position
        local transportuDef = UnitDefs[spGetUnitDefID(transpUID)]
        --local transportcapacity = transportuDef.transportCapacity
        --local loadingradius = tonumber(transportuDef.loadingRadius) or 100
        local loadingradius = transportuDef.customParams.mloaddistance or 100
        local UnitsAroundTransport = spGetUnitsInCylinder(x,z,loadingradius)
        for _, thisuID in ipairs(UnitsAroundTransport) do
            local thisUDID = spGetUnitDefID(thisuID)
            if thisuID == passengerUID and canBeTransported[thisUDID] then
                -- Actually "load" the unit:
                local cegposx, cegposy, cegposz = Spring.GetUnitPosition(passengerUID)
                Spring.SpawnCEG("scav-spawnexplo",cegposx,cegposy,cegposz,0,0,0)
                spSetUnitLoadingTransport(transpUID, thisuID)
                spUnitAttach(transpUID, passengerUID, 0)          -- Currently only attach to the 'root' object
                loadtheseunits[passengerUID] = nil
                local p_uID = UnitDefs[spGetUnitDefID(passengerUID)]
                if (p_uID.repairSpeed > 0) then -- builder units will automatically repair the transport / bunker
                    spGiveOrderToUnit(passengerUID, CMD_GUARD, { transpUID }, {})
                end
            end
        end
        -- check if passengers AND transport are still on the run, if not remove from pick-up list
        local transporterID = loadtheseunits[passengerUID]
        local assignablecapacity = currentassignablecapacity[transporterID]
        if not passengermovingtoload[passengerUID]
                and not transportmovingtoload[transporterID]
                and assignablecapacity then
            currentassignablecapacity[transporterID] = assignablecapacity + 1
            loadtheseunits[passengerUID] = nil
        end
    end
    end
    -- Process queued MoveCommands
    for i, data in ipairs(queuedMoveCommands) do
        local unitID = tonumber(data.unitID)
        local shift = data.shift
        local x,y,z = tonumber(data.pos.x), tonumber(data.pos.y), tonumber(data.pos.z)
        if shift then
            spGiveOrderToUnit(unitID, CMD_INSERT, {-1, CMD_MOVE, CMD_OPT_INTERNAL, x,y,z }, {"alt"} )
        else
            spGiveOrderToUnit(unitID, CMD_MOVE, {x,y,z}, {})
        end
        table.remove(queuedMoveCommands, i)
    end
end

--------------------------------------------------------------------------------
--endregion  END SYNCED
--------------------------------------------------------------------------------
else
--------------------------------------------------------------------------------
--region  UNSYNCED
--------------------------------------------------------------------------------

local morphUnits

local spGetGameFrame = Spring.GetGameFrame
local glBlending = gl.Blending
local glDepthTest = gl.DepthTest
local glPushMatrix     = gl.PushMatrix
local glPopMatrix      = gl.PopMatrix
local glTranslate      = gl.Translate
local glBlending       = gl.Blending
local glDepthTest      = gl.DepthTest
local glBillboard      = gl.Billboard
local glColor          = gl.Color
local glText           = gl.Text
local GL_LEQUAL        = GL.LEQUAL
local GL_ONE           = GL.ONE
local GL_SRC_ALPHA     = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local spGetLocalTeamID = Spring.GetLocalTeamID
local spGetUnitTeam    = Spring.GetUnitTeam
local GetSpectatingState = Spring.GetSpectatingState
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spIsUnitInView = Spring.IsUnitInView
local UItextColor = {1.0, 1.0, 0.6, 1.0}
local UItextSize = 14.0

function gadget:DrawWorld()
   if not next(SYNCED.currentassignablecapacity) then
       return --//no transports to draw
   end

   glBlending(GL_SRC_ALPHA, GL_ONE)
   glDepthTest(GL_LEQUAL)

   --- [BEGIN] Draw Transports current assignable capacity
   --Spring.Echo("Len: "..pairs_len(SYNCED.currentassignablecapacity))
   local localTeam = spGetLocalTeamID()
   for unitID, capacity in pairsByKeys(SYNCED.currentassignablecapacity) do
       --local capacity = SYNCED.currentassignablecapacity[unitID]
       if spIsUnitInView(unitID) and spGetUnitTeam(unitID) == localTeam then
           local ux, uy, uz = spGetUnitViewPosition(unitID)
           glPushMatrix()
           glTranslate(ux, uy, uz)
           glBillboard()
           glColor(UItextColor)
           local passengerscount = SYNCED.passengerscount[unitID]
           --glText("<" .. capacity..">", 20.0, -25.0, UItextSize, "cno")
           glText("[" .. passengerscount.."]", 0.0, -15.0, UItextSize, "cno")
           glPopMatrix()
       end
   end
   --- [END] Draw Transports current assignable capacity

   glDepthTest(false)
   glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
end

--------------------------------------------------------------------------------
--endregion  END UNSYNCED
--------------------------------------------------------------------------------
end
