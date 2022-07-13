local mapName = Game.mapName:lower()
Spring.Echo("Lava Mapname", mapName)
lavaMap = false

-- defaults:
nolavaburstcegs = false
lavaDiffuseEmitTex = "LuaUI/images/lava2_diffuseemit.dds"
lavaNormalHeightTex = "LuaUI/images/lava2_normalheight.dds"

lavaLevel = 1 -- pre-game lava level
lavaGrow = 0.25 -- initial lavaGrow speed
lavaDamage = 100 -- damage per second
lavaUVscale = 2.0 -- How many times to tile the lava texture across the entire map
lavaColorCorrection = "vec3(1.0, 1.0, 1.0)" -- final colorcorrection on all lava + shore coloring
lavaLOSdarkness = 0.5 -- how much to darken the out-of-los areas of the lava plane
lavaSwirlFreq = 0.025 -- How fast the main lava texture swirls around default 0.025
lavaSwirlAmp = 0.003 -- How much the main lava texture is swirled around default 0.003
lavaSpecularExp = 64.0 -- the specular exponent of the lava plane
lavaShadowStrength = 0.4 -- how much light a shadowed fragment can recieve
lavaCoastWidth = 25.0 -- how wide the coast of the lava should be
lavaCoastColor = "vec3(2.0, 0.5, 0.0)" -- the color of the lava coast
lavaCoastLightBoost = 0.6 -- how much extra brightness should coastal areas get

lavaParallaxDepth = 16.0 -- set to >0 to enable, how deep the parallax effect is
lavaParallaxOffset = 0.5 -- center of the parallax plane, from 0.0 (up) to 1.0 (down)

lavaFogColor = "vec3(2.0, 0.5, 0.0)" -- the color of the fog light
lavaFogFactor = 0.06 -- how dense the fog is
lavaFogHeight = 20 -- how high the fog is above the lava plane
lavaFogAbove = 1.0 -- the multiplier for how much fog should be above lava fragments, ~0.2 means the lava itself gets hardly any fog, while 2.0 would mean the lava gets a lot of extra fog
lavaFogEnabled = true --if fog above lava adds light / is enabled
lavaFogDistortion = 4.0 -- lower numbers are higher distortion amounts

lavaTideamplitude = 2 -- how much lava should rise up-down on static level
lavaTideperiod = 200 -- how much time between live rise up-down


--[[ EXAMPLE

addTideRhym(HeightLevel, Speed, Delay for next TideRhym in seconds)

if string.find(mapName, "quicksilver") then
    lavaMap = true
    lavaMinHeight = 137 -- minheight of map smf - otherwise will use 0
    lavaLevel = 220
    lavaGrow = 0.25
    lavaDamage = 100
    if (gadgetHandler:IsSyncedCode()) then
        addTideRhym (-21, 0.25, 5*10)
        addTideRhym (150, 0.25, 3)
        addTideRhym (-20, 0.25, 5*10)
        addTideRhym (150, 0.25, 5)
        addTideRhym (-20, 1, 5*60)
        addTideRhym (180, 0.5, 60)
        addTideRhym (240, 0.2, 10)
    end
end

]]


if string.find(mapName, "incandescence") then
	lavaMap = true
	lavaLevel = 207
	lavaDamage = 150 -- damage per second
	lavaTideamplitude = 3
	lavaTideperiod = 95
	lavaDiffuseEmitTex = "LuaUI/images/lava7_diffuseemit.dds"
	lavaNormalHeightTex = "LuaUI/images/lava7_normalheight.dds"
	lavaLOSdarkness = 0.7
	lavaColorCorrection = "vec3(1.1, 1.0, 0.88)"
	lavaShadowStrength = 1.0 -- how much light a shadowed fragment can recieve
	lavaCoastColor = "vec3(2.2, 0.4, 0.0)"
	lavaCoastLightBoost = 0.7
	lavaCoastWidth = 36.0
	lavaFogFactor = 0.08 -- how dense the fog is
	lavaFogColor = "vec3(2.0, 0.31, 0.0)"
	lavaFogHeight = 85
	lavaFogAbove = 0.18

	if isLavaGadget and isLavaGadget == "synced" then
		addTideRhym (206, 0.25, 5*6000) -- needs to be -1 than pre-game lava level
	end

	-- ALL LAVA-METAL-ASTEROID MAPS
elseif string.find(mapName, "asteroid_mines") then
	lavaMap = true
	lavaDiffuseEmitTex = "LuaUI/images/lava7_diffuseemit.dds"
	lavaNormalHeightTex = "LuaUI/images/lava7_normalheight.dds"
	lavaColorCorrection = "vec3(1.1, 1.0, 0.9)"
	lavaSwirlFreq = 0.01
	lavaSwirlAmp = 0.005
	lavaGrow = 0
	lavaLevel = 6 -- pre-game lava level
	lavaDamage = 150 -- damage per second
	lavaUVscale = 1.5 -- How many times to tile the lava texture across the entire map
	lavaTideamplitude = 3
	lavaTideperiod = 250
	lavaShadowStrength = 0.9 -- how much light a shadowed fragment can recieve
	lavaCoastColor = "vec3(2.2, 0.4, 0.0)"
	lavaCoastLightBoost = 0.7
	lavaCoastWidth = 100.0 -- how wide the coast of the lava should be
	lavaFogFactor = 0.09 -- how dense the fog is
	lavaFogColor = "vec3(1.7, 0.36, 0.0)"
	lavaFogHeight = 110
	lavaFogAbove = 0.2
	lavaFogDistortion = 4.0
	--lavaShadowStrength = 0.4 -- how much light a shadowed fragment can recieve
	if isLavaGadget and isLavaGadget == "synced" then
		addTideRhym (5, 0.25, 5*6000) -- needs to be -1 than pre-game lava level
	end

elseif string.find(mapName, "cloud9") or string.find(mapName, "oort_cloud") then
	lavaMap = true
	lavaGrow = 0
	lavaLevel = 6 -- pre-game lava level
	lavaDamage = 150 -- damage per second
	lavaUVscale = 1.5 -- How many times to tile the lava texture across the entire map
	lavaTideamplitude = 3
	lavaTideperiod = 250
	lavaShadowStrength = 0.9 -- how much light a shadowed fragment can recieve
	lavaCoastLightBoost = 0.7
	lavaCoastWidth = 100.0 -- how wide the coast of the lava should be
	lavaFogFactor = 0.09 -- how dense the fog is
	lavaFogColor = "vec3(1.5, 0.4, 0.0)"
	lavaFogHeight = 110
	lavaFogAbove = 0.2
	lavaFogDistortion = 8.0
	--lavaShadowStrength = 0.4 -- how much light a shadowed fragment can recieve
	if isLavaGadget and isLavaGadget == "synced" then
		addTideRhym (5, 0.25, 5*6000) -- needs to be -1 than pre-game lava level
	end

elseif string.find(mapName, "seths ravine") then
	lavaMap = false
	if isLavaGadget and isLavaGadget == "synced" then
		addTideRhym (208, 0.25, 5*6000) -- needs to be -1 than pre-game lava level
	end


elseif string.find(mapName, "ghenna") then
	lavaMap = true
	lavaLevel = 251 -- pre-game lava level
	lavaDamage = 750 -- damage per second
	lavaColorCorrection = "vec3(0.7, 0.7, 0.7)"
	lavaSwirlFreq = 0.017
	lavaSwirlAmp = 0.0024
	lavaTideamplitude = 3
	lavaSpecularExp = 4.0
	lavaShadowStrength = 0.9
	lavaCoastLightBoost = 0.8
	lavaUVscale = 1.5
	if isLavaGadget and isLavaGadget == "synced" then
		addTideRhym (250, 0.10, 15) -- needs to be -1 than pre-game lava level
		addTideRhym (415, 0.05, 30)
		addTideRhym (250, 0.10, 5*60)
		addTideRhym (415, 0.05, 30)
		addTideRhym (250, 0.10, 5*60)
		addTideRhym (415, 0.05, 3*30)
		addTideRhym (250, 0.10, 10*60)
	end


elseif string.find(mapName, "hotstepper") then
	lavaMap = true
	lavaLevel = 100 -- pre-game lava level
	lavaDamage = 130 -- damage per second
	if isLavaGadget and isLavaGadget == "synced" then
		addTideRhym (90, 0.25, 5*60) -- needs to be -1 than pre-game lava level
		addTideRhym (215, 0.10, 5)
		addTideRhym (90, 0.25, 5*60)
		addTideRhym (290, 0.15, 5)
		addTideRhym (90, 0.25, 4*60)
		addTideRhym (355, 0.20, 5)
		addTideRhym (90, 0.25, 4*60)
		addTideRhym (390, 0.20, 5)
		addTideRhym (90, 0.25, 2*60)
		addTideRhym (440, 0.04, 2*60)
	end

elseif string.find(mapName, "zed remake") then
	lavaMap = true
	lavaGrow = 0
	lavaLevel = 1 -- pre-game lava level
	lavaDamage = 75 -- damage per second
	lavaUVscale = 1.5
	lavaColorCorrection = "vec3(0.4, 0.09, 1.2)"
	lavaLOSdarkness = 0.8
	lavaCoastColor = "vec3(0.8, 0.03, 1.1)"
	lavaFogColor = "vec3(0.60, 0.10, 1.1)"
	lavaCoastLightBoost = 1.3
	lavaTideamplitude = 1.5 -- how much lava should rise up-down on static level
	lavaTideperiod = 150 -- how much time between live rise up-down
	if isLavaGadget and isLavaGadget == "synced" then
		addTideRhym (0, 0.3, 5*6000)
	end


elseif string.find(mapName, "acidicquarry") then
	lavaMap = true
	lavaGrow = 0
	nolavaburstcegs = true
	lavaLevel = 5
	lavaColorCorrection = "vec3(0.26, 1.0, 0.03)"
	--lavaCoastColor = "vec3(0.6, 0.7, 0.03)"
	lavaCoastLightBoost = 1.2
	lavaCoastWidth = 10.0 -- how wide the coast of the lava should be
	lavaFogColor = "vec3(1.60, 0.8, 0.3)"
	--lavaCoastWidth = 30.0
	lavaParallaxDepth = 32.0 -- set to >0 to enable, how deep the parallax effect is
	lavaParallaxOffset = 0.2 -- center of the parallax plane, from 0.0 (up) to 1.0 (down)
	lavaSwirlFreq = 0.008
	lavaSwirlAmp = 0.017
	lavaUVscale = 2.2
	lavaSpecularExp = 12.0
	lavaTideamplitude = 3
	lavaTideperiod = 40
	lavaFogFactor = 0.13
	lavaFogHeight = 36
	lavaFogAbove = 0.1
	lavaFogDistortion = 2.0
	if isLavaGadget and isLavaGadget == "synced" then
		addTideRhym (4, 0.05, 5*6000)
	end


elseif string.find(mapName, "speedmetal") then
	lavaMap = true
	lavaGrow = 0
	nolavaburstcegs = true
	lavaLevel = 1 -- pre-game lava level
	lavaColorCorrection = "vec3(0.3, 0.1, 1.5)"
	--lavaCoastWidth = 40.0
	--lavaCoastColor = "vec3(1.7, 0.02, 1.4)"
	lavaFogColor = "vec3(0.60, 0.02, 1)"
	lavaSwirlFreq = 0.025
	lavaSwirlAmp = 0.003
	lavaTideamplitude = 3
	lavaTideperiod = 50
	if isLavaGadget and isLavaGadget == "synced" then
		addTideRhym (1, 0.05, 5*6000)
	end

elseif string.find(mapName, "moonq") then
	lavaMap = false

elseif string.find(mapName, "crucible") then
	lavaMap = true
	lavaGrow = 0
	lavaSwirlFreq = 0.025
	lavaSwirlAmp = 0.003
	lavaTideamplitude = 0
	if isLavaGadget and isLavaGadget == "synced" then
		addTideRhym (1, 0.05, 5*6000)
	end

elseif string.find(mapName, "moonq") then
	lavaMap = false

elseif string.find(mapName, "forge") then
	lavaMap = true
	lavaGrow = 0
	lavaSwirlFreq = 0.025
	lavaSwirlAmp = 0.003
	lavaTideamplitude = 0
	if isLavaGadget and isLavaGadget == "synced" then
		addTideRhym (1, 0.05, 5*6000)
	end

elseif Game.waterDamage > 0 then -- Waterdamagemaps - keep at the very bottom
	--lavaMap = true
	--lavaGrow = 0
	--lavaLevel = 1
	--if isLavaGadget and isLavaGadget == "synced" then
	--	addTideRhym (1, 0.25, 5*6000)
	--end

	lavaMap = true
	lavaGrow = 0
	nolavaburstcegs = true
	lavaLevel = 1
	lavaColorCorrection = "vec3(0.15, 1.0, 0.45)"
	--lavaCoastColor = "vec3(0.6, 0.7, 0.03)"
	lavaCoastLightBoost = 0.5
	lavaCoastWidth = 16.0 -- how wide the coast of the lava should be
	lavaFogColor = "vec3(1.60, 0.8, 0.3)"
	--lavaCoastWidth = 30.0
	lavaParallaxDepth = 24.0 -- set to >0 to enable, how deep the parallax effect is
	lavaParallaxOffset = 0.15 -- center of the parallax plane, from 0.0 (up) to 1.0 (down)
	lavaSwirlFreq = 0.008
	lavaSwirlAmp = 0.01
	lavaUVscale = 3
	lavaSpecularExp = 12.0
	lavaTideamplitude = 3
	lavaTideperiod = 40
	lavaFogFactor = 0.1
	lavaFogHeight = 20
	lavaFogAbove = 0.1
	lavaFogDistortion = 1
	if isLavaGadget and isLavaGadget == "synced" then
		addTideRhym (4, 0.05, 5*6000)
	end

end


