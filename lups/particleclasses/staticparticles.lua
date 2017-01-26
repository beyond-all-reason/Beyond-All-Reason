-- $Id: StaticParticles.lua 3345 2008-12-02 00:03:50Z jk $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local StaticParticles = {}
StaticParticles.__index = StaticParticles

local billShader,sizeUniform,frameUniform
local colormapUniform,colorsUniform = {},0

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function StaticParticles.GetInfo()
  return {
    name      = "StaticParticles",
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

StaticParticles.Default = {
  particles = {},
  dlist     = 0,

  --// visibility check
  los            = true,
  airLos         = true,
  radar          = false,

  emitVector  = {0,1,0},
  pos         = {0,0,0}, --// start pos
  partpos     = "0,0,0", --// particle relative start pos (can contain lua code!)
  layer       = 0,

  life        = 0,
  lifeSpread  = 0,
  rot2Speed   = 0, --// global effect rotation
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

local spGetUnitLosState     = Spring.GetUnitLosState
local spGetPositionLosState = Spring.GetPositionLosState
local spGetUnitViewPosition = Spring.GetUnitViewPosition
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
local glCallList    = gl.CallList
local glRotate      = gl.Rotate
local glColor       = gl.Color

local glBeginEnd     = gl.BeginEnd
local GL_QUADS       = GL.QUADS
local glMultiTexCoord= gl.MultiTexCoord
local glVertex       = gl.Vertex

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function StaticParticles:CreateParticleAttributes(partpos,n)
  local life, pos, size;

  size   = rand()*self.sizeSpread
  life   = self.life + rand()*self.lifeSpread

  local part = {size=self.size+size,life=life,i=n}
  pos   = { ProcessParamCode(partpos, part) }

  return life, size, 
         pos[1],pos[2],pos[3];
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local lasttexture = nil

function StaticParticles:BeginDraw()
  gl.UseShader(billShader)
  lasttexture = nil
end

function StaticParticles:EndDraw()
  glTexture(false)
  glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
  gl.UseShader(0)
end

function StaticParticles:Draw()
  if (lasttexture ~= self.texture) then
    glTexture(self.texture)
    lasttexture = self.texture
  end
  glBlending(self.srcBlend,self.dstBlend)

  glUniform(sizeUniform,self.usize)
  glUniform(frameUniform,self.frame)

  glPushMatrix()
  glTranslate(self.pos[1],self.pos[2],self.pos[3])
  glRotate(90,self.emitVector[1],self.emitVector[2],self.emitVector[3])
  glRotate(self.rot2Speed*self.frame,0,1,0)
    glCallList(self.dlist)
  glPopMatrix()
end


local function DrawParticleForDList(size,life,x,y,z,colors)
  glMultiTexCoord(0,x,y,z,1.0)
  glMultiTexCoord(1,size,colors/life)
  glVertex(-0.5,-0.5,0,0)
  glVertex( 0.5,-0.5,1,0)
  glVertex( 0.5, 0.5,1,1)
  glVertex(-0.5, 0.5,0,1)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function StaticParticles:Initialize()
  billShader = gl.CreateShader({
    vertex = [[
      uniform float size;
      uniform float frame;

      uniform vec4 colormap[12];
      uniform int  colors;

      varying vec2 texCoord;

      void main()
      {
         #define pos gl_MultiTexCoord0
         #define csize gl_MultiTexCoord1.x
         #define clrslife gl_MultiTexCoord1.y
         #define texcoord gl_Vertex.pq
         #define billboardpos gl_Vertex.xy

         #define pos gl_MultiTexCoord0
         #define csize gl_MultiTexCoord1.x
         #define clrslife gl_MultiTexCoord1.y
         #define texcoord gl_Vertex.pq
         #define billboardpos gl_Vertex.xy

         float cpos      = frame*clrslife;
         int   ipos1     = int(cpos);
         float psize     = csize + size;

         if (ipos1>colors || psize<=0.0) {
           // paste dead particles offscreen, this way we don't dump the fragment shader with it
           const vec4 offscreen = vec4(-2000.0,-2000.0,-2000.0,-2000.0);
           gl_Position = offscreen;
         }else{
           int ipos2 = ipos1+1; if (ipos2>colors) ipos2 = colors;
           gl_FrontColor = mix(colormap[ipos1],colormap[ipos2],fract(cpos));

           // calc vertex position
           gl_Position     = gl_ModelViewMatrix * pos;

           // offset vertex from center of the polygon
           gl_Position.xy += billboardpos * psize;

           // end
           gl_Position  = gl_ProjectionMatrix * gl_Position;
           texCoord     = texcoord;
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
      frame = 0,
      size  = 0,
    },
  })

  if (billShader==nil) then
    print(PRIO_MAJOR,"LUPS->StaticParticles: Critical Shader Error: " ..gl.GetShaderLog())
    return false
  end

  sizeUniform   = gl.GetUniformLocation(billShader,"size")
  frameUniform  = gl.GetUniformLocation(billShader,"frame")

  colorsUniform = gl.GetUniformLocation(billShader,"colors")
  for i=1,12 do
    colormapUniform[i] = gl.GetUniformLocation(billShader,"colormap["..(i-1).."]")
  end
end

function StaticParticles:Finalize()
  gl.DeleteShader(billShader)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function StaticParticles:Update(n)
  self.frame  = self.frame + n
  self.usize  = self.usize + n*self.sizeGrowth
end

-- used if repeatEffect=true;
function StaticParticles:ReInitialize()
  self.usize = self.size
  self.frame = 0
  self.dieGameFrame = self.dieGameFrame + self.life + self.lifeSpread
end

function StaticParticles:CreateParticle()
  local maxSpawnRadius = 0
  self.ncolors = #self.colormap-1
  local partposCode = ParseParamString(self.partpos)

  self.dlist = gl.CreateList(function()
    glUniformInt(colorsUniform, self.ncolors)
    for i=1,min(self.ncolors+1,12) do
      local color = self.colormap[i]
      glUniform( colormapUniform[i] , color[1], color[2], color[3], color[4] )
    end
    gl.BeginEnd(GL.QUADS, function()
      for i=1,self.count do
        local life,size,x,y,z = self:CreateParticleAttributes(partposCode,i-1)
        DrawParticleForDList(size,life,
                             x,y,z,    -- relative start pos
                             self.ncolors)
        local spawnDist = sqrt(x*x+y*y+z*z)
        if (spawnDist>maxSpawnRadius) then maxSpawnRadius=spawnDist end
      end
    end)
  end)

  self.usize = self.size
  self.frame = 0
  self.firstGameFrame = Spring.GetGameFrame()
  self.dieGameFrame   = self.firstGameFrame + self.life + self.lifeSpread

  --// visibility check vars
  self.radius        = self.size + self.sizeSpread + maxSpawnRadius + 100
  self.sphereGrowth  = self.sizeGrowth
end

function StaticParticles:Destroy()
  for _,part in ipairs(self.particles) do
    gl.DeleteList(part.dlist)
  end
  --gl.DeleteTexture(self.texture)
end

function StaticParticles:Visible()
  local radius = self.radius +
                 self.frame*(self.sphereGrowth) --FIXME: frame is only updated on Update()
  local posX,posY,posZ = self.pos[1],self.pos[2],self.pos[3]
  local losState
  if (self.unit and not self.worldspace) then
    losState = GetUnitLosState(self.unit)
    local ux,uy,uz = spGetUnitViewPosition(self.unit)
	if not ux then
	  return false
	end
    posX,posY,posZ = posX+ux,posY+uy,posZ+uz
    radius = radius + (spGetUnitRadius(self.unit) or 0)
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

function StaticParticles.Create(Options)
  local newObject = MergeTable(Options, StaticParticles.Default)
  setmetatable(newObject,StaticParticles)  --// make handle lookup
  newObject:CreateParticle()
  return newObject
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return StaticParticles