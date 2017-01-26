-- beam_explosion

return {
  ["beam_explosion"] = {
    groundflash = {
      air                = true,
      alwaysvisible      = true,
      circlealpha        = 0.5,
      circlegrowth       = 10,
      circlesize         = 10,
      flashalpha         = 0.9,
      flashsize          = 120,
      ground             = true,
      ttl                = 15,
      water              = true,
      color = {
        [1]  = 1,
        [2]  = 0.30000001192093,
        [3]  = 1,
      },
    },
    pop = {
      air                = true,
      class              = [[heatcloud]],
      count              = 5,
      ground             = true,
      water              = true,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 0.4,
        maxheat            = 15,
        pos                = [[r-25 r25, 5, r-25 r25]],
        size               = 55,
        sizegrowth         = 0.9,
        speed              = [[r-1 r1, 1 0, r-1 r1]],
        texture            = [[2explo]],
      },
    },
    smoke = {
      air                = true,
      count              = 8,
      ground             = true,
      water              = true,
      properties = {
        agespeed           = 0.04,
        alwaysvisible      = true,
        color              = 0.1,
        pos                = [[r-3 r3, r-3 r3, r-3 r3]],
        size               = 40,
        sizeexpansion      = 0.9,
        sizegrowth         = 15,
        speed              = [[0, 1 r2.3, 0]],
        startsize          = 10,
      },
    },
  },

}

