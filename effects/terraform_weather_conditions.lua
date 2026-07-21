-- Weather Conditions CEGs
-- Custom particle effects designed for the Weather Brush system.
-- Each CEG is tuned for 3D layering: altitude offsets in pos, directional
-- gravity for realistic fall/drift, and colormaps that read well at
-- typical RTS camera distances.

return {

  -- =========================================================================
  -- SNOW
  -- =========================================================================

  -- Gentle snowflake cluster drifting down from 300-600 elmos above ground.
  -- Uses cloudpuff for soft round flakes, slight lateral wobble from gravity,
  -- airdrag 0.97 bleeds speed so flakes decelerate into a lazy drift.
  ["weather_snowflake"] = {
    usedefaultexplosions = false,
    flakes = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater         = false,
      properties = {
        airdrag            = 0.97,
        colormap           = [[0 0 0 0.0   0.82 0.84 0.9 0.04   0.9 0.92 0.97 0.06   0.82 0.84 0.9 0.04   0 0 0 0.0]],
        directional        = false,
        emitrot            = 170,
        emitrotspread      = 20,
        emitvector         = [[0, 1, 0]],
        gravity            = [[-0.012 r0.024, -0.06, -0.008 r0.016]],
        numparticles       = 3,
        particlelife       = 90,
        particlelifespread = 130,
        particlesize       = 4,
        particlesizespread = 9,
        particlespeed      = 2.0,
        particlespeedspread = 2.5,
        pos                = [[-60 r120, 300 r300, -60 r120]],
        rotParams          = [[-6 r12, -2 r4, -180 r360]],
        sizegrowth         = -0.01,
        sizemod            = 1,
        texture            = [[cloudpuff]],
        alwaysvisible      = true,
      },
    },
  },

  -- Dense snowfall with blowing drift at lower altitude.
  -- Two layers: falling flakes from high up + wind-blown cloud banks lower.
  ["weather_snowfall_heavy"] = {
    usedefaultexplosions = false,
    flakes = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater         = false,
      properties = {
        airdrag            = 0.96,
        colormap           = [[0 0 0 0.0   0.78 0.8 0.86 0.05   0.88 0.9 0.96 0.08   0.75 0.78 0.84 0.05   0 0 0 0.0]],
        directional        = false,
        emitrot            = 160,
        emitrotspread      = 30,
        emitvector         = [[0, 1, 0]],
        gravity            = [[-0.025 r0.05, -0.1, -0.015 r0.03]],
        numparticles       = 5,
        particlelife       = 60,
        particlelifespread = 110,
        particlesize       = 5,
        particlesizespread = 12,
        particlespeed      = 3.0,
        particlespeedspread = 3.5,
        pos                = [[-80 r160, 250 r350, -80 r160]],
        rotParams          = [[-10 r20, -3 r6, -180 r360]],
        sizegrowth         = -0.02,
        sizemod            = 1,
        texture            = [[cloudpuff]],
        alwaysvisible      = true,
      },
    },
    -- Wind-driven snow banks at 20-80 above ground
    drift = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater         = false,
      properties = {
        airdrag            = 0.98,
        colormap           = [[0 0 0 0.0   0.7 0.72 0.78 0.02   0.8 0.82 0.88 0.03   0 0 0 0.0]],
        directional        = false,
        emitrot            = 30,
        emitrotspread      = 30,
        emitvector         = [[0.5, 0.3, 0.2]],
        gravity            = [[-0.01 r0.02, -0.015, -0.005 r0.01]],
        numparticles       = 1,
        particlelife       = 100,
        particlelifespread = 80,
        particlesize       = 40,
        particlesizespread = 70,
        particlespeed      = 5,
        particlespeedspread = 3,
        pos                = [[-30 r60, 20 r60, -30 r60]],
        rotParams          = [[-3 r6, -1 r2, -180 r360]],
        sizegrowth         = [[0.15 r0.1]],
        sizemod            = 1,
        texture            = [[cloudpuff]],
        alwaysvisible      = true,
      },
    },
  },

  -- =========================================================================
  -- HAIL
  -- =========================================================================

  -- Fast, bright white particles plummeting from 400-600 above ground.
  -- directional=true elongates sprites along velocity for streak effect.
  -- No airdrag (1.0) so they accelerate under gravity to terminal speed.
  ["weather_hailstone"] = {
    usedefaultexplosions = false,
    stones = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater         = false,
      properties = {
        airdrag            = 1.0,
        colormap           = [[0 0 0 0.0   0.88 0.9 0.95 0.07   1.0 1.0 1.0 0.12   0.8 0.82 0.88 0.04   0 0 0 0.0]],
        directional        = true,
        emitrot            = 175,
        emitrotspread      = 10,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.35, 0]],
        numparticles       = 4,
        particlelife       = 22,
        particlelifespread = 30,
        particlesize       = 2,
        particlesizespread = 4,
        particlespeed      = 12,
        particlespeedspread = 8,
        pos                = [[-50 r100, 400 r200, -50 r100]],
        sizegrowth         = 0,
        sizemod            = 1,
        texture            = [[flare1]],
        alwaysvisible      = true,
      },
    },
  },

  -- =========================================================================
  -- ASH
  -- =========================================================================

  -- Dark particles descending slowly from 200-500 above ground.
  -- Uses dirtpuff for an ashy/dusty visual. Low alpha for semi-transparent
  -- drift. Lateral gravity wobble for organic fluttering.
  ["weather_ashfall"] = {
    usedefaultexplosions = false,
    ash = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater         = false,
      properties = {
        airdrag            = 0.96,
        colormap           = [[0 0 0 0.0   0.05 0.05 0.05 0.03   0.09 0.08 0.07 0.06   0.06 0.05 0.04 0.04   0 0 0 0.0]],
        directional        = false,
        emitrot            = 150,
        emitrotspread      = 40,
        emitvector         = [[0, 1, 0]],
        gravity            = [[-0.015 r0.03, -0.035, -0.01 r0.02]],
        numparticles       = 3,
        particlelife       = 100,
        particlelifespread = 160,
        particlesize       = 6,
        particlesizespread = 18,
        particlespeed      = 1.2,
        particlespeedspread = 1.8,
        pos                = [[-70 r140, 200 r300, -70 r140]],
        rotParams          = [[-5 r10, -2 r4, -180 r360]],
        sizegrowth         = [[0.08 r0.04]],
        sizemod            = 1,
        texture            = [[dirtpuff]],
        alwaysvisible      = true,
      },
    },
  },

  -- =========================================================================
  -- POLLEN / SPORES
  -- =========================================================================

  -- Tiny yellow-green specks floating lazily on warm air currents.
  -- Almost no directed movement; random 3D emission with slight updraft.
  -- flare1 texture gives a soft warm glow at small sizes.
  ["weather_pollen"] = {
    usedefaultexplosions = false,
    speck = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = false,
      underwater         = false,
      properties = {
        airdrag            = 0.94,
        colormap           = [[0 0 0 0.01   0.55 0.62 0.18 0.02   0.72 0.8 0.28 0.035   0.48 0.55 0.14 0.015   0 0 0 0.01]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 180,
        emitvector         = [[1, 1, 1]],
        gravity            = [[0, 0.005, 0]],
        numparticles       = 2,
        particlelife       = 60,
        particlelifespread = 120,
        particlesize       = 1.5,
        particlesizespread = 3.5,
        particlespeed      = 0.25,
        particlespeedspread = 0.45,
        pos                = [[-15 r30, 5 r40, -15 r30]],
        sizegrowth         = -0.008,
        sizemod            = 1,
        texture            = [[flare1]],
        alwaysvisible      = true,
      },
    },
  },

  -- =========================================================================
  -- EMBERS
  -- =========================================================================

  -- Glowing orange/red sparks rising from the ground.
  -- Positive Y gravity lifts them. Colormap shifts from bright orange
  -- through red to dark ember glow before vanishing.
  ["weather_embers"] = {
    usedefaultexplosions = false,
    ember = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = false,
      underwater         = false,
      properties = {
        airdrag            = 0.95,
        colormap           = [[0 0 0 0.01   0.95 0.55 0.12 0.04   1.0 0.4 0.06 0.06   0.7 0.18 0.03 0.03   0.2 0.05 0.01 0.012   0 0 0 0.01]],
        directional        = false,
        emitrot            = 12,
        emitrotspread      = 22,
        emitvector         = [[0, 1, 0]],
        gravity            = [[-0.015 r0.03, 0.04, -0.01 r0.02]],
        numparticles       = 2,
        particlelife       = 45,
        particlelifespread = 85,
        particlesize       = 2,
        particlesizespread = 5,
        particlespeed      = 0.8,
        particlespeedspread = 1.2,
        pos                = [[-20 r40, 2 r12, -20 r40]],
        rotParams          = [[-4 r8, -1.5 r3, -180 r360]],
        sizegrowth         = -0.015,
        sizemod            = 1,
        texture            = [[flare1]],
        alwaysvisible      = true,
      },
    },
  },

  -- =========================================================================
  -- DRIZZLE MIST
  -- =========================================================================

  -- Fine rain haze occupying the mid-altitude band (50-200 above ground).
  -- Designed as a layering companion for raindrop—fills the gap between
  -- the falling streaks above and ground splashes below.
  ["weather_drizzle_mist"] = {
    usedefaultexplosions = false,
    mist = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater         = false,
      properties = {
        airdrag            = 0.99,
        colormap           = [[0 0 0 0.0   0.11 0.11 0.13 0.015   0.14 0.14 0.16 0.025   0.09 0.09 0.11 0.012   0 0 0 0.0]],
        directional        = false,
        emitrot            = 60,
        emitrotspread      = 40,
        emitvector         = [[0.1, -0.4, 0.05]],
        gravity            = [[-0.004 r0.008, -0.012, -0.003 r0.006]],
        numparticles       = 2,
        particlelife       = 120,
        particlelifespread = 100,
        particlesize       = 50,
        particlesizespread = 100,
        particlespeed      = 2,
        particlespeedspread = 2,
        pos                = [[-40 r80, 50 r150, -40 r80]],
        rotParams          = [[-2 r4, -0.5 r1, -180 r360]],
        sizegrowth         = [[0.12 r0.08]],
        sizemod            = 1,
        texture            = [[cloudpuff]],
        alwaysvisible      = true,
      },
    },
  },
}
