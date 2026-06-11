--------------------------------------------------------------------------------------------
--- set some spring settings before the game/engine is really loaded yet
--------------------------------------------------------------------------------------------

Engine.Unsynced.SetConfigString("SplashScreenDir", "./MenuLoadscreens")

-- ghost icons dimming, override engine default but allow user setting
if Engine.Unsynced.GetConfigFloat("UnitGhostIconsDimming", 0.5) == 0.5 then
	Engine.Unsynced.SetConfigFloat("UnitGhostIconsDimming", 0.75)
end

-- set default unit rendering vars
Engine.Unsynced.SetConfigFloat("tonemapA", 4.75)
Engine.Unsynced.SetConfigFloat("tonemapB", 0.75)
Engine.Unsynced.SetConfigFloat("tonemapC", 3.5)
Engine.Unsynced.SetConfigFloat("tonemapD", 0.85)
Engine.Unsynced.SetConfigFloat("tonemapE", 1.0)
Engine.Unsynced.SetConfigFloat("envAmbient", 0.25)
Engine.Unsynced.SetConfigFloat("unitSunMult", 1.0)
Engine.Unsynced.SetConfigFloat("unitExposureMult", 1.0)
Engine.Unsynced.SetConfigFloat("modelGamma", 1.0)

-- BAR requires higher textureatlas size for particles than the default of 2048x2048
local maxTextureAtlasSize = 8192
Engine.Unsynced.SetConfigInt("MaxTextureAtlasSizeX", maxTextureAtlasSize)
Engine.Unsynced.SetConfigInt("MaxTextureAtlasSizeY", maxTextureAtlasSize)
if tonumber(Engine.Unsynced.GetConfigInt("MaxTextureAtlasSizeX", 2048) or 2048) < maxTextureAtlasSize then
	Engine.Unsynced.SetConfigInt("MaxTextureAtlasSizeX", maxTextureAtlasSize)
	Engine.Unsynced.SetConfigInt("MaxTextureAtlasSizeY", maxTextureAtlasSize)
end

-- Sets necessary spring configuration parameters, so shaded units look the way they should (pbr gadget also does this)
Engine.Unsynced.SetConfigInt("CubeTexGenerateMipMaps", 1)
Engine.Unsynced.SetConfigInt("CubeTexSizeReflection", 1024)

Engine.Unsynced.SetConfigInt("AdvSky", 0)

-- disable grass
Engine.Unsynced.SetConfigInt("GrassDetail", 0)

-- adv map shading
--Spring.SetConfigInt("AdvMapShading", 1)

-- make sure default/minimum ui opacity is set
if Engine.Unsynced.GetConfigFloat("ui_opacity", 0.6) < 0.3 then
	Engine.Unsynced.SetConfigFloat("ui_opacity", 0.6)
end
-- set default bg tile settings
if Engine.Unsynced.GetConfigFloat("ui_tileopacity", 0.011) < 0 then
	Engine.Unsynced.SetConfigFloat("ui_tileopacity", 0.011)
end
if Engine.Unsynced.GetConfigFloat("ui_tilescale", 7) < 0 then
	Engine.Unsynced.SetConfigFloat("ui_tilescale", 7)
end

-- disable ForceDisableShaders
if Engine.Unsynced.GetConfigInt("ForceDisableShaders", 0) == 1 then
	Engine.Unsynced.SetConfigInt("ForceDisableShaders", 0)
end

-- enable lua shaders
if not tonumber(Engine.Unsynced.GetConfigInt("LuaShaders", 0) or 0) then
	Engine.Unsynced.SetConfigInt("LuaShaders", 1)
end

-- Disable dynamic model lights
Engine.Unsynced.SetConfigInt("MaxDynamicModelLights", 0)

-- Enable deferred map/model rendering
Engine.Unsynced.SetConfigInt("AllowDeferredMapRendering", 1)
Engine.Unsynced.SetConfigInt("AllowDeferredModelRendering", 1)

-- Enables the DrawGroundDeferred event, which is needed for deferred map edge rendering
Engine.Unsynced.SetConfigInt("AllowDrawMapDeferredEvents", 1)

-- Disable LoadingMT because: crashes on load, but fixed in 105.1.1-1422, redisable in 105.1.1-1432
--Spring.SetConfigInt("LoadingMT", 0)

-- Chobby had this set to 100 before and it introduced latency of 4ms a sim-frame, having a 10%-15% penalty compared it the default
-- This was set to 2 as of 2022.08.16, Beherith reduced it to 1 for even less GC probability
Engine.Unsynced.SetConfigInt("LuaGarbageCollectionMemLoadMult", 1)

-- Reduce the max runtime of GC to 1 ms instead of 5 (2022.08.16)
Engine.Unsynced.SetConfigInt("LuaGarbageCollectionRunTimeMult", 1)

-- we used 3 as default toggle, changing to 4
if (Engine.Unsynced.GetConfigInt("GroundDecals", 3) or 3) >= 4 then
	Engine.Unsynced.SetConfigInt("GroundDecals", 3)
end

-- ground mesh detail
Engine.Unsynced.SetConfigInt("ROAM", 1)
if tonumber(Engine.Unsynced.GetConfigInt("GroundDetail", 1) or 1) < 200 then
	Engine.Unsynced.SetConfigInt("GroundDetail", 200)
end

-- This makes between-simframe interpolation smoother in mid-late game situations
Engine.Unsynced.SetConfigInt("SmoothTimeOffset", 2) -- New in BAR engine

-- This is needed for better profiling info, and (theoretically better frame timing).
-- Notably a decade ago windows had issues with this
Engine.Unsynced.SetConfigInt("UseHighResTimer", 1) -- Default off

-- This changes the sleep time of the game server thread to make it wake up every 1.999 ms instead of the default 5.999 ms
-- This hopefully gets us less variance in issuing new sim frames
Engine.Unsynced.SetConfigInt("ServerSleepTime", 1)

-- The default of 256 is just too tiny, at this size the VS load outpaces FS load anyway, makes for actually pretty reflections with CUS GL4
Engine.Unsynced.SetConfigInt("BumpWaterTexSizeReflection", 1024)

Engine.Unsynced.SetConfigFloat("CrossAlpha", 0) -- will be in effect next launch

if not Engine.Unsynced.GetConfigFloat("UnitIconFadeAmount") then
	Engine.Unsynced.SetConfigFloat("UnitIconFadeAmount", 0.1)
end

-- equalize
Engine.Unsynced.SetConfigInt("UnitIconFadeVanish", Engine.Unsynced.GetConfigInt("UnitIconFadeStart", 3000))

-- change some default value(s), upp the version and set what needs to be set
local version = 3
if Engine.Unsynced.GetConfigInt("version", 0) < version then
	Engine.Unsynced.SetConfigInt("version", version)

	-- set icon settings
	Engine.Unsynced.SetConfigInt("UnitIconsAsUI", 1)
	Engine.Unsynced.SetConfigFloat("UnitIconScaleUI", 1.05)
	Engine.Unsynced.SetConfigInt("UnitIconFadeVanish", 3000)
	Engine.Unsynced.SetConfigInt("UnitIconFadeStart", 3000)
	Engine.Unsynced.SetConfigInt("UnitIconsHideWithUI", 1)

	if Engine.Unsynced.GetConfigInt("UnitIconFadeVanish", 2700) < 2700 then
		Engine.Unsynced.SetConfigInt("UnitIconFadeVanish", 2700)
	end
	if Engine.Unsynced.GetConfigInt("UnitIconFadeStart", 3000) < 3000 then
		Engine.Unsynced.SetConfigInt("UnitIconFadeVanish", 3000)
	end

	Engine.Unsynced.SetConfigInt("VSyncGame", -1)
	Engine.Unsynced.SetConfigInt("CamMode", 3)
end
version = 4
if Engine.Unsynced.GetConfigInt("version", 0) < version then
	Engine.Unsynced.SetConfigInt("version", version)

	if Engine.Unsynced.GetConfigFloat("ui_scale", 1) == 1 then
		Engine.Unsynced.SetConfigFloat("ui_scale", 0.94)
	end
end
version = 5
if Engine.Unsynced.GetConfigInt("version", 0) < version then
	Engine.Unsynced.SetConfigInt("version", version)

	Engine.Unsynced.SetConfigInt("CamSpringMinZoomDistance", 300)
	Engine.Unsynced.SetConfigInt("OverheadMinZoomDistance", 300)
end
version = 8
if Engine.Unsynced.GetConfigInt("version", 0) < version then
	Engine.Unsynced.SetConfigInt("version", version)

	local voiceset = Engine.Unsynced.GetConfigString("voiceset", "")
	if voiceset == "en/allison" then
		Engine.Unsynced.SetConfigString("voiceset", "en/cephis")
	end
end

-- apply the old pre-engine implementation stored camera minimum zoom level
local oldMinCamHeight = Engine.Unsynced.GetConfigInt("MinimumCameraHeight", -1)
if oldMinCamHeight ~= -1 then
	Engine.Unsynced.SetConfigInt("MinimumCameraHeight", -1)
	Engine.Unsynced.SetConfigInt("CamSpringMinZoomDistance", oldMinCamHeight)
	Engine.Unsynced.SetConfigInt("OverheadMinZoomDistance", oldMinCamHeight)
end

-- in case we forget to save it once again
Engine.Unsynced.SetConfigInt("version", version)

Engine.Unsynced.SetConfigInt("VSync", Engine.Unsynced.GetConfigInt("VSyncGame", -1))

-- Configure sane keychain settings, this is to provide a standard experience
-- for users that is acceptable
local springKeyChainTimeout = 750 -- expected engine default in ms
local barKeyChainTimeout = 333 -- the setting we want to apply in ms
local userKeyChainTimeout = Engine.Unsynced.GetConfigInt("KeyChainTimeout")

-- Apply BAR's default if current setting is equal to engine default OR BAR's default
-- Reason is engine is unable to distinguish between:
--   - user configuring the setting to be equal to default
--   - the actual setting being empty and engine using default
if userKeyChainTimeout == springKeyChainTimeout or userKeyChainTimeout == barKeyChainTimeout then
	-- Setting a standardized keychain timeout, 750ms is too long
	-- A side benefit of making it smaller is reduced complexity of actions handling
	-- since there are fewer complex and long chains between keystrokes
	Engine.Unsynced.SetConfigInt("KeyChainTimeout", barKeyChainTimeout)
else
	-- If user has configured a custom KeyChainTimeout, restore this setting
	Engine.Unsynced.SetConfigInt("KeyChainTimeout", userKeyChainTimeout)
end

-- The default mouse drag threshold is set extremely low for engine by default, and fast clicking often results in a drag.
-- This is bad for single unit commands, which turn into empty area commmands as a result of the small drag
local xresolution = math.max(Engine.Unsynced.GetConfigInt("XResolution", 1920), Engine.Unsynced.GetConfigInt("XResolutionWindowed", 1920))
local yresolution = math.max(Engine.Unsynced.GetConfigInt("YResolution", 1080), Engine.Unsynced.GetConfigInt("YResolutionWindowed", 1080))

local baseDragThreshold = 16
baseDragThreshold = math.round(baseDragThreshold * (xresolution + yresolution) * (1 / 3000)) -- is 16 at 1080p
baseDragThreshold = math.clamp(baseDragThreshold, 8, 40)
Engine.Shared.Echo(string.format("Setting Mouse Drag thresholds based on resolution (%dx%d) for Selection to %d, and Command to %d", xresolution, yresolution, baseDragThreshold, baseDragThreshold + 16))
Engine.Unsynced.SetConfigInt("MouseDragSelectionThreshold", baseDragThreshold)
Engine.Unsynced.SetConfigInt("MouseDragCircleCommandThreshold", baseDragThreshold + 16)
Engine.Unsynced.SetConfigInt("MouseDragBoxCommandThreshold", baseDragThreshold + 16)
Engine.Unsynced.SetConfigInt("MouseDragFrontCommandThreshold", baseDragThreshold + 16)

Engine.Unsynced.SetConfigInt("MaxFontTries", 5)
Engine.Unsynced.SetConfigInt("UseFontConfigLib", 1)

--local language = Spring.GetConfigString("language", 'en')
--if language ~= 'en' and language ~= 'fr' then
--	Spring.SetConfigString("language", 'en')
--end
