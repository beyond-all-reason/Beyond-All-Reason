function widget:GetInfo()
   return {
      name      = "API Screencopy Manager",
      desc      = "Provides a per-frame shared screencopy to any widget/gadget requesting it",
      author    = "Beherith",
      date      = "2022.02.18",
      license   = "GNU GPL, v2 or later",
      layer     = -8288888,
	  handler   = true,
      enabled   = true
   }
end

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
			Spring.Echo("no manager",  WG['screencopymanager'] )
			return 
		end
		if screencopy == nil then return end
]]--

local ScreenCopy 
local lastScreenCopyFrame
local vsx, vsy = widgetHandler:GetViewSizes()
local firstCopy = true

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx, vsy = viewSizeX, viewSizeY
	if ScreenCopy then gl.DeleteTexture(ScreenCopy) end 
	ScreenCopy = gl.CreateTexture(vsx  , vsy, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP,
		wrap_t = GL.CLAMP,
	})
end

local function GetScreenCopy()
	local df = Spring.GetDrawFrame()
	--Spring.Echo("GetScreenCopy", df)
	if df ~= lastScreenCopyFrame then 
		gl.CopyToTexture(ScreenCopy, 0, 0, 0, 0, vsx, vsy) 
		lastScreenCopyFrame = df
	end	
	if firstCopy then 
		firstCopy = false
		return nil
	end
	return ScreenCopy
end

function widget:Initialize()
	if gl.CopyToTexture == nil then 
		Spring.Echo("Screencopy Manager api: your hardware is missing the necessary CopyToTexture feature")
		widgetHandler:RemoveWidget()
		return false
	end
	self:ViewResize(vsx, vsy)
	WG['screencopymanager'] = {}
	WG['screencopymanager'].GetScreenCopy = GetScreenCopy
	widgetHandler:RegisterGlobal('GetScreenCopy', WG['screencopymanager'].GetScreenCopy)
end

function widget:Shutdown()
	gl.DeleteTexture(ScreenCopy or 0)
	WG['screencopymanager'] = nil
	widgetHandler:DeregisterGlobal('GetScreenCopy')
end
