return {
	["juno_sphere_emit"] = {
		["nonodecay"] = {
			class = [[CSimpleParticleSystem]],
			air = true,
			water = true,
			ground = true,
			unit = true,
			count = 3,
			properties =  {
				airdrag = 0.95,
				sizeGrowth = -0.02,
				sizeMod = 1.0,
				pos = [[0, 1, 0]],
				emitVector = [[0, 1, 0]],
				gravity = [[0,0.2,0]],
				colorMap = [[0 0 0 0.0001   0.0 0.0 0.0 0.0001   0.0 0.0 0.0 0.7	  0.0 0.0 0.0 0.5 	0.0 0.0 0.0 0.001]],
				texture = [[nanoball]],
				particleLife = 5,
				particleLifeSpread = 15,
				numParticles = 1,
				particleSpeed = 1,
				particleSpeedSpread = 2,
				particleSize = 2,
				particleSizeSpread = 3,
				directional = true,
				emitRot = 40,
				emitRotSpread = 32,
				useAirLos = false;
			}
		},
	},
}
