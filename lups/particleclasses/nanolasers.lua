-- $Id: NanoLasers.lua 3357 2008-12-05 11:08:54Z jk $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local NanoLasers = {}
NanoLasers.__index = NanoLasers

local dlist
local laserShader

local knownNanoLasers = {}

local lastTexture = ""

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
function NanoLasers.GetInfo()
  return {
    name      = "NanoLasers",
    backup    = "NanoLasersNoShader", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = -16, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = false,
    shader    = true,
    rtt       = false,
    ctt       = false,
  }
end

NanoLasers.Default = {
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
  unitID    = -1,
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
local glMultiTexCoord   = gl.MultiTexCoord
local glVertex     = gl.Vertex
local glTranslate  = gl.Translate
local glMatrixMode = gl.MatrixMode
local glPushMatrix = gl.PushMatrix
local glPopMatrix  = gl.PopMatrix
local glBeginEnd   = gl.BeginEnd
local glUseShader  = gl.UseShader
local glAlphaTest  = gl.AlphaTest
local glCallList   = gl.CallList

local max  = math.max
local ceil = math.ceil

local ALL_ACCESS_TEAM = Script.ALL_ACCESS_TEAM

local spGetUnitBasePosition    = Spring.GetUnitBasePosition
local GetPositionLosState = Spring.GetPositionLosState
local GetCameraVectors    = Spring.GetCameraVectors
local IsSphereInView      = Spring.IsSphereInView

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoLasers:BeginDraw()
  glUseShader(laserShader)
  glBlending(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
  glAlphaTest(false)
end


function NanoLasers:EndDraw()
  glUseShader(0)
  glColor(1,1,1,1)
  glTexture(false)
  glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glAlphaTest(true)

  -- i hate that nv bug!
  glMultiTexCoord(0,0,0,0)
  glMultiTexCoord(1,0,0,0)
  glMultiTexCoord(2,0,0,0)
  glMultiTexCoord(3,0,0,0)

  lastTexture=""
end


function NanoLasers:Draw()
  if (lastTexture~=self.texture) then
    glTexture(self.texture)
    lastTexture=self.texture
  end

  local startPos = {self.pos[1],self.pos[2],self.pos[3]}
  local length   = self.length
  if (self.visibility<0) then
    startPos = Vadd(startPos,Vmul(self.dir,-self.visibility))
    length   = length * (1+self.visibility)
  else
    length   = length * self.visibility
  end
  local color = self.color
  local ndir  = self.normdir

  glColor(color[1],color[2],color[3],0.003)
  glMultiTexCoord(0,ndir[1],ndir[2],ndir[3],1)
  glMultiTexCoord(1,startPos[1],startPos[2],startPos[3],length)

  if (self.inversed) then
    glMultiTexCoord(2,  (thisGameFrame%self.streamSpeed)/self.streamSpeed, self.streamThickness, self.corealpha, self.corethickness)
  else
    glMultiTexCoord(2, -(thisGameFrame%self.streamSpeed)/self.streamSpeed, self.streamThickness, self.corealpha, self.corethickness)
  end

  glCallList(dlist)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoLasers:Update(n)
  if (self.allyID==LocalAllyTeamID)or(LocalAllyTeamID==ALL_ACCESS_TEAM) then
    self.visibility = 1
  end

  local endPos = Vadd(self.pos,self.dir)
  local _,startLos = GetPositionLosState(self.pos[1],self.pos[2],self.pos[3], LocalAllyTeamID)
  local _,endLos   = GetPositionLosState(  endPos[1],  endPos[2],  endPos[3], LocalAllyTeamID)

  self.visibility = 0
  if (not startLos)and(not endLos) then
    self.visibility = 0
  elseif (startLos and endLos) then
    self.visibility = 1
  elseif (startLos) then
    local losRayTile = ceil(Vlength(self.dir)/Game.squareSize)
    for i=losRayTile,0,-1 do
      local losPos = Vadd(self.pos,Vmul(self.dir,i/losRayTile))
      local _,los = GetPositionLosState(losPos[1],losPos[2],losPos[3], LocalAllyTeamID)
      if (los) then self.visibility = i/losRayTile; break end
    end
  else --//if (endLos) then
    local losRayTile = ceil(Vlength(self.dir)/Game.squareSize)
    for i=0,losRayTile do
      local losPos = Vadd(self.pos,Vmul(self.dir,i/losRayTile))
      local _,los  = GetPositionLosState(losPos[1],losPos[2],losPos[3], LocalAllyTeamID)
      if (los) then self.visibility = -i/losRayTile; break end
    end
  end
end

-- used if repeatEffect=true;
function NanoLasers:ReInitialize()
  self.dieGameFrame = self.dieGameFrame + self.life
end

function NanoLasers:Visible()
  if (self.allyID~=LocalAllyTeamID)and(not spGetUnitBasePosition(self.unitID)) then
    return false
  end
  local half_dir = Vmul(self.dir,0.5)
  local midPos   = Vadd(self.pos,half_dir)
  local radius   = Vlength(half_dir)+200
  return IsSphereInView(midPos[1],midPos[2],midPos[3],radius)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoLasers:Initialize()
  laserShader = gl.CreateShader({
    vertex = [[
      //gl.MultiTexCoord(0,emitVector[1],emitVector[2],emitVector[3],1.0)
      //gl.MultiTexCoord(1,startPos[1],startPos[2],startPos[3],length)
      //gl.MultiTexCoord(2,streamTranslate, streamThickness, coreAlpha, coreThickness)
      //gl.MultiTexCoord(3,isCore)
      //gl.Color(color[1],color[2],color[3])
      //gl.vertex.xy := length,width
      //gl.vertex.zw := texcoord

      #define emitVector       gl_MultiTexCoord0
      #define length           gl_MultiTexCoord1.w
      #define startpos         vec4(gl_MultiTexCoord1.xyz,0.0)
      #define streamTranslate  gl_MultiTexCoord2.x
      #define streamThickness  gl_MultiTexCoord2.y
      #define coreAlpha        gl_MultiTexCoord2.z
      #define coreThickness    gl_MultiTexCoord2.w
      #define isCore           gl_MultiTexCoord3.x

      varying vec3 texCoord;

      const vec4 centerPos = vec4(0.0,0.0,0.0,1.0);

      void main()
      {
        texCoord =  vec3(gl_Vertex.z + streamTranslate, gl_Vertex.w, gl_Vertex.z);
        gl_Position    = (gl_ModelViewMatrix * (centerPos + startpos));
        vec3 dir3      = (gl_ModelViewMatrix * (emitVector + startpos)).xyz - gl_Position.xyz;
        vec3 v = normalize( dir3 );
        vec3 w = normalize( -gl_Position.xyz );
        vec3 u = normalize( cross(w,v) );

        if (isCore>0.0) {
          gl_Position.xyz += (gl_Vertex.x * length) * v + (gl_Vertex.y * coreThickness) * u;
          gl_FrontColor.rgb = vec3(coreAlpha);
          gl_FrontColor.a   = 0.003;
        }else{
          gl_Position.xyz += (gl_Vertex.x * length) * v + (gl_Vertex.y * streamThickness) * u;
          gl_FrontColor = gl_Color;
        }

        gl_Position      = gl_ProjectionMatrix * gl_Position;
      }
    ]],
    fragment = [[
      uniform sampler2D tex0;

      varying vec3 texCoord;

      void main()
      {
         gl_FragColor = texture2D(tex0, texCoord.st) * gl_Color;
         if (texCoord.p>0.95) gl_FragColor *= vec4(1.0 - texCoord.p) * 20.0;
         if (texCoord.p<0.05) gl_FragColor *= vec4(texCoord.p) * 20.0;
      }
    ]],
    uniformInt = {
      tex0=0,
    }
  })


  if (laserShader == nil) then
    print(PRIO_MAJOR,"LUPS->nanoLaserShader: shader error: "..gl.GetShaderLog())
    return false
  end

  dlist = gl.CreateList(glBeginEnd,GL_QUADS,function()
    glMultiTexCoord(3,0)
    glVertex(1,-1, 1,0)
    glVertex(0,-1, 0,0)
    glVertex(0, 1, 0,1)
    glVertex(1, 1, 1,1)

    glMultiTexCoord(3,1)
    glVertex(1,-1, 1,0)
    glVertex(0,-1, 0,0)
    glVertex(0, 1, 0,1)
    glVertex(1, 1, 1,1)
  end)
end

function NanoLasers:Finalize()
  if (gl.DeleteShader) then
    gl.DeleteShader(laserShader)
  end
  gl.DeleteList(dlist)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoLasers:CreateParticle()
  self.life           = self.life + 1 --// so we can reuse existing fx's
  self.firstGameFrame = thisGameFrame
  self.dieGameFrame   = self.firstGameFrame + self.life

  self.length     = Vlength(self.dir)
  self.normdir    = Vmul( self.dir, 1/self.length )
  self.visibility = 0
  self:Update(0) --//update los
  if (self:Visible()) then self.visible = true end --// include the fx into the render-pipeline, even if the visibility-check was already done

  if (self.streamThickness<0) then
    self.streamThickness = 4+self.count*0.34
  end

  if (self.flare) then
    --[[if you add those flares, then the laser is slower as the engine, so it needs some tweaking]]--
    if (self.flare1id and particles[self.flare1id] and particles[self.flare2id]) then
      local flare1 = particles[self.flare1id]
      CopyVector(flare1.pos,self.pos,3)
      flare1.size  = self.count*0.1
      flare1:ReInitialize()
      local flare2 = particles[self.flare2id]
      CopyVector(flare2.pos,self.pos,3)
      flare2.size  = self.count*0.75
      flare2:ReInitialize()
      return
    end
    local r,g,b = max(self.color[1],0.13),max(self.color[2],0.13),max(self.color[3],0.13)
    local flare = {
      layer       = self.layer,
      pos         = self.pos,
      life        = 31,
      size        = self.count*0.1,
      sizeSpread  = 1,
      sizeGrowth  = 0.1,
      colormap    = { {r*2,g*2,b*2,0.01},{r*2,g*2,b*2,0.01},{r*2,g*2,b*2,0.01} },
      texture     = 'bitmaps/GPL/groundflash.tga',
      count       = 2,
      repeatEffect = false,
    }
    self.flare1id  = AddParticles("StaticParticles",flare)
    flare.size     = self.count*0.75
    flare.texture  = 'bitmaps/flare.tga'
    flare.colormap = { {r*2,g*2,b*2,0.009},{r*2,g*2,b*2,0.009},{r*2,g*2,b*2,0.009} }
    flare.count    = 2
    self.flare2id  = AddParticles("StaticParticles",flare)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoLasers.Create(Options)
  local unit,nanopiece=Options.unitID,Options.nanopiece
  if (unit and nanopiece)and(knownNanoLasers[unit])and(knownNanoLasers[unit][nanopiece]) then
    local reuseFx = knownNanoLasers[unit][nanopiece]
    CopyTable(reuseFx,Options)
    reuseFx:CreateParticle()
    return false,reuseFx.id
  else
    local newObject = MergeTable(Options, NanoLasers.Default)
    setmetatable(newObject,NanoLasers)  -- make handle lookup
    newObject:CreateParticle()

    if (unit and nanopiece) then
      if (not knownNanoLasers[unit]) then
        knownNanoLasers[unit] = {}
      end
      knownNanoLasers[unit][nanopiece] = newObject
    end

    return newObject
  end
end

function NanoLasers:Destroy()
  local unit,nanopiece=self.unitID,self.nanopiece
  knownNanoLasers[unit][nanopiece] = nil
  if (not next(knownNanoLasers[unit])) then
    knownNanoLasers[unit] = nil
  end

  if (self.flare) then
    RemoveParticles(self.flare1id)
    RemoveParticles(self.flare2id)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return NanoLasers