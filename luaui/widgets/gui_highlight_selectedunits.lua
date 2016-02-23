--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    gui_highlight_unit.lua
--  brief:   highlights the unit/feature under the cursor
--  author:  Dave Rodgers, modified by zwzsg
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local FadeToGrey = false -- Set to true to automatically turn your unit to grey so the health color shows better

function widget:GetInfo()
  return {
    name      = "Highlight Selected Units",
    desc      = "Highlights the selelected units",
    author    = "zwzsg, from trepan HighlightUnit",
    date      = "Apr 24, 2009",
    license   = "GNU GPL, v2 or later",
    layer     = 25,
    enabled   = true
  }
end


highlightAlpha = 0.24


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local function SetupCommandColors(state)
  local alpha = state and 1 or 0
  local f = io.open('cmdcolors.tmp', 'w+')
  if (f) then
    f:write('unitBox  0 1 0 ' .. alpha)
    f:close()
    Spring.SendCommands({'cmdcolors cmdcolors.tmp'})
  end
  os.remove('cmdcolors.tmp')
end


local texName = LUAUI_DIRNAME .. 'Images/highlight_strip.png'
local function HilightModel(unitID)
  gl.DepthTest(true)
  gl.PolygonOffset(-2, -2)
  gl.Blending(GL.SRC_ALPHA, GL.ONE)

  if (smoothPolys) then
    gl.Smoothing(nil, nil, true)
  end

  local scale = 35
  local shift = (2 * widgetHandler:GetHourTimer()) % scale
  gl.TexCoord(0, 0)
  gl.TexGen(GL.T, GL.TEXTURE_GEN_MODE, GL.EYE_LINEAR)
  gl.TexGen(GL.T, GL.EYE_PLANE, 0, (1 / scale), 0, shift)
  gl.Texture(texName)

  gl.Unit(unitID, true)

  gl.Texture(false)
  gl.TexGen(GL.T, false)

  if (smoothPolys) then
    gl.Smoothing(nil, nil, false)
  end

  gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
  gl.PolygonOffset(false)
  gl.DepthTest(false)
end


--------------------------------------------------------------------------------

function widget:Initialize()
  SetupCommandColors(false)
end


function widget:Shutdown()
  SetupCommandColors(true)
end



--------------------------------------------------------------------------------

function widget:DrawWorld()
	gl.DepthTest(true)
	gl.PolygonOffset(-2, -2)
	gl.Blending(GL.SRC_ALPHA, GL.ONE)

	for _,unitID in ipairs(Spring.GetSelectedUnits()) do
		local health,maxHealth,paralyzeDamage,captureProgress,buildProgress=Spring.GetUnitHealth(unitID)
		gl.Color(
		health>maxHealth/2 and 2-2*health/maxHealth or 1, -- red
		health>maxHealth/2 and 1 or 2*health/maxHealth, -- green
		0, -- blue
		highlightAlpha) -- alpha
		gl.Unit(unitID, true)
		--HilightModel(unitID)
	end

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.PolygonOffset(false)
	gl.DepthTest(false)
end


widget.DrawWorldReflection = widget.DrawWorld

widget.DrawWorldRefraction = widget.DrawWorld

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
