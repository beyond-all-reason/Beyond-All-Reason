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
        colormap           = [[1 0.85 0.6 0.013   0.6 0.2 0.06 0.01   0.4 0.06 0.015 0.006   0 0 0 0.01]],
        dir                = [[dir]],
        frontoffset        = 0,
        fronttexture       = [[shotgunflare]],
        length             = 45,
        sidetexture        = [[shotgunside]],
        size               = 9.6,
        sizegrowth         = -0.55,
        ttl                = 5.5,
        pos                = [[0.0, 1, 0.0]],
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
        colormap           = [[1 0.85 0.6 0.013   0.6 0.2 0.06 0.01   0.4 0.06 0.015 0.006   0 0 0 0.01]],
        dir                = [[dir]],
        frontoffset        = 0,
        fronttexture       = [[none]],
        length             = -9,
        sidetexture        = [[shotgunside]],
        size               = 10,
        sizegrowth         = -0.55,
        ttl                = 5.5,
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
	      colormap           = [[0.122 0.066 0.013 0.04   0 0 0 0.01]],
	      directional        = true,
	      emitrot            = 90,
	      emitrotspread      = 0,
	      emitvector         = [[0.0, 1, 0.0]],
	      gravity            = [[0.0, 0.0, 0.0]],
	      numparticles       = 1,
	      particlelife       = 9,
	      particlelifespread = 0,
	      particlesize       = 50,
	      particlesizespread = 6,
	      particlespeed      = 0,
	      particlespeedspread = 0,
	      pos                = [[0.0, 0, 0.0]],
	      sizegrowth         = -0.3,
	      sizemod            = 1,
	      texture            = [[dirt]],
	      useairlos          = true,
	    },
	  },
      smoke2 = {
          air                = true,
          class              = [[CSimpleParticleSystem]],
          count              = 1,
          ground             = true,
          water              = true,
          properties = {
              airdrag            = 0.91,
              colormap           = [[0.08 0.05 0.03 0.18   0.012 0.012 0.012 0.18   0 0 0 0.01]],
              directional        = true,
              emitrot            = 0,
              emitrotspread      = 8,
              emitvector         = [[dir]],
              gravity            = [[0.0, -0.01, 0.0]],
              numparticles       = 14,
              particlelife       = 14,
              particlelifespread = 10,
              particlesize       = 0.6,
              particlesizespread = 0.6,
              particlespeed      = 0.5,
              particlespeedspread = 3.5,
              pos                = [[0.0, 0, 0.0]],
              sizegrowth         = 0.15,
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
          airdrag            = 0.91,
          colormap           = [[0.2 0.16 0.11 0.18   0.08 0.08 0.08 0.18   0 0 0 0.01]],
          directional        = true,
          emitrot            = 0,
          emitrotspread      = 9,
          emitvector         = [[dir]],
          gravity            = [[0.0, -0.01, 0.0]],
          numparticles       = 13,
          particlelife       = 14,
          particlelifespread = 9,
          particlesize       = 0.66,
          particlesizespread = 0.66,
          particlespeed      = 0.5,
          particlespeedspread = 4.5,
          pos                = [[0.0, 0, 0.0]],
          sizegrowth         = 0.16,
          sizemod            = 1,
          texture            = [[dirt]],
          useairlos          = true,
      },
    },
    --clouddust = {
    --  air                = true,
    --  class              = [[CSimpleParticleSystem]],
    --  count              = 1,
    --  ground             = true,
    --  properties = {
    --    airdrag            = 0.85,
    --    colormap           = [[0.02 0.02 0.02 0.03  0.045 0.045 0.045 0.07  0.035 0.035 0.035 0.05  0.019 0.019 0.019 0.03  0 0 0 0]],
    --    directional        = true,
    --    emitrot            = 45,
    --    emitrotspread      = 4,
    --    emitvector         = [[0.5, 1, 0.5]],
    --    gravity            = [[0, 0.015, 0]],
    --    numparticles       = 2,
    --    particlelife       = 90,
    --    particlelifespread = 90,
    --    particlesize       = 4,
    --    particlesizespread = 1.5,
    --    particlespeed      = 1,
    --    particlespeedspread = 1,
    --    pos                = [[0, 0, 0]],
    --    sizegrowth         = 0.25,
    --    sizemod            = 1.0,
    --    texture            = [[bigexplosmoke]],
    --  },
    --},
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

local size = 0.44
definitions["barrelshot-tiny"] = deepcopy(definitions["barrelshot-medium"])
definitions["barrelshot-tiny"].fire.properties.length										= definitions["barrelshot-tiny"].fire.properties.length * size
definitions["barrelshot-tiny"].fire.properties.size											= definitions["barrelshot-tiny"].fire.properties.size * size
definitions["barrelshot-tiny"].fire.properties.ttl											= 3
definitions["barrelshot-tiny"].fire2.properties.length									= definitions["barrelshot-tiny"].fire2.properties.length * size
definitions["barrelshot-tiny"].fire2.properties.size										= definitions["barrelshot-tiny"].fire2.properties.size * size
definitions["barrelshot-tiny"].fire2.properties.ttl											= 3
definitions["barrelshot-tiny"].fireglow.properties.particlesize					= definitions["barrelshot-tiny"].fireglow.properties.particlesize * size*0.7
definitions["barrelshot-tiny"].fireglow.properties.particlelife					= 2 + definitions["barrelshot-tiny"].fireglow.properties.particlelife * size
definitions["barrelshot-tiny"].fireglow.properties.colormap       			= [[0.07 0.04 0.007 0.01   0 0 0 0.01]]
definitions["barrelshot-tiny"].smoke2 = nil
definitions["barrelshot-tiny"].smoke = nil
--definitions["barrelshot-tiny"].clouddust = nil

size = 0.7
definitions["barrelshot-small"] = deepcopy(definitions["barrelshot-medium"])
definitions["barrelshot-small"].fire.properties.length									= definitions["barrelshot-small"].fire.properties.length * size
definitions["barrelshot-small"].fire.properties.size										= definitions["barrelshot-small"].fire.properties.size * size
definitions["barrelshot-small"].fire.properties.ttl											= 4.5
definitions["barrelshot-small"].fire2.properties.length									= definitions["barrelshot-small"].fire2.properties.length * size
definitions["barrelshot-small"].fire2.properties.size										= definitions["barrelshot-small"].fire2.properties.size * size
definitions["barrelshot-small"].fire2.properties.ttl										= 4.5
definitions["barrelshot-small"].fireglow.properties.particlesize				= definitions["barrelshot-small"].fireglow.properties.particlesize * size
definitions["barrelshot-small"].fireglow.properties.particlelife				= 1.5 + definitions["barrelshot-small"].fireglow.properties.particlelife * size
definitions["barrelshot-small"].fireglow.properties.colormap          	= [[0.122 0.066 0.013 0.03   0 0 0 0.01]]
definitions["barrelshot-small"].smoke2.properties.particlelifespread			= definitions["barrelshot-small"].smoke2.properties.particlelifespread * size
definitions["barrelshot-small"].smoke2.properties.particlesize						= definitions["barrelshot-small"].smoke2.properties.particlesize * size
definitions["barrelshot-small"].smoke2.properties.particlesizespread			= definitions["barrelshot-small"].smoke2.properties.particlesizespread * size
definitions["barrelshot-small"].smoke2.properties.numparticles						= definitions["barrelshot-small"].smoke2.properties.numparticles * size
definitions["barrelshot-small"].smoke2.properties.particlespeedspread		= definitions["barrelshot-small"].smoke2.properties.particlespeedspread * size
definitions["barrelshot-small"].smoke.properties.particlelifespread			= definitions["barrelshot-small"].smoke.properties.particlelifespread * size
definitions["barrelshot-small"].smoke.properties.particlesize						= definitions["barrelshot-small"].smoke.properties.particlesize * size
definitions["barrelshot-small"].smoke.properties.particlesizespread			= definitions["barrelshot-small"].smoke.properties.particlesizespread * size
definitions["barrelshot-small"].smoke.properties.numparticles						= definitions["barrelshot-small"].smoke.properties.numparticles * size
definitions["barrelshot-small"].smoke.properties.particlespeedspread		= definitions["barrelshot-small"].smoke.properties.particlespeedspread * size
--definitions["barrelshot-small"].clouddust.properties.particlesize				= definitions["barrelshot-small"].clouddust.properties.particlesize * size
--definitions["barrelshot-small"].clouddust.properties.particlesizespread	= definitions["barrelshot-small"].clouddust.properties.particlesizespread * size
--definitions["barrelshot-small"].clouddust.properties.particlelife			= definitions["barrelshot-small"].clouddust.properties.particlelife * size
--definitions["barrelshot-small"].clouddust.properties.particlelifespread	= definitions["barrelshot-small"].clouddust.properties.particlelifespread * size

size = 1.6
definitions["barrelshot-large"] = deepcopy(definitions["barrelshot-medium"])
definitions["barrelshot-large"].fire.properties.length 									= definitions["barrelshot-large"].fire.properties.length * size
definitions["barrelshot-large"].fire.properties.size										= definitions["barrelshot-large"].fire.properties.size * size
definitions["barrelshot-large"].fire.properties.ttl											= 6.5
definitions["barrelshot-large"].fire2.properties.length									= definitions["barrelshot-large"].fire2.properties.length * size
definitions["barrelshot-large"].fire2.properties.size										= definitions["barrelshot-large"].fire2.properties.size * size
definitions["barrelshot-large"].fire2.properties.ttl										= 6.5
definitions["barrelshot-large"].fireglow.properties.particlesize				= definitions["barrelshot-large"].fireglow.properties.particlesize * size
definitions["barrelshot-large"].fireglow.properties.particlelife				= definitions["barrelshot-large"].fireglow.properties.particlelife * size
definitions["barrelshot-large"].fireglow.properties.colormap          	= [[0.122 0.066 0.013 0.035   0 0 0 0.01]]
definitions["barrelshot-large"].smoke2.properties.particlelifespread			= definitions["barrelshot-large"].smoke2.properties.particlelifespread * size
definitions["barrelshot-large"].smoke2.properties.particlesize						= definitions["barrelshot-large"].smoke2.properties.particlesize * size
definitions["barrelshot-large"].smoke2.properties.particlesizespread			= definitions["barrelshot-large"].smoke2.properties.particlesizespread * size
definitions["barrelshot-large"].smoke2.properties.numparticles						= definitions["barrelshot-large"].smoke2.properties.numparticles * size
definitions["barrelshot-large"].smoke2.properties.particlespeedspread		= definitions["barrelshot-large"].smoke2.properties.particlespeedspread * size
definitions["barrelshot-large"].smoke.properties.particlelifespread			= definitions["barrelshot-large"].smoke.properties.particlelifespread * size
definitions["barrelshot-large"].smoke.properties.particlesize						= definitions["barrelshot-large"].smoke.properties.particlesize * size
definitions["barrelshot-large"].smoke.properties.particlesizespread			= definitions["barrelshot-large"].smoke.properties.particlesizespread * size
definitions["barrelshot-large"].smoke.properties.numparticles						= definitions["barrelshot-large"].smoke.properties.numparticles * size
definitions["barrelshot-large"].smoke.properties.particlespeedspread		= definitions["barrelshot-large"].smoke.properties.particlespeedspread * size
--definitions["barrelshot-large"].clouddust.properties.particlesize				= definitions["barrelshot-large"].clouddust.properties.particlesize * size
--definitions["barrelshot-large"].clouddust.properties.particlesizespread	= definitions["barrelshot-large"].clouddust.properties.particlesizespread * size
--definitions["barrelshot-large"].clouddust.properties.particlelife			= definitions["barrelshot-small"].clouddust.properties.particlelife * size
--definitions["barrelshot-large"].clouddust.properties.particlelifespread	= definitions["barrelshot-small"].clouddust.properties.particlelifespread * size

size = 2.9
definitions["barrelshot-huge"] = deepcopy(definitions["barrelshot-medium"])
definitions["barrelshot-huge"].fire.properties.length 									= definitions["barrelshot-huge"].fire.properties.length * size
definitions["barrelshot-huge"].fire.properties.size											= definitions["barrelshot-huge"].fire.properties.size * size
definitions["barrelshot-huge"].fire.properties.ttl											= 8.5
definitions["barrelshot-huge"].fire2.properties.length									= definitions["barrelshot-huge"].fire2.properties.length * size
definitions["barrelshot-huge"].fire2.properties.size										= definitions["barrelshot-huge"].fire2.properties.size * size
definitions["barrelshot-huge"].fire2.properties.ttl											= 8.5
definitions["barrelshot-huge"].fireglow.properties.particlesize					= definitions["barrelshot-huge"].fireglow.properties.particlesize * size
definitions["barrelshot-huge"].fireglow.properties.particlelife					= definitions["barrelshot-huge"].fireglow.properties.particlelife * size
definitions["barrelshot-huge"].fireglow.properties.colormap        			= [[0.122 0.066 0.013 0.03   0 0 0 0.01]]
definitions["barrelshot-huge"].smoke2.properties.particlelifespread			= definitions["barrelshot-huge"].smoke2.properties.particlelifespread * size
definitions["barrelshot-huge"].smoke2.properties.particlesize						= definitions["barrelshot-huge"].smoke2.properties.particlesize * size
definitions["barrelshot-huge"].smoke2.properties.particlesizespread			= definitions["barrelshot-huge"].smoke2.properties.particlesizespread * size
definitions["barrelshot-huge"].smoke2.properties.numparticles						= definitions["barrelshot-huge"].smoke2.properties.numparticles * size
definitions["barrelshot-huge"].smoke2.properties.particlespeedspread		= definitions["barrelshot-huge"].smoke2.properties.particlespeedspread * size
definitions["barrelshot-huge"].smoke.properties.particlelifespread			= definitions["barrelshot-huge"].smoke.properties.particlelifespread * size
definitions["barrelshot-huge"].smoke.properties.particlesize						= definitions["barrelshot-huge"].smoke.properties.particlesize * size
definitions["barrelshot-huge"].smoke.properties.particlesizespread			= definitions["barrelshot-huge"].smoke.properties.particlesizespread * size
definitions["barrelshot-huge"].smoke.properties.numparticles						= definitions["barrelshot-huge"].smoke.properties.numparticles * size
definitions["barrelshot-huge"].smoke.properties.particlespeedspread			= definitions["barrelshot-huge"].smoke.properties.particlespeedspread * size
--definitions["barrelshot-huge"].clouddust.properties.particlesize				= definitions["barrelshot-huge"].clouddust.properties.particlesize * size
--definitions["barrelshot-huge"].clouddust.properties.particlesizespread	= definitions["barrelshot-huge"].clouddust.properties.particlesizespread * size
--definitions["barrelshot-huge"].clouddust.properties.particlelife			= definitions["barrelshot-small"].clouddust.properties.particlelife * size
--definitions["barrelshot-huge"].clouddust.properties.particlelifespread	= definitions["barrelshot-small"].clouddust.properties.particlelifespread * size

definitions["barrelshot-huge"].flash = {
	air = 1,
	water = 1,
	ground = 1,
	count = 1,
	class = [[CSimpleParticleSystem]],
	properties  =  {
		sizeGrowth = -4,
		sizeMod = 1.0,
		pos = [[0, 4, 0]],
		emitVector = [[-0, 1, 0]],
		gravity = [[0, 0, 0]],
		colorMap =  [[1 0.8 0.55 0.01   1 0.8 0.65 0.9   0 0 0 0.01]],
		texture = [[dirt]],
		airdrag = 1,
		particleLife = 5,
		particleLifeSpread = 0,
		numParticles = 1,
		particleSpeed = 1,
		particleSpeedSpread = 0,
		particleSize = 22,
		particleSizeSpread = 4,
		emitRot = 0,
		emitRotSpread = 180,
		directional = 1,
	},
}

definitions["barrelshot-tiny-aa"] = deepcopy(definitions["barrelshot-tiny"])
definitions["barrelshot-tiny-aa"].fire.properties.colormap = [[1 0.6 0.85 0.013   0.6 0.2 0.5 0.01   0.4 0.06 0.033 0.006   0 0 0 0.01]]
definitions["barrelshot-tiny-aa"].fire2.properties.colormap = [[1 0.6 0.85 0.013   0.6 0.2 0.5 0.01   0.4 0.06 0.033 0.006   0 0 0 0.01]]
definitions["barrelshot-tiny-aa"].fireglow.properties.colormap = [[0.122 0.066 0.09 0.04   0 0 0 0.01]]
--definitions["barrelshot-tiny-aa"].smoke.properties.colormap = [[0 0 0 0   0.15 0.055 0.12 0.2    0.48 0.26 0.40 0.44    0.2 0.135 0.17 0.4     0.16 0.12 0.145 0.4    0.145 0.11 0.13 0.4    0.13 0.095 0.075 0.4     0.115 0.088 0.07 0.35    0.1 0.075 0.066 0.3    0.09 0.07 0.06 0.26   0.08 0.065 0.06 0.22  0 0 0 0]]

definitions["barrelshot-small-aa"] = deepcopy(definitions["barrelshot-small"])
definitions["barrelshot-small-aa"].fire.properties.colormap = [[1 0.6 0.85 0.013   0.6 0.2 0.5 0.01   0.4 0.06 0.033 0.006   0 0 0 0.01]]
definitions["barrelshot-small-aa"].fire2.properties.colormap = [[1 0.6 0.85 0.013   0.6 0.2 0.5 0.01   0.4 0.06 0.033 0.006   0 0 0 0.01]]
definitions["barrelshot-small-aa"].fireglow.properties.colormap = [[0.122 0.066 0.09 0.04   0 0 0 0.01]]
definitions["barrelshot-small-aa"].smoke.properties.colormap = [[0 0 0 0   0.15 0.055 0.12 0.2    0.48 0.26 0.40 0.44    0.2 0.135 0.17 0.4     0.16 0.12 0.145 0.4    0.145 0.11 0.13 0.4    0.13 0.095 0.075 0.4     0.115 0.088 0.07 0.35    0.1 0.075 0.066 0.3    0.09 0.07 0.06 0.26   0.08 0.065 0.06 0.22  0 0 0 0]]
definitions["barrelshot-small-aa"].smoke2 = nil

definitions["barrelshot-medium-aa"] = deepcopy(definitions["barrelshot-medium"])
definitions["barrelshot-medium-aa"].fire.properties.colormap = [[1 0.6 0.85 0.013   0.6 0.2 0.5 0.01   0.4 0.06 0.033 0.006   0 0 0 0.01]]
definitions["barrelshot-medium-aa"].fire2.properties.colormap = [[1 0.6 0.85 0.013   0.6 0.2 0.5 0.01   0.4 0.06 0.033 0.006   0 0 0 0.01]]
definitions["barrelshot-medium-aa"].fireglow.properties.colormap = [[0.122 0.066 0.09 0.04   0 0 0 0.01]]
definitions["barrelshot-medium-aa"].smoke.properties.colormap = [[0 0 0 0   0.15 0.055 0.12 0.2    0.48 0.26 0.40 0.44    0.2 0.135 0.17 0.4     0.16 0.12 0.145 0.4    0.145 0.11 0.13 0.4    0.13 0.095 0.075 0.4     0.115 0.088 0.07 0.35    0.1 0.075 0.066 0.3    0.09 0.07 0.06 0.26   0.08 0.065 0.06 0.22  0 0 0 0]]
definitions["barrelshot-small-aa"].smoke2 = nil

definitions["barrelshot-large-aa"] = deepcopy(definitions["barrelshot-large"])
definitions["barrelshot-large-aa"].fire.properties.colormap = [[1 0.6 0.85 0.013   0.6 0.2 0.5 0.01   0.4 0.06 0.033 0.006   0 0 0 0.01]]
definitions["barrelshot-large-aa"].fire2.properties.colormap = [[1 0.6 0.85 0.013   0.6 0.2 0.5 0.01   0.4 0.06 0.033 0.006   0 0 0 0.01]]
definitions["barrelshot-large-aa"].fireglow.properties.colormap = [[0.122 0.066 0.09 0.04   0 0 0 0.01]]
definitions["barrelshot-large-aa"].smoke.properties.colormap = [[0 0 0 0   0.15 0.055 0.12 0.2    0.48 0.26 0.40 0.44    0.2 0.135 0.17 0.4     0.16 0.12 0.145 0.4    0.145 0.11 0.13 0.4    0.13 0.095 0.075 0.4     0.115 0.088 0.07 0.35    0.1 0.075 0.066 0.3    0.09 0.07 0.06 0.26   0.08 0.065 0.06 0.22  0 0 0 0]]
definitions["barrelshot-small-aa"].smoke2 = nil

definitions["barrelshot-huge-aa"] = deepcopy(definitions["barrelshot-huge"])
definitions["barrelshot-huge-aa"].fire.properties.colormap = [[1 0.6 0.85 0.013   0.6 0.2 0.5 0.01   0.4 0.06 0.033 0.006   0 0 0 0.01]]
definitions["barrelshot-huge-aa"].fire2.properties.colormap = [[1 0.6 0.85 0.013   0.6 0.2 0.5 0.01   0.4 0.06 0.033 0.006   0 0 0 0.01]]
definitions["barrelshot-huge-aa"].fireglow.properties.colormap = [[0.122 0.066 0.09 0.04   0 0 0 0.01]]
definitions["barrelshot-huge-aa"].smoke.properties.colormap = [[0 0 0 0   0.15 0.055 0.12 0.2    0.48 0.26 0.40 0.44    0.2 0.135 0.17 0.4     0.16 0.12 0.145 0.4    0.145 0.11 0.13 0.4    0.13 0.095 0.075 0.4     0.115 0.088 0.07 0.35    0.1 0.075 0.066 0.3    0.09 0.07 0.06 0.26   0.08 0.065 0.06 0.22  0 0 0 0]]
definitions["barrelshot-small-aa"].smoke2 = nil

definitions["barrelshot-sniper"] = deepcopy(definitions["barrelshot-large"])
definitions["barrelshot-sniper"].fire.properties.colormap = [[1 0.33 0.15 0.015   0.7 0.17 0.08 0.01   0.4 0.06 0.03 0.01   0 0 0 0.01]]
definitions["barrelshot-sniper"].fire2.properties.colormap = [[1 0.33 0.15 0.015   0.7 0.17 0.08 0.01   0.4 0.06 0.03 0.01   0 0 0 0.01]]
definitions["barrelshot-sniper"].fireglow.properties.colormap = [[0.122 0.066 0.025 0.04   0 0 0 0.01]]
definitions["barrelshot-sniper"].smoke.properties.colormap = [[0 0 0 0   0.15 0.055 0.03 0.2    0.48 0.26 0.15 0.44    0.2 0.135 0.1 0.4     0.16 0.12 0.11 0.4    0.145 0.11 0.095 0.4    0.13 0.095 0.075 0.4     0.115 0.088 0.07 0.35    0.1 0.075 0.066 0.3    0.09 0.07 0.06 0.26   0.08 0.065 0.06 0.22  0 0 0 0]]


return definitions
