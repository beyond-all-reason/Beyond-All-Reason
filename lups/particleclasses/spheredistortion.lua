-- $Id: SphereDistortion.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local SphereDistortion = {}
SphereDistortion.__index = SphereDistortion

local warpShader
local screenLoc, radiusLoc, strengthLoc, centerLoc

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SphereDistortion.GetInfo()
  return {
    name      = "SphereDistortion",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 1, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = true,
    shader    = true,
    distortion= true,
    intel     = 0,
  }
end

SphereDistortion.Default = {
  layer = 1,
  worldspace = true,

  life     = 25,
  pos      = {0,0,0},
  growth   = 2.5,
  strength = 0.15,

  repeatEffect = false,
  dieGameFrame = math.huge
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local glUniform   = gl.Uniform
local glUseShader = gl.UseShader
local spWorldToScreenCoords = Spring.WorldToScreenCoords

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SphereDistortion:BeginDrawDistortion()
  glUseShader(warpShader)
  glUniform(screenLoc, 1/vsx,1/vsy )
end

function SphereDistortion:EndDrawDistortion()
  glUseShader(0)
end


function SphereDistortion:DrawDistortion()
  local pos   = self.pos
  local x,y,z = pos[1],pos[2],pos[3]
  local cx,cy = spWorldToScreenCoords(x,y,z)
  glUniform(radiusLoc,   self.radius )
  glUniform(strengthLoc, self.strength )
  glUniform(centerLoc,   cx,cy )

  gl.BeginEnd(GL.QUADS,function()
     gl.TexCoord(-1,1)
    gl.Vertex(x,y,z)
     gl.TexCoord(1,1)
    gl.Vertex(x,y,z)
     gl.TexCoord(1,-1)
    gl.Vertex(x,y,z)
     gl.TexCoord(-1,-1)
    gl.Vertex(x,y,z)
  end)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SphereDistortion.Initialize()
  warpShader = gl.CreateShader({
    vertex = [[
      uniform vec2  center;
      uniform float radius;
      uniform vec2  screenInverse;

      varying vec2 texCoord;

      void main()
      {
         gl_Position     = gl_ModelViewMatrix * gl_Vertex;
         gl_Position.xy += gl_MultiTexCoord0.xy * radius;
         gl_Position     = gl_ProjectionMatrix * gl_Position;
         texCoord        = gl_MultiTexCoord0.st;
      }
    ]],
    fragment = [[
      uniform vec2  center;
      uniform float strength;
      uniform vec2  screenInverse;

      varying vec2 texCoord;

      float p1 = gl_ProjectionMatrix[2][2];
      float p2 = gl_ProjectionMatrix[2][3];

      float ConvertZtoEye(float z)
      {
          return p2/(z*2.0-1.0+p1);
      }

      float ConvertEyeToZ(float d)
      {
          return 0.5-0.5*p1+(1.0/(2.0*d))*p2;
      }

      void main(void)
      {
          float dist = length(texCoord);
          if (dist>1.0) {
            discard;
          }else{
            float eyeDepth = ConvertZtoEye(gl_FragCoord.z);
            eyeDepth -= cos(asin(dist))*30.0;
            gl_FragDepth = ConvertEyeToZ(eyeDepth);

            vec2 d = gl_FragCoord.xy - center;
            float distortion = smoothstep(1.0,0.0,dist)*strength;
            vec2 noiseVec    = (d/dist)*screenInverse*distortion;
            gl_FragColor.xyw = vec3(noiseVec,gl_FragCoord.z);

            //float distortion = pow(dist, 1.0/4.0)-dist;
            //float distortion = exp( -0.5*( pow(-dist*6.0+2.5,2.0) ) )*0.25;
            //float distortion = tanh(dist*3.0)-dist;
            //float distortion = smoothstep(0.0,1.0,dist)-dist;
          }
      }
    ]],
    uniform = {
      screenInverse = {1/1280,1/1024},
      strength = 0.15,
    }
  })

  if (warpShader == nil) then
    print(PRIO_MAJOR,"LUPS->SphereDistortion: critical shader error: "..gl.GetShaderLog())
    return false
  end

  screenLoc   = gl.GetUniformLocation(warpShader, 'screenInverse')
  strengthLoc = gl.GetUniformLocation(warpShader, 'strength')
  radiusLoc   = gl.GetUniformLocation(warpShader, 'radius')
  centerLoc   = gl.GetUniformLocation(warpShader, 'center')
end

function SphereDistortion.Finalize()
  if (gl.DeleteShader) then
    gl.DeleteShader(warpShader)
  end
end

function SphereDistortion.ViewResize()
  gl.UseShader(warpShader)
    gl.Uniform(screenLoc,1/vsx,1/vsy)
  gl.UseShader(0)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SphereDistortion:Update()
  self.radius = self.radius + self.growth
end

-- used if repeatEffect=true;
function SphereDistortion:ReInitialize()
  self.radius = 0

  self.dieGameFrame = self.dieGameFrame + self.life
end

function SphereDistortion:CreateParticle()
  self.radius = 0

  self.startGameFrame = thisGameFrame
  self.dieGameFrame   = self.startGameFrame + self.life
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local MergeTable   = MergeTable
local setmetatable = setmetatable

function SphereDistortion.Create(Options)
  local newObject = MergeTable(Options, SphereDistortion.Default)
  setmetatable(newObject,SphereDistortion)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function SphereDistortion:Destroy()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return SphereDistortion