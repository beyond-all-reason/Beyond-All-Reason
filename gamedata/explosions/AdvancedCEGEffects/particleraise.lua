-- particleraise

return {
  ["particleraise"] = {
    poof01 = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.2,
        colormap           = [[0.1 0.1 0.8 0.04	0.3 0.3 1.0 0.04	0.1 0.1 0.1 0.01]],
        directional        = false,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 10, 0]],
        numparticles       = 20,
        particlelife       = 10,
        particlelifespread = 32,
        particlesize       = 20,
        particlesizespread = 0,
        particlespeed      = 128,
        particlespeedspread = 128,
        pos                = [[0, -2, 0]],
        sizegrowth         = 0.8,
        sizemod            = 1.0,
        texture            = [[randomdots]],
        useairlos          = false,
      },
    },
  },

}

