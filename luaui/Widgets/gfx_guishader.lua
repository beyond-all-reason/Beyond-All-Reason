-- Intel GPU compatibility: Use a simplified shader path
-- The complex derivative-based quad message passing doesn't work reliably on Intel GPUs
local isIntelGPU = Platform ~= nil and Platform.gpuVendor == 'Intel'

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "GUI Shader",
		desc = "Blurs the 3D-world under several other widgets UI elements.",
		author = "Floris (original blurapi widget by: jK)",
		date = "17 february 2015",
		license = "GNU GPL, v2 or later",
		layer = -990000, -- other widgets can be run earlier (lower layer) and thus guishader blur are will lag behind a frame, (like tooltip screenblur)
		enabled = true
	}
end


-- Localized functions for performance
local mathMax = math.max

-- Localized Spring API for performance
local spEcho = Spring.Echo
local spGetViewGeometry = Spring.GetViewGeometry

local uiOpacity = Spring.GetConfigFloat("ui_opacity", 0.7)

local defaultBlurIntensity = 1

-- hardware capability
local canShader = gl.CreateShader ~= nil

local LuaShader = gl.LuaShader
local NON_POWER_OF_TWO = gl.HasExtension("GL_ARB_texture_non_power_of_two")

local renderDlists = {}
local deleteDlistQueue = {}
local blurShader

local screencopyUI -- this is for the special case of UI blur

local stenciltex
local stenciltexScreen

local screenBlur = false

local blurIntensity = defaultBlurIntensity
local guishaderRects = {}
local guishaderDlists = {}
local guishaderScreenRects = {}
local guishaderScreenDlists = {}
local updateStencilTexture = false
local updateStencilTextureScreen = false

local oldvs = 0
local vsx, vsy, vpx, vpy = spGetViewGeometry()

function widget:ViewResize(_, _)
	vsx, vsy, vpx, vpy = spGetViewGeometry()

	if screencopyUI then gl.DeleteTexture(screencopyUI) end
	screencopyUI = gl.CreateTexture(vsx, vsy, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP,
		wrap_t = GL.CLAMP,
	})

	updateStencilTexture = true
	updateStencilTextureScreen = true
end

local function DrawStencilTexture(world, fullscreen)
	--spEcho("DrawStencilTexture",world, fullscreen, Spring.GetDrawFrame(), updateStencilTexture)
	local usedStencilTex
	if world then
		usedStencilTex = stenciltex
		stenciltex = nil
	else
		usedStencilTex = stenciltexScreen
		stenciltexScreen = nil
	end

	if next(guishaderRects) or next(guishaderScreenRects) or next(guishaderDlists) then

		if usedStencilTex == nil or vsx + vsy ~= oldvs then
			gl.DeleteTexture(usedStencilTex)

			oldvs = vsx + vsy
			usedStencilTex = gl.CreateTexture(vsx, vsy, {
				border = false,
				min_filter = GL.NEAREST,
				mag_filter = GL.NEAREST,
				wrap_s = GL.CLAMP,
				wrap_t = GL.CLAMP,
				fbo = true,
			})

			if usedStencilTex == nil then
				Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader api: texture error")
				widgetHandler:RemoveWidget()
				return false
			end
		end
	else
		gl.RenderToTexture(usedStencilTex, gl.Clear, GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
		return
	end
	--gl.Texture(false)
	gl.RenderToTexture(usedStencilTex, function()
		gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
		gl.PushMatrix()
		gl.Translate(-1, -1, 0)
		gl.Scale(2 / vsx, 2 / vsy, 0)
		if world then
			for _, rect in pairs(guishaderRects) do
				gl.Rect(rect[1], rect[2], rect[3], rect[4])
			end
			for _, dlist in pairs(guishaderDlists) do
				gl.Color(1,1,1,1)
				gl.CallList(dlist)
			end
		elseif fullscreen then
			gl.Rect(0, 0, vsx, vsy)
		else
			for _, rect in pairs(guishaderScreenRects) do
				gl.Rect(rect[1], rect[2], rect[3], rect[4])
			end
			for _, dlist in pairs(guishaderScreenDlists) do
				gl.Color(1,1,1,1)
				gl.CallList(dlist)
			end
		end
		gl.PopMatrix()
	end)

	if world then
		stenciltex = usedStencilTex
	else
		stenciltexScreen = usedStencilTex
	end
	usedStencilTex = nil
end

local function CheckHardware()
	if not canShader then
		spEcho("guishader api: your hardware does not support shaders, OR: change springsettings: \"enable lua shaders\" ")
		widgetHandler:RemoveWidget()
		return false
	end

	if not NON_POWER_OF_TWO then
		spEcho("guishader api: your hardware does not non-2^n-textures")
		widgetHandler:RemoveWidget()
		return false
	end

	return true
end

local function CreateShaders()
	if blurShader then
		blurShader:Finalize()
	end

	-- create blur shaders
	local fragmentShaderCode
	
	if isIntelGPU then
		-- Intel GPUs: Use simple box blur with weighted distribution for quality
		-- Avoids derivative functions (dFdx/dFdy) which are buggy on Intel drivers
		fragmentShaderCode = [[
		#version 120
		uniform sampler2D tex2;
		uniform sampler2D tex0;
		uniform float ivsx;
		uniform float ivsy;

		void main(void)
		{
			vec2 texCoord = gl_TexCoord[0].st;
			float stencil = texture2D(tex2, texCoord).a;
			
			if (stencil < 0.01)
			{
				discard;
			}
			
			// 9-sample weighted blur for smooth, high-quality results
			vec4 sum = vec4(0.0);
			vec2 offset = vec2(ivsx, ivsy) * 6.0;
			
			// Center sample gets highest weight
			sum += texture2D(tex0, texCoord) * 4.0;
			
			// Cardinal directions weighted higher
			sum += texture2D(tex0, texCoord + vec2(offset.x, 0.0)) * 2.0;
			sum += texture2D(tex0, texCoord - vec2(offset.x, 0.0)) * 2.0;
			sum += texture2D(tex0, texCoord + vec2(0.0, offset.y)) * 2.0;
			sum += texture2D(tex0, texCoord - vec2(0.0, offset.y)) * 2.0;
			
			// Diagonal corners for smoothness
			sum += texture2D(tex0, texCoord + offset);
			sum += texture2D(tex0, texCoord - offset);
			sum += texture2D(tex0, texCoord + vec2(offset.x, -offset.y));
			sum += texture2D(tex0, texCoord + vec2(-offset.x, offset.y));
			
			gl_FragColor = sum / 17.0;
		}
		]]
	else
		-- Other GPUs: Use optimized shader with quad message passing
		fragmentShaderCode = [[
		#version 150 compatibility
		uniform sampler2D tex2;
		uniform sampler2D tex0;
		uniform int intensity;
		uniform float ivsx;
		uniform float ivsy;

		vec2 quadGetQuadVector(vec2 screenCoords){
			vec2 quadVector =  fract(floor(screenCoords) * 0.5) * 4.0 - 1.0;
			vec2 odd_start_mirror = 0.5 * vec2(dFdx(quadVector.x), dFdy(quadVector.y));
			quadVector = quadVector * odd_start_mirror;
			return sign(quadVector);
		}

		void main(void)
		{
			vec2 texCoord = vec2(gl_TextureMatrix[0] * gl_TexCoord[0]);
			float stencil = texture2D(tex2, texCoord).a;
			if (stencil<0.01)
			{
				gl_FragColor = vec4(0.0);
				return;
			}else{
				gl_FragColor = vec4(0.0,0.0,0.0,1.0);
				vec4 sum = vec4(0.0);
				#if 0
					vec2 subpixel = vec2(ivsx, ivsy) ;
					//subpixel *= 0.0;
					for (int i = -1; i <= 1; ++i) {
						for (int j = -1; j <= 1; ++j) {
							vec2 samplingCoords = texCoord + vec2(i, j) * 6.0 * subpixel + subpixel;
							sum += texture2D(tex0, samplingCoords);
						}
					}
					gl_FragColor.rgba = sum/9.0;
				#else
					//amazingly useless pixel quad message passing for less hammering of membus? 4 lookups instead of 9
					vec2 quadVector = quadGetQuadVector(gl_FragCoord.xy);
					vec2 subpixel = vec2(ivsx, ivsy) ;
					subpixel *= quadVector;
					//subpixel *= 0.0;
					for (int i = 0; i <= 1; ++i) {
						for (int j = 0; j <= 1; ++j) {
							vec2 samplingCoords = texCoord + vec2(i, j) * 6.0 * subpixel + subpixel;
							sum += texture2D(tex0, samplingCoords);
						}
					}

					vec4 inputadjx = sum - dFdx(sum) * quadVector.x;
					vec4 inputadjy = sum - dFdy(sum) * quadVector.y;
					vec4 inputdiag = inputadjx - dFdy(inputadjx) * quadVector.y;
					sum += inputadjx + inputadjy + inputdiag;

					gl_FragColor.rgba = sum/16.0;
				#endif
				//gl_FragColor.rgba = vec4(1.0);
			}
		}
		]]
	end

	blurShader = LuaShader({
		fragment = fragmentShaderCode,

		uniformInt = {
			tex0 = 0,
			tex2 = 2,
		},
		uniformFloat = {
			intensity = blurIntensity,
			offset = 0,
			ivsx = 0,
			ivsy = 0,
		}
	}, "guishader blurShader")


	if not blurShader:Initialize() then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader blurShader: shader error: " .. gl.GetShaderLog())
		widgetHandler:RemoveWidget()
		return false
	end



	screencopyUI = gl.CreateTexture(vsx, vsy, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP,
		wrap_t = GL.CLAMP,
	})

	if screencopyUI == nil then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader api: texture error")
		widgetHandler:RemoveWidget()
		return false
	end
end

local function DeleteShaders()
	gl.DeleteTexture(stenciltex)
	gl.DeleteTexture(stenciltexScreen)
	gl.DeleteTexture(usedStencilTex)
	gl.DeleteTexture(screencopyUI)
	stenciltex, stenciltexScreen, screencopyUI, usedStencilTex = nil, nil, nil, nil
	if blurShader then blurShader:Finalize() end
	blurShader = nil
end

function widget:Shutdown()
	DeleteShaders()
	WG['guishader'] = nil
	widgetHandler:DeregisterGlobal('GuishaderInsertRect')
	widgetHandler:DeregisterGlobal('GuishaderRemoveRect')
end

function widget:DrawScreenEffects() -- This blurs the world underneath UI elements
	if Spring.IsGUIHidden() or uiOpacity > 0.99 then
		return
	end

	if not screenBlur and blurShader then
		if not next(guishaderRects) and not next(guishaderDlists) then
			return
		end

		if WG['screencopymanager'] and WG['screencopymanager'].GetScreenCopy then
			screencopy = WG['screencopymanager'].GetScreenCopy()
		else
			spEcho("Missing Screencopy Manager, exiting",  WG['screencopymanager'] )
			widgetHandler:RemoveWidget()
			return false
		end

		if screencopy == nil then return end

		gl.Texture(false)
		gl.Color(1, 1, 1, 1) --needed? nope
		gl.Blending(true)

		if updateStencilTexture then
			DrawStencilTexture(true)
			updateStencilTexture = false
		end

		-- Debug: Check if stencil texture exists
		if isIntelGPU and stenciltex == nil then
			spEcho("DEBUG: stenciltex is nil!")
		end

		gl.Blending(true)
		gl.Texture(screencopy)
		gl.Texture(2, stenciltex)
		blurShader:Activate()
			--blurShader:SetUniform("intensity", mathMax(blurIntensity, 0.0015))
			blurShader:SetUniform("ivsx", 0.5/vsx)
			blurShader:SetUniform("ivsy", 0.5/vsy)

			gl.TexRect(0, vsy, vsx, 0) -- draw the blurred version
		blurShader:Deactivate()

		gl.Texture(2, false)
		gl.Texture(false)
		gl.Blending(false)
	end
end

local function DrawScreen() -- This blurs the UI elements obscured by other UI elements (only unit stats so far!)
	if Spring.IsGUIHidden() or uiOpacity > 0.99 then
		return
	end

	for i, dlist in ipairs(deleteDlistQueue) do
		gl.DeleteList(dlist)
		updateStencilTexture = true
	end
	deleteDlistQueue = {}

	--if true then return false end
	if (screenBlur or next(guishaderScreenRects) or next(guishaderScreenDlists)) and blurShader then
		gl.Texture(false)
		gl.Color(1, 1, 1, 1)
		gl.Blending(true)

		if updateStencilTextureScreen then
			DrawStencilTexture(false, screenBlur)
			updateStencilTextureScreen = false
		end

		gl.CopyToTexture(screencopyUI, 0, 0, vpx, vpy, vsx, vsy)
		gl.Texture(screencopyUI)

		gl.Texture(2, stenciltexScreen)

		blurShader:Activate()
			--blurShader:SetUniform("intensity", mathMax(blurIntensity, 0.0015))
			blurShader:SetUniform("ivsx", 0.5/vsx)
			blurShader:SetUniform("ivsy", 0.5/vsy)

			gl.TexRect(0, vsy, vsx, 0) -- draw the blurred version
		blurShader:Deactivate()
		gl.Texture(2, false)
		gl.Texture(false)
	end

	for k, v in pairs(renderDlists) do
		gl.Color(1,1,1,1)
		gl.CallList(k)
	end
end

function widget:DrawScreen()
	uiOpacity = Spring.GetConfigFloat("ui_opacity", 0.7)
	DrawScreen()
end

function widget:UpdateCallIns()
	self:ViewResize(vsx, vsy)
end

function widget:Initialize()
	if not CheckHardware() then
		return false
	end

	CreateShaders()

	self:UpdateCallIns()

	WG['guishader'] = {}
	WG['guishader'].InsertDlist = function(dlist, name, force)
		if force or guishaderDlists[name] ~= dlist then
			guishaderDlists[name] = dlist
			updateStencilTexture = true
		end
	end
	WG['guishader'].RemoveDlist = function(name)
		local found = guishaderDlists[name] ~= nil
		if found then
			guishaderDlists[name] = nil
			updateStencilTexture = true
		end
		return found
	end
	WG['guishader'].DeleteDlist = function(name)
		local found = guishaderDlists[name] ~= nil
		if found then
			deleteDlistQueue[#deleteDlistQueue + 1] = guishaderDlists[name]
			guishaderDlists[name] = nil
			updateStencilTexture = true
		end
		return found
	end
	WG['guishader'].InsertRect = function(left, top, right, bottom, name)
		guishaderRects[name] = { left, top, right, bottom }
		updateStencilTexture = true
	end
	WG['guishader'].RemoveRect = function(name)
		local found = guishaderRects[name] ~= nil
		if found then
			guishaderRects[name] = nil
			updateStencilTexture = true
		end
		return found
	end
	WG['guishader'].InsertScreenDlist = function(dlist, name)
		guishaderScreenDlists[name] = dlist
		updateStencilTextureScreen = true
	end
	WG['guishader'].RemoveScreenDlist = function(name)
		local found = guishaderScreenDlists[name] ~= nil
		if found then
			guishaderScreenDlists[name] = nil
			updateStencilTextureScreen = true
		end
		return found
	end
	WG['guishader'].DeleteScreenDlist = function(name)
		local found = guishaderScreenDlists[name] ~= nil
		if found then
			deleteDlistQueue[#deleteDlistQueue + 1] = guishaderScreenDlists[name]
			guishaderScreenDlists[name] = nil
		end
		return found
	end
	WG['guishader'].InsertScreenRect = function(left, top, right, bottom, name)
		guishaderScreenRects[name] = { left, top, right, bottom }
		updateStencilTextureScreen = true
	end
	WG['guishader'].RemoveScreenRect = function(name)
		local found = guishaderScreenRects[name] ~= nil
		if found then
			guishaderScreenRects[name] = nil
			updateStencilTextureScreen = true
		end
		return found
	end
	WG['guishader'].getBlurDefault = function()
		return defaultBlurIntensity
	end
	WG['guishader'].getBlurIntensity = function()
		return blurIntensity
	end
	WG['guishader'].setBlurIntensity = function(value)
		if value == nil then
			value = defaultBlurIntensity
		end
		if tonumber(value) == nil then
			spEcho("Attempted to set blurIntensity to a non-number:",value," resetting to default")
			blurIntensity = defaultBlurIntensity
		else
			blurIntensity = value
		end
	end

	WG['guishader'].setScreenBlur = function(value)
		updateStencilTextureScreen = true
		screenBlur = value
	end
	WG['guishader'].getScreenBlur = function(value)
		return screenBlur
	end

	-- will let it draw a given dlist to be rendered on top of screenblur
	WG['guishader'].insertRenderDlist = function(value)
		renderDlists[value] = true
	end
	WG['guishader'].removeRenderDlist = function(value)
		if renderDlists[value] then
			renderDlists[value] = nil
		end
	end

	WG.guishader.DrawScreen = DrawScreen	-- widgethandler wont call DrawScreen when chobby interface is shown, but it will call this one as exception

	widgetHandler:RegisterGlobal('GuishaderInsertRect', WG['guishader'].InsertRect)
	widgetHandler:RegisterGlobal('GuishaderRemoveRect', WG['guishader'].RemoveRect)
end

function widget:GetConfigData(data)
	return { blurIntensity = blurIntensity }
end

function widget:SetConfigData(data)
	if data.blurIntensity ~= nil then
		if tonumber(data.blurIntensity) == nil then
			spEcho("Attempted to set blurIntensity to a non-number:",data.blurIntensity," resetting to default")
			blurIntensity = defaultBlurIntensity
		else
			blurIntensity = data.blurIntensity
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		screenBlur = (msg:sub(1, 19) == 'LobbyOverlayActive1')
		updateStencilTextureScreen = true
	end
end
