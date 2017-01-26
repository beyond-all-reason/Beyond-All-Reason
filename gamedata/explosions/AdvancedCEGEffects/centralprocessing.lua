-- centralprocessing

return {
  ["centralprocessing"] = {
    explosionsphere = {
      air                = true,
      class              = [[CSpherePartSpawner]],
      count              = 1,
      ground             = true,
      properties = {
        alpha              = 0.4,
        alwaysvisible      = false,
        color              = [[0.0, 0.3, 0.5]],
        expansionspeed     = [[3 r3]],
        ttl                = 20,
      },
    },
    explosionspikes = {
      air                = true,
      class              = [[explspike]],
      count              = 7,
      ground             = true,
      water              = true,
      properties = {
        alpha              = 1,
        alphadecay         = 0.19,
        alwaysvisible      = false,
        color              = [[0.0, 0.3, 1]],
        dir                = [[-45 r90,-45 r90,-45 r90]],
        length             = 0.4,
        width              = 4,
      },
    },
    pop1 = {
      air                = true,
      class              = [[heatcloud]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        alwaysvisible      = false,
        heat               = 10,
        heatfalloff        = 0.8,
        maxheat            = 10,
        pos                = [[r-2 r2, 5, r-2 r2]],
        size               = 1,
        sizegrowth         = 16,
        speed              = [[0, 0, 0]],
        texture            = [[bluenovaexplo]],
      },
    },
  },

}

