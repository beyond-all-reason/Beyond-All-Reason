local startPoints = {
  -- corners
  [1] = { x = 1409, z = 2537, },  -- north west
  [2] = { x = 9212, z = 640, },   -- north east
  [3] = { x = 9218, z = 8343, },  -- south east
  [4] = { x = 681, z = 8977, },   -- south west
  -- edges
  [5] = { x = 4735, z = 617, },   -- north
  [6] = { x = 5129, z = 8992, },  -- south
  [7] = { x = 2118, z = 5119, },  -- west
  [8] = { x = 9211, z = 4469, },  -- east
  -- center
  [9] = { x = 5868, z = 6379, },  -- south
  [10] = { x = 5478, z = 3190, }, -- north
}

local byAllyTeamCount = {
  -- 3-way => north / south corner + opposite edge
  [3] = {
    { 1, 6, 8, },
    { 2, 3, 7, },
  },

  -- 4-way =>
  [4] = {
    -- corners
    { 1, 2, 3, 4, },
    -- edges
    { 5, 6, 7, 8, },
    -- west/east edges + center
    { 7, 8, 9, 10, },
  },

  -- 5-way => corners + south center
  [5] = {
    { 1, 2, 3, 4, 9, },
  },

  -- 6-way => corners + north/south edges
  [6] = {
    { 1, 2, 3, 4, 5, 6, },
    { 1, 2, 3, 4, 7, 8, },
  },

  -- 7-way => 8-way minus 1 spot
  [7] = {
    { 1, 2, 3, 4, 5, 6, 7, },
    { 1, 2, 3, 4, 5, 6, 8, },
  },

  -- 8-way => corners + edges
  [8] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, },
  },

  -- 9-way => 10-way minus 1 spot
  [9] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, },
    { 1, 2, 3, 4, 5, 6, 7, 8, 10, },
  },

  -- 10-way => all
  [10] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
