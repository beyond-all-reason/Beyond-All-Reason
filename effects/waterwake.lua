-- waterwake

return {
  ["waterwake"] = {
    wake = {
      air                = true,
      class              = [[CWakeProjectile]],
      count              = 1,
      ground             = true,
      underwater         = true,
      water              = true,
      properties = {
        startsize            = 10,
        sizeexpansion        = 10,
        alpha                = 0.9,
        alphafalloff         = 0.5,
        fadeuptime           = 2,
      },
    },
  },
}

