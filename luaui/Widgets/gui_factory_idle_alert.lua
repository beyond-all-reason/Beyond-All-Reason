function widget:GetInfo()
  return {
    name    = "Factory Idle Alert",
    desc    = "Subtle alert + quick-jump when factories idle for N seconds (no queue, not building)",
    author  = "bar-helper",
    date    = "2025-08-21",
    license = "GPLv2 or later",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Spring shortcuts
--------------------------------------------------------------------------------
local spGetMyTeamID        = Spring.GetMyTeamID
local spGetTeamUnits       = Spring.GetTeamUnits
local spGetUnitDefID       = Spring.GetUnitDefID
local spGetUnitIsStunned   = Spring.GetUnitIsStunned
local spGetUnitIsBuilding  = Spring.GetUnitIsBuilding
local spGetUnitBasePosition= Spring.GetUnitBasePosition
local spGetFullBuildQueue  = Spring.GetFullBuildQueue
local spGetCommandQueue    = Spring.GetCommandQueue
local spGetGameFrame       = Spring.GetGameFrame
local spEcho               = Spring.Echo
local spPlaySoundFile      = Spring.PlaySoundFile
local spSetCameraTarget    = Spring.SetCameraTarget
local spSelectUnitArray    = Spring.SelectUnitArray
local spIsGUIHidden        = Spring.IsGUIHidden
local myTeamID

--------------------------------------------------------------------------------
-- Config (persisted)
--------------------------------------------------------------------------------
local conf = {
  idleSeconds      = 7.5,
  ui                = true,
  beep              = true,
  beepIntervalSec   = 6.0,
  fontSize          = 14,
  margin            = 8,
  maxListed         = 6,
}

function widget:SetConfigData(data) if type(data)=="table" then for k,v in pairs(data) do conf[k]=v end end end
function widget:GetConfigData() return conf end

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local factories = {}         -- unitID -> {lastActiveGF = number}
local idleList  = {}         -- cached array of idle IDs (for UI)
local lastBeepGF = -9999
local fontSize = 14

local function isFactory(udefID)
  local ud = UnitDefs[udefID]
  return ud and ud.isFactory
end

local function hasQueue(uID)
  -- Prefer engine factory queue; fallback to command queue size
  local q = spGetFullBuildQueue and spGetFullBuildQueue(uID)
  if q and next(q) ~= nil then return true end
  local cq = spGetCommandQueue(uID, 0)
  return (cq and #cq or 0) > 0
end

local function refreshFactories()
  factories = {}
  local units = spGetTeamUnits(myTeamID) or {}
  for i=1,#units do
    local u = units[i]
    local ud = spGetUnitDefID(u)
    if isFactory(ud) then
      factories[u] = { lastActiveGF = spGetGameFrame() }
    end
  end
end

local function isActiveFactory(u)
  if spGetUnitIsStunned(u) then return true end
  if hasQueue(u) then return true end
  local building = spGetUnitIsBuilding(u)
  if building and building ~= nil then return true end
  return false
end

local function rebuildIdleList()
  idleList = {}
  local gf = spGetGameFrame()
  local idleFrames = math.floor(conf.idleSeconds * 30)
  for u,st in pairs(factories) do
    local active = isActiveFactory(u)
    if active then
      st.lastActiveGF = gf
    else
      if (gf - (st.lastActiveGF or gf)) >= idleFrames then
        idleList[#idleList+1] = u
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Widget lifecycle
--------------------------------------------------------------------------------
function widget:Initialize()
  myTeamID = spGetMyTeamID()
  refreshFactories()
  fontSize = conf.fontSize or 14
end

function widget:PlayerChanged(playerID)
  myTeamID = spGetMyTeamID()
  refreshFactories()
end

-- Track factories as they appear/disappear
function widget:UnitFinished(unitID, unitDefID, unitTeam)
  if unitTeam == myTeamID and isFactory(unitDefID) then
    factories[unitID] = { lastActiveGF = spGetGameFrame() }
  end
end
function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  factories[unitID] = nil
end
function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
  if unitTeam == myTeamID and isFactory(unitDefID) then
    factories[unitID] = { lastActiveGF = spGetGameFrame() }
  else
    factories[unitID] = nil
  end
end

function widget:Update(dt)
  rebuildIdleList()
  local gf = spGetGameFrame()
  if conf.beep and #idleList > 0 then
    local framesBetweenBeeps = math.floor((conf.beepIntervalSec or 6.0) * 30)
    if gf - lastBeepGF >= framesBetweenBeeps then
      spPlaySoundFile("LuaUI/Sounds/beep6.wav", 0.25)
      lastBeepGF = gf
    end
  end
end

function widget:DrawWorld()
  if #idleList == 0 then return end
  gl.DepthTest(true)
  for i=1,#idleList do
    local u = idleList[i]
    local x,y,z = spGetUnitBasePosition(u)
    if x then
      gl.Color(1.0,0.8,0.0,0.35)
      gl.DrawGroundCircle(x,y,z, 90, 20)
    end
  end
  gl.Color(1,1,1,1)
  gl.DepthTest(false)
end

function widget:DrawScreen()
  if spIsGUIHidden() or not conf.ui or #idleList == 0 then return end
  local w = 220
  local h = 18 + (#idleList > 0 and (math.min(#idleList, conf.maxListed)* (fontSize+2)) or fontSize)
  local x = conf.margin
  local y = conf.margin

  gl.Color(0,0,0,0.55); gl.Rect(x,y,x+w,y+h); gl.Color(1,1,1,1)
  gl.Text("Idle factories:", x+8, y+h-16, fontSize, "o")

  for i=1, math.min(#idleList, conf.maxListed) do
    local u = idleList[i]
    local name = UnitDefs[spGetUnitDefID(u)].humanName or "Factory"
    gl.Text(("* %s (#%d)"):format(name,u), x+12, y+h-16-(i*(fontSize+2)), fontSize, "n")
  end

  gl.Text("Ctrl+I: focus next", x+8, y+4, fontSize-2, "n")
end

-- Quick-jump to next idle factory
local lastFocusIdx = 0
local function focusNextIdle()
  if #idleList == 0 then return end
  lastFocusIdx = (lastFocusIdx % #idleList) + 1
  local u = idleList[lastFocusIdx]
  local x,y,z = spGetUnitBasePosition(u)
  if x then
    spSelectUnitArray({u})
    spSetCameraTarget(x,y,z, 0.3)
  end
end

function widget:KeyPress(key, mods, isRepeat)
  if mods.ctrl and (key == string.byte('I')) then
    focusNextIdle()
    return true
  end
end
