-- lightning_stormbolt

return {
  ["lightning_stormbolt"] = {
    groundflash = {
      circlealpha        = 1,
      circlegrowth       = 0,
      flashalpha         = 0.12,
      flashsize          = 40,
      ttl                = 3,
      color = {
        [1]  = 0.66,
        [2]  = 0.66,
        [3]  = 1,
      },
    },
    lightningballs = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater		 = true,
      properties = {
        airdrag            = 1,
        colormap           = [[0 0 0 0.01 1 1 1 0.01 0 0 0 0.01]],
        directional        = true,
        emitrot            = 80,
        emitrotspread      = 0,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = 3,
        particlelifespread = 0,
        particlesize       = 1.8,
        particlesizespread = 7.5,
        particlespeed      = 0.01,
        particlespeedspread = 0,
        pos                = [[-10 r10, 1.0, -10 r10]],
        sizegrowth         = 0,
        sizemod            = 1.0,
        texture            = [[lightbw]],
      },
    },
  },
  ["lightning_stormbolt_small"] = {
    groundflash = {
      circlealpha        = 1,
      circlegrowth       = 0,
      flashalpha         = 0.08,
      flashsize          = 25,
      ttl                = 2,
      color = {
        [1]  = 0.66,
        [2]  = 0.66,
        [3]  = 1,
      },
    },
    lightningballs = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater		 = true,
      properties = {
        airdrag            = 1,
        colormap           = [[0 0 0 0.01 1 1 1 0.01 0 0 0 0.01]],
        directional        = true,
        emitrot            = 80,
        emitrotspread      = 0,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = 3,
        particlelifespread = 0,
        particlesize       = 1.5,
        particlesizespread = 4.5,
        particlespeed      = 0.01,
        particlespeedspread = 0,
        pos                = [[-10 r10, 1.0, -10 r10]],
        sizegrowth         = 0,
        sizemod            = 1.0,
        texture            = [[lightbw]],
      },
    },
  },
  ["lightning_storm_emp"] = {
    -- groundflash = {
    --   circlealpha        = 1,
    --   circlegrowth       = 0,
    --   flashalpha         = 0.17,
    --   flashsize          = 40,
    --   ttl                = 3,
    --   color = {
    --     [1]  = 0.66,
    --     [2]  = 0.66,
    --     [3]  = 1,
    --   },
    -- },
    lightningballs = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater     = true,
      properties = {
        airdrag            = 1,
        colormap           = [[0 0 0 0.01   0.66 0.66 1 0.05   0.66 0.66 1 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 80,
        emitrotspread      = 120,
        emitvector         = [[1, 1, 1]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = 1,
        particlelifespread = 4,
        particlesize       = 9,
        particlesizespread = 50,
        particlespeed      = 0.03,
        particlespeedspread = 0,
        pos                = [[-10 r10, 1.0, -10 r10]],
        sizegrowth         = -0.2,
        sizemod            = 1.0,
        texture            = [[lightninginair]],
      },
    },
  },
  ["lightning_storm_emp2"] = {
    lightningballs = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater     = true,
      properties = {
        airdrag            = 1,
        colormap           = [[0 0 0 0.01   0.66 0.66 1 0.05   0.66 0.66 1 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 80,
        emitrotspread      = 120,
        emitvector         = [[1, 1, 1]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = 1,
        particlelifespread = 4,
        particlesize       = 9,
        particlesizespread = 50,
        particlespeed      = 0.03,
        particlespeedspread = 0,
        pos                = [[-10 r10, 1.0, -10 r10]],
        sizegrowth         = -0.2,
        sizemod            = 1.0,
        texture            = [[lwhitelightb]],
      },
    },
  },
  ["lightning_stormbig"] = {
    -- groundflash = {
    --   circlealpha        = 1,
    --   circlegrowth       = 0,
    --   flashalpha         = 0.17,
    --   flashsize          = 80,
    --   ttl                = 15,
    --   color = {
    --     [1]  = 0.66,
    --     [2]  = 0.66,
    --     [3]  = 0.66,
    --   },
    -- },
    lightningballs = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater     = true,
      properties = {
        airdrag            = 1,
        colormap           = [[0 0 0 0.01   0.96 0.75 0.60 0.05   0.9 0.6 0.3 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 80,
        emitrotspread      = 120,
        emitvector         = [[1, 1, 1]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = 2,
        particlelifespread = 8,
        particlesize       = 9,
        particlesizespread = 100,
        particlespeed      = 0.03,
        particlespeedspread = 0,
        pos                = [[-10 r10, 1.0, -10 r10]],
        sizegrowth         = -0.2,
        sizemod            = 1.0,
        texture            = [[whitelightb]],
      },
    },
  },
    ["lightning_stormbigalt"] = {
    -- groundflash = {
    --   circlealpha        = 1,
    --   circlegrowth       = 0,
    --   flashalpha         = 0.17,
    --   flashsize          = 80,
    --   ttl                = 15,
    --   color = {
    --     [1]  = 0.66,
    --     [2]  = 0.66,
    --     [3]  = 0.66,
    --   },
    -- },
    lightningballsalt = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater     = true,
      properties = {
        airdrag            = 0.91,
        colormap           = [[0 0 0 0.01   0.96 0.75 0.60 0.05   0.9 0.6 0.3 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 80,
        emitrotspread      = 120,
        emitvector         = [[1, 1, 1]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = 1,
        particlelifespread = 6,
        particlesize       = 8,
        particlesizespread = 75,
        particlespeed      = 0.06,
        particlespeedspread = 0,
        pos                = [[-10 r10, 1.0, -10 r10]],
        sizegrowth         = -0.2,
        sizemod            = 1.0,
        texture            = [[lightning]],
      },
    },
  },
  ["lightning_storm_juno"] = {
    groundflash = {
      circlealpha        = 1,
      circlegrowth       = 0,
      flashalpha         = 0.17,
      flashsize          = 80,
      ttl                = 15,
      color = {
        [1]  = 0.66,
        [2]  = 0.88,
        [3]  = 0.33,
      },
    },
    lightningarcs = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater     = true,
      properties = {
        airdrag            = 1,
        colormap           = [[0 0 0 0.01   0.66 0.92 0.5 0.08   0.5 0.71 0.4 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 80,
        emitrotspread      = 120,
        emitvector         = [[1, 1, 1]],
        gravity            = [[0, 0, 0]],
        --gravity            = [[-0.5 r1, 0, -0.5 r1]],
        numparticles       = 1,
        particlelife       = 2,
        particlelifespread = 8,
        particlesize       = 11,
        particlesizespread = 120,
        particlespeed      = 0.02,
        particlespeedspread = 0.01,
        pos                = [[-10 r10, 1.0, -10 r10]],
        sizegrowth         = 0.3,
        sizemod            = 1.0,
        texture            = [[lightninginair]],
      },
    },
    lightningelectric = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater     = true,
      properties = {
        airdrag            = 1,
        colormap           = [[0 0 0 0.01   0.66 0.92 0.5 0.08   0.5 0.71 0.4 0.01   0 0 0 0.01]],
        directional        = false,
        emitrot            = 80,
        emitrotspread      = 120,
        emitvector         = [[1, 1, 1]],
        gravity            = [[0, 0, 0]],
        --gravity            = [[-0.5 r1, 0, -0.5 r1]],
        numparticles       = [[0.6 r0.6]],
        particlelife       = 2,
        particlelifespread = 8,
        particlesize       = 10,
        particlesizespread = 190,
        particlespeed      = 0.01,
        particlespeedspread = 0.02,
        pos                = [[-30 r30, 30.0, -30 r30]],
        rotParams          = [[-1 r2, 0, -180 r360]],
        sizegrowth         = -0.2,
        sizemod            = 1.0,
        texture            = [[whitelightb]],
      },
    },
    lightorbs = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater     = true,
      properties = {
        airdrag            = 0.92,
        colormap           = [[0 0 0 0.01   0.72 0.92 0.4 0.015   0.6 0.71 0.35 0.01   0.4 0.65 0.3 0.005   0 0 0 0.01]],
        directional        = false,
        emitrot            = 80,
        emitrotspread      = 120,
        emitvector         = [[1, 1, 1]],
        gravity            = [[0, 0, 0]],
        numparticles       = [[0.35 r0.8]],
        particlelife       = 22,
        particlelifespread = 25,
        particlesize       = 9,
        particlesizespread = 150,
        particlespeed      = 0.12,
        particlespeedspread = 0.32,
        pos                = [[-10 r25, 1.0, -10 r25]],
        sizegrowth         = -0.3,
        sizemod            = 1.0,
        texture            = [[flare1]],
      },
    },
  },
  ["lightning_storm_juno_scav"] = {
    groundflash = {
      circlealpha        = 1,
      circlegrowth       = 0,
      flashalpha         = 0.17,
      flashsize          = 80,
      ttl                = 15,
      color = {
        [1]  = 0.66,
        [2]  = 0.33,
        [3]  = 0.88,
      },
    },
    lightningarcs = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater     = true,
      properties = {
        airdrag            = 1,
        colormap           = [[0 0 0 0.01   0.66 0.5 0.92 0.08   0.5 0.4 0.71 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 80,
        emitrotspread      = 120,
        emitvector         = [[1, 1, 1]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = 2,
        particlelifespread = 8,
        particlesize       = 11,
        particlesizespread = 120,
        particlespeed      = 0.03,
        particlespeedspread = 0,
        pos                = [[-10 r10, 1.0, -10 r10]],
        sizegrowth         = -0.2,
        sizemod            = 1.0,
        texture            = [[lightninginair]],
      },
    },
    lightningelectric = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater     = true,
      properties = {
        airdrag            = 1,
        colormap           = [[0 0 0 0.01   0.66 0.5 0.92 0.08   0.5 0.4 0.71 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 80,
        emitrotspread      = 120,
        emitvector         = [[1, 1, 1]],
        gravity            = [[0, 0, 0]],
        numparticles       = [[0.6 r0.6]],
        particlelife       = 2,
        particlelifespread = 8,
        particlesize       = 30,
        particlesizespread = 160,
        particlespeed      = 0.03,
        particlespeedspread = 0,
        pos                = [[-30 r30, 30.0, -30 r30]],
        sizegrowth         = -0.2,
        sizemod            = 1.0,
        texture            = [[lightninginair]],
      },
    },
    lightorbs = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater     = true,
      properties = {
        airdrag            = 0.92,
        colormap           = [[0 0 0 0.01   0.72 0.4 0.92 0.015   0.6 0.35 0.71 0.01   0.4 0.3 0.65 0.005   0 0 0 0.01]],
        directional        = false,
        emitrot            = 80,
        emitrotspread      = 120,
        emitvector         = [[1, 1, 1]],
        gravity            = [[0, 0, 0]],
        numparticles       = [[0.6 r0.8]],
        particlelife       = 22,
        particlelifespread = 25,
        particlesize       = 9,
        particlesizespread = 150,
        particlespeed      = 0.12,
        particlespeedspread = 0.32,
        pos                = [[-10 r25, 1.0, -10 r25]],
        sizegrowth         = -0.3,
        sizemod            = 1.0,
        texture            = [[flare1]],
      },
    },
  },
  ["lightning_stormflares"] = {
    -- groundflash = {
    --   circlealpha        = 0.9,
    --   circlegrowth       = -0.05,
    --   flashalpha         = 0.20,
    --   flashsize          = 100,
    --   ttl                = 12,
    --   color = {
    --     [1]  = 0.76,
    --     [2]  = 0.76,
    --     [3]  = 0.76,
    --   },
    -- },
    lightningballs = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater     = true,
      properties = {
        airdrag            = 0.92,
        colormap           = [[0 0 0 0.01   0.83 0.64 0.50 0.15   0.82 0.55 0.27 0.08   0.6 0.4 0.15 0.05   0 0 0 0.01]],
        directional        = true,
        emitrot            = 80,
        emitrotspread      = 120,
        emitvector         = [[1, 1, 1]],
        gravity            = [[0, 0, 0]],
        numparticles       = 1,
        particlelife       = 10,
        particlelifespread = 14,
        particlesize       = 12,
        particlesizespread = 50,
        particlespeed      = 0.12,
        particlespeedspread = 0.32,
        pos                = [[-20 r40, 1.0, -20 r40]],
        sizegrowth         = -0.6,
        sizemod            = 1.0,
        texture            = [[glow2]],
      },
    },
  },
}

