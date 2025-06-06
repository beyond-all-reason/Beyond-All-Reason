local conf = {
	grow = 0,
	effectBurst = false,
	level = 5,
	diffuseEmitTex = "LuaUI/images/lava/lava7_diffuseemit.dds",
	normalHeightTex = "LuaUI/images/lava/lava7_normalheight.dds",
	colorCorrection = "vec3(0.2, 0.65, 0.03)",
	--coastColor = "vec3(0.6, 0.7, 0.03)",
	coastLightBoost = 0.6,
	coastWidth = 60.0,
	fogColor = "vec3(1.60, 0.8, 0.3)",
	--coastWidth = 30.0,
	lavaParallaxDepth = 8.0,
	lavaParallaxOffset = 0.2,
	swirlFreq = 0.008,
	swirlAmp = 0.017,
	uvScale = 2.2,
	specularExp = 12.0,
	tideAmplitude = 3,
	tidePeriod = 40,
	fogFactor = 0.13,
	fogHeight = 36,
	fogAbove = 0.1,
	fogDistortion = 2.0,
	tideRhythm = { { 4, 0.05, 5*6000 } },
}

return conf
