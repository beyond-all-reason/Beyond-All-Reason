local conf = {
	level = 0,
	damage = 150,
	tideAmplitude = 3,
	tidePeriod = 95,
	diffuseEmitTex = "LuaUI/images/lava/lava7_diffuseemit.dds",
	normalHeightTex = "LuaUI/images/lava/lava7_normalheight.dds",
	losDarkness = 0.7,
	colorCorrection = "vec3(1.1, 1.0, 0.88)",
	shadowStrength = 1.0,
	coastColor = "vec3(2.2, 0.4, 0.0)",
	coastLightBoost = 0.7,
	coastWidth = 36.0,
	fogFactor = 0.02,
	fogColor = "vec3(2.0, 0.31, 0.0)",
	fogHeight = 35,
	fogAbove = 0.18,
	fogDistortion = 2.0,
	uvScale = 10.0,
	tideRhythm = { { -1, 0.25, 5*6000 } },
}

return conf
