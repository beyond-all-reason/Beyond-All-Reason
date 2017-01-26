-- shotgunspray

return {
  ["shotgunspray"] = {
    searingflame = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 1,
        colormap           = [[1.0 0.7 0.0 0.0  1.0 0.7 0.0 0.01]],
        directional        = true,
        emitrot            = 3,
        emitrotspread      = 1,
        emitvector         = [[dir]],
        gravity            = [[0, 0, 0]],
        numparticles       = 8,
        particlelife       = 10,
        particlelifespread = 5,
        particlesize       = 1,
        particlesizespread = 0,
        particlespeed      = 20,
        particlespeedspread = 10,
        pos                = [[0, 0, 0]],
        sizegrowth         = 1,
        sizemod            = 1,
        texture            = [[gunshot]],
        useairlos          = false,
      },
    },
  },

}

