-- $Id: Ribbons.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local Ribbon = {}
Ribbon.__index = Ribbon

local RibbonShader
local widthLoc, quadsLoc
local oldPosUniform = {}
local lastTexture

local DLists = {}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function Ribbon.GetInfo()
  return {
    name      = "Ribbon",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 1, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = false,
    shader    = true,
    rtt       = false,
    ctt       = false,
  }
end

Ribbon.Default = {
  layer = 1,

  life     = math.huge,
  unit     = nil,
  projectile=nil,
  piece    = 0,
  width    = 1,
  size     = 24, --//max 256
  color    = {0.9,0.9,1,1},
  texture  = "bitmaps/GPL/Lups/jet.bmp",
  decayRate = 0.01,

  worldspace = true,
  repeatEffect = true,
  dieGameFrame = math.huge,
  
  isvalid = true,
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local spGetUnitDefID         = Spring.GetUnitDefID
local spGetUnitIsDead        = Spring.GetUnitIsDead
local spIsUnitValid          = Spring.IsUnitValid
local spIsSphereInView       = Spring.IsSphereInView
local spGetUnitVelocity      = Spring.GetUnitVelocity
local spGetUnitPiecePosition = Spring.GetUnitPiecePosition
local spGetUnitViewPosition  = Spring.GetUnitViewPosition
local spGetUnitPiecePosDir   = Spring.GetUnitPiecePosDir
local spGetUnitVectors       = Spring.GetUnitVectors
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local glUniform    = gl.Uniform
local glUniformInt = gl.UniformInt
local glUseShader  = gl.UseShader
local glColor      = gl.Color
local glCallList   = gl.CallList
local glTexture    = gl.Texture
local glBlending   = gl.Blending
local GL_ONE = GL.ONE
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local function GetPiecePos(unit,piece)
  local x,y,z = spGetUnitViewPosition(unit,false)
  local front,up,right = spGetUnitVectors(unit)
  local px,py,pz = spGetUnitPiecePosition(unit,piece)
  return x + (pz*front[1] + py*up[1] + px*right[1]),
         y + (pz*front[2] + py*up[2] + px*right[2]),
         z + (pz*front[3] + py*up[3] + px*right[3])
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function Ribbon:BeginDraw()
  glUseShader(RibbonShader)
  glBlending(GL_SRC_ALPHA,GL_ONE)
end


function Ribbon:EndDraw()
  glUseShader(0)
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glTexture(0,false)
  lastTexture = nil
  glColor(1,1,1,1)
end


function Ribbon:Draw()
  
  local quads0 = self.quads0
  if self.texture ~= lastTexture then
	glTexture(0,":c:"..self.texture)
	lastTexture = self.texture
  end
  glUniform(widthLoc, self.width )
  glUniformInt(quadsLoc, quads0 )

  --// insert old pos
  local j = ((self.posIdx==self.size) and 1) or (self.posIdx+1)
  for i=1,quads0 do
    local dir = self.oldPos[j]
    j = ((j==self.size) and 1) or (j+1)
    glUniform( oldPosUniform[i] , dir[1], dir[2], dir[3] )
  end

  --// insert interpolated current unit pos
  if (self.isvalid) then
    --local x,y,z = GetPiecePos(self.unit,self.piecenum)
    local x,y,z
    if self.unit then
      x,y,z = spGetUnitPiecePosDir(self.unit,self.piecenum)
    elseif self.projectile then
      x,y,z = spGetProjectilePosition(self.projectile)
    end
    if x and y and z then 
      glUniform( oldPosUniform[quads0+1] , x,y,z )
    end
  else
    local dir = self.oldPos[j]
    glUniform( oldPosUniform[quads0+1] , dir[1], dir[2], dir[3] )
  end

  --// define color and add speed blending (don't show ribbon for slow/landing units!)
  if (self.blendfactor<1) then
    local clr = self.color
    glColor(clr[1],clr[2],clr[3],clr[4]*self.blendfactor)
  else
    glColor(self.color)
  end
  glCallList(DLists[quads0])
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function Ribbon.Initialize()
  RibbonShader = gl.CreateShader({
    vertex = [[
      uniform float width;
      uniform int   quads;
      uniform vec3  oldPos[256];

      varying vec2 texCoord;

      void main()
      {
         vec3 updir,right;
         vec3 vertex = oldPos[int(gl_MultiTexCoord0.w)];
         gl_Position = gl_ModelViewMatrix * vec4(vertex,1.0);

         vec3 vertex2,pos2;
         if (int(gl_MultiTexCoord0.w) == quads) {
           vertex2 = oldPos[int(gl_MultiTexCoord0.w)-1];
           pos2   = (gl_ModelViewMatrix * vec4(vertex2,1.0)).xyz;
           updir = gl_Position.xyz - pos2.xyz;
         }else{
           vertex2 = oldPos[int(gl_MultiTexCoord0.w)+1];
           pos2   = (gl_ModelViewMatrix * vec4(vertex2,1.0)).xyz;
           updir = pos2.xyz - gl_Position.xyz;
         }

         right = normalize( cross(updir,gl_Position.xyz) );

         gl_Position.xyz += right * gl_MultiTexCoord0.x * width;
         gl_Position    = gl_ProjectionMatrix * gl_Position;

         texCoord      = gl_MultiTexCoord0.pt;
         gl_FrontColor = gl_Color;
      }
    ]],
    fragment = [[
      uniform sampler2D ribbonTex;

      varying vec2 texCoord;

      void main()
      {
         gl_FragColor = texture2D(ribbonTex, texCoord )*gl_Color;
      }
    ]],
    uniformInt={
      ribbonTex = 0,
    },
  })

  if (RibbonShader == nil) then
    print(PRIO_MAJOR,"LUPS->Ribbon: critical shader error: "..gl.GetShaderLog())
    return false
  end

  widthLoc = gl.GetUniformLocation(RibbonShader, 'width')
  quadsLoc = gl.GetUniformLocation(RibbonShader, 'quads')

  for i=1,256 do
    oldPosUniform[i] = gl.GetUniformLocation(RibbonShader,"oldPos["..(i-1).."]")
  end
end


function Ribbon.Finalize()
  if (gl.DeleteShader) then
    gl.DeleteShader(RibbonShader)
  end

  while (next(DLists)) do
    local i,v = next(DLists)
    DLists[i] = nil
    gl.DeleteList(v)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function Ribbon:Update(n)
  self.isvalid = (self.unit and spGetUnitIsDead(self.unit) == false) or (self.projectile and Spring.GetProjectileDefID(self.projectile))
  if (self.isvalid) then
    local x,y,z
    if self.unit then
      x, y, z = spGetUnitPiecePosDir(self.unit,self.piecenum)
    elseif self.projectile then
      x,y,z = spGetProjectilePosition(self.projectile)
    end
    if x and y and z then
      self.posIdx = (self.posIdx % self.size)+1
      self.oldPos[self.posIdx] = {x,y,z}

      local vx,vy,vz
      if self.unit then
	vx, vy, vz = spGetUnitVelocity(self.unit)
      elseif self.projectile then
	vx, vy, vz = spGetProjectileVelocity(self.projectile)
      end
      if vx and vy and vz then
	self.blendfactor = (vx*vx+vy*vy+vz*vz)/30
      end
    end
  else
    local lastIndex = self.posIdx 
    self.posIdx = (self.posIdx % self.size)+1
    self.oldPos[self.posIdx] = self.oldPos[lastIndex]
    
    self.blendfactor = self.blendfactor - n * self.decayRate
  end
end


function Ribbon:Visible()
  self.isvalid = (self.unit and spGetUnitIsDead(self.unit) == false) or (self.projectile and Spring.GetProjectileDefID(self.projectile))
  local pos = self.oldPos[self.posIdx]
  return (self.blendfactor>0) and (spIsSphereInView(pos[1],pos[2],pos[3], self.radius))
end


function Ribbon:Valid()
  return self.isvalid or (self.blendfactor>0)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local function CreateDList(quads0)
  for i=0,quads0-1 do
    local tex_t      = i/quads0
    local tex_t_next = (i+1)/quads0

    gl.TexCoord(-1,tex_t_next,0,i+1)
    gl.Vertex(0,0,0)
    gl.TexCoord(1,tex_t_next,1,i+1)
    gl.Vertex(0,0,0)
    gl.TexCoord(1,tex_t,1,i)
    gl.Vertex(0,0,0)
    gl.TexCoord(-1,tex_t,0,i)
    gl.Vertex(0,0,0)
  end
end


-- used if repeatEffect=true;
function Ribbon:ReInitialize()
  self.dieGameFrame = self.dieGameFrame + self.life
end


function Ribbon:CreateParticle()
  if (self.size>256) then self.size=256
  elseif (self.size<2) then self.size=2 end

  self.posIdx = 1
  self.quads0 = self.size-1
  self.blendfactor = 1

  local x,y,z 
  if self.unit then
    x,y,z = spGetUnitPiecePosDir(self.unit,self.piecenum)
  elseif self.projectile then
	x,y,z = spGetProjectilePosition(self.projectile)
  end
  local curpos = {x,y,z}

  self.oldPos = {}
  for i=1,self.size do
    self.oldPos[i] = curpos
  end

  local udid  = self.unit and spGetUnitDefID(self.unit)
  local weapon = self.weapon
  local speed = self.speed or (UnitDefs[udid] and UnitDefs[udid].speed) or (weapon and WeaponDefs[weapon] and WeaponDefs[weapon].projectilespeed*30) or 100
  self.radius = (speed/30.0)*self.size

  if (not DLists[self.quads0]) then
    DLists[self.quads0] = gl.CreateList(gl.BeginEnd,GL.QUADS,CreateDList,self.quads0)
  end

  self.startGameFrame = thisGameFrame
  self.dieGameFrame   = self.startGameFrame + self.life
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local MergeTable   = MergeTable
local setmetatable = setmetatable

function Ribbon.Create(Options)
  local newObject = MergeTable(Options, Ribbon.Default)
  setmetatable(newObject,Ribbon)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function Ribbon:Destroy()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return Ribbon