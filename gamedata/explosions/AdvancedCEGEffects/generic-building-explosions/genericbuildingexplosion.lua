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
      flashalpha         = 0.24,
      flashsize          = 144,
      ground             = true,
      ttl                = 16,
      water              = true, 
	  underwater         = true,
      color = {
        [1]  = 1,
        [2]  = 0.8,
        [3]  = 0.3,
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
        colormap           = [[0 0 0 0   1 0.93 0.7 0.09   0.9 0.53 0.21 0.066   0.66 0.28 0.04 0.033   0 0 0 0]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 32,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.01, 0]],
        numparticles       = 60,
        particlelife       = 4,
        particlelifespread = 9,
        particlesize       = 2.4,
        particlesizespread = 7.7,
        particlespeed      = 1,
        particlespeedspread = 4.7,
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
        alwaysvisible      = true,
        colormap           = [[0.3 0.27 0.1 0.22   1 0.96 0.6 0.3   1 0.77 0.1 0.13   0 0 0 0]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 1, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 1,
        particlelife       = 13,
        particlelifespread = 0,
        particlesize       = 20,
        particlesizespread = 2,
        particlespeed      = 0,
        particlespeedspread = 0,
        pos                = [[0, 2, 0]],
        sizegrowth         = 1.5,
        sizemod            = 1,
        texture            = [[dirt]],
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
        alwaysvisible      = true,
        colormap           = [[0.26 0.22 0.08 0.26   0.44 0.38 0.13 0.44   0.2 0.14 0 0.2   0 0 0 0]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0.0, 0, 0.0]],
        gravity            = [[0.0, 0.0, 0.0]],
        numparticles       = 1,
        particlelife       = 16,
        particlelifespread = 0,
        particlesize       = 60,
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
        emitrot            = 25,
        emitrotspread      = 40,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.3, 0]],
        numparticles       = 80,
        particlelife       = 3,
        particlelifespread = 10,
        particlesize       = 1.7,
        particlesizespread = 8,
        particlespeed      = 1.5,
        particlespeedspread = 4.5,
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
      unit               = false,
      properties = {
        airdrag            = 0.96,
        alwaysvisible      = true,
        colormap           = [[0.04 0.03 0.01 0   0.1 0.07 0.033 0.66    0.1 0.07 0.03 0.58   0.08 0.065 0.035 0.47   0.075 0.07 0.06 0.4   0 0 0 0  ]],
        directional        = true,
        emitrot            = 24,
        emitrotspread      = 30,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.3, 0]],
        numparticles       = 120,
        particlelife       = 18,
        particlelifespread = 14,
        particlesize       = 1.6,
        particlesizespread = -1.3,
        particlespeed      = 4.5,
        particlespeedspread = 5.5,
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
      unit               = false,
      properties = {
        airdrag            = 0.96,
        alwaysvisible      = true,
        colormap           = [[0.04 0.03 0.01 0   0.1 0.07 0.033 0.66    0.1 0.07 0.03 0.58   0.08 0.065 0.035 0.47   0.075 0.07 0.06 0.4   0 0 0 0  ]],
        directional        = true,
        emitrot            = 0,
        emitrotspread      = 16,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.3, 0]],
        numparticles       = 60,
        particlelife       = 33,
        particlelifespread = 15,
        particlesize       = 1.5,
        particlesizespread = -1.25,
        particlespeed      = 3.5,
        particlespeedspread = 7,
        pos                = [[0, 3, 0]],
        sizegrowth         = -0.01,
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
        colormap           = [[0.02 0.02 0.02 0.03  0.055 0.055 0.055 0.066  0.05 0.05 0.05 0.052  0.03 0.03 0.03 0.028  0 0 0 0]],
        directional        = true,
        emitrot            = 45,
        emitrotspread      = 4,
        emitvector         = [[0.5, 1.35, 0.5]],
        gravity            = [[0, 0.03, 0]],
        numparticles       = 5,
        particlelife       = 70,
        particlelifespread = 400,
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
      unit               = false,
      properties = {
        airdrag            = 0.92,
        alwaysvisible      = true,
        colormap           = [[0.14 0.12 0.09 0.13 	0 0 0 0.0]],
        directional        = false,
        emitrot            = 90,
        emitrotspread      = -2,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0.03, 0]],
        numparticles       = 70,
        particlelife       = 10,
        particlelifespread = 90,
        particlesize       = 5.2,
        particlesizespread = 3,
        particlespeed      = 3.6,
        particlespeedspread = 1.6,
        pos                = [[0, 5, 0]],
        sizegrowth         = 0.18,
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
			flashalpha         = 0.26,
	    flashsize          = 220,
	    ground             = true,
	    ttl                = 22,
	  },
	  explosion = {
      properties = {
        numparticles       = 80,
        particlelifespread = 11,
        particlesize       = 3.3,
        particlesizespread = 10,
        particlespeedspread = 6.4,
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
    sparks = {
      properties = {
	    	numparticles = 130,
	    	sizemod = 0.815,
        particlespeed      = 2.5,
        particlespeedspread = 5,
	   	}
    },
    dirt = {
      properties = {
	    	numparticles = 250,
        particlelifespread = 44,
        particlespeed      = 3.5,
        particlespeedspread = 4.4,
	   	}
    },
    dirt2 = {
      properties = {
	    	numparticles = 125,
        particlelifespread = 50,
        particlespeed      = 3.5,
        particlespeedspread = 5.5,
	   	}
    },
    clouddust = {
      properties = {
        numparticles       = 7,
      	particlelifespread = 450,
        particlesize       = 70,
        particlesizespread = 90,
      }
    },
    grounddust = {
      properties = {
        numparticles       = 133,
        particlelifespread = 100,
        particlesize       = 6.6,
        particlesizespread = 3.5,
        particlespeed      = 5,
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
        size               = 4,
        sizegrowth         = 32,
      },
    },
		groundflash = {
			flashalpha         = 0.3,
	    flashsize          = 275,
	    ground             = true,
	    ttl                = 23,
	  },
	  explosion = {
      properties = {
        numparticles       = 110,
        particlelifespread = 13,
        particlesize       = 5,
        particlesizespread = 15,
        particlespeedspread = 8.5,
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
    sparks = {
      properties = {
	    	numparticles = 220,
	    	sizemod = 0.83,
        particlespeed      = 2.8,
        particlespeedspread = 5.5,
	   	}
    },
    dirt = {
      properties = {
	    	numparticles = 450,
        particlelifespread = 50,
        particlespeed      = 5.2,
        particlespeedspread = 6.5,
	   	}
    },
    dirt2 = {
      properties = {
	    	numparticles = 225,
        particlelifespread = 55,
        particlespeed      = 5.8,
        particlespeedspread = 8,
	   	}
    },
    clouddust = {
      properties = {
        numparticles       = 12,
      	particlelifespread = 500,
        particlesize       = 85,
        particlesizespread = 90,
      }
    },
    grounddust = {
      properties = {
        numparticles       = 190,
        particlelifespread = 115,
        particlesize       = 11,
        particlesizespread = 5.5,
        particlespeed      = 7.4,
        particlespeedspread = 3.7,
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
        size               = 5.5,
        sizegrowth         = 40,
      },
    },
		groundflash = {
			flashalpha         = 0.32,
	    flashsize          = 333,
	    ground             = true,
	    ttl                = 25,
	  },
	  explosion = {
      properties = {
        numparticles       = 140,
        particlelifespread = 15,
        particlesize       = 7.5,
        particlesizespread = 22,
        particlespeedspread = 9,
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
    sparks = {
      properties = {
	    	numparticles = 300,
	    	sizemod = 0.84,
        particlespeed      = 3.2,
        particlespeedspread = 7.4,
	   	}
    },
    dirt = {
      properties = {
	    	numparticles = 660,
        particlelifespread = 60,
        particlespeed      = 6.5,
        particlespeedspread = 8,
	   	}
    },
    dirt2 = {
      properties = {
	    	numparticles = 330,
        particlelifespread = 65,
        particlespeed      = 7,
        particlespeedspread = 11,
	   	}
    },
    clouddust = {
      properties = {
        numparticles       = 17,
      	particlelifespread = 550,
        particlesize       = 100,
        particlesizespread = 100,
      }
    },
    grounddust = {
      properties = {
        numparticles       = 266,
        particlelifespread = 133,
        particlesize       = 14,
        particlesizespread = 7,
        particlespeed      = 9.5,
        particlespeedspread = 4.5,
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
			color = {0.15,0.15,1},
		}
	},
	["blue-emp"] = {
		groundflash = {
			color = {0.15,0.15,1},
		}
	},
	green = {
		groundflash = {
			color = {0.15,1,0.15},
		}
	},
	red = {
		groundflash = {
			color = {1,0.15,0.15},
		}
	},
	white = {
		groundflash = {
			color = {1,1,1},
		}
	},
	purple = {
		groundflash = {
			color = {1,0.15,1},
		}
	}
}
for color, effects in pairs(colors) do
	for size, e in pairs(sizes) do
		definitions[root.."-"..size.."-"..color] = tableMerge(deepcopy(definitions[root.."-"..size]), deepcopy(effects))
	end
end

return definitions