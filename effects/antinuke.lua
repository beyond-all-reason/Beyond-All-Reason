-- missileburn
-- electricburn
-- burn
-- burnold
-- burnblack
-- burngreen

return {
  ["antinuke"] = {
    explosion = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater         = true,
      properties = {
        airdrag            = 0.82,
        colormap           = [[0 0 0 0   1 0.9 0.6 0.09   0.9 0.5 0.2 0.066   0.66 0.28 0.04 0.033   0 0 0 0]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1.1, 0]],
        gravity            = [[0, -0.01, 0]],
        numparticles       = 60,
        particlelife       = 1,
        particlelifespread = 17,
        particlesize       = 3.3,
        particlesizespread = 12,
        particlespeed      = 0.4,
        particlespeedspread = 3.8,
        pos                = [[0, 2, 0]],
        sizegrowth         = 0.3,
        sizemod            = 1,
        texture            = [[flashside3]],
        useairlos          = true,
      },
    },
    outerflash = {
      air                = true,
      class              = [[CHeatCloudProjectile]],
      count              = 2,
      ground             = true,
      water              = true,
      underwater         = true,
      properties = {
        heat               = 14,
        heatfalloff        = 1.3,
        maxheat            = 40,
        pos                = [[r-2 r2, 4, r-2 r2]],
        size               = 15,
        sizegrowth         = 1.2,
        speed              = [[0, 1 0, 0]],
        texture            = [[orangenovaexplo]],
        useairlos          = true,
      },
    },
  },

}

