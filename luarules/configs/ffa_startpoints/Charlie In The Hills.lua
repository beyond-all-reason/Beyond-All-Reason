local startPoints = {
  -- corners
  [1] = { x = 2440, z = 1841, }, -- north west
  [2] = { x = 5782, z = 1904, }, -- north east
  [3] = { x = 5738, z = 6358, }, -- south east
  [4] = { x = 2421, z = 6320, }, -- south west
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
