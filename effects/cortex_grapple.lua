return {
  ["cortex_grapple"] = {

    cable = {
      air = true, ground = true, water = true, underwater = 1,
      class = [[CBitmapMuzzleFlame]], count = 1,
      properties = {
        colormap     = [[0.85 0.88 0.9 1   0.55 0.58 0.62 0.8   0.2 0.22 0.25 0.2   0 0 0 0.01]],
        dir          = [[dir]],
        frontoffset  = 0,
        fronttexture = [[none]],
        sidetexture  = [[gunshotxl2]],
        length       = 1,
        size         = 8,
        sizegrowth   = 0,
        ttl          = 3,
        pos          = [[0, 0, 0]],
      },
    },

    smoke = {
      air = true, ground = true, water = true, underwater = 1,
      class = [[CSimpleParticleSystem]], count = 1,
      properties = {
        colormap           = [[0.28 0.3 0.32 0.6   0.18 0.2 0.22 0.4   0.08 0.09 0.1 0.15   0 0 0 0]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 15,
        emitvector         = [[0, 1, 0]],
        gravity            = [[-0.02 r0.04, 0.3 r0.2, -0.02 r0.04]],
        numparticles       = 2,
        particlelife       = 8,
        particlelifespread = 4,
        particlesize       = 8,
        particlesizespread = 4,
        particlespeed      = 0.6,
        particlespeedspread = 0.4,
        pos                = [[0, 0, 0]],
        sizegrowth         = 0.15,
        sizemod            = 1,
        texture            = [[smoke-anim]],
        animParams         = [[8, 6, 60 r40]],
        rotParams          = [[-8 r16, -4 r8, -180 r360]],
        useairlos          = false,
      },
    },

    flash = {
      air = true, ground = true, water = true, underwater = 1,
      class = [[CHeatCloudProjectile]], count = 0,
      properties = {
        heat    = 3,
        maxheat = 4,
        pos     = [[0, 0, 0]],
        size    = 8,
        speed   = 0.01,
        texture = [[flare]],
      },
    },
  },
}