local startPoints = {
  -- corners
  [1] = { x = 393, z = 416, },   -- north west
  [2] = { x = 8853, z = 456, },  -- north east
  [3] = { x = 8836, z = 5653, }, -- south east
  [4] = { x = 379, z = 5622, },  -- south west
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
