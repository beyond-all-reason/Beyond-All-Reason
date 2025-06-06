-- disable for intel cards (else it will render solid dark screen)
if Platform ~= nil and Platform.gpuVendor == 'Intel' then
	return
end

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

local uiOpacity = Spring.GetConfigFloat("ui_opacity", 0.7)

local defaultBlurIntensity = 1

-- hardware capability
local canShader = gl.CreateShader ~= nil
local NON_POWER_OF_TWO = gl.HasExtension("GL_ARB_texture_non_power_of_two")

local renderDlists = {}
local deleteDlistQueue = {}
local blurShader

local screencopyUI -- this is for the special case of UI blur

local stenciltex
local stenciltexScreen
local intensityLoc
local ivsxLoc
local ivsyLoc

local screenBlur = false

local blurIntensity = defaultBlurIntensity
local guishaderRects = {}
local guishaderDlists = {}
local guishaderScreenRects = {}
local guishaderScreenDlists = {}
local updateStencilTexture = false
local updateStencilTextureScreen = false

local oldvs = 0
local vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
local ivsx, ivsy = vsx, vsy
local intensityMult = (vsx + vsy) / 1600

function widget:ViewResize(_, _)
	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
	ivsx, ivsy = vsx, vsy

	if screencopyUI then gl.DeleteTexture(screencopyUI) end
	screencopyUI = gl.CreateTexture(vsx, vsy, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP,
		wrap_t = GL.CLAMP,
	})

	intensityMult = (vsx + vsy) / 2800
	updateStencilTexture = true
	updateStencilTextureScreen = true
end

local function DrawStencilTexture(world, fullscreen)
	--Spring.Echo("DrawStencilTexture",world, fullscreen, Spring.GetDrawFrame(), updateStencilTexture)
	local usedStencilTex = world and stenciltex or stenciltexScreen

	if next(guishaderRects) or next(guishaderScreenRects) or next(guishaderDlists) then

		if usedStencilTex == nil or vsx + vsy ~= oldvs then
			gl.DeleteTextureFBO(usedStencilTex)

			oldvs = vsx + vsy
			usedStencilTex = gl.CreateTexture(vsx, vsy, {
				border = false,
				min_filter = GL.NEAREST,
				mag_filter = GL.NEAREST,
				wrap_s = GL.CLAMP,
				wrap_t = GL.CLAMP,
				fbo = true,
			})

			if (usedStencilTex == nil) then
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
				gl.CallList(dlist)
			end
		elseif fullscreen then
			gl.Rect(0, 0, vsx, vsy)
		else
			for _, rect in pairs(guishaderScreenRects) do
				gl.Rect(rect[1], rect[2], rect[3], rect[4])
			end
			for _, dlist in pairs(guishaderScreenDlists) do
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
end

local function CheckHardware()
	if not canShader then
		Spring.Echo("guishader api: your hardware does not support shaders, OR: change springsettings: \"enable lua shaders\" ")
		widgetHandler:RemoveWidget()
		return false
	end

	if not NON_POWER_OF_TWO then
		Spring.Echo("guishader api: your hardware does not non-2^n-textures")
		widgetHandler:RemoveWidget()
		return false
	end

	return true
end

local function CreateShaders()
	if blurShader then
		gl.DeleteShader(blurShader or 0)
	end

	-- create blur shaders
	blurShader = gl.CreateShader({
		fragment = [[
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
	]],

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
	})


	if blurShader == nil then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader blurShader: shader error: " .. gl.GetShaderLog())
		widgetHandler:RemoveWidget()
		return false
	end

	intensityLoc = gl.GetUniformLocation(blurShader, "intensity")
	ivsxLoc = gl.GetUniformLocation(blurShader, "ivsx")
	ivsyLoc = gl.GetUniformLocation(blurShader, "ivsy")

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
	if gl.DeleteTextureFBO then
		gl.DeleteTextureFBO(stenciltex)
		gl.DeleteTextureFBO(stenciltexScreen)
	end
	gl.DeleteTexture(screencopyUI or 0)
	if gl.DeleteShader then
		gl.DeleteShader(blurShader or 0)
	end
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
			Spring.Echo("Missing Screencopy Manager, exiting",  WG['screencopymanager'] )
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

		gl.Blending(true)
		gl.Texture(screencopy)
		gl.Texture(2, stenciltex)
		gl.UseShader(blurShader)

		gl.Uniform(intensityLoc, math.max(blurIntensity, 0.0015))
		gl.Uniform(ivsxLoc, 0.5/vsx)
		gl.Uniform(ivsyLoc, 0.5/vsy)

		gl.TexRect(0, vsy, vsx, 0) -- draw the blurred version
		gl.UseShader(0)
		gl.Texture(2, false)
		gl.Texture(false)
		gl.Blending(false)
	end
end

local function DrawScreen() -- This blurs the UI elements obscured by other UI elements (only unit stats so far!)
	if Spring.IsGUIHidden() or uiOpacity > 0.99 then
		return
	end
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
		gl.UseShader(blurShader)

		gl.Uniform(intensityLoc, math.max(blurIntensity, 0.0015))
		gl.Uniform(ivsxLoc, 0.5/vsx)
		gl.Uniform(ivsyLoc, 0.5/vsy)

		gl.TexRect(0, vsy, vsx, 0) -- draw the blurred version
		gl.UseShader(0)
		gl.Texture(2, false)
		gl.Texture(false)
	end

	for k, v in pairs(renderDlists) do
		gl.CallList(k)
	end

	for k, v in pairs(deleteDlistQueue) do
		gl.DeleteList(deleteDlistQueue[v])
		if guishaderDlists[k] then
			guishaderDlists[k] = nil
		elseif guishaderScreenDlists[k] then
			guishaderScreenDlists[k] = nil
		end
		updateStencilTexture = true
	end
	deleteDlistQueue = {}
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
			deleteDlistQueue[name] = guishaderDlists[name]
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
		local found = false
		if guishaderScreenDlists[name] ~= nil then
			found = true
			deleteDlistQueue[name] = guishaderScreenDlists[name]
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
			Spring.Echo("Attempted to set blurIntensity to a non-number:",value," resetting to default")
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
			Spring.Echo("Attempted to set blurIntensity to a non-number:",data.blurIntensity," resetting to default")
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
