local conf = {
	level = 251,
	damage = 750,
	colorCorrection = "vec3(0.7, 0.7, 0.7)",
	swirlFreq = 0.017,
	swirlAmp = 0.0024,
	tideAmplitude = 3,
	specularExp = 4.0,
	shadowStrength = 0.9,
	coastLightBoost = 0.8,
	uvScale = 1.5,
	tideRhythm = { { 250, 0.10, 15    },
		     { 415, 0.05, 30    },
		     { 250, 0.10, 5*60  },
		     { 415, 0.05, 30    },
		     { 250, 0.10, 5*60  },
		     { 415, 0.05, 3*30  },
		     { 250, 0.10, 10*60 } },
}

return conf
