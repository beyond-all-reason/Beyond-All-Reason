-- jetflash

return {
  ["jetflash"] = {
    bitmapmuzzleflame = {
      air                = true,
      class              = [[CBitmapMuzzleFlame]],
      count              = 1,
      ground             = true,
      underwater         = 1,
      water              = true,
      properties = {
        colormap           = [[0.9 0.8 0.7 0.01 0.9 0.5 0.2 0.01  0 0 0 0.01]],
        dir                = [[dir]],
        frontoffset        = 0.05,
        fronttexture       = [[empty]],
        length             = 15,
        sidetexture        = [[shot]],
        size               = 7,
        sizegrowth         = 1,
        ttl                = 2,
      },
    },
    redpuff = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      underwater         = 1,
      water              = true,
      properties = {
        airdrag            = 1,
        colormap           = [[1 0.6 0 0.01 0.9 0.8 0.7 0.01  0 0 0 0.01]],
        directional        = true,
        emitrot            = 1,
        emitrotspread      = 5,
        emitvector         = [[dir]],
        gravity            = [[0.0, 0, .0]],
        numparticles       = 3,
        particlelife       = 1,
        particlelifespread = 2,
        particlesize       = 1,
        particlesizespread = 3,
        particlespeed      = 0,
        particlespeedspread = 3,
        pos                = [[0.0, 1, 0.0]],
        sizegrowth         = 0.9,
        sizemod            = 1,
        texture            = [[dirt]],
        useairlos          = true,
      },
    },
  },

}

