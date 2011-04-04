--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_metal_maker.lua
--  brief:   controls metal makers to minimize energy stalls and metal leaks
--  original author:  Owen Martindell
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Improved MetalMakers",
    desc      = "Controls metal makers - Disable other MM widgets before use (v2.70)",
    author    = "TheFatController, [LCC]jK",
    date      = "October 21, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false -- loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- global vars (so other widget (i.e. guis) can interact with the widget)

mmw_update         = 1.25  -- Seconds per update, do not set this too low
mmw_etargetPercent = 0.5   -- Percent of energy bar to aim for
mmw_estallPercent  = 0.3   -- Percent of "mmw_etargetPercent", when energy stalling begins (30% of 50% -> 15%)
mmw_forceStall     = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- speed up

local GetMyTeamID        = Spring.GetMyTeamID
local GetMyAllyTeamID    = Spring.GetMyAllyTeamID
local GetTeamUnits       = Spring.GetTeamUnits
local GetUnitDefID       = Spring.GetUnitDefID
local GetUnitHealth      = Spring.GetUnitHealth
local GiveOrderToUnitMap = Spring.GiveOrderToUnitMap
local GetTeamResources   = Spring.GetTeamResources
local GetTeamUnits       = Spring.GetTeamUnits
local GetUnitResources   = Spring.GetUnitResources
local GetTeamList        = Spring.GetTeamList
local GetSpectatingState = Spring.GetSpectatingState
local IsReplay           = Spring.IsReplay

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local myTeamID    = 0
local myAllyID    = 0
local eMaxRec     = 0
local timeCounter = 0
local minUpdate   = 0
local oldInc      = 0
local oldUse      = 0
local eStable     = 1

local metalMakers    = {}
local nonMetalMakers = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function maker(unitID, efficiency, drain, state)
  return { unitID = unitID, efficiency = efficiency, drain = drain, state = state }
end


function widget:Initialize()
  if (CheckForSpec()) then return false end
  UpdateTeamUnits()
  minUpdate = mmw_update - (mmw_update / 4)
end


function widget:TeamDied(teamID)
  CheckForSpec()
end

function isMetalMaker(inUnit)
  if (inUnit.isBuilding) and (inUnit.onOffable) and (inUnit.makesMetal > 0) and (inUnit.energyUpkeep > 0) then
    return true
  else
    return false
  end
end

function CheckForSpec()
  if GetSpectatingState() or IsReplay() then
    Spring.SendCommands({"echo MetalMakers widget disabled for spectators"})
    widgetHandler:RemoveWidget()
    return true
  end
end


function UpdateTeamUnits(teamID)
  metalMakers    = {}
  nonMetalMakers = {}

  if (CheckForSpec()) then return false end
  
  myAllyID = GetMyAllyTeamID()
  myTeamID = GetMyTeamID()
  
  local teamUnits = GetTeamUnits(myTeamID)
  for _,unitID in ipairs(teamUnits) do
    local _, _, _, _, buildProgress = GetUnitHealth(unitID)
    if (buildProgress == 1) then
      local unitDefID  = GetUnitDefID(unitID)
      local unitDef    = UnitDefs[unitDefID]
      if isMetalMaker(unitDef) then
        table.insert(metalMakers, maker(unitID,(unitDef.energyUpkeep / unitDef.makesMetal), unitDef.energyUpkeep, 0))
      else
        table.insert(nonMetalMakers, unitID)
      end
    end
  end

  table.sort(metalMakers, function(m1,m2) return m1.efficiency < m2.efficiency; end)
  
end


function widget:UnitFinished(unitID, unitDefID, unitTeam)

  myAllyID = GetMyAllyTeamID()
  myTeamID = GetMyTeamID()
  
  if (unitTeam ~= myTeamID) then
    return
  end
    
  local unitDef = UnitDefs[unitDefID]
  if isMetalMaker(unitDef) then
    table.insert(metalMakers, maker(unitID,(unitDef.energyUpkeep / unitDef.makesMetal), unitDef.energyUpkeep, 0))
    table.sort(metalMakers, function(m1,m2) return m1.efficiency < m2.efficiency; end)
  else
    table.insert(nonMetalMakers, unitID)
  end
end


function widget:TextCommand(command)
  if (string.find(command, 'energyhover ') == 1) then
    local inVar = tonumber(string.sub(command, 13))
    if (inVar > 1) then
      if (inVar <= 100) then
        inVar = (inVar / 100)
      else
        inVar = 1
      end
    elseif (inVar < 0) then
      inVar = 0
    end
    mmw_etargetPercent = inVar
    if (timeCounter < minUpdate) then 
      timeCounter = mmw_update
    end
  elseif (string.find(command, 'forcestall') == 1) then
    mmw_forceStall = true
    timeCounter = mmw_update
  end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  if (unitTeam ~= myTeamID) then
    return
  end

  local unitDef = UnitDefs[unitDefID]
  if isMetalMaker(unitDef) then 
    for makerIndex,makerStats in ipairs(metalMakers) do
      if (unitID == makerStats.unitID) then
        table.remove(metalMakers,makerIndex)
        break
      end
    end
  else
    for nonMakerIndex,nonMakerID in ipairs(nonMetalMakers) do
      if (unitID == nonMakerID) then
         table.remove(nonMetalMakers,nonMakerIndex)
         break
      end
    end
  end
end


function widget:UnitTaken(unitID, unitDefID, unitTeam)
  widget:UnitDestroyed(unitID, unitDefID, unitTeam)
end


function widget:UnitGiven(unitID, unitDefID, unitTeam)
  widget:UnitFinished(unitID, unitDefID, unitTeam)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local function updateMakers(eFree, eMax, eRemain)
  local checkOnce = false
  local onMakers = {}
  local offMakers = {}
  for _,makerStats in ipairs(metalMakers) do
    eFree = (eFree - makerStats.drain)
    local makerState = -1

    if (eFree > 0) then
      makerState = 1
    elseif (not checkOnce) and (((eRemain + eFree) / eMax) > mmw_etargetPercent) then
      makerState = 1
      checkOnce = true
    end
    
    if (makerStats.state ~= makerState) then
      makerStats.state = makerState
      if (makerState == 1) then
        onMakers[makerStats.unitID] = true
      else
        offMakers[makerStats.unitID] = true
      end
    end
  end
  GiveOrderToUnitMap(onMakers, CMD.ONOFF, { 1 }, { })
  GiveOrderToUnitMap(offMakers, CMD.ONOFF, { 0 }, { })  
end


function widget:Update(deltaTime)
  
  if (next(metalMakers) == nil) then return end
  
  if (myTeamID ~= GetMyTeamID()) then UpdateTeamUnits() end
  
  local eCur, eMax, eUse, eInc, _, _, _, eRec = GetTeamResources(myTeamID, "energy")
  
  if (eMaxRec < eRec) then eMaxRec = eRec end
  
  local ePercent = (eCur/eMax)
  
  if (math.max(math.abs(oldInc-eInc), math.abs(oldUse-eUse)) > (eMax * 0.20)) then
    if (timeCounter < minUpdate) then 
      timeCounter = minUpdate
    end
  elseif (ePercent < 0.15) and (timeCounter < minUpdate) then 
    timeCounter = minUpdate 
  end
  
  if (eStable == 0) and (math.abs(ePercent - mmw_etargetPercent) <= 0.05) then
    eStable = 1
    timeCounter = mmw_update
  elseif (eStable == 1) then
    if (math.abs(ePercent - mmw_etargetPercent) > 0.2) then
      eStable = 0
    end
  end
    
  oldInc = eInc
  oldUse = eUse

  if (not mmw_forceStall) and (ePercent < (mmw_etargetPercent * mmw_estallPercent)) then
    updateMakers(0, eMax, eCur) -- turn all metal makers off
  elseif (timeCounter >= mmw_update) then
    local mCur, mMax, mUse, _, _, mShare = GetTeamResources(myTeamID, "metal")

    local nonMakerDrain = 0
    
    for _,unitID in ipairs(nonMetalMakers) do
      local _, _, _, eUse = GetUnitResources(unitID)
      if eUse then
        nonMakerDrain = nonMakerDrain + eUse
      end
    end
            
    local eAvail = ((eInc + eMaxRec) - nonMakerDrain)
    
    if (ePercent < (mmw_etargetPercent - 0.05)) then
      eAvail = (eAvail - metalMakers[1].drain)
    elseif (ePercent > (mmw_etargetPercent + 0.05)) then
      local eCounting = 0
      local mCounting = 0
      local eEff      = metalMakers[1].efficiency
      for _,makerStats in ipairs(metalMakers) do
        if (makerStats.efficiency == eEff) then
          eCounting = eCounting + makerStats.drain
          mCounting = mCounting + 1
        else
          break
        end
      end
      if ((eMax * 0.2) > (metalMakers[1].drain * mCounting)) then
        eAvail = math.max(eCounting,(eAvail + metalMakers[1].drain))
      else
        if (ePercent > (mmw_etargetPercent + 0.2)) then
          eAvail = eAvail + metalMakers[1].drain
        end
      end
    end
    
    if mmw_forceStall then
      eAvail = eMax
      if (ePercent < 0.15) then
        mmw_forceStall = false
      end
    elseif ((mCur > (mMax-7)) and (mShare < 1) and (mUse == 0)) then
      eAvail = 0
    end
     
    updateMakers(eAvail, eMax, eCur)
     
    timeCounter = 0
        
  else
    timeCounter = timeCounter + deltaTime
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------