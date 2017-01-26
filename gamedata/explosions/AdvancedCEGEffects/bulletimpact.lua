-- bulletimpact

return {
  ["bulletimpact"] = {
    dirt01 = {
      class              = [[dirt]],
      count              = 3,
      ground             = true,
      properties = {
        alphafalloff       = 2,
        color              = [[0.2, 0.1, 0.05]],
        pos                = [[r-5 r5, 0, r-5 r5]],
        size               = 10,
        speed              = [[r1.5 r-1.5, 1.7, r1.5 r-1.5]],
      },
    },
    dirt03 = {
      air                = true,
      class              = [[dirt]],
      count              = 2,
      properties = {
        alphafalloff       = 2,
        color              = [[0.5, 0.5, 0.2]],
        pos                = [[r-5 r5, 0, r-5 r5]],
        size               = 10,
        speed              = [[r1.5 r-1.5, 1.7, r1.5 r-1.5]],
      },
    },
    dirtw03 = {
      class              = [[dirt]],
      count              = 5,
      water              = true,
      properties = {
        alphafalloff       = 2,
        color              = [[0.7, 0.7, 1.0]],
        pos                = [[r-5 r5, 0, r-5 r5]],
        size               = 7,
        speed              = [[r1.5 r-1.5, 1.7, r1.5 r-1.5]],
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
        size               = 20,
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
        size               = 10,
        sizegrowth         = 0,
        speed              = [[0, 5, 0]],
      },
    },
  },

}

