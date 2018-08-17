-- watersplash_small

return {
  ["com_sea_laser_bubbles"] = {
    waterball = {
      air                = false,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = false,
      underwater         = 1,
      water              = true,
      properties = {
        airdrag            = 1,
        colormap           = [[0 0 0 0  0.4 0.8 1 .1     0.6 .9 0.95 .4  	0 0 0 0.01]],
        directional        = true,
        emitrot            = 15,
        emitrotspread      = [[0 r-30 r30]],
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = 4,
        particlelifespread = 15,
        particlesize       = 1,
        particlesizespread = 2,
        particlespeed      = [[0 r3 i-0.05]],
        particlespeedspread = 2,
        pos                = [[0 r-5 r5, 3 r8, 0 r-5 r5]],
        sizegrowth         = [[0 0 0]],
        sizemod            = 1.0,
        texture            = [[dirt]],
        useairlos          = true,
      },
    },
  },
}

