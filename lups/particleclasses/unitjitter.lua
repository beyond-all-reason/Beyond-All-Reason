-- $Id: UnitJitter.lua 4454 2009-04-20 11:45:38Z jk $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local UnitJitter = {}
UnitJitter.__index = UnitJitter

local warpShader, warpShader2
local tex
local timerUniform
local lastCullFace = GL.FRONT

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitJitter.GetInfo()
  return {
    name      = "UnitJitter",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 15, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = true,
    shader    = true,
    distortion= true,
    intel     = 0,
  }
end

UnitJitter.Default = {
  layer      = 15,
  worldspace = true,

  inverse    = false,
  life       = math.huge,
  unit       = -1,
  unitDefID  = 0,
  team       = -1,
  allyTeam   = -1,

  repeatEffect = false,
  dieGameFrame = math.huge
}


local noiseTexture = 'bitmaps/GPL/Lups/perlin_noise.jpg'

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local GL_BACK = GL.BACK
local GL_FRONT = GL.FRONT
local glCulling = gl.Culling
local glUnit = gl.Unit
local glUniform = gl.Uniform
local glColor = gl.Color
local glMultiTexCoord = gl.MultiTexCoord

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitJitter:BeginDrawDistortion()
  gl.UseShader(warpShader)
  gl.Uniform(timerUniform,  Spring.GetGameSeconds()*0.1 - 0.5 )
  --gl.PolygonOffset(0,-1)
  lastCullFace = GL_FRONT
  gl.Culling(GL_FRONT)

  gl.Texture(0,noiseTexture)

  gl.PushAttrib(GL.DEPTH_BUFFER_BIT)
  gl.DepthTest(true)
  gl.DepthMask(true)
end

function UnitJitter:EndDrawDistortion()
  gl.PopAttrib()
  gl.UseShader(0)
  gl.Texture(0,false)
  gl.PolygonOffset(false)
  gl.Culling(GL_BACK)
  gl.Culling(false)
end

function UnitJitter:DrawDistortion()
  if (self.inverse) then
    glMultiTexCoord(2, (thisGameFrame-self.firstGameFrame)/self.life )
  else
    glMultiTexCoord(2, 1-((thisGameFrame-self.firstGameFrame)/self.life) )
  end

  if (self.isS3o) then
    if (lastCullFace~=GL_BACK) then
      lastCullFace = GL_BACK
      glCulling(GL_BACK)
    end
  else
    if (lastCullFace~=GL_FRONT) then
      lastCullFace = GL_FRONT
      glCulling(GL_FRONT)
    end
  end

  glUnit(self.unit,true,-1)
end


function UnitJitter:BeginDraw()
  gl.UseShader(warpShader2)
  gl.Blending(GL.ONE,GL.ONE)
  lastCullFace = GL_FRONT
  gl.Culling(GL_FRONT)
  gl.Texture(0,noiseTexture)
  gl.PushAttrib(GL.DEPTH_BUFFER_BIT)
  gl.DepthTest(true)
  gl.DepthMask(true)
end

function UnitJitter:EndDraw()
  gl.PopAttrib()
  gl.UseShader(0)
  gl.Texture(0,false)
  gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
  gl.PolygonOffset(false)
  gl.Culling(GL_BACK)
  gl.Culling(false)
  gl.Color(1,1,1,1)
end

function UnitJitter:Draw()
  if (self.inverse) then
    glMultiTexCoord(2, (thisGameFrame-self.firstGameFrame)/self.life )
  else
    glMultiTexCoord(2, 1-((thisGameFrame-self.firstGameFrame)/self.life) )
  end

  if (self.isS3o) then
    if (lastCullFace~=GL_BACK) then
      lastCullFace = GL_BACK
      glCulling(GL_BACK)
    end
  else
    if (lastCullFace~=GL_FRONT) then
      lastCullFace = GL_FRONT
      glCulling(GL_FRONT)
    end
  end

  glColor(self.teamColor)
  glUnit(self.unit,true,-1)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitJitter.Initialize()
  warpShader = gl.CreateShader({
    vertex = [[
      uniform float timer;

      varying vec3 texCoord;

      const vec4 ObjectPlaneS = vec4(0.005, 0.005, 0.000,  0.0);
      const vec4 ObjectPlaneT = vec4(0.000, 0.005, 0.005,  0.0);

	void main()
	{
            gl_Position = ftransform();
            texCoord.s = dot( gl_Vertex, ObjectPlaneS ) + timer; 
            texCoord.t = dot( gl_Vertex, ObjectPlaneT ) + timer;
            texCoord.z = gl_MultiTexCoord2.x; //life
            texCoord.z *= abs( dot(normalize(gl_NormalMatrix * gl_Normal), normalize(vec3(gl_ModelViewMatrix * gl_Vertex))) );
            texCoord.z *= 0.015;
	}
    ]],
    fragment = [[
      uniform sampler2D noiseMap;

      varying vec3 texCoord;

      #define life texCoord.z

      void main(void)
      {
          vec2 noiseVec;
          noiseVec = texture2D(noiseMap, texCoord.st).rg;
          noiseVec = (noiseVec - 0.50) * life;

          gl_FragColor = vec4(noiseVec,0.0,gl_FragCoord.z);
      }
    ]],
    uniformInt = {
      noiseMap = 0,
    },
    uniformFloat = {
      timer = 0,
    }
  })

  if (warpShader == nil) then
    print(PRIO_MAJOR,"LUPS->UnitJitter: critical shader error: "..gl.GetShaderLog())
    return false
  end

  timerUniform  = gl.GetUniformLocation(warpShader, 'timer')

  warpShader2 = gl.CreateShader({
    vertex = [[
      void main()
      {
          gl_Position = ftransform();
          float opac = 1.0-abs( dot(normalize(gl_NormalMatrix * gl_Normal), normalize(vec3(gl_ModelViewMatrix * gl_Vertex))) );
          float life = gl_MultiTexCoord2.x; //life

          gl_FrontColor = mix( gl_Color * (opac+0.15),
                              vec4( opac*opac ),
                              opac * 0.5) * life * 0.75;
      }
    ]],
    fragment = [[
      void main(void)
      {
          gl_FragColor  = gl_Color;
      }
    ]],
    uniformFloat = {
      life  = 1,
    }
  })

  if (warpShader2 == nil) then
    print(PRIO_MAJOR,"LUPS->UnitJitter: critical shader2 error: "..gl.GetShaderLog())
    return false
  end
end

function UnitJitter.Finalize()
  if (gl.DeleteShader) then
    gl.DeleteShader(warpShader)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local spGetTeamColor = Spring.GetTeamColor

-- used if repeatEffect=true;
function UnitJitter:ReInitialize()
  self.dieGameFrame = self.dieGameFrame + self.life
end

function UnitJitter:CreateParticle()
  local name = (UnitDefs[self.unitDefID].model and UnitDefs[self.unitDefID].model.name) or UnitDefs[self.unitDefID].modelname
  self.isS3o = ((name:lower():find("s3o") or name:lower():find("obj") or name:lower():find("dae")) and true)
  self.teamColor = {spGetTeamColor(self.team)}
  self.firstGameFrame = thisGameFrame
  self.dieGameFrame   = self.firstGameFrame + self.life
end

function UnitJitter:Visible()
  if self.allyTeam == LocalAllyTeamID then
    return Spring.IsUnitVisible(self.unit, 0, true) -- Don't draw for icons
  end

  local inLos = true
  if (self.enemyHit) then
    local x,y,z = Spring.GetUnitPosition(self.unit)
    if (x==nil) then return false end
    inLos = select(2, Spring.GetPositionLosState(x,y,z, LocalAllyTeamID))
  else
    local losState = Spring.GetUnitLosState(self.unit, LocalAllyTeamID) or {}
    inLos = (inLos)and(not losState.los)
  end
  return (inLos)and(Spring.IsUnitVisible(self.unit, 0, true)) -- Don't draw for icons
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitJitter.Create(Options)
  SetUnitLuaDraw(Options.unit,true)

  local newObject = MergeTable(Options, UnitJitter.Default)
  setmetatable(newObject,UnitJitter)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function UnitJitter:Destroy()
  SetUnitLuaDraw(self.unit,false)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return UnitJitter