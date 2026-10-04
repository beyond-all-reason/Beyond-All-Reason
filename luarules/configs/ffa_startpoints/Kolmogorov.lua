local startPoints = {
  -- north/south corners
  [1] = { x = 691, z = 5278, },   -- south west  north
  [2] = { x = 5077, z = 762, },   -- north east  north
  [3] = { x = 9545, z = 5151, },  -- north east  south
  [4] = { x = 5090, z = 9587, },  -- south west  south
  -- west/east corners
  [5] = { x = 1371, z = 9068, },  -- south west  west
  [6] = { x = 9264, z = 1182, },  -- north east  east
  [7] = { x = 3877, z = 6548, },  -- south west  east
  [8] = { x = 6459, z = 3731, },  -- north east  west
  [9] = { x = 3886, z = 4006, },  -- center      west
  [10] = { x = 6776, z = 6592, }, -- center      east
}


local byAllyTeamCount = {
  -- 3-way => north or south corners on each quadrant + opposite center
  [3] = {
    { 1, 2, 10, },
    { 3, 4, 9, },
  },

  -- 4-way => north/south corners from both quadrants
  [4] = {
    { 1, 2, 3, 4, },
  },

  -- 5-way => 4-way + one of the corners closer to center in one quadrant
  [5] = {
    { 1, 2, 3, 4, 7, },
    { 1, 2, 3, 4, 8, },
  },

  -- 6-way => 4-way + corners closer to center from both quadrants
  [6] = {
    { 1, 2, 3, 4, 7, 8, },
  },

  -- 7-way => 8-way but one of the corners farther from the center is removed
  [7] = {
    { 1, 2, 3, 4, 5, 7, 8, },
    { 1, 2, 3, 4, 6, 7, 8, },
  },

  -- 8-way => all corners from both quadrants
  [8] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, },
  },

  -- 9-way => 8-way + 1 of the remaining spots
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
