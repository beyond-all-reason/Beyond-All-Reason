local mapName = Game.mapName:lower()
Spring.Echo("Lava Mapname", mapName)

local voidWaterMap = false
local mapLavaConfig = false

local success, mapinfo = pcall(VFS.Include, "mapinfo.lua") -- load mapinfo.lua confs
if success or mapinfo ~= nil then
	voidWaterMap = mapinfo.voidwater
	mapLavaConfig = mapinfo.lava
end

local isLavaMap = false

-- defaults:
local diffuseEmitTex = "LuaUI/images/lava/lava2_diffuseemit.dds"
local normalHeightTex = "LuaUI/images/lava/lava2_normalheight.dds"

local level = 1 -- pre-game lava level
local grow = 0.25 -- initial lava grow speed
local damage = 100 -- damage per second or health proportion (0-1), check damageMode description
-- damageMode:
--    direct:  direct damage (damage is damage per second)
--    proportional: proportional damage (damage will be unitHealth*damage per second)
--    destroy: direct kill
local damageMode = "direct"
local damageFeatures = false -- Lava also damages features when set, if set to float, it's proportional damage per second (0 to 1), if set to true sets default of 0.1
local damageMinHealth = false -- Lava damage doesn't kill completely, set to 0.0-1.0 proportion of health
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

local tideRhym = {}

--[[ EXAMPLE

-- tidyRhym rows will be consumed by:
--  addTideRhym(HeightLevel, Speed, Delay for next TideRhym in seconds)

if string.find(mapName, "quicksilver") then
	isLavaMap = true
	level = 220
	grow = 0.25
	damage = 100
	tideRhym = { { -21, 0.25, 5*10 },
		     { 150, 0.25, 3    },
		     { -20, 0.25, 5*10 },
		     { 150, 0.25, 5    },
		     { -20, 1.00, 5*60 },
		     { 180, 0.50, 60   },
		     { 240, 0.20, 10   } }
end

]]

if mapLavaConfig and not voidWaterMap then
	isLavaMap = true

	diffuseEmitTex = mapLavaConfig.diffuseEmitTex or diffuseEmitTex
	normalHeightTex = mapLavaConfig.normalHeightTex or normalHeightTex

	level = mapLavaConfig.level or level
	grow = mapLavaConfig.grow or grow
	damage = mapLavaConfig.damage or damage
	damageMode = mapLavaConfig.damageMode or damageMode
	damageMinHealth = mapLavaConfig.damageMinHealth or damageMinHealth
	if mapLavaConfig.damageFeatures ~= nil then
		damageFeatures = mapLavaConfig.damageFeatures
	end
	uvScale = mapLavaConfig.uvScale or uvScale
	colorCorrection = mapLavaConfig.colorCorrection or colorCorrection
	losDarkness = mapLavaConfig.losDarkness or losDarkness
	swirlFreq = mapLavaConfig.swirlFreq or swirlFreq
	swirlAmp = mapLavaConfig.swirlAmp or swirlAmp
	specularExp = mapLavaConfig.specularExp or specularExp
	shadowStrength = mapLavaConfig.shadowStrength or shadowStrength
	coastWidth = mapLavaConfig.coastWidth or coastWidth
	coastColor = mapLavaConfig.coastColor or coastColor
	coastLightBoost = mapLavaConfig.coastLightBoost or coastLightBoost

	parallaxDepth = mapLavaConfig.parallaxDepth or parallaxDepth
	parallaxOffset = mapLavaConfig.parallaxOffset or parallaxOffset

	fogColor = mapLavaConfig.fogColor or fogColor
	fogFactor = mapLavaConfig.forFactor or fogFactor
	fogHeight = mapLavaConfig.fogHeight or fogHeight
	fogAbove = mapLavaConfig.fogAbove or fogAbove
	if mapLavaConfig.fogEnabled ~= nil then
		fogEnabled = mapLavaConfig.fogEnabled
	end
	fogDistortion = mapLavaConfig.fogDistortion or fogDistortion

	tideAmplitude = mapLavaConfig.tideAmplitude or tideAmplitude
	tidePeriod = mapLavaConfig.tidePeriod or tidePeriod
	tideRhym = mapLavaConfig.tideRhym or tideRhym
	effectDamage = mapLavaConfig.effectDamage or effectDamage
	if mapLavaConfig.effectBurst ~= nil then
		effectBurst = mapLavaConfig.effectBurst
	end
	effectBurstSounds = mapLavaConfig.effectBurstSounds or effectBurstSounds
	if mapLavaConfig.ambientSounds ~= nil then
		ambientSounds = mapLavaConfig.ambientSounds
	end

elseif string.find(mapName, "stronghold") then
	isLavaMap = true
	level = 20
	grow = 0

	damage = 25 -- damage per second
	tideAmplitude = 3
	tidePeriod = 95
	diffuseEmitTex = "LuaUI/images/lava/lava7_diffuseemit.dds"
	normalHeightTex = "LuaUI/images/lava/lava7_normalheight.dds"
	losDarkness = 0.7
	colorCorrection = "vec3(1.1, 1.0, 0.88)"
	shadowStrength = 1.0 -- how much light a shadowed fragment can recieve
	coastColor = "vec3(2.2, 0.4, 0.0)"
	coastLightBoost = 0.7
	coastWidth = 36.0
	fogFactor = 0.08 -- how dense the fog is
	fogColor = "vec3(2.0, 0.31, 0.0)"
	fogHeight = 85
	fogAbove = 0.18
	uvScale = 0.5
	swirlFreq = 0.017
	swirlAmp = 0.0024

	tideRhym = { { 19, 0.3, 5*6000 } }

elseif string.find(mapName, "incandescence") then
	isLavaMap = true
	level = 207
	damage = 150 -- damage per second
	tideAmplitude = 3
	tidePeriod = 95
	diffuseEmitTex = "LuaUI/images/lava/lava7_diffuseemit.dds"
	normalHeightTex = "LuaUI/images/lava/lava7_normalheight.dds"
	losDarkness = 0.7
	colorCorrection = "vec3(1.1, 1.0, 0.88)"
	shadowStrength = 1.0 -- how much light a shadowed fragment can recieve
	coastColor = "vec3(2.2, 0.4, 0.0)"
	coastLightBoost = 0.7
	coastWidth = 36.0
	fogFactor = 0.08 -- how dense the fog is
	fogColor = "vec3(2.0, 0.31, 0.0)"
	fogHeight = 85
	fogAbove = 0.18

	tideRhym = { { 206, 0.25, 5*6000 } } -- needs to be -1 than pre-game lava level

elseif string.find(mapName, "seths ravine") then
	isLavaMap = false
	tideRhym = { { 208, 0.25, 5*6000 } } -- needs to be -1 than pre-game lava level

elseif string.find(mapName, "moonq20xr2") then
	isLavaMap = false
	tideRhym = { { 208, 0.25, 5*6000 } } -- needs to be -1 than pre-game lava level

elseif string.find(mapName, "ghenna") then
	isLavaMap = true
	level = 251 -- pre-game lava level
	damage = 750 -- damage per second
	colorCorrection = "vec3(0.7, 0.7, 0.7)"
	swirlFreq = 0.017
	swirlAmp = 0.0024
	tideAmplitude = 3
	specularExp = 4.0
	shadowStrength = 0.9
	coastLightBoost = 0.8
	uvScale = 1.5
	tideRhym = { { 250, 0.10, 15    }, -- needs to be -1 than pre-game lava level
		     { 415, 0.05, 30    },
		     { 250, 0.10, 5*60  },
		     { 415, 0.05, 30    },
		     { 250, 0.10, 5*60  },
		     { 415, 0.05, 3*30  },
		     { 250, 0.10, 10*60 } }

elseif string.find(mapName, "hotstepper") then
	isLavaMap = true
	level = 100 -- pre-game lava level
	damage = 130 -- damage per second
	tideRhym = { { 90,  0.25, 5*60 }, -- needs to be -1 than pre-game lava level
		     { 215, 0.10, 5    },
		     { 90,  0.25, 5*60 },
		     { 290, 0.15, 5    },
		     { 90,  0.25, 4*60 },
		     { 355, 0.20, 5    },
		     { 90,  0.25, 4*60 },
		     { 390, 0.20, 5    },
		     { 90,  0.25, 2*60 },
		     { 440, 0.04, 2*60 } }

elseif string.find(mapName, "zed remake") then
	isLavaMap = true
	grow = 0
	level = 1 -- pre-game lava level
	damage = 75 -- damage per second
	uvScale = 1.5
	colorCorrection = "vec3(0.4, 0.09, 1.2)"
	losDarkness = 0.8
	coastColor = "vec3(0.8, 0.03, 1.1)"
	fogColor = "vec3(0.60, 0.10, 1.1)"
	coastLightBoost = 1.3
	tideAmplitude = 1.5 -- how much lava should rise up-down on static level
	tidePeriod = 150 -- how much time between live rise up-down
	tideRhym = { { 0, 0.3, 5*6000 } }


elseif string.find(mapName, "acidicquarry") then
	isLavaMap = true
	grow = 0
	effectBurst = false
	level = 5
	colorCorrection = "vec3(0.26, 1.0, 0.03)"
	--coastColor = "vec3(0.6, 0.7, 0.03)"
	coastLightBoost = 1.2
	coastWidth = 10.0 -- how wide the coast of the lava should be
	fogColor = "vec3(1.60, 0.8, 0.3)"
	--coastWidth = 30.0
	lavaParallaxDepth = 32.0 -- set to >0 to enable, how deep the parallax effect is
	lavaParallaxOffset = 0.2 -- center of the parallax plane, from 0.0 (up) to 1.0 (down)
	swirlFreq = 0.008
	swirlAmp = 0.017
	uvScale = 2.2
	specularExp = 12.0
	tideAmplitude = 3
	tidePeriod = 40
	fogFactor = 0.13
	fogHeight = 36
	fogAbove = 0.1
	fogDistortion = 2.0
	tideRhym = { { 4, 0.05, 5*6000 } }


elseif string.find(mapName, "speedmetal") then
	isLavaMap = true
	grow = 0
	effectBurst = false
	level = 1 -- pre-game lava level
	colorCorrection = "vec3(0.3, 0.1, 1.5)"
	--coastWidth = 40.0
	--coastColor = "vec3(1.7, 0.02, 1.4)"
	fogColor = "vec3(0.60, 0.02, 1)"
	swirlFreq = 0.025
	swirlAmp = 0.003
	tideAmplitude = 3
	tidePeriod = 50
	tideRhym = { { 1, 0.05, 5*6000 } }

elseif string.find(mapName, "thermal shock") then
	isLavaMap = true
	grow = 0
	colorCorrection = "vec3(1.0, 1.0, 1.0)"
	coastColor = "vec3(1.0, 0.25, 0.0)"
	coastLightBoost = 0.3
	fogColor = "vec3(1.5, 0.1, 0.0)"
	fogFactor = 0.01
	fogHeight = 15
	fogAbove = 4.0
	fogDistortion = 2.0
	tideAmplitude = 0.3
	tidePeriod = 1000
	tideRhym = { { -1, 0.05, 5*6000 } }

elseif string.find(mapName, "kill the middle") then
	isLavaMap = true
	level = 0
	damage = 150 -- damage per second
	tideAmplitude = 3
	tidePeriod = 95
	diffuseEmitTex = "LuaUI/images/lava/lava7_diffuseemit.dds"
	normalHeightTex = "LuaUI/images/lava/lava7_normalheight.dds"
	losDarkness = 0.7
	colorCorrection = "vec3(1.1, 1.0, 0.88)"
	shadowStrength = 1.0 -- how much light a shadowed fragment can recieve
	coastColor = "vec3(2.2, 0.4, 0.0)"
	coastLightBoost = 0.7
	coastWidth = 36.0
	fogFactor = 0.08 -- how dense the fog is
	fogColor = "vec3(2.0, 0.31, 0.0)"
	fogHeight = 85
	fogAbove = 0.18

	tideRhym = { { -1, 0.25, 5*6000 } } -- needs to be -1 than pre-game lava level

elseif string.find(mapName, "kings") then
	isLavaMap = true
	grow = 0
	colorCorrection = "vec3(1.0, 1.0, 1.0)"
	coastColor = "vec3(1.0, 0.25, 0.0)"
	coastLightBoost = 0.3
	fogColor = "vec3(1.5, 0.1, 0.0)"
	fogFactor = 0.01
	fogHeight = 15
	fogAbove = 4.0
	fogDistortion = 2.0
	tideAmplitude = 0.3
	tidePeriod = 1000
	tideRhym = { { -1, 0.05, 5*6000 } }

elseif string.find(mapName, "forge") then
	isLavaMap = true
	level = 0
	damage = 150 -- damage per second
	tideAmplitude = 3
	tidePeriod = 95
	diffuseEmitTex = "LuaUI/images/lava/lava7_diffuseemit.dds"
	normalHeightTex = "LuaUI/images/lava/lava7_normalheight.dds"
	losDarkness = 0.7
	colorCorrection = "vec3(1.1, 1.0, 0.88)"
	shadowStrength = 1.0 -- how much light a shadowed fragment can recieve
	coastColor = "vec3(2.2, 0.4, 0.0)"
	coastLightBoost = 0.7
	coastWidth = 36.0
	fogFactor = 0.02 -- how dense the fog is
	fogColor = "vec3(2.0, 0.31, 0.0)"
	fogHeight = 35
	fogAbove = 0.18

	tideRhym = { { -1, 0.25, 5*6000 } } -- needs to be -1 than pre-game lava level

elseif string.find(mapName, "sector") then
	isLavaMap = true
	grow = 0
	effectBurst = false
	level = 5
	diffuseEmitTex = "LuaUI/images/lava/lava7_diffuseemit.dds"
	normalHeightTex = "LuaUI/images/lava/lava7_normalheight.dds"
	colorCorrection = "vec3(0.2, 0.65, 0.03)"
	--coastColor = "vec3(0.6, 0.7, 0.03)"
	coastLightBoost = 0.6
	coastWidth = 60.0 -- how wide the coast of the lava should be
	fogColor = "vec3(1.60, 0.8, 0.3)"
	--coastWidth = 30.0
	lavaParallaxDepth = 8.0 -- set to >0 to enable, how deep the parallax effect is
	lavaParallaxOffset = 0.2 -- center of the parallax plane, from 0.0 (up) to 1.0 (down)
	swirlFreq = 0.008
	swirlAmp = 0.017
	uvScale = 2.2
	specularExp = 12.0
	tideAmplitude = 3
	tidePeriod = 40
	fogFactor = 0.13
	fogHeight = 36
	fogAbove = 0.1
	fogDistortion = 2.0
	tideRhym = { { 4, 0.05, 5*6000 } }

elseif string.find(mapName, "claymore") then
	isLavaMap = true
	grow = 0
	effectBurst = false
	diffuseEmitTex = "LuaUI/images/lava/lava2_diffuseemitblue.dds"
	colorCorrection = "vec3(0.4, 0.5, 0.4)"
	coastColor = "vec3(0.24, 0.46, 0.5)"
	coastLightBoost = 0.3
	fogColor = "vec3(0.24, 0.46, 0.5)"
	fogFactor = 0.01
	fogHeight = 15
	fogAbove = 4.0
	fogDistortion = 2.0
	tideAmplitude = 0.3
	tidePeriod = 1000
	tideRhym = { { -1, 0.05, 5*6000 } }

elseif string.find(mapName, "hyperion shale") then
	isLavaMap = true
	grow = 0
	effectBurst = false
	diffuseEmitTex = "LuaUI/images/lava/lava2_diffuseemitblue.dds"
	colorCorrection = "vec3(1.0, 1.0, 1.0)"
	coastColor = "vec3(0.0, 0.35, 0.9)"
	coastLightBoost = 0.3
	fogColor = "vec3(0.0, 0.3, 1.0)"
	fogFactor = 0.01
	fogHeight = 15
	fogAbove = 4.0
	fogDistortion = 2.0
	tideAmplitude = 0.3
	tidePeriod = 1000
	tideRhym = { { -1, 0.05, 5*6000 } }

elseif string.find(mapName, "azar") then
	isLavaMap = true
	level = 0
	damage = 150 -- damage per second
	tideAmplitude = 3
	tidePeriod = 95
	diffuseEmitTex = "LuaUI/images/lava/lava7_diffuseemit.dds"
	normalHeightTex = "LuaUI/images/lava/lava7_normalheight.dds"
	losDarkness = 0.7
	colorCorrection = "vec3(1.1, 1.0, 0.88)"
	shadowStrength = 1.0 -- how much light a shadowed fragment can recieve
	coastColor = "vec3(2.2, 0.4, 0.0)"
	coastLightBoost = 0.7
	coastWidth = 36.0
	fogFactor = 0.02 -- how dense the fog is
	fogColor = "vec3(2.0, 0.31, 0.0)"
	fogHeight = 35
	fogAbove = 0.18
	fogDistortion = 2.0
	uvScale = 10.0
	tideRhym = { { -1, 0.25, 5*6000 } } -- needs to be -1 than pre-game lava level

elseif string.find(mapName, "stronghold") then
	isLavaMap = true
	grow = 0
	effectBurst = false
	level = 5
	diffuseEmitTex = "LuaUI/images/lava/lava7_diffuseemit.dds"
	normalHeightTex = "LuaUI/images/lava/lava7_normalheight.dds"
	colorCorrection = "vec3(0.2, 0.65, 0.03)"
	--coastColor = "vec3(0.6, 0.7, 0.03)"
	coastLightBoost = 0.6
	coastWidth = 60.0 -- how wide the coast of the lava should be
	fogColor = "vec3(1.60, 0.8, 0.3)"
	--coastWidth = 30.0
	lavaParallaxDepth = 8.0 -- set to >0 to enable, how deep the parallax effect is
	lavaParallaxOffset = 0.2 -- center of the parallax plane, from 0.0 (up) to 1.0 (down)
	swirlFreq = 0.008
	swirlAmp = 0.017
	uvScale = 2.2
	specularExp = 12.0
	tideAmplitude = 3
	tidePeriod = 40
	fogFactor = 0.13
	fogHeight = 36
	fogAbove = 0.1
	fogDistortion = 2.0
	tideRhym = { { 4, 0.05, 5*6000 } }

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
	damageMode = damageMode,
	damageMinHealth = damageMinHealth,
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
