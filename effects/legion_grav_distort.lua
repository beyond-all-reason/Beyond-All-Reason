return {
  ["legion_grav_distort"] = {

    -- horizontal gravitational shockwave ring (looks upward facing)
    ring = {
      air = true, ground = true, water = true, underwater = 1,
      class = [[CBitmapMuzzleFlame]], count = 1,
      properties = {
        colormap     = [[0.1 1 0.3 0.85   0.05 0.6 0.15 0.45   0 0 0 0.01]],
        dir          = [[dir]],
        frontoffset  = 0,
        fronttexture = [[explosionwave]],
        sidetexture  = [[explosionwave]],
        length       = 0.2,
        size         = 5,
        sizegrowth   = 5,
        ttl          = 4,
        pos          = [[0, 0, 0]],
      },
    },

    -- brief bright pulse when lift engages
    pulse = {
      air = true, ground = true, water = true, underwater = 1,
      class = [[CHeatCloudProjectile]], count = 0,
      properties = {
        heat    = 3,
        maxheat = 5,
        pos     = [[0, 0, 0]],
        size    = 16,
        speed   = 0.025,
        texture = [[flare]],
      },
    },
  },
}