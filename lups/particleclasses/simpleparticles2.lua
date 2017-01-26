-- $Id: SimpleParticles2.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local SimpleParticles2 = {}
SimpleParticles2.__index = SimpleParticles2

local billShader
local colormapUniform = {}

local lastTexture = ""

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SimpleParticles2.GetInfo()
  return {
    name      = "SimpleParticles2",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "This is a simialr class to SimpleParticles, just that it is 100% implemented with shaders, todo so it miss the Airdrag tags and added new Exp tags.",

    layer     = 0, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = false,
    shader    = true,
    rtt       = false,
    ctt       = false,
  }
end

SimpleParticles2.Default = {
  emitVector     = {0,1,0},
  pos            = {0,0,0}, --// start pos
  partpos        = "0,0,0", --// particle relative start pos (can contain lua code!)
  layer          = 0,

  --// visibility check
  los            = true,
  airLos         = true,
  radar          = false,

  count          = 1,
  force          = {0,0,0}, --// global effect force
  forceExp       = 1,
  speed          = 0,
  speedSpread    = 0,
  speedExp       = 1, --// >1 : first decrease slow, then fast;  <1 : decrease fast, then slow
  life           = 0,
  lifeSpread     = 0,
  delaySpread    = 0,
  rotSpeed       = 0,
  rotSpeedSpread = 0,
  rotSpread      = 0,
  rotExp         = 1, --// >1 : first decrease slow, then fast;  <1 : decrease fast, then slow;  <0 : invert x-axis (start large become smaller)
  emitRot        = 0,
  emitRotSpread  = 0,
  size           = 0,
  sizeSpread     = 0,
  sizeGrowth     = 0,
  sizeExp        = 1, --// >1 : first decrease slow, then fast;  <1 : decrease fast, then slow;  <0 : invert x-axis (start large become smaller)
  colormap       = { {0, 0, 0, 0} }, --//max 16 entries
  texture        = '',
  repeatEffect   = false, --can be a number,too
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

function SimpleParticles2:CreateParticleAttributes(up, right, forward, partpos,n)
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
  rotStart  = rand() * self.rotSpread * degreeToPI
  rotEnd    = (self.rotSpeed + rand() * self.rotSpeedSpread) * life * degreeToPI

  if (partpos) then
    local part = { speed=speed, velocity=Vlength(speed), life=life, delay=delay, i=n }
    pos = { ProcessParamCode(partpos, part) }
  else
    pos = nullVector
  end

  return life, delay,
         pos[1],pos[2],pos[3],
         speed[1],speed[2],speed[3],
         sizeStart,sizeEnd,
         rotStart,rotEnd;
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SimpleParticles2.BeginDraw()
  glUseShader(billShader)
  glBlending(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
end

function SimpleParticles2.EndDraw()
  glTexture(0,false)
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glUseShader(0)

  lastTexture=""
end

function SimpleParticles2:Draw()
  if (lastTexture~=self.texture) then
    glTexture(0,self.texture)
    lastTexture=self.texture
  end

  glMultiTexCoord(5, self.frame/200)
  glCallList(self.dlist)
end


local function DrawParticleForDList(life,delay, x,y,z, dx,dy,dz, sizeStart,sizeEnd, rotStart,rotEnd)
  glMultiTexCoord(0, x,y,z, life/200)
  glMultiTexCoord(1, dx,dy,dz, delay/200)
  glMultiTexCoord(2, sizeStart, rotStart, sizeEnd, rotEnd)

  glVertex(0,0)
  glVertex(1,0)
  glVertex(1,1)
  glVertex(0,1)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SimpleParticles2:Initialize()
  billShader = gl.CreateShader({
    vertex = [[
      uniform vec4  colormap[16];

      varying vec2 texCoord;

      // global attributes
      #define iframe    gl_MultiTexCoord5.x
      #define colors    gl_MultiTexCoord3.w
      #define forceExp  gl_MultiTexCoord4.w
      #define forceDir (gl_MultiTexCoord4.xyz)

      // particle attributes
      #define posV     (gl_MultiTexCoord0.xyz)
      #define dirV     (gl_MultiTexCoord1.xyz)
      #define maxLife   gl_MultiTexCoord0.w
      #define delay     gl_MultiTexCoord1.w

      // 1. holds dist,size and rot start values
      // 2. holds dist,size and rot end values
      // 3. holds dist,size and rot exponent values (equation is: 1-(1-life)^exp)
      #define attributesStart vec3(0.0,gl_MultiTexCoord2.xy)
      #define attributesEnd   vec3(0.0,gl_MultiTexCoord2.zw)
      #define attributesExp  (gl_MultiTexCoord3.xyz)

      void main()
      {
         float lframe = iframe - delay;
         float life   = lframe / maxLife; // 0.0 .. 1.0 range!

         if (life<=0.0 || life>1.0) {
           // move dead particles offscreen, this way we don't dump the fragment shader with it
           gl_Position = vec4(-2000.0,-2000.0,-2000.0,-2000.0);
         }else{
           // calc color
           float cpos = life * colors;
           int ipos1  = int(cpos);
           int ipos2  = int(min(float(ipos1 + 1),colors));
           gl_FrontColor = mix(colormap[ipos1], colormap[ipos2], fract(cpos));

           // calc particle attributes
           vec3 attrib = vec3(1.0) - pow(vec3(1.0 - life), abs(attributesExp));
         //if (attributesExp.x<0.0) attrib.x = 1.0 - attrib.x; // speed (no need for backward movement)
           if (attributesExp.y<0.0) attrib.y = 1.0 - attrib.y; // size
           if (attributesExp.z<0.0) attrib.z = 1.0 - attrib.z; // rot
           attrib.yz   = attributesStart.yz + attrib.yz * attributesEnd.yz; 

           // calc vertex position
           vec3 forceV = (1.0 - pow(1.0 - life, abs(forceExp))) * forceDir; //FIXME combine with other attribs!
           vec4 pos4   = vec4(posV + attrib.x * dirV + forceV, 1.0);
           gl_Position = gl_ModelViewMatrix * pos4;

           // calc particle rotation
           float alpha     = attrib.z;
           float ca        = cos(alpha);
           float sa        = sin(alpha);
           mat2 rotation   = mat2( ca , -sa, sa, ca );

           // offset vertex from center of the polygon
           gl_Position.xy += rotation * ( (gl_Vertex.xy - 0.5) * attrib.y );

           // end
           gl_Position  = gl_ProjectionMatrix * gl_Position;
           texCoord     = gl_Vertex.xy;
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
  })

  if (billShader==nil) then
    print(PRIO_MAJOR,"LUPS->SimpleParticles2: Critical Shader Error: " ..gl.GetShaderLog())
    return false
  end

  for i=1,16 do
    colormapUniform[i] = gl.GetUniformLocation(billShader,"colormap["..(i-1).."]")
  end
end

function SimpleParticles2:Finalize()
  gl.DeleteShader(billShader)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SimpleParticles2:Update(n)
  self.frame  = self.frame + n
end

-- used if repeatEffect=true;
function SimpleParticles2:ReInitialize()
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

  --// global data
  glMultiTexCoord(3, self.speedExp, self.sizeExp, self.rotExp, self.ncolors)
  glMultiTexCoord(4, self.force[1], self.force[2], self.force[3], self.forceExp)

  local posX,posY,posZ = self.pos[1],self.pos[2],self.pos[3]

  local ev         = self.emitVector
  local emitMatrix = CreateEmitMatrix3x3(ev[1],ev[2],ev[3])

  self.maxSpawnRadius = 0
  for i=1,self.count do
    local life,delay, x,y,z, dx,dy,dz, sizeStart,sizeEnd, rotStart,rotEnd = self:CreateParticleAttributes(up,right,forward, partposCode, i-1)
    dx,dy,dz = MultMatrix3x3(emitMatrix,dx,dy,dz)
    DrawParticleForDList(life, delay,
                         x+posX,y+posY,z+posZ,    -- relative start pos
                         dx,dy,dz, -- speed vector
                         sizeStart,sizeEnd,
                         rotStart,rotEnd)
    local spawnDist = x*x + y*y + z*z
    if (spawnDist>self.maxSpawnRadius) then self.maxSpawnRadius=spawnDist end
  end
  self.maxSpawnRadius = sqrt(self.maxSpawnRadius)

  glMultiTexCoord(2, 0,0,0,1)
  glMultiTexCoord(3, 0,0,0,1)
  glMultiTexCoord(4, 0,0,0,1)
end

local function CreateDList(self)
  --// FIXME: compress each color into 32bit register of a MultiTexCoord, so each MultiTexCoord can hold 4 rgba packs!
  for i=1,min(self.ncolors+1,16) do
    local color = self.colormap[i]
    glUniform( colormapUniform[i] , color[1], color[2], color[3], color[4] )
  end

  glBeginEnd(GL_QUADS,InitializeParticles,self)
end

function SimpleParticles2:CreateParticle()
  self.ncolors = #self.colormap-1

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

function SimpleParticles2:Destroy()
  gl.DeleteList(self.dlist)
  --gl.DeleteTexture(self.texture)
end

function SimpleParticles2:Visible()
  local radius = self.radius +
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

function SimpleParticles2.Create(Options)
  local newObject = MergeTable(Options, SimpleParticles2.Default)
  setmetatable(newObject,SimpleParticles2)  --// make handle lookup
  newObject:CreateParticle()
  return newObject
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return SimpleParticles2