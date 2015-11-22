-- $Id: api_gfx_blur.lua 3171 2008-11-06 09:06:29Z det $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

---------------------------------------------------------------
-- TEH INTERFACE ----------------------------------------------
--
--  WG['guishader_api'].InsertRect(left,top,right,bottom) -> idx
--  WG['guishader_api'].RemoveRect(idx)
--  WG['guishader_api'].UseNoise(bool)

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

local imageDirectory	= ":n:"..LUAUI_DIRNAME.."Images/guishader/"

local OPTIONS = {}
OPTIONS.defaults = {	-- these will be loaded when switching style, but the style will overwrite the those values 
	name				= "Defaults",
	blurIntensity		= 0.001,
	useNoise			= false,
	noiseIntensity		= 0.01,
	noiseTexture		= "noise.dds",
	noiseMargin			= 0,
}
table.insert(OPTIONS, {
	name				= "Blur default",
	blurIntensity		= 0.0006,
})
--[[
table.insert(OPTIONS, {
	name				= "Glass 1",
	blurIntensity		= 0,001,
	useNoise			= true,
	noiseIntensity		= 0.01,
	noiseTexture		= "noise1.dds",
	noiseMargin			= 7,
})
table.insert(OPTIONS, {
	name				= "Glass 2",
	blurIntensity		= 0,001,
	useNoise			= true,
	noiseIntensity		= 0.066,
	noiseTexture		= "noise2.dds",
	noiseMargin			= 10,
})]]--
local currentOption = 1

function table.shallow_copy(t)
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end
OPTIONS_original = table.shallow_copy(OPTIONS)
OPTIONS_original.defaults = nil

local function toggleOptions()
	currentOption = currentOption + 1
	if not OPTIONS[currentOption] then
		currentOption = 1
	end
	loadOption()
	DeleteShaders()
	CreateShaders()
end

function loadOption()
	local appliedOption = OPTIONS_original[currentOption]
	OPTIONS[currentOption] = table.shallow_copy(OPTIONS.defaults)
	
	for option, value in pairs(appliedOption) do
		OPTIONS[currentOption][option] = value
	end
end
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


function widget:GetConfigData()
    savedTable = {}
    savedTable.currentOption = currentOption
	return savedTable
end

function widget:SetConfigData(data)
	if data.currentOption ~= nil and OPTIONS[data.currentOption] ~= nil then
		currentOption = data.currentOption or currentOption
		self:UpdateCallIns()
	end
end

function widget:UpdateCallIns()
  self:ViewResize(vsx, vsy)

  if (OPTIONS[currentOption].useNoise) then
    self.DrawScreenEffects = DrawScreenEffectsNoise
  else
    self.DrawScreenEffects = DrawScreenEffectsBlur
  end
  widgetHandler:UpdateCallIn("DrawScreenEffects")
end

function widget:TextCommand(command)
    if (string.find(command, "guishader") == 1  and  string.len(command) == 9) then 
		toggleOptions()
		Spring.Echo("GuiShader style: "..OPTIONS[currentOption].name)
		Spring.Echo("GuiShader: If artifacts show or not everything is updated... do a /luaui reload.")
		self:UpdateCallIns()
	end
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
        gl.Rect(adjustEdge(rect[1], true),adjustEdge(rect[2], false),adjustEdge(rect[3], true),adjustEdge(rect[4], false))
      end
    gl.PopMatrix()
  end)
end

function adjustEdge(value,isX)
	if OPTIONS[currentOption].useNoise then
		if isX then
			if value < OPTIONS[currentOption].noiseMargin then value = OPTIONS[currentOption].noiseMargin end
			if value > vsx-OPTIONS[currentOption].noiseMargin then value = vsx-OPTIONS[currentOption].noiseMargin end
		else
			if value < OPTIONS[currentOption].noiseMargin then value = OPTIONS[currentOption].noiseMargin end
			if value > vsy-OPTIONS[currentOption].noiseMargin then value = vsy-OPTIONS[currentOption].noiseMargin end
		end
	end
	return value
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
  
  loadOption()
  
  CreateShaders()

  self:UpdateCallIns()
  
  ---------------------------------------------------------------
  -- TEH INTERFACE
fullscreen = true
  WG['guishader_api'] = {}
  WG['guishader_api'].InsertRect = function(left,top,right,bottom,name)
      --if not name then
      --   name      = math.random(1024);
      --end
      guishaderRects[name] = {left,top,right,bottom};
      updateStencilTexture = true;
      --return name;
    end

  WG['guishader_api'].RemoveRect = function(name)
      guishaderRects[name] = nil;
      updateStencilTexture = true;
    end

  WG['guishader_api'].SetStyle = function(int)
	if int > 0 and int <= #OPTIONS then
      currentOption = int
      self:UpdateCallIns()
    else
      Spring.Echo("guishader api: invalid style id")
    end
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

  local str_blurShader_part2 = [[
        gl_FragColor = vec4(0.0,0.0,0.0,1.0);

        gl_FragColor.rgb += 1.78/16.0 * texture2D(tex0, texCoord + vec2(-intensity, -intensity)).rgb;
        gl_FragColor.rgb += 1.78/16.0 * texture2D(tex0, texCoord + vec2(-intensity,  0.0)).rgb;
        gl_FragColor.rgb += 1.78/16.0 * texture2D(tex0, texCoord + vec2(-intensity,  intensity)).rgb;
        
        gl_FragColor.rgb += 1.78/16.0 * texture2D(tex0, texCoord + vec2( 0.0,    -intensity)).rgb;
        gl_FragColor.rgb += 1.78/16.0 * texture2D(tex0, texCoord + vec2( 0.0,     0.0)).rgb;
        gl_FragColor.rgb += 1.78/16.0 * texture2D(tex0, texCoord + vec2( 0.0,     intensity)).rgb;
        
        gl_FragColor.rgb += 1.78/16.0 * texture2D(tex0, texCoord + vec2( intensity, -intensity)).rgb;
        gl_FragColor.rgb += 1.78/16.0 * texture2D(tex0, texCoord + vec2( intensity,  0.0)).rgb;
        gl_FragColor.rgb += 1.78/16.0 * texture2D(tex0, texCoord + vec2( intensity,  intensity)).rgb;
      }
  ]]

  local str_noiseShader_part2 = [[
        gl_FragColor = vec4(0.0,0.0,0.0,1.0);
        texCoord += intensity*(texture2D(tex1, 16.0*texCoord).xy-0.5); //noise
        gl_FragColor.rgb = texture2D(tex0, texCoord).rgb;
      }
  ]]

  -- create blur shaders
  blurShader = gl.CreateShader({
    fragment = "uniform sampler2D tex2; " .. str_blurShader_part1 .. 
               " float stencil = texture2D(tex2, texCoord).a; if (stencil<0.01) {gl_FragColor = texture2D(tex0, texCoord); return;} " ..
               str_blurShader_part2,
    uniform = {
      intensity = OPTIONS[currentOption].blurIntensity,
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

  blurFsShader = gl.CreateShader({
    fragment = str_blurShader_part1 .. str_blurShader_part2,
    uniformInt = {
      tex0 = 0,
    }
  })

  if (blurFsShader == nil) then
    Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader blurFsShader: shader error: "..gl.GetShaderLog())
    widgetHandler:RemoveWidget()
    return false
  end

  -- create noise shaders
  noiseShader = gl.CreateShader({
    fragment = "uniform sampler2D tex1; uniform sampler2D tex2; " .. str_blurShader_part1 .. 
               " float stencil = texture2D(tex2, texCoord).a; if (stencil<0.01) {gl_FragColor = texture2D(tex0, texCoord); return;} " ..
               str_noiseShader_part2,
    uniform = {
      intensity = OPTIONS[currentOption].noiseIntensity,
    },
    uniformInt = {
      tex0 = 0,
      tex1 = 1,
      tex2 = 2,
    }
  })

  if (noiseShader == nil) then
    Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader noiseShader: shader error: "..gl.GetShaderLog())
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
    Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader noiseFsShader: shader error: "..gl.GetShaderLog())
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
    gl.DeleteShader(blurFsShader or 0)
    gl.DeleteShader(blurShader or 0)
    gl.DeleteShader(noiseFsShader or 0)
    gl.DeleteShader(noiseShader or 0)
  end
  blurShader = nil
  blurFsShader = nil
  noiseShader = nil
  noiseFsShader = nil
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

function widget:DrawScreenEffectsNoise()
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
  gl.UseShader(noiseShader)

  gl.Texture(2,stenciltex)
  gl.Texture(2,false)
  gl.Texture(1,imageDirectory..OPTIONS[currentOption].noiseTexture)
  gl.Texture(1,false)

  gl.Texture(blurtex)
  gl.RenderToTexture(blurtex2, gl.TexRect, -1,1,1,-1)
  gl.Texture(blurtex2)
  gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)

  gl.UseShader(0)
  gl.Texture(blurtex)
  gl.TexRect(0,vsy,vsx,0) --// output to screen
  gl.Texture(false)

  gl.Blending(true)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
