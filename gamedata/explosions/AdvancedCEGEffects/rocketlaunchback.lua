-- rocketexhaust

return {
  ["rocketexhaust"] = {
    poofdots = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.8,
        colormap           = [[0.4 0.4 0.4 0.5   0.4 0.4 0.4 0.3 0.0 0.0 0.0 0.0]],
        directional        = false,
        emitrot            = -180,
        emitrotspread      = 50,
        emitvector         = [[dir]],
        gravity            = [[0, 0, 0]],
        numparticles       = 16,
        particlelife       = 30,
        particlelifespread = 8,
        particlesize       = 15,
        particlesizespread = 5,
        particlespeed      = 5,
        particlespeedspread = 5,
        pos                = [[0, 0, 0]],
        sizegrowth         = 0.3,
        sizemod            = 1.0,
        texture            = [[dirt]],
        useairlos          = false,
      },
    },
  },

}

