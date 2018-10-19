return {
    ["death_wave_sparks"] = {
        ["unit_sparkles"] = {
            class = [[CSimpleParticleSystem]],
            air = true,
            water = true,
            ground = true,
            unit = true,
            count = 1,
            properties = {
                airdrag = 0.95,
                sizeGrowth = 1.25,
                sizeMod = 1.0,
                pos = [[0, 0, 0]],
                emitVector = [[0, -1, 0]],
                gravity = [[0,0,0]],
                colorMap = [[0 0 0 0	0.5 0.5 0.5 0.2	  0.8 0.8 0.8 0.4	  0.3 0.3 0.3 0.2	  0.1 0.1 0.1 0.1	  0 0 0 0.01]],
                texture = [[lightb]],
                particleLife = 3,
                particleLifeSpread = 12,
                numParticles = 1,
                particleSpeed = 2,
                particleSpeedSpread = 2,
                particleSize = 5,
                particleSizeSpread = 30,
                directional = true,
                emitRot = 0,
                emitRotSpread = 270,
            }
        },
    },
}