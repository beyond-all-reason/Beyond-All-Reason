-- $Id: ShieldSphereColor.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local ShieldSphereColorParticle = {}
ShieldSphereColorParticle.__index = ShieldSphereColorParticle

local sphereList = {}
local shieldShader

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereColorParticle.GetInfo()
  return {
    name      = "ShieldSphereColor",
    backup    = "ShieldSphereColorFallback", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = -23, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = false,
    shader    = true,
    rtt       = false,
    ctt       = false,
  }
end

ShieldSphereColorParticle.Default = {
  pos        = {0,0,0}, -- start pos
  layer      = -23,

  life       = math.huge,

  size       = 10,
  margin     = 1,

  colormap1  = { {0, 0, 0, 0} },
  colormap2  = { {0, 0, 0, 0} },

  repeatEffect = false,
  shieldSize = "large",
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local glMultiTexCoord = gl.MultiTexCoord
local glCallList = gl.CallList

function ShieldSphereColorParticle:Visible()
	return self.visibleToMyAllyTeam
end

function ShieldSphereColorParticle:BeginDraw()
  gl.DepthMask(false)
  gl.UseShader(shieldShader)
  gl.Culling(GL.FRONT)
end

function ShieldSphereColorParticle:EndDraw()
  gl.DepthMask(false)
  gl.UseShader(0)

  gl.Culling(GL.BACK)
  gl.Culling(false)

  glMultiTexCoord(1, 1,1,1,1)
  glMultiTexCoord(2, 1,1,1,1)
  glMultiTexCoord(3, 1,1,1,1)
  glMultiTexCoord(4, 1,1,1,1)
end

function ShieldSphereColorParticle:Draw()
  local col1, col2 = GetShieldColor(self.unit, self)
  glMultiTexCoord(1, col1[1],col1[2],col1[3],col1[4] or 1)
  glMultiTexCoord(2, col2[1],col2[2],col2[3],col2[4] or 1)
  local pos = self.pos
  glMultiTexCoord(3, pos[1], pos[2], pos[3], 0)
  glMultiTexCoord(4, self.margin, self.size, 1, 1)

  glCallList(sphereList[self.shieldSize])
  if self.drawBack then
    gl.Scale(1,1,-1)
    if pos[3] ~= 0 then
      glMultiTexCoord(3, pos[1], pos[2], -pos[3], 0)
    end
    glMultiTexCoord(1, col1[1],col1[2],col1[3],(col1[4] or 1)*self.drawBack)
    glMultiTexCoord(2, col2[1],col2[2],col2[3],(col2[4] or 1)*self.drawBack)
    if self.drawBackMargin then
      glMultiTexCoord(4, self.drawBackMargin, self.size, 1, 1)
    end
    glCallList(sphereList[self.shieldSize])
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereColorParticle:Initialize()
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

  sphereList = {
    large = gl.CreateList(DrawSphere,0,0,0,1, 38,false),
    small = gl.CreateList(DrawSphere,0,0,0,1, 24,false),
  }
end

function ShieldSphereColorParticle:Finalize()
  gl.DeleteShader(shieldShader)
  for _, list in pairs(sphereList) do
    gl.DeleteList(list)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereColorParticle:CreateParticle()
  self.dieGameFrame = Spring.GetGameFrame() + self.life
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function ShieldSphereColorParticle:Update()
end

-- used if repeatEffect=true;
function ShieldSphereColorParticle:ReInitialize()
  self.dieGameFrame = self.dieGameFrame + self.life
end

function ShieldSphereColorParticle.Create(Options)
  local newObject = MergeTable(Options, ShieldSphereColorParticle.Default)
  setmetatable(newObject,ShieldSphereColorParticle)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function ShieldSphereColorParticle:Destroy()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return ShieldSphereColorParticle