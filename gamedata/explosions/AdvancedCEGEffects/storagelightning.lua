-- storagelightning

return {
  ["storagelightning"] = {
    bitmapmuzzleflame = {
      air                = true,
      class              = [[CBitmapMuzzleFlame]],
      count              = 1,
      ground             = true,
      underwater         = 1,
      water              = true,
      properties = {
        colormap           = [[0.7 0.8 0.9 0.01   0.2 0.5 0.9 0.01   0 0 0 0.01]],
        dir                = [[0, 0, 1]],
        frontoffset        = 0.05,
        fronttexture       = [[empty]],
        length             = 70,
        sidetexture        = [[shot]],
        size               = 20,
        sizegrowth         = 2,
        ttl                = 2,
      },
    },
  },

}

