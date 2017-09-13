-- genericshellexplosion-medium-lightning
-- genericshellexplosion-small-lightning
-- genericshellexplosion-large-lightning

return {

  ["junoflash"] = {
    centerflare = {
      air                = true,
      class              = [[heatcloud]],
      count              = 1,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        heat               = 9,
        heatfalloff        = 1.3,
        maxheat            = 20,
        pos                = [[r-2 r2, 5, r-2 r2]],
        size               = 1,
        sizegrowth         = 12,
        speed              = [[0, 1 0, 0]],
        texture            = [[flare]],
      },
    },
    electricstorm = {
      air                = true,
      class              = [[CExpGenSpawner]],
      count              = 40,
      ground             = true,
      water              = true, 
	  underwater         = true,
      properties = {
        delay              = [[20 r220]],
        explosiongenerator = [[custom:lightning_stormbolt]],
        pos                = [[-450 r900, 1, -450 r900]],
      },
    },
    groundflash = {
      air                = true,
      flashalpha         = 0.18,
      flashsize          = 770,
      ground             = true,
      ttl                = 166,
      water              = true, 
      underwater         = true,
      color = {
        [1]  = 0.7,
        [2]  = 1,
        [3]  = 0.2,
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
        heat               = 8,
        heatfalloff        = 1.8,
        maxheat            = 20,
        pos                = [[r-2 r2, 5, r-2 r2]],
        size               = 1.5,
        sizegrowth         = 17,
        speed              = [[0, 1 0, 0]],
        texture            = [[brightblueexplo]],
      },
    },
  },

}

