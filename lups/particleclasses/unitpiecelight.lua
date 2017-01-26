-- $Id: UnitPieceLight.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local UnitPieceLight = {}
UnitPieceLight.__index = UnitPieceLight

local depthtex, offscreentex, blurtex
local offscreen4, offscreen8
local blur4, blur8

local depthShader
local blurShader
local uniformScreenXY, uniformPixelSize, uniformDirection

local GL_DEPTH_BITS = 0x0D56

local GL_DEPTH_COMPONENT   = 0x1902
local GL_DEPTH_COMPONENT16 = 0x81A5
local GL_DEPTH_COMPONENT24 = 0x81A6
local GL_DEPTH_COMPONENT32 = 0x81A7

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitPieceLight.GetInfo()
  return {
    name      = "UnitPieceLight",
    backup    = "", --// backup class, if this class doesn't work (old cards,ati's,etc.)
    desc      = "",

    layer     = 32, --// extreme simply z-ordering :x

    --// gfx requirement
    fbo       = true,
    shader    = true,
    rtt       = true,
    ctt       = true,
    ms        = 0,
  }
end


UnitPieceLight.Default = {
  layer         = 32,
  life          = math.huge,
  worldspace    = true,

  piecenum      = 0,

  colormap      = { {1,1,1,0} },
  repeatEffect  = true,

  --// internal
  color         = {1,1,1,0},
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitPieceLight:BeginDraw()
  gl.CopyToTexture(depthtex, 0, 0, 0, 0, vsx, vsy)
  gl.Texture(depthtex)
  gl.UseShader(depthShader)
  gl.Uniform(uniformScreenXY, math.ceil(vsx*0.5),math.ceil(vsy*0.5) )
  gl.RenderToTexture(offscreentex, gl.Clear, GL.COLOR_BUFFER_BIT ,0,0,0,0)
end

function UnitPieceLight:EndDraw()
  gl.Color(1,1,1,1)
  gl.UseShader(0)
  gl.RenderToTexture(offscreen4, function()
     gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
     gl.Texture(offscreentex)
     gl.TexRect(-1,1,1,-1)
  end)

  gl.Texture(offscreentex)
  gl.UseShader(blurShader)
  gl.RenderToTexture(blurtex, function()
     gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
     gl.Uniform(uniformDirection,  1,0 )
     gl.Uniform(uniformPixelSize,  1.0/math.ceil(vsx*0.5) )
     gl.TexRect(-1-0.25/vsx,1+0.25/vsy,1+0.25/vsx,-1-0.25/vsy)
  end)
  gl.Texture(blurtex)
  gl.RenderToTexture(offscreentex, function()
     gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
     gl.Uniform(uniformDirection,  0,1 )
     gl.Uniform(uniformPixelSize,  math.ceil(vsy*0.5) )
     gl.TexRect(-1-0.25/vsx,1+0.25/vsy,1+0.25/vsx,-1-0.25/vsy)
  end)

  gl.Texture(offscreen4)
  gl.RenderToTexture(blur4, function()
     gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
     gl.Uniform(uniformDirection,  1,0 )
     gl.Uniform(uniformPixelSize,  1.0/math.ceil(vsx*0.25) )
     gl.TexRect(-1-0.125/vsx,1+0.125/vsy,1+0.125/vsx,-1-0.125/vsy)
  end)
  gl.Texture(blur4)
  gl.RenderToTexture(offscreen4, function()
     gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
     gl.Uniform(uniformDirection,  0,1 )
     gl.Uniform(uniformPixelSize,  1.0/math.ceil(vsy*0.25) )
     gl.TexRect(-1-0.125/vsx,1+0.125/vsy,1+0.125/vsx,-1-0.125/vsy)
  end)

  gl.UseShader(0)
  gl.Blending(GL.ONE,GL.ONE)

  gl.MatrixMode(GL.PROJECTION); gl.PushMatrix(); gl.LoadIdentity()
  gl.MatrixMode(GL.MODELVIEW);  gl.PushMatrix(); gl.LoadIdentity()

  gl.Texture(offscreentex)
  gl.TexRect(-1-0.5/vsx,1+0.5/vsy,1+0.5/vsx,-1-0.5/vsy)
  gl.Texture(offscreen4)
  gl.TexRect(-1-0.5/vsx,1+0.5/vsy,1+0.5/vsx,-1-0.5/vsy)

  gl.MatrixMode(GL.PROJECTION); gl.PopMatrix()
  gl.MatrixMode(GL.MODELVIEW);  gl.PopMatrix()

  gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
  gl.Texture(false)
  gl.UseShader(0)
end

function UnitPieceLight:Draw()
  gl.Color(self.color)
  gl.RenderToTexture(offscreentex, function()
     gl.PushMatrix()
     gl.ResetMatrices()
     gl.UnitMultMatrix(self.unit)
     gl.UnitPieceMultMatrix(self.unit,self.piecenum)
     gl.UnitPiece(self.unit,self.piecenum)
     gl.PopMatrix()
  end)
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitPieceLight:Update()
  self.life  = self.life + self.life_incr
  self.color = {GetColor(self.colormap,self.life)}
end

-- used if repeatEffect=true;
function UnitPieceLight:ReInitialize()
  self.life = 0
  self.dieGameFrame = self.dieGameFrame + self.clife
end

function UnitPieceLight.Initialize()
  depthShader = gl.CreateShader({
    fragment = [[
      uniform sampler2D tex0;
      uniform vec2 screenXY;

      void main(void)
      {
        vec2 texCoord = vec2( gl_FragCoord.x/screenXY.x , gl_FragCoord.y/screenXY.y );
        float depth  = texture2D(tex0, texCoord ).z;

        if (depth <= gl_FragCoord.z-0.0005) {
          discard;
        }
        gl_FragColor = gl_Color;
      }
    ]],
    uniformInt = {
      tex0 = 0,
    },
    uniform = {
      screenXY = {math.ceil(vsx*0.5),math.ceil(vsy*0.5)},
    },
  })

  if (depthShader == nil) then
    print(PRIO_MAJOR,"LUPS->UnitPieceLights: Critical Shader Error: DepthShader: "..gl.GetShaderLog())
    return false
  end

  blurShader = gl.CreateShader({
    fragment = [[
      float kernel[7];
      uniform sampler2D tex0;
      uniform float pixelsize;
      uniform vec2 dir;

      void InitKernel(void) {
	 kernel[0] = 0.013;
	 kernel[1] = 0.054;
	 kernel[2] = 0.069;
	 kernel[3] = 0.129;
	 kernel[4] = 0.212;
	 kernel[5] = 0.301;
	 kernel[6] = 0.372;
      }

      void main(void) {
        InitKernel();
        vec2 texCoord  = vec2(gl_TextureMatrix[0] * gl_TexCoord[0]);
        gl_FragColor = vec4(0.0);

        int n,i;

        i=1;
	for(n=6; n >= 0; --n){
          gl_FragColor += kernel[n] * texture2D(tex0, texCoord.st + dir * float(i)*pixelsize );
          ++i;
        }

        gl_FragColor += 0.4 * texture2D(tex0, texCoord );

	i = -7;
	for(n=0; n <= 6; ++n){
          gl_FragColor += kernel[n] * texture2D(tex0, texCoord.st + dir * float(i)*pixelsize );
	  ++i;
        }
      }
    ]],
    uniformInt = {
      tex0 = 0,
      uniform = {
        pixelsize = 1.0/math.ceil(vsx*0.5),
      }
    },
  })


  if (blurShader == nil) then
    print(PRIO_MAJOR,"LUPS->UnitPieceLights: Critical Shader Error: BlurShader: "..gl.GetShaderLog())
    return false
  end

  uniformScreenXY  = gl.GetUniformLocation(depthShader, 'screenXY')
  uniformPixelSize = gl.GetUniformLocation(blurShader,  'pixelsize')
  uniformDirection = gl.GetUniformLocation(blurShader,  'dir')

  UnitPieceLight.ViewResize(vsx, vsy)
end

function UnitPieceLight.Finalize()
  gl.DeleteTexture(depthtex)
  if (gl.DeleteTextureFBO) then
    gl.DeleteTextureFBO(offscreentex)
    gl.DeleteTextureFBO(blurtex)
  end

  if (gl.DeleteShader) then
    gl.DeleteShader(depthShader or 0)
    gl.DeleteShader(blurShader or 0)
  end
end

function UnitPieceLight.ViewResize(vsx, vsy)
  gl.DeleteTexture(depthtex or 0)
  gl.DeleteTextureFBO(offscreentex or 0)
  gl.DeleteTextureFBO(blurtex or 0)

  gl.DeleteTextureFBO(offscreen4 or 0)
  gl.DeleteTextureFBO(blur4 or 0)

  depthtex = gl.CreateTexture(vsx,vsy, {
    border = false,
    format = GL_DEPTH_COMPONENT24,
    min_filter = GL.NEAREST,
    mag_filter = GL.NEAREST,
  })

  offscreentex = gl.CreateTexture(math.ceil(vsx*0.5),math.ceil(vsy*0.5), {
    border = false,
    min_filter = GL.LINEAR,
    mag_filter = GL.LINEAR,
    wrap_s = GL.CLAMP_TO_BORDER,
    wrap_t = GL.CLAMP_TO_BORDER,
    fbo = true,
  })

  offscreen4 = gl.CreateTexture(math.ceil(vsx*0.25),math.ceil(vsy*0.25), {
    border = false,
    min_filter = GL.LINEAR,
    mag_filter = GL.LINEAR,
    wrap_s = GL.CLAMP_TO_BORDER,
    wrap_t = GL.CLAMP_TO_BORDER,
    fbo = true,
  })

  blurtex = gl.CreateTexture(math.ceil(vsx*0.5),math.ceil(vsy*0.5), {
    border = false,
    min_filter = GL.LINEAR,
    mag_filter = GL.LINEAR,
    wrap_s = GL.CLAMP_TO_BORDER,
    wrap_t = GL.CLAMP_TO_BORDER,
    fbo = true,
  })

  blur4 = gl.CreateTexture(math.ceil(vsx*0.25),math.ceil(vsy*0.25), {
    border = false,
    min_filter = GL.LINEAR,
    mag_filter = GL.LINEAR,
    wrap_s = GL.CLAMP_TO_BORDER,
    wrap_t = GL.CLAMP_TO_BORDER,
    fbo = true,
  })
end


function UnitPieceLight:Visible()
  local ux,uy,uz = Spring.GetUnitViewPosition(self.unit)
  if not ux then
    return false
  end

  local pos = {0,0,0}
  pos[1],pos[2],pos[3] = pos[1]+ux,pos[2]+uy,pos[3]+uz
  local radius = 300 + Spring.GetUnitRadius(self.unit)
  local losState = Spring.GetUnitLosState(self.unit, LocalAllyTeamID)

  return (losState and losState.los)and(Spring.IsSphereInView(pos[1],pos[2],pos[3],radius))
end

function UnitPieceLight:Valid()
  local ux = Spring.GetUnitViewPosition(self.unit)
  if (ux) then
    return true
  else
    return false
  end
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitPieceLight:CreateParticle()
  self.clife     = self.life
  self.life_incr = 1/self.life
  self.life      = 0
  self.dieGameFrame  = Spring.GetGameFrame() + self.clife
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function UnitPieceLight.Create(Options)
  local newObject = MergeTable(Options, UnitPieceLight.Default)
  setmetatable(newObject,UnitPieceLight)  -- make handle lookup
  newObject:CreateParticle()
  return newObject
end

function UnitPieceLight:Destroy()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return UnitPieceLight