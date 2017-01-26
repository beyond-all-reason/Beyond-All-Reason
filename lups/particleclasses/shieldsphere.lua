-- $Id: ShieldSphere.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local ShieldSphereParticle = {}
ShieldSphereParticle.__index = ShieldSphereParticle

local sphereList
local shieldShader

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
  gl.DepthMask(true)
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

function ShieldSphereParticle:Update(n)
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
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return ShieldSphereParticle