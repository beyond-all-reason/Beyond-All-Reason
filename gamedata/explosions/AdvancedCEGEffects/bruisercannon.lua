-- bruisercannon

return {
  ["bruisercannon"] = {
    pop2 = {
      air                = true,
      class              = [[heatcloud]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 1.3,
        maxheat            = 15,
        pos                = [[0, 0, 0]],
        size               = 20,
        sizegrowth         = -0.5,
        speed              = [[0, 0, 0]],
        texture            = [[flare]],
      },
    },
    searingflame2 = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 1,
        colormap           = [[1 0.2 0.1 0.01	1 0.5 0.1 0.01	0 0 0 0.01]],
        emitrot            = 0,
        emitrotspread      = 0,
        emitvector         = [[dir]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = 1,
        particlelifespread = 5,
        particlesize       = 10,
        particlesizespread = 0,
        particlespeed      = 0,
        particlespeedspread = 0,
        pos                = [[1 r3, 1 r3, 1 r3]],
        sizegrowth         = 0,
        sizemod            = 1,
        texture            = [[starexplobw]],
        useairlos          = true,
      },
    },
  },

}

