-- Cinematic volcano effects for BAR Made by Steel December 2025
-- Supports volcano_projectile_unit.lua and game_volcano_pyroclastic.lua
----------------------------------------------------------------------
-- VOLCANO SMOKE INTENSITY CONTROL
-- 1.0 = current heavy-ish plume
-- 0.5 = roughly “moderate”
-- 0.25 = “light”
-- 0.1 = ultra-light
----------------------------------------------------------------------
local VOLCANO_SMOKE_INTENSITY = 1.0  -- << EDIT THIS TO DIAL BACK >>

local function SmokeCount(base)
  -- scale counts for all our micro-emitters
  return math.max(1, math.floor(base * VOLCANO_SMOKE_INTENSITY + 0.5))
end

return {
["volcano_smoke_turbulence"] = {
    turbulence = {
      air      = true,
      ground   = true,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.72,
        colormap           = [[0.07 0.07 0.07 0.65   0.08 0.08 0.08 0.45   0.05 0.05 0.05 0.25   0 0 0 0.01]],
        directional        = false,

        emitrot            = 40,
        emitrotspread      = 60,
        emitvector         = [[0.4 r0.4, 1, 0.4 r0.4]],

        gravity            = [[-0.02 r0.05, 0.2 r0.4, -0.02 r0.05]],

        numparticles       = 6,
        particlelife       = 80,
        particlelifespread = 60,

        particlesize       = 90,
        particlesizespread = 100,

        particlespeed      = 2.0,
        particlespeedspread = 2.5,

        pos                = [[0 r200, 0 r200, 0 r200]],

        sizegrowth         = 1.2,
        sizemod            = 0.97,

        rotParams          = [[-20 r40, -20 r40, -180 r360]],

        -- TEXTURE/ANIM TWEAK
        animParams         = [[8,8,120 r80]],
        texture            = [[smoke-beh-anim]],

        castShadow         = true,
        useairlos          = false,
      },
    },
  },
["volcano_ash_build"] = {
    -- main wide low ash
    ash = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.92,
        colormap           = [[0.08 0.08 0.08 0.8   0.07 0.07 0.07 0.5   0.05 0.05 0.05 0.25   0 0 0 0.01]],
        directional        = false,
        emitrot            = 80,
        emitrotspread      = 30,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.01, 0]],
        -- reduced per-burst particles; micro wisps fill in
        numparticles       = 12,
        particlelife       = 210,
        particlelifespread = 80,
        particlesize       = 80,
        particlesizespread = 40,
        particlespeed      = 1.2,
        particlespeedspread = 0.8,
        pos                = [[-180 r360, 10, -180 r360]],
        sizegrowth         = 0.9,
        sizemod            = 0.97,

        rotParams          = [[-16 r16, -8 r8, -180 r360]],
        -- TEXTURE/ANIM TWEAK
        animParams         = [[8,8,120 r80]],
        texture            = [[smoke-anim]],

        useairlos          = true,
      },
    },

    -- taller, thinner ash above the rim
    ash_high = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.95,
        colormap           = [[0.07 0.07 0.07 0.6   0.06 0.06 0.06 0.35   0.04 0.04 0.04 0.18   0 0 0 0.01]],
        directional        = false,
        emitrot            = 85,
        emitrotspread      = 20,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.005, 0]],
        numparticles       = 8,
        particlelife       = 260,
        particlelifespread = 90,
        particlesize       = 110,
        particlesizespread = 45,
        particlespeed      = 0.7,
        particlespeedspread = 0.4,
        pos                = [[-140 r280, 80, -140 r280]],
        sizegrowth         = 0.7,
        sizemod            = 0.985,

        rotParams          = [[-16 r16, -8 r8, -180 r360]],
        -- TEXTURE/ANIM TWEAK
        animParams         = [[8,8,120 r80]],
        texture            = [[smoke-anim]],

        useairlos          = true,
      },
    },

    ------------------------------------------------------------------
    -- micro “wisps” to break up the pulses
    ------------------------------------------------------------------
    micro = {
      class    = [[CExpGenSpawner]],
      count    = SmokeCount(35),   -- << adjust base 35 for more / less ambient wisps
      properties = {
        delay              = [[0 r90]],  -- random up to 3 seconds per volcano_ash_build CEG
        explosiongenerator = [[custom:volcano_smoke_turbulence]],
        pos                = [[-200 r400, 0 r120, -200 r400]],
      },
    },
  },
["volcano_ash_big"] = {
    column_core = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.90,
        colormap           = [[0.07 0.07 0.07 1.0   0.06 0.06 0.06 0.8   0.05 0.05 0.05 0.45   0 0 0 0.01]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 20,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.015, 0]],
        -- fewer particles per single burst; micro system below handles “fill”
        numparticles       = 18,
        particlelife       = 260,
        particlelifespread = 110,

        -- SHRUNK FROM 150 / 70
        particlesize       = 90,
        particlesizespread = 40,

        particlespeed      = 4.0,
        particlespeedspread = 2.0,
        pos                = [[-80 r160, 40, -80 r160]],
        sizegrowth         = 1.4,
        sizemod            = 0.97,

        rotParams          = [[-16 r16, -8 r8, -180 r360]],
        -- TEXTURE/ANIM TWEAK
        animParams         = [[8,8,120 r80]],
        texture            = [[smoke-beh-anim]],

        useairlos          = true,
      },
    },

    column_sheath = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.93,
        colormap           = [[0.10 0.10 0.10 0.9   0.09 0.09 0.09 0.6   0.07 0.07 0.07 0.3   0 0 0 0.01]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 35,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.01, 0]],
        numparticles       = 16,
        particlelife       = 300,
        particlelifespread = 120,

        -- SHRUNK FROM 220 / 80
        particlesize       = 130,
        particlesizespread = 50,

        particlespeed      = 3.2,
        particlespeedspread = 1.6,
        pos                = [[-140 r280, 80, -140 r280]],
        sizegrowth         = 1.7,
        sizemod            = 0.975,

        rotParams          = [[-16 r16, -8 r8, -180 r360]],
        -- TEXTURE/ANIM TWEAK
        animParams         = [[8,8,120 r80]],
        texture            = [[smoke-beh-anim]],

        useairlos          = true,
      },
    },

    column_cap = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.96,
        colormap           = [[0.09 0.09 0.09 0.7   0.08 0.08 0.08 0.4   0.06 0.06 0.06 0.2   0 0 0 0.01]],
        directional        = false,
        emitrot            = 0,
        emitrotspread      = 20,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.0, 0]],
        numparticles       = 14,
        particlelife       = 320,
        particlelifespread = 130,

        -- SHRUNK FROM 260 / 90
        particlesize       = 160,
        particlesizespread = 55,

        particlespeed      = 2.2,
        particlespeedspread = 1.2,
        pos                = [[-220 r440, 500, -220 r440]],
        sizegrowth         = 1.1,
        sizemod            = 0.985,

        rotParams          = [[-16 r16, -8 r8, -180 r360]],
        -- TEXTURE/ANIM TWEAK
        animParams         = [[8,8,120 r80]],
        texture            = [[smoke-anim]],

        useairlos          = true,
      },
    },

    column_skirt = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.92,
        colormap           = [[0.10 0.10 0.10 0.8   0.09 0.09 0.09 0.5   0.07 0.07 0.07 0.25   0 0 0 0.01]],
        directional        = false,
        emitrot            = 5,
        emitrotspread      = 35,
        emitvector         = [[0.9, 0.4, 0.9]],
        gravity            = [[0, -0.02, 0]],
        numparticles       = 18,
        particlelife       = 180,
        particlelifespread = 80,

        -- SHRUNK FROM 140 / 60
        particlesize       = 85,
        particlesizespread = 36,

        particlespeed      = 8.5,
        particlespeedspread = 3.0,
        pos                = [[-140 r280, 260, -140 r280]],
        sizegrowth         = 1.3,
        sizemod            = 0.98,

        rotParams          = [[-16 r16, -8 r8, -180 r360]],
        -- TEXTURE/ANIM TWEAK
        animParams         = [[8,8,120 r80]],
        texture            = [[smoke-beh-anim]],

        useairlos          = true,
      },
    },

    ------------------------------------------------------------------
    -- random micro turbulence inside the column volume
    ------------------------------------------------------------------
    micro = {
      class    = [[CExpGenSpawner]],
      count    = SmokeCount(35),    -- was 50, slightly less dense
      properties = {
        delay              = [[0 r120]],  -- random up to 4 seconds per volcano_ash_big CEG
        explosiongenerator = [[custom:volcano_smoke_turbulence]],
        pos                = [[-220 r440, 80 r520, -220 r440]],
      },
    },
  },
["volcano_ash_small"] = {
    puff = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.93,
        colormap           = [[0.10 0.10 0.10 0.8   0.07 0.07 0.07 0.5   0 0 0 0.01]],
        directional        = false,
        emitrot            = 80,
        emitrotspread      = 30,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.01, 0]],
        numparticles       = 10,
        particlelife       = 160,
        particlelifespread = 70,
        particlesize       = 90,
        particlesizespread = 35,
        particlespeed      = 2.6,
        particlespeedspread = 1.4,
        pos                = [[-160 r320, 140 r80, -160 r320]],
        sizegrowth         = 1.0,
        sizemod            = 0.98,

        rotParams          = [[-16 r16, -8 r8, -180 r360]],
        -- TEXTURE/ANIM TWEAK
        animParams         = [[8,8,120 r80]],
        texture            = [[smoke-anim]],

        useairlos          = true,
      },
    },

    puff_drift = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.97,
        colormap           = [[0.08 0.08 0.08 0.6   0.06 0.06 0.06 0.35   0.04 0.04 0.04 0.15   0 0 0 0.01]],
        directional        = false,
        emitrot            = 60,
        emitrotspread      = 40,
        emitvector         = [[0.4, 1, 0.4]],
        gravity            = [[0, 0.002, 0]],
        numparticles       = 6,
        particlelife       = 200,
        particlelifespread = 80,
        particlesize       = 120,
        particlesizespread = 40,
        particlespeed      = 1.4,
        particlespeedspread = 0.9,
        pos                = [[-200 r400, 180 r80, -200 r400]],
        sizegrowth         = 0.9,
        sizemod            = 0.99,

        rotParams          = [[-16 r16, -8 r8, -180 r360]],
        -- TEXTURE/ANIM TWEAK
        animParams         = [[8,8,120 r80]],
        texture            = [[smoke-anim]],

        useairlos          = true,
      },
    },

    ------------------------------------------------------------------
    -- micro chaos for side puffs
    ------------------------------------------------------------------
    micro = {
      class    = [[CExpGenSpawner]],
      count    = SmokeCount(18),  -- << adjust base 18 for side puff chaos level
      properties = {
        delay              = [[0 r60]],
        explosiongenerator = [[custom:volcano_smoke_turbulence]],
        pos                = [[-200 r400, 120 r140, -200 r400]],
      },
    },
  },
["volcano_eject"] = {
    flame_core = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.86,
        colormap           = [[1.0 0.85 0.5 1.0   1.0 0.55 0.2 0.7   0.8 0.3 0.1 0.4   0.25 0.08 0.03 0.15   0 0 0 0.01]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 28,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.20, 0]],
        numparticles       = 26,
        particlelife       = 32,
        particlelifespread = 10,
        particlesize       = 140,
        particlesizespread = 60,
        particlespeed      = 20,
        particlespeedspread = 9,
        pos                = [[0, 18, 0]],
        sizegrowth         = -1.6,
        sizemod            = 0.96,
        texture            = [[flame]],
        useairlos          = true,
      },
    },

    eject_smoke = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.93,
        colormap           = [[0.14 0.12 0.11 0.95   0.11 0.10 0.10 0.6   0.08 0.08 0.08 0.28   0 0 0 0.01]],
        directional        = false,
        emitrot            = 75,
        emitrotspread      = 35,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.01, 0]],
        numparticles       = 22,
        particlelife       = 200,
        particlelifespread = 80,
        particlesize       = 120,
        particlesizespread = 50,
        particlespeed      = 4.8,
        particlespeedspread = 2.3,
        pos                = [[0, 26, 0]],
        sizegrowth         = 1.3,
        sizemod            = 0.97,

        rotParams          = [[-16 r16, -8 r8, -180 r360]],
        -- TEXTURE/ANIM TWEAK
        animParams         = [[8,8,120 r80]],
        texture            = [[smoke-beh-anim]],

        useairlos          = true,
      },
    },

    -- Turbulence to roughen ejection smoke
    turbulence = {
      class    = [[CExpGenSpawner]],
      count    = 8,
      properties = {
        delay              = [[0 r40]],
        explosiongenerator = [[custom:volcano_smoke_turbulence]],
        pos                = [[-60 r120, 24 r40, -60 r120]],
      },
    },
  },
["volcano_rock_impact"] = {
    smoke = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.90,
        colormap           = [[0.10 0.10 0.10 1.0   0.09 0.09 0.09 0.65   0 0 0 0.01]],
        directional        = false,
        emitrot            = 70,
        emitrotspread      = 30,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.06, 0]],
        numparticles       = 22,
        particlelife       = 90,
        particlelifespread = 40,
        particlesize       = 90,
        particlesizespread = 40,
        particlespeed      = 6.0,
        particlespeedspread = 2.5,
        pos                = [[0, 12, 0]],
        sizegrowth         = 1.0,
        sizemod            = 0.97,

        rotParams          = [[-16 r16, -8 r8, -180 r360]],
        -- TEXTURE/ANIM TWEAK
        animParams         = [[8,8,120 r80]],
        texture            = [[smoke-anim]],

        useairlos          = true,
      },
    },

    flame = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.88,
        colormap           = [[1.0 0.8 0.3 0.9   0.8 0.4 0.1 0.5   0.3 0.12 0.04 0.15   0 0 0 0.01]],
        directional        = false,
        emitrot            = 80,
        emitrotspread      = 25,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.20, 0]],
        numparticles       = 14,
        particlelife       = 40,
        particlelifespread = 16,
        particlesize       = 80,
        particlesizespread = 30,
        particlespeed      = 10,
        particlespeedspread = 4,
        pos                = [[0, 6, 0]],
        sizegrowth         = -0.7,
        sizemod            = 0.96,
        texture            = [[flame]],
        useairlos          = true,
      },
    },

    dust = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.91,
        colormap           = [[0.15 0.12 0.08 0.6   0.10 0.08 0.06 0.35   0.05 0.04 0.03 0.15   0 0 0 0.01]],
        directional        = false,
        emitrot            = 70,
        emitrotspread      = 40,
        emitvector         = [[0.7, 1, 0.7]],
        gravity            = [[0, -0.04, 0]],
        numparticles       = 20,
        particlelife       = 70,
        particlelifespread = 30,
        particlesize       = 70,
        particlesizespread = 30,
        particlespeed      = 7,
        particlespeedspread = 3,
        pos                = [[0, 6, 0]],
        sizegrowth         = 0.9,
        sizemod            = 0.98,
        texture            = [[smoke]],
        useairlos          = true,
      },
    },

    -- Impact turbulence: adds breakup to the smoke cap
    turbulence = {
      class    = [[CExpGenSpawner]],
      count    = 6,
      properties = {
        delay              = [[0 r20]],
        explosiongenerator = [[custom:volcano_smoke_turbulence]],
        pos                = [[0 r30, 6 r16, 0 r30]],
      },
    },
  },
["volcano_lava_splash_nukexl"] = {
  waterring = {
    air                = true,
    class              = [[CBitmapMuzzleFlame]],
    count              = 1,
    ground             = true,
    underwater         = 1,
    water              = true,
    properties = {
      colormap           = [[1.0 0.75 0.35 0.013   0.85 0.35 0.12 0.01   0.25 0.08 0.03 0.006   0 0 0 0.01]],
      dir                = [[0, 1, 0]],
      --gravity            = [[0.0, 0.1, 0.0]],
      frontoffset        = 0,
      fronttexture       = [[explowater]],
      length             = 45,
      sidetexture        = [[none]],
      size               = 190.9,
      sizegrowth         = 2,
      ttl                = 170,
      pos                = [[0.5, 1, 0.0]],
      alwaysvisible      = true,
    },
  },

  brightflare = {
    air                = true,
    class              = [[CBitmapMuzzleFlame]],
    count              = 1,
    ground             = true,
    underwater         = true,
    water              = true,
    properties = {
      colormap           = [[1.0 0.95 0.75 0.8    1.0 0.45 0.12 0.5    0 0 0 0]],
      dir                = [[0, 1, 0]],
      --gravity            = [[0.0, 0.1, 0.0]],
      frontoffset        = 0,
      fronttexture       = [[exploflare]],
      length             = 40,
      sidetexture        = [[none]],
      size               = 1100,
      sizegrowth         = [[0.1 r0.2]],
      ttl                = 15,
      pos                = [[0, 10, 0]],
    },
  },

  brightwake = {
    air                = true,
    class              = [[CBitmapMuzzleFlame]],
    count              = 1,
    ground             = true,
    underwater         = true,
    water              = true,
    properties = {
      colormap           = [[0 0 0 0    1.0 0.55 0.18 0.4    0.35 0.12 0.05 0.2    0 0 0 0]],
      dir                = [[0, 1, 0]],
      --gravity            = [[0.0, 0.1, 0.0]],
      frontoffset        = 0,
      fronttexture       = [[wake]],
      length             = 40,
      sidetexture        = [[none]],
      size               = [[280 r340]],
      sizegrowth         = [[0.15 r0.7]],
      ttl                = [[90 r70]],
      pos                = [[0, 5, 0]],
      rotParams          = [[-6 r12, -0.5 r1, -180 r360]],
    },
  },

  brightwakefoam = {
    air                = true,
    class              = [[CBitmapMuzzleFlame]],
    count              = 1,
    ground             = true,
    underwater         = true,
    water              = true,
    properties = {
      colormap           = [[0 0 0 0   1.0 0.65 0.25 0.8    0.35 0.14 0.06 0.2    0 0 0 0]],
      dir                = [[0, 1, 0]],
      --gravity            = [[0.0, 0.1, 0.0]],
      frontoffset        = 0,
      fronttexture       = [[waterfoam]],
      length             = 40,
      sidetexture        = [[none]],
      size               = [[400 r120]],
      sizegrowth         = [[0.15 r0.7]],
      ttl                = [[120 r40]],
      pos                = [[0, 5, 0]],
      rotParams          = [[-2 r4, -0.5 r1, -180 r360]],
      alwaysvisible      = true,
    },
  },

  brightwakewave = {
    air                = true,
    class              = [[CBitmapMuzzleFlame]],
    count              = 2,
    ground             = true,
    underwater         = true,
    water              = true,
    properties = {
      colormap           = [[0 0 0 0   0.85 0.35 0.12 0.5    0.30 0.10 0.05 0.2    0 0 0 0]],
      dir                = [[0, 1, 0]],
      --gravity            = [[0.0, 0.1, 0.0]],
      frontoffset        = 0,
      fronttexture       = [[explosionwave]],
      length             = 40,
      sidetexture        = [[none]],
      size               = [[120 r240]],
      sizegrowth         = [[0.15 r0.7]],
      ttl                = [[110 r40]],
      pos                = [[0, 0, 0]],
      alwaysvisible      = true,
    },
  },

  circlewaves = {
    air                = false,
    class              = [[CSimpleParticleSystem]],
    count              = 1,
    ground             = false,
    underwater         = 1,
    water              = true,
    properties = {
      airdrag            = 0.98,
      colormap           = [[0 0 0 0  1.0 0.55 0.18 .013     0.85 0.35 0.12 .008    0.25 0.08 0.03 .006   0 0 0 0.01]],
      directional        = true,
      emitrot            = 90,
      emitrotspread      = 0,
      emitvector         = [[0, 1, 0]],
      gravity            = [[0, 0, 0]],
      numparticles       = 20,
      particlelife       = 80,
      particlelifespread = 110,
      particlesize       = [[12 r27]],
      particlesizespread = 0,
      particlespeed      = [[3.5 i1.9]],
      particlespeedspread = 1.9,
      pos                = [[0 r-10 r10,4, 0 r-10 r10]],
      sizegrowth         = [[0.78]],
      sizemod            = 1.0,
      texture            = [[wave]],
      useairlos          = true,
      alwaysvisible      = true,
    },
  },

  waterrush = {
    air                = false,
    class              = [[CSimpleParticleSystem]],
    count              = 3,
    ground             = false,
    underwater         = 1,
    water              = true,
    properties = {
      airdrag            = 0.97,
      colormap           = [[0 0 0 0.005  0.35 0.12 0.05 .011     0.25 0.08 0.03 .006    0.1 0.03 0.01 .005   0 0 0 0.01]],
      directional        = false,
      emitrot            = 1,
      emitrotspread      = 0,
      emitvector         = [[r0.12, 0.7, r0.12]],
      gravity            = [[0, -0.06, 0]],
      numparticles       = 3,
      particlelife       = 100,
      particlelifespread = 140,
      particlesize       = [[120 r140]],
      particlesizespread = 140,
      particlespeed      = [[25.8 i1]],
      particlespeedspread = 15,
      pos                = [[-130 r260, 110 r60, -130 r260]],
      sizegrowth         = [[0.8]],
      sizemod            = 1,
      texture            = [[waterrush]],
      useairlos          = true,
      alwaysvisible      = true,
    },
  },

  sparks = {
    air                = true,
    class              = [[CSimpleParticleSystem]],
    count              = 1,
    ground             = true,
    water              = true,
    underwater         = true,
    properties = {
      airdrag            = 0.95,
      colormap           = [[1.0 0.65 0.25 0.020   0.85 0.35 0.12 0.01   0 0 0 0.005]],
      directional        = true,
      emitrot            = 12,
      emitrotspread      = 12,
      emitvector         = [[0, 1, 0]],
      gravity            = [[0, 0, 0]],
      numparticles       = 26,
      particlelife       = 90,
      particlelifespread = 65,
      particlesize       = 80,
      particlesizespread = 80,
      particlespeed      = 16.8,
      particlespeedspread = 26,
      pos                = [[0 r-10 r10,-32, 0 r-10 r10]],
      sizegrowth         = -0.25,
      sizemod            = 0.99,
      texture            = [[gunshotxl2]],
      useairlos          = false,
      alwaysvisible      = true,
    },
  },

  waterexplosion = {
    air                = false,
    class              = [[CSimpleParticleSystem]],
    count              = 1,
    ground             = false,
    underwater         = 1,
    water              = true,
    properties = {
      airdrag            = 0.952,
      colormap           = [[1.0 0.75 0.35 0.009   0.85 0.35 0.12 0.013   0.25 0.08 0.03 0.006   0 0 0 0.01]],
      directional        = true,
      emitrot            = 70,
      emitrotspread      = [[-20 r20]],
      emitvector         = [[0,1,0]],
      gravity            = [[0, -0.045, 0]],
      numparticles       = 24,
      particlelife       = 110,
      particlelifespread = 45,
      particlesize       = 60,
      particlesizespread = 150,
      particlespeed      = [[11 i1.95]],
      particlespeedspread = 10,
      rotParams          = [[-50 r100, -7 r14, -180 r360]],
      pos                = [[0, 18, 0]],
      sizegrowth         = -0.21,
      sizemod            = 1.0,
      texture            = [[explowater]],
      useairlos          = true,
      alwaysvisible      = true,
    },
  },

  shockwave = {
    air                = false,
    class              = [[CBitmapMuzzleFlame]],
    count              = 1,
    ground             = true,
    underwater         = true,
    water              = true,
    properties = {
      colormap           = [[1.0 0.65 0.25 0.011   0.85 0.35 0.12 0.01   0.25 0.08 0.03 0.006   0 0 0 0.01]],
      dir                = [[0, 1, 0]],
      --gravity            = [[0.0, 0.1, 0.0]],
      frontoffset        = 0,
      fronttexture       = [[blastwave]],
      length             = 40,
      sidetexture        = [[none]],
      size               = 20,
      sizegrowth         = [[-22 r6]],
      ttl                = 20,
      pos                = [[0, 5, 0]],
      alwaysvisible      = true,
    },
  },

  shockwave_slow = {
    air                = false,
    class              = [[CBitmapMuzzleFlame]],
    count              = 1,
    ground             = true,
    underwater         = true,
    water              = true,
    properties = {
      colormap           = [[1.0 0.65 0.25 0.013   0.85 0.35 0.12 0.008   0.25 0.08 0.03 0.005   0 0 0 0.01]],
      dir                = [[0, 1, 0]],
      --gravity            = [[0.0, 0.1, 0.0]],
      frontoffset        = 0,
      fronttexture       = [[explosionwave]],
      length             = 0,
      sidetexture        = [[none]],
      size               = 50,
      sizegrowth         = [[-18 r5]],
      ttl                = 220,
      pos                = [[0, 0, 0]],
      alwaysvisible      = true,
    },
  },

  dirt = {
    class              = [[CSimpleParticleSystem]],
    count              = 4,
    ground             = true,
    air                = true,
    underwater         = true,
    water              = true,
    properties = {
      airdrag            = 0.97,
      colormap           = [[0.35 0.12 0.05 0.013   0.25 0.08 0.03 0.01   0.1 0.03 0.01 0.006   0 0 0 0.01]],
      directional        = false,
      emitrot            = 30,
      emitrotspread      = 16,
      emitvector         = [[0, 1, 0]],
      gravity            = [[0, -0.12, 0]],
      numparticles       = 7,
      particlelife       = 80,
      particlelifespread = 85,
      particlesize       = 39,
      particlesizespread = 42,
      particlespeed      = 6,
      particlespeedspread = 15,
      rotParams          = [[-50 r100, -7 r14, -180 r360]],
      pos                = [[0, 3, 0]],
      sizegrowth         = -0.08,
      sizemod            = 1,
      texture            = [[randomdots]],
      useairlos          = false,
      alwaysvisible      = true,
    },
  },

  groundflash_white = {
    class              = [[CSimpleGroundFlash]],
    count              = 1,
    air                = false,
    ground             = true,
    water              = true,
    underwater         = true,
    properties = {
      colormap           = [[1.0 0.9 0.7 0.8   1.0 0.45 0.12 0.5   0.25 0.08 0.03 0.2   0 0 0 0.01]],
      size               = 520,
      sizegrowth         = 5,
      ttl                = 220,
      texture            = [[groundflashwhite]],
      alwaysvisible      = true,
    },
  },
},
["volcano1_flames"] = {
    rocks = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 30,
      ground             = true,
      water              = true,
      underwater         = true,
      properties = {
        airdrag            = 0.97,
        alwaysvisible      = true,
        colormap           = [[0.0 0.00 0.0 0.01
                               0.9 0.90 0.0 0.50
                               0.9 0.90 0.0 0.50
                               0.9 0.90 0.0 0.50
                               0.9 0.90 0.0 0.50
                               0.9 0.90 0.0 0.50
                               0.8 0.80 0.1 0.50
                               0.7 0.70 0.2 0.50
                               0.5 0.35 0.0 0.50
                               0.5 0.35 0.0 0.50
                               0.5 0.35 0.0 0.50
                               0.5 0.35 0.0 0.50
                               0.0 0.00 0.0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0.001 r-0.002, 0.0, 0.001 r-0.002]],
        numparticles       = 1,
        particlelife       = 180,
        particlelifespread = 20,
        particlesize       = 120,
        particlesizespread = 120,
        particlespeed      = 24,
        particlespeedspread = 0,
        pos                = [[0, 0, 0]],
        sizegrowth         = 0.05,
        sizemod            = 1.0,
        texture            = [[fireball]],
      },
    },
  },
["volcano_rising_fireball_spawner"] = {
    nw = {
      air                = true,
      class              = [[CExpGenSpawner]],
      count              = 150,
      ground             = true,
      water              = true,
      underwater         = true,
      properties = {
        delay              = [[0  i1]],
        explosiongenerator = [[custom:volcano_rising_fireball_sub]],
        pos                = [[20 r40, i20, -20 r40]],
      },
    },
  },
["volcano_rising_fireball_sub"] = {
    rocks = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater         = true,
      properties = {
        airdrag            = 0.97,
        alwaysvisible      = true,
        colormap           = [[
			     0.9  0.45 0.15 0.75
			     0.4  0.2  0.08 0.65
			     0.12 0.1  0.1  0.6
			     0.08 0.08 0.08 0.5
			     0.05 0.05 0.05 0.35
			     0.02 0.02 0.02 0.18
			     0.0  0.0  0.0  0.0
			     ]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 10,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0.001 r-0.002, 0.01 r-0.02, 0.001 r-0.002]],
        numparticles       = 1,
        particlelife       = 150,
        particlelifespread = 150,
        particlesize       = 90,
        particlesizespread = 90,
        particlespeed      =  3,
        particlespeedspread = 5,
        pos                = [[0, 0, 0]],
        sizegrowth         = 0.05,
        sizemod            = 1.0,
        texture            = [[fireball]],
      },
    },
  },

  ----------------------------------------------------------------------
  -- LAVA ROCK TRAIL – EXTREME STREAKING FIREBALL
  ----------------------------------------------------------------------
  ["volcano_rock_trail"] = {
    trail_flame = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.85,
        colormap           = [[1.0 0.8 0.4 1.0   1.0 0.45 0.12 0.7   0.7 0.2 0.06 0.4   0.25 0.08 0.03 0.12   0 0 0 0.01]],
        directional        = false,
        emitrot            = 0,
        emitrotspread      = 20,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.30, 0]],
        numparticles       = 6,
        particlelife       = 40,
        particlelifespread = 14,
        particlesize       = 25,
        particlesizespread = 12,
        particlespeed      = 2.2,
        particlespeedspread = 1.3,
        pos                = [[0, 0, 0]],
        sizegrowth         = -0.5,
        sizemod            = 0.96,
        texture            = [[flame]],
        useairlos          = true,
      },
    },

    trail_smoke = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.93,
        colormap           = [[0.08 0.07 0.07 0.95   0.09 0.09 0.09 0.7   0.07 0.07 0.07 0.4   0 0 0 0.01]],
        directional        = false,
        emitrot            = 10,
        emitrotspread      = 30,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.08, 0]],
        numparticles       = 5,
        particlelife       = 80,
        particlelifespread = 30,
        particlesize       = 30,
        particlesizespread = 12,
        particlespeed      = 1.0,
        particlespeedspread = 0.7,
        pos                = [[0, -2, 0]],
        sizegrowth         = 0.9,
        sizemod            = 0.98,

        rotParams          = [[-16 r16, -8 r8, -180 r360]],
        -- TEXTURE/ANIM TWEAK
        animParams         = [[8,8,120 r80]],
        texture            = [[smoke-anim]],

        useairlos          = true,
      },
    },

    sparks = {
      air      = true,
      ground   = true,
      water    = false,
      class    = [[CSimpleParticleSystem]],
      count    = 1,
      properties = {
        airdrag            = 0.86,
        colormap           = [[1.0 0.9 0.6 0.9   1.0 0.6 0.25 0.6   0.8 0.35 0.1 0.3   0 0 0 0.01]],
        directional        = false,
        emitrot            = 0,
        emitrotspread      = 45,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.35, 0]],
        numparticles       = 7,
        particlelife       = 22,
        particlelifespread = 8,
        particlesize       = 6,
        particlesizespread = 3,
        particlespeed      = 4.5,
        particlespeedspread = 2.5,
        pos                = [[0, 0, 0]],
        sizegrowth         = -0.7,
        sizemod            = 0.97,
        texture            = [[flame]],
        useairlos          = true,
      },
    },

    -- Small turbulence added to the trailing smoke
    turbulence = {
      class    = [[CExpGenSpawner]],
      count    = 6,
      properties = {
        delay              = [[0 r30]],
        explosiongenerator = [[custom:volcano_smoke_turbulence]],
        pos                = [[0 r12, -4 r8, 0 r12]],
      },
    },
  },

  ----------------------------------------------------------------------
  -- FIREBALL IMPACT EFFECT (EXTREME COMET IMPACT)
  ----------------------------------------------------------------------
  ["volcano_fireball_impact"] = {
    impact_smoke = {
      class  = [[CSimpleParticleSystem]],
      count  = 1,
      ground = true,
      air    = true,
      water  = false,
      properties = {
        airdrag            = 0.90,
        colormap           = [[0.1 0.1 0.1 1   0.09 0.09 0.09 0.6   0 0 0 0.01]],
        emitrot            = 80,
        emitrotspread      = 45,
        emitvector         = [[0,1,0]],
        gravity            = [[0,-0.05,0]],
        numparticles       = 20,
        particlelife       = 80,
        particlelifespread = 35,
        particlesize       = 120,
        particlesizespread = 60,
        particlespeed      = 6,
        particlespeedspread = 3,
        pos                = [[0,5,0]],
        sizegrowth         = 1.0,
        sizemod            = 0.97,

        rotParams          = [[-16 r16, -8 r8, -180 r360]],
        -- TEXTURE/ANIM TWEAK
        animParams         = [[8,8,120 r80]],
        texture            = [[smoke-beh-anim]],

        useairlos          = true,
      },
    },

    impact_flame = {
      class  = [[CSimpleParticleSystem]],
      count  = 1,
      air    = true,
      ground = true,
      water  = false,
      properties = {
        airdrag            = 0.90,
        colormap           = [[1 0.8 0.3 1   1 0.3 0.1 0.5   0.3 0.1 0.05 0.2   0 0 0 0.01]],
        emitrot            = 90,
        emitrotspread      = 25,
        emitvector         = [[0,1,0]],
        gravity            = [[0,-0.2,0]],
        numparticles       = 14,
        particlelife       = 30,
        particlelifespread = 12,
        particlesize       = 90,
        particlesizespread = 50,
        particlespeed      = 8,
        particlespeedspread = 3,
        pos                = [[0,3,0]],
        sizegrowth         = -1.4,
        sizemod            = 0.96,
        texture            = [[flame]],
        useairlos          = true,
      },
    },

    -- Extra churn in the impact smoke
    turbulence = {
      class    = [[CExpGenSpawner]],
      count    = 8,
      properties = {
        delay              = [[0 r25]],
        explosiongenerator = [[custom:volcano_smoke_turbulence]],
        pos                = [[0 r40, 4 r20, 0 r40]],
      },
    },
  },

}
