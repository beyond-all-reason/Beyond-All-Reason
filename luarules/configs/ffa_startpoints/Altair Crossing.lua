local startPoints = {
  -- corners
  [1] = { x = 455, z = 918, },   -- north west
  [2] = { x = 3629, z = 855, },  -- north east
  [3] = { x = 3644, z = 3187, }, -- south east
  [4] = { x = 465, z = 3088, },  -- south west
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
