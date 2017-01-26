-- shells

return {
  ["shells"] = {
    shells = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.97,
        colormap           = [[1 1 1 1   1 1 1 1]],
        directional        = true,
        emitrot            = 0,
        emitrotspread      = 10,
        emitvector         = [[dir]],
        gravity            = [[0, -0.5, 0]],
        numparticles       = 1,
        particlelife       = 30,
        particlelifespread = 0,
        particlesize       = 4,
        particlesizespread = 0,
        particlespeed      = 4,
        particlespeedspread = 0,
        pos                = [[0, 0, 0]],
        sizegrowth         = 0,
        sizemod            = 1.0,
        texture            = [[shell]],
      },
    },
  },

}

