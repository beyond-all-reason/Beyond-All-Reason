-- skyhatelaser

return {
  ["skyhatelaser"] = {
    dirtg = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.8,
        --alwaysvisible      = true,
        colormap           = [[0.75 0 0 0.1 	0.75 0 0 0.1 	0.75 0 0 0.1 	0.75 0 0 0.1 	0.5 0.5 0.5 0.1		0 0 0 0.0]],
        directional        = true,
        emitrot            = 0,
        emitrotspread      = 0,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 1, 0]],
        numparticles       = 1,
        particlelife       = 60,
        particlelifespread = 0,
        particlesize       = 5,
        particlesizespread = 10,
        particlespeed      = 5,
        particlespeedspread = 0,
        pos                = [[r-0.5 r0.5, 1 r2, r-0.5 r0.5]],
        sizegrowth         = 1.5,
        sizemod            = 1.0,
        texture            = [[laser]],
        useairlos          = false,
      },
    },
  },

}

