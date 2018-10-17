
local definitions = {
  ["reclaimshards1"] = {
    groundflash = {
      flashalpha         = 0.03,
      flashsize          = 40,
      ttl                = 9,
      color = {
        [1]  = 1,
        [2]  = 1,
        [3]  = 1,
      },
    },
    shards = {
        class = [[CSimpleParticleSystem]],
        count = 1,
        air = true,
        water = true,
        ground = true,
        count = true,
        properties = {
            airdrag = 0.9,
            directional = true,
            emitRot = 30,
            emitRotSpread = 30,
            emitVector = [[0, 0.8, 0]],
            gravity = [[0, 0.03, 0]],
            colorMap = [[0.6 0.6 0.6 1   0.2 0.2 0.2 1]],
            numParticles = [[0.2 r1.2]],
            particleLife = 16,
            particleLifeSpread = 12,
            particleSpeed = 2.5,
            particleSpeedSpread = 1.7,
            particleSize = 2.6,
            particleSizeSpread = 1.8,
            pos = [[0, -0.5, 0]],
            sizeGrowth = -0.16,
            sizeMod = 1,
            texture = [[shard1]],
        },
    },
    dirt = {
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      unit               = false,
      properties = {
        airdrag            = 1,
        colormap           = [[0.3 0.3 0.3 0.7   0.3 0.3 0.3 0.6   0 0 0 0]],
        directional        = true,
        emitrot            = 12,
        emitrotspread      = 33,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.3, 0]],
        numparticles       = [[0.35 r1]],
        particlelife       = 15,
        particlelifespread = 8,
        particlesize       = 1.2,
        particlesizespread = -1,
        particlespeed      = 1.6,
        particlespeedspread = 2.2,
        pos                = [[0, 4, 0]],
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
      unit               = false,
      properties = {
        airdrag            = 1,
        colormap           = [[0.3 0.3 0.3 0.7   0.3 0.3 0.3 0.6   0 0 0 0]],
        directional        = true,
        emitrot            = 0,
        emitrotspread      = 12,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.3, 0]],
        numparticles       = [[0.1 r1]],
        particlelife       = 25,
        particlelifespread = 10,
        particlesize       = 1.2,
        particlesizespread = -1,
        particlespeed      = 1.5,
        particlespeedspread = 2.6,
        pos                = [[0, 4, 0]],
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
        airdrag            = 0.92,
        colormap           = [[0.022 0.022 0.022 0.03  0.05 0.05 0.05 0.068  0.042 0.042 0.042 0.052  0.023 0.023 0.023 0.028  0 0 0 0]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 3,
        emitvector         = [[0.25, 0.8, 0.25]],
        gravity            = [[0, 0.02, 0]],
        numparticles       = [[0.2 r1]],
        particlelife       = 40,
        particlelifespread = 75,
        particlesize       = 13,
        particlesizespread = 16,
        particlespeed      = 4,
        particlespeedspread = 4,
        pos                = [[0, 6, 0]],
        sizegrowth         = 0.5,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
      },
    },
    grounddust = {
      air                = false,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      unit               = false,
      properties = {
        airdrag            = 0.92,
        colormap           = [[0.09 0.09 0.09 0.14 	0 0 0 0.0]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = -2,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.1, 0]],
        numparticles       = 3,
        particlelife       = 5,
        particlelifespread = 22,
        particlesize       = 3.5,
        particlesizespread = 1.5,
        particlespeed      = 0.8,
        particlespeedspread = 2,
        pos                = [[0, 0, 0]],
        sizegrowth         = 0.15,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
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

definitions["reclaimshards2"] = deepcopy(definitions["reclaimshards1"])
definitions["reclaimshards2"].shards.properties.texture = [[shard2]]
definitions["reclaimshards3"] = deepcopy(definitions["reclaimshards1"])
definitions["reclaimshards3"].shards.properties.texture = [[shard3]]

definitions["metalshards1"] = deepcopy(definitions["reclaimshards1"])
definitions["metalshards2"] = deepcopy(definitions["reclaimshards2"])
definitions["metalshards3"] = deepcopy(definitions["reclaimshards3"])

definitions["energyshards1"] = deepcopy(definitions["reclaimshards1"])
definitions["energyshards2"] = deepcopy(definitions["reclaimshards2"])
definitions["energyshards3"] = deepcopy(definitions["reclaimshards3"])
definitions["energyshards1"].shards.properties.colorMap = [[0.2 1 0.2 1   0.1 0.5 0.1 0.5]]
definitions["energyshards2"].shards.properties.colorMap = [[0.2 1 0.2 1   0.1 0.5 0.1 0.5]]
definitions["energyshards3"].shards.properties.colorMap = [[0.2 1 0.2 1   0.1 0.5 0.1 0.5]]

return definitions
