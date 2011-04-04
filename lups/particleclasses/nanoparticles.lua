-- $Id: NanoParticles.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local NanoParticles = {}
NanoParticles.__index = NanoParticles

local billShader

local lastTexture = ""

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoParticles.GetInfo()
  return {
    name      = "NanoParticles",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 0, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = false,
    shader    = true,
    rtt       = false,
    ctt       = false,
    atiseries = 1,
  }
end

NanoParticles.Default = {
  layer        = 0,
  worldspace   = true,
  repeatEffect = false, --can be a number,too

  --// shared options with all nanofx
  dir          = {0,1,0},
  pos          = {0,0,0}, --// start pos
  radius       = 0,       --// terraform/unit radius
  color        = {0, 0, 0, 0},
  count        = 1,
  inversed     = false,   --// reclaim?
  terraform    = false,   --// for terraform (2d target)
  unit         = -1,
  nanopiece    = -1,

  --// some unit informations
  unitID    = -1,
  unitDefID = -1,
  teamID    = -1,
  allyID    = -1,

  --//custom (user) options
  alpha       = 1,
  delaySpread = 30,
  size        = 3,
  sizeSpread  = 1,
  sizeGrowth  = 0.05,
  particles   = 1,
  texture     = 'bitmaps/PD/nano.tga',

  --// internal used
  dlist       = 0,
  life        = 0,
  speed       = 3,
  speedSpread = 1,
  invspeed    = 3,
  rotSpeed    = 0.15,
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

--// speed ups

local abs  = math.abs
local sqrt = math.sqrt
local ceil = math.ceil
local rand = math.random
local twopi= 2*math.pi
local cos  = math.cos
local sin  = math.sin
local min  = math.min
local max  = math.max
local degreeToPI = math.pi/180

local ALL_ACCESS_TEAM = Script.ALL_ACCESS_TEAM

local spGetPositionLosState = Spring.GetPositionLosState
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spIsSphereInView      = Spring.IsSphereInView
local spGetUnitRadius       = Spring.GetUnitRadius

local glTexture     = gl.Texture 
local glBlending    = gl.Blending
local glMultiTexCoord = gl.MultiTexCoord
local glPushMatrix  = gl.PushMatrix
local glPopMatrix   = gl.PopMatrix
local glTranslate   = gl.Translate
local glCreateList  = gl.CreateList
local glCallList    = gl.CallList
local glRotate      = gl.Rotate
local glColor       = gl.Color
local glUseShader   = gl.UseShader

local glBeginEnd     = gl.BeginEnd
local GL_QUADS       = GL.QUADS
local glMultiTexCoord= gl.MultiTexCoord
local glVertex       = gl.Vertex
local GL_ONE         = GL.ONE
local GL_SRC_ALPHA   = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoParticles:CreateParticleAttributes(minLength)
  local target = self.dir
  if (self.terraform) then
    local r,alpha = rand()*self.radius,rand()*twopi
    target = { target[1],  target[2] + r*cos(alpha),  target[3] + r*sin(alpha) }
  else
    local r,alpha,beta=rand()*self.radius,rand()*twopi,rand()*twopi
    target = { target[1] + r*cos(alpha),  target[2] + r*cos(beta)*sin(alpha),  target[3] + r*sin(beta)*sin(alpha) }
  end

  local distance = Vlength(target)
  if (distance<minLength) then distance = minLength end

  local speed  = self.speed + rand()*self.speedSpread
  local rot    = rand()*360
  local size   = self.size + rand()*self.sizeSpread
  local life   = distance/speed
  local speedv = Vmul( target, 1/life )
  local delay  = rand()*self.delaySpread

  return life, delay, size,
         speedv[1],speedv[2],speedv[3],
         rot;
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoParticles:BeginDraw()
  glUseShader(billShader)
  glBlending(GL_ONE,GL_ONE_MINUS_SRC_ALPHA)
end

function NanoParticles:EndDraw()
  glTexture(false)
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glUseShader(0)

  lastTexture=""
end

function NanoParticles:Draw()
  if (lastTexture~=self.texture) then
    glTexture(self.texture)
    lastTexture=self.texture
  end

  if (self.inversed)
    then glMultiTexCoord(3,self.urot, self.maxLife - self.frame - Spring.GetFrameTimeOffset())
    else glMultiTexCoord(3,self.urot, self.frame+Spring.GetFrameTimeOffset()) end

  glCallList(self.dlist)
end


local function DrawParticleForDList(size,sizeGrowth,life,delay,dx,dy,dz,rot)
  glMultiTexCoord(0,life,delay,size,sizeGrowth)
  glMultiTexCoord(1,dx,dy,dz,rot)
  glVertex(0,0,-0.5,-0.5)
  glVertex(1,0, 0.5,-0.5)
  glVertex(1,1, 0.5, 0.5)
  glVertex(0,1,-0.5, 0.5)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoParticles:Initialize()
  billShader = gl.CreateShader({
    vertex = [[
      //gl.MultiTexCoord(0,life,delay,size,sizeGrowth)
      //gl.MultiTexCoord(1,dx,dy,dz,rot_off)
      //gl.MultiTexCoord(2,R,G,B,A)
      //gl.MultiTexCoord(3,rot,frame)
      //gl.Vertex(ox,oy,s,t)

      #define size       gl_MultiTexCoord0.z
      #define sizeGrowth gl_MultiTexCoord0.w
      #define life       gl_MultiTexCoord0.x
      #define delay      gl_MultiTexCoord0.y
      #define speed      gl_MultiTexCoord1.xyz
      #define rot_off    gl_MultiTexCoord1.w
      #define rot        gl_MultiTexCoord3.x
      #define frame      gl_MultiTexCoord3.y
      #define incolor    gl_MultiTexCoord2

      const vec4 offscreen = vec4(-20000.0,-20000.0,-20000.0,-20000.0);

      varying vec2 texcoord;
      varying vec4 color;

      void main()
      {
         float lframe = frame - delay;
         float lifeN  = lframe / life;
         float psize  = lframe * sizeGrowth + size;

         if (lifeN<0.0 || lifeN>1.0 || psize<=0.0) {
           // paste dead particles offscreen, this way we don't dump the fragment shader with it
           gl_Position = offscreen;
         }else{
           color = incolor;
           if (lifeN>0.8) color *= (1.0-lifeN)*5.0; //fade out

           // calc vertex position
           vec4 pos        = vec4( lframe * speed, 1.0);
           gl_Position     = gl_ModelViewMatrix * pos;

           // calc particle rotation
           float alpha     = (rot_off + rot) * 0.159; //0.159 := (1/2pi)
           float ca        = cos(alpha);
           float sa        = sin(alpha);
           mat2 rotation   = mat2( ca , -sa, sa, ca );

           // offset vertex from center of the polygon
           gl_Position.xy += rotation * ( gl_Vertex.zw * psize );

           // end
           gl_Position = gl_ProjectionMatrix * gl_Position;
           texcoord    = gl_Vertex.xy;
         }
       }
    ]],
    fragment = [[
      uniform sampler2D tex0;

      varying vec2 texcoord;
      varying vec4 color;

      void main()
      {
        gl_FragColor = texture2D(tex0,texcoord) * color;
      }
    ]],
    uniformInt = {
      tex0 = 0,
    },
  })

  if (billShader==nil) then
    print(PRIO_MAJOR,"LUPS->NanoParticles: Critical Shader Error: " ..gl.GetShaderLog())
    return false
  end
end

function NanoParticles:Finalize()
  gl.DeleteShader(billShader)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoParticles:Update(n)
  self.urot  = self.urot  + n*self.rotSpeed
  self.frame = self.frame + n
end

-- used if repeatEffect=true;
function NanoParticles:ReInitialize()
  self.frame = 0
  self.urot  = 0
  self.dieGameFrame = self.dieGameFrame + self.maxLife
end

local function CreateParticlesForDList2(self,distance)
  local sizeGrowth = self.sizeGrowth
  for i=1,self.count do
    local life,delay,size,dx,dy,dz,rot = self:CreateParticleAttributes(distance)
    DrawParticleForDList(
        size, sizeGrowth,
        life, delay,
        dx,dy,dz, -- speed vector
        rot)
  end
end

local function CreateParticlesForDList(self,distance)
  glPushMatrix()
  glTranslate(self.pos[1],self.pos[2],self.pos[3])
  glRotate(90,self.dir[1],self.dir[2],self.dir[3])
  glMultiTexCoord(2,self.color[1],self.color[2],self.color[3],self.color[4])
  glBeginEnd(GL_QUADS,CreateParticlesForDList2,self,distance)
  glPopMatrix()
end

function NanoParticles:CreateParticle()
  self.count = self.count * self.particles
  self.color = Vmul(self.color,self.alpha)

  local col  = self.color
  local cmax = max(col[1],col[2],col[3])
  local cmin = min(col[1],col[2],col[3])
  if ((cmax+cmin)<0.05) then
    local hsl = HSL.new(col[1],col[2],col[3])
    hsl.L = 0.5
    self.color = hsl:getRGB()
    self.color[4] = col[4]
  end

  if (self.speedSpread<0) then --// we need positive speedSpreads
    self.speed       = self.speed-self.speedSpread
    self.speedSpread = -self.speedSpread
  end

  local distance = Vlength(self.dir)
  if (distance<100) then
    local f = distance/100
    if (f<0.4) then f=0.4 end
    self.speed       = self.speed*f
    self.speedSpread = self.speedSpread*f
  end

  self.invspeed = 1/self.speed
  self.dlist = glCreateList(CreateParticlesForDList,self,distance)

  self.urot  = 0
  self.frame = 0
  self.maxLife        = self.life+self.delaySpread+ceil((Vlength(self.dir)+self.radius)/self.speed)
  self.firstGameFrame = thisGameFrame
  self.dieGameFrame   = self.firstGameFrame + self.maxLife

  --// visibility check vars
  self.sizeRadius = self.size  + self.sizeSpread + 100
  self.normdir    = Vmul( self.dir, 1/Vlength(self.dir) )
end

function NanoParticles:Destroy()
  gl.DeleteList(self.dlist)
  --gl.DeleteTexture(self.texture)
end

function NanoParticles:Visible()
  local frame = 0 --FIXME: frame is only updated on Update() after visible()-check!!!
  if (self.inversed)
    then frame = self.maxLife - self.frame
    else frame = self.frame end

  local radius = self.sizeRadius +
                 self.delaySpread*self.speed*0.5+
                 frame*(self.speedSpread*0.5+self.sizeGrowth)

  local fTime = (self.speed+self.speedSpread*0.5)*frame

  local spos  = self.pos
  local sndir = self.normdir

  local pos = {spos[1] + sndir[1]*fTime,
               spos[2] + sndir[2]*fTime,
               spos[3] + sndir[3]*fTime}

  if (self.allyID==LocalAllyTeamID)or(LocalAllyTeamID==ALL_ACCESS_TEAM) then
    return spIsSphereInView(pos[1],pos[2],pos[3],radius)
  else
    local _,los = spGetPositionLosState(pos[1],pos[2],pos[3], LocalAllyTeamID)
    return (los)and(spIsSphereInView(pos[1],pos[2],pos[3],radius))
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoParticles.Create(Options)
  local newObject = MergeTable(Options, NanoParticles.Default)
  setmetatable(newObject,NanoParticles)  --// make handle lookup
  newObject:CreateParticle()
  return newObject
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return NanoParticles