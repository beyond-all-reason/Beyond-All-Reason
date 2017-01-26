-- $Id: ShockWave.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local ShockWave = {}
ShockWave.__index = ShockWave

local warpShader
local screenLoc
local dlist

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShockWave.GetInfo()
  return {
    name      = "ShockWave",
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

ShockWave.Default = {
  layer = 1,
  worldspace = true,

  life   = 23,
  pos    = {0,0,0},
  growth = 4.5,

  repeatEffect = false,
  dieGameFrame = math.huge
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local glUniform   = gl.Uniform
local glUseShader = gl.UseShader
local glCallList  = gl.CallList
local glMultiTexCoord = gl.MultiTexCoord
local spWorldToScreenCoords = Spring.WorldToScreenCoords

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShockWave:BeginDrawDistortion()
  glUseShader(warpShader)
  --glUniform(screenLoc, 1/vsx,1/vsy )
end

function ShockWave:EndDrawDistortion()
  glUseShader(0)
end


function ShockWave:DrawDistortion()
  local pos   = self.pos
  local x,y,z = pos[1],pos[2],pos[3]
  local cx,cy = spWorldToScreenCoords(x,y,z)

  glMultiTexCoord(0,x,y,z,1)
  glMultiTexCoord(1,cx,cy,self.radius,self.life2)

  glCallList(dlist)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShockWave.Initialize()
  warpShader = gl.CreateShader({
    vertex = [[
      uniform float radius;

      varying vec2  center;
      varying float life;
      varying vec2  texCoord;

      void main()
      {
         center   = gl_MultiTexCoord1.xy;
         life     = gl_MultiTexCoord1.w;
         texCoord = gl_Vertex.st;

         gl_Position     = gl_ModelViewMatrix * gl_MultiTexCoord0;
         gl_Position.xy += gl_Vertex.xy * gl_MultiTexCoord1.z;
         gl_Position     = gl_ProjectionMatrix * gl_Position;
      }
    ]],
    fragment = [[
      uniform vec2  screenInverse;

      varying vec2  center;
      varying float life;
      varying vec2  texCoord;

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
          float dist = (length(texCoord)-0.6)*2.5;
          if (dist>1.0) {
            discard;
          }else{
            float eyeDepth = ConvertZtoEye(gl_FragCoord.z);
            eyeDepth -= cos(asin(dist))*30.0;
            gl_FragDepth = ConvertEyeToZ(eyeDepth);

            vec2 d = gl_FragCoord.xy - center;
            float distortion = exp( -0.5*( pow(-dist*8.0+4.0,2.0) ) )*0.15;
            vec2 noiseVec    = (d/dist)*screenInverse*distortion*life;
            gl_FragColor.xyw = vec3(noiseVec,gl_FragCoord.z);

            //float distortion = pow(dist, 1.0/4.0)-dist;
            //float distortion = smoothstep(1.0,0.0,dist)*0.25;
            //float distortion = tanh(dist*3.0)-dist;
            //float distortion = smoothstep(0.0,1.0,dist)-dist;
          }
      }
    ]],
    uniform = {
      screenInverse = {1/1280,1/1024},
      life = 1,
    }
  })

  if (warpShader == nil) then
    print(PRIO_MAJOR,"LUPS->ShockWave: critical shader error: "..gl.GetShaderLog())
    return false
  end

  screenLoc = gl.GetUniformLocation(warpShader, 'screenInverse')

  dlist = gl.CreateList(gl.BeginEnd,GL.QUADS,function()
    gl.Vertex(-1,1)
    gl.Vertex(1,1)
    gl.Vertex(1,-1)
    gl.Vertex(-1,-1)
  end)
end

function ShockWave.Finalize()
  if (gl.DeleteShader) then
    gl.DeleteShader(warpShader)
  end
  gl.DeleteList(dlist)
end

function ShockWave.ViewResize()
  gl.UseShader(warpShader)
    gl.Uniform(screenLoc,1/vsx,1/vsy)
  gl.UseShader(0)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShockWave:Update()
  self.life2  = self.life2 - self.life_inc
  self.radius = self.radius + self.growth
end

-- used if repeatEffect=true;
function ShockWave:ReInitialize()
  self.life2  = 1
  self.radius = 0
  self.startGameFrame = thisGameFrame
  self.dieGameFrame = self.startGameFrame + self.life
end

function ShockWave:CreateParticle()
  self.startGameFrame = thisGameFrame
  self.dieGameFrame   = self.startGameFrame + self.life

  self.life2 = 1
  self.life_inc = 1/(self.dieGameFrame - self.startGameFrame)
  self.radius = 0
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShockWave.Create(Options)
  local newObject = MergeTable(Options, ShockWave.Default)
  setmetatable(newObject,ShockWave)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function ShockWave:Destroy()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return ShockWave