return {
  ["armada_ion"] = {

    -- white-hot core
    core = {
      air = true, ground = true, water = true, underwater = 1,
      class = [[CBitmapMuzzleFlame]], count = 1,
      properties = {
        colormap     = [[1 1 1 1   0.85 1 1 0.95   0.5 0.95 1 0.55   0 0 0 0.01]],
        dir          = [[dir]],
        frontoffset  = 0,
        fronttexture = [[none]],
        sidetexture  = [[gunshotxl2]],
        length       = 1,
        size         = 8,
        sizegrowth   = 0,
        ttl          = 4,
        pos          = [[0, 0, 0]],
      },
    },

    -- cyan inner glow
    inner = {
      air = true, ground = true, water = true, underwater = 1,
      class = [[CBitmapMuzzleFlame]], count = 1,
      properties = {
        colormap     = [[0.4 0.95 1 0.75   0.25 0.7 1 0.45   0.1 0.35 0.9 0.12   0 0 0 0.01]],
        dir          = [[dir]],
        frontoffset  = 0,
        fronttexture = [[none]],
        sidetexture  = [[gunshotxl2]],
        length       = 1,
        size         = 28,
        sizegrowth   = 0,
        ttl          = 4,
        pos          = [[0, 0, 0]],
      },
    },

    -- blue outer haze
    outer = {
      air = true, ground = true, water = true, underwater = 1,
      class = [[CBitmapMuzzleFlame]], count = 1,
      properties = {
        colormap     = [[0.15 0.5 1 0.3   0.05 0.2 0.8 0.08   0 0 0 0.01]],
        dir          = [[dir]],
        frontoffset  = 0,
        fronttexture = [[none]],
        sidetexture  = [[gunshotxl2]],
        length       = 1,
        size         = 55,
        sizegrowth   = 0,
        ttl          = 4,
        pos          = [[0, 0, 0]],
      },
    },

    -- energy discharge sparks at beam source
    sparks = {
      air = true, ground = true, water = true, underwater = 1,
      class = [[CSimpleParticleSystem]], count = 1,
      properties = {
        colormap           = [[0.8 1 1 0.9   0.4 0.8 1 0.45   0 0 0 0]],
        directional        = false,
        emitrot            = 75,
        emitrotspread      = 15,
        gravity            = [[0, 0, 0]],
        numparticles       = 3,
        particlelife       = 8,
        particlelifespread = 4,
        particlesize       = 5,
        particlesizespread = 3,
        pos                = [[0, 0, 0]],
        texture            = [[flare2]],
      },
    },

  },
}