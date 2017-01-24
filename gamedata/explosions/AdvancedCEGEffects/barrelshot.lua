local definitions = {

  ["barrelshot-medium"] = {
    fire = {
      air                = true,
      class              = [[CBitmapMuzzleFlame]],
      count              = 1,
      ground             = true,
      underwater         = 1,
      water              = true,
      properties = {
        colormap           = [[1 0.7 0.4 0.01 1 0.4 0.1 0.01 0 0 0 0.01]],
        dir                = [[dir]],
        frontoffset        = 0,
        fronttexture       = [[shotgunflare]],
        length             = 33,
        sidetexture        = [[shotgunside]],
        size               = 8,
        sizegrowth         = -0.6,
        ttl                = 4,
      },
    },
    fire2 = {
      air                = true,
      class              = [[CBitmapMuzzleFlame]],
      count              = 1,
      ground             = true,
      underwater         = 1,
      water              = true,
      properties = {
        colormap           = [[1 0.7 0.4 0.01 1 0.4 0.1 0.01 0 0 0 0.01]],
        dir                = [[dir]],
        frontoffset        = 0,
        fronttexture       = [[none]],
        length             = -6,
        sidetexture        = [[shotgunside]],
        size               = 8,
        sizegrowth         = -0.6,
        ttl                = 4,
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
	      alwaysvisible      = true,
	      colormap           = [[0.145 0.066 0.013 0.02   0 0 0 0.01]],
	      directional        = true,
	      emitrot            = 90,
	      emitrotspread      = 0,
	      emitvector         = [[0.0, 1, 0.0]],
	      gravity            = [[0.0, 0.0, 0.0]],
	      numparticles       = 1,
	      particlelife       = 7,
	      particlelifespread = 0,
	      particlesize       = 40,
	      particlesizespread = 6,
	      particlespeed      = 0,
	      particlespeedspread = 0,
	      pos                = [[0.0, 0, 0.0]],
	      sizegrowth         = -0.25,
	      sizemod            = 1,
	      texture            = [[dirt]],
	      useairlos          = true,
	    },
	  },
    smoke = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.84,
        colormap           = [[1 0.7 0.5 0.01   0.1 0.1 0.1 0.2   0.1 0.1 0.1 0.22   0.04 0.04 0.04 0.1  0 0 0 0]],
        colormap           = [[0.07 0.07 0.07 0.18   0.1 0.1 0.1 0.2   0.04 0.04 0.04 0.1  0 0 0 0]],
        directional        = false,
        emitrot            = 0,
        emitrotspread      = 10,
        emitvector         = [[dir]],
        gravity            = [[0, 0, 0]],
        numparticles       = 10,
        particlelife       = 55,
        particlelifespread = 15,
        particlesize       = 2,
        particlesizespread = 2,
        particlespeed      = 0,
        particlespeedspread = 2.5,
        pos                = [[0, 1, 3]],
        sizegrowth         = 0.03,
        sizemod            = 1.0,
        texture            = [[smoke]],
      },
    },
    smoke2 = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        airdrag            = 0.8,
        colormap           = [[ 0.06 0.06 0.06 0.2   0.1 0.1 0.1 0.2   0 0 0 0.02   0 0 0 0.01]],
        directional        = false,
        emitrot            = 0,
        emitrotspread      = 20,
        emitvector         = [[dir]],
        gravity            = [[0.02 r-0.1, 0.03 r-0.1, 0.02 r-0.1]],
        numparticles       = 8,
        particlelife       = 62,
        particlelifespread = 0,
        particlesize       = 2,
        particlesizespread = 2,
        particlespeed      = -3.5,
        particlespeedspread = -1,
        pos                = [[0, 1, 3]],
        sizegrowth         = 0.03,
        sizemod            = 1.0,
        texture            = [[smoke]],
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

local size = 0.66
definitions["barrelshot-small"] = deepcopy(definitions["barrelshot-medium"])
definitions["barrelshot-small"].fire.properties.length								= definitions["barrelshot-small"].fire.properties.length * size
definitions["barrelshot-small"].fire.properties.size									= definitions["barrelshot-small"].fire.properties.size * size
definitions["barrelshot-small"].fire2.properties.length								= definitions["barrelshot-small"].fire2.properties.length * size
definitions["barrelshot-small"].fire2.properties.size									= definitions["barrelshot-small"].fire2.properties.size * size
definitions["barrelshot-small"].fireglow.properties.particlesize			= definitions["barrelshot-small"].fireglow.properties.particlesize * size
definitions["barrelshot-small"].smoke.properties.particlesize					= definitions["barrelshot-small"].smoke.properties.particlesize * size
definitions["barrelshot-small"].smoke.properties.particlesizespread		= definitions["barrelshot-small"].smoke.properties.particlesizespread * size
definitions["barrelshot-small"].smoke.properties.numparticles					= definitions["barrelshot-small"].smoke.properties.numparticles * size
definitions["barrelshot-small"].smoke.properties.particlespeedspread	= definitions["barrelshot-small"].smoke.properties.particlespeedspread * size
definitions["barrelshot-small"].smoke2.properties.particlesize				= definitions["barrelshot-small"].smoke2.properties.particlesize * size
definitions["barrelshot-small"].smoke2.properties.particlesizespread	= definitions["barrelshot-small"].smoke2.properties.particlesizespread * size

size = 1.5
definitions["barrelshot-large"] = deepcopy(definitions["barrelshot-medium"])
definitions["barrelshot-large"].fire.properties.length 								= definitions["barrelshot-large"].fire.properties.length * size
definitions["barrelshot-large"].fire.properties.size									= definitions["barrelshot-large"].fire.properties.size * size
definitions["barrelshot-large"].fire2.properties.length								= definitions["barrelshot-large"].fire2.properties.length * size
definitions["barrelshot-large"].fire2.properties.size									= definitions["barrelshot-large"].fire2.properties.size * size
definitions["barrelshot-large"].fireglow.properties.particlesize			= definitions["barrelshot-large"].fireglow.properties.particlesize * size
definitions["barrelshot-large"].smoke.properties.particlesize					= definitions["barrelshot-large"].smoke.properties.particlesize * size
definitions["barrelshot-large"].smoke.properties.particlesizespread		= definitions["barrelshot-large"].smoke.properties.particlesizespread * size
definitions["barrelshot-large"].smoke.properties.numparticles					= definitions["barrelshot-large"].smoke.properties.numparticles * size
definitions["barrelshot-large"].smoke.properties.particlespeedspread	= definitions["barrelshot-large"].smoke.properties.particlespeedspread * size
definitions["barrelshot-large"].smoke2.properties.particlesize				= definitions["barrelshot-large"].smoke2.properties.particlesize * size
definitions["barrelshot-large"].smoke2.properties.particlesizespread	= definitions["barrelshot-large"].smoke2.properties.particlesizespread * size

return definitions