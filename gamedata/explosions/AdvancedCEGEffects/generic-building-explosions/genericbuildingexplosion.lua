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
    --groundflash = {
    --  air                = true,
    --      --  flashalpha         = 0.28,
    --  flashsize          = 125,
    --  ground             = true,
    --  ttl                = 16,
    --  water              = true, 
	  --underwater         = true,
    --  color = {
    --    [1]  = 1,
    --    [2]  = 0.8,
    --    [3]  = 0.4,
    --  },
    --},
    groundflash = {
      air                = true,
            flashalpha         = 0.6,
      flashsize          = 16,
      ground             = true,
      ttl                = 44,
      water              = true, 
	  underwater         = true,
      color = {
        [1]  = 1,
        [2]  = 0.15,
        [3]  = 0.05,
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
        colormap           = [[0 0 0 0   1 0.93 0.7 0.09   0.9 0.53 0.21 0.066   0.66 0.28 0.04 0.033   0 0 0 0]],
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
        colormap           = [[0.15 0.14 0.1 0.005   0 0 0 0]],
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
        colormap           = [[0.26 0.22 0.08 0.26   0.44 0.38 0.13 0.44   0.2 0.14 0 0.2   0 0 0 0]],
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
    sparks = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true, 
	  	underwater         = true,
      properties = {
        airdrag            = 0.95,
        colormap           = [[0.8 0.5 0.2 0.01   0.9 0.5 0.2 0.017   0 0 0 0]],
        directional        = true,
        emitrot            = 25,
        emitrotspread      = 40,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.3, 0]],
        numparticles       = 35,
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
      unit               = false,
      properties = {
        airdrag            = 0.95,
        colormap           = [[0.04 0.03 0.01 0   0.1 0.07 0.033 0.66    0.1 0.07 0.03 0.58   0.08 0.065 0.035 0.47   0.075 0.07 0.06 0.4   0 0 0 0  ]],
        directional        = true,
        emitrot            = 24,
        emitrotspread      = 30,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.33, 0]],
        numparticles       = 70,
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
      unit               = false,
      properties = {
        airdrag            = 0.95,
        colormap           = [[0.04 0.03 0.01 0   0.1 0.07 0.033 0.66    0.1 0.07 0.03 0.58   0.08 0.065 0.035 0.47   0.075 0.07 0.06 0.4   0 0 0 0  ]],
        directional        = true,
        emitrot            = 0,
        emitrotspread      = 16,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.33, 0]],
        numparticles       = 35,
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
    clouddust = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.9,
        colormap           = [[0.022 0.022 0.022 0.03  0.05 0.05 0.05 0.068  0.042 0.042 0.042 0.052  0.023 0.023 0.023 0.028  0 0 0 0]],
        directional        = true,
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
    outerflash = {
      air                = true,
      class              = [[heatcloud]],
      count              = 2,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
                heat               = 14,
        heatfalloff        = 1.3,
        maxheat            = 40,
        pos                = [[r-2 r2, 4, r-2 r2]],
        size               = 12,
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

	tiny = {
    centerflare = {
      properties = {
        size               = 1.3,
        sizegrowth         = 11,
      },
    },
		--groundflash = {
		--	flashalpha         = 0.24,
	  --  flashsize          = 77,
	  --  ground             = true,
	  --  ttl                = 18,
	  --},
    groundflash = {
      flashsize          = 8,
      ttl                = 34,
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
    sparks = {
      properties = {
	    	numparticles = 20,
        particlespeed      = 1,
        particlespeedspread = 2.9,
	   	}
    },
    dirt = {
      properties = {
	    	numparticles = 40,
        particlelifespread = 13,
        particlespeed      = 2.75,
        particlespeedspread = 3.6,
	   	}
    },
    dirt2 = {
      properties = {
	    	numparticles = 20,
        particlelifespread = 17,
        particlespeed      = 2.66,
        particlespeedspread = 4.3,
	   	}
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
    outerflash = {
      properties = {
                heat               = 10,
        maxheat            = 30,
        size               = 8.8,
      },
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
		--groundflash = {
		--	flashalpha         = 0.32,
	  --  flashsize          = 230,
	  --  ground             = true,
	  --  ttl                = 26,
	  --},
    groundflash = {
      flashsize          = 20,
      ttl                = 47,
    },
	  explosion = {
      properties = {
        numparticles       = 60,
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
    sparks = {
      properties = {
	    	numparticles = 80,
	    	sizemod = 0.815,
        particlespeed      = 2.5,
        particlespeedspread = 5,
	   	}
    },
    dirt = {
      properties = {
	    	numparticles = 130,
        particlelifespread = 44,
        particlespeed      = 3.5,
        particlespeedspread = 4.4,
	   	}
    },
    dirt2 = {
      properties = {
	    	numparticles = 65,
        particlelifespread = 50,
        particlespeed      = 3.5,
        particlespeedspread = 5.5,
	   	}
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
    outerflash = {
      properties = {
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
		--groundflash = {
		--	flashalpha         = 0.35,
	  --  flashsize          = 290,
	  --  ground             = true,
	  --  ttl                = 25,
	  --},
    groundflash = {
      flashsize          = 30,
      ttl                = 50,
    },
	  explosion = {
      properties = {
        numparticles       = 80,
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
    sparks = {
      properties = {
	    	numparticles = 130,
	    	sizemod = 0.83,
        particlespeed      = 2.8,
        particlespeedspread = 5.5,
	   	}
    },
    dirt = {
      properties = {
	    	numparticles = 240,
        particlelifespread = 50,
        particlespeed      = 5,
        particlespeedspread = 6,
	   	}
    },
    dirt2 = {
      properties = {
	    	numparticles = 120,
        particlelifespread = 55,
        particlespeed      = 5.3,
        particlespeedspread = 7.3,
	   	}
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
    outerflash = {
      properties = {
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
		--groundflash = {
		--	flashalpha         = 0.4,
	  --  flashsize          = 350,
	  --  ground             = true,
	  --  ttl                = 30,
	  --},
    groundflash = {
      flashsize          = 36,
      ttl                = 54,
    },
	  explosion = {
      properties = {
        numparticles       = 90,
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
    sparks = {
      properties = {
	    	numparticles = 170,
	    	sizemod = 0.84,
        particlespeed      = 3.2,
        particlespeedspread = 7.4,
	   	}
    },
    dirt = {
      properties = {
	    	numparticles = 280,
        particlelifespread = 55,
        particlespeed      = 6,
        particlespeedspread = 7.5,
	   	}
    },
    dirt2 = {
      properties = {
	    	numparticles = 140,
        particlelifespread = 60,
        particlespeed      = 6.5,
        particlespeedspread = 10,
	   	}
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
    outerflash = {
      properties = {
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



definitions['genericshellexplosion-meteor'] = deepcopy(definitions[root.."-huge"])
definitions['genericshellexplosion-meteor'].groundflash.alwaysvisible = true
definitions['genericshellexplosion-meteor'].explosion.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].centerflare.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].sparks.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].dirt.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].dirt2.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].grounddust.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].clouddust.properties.alwaysvisible = true
--definitions['genericshellexplosion-meteor'].groundclouddust.properties.alwaysvisible = true
definitions['genericshellexplosion-meteor'].outerflash.properties.alwaysvisible = true
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
