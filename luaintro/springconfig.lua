--------------------------------------------------------------------------------------------
--- Load spring settings before the game/enging is really loaded yet
--------------------------------------------------------------------------------------------

-- BAR requires higher textureatlas size for particles than the default of 2048x2048
local maxTextureAtlasSize = 4096
Spring.SetConfigInt("MaxTextureAtlasSizeX", maxTextureAtlasSize)
Spring.SetConfigInt("MaxTextureAtlasSizeZ", maxTextureAtlasSize)
if tonumber(Spring.GetConfigInt("MaxTextureAtlasSizeX",2048) or 2048) < maxTextureAtlasSize then
	Spring.SetConfigInt("MaxTextureAtlasSizeX", maxTextureAtlasSize)
	Spring.SetConfigInt("MaxTextureAtlasSizeZ", maxTextureAtlasSize)
end

-- Sets necessary spring configuration parameters, so shaded units look the way they should
Spring.SetConfigInt("CubeTexGenerateMipMaps", 1)
Spring.SetConfigInt("CubeTexSizeReflection", 2048)

-- Enable lua shaders
if not tonumber(Spring.GetConfigInt("LuaShaders",0) or 0) then
	Spring.SetConfigInt("LuaShaders", 1)
end

-- Disable PBO for intel GFX
if Platform.gpuVendor ~= 'Nvidia' and Platform.gpuVendor ~= 'AMD' then
	Spring.SetConfigInt("UsePBO",0)
end

-- Disable dynamic model lights
Spring.SetConfigInt("MaxDynamicModelLights", 0)


