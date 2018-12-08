-- $Id: NanoLasers.lua 3357 2008-12-05 11:08:54Z jk $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local NanoLasers = {}
NanoLasers.__index = NanoLasers

local dlist
local laserShader

local knownNanoLasers = {}

local lastTexture = ""
local enableLights = true

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
  pos          = {0,0,0}, --// start pos
  targetpos    = {0,0,0},
  targetradius = 0,       --// terraform/unit radius
  color        = {0, 0, 0, 0},
  count        = 1,
  unit         = -1,
  nanopiece    = -1,

  --// some unit informations
  targetID  = -1,
  unitID    = -1,
  unitpiece = -1,
  unitDefID = -1,
  teamID    = -1,
  allyID    = -1,

  --// custom (user) options
  life            = 30,
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

  local color = self.color
  local startPos = self.pos
  local endPos   = self.targetpos

  glColor(color[1],color[2],color[3],0.0003)
  glMultiTexCoord(0,endPos[1] - self.normdir[3] * self.scane_mult ,endPos[2],endPos[3] + self.normdir[1] * self.scane_mult,1)
  glMultiTexCoord(1,startPos[1],startPos[2],startPos[3],1)

  if (self.type == 'building' or self.type == 'repair') then
    glTexture('bitmaps/projectiletextures/nanobeam-build.tga')
    glMultiTexCoord(2, -(thisGameFrame+Spring.GetFrameTimeOffset())*self.streamSpeed, self.streamThickness, self.corealpha, self.corethickness)
  elseif (self.type == 'reclaim') then
    glTexture('bitmaps/projectiletextures/nanobeam-reclaim.png')
    glMultiTexCoord(2,  (thisGameFrame+Spring.GetFrameTimeOffset())*self.streamSpeed, self.streamThickness/2, self.corealpha, self.corethickness/2)
  elseif (self.type == 'restore') then
    glTexture('bitmaps/projectiletextures/nanobeam-capture.png')
    glMultiTexCoord(2,  (thisGameFrame+Spring.GetFrameTimeOffset())*self.streamSpeed, self.streamThickness/2, self.corealpha, self.corethickness/2)
  elseif (self.type == 'resurrect') then
    glTexture('bitmaps/projectiletextures/nanobeam-resurrect.png')
    glMultiTexCoord(2,  (thisGameFrame+Spring.GetFrameTimeOffset())*self.streamSpeed, self.streamThickness/2.5, self.corealpha, self.corethickness/2.5)
  elseif (self.type == 'capture') then
    glTexture('bitmaps/projectiletextures/nanobeam-capture.png')
    glMultiTexCoord(2,  (thisGameFrame+Spring.GetFrameTimeOffset())*self.streamSpeed, self.streamThickness/2, self.corealpha, self.corethickness/2)
  else
    glTexture('bitmaps/projectiletextures/nanobeam-build.tga')
    glMultiTexCoord(2, -(thisGameFrame+Spring.GetFrameTimeOffset())*self.streamSpeed, self.streamThickness, self.corealpha, self.corethickness)
  end

  glCallList(dlist)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoLasers:Update(n)
  if not self._lastupdate or thisGameFrame - self._lastupdate > 2 or (self.quickupdates and thisGameFrame - self._lastupdate > 1) then  -- save some performance/memory
    UpdateNanoParticles(self)
    --Spring.Echo(self.pos[1]..'  '..self.targetpos[1]..'  '..self.streamThickness)
    if enableLights and Script.LuaUI("GadgetCreateBeamLight") then
      local dx = self.targetpos[1] - self.pos[1]
      local dy = self.targetpos[2] - self.pos[2]
      local dz = self.targetpos[3] - self.pos[3]
      local radius = 45+(self.corethickness*60)+(self.streamSpeed*200)
      if not self.lightID then
        self.lightID = Script.LuaUI.GadgetCreateBeamLight('nano', self.pos[1], self.pos[2], self.pos[1], dx, dy, dz, radius, {self.color[1],self.color[2],self.color[3],0.025+(self.streamSpeed*0.6)})
      else
        if not Script.LuaUI.GadgetEditBeamLight(self.lightID, {px=self.pos[1],py=self.pos[2],pz=self.pos[3],dx=dx,dy=dy,dz=dz,orgMult=0.11+(self.streamSpeed*0.6), param={radius=radius}}) then
          self.lightID = nil
        end
      end
    end

    self.fpos = (self.fpos or 0) + self.count * 5 * n
    --if (self.inversed) then
    --  self.scane_mult = 4 * math.cos(6*(self.fpos%3001)/3000*math.pi)
    --else
      self.scane_mult = 8 * math.cos(2*(self.fpos%3001)/3000*math.pi)
    --end

    if (self._dead) then
      RemoveParticles(self.id)
    end
  end
end

-- used if repeatEffect=true;
function NanoLasers:ReInitialize()
  self.dieGameFrame = self.dieGameFrame + self.life
end

function NanoLasers:Visible()
  if not self._midpos then
    return false
  end
  local midPos = self._midpos

  return IsSphereInView(midPos[1],midPos[2],midPos[3], self._radius)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoLasers:Initialize()
  laserShader = gl.CreateShader({
    vertex = [[
      //gl.vertex.xy := length,width
      //gl.vertex.zw := texcoord

      #define startpos         gl_MultiTexCoord0
      #define endpos           gl_MultiTexCoord1
      #define streamTranslate  gl_MultiTexCoord2.x
      #define streamThickness  gl_MultiTexCoord2.y
      #define coreAlpha        gl_MultiTexCoord2.z
      #define coreThickness    gl_MultiTexCoord2.w
      #define isCore           gl_MultiTexCoord3.x

      varying vec3 texCoord;

      void main()
      {
        texCoord    =  vec3(gl_Vertex.z - streamTranslate, gl_Vertex.w, gl_Vertex.z);
        vec3 dir3;
        if (gl_Vertex.x>0.5) {
          gl_Position = (gl_ModelViewMatrix * endpos);
          dir3   = gl_Position.xyz - (gl_ModelViewMatrix * (startpos)).xyz;
        } else {
          gl_Position = (gl_ModelViewMatrix * startpos);
          dir3   = (gl_ModelViewMatrix * (endpos)).xyz - gl_Position.xyz;
        }
        vec3 v = normalize( dir3 );
        vec3 w = normalize( -gl_Position.xyz );
        vec3 u = normalize( cross(w,v) );

        if (isCore>0.0) {
          gl_Position.xyz  += (gl_Vertex.y * coreThickness) * u;
          gl_FrontColor.rgb = vec3(coreAlpha);
          gl_FrontColor.a   = 0.003;
        }else{
          gl_Position.xyz += (gl_Vertex.y * streamThickness) * u;
          gl_FrontColor    = gl_Color;
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
  self.nowater        = true

  if (self.flare) then  -- too expensive!
    --[[if you add those flares, then the laser is slower as the engine, so it needs some tweaking]]--
    if (self.flare1id and particles[self.flare1id] and particles[self.flare2id]) then
      local flare1 = particles[self.flare1id]
      flare1.size  = self.count*0.1
      flare1:ReInitialize()
      local flare2 = particles[self.flare2id]
      flare2.size  = self.count*0.75
      flare2:ReInitialize()
      return
    else
      local r,g,b = max(self.color[1],0.13),max(self.color[2],0.13),max(self.color[3],0.13)
      local flare = {
        unit         = self.unitID,
        piecenum     = self.unitpiece,
        layer        = self.layer,
        life         = 31,
        size         = self.count*0.1,
        sizeSpread   = 1,
        sizeGrowth   = 0.1,
        colormap     = { {r*2,g*2,b*2,0.01},{r*2,g*2,b*2,0.01},{r*2,g*2,b*2,0.01} },
        texture      = 'bitmaps/GPL/groundflash.tga',
        count        = 2,
        repeatEffect = false,
        nowater      = true
      }
      self.flare1id  = AddParticles("StaticParticles",flare)
      flare.size     = self.count*0.75
      flare.texture  = 'bitmaps/flare.tga'
      flare.colormap = { {r*2,g*2,b*2,0.009},{r*2,g*2,b*2,0.009},{r*2,g*2,b*2,0.009} }
      flare.count    = 2
      self.flare2id  = AddParticles("StaticParticles",flare)
    end
  end

  self.visibility = 0
  self:Update(0) --//update los

  if (self.streamThickness<0) then
    self.streamThickness = 4+self.count*0.34
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

  if self.lightID and Script.LuaUI("GadgetRemoveBeamLight") then
    Script.LuaUI.GadgetRemoveBeamLight(self.lightID)
  end

  if (self.flare) then
    RemoveParticles(self.flare1id)
    RemoveParticles(self.flare2id)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return NanoLasers