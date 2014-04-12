--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_game_type_info.lua
--  brief:   informs players of the game type at start (i.e. Comends, lineage, com continues(killall) , commander control or commander mode)
--  author:  Riku Eischer
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--  Thanks to trepan (Dave Rodgers) for the original CommanderEnds widget
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "GameTypeInfo",
    desc      = "informs players of the game type at start",
    author    = "Teutooni",
    date      = "Jul 6, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

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


function widget:DrawScreen()
  if (spGetGameSeconds() > 1) then
    widgetHandler:RemoveWidget()
  end
  
  local timer = widgetHandler:GetHourTimer()
  local colorStr = WhiteStr
  local message
	
	
 if (Game.gameMode == 1) then
	message = "Commander Ends"
  elseif (Game.gameMode == 2) then
	message = "Lineage"
  else
	message = "Commander Continues"
	if Spring.GetModOptions().deathmode=="com" then
		message = "Kill all enemy Commanders"
	elseif Spring.GetModOptions().deathmode=="comcontrol" then
		message = "Lose your Commander, Lose Control!"
	elseif Spring.GetModOptions().deathmode=="minors" then
		message = "changeme" -- depends on mod
	end
  end
		

  local msg = colorStr .. string.format("%s %s", "Gametype: ",  message)
  glPushMatrix()
  glTranslate((vsx * 0.5), (vsy * 0.22), 0) --has to be below where newbie info appears!
  glScale(1.5, 1.5, 1)
--  glRotate(30 * math.sin(math.pi * 0.5 * timer), 0, 0, 1)
  if (fh) then
    fh = fontHandler.UseFont(font)
    fontHandler.DrawCentered(msg)
  else
    glText(msg, 0, 0, 24, "oc")
  end
  glPopMatrix()
end

function widget:GameOver()
  widgetHandler:RemoveWidget()
end

