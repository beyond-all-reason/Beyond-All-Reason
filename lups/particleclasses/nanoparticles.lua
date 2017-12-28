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
    backup    = "NanoLasers", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 0, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = false,
    shader    = true,
    rtt       = false,
    ctt       = false,
  }
end

NanoParticles.Default = {
  layer        = 0,
  worldspace   = true,
  repeatEffect = false, --can be a number,too

  --// shared options with all nanofx
  pos          = {0,0,0}, --// start pos
  targetpos    = {0,0,0},
  targetradius = 0,       --// terraform/unit radius
  color        = {0, 0, 0, 0},
  count        = 1,
  inversed     = false,   --// reclaim?
  terraform    = false,   --// for terraform (2d target)
  unit         = -1,
  nanopiece    = -1,

  --// some unit informations
  targetID  = -1,
  unitID    = -1,
  unitpiece = -1,
  unitDefID = -1,
  teamID    = -1,
  allyID    = -1,

  --//custom (user) options
  life        = -1, --//auto adjusted on initialization
  alpha       = 1,
  delaySpread = 30,
  size        = 3,
  sizeSpread  = 1,
  sizeGrowth  = 0.05,
  rotSpeed    = 0.15,
  particles   = 1,
  texture     = 'bitmaps/PD/nano.png',

  --// internal used
  dlist       = 0,
  stopframe   = 1e9,
  _dead       = false,
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

--// speed ups

local rand = math.random
local twopi= 2*math.pi
local cos  = math.cos
local sin  = math.sin
local min  = math.min
local max  = math.max

local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spIsSphereInView      = Spring.IsSphereInView
local spGetUnitRadius       = Spring.GetUnitRadius

local glTexture     = gl.Texture 
local glBlending    = gl.Blending
local glMultiTexCoord = gl.MultiTexCoord
local glCreateList  = gl.CreateList
local glCallList    = gl.CallList
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

local function CreateParticleAttributes(inversed,terraform)
  local offX = 0
  local offY = 0
  local offZ = 0
  if (terraform) then
    local r     = rand()
    local alpha = rand()*twopi

    offX = 0
    offY = r*cos(alpha)
    offZ = r*sin(alpha)
  else
    local r     = rand()
    local alpha = rand()*twopi
    local beta  = rand()*twopi

    local sin_alpha = sin(alpha)

    offX = r * cos(alpha)
    offY = r * cos(beta) * sin_alpha
    offZ = r * sin(beta) * sin_alpha
  end

  local rot    = rand()*360
  local size   = rand()
  local delay  = rand()
  if (inversed) then delay = -delay end

  return delay, size, rot,
         offX,offY,offZ;
end

local function DrawParticleForDList(size,delay,rot, offx,offy,offz)
  glMultiTexCoord(4,delay,size,rot)
  glMultiTexCoord(5,offx,offy,offz,0)
  glVertex(0,0,-0.5,-0.5)
  glVertex(1,0, 0.5,-0.5)
  glVertex(1,1, 0.5, 0.5)
  glVertex(0,1,-0.5, 0.5)
end

local function CreateParticlesForDList(count, inversed, terraform)
  for i=1,count do
    local delay,size,rot,offx,offy,offz = CreateParticleAttributes(inversed, terraform)
    DrawParticleForDList(
        size, delay, rot,
        offx,offy,offz) -- offset vector
  end
end

local buffDLists = {{},{},{}}
local function GetParticlesDList(self)
  local idx = (self.inversed and 2) or (self.terraform and 3) or 1
  local dl = buffDLists[idx][self.count]
  if (not dl) then
    dl = glCreateList(glBeginEnd,GL_QUADS,CreateParticlesForDList,self.count, self.inversed, self.terraform)
    buffDLists[idx][self.count] = dl
  end
  return dl
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
    lastTexture = self.texture
  end

  local startPos  = self.pos
  local endPosNew = self.targetpos
  local endPosOld = self.targetposStart
  
  if (not self.pos) or (not self.targetpos) or (not self.targetposStart) then
    self._dead = true
    return
  end
  
  glMultiTexCoord(0,  startPos[1],  startPos[2],  startPos[3], 1)
  glMultiTexCoord(1, endPosNew[1], endPosNew[2], endPosNew[3], 1)
  glMultiTexCoord(2, endPosOld[1], endPosOld[2], endPosOld[3], 1)

  glMultiTexCoord(6,self.size,self.sizeSpread,self.sizeGrowth,self.targetradius)
  glMultiTexCoord(7,self.delaySpread,1/self.life)

  local color = self.color
  glColor(color[1],color[2],color[3],color[4])

  if (self.inversed)
    then glMultiTexCoord(3, self.urot, self.life - self.frame - Spring.GetFrameTimeOffset(), self.maxLife, self.stopframe)
    else glMultiTexCoord(3, self.urot, self.frame + Spring.GetFrameTimeOffset(), self.maxLife, self.stopframe) end

  glCallList(self.dlist)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoParticles:Initialize()
  billShader = gl.CreateShader({
    vertex = [[
      //gl.Vertex(s,t,ox,oy)

      #define delay      gl_MultiTexCoord4.x
      #define size       gl_MultiTexCoord4.y
      #define rot_off    gl_MultiTexCoord4.z
      #define rot        gl_MultiTexCoord3.x
      #define frame      gl_MultiTexCoord3.y
      #define maxlife    gl_MultiTexCoord3.z
      #define stopframe  gl_MultiTexCoord3.w

      #define minsize     gl_MultiTexCoord6.x
      #define sizeSpread  gl_MultiTexCoord6.y
      #define sizeGrowth  gl_MultiTexCoord6.z
      #define radius      gl_MultiTexCoord6.w

      #define delaySpread gl_MultiTexCoord7.x
      #define invspeed    gl_MultiTexCoord7.y

      #define offset     gl_MultiTexCoord5
      #define startpos   gl_MultiTexCoord0
      #define endpos_now gl_MultiTexCoord1
      #define endpos_old gl_MultiTexCoord2

      #define incolor    gl_Color

      const vec4 offscreen = vec4(-20000.0,-20000.0,-20000.0,-20000.0);

      varying vec2 texcoord;
      varying vec4 color;

      void main()
      {
         float lframe = frame - (delay * delaySpread);
         float lifeN  = lframe * invspeed;
         float psize  = (lframe * sizeGrowth) + minsize + (size * sizeSpread);

         if (lifeN<0.0 || lifeN>1.0 || psize<=0.0) {
           // paste dead particles offscreen, this way we don't dump the fragment shader with it
           gl_Position = offscreen;
         }else{
           color = incolor;
           if (lifeN>0.8) color *= (1.0-lifeN)*5.0; //fade out

           // calc vertex position
           vec4 finalpos = mix(endpos_old, endpos_now, max(frame / maxlife,lifeN));
           vec4 pos      = mix(startpos, finalpos + (offset * radius), lifeN);
           gl_Position   = gl_ModelViewMatrix * pos;

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

  UpdateNanoParticles(self)

  if (self._dead)and(self.stopframe == NanoParticles.Default.stopframe) then
    self.stopframe = self.frame
  end
end

function NanoParticles:Visible()
  if (self.allyID ~= LocalAllyTeamID)and(self.visibility == 0) then
    return false
  end

  local midPos = self._midpos
  return spIsSphereInView(midPos[1],midPos[2],midPos[3], self._radius)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

-- used if repeatEffect=true;
function NanoParticles:ReInitialize()
  self.frame = 0
  self.urot  = 0

  local endPos   = self.targetpos
  self.targetposStart = {endPos[1],endPos[2],endPos[3]}

  self.dieGameFrame = self.dieGameFrame + self.maxLife
end

function NanoParticles:CreateParticle()
  self.count = self.count * self.particles
  self.color = Vmul(self.color,self.alpha)

  self.urot  = 0
  self.frame = 0

  self:Update(0)

  if (self._dead) then
    --// Update() sets _dead when the nanospray command is already finished (e.g. both units are dead etc.)
    return false
  end

  local endPos   = self.targetpos
  self.targetposStart = {endPos[1],endPos[2],endPos[3]}

  local col  = self.color
  local cmax = max(col[1],col[2],col[3])
  local cmin = min(col[1],col[2],col[3])
  if ((cmax+cmin)<0.05) then
    local hsl = HSL.new(col[1],col[2],col[3])
    hsl.L = 0.5
    self.color = hsl:getRGB()
    self.color[4] = col[4]
  end

  --// defines the speed of the particles (life = time in gameframe the particles need for startpos->finalpos)
  local distance = Vlength(self.dir)
  self.life = 40 * math.log10(distance/136+1) / math.log10(2)

  --// create the DisplayList
  self.dlist = GetParticlesDList(self)

  --// visibility check vars
  self.sizeRadius = self.size + self.sizeSpread + 100

  self.maxLife        = self.life + self.delaySpread
  self.firstGameFrame = thisGameFrame
  self.dieGameFrame   = self.firstGameFrame + self.maxLife

  return true
end

function NanoParticles:Destroy()
  --gl.DeleteList(self.dlist)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoParticles.Create(Options)
  local newObject = MergeTable(Options, NanoParticles.Default)
  setmetatable(newObject,NanoParticles)  --// make handle lookup
  return newObject:CreateParticle() and newObject
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return NanoParticles
