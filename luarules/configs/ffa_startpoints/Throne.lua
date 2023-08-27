local startPoints = {
  -- outer
  [1] = { x = 1480, z = 2782, },
  [2] = { x = 5331, z = 843, },
  [3] = { x = 10071, z = 2076, },
  [4] = { x = 11354, z = 6600, },
  [5] = { x = 8933, z = 10865, },
  [6] = { x = 4408, z = 11097, },
  [7] = { x = 926, z = 7790, },
  -- middle
  [8] = { x = 2604, z = 4947, },
  [9] = { x = 5566, z = 2220, },
  [10] = { x = 9315, z = 4325, },
  [11] = { x = 8728, z = 8340, },
  [12] = { x = 4513, z = 9034, },
  -- inner
  [13] = { x = 4105, z = 5691, },
  [14] = { x = 6956, z = 3847, },
  [15] = { x = 7138, z = 7357, },
  -- center
  [16] = { x = 6070, z = 5575, },
}

local byAllyTeamCount = {
  -- 3-way => inner
  [3] = {
    { 13, 14, 15, },
  },

  -- 4-way => try to distribute on outer ring, balancing access to ramps
  [4] = {
    { 1, 3, 5, 7, },
    { 1, 3, 5, 6, },
    { 2, 4, 5, 7, },
  },

  -- 5-way => middle
  [5] = {
    { 8, 9, 10, 11, 12, },
  },

  -- 6-way => middle + center
  [6] = {
    { 8, 9, 10, 11, 12, 16, },
  },

  -- 7-way => outer
  [7] = {
    { 1, 2, 3, 4, 5, 6, 7, },
  },

  -- 8-way => outer + center
  [8] = {
    { 1, 2, 3, 4, 5, 6, 7, 16, },
  },

  -- 9-way => 4-way + 5-way but only keep the best configuration for access to ramps
  [9] = {
    { 1, 3, 5, 6, 8, 9, 10, 11, 12, },
  },

  -- 10-way => outer + inner
  [10] = {
    { 1, 2, 3, 4, 5, 6, 7, 13, 14, 15, },
  },

  -- 11-way => outer + middle except north spot, which is the least desirable one
  [11] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, },
  },

  -- 12-way => outer + middle
  [12] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, },
  },

  -- 13-way => outer + middle + center
  [13] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 16, },
  },

  -- 14-way => outer + middle + 2/3 of inner
  [14] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, },
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, },
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, },
  },

  -- 15-way => outer + middle + inner
  [15] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, },
  },

  -- 16-way => all
  [16] = {
    { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
