--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_build_eta.lua
--  brief:   display estimated time of arrival for builds
--  author:  Dave Rodgers
--
--  >> modified by: jK <<
--
--  Copyright (C) 2007,2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "BuildETA",
    desc      = "Displays estimated time of arrival for builds",
    author    = "trepan (modified by jK)",
    date      = "Feb, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = -1,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gl     = gl  --  use a local copy for faster access
local Spring = Spring
local table  = table

local etaTable = {}


--------------------------------------------------------------------------------

local vsx, vsy = widgetHandler:GetViewSizes()

function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY
end


--------------------------------------------------------------------------------

local function MakeETA(unitID,unitDefID)
  if (unitDefID == nil) then return nil end
  local _,_,_,_,buildProgress = Spring.GetUnitHealth(unitID)
  if (buildProgress == nil) then return nil end

  local ud = UnitDefs[unitDefID]
  if (ud == nil)or(ud.height == nil) then return nil end

  return {
    firstSet = true,
    lastTime = Spring.GetGameSeconds(),
    lastProg = buildProgress,
    rate     = nil,
    timeLeft = nil,
    yoffset  = ud.height+14
  }
end


--------------------------------------------------------------------------------

function widget:Initialize()
  local myUnits = Spring.GetTeamUnits(Spring.GetMyTeamID())
  for _,unitID in ipairs(myUnits) do
    local _,_,_,_,buildProgress = Spring.GetUnitHealth(unitID)
    if (buildProgress < 1) then
      etaTable[unitID] = MakeETA(unitID,Spring.GetUnitDefID(unitID))
    end
  end
end


--------------------------------------------------------------------------------

local SpGetGameSeconds = Spring.GetGameSeconds
local SpIsUnitInView = Spring.IsUnitInView
local SpValidUnitID = Spring.ValidUnitID
local SpGetCameraPosition = Spring.GetCameraPosition
local SpGetSmoothMeshHeight = Spring.GetSmoothMeshHeight
local SpIsGUIHidden = Spring.IsGUIHidden

local lastGameUpdate = -1

function widget:Update(dt)

  local userSpeed,_,pause = Spring.GetGameSpeed()
  if (pause) then
    return
  end

  local gs = Spring.GetGameSeconds()
  if (gs - lastGameUpdate < 0.1) then
    return
  end
  lastGameUpdate = gs
  
  local killTable = {}
  for unitID,bi in pairs(etaTable) do
    local _,_,_,_,buildProgress = Spring.GetUnitHealth(unitID)
    if ((not buildProgress) or (buildProgress >= 1.0)) then
      table.insert(killTable, unitID)
    else
      local dp = buildProgress - bi.lastProg 
      local dt = gs - bi.lastTime
      if (dt > 2) then
        bi.firstSet = true
        bi.rate = nil
        bi.timeLeft = nil
      end

      local rate = (dp / dt) * userSpeed

      if (rate ~= 0) then
        if (bi.firstSet) then
          if (buildProgress > 0.001) then
            bi.firstSet = false
          end
        else
          local rf = 0.5
          if (bi.rate == nil) then
            bi.rate = rate
          else
            bi.rate = ((1 - rf) * bi.rate) + (rf * rate)
          end

          local tf = 0.1
          if (rate > 0) then
            local newTime = (1 - buildProgress) / rate
            if (bi.timeLeft and (bi.timeLeft > 0)) then
              bi.timeLeft = ((1 - tf) * bi.timeLeft) + (tf * newTime)
            else
              bi.timeLeft = (1 - buildProgress) / rate
            end
          elseif (rate < 0) then
            local newTime = buildProgress / rate
            if (bi.timeLeft and (bi.timeLeft < 0)) then
              bi.timeLeft = ((1 - tf) * bi.timeLeft) + (tf * newTime)
            else
              bi.timeLeft = buildProgress / rate
            end
          end
        end
        bi.lastTime = gs
        bi.lastProg = buildProgress
      end
    end
  end
  for _,unitID in pairs(killTable) do
    etaTable[unitID] = nil
  end
end


--------------------------------------------------------------------------------

function widget:UnitCreated(unitID, unitDefID, unitTeam)
  local spect,spectFull = Spring.GetSpectatingState()
  if Spring.AreTeamsAllied(unitTeam,Spring.GetMyTeamID()) or (spect and spectFull) then
    etaTable[unitID] = MakeETA(unitID,unitDefID)
  end
end


function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  etaTable[unitID] = nil
end


function widgetHandler:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
  etaTable[unitID] = nil
end


function widget:UnitFinished(unitID, unitDefID, unitTeam)
  etaTable[unitID] = nil
end


--------------------------------------------------------------------------------

local function DrawEtaText(timeLeft,yoffset)
  local etaStr
  if (timeLeft == nil) then
    etaStr = '\255\255\255\1ETA\255\255\255\255:\255\1\1\255???'
  else
    if (timeLeft > 60) then
        etaStr = "\255\255\255\1ETA\255\255\255\255:" .. string.format('\255\1\255\1%d', timeLeft / 60) .. "m, " .. string.format('\255\1\255\1%.1f', timeLeft % 60) .. "s"
    elseif (timeLeft > 0) then
      etaStr = "\255\255\255\1ETA\255\255\255\255:" .. string.format('\255\1\255\1%.1f', timeLeft) .. "s"
    else
      etaStr = "\255\255\255\1ETA\255\255\255\255:" .. string.format('\255\255\1\1%.1f', -timeLeft) .. "s"
    end
  end

  gl.Translate(0, yoffset,0)
  gl.Billboard()
  gl.Translate(0, 5 ,0)
  --fontHandler.DrawCentered(etaStr)
  gl.Text(etaStr, 0, 0, 8, "c")
end

local maxUnitDistance = 9000000 --max squared distance at which any info is drawn for units (matches unit_healthbars)

function widget:DrawWorld()
  -- do the same check as healthbars; don't draw if too far zoomed out
  cx, cy, cz = SpGetCameraPosition()
  local smoothheight = SpGetSmoothMeshHeight(cx,cz) --clamps x and z
  if ((cy-smoothheight)^2 >= maxUnitDistance) or SpIsGUIHidden() then 
	return
  end

  gl.DepthTest(true)

  gl.Color(1, 1, 1)
  --fontHandler.UseDefaultFont()

  for unitID, bi in pairs(etaTable) do
	if SpIsUnitInView(unitID) then
	  gl.DrawFuncAtUnit(unitID, false, DrawEtaText, bi.timeLeft,bi.yoffset)
	end
  end

  gl.DepthTest(false)
end
  

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
