local defs = {

  ["deathceg2"] = {
    --groundflash = {
    --      --  flashalpha         = 0.02,
    --  flashsize          = 35,
    --  ground             = true,
    --  ttl                = 12,
	  --	underwater         = true,
    --  color = {
    --    [1]  = 1,
    --    [2]  = 0.8,
    --    [3]  = 0.5,
    --  },
    --},
    fire = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.4,
        colormap           = [[1 0.97 0.93 0.55   1 0.8 0.4 0.44    0.75 0.47 0.18 0.37    0.3 0.14 0.04 0.3   0.11 0.033 0 0.25   0.08 0.016 0 0.16  0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 2,
        particlelife       = 4,
        particlelifespread = 2,
        particlesize       = 2,
        particlesizespread = 0.8,
        particlespeed      = 0.22,
        particlespeedspread = 1.48,
        pos                = [[0.0, 2, 0.0]],
        sizegrowth         = -0.3,
        sizemod            = 1,
        texture            = [[dirt]],
        useairlos          = true,
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
        colormap           = [[0.08 0.05 0.01 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 1,
        particlelife       = 1,
        particlelifespread = 0,
        particlesize       = 15,
        particlesizespread = 1.5,
        particlespeed      = 0,
        particlespeedspread = 0,
        pos                = [[0.0, 0, 0.0]],
        sizegrowth         = -1.7,
        sizemod            = 1,
        texture            = [[glow]],
        useairlos          = true,
      },
    },
    --smoke = {
    --  air                = true,
    --  class              = [[CSimpleParticleSystem]],
    --  count              = 1,
    --  ground             = true,
    --  properties = {
    --    airdrag            = 0.8,
    --    colormap           = [[0.01 0.007 0.005 0.11   0.01 0.0075 0.0065 0.11   0.1 0.085 0.075 0.11   0.09 0.085 0.08 0.11   0.066 0.063 0.06 0.1   0.055 0.052 0.05 0.075   0 0 0 0]],
    --    directional        = true,
    --    emitrot            = 45,
    --    emitrotspread      = 4,
    --    emitvector         = [[0.5, 0.9, 0.5]],
    --    gravity            = [[0, 0.05, 0]],
    --    numparticles       = 1,
    --    particlelife       = 10,
    --    particlelifespread = 9,
    --    particlesize       = 2,
    --    particlesizespread = 0.55,
    --    particlespeed      = 0.3,
    --    particlespeedspread = 0.15,
    --    pos                = [[0, 1, 0]],
    --    sizegrowth         = 0.06,
    --    sizemod            = 1.0,
    --    texture            = [[bigexplosmoke]],
    --  },
    --},
  },
  
  
  
  ["deathceg3"] = {
    --groundflash = {
    --      --  flashalpha         = 0.02,
    --  flashsize          = 35,
    --  ground             = true,
    --  ttl                = 12,
	  --	underwater         = true,
    --  color = {
    --    [1]  = 1,
    --    [2]  = 0.8,
    --    [3]  = 0.5,
    --  },
    --},
    fire = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.4,
        colormap           = [[1 0.97 0.93 0.55   1 0.8 0.4 0.44    0.75 0.47 0.18 0.37    0.3 0.14 0.04 0.3   0.11 0.033 0 0.25   0.08 0.016 0 0.16  0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 3,
        particlelife       = 4,
        particlelifespread = 2,
        particlesize       = 2.15,
        particlesizespread = 1,
        particlespeed      = 0,
        particlespeedspread = 2,
        pos                = [[0.0, 2, 0.0]],
        sizegrowth         = -0.33,
        sizemod            = 1,
        texture            = [[dirt]],
        useairlos          = true,
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
        colormap           = [[0.08 0.05 0.01 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 1,
        particlelife       = 2,
        particlelifespread = 0,
        particlesize       = 18,
        particlesizespread = 2,
        particlespeed      = 0,
        particlespeedspread = 0,
        pos                = [[0.0, 0, 0.0]],
        sizegrowth         = -1.7,
        sizemod            = 1,
        texture            = [[glow]],
        useairlos          = true,
      },
    },
    smoke = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.8,
        colormap           = [[0.01 0.007 0.005 0.11   0.01 0.0075 0.0065 0.11   0.1 0.085 0.075 0.11   0.09 0.085 0.08 0.11   0.066 0.063 0.06 0.1   0.055 0.052 0.05 0.075   0 0 0 0]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 4,
        emitvector         = [[0.5, 0.9, 0.5]],
        gravity            = [[0, 0.05, 0]],
        numparticles       = 1,
        particlelife       = 9,
        particlelifespread = 4,
        particlesize       = 2.4,
        particlesizespread = 0.7,
        particlespeed      = 0.35,
        particlespeedspread = 0.2,
        pos                = [[0, 1, 0]],
        sizegrowth         = 0.06,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
      },
    },
    --dirt = {
    --  class              = [[CSimpleParticleSystem]],
    --  count              = 1,
    --  ground             = true,
    --  unit               = false,
    --  properties = {
    --    airdrag            = 1,
    --    colormap           = [[0.04 0.03 0.01 0   0.1 0.07 0.033 0.66    0.1 0.07 0.03 0.58   0.08 0.065 0.035 0.47   0.075 0.07 0.06 0.4   0 0 0 0  ]],
    --    directional        = true,
    --    emitrot            = 0,
    --    emitrotspread      = 40,
    --    emitvector         = [[0, 1, 0]],
    --    gravity            = [[0, -0.22, 0]],
    --    numparticles       = 1,
    --    particlelife       = 11,
    --    particlelifespread = 5,
    --    particlesize       = 1.1,
    --    particlesizespread = -0.9,
    --    particlespeed      = 0.6,
    --    particlespeedspread = 1,
    --    pos                = [[0, 4, 0]],
    --    sizegrowth         = -0.01,
    --    sizemod            = 1,
    --    texture            = [[bigexplosmoke]],
    --    useairlos          = false,
    --  },
    --},
    --grounddust = {
    --  air                = false,
    --  class              = [[CSimpleParticleSystem]],
    --  count              = 1,
    --  ground             = true,
    --  unit               = false,
    --  properties = {
    --    airdrag            = 0.92,
    --    colormap           = [[0.15 0.13 0.09 0.14 	0 0 0 0.0]],
    --    directional        = true,
    --    emitrot            = 90,
    --    emitrotspread      = -2,
    --    emitvector         = [[0, 1, 0]],
    --    gravity            = [[0, 0.1, 0]],
    --    numparticles       = 3,
    --    particlelife       = 3,
    --    particlelifespread = 30,
    --    particlesize       = 1.5,
    --    particlesizespread = 0.5,
    --    particlespeed      = 0.9,
    --    particlespeedspread = 1.6,
    --    pos                = [[0, 1, 0]],
    --    sizegrowth         = 0.15,
    --    sizemod            = 1.0,
    --    texture            = [[bigexplosmoke]],
    --  },
    --},
  },
  
  
  
  ["deathceg4"] = {
    --groundflash = {
    --      --  flashalpha         = 0.02,
    --  flashsize          = 45,
    --  ground             = true,
    --  ttl                = 12,
	  --	underwater         = true,
    --  color = {
    --    [1]  = 1,
    --    [2]  = 0.8,
    --    [3]  = 0.5,
    --  },
    --},
    fire = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.4,
        colormap           = [[1 0.97 0.93 0.55   1 0.8 0.4 0.44    0.75 0.47 0.18 0.37    0.3 0.14 0.04 0.3   0.11 0.033 0 0.25   0.08 0.016 0 0.16  0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 4,
        particlelife       = 6,
        particlelifespread = 3,
        particlesize       = 2.35,
        particlesizespread = 1.4,
        particlespeed      = 0,
        particlespeedspread = 2,
        pos                = [[0.0, 2, 0.0]],
        sizegrowth         = -0.35,
        sizemod            = 1,
        texture            = [[dirt]],
        useairlos          = true,
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
        colormap           = [[0.08 0.05 0.01 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 1,
        particlelife       = 2,
        particlelifespread = 0,
        particlesize       = 24,
        particlesizespread = 3,
        particlespeed      = 0,
        particlespeedspread = 0,
        pos                = [[0.0, 0, 0.0]],
        sizegrowth         = -1.8,
        sizemod            = 1,
        texture            = [[glow]],
        useairlos          = true,
      },
    },
    smoke = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.8,
        colormap           = [[0.01 0.007 0.005 0.11   0.01 0.0075 0.0065 0.11   0.1 0.085 0.075 0.11   0.09 0.085 0.08 0.11   0.066 0.063 0.06 0.1   0.055 0.052 0.05 0.075   0 0 0 0]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 4,
        emitvector         = [[0.5, 0.9, 0.5]],
        gravity            = [[0, 0.05, 0]],
        numparticles       = 1,
        particlelife       = 12,
        particlelifespread = 5,
        particlesize       = 3.5,
        particlesizespread = 1.5,
        particlespeed      = 0.35,
        particlespeedspread = 0.2,
        pos                = [[0, 1, 0]],
        sizegrowth         = 0.06,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
      },
    },
    --dirt = {
    --  class              = [[CSimpleParticleSystem]],
    --  count              = 1,
    --  ground             = true,
    --  unit               = false,
    --  properties = {
    --    airdrag            = 1,
    --    colormap           = [[0.04 0.03 0.01 0   0.1 0.07 0.033 0.66    0.1 0.07 0.03 0.58   0.08 0.065 0.035 0.47   0.075 0.07 0.06 0.4   0 0 0 0  ]],
    --    directional        = true,
    --    emitrot            = 0,
    --    emitrotspread      = 40,
    --    emitvector         = [[0, 1, 0]],
    --    gravity            = [[0, -0.22, 0]],
    --    numparticles       = 2,
    --    particlelife       = 15,
    --    particlelifespread = 5,
    --    particlesize       = 1.1,
    --    particlesizespread = -0.85,
    --    particlespeed      = 0.3,
    --    particlespeedspread = 1.2,
    --    pos                = [[0, 4, 0]],
    --    sizegrowth         = -0.01,
    --    sizemod            = 1,
    --    texture            = [[bigexplosmoke]],
    --    useairlos          = false,
    --  },
    --},
    --grounddust = {
    --  air                = false,
    --  class              = [[CSimpleParticleSystem]],
    --  count              = 1,
    --  ground             = true,
    --  unit               = false,
    --  properties = {
    --    airdrag            = 0.92,
    --    colormap           = [[0.15 0.13 0.09 0.14 	0 0 0 0.0]],
    --    directional        = true,
    --    emitrot            = 90,
    --    emitrotspread      = -2,
    --    emitvector         = [[0, 1, 0]],
    --    gravity            = [[0, 0.1, 0]],
    --    numparticles       = 4,
    --    particlelife       = 4,
    --    particlelifespread = 35,
    --    particlesize       = 2,
    --    particlesizespread = 0.6,
    --    particlespeed      = 1,
    --    particlespeedspread = 1.4,
    --    pos                = [[0, 1, 0]],
    --    sizegrowth         = 0.1,
    --    sizemod            = 1.0,
    --    texture            = [[bigexplosmoke]],
    --  },
    --},
  },
}


function tableMerge(t1, t2)
    for k,v in pairs(t2) do
    	if type(v) == "table" then
    		if type(t1[k] or false) == "table" then
    			tableMerge(t1[k] or {}, t2[k] or {})
    		else
    			t1[k] = v
    		end
    	else
    		t1[k] = v
    	end
    end
    return t1
end

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
local effects = {
  electricity = {
    air                = true,
    class              = [[CSimpleParticleSystem]],
    count              = 1,
    ground             = true,
    water              = true,
    underwater         = true,
    properties = {
      airdrag            = 0.8,
      colormap           = [[0.7 0.7 0.9 0.037   0.5 0.5 0.9 0.01]],
      directional        = true,
      emitrot            = 45,
      emitrotspread      = 32,
      emitvector         = [[0, 1, 0]],
      gravity            = [[0, -0.01, 0]],
      numparticles       = 2.5,
      particlelife       = 4,
      particlelifespread = 1,
      particlesize       = 1.6,
      particlesizespread = 0.8,
      particlespeed      = 0,
      particlespeedspread = 1.2,
      pos                = [[0, 2, 0]],
      sizegrowth         = 0.6,
      sizemod            = 1,
      texture            = [[whitelightb]],
      useairlos          = false,
    },
  },
  fire = {
    properties = {
      colormap           = [[1 1 1 0.55   1 0.75 0.55 0.44    0.75 0.47 0.44 0.37    0.3 0.14 0.25 0.3   0.11 0.033 0.14 0.11   0.08 0.016 0.12 0.16  0 0 0 0.01]],
    },
  },
  fireglow = {
    properties = {
      colormap           = [[0.1 0.06 0.07 0.01   0 0 0 0.01]],
    },
  },
}

defs["deathceg2-lightning"] = tableMerge(deepcopy(defs["deathceg2"]), deepcopy(effects))
defs["deathceg2-lightning"].fire.properties.numparticles = defs["deathceg2-lightning"].fire.properties.numparticles/2.5
defs["deathceg2-lightning"].electricity.properties.numparticles = defs["deathceg2-lightning"].electricity.properties.numparticles/1.6
defs["deathceg2-lightning"].electricity.properties.particlelife = defs["deathceg2-lightning"].electricity.properties.particlelife/1.6
defs["deathceg3-lightning"] = tableMerge(deepcopy(defs["deathceg3"]), deepcopy(effects))
defs["deathceg3-lightning"].fire.properties.numparticles = defs["deathceg3-lightning"].fire.properties.numparticles/2.5
defs["deathceg3-lightning"].electricity.properties.numparticles = defs["deathceg3-lightning"].electricity.properties.numparticles/1.2
defs["deathceg3-lightning"].electricity.properties.particlelife = defs["deathceg3-lightning"].electricity.properties.particlelife/1.2
defs["deathceg4-lightning"] = tableMerge(deepcopy(defs["deathceg4"]), deepcopy(effects))
defs["deathceg4-lightning"].fire.properties.numparticles = defs["deathceg4-lightning"].fire.properties.numparticles/2.5

effects = {
  fire = {
    properties = {
      colormap           = [[1 0.97 0.93 0.66   1 0.8 0.4 0.5    0.75 0.47 0.18 0.4    0.33 0.14 0.04 0.33   0.14 0.033 0 0.25   0.11 0.016 0 0.16  0 0 0 0.01]],
    },
  },
  fireglow = {
    properties = {
      colormap           = [[0.15 0.075 0.02 0.015   0 0 0 0.01]],
    },
  },
}
defs["deathceg2-fire"] = tableMerge(deepcopy(defs["deathceg2"]), deepcopy(effects))
defs["deathceg2-fire"].fireglow.properties.particlesize = defs["deathceg2-fire"].fireglow.properties.particlesize*1.7
--defs["deathceg2-fire"].smoke.properties.particlesize = defs["deathceg2-fire"].smoke.properties.particlesize*1.4
--defs["deathceg2-fire"].smoke.properties.particlelife = defs["deathceg2-fire"].smoke.properties.particlelife*1.8
defs["deathceg2-fire"].fire.properties.particlesize = defs["deathceg2-fire"].fire.properties.particlesize*1.7
defs["deathceg2-fire"].fire.properties.particlelife = defs["deathceg2-fire"].fire.properties.particlelife*1.7
defs["deathceg3-fire"] = tableMerge(deepcopy(defs["deathceg3"]), deepcopy(effects))
defs["deathceg3-fire"].fireglow.properties.particlesize = defs["deathceg3-fire"].fireglow.properties.particlesize*1.7
defs["deathceg3-fire"].smoke.properties.particlesize = defs["deathceg3-fire"].smoke.properties.particlesize*1.4
defs["deathceg3-fire"].smoke.properties.particlelife = defs["deathceg3-fire"].smoke.properties.particlelife*1.8
defs["deathceg3-fire"].fire.properties.particlesize = defs["deathceg3-fire"].fire.properties.particlesize*1.7
defs["deathceg3-fire"].fire.properties.particlelife = defs["deathceg3-fire"].fire.properties.particlelife*1.7
defs["deathceg4-fire"] = tableMerge(deepcopy(defs["deathceg3"]), deepcopy(effects))
defs["deathceg4-fire"].fireglow.properties.particlesize = defs["deathceg4-fire"].fireglow.properties.particlesize*1.7
defs["deathceg4-fire"].smoke.properties.particlesize = defs["deathceg4-fire"].smoke.properties.particlesize*1.4
defs["deathceg4-fire"].smoke.properties.particlelife = defs["deathceg4-fire"].smoke.properties.particlelife*1.8
defs["deathceg4-fire"].fire.properties.particlesize = defs["deathceg4-fire"].fire.properties.particlesize*1.7
defs["deathceg4-fire"].fire.properties.particlelife = defs["deathceg4-fire"].fire.properties.particlelife*1.7

--local effects = {
--  searingflame = {
--    air                = true,
--    class              = [[CSimpleParticleSystem]],
--    count              = 1,
--    ground             = true,
--    water              = true,
--    properties = {
--      airdrag            = 1,
--      --      colormap           = [[1 0.8 0.5 0.04   0.6 0.1 0.1 0.01]],
--      directional        = true,
--      emitrot            = 90,
--      --emitrotspread      = 45,
--      emitvector         = [[dir]],
--      gravity            = [[0, -0.1, 0]],
--      numparticles       = 12,
--      particlelife       = 150,
--      particlelifespread = 2,
--      particlesize       = 9,
--      particlesizespread = 4.5,
--      particlespeed      = 0.02,
--      particlespeedspread = 0.02,
--      pos                = [[0, 2, 0]],
--      sizegrowth         = -0.01,
--      sizemod            = 0.5,
--      texture            = [[gunshotglow]],
--      useairlos          = false,
--    },
--  },
--}
--defs["deathceg2-air"] = tableMerge(deepcopy(defs["deathceg2"]), deepcopy(effects))
--defs["deathceg3-air"] = tableMerge(deepcopy(defs["deathceg3"]), deepcopy(effects))


return defs
