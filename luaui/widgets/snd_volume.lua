--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    snd_volume.lua
--  brief:   volume control slider
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "SoundVolume",
    desc      = "A sound volume slider  (only works in game)",
    author    = "trepan",
    date      = "Jan 15, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--fixed to work with 0.79.1 by very_bad_soldier
--fixed to work with 0.76b1 by very_bad_soldier
--


local TEST_SOUND = LUAUI_DIRNAME .. 'Sounds/pop.wav'

local function PlayTestSound()
  Spring.PlaySoundFile(TEST_SOUND, 1.0)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local volume = 1.0

local vsx, vsy = widgetHandler:GetViewSizes()
local xmin, xmax, ymin, ymax


local function UpdateGeometry()
  xmin = math.floor(vsx * 0.9)
  xmax = math.floor(vsx * 0.92)
  ymin = math.floor(vsy * 0.2)
  ymax = math.floor(vsy * 0.4)
end
UpdateGeometry()


function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY
  UpdateGeometry()
end


--------------------------------------------------------------------------------

local function CalcVolume(y)
  volume = (y - ymin) / (ymax - ymin)
  if (volume > 100) then
    volume = 1
  elseif (volume < 0) then
    volume = 0
  end
end


function widget:Initialize()
  volume = Spring.GetConfigInt("snd_volmaster", 60)
  volume = volume * 0.01
end


function widget:IsAbove(x, y)
  return ((x >= xmin) and (x <= xmax) and
          (y >= ymin) and (y <= ymax))
end


function widget:GetTooltip(x, y)
  if (Spring.GetGameSeconds() < 0.1) then
    return "Sound Volume  (only works in game)"
  else
    return "Sound Volume"
  end
end


function widget:MousePress(x, y, button)
  if (Spring.GetGameSeconds() < 0.1) then
    return false
  end
  if (widget:IsAbove(x, y)) then
    CalcVolume(y)
	Spring.SetConfigInt("snd_volmaster", volume * 100)
	
	volume = Spring.GetConfigInt("snd_volmaster", volume)

	volume = volume * 0.01
  
    return true
  end
  return false
end


function widget:MouseMove(x, y, dx, dy, button)
  CalcVolume(y)
  Spring.SetConfigInt("snd_volmaster", volume * 100)
  return
end


function widget:MouseRelease(x, y, button)
  CalcVolume(y)
  Spring.SetConfigInt("snd_volmaster", volume * 100)
  PlayTestSound()
  return -1
end


function widget:DrawScreen()
  -- fade before the game starts  ("volume" command is not available)
  local alpha = (Spring.GetGameSeconds() < 0.1) and 0.2 or 0.9
  local yvol = ymin + volume * (ymax - ymin)
  -- green/red level indicator
  gl.ShadeModel(GL.FLAT)
  gl.Color(.3, .3, .3)
  gl.Shape(GL.QUAD_STRIP, {
    { v = { xmin, ymin } },
    { v = { xmax, ymin } },
    { v = { xmin, yvol } },
    { v = { xmax, yvol }, c = { 0, 1, 0, alpha } },
    { v = { xmin, ymax } },
    { v = { xmax, ymax }, c = { 1, 0, 0, alpha } }
  })
  gl.ShadeModel(GL.SMOOTH)
  -- outline
  gl.Color(0, 0, 0, alpha)
  gl.Shape(GL.LINE_LOOP, {
    { v = { xmin - 0.5, ymin - 0.5 } },
    { v = { xmax + 0.5, ymin - 0.5 } },
    { v = { xmax + 0.5, ymax + 0.5 } },
    { v = { xmin - 0.5, ymax + 0.5 } },
  })
  gl.Color(1, 1, 1, alpha)
  gl.Shape(GL.LINE_LOOP, {
    { v = { xmin - 1.5, ymin - 1.5 } },
    { v = { xmax + 1.5, ymin - 1.5 } },
    { v = { xmax + 1.5, ymax + 1.5 } },
    { v = { xmin - 1.5, ymax + 1.5 } },
  })
  -- header
  gl.Text(string.format("%i%%", 100 * volume),
                        0.5 * (xmin + xmax), ymax + 4, 12, "ocn")
  return
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
