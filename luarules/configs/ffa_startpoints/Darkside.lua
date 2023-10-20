local startPoints = {
  -- corners
  [1] = { x = 1702, z = 662, },    -- north west
  [2] = { x = 9937, z = 639, },    -- north east
  [3] = { x = 11236, z = 11066, }, -- south east
  [4] = { x = 1884, z = 11923, },  -- south west
  -- craters
  [5] = { x = 6549, z = 8603, },   -- south
  [6] = { x = 5918, z = 3577, },   -- north
  -- edges
  [7] = { x = 10862, z = 6795, },  -- east
  [8] = { x = 931, z = 7557, },    -- west
}

local byAllyTeamCount = {
  -- 4-way => corners
  [4] = {
    { 1, 2, 3, 4, },
  },

  -- 5-way => corners + south crater
  [5] = {
    { 1, 2, 3, 4, 5, },
  },

  -- 6-way => corners + craters
  [6] = {
    { 1, 2, 3, 4, 5, 6, },
  },

  -- 7-way => corners + craters + east edge
  [7] = {
    { 1, 2, 3, 4, 5, 6, 7, },
  },

  -- 8-way => corners + craters + edges
  [8] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
