-- $Id: Jet.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local Jet = {}
Jet.__index = Jet

local jitShader
local tex --//screencopy
local timerUniform
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function Jet.GetInfo()
  return {
    name      = "Jet",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 4, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = true,
    shader    = true,
    distortion= true,
    ms        = -1,
    intel     = -1,
  }
end


Jet.Default = {
  layer = 4,
  life  = math.huge,
  repeatEffect  = true,

  emitVector    = {0,0,-1},
  pos           = {0,0,0}, --// not used
  width         = 4,
  length        = 50,
  distortion    = 0.02,
  animSpeed     = 1,

  texture1      = "bitmaps/GPL/Lups/perlin_noise.jpg", --// noise texture
  texture2      = ":c:bitmaps/GPL/Lups/jet.bmp",       --// jitter shape
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local spGetGameSeconds = Spring.GetGameSeconds
local glUseShader = gl.UseShader
local glUniform   = gl.Uniform
local glTexture   = gl.Texture
local glCallList  = gl.CallList

function Jet:BeginDrawDistortion()
  glUseShader(jitShader)
    glUniform(timerUniform, spGetGameSeconds())
end

function Jet:EndDrawDistortion()
  glUseShader(0)
  glTexture(1,false)
  glTexture(2,false)
end

function Jet:DrawDistortion()
  glTexture(1,self.texture1) 
  glTexture(2,self.texture2) 

  glCallList(self.dList)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

-- used if repeatEffect=true;
function Jet:ReInitialize()
  self.dieGameFrame = self.dieGameFrame + self.life
end

function Jet.Initialize()
  jitShader = gl.CreateShader({
    vertex = [[
      uniform float timer;

      varying float distortion;
      varying vec4 texCoords;

      const vec4 centerPos = vec4(0.0,0.0,0.0,1.0);

      // gl_vertex.xy := width/length
      // gl_vertex.zw := texcoord
      // gl_MultiTexCoord0.x  := (quad_width) / (quad_length) (used to normalize the texcoord dimensions)
      // gl_MultiTexCoord0.y  := distortion strength
      // gl_MultiTexCoord0.z  := animation speed
      // gl_MultiTexCoord1    := emit vector

      void main()
      {
        texCoords.st  = gl_Vertex.pq;
        texCoords.pq  = gl_Vertex.pq;
        texCoords.p  *= gl_MultiTexCoord0.x;
        texCoords.pq += timer*gl_MultiTexCoord0.z;

        gl_Position = gl_ModelViewMatrix * centerPos;
        vec3 dir3   = vec3(gl_ModelViewMatrix * gl_MultiTexCoord1) - gl_Position.xyz;
        vec3 v = normalize( dir3 );
        vec3 w = normalize( -vec3(gl_Position) );
        vec3 u = normalize( cross(w,v) );
        gl_Position.xyz += gl_Vertex.x*v + gl_Vertex.y*u;
        gl_Position      = gl_ProjectionMatrix * gl_Position;

        distortion = gl_MultiTexCoord0.y;
      }
    ]],
    fragment = [[
      uniform sampler2D noiseMap;
      uniform sampler2D mask;

      varying float distortion;
      varying vec4 texCoords;

      void main(void)
      {
          float opac    = texture2D(mask,texCoords.st).r;
          vec2 noiseVec = (texture2D(noiseMap, texCoords.pq).st - 0.5) * distortion * opac;
          gl_FragColor  = vec4(noiseVec.xy,0.0,gl_FragCoord.z);
      }

    ]],
    uniformInt = {
      noiseMap = 1,
      mask = 2,
    },
    uniform = {
      timer = 0,
    }
  })


  if (jitShader == nil) then
    print(PRIO_MAJOR,"LUPS->Jet: shader error: "..gl.GetShaderLog())
    return false
  end

  timerUniform = gl.GetUniformLocation(jitShader, 'timer')
end

function Jet:Finalize()
  if (gl.DeleteShader) then
    gl.DeleteShader(jitShader)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local glMultiTexCoord = gl.MultiTexCoord
local glVertex        = gl.Vertex
local glCreateList    = gl.CreateList
local glDeleteList    = gl.DeleteList
local glBeginEnd      = gl.BeginEnd
local GL_QUADS        = GL.QUADS

local function BeginEndDrawList(self)
  local ev    = self.emitVector 
  glMultiTexCoord(0,self.width/self.length,self.distortion,0.2*self.animSpeed)
  glMultiTexCoord(1,ev[1],ev[2],ev[3],1)

  --// xy = width/length ; zw = texcoord
  local w = self.width
  local l = self.length
  glVertex(-l,-w, 1,0)
  glVertex(0, -w, 1,1)
  glVertex(0,  w, 0,1)
  glVertex(-l, w, 0,0)
end


function Jet:CreateParticle()
  self.dList = glCreateList(glBeginEnd,GL_QUADS,
                            BeginEndDrawList,self)

  --// used for visibility check
  self.radius = self.length

  self.dieGameFrame  = thisGameFrame + self.life
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local MergeTable   = MergeTable
local setmetatable = setmetatable

function Jet.Create(Options)
  local newObject = MergeTable(Options, Jet.Default)
  setmetatable(newObject,Jet)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function Jet:Destroy()
  --gl.DeleteTexture(self.texture1)
  --gl.DeleteTexture(self.texture2)
  glDeleteList(self.dList)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return Jet