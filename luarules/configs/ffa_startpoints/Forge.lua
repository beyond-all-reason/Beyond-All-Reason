local startPoints = {
  -- outer
  [1] = { x = 2119, z = 1529, }, -- north west
  [2] = { x = 7091, z = 1539, }, -- north east
  [3] = { x = 7121, z = 7662, }, -- south east
  [4] = { x = 2115, z = 7636, }, -- south west
  -- inner
  [5] = { x = 3118, z = 2684, }, -- north west
  [6] = { x = 6084, z = 2679, }, -- north east
  [7] = { x = 5903, z = 6549, }, -- south east
  [8] = { x = 3308, z = 6577, }, -- south west
}

local byAllyTeamCount = {
  -- 4-way => 1 per quadrant, make sure everybody has equal access to op geos
  [4] = {
    { 1, 2, 3, 4, },
    { 5, 6, 7, 8, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
