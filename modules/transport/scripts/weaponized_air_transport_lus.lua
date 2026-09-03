TransportAPI = GG.TransportAPI
if not TransportAPI then
	spEcho("TransportAPI must be loaded before this unit script")
	return false
end

local spMoveCtrlSetGunshipMoveTypeData = Spring.MoveCtrl.SetGunshipMoveTypeData
local spGetUnitIsTransporting = Spring.GetUnitIsTransporting
local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spUnitDetach = Spring.UnitDetach
local spEcho = Spring.Echo

local AIR_TRANSPORT_PATH = "modules/transport/scripts/airTransports/"
local AIR_TRANSPORT_INC = AIR_TRANSPORT_PATH

local unitDef = UnitDefs[unitDefID]
local unitName = unitDef.name
local UNIT_CONFIG_PATH = AIR_TRANSPORT_PATH .. unitName .. "/"
transporterID = unitID

include(AIR_TRANSPORT_INC .. "CargoHandler.lua")
include(AIR_TRANSPORT_INC .. "TransportAnimator.lua")
include(AIR_TRANSPORT_INC .. "GenericAnimator.lua")
include(AIR_TRANSPORT_INC .. "WeaponAnimator.lua")

local animSetup = VFS.Include(UNIT_CONFIG_PATH .. "setup.lua")
local transportSetup = VFS.Include(AIR_TRANSPORT_PATH .. "loadpadsdefinitions/loadpaddefs.lua")
local thisSize = "size" .. (unitDef.customParams.transporterseats or "0")
cargo = nil

---@return boolean|nil success
function script.Create()
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

	local existing = spGetUnitIsTransporting(transporterID)
	table.sort(existing, function(a, b)
		return TransportAPI.GetPassengerSize(a) > TransportAPI.GetPassengerSize(b)
	end)
	for _, passengerID in ipairs(existing) do
		local passengerData = CargoHandler.FindSlot(passengerID, cargo)
		if passengerData then
			local count = CargoHandler.Register(passengerID, passengerData, cargo)
			CargoHandler.BeginLoading(cargo)
			TransportAnimator.Snap(passengerData)
			CargoHandler.EndLoading(cargo)
			if count == 1 then
				TransportAnimator.HasCargo(true)
			end
		end
	end

	StartThread(GenericAnimator.IdleHover)
end

---@param passengerID number
function PerformLoad(passengerID)
	local passengerData = CargoHandler.FindSlot(passengerID, cargo, true)
	if not passengerData then
		return
	end
	StartThread(TransportAnimator.Load, passengerData)
end

---@param passengerID number
function PerformLoadInstant(passengerID)
	local passengerData = CargoHandler.FindSlot(passengerID, cargo)
	if not passengerData then
		return
	end
	StartThread(TransportAnimator.Load, passengerData, false)
end

---@param passengerID number
---@param goalX number
---@param goalY number
---@param goalZ number
function PerformUnload(passengerID, goalX, goalY, goalZ)
	local passengerData = cargo.passengers[passengerID]
	if passengerData and spValidUnitID(passengerID) and not spGetUnitIsDead(passengerID) then
		StartThread(TransportAnimator.Unload, passengerData, goalX, goalY, goalZ)
	else
		if spValidUnitID(passengerID) then
			spUnitDetach(passengerID)
		end
		if passengerData and passengerData.slotID then
			Move(passengerData.slotID, 1, 0)
			Move(passengerData.slotID, 2, 0)
			Move(passengerData.slotID, 3, 0)
			Turn(passengerData.slotID, 1, 0)
			Turn(passengerData.slotID, 2, 0)
			Turn(passengerData.slotID, 3, 0)
		end
		local count = CargoHandler.Unregister(passengerID, cargo)
		if count == 0 then
			TransportAnimator.HasCargo(false)
		end
	end
end

---@param passengerID number
---@param goalX number
---@param goalY number
---@param goalZ number
function PerformUnloadInstant(passengerID, goalX, goalY, goalZ)
	local passengerData = cargo.passengers[passengerID]
	if not passengerData then
		return
	end
	StartThread(TransportAnimator.Unload, passengerData, goalX, goalY, goalZ, false)
end

function script.Activate()
	GenericAnimator.Activate()
end

function script.Deactivate()
	GenericAnimator.Deactivate()
end

---@param v number moveRate
function script.MoveRate(v)
	GenericAnimator.MoveRate(v)
end

---@param s number|nil damageState
---@return number|nil restoreState
function script.Killed(s)
	return GenericAnimator.Killed(s)
end

---@param wpnNum number weaponNumber
---@param heading number
---@param pitch number
---@return boolean aimSuccess
function script.AimWeapon(wpnNum, heading, pitch)
	return WeaponAnimator.AimWeapon(heading, pitch)
end

---@return boolean fireSuccess
function script.FireWeapon()
	return WeaponAnimator.FireWeapon()
end

---@return number readyState
function script.QueryWeapon()
	return WeaponAnimator.QueryWeapon()
end

---@return number pieceNumber
function script.AimFromWeapon()
	return WeaponAnimator.AimFromWeapon()
end
