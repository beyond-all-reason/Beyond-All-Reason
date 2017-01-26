-- nano
-- nanohuge

return {
  ["nano"] = {
    dirtg = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.7,
        alwaysvisible      = true,
        colormap           = [[0.25 0.60 0.30 1.0	0 0 0 0.0]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = 60,
        particlelifespread = 20,
        particlesize       = 12,
        particlesizespread = 10,
        particlespeed      = 1,
        particlespeedspread = 6,
        pos                = [[r-0.5 r0.5, 1 r2, r-0.5 r0.5]],
        sizegrowth         = 1.5,
        sizemod            = 1.0,
        texture            = [[electriclight]],
        useairlos          = false,
      },
    },
  },

  ["nanohuge"] = {
    dirtg = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.7,
        alwaysvisible      = true,
        colormap           = [[0.25 0.60 0.30 1.0	0 0 0 0.0]],
        directional        = true,
        emitrot            = 0,
        emitrotspread      = 0,
        emitvector         = [[0, 0, 0]],
        gravity            = [[0, 0.3 r0.3, 0]],
        numparticles       = 1,
        particlelife       = 60,
        particlelifespread = 20,
        particlesize       = [[12 r4]],
        particlesizespread = 10,
        particlespeed      = 1,
        particlespeedspread = 6,
        pos                = [[r-0.5 r0.5, 1 r2, r-0.5 r0.5]],
        sizegrowth         = 1.5,
        sizemod            = 1.0,
        texture            = [[electriclight]],
        useairlos          = false,
      },
    },
  },

}

