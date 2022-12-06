local defs = {

  ["deathceg2"] = {
	  flame = {
		  air                = true,
		  class              = [[CSimpleParticleSystem]],
		  count              = 1,
		  ground             = true,
		  properties = {
			  airdrag            = 0.85,
			  colormap           = [[1.0 0.9 0.7 1  0.8 0.55 0.33 0.85   0.19 0.15 0.12 0.73  0.14 0.12 0.1 0.62   0.09 0.08 0.07 0.5   0.022 0.022 0.022 0.3   0.01 0.01 0.01 0.15   0 0 0 0.01]],
			  directional        = true,
			  emitrot            = 90,
			  emitrotspread      = 30,
			  emitvector         = [[0.3 r0.1, 1, 0.3 r0.1]],
			  gravity            = [[-0.09 r0.18, 0.06 r0.11, -0.09 r0.18]],
			  numparticles       = 1,
			  particlelife       = 6,
			  particlelifespread = 9,
			  particlesize       = 3.3,
			  particlesizespread = 2,
			  particlespeed      = 0.2,
			  particlespeedspread = 0.55,
			  pos                = [[-1.5 r3, -1.5 r3, -1.5 r3]],
			  rotParams          = [[-5 r10, 0, -180 r360]],
			  sizegrowth         = [[2 r1.5]],
			  sizemod            = 0.85,
			  animParams         = [[16,6,40 r40]],
			  texture            = [[BARFlame02]],
			  useairlos          = true,
			  alwaysVisible      = true,
			  drawOrder          = 1,
		  },
	  },
	  --fire = {
	--	  air                = true,
	--	  class              = [[CSimpleParticleSystem]],
	--	  count              = 1,
	--	  ground             = true,
	--	  properties = {
	--		  airdrag            = 0.66,
	--		  colormap           = [[0.8 0.66 0.4 0.04   0.75 0.55 0.35 0.035   0.5 0.37 0.25 0.03   0.3 0.22 0.15 0.022   0.2 0.15 0.06 0.015   0 0 0 0.01]],
	--		  directional        = true,
	--		  emitrot            = 90,
	--		  emitrotspread      = 0,
	--		  emitvector         = [[0.0, 1, 0.0]],
	--		  gravity            = [[0, -0.011, 0]],
	--		  numparticles       = [[0.5 r1]],
	--		  particlelife       = 2,
	--		  particlelifespread = 1,
	--		  particlesize       = 1.1,
	--		  particlesizespread = 1.5,
	--		  particlespeed      = 0.3,
	--		  particlespeedspread = 0.8,
	--		  pos                = [[-1.5 r3, -1.5 r3, -1.5 r3]],
	--		  sizegrowth         = 0.25,
	--		  sizemod            = 0.97,
	--		  texture            = [[flame]],
	--	  },
	  --},
	  --fireglow = {
	--	  air                = true,
	--	  class              = [[CSimpleParticleSystem]],
	--	  count              = 1,
	--	  ground             = true,
	--	  water              = true,
	--	  properties = {
	--		  airdrag            = 0,
	--		  colormap           = [[0.33 0.15 0.04 0.01   0 0 0 0.01]],
	--		  directional        = true,
	--		  emitrot            = 90,
	--		  emitrotspread      = 0,
	--		  emitvector         = [[0.0, 1, 0.0]],
	--		  gravity            = [[0.0, 0.0, 0.0]],
	--		  numparticles       = 1,
	--		  particlelife       = 1,
	--		  particlelifespread = 1,
	--		  particlesize       = 19,
	--		  particlesizespread = 3,
	--		  particlespeed      = 0,
	--		  particlespeedspread = 0,
	--		  pos                = [[0.0, 0, 0.0]],
	--		  sizegrowth         = -1.7,
	--		  sizemod            = 1,
	--		  texture            = [[glow2]],
	--		  useairlos          = true,
	--	  },
	  --},
  },



  ["deathceg3"] = {
	  flame = {
		  air                = true,
		  class              = [[CSimpleParticleSystem]],
		  count              = 1,
		  ground             = true,
		  properties = {
			  airdrag            = 0.85,
			  colormap           = [[1.0 0.9 0.7 1  0.8 0.55 0.33 0.85   0.19 0.15 0.12 0.73  0.14 0.12 0.1 0.62   0.09 0.08 0.07 0.5   0.022 0.022 0.022 0.3   0.01 0.01 0.01 0.15   0 0 0 0.01]],
			  directional        = true,
			  emitrot            = 90,
			  emitrotspread      = 30,
			  emitvector         = [[0.3 r0.1, 1, 0.3 r0.1]],
			  gravity            = [[-0.09 r0.18, 0.06 r0.11, -0.09 r0.18]],
			  numparticles       = 1,
			  particlelife       = 7,
			  particlelifespread = 12,
			  particlesize       = 5,
			  particlesizespread = 3.5,
			  particlespeed      = 0.2,
			  particlespeedspread = 0.55,
			  pos                = [[-1.5 r3, -1.5 r3, -1.5 r3]],
			  rotParams          = [[-5 r10, 0, -180 r360]],
			  sizegrowth         = [[2 r1.5]],
			  sizemod            = 0.85,
			  animParams         = [[16,6,40 r40]],
			  texture            = [[BARFlame02]],
			  useairlos          = true,
			  alwaysVisible      = true,
			  drawOrder          = 1,
		  },
	  },
	  --fire = {
	--	  air                = true,
	--	  class              = [[CSimpleParticleSystem]],
	--	  count              = 1,
	--	  ground             = true,
	--	  properties = {
	--		  airdrag            = 0.66,
	--		  colormap           = [[0.8 0.66 0.4 0.04   0.75 0.55 0.35 0.035   0.5 0.37 0.25 0.03   0.3 0.22 0.15 0.022   0.2 0.15 0.06 0.015   0 0 0 0.01]],
	--		  directional        = true,
	--		  emitrot            = 90,
	--		  emitrotspread      = 0,
	--		  emitvector         = [[0.0, 1, 0.0]],
	--		  gravity            = [[0, -0.011, 0]],
	--		  numparticles       = [[0.66 r1]],
	--		  particlelife       = 2,
	--		  particlelifespread = 1,
	--		  particlesize       = 1.50,
	--		  particlesizespread = 2.7,
	--		  particlespeed      = 0.3,
	--		  particlespeedspread = 0.8,
	--		  pos                = [[-2 r4, -2 r4, -2 r4]],
	--		  sizegrowth         = 0.25,
	--		  sizemod            = 0.97,
	--		  texture            = [[flame]],
	--	  },
	  --},
	  --fireglow = {
	--	  air                = true,
	--	  class              = [[CSimpleParticleSystem]],
	--	  count              = 1,
	--	  ground             = true,
	--	  water              = true,
	--	  properties = {
	--		  airdrag            = 0,
	--		  colormap           = [[0.35 0.15 0.04 0.01   0 0 0 0.01]],
	--		  directional        = true,
	--		  emitrot            = 90,
	--		  emitrotspread      = 0,
	--		  emitvector         = [[0.0, 1, 0.0]],
	--		  gravity            = [[0.0, 0.0, 0.0]],
	--		  numparticles       = 1,
	--		  particlelife       = 2,
	--		  particlelifespread = 1,
	--		  particlesize       = 25,
	--		  particlesizespread = 5,
	--		  particlespeed      = 0,
	--		  particlespeedspread = 0,
	--		  pos                = [[0.0, 0, 0.0]],
	--		  sizegrowth         = -1.7,
	--		  sizemod            = 1,
	--		  texture            = [[glow2]],
	--		  useairlos          = true,
	--	  },
	  --},
    --dustparticles = {
    --  air                = true,
    --  class              = [[CSimpleParticleSystem]],
    --  count              = 1,
    --  ground             = true,
    --  underwater         = true,
    --  water              = true,
    --  properties = {
    --    airdrag            = 0.75,
    --    colormap           = [[1 0.7 0.4 0.01   0 0 0 0.01]],
    --    directional        = true,
    --    emitrot            = 20,
    --    emitrotspread      = 2,
    --    emitvector         = [[dir]],
    --    gravity            = [[0, -0.011, 0]],
    --    numparticles       = 1,
    --    particlelife       = 4,
    --    particlelifespread = 1,
    --    particlesize       = 2.2,
    --    particlesizespread = 2.2,
    --    particlespeed      = 0.015,
    --    particlespeedspread = 0.04,
    --    pos                = [[0, 0, 0]],
    --    sizegrowth         = 0.35,
    --    sizemod            = 0.9,
    --    texture            = [[randdots]],
    --  },
    --},
  },



  ["deathceg4"] = {
	  flame = {
		  air                = true,
		  class              = [[CSimpleParticleSystem]],
		  count              = 1,
		  ground             = true,
		  properties = {
			  airdrag            = 0.85,
			  colormap           = [[1.0 0.9 0.7 1  0.8 0.55 0.33 0.85   0.19 0.15 0.12 0.73  0.14 0.12 0.1 0.62   0.09 0.08 0.07 0.5   0.022 0.022 0.022 0.3   0.01 0.01 0.01 0.15   0 0 0 0.01]],
			  directional        = true,
			  emitrot            = 90,
			  emitrotspread      = 30,
			  emitvector         = [[0.3 r0.1, 1, 0.3 r0.1]],
			  gravity            = [[-0.09 r0.18, 0.06 r0.11, -0.09 r0.18]],
			  numparticles       = 1,
			  particlelife       = 13,
			  particlelifespread = 16,
			  particlesize       = 8,
			  particlesizespread = 5,
			  particlespeed      = 0.2,
			  particlespeedspread = 0.55,
			  pos                = [[-1.5 r3, -1.5 r3, -1.5 r3]],
			  rotParams          = [[-5 r10, 0, -180 r360]],
			  sizegrowth         = [[2 r1.5]],
			  sizemod            = 0.84,
			  animParams         = [[16,6,100 r80]],
			  texture            = [[BARFlame02]],
			  useairlos          = true,
			  alwaysVisible      = true,
			  drawOrder          = 1,
		  },
	  },
	  --fire = {
	--	  air                = true,
	--	  class              = [[CSimpleParticleSystem]],
	--	  count              = 1,
	--	  ground             = true,
	--	  properties = {
	--		  airdrag            = 0.66,
	--		  colormap           = [[0.8 0.66 0.4 0.04   0.75 0.55 0.35 0.035   0.5 0.37 0.25 0.03   0.3 0.22 0.15 0.022   0.2 0.15 0.06 0.015   0 0 0 0.01]],
	--		  directional        = true,
	--		  emitrot            = 90,
	--		  emitrotspread      = 0,
	--		  emitvector         = [[0.0, 1, 0.0]],
	--		  gravity            = [[0, -0.011, 0]],
	--		  numparticles       = [[0.66 r1]],
	--		  particlelife       = 4,
	--		  particlelifespread = 2,
	--		  particlesize       = 2.2,
	--		  particlesizespread = 3.5,
	--		  particlespeed      = 0.3,
	--		  particlespeedspread = 0.8,
	--		  pos                = [[-2 r4, -2 r4, -2 r4]],
	--		  sizegrowth         = 0.25,
	--		  sizemod            = 0.97,
	--		  texture            = [[flame]],
	--	  },
	  --},
	  --fireglow = {
	--	  air                = true,
	--	  class              = [[CSimpleParticleSystem]],
	--	  count              = 1,
	--	  ground             = true,
	--	  water              = true,
	--	  properties = {
	--		  airdrag            = 0,
	--		  colormap           = [[0.4 0.17 0.04 0.01   0 0 0 0.01]],
	--		  directional        = true,
	--		  emitrot            = 90,
	--		  emitrotspread      = 0,
	--		  emitvector         = [[0.0, 1, 0.0]],
	--		  gravity            = [[0.0, 0.0, 0.0]],
	--		  numparticles       = 1,
	--		  particlelife       = 2,
	--		  particlelifespread = 0,
	--		  particlesize       = 42,
	--		  particlesizespread = 10,
	--		  particlespeed      = 0,
	--		  particlespeedspread = 0,
	--		  pos                = [[0.0, 0, 0.0]],
	--		  sizegrowth         = -1.8,
	--		  sizemod            = 1,
	--		  texture            = [[glow2]],
	--		  useairlos          = true,
	--	  },
	  --},
    --dustparticles = {
    --  air                = true,
    --  class              = [[CSimpleParticleSystem]],
    --  count              = 1,
    --  ground             = true,
    --  underwater         = true,
    --  water              = true,
    --  properties = {
    --    airdrag            = 0.75,
    --    colormap           = [[1 0.7 0.4 0.01   0 0 0 0.01]],
    --    directional        = true,
    --    emitrot            = 20,
    --    emitrotspread      = 2,
    --    emitvector         = [[dir]],
    --    gravity            = [[0, -0.011, 0]],
    --    numparticles       = 1,
    --    particlelife       = 4,
    --    particlelifespread = 2,
    --    particlesize       = 3,
    --    particlesizespread = 3,
    --    particlespeed      = 0.015,
    --    particlespeedspread = 0.04,
    --    pos                = [[0, 0, 0]],
    --    sizegrowth         = 0.35,
    --    sizemod            = 0.9,
    --    texture            = [[randdots]],
    --  },
    --},
  }
}

local effects = {
  electricity = {
    air                = true,
    class              = [[CSimpleParticleSystem]],
    count              = 1,
    ground             = true,
    water              = true,
    underwater         = true,
    properties = {
      airdrag            = 0.8,
      colormap           = [[0.7 0.7 0.9 0.037   0.5 0.5 0.9 0.01]],
      directional        = true,
      emitrot            = 45,
      emitrotspread      = 32,
      emitvector         = [[0, 1, 0]],
      gravity            = [[0, -0.01, 0]],
      numparticles       = 2,
      particlelife       = 3,
      particlelifespread = 1,
      particlesize       = 1.6,
      particlesizespread = 0.8,
      particlespeed      = 0,
      particlespeedspread = 1.2,
      pos                = [[0, 2, 0]],
      sizegrowth         = 0.6,
      sizemod            = 1,
      texture            = [[whitelightb]],
      useairlos          = false,
    },
  },
  --fire = {
  --  properties = {
  --    colormap           = [[1 1 1 0.55   1 0.75 0.55 0.44    0.75 0.47 0.44 0.37    0.3 0.14 0.25 0.3   0.11 0.033 0.14 0.11   0.08 0.016 0.12 0.16  0 0 0 0.01]],
  --  },
  --},
  --fireglow = {
  --  properties = {
  --    colormap           = [[0.25 0.17 0.05 0.01   0 0 0 0.01]],
  --  },
  --},
}

defs["deathceg2-lightning"] = table.merge(defs["deathceg2"], effects)
--defs["deathceg2-lightning"].fire.properties.numparticles = defs["deathceg2-lightning"].fire.properties.numparticles/2.5
--defs["deathceg2-lightning"].electricity.properties.numparticles = defs["deathceg2-lightning"].electricity.properties.numparticles/1.6
defs["deathceg2-lightning"].electricity.properties.particlelife = defs["deathceg2-lightning"].electricity.properties.particlelife/1.6
defs["deathceg3-lightning"] = table.merge(defs["deathceg3"], effects)
--defs["deathceg3-lightning"].fire.properties.numparticles = defs["deathceg3-lightning"].fire.properties.numparticles/2.5
--defs["deathceg3-lightning"].electricity.properties.numparticles = defs["deathceg3-lightning"].electricity.properties.numparticles/1.2
--defs["deathceg3-lightning"].electricity.properties.particlelife = defs["deathceg3-lightning"].electricity.properties.particlelife/1.2
defs["deathceg4-lightning"] = table.merge(defs["deathceg4"], effects)
--defs["deathceg4-lightning"].fire.properties.numparticles = defs["deathceg4-lightning"].fire.properties.numparticles/2.5

effects = {
  --fire = {
  --  properties = {
  --    colormap           = [[1 0.97 0.93 0.66   1 0.8 0.4 0.5    0.75 0.47 0.18 0.4    0.33 0.14 0.04 0.33   0.14 0.033 0 0.25   0.11 0.016 0 0.16  0 0 0 0.01]],
  --  },
  --},
  --fireglow = {
  --  properties = {
  --    colormap           = [[0.15 0.075 0.02 0.015   0 0 0 0.01]],
  --  },
  --},
}
defs["deathceg2-fire"] = table.merge(defs["deathceg2"], effects)
--defs["deathceg2-fire"].fireglow.properties.particlesize = defs["deathceg2-fire"].fireglow.properties.particlesize*1.7
--defs["deathceg2-fire"].fireandsmoke.properties.particlesize = defs["deathceg2-fire"].fireandsmoke.properties.particlesize*1.4
--defs["deathceg2-fire"].fireandsmoke.properties.particlelife = defs["deathceg2-fire"].fireandsmoke.properties.particlelife*1.8
--defs["deathceg2-fire"].fire.properties.particlesize = defs["deathceg2-fire"].fire.properties.particlesize*1.7
--defs["deathceg2-fire"].fire.properties.particlelife = defs["deathceg2-fire"].fire.properties.particlelife*1.7
defs["deathceg3-fire"] = table.merge(defs["deathceg3"], effects)
--defs["deathceg3-fire"].fireglow.properties.particlesize = defs["deathceg3-fire"].fireglow.properties.particlesize*1.7
--defs["deathceg3-fire"].fireandsmoke.properties.particlesize = defs["deathceg3-fire"].fireandsmoke.properties.particlesize*1.4
--defs["deathceg3-fire"].fireandsmoke.properties.particlelife = defs["deathceg3-fire"].fireandsmoke.properties.particlelife*1.8
--defs["deathceg3-fire"].fire.properties.particlesize = defs["deathceg3-fire"].fire.properties.particlesize*1.7
--defs["deathceg3-fire"].fire.properties.particlelife = defs["deathceg3-fire"].fire.properties.particlelife*1.7
defs["deathceg4-fire"] = table.merge(defs["deathceg4"], effects)
--defs["deathceg4-fire"].fireglow.properties.particlesize = defs["deathceg4-fire"].fireglow.properties.particlesize*1.7


effects = {
  --fire = {
  --  properties = {
  --    colormap           = [[0.98 1 0.91 0.55   0.85 1 0.3 0.4    0.4 0.6 0.1 0.3   0 0 0 0.01]],
  --  },
  --},
  --fireglow = {
  --  properties = {
  --    colormap           = [[0.12 0.15 0.02 0.015   0 0 0 0.01]],
  --  },
  --},
}
defs["deathceg2-builder"] = table.merge(defs["deathceg2"], effects)
defs["deathceg3-builder"] = table.merge(defs["deathceg3"], effects)
defs["deathceg4-builder"] = table.merge(defs["deathceg4"], effects)
--
--defs["deathceg2-builder"].fire.properties.colormap = [[0.9 0.8 0.2 0.04   0.8 0.6 0.150 0.022   0.6 0.5 0.10 0.03   0.25 0.2 0.05 0.016   0.15 0.15 0.05 0.012   0 0 0 0.01]]
--defs["deathceg3-builder"].fire.properties.colormap = defs["deathceg2-builder"].fire.properties.colormap
--defs["deathceg4-builder"].fire.properties.colormap = defs["deathceg2-builder"].fire.properties.colormap
--
--defs["deathceg2-builder"].fireglow.properties.colormap = [[0.50 0.40 0.04 0.01   0 0 0 0.01]]
--defs["deathceg3-builder"].fireglow.properties.colormap = defs["deathceg2-builder"].fireglow.properties.colormap
--defs["deathceg4-builder"].fireglow.properties.colormap = defs["deathceg2-builder"].fireglow.properties.colormap
--
--defs["deathceg3-builder"].dustparticles.properties.colormap = [[0.8 1 0.2 0.01   0 0 0 0.01]]
--defs["deathceg4-builder"].dustparticles.properties.colormap = defs["deathceg3-builder"].dustparticles.properties.colormap


--local effects = {
--  searingflame = {
--    air                = true,
--    class              = [[CSimpleParticleSystem]],
--    count              = 1,
--    ground             = true,
--    water              = true,
--    properties = {
--      airdrag            = 1,
--      --      colormap           = [[1 0.8 0.5 0.04   0.6 0.1 0.1 0.01]],
--      directional        = true,
--      emitrot            = 90,
--      --emitrotspread      = 45,
--      emitvector         = [[dir]],
--      gravity            = [[0, -0.1, 0]],
--      numparticles       = 12,
--      particlelife       = 150,
--      particlelifespread = 2,
--      particlesize       = 9,
--      particlesizespread = 4.5,
--      particlespeed      = 0.02,
--      particlespeedspread = 0.02,
--      pos                = [[0, 2, 0]],
--      sizegrowth         = -0.01,
--      sizemod            = 0.5,
--      texture            = [[gunshotglow]],
--      useairlos          = false,
--    },
--  },
--}
defs["deathceg2-air"] = table.merge(defs["deathceg2"], effects)
defs["deathceg3-air"] = table.merge(defs["deathceg3"], effects)


local airDefs = {}
for k,v in pairs(defs) do
	airDefs['air'..k] = table.copy(defs[k])
	--airDefs['air'..k].fireandsmoke.properties.particlelife = v.fireandsmoke.properties.particlelife * 0.6
	--airDefs['air'..k].fireandsmoke.properties.colormap = [[0.05 0.034 0.028 0.62   0.044 0.033 0.027 0.57   0.04 0.031 0.026 0.48   0.025 0.023 0.023 0.3   0.014 0.013 0.013 0.15    0.006 0.006 0.006 0.06   0 0 0 0.01]]
end
table.mergeInPlace(defs, airDefs)

-- add purple scavenger variants
local scavengerDefs = {}
for k,v in pairs(defs) do
	scavengerDefs[k..'-purple'] = table.copy(defs[k])
end

local purpleEffects = {
  --fire = {
  --  properties = {
  --    colormap = [[0.6 0.25 0.8 0.04   0.5 0.35 0.75 0.035   0.3 0.1 0.5 0.03   0.2 0.08 0.3 0.022   0.1 0.04 0.2 0.015   0 0 0 0.01]]
  --  }
  --},
  --fireglow = {
  --  properties = {
  --    colormap = [[0.18 0.07 0.33 0.01   0 0 0 0.01]]
  --  }
  --},
}
for defName, def in pairs(scavengerDefs) do
  for effect, effectParams in pairs(purpleEffects) do
    if scavengerDefs[defName][effect] then
      for param, paramValue in pairs(effectParams) do
        if scavengerDefs[defName][effect][param] then
          if param == 'properties' then
            for property,propertyValue in pairs(paramValue) do
              if scavengerDefs[defName][effect][param][property] then
                scavengerDefs[defName][effect][param][property] = propertyValue
              end
            end
          else
            scavengerDefs[defName][effect][param] = paramValue
          end
        end
      end
    end
  end
end

table.mergeInPlace(defs, scavengerDefs)

return defs
