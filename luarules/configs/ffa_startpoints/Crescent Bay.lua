local startPoints = {
  -- corners
  [1] = { x = 1349, z = 3119, },   -- north
  [2] = { x = 9153, z = 1358, },   -- east
  [3] = { x = 11016, z = 9194, },  -- south
  [4] = { x = 3126, z = 10941, },  -- west
  -- center
  [5] = { x = 5459, z = 1256, },   -- north
  [6] = { x = 11041, z = 5459, },  -- east
  [7] = { x = 6831, z = 11020, },  -- south
  [8] = { x = 1254, z = 6828, },   -- west
  -- staggered
  [9] = { x = 3304, z = 1731, },   -- north
  [10] = { x = 10558, z = 3311, }, -- east
  [11] = { x = 8986, z = 10546, }, -- south
  [12] = { x = 1741, z = 8988, },  -- west
  -- close to the middle
  [13] = { x = 7236, z = 3200, },  -- north
  [14] = { x = 9092, z = 7239, },  -- east
  [15] = { x = 5056, z = 9094, },  -- south
  [16] = { x = 3179, z = 5047, },  -- west
}

local byAllyTeamCount = {
  -- 4-way => 1 on each island
  [4] = {
    { 1,  2,  3,  4, },
    { 5,  6,  7,  8, },
    { 9,  10, 11, 12, },
    { 13, 14, 15, 16, },
  },

  -- 8-way => 2 on each island, but only corners + center
  -- we don't use the other configuration (staggered + close to the middle)
  -- because in that configuration there's a strong advantage for the staggered
  -- spots vs. those close to the middle
  [8] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, },
  },

  -- 16-way => 4 on each island
  [16] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
