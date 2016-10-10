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
        sizegrowth         = -0.03,
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
		groundflash = {
			flashalpha         = 0.25,
	    flashsize          = 250,
	    ground             = true,
	    ttl                = 30,
	  }
	},
	large = {
	
	},
	huge = {
	
	},
}
for size, effects in pairs(sizes) do
	if definitions[root.."-"..size] == nil then 
		definitions[root.."-"..size] = deepcopy(definitions[root.."-small"])
	end
	for effect, attributes in pairs(effects) do
		for attribute, value in pairs(attributes) do
			if definitions[root.."-"..size][effect] == nil then 
				definitions[root.."-"..size][effect] = deepcopy(attributes)
				break
			end
			definitions[root.."-"..size][effect][attribute] = deepcopy(value)
		end
	end
end

-- add coloring
local colors = {
	blue = {
		groundflash = {
			color = {0,0,1}
		}
	},
	["blue-emp"] = {
		groundflash = {
			color = {0,0,1}
		}
	},
	green = {
		groundflash = {
			color = {0,1,0}
		}
	},
	red = {
		groundflash = {
			color = {1,0,0}
		}
	},
	white = {
		groundflash = {
			color = {1,1,1}
		}
	},
	purple = {
		groundflash = {
			color = {1,0,1}
		}
	}
}
for color, effects in pairs(colors) do
	for size, e in pairs(sizes) do
		if definitions[root.."-"..size.."-"..color] == nil then
			definitions[root.."-"..size.."-"..color] = deepcopy(definitions[root.."-"..size])
		end
		for effect, attributes in pairs(effects) do	-- the effects of colors
			if definitions[root.."-"..size.."-"..color][effect] == nil then 
				definitions[root.."-"..size.."-"..color][effect] = deepcopy(attributes)
			else
				for attribute, value in pairs(attributes) do
					definitions[root.."-"..size.."-"..color][effect][attribute] = deepcopy(value)
				end
			end
		end
	end
end

return definitions