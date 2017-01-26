-- miofskyparticles

return {
  ["miofskyparticles"] = {
    poof01 = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.95,
        colormap           = [[0.3 0.5 0.01 1.0 0.15 0.2 0.15 0.1   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 10,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.3, 0]],
        numparticles       = 5,
        particlelife       = 10,
        particlelifespread = 10,
        particlesize       = 20,
        particlesizespread = 0,
        particlespeed      = 17,
        particlespeedspread = 2,
        pos                = [[r-1 r1, r-1 r1, r-1 r1]],
        sizegrowth         = 0.8,
        sizemod            = 1.0,
        texture            = [[dirt]],
        useairlos          = true,
      },
    },
    smoke = {
      air                = true,
      count              = 3,
      ground             = true,
      water              = true,
      properties = {
        agespeed           = 0.05,
        alwaysvisible      = true,
        color              = 0.1,
        pos                = [[r-800 r800, 3, r-800 r800]],
        size               = 2,
        sizeexpansion      = 0.6,
        sizegrowth         = 5,
        speed              = [[r-3 r3, 1 r2.3, r-3 r3]],
        startsize          = 1,
      },
    },
  },

}

