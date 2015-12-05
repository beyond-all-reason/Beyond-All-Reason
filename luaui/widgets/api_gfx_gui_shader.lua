-- $Id: api_gfx_blur.lua 3171 2008-11-06 09:06:29Z det $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

---------------------------------------------------------------
-- TEH INTERFACE ----------------------------------------------
--
--  WG['guishader_api'].InsertRect(left,top,right,bottom) -> idx
--  WG['guishader_api'].RemoveRect(idx)

function widget:GetInfo()
  return {
    name      = "GUI-Shader",
    desc      = "Blurs the 3D-world under several other widgets UI elements.",
    author    = "Floris (original blurapi widget by: jK)",
    date      = "17 february 2015",
    license   = "GNU GPL, v2 or later",
    layer     = -10000,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
-- Console commands
--------------------------------------------------------------------------------

-- /guishader				-- toggles different styles!

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local imageDirectory			= ":n:"..LUAUI_DIRNAME.."Images/guishader/"
local blurIntensity				= 0.0006
local useSimplifiedShaderBelow	= 0.0007		-- generally a blurIntensity higher than 0.0006 will look uglier with the simplified shader version

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
local screencopy
local blurtex
local blurtex2
local stenciltex

local guishaderRects = {}
local updateStencilTexture = false

local oldvs = 0
local vsx, vsy   = widgetHandler:GetViewSizes()
local ivsx, ivsy = vsx, vsy
function widget:ViewResize(viewSizeX, viewSizeY)
  vsx, vsy  = viewSizeX,viewSizeY
  ivsx,ivsy = vsx, vsy

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
    Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader api: texture error")
    widgetHandler:RemoveWidget()
    return false
  end

  updateStencilTexture = true
end


function widget:UpdateCallIns()
  self:ViewResize(vsx, vsy)

  self.DrawScreenEffects = DrawScreenEffectsBlur
  widgetHandler:UpdateCallIn("DrawScreenEffects")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function DrawStencilTexture()
  if (next(guishaderRects)) then 
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
        Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader api: texture error")
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
      for _,rect in pairs(guishaderRects) do
        gl.Rect(rect[1],rect[2],rect[3],rect[4])
      end
    gl.PopMatrix()
  end)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function CheckHardware()
  if (not canCTT) then
    Spring.Echo("guishader api: your hardware is missing the necessary CopyToTexture feature")
    widgetHandler:RemoveWidget()
    return false
  end

  if (not canRTT) then
    Spring.Echo("guishader api: your hardware is missing the necessary RenderToTexture feature")
    widgetHandler:RemoveWidget()
    return false
  end

  if (not canShader) then
    Spring.Echo("guishader api: your hardware does not support shaders, OR: change springsettings: \"enable lua shaders\" ")
    widgetHandler:RemoveWidget()
    return false
  end

  if (not canFBO) then
    Spring.Echo("guishader api: your hardware does not fbo textures")
    widgetHandler:RemoveWidget()
    return false
  end

  if (not NON_POWER_OF_TWO) then
    Spring.Echo("guishader api: your hardware does not non-2^n-textures")
    widgetHandler:RemoveWidget()
    return false
  end

  return true
end

function widget:Initialize()
  if (not CheckHardware()) then return false end
  
  CreateShaders()

  self:UpdateCallIns()
  
  WG['guishader_api'] = {}
  WG['guishader_api'].InsertRect = function(left,top,right,bottom,name)
      guishaderRects[name] = {left,top,right,bottom};
      updateStencilTexture = true;
  end
  WG['guishader_api'].RemoveRect = function(name)
      guishaderRects[name] = nil;
      updateStencilTexture = true;
  end
end


function CreateShaders()

  local str_blurShader_part1 = [[
      uniform sampler2D tex0;
      uniform float intensity;
      
      void main(void)
      {
        vec2 texCoord = vec2(gl_TextureMatrix[0] * gl_TexCoord[0]);
  ]]
  
  local str_blurShader_part2
  if blurIntensity < useSimplifiedShaderBelow then 	-- a tad cheaper, but will show with higher blur value
	  str_blurShader_part2 = [[
			gl_FragColor = vec4(0.0,0.0,0.0,1.0);
			
			gl_FragColor.rgb += 0.165 * texture2D(tex0, texCoord + vec2(-intensity, -intensity)).rgb;
			gl_FragColor.rgb += 0.165 * texture2D(tex0, texCoord + vec2(-intensity,  0.0)).rgb;
			gl_FragColor.rgb += 0.165 * texture2D(tex0, texCoord + vec2(-intensity,  intensity)).rgb;
			
			gl_FragColor.rgb += 0.165 * texture2D(tex0, texCoord + vec2( intensity, -intensity)).rgb;
			gl_FragColor.rgb += 0.165 * texture2D(tex0, texCoord + vec2( intensity,  0.0)).rgb;
			gl_FragColor.rgb += 0.165 * texture2D(tex0, texCoord + vec2( intensity,  intensity)).rgb;
		 }
	  ]]
  else
	  str_blurShader_part2 = [[
			gl_FragColor = vec4(0.0,0.0,0.0,1.0);
        
			gl_FragColor.rgb += 0.11 * texture2D(tex0, texCoord + vec2(-intensity, -intensity)).rgb;
			gl_FragColor.rgb += 0.11 * texture2D(tex0, texCoord + vec2(-intensity,  0.0)).rgb;
			gl_FragColor.rgb += 0.11 * texture2D(tex0, texCoord + vec2(-intensity,  intensity)).rgb;
			
			gl_FragColor.rgb += 0.11 * texture2D(tex0, texCoord + vec2( 0.0,    -intensity)).rgb;
			gl_FragColor.rgb += 0.11 * texture2D(tex0, texCoord + vec2( 0.0,     0.0)).rgb;
			gl_FragColor.rgb += 0.11 * texture2D(tex0, texCoord + vec2( 0.0,     intensity)).rgb;
			
			gl_FragColor.rgb += 0.11 * texture2D(tex0, texCoord + vec2( intensity, -intensity)).rgb;
			gl_FragColor.rgb += 0.11 * texture2D(tex0, texCoord + vec2( intensity,  0.0)).rgb;
			gl_FragColor.rgb += 0.11 * texture2D(tex0, texCoord + vec2( intensity,  intensity)).rgb;
		  }
	  ]]
  end
  
  -- create blur shaders
  blurShader = gl.CreateShader({
    fragment = "uniform sampler2D tex2; " .. str_blurShader_part1 .. 
               " float stencil = texture2D(tex2, texCoord).a; if (stencil<0.01) {gl_FragColor = texture2D(tex0, texCoord); return;} " ..
               str_blurShader_part2,
    uniform = {
      intensity = blurIntensity,
    },
    uniformInt = {
      tex0 = 0,
      tex2 = 2,
    }
  })

  if (blurShader == nil) then
    Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader blurShader: shader error: "..gl.GetShaderLog())
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
    Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader api: texture error")
    widgetHandler:RemoveWidget()
    return false
  end
end


function DeleteShaders()
  if (gl.DeleteTextureFBO) then
    gl.DeleteTextureFBO(blurtex)
    gl.DeleteTextureFBO(blurtex2)
    gl.DeleteTextureFBO(stenciltex)
  end
  gl.DeleteTexture(screencopy or 0)

  if (gl.DeleteShader) then
    gl.DeleteShader(blurShader or 0)
  end
  blurShader = nil
end

function widget:Shutdown()
  DeleteShaders()
  WG['guishader_api'] = nil
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:DrawScreenEffectsBlur()
  if Spring.IsGUIHidden() then return end
  if not next(guishaderRects) then return end

  gl.Texture(false)
  gl.Color(1,1,1,1)
  gl.Blending(false)

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
  gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)

  gl.UseShader(0)
  gl.Texture(blurtex)
  gl.TexRect(0,vsy,vsx,0)
  gl.Texture(false)

  gl.Blending(true)
end
