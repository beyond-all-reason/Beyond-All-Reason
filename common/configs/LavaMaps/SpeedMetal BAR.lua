local conf = {
	grow = 0,
	effectBurst = false,
	level = 1,
	colorCorrection = "vec3(0.3, 0.1, 1.5)",
	--coastWidth = 40.0,
	--coastColor = "vec3(1.7, 0.02, 1.4)",
	fogColor = "vec3(0.60, 0.02, 1)",
	swirlFreq = 0.025,
	swirlAmp = 0.003,
	tideAmplitude = 3,
	tidePeriod = 50,
	tideRhythm = { { 1, 0.05, 5*6000 } },
}

return conf
