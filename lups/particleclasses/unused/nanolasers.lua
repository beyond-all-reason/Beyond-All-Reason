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


-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

--//speed ups

local GL_ONE       = GL.ONE
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_QUADS     = GL.QUADS

local glColor      = gl.Color
local glTexture    = gl.Texture
local glBlending   = gl.Blending
local glMultiTexCoord   = gl.MultiTexCoord
local glVertex     = gl.Vertex
local glBeginEnd   = gl.BeginEnd
local glUseShader  = gl.UseShader
local glAlphaTest  = gl.AlphaTest
local glCallList   = gl.CallList

local IsSphereInView      = Spring.IsSphereInView

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoLasers:BeginDraw()
	--gl.DepthTest(true)
	gl.DepthMask(false)
	glUseShader(laserShader)
	glBlending(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
	glAlphaTest(false)
end


function NanoLasers:EndDraw()
	--gl.DepthTest(true)
	gl.DepthMask(true)
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

  glColor(self.color[1],self.color[2],self.color[3],0.0003)
  glMultiTexCoord(0,self.targetpos[1] - self.normdir[3] * self.scane_mult ,self.targetpos[2],self.targetpos[3] + self.normdir[1] * self.scane_mult,1)
  glMultiTexCoord(1,self.pos[1],self.pos[2],self.pos[3],1)

  if (self.type == 'building' or self.type == 'repair') then
    if lastTexture ~= 1 then
      glTexture('bitmaps/projectiletextures/nanobeam-build.tga')
      lastTexture = 1
    end
    glMultiTexCoord(2, -(thisGameFrame+Spring.GetFrameTimeOffset())*self.streamSpeed, self.streamThickness, self.corealpha, self.corethickness)
  elseif (self.type == 'reclaim') then
    if lastTexture ~= 2 then
      glTexture('bitmaps/projectiletextures/nanobeam-reclaim.png')
      lastTexture = 2
    end
    glMultiTexCoord(2,  (thisGameFrame+Spring.GetFrameTimeOffset())*self.streamSpeed, self.streamThickness/2, self.corealpha, self.corethickness/2)
  elseif (self.type == 'restore') then
    if lastTexture ~= 3 then
      glTexture('bitmaps/projectiletextures/nanobeam-capture.png')
      lastTexture = 3
    end
    glMultiTexCoord(2,  (thisGameFrame+Spring.GetFrameTimeOffset())*self.streamSpeed, self.streamThickness/2, self.corealpha, self.corethickness/2)
  elseif (self.type == 'resurrect') then
    if lastTexture ~= 4 then
      glTexture('bitmaps/projectiletextures/nanobeam-resurrect.png')
      lastTexture = 4
    end
    glMultiTexCoord(2,  (thisGameFrame+Spring.GetFrameTimeOffset())*self.streamSpeed, self.streamThickness/2.5, self.corealpha, self.corethickness/2.5)
  elseif (self.type == 'capture') then
    if lastTexture ~= 5 then
      glTexture('bitmaps/projectiletextures/nanobeam-capture.png')
      lastTexture = 5
    end
    glMultiTexCoord(2,  (thisGameFrame+Spring.GetFrameTimeOffset())*self.streamSpeed, self.streamThickness/2, self.corealpha, self.corethickness/2)
  else
    if lastTexture ~= 1 then
      glTexture('bitmaps/projectiletextures/nanobeam-build.tga')
      lastTexture = 1
    end
    glMultiTexCoord(2, -(thisGameFrame+Spring.GetFrameTimeOffset())*self.streamSpeed, self.streamThickness, self.corealpha, self.corethickness)
  end

  glCallList(dlist)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoLasers:Update(n)
  if not self._lastupdate or thisGameFrame - self._lastupdate > 1 or (self.quickupdates and thisGameFrame - self._lastupdate >= 1) then  -- save some performance/memory
    UpdateNanoParticles(self)
    --Spring.Echo(self.pos[1]..'  '..self.targetpos[1]..'  '..self.streamThickness)
    if enableLights and Script.LuaUI("GadgetCreateBeamLight") then
      local dx = self.targetpos[1] - self.pos[1]
      local dy = self.targetpos[2] - self.pos[2]
      local dz = self.targetpos[3] - self.pos[3]
      local radius = 45+(self.corethickness*60)+(self.streamSpeed*200)
      if not self.lightID then
        self.lightID = Script.LuaUI.GadgetCreateBeamLight('nano', self.pos[1], self.pos[2], self.pos[1], dx, dy, dz, radius, {self.color[1],self.color[2],self.color[3],0.023+(self.streamSpeed*0.5)})
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
	  #version 150 compatibility
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
	  #version 150 compatibility
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

  if Script.LuaUI("GadgetRemoveBeamLight") then
    Script.LuaUI.GadgetRemoveBeamLight(-1)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function NanoLasers:CreateParticle()
  self.life           = self.life + 1 --// so we can reuse existing fx's
  self.firstGameFrame = thisGameFrame
  self.dieGameFrame   = self.firstGameFrame + self.life
  self.nowater        = true

  self.visibility = 0
  self:Update(0) --//update los

  if (self.streamThickness<0) then
    self.streamThickness = 4+self.count*0.34
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

-- update (position) more frequently for air builders
local airBuilders = {}
for udid, unitDef in pairs(UnitDefs) do
  if unitDef.canFly then
    airBuilders[udid] = true
  end
end

function NanoLasers.Create(Options)
  local unit,nanopiece=Options.unitID,Options.nanopiece
  if (unit and nanopiece)and(knownNanoLasers[unit])and(knownNanoLasers[unit][nanopiece]) then
    local reuseFx = knownNanoLasers[unit][nanopiece]
    table.mergeInPlace(reuseFx, Options)
    reuseFx:CreateParticle()
    return false,reuseFx.id
  else
    local newObject = {}
    for key, value in pairs(Options) do
      newObject[key] = value
    end
    newObject.teamID = Spring.GetUnitTeam(unit)
    newObject.color = { Spring.GetTeamColor(newObject.teamID) }
    newObject.allyID = Spring.GetUnitAllyTeam(unit)
    newObject.unitDefID = Spring.GetUnitDefID(unit)
    newObject.quickupdates = airBuilders[newObject.unitDefID] and true or false

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
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return NanoLasers