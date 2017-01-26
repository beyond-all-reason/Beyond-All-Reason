-- $Id: JitterParticles2.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local JitterParticles2 = {}
JitterParticles2.__index = JitterParticles2

local billShader
local colormapUniform = {}

local lastTexture = ""

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function JitterParticles2.GetInfo()
  return {
    name      = "JitterParticles2",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "This is a simialr class to JitterParticles, just that it is 100% implemented with shaders, todo so it miss the Airdrag tags and added new Exp tags.",

    layer     = 0, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = false,
    shader    = true,
    distortion= true,
    rtt       = false,
    ctt       = false,
  }
end

JitterParticles2.Default = {
  emitVector     = {0,1,0},
  pos            = {0,0,0}, --// start pos
  partpos        = "0,0,0", --// particle relative start pos (can contain lua code!)
  layer          = 0,

  --// visibility check
  los            = true,
  airLos         = true,
  radar          = false,

  count          = 1,

  life           = 0,
  lifeSpread     = 0,
  delaySpread    = 0,

  emitVector     = {0,1,0},
  emitRot        = 0,
  emitRotSpread  = 0,

  force          = {0,0,0}, --// global effect force
  forceExp       = 1,

  speed          = 0,
  speedSpread    = 0,
  speedExp       = 1, --// >1 : first decrease slow, then fast;  <1 : decrease fast, then slow

  size           = 0,
  sizeSpread     = 0,
  sizeGrowth     = 0,
  sizeExp        = 1, --// >1 : first decrease slow, then fast;  <1 : decrease fast, then slow;  <0 : invert x-axis (start large become smaller)

  texture        = 'bitmaps/GPL/Lups/mynoise.png',

  strength       = 1, --// distortion strength
  scale          = 1, --// scales the distortion texture
  animSpeed      = 1, --// speed of the distortion
  heat           = 0, --// brighten distorted regions by "length(distortionVec)*heat"

  repeatEffect   = false, --can be a number,too
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

--// speed ups

local abs   = math.abs
local sqrt  = math.sqrt
local rand  = math.random
local twopi = 2 * math.pi
local cos   = math.cos
local sin   = math.sin
local min   = math.min
local floor = math.floor
local degreeToPI = math.pi/180

local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetPositionLosState = Spring.GetPositionLosState
local spGetUnitLosState     = Spring.GetUnitLosState
local spIsSphereInView      = Spring.IsSphereInView
local spGetUnitRadius       = Spring.GetUnitRadius
local spGetProjectilePosition = Spring.GetProjectilePosition

local IsPosInLos    = Spring.IsPosInLos
local IsPosInAirLos = Spring.IsPosInAirLos
local IsPosInRadar  = Spring.IsPosInRadar

local glTexture     = gl.Texture 
local glBlending    = gl.Blending
local glUniform     = gl.Uniform
local glUniformInt  = gl.UniformInt
local glPushMatrix  = gl.PushMatrix
local glPopMatrix   = gl.PopMatrix
local glTranslate   = gl.Translate
local glCreateList  = gl.CreateList
local glCallList    = gl.CallList
local glRotate      = gl.Rotate
local glColor       = gl.Color
local glUseShader   = gl.UseShader

local GL_QUADS               = GL.QUADS
local GL_ONE                 = GL.ONE
local GL_SRC_ALPHA           = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local glBeginEnd     = gl.BeginEnd
local glMultiTexCoord= gl.MultiTexCoord
local glVertex       = gl.Vertex

local ProcessParamCode = ProcessParamCode
local ParseParamString = ParseParamString
local Vmul    = Vmul
local Vlength = Vlength

local nullVector = {0,0,0}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function JitterParticles2:CreateParticleAttributes(up, right, forward, partpos,n)
  local life, delay, pos, speed, sizeStart,sizeEnd, rotStart,rotEnd;

  local az = rand()*twopi;
  local ay = (self.emitRot + rand() * self.emitRotSpread) * degreeToPI;

  local a,b,c = cos(ay),  cos(az)*sin(ay),  sin(az)*sin(ay)

  speed = {
    up[1]*a - right[1]*b + forward[1]*c,
    up[2]*a - right[2]*b + forward[2]*c,
    up[3]*a - right[3]*b + forward[3]*c}

  life      = self.life + rand() * self.lifeSpread
  speed     = Vmul( speed,( self.speed + rand() * self.speedSpread) * life)
  delay     = rand() * self.delaySpread

  sizeStart = self.size + rand() * self.sizeSpread
  sizeEnd   = sizeStart + self.sizeGrowth * life

  if (partpos) then
    local part = { speed=speed, velocity=Vlength(speed), life=life, delay=delay, i=n }
    pos = { ProcessParamCode(partpos, part) }
  else
    pos = nullVector
  end

  return life, delay,
         pos[1],pos[2],pos[3],
         speed[1],speed[2],speed[3],
         sizeStart,sizeEnd;
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
local time

function JitterParticles2.BeginDrawDistortion()
  glUseShader(billShader)
  time = Spring.GetGameFrame()*0.01
end

function JitterParticles2.EndDrawDistortion()
  glTexture(0,false)
  glUseShader(0)

  lastTexture=""
end

function JitterParticles2:DrawDistortion()
  if (lastTexture~=self.texture) then
    glTexture(0,self.texture)
    lastTexture=self.texture
  end

  glMultiTexCoord(5, self.frame/200, time*self.animSpeed)
  glCallList(self.dlist)
end


local function DrawParticleForDList(life,delay, x,y,z, dx,dy,dz, sizeStart,sizeEnd)
  local animDirX = floor((rand() - 0.5) * 2)
  local animDirY = floor((rand() - 0.5) * 2)

  glMultiTexCoord(0, x,y,z, life/200)
  glMultiTexCoord(1, dx,dy,dz, delay/200)
  glMultiTexCoord(2, sizeStart, sizeEnd, animDirX,animDirY )

  glVertex(0,0)
  glVertex(1,0)
  glVertex(1,1)
  glVertex(0,1)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function JitterParticles2:Initialize()
  billShader = gl.CreateShader({
    vertex = [[
      // global attributes
      #define frame         gl_MultiTexCoord5.x
      #define time          gl_MultiTexCoord5.y
      #define forceExp      gl_MultiTexCoord4.w
      #define force        (gl_MultiTexCoord4.xyz)
      #define distStrength  gl_MultiTexCoord6.x
      #define distScale     gl_MultiTexCoord6.y
      #define distHeat      gl_MultiTexCoord6.z
      #define animDir      (gl_MultiTexCoord2.zw) 

      // particle attributes
      #define posV        (gl_MultiTexCoord0.xyz)
      #define dirV        (gl_MultiTexCoord1.xyz)
      #define maxLife      gl_MultiTexCoord0.w
      #define delay        gl_MultiTexCoord1.w

      #define sizeStart       gl_MultiTexCoord2.x
      #define sizeEnd         gl_MultiTexCoord2.y
      // equation is: 1-(1-life)^exp
      #define attributesExp  (gl_MultiTexCoord3.xy) 

      const float halfpi = 0.159;


      varying float strength;
      varying float heat;
      varying vec4  texCoords;

      void main()
      {
         float lframe = frame - delay;
         float life   = lframe / maxLife; // 0.0 .. 1.0 range!

         if (life<=0.0 || life>1.0) {
           // move dead particles offscreen, this way we don't dump the fragment shader with it
           gl_Position = vec4(-2000.0,-2000.0,-2000.0,-2000.0);
         }else{
           // calc particle attributes
           vec2 attrib = vec2(1.0) - pow(vec2(1.0 - life), abs(attributesExp));
         //if (attributesExp.x<0.0) attrib.x = 1.0 - attrib.x; // speed (no need for backward movement)
           if (attributesExp.y<0.0) attrib.y = 1.0 - attrib.y; // size
           attrib.y   = sizeStart + attrib.y * sizeEnd; 

           // calc vertex position
           vec3 forceV     = (1.0 - pow(1.0 - life, abs(forceExp))) * force;
           vec4 pos4       = vec4(posV + attrib.x * dirV + forceV, 1.0);
           gl_Position     = gl_ModelViewMatrix * pos4;

           // offset vertex from center of the polygon
           gl_Position.xy += (gl_Vertex.xy - 0.5) * attrib.y;

           // final position
           gl_Position     = gl_ProjectionMatrix * gl_Position;

           // calc some stuff used by the fragment shader
           texCoords.st  = (gl_Vertex.st + animDir * time) * distScale;
           strength      = (1.0 - life) * distStrength;
           heat          = distHeat;
           texCoords.pq  = (gl_Vertex.xy - 0.5) * 2.0;
         }
       }
    ]],
    fragment = [[
      uniform sampler2D noiseMap;

      varying float strength;
      varying float heat;
      varying vec4  texCoords;

      void main()
      {
         vec2 noiseVec;
         vec4 noise = texture2D(noiseMap, texCoords.st);
         noiseVec = (noise.xy - 0.50) * strength;

         noiseVec *= smoothstep(1.0, 0.0, dot(texCoords.pq,texCoords.pq) ); // smooth dot (FIXME: use a mask texture instead?)

         gl_FragColor = vec4(noiseVec,length(noiseVec)*heat,gl_FragCoord.z);
      }
    ]],
    uniformInt = {
      noiseMap = 0,
    },
  })

  if (billShader==nil) then
    print(PRIO_MAJOR,"LUPS->JitterParticles2: Critical Shader Error: " ..gl.GetShaderLog())
    return false
  end
end

function JitterParticles2:Finalize()
  gl.DeleteShader(billShader)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function JitterParticles2:Update(n)
  self.frame  = self.frame + n
end

-- used if repeatEffect=true;
function JitterParticles2:ReInitialize()
  self.frame = 0
  self.dieGameFrame = self.dieGameFrame + self.life + self.lifeSpread + self.delaySpread
end

local function InitializeParticles(self)
  -- calc base of the emitvector system
  local up      = self.emitVector;
  local right   = Vcross( up, {up[2],up[3],-up[1]} );
  local forward = Vcross( up, right );

  local partposCode
  if (self.partpos ~= "0,0,0") then
    partposCode = ParseParamString(self.partpos)
  end

  self.force = Vmul(self.force,self.life + self.lifeSpread)

  local ev         = self.emitVector
  local emitMatrix = CreateEmitMatrix3x3(ev[1],ev[2],ev[3])

  --// global data
  glMultiTexCoord(3, self.speedExp, self.sizeExp)
  glMultiTexCoord(4, self.force[1], self.force[2], self.force[3], self.forceExp)
  glMultiTexCoord(6, self.strength * 0.01, self.scale, self.heat/self.strength)

  self.maxSpawnRadius = 0
  for i=1,self.count do
    local life,delay, x,y,z, dx,dy,dz, sizeStart,sizeEnd = self:CreateParticleAttributes(up,right,forward, partposCode, i-1)
    dx,dy,dz = MultMatrix3x3(emitMatrix,dx,dy,dz)
    DrawParticleForDList(life, delay,
                         x,y,z,    -- relative start pos
                         dx,dy,dz, -- speed vector
                         sizeStart,sizeEnd)
    local spawnDist = x*x + y*y + z*z
    if (spawnDist>self.maxSpawnRadius) then self.maxSpawnRadius=spawnDist end
  end
  self.maxSpawnRadius = sqrt(self.maxSpawnRadius)

  glMultiTexCoord(2, 0,0,0,1)
  glMultiTexCoord(3, 0,0,0,1)
  glMultiTexCoord(4, 0,0,0,1)
  glMultiTexCoord(5, 0,0,0,1)
  glMultiTexCoord(6, 0,0,0,1)
end

local function CreateDList(self)
  glPushMatrix()
    glTranslate(self.pos[1],self.pos[2],self.pos[3])
    glBeginEnd(GL_QUADS,InitializeParticles,self)
  glPopMatrix()
end

function JitterParticles2:CreateParticle()
  self.dlist = glCreateList(CreateDList,self)

  self.frame = 0
  self.firstGameFrame = thisGameFrame
  self.dieGameFrame   = self.firstGameFrame + self.life + self.lifeSpread + self.delaySpread

  --// visibility check vars
  self.radius        = self.size + self.sizeSpread + self.maxSpawnRadius + 100
  self.maxSpeed      = self.speed + abs(self.speedSpread)
  self.forceStrength = Vlength(self.force)
  self.sphereGrowth  = self.forceStrength + self.sizeGrowth + self.maxSpeed
end

function JitterParticles2:Destroy()
  gl.DeleteList(self.dlist)
  --gl.DeleteTexture(self.texture)
end

function JitterParticles2:Visible()
  local radius = self.radius +
                 self.frame*self.sphereGrowth --FIXME: frame is only updated on Update()
  local posX,posY,posZ = self.pos[1],self.pos[2],self.pos[3]
  local losState
  if (self.unit and not self.worldspace) then
    local ux,uy,uz = spGetUnitViewPosition(self.unit)
    posX,posY,posZ = posX+ux,posY+uy,posZ+uz
    radius = radius + spGetUnitRadius(self.unit)
    losState = GetUnitLosState(self.unit)
  elseif (self.projectile and not self.worldspace) then
    local px,py,pz = spGetProjectilePosition(self.projectile)
    posX,posY,posZ = posX+px,posY+py,posZ+pz
  end
  if (losState==nil) then
    if (self.radar) then
      losState = IsPosInRadar(posX,posY,posZ)
    end
    if ((not losState) and self.airLos) then
      losState = IsPosInAirLos(posX,posY,posZ)
    end
    if ((not losState) and self.los) then
      losState = IsPosInLos(posX,posY,posZ)
    end
  end
  return (losState)and(spIsSphereInView(posX,posY,posZ,radius))
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local MergeTable   = MergeTable
local setmetatable = setmetatable

function JitterParticles2.Create(Options)
  local newObject = MergeTable(Options, JitterParticles2.Default)
  setmetatable(newObject,JitterParticles2)  --// make handle lookup
  newObject:CreateParticle()
  return newObject
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return JitterParticles2