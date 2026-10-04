local startPoints = {
  -- corners
  [1] = { x = 3031, z = 1663, },  -- north west
  [2] = { x = 11218, z = 1883, }, -- north east
  [3] = { x = 9826, z = 10871, }, -- south east
  [4] = { x = 2976, z = 10024, }, -- south west
  -- edges
  [5] = { x = 9919, z = 6010, },  -- east
  [6] = { x = 1918, z = 5111, },  -- west
  [7] = { x = 6997, z = 1606, },  -- north
  [8] = { x = 5185, z = 11106, }, -- south
  -- replacement corner
  [9] = { x = 2420, z = 8257, },  -- north west
  [10] = { x = 4995, z = 1725, },
  -- missing all around
  [11] = { x = 9122, z = 2209, },
  [12] = { x = 10368, z = 4160, },
  [13] = { x = 10157, z = 8437, },
  [14] = { x = 7552, z = 10562, },
  [15] = { x = 1298, z = 6793, },
  [16] = { x = 2663, z = 3350, },
}

local byAllyTeamCount = {
  -- 3-way => 2 corners + 1 edge center
  [3] = {
    { 1, 4,  5, },
    { 3, 11, 15, },
    { 7, 9,  13, },
  },

  -- 4-way => corners
  [4] = {
    { 1, 2, 3, 4, },
  },

  -- 5-way => all around 2 spots apart ignoring spot 2
  [5] = {
    { 1, 8, 11, 13, 15, },
    { 5, 7, 9,  14, 16, },
  },

  -- 6-way => corners + west/east
  [6] = {
    { 1, 2, 3, 4, 5, 6, },
  },

  -- 7-way => all around 2 or 1 spots apart
  [7] = {
    { 1, 2, 3, 4, 5, 6, 7, },
  },

  -- 8-way => all around 1 spot apart
  [8] = {
    { 1, 2,  3,  5,  6,  7,  8,  9, },
    { 4, 10, 11, 12, 13, 14, 15, 16, },
  },

  -- 9-way => all around with empty spots in corners or edge centers
  [9] = {
    { 6, 8, 9, 10, 11, 12, 13, 14, 16, },
  },

  -- 10-way => all around with empty spots in corners or edge centers
  [10] = {
    { 4, 6, 8, 9, 10, 11, 12, 13, 14, 16, },
  },

  -- 11-way => starting from 13-way, removing the worst spot
  [11] = {
    { 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 16, },
  },

  -- 12-way => starting from 13-way, removing the worst spot
  [12] = {
    { 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, },
  },

  -- 13-way => starting from 14-way, removing the worst spot
  [13] = {
    { 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, },
  },

  -- 14-way => starting from 15-way, removing the worst spot
  [14] = {
    { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, },
  },

  -- 15-way => starting from 16-way, removing the worst spot
  [15] = {
    { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, },
  },


  -- 16-way => all around
  [16] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
