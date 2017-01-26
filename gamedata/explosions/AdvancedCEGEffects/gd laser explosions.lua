-- laser

return {
  ["laser"] = {
    groundflash = {
      air                = true,
      circlealpha        = 0,
      circlegrowth       = 0,
      flashalpha         = 0.9,
      flashsize          = 3,
      ground             = true,
      ttl                = 15,
      water              = true,
      color = {
        [1]  = 1,
        [2]  = 0.25,
        [3]  = 0.5,
      },
    },
    smoke = {
      air                = true,
      count              = 2,
      ground             = true,
      water              = true,
      properties = {
        agespeed           = 0.03,
        color              = [[0.8 r0.2]],
        pos                = [[5 r-5, 5 r-5, 5 r-5]],
        size               = 0.5,
        sizeexpansion      = 0.25,
        sizegrowth         = -0.75,
        speed              = [[0, 0.6 r0.3, 0]],
        startsize          = 0.5,
      },
    },
  },

}

