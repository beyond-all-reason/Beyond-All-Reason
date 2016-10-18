--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    minimap_relative.lua
--  brief:   keeps the minimap at a relative size (maxspect)
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "RelativeMinimap",
    desc      = "Keeps the minimap at a relative size (maxspect)",
    author    = "trepan",
    date      = "Feb 5, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- Adjust these setting to your liking
--

-- offsets, in pixels
local xoff = 2
local yoff = 2

-- maximum fraction of screen size,
-- set one value to 1 to calibrate the other
local xmax = 0.262
local ymax = 0.310


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- Make sure these are floored
--

xoff = math.floor(xoff)
yoff = math.floor(yoff)


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
  widget:ViewResize(widgetHandler:GetViewSizes())
end


function widget:ViewResize(viewSizeX, viewSizeY)
  -- the extra 2 pixels are for the minimap border
  local xp = math.floor(viewSizeX * xmax) - xoff - 2
  local yp = math.floor(viewSizeY * ymax) - yoff - 2
  local limitAspect = (xp / yp)
  local mapAspect = (Game.mapSizeX / Game.mapSizeZ)

  local sx, sy
  if (mapAspect > limitAspect) then
    sx = xp
    sy = xp / mapAspect
  else
    sx = yp * mapAspect
    sy = yp
  end
  sx = math.floor(sx)
  sy = math.floor(sy)
  gl.ConfigMiniMap(xoff, viewSizeY - sy - yoff, sx, sy)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
