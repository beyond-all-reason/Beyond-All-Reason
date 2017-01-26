-- artyshot2

return {
  ["artyshot2"] = {
    smokeandfire = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.70,
        alwaysvisible      = true,
        colormap           = [[0.9 0.25 0.0 0.05    0.25 0.25 0.25 0.05	0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 2,
        particlelife       = 10,
        particlelifespread = 4,
        particlesize       = 1,
        particlesizespread = 20,
        particlespeed      = 2,
        particlespeedspread = 2,
        pos                = [[0.0, 1, 0.0]],
        sizegrowth         = -0.1,
        sizemod            = 1,
        texture            = [[dirt]],
        useairlos          = true,
      },
    },
  },

}

