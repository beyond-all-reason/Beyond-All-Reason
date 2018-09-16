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
        sizegrowth         = 17,
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
        colormap           = [[1 0.7 0.3 0.3   0 0 0 0.01]],
        size               = 120,
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
        colormap           = [[1 0.9 0.75 0.3   0 0 0 0.01]],
        size               = 85,
        sizegrowth         = 0,
        ttl                = 5,
        texture            = [[groundflash]],
      },
    },
    --kickedupwater = {
    --  class              = [[CSimpleParticleSystem]],
    --  count              = 1,
    --  water              = true,
	--  underwater         = true,
    --  properties = {
    --    airdrag            = 0.87,
    --    colormap           = [[0.7 0.7 0.9 0.35	0 0 0 0.0]],
    --    directional        = false,
    --    emitrot            = 90,
    --    emitrotspread      = 5,
    --    emitvector         = [[0, 1, 0]],
    --    gravity            = [[0, 0.1, 0]],
    --    numparticles       = 80,
    --    particlelife       = 2,
    --    particlelifespread = 30,
    --    particlesize       = 2,
    --    particlesizespread = 1,
    --    particlespeed      = 10,
    --    particlespeedspread = 6,
    --    pos                = [[0, 1, 0]],
    --    sizegrowth         = 0.5,
    --    sizemod            = 1.0,
    --    texture            = [[wake]],
    --  },
    --},
    explosion = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.82,
        colormap           = [[0 0 0 0   1 0.8 0.5 0.09   0.9 0.4 0.15 0.066   0.66 0.28 0.03 0.033   0 0 0 0.01]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.01, 0]],
        numparticles       = 9,
        particlelife       = 4,
        particlelifespread = 9,
        particlesize       = 3.2,
        particlesizespread = 5,
        particlespeed      = 2,
        particlespeedspread = 3.75,
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
        colormap           = [[0.35 0.32 0.23 0.01   0 0 0 0.01]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 1,
        particlelife       = 13,
        particlelifespread = 0,
        particlesize       = 22,
        particlesizespread = 4,
        particlespeed      = 0,
        particlespeedspread = 0,
        pos                = [[0, 2, 0]],
        sizegrowth         = 1.5,
        sizemod            = 1,
        texture            = [[glow2]],
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
        sizeGrowth = 0.5,
        sizeMod = 1.0,
        pos = [[r-1 r1, 0, r-1 r1]],
        emitRot=33,
        emitRotSpread=50,
        emitVector = [[0, 1, 0]],
        gravity = [[0, 0.02, 0]],
        colorMap=[[1 0.6 0.35 0.6    0.3 0.2 0.1 0.5   0.18 0.14 0.09 0.44    0.12 0.1 0.08 0.33   0.09 0.09 0.085 0.26   0.06 0.06 0.05 0.16    0 0 0 0.01]],
        Texture=[[graysmoke]],
        particleLife=25,
        particleLifeSpread=70,
        numparticles=4,
        particleSpeed=2,
        particleSpeedSpread=5,
        particleSize=7,
        particleSizeSpread=15
      },
    },
    outersmoke = {
      class = [[CSimpleParticleSystem]],
      water=0,
      air=1,
      ground=1,
      count=1,
      properties = {
        airdrag=0.35,
        alwaysVisible = 0,
        sizeGrowth = 0.45,
        sizeMod = 1.0,
        pos = [[r-1 r1, 0, r-1 r1]],
        emitRot=33,
        emitRotSpread=50,
        emitVector = [[0, 1, 0]],
        gravity = [[0, -0.02, 0]],
        colorMap=[[1 0.6 0.35 0.6    0.3 0.2 0.1 0.5   0.18 0.14 0.09 0.44    0.12 0.1 0.08 0.33   0.09 0.09 0.085 0.26   0.06 0.06 0.05 0.16    0 0 0 0.01]],
        Texture=[[graysmoke]],
        particleLife=15,
        particleLifeSpread=50,
        numparticles=3,
        particleSpeed=2.5,
        particleSpeedSpread=5.5,
        particleSize=20,
        particleSizeSpread=11,
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
        airdrag            = 0.96,
        colormap           = [[0.9 0.85 0.77 0.017   0.8 0.55 0.3 0.011   0 0 0 0]],
        directional        = true,
        emitrot            = 25,
        emitrotspread      = 40,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.3, 0]],
        numparticles       = 4,
        particlelife       = 7,
        particlelifespread = 7,
        particlesize       = 70,
        particlesizespread = 120,
        particlespeed      = 2.4,
        particlespeedspread = 4.55,
        pos                = [[0, 4, 0]],
        sizegrowth         = 1,
        sizemod            = 0.66,
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
        numparticles       = 4,
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
        numparticles       = 2,
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
        numparticles       = [[1 r1.25]],
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
        numparticles       = [[1 r1.25]],
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
        numparticles       = [[r1.25]],
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
        numparticles       = 2,
        particlelife       = 30,
        particlelifespread = 110,
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
        numparticles       = 13,
        particlelife       = 10,
        particlelifespread = 90,
        particlesize       = 5.2,
        particlesizespread = 2.8,
        particlespeed      = 3.2,
        particlespeedspread = 1.35,
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
        size               = 75,
        ttl                = 17,
      },
    },
    groundflash_white = {
      properties = {
        colormap           = [[1 0.9 0.75 0.33   0 0 0 0.01]],
        size               = 55,
        ttl                = 5,
      },
    },
	explosion = {
      properties = {
        numparticles       = 6,
        particlelifespread = 8,
        particlesize       = 3,
        particlesizespread = 4,
        particlespeed      = 1.5,
        particlespeedspread = 2.5,
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
        particleLife = 20,
        particleLifeSpread = 55,
        numparticles = 3,
        particleSpeed = 1.5,
        particleSpeedSpread = 3.5,
        particleSize = 6,
        particleSizeSpread = 12,
      },
    },
    outersmoke = {
      properties = {
        particleLife = 12,
        particleLifeSpread = 38,
        numparticles = 3,
        particleSpeed = 1.8,
        particleSpeedSpread = 4.2,
        particleSize = 18,
        particleSizeSpread = 9,
      },
    },
    sparks = {
      properties = {
        numparticles = 3,
        particlespeed      = 1.66,
        particlespeedspread = 3,
	   	}
    },
    dirt = {
      properties = {
	    numparticles = 1,
        particlelifespread = 13,
        particlespeed      = 3,
        particlespeedspread = 3.7,
	   	}
    },
    dirt2 = {
      properties = {
	    numparticles = 1,
        particlelifespread = 17,
        particlespeed      = 2.8,
        particlespeedspread = 4.4,
	   	}
    },
    shard1 = {
      properties = {
        numparticles       = [[1 r0.75]],
        particlelife       = 22,
        particlesize       = 1.8,
        particlesizespread = 2.3,
        particlespeed      = 2.2,
        particlespeedspread = 4.5,
      },
    },
    shard2 = {
      properties = {
        numparticles       = [[r1.25]],
        particlelife       = 22,
        particlesize       = 1.8,
        particlesizespread = 2.3,
        particlespeed      = 2.2,
        particlespeedspread = 4.5,
      },
    },
    shard3 = {
      properties = {
        numparticles       = [[r1.1]],
        particlelife       = 22,
        particlesize       = 1.8,
        particlesizespread = 2.3,
        particlespeed      = 2.2,
        particlespeedspread = 4.5,
      },
    },
    clouddust = {
      properties = {
        numparticles       = 1,
      	particlelifespread = 50,
        particlesize       = 33,
        particlesizespread = 55,
      }
    },
    grounddust = {
      properties = {
        numparticles       = 10,
        particlelifespread = 65,
        particlesize       = 4.1,
        particlesizespread = 2.1,
        particlespeed      = 2.33,
        particlespeedspread = 1,
	  }
    },
  },
	
  small = {
	
  },
	
  medium = {
    centerflare = {
      properties = {
        size               = 3,
        sizegrowth         = 23,
      },
    },
    groundflash_large = {
      properties = {
        colormap           = [[1 0.7 0.3 0.36   0 0 0 0.01]],
        size               = 215,
        ttl                = 26,
      },
    },
    groundflash_white = {
      properties = {
        colormap           = [[1 0.9 0.75 0.36   0 0 0 0.01]],
        size               = 166,
        ttl                = 6,
      },
    },
	explosion = {
      properties = {
        numparticles       = 12,
        particlelifespread = 11,
        particlesize       = 6.5,
        particlesizespread = 11,
        particlespeed      = 2.5,
        particlespeedspread = 7,
	  }
	},
    fireglow = {
      properties = {
        particlesize       = 33,
        particlelife       = 16,
      }
    },
    fireglow2 = {
      properties = {
        particlesize       = 64,
        particlelife       = 18,
      }
    },
    innersmoke = {
      properties = {
        particleLife = 32,
        particleLifeSpread = 80,
        numparticles = 5,
        particleSpeed = 3,
        particleSpeedSpread = 7,
        particleSize = 11,
        particleSizeSpread = 20,
      },
    },
    outersmoke = {
      properties = {
        particleLife = 24,
        particleLifeSpread = 60,
        numparticles = 4,
        particleSpeed = 3.2,
        particleSpeedSpread = 7.5,
        particleSize = 26,
        particleSizeSpread = 15,
      },
    },
    sparks = {
      properties = {
	    numparticles = 7,
        particlespeed      = 3.3,
        particlespeedspread = 6,
	  }
    },
    dirt = {
      properties = {
	    numparticles = 6,
        particlelifespread = 40,
        particlespeed      = 3.7,
        particlespeedspread = 4.7,
	  }
    },
    dirt2 = {
      properties = {
	    numparticles = 3,
        particlelifespread = 45,
        particlespeed      = 3.7,
        particlespeedspread = 5.7,
	  }
    },
    shard1 = {
      properties = {
        numparticles       = [[2 r2.25]],
        particlelife       = 40,
        particlesize       = 2.3,
        particlesizespread = 3,
        particlespeed      = 4,
        particlespeedspread = 8,
      },
    },
    shard2 = {
      properties = {
        numparticles       = [[2 r1.25]],
        particlelife       = 30,
        particlesize       = 2.3,
        particlesizespread = 3,
        particlespeed      = 4,
        particlespeedspread = 8,
      },
    },
    shard3 = {
      properties = {
        numparticles       = [[1 r1.25]],
        particlelife       = 25,
        particlesize       = 2.3,
        particlesizespread = 3,
        particlespeed      = 4,
        particlespeedspread = 8,
      },
    },
    clouddust = {
      properties = {
        numparticles       = 3,
      	particlelifespread = 130,
        particlesize       = 72,
        particlesizespread = 95,
      }
    },
    grounddust = {
      properties = {
        numparticles       = 16,
        particlelifespread = 90,
        particlesize       = 7,
        particlesizespread = 3.3,
        particlespeed      = 4.75,
        particlespeedspread = 1.75,
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
        colormap           = [[1 0.7 0.3 0.38   0 0 0 0.01]],
        size               = 265,
        ttl                = 25,
      },
    },
    groundflash_white = {
      properties = {
        colormap           = [[1 0.9 0.75 0.38   0 0 0 0.01]],
        size               = 200,
        ttl                = 7,
      },
    },
	explosion = {
      properties = {
        numparticles       = 16,
        particlelifespread = 13,
        particlesize       = 10,
        particlesizespread = 14,
        particlespeed      = 3.8,
        particlespeedspread = 9.5,
	  }
	},
    fireglow = {
      properties = {
        particlesize       = 53,
        particlelife       = 17,
      }
    },
    fireglow2 = {
      properties = {
        particlesize       = 105,
        particlelife       = 19,
      }
    },
    innersmoke = {
      properties = {
        particleLife = 40,
        particleLifeSpread = 100,
        numparticles = 6,
        particleSpeed = 3,
        particleSpeedSpread = 10,
        particleSize = 18,
        particleSizeSpread = 25,
      },
    },
    outersmoke = {
      properties = {
        particleLife = 32,
        particleLifeSpread = 80,
        numparticles = 4,
        particleSpeed = 3.2,
        particleSpeedSpread = 10.5,
        particleSize = 40,
        particleSizeSpread = 28,
      },
    },
    sparks = {
      properties = {
	    numparticles = 10,
        particlespeed      = 3.75,
        particlespeedspread = 6.8,
	  }
    },
    dirt = {
      properties = {
	    numparticles = 7,
        particlelifespread = 50,
        particlespeed      = 5.5,
        particlespeedspread = 6.2,
	  }
    },
    dirt2 = {
      properties = {
	    numparticles = 4,
        particlelifespread = 55,
        particlespeed      = 5.75,
        particlespeedspread = 7.5,
	  }
    },
    shard1 = {
      properties = {
        numparticles       = [[3 r2]],
        particlelife       = 50,
        particlesize       = 2.5,
        particlesizespread = 4.5,
        particlespeed      = 5.6,
        particlespeedspread = 10.5,
      },
    },
    shard2 = {
      properties = {
        numparticles       = [[2 r1.4]],
        particlelife       = 40,
        particlesize       = 2.5,
        particlesizespread = 4.5,
        particlespeed      = 5.2,
        particlespeedspread = 10.5,
      },
    },
    shard3 = {
      properties = {
        numparticles       = [[1 r1.2]],
        particlelife       = 45,
        particlesize       = 2.5,
        particlesizespread = 4.5,
        particlespeed      = 5.2,
        particlespeedspread = 10.5,
      },
    },
    clouddust = {
      properties = {
        numparticles       = 4,
      	particlelifespread = 160,
        particlesize       = 85,
        particlesizespread = 90,
      }
    },
    grounddust = {
      properties = {
        numparticles       = 22,
        particlelifespread = 115,
        particlesize       = 10,
        particlesizespread = 5,
        particlespeed      = 6.7,
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
        size               = 330,
        ttl                = 30,
      },
    },
    groundflash_white = {
      properties = {
        colormap           = [[1 0.9 0.75 0.4   0 0 0 0.01]],
        size               = 250,
        ttl                = 7.5,
      },
    },
    explosion = {
      properties = {
        numparticles       = 20,
        particlelifespread = 15,
        particlesize       = 13,
        particlesizespread = 20,
        particlespeed      = 5.5,
        particlespeedspread = 10,
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
        particleLife = 45,
        particleLifeSpread = 125,
        numparticles = 7,
        particleSpeed = 3.2,
        particleSpeedSpread = 13,
        particleSize = 20,
        particleSizeSpread = 30,
      },
    },
    outersmoke = {
      properties = {
        particleLife = 35,
        particleLifeSpread = 100,
        numparticles = 5,
        particleSpeed = 3.4,
        particleSpeedSpread = 14,
        particleSize = 38,
        particleSizeSpread = 30,
      },
    },
    sparks = {
      properties = {
        numparticles = 10,
        particlespeed      = 4.2,
        particlespeedspread = 8,
      }
    },
    dirt = {
      properties = {
        numparticles = 7,
        particlelifespread = 55,
        particlespeed      = 7,
        particlespeedspread = 7.7,
      }
    },
    dirt2 = {
      properties = {
        numparticles = 4,
        particlelifespread = 60,
        particlespeed      = 7.5,
        particlespeedspread = 10.3,
      }
    },
    shard1 = {
      properties = {
        numparticles       = [[3 r3]],
        particlelife       = 55,
        particlesize       = 3,
        particlesizespread = 5,
        particlespeed      = 6.5,
        particlespeedspread = 15,
      },
    },
    shard2 = {
      properties = {
        numparticles       = [[2 r2]],
        particlelife       = 45,
        particlesize       = 3,
        particlesizespread = 5,
        particlespeed      = 6.5,
        particlespeedspread = 15,
      },
    },
    shard3 = {
      properties = {
        numparticles       = [[1 r2]],
        particlelife       = 50,
        particlesize       = 3,
        particlesizespread = 5,
        particlespeed      = 6.5,
        particlespeedspread = 15,
      },
    },
    clouddust = {
      properties = {
        numparticles       = 5,
        particlelifespread = 180,
        particlesize       = 100,
        particlesizespread = 100,
      }
    },
    grounddust = {
      properties = {
        numparticles       = 24,
        particlelifespread = 130,
        particlesize       = 14,
        particlesizespread = 5.5,
        particlespeed      = 11,
        particlespeedspread = 4.4,
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
        colormap           = [[1 0.7 0.3 0.43   0 0 0 0.01]],
        size               = 430,
        ttl                = 33,
      },
    },
    groundflash_white = {
      properties = {
        colormap           = [[1 0.9 0.75 0.43   0 0 0 0.01]],
        size               = 330,
        ttl                = 8,
      },
    },
    explosion = {
      properties = {
        numparticles       = 24,
        particlelifespread = 17,
        particlesize       = 18,
        particlesizespread = 24,
        particlespeed      = 7.5,
        particlespeedspread = 11.5,
      }
    },
    fireglow = {
      properties = {
        particlesize       = 90,
        particlelife       = 21,
      }
    },
    fireglow2 = {
      properties = {
        particlesize       = 190,
        particlelife       = 23,
      }
    },
    innersmoke = {
      properties = {
        particleLife = 65,
        particleLifeSpread = 150,
        numparticles = 8,
        particleSpeed = 3.6,
        particleSpeedSpread = 16,
        particleSize = 26,
        particleSizeSpread = 34,
      },
    },
    outersmoke = {
      properties = {
        particleLife = 45,
        particleLifeSpread = 120,
        numparticles = 6,
        particleSpeed = 4,
        particleSpeedSpread = 19,
        particleSize = 45,
        particleSizeSpread = 32,
      },
    },
    sparks = {
      properties = {
        numparticles = 10,
        particlespeed      = 6.5,
        particlespeedspread = 9,
      }
    },
    dirt = {
      properties = {
        numparticles = 9,
        particlelifespread = 60,
        particlespeed      = 10,
        particlespeedspread = 11,
      }
    },
    dirt2 = {
      properties = {
        numparticles = 4,
        particlelifespread = 65,
        particlespeed      = 10.6,
        particlespeedspread = 14.5,
      }
    },
    shard1 = {
      properties = {
        numparticles       = [[3 r3.5]],
        particlelife       = 55,
        particlesize       = 3.4,
        particlesizespread = 6,
        particlespeed      = 8,
        particlespeedspread = 15.5,
      },
    },
    shard2 = {
      properties = {
        numparticles       = [[3 r2]],
        particlelife       = 55,
        particlesize       = 3.4,
        particlesizespread = 6,
        particlespeed      = 8,
        particlespeedspread = 15.5,
      },
    },
    shard3 = {
      properties = {
        numparticles       = [[2 r2]],
        particlelife       = 55,
        particlesize       = 3.4,
        particlesizespread = 6,
        particlespeed      = 8,
        particlespeedspread = 15.5,
      },
    },
    clouddust = {
      properties = {
        numparticles       = 6,
        particlelifespread = 200,
        particlesize       = 120,
        particlesizespread = 120,
      }
    },
    grounddust = {
      properties = {
        numparticles       = 28,
        particlelifespread = 130,
        particlesize       = 15,
        particlesizespread = 7,
        particlespeed      = 15,
        particlespeedspread = 6,
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
definitions[root..'-nano'].explosion.properties.colormap = [[0 0 0 0   0.92 1 0.7 0.08   0.77 0.9 0.21 0.06   0.57 0.66 0.04 0.03   0 0 0 0.01]]
definitions[root..'-nano'].fireglow.properties.colormap = [[0.15 0.14 0.1 0.005  0 0 0 0.01]]
definitions[root..'-nano'].fireglow2.properties.colormap = [[0.26 0.24 0.08 0.26   0.36 0.44 0.13 0.44   0.15 0.2 0 0.2   0 0 0 0.01]]
definitions[root..'-nano'].sparks.properties.colormap = [[0.85 0.95 0.77 0.017   0.6 0.9 0.3 0.011   0 0 0 0]]
definitions[root..'-nano'].sparks.properties.numparticles = definitions[root..'-nano'].sparks.properties.numparticles * 1.5
definitions[root..'-nano'].dirt.properties.colormap = [[0.8 1 0.4 0.1   0 0 0 0.01]]
definitions[root..'-nano'].dirt2.properties.colormap = [[0.7 1 0.3 0.1   0 0 0 0.01]]

definitions[root..'-metalmaker'] = deepcopy(definitions[root.."-medium"])
definitions[root..'-metalmaker'].clouddust.properties.numparticles = definitions[root..'-metalmaker'].clouddust.properties.numparticles / 3
definitions[root..'-metalmaker'].grounddust.properties.numparticles = definitions[root..'-metalmaker'].grounddust.properties.numparticles / 3
definitions[root..'-metalmaker'].dirt.properties.numparticles = definitions[root..'-metalmaker'].dirt.properties.numparticles / 2
definitions[root..'-metalmaker'].dirt2.properties.numparticles = definitions[root..'-metalmaker'].dirt2.properties.numparticles / 2
definitions[root..'-metalmaker'].sparks.properties.numparticles = definitions[root..'-metalmaker'].sparks.properties.numparticles / 2

definitions[root..'-metalmakerselfd'] = deepcopy(definitions[root.."-large"])
definitions[root..'-metalmakerselfd'].clouddust.properties.numparticles = definitions[root..'-metalmakerselfd'].clouddust.properties.numparticles / 3
definitions[root..'-metalmakerselfd'].grounddust.properties.numparticles = definitions[root..'-metalmakerselfd'].grounddust.properties.numparticles / 3
definitions[root..'-metalmakerselfd'].dirt.properties.numparticles = definitions[root..'-metalmakerselfd'].dirt.properties.numparticles / 2
definitions[root..'-metalmakerselfd'].dirt2.properties.numparticles = definitions[root..'-metalmakerselfd'].dirt2.properties.numparticles / 2
definitions[root..'-metalmakerselfd'].sparks.properties.numparticles = definitions[root..'-metalmakerselfd'].sparks.properties.numparticles / 2

definitions[root..'-advmetalmaker'] = deepcopy(definitions[root.."-metalmakerselfd"])

definitions[root..'-advmetalmakerselfd'] = deepcopy(definitions[root.."-huge"])
definitions[root..'-advmetalmakerselfd'].clouddust.properties.numparticles = definitions[root..'-advmetalmakerselfd'].clouddust.properties.numparticles / 3
definitions[root..'-advmetalmakerselfd'].grounddust.properties.numparticles = definitions[root..'-advmetalmakerselfd'].grounddust.properties.numparticles / 3
definitions[root..'-advmetalmakerselfd'].dirt.properties.numparticles = definitions[root..'-advmetalmakerselfd'].dirt.properties.numparticles / 2
definitions[root..'-advmetalmakerselfd'].dirt2.properties.numparticles = definitions[root..'-advmetalmakerselfd'].dirt2.properties.numparticles / 2
definitions[root..'-advmetalmakerselfd'].sparks.properties.numparticles = definitions[root..'-advmetalmakerselfd'].sparks.properties.numparticles / 2

definitions['genericshellexplosion-meteor'] = deepcopy(definitions[root.."-huge"])
definitions['genericshellexplosion-meteor'].groundflash_large.alwaysvisible = true
definitions['genericshellexplosion-meteor'].groundflash_white.alwaysvisible = true
definitions['genericshellexplosion-meteor'].explosion.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].explosion.properties.particlespeed = 1.5
definitions['genericshellexplosion-meteor'].explosion.properties.particlespeedspread = 11
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
definitions['genericshellexplosion-meteor'].clouddust = nil
--definitions['genericshellexplosion-meteor'].groundclouddust.properties.alwaysvisible = true
--definitions['genericshellexplosion-meteor'].kickedupwater.properties.alwaysvisible = true


local types = {
  uw = {
    groundflash_small = false,
    groundflash_large = false,
    groundflash_white = false,
    explosion = {ground=false, water=false, air=false, underwater=true, properties={colormap=[[0 0 0 0   1 0.75 0.9 0.09   0.45 0.4 0.66 0.066   0.33 0.3 0.05 0.033   0 0 0 0]]}},
    dirt = false,
    dirt2 = false,
    sparks = false,
  },
}
for t, effects in pairs(types) do
  for size, _ in pairs(sizes) do
    definitions[root.."-"..size.."-"..t] = tableMerge(deepcopy(definitions[root.."-"..size]), deepcopy(effects))
  end
end


return definitions
