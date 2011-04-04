--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_limit_dgun.lua
--  brief:   shows a pre-game warning if DGun limit is on--  author:  KingRaptor
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "DGunLimit",
    desc      = "Indicator for the Limit DGun state (at game start)",
    author    = "KingRaptor",
    date      = "May 22, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = -3,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not Game.limitDGun) then
  return false
end

WhiteStr   = "\255\255\255\255"
GreyStr    = "\255\210\210\210"
GreenStr   = "\255\092\255\092"
BlueStr    = "\255\170\170\255" 
YellowStr  = "\255\255\255\152"
OrangeStr  = "\255\255\190\128"
RedStr     = "\255\170\170\255"

local vsx, vsy = widgetHandler:GetViewSizes()

function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY
end


function widget:DrawScreen()
  if (Spring.GetGameSeconds() > 1) then
    widgetHandler:RemoveWidget()
  end
  local timer = widgetHandler:GetHourTimer()
  local colorStr
  if ((timer % 0.5) < 0.25) then
    colorStr = RedStr
  else
    colorStr = YellowStr
  end
  gl.Text(colorStr .. "DGun Limit is ON", (vsx * 0.5), (vsy * 0.4) - 50, 24, "oc")
end

