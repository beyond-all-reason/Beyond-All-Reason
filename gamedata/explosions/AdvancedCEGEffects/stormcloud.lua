-- stormcloud

return {
  ["stormcloud"] = {
    poof01 = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 1.0,
        colormap           = [[0.3 0.3 0.3 0.5   0 0 0 0.3]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 25,
        emitvector         = [[0, 0, 0]],
        gravity            = [[r-0.05 r0.05, 0 r0.05, r-0.05 r0.05]],
        numparticles       = 2,
        particlelife       = 20,
        particlelifespread = 40,
        particlesize       = 10,
        particlesizespread = 10,
        particlespeed      = 3,
        particlespeedspread = 10,
        pos                = [[r-1 r1, r-1 r1, r-1 r1]],
        sizegrowth         = 0.8,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
        useairlos          = true,
      },
    },
  },

}

