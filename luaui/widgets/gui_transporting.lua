--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_transporting.lua
--  brief:   Display the units currently being transported
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Transporting",
    desc      = "Display the units being transported",
    author    = "trepan",
    date      = "Jan 8, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
--  Disabled for Spring versions older then 0.74b3 (no GetUnitDefDimensions())
--

function widget:Initialize()
  if ((Spring.GetUnitDefDimensions == nil) or
      (Spring.GetUnitIsTransporting == nil)) then
    Spring.SendCommands({"echo Transporting widget has been disabled"})
    widgetHandler:RemoveWidget()
  end
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

include("colors.h.lua")


local unloadUnitCmdID = 4576


local vsx, vsy = widgetHandler:GetViewSizes()
function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
--  Selection Icons (rough around the edges)
--

local unitTypes = 0
local countsTable = {}
local activePress = false
local mouseIcon = -1
local currentDef = nil

local iconSizeX = math.floor(68)
local iconSizeY = math.floor(iconSizeX * 0.75)
local fontSize = iconSizeY * 0.25

local rectMinX = 0
local rectMaxX = 0
local rectMinY = 0
local rectMaxY = 0


local function SortedTransportedUnits()
  local selUnits = Spring.GetSelectedUnits()
  if (selUnits.n ~= 1) then
    return { n = 0 }
  end
  local units = Spring.GetUnitIsTransporting(selUnits[1])
  if (units == nil) then
    return { n = 0 }
  end
  local typed = {}
  local typeCount = 0
  for _,uid in ipairs(units) do
    local udid = Spring.GetUnitDefID(uid)
    if (udid) then
      if (typed[udid] == nil) then
        typed[udid] = 1
        typeCount = typeCount + 1
      else
        typed[udid] = typed[udid] + 1
      end
    end
  end
  typed.n = typeCount
  return typed
end


function widget:DrawScreen()
  unitCounts = SortedTransportedUnits()
  unitTypes = unitCounts.n;
  if (unitTypes <= 0) then
    countsTable = {}
    activePress = false
    currentDef  = nil
    return
  end
  
  SetupDimensions(unitTypes)

  -- unit model rendering uses the depth-buffer
  gl.Clear(GL.DEPTH_BUFFER_BIT)

  -- draw the buildpics
  unitCounts.n = nil  
  local icon = 0
  for udid,count in pairs(unitCounts) do
    DrawUnitDefIcon(udid, icon, count)
    icon = icon + 1
  end
end


function SetupDimensions(count)
  local xmid = vsx * 0.5
  local width = math.floor(iconSizeX * count)
  rectMinX = math.floor(xmid - (0.5 * width))
  rectMaxX = math.floor(xmid + (0.5 * width))
  rectMaxY = math.floor(vsy * 0.15)
  rectMinY = math.floor(rectMaxY - iconSizeY)
end


function CenterUnitDef(unitDefID)
  local ud = UnitDefs[unitDefID] 
  if (not ud) then
    return
  end
  if (not ud.dimensions) then
    ud.dimensions = Spring.GetUnitDefDimensions(unitDefID)
  end
  if (not ud.dimensions) then
    return
  end

  local d = ud.dimensions
  local xSize = (d.maxx - d.minx)
  local ySize = (d.maxy - d.miny)
  local zSize = (d.maxz - d.minz)

  local hSize -- maximum horizontal dimension
  if (xSize > zSize) then hSize = xSize else hSize = zSize end

  -- aspect ratios
  local mAspect = hSize / ySize
  local vAspect = iconSizeX / iconSizeY

  -- scale the unit to the box (maxspect)
  local scale
  if (mAspect > vAspect) then
    scale = (iconSizeX / hSize)
  else
    scale = (iconSizeY / ySize)
  end
  scale = scale * 0.8
  gl.Scale(scale, scale, scale)

  -- translate to the unit's midpoint
  local xMid = 0.5 * (d.maxx + d.minx)
  local yMid = 0.5 * (d.maxy + d.miny)
  local zMid = 0.5 * (d.maxz + d.minz)
  gl.Translate(-xMid, -yMid, -zMid)
end


local function SetupModelDrawing()
  gl.DepthTest(true) 
  gl.DepthMask(true)
  --gl.Culling(GL.FRONT)
  gl.Lighting(true)
  gl.Blending(false)
  gl.Material({
    ambient  = { 0.2, 0.2, 0.2, 1.0 },
    diffuse  = { 1.0, 1.0, 1.0, 1.0 },
    emission = { 0.0, 0.0, 0.0, 1.0 },
    specular = { 0.2, 0.2, 0.2, 1.0 },
    shininess = 16.0
  })
end


local function RevertModelDrawing()
  gl.Blending(true)
  gl.Lighting(false)
  --gl.Culling(false)
  gl.DepthMask(false)
  gl.DepthTest(false)
end


local function SetupBackgroundColor(ud)
  if (ud.canFly) then
    gl.Color(0.2, 0.2, 0.0, 0.65)
  elseif (ud.floatOnWater) then
    gl.Color(0.0, 0.0, 0.2, 0.65)
  elseif (ud.builder) then
    gl.Color(0.0, 0.2, 0.0, 0.65)
  else
    gl.Color(0.2, 0.2, 0.2, 0.65)
  end
end


function DrawUnitDefIcon(unitDefID, iconPos, count)
  local xmin = math.floor(rectMinX + (iconSizeX * iconPos))
  local xmax = xmin + iconSizeX
  if ((xmax < 0) or (xmin > vsx)) then return end  -- bail
  
  local ymin = rectMinY
  local ymax = rectMaxY
  local xmid = (xmin + xmax) * 0.5
  local ymid = (ymin + ymax) * 0.5

  local ud = UnitDefs[unitDefID] 

  -- draw background quad
--  gl.Color(0.3, 0.3, 0.3, 1.0)
--  gl.Texture('#'..unitDefID)
  SetupBackgroundColor(ud)
  gl.Shape(GL.QUADS, {
    { v = { xmin + 1, ymin + 1 }, t = { 0, 1 } },
    { v = { xmax - 0, ymin + 1 }, t = { 1, 1 } },
    { v = { xmax - 0, ymax - 0 }, t = { 1, 0 } },
    { v = { xmin + 1, ymax - 0 }, t = { 0, 0 } },
  })
  gl.Texture(false)

  -- draw the 3D unit
	SetupModelDrawing()
  
  gl.PushMatrix()
  gl.Scissor(xmin, ymin, xmax - xmin, ymax - ymin)
  gl.Translate(xmid, ymid, 0)
  gl.Rotate(15.0, 1, 0, 0)
  local timer = 1.5 * widgetHandler:GetHourTimer()
  gl.Rotate(math.cos(0.38 * math.pi * timer) * 60.0, 0, 1, 0)

  CenterUnitDef(unitDefID)
  
  local scribe = false
  if (scribe) then
    gl.Lighting(false)
    gl.Culling(false)
    gl.Color(0,0,0,1)
  end

  gl.UnitShape(unitDefID, Spring.GetMyTeamID())

  if (scribe) then
--    gl.LineWidth(0.1)
    gl.Lighting(false)
    gl.DepthMask(false)
    gl.Color(1,1,1,1)
    gl.PolygonOffset(-4, -4)
    gl.PolygonMode(GL.FRONT_AND_BACK, GL.LINE)
    gl.UnitShape(unitDefID, Spring.GetMyTeamID())
    gl.PolygonMode(GL.FRONT_AND_BACK, GL.FILL)
    gl.PolygonOffset(false)
--    gl.LineWidth(1.0)
  end

  gl.Scissor(false)
  gl.PopMatrix()

	RevertModelDrawing()

  -- draw the count text
  gl.Text(count, (xmin + xmax) * 0.5, ymin - fontSize - 4, fontSize, "oc")

  -- draw the border  (note the half pixel shift for drawing lines)
  gl.Color(0, 0, 0)
  gl.Shape(GL.LINE_LOOP, {
    { v = { xmin + 0.5, ymin + 0.5 }, t = { 0, 1 } },
    { v = { xmax + 0.5, ymin + 0.5 }, t = { 1, 1 } },
    { v = { xmax + 0.5, ymax + 0.5 }, t = { 1, 0 } },
    { v = { xmin + 0.5, ymax + 0.5 }, t = { 0, 0 } },
  })
end


function DrawIconQuad(iconPos, color)
  local xmin = rectMinX + (iconSizeX * iconPos)
  local xmax = xmin + iconSizeX
  local ymin = rectMinY
  local ymax = rectMaxY
  gl.Color(color)
  gl.Blending(GL.SRC_ALPHA, GL.ONE)
  gl.Shape(GL.QUADS, {
    { v = { xmin, ymin } },
    { v = { xmax, ymin } },
    { v = { xmax, ymax } },
    { v = { xmin, ymax } },
  })
  gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end
