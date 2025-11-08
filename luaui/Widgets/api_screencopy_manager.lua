local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name      = "API Screencopy Manager",
      desc      = "Provides a per-frame shared screencopy to any widget/gadget requesting it",
      author    = "Beherith",
      date      = "2022.02.18",
      license   = "GNU GPL, v2 or later",
      layer     = -828888, -- This means it runs late in the render order
	  handler   = true,
      enabled   = true
   }
end


-- Localized Spring API for performance
local spEcho = Spring.Echo
local spGetViewGeometry = Spring.GetViewGeometry

-- So in total about 168/162 fps delta just going from 1 to 2 screencopies!

-- 3 things want screencopies, at least:
-- GUIshader - Done -- dont care if its not sharpened, in fact!
-- CAS - Done
-- TODO:
	-- LUPS distortionFBO - hard because large areas might have a noticable lack of sharpening...

-- Code snippet to use if you want to request a copy:
-- also note that the first copy will return nil, as its all black!
-- so be prepared to nil check the return value of GetScreenCopy!
--[[
		if WG['screencopymanager'] and WG['screencopymanager'].GetScreenCopy then
			screencopy = WG['screencopymanager'].GetScreenCopy()
		else
			-- gl.CopyToTexture(screencopy, 0, 0, 0, 0, vsx, vsy) -- copy screen to screencopy, and render screencopy into blurtex
			spEcho("no manager",  WG['screencopymanager'] )
			return
		end
		if screencopy == nil then return end
]]--

-- Also provide a depth copy too!
-- For correct render order, the depth copy should be requested before things like healthbars. 
-- Why do we even return nil for our first copy?

local ScreenCopy
local lastScreenCopyFrame


local DepthCopy
local lastDepthCopyFrame

local vsx, vsy, vpx, vpy = spGetViewGeometry()
local firstCopy = true

function widget:ViewResize()
	vsx, vsy, vpx, vpy = spGetViewGeometry()
	if ScreenCopy then gl.DeleteTexture(ScreenCopy) end
	ScreenCopy = gl.CreateTexture(vsx  , vsy, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP,
		wrap_t = GL.CLAMP,
	})

	local GL_DEPTH_COMPONENT32 = 0x81A7
	if DepthCopy then gl.DeleteTexture(DepthCopy) end
	DepthCopy = gl.CreateTexture(vsx  , vsy, {
		border = false,
		format = GL_DEPTH_COMPONENT32,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP,
		wrap_t = GL.CLAMP,
	})
	if not ScreenCopy then spEcho("ScreenCopy Manager failed to create a ScreenCopy") end 
	if not DepthCopy then spEcho("ScreenCopy Manager failed to create a DepthCopy") end 
end

local function GetScreenCopy()
	local df = Spring.GetDrawFrame()
	--spEcho("GetScreenCopy", df)
	if df ~= lastScreenCopyFrame then
		gl.CopyToTexture(ScreenCopy, 0, 0, vpx, vpy, vsx, vsy)
		lastScreenCopyFrame = df
	end
	if firstCopy then
		firstCopy = false
		return nil
	end
	return ScreenCopy
end


local function GetDepthCopy()
	local df = Spring.GetDrawFrame()
	--spEcho("GetScreenCopy", df)
	if df ~= lastDepthCopyFrame then
		gl.CopyToTexture(DepthCopy, 0, 0, vpx, vpy, vsx, vsy)
		lastDepthCopyFrame = df
	end
	if firstCopy then
		firstCopy = false
		return nil
	end
	return DepthCopy
end


function widget:Initialize()
	if gl.CopyToTexture == nil then
		spEcho("ScreenCopy Manager API: your hardware is missing the necessary CopyToTexture feature")
		widgetHandler:RemoveWidget()
		return false
	end
	self:ViewResize(vsx, vsy)
	WG['screencopymanager'] = {}
	WG['screencopymanager'].GetScreenCopy = GetScreenCopy
	WG['screencopymanager'].GetDepthCopy = GetDepthCopy
	widgetHandler:RegisterGlobal('GetScreenCopy', WG['screencopymanager'].GetScreenCopy)
	widgetHandler:RegisterGlobal('GetDepthCopy', WG['screencopymanager'].GetDepthCopy)
end

function widget:Shutdown()
	gl.DeleteTexture(ScreenCopy or 0)
	gl.DeleteTexture(DepthCopy or 0)
	WG['screencopymanager'] = nil
	widgetHandler:DeregisterGlobal('GetScreenCopy')
	widgetHandler:DeregisterGlobal('GetDepthCopy')
end
