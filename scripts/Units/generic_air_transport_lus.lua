-- generic_air_transport_lus.lua
-- Shared unit script for all tractor-beam air transports (armatlas, corvalk, corhvytrans, ...).
-- Included handler files run in this same environment and share all globals defined here.
--
-- Handler files (via include(), path relative to scripts/):
--   CargoHandler.lua              -- slot management, load/unload sequencing  --> CargoHandler
--   TransportAnimator.lua         -- velocity damping, CEG beams, attach/detach animation  --> TransportAnimator
--   GenericAnimator.lua           -- thrusters, banking, idle hover, killed  --> GenericAnimator
--
-- Per-unit config file (via VFS.Include(), path relative to game root):
--   <unitName>/setup.lua  -- cargo slots, load method, and anim config in one table

TransportAPI = GG.TransportAPI
if not TransportAPI then
	Spring.Echo("TransportAPI must be loaded before this unit script")
	return false
end

local unitDef            = UnitDefs[unitDefID]
local unitName           = unitDef.name
local AIR_TRANSPORT_PATH = "scripts/Units/airTransports/"  -- prefix for VFS.Include (from game root)
local AIR_TRANSPORT_INC  = "Units/airTransports/"          -- prefix for include()    (from scripts/)
local UNIT_CONFIG_PATH   = AIR_TRANSPORT_PATH .. unitName .. "/"
transporterID = unitID -- just to keep it consistent with other envs


SpGetUnitDefID          = Spring.GetUnitDefID
SpGetUnitHeight         = Spring.GetUnitHeight
SpSetUnitRulesParam     = Spring.SetUnitRulesParam
SpEcho                  = Spring.Echo
SpGetUnitPosition       = Spring.GetUnitPosition
SpGetUnitCommands       = Spring.GetUnitCommands
SpGetGameFrame          = Spring.GetGameFrame
SpGetUnitRotation       = Spring.GetUnitRotation
SpGetUnitPiecePosDir    = Spring.GetUnitPiecePosDir
SpGetUnitVelocity       = Spring.GetUnitVelocity
SpSetUnitVelocity       = Spring.SetUnitVelocity
SpGetUnitIsDead         = Spring.GetUnitIsDead
SpGetGroundHeight       = Spring.GetGroundHeight
SpSpawnCEG              = Spring.SpawnCEG
SpUnitAttach            = Spring.UnitAttach
SpUnitDetach            = Spring.UnitDetach
SpValidUnitID           = Spring.ValidUnitID
SpMoveCtrl              = Spring.MoveCtrl
SpGetGroundNormal       = Spring.GetGroundNormal
SpGetUnitIsTransporting = Spring.GetUnitIsTransporting

include(AIR_TRANSPORT_INC .. "CargoHandler.lua")
include(AIR_TRANSPORT_INC .. "TransportAnimator.lua")
include(AIR_TRANSPORT_INC .. "GenericAnimator.lua")

local setup = VFS.Include(UNIT_CONFIG_PATH .. "setup.lua")

-- initialize handlers with config; handlers expose functions that the unit script calls 
-- in response to game events (see PerformLoad, PerformUnload, etc below)
cargo = CargoHandler.Init(setup.cargo)
TransportAnimator.Init(setup.loadMethod)
GenericAnimator.Init(setup.anim)

function script.Create()
    -- setup the default state
    GenericAnimator.HideThrusters()
    SpMoveCtrl.SetGunshipMoveTypeData(transporterID, "dontLand", false)
    CargoHandler.HideSlots(cargo)

    -- load preexisting cargo (save/load)
    local existing = SpGetUnitIsTransporting(transporterID)
    table.sort(existing, function(a, b)
        return TransportAPI.GetPassengerSize(a) > TransportAPI.GetPassengerSize(b) -- largest first for correct slot assignment
    end)
    for _, passengerID in ipairs(existing) do
        local passengerData = CargoHandler.FindSlot(passengerID, cargo)
        if passengerData then
            local count = CargoHandler.Register(passengerID, passengerData, cargo)
            TransportAnimator.Snap(passengerData)
            if count == 1 then TransportAnimator.HasCargo(true) end
        end
    end

    -- start idleHover thread
    StartThread(GenericAnimator.IdleHover)
end

function PerformLoad(passengerID) -- entry point from gadget transport handler: called on load approval, and by ReorganizeAndLoad
    local passengerData = CargoHandler.FindSlot(passengerID, cargo, true)
    if not passengerData then return end
    StartThread(TransportAnimator.Load, passengerData)
end

function PerformLoadInstant(passengerID) -- instant load not used currently
    local passengerData = CargoHandler.FindSlot(passengerID, cargo)
    if not passengerData then return end
    StartThread(TransportAnimator.Load, passengerData, false)
end

function PerformUnload(passengerID, goalX, goalY, goalZ) -- entry point from gadget transport handler: called once per passenger
    local passengerData = cargo.passengers[passengerID]
    if passengerData and SpValidUnitID(passengerID) and not SpGetUnitIsDead(passengerID) then
        StartThread(TransportAnimator.Unload, passengerData, goalX, goalY, goalZ)
    else -- unit invalid/dead: reset slot and unregister without animating
        if passengerData and passengerData.slotID then
            Move(passengerData.slotID, 1, 0)  Move(passengerData.slotID, 2, 0)  Move(passengerData.slotID, 3, 0)
            Turn(passengerData.slotID, 1, 0)  Turn(passengerData.slotID, 2, 0)  Turn(passengerData.slotID, 3, 0)
        end
        local count = CargoHandler.Unregister(passengerID, cargo)
        if count == 0 then TransportAnimator.HasCargo(false) end
    end
end

function PerformUnloadInstant(passengerID, goalX, goalY, goalZ) -- used by ReorganizeAndLoad
    local passengerData = cargo.passengers[passengerID]
    if not passengerData then return end
    StartThread(TransportAnimator.Unload, passengerData, goalX, goalY, goalZ, false)
end

-- engine callbacks mapped to pre-authored animations
function script.Activate()   GenericAnimator.Activate()         end
function script.Deactivate() GenericAnimator.Deactivate()        end
function script.MoveRate(v)  GenericAnimator.MoveRate(v)         end
function script.Killed(s)    return GenericAnimator.Killed(s)    end
