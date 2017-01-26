

return {
  ["steam"] = {
    dirtg = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 2,
      ground             = true,
	  water				 = true,
      properties = {
        airdrag            = 0.7,
        alwaysvisible      = false,
        colormap           = [[0.5 0.5 0.5 1.0		0.7 0.7 0.7 1.0		0.9 0.9 0.9 1.0		0.9 0.9 0.9 0.5		0.9 0.9 0.9 0.1		0 0 0 0]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.2, 0]],
        numparticles       = 4,
        particlelife       = 60,
        particlelifespread = 20,
        particlesize       = 1,
        particlesizespread = 2,
        particlespeed      = 0.5,
        particlespeedspread = 12,
        sizegrowth         = 1,
        sizemod            = 0.9,
        texture            = [[new_dirta]],
        useairlos          = false,
		colorchange			= "stuffs",
      },
    },
  },
}

