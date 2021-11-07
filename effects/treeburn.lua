-- treeburnexplode
-- treeburn

local definitions = {
  ["treeburnexplode"] = {
    -- groundflash = {
    --   air                = true,
    --   circlealpha        = 0.0,
    --   circlegrowth       = 6,
    --   flashalpha         = 0.16,
    --   flashsize          = 45,
    --   ground             = true,
    --   ttl                = 25,
    --   underwater         = 1,
    --   water              = true,
    --   color = {
    --     [1]  = 1,
    --     [2]  = 0.15,
    --     [3]  = 0,
    --   },
    -- },
    sparks = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.90,
        colormap           = [[1 1 0.4 0.08	1.0 0.66 0.2 0.06	1.0 0.55 0.0 0.01]],
        directional        = true,
        emitrot            = 14,
        emitrotspread      = 75,
        emitvector         = [[0 r0.2, 1, 0 r0.2]],
        gravity            = [[-0.1 r0.2, 0.4, -0.1 r0.2]],
        numparticles       = [[0.5 r1.51]],
        particlelife       = 9,
        particlelifespread = 14,
        particlesize       = 15,
        particlesizespread = 7,
        particlespeed      = 1,
        particlespeedspread = 2,
        pos                = [[0, 20, 0]],
        sizegrowth         = 1.2,
        sizemod            = 0.80,
        texture            = [[gunshotglow]],
        useairlos          = true,
        drawOrder          = 1,
      },
    },
  },


  ["treeburn"] = {
    flame = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.93,
        colormap           = [[0.5 0.4 0.3 0.5  0.45 0.35 0.25 0.17   0.4 0.3 0.2 0.10   0.3 0.3 0.3 0.08    0 0 0 0.01]],
        directional        = true,
        emitrot            = 70,
        emitrotspread      = 40,
        emitvector         = [[0.3 r0.1, 1, 0.3 r0.1]],
        gravity            = [[0 r0.1, 0.125 r0.1, 0 r0.1]],
        numparticles       = 1,
        particlelife       = 12,
        particlelifespread = 18,
        particlesize       = 0.5,
        particlesizespread = 1.0,
        particlespeed      = 0.2,
        particlespeedspread = 0.55,
        pos                = [[-10 r20, -4 r30, -10 r20]],
        sizegrowth         = 0.7,
        sizemod            = 0.99,
        texture            = [[fire]],
        useairlos          = true,
        alwaysVisible      = true,
        drawOrder          = 1,
      },
    },
  },
}

-- add different sizes
local root = 'treeburn'
definitions[root..'-medium'] = definitions[root]

local sizes = {
  tiny = {
    flame = {
      properties = {
        numparticles       = 2,
        -- particlesize       = 0.2,
        -- particlesizespread = 0.4,
        particlespeed      = 0.07,
        particlespeedspread = 0.13,
        particlelifespread = 15,
        pos                = [[-5 r10, -1 r15, -5 r10]],
      },
    },
  },

  small = {
    flame = {
      properties = {
        numparticles       = 2,
        -- particlesize       = 0.35,
        -- particlesizespread = 0.6,
        particlespeed      = 0.13,
        particlespeedspread = 0.25,
        particlelifespread = 20,
        pos                = [[-7 r14, -1 r20, -7 r14]],
      },
    },
  },

  large = {
    flame = {
      properties = {
        numparticles       = 2,
        -- particlesize       = 1.1,
        -- particlesizespread = 1.1,
        particlespeed      = 0.35,
        particlespeedspread = 0.75,
        particlelifespread = 32,
        pos                = [[-15 r30, -4 r30, -15 r30]],
      },
    },
  },
}
for size, effects in pairs(sizes) do
  definitions[root..'-'..size] = table.merge(definitions[root], effects)
end



root = 'treeburnexplode'
definitions[root..'-medium'] = definitions[root]

local sizes = {
  tiny = {
    -- groundflash = {
    --   flashsize = 12,
    -- },
    sparks = {
      particlelife = 6,
      particlelifespread = 8,
      particlesizespread = 4,
      particlespeed = 0.3,
      emitrot = 8,
    }
  },
  small = {
    -- groundflash = {
    --   flashsize = 18,
    -- },
    sparks = {
      particlelife = 8,
      particlelifespread = 11,
      particlesizespread = 5,
      particlespeed = 0.55,
      emitrot = 11,
    }
  },
  large = {
    -- groundflash = {
    --   flashsize = 32,
    -- },
    sparks = {
      particlelife = 10,
      particlelifespread = 18,
      particlesizespread = 7,
      particlespeed = 4,
      emitrot = 19,
    }
  },
}
for size, effects in pairs(sizes) do
  definitions[root..'-'..size] = table.merge(definitions[root], effects)
end


return definitions
