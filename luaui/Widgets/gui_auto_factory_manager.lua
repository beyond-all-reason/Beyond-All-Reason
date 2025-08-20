function widget:GetInfo()
  return {
    name      = "Auto Factory Manager",
    desc      = "Auto-pauses factories on energy stalls; auto-resumes when recovered. Per-factory toggle + chat commands.",
    author    = "you + GPT-5 Pro",
    date      = "2025-08-20",
    license   = "MIT",
    version   = 1,
    layer     = 0,
    enabled   = false, -- start disabled; enable via F11 or /luaui enable
  }
end

--------------------------------------------------------------------------------
-- Config (can be changed at runtime via chat commands; see bottom)
--------------------------------------------------------------------------------

local managedDefault     = true   -- newly finished factories are managed unless you toggle them off
local manageInterval     = 15     -- frames between checks (0.5 sec at 30fps; ~0.25s at 60fps)
local stallThresholdE    = 0.05   -- pause if energy < 5% of storage
local resumeThresholdE   = 0.20   -- resume when energy > 20% of storage
local ignoreDuringBuild  = false  -- if true, do not pause a factory while it's currently producing a unit
local drawMarkers        = true   -- draw a ground ring for managed factories
local colorManaged       = {0.2, 1.0, 0.2, 0.7}
local colorPaused        = {1.0, 0.7, 0.2, 0.8}
local ringRadius         = 48

--------------------------------------------------------------------------------
-- Locals / engine refs
--------------------------------------------------------------------------------

local spGetMyTeamID           = Spring.GetMyTeamID
local spGetSpectatingState    = Spring.GetSpectatingState
local spGetTeamResources      = Spring.GetTeamResources
local spGetTeamUnits          = Spring.GetTeamUnits
local spGetUnitDefID          = Spring.GetUnitDefID
local spGetUnitTeam           = Spring.GetUnitTeam
local spGetUnitStates         = Spring.GetUnitStates
local spGiveOrderToUnit       = Spring.GiveOrderToUnit
local spGetSelectedUnits      = Spring.GetSelectedUnits
local spEcho                  = Spring.Echo
local spGetGameFrame          = Spring.GetGameFrame

local CMD_ONOFF               = CMD.ONOFF

local myTeamID                = nil
local isSpec                  = false

-- tracked factories: [unitID] = { managed = bool, paused = bool, defID = int }
local factories = {}
local lastFrameCheck = 0

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function IsFactory(defID)
  if not defID then return false end
  local ud = UnitDefs[defID]
  return ud and ud.isFactory
end

local function AddFactory(unitID, defID)
  if not defID then defID = spGetUnitDefID(unitID) end
  if not IsFactory(defID) then return end
  if factories[unitID] then return end
  factories[unitID] = {
    managed = managedDefault,
    paused  = false,
    defID   = defID,
  }
end

local function RemoveFactory(unitID)
  factories[unitID] = nil
end

local function GetEnergyFrac(teamID)
  local eCur, eStor = spGetTeamResources(teamID, "energy")
  if not eCur or not eStor or eStor <= 0 then return 1.0 end
  return math.max(0, math.min(1, eCur / eStor))
end

local function SetFactoryActive(unitID, active)
  -- Don't spam: check current state first
  local st = spGetUnitStates(unitID)
  if not st then return end
  local cur = (st.active == true)
  if cur == active then return end
  spGiveOrderToUnit(unitID, CMD_ONOFF, { active and 1 or 0 }, 0)
end

local function IsFactoryBuilding(unitID)
  -- When a lab is actively producing, its 'busy' state is often visible via unit rules params or build progress.
  -- Generic safe approach: consider active && not idle as "building".
  local st = spGetUnitStates(unitID)
  if not st then return false end
  -- Heuristic: if active and not repeating with empty queue, it's likely building. Without gadget access,
  -- keep it simple and just treat "active == true" as building.
  return st.active == true
end

local function ManageFactories()
  if isSpec then return end
  if not myTeamID then return end

  local eFrac = GetEnergyFrac(myTeamID)
  local needPause  = (eFrac <= stallThresholdE)
  local canResume  = (eFrac >= resumeThresholdE)

  for unitID, data in pairs(factories) do
    if data.managed then
      if needPause then
        if (not ignoreDuringBuild) or (ignoreDuringBuild and not IsFactoryBuilding(unitID)) then
          SetFactoryActive(unitID, false)
          data.paused = true
        end
      elseif canResume and data.paused then
        SetFactoryActive(unitID, true)
        data.paused = false
      end
    end
  end
end

local function ToggleSelectedManaged()
  local sel = spGetSelectedUnits()
  if not sel or #sel == 0 then
    spEcho("[AFM] Select one or more factories to toggle management.")
    return
  end
  local toggled = 0
  for i = 1, #sel do
    local u = sel[i]
    local d = factories[u]
    if d then
      d.managed = not d.managed
      toggled = toggled + 1
    end
  end
  spEcho("[AFM] Toggled management for " .. toggled .. " factory(ies).")
end

--------------------------------------------------------------------------------
-- Widget API
--------------------------------------------------------------------------------

function widget:Initialize()
  myTeamID = spGetMyTeamID()
  isSpec   = select(3, spGetSpectatingState())

  if isSpec then
    widgetHandler:RemoveWidget()
    return
  end

  -- Scan existing team units
  local units = spGetTeamUnits(myTeamID) or {}
  for i = 1, #units do
    local u = units[i]
    local defID = spGetUnitDefID(u)
    if IsFactory(defID) then
      AddFactory(u, defID)
    end
  end

  -- Register an action so you can bind a key:
  -- /bind any+p luaui afm_toggle_selected
  widgetHandler:AddAction("afm_toggle_selected", function() ToggleSelectedManaged() end, nil, "t")

  spEcho("[AFM] Auto Factory Manager loaded. Type /afm help for commands.")
end

function widget:Shutdown()
  -- nothing persistent written; thresholds may be saved via widget options if extended later
end

function widget:PlayerChanged(playerID)
  myTeamID = spGetMyTeamID()
  isSpec   = select(3, spGetSpectatingState())
  if isSpec then widgetHandler:RemoveWidget() end
end

function widget:GameFrame(n)
  if (n - lastFrameCheck) >= manageInterval then
    lastFrameCheck = n
    ManageFactories()
  end
end

-- Track ownership changes / add-remove

function widget:UnitFinished(unitID, unitDefID, unitTeam)
  if unitTeam == myTeamID and IsFactory(unitDefID) then
    AddFactory(unitID, unitDefID)
  end
end

function widget:UnitDestroyed(unitID)
  if factories[unitID] then
    RemoveFactory(unitID)
  end
end

function widget:UnitGiven(unitID, unitDefID, newTeam)
  if factories[unitID] then RemoveFactory(unitID) end
  if newTeam == myTeamID and IsFactory(unitDefID) then
    AddFactory(unitID, unitDefID)
  end
end

function widget:UnitTaken(unitID, unitDefID, oldTeam)
  if factories[unitID] then RemoveFactory(unitID) end
end

--------------------------------------------------------------------------------
-- Drawing (markers for managed / paused factories)
--------------------------------------------------------------------------------

local glColor            = gl.Color
local glDrawGroundCircle = gl.DrawGroundCircle
local glDepthTest        = gl.DepthTest

function widget:DrawWorldPreUnit()
  if not drawMarkers then return end
  glDepthTest(true)
  for unitID, data in pairs(factories) do
    if data.managed then
      local r,g,b,a = (data.paused and colorPaused[1] or colorManaged[1]),
                      (data.paused and colorPaused[2] or colorManaged[2]),
                      (data.paused and colorPaused[3] or colorManaged[3]),
                      (data.paused and colorPaused[4] or colorManaged[4])
      glColor(r,g,b,a)
      local x,y,z = Spring.GetUnitPosition(unitID)
      if x and y and z then
        glDrawGroundCircle(x, y, z, ringRadius, 24)
      end
    end
  end
  glColor(1,1,1,1)
  glDepthTest(false)
end

--------------------------------------------------------------------------------
-- Commands: "/afm ..."
--   /afm on|off               -> enable/disable management for ALL your factories
--   /afm stall <0..1>         -> set stall energy threshold
--   /afm resume <0..1>        -> set resume energy threshold
--   /afm status               -> print current config and counts
--   /afm ignorebuilding on|off-> set ignoreDuringBuild
--   /afm markers on|off       -> toggle ground markers
--   /afm toggle               -> toggle management for selected factories (same as hotkey action)
--   /afm help                 -> show help
--------------------------------------------------------------------------------

local function Clamp01(x) return math.max(0, math.min(1, x)) end

local function PrintStatus()
  local total, managed, paused = 0,0,0
  for _, d in pairs(factories) do
    total = total + 1
    if d.managed then managed = managed + 1 end
    if d.paused  then paused  = paused + 1 end
  end
  spEcho(("[AFM] eStall=%.2f  eResume=%.2f  managed=%d paused=%d total=%d  ignoreDuringBuild=%s  markers=%s")
    :format(stallThresholdE, resumeThresholdE, managed, paused, total, tostring(ignoreDuringBuild), tostring(drawMarkers)))
end

function widget:TextCommand(cmd)
  if cmd:sub(1,4) ~= "afm " then return end
  local args = {}
  for tok in cmd:gmatch("%S+") do args[#args+1] = tok end
  local sub = args[2]

  if sub == "help" or sub == nil then
    spEcho("[AFM] Commands:")
    spEcho("  /afm on|off                - enable/disable management for all your factories")
    spEcho("  /afm stall <0..1>          - set stall energy threshold (pause below)")
    spEcho("  /afm resume <0..1>         - set resume energy threshold (resume above)")
    spEcho("  /afm ignorebuilding on|off - do not pause if factory is building")
    spEcho("  /afm markers on|off        - show ground rings for managed factories")
    spEcho("  /afm toggle                - toggle management for selected factories")
    spEcho("  /afm status                - print current settings")
    return true
  elseif sub == "on" or sub == "off" then
    local set = (sub == "on")
    for _, d in pairs(factories) do d.managed = set end
    spEcho("[AFM] Management set to " .. tostring(set) .. " for all factories.")
    return true
  elseif sub == "stall" and args[3] then
    local v = tonumber(args[3])
    if v then
      stallThresholdE = Clamp01(v)
      spEcho("[AFM] stallThresholdE = " .. stallThresholdE)
    end
    return true
  elseif sub == "resume" and args[3] then
    local v = tonumber(args[3])
    if v then
      resumeThresholdE = Clamp01(v)
      spEcho("[AFM] resumeThresholdE = " .. resumeThresholdE)
    end
    return true
  elseif sub == "ignorebuilding" and args[3] then
    local on = (args[3] == "on" or args[3] == "true" or args[3] == "1")
    ignoreDuringBuild = on
    spEcho("[AFM] ignoreDuringBuild = " .. tostring(on))
    return true
  elseif sub == "markers" and args[3] then
    local on = (args[3] == "on" or args[3] == "true" or args[3] == "1")
    drawMarkers = on
    spEcho("[AFM] drawMarkers = " .. tostring(on))
    return true
  elseif sub == "toggle" then
    ToggleSelectedManaged()
    return true
  elseif sub == "status" then
    PrintStatus()
    return true
  end

  spEcho("[AFM] Unknown command. Use /afm help")
  return true
end
