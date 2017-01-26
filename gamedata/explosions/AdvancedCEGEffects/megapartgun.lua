-- megapartgun

return {
  ["megapartgun"] = {
    dirt = {
      count              = 4,
      ground             = true,
      properties = {
        alphafalloff       = 2,
        alwaysvisible      = true,
        color              = [[0.2, 0.1, 0.05]],
        pos                = [[r-10 r10, 0, r-10 r10]],
        size               = 20,
        speed              = [[r1.5 r-1.5, 2, r1.5 r-1.5]],
      },
    },
    groundflash = {
      air                = true,
      alwaysvisible      = true,
      circlealpha        = 0.5,
      circlegrowth       = 8,
      flashalpha         = 0.9,
      flashsize          = 140,
      ground             = true,
      ttl                = 17,
      water              = true,
      color = {
        [1]  = 1,
        [2]  = 0.30000001192093,
        [3]  = 0.5,
      },
    },
    pillar = {
      air                = true,
      class              = [[heatcloud]],
      count              = 3,
      ground             = true,
      water              = true,
      properties = {
        alwaysvisible      = true,
        heat               = 15,
        heatfalloff        = 2.5,
        maxheat            = 15,
        pos                = [[0,0 i5, 0]],
        size               = 90,
        sizegrowth         = -11,
        speed              = [[0, 10, 0]],
        texture            = [[pinknovaexplo]],
      },
    },
    pop = {
      air                = true,
      class              = [[heatcloud]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 0.5,
        maxheat            = 15,
        pos                = [[r-2 r2, 5, r-2 r2]],
        size               = 90,
        sizegrowth         = 0.9,
        speed              = [[0, 1 0, 0]],
        texture            = [[pinknovaexplo]],
      },
    },
  },

}

