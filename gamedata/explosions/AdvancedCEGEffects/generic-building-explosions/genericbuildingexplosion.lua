local root = "genericbuildingexplosion"
local definitions = {
  [root.."-small"] = {
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
        size               = 2,
        sizegrowth         = 16,
        speed              = [[0, 1 0, 0]],
        texture            = [[flare]],
      },
    },
    groundflash_large = {
      class              = [[CSimpleGroundFlash]],
      count              = 1,
      air                = true,
      ground             = true,
      water              = true,
      properties = {
        colormap           = [[1 0.7 0.3 0.28   0 0 0 0.01]],
        size               = 115,
        sizegrowth         = -1,
        ttl                = 18,
        texture            = [[groundflash]],
      },
    },
    groundflash_white = {
      class              = [[CSimpleGroundFlash]],
      count              = 1,
      air                = true,
      ground             = true,
      water              = true,
      properties = {
        colormap           = [[1 0.9 0.75 0.09   0 0 0 0.01]],
        size               = 105,
        sizegrowth         = 0,
        ttl                = 4,
        texture            = [[groundflash]],
      },
    },
    heatedgroundflash = {
      class              = [[CSimpleGroundFlash]],
      count              = 1,
      air                = false,
      ground             = true,
      unit               = false,
      water              = false,
      properties = {
        colormap           = [[1 0.15 0.05 0.4   1 0.15 0.05 0.3   0 0 0 0.01]],
        size               = 16,
        sizegrowth         = 0,
        ttl                = 33,
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
        numparticles       = 80,
        particlelife       = 2,
        particlelifespread = 30,
        particlesize       = 2,
        particlesizespread = 1,
        particlespeed      = 10,
        particlespeedspread = 6,
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
        numparticles       = 25,
        particlelife       = 4,
        particlelifespread = 9,
        particlesize       = 2,
        particlesizespread = 5,
        particlespeed      = 0.5,
        particlespeedspread = 3,
        pos                = [[0, 2, 0]],
        sizegrowth         = 0.3,
        sizemod            = 1,
        texture            = [[flashside2]],
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
        airdrag            = 0.5,
        colormap           = [[0.15 0.14 0.1 0.005   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 1,
        particlelife       = 13,
        particlelifespread = 0,
        particlesize       = 17,
        particlesizespread = 4,
        particlespeed      = 0,
        particlespeedspread = 0,
        pos                = [[0, 2, 0]],
        sizegrowth         = 1.5,
        sizemod            = 1,
        texture            = [[glow]],
        useairlos          = false,
      },
    },
    fireglow2 = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.5,
        colormap           = [[0.26 0.22 0.08 0.26   0.44 0.38 0.13 0.44   0.2 0.14 0 0.2   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 0, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 1,
        particlelife       = 16,
        particlelifespread = 0,
        particlesize       = 44,
        particlesizespread = 2,
        particlespeed      = 0,
        particlespeedspread = 0,
        pos                = [[0, 2, 0]],
        sizegrowth         = 1,
        sizemod            = 1,
        texture            = [[dirt]],
        useairlos          = false,
      },
    },
    innersmoke = {
      class = [[CSimpleParticleSystem]],
      water=0,
      air=1,
      ground=1,
      count=1,
      properties = {
        airdrag=0.75,
        alwaysVisible = 0,
        sizeGrowth = 0.3,
        sizeMod = 1.0,
        pos = [[r-1 r1, 0, r-1 r1]],
        emitRot=33,
        emitRotSpread=50,
        emitVector = [[0, 1, 0]],
        gravity = [[0, 0.02, 0]],
        colorMap=[[1 0.66 0.45 0.35    0.44 0.24 0.14 0.45   0.25 0.17 0.13 0.4    0.19 0.16 0.14 0.35   0.1 0.095 0.088 0.25   0.07 0.065 0.058 0.17    0 0 0 0.01]],
        Texture=[[graysmoke]],
        particleLife=15,
        particleLifeSpread=45,
        numparticles=3,
        particleSpeed=2,
        particleSpeedSpread=5,
        particleSize=11,
        particleSizeSpread=20,
        directional=0,
      },
    },
    outersmoke = {
      class = [[CSimpleParticleSystem]],
      water=0,
      air=1,
      ground=1,
      count=1,
      properties = {
        airdrag=0.2,
        alwaysVisible = 0,
        sizeGrowth = 0.3,
        sizeMod = 1.0,
        pos = [[r-1 r1, 0, r-1 r1]],
        emitRot=33,
        emitRotSpread=50,
        emitVector = [[0, 1, 0]],
        gravity = [[0, -0.02, 0]],
        colorMap=[[1 0.66 0.45 0.35    0.44 0.24 0.14 0.45   0.25 0.17 0.13 0.4    0.19 0.16 0.14 0.35   0.1 0.095 0.088 0.25   0.07 0.065 0.058 0.17    0 0 0 0.01]],
        Texture=[[graysmoke]],
        particleLife=7,
        particleLifeSpread=30,
        numparticles=2,
        particleSpeed=2.5,
        particleSpeedSpread=5.5,
        particleSize=30,
        particleSizeSpread=15,
        directional=0,
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
        airdrag            = 0.95,
        colormap           = [[0.8 0.5 0.2 0.01   0.9 0.5 0.2 0.017   0 0 0 0.01]],
        directional        = true,
        emitrot            = 25,
        emitrotspread      = 40,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.3, 0]],
        numparticles       = 14,
        particlelife       = 3,
        particlelifespread = 10,
        particlesize       = 5,
        particlesizespread = 24,
        particlespeed      = 1.2,
        particlespeedspread = 4,
        pos                = [[0, 4, 0]],
        sizegrowth         = 1,
        sizemod            = 0.8,
        texture            = [[gunshotglow]],
        useairlos          = false,
      },
    },
    dirt = {
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.95,
        colormap           = [[0.04 0.03 0.01 0   0.1 0.07 0.033 0.66    0.1 0.07 0.03 0.58   0.08 0.065 0.035 0.47   0.075 0.07 0.06 0.4   0 0 0 0  ]],
        directional        = true,
        emitrot            = 24,
        emitrotspread      = 30,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.33, 0]],
        numparticles       = 14,
        particlelife       = 18,
        particlelifespread = 14,
        particlesize       = 1.6,
        particlesizespread = -1.3,
        particlespeed      = 3.5,
        particlespeedspread = 4.7,
        pos                = [[0, 3, 0]],
        sizegrowth         = -0.01,
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
        airdrag            = 0.95,
        colormap           = [[0.04 0.03 0.01 0   0.1 0.07 0.033 0.66    0.1 0.07 0.03 0.58   0.08 0.065 0.035 0.47   0.075 0.07 0.06 0.4   0 0 0 0  ]],
        directional        = true,
        emitrot            = 0,
        emitrotspread      = 16,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.33, 0]],
        numparticles       = 7,
        particlelife       = 33,
        particlelifespread = 15,
        particlesize       = 1.5,
        particlesizespread = -1.25,
        particlespeed      = 3,
        particlespeedspread = 6.2,
        pos                = [[0, 3, 0]],
        sizegrowth         = -0.01,
        sizemod            = 1,
        texture            = [[bigexplosmoke]],
        useairlos          = false,
      },
    },
    shard1 = {
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.93,
        colormap           = [[1 0.55 0.45 1    0.55 0.44 0.38 1    0.36 0.34 0.33 1    0 0 0 0.01]],
        directional        = true,
        emitrot            = 15,
        emitrotspread      = 25,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.3, 0]],
        numparticles       = [[2.5 r1.5]],
        particlelife       = 24,
        particlelifespread = 15,
        particlesize       = 2,
        particlesizespread = 3,
        particlespeed      = 2.8,
        particlespeedspread = 6.5,
        pos                = [[0, 2, 0]],
        sizegrowth         = 0,
        sizemod            = 1,
        texture            = [[shard1]],
        useairlos          = false,
      },
    },
    shard2 = {
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.93,
        colormap           = [[1 0.55 0.45 1    0.55 0.44 0.38 1    0.36 0.34 0.33 1    0 0 0 0.01]],
        directional        = true,
        emitrot            = 15,
        emitrotspread      = 25,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.3, 0]],
        numparticles       = [[2.5 r1.5]],
        particlelife       = 24,
        particlelifespread = 15,
        particlesize       = 2,
        particlesizespread = 3,
        particlespeed      = 2.8,
        particlespeedspread = 6.5,
        pos                = [[0, 2, 0]],
        sizegrowth         = 0,
        sizemod            = 1,
        texture            = [[shard2]],
        useairlos          = false,
      },
    },
    shard3 = {
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.93,
        colormap           = [[1 0.55 0.45 1    0.55 0.44 0.38 1    0.36 0.34 0.33 1    0 0 0 0.01]],
        directional        = true,
        emitrot            = 15,
        emitrotspread      = 25,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.3, 0]],
        numparticles       = [[2.5 r1.5]],
        particlelife       = 28,
        particlelifespread = 12,
        particlesize       = 2,
        particlesizespread = 3,
        particlespeed      = 2.8,
        particlespeedspread = 6.5,
        pos                = [[0, 2, 0]],
        sizegrowth         = 0,
        sizemod            = 1,
        texture            = [[shard3]],
        useairlos          = false,
      },
    },
    clouddust = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.9,
        colormap           = [[0 0 0 0.01  0.022 0.022 0.022 0.03  0.05 0.05 0.05 0.068  0.042 0.042 0.042 0.052  0.023 0.023 0.023 0.028  0 0 0 0.01]],
        directional        = false,
        emitrot            = 45,
        emitrotspread      = 4,
        emitvector         = [[0.5, 1.35, 0.5]],
        gravity            = [[0, 0.03, 0]],
        numparticles       = 4,
        particlelife       = 70,
        particlelifespread = 350,
        particlesize       = 45,
        particlesizespread = 70,
        particlespeed      = 3,
        particlespeedspread = 4,
        pos                = [[0, 4, 0]],
        sizegrowth         = 0.35,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
      },
    },
    grounddust = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      unit               = false,
      properties = {
        airdrag            = 0.92,
        colormap           = [[0.07 0.07 0.07 0.1 	0 0 0 0.0]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = -2,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.03, 0]],
        numparticles       = 45,
        particlelife       = 10,
        particlelifespread = 90,
        particlesize       = 4.8,
        particlesizespread = 2.7,
        particlespeed      = 3,
        particlespeedspread = 1.3,
        pos                = [[0, 5, 0]],
        sizegrowth         = 0.18,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
      },
    },
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

-- add different sizes
definitions[root] = definitions[root.."-small"]
local sizes = {

  tiny = {
    centerflare = {
      properties = {
        size               = 1.3,
        sizegrowth         = 11,
      },
    },
    groundflash_large = {
      properties = {
        colormap           = [[1 0.7 0.3 0.24   0 0 0 0.01]],
        size               = 70,
        ttl                = 17,
      },
    },
    groundflash_white = {
      properties = {
        colormap           = [[1 0.9 0.75 0.08   0 0 0 0.01]],
        size               = 62,
        ttl                = 4,
      },
    },
    heatedgroundflash = {
      properties = {
        size = 8,
        ttl = 28,
      },
    },
	explosion = {
      properties = {
        numparticles       = 14,
        particlelifespread = 8,
        particlesize       = 1.75,
        particlesizespread = 3.75,
        particlespeedspread = 2,
	  }
	},
    fireglow = {
      properties = {
        particlesize       = 14,
        particlelife       = 11,
      }
    },
    fireglow2 = {
      properties = {
        particlesize       = 33,
        particlelife       = 14,
      }
    },
    innersmoke = {
      properties = {
        particleLife = 13,
        particleLifeSpread = 36,
        numparticles = 2,
        particleSpeed = 1.5,
        particleSpeedSpread = 3.5,
        particleSize = 7,
        particleSizeSpread = 14,
      },
    },
    outersmoke = {
      properties = {
        particleLife = 6,
        particleLifeSpread = 23,
        numparticles = 2,
        particleSpeed = 1.8,
        particleSpeedSpread = 4.2,
        particleSize = 24,
        particleSizeSpread = 11,
      },
    },
    sparks = {
      properties = {
        numparticles = 10,
        particlespeed      = 1,
        particlespeedspread = 2.9,
	   	}
    },
    dirt = {
      properties = {
	    numparticles = 10,
        particlelifespread = 13,
        particlespeed      = 2.75,
        particlespeedspread = 3.6,
	   	}
    },
    dirt2 = {
      properties = {
	    numparticles = 5,
        particlelifespread = 17,
        particlespeed      = 2.66,
        particlespeedspread = 4.3,
	   	}
    },
    shard1 = {
      properties = {
        numparticles       = [[1 r1.5]],
        particlelife       = 22,
        particlesize       = 1.8,
        particlesizespread = 2.3,
        particlespeed      = 2,
        particlespeedspread = 4.5,
      },
    },
    shard2 = {
      properties = {
        numparticles       = [[1 r1.5]],
        particlelife       = 22,
        particlesize       = 1.8,
        particlesizespread = 2.3,
        particlespeed      = 2,
        particlespeedspread = 4.5,
      },
    },
    shard3 = {
      properties = {
        numparticles       = [[1 r1.5]],
        particlelife       = 22,
        particlesize       = 1.8,
        particlesizespread = 2.3,
        particlespeed      = 2,
        particlespeedspread = 4.5,
      },
    },
    clouddust = {
      properties = {
        numparticles       = 2,
      	particlelifespread = 280,
        particlesize       = 33,
        particlesizespread = 55,
      }
    },
    grounddust = {
      properties = {
        numparticles       = 25,
        particlelifespread = 65,
        particlesize       = 3.8,
        particlesizespread = 2,
        particlespeed      = 2.25,
        particlespeedspread = 0.9,
	   	}
    },
  },
	
  small = {
	
  },
	
  medium = {
    centerflare = {
      properties = {
        size               = 3,
        sizegrowth         = 22,
      },
    },
    groundflash_large = {
      properties = {
        colormap           = [[1 0.7 0.3 0.32   0 0 0 0.01]],
        size               = 205,
        ttl                = 26,
      },
    },
      groundflash_white = {
          properties = {
              colormap           = [[1 0.9 0.75 0.1   0 0 0 0.01]],
              size               = 185,
              ttl                = 5,
          },
      },
    heatedgroundflash = {
      properties = {
        size = 20,
        ttl = 36,
      },
    },
	explosion = {
      properties = {
        numparticles       = 36,
        particlelifespread = 11,
        particlesize       = 3.3,
        particlesizespread = 10,
        particlespeedspread = 6,
	  }
	},
    fireglow = {
      properties = {
        particlesize       = 30,
        particlelife       = 16,
      }
    },
    fireglow2 = {
      properties = {
        particlesize       = 60,
        particlelife       = 18,
      }
    },
    innersmoke = {
      properties = {
        particleLife = 20,
        particleLifeSpread = 60,
        numparticles = 4,
        particleSpeed = 3,
        particleSpeedSpread = 7,
        particleSize = 15,
        particleSizeSpread = 28,
      },
    },
    outersmoke = {
      properties = {
        particleLife = 10,
        particleLifeSpread = 44,
        numparticles = 3,
        particleSpeed = 3.2,
        particleSpeedSpread = 7.5,
        particleSize = 40,
        particleSizeSpread = 21,
      },
    },
    sparks = {
      properties = {
	    numparticles = 22,
	    sizemod = 0.815,
        particlespeed      = 2.5,
        particlespeedspread = 5,
	  }
    },
    dirt = {
      properties = {
	    numparticles = 22,
        particlelifespread = 44,
        particlespeed      = 3.5,
        particlespeedspread = 4.4,
	  }
    },
    dirt2 = {
      properties = {
	    numparticles = 11,
        particlelifespread = 50,
        particlespeed      = 3.5,
        particlespeedspread = 5.5,
	  }
    },
    shard1 = {
      properties = {
        numparticles       = [[7 r3.5]],
        particlelife       = 40,
        particlesize       = 2.3,
        particlesizespread = 3,
        particlespeed      = 4,
        particlespeedspread = 8,
      },
    },
    shard2 = {
      properties = {
        numparticles       = [[7 r3.5]],
        particlelife       = 40,
        particlesize       = 2.3,
        particlesizespread = 3,
        particlespeed      = 4,
        particlespeedspread = 8,
      },
    },
    shard3 = {
      properties = {
        numparticles       = [[7 r3.5]],
        particlelife       = 40,
        particlesize       = 2.3,
        particlesizespread = 3,
        particlespeed      = 4,
        particlespeedspread = 8,
      },
    },
    clouddust = {
      properties = {
        numparticles       = 5,
      	particlelifespread = 400,
        particlesize       = 70,
        particlesizespread = 90,
      }
    },
    grounddust = {
      properties = {
        numparticles       = 95,
        particlelifespread = 100,
        particlesize       = 6,
        particlesizespread = 3,
        particlespeed      = 4.5,
        particlespeedspread = 1.7,
	  }
    },
  },
	
  large = {
    centerflare = {
      properties = {
        size               = 4,
        sizegrowth         = 32,
      },
    },
    groundflash_large = {
      properties = {
        colormap           = [[1 0.7 0.3 0.35   0 0 0 0.01]],
        size               = 255,
        ttl                = 25,
      },
    },
      groundflash_white = {
          properties = {
              colormap           = [[1 0.9 0.75 0.11   0 0 0 0.01]],
              size               = 230,
              ttl                = 6,
          },
      },
    heatedgroundflash = {
      properties = {
        size = 30,
        ttl = 43,
      },
    },
	explosion = {
      properties = {
        numparticles       = 44,
        particlelifespread = 13,
        particlesize       = 4,
        particlesizespread = 13,
        particlespeedspread = 8,
	  }
	},
    fireglow = {
      properties = {
        particlesize       = 50,
        particlelife       = 17,
      }
    },
    fireglow2 = {
      properties = {
        particlesize       = 100,
        particlelife       = 19,
      }
    },
    innersmoke = {
      properties = {
        particleLife = 26,
        particleLifeSpread = 75,
        numparticles = 5,
        particleSpeed = 3,
        particleSpeedSpread = 10,
        particleSize = 20,
        particleSizeSpread = 36,
      },
    },
    outersmoke = {
      properties = {
        particleLife = 14,
        particleLifeSpread = 60,
        numparticles = 3,
        particleSpeed = 3.2,
        particleSpeedSpread = 10.5,
        particleSize = 55,
        particleSizeSpread = 37,
      },
    },
    sparks = {
      properties = {
	    numparticles = 30,
	    sizemod = 0.83,
        particlespeed      = 2.8,
        particlespeedspread = 5.5,
	  }
    },
    dirt = {
      properties = {
	    numparticles = 26,
        particlelifespread = 50,
        particlespeed      = 5,
        particlespeedspread = 6,
	  }
    },
    dirt2 = {
      properties = {
	    numparticles = 13,
        particlelifespread = 55,
        particlespeed      = 5.3,
        particlespeedspread = 7.3,
	  }
    },
    shard1 = {
      properties = {
        numparticles       = [[8 r4.5]],
        particlelife       = 50,
        particlesize       = 2.5,
        particlesizespread = 4.5,
        particlespeed      = 5.5,
        particlespeedspread = 10.5,
      },
    },
    shard2 = {
      properties = {
        numparticles       = [[8 r4.5]],
        particlelife       = 50,
        particlesize       = 2.5,
        particlesizespread = 4.5,
        particlespeed      = 5,
        particlespeedspread = 10.5,
      },
    },
    shard3 = {
      properties = {
        numparticles       = [[8 r4.5]],
        particlelife       = 50,
        particlesize       = 2.5,
        particlesizespread = 4.5,
        particlespeed      = 5,
        particlespeedspread = 10.5,
      },
    },
    clouddust = {
      properties = {
        numparticles       = 8,
      	particlelifespread = 450,
        particlesize       = 85,
        particlesizespread = 90,
      }
    },
    grounddust = {
      properties = {
        numparticles       = 120,
        particlelifespread = 115,
        particlesize       = 8.5,
        particlesizespread = 4.4,
        particlespeed      = 6.2,
        particlespeedspread = 3.3,
	  }
    },
  },

  huge = {
    centerflare = {
      properties = {
        size               = 5.5,
        sizegrowth         = 40,
      },
    },
    groundflash_large = {
      properties = {
        colormap           = [[1 0.7 0.3 0.4   0 0 0 0.01]],
        size               = 310,
        ttl                = 30,
      },
    },
      groundflash_white = {
          properties = {
              colormap           = [[1 0.9 0.75 0.12   0 0 0 0.01]],
              size               = 275,
              ttl                = 7,
          },
      },
    heatedgroundflash = {
      properties = {
        size = 36,
        ttl = 47,
      },
    },
    explosion = {
      properties = {
        numparticles       = 50,
        particlelifespread = 15,
        particlesize       = 6,
        particlesizespread = 18,
        particlespeedspread = 8.5,
      }
    },
    fireglow = {
      properties = {
        particlesize       = 75,
        particlelife       = 19,
      }
    },
    fireglow2 = {
      properties = {
        particlesize       = 150,
        particlelife       = 21,
      }
    },
    innersmoke = {
      properties = {
        particleLife = 33,
        particleLifeSpread = 90,
        numparticles = 6,
        particleSpeed = 3,
        particleSpeedSpread = 13,
        particleSize = 30,
        particleSizeSpread = 44,
      },
    },
    outersmoke = {
      properties = {
        particleLife = 20,
        particleLifeSpread = 75,
        numparticles = 4,
        particleSpeed = 3.2,
        particleSpeedSpread = 14,
        particleSize = 55,
        particleSizeSpread = 44,
      },
    },
    sparks = {
      properties = {
        numparticles = 50,
        sizemod = 0.84,
        particlespeed      = 3.2,
        particlespeedspread = 7.4,
      }
    },
    dirt = {
      properties = {
        numparticles = 36,
        particlelifespread = 55,
        particlespeed      = 6,
        particlespeedspread = 7.5,
      }
    },
    dirt2 = {
      properties = {
        numparticles = 18,
        particlelifespread = 60,
        particlespeed      = 6.5,
        particlespeedspread = 10,
      }
    },
    shard1 = {
      properties = {
        numparticles       = [[10 r4.5]],
        particlelife       = 55,
        particlesize       = 3,
        particlesizespread = 5,
        particlespeed      = 6.5,
        particlespeedspread = 13,
      },
    },
    shard2 = {
      properties = {
        numparticles       = [[10 r4.5]],
        particlelife       = 55,
        particlesize       = 3,
        particlesizespread = 5,
        particlespeed      = 6.5,
        particlespeedspread = 13,
      },
    },
    shard3 = {
      properties = {
        numparticles       = [[10 r4.5]],
        particlelife       = 55,
        particlesize       = 3,
        particlesizespread = 5,
        particlespeed      = 6.5,
        particlespeedspread = 13,
      },
    },
    clouddust = {
      properties = {
        numparticles       = 10,
        particlelifespread = 500,
        particlesize       = 100,
        particlesizespread = 100,
      }
    },
    grounddust = {
      properties = {
        numparticles       = 150,
        particlelifespread = 130,
        particlesize       = 11,
        particlesizespread = 5,
        particlespeed      = 9,
        particlespeedspread = 4,
      }
    },
  },

  gigantic = {
    centerflare = {
      properties = {
        size               = 5.5,
        sizegrowth         = 40,
      },
    },
    groundflash_large = {
      properties = {
        colormap           = [[1 0.7 0.3 0.4   0 0 0 0.01]],
        size               = 400,
        ttl                = 33,
      },
    },
      groundflash_white = {
          properties = {
              colormap           = [[1 0.9 0.75 0.13   0 0 0 0.01]],
              size               = 360,
              ttl                = 7,
          },
      },
    heatedgroundflash = {
      properties = {
        size = 45,
        ttl = 53,
      },
    },
    explosion = {
      properties = {
        numparticles       = 60,
        particlelifespread = 17,
        particlesize       = 7.5,
        particlesizespread = 22,
        particlespeedspread = 10.5,
      }
    },
    fireglow = {
      properties = {
        particlesize       = 88,
        particlelife       = 21,
      }
    },
    fireglow2 = {
      properties = {
        particlesize       = 185,
        particlelife       = 23,
      }
    },
    innersmoke = {
      properties = {
        particleLife = 36,
        particleLifeSpread = 100,
        numparticles = 7,
        particleSpeed = 3.2,
        particleSpeedSpread = 16,
        particleSize = 36,
        particleSizeSpread = 44,
      },
    },
    outersmoke = {
      properties = {
        particleLife = 23,
        particleLifeSpread = 85,
        numparticles = 5,
        particleSpeed = 3.4,
        particleSpeedSpread = 19,
        particleSize = 65,
        particleSizeSpread = 50,
      },
    },
    sparks = {
      properties = {
        numparticles = 55,
        sizemod = 0.85,
        particlespeed      = 3.6,
        particlespeedspread = 10.5,
      }
    },
    dirt = {
      properties = {
        numparticles = 40,
        particlelifespread = 60,
        particlespeed      = 8,
        particlespeedspread = 10.5,
      }
    },
    dirt2 = {
      properties = {
        numparticles = 22,
        particlelifespread = 65,
        particlespeed      = 8.5,
        particlespeedspread = 14,
      }
    },
    shard1 = {
      properties = {
        numparticles       = [[11 r4.5]],
        particlelife       = 55,
        particlesize       = 3.4,
        particlesizespread = 6,
        particlespeed      = 8,
        particlespeedspread = 15.5,
      },
    },
    shard2 = {
      properties = {
        numparticles       = [[11 r4.5]],
        particlelife       = 55,
        particlesize       = 3.4,
        particlesizespread = 6,
        particlespeed      = 8,
        particlespeedspread = 15.5,
      },
    },
    shard3 = {
      properties = {
        numparticles       = [[11 r4.5]],
        particlelife       = 55,
        particlesize       = 3.4,
        particlesizespread = 6,
        particlespeed      = 8,
        particlespeedspread = 15.5,
      },
    },
    clouddust = {
      properties = {
        numparticles       = 12,
        particlelifespread = 500,
        particlesize       = 120,
        particlesizespread = 120,
      }
    },
    grounddust = {
      properties = {
        numparticles       = 150,
        particlelifespread = 130,
        particlesize       = 12,
        particlesizespread = 6,
        particlespeed      = 13,
        particlespeedspread = 5.5,
      }
    },
  },
}
for size, effects in pairs(sizes) do
	definitions[root.."-"..size] = tableMerge(deepcopy(definitions[root.."-small"]), deepcopy(effects))
end

definitions[root..'-wind'] = deepcopy(definitions[root.."-small"])
definitions[root..'-wind'].clouddust.properties.numparticles = definitions[root..'-wind'].clouddust.properties.numparticles / 3
definitions[root..'-wind'].grounddust.properties.numparticles = definitions[root..'-wind'].grounddust.properties.numparticles / 3
definitions[root..'-wind'].dirt.properties.numparticles = definitions[root..'-wind'].dirt.properties.numparticles / 2
definitions[root..'-wind'].dirt2.properties.numparticles = definitions[root..'-wind'].dirt2.properties.numparticles / 2
definitions[root..'-wind'].sparks.properties.numparticles = definitions[root..'-wind'].sparks.properties.numparticles / 2

definitions[root..'-nano'] = deepcopy(definitions[root.."-wind"])
definitions[root..'-nano'].explosion.properties.colormap = [[0 0 0 0   0.9 1 0.7 0.09   0.75 0.9 0.21 0.066   0.5 0.66 0.04 0.033   0 0 0 0.01]]
definitions[root..'-nano'].fireglow.properties.colormap = [[0.12 0.15 0.1 0.005  0 0 0 0.01]]
definitions[root..'-nano'].fireglow2.properties.colormap = [[0.22 0.26 0.08 0.26   0.33 0.44 0.13 0.44   0.14 0.2 0 0.2   0 0 0 0.01]]
definitions[root..'-wind'].sparks.properties.colormap = [[0.5 0.8 0.2 0.01   0.5 0.9 0.2 0.017   0 0 0 0.01]]
definitions[root..'-wind'].sparks.properties.numparticles = definitions[root..'-wind'].sparks.properties.numparticles * 2

definitions['genericshellexplosion-meteor'] = deepcopy(definitions[root.."-huge"])
definitions['genericshellexplosion-meteor'].groundflash_large.alwaysvisible = true
definitions['genericshellexplosion-meteor'].groundflash_white.alwaysvisible = true
definitions['genericshellexplosion-meteor'].heatedgroundflash.alwaysvisible = true
definitions['genericshellexplosion-meteor'].explosion.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].centerflare.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].sparks.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].innersmoke.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].outersmoke.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].dirt.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].dirt2.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].shard1 = nil
definitions['genericshellexplosion-meteor'].shard2 = nil
definitions['genericshellexplosion-meteor'].shard3 = nil
definitions['genericshellexplosion-meteor'].grounddust.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].clouddust.properties.alwaysvisible = true
--definitions['genericshellexplosion-meteor'].groundclouddust.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].kickedupwater.properties.alwaysvisible = true


-- add coloring
--local colors = {
--	--blue = {
--	--	groundflash = {
--	--		color = {0.15,0.15,1},
--	--	}
--	},
--}
--for color, effects in pairs(colors) do
--	for size, e in pairs(sizes) do
--		definitions[root.."-"..size.."-"..color] = tableMerge(deepcopy(definitions[root.."-"..size]), deepcopy(effects))
--	end
--end

return definitions
