local startPoints = {
  -- corners
  [1] = { x = 648, z = 377, },   -- north west
  [2] = { x = 7532, z = 365, },  -- north east
  [3] = { x = 7450, z = 5453, }, -- south east
  [4] = { x = 750, z = 5445, },  -- south west
}

local byAllyTeamCount = {
  -- 4-way => corners
  [4] = {
    { 1, 2, 3, 4, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
