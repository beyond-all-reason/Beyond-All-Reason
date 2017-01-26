-- lvl1m

return {
  ["lvl1m"] = {
    dirtw03 = {
      class              = [[dirt]],
      count              = 5,
      water              = true,
      properties = {
        alphafalloff       = 2,
        color              = [[0.7, 0.7, 1.0]],
        pos                = [[r-5 r5, 0, r-5 r5]],
        size               = 7,
        speed              = [[r1.5 r-1.5, 1.7, r1.5 r-1.5]],
      },
    },
    pillar = {
      air                = true,
      class              = [[heatcloud]],
      count              = 3,
      properties = {
        alwaysvisible      = true,
        heat               = 15,
        heatfalloff        = 2.5,
        maxheat            = 15,
        pos                = [[0,1, 0]],
        size               = 20,
        sizegrowth         = -1,
        speed              = [[0, 0, 0]],
        texture            = [[flare]],
      },
    },
    poof01 = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.8,
        alwaysvisible      = true,
        colormap           = [[0.7 0.6 0.3 0.01  0 0 0 0.01]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[dir]],
        gravity            = [[0, 0, 0]],
        numparticles       = 8,
        particlelife       = 10,
        particlelifespread = 5,
        particlesize       = 2,
        particlesizespread = 0,
        particlespeed      = 2,
        particlespeedspread = 5,
        pos                = [[0, 2, 0]],
        sizegrowth         = 1,
        sizemod            = 1.1,
        texture            = [[flashside1]],
        useairlos          = false,
      },
    },
    smoke = {
      air                = true,
      count              = 2,
      ground             = true,
      properties = {
        agespeed           = 0.15,
        alwaysvisible      = true,
        color              = 0.3,
        pos                = [[0,-1 i4,0]],
        size               = 10,
        sizegrowth         = 0,
        speed              = [[0, 5, 0]],
      },
    },
  },

}

