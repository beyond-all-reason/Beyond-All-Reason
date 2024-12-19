local mapName = Game.mapName
Spring.Echo("Lava Mapname", mapName)

local MAP_CONFIG_PATH = "mapconfig/lava.lua"
local GAME_CONFIG_DIR = "common/configs/LavaMaps/"

local voidWaterMap = false

local success, mapinfo = pcall(VFS.Include, "mapinfo.lua") -- load mapinfo.lua confs
if success or mapinfo ~= nil then
	voidWaterMap = mapinfo.voidwater
end

local isLavaMap = false

----------------------------------------
-- Defaults:

local diffuseEmitTex = "LuaUI/images/lava/lava2_diffuseemit.dds"
local normalHeightTex = "LuaUI/images/lava/lava2_normalheight.dds"

local level = 1 -- pre-game lava level
local grow = 0.25 -- initial lava grow speed
local damage = 100 -- damage per second or health proportion (0-1)
local damageFeatures = false -- Lava also damages features when set, if set to float, it's proportional damage per second (0 to 1), if set to true sets default of 0.1
local uvScale = 2.0 -- How many times to tile the lava texture across the entire map
local colorCorrection = "vec3(1.0, 1.0, 1.0)" -- final colorcorrection on all lava + shore coloring
local losDarkness = 0.5 -- how much to darken the out-of-los areas of the lava plane
local swirlFreq = 0.025 -- How fast the main lava texture swirls around default 0.025
local swirlAmp = 0.003 -- How much the main lava texture is swirled around default 0.003
local specularExp = 64.0 -- the specular exponent of the lava plane
local shadowStrength = 0.4 -- how much light a shadowed fragment can recieve
local coastWidth = 25.0 -- how wide the coast of the lava should be
local coastColor = "vec3(2.0, 0.5, 0.0)" -- the color of the lava coast
local coastLightBoost = 0.6 -- how much extra brightness should coastal areas get

local parallaxDepth = 16.0 -- set to >0 to enable, how deep the parallax effect is
local parallaxOffset = 0.5 -- center of the parallax plane, from 0.0 (up) to 1.0 (down)

local fogColor = "vec3(2.0, 0.5, 0.0)" -- the color of the fog light
local fogFactor = 0.06 -- how dense the fog is
local fogHeight = 20 -- how high the fog is above the lava plane
local fogAbove = 1.0 -- the multiplier for how much fog should be above lava fragments, ~0.2 means the lava itself gets hardly any fog, while 2.0 would mean the lava gets a lot of extra fog
local fogEnabled = true --if fog above lava adds light / is enabled
local fogDistortion = 4.0 -- lower numbers are higher distortion amounts

local tideAmplitude = 2 -- how much lava should rise up-down on static level
local tidePeriod = 200 -- how much time between live rise up-down

local effectDamage = "lavadamage" -- damage ceg effect
local effectBurst = "lavasplash" -- burst ceg effect, set to false to disable
-- sound arrays: always rows with {soundid, minVolume, maxVolume}
local effectBurstSounds = { {"lavaburst1", 80, 100}, {"lavaburst2", 80, 100} } -- array of sounds to use for bursts, false or empty array will disable sounds
local ambientSounds =  { {"lavabubbleshort1", 25, 65}, -- ambient sounds, set ambientSounds = false to disable
			 {"lavabubbleshort2", 25, 65},
			 {"lavarumbleshort1", 20, 40},
			 {"lavarumbleshort2", 20, 40},
			 {"lavarumbleshort3", 20, 40} }

--- Tide animation scenes
---  each row is: { HeightLevel, Speed, Delay for next TideRhym in seconds }
---  first element needs to be -1 than pre-game lava level when present
local tideRhym = {}


----------------------------------------
-- Helper methods

local function trimMapVersion(mapName)
	-- Trims version from the end of the map name.
	-- find last space before version (version is numbers with dots, possibly preceded by v or V)
	local lastSpace = mapName:match'^.*()\ [vV]*[%d%.]+'
	if not lastSpace then return mapName end
	return string.sub(mapName, 1, lastSpace - 1)
end

local function gameConfigPath(mapName)
	return GAME_CONFIG_DIR .. mapName .. ".lua"
end

local function getLavaConfig(mapName)
	if voidWaterMap then return end
	-- Get lava config for map.
	-- mapConfig has preference over gameConfig, unless game sets 'overrideMap'
	local gameConfig, mapConfig
	if mapName then
		-- Look for full name (with version), and otherwise try with trimmed version.
		local mapNameNoVersion = trimMapVersion(mapName)
		if VFS.FileExists(gameConfigPath(mapName)) then
			gameConfig = VFS.Include(gameConfigPath(mapName))
			Spring.Log('Lava', LOG.INFO, "Loaded map config for", mapName)
		elseif mapName ~= mapNameNoVersion and VFS.FileExists(gameConfigPath(mapNameNoVersion)) then
			gameConfig = VFS.Include(gameConfigPath(mapNameNoVersion))
			Spring.Log('Lava', LOG.INFO, "Loaded map config for", mapNameNoVersion)
		end
	end
	if VFS.FileExists(MAP_CONFIG_PATH) then
		mapConfig = VFS.Include(MAP_CONFIG_PATH)
		Spring.Log('Lava', LOG.INFO, "Loaded map config for", mapNameNoVersion)
	end
	if mapConfig and gameConfig and gameConfig.overrideMap then
		-- allow gameconfig to override map config when 'overrideMap' is set
		mapConfig = gameConfig
		Spring.Log('Lava', LOG.INFO, "Game config overrides map")
	end
	return mapConfig or gameConfig
end

local function applyConfig(lavaConfig)
	isLavaMap = true

	diffuseEmitTex = lavaConfig.diffuseEmitTex or diffuseEmitTex
	normalHeightTex = lavaConfig.normalHeightTex or normalHeightTex

	level = lavaConfig.level or level
	grow = lavaConfig.grow or grow
	damage = lavaConfig.damage or damage
	if lavaConfig.damageFeatures ~= nil then
		damageFeatures = lavaConfig.damageFeatures
	end
	uvScale = lavaConfig.uvScale or uvScale
	colorCorrection = lavaConfig.colorCorrection or colorCorrection
	losDarkness = lavaConfig.losDarkness or losDarkness
	swirlFreq = lavaConfig.swirlFreq or swirlFreq
	swirlAmp = lavaConfig.swirlAmp or swirlAmp
	specularExp = lavaConfig.specularExp or specularExp
	shadowStrength = lavaConfig.shadowStrength or shadowStrength
	coastWidth = lavaConfig.coastWidth or coastWidth
	coastColor = lavaConfig.coastColor or coastColor
	coastLightBoost = lavaConfig.coastLightBoost or coastLightBoost

	parallaxDepth = lavaConfig.parallaxDepth or parallaxDepth
	parallaxOffset = lavaConfig.parallaxOffset or parallaxOffset

	fogColor = lavaConfig.fogColor or fogColor
	fogFactor = lavaConfig.forFactor or fogFactor
	fogHeight = lavaConfig.fogHeight or fogHeight
	fogAbove = lavaConfig.fogAbove or fogAbove
	if lavaConfig.fogEnabled ~= nil then
		fogEnabled = lavaConfig.fogEnabled
	end
	fogDistortion = lavaConfig.fogDistortion or fogDistortion

	tideAmplitude = lavaConfig.tideAmplitude or tideAmplitude
	tidePeriod = lavaConfig.tidePeriod or tidePeriod
	tideRhym = lavaConfig.tideRhym or tideRhym
	effectDamage = lavaConfig.effectDamage or effectDamage
	if lavaConfig.effectBurst ~= nil then
		effectBurst = lavaConfig.effectBurst
	end
	effectBurstSounds = lavaConfig.effectBurstSounds or effectBurstSounds
	if lavaConfig.ambientSounds ~= nil then
		ambientSounds = lavaConfig.ambientSounds
	end
end


----------------------------------------
-- Process config

local mapLavaConfig = getLavaConfig(mapName)

if mapLavaConfig and (not voidWaterMap) then
	applyConfig(mapLavaConfig)

elseif Game.waterDamage > 0 and (not voidWaterMap) then -- Waterdamagemaps - keep at the very bottom
	isLavaMap = true
	grow = 0
	effectBurst = false
	level = 1
	colorCorrection = "vec3(0.15, 1.0, 0.45)"
	--coastColor = "vec3(0.6, 0.7, 0.03)"
	coastLightBoost = 0.5
	coastWidth = 16.0 -- how wide the coast of the lava should be
	fogColor = "vec3(1.60, 0.8, 0.3)"
	--coastWidth = 30.0
	lavaParallaxDepth = 24.0 -- set to >0 to enable, how deep the parallax effect is
	lavaParallaxOffset = 0.15 -- center of the parallax plane, from 0.0 (up) to 1.0 (down)
	swirlFreq = 0.008
	swirlAmp = 0.01
	uvScale = 3
	specularExp = 12.0
	tideAmplitude = 3
	tidePeriod = 40
	fogFactor = 0.1
	fogHeight = 20
	fogAbove = 0.1
	fogDistortion = 1
	tideRhym = { { 4, 0.05, 5*6000 } }
	--tideRhym = { { 1, 0.25, 5*6000 } }

elseif Spring.GetModOptions().map_waterislava and (not voidWaterMap) then
	isLavaMap = true
	level = 4
	tideRhym = { { 4, 0.05, 5*6000 } }
end


return {
	isLavaMap = isLavaMap,

	diffuseEmitTex = diffuseEmitTex,
	normalHeightTex = normalHeightTex,

	level = level,
	grow = grow,
	damage = damage,
	damageFeatures = damageFeatures,
	uvScale = uvScale,
	colorCorrection = colorCorrection,
	losDarkness = losDarkness,
	swirlFreq = swirlFreq,
	swirlAmp = swirlAmp,
	specularExp = specularExp,
	shadowStrength = shadowStrength,
	coastWidth = coastWidth,
	coastColor = coastColor,
	coastLightBoost = coastLightBoost,

	lavaParallaxDepth = lavaParallaxDepth,
	lavaParallaxOffset = lavaParallaxOffset,

	fogColor = fogColor,
	fogFactor = fogFactor,
	fogHeight = fogHeight,
	fogAbove = fogAbove,
	fogEnabled = fogEnabled,
	fogDistortion = fogDistortion,

	tideAmplitude = tideAmplitude,
	tidePeriod = tidePeriod,

	tideRhym = tideRhym,

	effectDamage = effectDamage,
	effectBurst = effectBurst,
	effectBurstSounds = effectBurstSounds,
	ambientSounds = ambientSounds,
}
