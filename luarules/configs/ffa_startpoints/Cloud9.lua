local startPoints = {
  -- all around
  [1] = { x = 1600, z = 1600, }, -- corner  north west
  [2] = { x = 4651, z = 1660, }, -- edge    north
  [3] = { x = 7602, z = 1696, }, -- corner  north east
  [4] = { x = 7582, z = 4511, }, -- edge    east
  [5] = { x = 7583, z = 7349, }, -- corner  south east
  [6] = { x = 4658, z = 7349, }, -- edge    south
  [7] = { x = 1635, z = 7361, }, -- corner  south west
  [8] = { x = 1633, z = 4526, }, -- edge    west
  -- center
  [9] = { x = 4680, z = 4465, },
}

local byAllyTeamCount = {
  -- 4-way =>
  [4] = {
    -- corners
    { 1, 3, 5, 7, },
    -- edges
    { 2, 4, 6, 8, },
  },

  -- 5-way => corners + center
  [5] = {
    { 1, 3, 5, 7, 9, },
  },

  -- 8-way => all around
  [8] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, },
  },

  -- 9-way => all
  [9] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
