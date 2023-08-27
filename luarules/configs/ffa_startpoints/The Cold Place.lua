local startPoints = {
  -- corners
  [1] = { x = 1843, z = 1924, }, -- north west
  [2] = { x = 8421, z = 2015, }, -- north east
  [3] = { x = 5119, z = 7395, }, -- south
  -- staggered
  [4] = { x = 3072, z = 2633, }, -- north west
  [5] = { x = 7530, z = 2741, }, -- north east
  [6] = { x = 5127, z = 6276, }, -- south
  -- geo
  [7] = { x = 5294, z = 937, },  -- south west
  [8] = { x = 8932, z = 5154, }, -- north
  [9] = { x = 1629, z = 5782, }, -- south east
}

local byAllyTeamCount = {
  -- 3-way =>
  [3] = {
    -- corners
    { 1, 2, 3, },
    -- staggered
    { 4, 5, 6, },
    -- geos
    { 7, 8, 9, },
  },

  -- 6-way => staggered + geos
  [6] = {
    { 4, 5, 6, 7, 8, 9, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
