-- shotgunimpact

return {
  ["shotgunimpact"] = {
    dirt01 = {
      class              = [[dirt]],
      count              = 3,
      ground             = true,
      properties = {
        alphafalloff       = 2,
        alwaysvisible      = true,
        color              = [[0.2, 0.1, 0.05]],
        pos                = [[r-5 r5, 0, r-5 r5]],
        size               = 10,
        speed              = [[r1.5 r-1.5, 4.7, r1.5 r-1.5]],
      },
    },
    dirt02 = {
      class              = [[dirt]],
      count              = 4,
      water              = true,
      properties = {
        alphafalloff       = 2,
        alwaysvisible      = true,
        color              = [[0.8, 0.8, 1.0]],
        pos                = [[r-5 r5, 0, r-5 r5]],
        size               = 33,
        speed              = [[r1.5 r-1.5, 4.7, r1.5 r-1.5]],
      },
    },
    pillar = {
      air                = true,
      class              = [[heatcloud]],
      count              = 3,
      properties = {
        alwaysvisible      = true,
        heat               = 15,
        heatfalloff        = 2.5,
        maxheat            = 15,
        pos                = [[0,1, 0]],
        size               = 35,
        sizegrowth         = -1,
        speed              = [[0, 0, 0]],
        texture            = [[flare]],
      },
    },
    smoke = {
      air                = true,
      count              = 2,
      ground             = true,
      properties = {
        agespeed           = 0.15,
        alwaysvisible      = true,
        color              = 0.3,
        pos                = [[0,-1 i4,0]],
        size               = 45,
        sizegrowth         = 0,
        speed              = [[0, 5, 0]],
      },
    },
  },

}

