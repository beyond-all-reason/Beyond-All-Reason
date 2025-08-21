function widget:GetInfo()
  return {
    name    = "Build Planner",
    desc    = "Shows BP, resource demand, stall status and ETA for selected factories/builders",
    author  = "bar-helper",
    date    = "2025-08-21",
    license = "GPLv2 or later",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Spring / GL shortcuts
--------------------------------------------------------------------------------
local spGetMyTeamID        = Spring.GetMyTeamID
local spGetSelectedUnits   = Spring.GetSelectedUnits
local spGetTeamResources   = Spring.GetTeamResources
local spGetUnitDefID       = Spring.GetUnitDefID
local spGetCommandQueue    = Spring.GetCommandQueue
local spGetUnitIsBuilding  = Spring.GetUnitIsBuilding
local spGetUnitHealth      = Spring.GetUnitHealth
local spIsGUIHidden        = Spring.IsGUIHidden
local glColor, glRect, glText = gl.Color, gl.Rect, gl.Text

local myTeam = spGetMyTeamID()

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function isBuilderUD(ud)
  return ud and ud.isBuilder
end

local function isFactoryUD(ud)
  return ud and ud.isFactory
end

local function getBP(ud)  -- build power (buildSpeed)
  return (ud and ud.buildSpeed) or 0
end

local function econ(kind) -- cur, storage, pull, income, expense
  local c,s,p,i,e = spGetTeamResources(myTeam, kind)
  c,s,p,i,e = c or 0, s or 0, p or 0, i or 0, e or 0
  return c,s,(i-e)
end

local function currentTargetDefID(uID)
  -- Prefer the actual unit being built
  local buildingID = spGetUnitIsBuilding(uID)
  if buildingID then
    return spGetUnitDefID(buildingID), buildingID
  end
  -- Fallback: first build command in command queue
  local cq = spGetCommandQueue(uID, 1) or {}
  local cmd = cq[1]
  if cmd and cmd.id and cmd.id < 0 then
    return -cmd.id, nil
  end
  return nil, nil
end

local function buildProgress(buildingUnitID)
  if not buildingUnitID then return 0 end
  local _, _, _, _, bp = spGetUnitHealth(buildingUnitID) -- 0..1
  return bp or 0
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------
local pad   = 8
local font  = 13
local boxW  = 360
local maxShown = 3

local function drawPanel(x, y, lines)
  local h = pad*2 + (#lines * (font+3))
  glColor(0,0,0,0.55); glRect(x,y,x+boxW,y+h)
  local cy = y + h - pad - font
  for i=1,#lines do
    local L = lines[i]
    glColor(L[2], L[3], L[4], 1.0)
    glText(L[1], x+pad, cy, font, "n")
    cy = cy - (font+3)
  end
  glColor(1,1,1,1)
end

function widget:DrawScreen()
  if spIsGUIHidden() then return end
  local sel = spGetSelectedUnits() or {}
  if #sel == 0 then return end

  local _,_,mNet = econ("metal")
  local _,_,eNet = econ("energy")

  local shown = 0
  local x = 8
  local y = 84

  for i=1,#sel do
    if shown >= maxShown then break end
    local uID = sel[i]
    local udid = spGetUnitDefID(uID)
    local ud = UnitDefs[udid]
    if not ud then goto continue end

    if isFactoryUD(ud) or isBuilderUD(ud) then
      local bp = getBP(ud)
      local tgtDefID, buildingID = currentTargetDefID(uID)
      if tgtDefID then
        local tUD = UnitDefs[tgtDefID]
        if tUD then
          local name = tUD.humanName or ("Unit "..tgtDefID)
          local mCost, eCost, bt = tUD.metalCost or 0, tUD.energyCost or 0, tUD.buildTime or 1
          local mRate = bp * (mCost / bt)                 -- m/s needed at full BP
          local eRate = bp * (eCost / bt)                 -- e/s needed at full BP
          local stallM = (mNet < mRate)
          local stallE = (eNet < eRate)

          local prog = buildProgress(buildingID)          -- 0..1 if already started
          local baseETA = (bt * (1.0 - prog)) / math.max(bp, 1e-6) -- seconds ignoring stall

          -- crude slow-down factor based on limiting resource
          local rM = (mRate <= 0) and 1 or math.max(0.1, math.min(1.0, mNet / mRate))
          local rE = (eRate <= 0) and 1 or math.max(0.1, math.min(1.0, eNet / eRate))
          local slow = math.min(rM, rE)
          local eta = baseETA / slow

          local lines = {
            {("» %s  (BP %.0f)"):format(name, bp), 1,1,1},
            {("Needs m/s: %.1f   e/s: %.0f"):format(mRate, eRate), stallM and 1 or 0.8, (stallM and 0.6 or 1), stallM and 0.6 or 1},
            {("Net  m/s: %+0.1f  e/s: %+0.0f"):format(mNet, eNet), 0.9,0.9,0.9},
            {("ETA: %.1fs %s"):format(eta, (stallM or stallE) and "(stalling)" or ""), stallM or stallE and 1 or 0.8, stallM or stallE and 0.6 or 1, stallM or stallE and 0.6 or 1},
          }
          drawPanel(x, y, lines)
          y = y + 86
          shown = shown + 1
        end
      end
    end
    ::continue::
  end
end
