-- teleport_beam

return {
  ["teleport_beam"] = {
    usedefaultexplosions = true,
     GlowSpawner = {
      air                = true,
      class              = [[CExpGenSpawner]],
      count              = 13,
      ground             = true,
      water              = false,
      properties = {
        delay              = [[0 i4]],
        explosiongenerator = [[custom:Glow2]],
        pos                = [[0, 0, 0]],
      },
    },
  },
    ["Glow2"] = {
       glow = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 2,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 1,
        colormap           = [[0.55 0.6 0.9 0.008    0.55 0.7 1 0.008              0 0 0 0.01]],
        directional        = true,
        emitrot            = 0,
        emitrotspread      = 0,
        emitvector         = [[0, 0, 0]],
        gravity            = [[0, 0.00, 0]],
        numparticles       = 1,
        particlelife       = 11,
        particlelifespread = 0,
        particlesize       = 50,
        particlesizespread = 10,
        particlespeed      = 1,
        particlespeedspread = 0,
        pos                = [[0, 2, 0]],
        sizegrowth         = 35.0,
        sizemod            = 1.0,
        texture            = [[flare1]],
      },
    },
  },
}

