--------------------------------------------------------------------------------------------
--- set some spring settings before the game/engine is really loaded yet
--------------------------------------------------------------------------------------------

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

-- Sets necessary spring configuration parameters, so shaded units look the way they should
Spring.SetConfigInt("CubeTexGenerateMipMaps", 1)
Spring.SetConfigInt("CubeTexSizeReflection", 2048)

-- disable grass
Spring.SetConfigInt("GrassDetail", 0)

-- adv unit shading
if not tonumber(Spring.GetConfigInt("AdvUnitShading",0) or 0) then
	Spring.SetConfigInt("AdvUnitShading", 1)
end

-- adv map shading
--if not tonumber(Spring.GetConfigInt("AdvMapShading",0) or 0) then
--	Spring.SetConfigInt("AdvMapShading", 1)
--end

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

-- Disable PBO for intel GFX
if Platform.gpuVendor ~= 'Nvidia' and Platform.gpuVendor ~= 'AMD' then
	Spring.SetConfigInt("UsePBO", 0)
else
	Spring.SetConfigInt("UsePBO", 1)
end

-- Disable dynamic model lights
Spring.SetConfigInt("MaxDynamicModelLights", 0)

-- Disable LoadingMT because: crashes on load
Spring.SetConfigInt("LoadingMT", 0)

-- Chobby had this set to 100 before and it introduced latency of 4ms a sim-frame, having a 10%-15% penalty compared it the default
Spring.SetConfigInt("LuaGarbageCollectionMemLoadMult", 2)

-- we used 3 as default toggle, changing to 4
if (Spring.GetConfigInt("GroundDecals", 4) or 3) <= 3 then
	Spring.SetConfigInt("GroundDecals", 4)
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

Spring.SetConfigInt("UnitLodDist", 999999)



if not Spring.GetConfigFloat("UnitIconFadeAmount") then
	Spring.SetConfigFloat("UnitIconFadeAmount", 0.1)
end

-- equalize
Spring.SetConfigInt("UnitIconFadeVanish", Spring.GetConfigInt("UnitIconFadeStart", 3000))

-- change some default value(s), upp the version and set what needs to be set
local version = 2
if Spring.GetConfigInt("version", 0) < version then
	Spring.SetConfigInt("version", version)

	-- set icon settings
	Spring.SetConfigInt("UnitIconsAsUI", 1)
	Spring.SetConfigFloat("UnitIconScaleUI", 1.05)
	Spring.SetConfigInt("UnitIconFadeVanish", 3000)
	Spring.SetConfigInt("UnitIconFadeStart", 3000)
	Spring.SetConfigInt("UnitIconsHideWithUI", 1)
end

version = 3
if Spring.GetConfigInt("version", 0) < version then
	Spring.SetConfigInt("version", version)

	if Spring.GetConfigInt("UnitIconFadeVanish", 2700) < 2700 then
		Spring.SetConfigInt("UnitIconFadeVanish", 2700)
	end
	if Spring.GetConfigInt("UnitIconFadeStart", 3000) < 3000 then
		Spring.SetConfigInt("UnitIconFadeVanish", 3000)
	end
end
