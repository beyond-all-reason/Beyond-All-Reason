local startPoints = {
  -- corners
  [1] = { x = 3396, z = 957, },
  [2] = { x = 10748, z = 4145, },
  [3] = { x = 8898, z = 11365, },
  [4] = { x = 1539, z = 8123, },
  -- center
  [5] = { x = 5850, z = 2609, }, -- inner
  [6] = { x = 9162, z = 7335, }, -- outer
  [7] = { x = 6433, z = 9680, }, -- inner
  [8] = { x = 3140, z = 4969, }, -- outer
}

local byAllyTeamCount = {
  -- 4-way =>
  [4] = {
    -- corners
    { 1, 2, 3, 4, },
    -- center
    { 5, 6, 7, 8, },
  },

  -- 6-way => corners + outer, leaving inner to be fought over
  [6] = {
    { 1, 2, 3, 4, 5, 7, },
  },

  -- 8-way => all
  [8] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
