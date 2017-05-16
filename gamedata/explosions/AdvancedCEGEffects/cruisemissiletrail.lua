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
    fire = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.25,
                colormap           = [[0.9 0.7 0.33 0.15   0.44 0.26 0.09 0.2    0.27 0.055 0 0.17    0.08 0.03 0 0.11    0.02 0.0066 0 0.06	 0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.1, 0.0]],
        numparticles       = 15,
        particlelife       = 18,
        particlelifespread = 13,
        particlesize       = 3.5,
        particlesizespread = 3.5,
        particlespeed      = 1.6,
        particlespeedspread = 5,
        pos                = [[0.0, 2, 0.0]],
        sizegrowth         = -0.19,
        sizemod            = 0.9,
        texture            = [[dirt]],
        useairlos          = true,
      },
    },
    searingflame = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.5,
                colormap           = [[0.9 0.7 0.6 0.04   0.9 0.4 0.1 0.01  0.5 0.1 0.1 0.01]],
        directional        = true,
        emitrot            = 0,
        emitrotspread      = 180,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.01, 0]],
        numparticles       = 8,
        particlelife       = 5,
        particlelifespread = 5,
        particlesize       = 27,
        particlesizespread = 0,
        particlespeed      = 3,
        particlespeedspread = 1,
        pos                = [[0, 2, 0]],
        sizegrowth         = 1,
        sizemod            = 0.5,
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
        airdrag            = 0,
                colormap           = [[0.13 0.063 0.012 0.017   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 1,
        particlelife       = 3,
        particlelifespread = 0,
        particlesize       = 50,
        particlesizespread = 10,
        particlespeed      = 0,
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
        airdrag            = 0.6,
                colormap           = [[0.03 0.03 0.03 0.12   0.07 0.07 0.07 0.3   0.11 0.11 0.11 0.25   0.06 0.06 0.06 0.17    0.035 0.035 0.035 0.09   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, -0.03, 0.0]],
        numparticles       = 1,
        particlelife       = 50,
        particlelifespread = 25,
        particlesize       = 6,
        particlesizespread = 5,
        particlespeed      = 1,
        particlespeedspread = 1,
        pos                = [[0.0, 1, 0.0]],
        sizegrowth         = 0.11,
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
        airdrag            = 0.6,
                colormap           = [[0.03 0.03 0.03 0.07  0.1 0.1 0.1 0.2   0.1 0.1 0.1 0.15   0.098 0.08 0.08 0.1    0.05 0.05 0.05 0.05   0 0 0 0]],
        directional        = true,
        emitrot            = 4,
        emitrotspread      = 4,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.04, 0]],
        numparticles       = 1,
        particlelife       = 40,
        particlelifespread = 30,
        particlesize       = 6,
        particlesizespread = 3,
        particlespeed      = 1.6,
        particlespeedspread = 0.7,
        pos                = [[0, 1, 0]],
        sizegrowth         = 0.1,
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
        airdrag            = 0.77,
        colormap           = [[0.55 0.55 0.55 0.018    0.33 0.33 0.33 0.12    0.11 0.11 0.11 0.07    0 0 0 0]],
        directional        = false,
        emitrot            = 80,
        emitrotspread      = 5,
        emitvector         = [[1, 1, 1]],
        gravity            = [[0, -0.015, 0]],
        numparticles       = 3,
        particlelife       = 30,
        particlelifespread = 7,
        particlesize       = 4.8,
        particlesizespread = 1,
        particlespeed      = 0.24,
        particlespeedspread = 0.11,
        pos                = [[0, 1, 0]],
        sizegrowth         = 0.033,
        sizemod            = 1.0,
        texture            = [[randomdots]],
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

definitions["cruisemissiletrail-emp"] = deepcopy(definitions["cruisemissiletrail"])
definitions["cruisemissiletrail-tacnuke"] = deepcopy(definitions["cruisemissiletrail"])

return definitions
