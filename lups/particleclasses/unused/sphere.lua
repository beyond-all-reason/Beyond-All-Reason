-- $Id: Sphere.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local SphereParticle = {}
SphereParticle.__index = SphereParticle

local SphereList

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SphereParticle.GetInfo()
  return {
    name      = "Sphere",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = -24, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = false,
    shader    = false,
    rtt       = false,
    ctt       = false,
  }
end

SphereParticle.Default = {
  pos        = {0,0,0}, -- start pos
  layer      = -24,

  life       = 0,

  size       = 0,
  sizeGrowth = 0,
  colormap   = { {0, 0, 0, 0} },

  texture    = 'bitmaps/GPL/Lups/sphere.png',
  repeatEffect = false,
  genmipmap    = true,  -- todo
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SphereParticle:BeginDraw()
  gl.DepthMask(true)

  gl.Culling(GL.BACK)
end

function SphereParticle:EndDraw()
  gl.DepthMask(false)
  gl.Texture(false)
  gl.Color(1,1,1,1)
  gl.Culling(false)
end

function SphereParticle:Draw()
  gl.Texture(self.texture)
  gl.Color(self.color)

  gl.TexCoord(0, 0)
  gl.PushMatrix()
  gl.Translate(self.pos[1],self.pos[2],self.pos[3])
  gl.Scale(self.size,self.size,self.size)

  gl.MatrixMode(GL.TEXTURE)
  gl.PushMatrix()
  gl.Translate(-0.5,-0.5,0)
  gl.Scale(0.5,-0.5,0)

  gl.TexGen(GL.S, GL.TEXTURE_GEN_MODE, GL.REFLECTION_MAP)
  gl.TexGen(GL.T, GL.TEXTURE_GEN_MODE, GL.REFLECTION_MAP)
  gl.TexGen(GL.R, GL.TEXTURE_GEN_MODE, GL.REFLECTION_MAP)

  gl.CallList(SphereList)
  gl.PopMatrix()
  gl.MatrixMode(GL.MODELVIEW)

  gl.TexGen(GL.S, false)
  gl.TexGen(GL.T, false)
  gl.TexGen(GL.R, false)
  gl.PopMatrix()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SphereParticle:Initialize()
  SphereList = gl.CreateList(DrawSphere,0,0,0,40,25)
end

function SphereParticle:Finalize()
  gl.DeleteList(SphereList)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SphereParticle:CreateParticle()
  -- needed for repeat mode
  self.csize  = self.size
  self.clife  = self.life

  self.size      = self.csize or self.size
  self.life_incr = 1/self.life
  self.life      = 0
  self.color     = self.colormap[1]

  self.firstGameFrame = Spring.GetGameFrame()
  self.dieGameFrame   = self.firstGameFrame + self.clife
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SphereParticle:Update(n)
  if (self.life<1) then
    self.life     = self.life + n*self.life_incr
    self.size     = self.size + n*self.sizeGrowth
    self.color    = {GetColor(self.colormap,self.life)}
  end
end

-- used if repeatEffect=true;
function SphereParticle:ReInitialize()
  self.size     = self.csize
  self.life     = 0
  self.color    = self.colormap[1]

  self.dieGameFrame = self.dieGameFrame + self.clife
end

function SphereParticle.Create(Options)
  local newObject = MergeTable(Options, SphereParticle.Default)
  setmetatable(newObject,SphereParticle)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function SphereParticle:Destroy()
  gl.DeleteTexture(self.texture)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return SphereParticle