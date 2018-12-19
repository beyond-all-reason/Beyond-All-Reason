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

function widget:GetInfo()
  return {
    name         = "Under construction gfx",
    desc         = "",
    author       = "Floris",
    date         = "May 2018",
    license      = "GPL",
    layer        = 50,
    enabled      = true
  }
end

local highlightAlpha = 0.4
local useHighlightShader = true
local maxShaderUnits = 100
local edgeExponent = 5

local spIsUnitIcon = Spring.IsUnitIcon
local spIsUnitInView = Spring.IsUnitInView
local spGetTeamColor = Spring.GetTeamColor
local spGetUnitTeam = Spring.GetUnitTeam
local myPlayerID = Spring.GetMyPlayerID()
local prevMyAllyTeamID = Spring.GetMyAllyTeamID()
local mySpec, prevMyFullView = Spring.GetSpectatingState()
local unitList = {}
local unitListCount = 0

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function CreateHighlightShader()
  if shader then
    gl.DeleteShader(shader)
  end
  if gl.CreateShader then
    shader = gl.CreateShader({

      uniform = {
        edgeExponent = edgeExponent/(0.8+highlightAlpha),
        plainAlpha = highlightAlpha*0.8,
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

          gl_FragColor.rgb = color + (opac*1.3);
          gl_FragColor.a = plainAlpha + opac;

        }
      ]],
    })
  end
end
--------------------------------------------------------------------------------

function ResetUnderConstructionUnits()
  local allUnits = Spring.GetAllUnits()
  unitList = {}
  unitListCount = 0
  for _, unitID in pairs(allUnits) do
    local health,maxHealth,paralyzeDamage,captureProgress,buildProgress=Spring.GetUnitHealth(unitID)
    if buildProgress and buildProgress < 1 then
      --local unitDefID = Spring.GetUnitDefID(unitID)
      unitList[unitID] = spGetUnitTeam(unitID)
      unitListCount = unitListCount + 1
    end
  end
end

function widget:Initialize()
  WG['underconstructiongfx'] = {}
  WG['underconstructiongfx'].getOpacity = function()
    return highlightAlpha
  end
  WG['underconstructiongfx'].setOpacity = function(value)
    highlightAlpha = value
    CreateHighlightShader()
  end
  WG['underconstructiongfx'].getShader = function()
    return useHighlightShader
  end
  WG['underconstructiongfx'].setShader = function(value)
    if value and (Spring.GetConfigInt("ForceShaders") or 1) ~= 1 then
      Spring.SetConfigInt("ForceShaders",1)
      Spring.Echo('enabled lua shaders')
    end
    useHighlightShader = value
    CreateHighlightShader()
  end

  if gl.CreateShader ~= nil then
    CreateHighlightShader()
  end

  ResetUnderConstructionUnits()
end


function widget:Shutdown()
  if shader then
    gl.DeleteShader(shader)
  end
  WG['underconstructiongfx'] = nil
end


function widget:UnitCreated(unitID, unitDefID, unitTeam)
  unitList[unitID] = unitTeam
  unitListCount = unitListCount + 1
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  if unitList[unitID] then
    unitList[unitID] = nil
    unitListCount = unitListCount - 1
  end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
  if unitList[unitID] then
    unitList[unitID] = unitTeam
  end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
  if unitList[unitID] then
    unitList[unitID] = nil
    unitListCount = unitListCount - 1
  end
end


--------------------------------------------------------------------------------

function widget:DrawWorld()
    --if Spring.IsGUIHidden() then return end

  if Spring.GetMyAllyTeamID() ~= prevMyAllyTeamID or select(2,Spring.GetSpectatingState()) ~= prevMyFullView then
    prevMyAllyTeamID = Spring.GetMyAllyTeamID()
    ResetUnderConstructionUnits()
  end

  gl.DepthTest(true)
  gl.PolygonOffset(-1, -1)
  --gl.Blending(GL.SRC_ALPHA, GL.ONE)

  if useHighlightShader and shader and unitListCount < maxShaderUnits then
    gl.UseShader(shader)
  end
  local teamID, prevTeamID, r,g,b
  for unitID,teamID in pairs(unitList) do
    if not spIsUnitIcon(unitID) and spIsUnitInView(unitID) then
      local health,maxHealth,paralyzeDamage,captureProgress,buildProgress=Spring.GetUnitHealth(unitID)
      if maxHealth ~= nil then
        if teamID ~= prevTeamID then
          r,g,b = spGetTeamColor(teamID)
        end
        prevTeamID = teamID
        gl.Color(r*0.8,g*0.8,b*0.8,highlightAlpha - (highlightAlpha*buildProgress))
        gl.Unit(unitID, true)
      end
    end
  end

  if useHighlightShader and shader and unitListCount < maxShaderUnits then
    gl.UseShader(0)
  end

  gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
  gl.PolygonOffset(false)
  gl.DepthTest(false)
end


widget.DrawWorldReflection = widget.DrawWorld

widget.DrawWorldRefraction = widget.DrawWorld



function widget:GetConfigData()
	return {highlightAlpha=highlightAlpha, useHighlightShader=useHighlightShader}
end

function widget:SetConfigData(data)
  if data.useHighlightShader ~= nil then highlightAlpha = data.highlightAlpha end
  if data.useHighlightShader ~= nil then useHighlightShader = data.useHighlightShader end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
