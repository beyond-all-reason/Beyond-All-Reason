-- $Id: NanoLasersNoShader.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local NanoLasersNoShader = {}
NanoLasersNoShader.__index = NanoLasersNoShader

local cam_up
local knownNanoLasersNoShader = {}

local lastTexture = ""

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
function NanoLasersNoShader.GetInfo()
  return {
    name      = "NanoLasersNoShader",
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

NanoLasersNoShader.Default = {
  layer        = 0,
  worldspace   = true,
  repeatEffect = false,

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
  life         = 30,

  --// some unit informations
  targetID  = -1,
  unitID    = -1,
  unitpiece = -1,
  unitDefID = -1,
  teamID    = -1,
  allyID    = -1,

  --// custom (user) options
  flare           = false,
  streamSpeed     = 10,
  streamThickness = -1,  --//streamThickness =  4+self.count*0.34,
  corethickness   = 1,
  corealpha       = 1,
  texture         = "bitmaps/largelaserfalloff.tga",
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

--//speed ups

local GL_ONE       = GL.ONE
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_QUADS     = GL.QUADS
local GL_TEXTURE   = GL.TEXTURE
local GL_MODELVIEW = GL.MODELVIEW

local glColor      = gl.Color
local glTexture    = gl.Texture
local glBlending   = gl.Blending
local glTexCoord   = gl.TexCoord
local glVertex     = gl.Vertex
local glTranslate  = gl.Translate
local glMatrixMode = gl.MatrixMode
local glPushMatrix = gl.PushMatrix
local glPopMatrix  = gl.PopMatrix
local glBeginEnd   = gl.BeginEnd

local max  = math.max

local GetCameraVectors    = Spring.GetCameraVectors
local IsSphereInView      = Spring.IsSphereInView

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoLasersNoShader:BeginDraw()
  glBlending(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
  cam_up = GetCameraVectors().forward
end

function NanoLasersNoShader:EndDraw()
  glColor(1,1,1,1)
  glTexture(false)
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

  lastTexture=""
end

local function DrawNanoLasersNoShader(dir,dir_upright,visibility,streamThickness,core_alpha,core_thickness)
  local startF,endF = 0,1
  if (visibility==0)
    then startF=-visibility
    else endF  = visibility end

  local start_dir = Vmul(dir,startF)
  local   end_dir = Vmul(dir,endF)

  local dir_upright1 = Vmul(dir_upright,streamThickness)

  glTexCoord(0,0)
  glVertex(start_dir[1]+dir_upright1[1],start_dir[2]+dir_upright1[2],start_dir[3]+dir_upright1[3])
  glTexCoord(0,1)
  glVertex(start_dir[1]-dir_upright1[1],start_dir[2]-dir_upright1[2],start_dir[3]-dir_upright1[3])
  glTexCoord(1,1)
  glVertex(end_dir[1]-dir_upright1[1],end_dir[2]-dir_upright1[2],end_dir[3]-dir_upright1[3])
  glTexCoord(1,0)
  glVertex(end_dir[1]+dir_upright1[1],end_dir[2]+dir_upright1[2],end_dir[3]+dir_upright1[3])

  glColor(core_alpha,core_alpha,core_alpha,0.003)
  dir_upright = Vmul(dir_upright,core_thickness)

  glTexCoord(0,0)
  glVertex(start_dir[1]+dir_upright[1],start_dir[2]+dir_upright[2],start_dir[3]+dir_upright[3])
  glTexCoord(0,1)
  glVertex(start_dir[1]-dir_upright[1],start_dir[2]-dir_upright[2],start_dir[3]-dir_upright[3])
  glTexCoord(1,1)
  glVertex(end_dir[1]-dir_upright[1],end_dir[2]-dir_upright[2],end_dir[3]-dir_upright[3])
  glTexCoord(1,0)
  glVertex(end_dir[1]+dir_upright[1],end_dir[2]+dir_upright[2],end_dir[3]+dir_upright[3])
end

function NanoLasersNoShader:Draw()
  if (lastTexture~=self.texture) then
    glTexture(self.texture)
    lastTexture=self.texture
  end

  glPushMatrix()
  glTranslate(self.pos[1],self.pos[2],self.pos[3])

    glMatrixMode(GL_TEXTURE)
    glPushMatrix()
      if (self.inversed) then
        glTranslate(  (thisGameFrame+Spring.GetFrameTimeOffset())*self.streamSpeed, 0,0)
      else
        glTranslate( -(thisGameFrame+Spring.GetFrameTimeOffset())*self.streamSpeed, 0,0)
      end

      local dir_upright = Vcross(self.normdir,cam_up)

      local color = self.color
      glColor(color[1],color[2],color[3],0.003)
      glBeginEnd(GL_QUADS,DrawNanoLasersNoShader,self.dir,dir_upright,self.visibility,self.streamThickness,self.corealpha,self.corethickness)

    glPopMatrix()
    glMatrixMode(GL_MODELVIEW)

  glPopMatrix()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoLasersNoShader:Update(n)
  UpdateNanoParticles(self)

  if (self._dead) then
    RemoveParticles(self.id)
  end
end

-- used if repeatEffect=true;
function NanoLasersNoShader:ReInitialize()
  self.dieGameFrame = self.dieGameFrame + self.life
end

function NanoLasersNoShader:Visible()
  if (self.allyID ~= LocalAllyTeamID)and(self.visibility == 0) then
    return false
  end

  local midPos = self._midpos
  return IsSphereInView(midPos[1],midPos[2],midPos[3], self._radius)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoLasersNoShader:Initialize()
end

function NanoLasersNoShader:Finalize()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoLasersNoShader:CreateParticle()
  self.life           = self.life + 1 --// so we can reuse existing fx's
  self.firstGameFrame = thisGameFrame
  self.dieGameFrame   = self.firstGameFrame + self.life

  self.visibility = 0
  self:Update(0) --//update los

  if (self.streamThickness<0) then
    self.streamThickness = 4+self.count*0.34
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoLasersNoShader.Create(Options)
  local unit,nanopiece=Options.unitID,Options.nanopiece
  if (unit and nanopiece)and(knownNanoLasersNoShader[unit])and(knownNanoLasersNoShader[unit][nanopiece]) then
    local reuseFx = knownNanoLasersNoShader[unit][nanopiece]
    CopyTable(reuseFx,Options)
    reuseFx:CreateParticle()
    return false,reuseFx.id
  else
    local newObject = MergeTable(Options, NanoLasersNoShader.Default)
    setmetatable(newObject,NanoLasersNoShader)  -- make handle lookup
    newObject:CreateParticle()

    if (unit and nanopiece) then
      if (not knownNanoLasersNoShader[unit]) then
        knownNanoLasersNoShader[unit] = {}
      end
      knownNanoLasersNoShader[unit][nanopiece] = newObject
    end
    return newObject
  end
end

function NanoLasersNoShader:Destroy()
  local unit,nanopiece=self.unitID,self.nanopiece
  knownNanoLasersNoShader[unit][nanopiece] = nil
  if (not next(knownNanoLasersNoShader[unit])) then
    knownNanoLasersNoShader[unit] = nil
  end

  if (self.flare) then
    RemoveParticles(self.flare1id)
    RemoveParticles(self.flare2id)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return NanoLasersNoShader