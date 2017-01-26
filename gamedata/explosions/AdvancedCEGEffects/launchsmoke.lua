-- launchsmoke

return {
  ["launchsmoke"] = {
    groundflash = {
      air                = true,
      alwaysvisible      = true,
      circlealpha        = 0.2,
      circlegrowth       = 6,
      flashalpha         = 0.3,
      flashsize          = 100,
      ground             = true,
      ttl                = 13,
      water              = true,
      color = {
        [1]  = 1,
        [2]  = 1,
        [3]  = 1,
      },
    },
    poof01 = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.95,
        alwaysvisible      = true,
        colormap           = [[0.1 0.1 0.1 1.0	0.5 0.4 0.3 1.0		0 0 0 0.0]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0, 0]],
        numparticles       = 22,
        particlelife       = 3,
        particlelifespread = 3,
        particlesize       = 5,
        particlesizespread = 5,
        particlespeed      = 1,
        particlespeedspread = 10,
        pos                = [[r-1 r1, 1, r-1 r1]],
        sizegrowth         = 1.2,
        sizemod            = 1.0,
        texture            = [[dirt]],
        useairlos          = true,
      },
    },
  },

}

