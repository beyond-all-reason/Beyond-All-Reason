function widget:GetInfo()
  return {
    name    = "Stall Guard",
    desc    = "Non-intrusive alerts when energy/metal stall; optional rings around under-construction buildings; configurable thresholds",
    author  = "bar-helper",
    date    = "2025-08-21",
    license = "GPLv2 or later",
    layer   = 0,
    enabled = true, -- default on; alert-only by default
  }
end

--------------------------------------------------------------------------------
-- locals / Spring shortcuts
--------------------------------------------------------------------------------
local spGetMyTeamID        = Spring.GetMyTeamID
local spGetGameFrame       = Spring.GetGameFrame
local spGetTeamResources   = Spring.GetTeamResources
local spGetTeamUnits       = Spring.GetTeamUnits
local spGetUnitHealth      = Spring.GetUnitHealth
local spGetUnitBasePosition= Spring.GetUnitBasePosition
local spAreTeamsAllied     = Spring.AreTeamsAllied
local spIsGUIHidden        = Spring.IsGUIHidden
local spEcho               = Spring.Echo
local spPlaySoundFile      = Spring.PlaySoundFile
local glColor              = gl.Color
local glRect               = gl.Rect
local glText               = gl.Text
local glDepthTest          = gl.DepthTest
local glDrawGroundCircle   = gl.DrawGroundCircle

local myTeamID = spGetMyTeamID()

--------------------------------------------------------------------------------
-- config (persisted)
--------------------------------------------------------------------------------
local conf = {
  showUI          = true,   -- draw small banner when stalling
  showRings       = true,   -- draw rings around incomplete structures while in stall
  beep            = true,   -- play subtle beep (rate-limited)
  beepIntervalSec = 3.0,    -- seconds between beeps during continuous stall
  ringRefreshF    = 15,     -- how often (in frames) to refresh the build list
  fontSize        = 15,
  pad             = 6,

  -- Stall thresholds; stall when (cur < max(abs, pct*storage)) AND (net < -netThreshold)
  energy = { abs = 300, pct = 0.05, netThreshold = 15 },
  metal  = { abs = 30,  pct = 0.05, netThreshold = 3  },

  -- ring visuals
  ring = {
    minRadius = 60,
    maxRadius = 110, -- scales with (1 - buildProgress)
    alpha     = 0.45,
    segments  = 18,
  },
}

-- light utils (no dependency on Spring.Utilities)
local function deepMerge(dst, src)
  if type(dst) ~= "table" or type(src) ~= "table" then return dst end
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then
      deepMerge(dst[k], v)
    else
      dst[k] = v
    end
  end
  return dst
end

function widget:SetConfigData(data)
  if type(data) == "table" then deepMerge(conf, data) end
end

function widget:GetConfigData()
  return conf
end

--------------------------------------------------------------------------------
-- state
--------------------------------------------------------------------------------
local stalledEnergy, stalledMetal = false, false
local lastBeepFrame = -9999
local underConstruction = {}
local lastRingRefresh = -9999

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------
local function resourceState(kind)
  -- current, storage, pull, income, expense, share, sent, received
  local cur, storage, pull, income, expense = spGetTeamResources(myTeamID, kind)
  cur      = cur or 0
  storage  = storage or 0
  income   = income or 0
  expense  = expense or 0
  local net = income - expense
  return cur, storage, net, income, expense
end

local function checkStall(kindConf, kindName)
  local cur, storage, net = resourceState(kindName)
  local floorAbs = kindConf.abs
  local floorPct = (kindConf.pct or 0) * (storage or 0)
  local floor    = math.max(floorAbs, floorPct)
  local netNeed  = kindConf.netThreshold or 0
  local isStall  = (cur < floor) and (net < -netNeed)
  return isStall, cur, storage, net
end

local function refreshUnderConstruction()
  underConstruction = {}
  local units = spGetTeamUnits(myTeamID) or {}
  for i = 1, #units do
    local uID = units[i]
    local hp, maxhp, paralyze, capture, buildProgress = spGetUnitHealth(uID)
    if buildProgress and buildProgress < 1 then
      local x, y, z = spGetUnitBasePosition(uID)
      if x then
        underConstruction[#underConstruction + 1] = {
          id = uID, x = x, y = y, z = z, bp = buildProgress
        }
      end
    end
  end
  lastRingRefresh = spGetGameFrame()
end

--------------------------------------------------------------------------------
-- widget lifecycle
--------------------------------------------------------------------------------
function widget:Initialize()
  myTeamID = spGetMyTeamID()
end

function widget:Update(dt)
  -- skip in spec if desired (comment out to allow while spectating)
  -- if Spring.GetSpectatingState and Spring.GetSpectatingState() then return end

  stalledEnergy = select(1, checkStall(conf.energy, "energy"))
  stalledMetal  = select(1, checkStall(conf.metal,  "metal"))

  local gf = spGetGameFrame()

  if conf.showRings and (stalledEnergy or stalledMetal) and gf - lastRingRefresh >= conf.ringRefreshF then
    refreshUnderConstruction()
  end

  if conf.beep and (stalledEnergy or stalledMetal) then
    local framesBetweenBeeps = math.floor((conf.beepIntervalSec or 3.0) * 30)
    if gf - lastBeepFrame >= framesBetweenBeeps then
      -- keep sound optional & tolerant if file is missing
      local ok = spPlaySoundFile and spPlaySoundFile("LuaUI/Sounds/beep6.wav", 0.3)
      if not ok then spEcho("[StallGuard] Stall!") end
      lastBeepFrame = gf
    end
  end
end

function widget:DrawWorld()
  if not conf.showRings or not (stalledEnergy or stalledMetal) then return end
  if #underConstruction == 0 then return end

  local col = stalledEnergy and {1.0, 0.25, 0.25, conf.ring.alpha}
              or              {1.0, 0.85, 0.25, conf.ring.alpha}
  glDepthTest(true)
  glColor(col[1], col[2], col[3], col[4])
  local segs = conf.ring.segments or 18
  local minR = conf.ring.minRadius or 60
  local maxR = conf.ring.maxRadius or 110

  for i = 1, #underConstruction do
    local u = underConstruction[i]
    -- scale radius by remaining build (emphasize early builds)
    local r = minR + (1 - (u.bp or 0)) * (maxR - minR)
    glDrawGroundCircle(u.x, u.y, u.z, r, segs)
  end

  glDepthTest(false)
  glColor(1, 1, 1, 1)
end

function widget:DrawScreen()
  if spIsGUIHidden() or not conf.showUI then return end
  if not (stalledEnergy or stalledMetal) then return end

  local w = 220
  local h = 40
  local x = 14
  local y = 14
  glColor(0, 0, 0, 0.55)
  glRect(x, y, x + w, y + h)
  glColor(1, 1, 1, 1)

  local label = stalledEnergy and (stalledMetal and "STALL: E + M" or "STALL: ENERGY")
                 or "STALL: METAL"
  local col = stalledEnergy and {1.0, 0.35, 0.35, 1.0}
              or              {1.0, 0.85, 0.35, 1.0}
  glColor(col[1], col[2], col[3], col[4])
  glText(label, x + conf.pad, y + h/2 - conf.fontSize/2, conf.fontSize, "o")
  glColor(1, 1, 1, 1)
end

--------------------------------------------------------------------------------
-- keybinds and WG API
--------------------------------------------------------------------------------
function widget:KeyPress(key, mods, isRepeat)
  -- Cheap, discoverable toggles:
  -- Ctrl+Alt+S : toggle UI banner
  -- Ctrl+Alt+R : toggle world rings
  if mods.ctrl and mods.alt then
    if key == string.byte('S') then
      conf.showUI = not conf.showUI
      spEcho("[StallGuard] UI banner: " .. (conf.showUI and "ON" or "OFF"))
      return true
    elseif key == string.byte('R') then
      conf.showRings = not conf.showRings
      spEcho("[StallGuard] Rings: " .. (conf.showRings and "ON" or "OFF"))
      return true
    end
  end
end

function widget:Shutdown()
  -- nothing persistent besides config
end
