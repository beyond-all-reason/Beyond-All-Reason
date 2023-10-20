local startPoints = {
  -- corners
  [1] = { x = 920, z = 1008, },   -- north west
  [2] = { x = 7336, z = 1006, },  -- north east
  [3] = { x = 7324, z = 7225, },  -- south east
  [4] = { x = 858, z = 7183, },   -- south west
  -- left / right
  [5] = { x = 642, z = 2350, },   -- north west
  [6] = { x = 2326, z = 683, },   -- north west
  [7] = { x = 5830, z = 668, },   -- north east
  [8] = { x = 7496, z = 2416, },  -- north east
  [9] = { x = 7639, z = 5774, },  -- south east
  [10] = { x = 5840, z = 7538, }, -- south east
  [11] = { x = 2470, z = 7427, }, -- south west
  [12] = { x = 627, z = 5758, },  -- south west
  -- middle
  [13] = { x = 1926, z = 2022, }, -- north west
  [14] = { x = 6270, z = 1931, }, -- north east
  [15] = { x = 6290, z = 6101, }, -- south east
  [16] = { x = 1918, z = 6103, }, -- south west
}

local byAllyTeamCount = {
  -- 4-way =>
  [4] = {
    -- corners
    { 1,  2,  3,  4, },
    -- center
    { 13, 14, 15, 16, },
  },

  -- 8-way => left / right
  [8] = {
    { 5, 6, 7, 8, 9, 10, 11, 12, },
  },

  -- 12-way => left / right + middle
  [12] = {
    { 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
