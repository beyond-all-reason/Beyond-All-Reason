function gadget:GetInfo()
  return {
    name      = "MissileControl",
    desc      = "Missile Command",
    author    = "TheFatController",
    date      = "18 Sept 2010",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return
end

local GetUnitWeaponState = Spring.GetUnitWeaponState
local GetGameFrame = Spring.GetGameFrame
local EditUnitCmdDesc = Spring.EditUnitCmdDesc
local FindUnitCmdDesc = Spring.FindUnitCmdDesc
local InsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local SetUnitCOBValue = Spring.SetUnitCOBValue
local DELAY_UNIT_VAR = 1024

local DELAY_UNIT = {
  [UnitDefNames["screamer"].id] = 45,
  [UnitDefNames["mercury"].id] = 45,
  [UnitDefNames["corerad"].id] = 30,
  [UnitDefNames["armcir"].id] = 30,
}

local reservedTargets = {}

function gadget:Initialize()
  gadgetHandler:RegisterGlobal("TargetCheck",TargetCheck)
end

function TargetCheck(unitID, unitDefID, unitTeam)
  local _,canFire = Spring.GetUnitWeaponState(unitID, 0)
  local unitTarget = Spring.GetUnitCOBValue(unitID, 83, 1)
  if (not reservedTargets[unitTarget]) then
    if canFire then
		reservedTargets[unitTarget] = Spring.GetGameFrame()+DELAY_UNIT[unitDefID]
		SetUnitCOBValue(unitID, DELAY_UNIT_VAR, 1)
    end
  else
	SetUnitCOBValue(unitID, 98, 1)
  end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
  if DELAY_UNIT[unitDefID] then
    SetUnitCOBValue(unitID, DELAY_UNIT_VAR, 0)
  end
end

function gadget:GameFrame(n)
  for unitID,t in pairs(reservedTargets) do
    if n>t then
      reservedTargets[unitID] = nil
    end
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------