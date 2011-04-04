-- $Id: UnitPieceLight.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local UnitPieceLight = {}
UnitPieceLight.__index = UnitPieceLight

local depthtex, offscreentex, blurtex
local offscreen4, offscreen8
local blur4, blur8

local depthShader
local blurShader_h
local blurShader_v
local uniformScreenXY, uniformScreenX, uniformScreenY

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
    atiseries = 2,
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
  gl.RenderToTexture(offscreen8, function()
     gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
     gl.Texture(offscreen4)
     gl.TexRect(-1,1,1,-1)
  end)

  gl.Texture(offscreentex)
  gl.RenderToTexture(blurtex, function()
     gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
     gl.UseShader(blurShader_h)
     gl.UniformInt(uniformScreenX,  math.ceil(vsx*0.5) )
     gl.TexRect(-1-0.25/vsx,1+0.25/vsy,1+0.25/vsx,-1-0.25/vsy)
  end)
  gl.Texture(blurtex)
  gl.RenderToTexture(offscreentex, function()
     gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
     gl.UseShader(blurShader_v)
     gl.UniformInt(uniformScreenY,  math.ceil(vsy*0.5) )
     gl.TexRect(-1-0.25/vsx,1+0.25/vsy,1+0.25/vsx,-1-0.25/vsy)
  end)

  gl.Texture(offscreen4)
  gl.RenderToTexture(blur4, function()
     gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
     gl.UseShader(blurShader_h)
     gl.UniformInt(uniformScreenX,  math.ceil(vsx*0.25) )
     gl.TexRect(-1-0.125/vsx,1+0.125/vsy,1+0.125/vsx,-1-0.125/vsy)
  end)
  gl.Texture(blur4)
  gl.RenderToTexture(offscreen4, function()
     gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
     gl.UseShader(blurShader_v)
     gl.UniformInt(uniformScreenY,  math.ceil(vsy*0.25) )
     gl.TexRect(-1-0.125/vsx,1+0.125/vsy,1+0.125/vsx,-1-0.125/vsy)
  end)

  gl.Texture(offscreen8)
  gl.RenderToTexture(blur8, function()
     gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
     gl.UseShader(blurShader_h)
     gl.UniformInt(uniformScreenX,  math.ceil(vsx*0.125) )
     gl.TexRect(-1-0.0625/vsx,1+0.0625/vsy,1+0.0625/vsx,-1-0.0625/vsy)
  end)
--[[
  gl.Texture(blur8)
  gl.RenderToTexture(offscreen8, function()
     gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
     gl.UseShader(blurShader_v)
     gl.UniformInt(uniformScreenY,  math.ceil(vsy*0.125) )
     gl.TexRect(-1-0.0625/vsx,1+0.0625/vsy,1+0.0625/vsx,-1-0.0625/vsy)
  end)
--]]

  gl.UseShader(0)
  gl.Blending(GL.ONE,GL.ONE)

  gl.MatrixMode(GL.PROJECTION); gl.PushMatrix(); gl.LoadIdentity()
  gl.MatrixMode(GL.MODELVIEW);  gl.PushMatrix(); gl.LoadIdentity()

  gl.Texture(offscreentex)
  gl.TexRect(-1-0.5/vsx,1+0.5/vsy,1+0.5/vsx,-1-0.5/vsy)
  gl.Texture(offscreen4)
  gl.TexRect(-1-0.5/vsx,1+0.5/vsy,1+0.5/vsx,-1-0.5/vsy)
  gl.Texture(blur8)
  --gl.Texture(offscreen8)
  gl.TexRect(-1-0.5/vsx,1+0.5/vsy,1+0.5/vsx,-1-0.5/vsy)
  gl.TexRect(-1-0.5/vsx,1+0.5/vsy,1+0.5/vsx,-1-0.5/vsy)
  gl.TexRect(-1-0.5/vsx,1+0.5/vsy,1+0.5/vsx,-1-0.5/vsy)
  gl.TexRect(-1-0.5/vsx,1+0.5/vsy,1+0.5/vsx,-1-0.5/vsy)

  gl.MatrixMode(GL.PROJECTION); gl.PopMatrix()
  gl.MatrixMode(GL.MODELVIEW);  gl.PopMatrix()

  gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
  gl.Texture(false)
  gl.UseShader(0)
end

function UnitPieceLight:Draw()
  gl.Color(self.color[1],self.color[2],self.color[3],self.color[4])
  gl.RenderToTexture(offscreentex, function()
     gl.PushMatrix()
     gl.ResetMatrices()
     gl.PushMatrix()
     gl.UnitMultMatrix(self.unit)
     --local x,y,z    = Spring.GetUnitViewPosition(self.unit)
     --local dx,_,dz  = Spring.GetUnitDirection(self.unit)
     --local h        = Spring.GetHeadingFromVector(dx,dz)
     --gl.Translate(x,y,z)
     --gl.Rotate(h/360*2, 0, 1, 0)
     --gl.UnitPieceMatrix(self.unit,self.piecenum)
     gl.UnitPieceMultMatrix(self.unit,self.piecenum)
     gl.UnitPiece(self.unit,self.piecenum)
     gl.PopMatrix()
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

  blurShader_h = gl.CreateShader({
    fragment = [[
      float kernel[7]; //= float[7](0.013, 0.054, 0.069, 0.129, 0.212, 0.301, 0.372);
      uniform sampler2D tex0;
      uniform int screenX;

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

        int n;
	int i;

        float pixelsize = 1.0/float(screenX);

        i=1;
	for(n=6; n >= 0; --n){
          gl_FragColor += kernel[n] * texture2D(tex0, vec2(texCoord.s + float(i)*pixelsize,texCoord.t) );
          ++i;
        }

        gl_FragColor += 0.4 * texture2D(tex0, texCoord );

	i = -7;
	for(n=0; n <= 6; ++n){
          gl_FragColor += kernel[n] * texture2D(tex0, vec2(texCoord.s + float(i)*pixelsize,texCoord.t) );
	  ++i;
        }
      }
    ]],
    uniformInt = {
      tex0 = 0,
      screenX = math.ceil(vsx*0.5),
    },
  })


  if (blurShader_h == nil) then
    print(PRIO_MAJOR,"LUPS->UnitPieceLights: Critical Shader Error: HBlurShader: "..gl.GetShaderLog())
    return false
  end

  blurShader_v = gl.CreateShader({
    fragment = [[
      float kernel[7]; //= float[7](0.013, 0.054, 0.069, 0.129, 0.212, 0.301, 0.372);
      uniform sampler2D tex0;
      uniform int screenY;

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
        vec2 texCoord  = vec2(gl_TextureMatrix[0] * gl_TexCoord[0]);
        gl_FragColor = vec4(0.0);

        int i;
	int n;

        float pixelsize = 1.0/float(screenY);

        i=1;
	for(n=6; n >= 0; --n){
          gl_FragColor += kernel[n] * texture2D(tex0, vec2(texCoord.s,texCoord.t + float(i)*pixelsize) );
	  ++i;
        }

        gl_FragColor += 0.4 * texture2D(tex0, texCoord );

	i = -7;
	for(n=0; n <= 6; ++n){
          gl_FragColor += kernel[n] * texture2D(tex0, vec2(texCoord.s,texCoord.t + float(i)*pixelsize) );
          ++i;
        }
      }
    ]],
    uniformInt = {
      tex0 = 0,
      screenY = math.ceil(vsy*0.5);
    },
  })

  if (blurShader_v == nil) then
    print(PRIO_MAJOR,"LUPS->UnitPieceLights: Critical Shader Error: VBlurShader: "..gl.GetShaderLog())
    return false
  end

  uniformScreenXY = gl.GetUniformLocation(depthShader,  'screenXY')
  uniformScreenX  = gl.GetUniformLocation(blurShader_h, 'screenX')
  uniformScreenY  = gl.GetUniformLocation(blurShader_v, 'screenY')

  UnitPieceLight.ViewResize()
end

function UnitPieceLight.Finalize()
  gl.DeleteTexture(depthtex)
  if (gl.DeleteTextureFBO) then
    gl.DeleteTextureFBO(offscreentex)
    gl.DeleteTextureFBO(blurtex)
  end

  if (gl.DeleteShader) then
    gl.DeleteShader(depthShader or 0)
    gl.DeleteShader(blurShader_h or 0)
    gl.DeleteShader(blurShader_v or 0)
  end
end

function UnitPieceLight.ViewResize()
  gl.DeleteTexture(depthtex or 0)
  gl.DeleteTextureFBO(offscreentex or 0)
  gl.DeleteTextureFBO(blurtex or 0)

  gl.DeleteTextureFBO(offscreen4 or 0)
  gl.DeleteTextureFBO(offscreen8 or 0)
  gl.DeleteTextureFBO(blur4 or 0)
  gl.DeleteTextureFBO(blur8 or 0)

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
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
    fbo = true,
  })

  offscreen4 = gl.CreateTexture(math.ceil(vsx*0.25),math.ceil(vsy*0.25), {
    border = false,
    min_filter = GL.LINEAR,
    mag_filter = GL.LINEAR,
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
    fbo = true,
  })

  offscreen8 = gl.CreateTexture(math.ceil(vsx*0.125),math.ceil(vsy*0.125), {
    border = false,
    min_filter = GL.LINEAR,
    mag_filter = GL.LINEAR,
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
    fbo = true,
  })

  blurtex = gl.CreateTexture(math.ceil(vsx*0.5),math.ceil(vsy*0.5), {
    border = false,
    min_filter = GL.LINEAR,
    mag_filter = GL.LINEAR,
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
    fbo = true,
  })

  blur4 = gl.CreateTexture(math.ceil(vsx*0.25),math.ceil(vsy*0.25), {
    border = false,
    min_filter = GL.LINEAR,
    mag_filter = GL.LINEAR,
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
    fbo = true,
  })

  blur8 = gl.CreateTexture(math.ceil(vsx*0.125),math.ceil(vsy*0.125), {
    border = false,
    min_filter = GL.LINEAR,
    mag_filter = GL.LINEAR,
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
    fbo = true,
  })
end


function UnitPieceLight:Visible()
  local radius = 300
  local pos = {0,0,0}
  local losState

  local ux,uy,uz = Spring.GetUnitViewPosition(self.unit)
  if (ux) then
    pos[1],pos[2],pos[3] = pos[1]+ux,pos[2]+uy,pos[3]+uz
    radius = radius + Spring.GetUnitRadius(self.unit)
    losState = Spring.GetUnitLosState(self.unit, LocalAllyTeamID)

    return (losState.los)and(Spring.IsSphereInView(pos[1],pos[2],pos[3],radius))
  else
    return false
  end
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
