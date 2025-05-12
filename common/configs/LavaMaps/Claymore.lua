local conf = {
	grow = 0,
	effectBurst = false,
	diffuseEmitTex = "LuaUI/images/lava/lava2_diffuseemitblue.dds",
	colorCorrection = "vec3(0.4, 0.5, 0.4)",
	coastColor = "vec3(0.24, 0.46, 0.5)",
	coastLightBoost = 0.3,
	fogColor = "vec3(0.24, 0.46, 0.5)",
	fogFactor = 0.01,
	fogHeight = 15,
	fogAbove = 4.0,
	fogDistortion = 2.0,
	tideAmplitude = 0.3,
	tidePeriod = 1000,
	tideRhythm = { { -1, 0.05, 5*6000 } },
}

return conf
