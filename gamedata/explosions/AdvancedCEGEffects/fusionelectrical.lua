-- fusionelectrical

return {
  ["fusionelectrical"] = {
    dirtg = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.7,
        alwaysvisible      = true,
        colormap           = [[1 1 1 1  1 1 1 1]],
        directional        = true,
        emitrot            = 0,
        emitrotspread      = 0,
        emitvector         = [[0.1 r0.3, 0, 0.1r0.3]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = 15,
        particlelifespread = 20,
        particlesize       = [[3 r4]],
        particlesizespread = 10,
        particlespeed      = 1,
        particlespeedspread = 3,
        pos                = [[r-0.5 r0.5, 1 r2, r-0.5 r0.5]],
        sizegrowth         = 1.0,
        sizemod            = 1.0,
        texture            = [[electricalarc]],
        useairlos          = false,
      },
    },
  },

}

