-- flamethrowerrange500

return {
  ["flamethrowerrange500"] = {
    searingflame2 = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 1,
        colormap           = [[0.01 0.01 0.01 0.005    0.04 0.04 0.1 0.005    0.08 0.03 0.01 0.005    0 0 0 0.05 0 0 0 0.01]],
        directional        = true,
        emitrot            = 3,
        emitrotspread      = 5,
        emitvector         = [[dir]],
        gravity            = [[0, 0.05, 0]],
        numparticles       = 30,
        particlelife       = 60,
        particlelifespread = 5,
        particlesize       = [[2 r3]],
        particlesizespread = 0,
        particlespeed      = 8,
        particlespeedspread = 3,
        pos                = [[0, 0, 0]],
        sizegrowth         = 0.5,
        sizemod            = 1,
        texture            = [[flame]],
        useairlos          = true,
      },
    },
  },

}

