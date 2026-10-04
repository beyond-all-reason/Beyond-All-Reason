local startPoints = {
  -- corners
  [1] = { x = 1016, z = 1582, }, -- north west
  [2] = { x = 7068, z = 1969, }, -- north east
  [3] = { x = 7177, z = 6603, }, -- south east
  [4] = { x = 1128, z = 6201, }, -- south west
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
