local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "API Screencopy Manager",
		desc = "Provides a per-frame shared screencopy to any widget/gadget requesting it",
		author = "Beherith",
		date = "2022.02.18",
		license = "GNU GPL, v2 or later",
		layer = -828888, -- This means it runs late in the render order
		handler = true,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spEcho = Spring.Echo
local spGetViewGeometry = Spring.GetViewGeometry
local spGetDrawFrame = Spring.GetDrawFrame

local glCopyToTexture = gl.CopyToTexture
local glCreateTexture = gl.CreateTexture
local glDeleteTexture = gl.DeleteTexture

-- So in total about 168/162 fps delta just going from 1 to 2 screencopies!

-- 3 things want screencopies, at least:
-- GUIshader - Done -- dont care if its not sharpened, in fact!
-- CAS - Done
-- TODO:
-- distortionFBO - hard because large areas might have a noticeable lack of sharpening...

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
]]
-- If you draw over the screen after reading the copy, call InvalidateScreenCopy() so that later callers
-- this frame get a new copy with your drawing in it (CAS rewrites every pixel from the copy).
--

-- Also provide a depth copy too!
-- For correct render order, the depth copy should be requested before things like healthbars.
-- Why do we even return nil for our first copy?

local GL_DEPTH_COMPONENT32 = 0x81A7

-- created on first request, so a copy nobody asks for (usually the depth one) takes no VRAM; false if that failed
local ScreenCopy
local lastScreenCopyFrame

local DepthCopy
local lastDepthCopyFrame

local vsx, vsy, vpx, vpy = spGetViewGeometry()
local firstCopy = true

local function CreateCopyTexture(format, filter, name)
	local texture = glCreateTexture(vsx, vsy, {
		border = false,
		format = format,
		min_filter = filter,
		mag_filter = filter,
		wrap_s = GL.CLAMP,
		wrap_t = GL.CLAMP,
	})
	if not texture then
		spEcho("ScreenCopy Manager failed to create a " .. name)
	end
	return texture or false
end

local function DeleteCopies()
	if ScreenCopy then
		glDeleteTexture(ScreenCopy)
	end
	if DepthCopy then
		glDeleteTexture(DepthCopy)
	end
	ScreenCopy, lastScreenCopyFrame = nil, nil
	DepthCopy, lastDepthCopyFrame = nil, nil
end

function widget:ViewResize()
	vsx, vsy, vpx, vpy = spGetViewGeometry()
	DeleteCopies()
end

local function GetScreenCopy()
	local df = spGetDrawFrame()
	--spEcho("GetScreenCopy", df)
	if df ~= lastScreenCopyFrame then
		if ScreenCopy == nil then
			ScreenCopy = CreateCopyTexture(nil, GL.LINEAR, "ScreenCopy")
		end
		if not ScreenCopy then
			return nil
		end
		glCopyToTexture(ScreenCopy, 0, 0, vpx, vpy, vsx, vsy)
		lastScreenCopyFrame = df
	end
	if firstCopy then
		firstCopy = false
		return nil
	end
	return ScreenCopy
end

local function InvalidateScreenCopy()
	lastScreenCopyFrame = nil
end

local function GetDepthCopy()
	local df = spGetDrawFrame()
	--spEcho("GetScreenCopy", df)
	if df ~= lastDepthCopyFrame then
		if DepthCopy == nil then
			DepthCopy = CreateCopyTexture(GL_DEPTH_COMPONENT32, GL.NEAREST, "DepthCopy")
		end
		if not DepthCopy then
			return nil
		end
		glCopyToTexture(DepthCopy, 0, 0, vpx, vpy, vsx, vsy)
		lastDepthCopyFrame = df
	end
	if firstCopy then
		firstCopy = false
		return nil
	end
	return DepthCopy
end

function widget:Initialize()
	if glCopyToTexture == nil then
		spEcho("ScreenCopy Manager API: your hardware is missing the necessary CopyToTexture feature")
		widgetHandler:RemoveWidget()
		return false
	end
	WG.screencopymanager = {}
	WG.screencopymanager.GetScreenCopy = GetScreenCopy
	WG.screencopymanager.InvalidateScreenCopy = InvalidateScreenCopy
	WG.screencopymanager.GetDepthCopy = GetDepthCopy
	widgetHandler:RegisterGlobal("GetScreenCopy", WG.screencopymanager.GetScreenCopy)
	widgetHandler:RegisterGlobal("GetDepthCopy", WG.screencopymanager.GetDepthCopy)
end

function widget:Shutdown()
	DeleteCopies()
	WG.screencopymanager = nil
	widgetHandler:DeregisterGlobal("GetScreenCopy")
	widgetHandler:DeregisterGlobal("GetDepthCopy")
end
