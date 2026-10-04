local startPoints = {
  -- islands
  [1] = { x = 1767, z = 1458, }, -- north west
  [2] = { x = 8056, z = 3209, }, -- north east
  [3] = { x = 3463, z = 7692, }, -- south
  -- corners
  [4] = { x = 4356, z = 1798, }, -- north
  [5] = { x = 6253, z = 5502, }, -- south east
  [6] = { x = 2103, z = 5330, }, -- south west
  -- center
  [7] = { x = 3166, z = 3510, }, -- north west
  [8] = { x = 5675, z = 3706, }, -- north east
  [9] = { x = 4124, z = 5630, }, -- south
}

local byAllyTeamCount = {
  -- 3-way =>
  [3] = {
    -- islands
    { 1, 2, 3, },
    -- corners
    { 4, 5, 6, },
    -- center
    { 7, 8, 9, },
  },

  -- 6-way =>
  [6] = {
    -- islands + corners
    { 1, 2, 3, 4, 5, 6, },
    -- islands + center
    { 1, 2, 3, 7, 8, 9, },
    -- corners + center
    { 4, 5, 6, 7, 8, 9, },
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
