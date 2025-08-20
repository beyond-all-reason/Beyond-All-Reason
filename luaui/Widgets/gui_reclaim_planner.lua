function widget:GetInfo()
  return {
    name      = "Reclaim Planner",
    desc      = "Heatmap of reclaim in LOS + Shift-drag to auto-queue optimized reclaim for selected constructors (Alt = clustered area reclaim).",
    author    = "you + GPT-5 Pro",
    date      = "2025-08-20",
    license   = "MIT",
    version   = 1,
    layer     = 0,
    enabled   = false, -- enable with F11 widget list or /luaui enablewidget Reclaim Planner
  }
end

--------------------------------------------------------------------------------
-- Config (can be changed via /reclaimui chat cmds)
--------------------------------------------------------------------------------

local scanIntervalFrames = 30   -- refresh every ~0.5s at 60fps
local minMetal           = 5    -- minimum metal to display/consider (features with less are ignored)
local minEnergy          = 0    -- minimum energy to display/consider
local drawHeatmap        = true
local drawTopN           = 80   -- draw only the top N highest-value features
local ringRadiusMin      = 18
local ringRadiusMax      = 64
local metalWeight        = 1.0  -- value score = metal*metalWeight + energy*energyWeight
local energyWeight       = 0.02 -- energy is usually low value vs metal; scale accordingly
local rectLineWidth      = 2.0  -- selection rectangle outline
local colorRectFill      = {0.1, 0.9, 0.1, 0.10}
local colorRectLine      = {0.2, 1.0, 0.2, 0.8}
local colorHeatLow       = {0.6, 0.8, 1.0, 0.35}
local colorHeatHigh      = {1.0, 0.5, 0.1, 0.80}
local clusterCell        = 128  -- world units per cluster cell (Alt-drag area reclaim)
local clusterRadius      = 128  -- radius for area reclaim commands

--------------------------------------------------------------------------------
-- Engine refs
--------------------------------------------------------------------------------

local Echo                      = Spring.Echo
local glColor                   = gl.Color
local glDrawGroundCircle        = gl.DrawGroundCircle
local glDepthTest               = gl.DepthTest
local glRect                    = gl.Rect
local glLineWidth               = gl.LineWidth
local glBeginEnd                = gl.BeginEnd
local GL_LINE_LOOP              = GL.LINE_LOOP
local GetViewGeometry           = Spring.GetViewGeometry
local WorldToScreenCoords       = Spring.WorldToScreenCoords
local TraceScreenRay            = Spring.TraceScreenRay
local GetSelectedUnits          = Spring.GetSelectedUnits
local GetUnitDefID              = Spring.GetUnitDefID
local GetTeamUnits              = Spring.GetTeamUnits
local GetFeatureDefID           = Spring.GetFeatureDefID
local GetFeaturePosition        = Spring.GetFeaturePosition
local GetAllFeatures            = Spring.GetAllFeatures
local GetMyAllyTeamID           = Spring.GetMyAllyTeamID
local GetSpectatingState        = Spring.GetSpectatingState
local GetMyTeamID               = Spring.GetMyTeamID
local IsPosInLos                = Spring.IsPosInLos
local GiveOrderToUnit           = Spring.GiveOrderToUnit
local GetModKeyState            = Spring.GetModKeyState
local GetGameFrame              = Spring.GetGameFrame

local CMD_RECLAIM               = CMD.RECLAIM

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local myTeamID       = nil
local myAllyTeamID   = nil
local isSpec         = false

-- { {id, x,y,z, metal, energy, value}, ... } sorted by value DESC
local featuresCache  = {}
local lastScanFrame  = 0
local needsRescan    = true

-- input/drag
local dragging       = false
local dragStartX, dragStartY = 0, 0
local dragCurX,   dragCurY   = 0, 0

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function Clamp(x, a, b) return (x < a and a) or (x > b and b) or x end

local function MixColor(c1, c2, t)
  return
    c1[1] + (c2[1]-c1[1])*t,
    c1[2] + (c2[2]-c1[2])*t,
    c1[3] + (c2[3]-c1[3])*t,
    c1[4] + (c2[4]-c1[4])*t
end

local function ScreenToGround(x, y)
  local typ, gx, gy, gz = TraceScreenRay(x, y, true, true)
  if typ == "ground" then
    return gx, gy, gz
  end
  return nil
end

local function IsConstructor(unitID)
  local ud = UnitDefs[GetUnitDefID(unitID) or -1]
  if not ud then return false end
  return (ud.builder == true) or (ud.canReclaim == true)
end

local function FeatureValue(fd)
  local m = fd.metal or 0
  local e = fd.energy or 0
  return m * metalWeight + e * energyWeight
end

local function ScanFeatures()
  local ally = myAllyTeamID
  if not ally then return end

  local list = {}
  local all = GetAllFeatures() or {}
  for i = 1, #all do
    local fid  = all[i]
    local fdid = GetFeatureDefID(fid)
    local fd   = fdid and FeatureDefs[fdid]
    if fd then
      local m = fd.metal or 0
      local e = fd.energy or 0
      if (m >= minMetal) or (e >= minEnergy) then
        local x,y,z = GetFeaturePosition(fid)
        if x and IsPosInLos(x,y,z, ally) then
          local value = FeatureValue(fd)
          if value > 0 then
            list[#list+1] = { id = fid, x = x, y = y, z = z, metal = m, energy = e, value = value }
          end
        end
      end
    end
  end
  table.sort(list, function(a,b) return a.value > b.value end)
  featuresCache = list
  needsRescan = false
end

local function DrawHeatmap()
  if not drawHeatmap then return end
  glDepthTest(true)
  local count = math.min(drawTopN, #featuresCache)
  local maxV  = 0
  for i = 1, count do
    if featuresCache[i].value > maxV then maxV = featuresCache[i].value end
  end
  if maxV <= 0 then glDepthTest(false) return end

  for i = 1, count do
    local f = featuresCache[i]
    local t = Clamp(f.value / maxV, 0, 1)
    local r,g,b,a = MixColor(colorHeatLow, colorHeatHigh, t)
    glColor(r,g,b,a)
    local radius = Clamp(ringRadiusMin + (ringRadiusMax - ringRadiusMin) * t, ringRadiusMin, ringRadiusMax)
    glDrawGroundCircle(f.x, f.y, f.z, radius, 24)
  end
  glColor(1,1,1,1)
  glDepthTest(false)
end

local function DrawDragRect()
  if not dragging then return end
  local x1,y1 = dragStartX, dragStartY
  local x2,y2 = dragCurX,   dragCurY
  glColor(colorRectFill[1],colorRectFill[2],colorRectFill[3],colorRectFill[4])
  glRect(x1, y1, x2, y2)
  glColor(colorRectLine[1],colorRectLine[2],colorRectLine[3],colorRectLine[4])
  glLineWidth(rectLineWidth)
  glBeginEnd(GL_LINE_LOOP, function()
    gl.Vertex(x1, y1); gl.Vertex(x2, y1); gl.Vertex(x2, y2); gl.Vertex(x1, y2)
  end)
  glLineWidth(1.0)
  glColor(1,1,1,1)
end

local function GetBoxWorldBounds()
  local sx1, sy1 = dragStartX, dragStartY
  local sx2, sy2 = dragCurX,   dragCurY
  local gx1,gy1,gz1 = ScreenToGround(sx1, sy1)
  local gx2,gy2,gz2 = ScreenToGround(sx2, sy2)
  if not gx1 or not gx2 then return nil end
  local minx = math.min(gx1, gx2)
  local maxx = math.max(gx1, gx2)
  local minz = math.min(gz1, gz2)
  local maxz = math.max(gz1, gz2)
  return minx, minz, maxx, maxz
end

local function FeaturesInBox(minx, minz, maxx, maxz)
  local t = {}
  for i = 1, #featuresCache do
    local f = featuresCache[i]
    if f.x >= minx and f.x <= maxx and f.z >= minz and f.z <= maxz then
      t[#t+1] = f
    end
  end
  table.sort(t, function(a,b) return a.value > b.value end)
  return t
end

local function SelectedConstructors()
  local sel = GetSelectedUnits() or {}
  local out = {}
  for i = 1, #sel do
    local u = sel[i]
    if IsConstructor(u) then out[#out+1] = u end
  end
  return out
end

local function QueueFeatureReclaim(builders, feats)
  if #builders == 0 or #feats == 0 then
    Echo("[RP] Select one or more constructors and Shift-drag a box over wreckage.")
    return
  end
  local idx = 1
  for i = 1, #feats do
    local b = builders[((idx - 1) % #builders) + 1]
    GiveOrderToUnit(b, CMD_RECLAIM, {feats[i].id}, {"shift"})
    idx = idx + 1
  end
  Echo(("[RP] Queued reclaim: %d features across %d builders."):format(#feats, #builders))
end

local function QueueClusterReclaim(builders, feats)
  if #builders == 0 or #feats == 0 then
    Echo("[RP] Select one or more constructors and Alt+Shift-drag a box over wreckage.")
    return
  end
  -- Simple grid clustering
  local cells = {}  -- key="ix:iz" => {sumx,sumz,count}
  for i = 1, #feats do
    local f = feats[i]
    local ix = math.floor(f.x / clusterCell)
    local iz = math.floor(f.z / clusterCell)
    local k = ix .. ":" .. iz
    local c = cells[k]
    if not c then
      c = { sumx = 0, sumz = 0, count = 0, weight = 0 }
      cells[k] = c
    end
    c.sumx   = c.sumx + f.x
    c.sumz   = c.sumz + f.z
    c.count  = c.count + 1
    c.weight = c.weight + f.value
  end
  local clusters = {}
  for _,c in pairs(cells) do
    clusters[#clusters+1] = {
      x = c.sumx / c.count,
      z = c.sumz / c.count,
      weight = c.weight
    }
  end
  table.sort(clusters, function(a,b) return a.weight > b.weight end)

  local idx = 1
  for i = 1, #clusters do
    local cl = clusters[i]
    local x,z = cl.x, cl.z
    local y   = 0 -- engine fills height
    local b   = builders[((idx - 1) % #builders) + 1]
    GiveOrderToUnit(b, CMD_RECLAIM, {x, y, z, clusterRadius}, {"shift"})
    idx = idx + 1
  end
  Echo(("[RP] Queued area-reclaim: %d clusters across %d builders."):format(#clusters, #builders))
end

--------------------------------------------------------------------------------
-- Widget lifecycle
--------------------------------------------------------------------------------

function widget:Initialize()
  myTeamID     = GetMyTeamID()
  myAllyTeamID = GetMyAllyTeamID()
  isSpec       = select(3, GetSpectatingState())

  if isSpec then
    widgetHandler:RemoveWidget()
    return
  end

  ScanFeatures()
  widgetHandler:AddAction("reclaimui_toggle", function()
    drawHeatmap = not drawHeatmap
    Echo("[RP] Heatmap draw = " .. tostring(drawHeatmap))
  end, nil, "t")

  Echo("[RP] Reclaim Planner loaded. Shift-drag to auto-queue reclaim. Use /reclaimui help for commands.")
end

function widget:Shutdown()
  -- nothing to persist
end

--------------------------------------------------------------------------------
-- Feature events -> mark for rescan (cheap)
--------------------------------------------------------------------------------

function widget:FeatureCreated()
  needsRescan = true
end

function widget:FeatureDestroyed()
  needsRescan = true
end

--------------------------------------------------------------------------------
-- Per-frame
--------------------------------------------------------------------------------

function widget:GameFrame(n)
  if needsRescan or (n - lastScanFrame) >= scanIntervalFrames then
    ScanFeatures()
    lastScanFrame = n
  end
end

function widget:DrawWorldPreUnit()
  DrawHeatmap()
end

function widget:DrawScreen()
  DrawDragRect()
end

--------------------------------------------------------------------------------
-- Mouse input (Shift-drag = queue; Alt modifies to cluster/area)
--------------------------------------------------------------------------------

function widget:MousePress(x, y, button)
  local alt, ctrl, meta, shift = GetModKeyState()
  if button == 1 and shift then
    dragging   = true
    dragStartX = x; dragStartY = y
    dragCurX   = x; dragCurY   = y
    return true
  end
  return false
end

function widget:MouseMove(x, y, dx, dy, button)
  if dragging then
    dragCurX = x; dragCurY = y
  end
end

function widget:MouseRelease(x, y, button)
  if dragging and button == 1 then
    dragging = false
    dragCurX, dragCurY = x, y

    local minx, minz, maxx, maxz = GetBoxWorldBounds()
    if not minx then return end

    local feats   = FeaturesInBox(minx, minz, maxx, maxz)
    local builders = SelectedConstructors()

    local alt, ctrl, meta, shift = GetModKeyState()
    if alt then
      QueueClusterReclaim(builders, feats)
    else
      QueueFeatureReclaim(builders, feats)
    end
    return true
  end
end

--------------------------------------------------------------------------------
-- Chat commands: /reclaimui ...
--------------------------------------------------------------------------------
local function Clamp01(v) return Clamp(v, 0, 1) end

local function PrintStatus()
  Echo(("[RP] drawHeatmap=%s topN=%d minMetal=%d minEnergy=%d scanInterval=%d frames")
    :format(tostring(drawHeatmap), drawTopN, minMetal, minEnergy, scanIntervalFrames))
end

function widget:TextCommand(cmd)
  if cmd:sub(1,10) ~= "reclaimui " then return end
  local args = {}
  for tok in cmd:gmatch("%S+") do args[#args+1] = tok end
  local sub = args[2]

  if not sub or sub == "help" then
    Echo("[RP] Commands:")
    Echo("  /reclaimui toggle        - toggle heatmap drawing")
    Echo("  /reclaimui min <metal>   - set minimum metal per feature (default 5)")
    Echo("  /reclaimui energy <en>   - set minimum energy per feature (default 0)")
    Echo("  /reclaimui top <N>       - draw top N features (default 80)")
    Echo("  /reclaimui interval <f>  - set scan interval in frames (default 30)")
    Echo("  /reclaimui status        - print current settings")
    Echo("Usage: Shift-drag to queue reclaim; Alt+Shift-drag to queue cluster area-reclaim.")
    return true
  elseif sub == "toggle" then
    drawHeatmap = not drawHeatmap
    Echo("[RP] drawHeatmap = " .. tostring(drawHeatmap))
    return true
  elseif sub == "min" and args[3] then
    minMetal = math.max(0, tonumber(args[3]) or minMetal)
    Echo("[RP] minMetal = " .. minMetal)
    needsRescan = true
    return true
  elseif sub == "energy" and args[3] then
    minEnergy = math.max(0, tonumber(args[3]) or minEnergy)
    Echo("[RP] minEnergy = " .. minEnergy)
    needsRescan = true
    return true
  elseif sub == "top" and args[3] then
    drawTopN = math.max(1, math.floor(tonumber(args[3]) or drawTopN))
    Echo("[RP] drawTopN = " .. drawTopN)
    return true
  elseif sub == "interval" and args[3] then
    scanIntervalFrames = math.max(1, math.floor(tonumber(args[3]) or scanIntervalFrames))
    Echo("[RP] scanIntervalFrames = " .. scanIntervalFrames)
    return true
  elseif sub == "status" then
    PrintStatus()
    return true
  end
  Echo("[RP] Unknown command. Use /reclaimui help")
  return true
end
