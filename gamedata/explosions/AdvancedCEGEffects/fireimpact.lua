-- fireimpact

return {
  ["fireimpact"] = {
    groundflash = {
      air                = true,
      alwaysvisible      = true,
      circlealpha        = 0.0,
      circlegrowth       = 9,
      flashalpha         = 0.3,
      flashsize          = 50,
      ground             = true,
      ttl                = 7,
      water              = true,
      color = {
        [1]  = 1,
        [2]  = 0.69999998807907,
        [3]  = 0.10000000149012,
      },
    },
    whiteglow = {
      air                = true,
      class              = [[heatcloud]],
      count              = 1,
      ground             = true,
      water              = true,
      properties = {
        alwaysvisible      = true,
        heat               = 10,
        heatfalloff        = 1.7,
        maxheat            = 15,
        pos                = [[0, 0, 0]],
        size               = 5,
        sizegrowth         = 10,
        speed              = [[0, 0, 0]],
        texture            = [[laserend]],
      },
    },
  },

}

