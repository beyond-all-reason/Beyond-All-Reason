-- $Id: Bursts.lua 4099 2009-03-16 05:18:45Z jk $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

-- todo: burst .rotArc length (in DisplayList creation)

local Bursts = {}
Bursts.__index = Bursts
local checkStunned = true

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
function Bursts.GetInfo()
  return {
    name      = "Bursts",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = -16, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = false,
    shader    = false,
    rtt       = false,
    ctt       = false,
  }
end

Bursts.Default = {
  lists = {},

  pos        = {0,0,0}, -- start pos
  layer      = -16,

  life       = 0,
  lifeSpread = 0,

  rotSpeed   = 0,
  rotSpread  = 0,
  rotairdrag = 1,

  arc        = 60,
  arcSpread  = 0,

  size       = 0,
  sizeSpread = 0,
  sizeGrowth = 0,
  colormap   = { {0, 0, 0, 0} },

  directional= false, -- This option only looks good in combination with a sphere. So you can do sunburst effects with it.

  srcBlend   = GL.SRC_ALPHA,
  dstBlend   = GL.ONE_MINUS_SRC_ALPHA,
  texture    = 'bitmaps/GPL/Lups/sunburst.png',
  count      = 0,
  repeatEffect = false,
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function Bursts:InitializePartList(partList)
  partList.rotspeed = self.rotSpeed
  partList.size     = self.size
  partList.life     = 0
  local r,g,b,a     = GetColor(self.colormap,partList.life)
  partList.color    = {r,g,b,a}
  partList.arc      = self.arc
  partList.rotArc   = 0
  partList.start_pos= self.pos

  -- spread values
  if (self.sizeSpread>0)  then partList.size    = partList.size     + math.random(self.sizeSpread*100)/100 end
  if (self.rotSpread>0)   then partList.rotspeed= partList.rotspeed + math.random(self.rotSpread*100)/100 end
  if (self.arcSpread>0)   then partList.arc     = partList.arc + math.random(self.arc) end
  local rand = 0
  if (self.lifeSpread>0) then rand = math.random(self.lifeSpread) end
  partList.life_incr = 1/(self.life+rand)

  -- create rotation up vector
  partList.rotv = {((-1)^math.random(2,3))*math.random(),((-1)^math.random(2,3))*math.random(),((-1)^math.random(2,3))*math.random()}
  local  length = math.sqrt(partList.rotv[1]^2+partList.rotv[2]^2+partList.rotv[3]^2)
  partList.rotv = {partList.rotv[1]/length,partList.rotv[2]/length,partList.rotv[3]/length}
end

function Bursts:UpdatePartList(partList,n)
  local rotBoost = 0
  for i=1,n do rotBoost = rotBoost + partList.rotspeed*(self.rotairdrag^i) end

  partList.rotspeed = partList.rotspeed*(self.rotairdrag^n)
  partList.rotArc   = partList.rotArc*(self.rotairdrag^n) + rotBoost
  partList.size     = partList.size  + n*self.sizeGrowth
  partList.life     = partList.life  + n*partList.life_incr
  local r,g,b,a     = GetColor(self.colormap,partList.life)
  partList.color    = {r,g,b,a }
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local lasttexture = nil

function Bursts:BeginDraw()
  lasttexture = nil
end

function Bursts:EndDraw()
  gl.Texture(false)
  gl.Color(1,1,1,1)
  gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end

function Bursts:Draw()
  if checkStunned then
    self.stunned = Spring.GetUnitIsStunned(self.unit)
  end
  if self.stunned then
    return
  end
  if (lasttexture ~= self.texture) then
    gl.Texture(self.texture)
    lasttexture = self.texture
  end
  gl.Blending(self.srcBlend,self.dstBlend)
  gl.PushMatrix()
  gl.Translate(self.pos[1],self.pos[2],self.pos[3])

  local partList
  for i=1,#self.lists do
      partList = self.lists[i]
      local rotv = partList.rotv
      local size = partList.size

      gl.Color(partList.color)

      gl.PushMatrix()
        gl.Rotate(partList.rotArc,rotv[1],rotv[2],rotv[3])
        gl.Scale(size,size,size)
        gl.CallList(partList.dlist)
      gl.PopMatrix()
  end

  gl.PopMatrix()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local function rotateVector(vector,axis,phi)
  local rcos = math.cos(math.pi*phi/180);
  local rsin = math.sin(math.pi*phi/180);
  local u,v,w = axis[1],axis[2],axis[3];
  local matrix = {};
  matrix[0],matrix[1],matrix[2] = {},{},{};

  matrix[0][0] =      rcos + u*u*(1-rcos);
  matrix[1][0] =  w * rsin + v*u*(1-rcos);
  matrix[2][0] = -v * rsin + w*u*(1-rcos);
  matrix[0][1] = -w * rsin + u*v*(1-rcos);
  matrix[1][1] =      rcos + v*v*(1-rcos);
  matrix[2][1] =  u * rsin + w*v*(1-rcos);
  matrix[0][2] =  v * rsin + u*w*(1-rcos);
  matrix[1][2] = -u * rsin + v*w*(1-rcos);
  matrix[2][2] =      rcos + w*w*(1-rcos);

  local x,y,z = vector[1],vector[2],vector[3];

  return x * matrix[0][0] + y * matrix[0][1] + z * matrix[0][2],
         x * matrix[1][0] + y * matrix[1][1] + z * matrix[1][2],
         x * matrix[2][0] + y * matrix[2][1] + z * matrix[2][2];
end

local glTexCoord = gl.TexCoord
local glVertex = gl.Vertex

function DrawBurstVertices(rotv,directional,arc, alpha,beta,gamma)
      glTexCoord(1,1)
    glVertex(0,0,0)
      glTexCoord(0,1)
    glVertex(alpha,beta,gamma)

    if (directional) then
      local n = arc
      local t, t_inc = 0, 1/n
      local v,u,w = alpha,beta,gamma
      while (n>=45) do
        v,u,w = rotateVector({v,u,w},rotv,45)
          glTexCoord(0,1-t)
        glVertex(v,u,w)
        n = n-45
        t = t + t_inc*45
      end
      if (n>0) then
        v,u,w = rotateVector({v,u,w},rotv,n)
          glTexCoord(0,0)
        glVertex(v,u,w)
      end
    else
      local v,u,w = alpha,gamma,beta  -- 'random' movement of the burst
        glTexCoord(0,0)
      glVertex(v,u,w)
    end

end

local glBeginEnd = gl.BeginEnd
local GL_TRIANGLE_FAN = GL.TRIANGLE_FAN
local rand = math.random

local function DrawBurst(rotv,directional,arc)
  -- we need a orthognalized vector to the rotation vector "rotv"
    -- random vector
    local alpha = rand()-rand()
    local beta  = rand()-rand()
    local gamma = rand()-rand()

    -- gram-schmidt
    local proj = (rotv[1]*alpha + rotv[2]*beta + rotv[3]*gamma) / (rotv[1]^2 + rotv[2]^2 + rotv[3]^2)
    alpha = alpha-rotv[1]*proj
    beta  = beta-rotv[2]*proj
    gamma = gamma-rotv[3]*proj

    -- normalization
    local length = math.sqrt(alpha*alpha+beta*beta+gamma*gamma)
    alpha = alpha/length
    beta  = beta/length
    gamma = gamma/length

  glBeginEnd(GL_TRIANGLE_FAN, DrawBurstVertices, rotv,directional,arc, alpha,beta,gamma)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local time = 0
function Bursts:Update(n)
  time = time + n
  if time > 40 then
    checkStunned = true
    time = 0
  else
    checkStunned = false
  end

  local l = self.lists
  for i=1,#l do
    local partList = l[i]
    if (partList.life<1) then
      self:UpdatePartList(partList,n)
    end
  end
end

-- used if repeatEffect=true;
function Bursts:ReInitialize()
  for _,partList in ipairs(self.lists) do
    partList.life = 0
    -- self:InitializePartList(partList)
  end
  self.dieGameFrame = self.dieGameFrame + self.life + self.lifeSpread
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function Bursts:Initialize()
end

function Bursts:Finalize()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function Bursts:CreateParticle()
  for i=1,self.count do
    local newPartList = {}
    self:InitializePartList(newPartList)
    newPartList.dlist = gl.CreateList( DrawBurst ,newPartList.rotv,self.directional,newPartList.arc)
    table.insert(self.lists,newPartList)
  end

  self.firstGameFrame = thisGameFrame
  self.dieGameFrame   = self.firstGameFrame + self.life + self.lifeSpread
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function Bursts.Create(Options)
  local newObject = MergeTable(Options, Bursts.Default)
  setmetatable(newObject,Bursts)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function Bursts:Destroy()
  for _,partList in ipairs(self.lists) do
    gl.DeleteList(partList.dlist)
  end
  --gl.DeleteTexture(self.texture)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return Bursts