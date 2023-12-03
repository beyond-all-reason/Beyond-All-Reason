local startPoints = {
  -- all around
  [1] = { x = 4342, z = 986, },
  [2] = { x = 6341, z = 1525, },
  [3] = { x = 7785, z = 3346, },
  [4] = { x = 7938, z = 5593, },
  [5] = { x = 6688, z = 7558, },
  [6] = { x = 4671, z = 8030, },
  [7] = { x = 2536, z = 7453, },
  [8] = { x = 1124, z = 6061, },
  [9] = { x = 1163, z = 3913, },
  [10] = { x = 2270, z = 1771, },
}

local byAllyTeamCount = {
  -- 5-way => all around 1 spot apart
  [5] = {
    { 1, 3, 5, 7, 9, },
    { 2, 4, 6, 8, 10, },
  },

  -- 10-way => all around
  [10] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
