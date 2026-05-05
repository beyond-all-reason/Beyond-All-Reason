return {
  ["tractorbeam_weak"] = {

    spawnbeam = {
      air                = true,
      class              = [[CBitmapMuzzleFlame]],
      count              = 1,
      ground             = true,
      underwater         = 1,
      water              = true,
      properties = {
        colormap           = [[0.55 0.3 0.2 0.95   0.4 0.25 0.2 0.7   0.1 0.1 0.15 0.08   0 0 0 0.01]],
        dir                = [[dir]],
        --gravity            = [[0.0, 0.1, 0.0]],
        frontoffset        = 0,
        fronttexture       = [[none]],
        length             = 1,
        sidetexture        = [[gunshotxl2]],
        size               = 30,
        sizegrowth         = 0.7,
        ttl                = 4,
        --rotParams          = [[-120 r240, -40 r80, -180 r360]],
        pos                = [[0, 0, 0]],
      },
    },
  },
}