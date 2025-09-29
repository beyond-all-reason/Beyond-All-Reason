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

local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "RelativeMinimap",
    desc      = "Keeps the minimap at a relative size (maxspect)",
    author    = "trepan",
    date      = "Feb 5, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
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

local getCurrentMiniMapRotationOption = VFS.Include("luaui/Include/minimap_utils.lua").getCurrentMiniMapRotationOption
local ROTATION = VFS.Include("luaui/Include/minimap_utils.lua").ROTATION

function widget:Initialize()
  widget:ViewResize(widgetHandler:GetViewSizes())
end


function widget:ViewResize(viewSizeX, viewSizeY)
  -- the extra 2 pixels are for the minimap border
  local xp = math.floor(viewSizeX * xmax) - xoff - 2
  local yp = math.floor(viewSizeY * ymax) - yoff - 2
  local limitAspect = (xp / yp)
  local currRot = getCurrentMiniMapRotationOption()
  local mapAspect
  if currRot == ROTATION.DEG_90 or currRot == ROTATION.DEG_270 then
    mapAspect = (Game.mapSizeZ / Game.mapSizeX)
  else
    mapAspect = (Game.mapSizeX / Game.mapSizeZ)
  end

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
