-- $Id: gimmick1.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local ShieldSphereColorFallback = {}
ShieldSphereColorFallback.__index = ShieldSphereColorFallback

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereColorFallback.GetInfo()
  return {
    name      = "ShieldSphereColorFallback",
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

ShieldSphereColorFallback.Default = {
  pos        = {0,0,0},
  layer      = -24,
  life       = math.huge,
  repeatEffect = true,
  shieldSize = "large",
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereColorFallback:Visible()
	return self.visibleToMyAllyTeam
end

function ShieldSphereColorFallback:BeginDraw()
  gl.DepthMask(false)
  gl.Lighting(true)
  gl.Light(0, true )
  gl.Light(0, GL.POSITION, gl.GetSun() )
  gl.Light(0, GL.AMBIENT, gl.GetSun("ambient","unit") )
  gl.Light(0, GL.DIFFUSE, gl.GetSun("diffuse","unit") )
  gl.Light(0, GL.SPECULAR, gl.GetSun("specular") )
  --gl.Culling(GL.BACK)
end

function ShieldSphereColorFallback:EndDraw()
  gl.DepthMask(false)
  gl.Lighting(false)
  gl.Light(0, false)
end

function ShieldSphereColorFallback:Draw()
  local pos  = self.pos
  gl.Translate(pos[1],pos[2],pos[3])
  
  local col = GetShieldColor(self.unit, self)
  col[4] = col[4]*0.2
  
  gl.Color(1, 1, 1, 1)
  gl.Material({
    ambient   = {col[1], col[2], col[3], col[4]},
    diffuse   = {1,1,1,col[4]},
    specular  = {1,1,1,col[4]},
    shininess = 120,
  })

  gl.Scale(self.size, self.size, self.size)
  if self.texture then
    gl.Texture(self.texture)
  end
  gl.CallList(self.SphereList[self.shieldSize])
  if self.texture then
    gl.Texture(false)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereColorFallback:Initialize()
  ShieldSphereColorFallback.SphereList = {
    large = gl.CreateList(DrawSphere,0,0,0,1, 32),
    small = gl.CreateList(DrawSphere,0,0,0,1, 20),
  }
end

function ShieldSphereColorFallback:Finalize()
  for _, list in pairs(ShieldSphereColorFallback.SphereList) do
    gl.DeleteList(list)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereColorFallback:CreateParticle()
  self.dieGameFrame = Spring.GetGameFrame() + self.life
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereColorFallback:Update()
end

-- used if repeatEffect=true;
function ShieldSphereColorFallback:ReInitialize()
  self.dieGameFrame = self.dieGameFrame + self.life
end

function ShieldSphereColorFallback.Create(Options)
  local newObject = MergeTable(Options, ShieldSphereColorFallback.Default)
  setmetatable(newObject,ShieldSphereColorFallback)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function ShieldSphereColorFallback:Destroy()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return ShieldSphereColorFallback