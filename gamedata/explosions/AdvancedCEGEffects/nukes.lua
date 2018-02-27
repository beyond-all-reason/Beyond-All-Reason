-- nukedatbewm
local definitions = {
    ["armnuke"] = {
        centerflare = {
            air                = true,
            class              = [[heatcloud]],
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
                particlelife       = 16,
                particlelifespread = 9,
                particlesize       = 16,
                particlesizespread = 30,
                particlespeed      = 5,
                particlespeedspread = 7,
                pos                = [[0, 15, 0]],
                sizegrowth         = 0.3,
                sizemod            = 1,
                texture            = [[flashside2]],
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

function deepcopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[deepcopy(orig_key)] = deepcopy(orig_value)
    end
    setmetatable(copy, deepcopy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

local size = 1.5

definitions['cornuke-floor'] = deepcopy(definitions['armnuke-floor'])
definitions['cornuke-floor'].smoke.properties.numparticles = math.floor(definitions['cornuke-floor'].smoke.properties.numparticles * size)
definitions['cornuke-floor'].smoke.properties.particlespeedspread = math.floor(definitions['cornuke-floor'].smoke.properties.particlespeedspread * size)
definitions['cornuke-stem'] = deepcopy(definitions['armnuke-stem'])
definitions['cornuke-stem'].smoke.properties.particlesize = math.floor(definitions['cornuke-stem'].smoke.properties.particlesize * size)
definitions['cornuke-stem2'] = deepcopy(definitions['armnuke-stem2'])
definitions['cornuke-stem2'].smoke.properties.particlesize = math.floor(definitions['cornuke-stem2'].smoke.properties.particlesize * size)
definitions['cornuke-headring'] = deepcopy(definitions['armnuke-headring'])
definitions['cornuke-headring'].smoke.properties.numparticles = math.floor(definitions['cornuke-headring'].smoke.properties.numparticles * size)
definitions['cornuke-headring'].smoke.properties.particlespeedspread = math.floor(definitions['cornuke-headring'].smoke.properties.particlespeedspread * size)
definitions['cornuke-headring'].smoke.properties.particlesize = math.floor(definitions['cornuke-headring'].smoke.properties.particlesize * size)
definitions['cornuke-head'] = deepcopy(definitions['armnuke-head'])
definitions['cornuke-head'].smoke.properties.numparticles = math.floor(definitions['cornuke-head'].smoke.properties.numparticles * size)
definitions['cornuke-head'].smoke.properties.particlespeedspread = math.floor(definitions['cornuke-head'].smoke.properties.particlespeedspread * size)
definitions['cornuke-head'].smoke.properties.particlesize = math.floor(definitions['cornuke-head'].smoke.properties.particlesize * size)
--
definitions['cornuke'] = deepcopy(definitions['armnuke'])
definitions['cornuke'].nukefloor.properties.explosiongenerator = [[custom:cornuke-floor]]
definitions['cornuke'].nukestem.properties.explosiongenerator = [[custom:cornuke-stem]]
definitions['cornuke'].nukestem2.properties.explosiongenerator = [[custom:cornuke-stem2]]
definitions['cornuke'].nukeheadring.properties.explosiongenerator = [[custom:cornuke-headring]]
definitions['cornuke'].nukehead.properties.explosiongenerator = [[custom:cornuke-head]]

definitions['cornuke'].sparks.properties.particlespeed = math.floor(definitions['cornuke'].sparks.properties.particlespeed * size)
definitions['cornuke'].sparks.properties.particlespeedspread = math.floor(definitions['cornuke'].sparks.properties.particlespeedspread * size)
definitions['cornuke'].dirt.properties.particlespeed = math.floor(definitions['cornuke'].dirt.properties.particlespeed * size)
definitions['cornuke'].dirt.properties.particlespeedspread = math.floor(definitions['cornuke'].dirt.properties.particlespeedspread * size)
definitions['cornuke'].dirt2.properties.particlespeed = math.floor(definitions['cornuke'].dirt2.properties.particlespeed * size)
definitions['cornuke'].dirt2.properties.particlespeedspread = math.floor(definitions['cornuke'].dirt2.properties.particlespeedspread * size)
definitions['cornuke'].centerflare.properties.size = math.floor(definitions['cornuke'].centerflare.properties.size * size)
definitions['cornuke'].groundflash_large.properties.size = math.floor(definitions['cornuke'].groundflash_large.properties.size * size)
definitions['cornuke'].groundflash_white.properties.size = math.floor(definitions['cornuke'].groundflash_white.properties.size * size)



local size = 0.6

definitions['chickennuke-floor'] = deepcopy(definitions['armnuke-floor'])
definitions['chickennuke-floor'].smoke.properties.numparticles = math.floor(definitions['chickennuke-floor'].smoke.properties.numparticles * size)
definitions['chickennuke-floor'].smoke.properties.particlespeedspread = math.floor(definitions['chickennuke-floor'].smoke.properties.particlespeedspread * size)
definitions['chickennuke-stem'] = deepcopy(definitions['armnuke-stem'])
definitions['chickennuke-stem'].smoke.properties.particlesize = math.floor(definitions['chickennuke-stem'].smoke.properties.particlesize * size)
definitions['chickennuke-stem2'] = deepcopy(definitions['armnuke-stem2'])
definitions['chickennuke-stem2'].smoke.properties.particlesize = math.floor(definitions['chickennuke-stem2'].smoke.properties.particlesize * size)
definitions['chickennuke-headring'] = deepcopy(definitions['armnuke-headring'])
definitions['chickennuke-headring'].smoke.properties.numparticles = math.floor(definitions['chickennuke-headring'].smoke.properties.numparticles * size)
definitions['chickennuke-headring'].smoke.properties.particlespeedspread = math.floor(definitions['chickennuke-headring'].smoke.properties.particlespeedspread * size)
definitions['chickennuke-headring'].smoke.properties.particlesize = math.floor(definitions['chickennuke-headring'].smoke.properties.particlesize * size)
definitions['chickennuke-head'] = deepcopy(definitions['armnuke-head'])
definitions['chickennuke-head'].smoke.properties.numparticles = math.floor(definitions['chickennuke-head'].smoke.properties.numparticles * size)
definitions['chickennuke-head'].smoke.properties.particlespeedspread = math.floor(definitions['chickennuke-head'].smoke.properties.particlespeedspread * size)
definitions['chickennuke-head'].smoke.properties.particlesize = math.floor(definitions['chickennuke-head'].smoke.properties.particlesize * size)
--
definitions['chickennuke'] = deepcopy(definitions['armnuke'])
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
definitions['chickennuke'].centerflare.properties.size = math.floor(definitions['chickennuke'].centerflare.properties.size * size)
definitions['chickennuke'].groundflash_large.properties.size = math.floor(definitions['chickennuke'].groundflash_large.properties.size * size)
definitions['chickennuke'].groundflash_white.properties.size = math.floor(definitions['chickennuke'].groundflash_white.properties.size * size)

return definitions
