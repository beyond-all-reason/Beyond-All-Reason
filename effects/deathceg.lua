local defs = {

  ["deathceg2"] = {
    fire = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 2,
      ground             = true,
      properties = {
        airdrag            = 0.66,
        colormap           = [[0.8 0.66 0.4 0.04   0.75 0.55 0.35 0.035   0.5 0.37 0.25 0.03   0.3 0.22 0.15 0.022   0.2 0.15 0.06 0.015   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0, -0.011, 0]],
        numparticles       = [[0.5 r1]],
        particlelife       = 2,
        particlelifespread = 1,
        particlesize       = 1.4,
        particlesizespread = 1.6,
        particlespeed      = 0.3,
        particlespeedspread = 0.8,
        pos                = [[-1.5 r3, -1.5 r3, -1.5 r3]],
        sizegrowth         = 0.25,
        sizemod            = 0.97,
        texture            = [[fire]],
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
        colormap           = [[0.33 0.15 0.04 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 1,
        particlelife       = 1,
        particlelifespread = 0,
        particlesize       = 13.5,
        particlesizespread = 1.5,
        particlespeed      = 0,
        particlespeedspread = 0,
        pos                = [[0.0, 0, 0.0]],
        sizegrowth         = -1.7,
        sizemod            = 1,
        texture            = [[glow2]],
        useairlos          = true,
      },
    },
    fireandsmoke = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.4,
        colormap           = [[0.05 0.04 0.033 0.62   0.04 0.038 0.034 0.57   0.04 0.036 0.032 0.48   0.025 0.025 0.025 0.3   0.014 0.014 0.014 0.15    0.006 0.006 0.006 0.06   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, -0.03, 0.0]],
        numparticles       = [[0.6 r1]],
        particlelife       = 4,
        particlelifespread = 3,
        particlesize       = 1.5,
        particlesizespread = 1.7,
        particlespeed      = 0,
        particlespeedspread = 2,
        pos                = [[-2 r4, -2 r4, -2 r4]],
        sizegrowth         = 0.3,
        sizemod            = 1,
        texture            = [[smoke]],
        useairlos          = true,
      },
    },
  },
  
  
  
  ["deathceg3"] = {
    fire = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 2,
      ground             = true,
      properties = {
        airdrag            = 0.66,
        colormap           = [[0.8 0.66 0.4 0.04   0.75 0.55 0.35 0.035   0.5 0.37 0.25 0.03   0.3 0.22 0.15 0.022   0.2 0.15 0.06 0.015   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0, -0.011, 0]],
        numparticles       = [[0.66 r1]],
        particlelife       = 2,
        particlelifespread = 2,
        particlesize       = 2.1,
        particlesizespread = 2.5,
        particlespeed      = 0.3,
        particlespeedspread = 0.8,
        pos                = [[-2 r4, -2 r4, -2 r4]],
        sizegrowth         = 0.25,
        sizemod            = 0.97,
        texture            = [[fire]],
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
        colormap           = [[0.35 0.15 0.04 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 1,
        particlelife       = 2,
        particlelifespread = 0,
        particlesize       = 16.5,
        particlesizespread = 2,
        particlespeed      = 0,
        particlespeedspread = 0,
        pos                = [[0.0, 0, 0.0]],
        sizegrowth         = -1.7,
        sizemod            = 1,
        texture            = [[glow2]],
        useairlos          = true,
      },
    },
    fireandsmoke = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.4,
        colormap           = [[0.05 0.04 0.033 0.62   0.04 0.038 0.034 0.57   0.04 0.036 0.032 0.48   0.025 0.025 0.025 0.3   0.014 0.014 0.014 0.15    0.006 0.006 0.006 0.06   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, -0.03, 0.0]],
        numparticles       = [[0.66 r1]],
        particlelife       = 6,
        particlelifespread = 4,
        particlesize       = 2.2,
        particlesizespread = 3,
        particlespeed      = 0,
        particlespeedspread = 2,
        pos                = [[-2 r4, -2 r4, -2 r4]],
        sizegrowth         = 0.3,
        sizemod            = 1,
        texture            = [[smoke]],
        useairlos          = true,
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
        airdrag            = 0.75,
        colormap           = [[1 0.7 0.4 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 20,
        emitrotspread      = 2,
        emitvector         = [[dir]],
        gravity            = [[0, -0.011, 0]],
        numparticles       = 1,
        particlelife       = 2,
        particlelifespread = 1,
        particlesize       = 2.2,
        particlesizespread = 2.2,
        particlespeed      = 0.015,
        particlespeedspread = 0.04,
        pos                = [[0, 0, 0]],
        sizegrowth         = 0.35,
        sizemod            = 0.9,
        texture            = [[randomdots]],
      },
    },
  },
  
  
  
  ["deathceg4"] = {
    fire = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 2,
      ground             = true,
      properties = {
        airdrag            = 0.66,
        colormap           = [[0.8 0.66 0.4 0.04   0.75 0.55 0.35 0.035   0.5 0.37 0.25 0.03   0.3 0.22 0.15 0.022   0.2 0.15 0.06 0.015   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0, -0.011, 0]],
        numparticles       = [[0.66 r1]],
        particlelife       = 3,
        particlelifespread = 2,
        particlesize       = 2.5,
        particlesizespread = 3.5,
        particlespeed      = 0.3,
        particlespeedspread = 0.8,
        pos                = [[-2 r4, -2 r4, -2 r4]],
        sizegrowth         = 0.25,
        sizemod            = 0.97,
        texture            = [[fire]],
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
        colormap           = [[0.4 0.17 0.04 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 1,
        particlelife       = 2,
        particlelifespread = 0,
        particlesize       = 22,
        particlesizespread = 3,
        particlespeed      = 0,
        particlespeedspread = 0,
        pos                = [[0.0, 0, 0.0]],
        sizegrowth         = -1.8,
        sizemod            = 1,
        texture            = [[glow2]],
        useairlos          = true,
      },
    },
    fireandsmoke = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.4,
        colormap           = [[0.05 0.04 0.033 0.62   0.04 0.038 0.034 0.57   0.04 0.036 0.032 0.48   0.025 0.025 0.025 0.3   0.014 0.014 0.014 0.15    0.006 0.006 0.006 0.06   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, -0.03, 0.0]],
        numparticles       = [[0.75 r1]],
        particlelife       = 8,
        particlelifespread = 4,
        particlesize       = 3.5,
        particlesizespread = 4.7,
        particlespeed      = 0,
        particlespeedspread = 2,
        pos                = [[-2 r4, -2 r4, -2 r4]],
        sizegrowth         = 0.3,
        sizemod            = 1,
        texture            = [[smoke]],
        useairlos          = true,
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
        airdrag            = 0.75,
        colormap           = [[1 0.7 0.4 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 20,
        emitrotspread      = 2,
        emitvector         = [[dir]],
        gravity            = [[0, -0.011, 0]],
        numparticles       = 1,
        particlelife       = 2,
        particlelifespread = 2,
        particlesize       = 3,
        particlesizespread = 3,
        particlespeed      = 0.015,
        particlespeedspread = 0.04,
        pos                = [[0, 0, 0]],
        sizegrowth         = 0.35,
        sizemod            = 0.9,
        texture            = [[randomdots]],
      },
    },
  }
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
      numparticles       = 2,
      particlelife       = 3,
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
      colormap           = [[0.25 0.17 0.05 0.01   0 0 0 0.01]],
    },
  },
}

defs["deathceg2-lightning"] = tableMerge(deepcopy(defs["deathceg2"]), deepcopy(effects))
--defs["deathceg2-lightning"].fire.properties.numparticles = defs["deathceg2-lightning"].fire.properties.numparticles/2.5
--defs["deathceg2-lightning"].electricity.properties.numparticles = defs["deathceg2-lightning"].electricity.properties.numparticles/1.6
defs["deathceg2-lightning"].electricity.properties.particlelife = defs["deathceg2-lightning"].electricity.properties.particlelife/1.6
defs["deathceg3-lightning"] = tableMerge(deepcopy(defs["deathceg3"]), deepcopy(effects))
--defs["deathceg3-lightning"].fire.properties.numparticles = defs["deathceg3-lightning"].fire.properties.numparticles/2.5
--defs["deathceg3-lightning"].electricity.properties.numparticles = defs["deathceg3-lightning"].electricity.properties.numparticles/1.2
--defs["deathceg3-lightning"].electricity.properties.particlelife = defs["deathceg3-lightning"].electricity.properties.particlelife/1.2
defs["deathceg4-lightning"] = tableMerge(deepcopy(defs["deathceg4"]), deepcopy(effects))
--defs["deathceg4-lightning"].fire.properties.numparticles = defs["deathceg4-lightning"].fire.properties.numparticles/2.5

effects = {
  fire = {
    properties = {
      --colormap           = [[1 0.97 0.93 0.66   1 0.8 0.4 0.5    0.75 0.47 0.18 0.4    0.33 0.14 0.04 0.33   0.14 0.033 0 0.25   0.11 0.016 0 0.16  0 0 0 0.01]],
    },
  },
  fireglow = {
    properties = {
      --colormap           = [[0.15 0.075 0.02 0.015   0 0 0 0.01]],
    },
  },
}
defs["deathceg2-fire"] = tableMerge(deepcopy(defs["deathceg2"]), deepcopy(effects))
defs["deathceg2-fire"].fireglow.properties.particlesize = defs["deathceg2-fire"].fireglow.properties.particlesize*1.7
defs["deathceg2-fire"].fireandsmoke.properties.particlesize = defs["deathceg2-fire"].fireandsmoke.properties.particlesize*1.4
defs["deathceg2-fire"].fireandsmoke.properties.particlelife = defs["deathceg2-fire"].fireandsmoke.properties.particlelife*1.8
defs["deathceg2-fire"].fire.properties.particlesize = defs["deathceg2-fire"].fire.properties.particlesize*1.7
defs["deathceg2-fire"].fire.properties.particlelife = defs["deathceg2-fire"].fire.properties.particlelife*1.7
defs["deathceg3-fire"] = tableMerge(deepcopy(defs["deathceg3"]), deepcopy(effects))
defs["deathceg3-fire"].fireglow.properties.particlesize = defs["deathceg3-fire"].fireglow.properties.particlesize*1.7
defs["deathceg3-fire"].fireandsmoke.properties.particlesize = defs["deathceg3-fire"].fireandsmoke.properties.particlesize*1.4
defs["deathceg3-fire"].fireandsmoke.properties.particlelife = defs["deathceg3-fire"].fireandsmoke.properties.particlelife*1.8
defs["deathceg3-fire"].fire.properties.particlesize = defs["deathceg3-fire"].fire.properties.particlesize*1.7
defs["deathceg3-fire"].fire.properties.particlelife = defs["deathceg3-fire"].fire.properties.particlelife*1.7
defs["deathceg4-fire"] = tableMerge(deepcopy(defs["deathceg4"]), deepcopy(effects))
defs["deathceg4-fire"].fireglow.properties.particlesize = defs["deathceg4-fire"].fireglow.properties.particlesize*1.7
--defs["deathceg4-fire"].fireandsmoke.properties.particlesize = defs["deathceg4-fire"].fireandsmoke.properties.particlesize*1.4
--defs["deathceg4-fire"].fireandsmoke.properties.particlelife = defs["deathceg4-fire"].fireandsmoke.properties.particlelife*1.8
--defs["deathceg4-fire"].fire.properties.particlesize = defs["deathceg4-fire"].fire.properties.particlesize*1.7
--defs["deathceg4-fire"].fire.properties.particlelife = defs["deathceg4-fire"].fire.properties.particlelife*1.7


effects = {
  fire = {
    properties = {
      colormap           = [[0.98 1 0.91 0.55   0.85 1 0.3 0.4    0.4 0.6 0.1 0.3   0 0 0 0.01]],
    },
  },
  fireglow = {
    properties = {
      colormap           = [[0.12 0.15 0.02 0.015   0 0 0 0.01]],
    },
  },
}
defs["deathceg2-builder"] = tableMerge(deepcopy(defs["deathceg2"]), deepcopy(effects))
defs["deathceg3-builder"] = tableMerge(deepcopy(defs["deathceg3"]), deepcopy(effects))
defs["deathceg4-builder"] = tableMerge(deepcopy(defs["deathceg4"]), deepcopy(effects))

defs["deathceg2-builder"].fire.properties.colormap = [[0.5 0.8 0.4 0.04   0.4 0.7 0.35 0.035   0.3 0.55 0.25 0.03   0.2 0.3 0.15 0.022   0.15 0.18 0.06 0.015   0 0 0 0.01]]
defs["deathceg3-builder"].fire.properties.colormap = deepcopy(defs["deathceg2-builder"].fire.properties.colormap)
defs["deathceg4-builder"].fire.properties.colormap = deepcopy(defs["deathceg2-builder"].fire.properties.colormap)

defs["deathceg2-builder"].fireglow.properties.colormap = [[0.16 0.33 0.04 0.01   0 0 0 0.01]]
defs["deathceg3-builder"].fireglow.properties.colormap = deepcopy(defs["deathceg2-builder"].fireglow.properties.colormap)
defs["deathceg4-builder"].fireglow.properties.colormap = deepcopy(defs["deathceg2-builder"].fireglow.properties.colormap)

defs["deathceg3-builder"].dustparticles.properties.colormap = [[0.8 1 0.4 0.01   0 0 0 0.01]]
defs["deathceg4-builder"].dustparticles.properties.colormap = deepcopy(defs["deathceg3-builder"].dustparticles.properties.colormap)


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
