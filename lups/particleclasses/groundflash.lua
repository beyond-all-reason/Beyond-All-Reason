-- $Id: Groundflash.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local GroundFlash = {}
GroundFlash.__index = GroundFlash

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function GroundFlash.GetInfo()
  return {
    name      = "GroundFlash",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = -32, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = false,
    shader    = false,
    rtt       = false,
    ctt       = false,
  }
end

GroundFlash.Default = {
  pos        = {0,0,0}, -- start pos
  layer      = -32,
  worldspace = true,

  life       = 0,

  size       = 0,
  sizeGrowth = 0,
  colormap   = { {0, 0, 0, 0} },

  texture    = 'bitmaps/GPL/Lups/groundring.png',
  repeatEffect = false,
  genmipmap    = true,  -- todo
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local lasttexture = nil

function GroundFlash:BeginDraw()
  lasttexture = nil
  gl.AlphaTest(GL.GREATER, 0)
  gl.PolygonOffset(-5,0)
end

function GroundFlash:EndDraw()
  gl.PolygonOffset(false)
  gl.AlphaTest(GL.GREATER, 0.5)
  gl.AlphaTest(false)
  gl.Texture(false)
  gl.Color(1,1,1,1)
end

function GroundFlash:Draw()
  if (lasttexture ~= self.texture) then
    gl.Texture(self.texture)
    lasttexture=self.texture
  end
  gl.Color(self.color)

  local x1,z1,x2,z2 = self.pos[1]-self.size, self.pos[3]-self.size, self.pos[1]+self.size, self.pos[3]+self.size
  gl.DrawGroundQuad(x1,z1,x2,z2,false,true)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function GroundFlash:Initialize()
end

function GroundFlash:Finalize()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function GroundFlash:Update(n)
  if (self.life<1) then
    self.life     = self.life + n*self.life_incr
    self.size     = self.size + n*self.sizeGrowth
    local r,g,b,a = GetColor(self.colormap,self.life)
    self.color    = {r,g,b,a}
  end
  --cheap hack for mobility
  if self.mobile then
	local pos
	if self.unit then
		pos = {Spring.GetUnitPosition(self.unit)}
	elseif self.projectile then
		pos = {Spring.GetProjectilePosition(self.projectile)}
	end
	if pos[1] then
		self.pos = pos
	end
  end
end

-- used if repeatEffect=true;
function GroundFlash:ReInitialize()
  self.size     = self.csize
  self.life     = 0
  self.color    = self.colormap[1]

  self.dieGameFrame = self.dieGameFrame + self.clife
end

function GroundFlash:CreateParticle()
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

function GroundFlash:Destroy()
  --gl.DeleteTexture(self.texture)
end

function GroundFlash:Visible()
  if (self.unit) then
    return Spring.IsUnitVisible(self.unit)
  end
  local pos   = self.pos
  local radius= self.size*2.5
  return Spring.IsSphereInView(pos[1],pos[2],pos[3],radius)
end

function GroundFlash:Valid()
  if (self.unit) then
    return Spring.GetUnitTeam(self.unit)
  end
  return self:Visible()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function GroundFlash.Create(Options)
  local newObject = MergeTable(Options, GroundFlash.Default)
  setmetatable(newObject,GroundFlash)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return GroundFlash