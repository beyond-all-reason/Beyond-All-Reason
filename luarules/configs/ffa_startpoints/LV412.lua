local startPoints = {
  -- spiral
  [1] = { x = 3035, z = 1481, }, -- north
  [2] = { x = 7006, z = 3681, }, -- east
  [3] = { x = 4871, z = 7909, }, -- south
  [4] = { x = 940, z = 5323, },  -- west
  -- corners
  [5] = { x = 7880, z = 525, },  -- north west
  [6] = { x = 7738, z = 7822, }, -- north east
  [7] = { x = 498, z = 7654, },  -- south east
  [8] = { x = 552, z = 685, },   -- south west
}

local byAllyTeamCount = {
  -- 4-way =>
  [4] = {
    -- spiral
    { 1, 2, 3, 4, },
    -- corners
    { 5, 6, 7, 8, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
