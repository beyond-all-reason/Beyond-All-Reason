-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local AirJet = {}
AirJet.__index = AirJet

local jetShader
local tex --//screencopy
local timerUniform --, colorUniform, distortionUniform, distortionMaxUniform
local screenXUniform, screenYUniform

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function AirJet.GetInfo()
  return {
    name      = "ThundAirJet",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 32, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = true,
    shader    = true,
    rtt       = false,
    ctt       = true,
    ati       = 0, --// 1=works,0=doesn't work,-1=unknown
    ms        = 0,
    intel     = 0,
  }
end


AirJet.Default = {
  layer = 32,
  life  = math.huge,

  emitVector    = {0,1,0},
  pos           = {0,0,0},
  width         = 4,
  length        = 50,
  color         = {0, 0, 0.5}, --// blueish
  distortion    = 0.003,
  distortionMax = 0.02,
  texture1      = "bitmaps/GPL/Lups/perlin_noise.jpg", --// noise texture
  texture2      = ":c:bitmaps/GPL/Lups/jet.bmp",       --// shape
  repeatEffect  = true,
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function AirJet:BeginDraw()
  gl.CopyToTexture(tex, 0, 0, 0, 0, vsx, vsy)
  gl.UseShader(jetShader)
    gl.UniformInt(screenXUniform, vsx )
    gl.UniformInt(screenYUniform, vsy )
    gl.Uniform(timerUniform, Spring.GetGameSeconds()*0.1 - 0.5 )
  gl.Texture(0,tex)
  --gl.DepthMask(true)
end

function AirJet:EndDraw()
  gl.UseShader(0)
  gl.Texture(0,false)
  gl.Texture(1,false)
  gl.Texture(2,false)
  --gl.DepthMask(false)
end

function AirJet:Draw()
  gl.Texture(1,self.texture1) 
  gl.Texture(2,self.texture2) 

  if (self.dList==0) then
    self.dList=gl.CreateList(function()
      gl.BeginEnd(GL.QUADS,function()
        local ev = self.emitVector
        gl.MultiTexCoord(1,ev[1],ev[2],ev[3],1)
        local color = self.color
        gl.MultiTexCoord(2,color[1],color[2],color[3])
        gl.MultiTexCoord(3,self.distortion,self.distortionMax)

        gl.MultiTexCoord(0,1,0)
        gl.Vertex(-self.length,-self.width)

        gl.MultiTexCoord(0,1,1)
        gl.Vertex(0,-self.width)

        gl.MultiTexCoord(0,0,1)
        gl.Vertex(0,self.width)

        gl.MultiTexCoord(0,0,0)
        gl.Vertex(-self.length,self.width)
      end)
    end)
  end
  gl.CallList(self.dList)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local time = 0
function AirJet:Update(n)
  time = time + n
  if time > 1.5 then
    time = 0
    if Spring.GetUnitMoveTypeData(self.unit) and Spring.GetUnitMoveTypeData(self.unit).aircraftState == "crashing" then
      self.repeatEffect = false
      self.dieGameFrame = Spring.GetGameFrame() + 1
    end
  end
end

-- used if repeatEffect=true;
function AirJet:ReInitialize()
  self.dieGameFrame = self.dieGameFrame + self.life
end

function AirJet.Initialize()
  jetShader = gl.CreateShader({
    vertex = [[
      uniform int  screenX;
      uniform int  screenY;

      varying vec2 dir;
      varying vec3 color;
      varying float distortion;

      void main()
      {
        gl_TexCoord[1] = gl_MultiTexCoord0;

        gl_Position     = gl_ModelViewMatrix * vec4(0.0,0.0,0.0,1.0);
        vec3 dir3  = vec3(gl_ModelViewMatrix * gl_MultiTexCoord1)-gl_Position.xyz;
        vec3 v = normalize( dir3 );
        vec3 w = normalize( -vec3(gl_Position) );
        vec3 u = normalize( cross(w,v) );
        gl_Position.xyz += gl_Vertex.y*u + gl_Vertex.x*v;
        gl_Position     = gl_ProjectionMatrix * gl_Position;

        dir  = dir3.xy;
        dir /= max( pow(gl_Position.z*0.005,2.0) ,gl_MultiTexCoord3.y); //gl_MultiTexCoord3.y := limits distortion (distortionMax)

        color = gl_MultiTexCoord2.rgb;

        distortion = gl_MultiTexCoord3.x;
      }
    ]],
    fragment = [[
      #version 120
      uniform sampler2D tex0;
      uniform sampler2D noiseMap;
      uniform sampler2D mask;
      uniform float     timer;
      uniform int       screenX;
      uniform int       screenY;

      varying vec2 dir;
      varying vec3 color;
      varying float distortion;

      void main(void)
      {
        vec2 noiseVec;
	  float noiseStrength;
	  vec2 displacement = gl_TexCoord[1].xy;
	  displacement.y += 30*timer;
	  noiseStrength = texture2D(noiseMap, displacement.xy).y * distortion;
        vec2 txCoord = gl_TexCoord[1].xy;
        txCoord.s += (texture2D(noiseMap, displacement.xy*distortion*200.0).y-0.5)* distortion * min(800.0 / length(dir),300.0);
        txCoord.t += abs(noiseStrength)*90.0*(1.0-txCoord.t);
	  float opac = texture2D(mask,txCoord).r;

          noiseVec = dir * abs(noiseStrength) * opac;
          vec2 texCoord = vec2(gl_FragCoord.x/float(screenX),gl_FragCoord.y/float(screenY));

          gl_FragColor.rgb  = texture2D(tex0, texCoord + noiseVec).rgb; //screen
          gl_FragColor.rgb += opac*color;                               //color
          gl_FragColor.rgb += pow(opac,fract(timer*70.0)+6.0);           //white flame
          gl_FragColor.a    = opac*1.5;
      }

    ]],
    uniformInt = {
      tex0 = 0,
      noiseMap = 1,
      mask = 2,
      screenX = vsx,
      screenY = vsy
    },
    uniform = {
      timer = 0,
    }
  })

  if (jetShader == nil) then
    Spring.Echo("LUPS: airjet particle class: shader error: "..gl.GetShaderLog())
    return false
  end

  timerUniform = gl.GetUniformLocation(jetShader, 'timer')
  screenXUniform = gl.GetUniformLocation(jetShader, 'screenX')
  screenYUniform = gl.GetUniformLocation(jetShader, 'screenY')

  tex = gl.CreateTexture(vsx, vsy, {
    min_filter = GL.NEAREST,
    mag_filter = GL.NEAREST,
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
  })
end

function AirJet:Finalize()
  gl.DeleteTextureFBO(tex)
  gl.DeleteShader(jetShader)
end

function AirJet.ViewResize(viewSizeX, viewSizeY)
  gl.DeleteTextureFBO(tex)
  tex = gl.CreateTexture(vsx, vsy, {
    min_filter = GL.NEAREST,
    mag_filter = GL.NEAREST,
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
  })
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function AirJet:CreateParticle()
  self.dList = 0
  self.dieGameFrame  = Spring.GetGameFrame() + self.life
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function AirJet.Create(Options)
  local newObject = MergeTable(Options, AirJet.Default)
  setmetatable(newObject,AirJet)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function AirJet:Destroy()
  gl.DeleteTexture(self.texture1)
  gl.DeleteTexture(self.texture2)
  if (self.dList>0) then
    gl.DeleteList(self.dList)
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return AirJet
