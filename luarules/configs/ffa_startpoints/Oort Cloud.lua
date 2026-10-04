local startPoints = {
  -- all around
  [1] = { x = 1625, z = 1671, },   -- corner  north west
  [2] = { x = 4657, z = 1689, },   -- edge    north west
  [3] = { x = 7581, z = 1684, },   -- edge    north east
  [4] = { x = 10585, z = 1699, },  -- corner  north east
  [5] = { x = 10556, z = 4512, },  -- edge    east north
  [6] = { x = 10563, z = 7347, },  -- edge    east south
  [7] = { x = 10563, z = 10285, }, -- corner  south east
  [8] = { x = 7587, z = 10280, },  -- edge    south east
  [9] = { x = 4653, z = 10283, },  -- edge    south west
  [10] = { x = 1637, z = 10274, }, -- corner  south west
  [11] = { x = 1630, z = 7348, },  -- edge    east south
  [12] = { x = 1630, z = 4531, },  -- edge    west north
  -- center
  [13] = { x = 4662, z = 4473, },  -- center  north west
  [14] = { x = 7606, z = 4451, },  -- center  north east
  [15] = { x = 7592, z = 7396, },  -- center  south east
  [16] = { x = 4665, z = 7406, },  -- center  south west
}

local byAllyTeamCount = {
  -- 3-way => all around 3 spots apart
  [3] = {
    { 1, 5, 9, },
    { 2, 6, 10, },
    { 3, 7, 11, },
    { 4, 8, 12, },
  },

  -- 4-way =>
  [4] = {
    -- all around 2 spots apart
    { 1,  4,  7,  10, },
    { 2,  5,  8,  11, },
    { 3,  6,  9,  12, },
    -- center
    { 13, 14, 15, 16, },
  },

  -- 6-way => all around 1 spot apart
  [6] = {
    { 1, 3, 5, 7, 9,  11, },
    { 2, 4, 6, 8, 10, 12, },
  },

  -- 8-way =>
  [8] = {
    -- edges
    { 2, 3, 5, 6,  8,  9,  11, 12, },
    -- corners + center
    { 1, 4, 7, 10, 13, 14, 15, 16, },
    -- check pattern
    { 1, 3, 5, 7,  9,  11, 13, 15, },
    { 2, 4, 6, 8,  10, 12, 14, 16, },
  },

  -- 12-way =>
  [12] = {
    -- all around
    { 1, 2, 3, 4, 5, 6, 7,  8,  9,  10, 11, 12, },
    -- edges + center
    { 2, 3, 5, 6, 8, 9, 11, 12, 13, 14, 15, 16, },
  },

  -- 16-way => all
  [16] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
