--------------------------------------------------------------------------------------------
--- set some spring settings before the game/engine is really loaded yet
--------------------------------------------------------------------------------------------

Spring.SetConfigString("SplashScreenDir", "./MenuLoadscreens")

-- set default unit rendering vars
Spring.SetConfigFloat("tonemapA", 4.75)
Spring.SetConfigFloat("tonemapB", 0.75)
Spring.SetConfigFloat("tonemapC", 3.5)
Spring.SetConfigFloat("tonemapD", 0.85)
Spring.SetConfigFloat("tonemapE", 1.0)
Spring.SetConfigFloat("envAmbient", 0.25)
Spring.SetConfigFloat("unitSunMult", 1.0)
Spring.SetConfigFloat("unitExposureMult", 1.0)
Spring.SetConfigFloat("modelGamma", 1.0)


-- BAR requires higher textureatlas size for particles than the default of 2048x2048
local maxTextureAtlasSize = 8192
Spring.SetConfigInt("MaxTextureAtlasSizeX", maxTextureAtlasSize)
Spring.SetConfigInt("MaxTextureAtlasSizeY", maxTextureAtlasSize)
if tonumber(Spring.GetConfigInt("MaxTextureAtlasSizeX",2048) or 2048) < maxTextureAtlasSize then
	Spring.SetConfigInt("MaxTextureAtlasSizeX", maxTextureAtlasSize)
	Spring.SetConfigInt("MaxTextureAtlasSizeY", maxTextureAtlasSize)
end

-- Sets necessary spring configuration parameters, so shaded units look the way they should (pbr gadget also does this)
Spring.SetConfigInt("CubeTexGenerateMipMaps", 1)
Spring.SetConfigInt("CubeTexSizeReflection", 1024)

-- disable grass
Spring.SetConfigInt("GrassDetail", 0)

-- adv unit shading
if not tonumber(Spring.GetConfigInt("AdvUnitShading",0) or 0) then
	Spring.SetConfigInt("AdvUnitShading", 1)
end

-- adv map shading
if not tonumber(Spring.GetConfigInt("AdvMapShading",0) or 0) then
	Spring.SetConfigInt("AdvMapShading", 1)
end

-- make sure default/minimum ui opacity is set
if Spring.GetConfigFloat("ui_opacity", 0.6) < 0.3 then
	Spring.SetConfigFloat("ui_opacity", 0.6)
end
-- set default bg tile settings
if Spring.GetConfigFloat("ui_tileopacity", 0.011) < 0 then
	Spring.SetConfigFloat("ui_tileopacity", 0.011)
end
if Spring.GetConfigFloat("ui_tilescale", 7) < 0 then
	Spring.SetConfigFloat("ui_tilescale", 7)
end

-- disable ForceDisableShaders
if Spring.GetConfigInt("ForceDisableShaders",0) == 1 then
	Spring.SetConfigInt("ForceDisableShaders", 0)
end

-- enable lua shaders
if not tonumber(Spring.GetConfigInt("LuaShaders",0) or 0) then
	Spring.SetConfigInt("LuaShaders", 1)
end

-- Disable dynamic model lights
Spring.SetConfigInt("MaxDynamicModelLights", 0)

-- Enable deferred map/model rendering
Spring.SetConfigInt("AllowDeferredMapRendering", 1)
Spring.SetConfigInt("AllowDeferredModelRendering", 1)

-- Enables the DrawGroundDeferred event, which is needed for deferred map edge rendering
Spring.SetConfigInt("AllowDrawMapDeferredEvents", 1)

-- Disable LoadingMT because: crashes on load, but fixed in 105.1.1-1422, redisable in 105.1.1-1432
--Spring.SetConfigInt("LoadingMT", 0)

-- Chobby had this set to 100 before and it introduced latency of 4ms a sim-frame, having a 10%-15% penalty compared it the default
-- This was set to 2 as of 2022.08.16, Beherith reduced it to 1 for even less GC probability
Spring.SetConfigInt("LuaGarbageCollectionMemLoadMult", 1)

-- Reduce the max runtime of GC to 1 ms instead of 5 (2022.08.16)
Spring.SetConfigInt("LuaGarbageCollectionRunTimeMult", 1)


-- we used 3 as default toggle, changing to 4
if (Spring.GetConfigInt("GroundDecals", 3) or 3) >= 4 then
	Spring.SetConfigInt("GroundDecals", 3)
end

-- ground mesh detail
Spring.SetConfigInt("ROAM", 1)
if tonumber(Spring.GetConfigInt("GroundDetail", 1) or 1) < 200 then
	Spring.SetConfigInt("GroundDetail", 200)
end

-- This makes between-simframe interpolation smoother in mid-late game situations
Spring.SetConfigInt("SmoothTimeOffset", 2) -- New in BAR engine

-- This is needed for better profiling info, and (theoretically better frame timing).
-- Notably a decade ago windows had issues with this
Spring.SetConfigInt("UseHighResTimer", 1)  -- Default off

-- This changes the sleep time of the game server thread to make it wake up every 1.999 ms instead of the default 5.999 ms
-- This hopefully gets us less variance in issuing new sim frames
Spring.SetConfigInt("ServerSleepTime", 1)

-- The default of 256 is just too tiny, at this size the VS load outpaces FS load anyway, makes for actually pretty reflections with CUS GL4
Spring.SetConfigInt("BumpWaterTexSizeReflection", 1024)

Spring.SetConfigFloat("CrossAlpha", 0)	-- will be in effect next launch

if Spring.GetConfigInt("AdvModelShading", 0) ~= 1 then
	Spring.SetConfigInt("AdvModelShading", 1)
end

if not Spring.GetConfigFloat("UnitIconFadeAmount") then
	Spring.SetConfigFloat("UnitIconFadeAmount", 0.1)
end

-- equalize
Spring.SetConfigInt("UnitIconFadeVanish", Spring.GetConfigInt("UnitIconFadeStart", 3000))

-- change some default value(s), upp the version and set what needs to be set
local version = 3
if Spring.GetConfigInt("version", 0) < version then
	Spring.SetConfigInt("version", version)

	-- set icon settings
	Spring.SetConfigInt("UnitIconsAsUI", 1)
	Spring.SetConfigFloat("UnitIconScaleUI", 1.05)
	Spring.SetConfigInt("UnitIconFadeVanish", 3000)
	Spring.SetConfigInt("UnitIconFadeStart", 3000)
	Spring.SetConfigInt("UnitIconsHideWithUI", 1)

	if Spring.GetConfigInt("UnitIconFadeVanish", 2700) < 2700 then
		Spring.SetConfigInt("UnitIconFadeVanish", 2700)
	end
	if Spring.GetConfigInt("UnitIconFadeStart", 3000) < 3000 then
		Spring.SetConfigInt("UnitIconFadeVanish", 3000)
	end

	Spring.SetConfigInt("VSyncGame", -1)
	Spring.SetConfigInt("CamMode", 3)
end
version = 4
if Spring.GetConfigInt("version", 0) < version then
	Spring.SetConfigInt("version", version)

	if Spring.GetConfigFloat("ui_scale", 1) == 1 then
		Spring.SetConfigFloat("ui_scale", 0.94)
	end
end
version = 5
if Spring.GetConfigInt("version", 0) < version then
	Spring.SetConfigInt("version", version)

	Spring.SetConfigInt("CamSpringMinZoomDistance", 300)
	Spring.SetConfigInt("OverheadMinZoomDistance", 300)
end
version = 6
if Spring.GetConfigInt("version", 0) < version then
	Spring.SetConfigInt("version", version)

	-- disabling for now
	Spring.SetConfigInt("ui_rendertotexture", 0)
end

-- apply the old pre-engine implementation stored camera minimum zoom level
local oldMinCamHeight = Spring.GetConfigInt("MinimumCameraHeight", -1)
if oldMinCamHeight ~= -1 then
	Spring.SetConfigInt("MinimumCameraHeight", -1)
	Spring.SetConfigInt("CamSpringMinZoomDistance", oldMinCamHeight)
	Spring.SetConfigInt("OverheadMinZoomDistance", oldMinCamHeight)
end


Spring.SetConfigInt("VSync", Spring.GetConfigInt("VSyncGame", -1))

-- Configure sane keychain settings, this is to provide a standard experience
-- for users that is acceptable
local springKeyChainTimeout = 750 -- expected engine default in ms
local barKeyChainTimeout = 333 -- the setting we want to apply in ms
local userKeyChainTimeout = Spring.GetConfigInt("KeyChainTimeout")

-- Apply BAR's default if current setting is equal to engine default OR BAR's default
-- Reason is engine is unable to distinguish between:
--   - user configuring the setting to be equal to default
--   - the actual setting being empty and engine using default
if userKeyChainTimeout == springKeyChainTimeout or userKeyChainTimeout == barKeyChainTimeout then
	-- Setting a standardized keychain timeout, 750ms is too long
	-- A side benefit of making it smaller is reduced complexity of actions handling
	-- since there are fewer complex and long chains between keystrokes
	Spring.SetConfigInt("KeyChainTimeout", barKeyChainTimeout)
else
	-- If user has configured a custom KeyChainTimeout, restore this setting
	Spring.SetConfigInt("KeyChainTimeout", userKeyChainTimeout)
end


-- The default mouse drag threshold is set extremely low for engine by default, and fast clicking often results in a drag.
-- This is bad for single unit commands, which turn into empty area commmands as a result of the small drag
local xresolution = math.max(Spring.GetConfigInt("XResolution", 1920), Spring.GetConfigInt("XResolutionWindowed", 1920))
local yresolution = math.max(Spring.GetConfigInt("YResolution", 1080), Spring.GetConfigInt("YResolutionWindowed", 1080))

local baseDragThreshold = 16
baseDragThreshold = math.round(baseDragThreshold * (xresolution + yresolution) * ( 1/3000) ) -- is 16 at 1080p
baseDragThreshold = math.clamp(baseDragThreshold, 8, 40)
Spring.Echo(string.format("Setting Mouse Drag thresholds based on resolution (%dx%d) for Selection to %d, and Command to %d", xresolution,yresolution,baseDragThreshold, baseDragThreshold + 16))
Spring.SetConfigInt("MouseDragSelectionThreshold", baseDragThreshold)
Spring.SetConfigInt("MouseDragCircleCommandThreshold", baseDragThreshold + 16)
Spring.SetConfigInt("MouseDragBoxCommandThreshold", baseDragThreshold + 16)
Spring.SetConfigInt("MouseDragFrontCommandThreshold", baseDragThreshold + 16)

-- These config ints control some multithreading functionality, and are now set to their enabled state for performance
Spring.SetConfigInt("AnimationMT", 1)
Spring.SetConfigInt("UpdateBoundingVolumeMT", 1)
Spring.SetConfigInt("UpdateWeaponVectorsMT", 1)

Spring.SetConfigInt("MaxFontTries", 4)
Spring.SetConfigInt("UseFontConfigLib", 1)

local language = Spring.GetConfigString("language", 'en')
if language ~= 'en' and language ~= 'fr' then
	Spring.SetConfigString("language", 'en')
end
