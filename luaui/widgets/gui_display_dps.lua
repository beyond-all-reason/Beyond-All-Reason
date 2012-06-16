--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_display_dps.lua
--  brief:   Displays DPS done to your allies units
--  author:  Owen Martindell
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Display DPS",
    desc      = "Displays damage per second done to your allies units v2.1",
    author    = "TheFatController",
    date      = "May 27, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Speed Up

local GetUnitDefID         = Spring.GetUnitDefID
local GetUnitDefDimensions = Spring.GetUnitDefDimensions
local AreTeamsAllied       = Spring.AreTeamsAllied
local GetMyTeamID          = Spring.GetMyTeamID
local GetGameSpeed         = Spring.GetGameSpeed
local GetGameSeconds       = Spring.GetGameSeconds
local GetUnitViewPosition  = Spring.GetUnitViewPosition

local glTranslate      = gl.Translate
local glColor          = gl.Color
local glBillboard      = gl.Billboard
local glText           = gl.Text
local glDepthMask      = gl.DepthMask
local glDepthTest      = gl.DepthTest
local glAlphaTest      = gl.AlphaTest
local glBlending       = gl.Blending
local glDrawFuncAtUnit = gl.DrawFuncAtUnit
local glPushMatrix     = gl.PushMatrix
local glPopMatrix      = gl.PopMatrix

local GL_GREATER             = GL.GREATER
local GL_SRC_ALPHA           = GL.SRC_ALPHA
local GL_ONE                 = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local damageTable = {}
local unitParalyze = {}
local unitDamage = {}
local deadList = {}
local lastTime = 0
local paused = false
local changed = false
local heightList = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function unitHeight(unitDefID)
  if not heightList[unitDefID] then 
    heightList[unitDefID] = (GetUnitDefDimensions(unitDefID).height * 0.9)
  end
  return heightList[unitDefID]  
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
  if not heightList[unitDefID] then
    heightList[unitDefID] = (GetUnitDefDimensions(unitDefID).height * 0.9)
  end
end

local function getTextSize(damage, paralyze)
  local sizeMod = 3
  if paralyze then sizeMod = 2.25 end
  return math.floor(8 * (1 + sizeMod * (1 - (200 / (200 + damage)))))
end

local function displayDamage(unitID, unitDefID, damage, paralyze)
  table.insert(damageTable,1,{})
  damageTable[1].unitID = unitID
  damageTable[1].damage = math.ceil(damage - 0.5)
  damageTable[1].height = unitHeight(unitDefID)
  damageTable[1].offset = (6 - math.random(0,12))
  damageTable[1].textSize = getTextSize(damage, paralyze)
  damageTable[1].heightOffset = 0
  damageTable[1].lifeSpan = 1
  damageTable[1].paralyze = paralyze
  damageTable[1].fadeTime = math.max((0.03 - (damage / 333333)), 0.015)
  damageTable[1].riseTime = (math.min((damage / 2500), 2) + 1)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  if unitDamage[unitID] then
    local ux, uy, uz = GetUnitViewPosition(unitID)
    if ux ~= nil then
      table.insert(deadList,1,{})
      local damage = math.ceil(unitDamage[unitID].damage - 0.5)
      deadList[1].x = ux
      deadList[1].y = (uy + unitHeight(unitDefID))
      deadList[1].z = uz
      deadList[1].lifeSpan = 1
      deadList[1].fadeTime = math.max((0.03 - (damage / 333333)), 0.015) * 0.66
      deadList[1].riseTime = (math.min((damage / 2500), 2) + 1)* 1.33
      deadList[1].damage = damage
      deadList[1].textSize = getTextSize(damage, false)
      deadList[1].red = true
    end
  end
  unitDamage[unitID] = nil
  unitParalyze[unitID] = nil
  for i,v in pairs(damageTable) do
    if (v.unitID == unitID) then
      if not v.paralyze then
        local ux, uy, uz = GetUnitViewPosition(unitID)
        if ux ~= nil then
          table.insert(deadList,1,{})
          deadList[1].x = ux + v.offset
          deadList[1].y = uy + v.height + v.heightOffset
          deadList[1].z = uz
          deadList[1].lifeSpan = v.lifeSpan
          deadList[1].fadeTime = v.fadeTime * 2.5
          deadList[1].riseTime = v.riseTime * 0.66
          deadList[1].damage = v.damage
          deadList[1].textSize = v.textSize
          deadList[1].red = false
        end
      end
      table.remove(damageTable,i)
    end
  end
end

function widget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
  if not (AreTeamsAllied(oldTeam, newTeam)) then
    widget:UnitDestroyed(unitID, unitDefID, newTeam)
  end
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
  if (damage < 1.5) then return end
  
  if (UnitDefs[unitDefID] == nil) then return end
    
  if paralyzer then
    if unitParalyze[unitID] then
      unitParalyze[unitID].damage = (unitParalyze[unitID].damage + damage)
    end
    return
  elseif unitDamage[unitID] then
    unitDamage[unitID].damage = (unitDamage[unitID].damage + damage)
    return
  end
    
  if paralyze then 
    unitParalyze[unitID] = {}
    unitParalyze[unitID].damage = damage
    unitParalyze[unitID].time = (lastTime + 0.1)
  else
    unitDamage[unitID] = {}
    unitDamage[unitID].damage = damage
    unitDamage[unitID].time = (lastTime + 0.1)
  end
end

local function calcDPS(inTable, paralyze, theTime)
  for unitID,damageDef in pairs(inTable) do
    if (damageDef.time < theTime) then
      local unitDefID = GetUnitDefID(unitID)
      if unitDefID and (damageDef.damage >= 1) then
        displayDamage(unitID, unitDefID, damageDef.damage, paralyze)
        damageDef.damage = 0
        damageDef.time = (theTime + 1)
        changed = true
      else
        inTable[unitID] = nil
      end
    end
  end
end

local function drawDeathDPS(damage,ux,uy,uz,textSize,red,alpha)
  
  glPushMatrix()
  glTranslate(ux, uy, uz)
  glBillboard()
  gl.MultiTexCoord(1, 0.25 + (0.5 * alpha))
  
  if red then
    glColor(1, 0, 0)
  else
    glColor(1, 1, 1)
  end
  
  glText(damage, 0, 0, textSize, "cno")
  
  glPopMatrix()
end

local function DrawUnitFunc(yshift, xshift, damage, textSize, alpha, paralyze)
  glTranslate(xshift, yshift, 0)
  glBillboard()
  gl.MultiTexCoord(1, 0.25 + (0.5 * alpha))
  if paralyze then
    glColor(0, 0, 1)
    glText(damage, 0, 0, textSize, 'cnO')
  else
    glColor(1, 1, 1)
    glText(damage, 0, 0, textSize, 'cno')
  end
end

function widget:DrawWorld()
  local theTime = GetGameSeconds()
  
  if (theTime ~= lastTime) then
  
    if next(unitDamage) then calcDPS(unitDamage, false, theTime) end
    if next(unitParalyze) then calcDPS(unitParalyze, true, theTime) end
    
    if changed then
      table.sort(damageTable, function(m1,m2) return m1.damage < m2.damage; end)
      changed = false
    end
  end
  
  lastTime = theTime
 
  if (not next(damageTable)) and (not next(deadList)) then return end
    
  _,_,paused = GetGameSpeed()
  
  glDepthMask(true)
  glDepthTest(true)
  glAlphaTest(GL_GREATER, 0)
  glBlending(GL_SRC_ALPHA, GL_ONE)
  gl.Texture(1, LUAUI_DIRNAME .. "images/gradient_alpha_2.png")

  for i, damage in pairs(damageTable) do
    if (damage.lifeSpan <= 0) then 
      table.remove(damageTable,i)
    else
      glDrawFuncAtUnit(damage.unitID, false, DrawUnitFunc, (damage.height + damage.heightOffset), 
                       damage.offset, damage.damage, damage.textSize, damage.lifeSpan, damage.paralyze)
      if not paused then
        if damage.paralyze then 
          damage.lifeSpan = (damage.lifeSpan - 0.05)
          damage.textSize = (damage.textSize + 0.2)
        else
          damage.heightOffset = (damage.heightOffset + damage.riseTime)
          if (damage.heightOffset > 25) then 
            damage.lifeSpan = (damage.lifeSpan - damage.fadeTime)
          end
        end
      end
    end
  end
  
  for i, death in pairs(deadList) do
    if (death.lifeSpan <= 0) then
      table.remove(deadList,i)
    else
      drawDeathDPS(death.damage, death.x, death.y, death.z, death.textSize, death.red, death.lifeSpan)
      if not paused then
        death.y = (death.y + death.riseTime)
        death.lifeSpan = (death.lifeSpan - death.fadeTime)
      end
    end
  end
    
  gl.Texture(1, false)
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glAlphaTest(false)
  glDepthTest(false)
  glDepthMask(false)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------