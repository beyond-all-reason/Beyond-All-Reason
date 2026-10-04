local startPoints = {
  -- corners
  [1] = { x = 1780, z = 683, },   -- north west
  [2] = { x = 6719, z = 773, },   -- north east
  [3] = { x = 6382, z = 7533, },  -- south east
  [4] = { x = 1467, z = 7437, },  -- south west
  -- staggered
  [5] = { x = 457, z = 1565, },   -- north west west
  [6] = { x = 3022, z = 472, },   -- north west east
  [7] = { x = 5693, z = 420, },   -- north east
  [8] = { x = 7841, z = 3304, },  -- east
  [9] = { x = 7746, z = 6606, },  -- south east east
  [10] = { x = 5168, z = 7695, }, -- south east west
  [11] = { x = 2490, z = 7830, }, -- south west
  [12] = { x = 322, z = 4877, },  -- west
}

local byAllyTeamCount = {
  -- 4-way => corners
  [4] = {
    { 1, 2, 3, 4, },
  },

  -- 8-way => staggered
  [8] = {
    { 5, 6, 7, 8, 9, 10, 11, 12, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
