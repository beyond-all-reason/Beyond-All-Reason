-- nukedatbewm

local definitions = {
  ["armnuke"] = {
    groundflash = {
      air                = true,
      ground             = true,
	  water		         = true,
	  underwater		 = true,
      flashalpha         = 0.3,
      flashsize          = 660,
      ground             = true,
      ttl                = 35,
      water              = true,
      color = {
        [1]  = 1,
        [2]  = 0.9,
        [3]  = 0.55,
      },
    },

    pop1 = {
      class=[[heatcloud]],
      air=1,
      water=1,
      ground=1,
      count=2,
      properties ={
        alwaysVisible=1,
        texture=[[fireball]],
        heat = 10,
        maxheat = 10,
        heatFalloff = 0.7,
        size = 2,
        sizeGrowth = 22,
        pos = [[r-10 r10, 0, r-10 r10]],
        speed=[[0, 0, 0]],
        useairlos = true,
      },
    },

    innersmoke = {
      class = [[CSimpleParticleSystem]],
      water=0,
      air=1,
      ground=1,
      count=1,
      properties = {
        alwaysVisible = 1,
        sizeGrowth = 1.08,
        sizeMod = 1.0,
        pos = [[r-1 r1, 0, r-1 r1]],
        emitRot=35,
        emitRotSpread=70,
        emitVector = [[0, 1, 0]],
        gravity = [[0, 0.005, 0]],
        colorMap=[[1 0.65 0.4 0.45    0.45 0.24 0.09 0.77   0.3 0.19 0.12 0.7    0.2 0.17 0.14 0.55   0.1 0.095 0.088 0.25   0.07 0.065 0.058 0.15    0 0 0 0.01]],
        Texture=[[graysmoke]],
        airdrag=0.66,
        particleLife=20,
        particleLifeSpread=150,
        numParticles=35,
        particleSpeed=2,
        particleSpeedSpread=75,
        particleSize=30,
        particleSizeSpread=6,
        directional=1,
        useairlos = true,
      },
    },

    outersmoke = {
      class = [[CSimpleParticleSystem]],
      water=0,
      air=1,
      ground=1,
      count=1,
      properties = {
        alwaysVisible = 1,
        sizeGrowth = 1.08,
        sizeMod = 1.0,
        pos = [[r-1 r1, 0, r-1 r1]],
        emitRot=35,
        emitRotSpread=70,
        emitVector = [[0, 1, 0]],
        gravity = [[0, 0.005, 0]],
        colorMap=[[1 0.65 0.4 0.45    0.42 0.22 0.07 0.77   0.2 0.17 0.14 0.55   0.1 0.095 0.088 0.25    0 0 0 0.01]],
        Texture=[[graysmoke]],
        airdrag=0.77,
        particleLife=10,
        particleLifeSpread=110,
        numParticles=130,
        particleSpeed=15,
        particleSpeedSpread=40,
        particleSize=25,
        particleSizeSpread=6,
        directional=1,
        useairlos = true,
      },
    },

    dirt = {
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water        			 = true,
      air        			   = true,
      properties = {
        airdrag            = 0.96,
        colormap           = [[ 0.1 0.07 0.033 0.66    0.02 0.02 0.2 0.4   0.08 0.065 0.035 0.55   0.075 0.07 0.06 0.4   0 0 0 0  ]],
        directional        = true,
        emitrot            = 25,
        emitrotspread      = 35,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.55, 0]],
        numparticles       = 30,
        particlelife       = 200,
        particlelifespread = 50,
        particlesize       = 3.2,
        particlesizespread = -2.7,
        particlespeed      = 10,
        particlespeedspread = 17,
        pos                = [[0, 10, 0]],
        sizegrowth         = 0,
        sizemod            = 1,
        texture            = [[bigexplosmoke]],
        useairlos          = true,
      },
    },

    dirtbig = {
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      water        	   = true,
      underwater         = true,
      properties = {
        airdrag            = 0.96,
        colormap           = [[0.04 0.03 0.01 0.09   0.1 0.07 0.033 0.66    0.02 0.02 0.2 0.4   0.08 0.065 0.035 0.55   0.075 0.07 0.06 0.4   0 0 0 0  ]],
        directional        = true,
        emitrot            = 25,
        emitrotspread      = 25,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.85, 0]],
        numparticles       = 25,
        particlelife       = 150,
        particlelifespread = 50,
        particlesize       = 4,
        particlesizespread = -3.3,
        particlespeed      = 9,
        particlespeedspread = 16,
        pos                = [[0, 10, 0]],
        sizegrowth         = 0,
        sizemod            = 1,
        texture            = [[bigexplosmoke]],
        useairlos          = true,
      },
    },

    sparks = {
      air                = true,
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      ground             = true,
      properties = {
        airdrag            = 0.98,
        colormap           = [[0.9 0.5 0.2 0.022   0.5 0.3 0.1 0.013   0.04 0.03 0.01 0.07   0.01 0.01 0 0.015]],
        directional        = true,
        emitrot            = 22,
        emitrotspread      = 66,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.11, 0]],
        numparticles       = 30,
        particlelife       = 25,
        particlelifespread = 70,
        particlesize       = 5,
        particlesizespread = 7,
        particlespeed      = 7.5,
        particlespeedspread = 11,
        pos                = [[0, 4, 0]],
        sizegrowth         = -0.007,
        sizemod            = 1,
        texture            = [[gunshotglow]],
        useairlos          = true,
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

local size = 1.2
definitions['cornuke'] = deepcopy(definitions['armnuke'])

-- method below fails :(
--definitions['cornuke'].innersmoke.properties.numparticles = math.floor(definitions['cornuke'].innersmoke.properties.numparticles * size)
--definitions['cornuke'].innersmoke.properties.particlespeed = definitions['cornuke'].innersmoke.properties.particlespeed * size
--definitions['cornuke'].innersmoke.properties.particlespeedspread = definitions['cornuke'].innersmoke.properties.particlespeedspread * size
--definitions['cornuke'].outersmoke.properties.numparticles = math.floor(definitions['cornuke'].outersmoke.properties.numparticles * size)
--definitions['cornuke'].outersmoke.properties.particlespeed = definitions['cornuke'].outersmoke.properties.particlespeed * size
--definitions['cornuke'].outersmoke.properties.particlespeedspread = definitions['cornuke'].outersmoke.properties.particlespeedspread * size
--definitions['cornuke'].dirt.properties.particlespeed = definitions['cornuke'].dirt.properties.particlespeed * size
--definitions['cornuke'].dirt.properties.particlespeedspread = definitions['cornuke'].dirt.properties.particlespeedspread * size
--definitions['cornuke'].dirtbig.properties.particlespeed = definitions['cornuke'].dirtbig.properties.particlespeed * size
--definitions['cornuke'].dirtbig.properties.particlespeedspread = definitions['cornuke'].dirtbig.properties.particlespeedspread * size
--definitions['cornuke'].sparks.properties.particlespeed = definitions['cornuke'].sparks.properties.particlespeed * size
--definitions['cornuke'].sparks.properties.particlespeedspread = definitions['cornuke'].sparks.properties.particlespeedspread * size


return definitions
