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

local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 45
local fontfileOutlineSize = 8
local fontfileOutlineStrength = 1.7
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)

-- Automatically generated local definitions

local vsx, vsy = gl.GetViewSizes()
local widgetScale = (0.80 + (vsx*vsy / 6000000))

local glPopMatrix      = gl.PopMatrix
local glPushMatrix     = gl.PushMatrix
local glRotate         = gl.Rotate
local glScale          = gl.Scale
local glText           = gl.Text
local glTranslate      = gl.Translate
local spGetGameSeconds = Spring.GetGameSeconds

local message = ""
local message2 = ""
local message3 = ""
local message4 = ""

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local floor = math.floor

function widget:ViewResize(n_vsx,n_vsy)
  vsx,vsy = Spring.GetViewGeometry()
  widgetScale = (0.80 + (vsx*vsy / 6000000))

  local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
  if (fontfileScale ~= newFontfileScale) then
    fontfileScale = newFontfileScale
    gl.DeleteFont(font)
    font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
  end
end

function widget:Initialize()
  if Spring.GetModOptions().deathmode=="com" then
    message = "Kill all enemy Commanders"
  elseif Spring.GetModOptions().deathmode=="killall" then
    message = "Kill all enemy units"
  elseif Spring.GetModOptions().deathmode=="neverend" then
    widgetHandler:RemoveWidget(self)
  end
  
  if (tonumber(Spring.GetModOptions().preventcombomb) or 0) ~= 0 then
	message2 = "Commanders survive DGuns and commander explosions"
  end
  
  if (tonumber(Spring.GetModOptions().armageddontime) or -1) > 0 then
    plural = ""
    if tonumber(Spring.GetModOptions().armageddontime) ~= 1 then
        plural = "s"
    end
    message3 = "Armageddon at " .. Spring.GetModOptions().armageddontime .. " minute" .. plural
  end

  if (Spring.GetModOptions().unba or "disabled") == "enabled" then
    message4 = "Unbalanced Commanders is enabled: Commander levels up and gain upgrades"
  end
end


local sec = 0
local blink = false
function widget:Update(dt)
  sec = sec + dt
  if sec > 1 then
    sec = sec - 1
  end
  if sec>0.5 then
    blink = true
  else
    blink = false
  end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then return end
  if (spGetGameSeconds() > 0) then
    widgetHandler:RemoveWidget(self)
    return
  end

  local msg = '\255\255\255\255' .. string.format("%s %s", "Gametype: ",  message)
  local msg2 = '\255\255\255\255' .. message2
  local msg3 = "\255\255\0\0" .. message3
  local msg4
  if blink then
    msg4 = "\255\255\222\111" .. message4
  else
    msg4 = "\255\255\150\050" .. message4
  end

  glPushMatrix()
  glTranslate((vsx * 0.5), (vsy * 0.18), 0) --has to be below where newbie info appears!
  glScale(1.5, 1.5, 1)
  font:Begin()
  font:Print(msg, 0, 15*widgetScale, 18*widgetScale, "oc")
  font:Print(msg2, 0, -35*widgetScale, 12.5*widgetScale, "oc")
  font:Print(msg3, 0, -55*widgetScale, 11*widgetScale, "oc")
  font:Print(msg4, 0, 60*widgetScale, 18*widgetScale, "oc")
  font:End()
  glPopMatrix()
end

function widget:GameOver()
  widgetHandler:RemoveWidget(self)
end


function widget:Shutdown()
  gl.DeleteFont(font)
end