-- nukedatbewm
local definitions = {
    ["newnuke"] = {
        centerflare = {
            air                = true,
            class              = [[CHeatCloudProjectile]],
            count              = 2,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                heat               = 15,
                heatfalloff        = [[0.18 r0.04]],
                maxheat            = 20,
                pos                = [[r-2 r2, 50, r-2 r2]],
                rotParams          = [[30 r20, -12 r-4, -180 r360]],
                --rotParams          = [[25 r30, -4 r-6, -180 r360]],
                size               = [[32 r5]],
                sizegrowth         = [[7 r3]],
                speed              = [[-1 r2, 0.7, -1 r2]],
                texture            = [[orangenovaexplo]],
                alwaysvisible      = true,
                drawOrder          = 1,
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
            colormap           = [[1.0 0.96 0.80 0.1    0.8 0.72 0.60 0.5    0.35 0.28 0.18 0.5    0 0 0 0]],
            dir                = [[0, 1, 0]],
            --gravity            = [[0.0, 0.1, 0.0]],
            frontoffset        = 0,
            fronttexture       = [[exploflare]],
            length             = 40,
            sidetexture        = [[none]],
            size               = 3800,
            sizegrowth         = [[0.4 r0.2]],
            ttl                = 38,
            pos                = [[0, 180, 0]],
            drawOrder          = 0,
          },
        },
        brightflareslow = {
          air                = true,
          class              = [[CBitmapMuzzleFlame]],
          count              = 1,
          ground             = true,
          underwater         = true,
          water              = true,
          properties = {
            colormap           = [[1.0 0.96 0.80 0.4    0.8 0.72 0.60 0.25    0.35 0.28 0.18 0.11    0 0 0 0]],
            dir                = [[0, 1, 0]],
            --gravity            = [[0.0, 0.1, 0.0]],
            frontoffset        = 9,
            fronttexture       = [[circularthingy]],
            length             = 40,
            sidetexture        = [[none]],
            size               = 500,
            sizegrowth         = [[0.4 r0.2]],
            ttl                = 200,
            pos                = [[0, -350, 0]],
            drawOrder          = 0,
          },
        },
        groundflash_large = {
            class              = [[CSimpleGroundFlash]],
            count              = 1,
            air                = false,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                rotParams          = [[11 r6, -2 r-4, -180 r360]],
                colormap           = [[1 0.7 0.3 0.49   0 0 0 0.01]],
                size               = 900,
                ttl                = 250,
                sizegrowth         = -3,
                texture            = [[groundflash]],
                alwaysvisible      = true,
            },
        },
        groundflash_quick = {
            class              = [[CSimpleGroundFlash]],
            count              = 1,
            air                = false,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                rotParams          = [[4 r2, -1 r-0.5, -180 r360]],
                colormap           = [[1 0.93 0.75 0.3   0 0 0 0.01]],
                size               = 200,
                sizegrowth         = 18,
                ttl                = 250,
                --sizegrowth         = 10,
                texture            = [[groundflash]],
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
                colormap           = [[1 0.9 0.75 0.45   0 0 0 0.01]],
                size               = 1200,
                sizegrowth         = 0,
                ttl                = 145,
                texture            = [[groundflash]],
                alwaysvisible      = true,
            },
        },
        kickedupwater = {
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            water              = true,
            underwater         = true,
            properties = {
                airdrag            = 0.87,
                colormap           = [[0.7 0.7 0.9 0.35 0 0 0 0.0]],
                directional        = false,
                emitrot            = 90,
                emitrotspread      = 5,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0, 0.1, 0]],
                numparticles       = 100,
                particlelife       = 2,
                particlelifespread = 45,
                particlesize       = 3,
                particlesizespread = 1.5,
                particlespeed      = 12,
                particlespeedspread = 20,
                pos                = [[0, 1, 0]],
                sizegrowth         = 0.5,
                sizemod            = 1.0,
                texture            = [[wake]],
                alwaysvisible      = true,
            },
        },
        explosion_flames = {
            air                = true,
            class              = [[CSimpleParticleSystem]],
            count              = 2,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                airdrag            = 0.96,
                colormap           = [[0 0 0 0   1 0.95 0.8 0.02   0.92 0.67 0.35 0.015   0.55 0.24 0.07 0.01   0.1 0.05 0.02 0.005   0 0 0 0.01]],
                directional        = true,
                emitrot            = 45,
                emitrotspread      = 32,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0, -0.01, 0]],
                numparticles       = 5,
                particlelife       = 60,
                particlelifespread = 20,
                particlesize       = 45,
                particlesizespread = 62,
                particlespeed      = 8,
                particlespeedspread = 8,
                pos                = [[0, 15, 0]],
                sizegrowth         = 0.4,
                sizemod            = 1,
                texture            = [[flashside3]],
                useairlos          = false,
                alwaysvisible      = true,
                drawOrder          = 1,
            },
        },
        explosion = {
            air                = true,
            class              = [[CSimpleParticleSystem]],
            count              = 2,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                airdrag            = 0.96,
                colormap           = [[0 0 0 0   1 0.93 0.7 0.008  0.9 0.63 0.26 0.012   0.70 0.38 0.04 0.008    0.15 0.05 0.002 0.005   0.40 0.20 0.04 0.008   0 0 0 0.01]],
                directional        = true,
                emitrot            = 45,
                emitrotspread      = 32,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0, 0.005, 0]],
                numparticles       = 4,
                particlelife       = 52,
                particlelifespread = 34,
                particlesize       = 57,
                particlesizespread = 68,
                particlespeed      = 6,
                particlespeedspread = 2,
                pos                = [[0, 60, 0]],
                sizegrowth         = 3.2,
                sizemod            = 0.97,
                texture            = [[flashside3]],
                useairlos          = false,
                alwaysvisible      = true,
                drawOrder          = 1,
            },
        },
        sparks = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater         = false,
      properties = {
        airdrag            = 0.97,
        colormap           = [[0.85 0.75 0.67 0.005   0.8 0.55 0.3 0.011   0.8 0.55 0.3 0.005   0.4 0.22 0.15 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 30,
        emitrotspread      = 40,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.05, 0]],
        numparticles       = 13,
        particlelife       = 80,
        particlelifespread = 16,
        particlesize       = 70,
        particlesizespread = 95,
        particlespeed      = 14,
        particlespeedspread = 9,
        pos                = [[0, 4, 0]],
        rotParams          = [[-5 r10, -5 r10, -180]],
        sizegrowth         = -0.04,
        sizemod            = 0.98,
        texture            = [[gunshotxl]],
        useairlos          = false,
        alwaysvisible      = true,
        drawOrder          = 2,
      },
    },
    fireglow = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater         = true,
      properties = {
        airdrag            = 0.9,
        colormap           = [[0.4 0.3 0.055 0.01   0 0 0 0]],
        directional        = true,
        emitrot            = 65,
        emitrotspread      = 30,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 5,
        particlelife       = 40,
        particlelifespread = 0,
        particlesize       = 128,
        particlesizespread = 64,
        particlespeed      = 3,
        particlespeedspread = 0,
        pos                = [[0, 2, 0]],
        sizegrowth         = -0.2,
        sizemod            = 1,
        texture            = [[glow2]],
        useairlos          = false,
        alwaysvisible      = true,
        drawOrder          = 2,
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
            colormap           = [[0 0 0 0   1 0.95 0.8 0.50   0.9 0.8 0.70 0.7  0.8 0.65 0.4 0.35   0.10 0.08 0.04 0.012    0.06 0.04 0.02 0.006    0 0 0 0.01]],
            dir                = [[0, 1, 0]],
            --gravity            = [[0.0, 0.1, 0.0]],
            frontoffset        = 0,
            fronttexture       = [[blastwave]],
            length             = 40,
            sidetexture        = [[none]],
            size               = 12,
            sizegrowth         = [[-29 r6]],
            ttl                = 38,
            pos                = [[0, 75, 0]],
            drawOrder          = 1,
          },
        },
    shockwave_inner = {
          air                = true,
          class              = [[CBitmapMuzzleFlame]],
          count              = 1,
          ground             = true,
          underwater         = true,
          water              = true,
          properties = {
            colormap           = [[0 0 0 0   0.7 0.6 0.35 0.25   0.5 0.38 0.15 0.12  0.3 0.25 0.09 0.10   0.10 0.08 0.04 0.008    0.06 0.04 0.02 0.005    0 0 0 0.01]],
            dir                = [[0, 1, 0]],
            --gravity            = [[0.0, 0.1, 0.0]],
            frontoffset        = 0,
            fronttexture       = [[explosionwave]],
            length             = 0,
            sidetexture        = [[none]],
            size               = 45,
            sizegrowth         = [[-15 r6]],
            ttl                = 95,
            pos                = [[0, 5, 0]],
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
            colormap           = [[0 0 0 0   0.06 0.04 0.02 0.006   0.10 0.08 0.04 0.008   0.18 0.12 0.08 0.010   0.4 0.35 0.3 0.15  0.18 0.12 0.08 0.010   0.10 0.08 0.04 0.005    0.06 0.04 0.02 0.004    0 0 0 0.01]],
            dir                = [[0, 1, 0]],
            --gravity            = [[0.0, 0.1, 0.0]],
            frontoffset        = 0,
            fronttexture       = [[explosionwave]],
            length             = 0,
            sidetexture        = [[none]],
            size               = 24,
            sizegrowth         = [[-15 r3]],
            ttl                = 120,
            pos                = [[0, 25, 0]],
          },
        },
    -- shockwave = {
    --     class              = [[CSpherePartSpawner]],
    --         count              = 1,
    --         ground             = true,
    --         water              = true,
    --         underwater         = true,
    --         air                = true,
    --         properties = {
    --             alpha           = 0.20,
    --             ttl             = 30,
    --             expansionSpeed  = 18,
    --             color           = [[1.0, 0.85, 0.45]],
    --             alwaysvisible      = true,
    --         },
    -- },
    -- shockwave_slow = {
    --     class              = [[CSpherePartSpawner]],
    --         count              = 1,
    --         ground             = true,
    --         water              = true,
    --         underwater         = true,
    --         air                = true,
    --         properties = {
    --             alpha           = 0.05,
    --             ttl             = 120,
    --             expansionSpeed  = 9,
    --             color           = [[0.8, 0.55, 0.2]],
    --         },
    -- },
    -- shockwave_inner = {
    --     class              = [[CSpherePartSpawner]],
    --         count              = 1,
    --         ground             = true,
    --         water              = true,
    --         underwater         = true,
    --         air                = true,
    --         properties = {
    --             alpha           = 0.95,
    --             ttl             = 50,
    --             expansionSpeed  = 4.8,
    --             color           = [[0.7, 0.60, 0.32]],
    --             alwaysvisible      = true,
    --         },
    -- },
    bigsmoketrails = {
      air                = true,
      class              = [[CBitmapMuzzleFlame]],
      count              = 5,
      ground             = true,
      underwater         = 0,
      water              = true,
      properties = {
        colormap           = [[0 0 0 0   0.9 0.63 0.26 0.4   0.07 0.05 0.05 0.25   0.07 0.05 0.05 0.44    0.05 0.04 0.04 0.25   0.03 0.03 0.03 0.15   0 0 0 0.01]],
        dir                = [[-0.7 r1.4, 0.3 r0.58, 0 r-0.7]],
        --gravity            = [[0.0, 0.1, 0.0]],
        frontoffset        = 0.05,
        fronttexture       = [[none]],
        length             = [[260 r25]],
        sidetexture        = [[flamestream]],
        size               = [[170 r25]],
        sizegrowth         = 0.75,
        ttl                = 100,
        rotParams          = [[-15 r30, -5 r10, -90 r180]],
        pos                = [[-50 r100, 0 r50, -50 r100]],
        drawOrder          = 0,
      },
    },
        dirt = {
            class              = [[CSimpleParticleSystem]],
            count              = 8,
            ground             = true,
            air                = false,
            properties = {
                airdrag            = 0.97,
                colormap           = [[0.04 0.03 0.01 0   0.15 0.14 0.066 0.50    0.13 0.09 0.05 0.45   0.08 0.065 0.035 0.35   0.075 0.07 0.06 0.20   0 0 0 0  ]],
                directional        = false,
                emitrot            = 35,
                emitrotspread      = 16,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0, -0.15, 0]],
                numparticles       = 6,
                particlelife       = 100,
                particlelifespread = 45,
                particlesize       = 40,
                particlesizespread = -3.6,
                particlespeed      = 6,
                particlespeedspread = 14,
                rotParams          = [[-20 r40, 0, -180 r360]],
                pos                = [[0, 3, 0]],
                sizegrowth         = -0.045,
                sizemod            = 1,
                texture            = [[randomdots]],
                useairlos          = false,
                alwaysvisible      = true,
                drawOrder          = 1,
            },
        },
        dirt2 = {
            class              = [[CSimpleParticleSystem]],
            count              = 3,
            ground             = true,
            air                = false,
            properties = {
                airdrag            = 0.98,
                colormap           = [[0.08 0.06 0.03 0.66   0.12 0.09 0.05 0.58    0.1 0.07 0.03 0.52   0.08 0.065 0.035 0.40   0.075 0.07 0.06 0.3   0 0 0 0  ]],
                directional        = false,
                emitrot            = 10,
                emitrotspread      = 20,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0, -0.15, 0]],
                numparticles       = 18,
                particlelife       = 180,
                particlelifespread = 40,
                particlesize       = 3,
                particlesizespread = -1.5,
                particlespeed      = 10,
                particlespeedspread = 18,
                rotParams          = [[-10 r20, 0, -180 r360]],
                pos                = [[0, 3, 0]],
                sizegrowth         = -0.015,
                sizemod            = 1,
                texture            = [[bigexplosmoke]],
                useairlos          = false,
                alwaysvisible      = true,
                drawOrder          = 0,
            },
        },
        dirt3 = {
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            ground             = true,
            air                = false,
            properties = {
                airdrag            = 0.96,
                colormap           = [[0.03 0.02 0.01 0.6   0.1 0.07 0.033 0.76    0.1 0.07 0.03 0.58   0.08 0.065 0.035 0.47   0.075 0.07 0.06 0.4   0 0 0 0  ]],
                directional        = false,
                emitrot            = 45,
                emitrotspread      = 16,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0, -0.10, 0]],
                numparticles       = 7,
                particlelife       = 80,
                particlelifespread = 45,
                particlesize       = 90,
                particlesizespread = -3.6,
                particlespeed      = 8,
                particlespeedspread = 4,
                rotParams          = [[-5 r10, 0, -180 r360]],
                pos                = [[0, 3, 0]],
                sizegrowth         = -0.2,
                sizemod            = 1,
                texture            = [[randomdots]],
                useairlos          = false,
                alwaysvisible      = true,
                drawOrder          = 0,
            },
        },
        clouddust = {
            air                = true,
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                airdrag            = 0.96,
                colormap           = [[0 0 0 0.01  0.025 0.02 0.02 0.05  0.06 0.055 0.055 0.16  0.043 0.04 0.04 0.11   0.0238 0.022 0.022 0.06  0 0 0 0.01]],
                directional        = false,
                emitrot            = 40,
                emitrotspread      = 15,
                emitvector         = [[0.5, 1, 0.5]],
                gravity            = [[0, -0.01, 0]],
                numparticles       = 35,
                particlelife       = 90,
                particlelifespread = 150,
                particlesize       = 66,
                particlesizespread = 40,
                particlespeed      = 0.3,
                particlespeedspread = 6,
                pos                = [[0, 40, 0]],
                rotParams          = [[-30 r60, 0, -180 r360]],
                sizegrowth         = 0.15,
                sizemod            = 1.0,
                texture            = [[bigexplosmoke]],
                alwaysvisible      = true,
                drawOrder          = 0,
            },
        },
        dustparticles = {
          air                = false,
          class              = [[CSimpleParticleSystem]],
          count              = 1,
          ground             = true,
          underwater         = true,
          water              = true,
          properties = {
                airdrag            = 0.94,
                colormap           = [[1 0.85 0.6 0.22  1 0.63 0.3 0.12  1 0.52 0.2 0.06   0 0 0 0.01]],
                directional        = true,
                emitrot            = 45,
                emitrotspread      = 32,
                emitvector         = [[0.5, 1, 0.5]],
                gravity            = [[0, -0.011, 0]],
                numparticles       = 12,
                particlelife       = 40,
                particlelifespread = 5.75,
                particlesize       = 5,
                particlesizespread = 1.5,
                particlespeed      = 5.8,
                particlespeedspread = 2,
                rotParams          = [[-5 r10, 0, -180 r360]],
                pos                = [[0, 0, 0]],
                sizegrowth         = 2.2,
                sizemod            = 1.0,
                texture            = [[randomdots]],
                alwaysvisible      = true,
                drawOrder          = 1,
      },
    },
    grounddust = {
      air                = false,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      underwater         = true,
      unit               = false,
      properties = {
        airdrag            = 0.92,
        colormap           = [[0 0 0 0   0.36 0.32 0.28 0.4   0 0 0 0.01]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = -2,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.1, 0]],
        numparticles       = 4,
        particlelife       = 130,
        particlelifespread = 55,
        particlesize       = 20,
        particlesizespread = 60,
        particlespeed      = 12,
        particlespeedspread = 3,
        rotParams          = [[-4 r8, -1 r2, -180 r360]],
        pos                = [[0, 50, 0]],
        sizegrowth         = 1.6,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
        alwaysvisible      = true,
      },
    },

        nukefloor = {
            air                = true,
            class              = [[CExpGenSpawner]],
            count              = 2,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                delay              = [[22 i1]],
                explosiongenerator = [[custom:newnuke-floor]],
                pos                = [[-70 r140, 70 r15, -70 r140]],
            },
        },
},

    ["newnuke-floor"] = {
            smoke = {
                air                = true,
                class              = [[CSimpleParticleSystem]],
                count              = 2,
                ground             = true,
                water              = true,
                properties = {
                    airdrag            = 0.86,
                    colormap           = [[0 0 0 0.01   0.20 0.16 0.14 0.46   0.32 0.244 0.12 0.30    0.24 0.20 0.16 0.62   0.22 0.18 0.14 0.53   0.20 0.16 0.14 0.46   0.18 0.12 0.1 0.42   0.16 0.12 0.08 0.38   0.065 0.048 0.037 0.36   0.045 0.035 0.03 0.32   0.05 0.04 0.035 0.2    0 0 0 0.01]],
                    directional        = false,
                    emitrot            = 55,
                    emitrotspread      = 25,
                    emitvector         = [[0, 1, 0]],
                    gravity            = [[0.0, 0.06, 0.0]],
                    numparticles       = 3,
                    particlelife       = 110,
                    particlelifespread = 120,
                    particlesize       = 13,
                    particlesizespread = 65,
                    particlespeed      = 13,
                    particlespeedspread = 14,
                    rotParams          = [[-30 r60, -1 r2, -180 r360]],
                    pos                = [[0.0, 80, 0.0]],
                    sizegrowth         = 1.08,
                    sizemod            = 1,
                    texture            = [[dirt]],
                    useairlos          = true,
                    alwaysvisible      = true,
                    drawOrder          = 0,
                },
            },
            smoke2 = {
                air                = true,
                class              = [[CSimpleParticleSystem]],
                count              = 2,
                ground             = true,
                water              = true,
                properties = {
                    airdrag            = 0.88,
                    colormap           = [[0 0 0 0.01   0.1 0.09 0.06 0.05    0.20 0.14 0.08 0.04   0.30 0.22 0.10 0.20    0.22 0.18 0.17 0.50   0.22 0.18 0.16 0.45   0.19 0.15 0.15 0.42   0.18 0.14 0.14 0.34   0.17 0.14 0.14 0.30   0.16 0.14 0.13 0.24   0.14 0.10 0.10 0.16    0 0 0 0.01]],
                    directional        = false,
                    emitrot            = 95,
                    emitrotspread      = 10,
                    emitvector         = [[0, 1, 0]],
                    gravity            = [[0.0, 0.065, 0.0]],
                    numparticles       = 1,
                    particlelife       = 120,
                    particlelifespread = 135,
                    particlesize       = 17,
                    particlesizespread = 65,
                    particlespeed      = 11,
                    particlespeedspread = 12,
                    rotParams          = [[-30 r60, -2 r4, -180 r360]],
                    pos                = [[0.0, 80, 0.0]],
                    sizegrowth         = 1.01,
                    sizemod            = 1,
                    texture            = [[fogdirty]],
                    useairlos          = true,
                    alwaysvisible      = true,
                    drawOrder          = 0,
                },
            },
            smoke3 = {
                air                = true,
                class              = [[CSimpleParticleSystem]],
                count              = 3,
                ground             = true,
                water              = true,
                properties = {
                    airdrag            = 0.88,
                    colormap           = [[0 0 0 0.01   0.13 0.10 0.07 0.05    0.20 0.14 0.08 0.04   0.30 0.22 0.10 0.20    0.22 0.18 0.17 0.55   0.20 0.16 0.14 0.50   0.17 0.13 0.13 0.42   0.12 0.10 0.10 0.36   0.13 0.10 0.10 0.30   0.11 0.09 0.09 0.24   0.10 0.07 0.07 0.16    0 0 0 0.01]],
                    directional        = false,
                    emitrot            = 95,
                    emitrotspread      = 10,
                    emitvector         = [[0, 1, 0]],
                    gravity            = [[0.0, 0.065, 0.0]],
                    numparticles       = 1,
                    particlelife       = 160,
                    particlelifespread = 145,
                    particlesize       = 40,
                    particlesizespread = 115,
                    particlespeed      = 11,
                    particlespeedspread = 12,
                    rotParams          = [[-6 r12, -2 r4, -180 r360]],
                    pos                = [[-50 r100, 80, -50 r100]],
                    sizegrowth         = 1.01,
                    sizemod            = 1,
                    texture            = [[cloudpuff]],
                    useairlos          = true,
                    alwaysvisible      = true,
                    drawOrder          = 0,
                },
            },
        },

    ["armnuke"] = {
        centerflare = {
            air                = true,
            class              = [[CHeatCloudProjectile]],
            count              = 1,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                heat               = 10,
                heatfalloff        = 1.3,
                maxheat            = 20,
                pos                = [[r-2 r2, 5, r-2 r2]],
                size               = 9,
                sizegrowth         = 40,
                speed              = [[0, 1 0, 0]],
                texture            = [[flare]],
            },
        },
        groundflash_large = {
            class              = [[CSimpleGroundFlash]],
            count              = 1,
            air                = false,
            ground             = true,
            water              = true,
            properties = {
                colormap           = [[1 0.7 0.3 0.45   0 0 0 0.01]],
                size               = 900,
                ttl                = 40,
                sizegrowth         = -1,
                texture            = [[groundflash]],
            },
        },
        groundflash_white = {
            class              = [[CSimpleGroundFlash]],
            count              = 1,
            air                = false,
            ground             = true,
            water              = true,
            properties = {
                colormap           = [[1 0.9 0.75 0.55   0 0 0 0.01]],
                size               = 1200,
                sizegrowth         = 0,
                ttl                = 45,
                texture            = [[groundflash]],
            },
        },
        kickedupwater = {
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            water              = true,
            underwater         = true,
            properties = {
                airdrag            = 0.87,
                colormap           = [[0.7 0.7 0.9 0.35	0 0 0 0.0]],
                directional        = false,
                emitrot            = 90,
                emitrotspread      = 5,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0, 0.1, 0]],
                numparticles       = 100,
                particlelife       = 2,
                particlelifespread = 45,
                particlesize       = 3,
                particlesizespread = 1.5,
                particlespeed      = 12,
                particlespeedspread = 20,
                pos                = [[0, 1, 0]],
                sizegrowth         = 0.5,
                sizemod            = 1.0,
                texture            = [[wake]],
            },
        },
        explosion = {
            air                = true,
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                airdrag            = 0.82,
                colormap           = [[0 0 0 0   1 0.93 0.7 0.09   0.9 0.53 0.21 0.066   0.66 0.28 0.04 0.033   0 0 0 0.01]],
                directional        = true,
                emitrot            = 45,
                emitrotspread      = 32,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0, -0.01, 0]],
                numparticles       = 22,
                particlelife       = 18,
                particlelifespread = 13,
                particlesize       = 20,
                particlesizespread = 32,
                particlespeed      = 6,
                particlespeedspread = 8,
                pos                = [[0, 15, 0]],
                sizegrowth         = 0.3,
                sizemod            = 1,
                texture            = [[flashside3]],
                useairlos          = false,
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
                airdrag            = 0.96,
                colormap           = [[0.8 0.5 0.2 0.01   0.95 0.55 0.25 0.017   0.6 0.35 0.1 0.01   0 0 0 0.01]],
                directional        = true,
                emitrot            = 20,
                emitrotspread      = 35,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0, -0.55, 0]],
                numparticles       = 35,
                particlelife       = 22,
                particlelifespread = 22,
                particlesize       = 140,
                particlesizespread = 200,
                particlespeed      = 9,
                particlespeedspread = 18,
                pos                = [[0, 4, 0]],
                sizegrowth         = 1,
                sizemod            = 0.7,
                texture            = [[gunshotglow]],
                useairlos          = false,
            },
        },
        dirt = {
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            ground             = true,
            properties = {
                airdrag            = 0.98,
                colormap           = [[0.04 0.03 0.01 0   0.1 0.07 0.033 0.66    0.1 0.07 0.03 0.58   0.08 0.065 0.035 0.47   0.075 0.07 0.06 0.4   0 0 0 0  ]],
                directional        = true,
                emitrot            = 25,
                emitrotspread      = 16,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0, -0.55, 0]],
                numparticles       = 40,
                particlelife       = 55,
                particlelifespread = 25,
                particlesize       = 3,
                particlesizespread = -1.8,
                particlespeed      = 9,
                particlespeedspread = 22,
                pos                = [[0, 3, 0]],
                sizegrowth         = -0.015,
                sizemod            = 1,
                texture            = [[bigexplosmoke]],
                useairlos          = false,
            },
        },
        dirt2 = {
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            ground             = true,
            properties = {
                airdrag            = 0.96,
                colormap           = [[0.04 0.03 0.01 0   0.1 0.07 0.033 0.66    0.1 0.07 0.03 0.58   0.08 0.065 0.035 0.47   0.075 0.07 0.06 0.4   0 0 0 0  ]],
                directional        = true,
                emitrot            = 0,
                emitrotspread      = 20,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0, -0.55, 0]],
                numparticles       = 10,
                particlelife       = 45,
                particlelifespread = 20,
                particlesize       = 2.7,
                particlesizespread = -1.5,
                particlespeed      = 9,
                particlespeedspread = 22,
                pos                = [[0, 3, 0]],
                sizegrowth         = -0.015,
                sizemod            = 1,
                texture            = [[bigexplosmoke]],
                useairlos          = false,
            },
        },
        clouddust = {
            air                = true,
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            ground             = true,
            properties = {
                airdrag            = 0.96,
                colormap           = [[0 0 0 0.01  0.025 0.02 0.02 0.05  0.06 0.055 0.055 0.1  0.043 0.04 0.04 0.06   0.0238 0.022 0.022 0.03  0 0 0 0.01]],
                directional        = false,
                emitrot            = 40,
                emitrotspread      = 15,
                emitvector         = [[0.5, 1, 0.5]],
                gravity            = [[0, -0.01, 0]],
                numparticles       = 35,
                particlelife       = 90,
                particlelifespread = 150,
                particlesize       = 66,
                particlesizespread = 40,
                particlespeed      = 0.3,
                particlespeedspread = 6,
                pos                = [[0, 40, 0]],
                sizegrowth         = 0.15,
                sizemod            = 1.0,
                texture            = [[bigexplosmoke]],
            },
        },

        nukefloor = {
            air                = true,
            class              = [[CExpGenSpawner]],
            count              = 6,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                delay              = [[0 i1]],
                explosiongenerator = [[custom:armnuke-floor]],
                pos                = [[-50 r100, 40, -50 r100]],
            },
        },
        nukestem = {
            air                = true,
            class              = [[CExpGenSpawner]],
            count              = 8,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                delay              = [[i1.5]],
                explosiongenerator = [[custom:armnuke-stem]],
                pos                = [[-10 r20, -66 r33 i30, -10 r20]],
            },
        },
        nukestem2 = {
            air                = true,
            class              = [[CExpGenSpawner]],
            count              = 8,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                delay              = [[i1]],
                explosiongenerator = [[custom:armnuke-stem2]],
                pos                = [[-10 r20, -66 r33 i30, -10 r20]],
            },
        },
        --nukemid = {
        --    air                = true,
        --    class              = [[CExpGenSpawner]],
        --    count              = 7,
        --    ground             = true,
        --    water              = true,
        --    underwater         = true,
        --    properties = {
        --        delay              = [[6 i2]],
        --        explosiongenerator = [[custom:armnuke-mid]],
        --        pos                = [[-10 r20, 90 i5.5, -10 r20]],
        --    },
        --},
        nukeheadring = {
            air                = true,
            class              = [[CExpGenSpawner]],
            count              = 1,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                delay              = [[4 i1]],
                explosiongenerator = [[custom:armnuke-headring]],
                pos                = [[0, 235, 0]],
            },
        },
        nukehead = {
            air                = true,
            class              = [[CExpGenSpawner]],
            count              = 8,
            ground             = true,
            water              = true,
            underwater         = true,
            properties = {
                delay              = [[8.5 i1]],
                explosiongenerator = [[custom:armnuke-head]],
                pos                = [[-25 r50, 245 i2.7, -25 r50]],
            },
        },
    },

    ["armnuke-floor"] = {
        smoke = {
            air                = true,
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            ground             = true,
            water              = true,
            properties = {
                airdrag            = 0.4,
                colormap           = [[0.63 0.5 0.4 0.01  0.28 0.25 0.21 0.4   0.18 0.16 0.14 0.38   0.15 0.14 0.13 0.38   0.14 0.13 0.12 0.34   0.108 0.1 0.09 0.26   0.105 0.1 0.09 0.26   0.1 0.095 0.085 0.2   0.095 0.09 0.085 0.2   0.045 0.045 0.04 0.1   0.045 0.045 0.04 0.1   0.022 0.022 0.02 0.05   0.022 0.022 0.02 0.05   0 0 0 0.01]],
                directional        = true,
                emitrot            = 94,
                emitrotspread      = 3,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0.0, 0.005, 0.0]],
                numparticles       = 65,
                particlelife       = 120,
                particlelifespread = 75,
                particlesize       = 26,
                particlesizespread = 12,
                particlespeed      = 15,
                particlespeedspread = 180,
                pos                = [[0.0, 0, 0.0]],
                sizegrowth         = 0.3,
                sizemod            = 1,
                texture            = [[dirt]],
                useairlos          = true,
            },
        },
    },
    ["armnuke-stem"] = {
        smoke = {
            air                = true,
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            ground             = true,
            water              = true,
            properties = {
                airdrag            = 0.9,
                colormap           = [[0.25 0.21 0.1 0.5   0.45 0.27 0.18 0.45  0.3 0.22 0.13 0.4   0.25 0.17 0.13 0.37   0.33 0.24 0.12 0.35  0.25 0.2 0.12 0.35   0.18 0.14 0.11 0.3   0 0 0 0.01]],
                directional        = true,
                emitrot            = 0,
                emitrotspread      = 0,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0.0, 0.08, 0.0]],
                numparticles       = 2,
                particlelife       = 30,
                particlelifespread = 15,
                particlesize       = 15,
                particlesizespread = 6,
                particlespeed      = 5.5,
                particlespeedspread = 3.5,
                pos                = [[0.0, 0, 0.0]],
                sizegrowth         = 0.15,
                sizemod            = 1,
                texture            = [[dirt]],
                useairlos          = true,
            },
        },
    },
    ["armnuke-stem2"] = {
        smoke = {
            air                = true,
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            ground             = true,
            water              = true,
            properties = {
                airdrag            = 0.9,
                colormap           = [[0.17 0.15 0.12 0.15  0.17 0.15 0.11 0.4   0.17 0.14 0.1 0.38   0.17 0.14 0.1 0.38   0.16 0.13 0.095 0.34   0.13 0.11 0.09 0.26   0.11 0.095 0.075 0.2   0.085 0.075 0.07 0.15   0 0 0 0.01]],
                directional        = true,
                emitrot            = 2,
                emitrotspread      = 2,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0.0, 0.08, 0.0]],
                numparticles       = [[4 r1.5]],
                particlelife       = 50,
                particlelifespread = 20,
                particlesize       = 14,
                particlesizespread = 5,
                particlespeed      = 3,
                particlespeedspread = 5,
                pos                = [[0.0, 0, 0.0]],
                sizegrowth         = 0.15,
                sizemod            = 1,
                texture            = [[dirt]],
                useairlos          = true,
            },
        },
    },
    ["armnuke-mid"] = {
        smoke = {
            air                = true,
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            ground             = true,
            water              = true,
            properties = {
                airdrag            = 0.82,
                colormap           = [[0.38 0.28 0.18 0.4  0.22 0.16 0.1 0.33  0.2 0.15 0.1 0.3   0.2 0.15 0.1 0.3   0.22 0.18 0.09 0.25  0.2 0.15 0.07 0.22   0.19 0.16 0.1 0.25   0 0 0 0.01]],
                directional        = true,
                emitrot            = 100,
                emitrotspread      = 1,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0.0, 0.3, 0.0]],
                numparticles       = 3,
                particlelife       = 36,
                particlelifespread = 10,
                particlesize       = 13,
                particlesizespread = 8,
                particlespeed      = 1,
                particlespeedspread = 2,
                pos                = [[0, 5, 0]],
                sizegrowth         = -0.15,
                sizemod            = 1,
                texture            = [[dirt]],
                useairlos          = true,
            },
        },
    },
    ["armnuke-headring"] = {
        smoke = {
            air                = true,
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            ground             = true,
            water              = true,
            properties = {
                airdrag            = 0.44,
                colormap           = [[0 0 0 0.01    0.006 0.003 0.001 0.009    0.2 0.15 0.07 0.03    0.3 0.23 0.1 0.35   0.4 0.29 0.15 0.42    0.7 0.5 0.28 0.4   0.55 0.3 0.25 0.32   0.45 0.225 0.13 0.25    0.3 0.2 0.07 0.2    0 0 0 0.01]],
                directional        = true,
                emitrot            = 90,
                emitrotspread      = 2,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0.0, 0.66, 0.0]],
                numparticles       = 40,
                particlelife       = 24,
                particlelifespread = 24,
                particlesize       = 33,
                particlesizespread = 3,
                particlespeed      = 23,
                particlespeedspread = 1,
                pos                = [[48, 48, 48]],
                sizegrowth         = -0.6,
                sizemod            = 1,
                texture            = [[dirt]],
                useairlos          = true,
            },
        },
    },
    ["armnuke-head"] = {
        smoke = {
            air                = true,
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            ground             = true,
            water              = true,
            properties = {
                airdrag            = 0.88,
                colormap           = [[0.022 0.019 0.015 0.04   0.055 0.045 0.04 0.08   0.18 0.15 0.13 0.33   0.13 0.11 0.095 0.27   0.11 0.09 0.08 0.22  0.06 0.05 0.045 0.145   0.043 0.04 0.03 0.1   0 0 0 0.01]],
                directional        = true,
                emitrot            = 100,
                emitrotspread      = 2,
                emitvector         = [[0, 1, 0]],
                gravity            = [[0.0, 0.015, 0.0]],
                numparticles       = 7,
                particlelife       = 40,
                particlelifespread = 55,
                particlesize       = 6.5,
                particlesizespread = 6.5,
                particlespeed      = 1,
                particlespeedspread = 2,
                pos                = [[50, 50, 50]],
                sizegrowth         = 0.27,
                sizemod            = 1,
                texture            = [[dirt]],
                useairlos          = true,
            },
        },
    },

}

-- local size = 1.5

-- definitions['cornuke-floor'] = table.copy(definitions['armnuke-floor'])
-- definitions['cornuke-floor'].smoke.properties.numparticles = math.floor(definitions['cornuke-floor'].smoke.properties.numparticles * size)
-- definitions['cornuke-floor'].smoke.properties.particlespeedspread = math.floor(definitions['cornuke-floor'].smoke.properties.particlespeedspread * size)
-- definitions['cornuke-stem'] = table.copy(definitions['armnuke-stem'])
-- definitions['cornuke-stem'].smoke.properties.particlesize = math.floor(definitions['cornuke-stem'].smoke.properties.particlesize * size)
-- definitions['cornuke-stem2'] = table.copy(definitions['armnuke-stem2'])
-- definitions['cornuke-stem2'].smoke.properties.particlesize = math.floor(definitions['cornuke-stem2'].smoke.properties.particlesize * size)
-- definitions['cornuke-headring'] = table.copy(definitions['armnuke-headring'])
-- definitions['cornuke-headring'].smoke.properties.numparticles = math.floor(definitions['cornuke-headring'].smoke.properties.numparticles * size)
-- definitions['cornuke-headring'].smoke.properties.particlespeedspread = math.floor(definitions['cornuke-headring'].smoke.properties.particlespeedspread * size)
-- definitions['cornuke-headring'].smoke.properties.particlesize = math.floor(definitions['cornuke-headring'].smoke.properties.particlesize * size)
-- definitions['cornuke-head'] = table.copy(definitions['armnuke-head'])
-- definitions['cornuke-head'].smoke.properties.numparticles = math.floor(definitions['cornuke-head'].smoke.properties.numparticles * size)
-- definitions['cornuke-head'].smoke.properties.particlespeedspread = math.floor(definitions['cornuke-head'].smoke.properties.particlespeedspread * size)
-- definitions['cornuke-head'].smoke.properties.particlesize = math.floor(definitions['cornuke-head'].smoke.properties.particlesize * size)
-- --
-- definitions['cornuke'] = table.copy(definitions['armnuke'])
-- definitions['cornuke'].nukefloor.properties.explosiongenerator = [[custom:cornuke-floor]]
-- definitions['cornuke'].nukestem.properties.explosiongenerator = [[custom:cornuke-stem]]
-- definitions['cornuke'].nukestem2.properties.explosiongenerator = [[custom:cornuke-stem2]]
-- definitions['cornuke'].nukeheadring.properties.explosiongenerator = [[custom:cornuke-headring]]
-- definitions['cornuke'].nukehead.properties.explosiongenerator = [[custom:cornuke-head]]

-- definitions['cornuke'].sparks.properties.particlespeed = math.floor(definitions['cornuke'].sparks.properties.particlespeed * size)
-- definitions['cornuke'].sparks.properties.particlespeedspread = math.floor(definitions['cornuke'].sparks.properties.particlespeedspread * size)
-- definitions['cornuke'].dirt.properties.particlespeed = math.floor(definitions['cornuke'].dirt.properties.particlespeed * size)
-- definitions['cornuke'].dirt.properties.particlespeedspread = math.floor(definitions['cornuke'].dirt.properties.particlespeedspread * size)
-- definitions['cornuke'].dirt2.properties.particlespeed = math.floor(definitions['cornuke'].dirt2.properties.particlespeed * size)
-- definitions['cornuke'].dirt2.properties.particlespeedspread = math.floor(definitions['cornuke'].dirt2.properties.particlespeedspread * size)
-- definitions['cornuke'].centerflare.properties.size = math.floor(definitions['cornuke'].centerflare.properties.size * size)
-- definitions['cornuke'].groundflash_large.properties.size = math.floor(definitions['cornuke'].groundflash_large.properties.size * size)
-- definitions['cornuke'].groundflash_white.properties.size = math.floor(definitions['cornuke'].groundflash_white.properties.size * size)


local size = 1.5

definitions['newnukecor-floor'] = table.copy(definitions['newnuke-floor'])
definitions['newnukecor-floor'].smoke.properties.numparticles = math.floor(definitions['newnukecor-floor'].smoke.properties.numparticles * size * 1.3)
definitions['newnukecor-floor'].smoke.properties.particlesize = math.floor(definitions['newnukecor-floor'].smoke.properties.particlesize * size * 1.3)
definitions['newnukecor-floor'].smoke.properties.particlespeed = math.floor(definitions['newnukecor-floor'].smoke.properties.particlespeed * size)
definitions['newnukecor-floor'].smoke.properties.particlespeedspread = math.floor(definitions['newnukecor-floor'].smoke.properties.particlespeedspread * size)
definitions['newnukecor-floor'].smoke3.properties.particlesize = math.floor(definitions['newnukecor-floor'].smoke3.properties.particlesize * size * 1.3)
--
definitions['newnukecor'] = table.copy(definitions['newnuke'])
definitions['newnukecor'].nukefloor.properties.explosiongenerator = [[custom:newnukecor-floor]]

definitions['newnukecor'].sparks.properties.particlespeed = math.floor(definitions['newnukecor'].sparks.properties.particlespeed * size)
definitions['newnukecor'].sparks.properties.particlespeedspread = math.floor(definitions['newnukecor'].sparks.properties.particlespeedspread * size)
definitions['newnukecor'].explosion_flames.properties.particlespeed = math.floor(definitions['newnukecor'].explosion_flames.properties.particlespeed * size)
definitions['newnukecor'].explosion_flames.properties.particlesize = math.floor(definitions['newnukecor'].explosion_flames.properties.particlesize * size)
definitions['newnukecor'].explosion.properties.particlespeed = math.floor(definitions['newnukecor'].explosion.properties.particlespeed * size)
definitions['newnukecor'].explosion.properties.particlesize = math.floor(definitions['newnukecor'].explosion.properties.particlesize * size)
definitions['newnukecor'].dustparticles.properties.particlespeed = math.floor(definitions['newnukecor'].dustparticles.properties.particlespeed * size)
definitions['newnukecor'].dustparticles.properties.particlesize = math.floor(definitions['newnukecor'].dustparticles.properties.particlesize * size)
definitions['newnukecor'].clouddust.properties.particlespeed = math.floor(definitions['newnukecor'].clouddust.properties.particlespeed * size)
definitions['newnukecor'].clouddust.properties.particlesize = math.floor(definitions['newnukecor'].clouddust.properties.particlesize * size)
definitions['newnukecor'].dirt.properties.particlespeed = math.floor(definitions['newnukecor'].dirt.properties.particlespeed * size * 0.7)
definitions['newnukecor'].dirt.properties.particlespeedspread = math.floor(definitions['newnukecor'].dirt.properties.particlespeedspread * size * 0.7)
definitions['newnukecor'].dirt.properties.numparticles = math.floor(definitions['newnukecor'].dirt.properties.numparticles * size)
definitions['newnukecor'].dirt2.properties.particlespeed = math.floor(definitions['newnukecor'].dirt2.properties.particlespeed * size * 0.7)
definitions['newnukecor'].dirt2.properties.particlespeedspread = math.floor(definitions['newnukecor'].dirt2.properties.particlespeedspread * size * 0.7)
definitions['newnukecor'].dirt2.properties.numparticles = math.floor(definitions['newnukecor'].dirt2.properties.numparticles * size)
definitions['newnukecor'].brightflare.properties.ttl = math.floor(definitions['newnukecor'].brightflare.properties.ttl * size * 0.7)
definitions['newnukecor'].shockwave.properties.ttl = math.floor(definitions['newnukecor'].shockwave.properties.ttl * size)
definitions['newnukecor'].shockwave_slow.properties.ttl = math.floor(definitions['newnukecor'].shockwave_slow.properties.ttl * size)
definitions['newnukecor'].shockwave_inner.properties.ttl = math.floor(definitions['newnukecor'].shockwave_inner.properties.ttl * size)
-- definitions['newnukecor'].centerflare.properties.size = math.floor(definitions['newnukecor'].centerflare.properties.size * size * 1.2)
-- definitions['newnukecor'].centerflare.properties.heat = math.floor(definitions['newnukecor'].centerflare.properties.heat * size * 0.85)
-- definitions['newnukecor'].centerflare.properties.maxheat = math.floor(definitions['newnukecor'].centerflare.properties.maxheat * size)
definitions['newnukecor'].centerflare.properties.size = [[48 r7]]
definitions['newnukecor'].centerflare.properties.heat = math.floor(definitions['newnukecor'].centerflare.properties.heat * size * 0.85)
definitions['newnukecor'].centerflare.properties.maxheat = math.floor(definitions['newnukecor'].centerflare.properties.maxheat * size)
definitions['newnukecor'].groundflash_large.properties.size = math.floor(definitions['newnukecor'].groundflash_large.properties.size * size)
definitions['newnukecor'].groundflash_white.properties.size = math.floor(definitions['newnukecor'].groundflash_white.properties.size * size)
definitions['newnukecor'].groundflash_quick.properties.size = math.floor(definitions['newnukecor'].groundflash_quick.properties.size * size)
definitions['newnukecor'].bigsmoketrails.properties.size = [[226 r45]]
definitions['newnukecor'].bigsmoketrails.properties.length = [[310 r45]]
definitions['newnukecor'].bigsmoketrails.count = 7

local size = 2.2

definitions['newnukehuge-floor'] = table.copy(definitions['newnuke-floor'])
definitions['newnukehuge-floor'].smoke.properties.numparticles = math.floor(definitions['newnukehuge-floor'].smoke.properties.numparticles * size)
definitions['newnukehuge-floor'].smoke.properties.particlespeed = math.floor(definitions['newnukehuge-floor'].smoke.properties.particlespeed * size)
definitions['newnukehuge-floor'].smoke.properties.particlespeedspread = math.floor(definitions['newnukehuge-floor'].smoke.properties.particlespeedspread * size)
--
definitions['newnukehuge'] = table.copy(definitions['newnuke'])
definitions['newnukehuge'].nukefloor.properties.explosiongenerator = [[custom:newnukehuge-floor]]

definitions['newnukehuge'].sparks.properties.particlespeed = math.floor(definitions['newnukehuge'].sparks.properties.particlespeed * size)
definitions['newnukehuge'].sparks.properties.particlespeedspread = math.floor(definitions['newnukehuge'].sparks.properties.particlespeedspread * size)
definitions['newnukehuge'].explosion_flames.properties.particlespeed = math.floor(definitions['newnukehuge'].explosion_flames.properties.particlespeed * size)
definitions['newnukehuge'].explosion_flames.properties.particlesize = math.floor(definitions['newnukehuge'].explosion_flames.properties.particlesize * size)
definitions['newnukehuge'].explosion.properties.particlespeed = math.floor(definitions['newnukehuge'].explosion.properties.particlespeed * size)
definitions['newnukehuge'].explosion.properties.particlesize = math.floor(definitions['newnukehuge'].explosion.properties.particlesize * size)
definitions['newnukehuge'].dustparticles.properties.particlespeed = math.floor(definitions['newnukehuge'].dustparticles.properties.particlespeed * size)
definitions['newnukehuge'].dustparticles.properties.particlesize = math.floor(definitions['newnukehuge'].dustparticles.properties.particlesize * size)
definitions['newnukehuge'].clouddust.properties.particlespeed = math.floor(definitions['newnukehuge'].clouddust.properties.particlespeed * size)
definitions['newnukehuge'].clouddust.properties.particlesize = math.floor(definitions['newnukehuge'].clouddust.properties.particlesize * size)
definitions['newnukehuge'].dirt.properties.particlespeed = math.floor(definitions['newnukehuge'].dirt.properties.particlespeed * size * 0.7)
definitions['newnukehuge'].dirt.properties.particlespeedspread = math.floor(definitions['newnukehuge'].dirt.properties.particlespeedspread * size * 0.7)
definitions['newnukehuge'].dirt.properties.numparticles = math.floor(definitions['newnukehuge'].dirt.properties.numparticles * size)
definitions['newnukehuge'].dirt2.properties.particlespeed = math.floor(definitions['newnukehuge'].dirt2.properties.particlespeed * size * 0.7)
definitions['newnukehuge'].dirt2.properties.particlespeedspread = math.floor(definitions['newnukehuge'].dirt2.properties.particlespeedspread * size * 0.7)
definitions['newnukehuge'].dirt2.properties.numparticles = math.floor(definitions['newnukehuge'].dirt2.properties.numparticles * size)
definitions['newnukehuge'].brightflare.properties.ttl = math.floor(definitions['newnukehuge'].brightflare.properties.ttl * size)
definitions['newnukehuge'].shockwave.properties.ttl = math.floor(definitions['newnukehuge'].shockwave.properties.ttl * size) * 0.7
definitions['newnukehuge'].shockwave_slow.properties.ttl = math.floor(definitions['newnukehuge'].shockwave_slow.properties.ttl * size)
definitions['newnukehuge'].shockwave_inner.properties.ttl = math.floor(definitions['newnukehuge'].shockwave_inner.properties.ttl * size)
definitions['newnukehuge'].centerflare.properties.size = [[64 r9]]
definitions['newnukehuge'].centerflare.properties.heat = math.floor(definitions['newnukehuge'].centerflare.properties.heat * size * 0.7)
definitions['newnukehuge'].centerflare.properties.maxheat = math.floor(definitions['newnukehuge'].centerflare.properties.maxheat * size * 0.7)
definitions['newnukehuge'].groundflash_large.properties.size = math.floor(definitions['newnukehuge'].groundflash_large.properties.size * size)
definitions['newnukehuge'].groundflash_white.properties.size = math.floor(definitions['newnukehuge'].groundflash_white.properties.size * size)

local size = 0.48

definitions['newnuketac-floor'] = table.copy(definitions['newnuke-floor'])
definitions['newnuketac-floor'].smoke.properties.numparticles = math.floor(definitions['newnuketac-floor'].smoke.properties.numparticles * size * 0.8)
definitions['newnuketac-floor'].smoke.properties.particlespeed = math.floor(definitions['newnuketac-floor'].smoke.properties.particlespeed * size * 0.4)
definitions['newnuketac-floor'].smoke.properties.particlespeedspread = math.floor(definitions['newnuketac-floor'].smoke.properties.particlespeedspread * size * 0.4)
definitions['newnuketac-floor'].smoke.properties.particlesize = math.floor(definitions['newnuketac-floor'].smoke.properties.particlesize * size * 0.4)
definitions['newnuketac-floor'].smoke.properties.particlelife = math.floor(definitions['newnuketac-floor'].smoke.properties.particlelife * size * 0.4)
definitions['newnuketac-floor'].smoke2.properties.particlelife = math.floor(definitions['newnuketac-floor'].smoke2.properties.particlelife * size * 0.4)
definitions['newnuketac-floor'].smoke2.properties.particlespeed = math.floor(definitions['newnuketac-floor'].smoke2.properties.particlespeed * size * 0.4)
definitions['newnuketac-floor'].smoke2.properties.particlesize = math.floor(definitions['newnuketac-floor'].smoke2.properties.particlesize * size * 0.4)
definitions['newnuketac-floor'].smoke3.properties.particlespeed = math.floor(definitions['newnuketac-floor'].smoke3.properties.particlespeed * size * 0.5)
definitions['newnuketac-floor'].smoke3.properties.particlesize = math.floor(definitions['newnuketac-floor'].smoke3.properties.particlesize * size * 0.4)
definitions['newnuketac-floor'].smoke3.properties.particlelife = math.floor(definitions['newnuketac-floor'].smoke3.properties.particlelife * size * 0.6)
--
definitions['newnuketac'] = table.copy(definitions['newnuke'])
definitions['newnuketac'].nukefloor.properties.explosiongenerator = [[custom:newnuketac-floor]]
definitions['newnuketac'].nukefloor.properties.delay = [[10 i0.5]]

definitions['newnuketac'].sparks.properties.particlespeed = math.floor(definitions['newnuketac'].sparks.properties.particlespeed * size * 1.2)
definitions['newnuketac'].sparks.properties.particlespeedspread = math.floor(definitions['newnuketac'].sparks.properties.particlespeedspread * size)
definitions['newnuketac'].sparks.properties.particlelife = math.floor(definitions['newnuketac'].sparks.properties.particlelife * size * 0.6)
definitions['newnuketac'].explosion_flames.properties.particlespeed = math.floor(definitions['newnuketac'].explosion_flames.properties.particlespeed * 0.6)
definitions['newnuketac'].explosion_flames.properties.particlesize = math.floor(definitions['newnuketac'].explosion_flames.properties.particlesize * size * 0.7)
--definitions['newnuketac'].explosion_flames.properties.numparticles = math.floor(definitions['newnuketac'].explosion_flames.properties.numparticles * size)
definitions['newnuketac'].explosion_flames.properties.particlelife = math.floor(definitions['newnuketac'].explosion_flames.properties.particlelife * size)
definitions['newnuketac'].explosion.properties.particlespeed = math.floor(definitions['newnuketac'].explosion.properties.particlespeed * size * 0.7)
definitions['newnuketac'].explosion.properties.particlesize = math.floor(definitions['newnuketac'].explosion.properties.particlesize * size * 0.7)
definitions['newnuketac'].explosion.properties.particlelife = math.floor(definitions['newnuketac'].explosion.properties.particlelife * size)
definitions['newnuketac'].dustparticles.properties.particlespeed = math.floor(definitions['newnuketac'].dustparticles.properties.particlespeed * size * 0.6)
definitions['newnuketac'].dustparticles.properties.particlesize = math.floor(definitions['newnuketac'].dustparticles.properties.particlesize * size * 0.5)
definitions['newnuketac'].dustparticles.properties.particlelife = math.floor(definitions['newnuketac'].dustparticles.properties.particlelife * size * 0.5)
definitions['newnuketac'].clouddust.properties.particlespeed = math.floor(definitions['newnuketac'].clouddust.properties.particlespeed * size)
definitions['newnuketac'].clouddust.properties.particlesize = math.floor(definitions['newnuketac'].clouddust.properties.particlesize * size)
definitions['newnuketac'].clouddust.properties.particlelife = math.floor(definitions['newnuketac'].clouddust.properties.particlelife * size * 0.5)

definitions['newnuketac'].dirt.properties.particlespeed = math.floor(definitions['newnuketac'].dirt.properties.particlespeed * size * 0.8)
definitions['newnuketac'].dirt.properties.particlespeedspread = math.floor(definitions['newnuketac'].dirt.properties.particlespeedspread * size * 0.9)
definitions['newnuketac'].dirt.properties.numparticles = math.floor(definitions['newnuketac'].dirt.properties.numparticles * size)
definitions['newnuketac'].dirt2.properties.particlelife = math.floor(definitions['newnuketac'].dirt2.properties.particlelife * size * 0.8)
definitions['newnuketac'].dirt2.properties.particlespeed = math.floor(definitions['newnuketac'].dirt2.properties.particlespeed * size * 0.9)
definitions['newnuketac'].dirt2.properties.particlespeedspread = math.floor(definitions['newnuketac'].dirt2.properties.particlespeedspread * size * 0.9)
definitions['newnuketac'].dirt2.properties.numparticles = math.floor(definitions['newnuketac'].dirt2.properties.numparticles * size)
definitions['newnuketac'].dirt3.properties.particlespeed = math.floor(definitions['newnuketac'].dirt3.properties.particlespeed * size * 0.9)
definitions['newnuketac'].dirt3.properties.particlespeedspread = math.floor(definitions['newnuketac'].dirt3.properties.particlespeedspread * size * 0.9)
definitions['newnuketac'].dirt3.properties.numparticles = math.floor(definitions['newnuketac'].dirt3.properties.numparticles * size)
definitions['newnuketac'].brightflare.properties.ttl = math.floor(definitions['newnuketac'].brightflare.properties.ttl * size) * 0.4
definitions['newnuketac'].brightflare.properties.size = math.floor(definitions['newnuketac'].brightflare.properties.size * size) * 0.4
definitions['newnuketac'].brightflareslow.properties.ttl = math.floor(definitions['newnuketac'].brightflareslow.properties.ttl * size)
definitions['newnuketac'].brightflareslow.properties.size = math.floor(definitions['newnuketac'].brightflareslow.properties.size * size)
definitions['newnuketac'].shockwave.properties.ttl = math.floor(definitions['newnuketac'].shockwave.properties.ttl * size * 0.7)
definitions['newnuketac'].shockwave.properties.size = math.floor(definitions['newnuketac'].shockwave.properties.size * size * 1.2)
definitions['newnuketac'].shockwave_slow.properties.ttl = math.floor(definitions['newnuketac'].shockwave_slow.properties.ttl * size * 0.8)
definitions['newnuketac'].shockwave_slow.properties.size = math.floor(definitions['newnuketac'].shockwave_slow.properties.size * size * 1.3)
definitions['newnuketac'].shockwave_inner.properties.ttl = math.floor(definitions['newnuketac'].shockwave_inner.properties.ttl * size * 0.8)
definitions['newnuketac'].shockwave_inner.properties.size = math.floor(definitions['newnuketac'].shockwave_inner.properties.size * size * 0.4)
definitions['newnuketac'].centerflare.properties.size = [[24 r4]]
definitions['newnuketac'].centerflare.properties.heat = math.floor(definitions['newnuketac'].centerflare.properties.heat * size * 1.05)
definitions['newnuketac'].centerflare.properties.maxheat = math.floor(definitions['newnuketac'].centerflare.properties.maxheat * size * 1.05)
definitions['newnuketac'].groundflash_large.properties.size = math.floor(definitions['newnuketac'].groundflash_large.properties.size * size * 0.8)
definitions['newnuketac'].groundflash_white.properties.size = math.floor(definitions['newnuketac'].groundflash_white.properties.size * size * 0.8)
definitions['newnuketac'].groundflash_quick.properties.size = math.floor(definitions['newnuketac'].groundflash_quick.properties.size * size * 0.8)
definitions['newnuketac'].groundflash_quick.properties.ttl = math.floor(definitions['newnuketac'].groundflash_quick.properties.ttl * size * 0.6)
definitions['newnuketac'].groundflash_quick.properties.sizegrowth = math.floor(definitions['newnuketac'].groundflash_quick.properties.sizegrowth * size * 0.8)
definitions['newnuketac'].grounddust.properties.particlesize = math.floor(definitions['newnuketac'].grounddust.properties.particlesize * size)
definitions['newnuketac'].grounddust.properties.particlespeed = math.floor(definitions['newnuketac'].grounddust.properties.particlespeed * size)
definitions['newnuketac'].grounddust.properties.particlespeedspread = math.floor(definitions['newnuketac'].grounddust.properties.particlespeedspread * size)
definitions['newnuketac'].grounddust.properties.particlelife = math.floor(definitions['newnuketac'].grounddust.properties.particlelife * size * 0.5)
definitions['newnuketac'].bigsmoketrails.properties.size = [[130 r25]]
definitions['newnuketac'].bigsmoketrails.properties.length = [[170 r25]]
definitions['newnuketac'].bigsmoketrails.count = 3

local size = 0.6

definitions['chickennuke-floor'] = table.copy(definitions['armnuke-floor'])
definitions['chickennuke-floor'].smoke.properties.numparticles = math.floor(definitions['chickennuke-floor'].smoke.properties.numparticles * size)
definitions['chickennuke-floor'].smoke.properties.particlespeedspread = math.floor(definitions['chickennuke-floor'].smoke.properties.particlespeedspread * size)
definitions['chickennuke-stem'] = table.copy(definitions['armnuke-stem'])
definitions['chickennuke-stem'].smoke.properties.particlesize = math.floor(definitions['chickennuke-stem'].smoke.properties.particlesize * size)
definitions['chickennuke-stem2'] = table.copy(definitions['armnuke-stem2'])
definitions['chickennuke-stem2'].smoke.properties.particlesize = math.floor(definitions['chickennuke-stem2'].smoke.properties.particlesize * size)
definitions['chickennuke-headring'] = table.copy(definitions['armnuke-headring'])
definitions['chickennuke-headring'].smoke.properties.numparticles = math.floor(definitions['chickennuke-headring'].smoke.properties.numparticles * size)
definitions['chickennuke-headring'].smoke.properties.particlespeedspread = math.floor(definitions['chickennuke-headring'].smoke.properties.particlespeedspread * size)
definitions['chickennuke-headring'].smoke.properties.particlesize = math.floor(definitions['chickennuke-headring'].smoke.properties.particlesize * size)
definitions['chickennuke-head'] = table.copy(definitions['armnuke-head'])
definitions['chickennuke-head'].smoke.properties.numparticles = math.floor(definitions['chickennuke-head'].smoke.properties.numparticles * size)
definitions['chickennuke-head'].smoke.properties.particlespeedspread = math.floor(definitions['chickennuke-head'].smoke.properties.particlespeedspread * size)
definitions['chickennuke-head'].smoke.properties.particlesize = math.floor(definitions['chickennuke-head'].smoke.properties.particlesize * size)
--
definitions['chickennuke'] = table.copy(definitions['armnuke'])
definitions['chickennuke'].nukefloor.properties.explosiongenerator = [[custom:chickennuke-floor]]
definitions['chickennuke'].nukestem.properties.explosiongenerator = [[custom:chickennuke-stem]]
definitions['chickennuke'].nukestem2.properties.explosiongenerator = [[custom:chickennuke-stem2]]
definitions['chickennuke'].nukeheadring.properties.explosiongenerator = [[custom:chickennuke-headring]]
definitions['chickennuke'].nukehead.properties.explosiongenerator = [[custom:chickennuke-head]]

definitions['chickennuke'].sparks.properties.particlespeed = math.floor(definitions['chickennuke'].sparks.properties.particlespeed * size)
definitions['chickennuke'].sparks.properties.particlespeedspread = math.floor(definitions['chickennuke'].sparks.properties.particlespeedspread * size)
definitions['chickennuke'].dirt.properties.particlespeed = math.floor(definitions['chickennuke'].dirt.properties.particlespeed * size)
definitions['chickennuke'].dirt.properties.particlespeedspread = math.floor(definitions['chickennuke'].dirt.properties.particlespeedspread * size)
definitions['chickennuke'].dirt2.properties.particlespeed = math.floor(definitions['chickennuke'].dirt2.properties.particlespeed * size)
definitions['chickennuke'].dirt2.properties.particlespeedspread = math.floor(definitions['chickennuke'].dirt2.properties.particlespeedspread * size)
definitions['chickennuke'].centerflare.properties.size = [[15 r4]]
definitions['chickennuke'].groundflash_large.properties.size = math.floor(definitions['chickennuke'].groundflash_large.properties.size * size)
definitions['chickennuke'].groundflash_white.properties.size = math.floor(definitions['chickennuke'].groundflash_white.properties.size * size)


return definitions
