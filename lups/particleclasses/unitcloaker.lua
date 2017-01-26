-- $Id: UnitCloaker.lua 3871 2009-01-28 00:09:23Z jk $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local UnitCloaker = {}
UnitCloaker.__index = UnitCloaker

local warpShader
local tex
local cameraUniform,lightUniform
local isS3oUniform, lifeUniform

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitCloaker.GetInfo()
  return {
    name      = "UnitCloaker",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 16, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = true,
    shader    = true,
    rtt       = false,
    ctt       = true,
    intel     = 0,
  }
end

UnitCloaker.Default = {
  layer = 16,
  worldspace = true,

  inverse    = false,
  life       = math.huge,
  unit       = -1,
  unitDefID  = -1,

  repeatEffect = false,
  dieGameFrame = math.huge
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local loadedS3oTexture = -1

function UnitCloaker:BeginDraw()
  gl.Culling(GL.FRONT)
  gl.Culling(true)
  gl.DepthMask(true)

  gl.UseShader(warpShader)
  local x,y,z = Spring.GetCameraPosition()
  gl.Uniform(cameraUniform,x,y,z)

  x,y,z = gl.GetSun( "pos" )
  gl.Light(0,GL.POSITION,x,y,z)

  gl.Uniform(lightUniform,x,y,z)

  x,y,z = gl.GetSun( "ambient" ,"unit")
  gl.Light(0,GL.AMBIENT,x,y,z)
  x,y,z = gl.GetSun( "diffuse" ,"unit")
  gl.Light(0,GL.DIFFUSE,x,y,z)

  --gl.Texture(1,'bitmaps/cdet.bmp')
  --gl.Texture(1,'bitmaps/clouddetail.bmp')
  --gl.Texture(1,'bitmaps/GPL/Lups/perlin_noise.jpg')
  gl.Texture(2,'bitmaps/GPL/Lups/mynoise2.png')
  gl.Texture(3,'$specular')
  gl.Texture(4,'$reflection')

  gl.MatrixMode(GL.PROJECTION)
  gl.PushMatrix()
  gl.MultMatrix("camera")
  gl.MatrixMode(GL.MODELVIEW)
  gl.PushMatrix()
  gl.LoadIdentity()
end

function UnitCloaker:EndDraw()
  gl.MatrixMode(GL.PROJECTION)
  gl.PopMatrix()
  gl.MatrixMode(GL.MODELVIEW)
  gl.PopMatrix()

  gl.Culling(GL.BACK)
  gl.Culling(false)
  gl.DepthMask(true)

  gl.UseShader(0)

  gl.Texture(0,false)
  gl.Texture(1,false)
  gl.Texture(2,false)
  gl.Texture(3,false)
  gl.Texture(4,false)

  gl.Color(1,1,1,1)

  loadedS3oTexture = -1
end

function UnitCloaker:Draw()
  local udid = 0
  if (self.isS3o) then
    udid = self.unitDefID
  end

  if (udid~=loadedS3oTexture) then
    gl.Texture(0, "%" .. udid .. ":0")
    gl.Texture(1, "%" .. udid .. ":1")
    loadedS3oTexture = udid
  end

  if (self.inverse) then
    gl.Uniform( lifeUniform, 1-(thisGameFrame-self.firstGameFrame)/self.life )
  else
    gl.Uniform( lifeUniform,   (thisGameFrame-self.firstGameFrame)/self.life )
  end

  gl.Color(Spring.GetTeamColor(self.team))

  if (self.isS3o) then
    gl.Culling(GL.BACK)
    gl.Unit(self.unit,true,-1)
    gl.Culling(GL.FRONT)
  else
    gl.Unit(self.unit,true,-1)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitCloaker.Initialize()
  warpShader = gl.CreateShader({
    vertex = [[
      uniform vec3 cameraPos;
      uniform vec3 lightPos;
      uniform float life;

      varying float opac;
      varying vec4  texCoord;
      varying vec3  normal;
      varying vec3  viewdir;

      //const vec4 ObjectPlaneS = vec4(0.002, 0.002, 0.0,   0.3);
      //const vec4 ObjectPlaneT = vec4(0.0,   0.002, 0.002, 0.3);

      const vec4 ObjectPlaneS = vec4(0.005, 0.005, 0.000,  0.0);
      const vec4 ObjectPlaneT = vec4(0.000, 0.005, 0.005,  0.0);

      void main(void)
      {
        texCoord.st  = gl_MultiTexCoord0.st;
        texCoord.p   = dot( gl_Vertex, ObjectPlaneS ); 
        texCoord.q   = dot( gl_Vertex, ObjectPlaneT );// + life*0.25;
        normal       = gl_NormalMatrix * gl_Normal;
        viewdir      = (gl_ModelViewMatrix * gl_Vertex).xyz - cameraPos;

        gl_FrontColor = gl_Color;

        float a = max( dot(normal, lightPos), 0.0);
        gl_FrontSecondaryColor.rgb = a * gl_LightSource[0].diffuse.rgb + gl_LightSource[0].ambient.rgb;

        opac = dot(normalize(normal), normalize(viewdir));
        opac = 1.0 - abs(opac);
        opac = pow(opac, 5.0);

        gl_Position = ftransform();
      }
    ]],
    fragment = [[
      uniform sampler2D texture1;
      uniform sampler2D texture2;
      uniform sampler2D noiseMap;
      uniform samplerCube specularMap;
      uniform samplerCube reflectMap;
      uniform float     life;

      varying float opac;
      varying vec4  texCoord;
      varying vec3  normal;
      varying vec3  viewdir;

      void main(void)
      {
          vec4 noise = texture2D(noiseMap, texCoord.pq);

          //if (noise.r < life) {
          //  discard;
          //}

          gl_FragColor     = texture2D(texture1, texCoord.st);
          gl_FragColor.rgb = mix(gl_FragColor.rgb, gl_Color.rgb, gl_FragColor.a);

          vec4 extraColor = texture2D(texture2, texCoord.st);

          vec3 reflectDir = reflect(viewdir, normalize(normal));

          vec3 spec = textureCube(specularMap, reflectDir).rgb * 4.0 * extraColor.g;
          vec3 refl = textureCube(reflectMap,  reflectDir).rgb;
          refl  = mix(gl_SecondaryColor.rgb, refl, extraColor.g);
          refl += extraColor.r;

          gl_FragColor.rgb = gl_FragColor.rgb * refl + spec;
          gl_FragColor.a   = extraColor.a;

          if (life*1.4>noise.r) {
            float d = life*1.4-noise.r;
            gl_FragColor.a *= smoothstep(0.4,0.0,d);
          }
          gl_FragColor.rgb += vec3(life*0.25);
      }
    ]],
    uniform = {
      isS3o    = false,
    },
    uniformInt = {
      texture1    = 0,
      texture2    = 1,
      noiseMap    = 2,
      specularMap = 3,
      reflectMap  = 4,
    },
    uniformFloat = {
      life  = 1,
    }
  })

  if (warpShader == nil) then
    print(PRIO_MAJOR,"LUPS->UnitCloaker: critical shader error: "..gl.GetShaderLog())
    return false
  end

  cameraUniform = gl.GetUniformLocation(warpShader, 'cameraPos')
  lightUniform  = gl.GetUniformLocation(warpShader, 'lightPos')
  lifeUniform   = gl.GetUniformLocation(warpShader, 'life')
end

function UnitCloaker.Finalize()
  if (gl.DeleteShader) then
    gl.DeleteShader(warpShader)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

-- used if repeatEffect=true;
function UnitCloaker:ReInitialize()
  self.dieGameFrame = self.dieGameFrame + self.life
end

function UnitCloaker:CreateParticle()
  local name = UnitDefs[self.unitDefID].model.name
  self.isS3o = ((name:lower():find("s3o") or name:lower():find("obj")) and true)
  self.firstGameFrame = thisGameFrame
  self.dieGameFrame   = self.firstGameFrame + self.life
end

function UnitCloaker:Visible()
  if self.allyTeam == LocalAllyTeamID then
    return Spring.IsUnitVisible(self.unit)
  end

  local _, specFullView = Spring.GetSpectatingState()
  local losState = Spring.GetUnitLosState(self.unit, LocalAllyTeamID) or {}
  return specFullView or (losState and losState.los)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitCloaker.Create(Options)
  SetUnitLuaDraw(Options.unit,true)
  local newObject = MergeTable(Options, UnitCloaker.Default)
  setmetatable(newObject,UnitCloaker)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function UnitCloaker:Destroy()
  SetUnitLuaDraw(self.unit,false)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return UnitCloaker
