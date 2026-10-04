return {
	["juno_sphere_emit"] = {
		nonodecay = {
			class = [[CSimpleParticleSystem]],
			air = true,
			water = true,
			ground = true,
			unit = true,
			count = 4,
			properties =  {
				airdrag = 0.92,
				sizeGrowth = -0.03,
				sizeMod = 1.0,
				pos = [[0, 1, 0]],
				emitVector = [[0, 1, 0]],
				gravity = [[0,0.1,0]],
				colorMap = [[0.1 0.1 0.1 0.0001   0.4 0.4 0.4 0.4   0.4 0.2 0.2 0.5	  0.4 0.0 0.0 0.4 	0.0 0.0 0.0 0.001]],
				texture = [[nanobeam-resurrect]],
				particleLife = 30,
				particleLifeSpread = 20,
				numParticles = 1,
				particleSpeed = 1,
				particleSpeedSpread = 1.5,
				particleSize = 1,
				particleSizeSpread = 2,
				directional = true,
				emitRot = 40,
				emitRotSpread = 32,
				useAirLos = false;
			},
		},
	},
}
