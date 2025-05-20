local conf = {
	grow = 0,
	colorCorrection = "vec3(1.0, 1.0, 1.0)",
	coastColor = "vec3(1.0, 0.25, 0.0)",
	coastLightBoost = 0.3,
	fogColor = "vec3(1.5, 0.1, 0.0)",
	fogFactor = 0.01,
	fogHeight = 15,
	fogAbove = 4.0,
	fogDistortion = 2.0,
	tideAmplitude = 0.3,
	tidePeriod = 1000,
	tideRhythm = { { -1, 0.05, 5*6000 } },
}

return conf
