--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Coop Info",
    desc      = "informs players of the game type at start",
    author    = "Teutooni/TheFatController",
    date      = "Jul 6, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local enabled = tonumber(Spring.GetModOptions().mo_coop) or 0

if (enabled == 0) or (Game.startPosType ~= 2) then
  return false
end

if Spring.GetSpectatingState() or Spring.IsReplay() then
  return false
end

if (enabled == 1) then
  local playerCount = 0
  for _, playerID in ipairs(Spring.GetPlayerList(myTeamID)) do
    if not select(3,Spring.GetPlayerInfo(playerID)) then
      playerCount = playerCount + 1
    end
  end
  if (playerCount < 2) then
    return false
  end
end

-- Automatically generated local definitions

local glPopMatrix      = gl.PopMatrix
local glPushMatrix     = gl.PushMatrix
local glRotate         = gl.Rotate
local glScale          = gl.Scale
local glText           = gl.Text
local glTranslate      = gl.Translate
local spGetGameSeconds = Spring.GetGameSeconds

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

include("colors.h.lua")

local floor = math.floor

local font = "LuaUI/Fonts/FreeSansBold_30"
local fh = fontHandler.UseFont(font)

local vsx, vsy = widgetHandler:GetViewSizes()
function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY
end

function widget:GameStart()
  widgetHandler:RemoveWidget()
end

function widget:DrawScreen()
  if Spring.GetGameFrame() > 1 then 
    widgetHandler:RemoveWidget()
  end
  local colorStr = WhiteStr
  local message	 = "Coop mode: Don't press 'Ready' until all allies points are chosen."

  local msg = colorStr .. message
  glPushMatrix()
  glTranslate((vsx * 0.5), (vsy * 0.5) - 100, 0)
  glScale(1.5, 1.5, 1)
  if (fh) then
    fh = fontHandler.UseFont(font)
    fontHandler.DrawCentered(msg)
  else
    glText(msg, 0, 0, 20, "doc")
  end
  glPopMatrix()
end

