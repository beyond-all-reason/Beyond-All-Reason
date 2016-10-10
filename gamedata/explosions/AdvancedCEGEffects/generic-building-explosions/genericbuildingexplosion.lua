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
        alwaysvisible      = true,
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
	
    groundflash = {
      air                = true,
      alwaysvisible      = true,
      flashalpha         = 0.25,
      flashsize          = 180,
      ground             = true,
      ttl                = 24,
      water              = true, 
	    underwater         = true,
      color = {
        [1]  = 1,
        [2]  = 0.6,
        [3]  = 0,
      },
    },
    kickedupwater = {
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      water              = true, 
	  underwater         = true,
      properties = {
        airdrag            = 0.87,
        alwaysvisible      = true,
        colormap           = [[0.7 0.7 0.9 0.35	0 0 0 0.0]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.1, 0]],
        numparticles       = 120,
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
        alwaysvisible      = true,
        colormap           = [[0 0 0 0   1 0.66 0.3 0.06   0 0 0 0]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1.1, 0]],
        gravity            = [[0, -0.01, 0]],
        numparticles       = 66,
        particlelife       = 1,
        particlelifespread = 16,
        particlesize       = 3,
        particlesizespread = 15,
        particlespeed      = 0.35,
        particlespeedspread = 6,
        pos                = [[0, 2, 0]],
        sizegrowth         = 0.4,
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
        airdrag            = 1,
        alwaysvisible      = true,
        colormap           = [[0.8 0.5 0.2 0.01   0.9 0.5 0.2 0.017   0 0 0 0]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -1, 0]],
        numparticles       = 65,
        particlelife       = 2,
        particlelifespread = 15,
        particlesize       = 2,
        particlesizespread = 10,
        particlespeed      = 2,
        particlespeedspread = 7,
        pos                = [[0, 4, 0]],
        sizegrowth         = 1,
        sizemod            = 0.8,
        texture            = [[gunshot]],
        useairlos          = false,
      },
    },
    dirt = {
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 1,
        alwaysvisible      = true,
        colormap           = [[0.04 0.03 0.01 0.05   0.1 0.07 0.033 0.66    0.02 0.02 0.2 0.4   0.08 0.065 0.035 0.55   0.075 0.07 0.06 0.4   0 0 0 0  ]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1.2, 0]],
        gravity            = [[0, -0.5, 0]],
        numparticles       = 90,
        particlelife       = 5,
        particlelifespread = 25,
        particlesize       = 2.3,
        particlesizespread = -2,
        particlespeed      = 0.5,
        particlespeedspread = 5,
        pos                = [[0, 6, 0]],
        sizegrowth         = -0.025,
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
        airdrag            = 0.9,
        alwaysvisible      = true,
        colormap           = [[0.05 0.04 0.02 0.04  0.077 0.065 0.04 0.08  0.06 0.056 0.028 0.056  0.024 0.022 0.02 0.026  0 0 0 0]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 4,
        emitvector         = [[0.5, 1.5, 0.5]],
        gravity            = [[0, 0.05, 0]],
        numparticles       = 2,
        particlelife       = 70,
        particlelifespread = 380,
        particlesize       = 60,
        particlesizespread = 90,
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
      properties = {
        airdrag            = 0.98,
        alwaysvisible      = true,
        colormap           = [[0.21 0.16 0.08 0.25 	0 0 0 0.0]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = 5,
        emitvector         = [[0, 1.1, 0]],
        gravity            = [[0, 0.1, 0]],
        numparticles       = 40,
        particlelife       = 0,
        particlelifespread = 33,
        particlesize       = 1,
        particlesizespread = 7,
        particlespeed      = 2,
        particlespeedspread = 2,
        pos                = [[0, 3, 0]],
        sizegrowth         = 0.25,
        sizemod            = 1.0,
        texture            = [[bigexplosmoke]],
      },
    },
    outerflash = {
      air                = true,
      class              = [[heatcloud]],
      count              = 2,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        alwaysvisible      = true,
        heat               = 14,
        heatfalloff        = 1.3,
        maxheat            = 40,
        pos                = [[r-2 r2, 4, r-2 r2]],
        size               = 15,
        sizegrowth         = 1.2,
        speed              = [[0, 1 0, 0]],
        texture            = [[orangenovaexplo]],
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
	small = {
	
	},
	
	medium = {
    centerflare = {
      properties = {
        size               = 3,
        sizegrowth         = 22,
      },
    },
		groundflash = {
			flashalpha         = 0.25,
	    flashsize          = 250,
	    ground             = true,
	    ttl                = 30,
	  },
	  explosion = {
      properties = {
        numparticles       = 85,
        particlelifespread = 24,
        particlesize       = 6,
        particlesizespread = 28,
        particlespeedspread = 7,
	  	}
	  },
    sparks = {
      properties = {
	    	numparticles = 90,
	    	sizemod = 0.84,
        particlelifespread = 17,
        particlespeedspread = 9,
	   	}
    },
    dirt = {
      properties = {
	    	numparticles = 120,
        particlelifespread = 30,
        particlespeed      = 0.7,
        particlespeedspread = 7,
	   	}
    },
    clouddust = {
      properties = {
      	particlelifespread = 500,
        particlesize       = 90,
        particlesizespread = 130,
      }
    },
    grounddust = {
      properties = {
        airdrag            = 1.04,
        numparticles       = 60,
        particlelifespread = 50,
        particlesize       = 2,
        particlesizespread = 12,
        particlespeed      = 3,
        particlespeedspread = 2,
	   	}
    },
    outerflash = {
      properties = {
        alwaysvisible      = true,
        heat               = 16,
        maxheat            = 50,
        size               = 22,
      },
    },
	},
	
	large = {
    centerflare = {
      properties = {
        size               = 4.5,
        sizegrowth         = 32,
      },
    },
		groundflash = {
			flashalpha         = 0.28,
	    flashsize          = 350,
	    ground             = true,
	    ttl                = 45,
	  },
	  explosion = {
      properties = {
        numparticles       = 120,
        particlelifespread = 33,
        particlesize       = 10,
        particlesizespread = 40,
        particlespeedspread = 9,
	  	}
	  },
    sparks = {
      properties = {
	    	numparticles = 120,
	    	sizemod = 0.88,
        particlelifespread = 20,
        particlespeedspread = 11,
	   	}
    },
    dirt = {
      properties = {
	    	numparticles = 150,
        particlelifespread = 30,
        particlespeed      = 0.9,
        particlespeedspread = 9,
	   	}
    },
    clouddust = {
      properties = {
      	particlelifespread = 600,
        particlesize       = 120,
        particlesizespread = 130,
      }
    },
    grounddust = {
      properties = {
        airdrag            = 1.08,
        numparticles       = 90,
        particlelifespread = 50,
        particlesize       = 3,
        particlesizespread = 16,
        particlespeed      = 4,
        particlespeedspread = 3,
	   	}
    },
    outerflash = {
      properties = {
        alwaysvisible      = true,
        heat               = 20,
        maxheat            = 60,
        size               = 36,
      },
    },
	},
	
	huge = {
    centerflare = {
      properties = {
        size               = 6,
        sizegrowth         = 40,
      },
    },
		groundflash = {
			flashalpha         = 0.28,
	    flashsize          = 350,
	    ground             = true,
	    ttl                = 60,
	  },
	  explosion = {
      properties = {
        numparticles       = 160,
        particlelifespread = 44,
        particlesize       = 16,
        particlesizespread = 60,
        particlespeedspread = 14,
	  	}
	  },
    sparks = {
      properties = {
	    	numparticles = 150,
	    	sizemod = 0.9,
        particlelifespread = 28,
        particlespeedspread = 16,
	   	}
    },
    dirt = {
      properties = {
	    	numparticles = 150,
        particlelifespread = 30,
        particlespeed      = 0.9,
        particlespeedspread = 9,
	   	}
    },
    clouddust = {
      properties = {
      	particlelifespread = 600,
        particlesize       = 120,
        particlesizespread = 130,
      }
    },
    grounddust = {
      properties = {
        airdrag            = 1.12,
        numparticles       = 130,
        particlelifespread = 70,
        particlesize       = 5,
        particlesizespread = 25,
        particlespeed      = 5,
        particlespeedspread = 4,
	   	}
    },
    outerflash = {
      properties = {
        alwaysvisible      = true,
        heat               = 20,
        maxheat            = 60,
        size               = 36,
      },
    },
	
	},
}
for size, effects in pairs(sizes) do
	definitions[root.."-"..size] = tableMerge(deepcopy(definitions[root.."-small"]), deepcopy(effects))
end

-- add coloring
local colors = {
	blue = {
		groundflash = {
			color = {0,0,1},
		}
	},
	["blue-emp"] = {
		groundflash = {
			color = {0,0,1},
		}
	},
	green = {
		groundflash = {
			color = {0,1,0},
		}
	},
	red = {
		groundflash = {
			color = {1,0,0},
		}
	},
	white = {
		groundflash = {
			color = {1,1,1},
		}
	},
	purple = {
		groundflash = {
			color = {1,0,1},
		}
	}
}
for color, effects in pairs(colors) do
	for size, e in pairs(sizes) do
		definitions[root.."-"..size.."-"..color] = tableMerge(deepcopy(definitions[root.."-"..size]), deepcopy(effects))
	end
end

return definitions