-- flame

return {
  ["flame"] = {
    groundflash = {
      air                = true,
      circlealpha        = 0,
      circlegrowth       = 0,
      flashalpha         = 0.8,
      flashsize          = 12,
      ground             = true,
      ttl                = 60,
      water              = true,
      color = {
        [1]  = 1,
        [2]  = 0.30000001192093,
        [3]  = 0.20000000298023,
      },
    },
    heatcloud = {
      air                = true,
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        heat               = 15,
        heatfalloff        = 1,
        maxheat            = 15,
        pos                = [[0, 0, 0]],
        size               = 1.25,
        sizegrowth         = 0.5,
        sizemod            = 0,
        sizemodmod         = 0,
        speed              = [[0, 2, 0]],
        texture            = [[ExplodeHeat]],
      },
    },
    smoke = {
      air                = true,
      count              = 3,
      ground             = true,
      water              = true,
      properties = {
        agespeed           = 0.03,
        color              = 0.1,
        pos                = [[5 r-5, 5 r-5, 5 r-5]],
        size               = 2.5,
        sizeexpansion      = 0.5,
        sizegrowth         = 0.5,
        speed              = [[0, 2 r0.5, 0]],
        startsize          = 0.75,
      },
    },
  },

}

