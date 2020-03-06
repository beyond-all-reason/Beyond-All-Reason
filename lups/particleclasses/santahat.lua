-- $Id: gimmick1.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local SantaHat = {}
SantaHat.__index = SantaHat

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SantaHat.GetInfo()
  return {
    name      = "SantaHat",
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

SantaHat.Default = {
  pos        = {0,0,0}, -- start pos
  emitVector = {0.25,1,0},
  layer      = -24,

  life       = math.huge,

  height     = 10,
  width      = 4,
  ballSize   = 0.9,

  color      = {1, 0, 0, 1},

  repeatEffect = true,
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SantaHat:BeginDraw()
  gl.DepthMask(true)
  gl.Lighting(true)
  gl.Light(0, true )
  gl.Light(0, GL.POSITION, gl.GetSun() )
  gl.Light(0, GL.AMBIENT, gl.GetSun("ambient","unit") )
  gl.Light(0, GL.DIFFUSE, gl.GetSun("diffuse","unit") )
  gl.Light(0, GL.SPECULAR, gl.GetSun("specular") )
  --gl.Culling(GL.BACK)
end

function SantaHat:EndDraw()
  gl.DepthMask(false)
  gl.Lighting(false)
  gl.Light(0, false )
  --gl.Culling(false)
end

function SantaHat:Draw()
  --gl.Color(self.color)
  local color = self.color
  gl.Material({
    ambient   = {color[1]*0.5,color[2]*0.5,color[3]*0.5,color[4]},
    diffuse   = color,
    specular  = {1,1,1,1},
    shininess = 65,
  })

  gl.PushMatrix()
  local pos  = self.pos
  local emit = self.emitVector
  gl.Translate(pos[1],pos[2],pos[3])
  gl.Rotate(90,emit[1],emit[2],emit[3])

  gl.PushMatrix()
  gl.Scale(self.width,self.height,self.width)
  gl.CallList(self.ConeList)
  gl.PopMatrix()

  gl.Color(1,1,1,1)
  gl.Material({
    ambient   = {0.5,0.5,0.5,1},
    diffuse   = {1,1,1,1},
    specular  = {1,1,1,1},
    shininess = 120,
  })

  gl.PushMatrix()
  gl.Translate(0,self.height,0)
  gl.Scale(self.ballSize,self.ballSize,self.ballSize)
  gl.CallList(self.BallList)
  gl.PopMatrix()

  gl.Scale(self.width+0.3,self.width+0.1,self.width+0.3)
  gl.CallList(self.TorusList)

  gl.PopMatrix()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SantaHat:Initialize()
  SantaHat.ConeList  = gl.CreateList(DrawPin,1,1,8)
  SantaHat.BallList  = gl.CreateList(DrawSphere,0,0,0,1,14)
  SantaHat.TorusList = gl.CreateList(DrawTorus,1,0.15,16,16)
end

function SantaHat:Finalize()
  gl.DeleteList(SantaHat.ConeList)
  gl.DeleteList(SantaHat.BallList)
  gl.DeleteList(SantaHat.TorusList)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SantaHat:CreateParticle()
  self.firstGameFrame = Spring.GetGameFrame()
  self.dieGameFrame   = self.firstGameFrame + self.life
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function SantaHat:Update()
end

-- used if repeatEffect=true;
function SantaHat:ReInitialize()
  self.dieGameFrame = self.dieGameFrame + self.life
end

function SantaHat.Create(Options)
  local newObject = MergeTable(Options, SantaHat.Default)
  setmetatable(newObject,SantaHat)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function SantaHat:Destroy()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return SantaHat