--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- UNSYNCED ONLY
if gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Thrusters",
    desc      = "Da red ones go fasta",
    author    = "KingRaptor (L.J. Lim)",
    date      = "2013.06.25",
    license   = "Public Domain",
    layer     = 0,
    enabled   = true,
  }
end

local unitDefs = include("LuaRules/Configs/lups_thruster_fxs.lua")
local UPDATE_PERIOD = 3
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local Lups
local LupsAddParticles 
local SYNCED = SYNCED

local units = {}
local unitSpeeds = {}
local startup = true

local function AddUnit(unitID, unitDefID)
  if (not Lups) then Lups = GG['Lups']; LupsAddParticles = Lups.AddParticles end
  
  units[unitID] = {
    unitDefID = unitDefID,
    speed = unitSpeeds[unitID],
    fx = {},
  }
  local def = unitDefs[unitDefID]
  for i=1,#def do
    local fxTable = units[unitID].fx
    local fx = def[i]
    local options = Spring.Utilities.CopyTable(fx.options)
    options.unit = unitID
    local fxID = LupsAddParticles(fx.class, options)
    if fxID ~= -1 then
      fxTable[#fxTable+1] = fxID
    end
  end
end

local function RemoveUnit(unitID)
  if units[unitID] then
    for i=1,#units[unitID].fx do
      local fx = units[unitID].fx[i]
      Lups.RemoveParticles(fx)
    end
    units[unitID] = nil
  end
end

local function GameFrameUnitsCheck()
  for unitID, data in pairs(units) do
    local def = unitDefs[data.unitDefID]
    local maxDelta = def.maxDeltaSpeed*(UPDATE_PERIOD/30)
    local oldSpeed = data.speed or 0
    local trueSpeed = unitSpeeds[unitID]
    local delta = trueSpeed - oldSpeed
    if delta > maxDelta then
      delta = maxDelta
    elseif delta < -maxDelta then
      delta = -maxDelta
    end
    
    local speed = oldSpeed + delta
    if speed < def.minSpeed then
      speed = def.minSpeed
    end
    
    if delta > 0.01 or delta < -0.01 then
      data.speed = speed
      local modDelta = delta + delta*def.accelMod -- give bigger thrust when accelerating then when at constant speed
      local modSpeed = speed + modDelta
      
      local mult = modSpeed/(def.baseSpeed or 8)
      
      for i=1,#data.fx do
	local fxID = data.fx[i]
	local fx = Lups.GetParticles(fxID)
	if fx.size then
	  fx.size = fx.baseSize*mult
	end
	if fx.length then
	  fx.length = fx.baseLength + fx.linearLength*mult
	end
	fx:Destroy()	-- clean up any display lists
	fx:CreateParticle()
      end
    end
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// Speed-ups
local spGetUnitVelocity = Spring.GetUnitVelocity

local function GetUnitSpeed(unitID)
  if GG.GetUnitSpeed then
    local speed = GG.GetUnitSpeed(unitID)
    if speed then
      return speed
    end
  end

  local _, _, _, speed = spGetUnitVelocity(unitID)
  return speed
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
  RemoveUnit(unitID)
  unitSpeeds[unitID] = nil
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
  if unitDefs[unitDefID] then
    AddUnit(unitID, unitDefID)
    unitSpeeds[unitID] = GetUnitSpeed(unitID) 
  end
end

function gadget:GameFrame(n)
  if startup then
    local allUnits = Spring.GetAllUnits()
    for i=1,#allUnits do
      local unitID = allUnits[i]
      local unitDefID = Spring.GetUnitDefID(unitID)
      gadget:UnitCreated(unitID, unitDefID)
    end
    startup = false
  end
  if n%UPDATE_PERIOD == 0 then
    for unitID in pairs(unitSpeeds) do
      unitSpeeds[unitID] = GetUnitSpeed(unitID)
    end
    GameFrameUnitsCheck()
  end
end