-- $Id: SimpleParticles.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local SimpleParticles = {}
SimpleParticles.__index = SimpleParticles

local billShader,sizeUniform,frameUniform,rotUniform,movCoeffUniform
local colormapUniform,colorsUniform = {},0

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SimpleParticles.GetInfo()
  return {
    name      = "SimpleParticles",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 0, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = false,
    shader    = true,
    rtt       = false,
    ctt       = false,
  }
end

SimpleParticles.Default = {
  dlist       = 0,

  emitVector  = {0,1,0},
  pos         = {0,0,0}, --// start pos
  partpos     = "0,0,0", --// particle relative start pos (can contain lua code!)
  layer       = 0,

  --// visibility check
  los         = true,
  airLos      = true,
  radar       = false,

  force       = {0,0,0}, --// global effect force
  airdrag     = 1,
  speed       = 0,
  speedSpread = 0,
  life        = 0,
  lifeSpread  = 0,
  rotSpeed    = 0,
  rotFactor       = 0, --// we can't have a rotSpeedSpread cos of hardware limitation (you can't compute the airdrag in a shader), instead
  rotFactorSpread = 0, --// rotFactor+rotFactorSpread simulate it:   vertex_pos = vertex * rot_matrix(alpha*rotFactor+rand()*rotFactorSpread)
  rotSpread   = 0, --// this is >not< a rotSpeedSpread! it is an offset of the 0 angle, so not all particles start as upangles
  rotairdrag  = 1,
  rot2Speed   = 0, --// global effect rotation
  rot2airdrag = 1, --// global effect rotation airdrag
  emitRot     = 0,
  emitRotSpread = 0,
  size        = 0,
  sizeSpread  = 0,
  sizeGrowth  = 0,
  colormap    = { {0, 0, 0, 0} }, --//max 12 entries
  srcBlend    = GL.ONE,
  dstBlend    = GL.ONE_MINUS_SRC_ALPHA,
  alphaTest   = 0, --FIXME
  texture     = '',
  count       = 1,
  repeatEffect = false, --can be a number,too
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
local GL_SRC_ALPHA           = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local glBeginEnd     = gl.BeginEnd
local glMultiTexCoord= gl.MultiTexCoord
local glVertex       = gl.Vertex

local ProcessParamCode = ProcessParamCode
local ParseParamString = ParseParamString
local Vmul    = Vmul
local Vlength = Vlength

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SimpleParticles:CreateParticleAttributes(up, right, forward,partpos,n)
  local life, pos, speed, size, rot, rotFactor;

  local az = rand()*twopi;
  local ay = (self.emitRot + rand() * self.emitRotSpread) * degreeToPI;

  local a,b,c = cos(ay),  cos(az)*sin(ay),  sin(az)*sin(ay)

  speed = {
    up[1]*a - right[1]*b + forward[1]*c,
    up[2]*a - right[2]*b + forward[2]*c,
    up[3]*a - right[3]*b + forward[3]*c}

  speed     = Vmul( speed, self.speed + rand() * self.speedSpread )
  rot       = rand()*self.rotSpread
  rotFactor = self.rotFactor + rand()*self.rotFactorSpread
  size      = self.size + rand()*self.sizeSpread
  life      = self.life + rand()*self.lifeSpread

  local part = {speed=Vlength(speed),rot=rot,size=size,life=life,i=n}
  pos = { ProcessParamCode(partpos, part) }

  return life, size,
         pos[1],pos[2],pos[3],
         speed[1],speed[2],speed[3],
         rot, rotFactor;
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SimpleParticles:BeginDraw()
  glUseShader(billShader)
end

function SimpleParticles:EndDraw()
  glTexture(false)
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glUseShader(0)
end

function SimpleParticles:Draw()
  glTexture(self.texture)
  glBlending(self.srcBlend,self.dstBlend)

  glUniform(rotUniform, self.urot)
  glUniform(sizeUniform, self.usize)
  glUniform(frameUniform, self.frame)
  glUniform(movCoeffUniform, self.uMovCoeff)

  glUniformInt(colorsUniform, self.ncolors)
  for i=1,min(self.ncolors+1,12) do
    local color = self.colormap[i]
    glUniform( colormapUniform[i] , color[1], color[2], color[3], color[4] )
  end

  local pos   = self.pos
  local force = self.uforce
  local emit  = self.emitVector

  glPushMatrix()
    glTranslate(pos[1],pos[2],pos[3])
    glRotate(90,emit[1],emit[2],emit[3])
    glRotate(self.urot2Speed,0,1,0)
    glTranslate(force[1],force[2],force[3])
      glCallList(self.dlist)
  glPopMatrix()
end


local function DrawParticleForDList(size,life,x,y,z,dx,dy,dz,rot,rotFactor,colors)
  glMultiTexCoord(0,x,y,z,colors/life)
  glMultiTexCoord(1,dx,dy,dz,rot)
  glMultiTexCoord(2,size,rotFactor)
  glVertex(0,0)
  glVertex(1,0)
  glVertex(1,1)
  glVertex(0,1)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SimpleParticles:Initialize()
  billShader = gl.CreateShader({
    vertex = [[
      uniform float size;
      uniform float rot;
      uniform float frame;
      uniform float movCoeff;

      uniform vec4 colormap[12];
      uniform int  colors;

      varying vec2 texCoord;

      void main()
      {
         //gl.MultiTexCoord(0,x,y,z,colors/life)
         //gl.MultiTexCoord(1,dx,dy,dz,rot)
         //gl.MultiTexCoord(2,size,rotFactor)
         //gl.Vertex(s,t)

         float  cpos = frame*gl_MultiTexCoord0.w;
         int   ipos1 = int(cpos);
         float psize = size+gl_MultiTexCoord2.x;

         if (ipos1>=colors || psize<=0.0) {
           // paste dead particles offscreen, this way we don't dump the fragment shader with it
           gl_Position = vec4(-2000.0,-2000.0,-2000.0,-2000.0);
         }else{
           int ipos2 = ipos1+1; if (ipos2>colors) ipos2 = colors;
           gl_FrontColor = mix(colormap[ipos1],colormap[ipos2],fract(cpos));

           // calc vertex position
           vec4 pos        = vec4( gl_MultiTexCoord0.xyz + movCoeff * gl_MultiTexCoord1.xyz ,1.0);
           gl_Position     = gl_ModelViewMatrix * pos;

           // calc particle rotation
           float alpha     = (gl_MultiTexCoord1.w + rot) * 0.159 * gl_MultiTexCoord2.y; //0.159 := ~(1/2pi)
           float ca        = cos(alpha);
           float sa        = sin(alpha);
           mat2 rotation   = mat2( ca , -sa, sa, ca );

           // offset vertex from center of the polygon
           gl_Position.xy += rotation * ( (gl_Vertex.xy-0.5) * psize );

           // end
           gl_Position = gl_ProjectionMatrix * gl_Position;
           texCoord    = gl_Vertex.xy;
         }
       }
    ]],
    fragment = [[
      uniform sampler2D tex0;

      varying vec2 texCoord;

      void main()
      {
        gl_FragColor = texture2D(tex0,texCoord) * gl_Color;
      }
    ]],
    uniformInt = {
      tex0 = 0,
    },
    uniform = {
      size  = 0,
      rot   = 0,
      frame = 0,
      movCoeff = 0,
    },
  })

  if (billShader==nil) then
    print(PRIO_MAJOR,"LUPS->SimpleParticles: Critical Shader Error: " ..gl.GetShaderLog())
    return false
  end

  rotUniform   = gl.GetUniformLocation(billShader,"rot")
  sizeUniform  = gl.GetUniformLocation(billShader,"size")
  frameUniform = gl.GetUniformLocation(billShader,"frame")
  movCoeffUniform = gl.GetUniformLocation(billShader,"movCoeff")

  colorsUniform = gl.GetUniformLocation(billShader,"colors")
  for i=1,12 do
    colormapUniform[i] = gl.GetUniformLocation(billShader,"colormap["..(i-1).."]")
  end
end

function SimpleParticles:Finalize()
  gl.DeleteShader(billShader)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SimpleParticles:Update(n)
  if (n==1) then --// in the case of 1 frame we can use much faster equations
    self.uMovCoeff = self.airdrag^self.frame + self.uMovCoeff;
    self.urot = (self.urot + self.rotSpeed)*self.rotairdrag;
  else
    local rotBoost = 0
    for i=1,n do 
      rotBoost = self.rotSpeed*(self.rotairdrag^i) + rotBoost;
      self.uMovCoeff = self.airdrag^(self.frame+i) + self.uMovCoeff;
    end
    self.urot = (self.urot * (self.rotairdrag^n)) + rotBoost
  end

  self.usize  = self.usize + n*self.sizeGrowth
  self.frame  = self.frame + n

  self.urot2Speed = self.rot2Speed*self.frame
  self.uforce[1],self.uforce[2],self.uforce[3] = self.force[1]*self.frame,self.force[2]*self.frame,self.force[3]*self.frame
end

-- used if repeatEffect=true;
function SimpleParticles:ReInitialize()
  self.frame = 0
  self.usize = 0
  self.urot  = 0
  self.uMovCoeff = 1
  self.dieGameFrame = self.dieGameFrame + self.life + self.lifeSpread
  self.urot2Speed = 0
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
    local life,size,x,y,z,dx,dy,dz,rot,rotFactor = self:CreateParticleAttributes(up,right,forward, partposCode,i-1)
    glBeginEnd(GL_QUADS,DrawParticleForDList,
                 size,life,
                 x,y,z,    -- relative start pos
                 dx,dy,dz, -- speed vector
                 rot,rotFactor,
                 self.ncolors)
    local spawnDist = x*x + y*y + z*z
    if (spawnDist>self.maxSpawnRadius) then self.maxSpawnRadius=spawnDist end
  end
  self.maxSpawnRadius = sqrt(self.maxSpawnRadius)
end

function SimpleParticles:CreateParticle()
  self.ncolors = #self.colormap-1

  self.dlist = glCreateList(InitializeParticles,self)

  self.frame = 0
  self.firstGameFrame = thisGameFrame
  self.dieGameFrame   = self.firstGameFrame + self.life + self.lifeSpread

  self.urot  = 0
  self.usize = 0
  self.uMovCoeff = 1
  self.urot2Speed = 0
  self.uforce = {0,0,0}

  --// visibility check vars
  self.radius        = self.size + self.sizeSpread + self.maxSpawnRadius + 100
  self.maxSpeed      = self.speed+ abs(self.speedSpread)
  self.forceStrength = Vlength(self.force)
  self.sphereGrowth  = self.forceStrength+self.sizeGrowth
end

function SimpleParticles:Destroy()
  gl.DeleteList(self.dlist)
  --gl.DeleteTexture(self.texture)
end

function SimpleParticles:Visible()
  local radius = self.radius +
                 self.uMovCoeff*self.maxSpeed +
                 self.frame*self.sphereGrowth --FIXME: frame is only updated on Update()
  local posX,posY,posZ = self.pos[1],self.pos[2],self.pos[3]
  local losState
  if (self.unit and not self.worldspace) then
    losState = GetUnitLosState(self.unit)
    local ux,uy,uz = spGetUnitViewPosition(self.unit)
    posX,posY,posZ = posX+ux,posY+uy,posZ+uz
    radius = radius + spGetUnitRadius(self.unit)
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

function SimpleParticles.Create(Options)
  local newObject = MergeTable(Options, SimpleParticles.Default)
  setmetatable(newObject,SimpleParticles)  --// make handle lookup
  newObject:CreateParticle()
  return newObject
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return SimpleParticles