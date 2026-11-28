-- Disclaimer: AI generated + human edited.

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

  ["legion_grav_distort"] = {

    -- horizontal gravitational shockwave ring (looks upward facing)
    ring = {
      air = true, ground = true, water = true, underwater = 1,
      class = [[CBitmapMuzzleFlame]], count = 1,
      properties = {
        colormap     = [[0.1 1 0.3 0.85   0.05 0.6 0.15 0.45   0 0 0 0.01]],
        dir          = [[dir]],
        frontoffset  = 0,
        fronttexture = [[explosionwave]],
        sidetexture  = [[explosionwave]],
        length       = 0.2,
        size         = 5,
        sizegrowth   = 5,
        ttl          = 4,
        pos          = [[0, 0, 0]],
      },
    },

    -- brief bright pulse when lift engages
    pulse = {
      air = true, ground = true, water = true, underwater = 1,
      class = [[CHeatCloudProjectile]], count = 0,
      properties = {
        heat    = 3,
        maxheat = 5,
        pos     = [[0, 0, 0]],
        size    = 16,
        speed   = 0.025,
        texture = [[flare]],
      },
    },

  },

  ["tractorbeam_weak"] = {

    -- red lock column; CBitmapMuzzleFlame size scales with dir magnitude
    beam_core = {
      air = true, ground = true, water = true, underwater = 1,
      class = [[CBitmapMuzzleFlame]], count = 1,
      properties = {
        colormap     = [[1 0.15 0.1 0.9   0.75 0.05 0.05 0.55   0.35 0.0 0.0 0.12   0 0 0 0.01]],
        dir          = [[dir]],
        frontoffset  = 0,
        fronttexture = [[none]],
        sidetexture  = [[gunshotxl2]],
        length       = 1,
        size         = 6,
        sizegrowth   = 0,
        ttl          = 5,
        pos          = [[0, 0, 0]],
      },
    },

    -- alarm ring: flat disc grows outward, cylinder body climbs upward toward transport
    alert_ring = {
      air = true, ground = true, water = true, underwater = 1,
      class = [[CBitmapMuzzleFlame]], count = 1,
      properties = {
        colormap     = [[1 0.85 0.1 0.9   0.9 0.55 0.05 0.5   0.4 0.2 0.0 0.1   0 0 0 0.01]],
        dir          = [[dir]],
        frontoffset  = 0,
        fronttexture = [[explosionwave]],
        sidetexture  = [[gunshotxl2]],
        length       = 0.125,
        size         = 2,
        sizegrowth   = 8,
        ttl          = 5,
        pos          = [[0, 0, 0]],
      },
    },

    -- erratic white/yellow sparks in all directions: system interference
    interference = {
      air = true, ground = true, water = true, underwater = 1,
      class = [[CSimpleParticleSystem]], count = 1,
      properties = {
        colormap           = [[1 1 0.6 1   0.9 1 0.3 0.7   1 1 1 0.4   0 0 0 0]],
        directional        = false,
        emitrot            = 180,
        emitrotspread      = 180,
        gravity            = [[0, 0.05, 0]],
        numparticles       = 5,
        particlelife       = 6,
        particlelifespread = 4,
        particlesize       = 3,
        particlesizespread = 2,
        particlespeed      = 2.5,
        particlespeedspread = 2.0,
        pos                = [[0, 0, 0]],
        sizegrowth         = -0.2,
        sizemod            = 1,
        texture            = [[flare2]],
      },
    },

    -- hot orange alert pulse on each spawn tick
    warning_flash = {
      air = true, ground = true, water = true, underwater = 1,
      class = [[CHeatCloudProjectile]], count = 0,
      properties = {
        heat    = 5,
        maxheat = 7,
        pos     = [[0, 0, 0]],
        size    = 22,
        speed   = 0.03,
        texture = [[flare]],
      },
    },

  },
}
