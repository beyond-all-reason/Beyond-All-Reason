-- $Id: JitterParticles.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local JitterParticles = {}
JitterParticles.__index = JitterParticles

local billShader,sizeUniform,frameUniform,timeUniform,movCoeffUniform

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function JitterParticles.GetInfo()
  return {
    name      = "JitterParticles",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 0, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = false,
    shader    = true,
    distortion= true,
    rtt       = false,
    ctt       = false,
  }
end

JitterParticles.Default = {
  dlist       = 0,

  emitVector  = {0,1,0},
  pos         = {0,0,0}, --// start pos of the effect
  partpos     = "0,0,0", --// particle relative start pos (can contain lua code!)
  layer       = 0,

  force       = {0,0,0}, --// global effect force
  airdrag     = 1,
  speed       = 0,
  speedSpread = 0,
  life        = 0,
  lifeSpread  = 0,
  emitRot     = 0,
  emitRotSpread = 0,
  size        = 0,
  sizeSpread  = 0,
  sizeGrowth  = 0,
  texture     = 'bitmaps/GPL/Lups/mynoise.png',
  count       = 1,
  jitterStrength = 1,
  repeatEffect = false, --can be a number,too
  genmipmap    = true,  --FIXME
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

--// speed ups

local abs  = math.abs
local sqrt = math.sqrt
local rand = math.random
local twopi= 2*math.pi
local cos  = math.cos
local sin  = math.sin
local min  = math.min
local degreeToPI = math.pi/180

local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spGetPositionLosState = Spring.GetPositionLosState
local spGetUnitLosState     = Spring.GetUnitLosState
local spIsSphereInView      = Spring.IsSphereInView
local spGetUnitRadius       = Spring.GetUnitRadius
local spGetProjectilePosition = Spring.GetProjectilePosition

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

local GL_QUADS = GL.QUADS

local glBeginEnd     = gl.BeginEnd
local glMultiTexCoord= gl.MultiTexCoord
local glVertex       = gl.Vertex

local ProcessParamCode = ProcessParamCode
local ParseParamString = ParseParamString
local Vmul    = Vmul
local Vlength = Vlength

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function JitterParticles:CreateParticleAttributes(up, right, forward,partpos,n)
  local life, pos, speed, size;

  local az = rand()*twopi;
  local ay = (self.emitRot + rand() * self.emitRotSpread) * degreeToPI;

  local a,b,c = cos(ay),  cos(az)*sin(ay),  sin(az)*sin(ay)

  speed = {
    up[1]*a - right[1]*b + forward[1]*c,
    up[2]*a - right[2]*b + forward[2]*c,
    up[3]*a - right[3]*b + forward[3]*c}

  speed  = Vmul( speed, self.speed + rand() * self.speedSpread )
  size   = self.size + rand()*self.sizeSpread
  life   = self.life + rand()*self.lifeSpread

  local part = {speed=Vlength(speed),size=size,life=life,i=n}
  pos = { ProcessParamCode(partpos, part) }

  return life, size,
         pos[1],pos[2],pos[3],
         speed[1],speed[2],speed[3];
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function JitterParticles:BeginDrawDistortion()
  glUseShader(billShader)
  glUniform(timeUniform, Spring.GetGameFrame()*0.01)
end

function JitterParticles:EndDrawDistortion()
  glTexture(false)
  glUseShader(0)
end

function JitterParticles:DrawDistortion()
  glTexture(self.texture)

  glUniform(sizeUniform, self.usize)
  glUniform(frameUniform, self.frame)
  glUniform(movCoeffUniform, self.uMovCoeff)

  local pos   = self.pos
  local force = self.uforce
  local emit  = self.emitVector

  glPushMatrix()
    glTranslate(pos[1],pos[2],pos[3])
    glTranslate(force[1],force[2],force[3])
    glRotate(90,emit[1],emit[2],emit[3])
      glCallList(self.dlist)
  glPopMatrix()
end


local function DrawParticleForDList(size,life,jitterStrength,x,y,z,dx,dy,dz)
  glMultiTexCoord(0,x,y,z,life)
  glMultiTexCoord(1,dx,dy,dz)
  glVertex(0,0,size,jitterStrength)
  glVertex(1,0,size,jitterStrength)
  glVertex(1,1,size,jitterStrength)
  glVertex(0,1,size,jitterStrength)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function JitterParticles:Initialize()
  billShader = gl.CreateShader({
    vertex = [[
      uniform float size;
      uniform float frame;
      uniform float time;
      uniform float movCoeff;

      varying float distStrength;
      varying vec4 texCoords;

      void main()
      {
         //gl.MultiTexCoord(0,x,y,z,life)
         //gl.MultiTexCoord(1,dx,dy,dz)
         //gl.Vertex(s,t,size)

         float psize = size+gl_Vertex.z;
         float life  = frame / gl_MultiTexCoord0.w;
         if (life>1.0 || psize<=0.0) {
           // paste dead particles offscreen, this way we don't dump the fragment shader with it
           gl_Position = vec4(-2000.0,-2000.0,-2000.0,-2000.0);
         }else{
           // calc vertex position
           vec4 pos          = vec4( gl_MultiTexCoord0.xyz + movCoeff * gl_MultiTexCoord1.xyz ,1.0);
           gl_Position       = gl_ModelViewMatrix * pos;
           gl_Position.xy   += (gl_Vertex.xy-0.5) * psize;
           gl_Position       = gl_ProjectionMatrix * gl_Position;
           texCoords.st  = gl_Vertex.yz*gl_Vertex.zx*0.2+time;
           texCoords.t  += life+gl_Vertex.z;
           texCoords.st *= vec2(0.1);
           distStrength  = (1.0 - life) * 0.075 * gl_Vertex.w;
           texCoords.pq  = (gl_Vertex.xy - 0.5) * 2.0;
         }
      }
    ]],
    fragment = [[
      uniform sampler2D noiseMap;

      varying float distStrength;
      varying vec4 texCoords;

      void main()
      {
         vec2 noiseVec;
         vec4 noise = texture2D(noiseMap, texCoords.st);
         noiseVec = (noise.xy - 0.50) * distStrength;

         //if (texCoords.z<0.625) {
         //  noiseVec *= texCoords.z * 1.6;
         //}

         noiseVec *= smoothstep(1.0, 0.0, dot(texCoords.pq,texCoords.pq) );

         gl_FragColor = vec4(noiseVec,0.0,gl_FragCoord.z);
      }
    ]],
    uniformInt = {
      noiseMap = 0,
	},
	uniform = {
      size  = 0,
      frame = 0,
      movCoeff = 0,
    },
  })

  if (billShader==nil) then
    print(PRIO_MAJOR,"LUPS->JitterParticles: Critical Shader Error: " ..gl.GetShaderLog())
    return false
  end

  sizeUniform     = gl.GetUniformLocation(billShader,"size")
  frameUniform    = gl.GetUniformLocation(billShader,"frame")
  timeUniform     = gl.GetUniformLocation(billShader,"time")
  movCoeffUniform = gl.GetUniformLocation(billShader,"movCoeff")
end

function JitterParticles:Finalize()
  gl.DeleteShader(billShader)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function JitterParticles:Update(n)
  self.frame  = self.frame + n

  if (n==1) then --// in the case of 1 frame we can use much faster equations
    self.uMovCoeff = self.airdrag^self.frame + self.uMovCoeff;
  else
    local rotBoost = 0
    for i=1,n do 
      self.uMovCoeff = self.airdrag^(self.frame+i) + self.uMovCoeff;
    end
  end

  self.usize  = self.usize + n*self.sizeGrowth
  local force,frame = self.force,self.frame
  self.uforce[1],self.uforce[2],self.uforce[3] = force[1]*frame,force[2]*frame,force[3]*frame
end

-- used if repeatEffect=true;
function JitterParticles:ReInitialize()
  self.frame = 0
  self.usize = 0
  self.uMovCoeff = 1
  self.dieGameFrame = self.dieGameFrame + self.life + self.lifeSpread
  self.uforce[1],self.uforce[2],self.uforce[3] = 0,0,0
end

local function InitializeParticles(self)
  -- calc base of the emitvector system
  local up      = self.emitVector;
  local right   = Vcross( up, {up[2],up[3],-up[1]} );
  local forward = Vcross( up, right );

  local partposCode = ParseParamString(self.partpos)

  self.maxSpawnRadius = 0
  for i=1,self.count do
    local life,size,x,y,z,dx,dy,dz = self:CreateParticleAttributes(up,right,forward, partposCode,i-1)
    glBeginEnd(GL_QUADS,DrawParticleForDList,
                 size,life, self.jitterStrength,
                 x,y,z,    -- relative start pos
                 dx,dy,dz) -- speed vector
    local spawnDist = x*x + y*y + z*z
    if (spawnDist>self.maxSpawnRadius) then self.maxSpawnRadius=spawnDist end
  end
  self.maxSpawnRadius = sqrt(self.maxSpawnRadius)
end

function JitterParticles:CreateParticle()
  self.dlist = glCreateList(InitializeParticles,self)

  self.frame = 0
  self.firstGameFrame = thisGameFrame
  self.dieGameFrame   = self.firstGameFrame + self.life + self.lifeSpread

  self.usize = 0
  self.uMovCoeff = 1
  self.uforce = {0,0,0}

  --// visibility check vars
  self.radius        = self.size + self.sizeSpread + self.maxSpawnRadius + 100
  self.maxSpeed      = self.speed+ abs(self.speedSpread)
  self.forceStrength = Vlength(self.force)
  self.sphereGrowth  = self.forceStrength+self.sizeGrowth
end

function JitterParticles:Destroy()
  gl.DeleteList(self.dlist)
  --gl.DeleteTexture(self.texture)
end

function JitterParticles:Visible()
  local radius = self.radius +
                 self.uMovCoeff*self.maxSpeed +
                 self.frame*(self.sphereGrowth) --FIXME: frame is only updated on Update()
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

function JitterParticles.Create(Options)
  local newObject = MergeTable(Options, JitterParticles.Default)
  setmetatable(newObject,JitterParticles)  --// make handle lookup
  newObject:CreateParticle()
  return newObject
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return JitterParticles