-- $Id: ShieldSphere.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local ShieldSphereParticle = {}
ShieldSphereParticle.__index = ShieldSphereParticle

local sphereList
local shieldShader
local checkStunned = true

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereParticle.GetInfo()
  return {
    name      = "ShieldSphere",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = -23, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = false,
    shader    = true,
    rtt       = false,
    ctt       = false,
  }
end

ShieldSphereParticle.Default = {
  pos        = {0,0,0}, -- start pos
  layer      = -23,

  life       = 0,

  size       = 0,
  sizeGrowth = 0,

  margin     = 1,

  colormap1  = { {0, 0, 0, 0} },
  colormap2  = { {0, 0, 0, 0} },

  repeatEffect = false,
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local glMultiTexCoord = gl.MultiTexCoord
local glCallList = gl.CallList

function ShieldSphereParticle:BeginDraw()
  gl.DepthMask(false)
  gl.UseShader(shieldShader)
  gl.Culling(GL.FRONT)
end

function ShieldSphereParticle:EndDraw()
  gl.DepthMask(false)
  gl.UseShader(0)

  gl.Culling(GL.BACK)
  gl.Culling(false)

  glMultiTexCoord(1, 1,1,1,1)
  glMultiTexCoord(2, 1,1,1,1)
  glMultiTexCoord(3, 1,1,1,1)
  glMultiTexCoord(4, 1,1,1,1)
end

function ShieldSphereParticle:Draw()
  if checkStunned then
    self.stunned = Spring.GetUnitIsStunned(self.unit)
  end
  if self.stunned or Spring.IsUnitIcon(self.unit) then
    if self.lightID and WG['lighteffects'] then
      WG['lighteffects'].removeLight(self.lightID)
      self.lightID = nil
    end
    return
  end
  local color = self.color1
  glMultiTexCoord(1, color[1],color[2],color[3],color[4] or 1)
  color = self.color2
  glMultiTexCoord(2, color[1],color[2],color[3],color[4] or 1)
  local pos = self.pos
  glMultiTexCoord(3, pos[1],pos[2],pos[3], 0)
  glMultiTexCoord(4, self.margin, self.size, 1, 1)

  glCallList(sphereList)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereParticle:Initialize()
  shieldShader = gl.CreateShader({
    vertex = [[
      #define pos gl_MultiTexCoord3
      #define margin gl_MultiTexCoord4.x
      #define size vec4(gl_MultiTexCoord4.yyy,1.0)

      varying float opac;
      varying vec4 color1;
      varying vec4 color2;

      void main()
      {
          gl_Position = gl_ModelViewProjectionMatrix * (gl_Vertex * size + pos);
          vec3 normal = gl_NormalMatrix * gl_Normal;
          vec3 vertex = vec3(gl_ModelViewMatrix * gl_Vertex);
          float angle = dot(normal,vertex)*inversesqrt( dot(normal,normal)*dot(vertex,vertex) ); //dot(norm(n),norm(v))
          opac = pow( abs( angle ) , margin);

          color1 = gl_MultiTexCoord1;
          color2 = gl_MultiTexCoord2;
      }
    ]],
    fragment = [[
      varying float opac;
      varying vec4 color1;
      varying vec4 color2;

      void main(void)
      {
          gl_FragColor =  mix(color1,color2,opac);
      }

    ]],
    uniform = {
      margin = 1,
    }
  })

  if (shieldShader == nil) then
    print(PRIO_MAJOR,"LUPS->Shield: critical shader error: "..gl.GetShaderLog())
    return false
  end

  sphereList = gl.CreateList(DrawSphere,0,0,0,1,30,false)
end

function ShieldSphereParticle:Finalize()
  gl.DeleteShader(shieldShader)
  gl.DeleteList(sphereList)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereParticle:CreateParticle()
  -- needed for repeat mode
  self.csize  = self.size
  self.clife  = self.life

  self.size      = self.csize or self.size
  self.life_incr = 1/self.life
  self.life      = 0
  self.color1     = self.colormap1[1]
  self.color2     = self.colormap2[1]

  self.firstGameFrame = Spring.GetGameFrame()
  self.dieGameFrame   = self.firstGameFrame + self.clife

end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local time = 0
function ShieldSphereParticle:Update(n)
  time = time + n
  if time > 40 then
    checkStunned = true
    time = 0
  else
    checkStunned = false
  end

  if not self.stunned and self.light then
    if WG['lighteffects'] and WG['lighteffects'].createLight then
      if not self.unitPos then
        self.unitPos = {}
        self.unitPos[1], self.unitPos[2], self.unitPos[3] = Spring.GetUnitPosition(self.unit)
      end
      local color = {GetColor(self.colormap2,self.life) }
      color[4]=color[4]*self.light
      if not self.lightID then
        self.lightID = WG['lighteffects'].createLight('shieldsphere',self.unitPos[1]+self.pos[1], self.unitPos[2]+self.pos[2], self.unitPos[3]+self.pos[1], self.size*6, color)
      else
        WG['lighteffects'].editLight(self.lightID, {orgMult=color[4],param={r=color[1],g=color[2],b=color[3]}})
      end
    else
      self.lightID = nil
    end
  end

  if (self.life<1) then
    self.life     = self.life + n*self.life_incr
    self.size     = self.size + n*self.sizeGrowth
    self.color1 = {GetColor(self.colormap1,self.life)}
    self.color2 = {GetColor(self.colormap2,self.life)}
  end
end

-- used if repeatEffect=true;
function ShieldSphereParticle:ReInitialize()
  self.size     = self.csize
  self.life     = 0
  self.color1   = self.colormap1[1]
  self.color2   = self.colormap2[1]

  self.dieGameFrame = self.dieGameFrame + self.clife
end

function ShieldSphereParticle.Create(Options)
  local newObject = MergeTable(Options, ShieldSphereParticle.Default)
  setmetatable(newObject,ShieldSphereParticle)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function ShieldSphereParticle:Destroy()
  if self.lightID and WG['lighteffects'] and WG['lighteffects'].removeLight then
    WG['lighteffects'].removeLight(self.lightID)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return ShieldSphereParticle