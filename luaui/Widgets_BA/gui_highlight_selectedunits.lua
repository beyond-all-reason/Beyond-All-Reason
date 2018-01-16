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
    author    = "Floris (original: zwzsg, from trepan HighlightUnit)",
    date      = "Apr 24, 2009",
    license   = "GNU GPL, v2 or later",
    layer     = -25,
    enabled   = true
  }
end


local highlightAlpha = 0.2
local useShader = true
local maxShaderUnits = 150
local edgeExponent = 3.5

local spIsUnitIcon = Spring.IsUnitIcon
local spIsUnitInView = Spring.IsUnitInView

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


function CreateHighlightShader()
  if shader then
    gl.DeleteShader(shader)
  end
  shader = gl.CreateShader({

    uniform = {
      edgeExponent = edgeExponent/(0.8+highlightAlpha),
      plainAlpha = highlightAlpha,
    },

    vertex = [[
	  // Application to vertex shader
	  varying vec3 normal;
	  varying vec3 eyeVec;
	  varying vec3 color;
	  uniform mat4 camera;
	  uniform mat4 caminv;

	  void main()
	  {
		vec4 P = gl_ModelViewMatrix * gl_Vertex;

		eyeVec = P.xyz;

		normal  = gl_NormalMatrix * gl_Normal;

		color = gl_Color.rgb;

		gl_Position = gl_ProjectionMatrix * P;
	  }
	]],

    fragment = [[
	  varying vec3 normal;
	  varying vec3 eyeVec;
	  varying vec3 color;

	  uniform float edgeExponent;
	  uniform float plainAlpha;

	  void main()
	  {
		float opac = dot(normalize(normal), normalize(eyeVec));
		opac = 1.0 - abs(opac);
		opac = pow(opac, edgeExponent)*0.45;

		gl_FragColor.rgb = color + (opac*1.33);
		gl_FragColor.a = plainAlpha + opac;

	  }
	]],
  })
end
--------------------------------------------------------------------------------

function widget:Initialize()
  WG['highlightselunits'] = {}
  WG['highlightselunits'].getOpacity = function()
    return highlightAlpha
  end
  WG['highlightselunits'].setOpacity = function(value)
    highlightAlpha = value
    CreateHighlightShader()
  end
  WG['highlightselunits'].getShader = function()
    return useShader
  end
  WG['highlightselunits'].setShader = function(value)
    useShader = value
    CreateHighlightShader()
  end
  
  SetupCommandColors(false)
  if gl.CreateShader ~= nil then
    CreateHighlightShader()
  end
end


function widget:Shutdown()
  SetupCommandColors(true)
  if shader then
    gl.DeleteShader(shader)
  end
end



--------------------------------------------------------------------------------

function widget:DrawWorld()
  if Spring.IsGUIHidden() then return end

  gl.DepthTest(true)
  gl.PolygonOffset(-0.5, -0.5)
  gl.Blending(GL.SRC_ALPHA, GL.ONE)

  local selectedUnits = Spring.GetSelectedUnits()
  if useShader and shader and #selectedUnits < maxShaderUnits then
    gl.UseShader(shader)
  end

  for _,unitID in ipairs(selectedUnits) do
    if not spIsUnitIcon(unitID) and spIsUnitInView(unitID) then
      local health,maxHealth,paralyzeDamage,captureProgress,buildProgress=Spring.GetUnitHealth(unitID)
      if maxHealth ~= nil then
        gl.Color(
        health>maxHealth/2 and 2-2*health/maxHealth or 1, -- red
        health>maxHealth/2 and 1 or 2*health/maxHealth, -- green
        0, -- blue
        highlightAlpha) -- alpha
        gl.Unit(unitID, true)
      end
    end
  end

  if useShader and shader and #selectedUnits < maxShaderUnits then
    gl.UseShader(0)
  end

  gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
  gl.PolygonOffset(false)
  gl.DepthTest(false)
end


widget.DrawWorldReflection = widget.DrawWorld

widget.DrawWorldRefraction = widget.DrawWorld



function widget:GetConfigData()
	return {highlightAlpha = highlightAlpha, userShader = useShader}
end

function widget:SetConfigData(data)
  highlightAlpha = data.highlightAlpha or highlightAlpha
  userShader = data.userShader or userShader
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
