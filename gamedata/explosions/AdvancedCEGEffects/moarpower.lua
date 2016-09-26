-- sparklegreen

return {
  ["moarpower"] = {
	number = {
		air			= true,
		water		= true,
		ground		= true,
		underwater	= true,
		count		= 1,
		class              	= [[CSimpleParticleSystem]],
		
		properties = {
			sizeGrowth			= 0,
			sizeMod				= 1,
			pos					= [[0, 20, 0]],
			emitVector			= [[0, 1, 0]],
			gravity				= [[0, 0, 0]],
			colorMap			= [[1 1 1 1   1 1 1 1   0 0 0 0]],
			Texture				= [[moarpower]],
			airdrag				= 0.95,
			particleLife		= 100,
			particleLifeSpread	= 0,
			numParticles		= 1,
			particleSpeed		= 5,
			particleSpeedSpread	= 0,
			particleSize		= 30,
			particleSizeSpread	= 0,
			emitRot				= 0,
			emitRotSpread		= 0,
			directional			= 0,
		},
	}, 
	
	-- resources = {
      -- class              = [[heatcloud]],
      -- count              = 1,
		-- air			= true,
		-- water		= true,
		-- ground		= true,
		-- underwater	= true,
      -- properties = {
        -- alwaysvisible      = false,
        -- heat               = 5,
        -- heatfalloff        = 0.1,
        -- maxheat            = 10,
        -- pos                = [[0, 0, 0]],
        -- size               = 1,
        -- sizegrowth         = 5,
        -- speed              = [[0, 5, 0]],
        -- texture            = [[plus5plus5]],
      -- },
    -- },
	
	
  },

  ["sparklegreenplus51"] = {
    pop1 = {
      class              = [[heatcloud]],
      count              = 1,
		air			= true,
		water		= true,
		ground		= true,
		underwater	= true,
      properties = {
        alwaysvisible      = false,
        heat               = 5,
        heatfalloff        = 0.1,
        maxheat            = 10,
        pos                = [[0, 0, 0]],
        size               = 1,
        sizegrowth         = 5,
        speed              = [[0, 5, 0]],
        texture            = [[plus5plus5]],
      },
    },
  },
  
  
}

