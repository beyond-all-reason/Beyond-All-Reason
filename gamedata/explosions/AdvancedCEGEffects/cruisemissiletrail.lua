-- cruisemissiletrail

local definitions = {
	["cruisemissiletrail"] = {
    groundflash = {
      circlealpha        = 0,
      circlegrowth       = 0,
      flashalpha         = 0.13,
      flashsize          = 90,
      ttl                = 10,
      color = {
        [1]  = 0.80000001192093,
        [2]  = 0.50000000149012,
        [3]  = 0.15,
      },
    },
    smokeandfire = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 1,
        colormap           = [[0.7 0.6 0.45 0.2   0.44 0.33 0.06 0.2    0.34 0.15 0 0.15    0.09 0.025 0 0.11     0.05 0.01 0 0.09   0.02 0.008 0 0.06   0 0 0 0.01]],
        directional        = true,
        emitrot            = 180,
        emitrotspread      = 7,
        emitvector         = [[dir]],
        gravity            = [[0.0, 0.01, 0.0]],
        numparticles       = 6,
        particlelife       = 8,
        particlelifespread = 3,
        particlesize       = 7.5,
        particlesizespread = 4.5,
        particlespeed      = 3,
        particlespeedspread = 10,
        pos                = [[0.0, 0, 0.0]],
        sizegrowth         = -0.5,
        sizemod            = 1,
        texture            = [[dirt]],
        useairlos          = true,
      },
    },
    sparks = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.9,
        colormap           = [[0.9 0.5 0.4 0.01   0.9 0.4 0.1 0.007  0.5 0.1 0.1 0]],
        directional        = true,
        emitrot            = 180,
        emitrotspread      = 7,
        emitvector         = [[dir]],
        gravity            = [[0, -0.03, 0]],
        numparticles       = 2,
        particlelife       = 3,
        particlelifespread = 5,
        particlesize       = 60,
        particlesizespread = 60,
        particlespeed      = 13,
        particlespeedspread = 6,
        pos                = [[0, 0, 0]],
        sizegrowth         = -3,
        sizemod            = 0.8,
        texture            = [[gunshotglow]],
        useairlos          = false,
      },
    },
    fireglow = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 1,
        colormap           = [[0.07 0.038 0.007 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 180,
        emitrotspread      = 0,
        emitvector         = [[dir]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 1,
        particlelife       = 7,
        particlelifespread = 0,
        particlesize       = 90,
        particlesizespread = 16,
        particlespeed      = 20,
        particlespeedspread = 0,
        pos                = [[0.0, 0, 0.0]],
        sizegrowth         = -0.5,
        sizemod            = 1,
        texture            = [[dirt]],
        useairlos          = true,
      },
    },
    exhale4 = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.92,
        colormap           = [[0.03 0.03 0.03 0.12   0.07 0.07 0.07 0.3   0.11 0.11 0.11 0.25   0.06 0.06 0.06 0.17    0.035 0.035 0.035 0.09   0 0 0 0.01]],
        directional        = true,
        emitrot            = 180,
        emitrotspread      = 5,
        emitvector         = [[dir]],
        gravity            = [[0.0, -0.03, 0.0]],
        numparticles       = 1,
        particlelife       = 45,
        particlelifespread = 25,
        particlesize       = 6,
        particlesizespread = 5,
        particlespeed      = 3,
        particlespeedspread = 6,
        pos                = [[0.0, 1, 0.0]],
        sizegrowth         = 0.15,
        sizemod            = 1,
        texture            = [[dirt]],
        useairlos          = true,
      },
    },
    exhale = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.92,
        colormap           = [[0.03 0.03 0.03 0.07  0.1 0.1 0.1 0.2   0.1 0.1 0.1 0.15   0.098 0.08 0.08 0.1    0.05 0.05 0.05 0.05   0 0 0 0]],
        directional        = true,
        emitrot            = 180,
        emitrotspread      = 13,
        emitvector         = [[dir]],
        gravity            = [[0, -0.04, 0]],
        numparticles       = 1,
        particlelife       = 40,
        particlelifespread = 25,
        particlesize       = 6,
        particlesizespread = 3,
        particlespeed      = 2,
        particlespeedspread = 5,
        pos                = [[0, 1, 0]],
        sizegrowth         = 0.15,
        sizemod            = 1,
        texture            = [[bigexplosmoke]],
      },
    },
    dustparticles = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      underwater         = true,
      water              = true,
      properties = {
        airdrag            = 0.8,
        colormap           = [[0.4 0.4 0.4 0.008    1 0.75 0.5 0.02    0.66 0.37 0.3 0.18    0.5 0.27 0.22 0.15    0.33 0.18 0.18 0.15    0 0 0 0.01]],
        directional        = true,
        emitrot            = 80,
        emitrotspread      = 9,
        emitvector         = [[1, 1, 1]],
        gravity            = [[0, -0.011, 0]],
        numparticles       = 2,
        particlelife       = 20,
        particlelifespread = 8,
        particlesize       = 7,
        particlesizespread = 1.75,
        particlespeed      = 0.04,
        particlespeedspread = 0.12,
        pos                = [[0, 0, 0]],
        sizegrowth         = 0.01,
        sizemod            = 1.0,
        texture            = [[randomdots]],
      },
    },
	--dustparticles2 = {
    --  air                = true,
    --  class              = [[CSimpleParticleSystem]],
    --  count              = 1,
    --  ground             = true,
    --  underwater         = true,
    --  water              = true,
    --  properties = {
    --    airdrag            = 0.77,
    --    colormap           = [[0.55 0.55 0.55 0.02    0.4 0.4 0.4 0.13    0.15 0.15 0.15 0.08    0 0 0 0]],
    --    directional        = false,
    --    emitrot            = 80,
    --    emitrotspread      = 5,
    --    emitvector         = [[1, 1, 1]],
    --    gravity            = [[0, -0.015, 0]],
    --    numparticles       = 2,
    --    particlelife       = 38,
    --    particlelifespread = 9,
    --    particlesize       = 4.2,
    --    particlesizespread = 1,
    --    particlespeed      = 0.24,
    --    particlespeedspread = 0.11,
    --    pos                = [[0, 1, 0]],
    --    sizegrowth         = 0.033,
    --    sizemod            = 1.0,
    --    texture            = [[randomdots]],
    --  },
    --},
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

definitions["cruisemissiletrail-emp"] = deepcopy(definitions["cruisemissiletrail"])
definitions["cruisemissiletrail-emp"].smokeandfire.properties.colormap = [[0.7 0.6 0.7 0.2   0.44 0.33 0.5 0.2    0.34 0.15 0.4 0.15    0.09 0.025 0.11 0.11     0.05 0.01 0.065 0.09   0.02 0.01 0.2 0.06   0 0 0 0.01]]
definitions["cruisemissiletrail-emp"].fireglow.properties.colormap = [[0.05 0.027 0.07 0.01   0 0 0 0.01]]
definitions["cruisemissiletrail-emp"].sparks.properties.colormap = [[0.9 0.5 0.9 0.01   0.8 0.4 0.9 0.007  0.5 0.1 0.65 0]]

definitions["cruisemissiletrail-tacnuke"] = deepcopy(definitions["cruisemissiletrail"])
definitions["cruisemissiletrail-tacnuke"].smokeandfire.properties.colormap = [[0.7 0.6 0.45 0.2   0.44 0.33 0.06 0.2    0.34 0.15 0 0.15    0.09 0.025 0 0.11     0.05 0.01 0 0.09   0.024 0.01 0 0.065   0.014 0.002 0 0.03   0 0 0 0.01]]

return definitions
