-- factorydustsmall

return {
  ["factorydustsmall"] = {
    poof01 = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.95,
        colormap           = [[0.1 0.1 0.1 1.0	0.5 0.4 0.3 1.0		0 0 0 0.0]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0, 0]],
        numparticles       = 80,
        particlelife       = 15,
        particlelifespread = 10,
        particlesize       = 15,
        particlesizespread = 5,
        particlespeed      = 1,
        particlespeedspread = 10,
        pos                = [[r-1 r1, 1, r-1 r1]],
        sizegrowth         = 1.2,
        sizemod            = 1.0,
        texture            = [[dirt]],
        useairlos          = true,
      },
    },
  },

}

