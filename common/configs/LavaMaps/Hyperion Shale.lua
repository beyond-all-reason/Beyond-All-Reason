local conf = {
	grow = 0,
	effectBurst = false,
	diffuseEmitTex = "LuaUI/images/lava/lava2_diffuseemitblue.dds",
	colorCorrection = "vec3(1.0, 1.0, 1.0)",
	coastColor = "vec3(0.0, 0.35, 0.9)",
	coastLightBoost = 0.3,
	fogColor = "vec3(0.0, 0.3, 1.0)",
	fogFactor = 0.01,
	fogHeight = 15,
	fogAbove = 4.0,
	fogDistortion = 2.0,
	tideAmplitude = 0.3,
	tidePeriod = 1000,
	tideRhythm = { { -1, 0.05, 5*6000 } },
}

return conf
