-- $Id: api_gfx_blur.lua 3171 2008-11-06 09:06:29Z det $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

---------------------------------------------------------------
-- TEH INTERFACE ----------------------------------------------
--
--  WG['blur_api'].Fullscreen(on)
--  WG['blur_api'].InsertBlurRect(left,top,right,bottom) -> idx
--  WG['blur_api'].RemoveBlurRect(idx)
--  WG['blur_api'].BlurNow(rects)
--  WG['blur_api'].UseNoise(bool)
--  WG['blur_api'].Quality(int)   1->highest, 1+x->worse

function widget:GetInfo()
  return {
    name      = "BlurApi",
    desc      = "An interface for other widgets to blur the world screen.",
    author    = "jK",
    date      = "Mar, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = -10000,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local quality  = 1
local useNoise = false

local noiseTexture = ":n:LuaUI/Images/noise.png"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--hardware capability

local canRTT    = (gl.RenderToTexture ~= nil)
local canCTT    = (gl.CopyToTexture ~= nil)
local canShader = (gl.CreateShader ~= nil)
local canFBO    = (gl.DeleteTextureFBO ~= nil)

local NON_POWER_OF_TWO = gl.HasExtension("GL_ARB_texture_non_power_of_two")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local blurShader
local blurFsShader --fullscreen
local noiseShader
local noiseFsShader --fullscreen
local screencopy
local blurtex
local blurtex2
local stenciltex

local fullscreen = false

local BlurRects = {}
local updateStencilTexture = false

local oldvs = 0
local vsx, vsy   = widgetHandler:GetViewSizes()
local ivsx, ivsy = math.floor(vsx/quality), math.floor(vsy/quality)
function widget:ViewResize(viewSizeX, viewSizeY)
  vsx, vsy  = viewSizeX,viewSizeY
  ivsx,ivsy = math.floor(vsx/quality), math.floor(vsy/quality)

  if (gl.DeleteTextureFBO) then
    gl.DeleteTextureFBO(blurtex)
    gl.DeleteTextureFBO(blurtex2)
    gl.DeleteTexture(screencopy)
  end

  screencopy = gl.CreateTexture(vsx, vsy, {
    border = false,
    min_filter = GL.NEAREST,
    mag_filter = GL.NEAREST,
  })
  blurtex = gl.CreateTexture(ivsx, ivsy, {
    border = false,
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
    fbo = true,
  })
  blurtex2 = gl.CreateTexture(ivsx, ivsy, {
    border = false,
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
    fbo = true,
  })

  if (blurtex == nil)or(blurtex2 == nil)or(screencopy == nil) then
    Spring.Echo("blur api: texture error")
    widgetHandler:RemoveWidget()
    return false
  end

  updateStencilTexture = true
end


function widget:GetConfigData()
  return {
    quality  = quality,
    useNoise = useNoise,
  }
end

function widget:SetConfigData(data)
  quality  = data.quality  or 1
  useNoise = data.useNoise or false

  self:UpdateCallIns()
end

function widget:UpdateCallIns()
  self:ViewResize(vsx, vsy)

  if (useNoise) then
    self.DrawScreenEffects = DrawScreenEffectsNoise
  else
    self.DrawScreenEffects = DrawScreenEffectsBlur
  end
  widgetHandler:UpdateCallIn("DrawScreenEffects")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function DrawStencilTexture()
  if (next(BlurRects)) then 
    if (stenciltex == nil)or(vsx+vsy~=oldvs) then
      gl.DeleteTextureFBO(stenciltex)

      oldvs = vsx+vsy
      stenciltex = gl.CreateTexture(vsx, vsy, {
        border = false,
        min_filter = GL.NEAREST,
        mag_filter = GL.NEAREST,
        wrap_s = GL.CLAMP,
        wrap_t = GL.CLAMP,
        fbo = true,
      })

      if (stenciltex == nil) then
        Spring.Echo("blur api: texture error")
        widgetHandler:RemoveWidget()
        return false
      end
    end 
  else
    gl.RenderToTexture(stenciltex, gl.Clear, GL.COLOR_BUFFER_BIT ,0,0,0,0)
    return
  end

  gl.RenderToTexture(stenciltex, function()
    gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
    gl.PushMatrix()
      gl.Translate(-1,-1,0)
      gl.Scale(2/vsx,2/vsy,0)
      for _,rect in pairs(BlurRects) do
        gl.Rect(rect[1],rect[2],rect[3],rect[4])
      end
    gl.PopMatrix()
  end)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function CheckHardware()
  if (not canCTT) then
    Spring.Echo("blur api: your hardware is missing the necessary CopyToTexture feature")
    widgetHandler:RemoveWidget()
    return false
  end

  if (not canRTT) then
    Spring.Echo("blur api: your hardware is missing the necessary RenderToTexture feature")
    widgetHandler:RemoveWidget()
    return false
  end

  if (not canShader) then
    Spring.Echo("blur api: your hardware does not support shaders")
    widgetHandler:RemoveWidget()
    return false
  end

  if (not canFBO) then
    Spring.Echo("blur api: your hardware does not fbo textures")
    widgetHandler:RemoveWidget()
    return false
  end

  if (not NON_POWER_OF_TWO) then
    Spring.Echo("blur api: your hardware does not non-2^n-textures")
    widgetHandler:RemoveWidget()
    return false
  end

  return true
end

function widget:Initialize()
  if (not CheckHardware()) then return false end

  -- create shaders code
  local str_blurShader_part1 = [[
      uniform sampler2D tex0;
      
      void main(void)
      {

        vec2 texCoord = vec2(gl_TextureMatrix[0] * gl_TexCoord[0]);
  ]]

  local str_blurShader_part2 = [[
        gl_FragColor = vec4(0.0,0.0,0.0,1.0);

	gl_FragColor.rgb += 1.0/16.0 * texture2D(tex0, texCoord + vec2(-0.0017, -0.0017)).rgb;
	gl_FragColor.rgb += 2.0/16.0 * texture2D(tex0, texCoord + vec2(-0.0017,  0.0)).rgb;
	gl_FragColor.rgb += 1.0/16.0 * texture2D(tex0, texCoord + vec2(-0.0017,  0.0017)).rgb;
	gl_FragColor.rgb += 2.0/16.0 * texture2D(tex0, texCoord + vec2( 0.0,    -0.0017)).rgb;
	gl_FragColor.rgb += 5.0/16.0 * texture2D(tex0, texCoord + vec2( 0.0,     0.0)).rgb;
	gl_FragColor.rgb += 2.0/16.0 * texture2D(tex0, texCoord + vec2( 0.0,     0.0017)).rgb;
	gl_FragColor.rgb += 1.0/16.0 * texture2D(tex0, texCoord + vec2( 0.0017, -0.0017)).rgb;
	gl_FragColor.rgb += 2.0/16.0 * texture2D(tex0, texCoord + vec2( 0.0017,  0.0)).rgb;
	gl_FragColor.rgb += 1.0/16.0 * texture2D(tex0, texCoord + vec2( 0.0017,  0.0017)).rgb;
      }
  ]]

  local str_noiseShader_part2 = [[
        gl_FragColor = vec4(0.0,0.0,0.0,1.0);
        texCoord += 0.008*(texture2D(tex1, 16.0*texCoord).xy-0.5); //noise
        gl_FragColor.rgb = texture2D(tex0, texCoord).rgb;
      }
  ]]

  -- create blur shaders
  blurShader = gl.CreateShader({
    fragment = "uniform sampler2D tex2; " .. str_blurShader_part1 .. 
               " float stencil = texture2D(tex2, texCoord).a; if (stencil<0.01) {gl_FragColor = texture2D(tex0, texCoord); return;} " ..
               str_blurShader_part2,
    uniformInt = {
      tex0 = 0,
      tex2 = 2,
    }
  })

  if (blurShader == nil) then
    Spring.Echo("blurShader: shader error: "..gl.GetShaderLog())
    widgetHandler:RemoveWidget()
    return false
  end

  blurFsShader = gl.CreateShader({
    fragment = str_blurShader_part1 .. str_blurShader_part2,
    uniformInt = {
      tex0 = 0,
    }
  })

  if (blurFsShader == nil) then
    Spring.Echo("blurFsShader: shader error: "..gl.GetShaderLog())
    widgetHandler:RemoveWidget()
    return false
  end

  -- create noise shaders
  noiseShader = gl.CreateShader({
    fragment = "uniform sampler2D tex1; uniform sampler2D tex2; " .. str_blurShader_part1 .. 
               " float stencil = texture2D(tex2, texCoord).a; if (stencil<0.01) {gl_FragColor = texture2D(tex0, texCoord); return;} " ..
               str_noiseShader_part2,
    uniformInt = {
      tex0 = 0,
      tex1 = 1,
      tex2 = 2,
    }
  })

  if (noiseShader == nil) then
    Spring.Echo("noiseShader: shader error: "..gl.GetShaderLog())
    widgetHandler:RemoveWidget()
    return false
  end

  noiseFsShader = gl.CreateShader({
    fragment = "uniform sampler2D tex1;" .. str_blurShader_part1 .. str_noiseShader_part2,
    uniformInt = {
      tex0 = 0,
      tex1 = 1,
    }
  })

  if (noiseFsShader == nil) then
    Spring.Echo("noiseFsShader: shader error: "..gl.GetShaderLog())
    widgetHandler:RemoveWidget()
    return false
  end

  -- create blurtextures
  screencopy = gl.CreateTexture(vsx, vsy, {
    border = false,
    min_filter = GL.NEAREST,
    mag_filter = GL.NEAREST,
  })
  blurtex = gl.CreateTexture(ivsx, ivsy, {
    border = false,
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
    fbo = true,
  })
  blurtex2 = gl.CreateTexture(ivsx, ivsy, {
    border = false,
    wrap_s = GL.CLAMP,
    wrap_t = GL.CLAMP,
    fbo = true,
  })

  -- debug?
  if (blurtex == nil)or(blurtex2 == nil)or(screencopy == nil) then
    Spring.Echo("blur api: texture error")
    widgetHandler:RemoveWidget()
    return false
  end

  self:UpdateCallIns()

  ---------------------------------------------------------------
  -- TEH INTERFACE

  WG['blur_api'] = {}
  WG['blur_api'].Fullscreen = function(on)
      fullscreen = on
    end

  WG['blur_api'].InsertBlurRect = function(left,top,right,bottom)
      local idx      = math.random(1024);
      BlurRects[idx] = {left,top,right,bottom};
      updateStencilTexture = true;
      return idx;
    end

  WG['blur_api'].RemoveBlurRect = function(idx)
      BlurRects[idx] = nil;
      updateStencilTexture = true;
    end

  WG['blur_api'].BlurNow = function(rects)
      local oldFullscreen = fullscreen;
      local oldBlurRects  = BlurRects;
      BlurRects  = rects;
      fullscreen = false;
      DrawStencilTexture();
      if (useNoise) then
        self:DrawScreenEffectsNoise();
      else
        self:DrawScreenEffectsBlur();
      end
      BlurRects  = oldBlurRects;
      fullscreen = oldFullscreen;
      updateStencilTexture = true;
    end

  WG['blur_api'].UseNoise = function(bool)
      useNoise = bool
      self:UpdateCallIns()
    end

  WG['blur_api'].Quality = function(int)
      quality = int
      self:UpdateCallIns()
    end
end


function widget:Shutdown()
  if (gl.DeleteTextureFBO) then
    gl.DeleteTextureFBO(blurtex)
    gl.DeleteTextureFBO(blurtex2)
    gl.DeleteTextureFBO(stenciltex)
  end
  gl.DeleteTexture(screencopy or 0)

  if (gl.DeleteShader) then
    gl.DeleteShader(blurFsShader or 0)
    gl.DeleteShader(blurShader or 0)
    gl.DeleteShader(noiseFsShader or 0)
    gl.DeleteShader(noiseShader or 0)
  end
  WG['blur_api'] = nil
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawScreenEffectsBlur()
  if (fullscreen) then

    gl.CopyToTexture(screencopy, 0, 0, 0, 0, vsx, vsy)
    gl.Texture(screencopy)
    gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)
    gl.UseShader(blurFsShader)

    gl.Texture(blurtex)
    gl.RenderToTexture(blurtex2, gl.TexRect, -1,1,1,-1)
    gl.Texture(blurtex2)
    gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)

    gl.Texture(blurtex)
    gl.TexRect(0,vsy,vsx,0)

    gl.Texture(false)
    gl.UseShader(0)

  elseif (next(BlurRects)) then

    if updateStencilTexture then
      DrawStencilTexture();
      updateStencilTexture = false;
    end

    gl.CopyToTexture(screencopy, 0, 0, 0, 0, vsx, vsy)
    gl.Texture(screencopy)
    gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)
    gl.UseShader(blurShader)

    gl.Texture(2,stenciltex)
    gl.Texture(2,false)

    gl.Texture(blurtex)
    gl.RenderToTexture(blurtex2, gl.TexRect, -1,1,1,-1)
    gl.Texture(blurtex2)
    --gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)

    gl.UseShader(0)
    --gl.Texture(blurtex)
    gl.TexRect(0,vsy,vsx,0)
    gl.Texture(false)

  end
end

function widget:DrawScreenEffectsNoise()
  if (fullscreen) then

    gl.CopyToTexture(screencopy, 0, 0, 0, 0, vsx, vsy)
    gl.Texture(screencopy)
    gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)
    gl.UseShader(noiseFsShader)

    gl.Texture(1,noiseTexture)
    gl.Texture(1,false)
    gl.Texture(blurtex)
    gl.RenderToTexture(blurtex2, gl.TexRect, -1,1,1,-1)
    gl.Texture(blurtex2)
    gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)
    gl.Texture(blurtex)
    gl.TexRect(0,vsy,vsx,0) --// output to screen

    gl.Texture(false)
    gl.UseShader(0)

  elseif (next(BlurRects)) then

    if updateStencilTexture then
      DrawStencilTexture();
      updateStencilTexture = false;
    end

    gl.CopyToTexture(screencopy, 0, 0, 0, 0, vsx, vsy)
    gl.Texture(screencopy)
    gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)
    gl.UseShader(noiseShader)

    gl.Texture(2,stenciltex)
    gl.Texture(2,false)
    gl.Texture(1,noiseTexture)
    gl.Texture(1,false)

    gl.Texture(blurtex)
    gl.RenderToTexture(blurtex2, gl.TexRect, -1,1,1,-1)
    gl.Texture(blurtex2)
    gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)
    gl.Texture(blurtex)

    gl.UseShader(0)
    gl.TexRect(0,vsy,vsx,0) --// output to screen
    gl.Texture(false)

  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
