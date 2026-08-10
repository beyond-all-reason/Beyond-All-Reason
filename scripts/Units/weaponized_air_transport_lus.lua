-- weaponized_air_transport_lus.lua
-- derived from generic_air_transport_lus.lua, for weaponized transports
-- Included handler files run in this same environment and share all globals defined here.
--
-- Handler files (via include(), path relative to scripts/):
--   CargoHandler.lua              -- slot management, load/unload sequencing  --> CargoHandler
--   TransportAnimator.lua         -- velocity damping, CEG beams, attach/detach animation  --> TransportAnimator
--   GenericAnimator.lua           -- thrusters, banking, idle hover, killed  --> GenericAnimator
--   WeaponAnimator.lua	           -- weapon pieces and logic --> WeaponAnimator
--
-- Per-unit config file (via VFS.Include(), path relative to game root):
--   <unitName>/setup.lua  -- cargo slots, load method, and anim config in one table

TransportAPI = GG.TransportAPI
if not TransportAPI then
	spEcho("TransportAPI must be loaded before this unit script")
	return false
end

-- SPRING API LOCALS
local spMoveCtrlSetGunshipMoveTypeData = Spring.MoveCtrl.SetGunshipMoveTypeData
local spGetUnitIsTransporting         = Spring.GetUnitIsTransporting
local spValidUnitID                   = Spring.ValidUnitID
local spGetUnitIsDead                 = Spring.GetUnitIsDead
local spUnitDetach                    = Spring.UnitDetach
local spEcho                          = Spring.Echo

-- CUSTOM SETTINGS
-- (none)

-- CONSTANTS
local AIR_TRANSPORT_PATH = "scripts/Units/airTransports/"  -- prefix for VFS.Include (from game root)
local AIR_TRANSPORT_INC  = "Units/airTransports/"          -- prefix for include()    (from scripts/)

-- VARIABLES
local unitDef            = UnitDefs[unitDefID]
local unitName           = unitDef.name
local UNIT_CONFIG_PATH   = AIR_TRANSPORT_PATH .. unitName .. "/"
transporterID = unitID -- just to keep it consistent with other envs

include(AIR_TRANSPORT_INC .. "CargoHandler.lua")
include(AIR_TRANSPORT_INC .. "TransportAnimator.lua")
include(AIR_TRANSPORT_INC .. "GenericAnimator.lua")
include(AIR_TRANSPORT_INC .. "WeaponAnimator.lua")

-- VARIABLES (post-include)
local animSetup     = VFS.Include(UNIT_CONFIG_PATH .. "setup.lua")
local transportSetup = VFS.Include(AIR_TRANSPORT_PATH .. "loadpadsdefinitions/loadpaddefs.lua")
local thisSize      = "size" .. (unitDef.customParams.transporterseats or "0")
cargo               = nil  -- will be initialized in script.Create

-- SCRIPT FUNCTIONS
-- function script.Create()                -- Initialize handlers; restore preexisting passengers; start idle hover thread
-- function PerformLoad(...)               -- Initiate smooth animated load sequence for a passenger
-- function PerformLoadInstant(...)        -- Initiate instant (no animation) load for a passenger
-- function PerformUnload(...)             -- Initiate animated unload; instant cleanup if passenger is dead/invalid
-- function PerformUnloadInstant(...)      -- Initiate instant unload for a passenger (used by ReorganizeAndLoad)
-- function script.Activate()             -- Engine callback: unit entered active state
-- function script.Deactivate()           -- Engine callback: unit entered inactive state
-- function script.MoveRate(...)          -- Engine callback: unit move speed changed
-- function script.Killed(...)            -- Engine callback: unit killed; return wreck level
-- function script.AimWeapon(...)         -- Engine callback: rotate aim piece toward heading/pitch; return true to confirm
-- function script.FireWeapon()           -- Engine callback: fire weapon animation hook
-- function script.QueryWeapon()          -- Engine callback: return the fire piece ID
-- function script.AimFromWeapon()        -- Engine callback: return the aim-from piece ID

---@return boolean|nil success
function script.Create()
    -- validate and initialize handlers with config; handlers expose functions that the unit script calls
    -- in response to game events (see PerformLoad, PerformUnload, etc below)
    if not transportSetup[thisSize] then
        spEcho("Invalid transporterSeats in unitDef customParams: " .. tostring(unitDef.customParams.transporterseats))
        return false
    end
    cargo = CargoHandler.Init(transportSetup[thisSize].cargo)
    TransportAnimator.Init(transportSetup[thisSize].loadMethod)
    GenericAnimator.Init(animSetup.anim)
    WeaponAnimator.Init(animSetup.wpn)
    GenericAnimator.HideThrusters()
    spMoveCtrlSetGunshipMoveTypeData(transporterID, "dontLand", false)
    CargoHandler.HideSlots(cargo)

    -- load preexisting cargo (save/load)
    local existing = spGetUnitIsTransporting(transporterID)
    table.sort(existing, function(a, b)
        return TransportAPI.GetPassengerSize(a) > TransportAPI.GetPassengerSize(b) -- largest first for correct slot assignment
    end)
    for _, passengerID in ipairs(existing) do
        local passengerData = CargoHandler.FindSlot(passengerID, cargo)
        if passengerData then
            local count = CargoHandler.Register(passengerID, passengerData, cargo)
            CargoHandler.BeginLoading(cargo)
            TransportAnimator.Snap(passengerData)
            CargoHandler.EndLoading(cargo)
            if count == 1 then TransportAnimator.HasCargo(true) end
        end
    end

    -- start idleHover thread
    StartThread(GenericAnimator.IdleHover)
end

---@param passengerID number
function PerformLoad(passengerID) -- entry point from gadget transport handler: called on load approval, and by ReorganizeAndLoad
    local passengerData = CargoHandler.FindSlot(passengerID, cargo, true)
    if not passengerData then return end
    StartThread(TransportAnimator.Load, passengerData)
end

---@param passengerID number
function PerformLoadInstant(passengerID) -- instant load not used currently
    local passengerData = CargoHandler.FindSlot(passengerID, cargo)
    if not passengerData then return end
    StartThread(TransportAnimator.Load, passengerData, false)
end

---@param passengerID number
---@param goalX number
---@param goalY number
---@param goalZ number
function PerformUnload(passengerID, goalX, goalY, goalZ) -- entry point from gadget transport handler: called once per passenger
    local passengerData = cargo.passengers[passengerID]
    if passengerData and spValidUnitID(passengerID) and not spGetUnitIsDead(passengerID) then
        StartThread(TransportAnimator.Unload, passengerData, goalX, goalY, goalZ)
    else -- unit invalid/dead: reset slot and unregister without animating
        if spValidUnitID(passengerID) then -- unit is valid but dead
            spUnitDetach(passengerID)
        end
        if passengerData and passengerData.slotID then
            Move(passengerData.slotID, 1, 0)  Move(passengerData.slotID, 2, 0)  Move(passengerData.slotID, 3, 0)
            Turn(passengerData.slotID, 1, 0)  Turn(passengerData.slotID, 2, 0)  Turn(passengerData.slotID, 3, 0)
        end
        local count = CargoHandler.Unregister(passengerID, cargo)
        if count == 0 then TransportAnimator.HasCargo(false) end
    end
end

---@param passengerID number
---@param goalX number
---@param goalY number
---@param goalZ number
function PerformUnloadInstant(passengerID, goalX, goalY, goalZ) -- used by ReorganizeAndLoad
    local passengerData = cargo.passengers[passengerID]
    if not passengerData then return end
    StartThread(TransportAnimator.Unload, passengerData, goalX, goalY, goalZ, false)
end

function script.Activate()   GenericAnimator.Activate()         end

function script.Deactivate() GenericAnimator.Deactivate()        end

---@param v number moveRate
function script.MoveRate(v)  GenericAnimator.MoveRate(v)         end

---@param s number|nil damageState
---@return number|nil restoreState
function script.Killed(s)    return GenericAnimator.Killed(s)    end

---@param wpnNum number weaponNumber
---@param heading number
---@param pitch number
---@return boolean aimSuccess
function script.AimWeapon(wpnNum, heading, pitch) return WeaponAnimator.AimWeapon(heading, pitch) end

---@return boolean fireSuccess
function script.FireWeapon() return WeaponAnimator.FireWeapon() end

---@return number readyState
function script.QueryWeapon() return WeaponAnimator.QueryWeapon() end

---@return number pieceNumber
function script.AimFromWeapon() return WeaponAnimator.AimFromWeapon() end
