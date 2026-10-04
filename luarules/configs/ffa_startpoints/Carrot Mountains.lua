local startPoints = {
  -- all around
  [1] = { x = 849, z = 1605, },     -- north west
  [2] = { x = 2587, z = 1188, },    -- north west / north
  [3] = { x = 4335, z = 561, },     -- north / north west
  [4] = { x = 6513, z = 771, },     -- north
  [5] = { x = 8059, z = 1441, },    -- north / north east
  [6] = { x = 9581, z = 180, },     -- north east / north
  [7] = { x = 11049, z = 1360, },   -- north east
  [8] = { x = 11200, z = 3437, },   -- east / north east
  [9] = { x = 12047, z = 5550, },   -- east
  [10] = { x = 10717, z = 7226, },  -- east / south east
  [11] = { x = 11917, z = 9090, },  -- south east / east
  [12] = { x = 11999, z = 11883, }, -- south east
  [13] = { x = 10101, z = 11765, }, -- south east / south
  [14] = { x = 7918, z = 11990, },  -- south / south east
  [15] = { x = 5169, z = 11195, },  -- south / south west
  [16] = { x = 2279, z = 12035, },  -- south west / south
  [17] = { x = 432, z = 10737, },   -- south west
  [18] = { x = 1089, z = 8871 },    -- west / west south
  [19] = { x = 237, z = 6313, },    -- west
  [20] = { x = 1378, z = 3808, },   -- west / north west
  -- center
  [21] = { x = 3954, z = 6244, },   -- west
  [22] = { x = 4802, z = 4287, },   -- north west
  [23] = { x = 7332, z = 3528, },   -- north / north east
  [24] = { x = 8534, z = 4935, },   -- north east / east
  [25] = { x = 8815, z = 6806, },   -- east / south east
  [26] = { x = 7235, z = 8345, },   -- south / south east
  [27] = { x = 4877, z = 8113, },   -- south west
}

local byAllyTeamCount = {
  -- 3-way => center
  -- north west quadrant has less metal, so we avoid combinations involving north west start pos
  [3] = {
    { 21, 23, 25, },
    { 21, 23, 26, },
    { 27, 23, 25, },
  },

  -- 4-way => corners
  [4] = {
    { 1, 6, 12, 16, },
    { 1, 6, 12, 17, },
    { 1, 7, 12, 16, },
    { 1, 7, 12, 17, },
  },

  -- 5-way => all around, everyone 3 spots apart
  [5] = {
    { 1, 5, 9,  13, 17, },
    { 2, 6, 10, 14, 18, },
    { 3, 7, 11, 15, 19, },
    { 4, 8, 12, 16, 20, },
  },

  -- 6-way =>
  [6] = {
    -- all around, 2/3 spots apart
    { 4, 7, 10, 14, 17, 20, },
    { 3, 6, 9,  13, 16, 19, },
    -- corners-ish + 2 center
    { 1, 6, 12, 16, 21, 25, },
  },

  -- 7-way =>
  [7] = {
    -- center
    { 21, 22, 23, 24, 25, 26, 27, },
    -- all around, almost everyone 2 spots apart
    { 2,  5,  8,  11, 14, 16, 19, },
  },

  -- 8-way => all around, everyone 2 or 1 spots apart
  -- south / south west spot [15] is 3 mexes and farther from nearest metal, so we avoid combinations with it
  -- north spot [4] is 3 mexes, so pick only combinations with 2 empty spots on both side
  [8] = {
    { 1, 4, 7, 9,  11, 14, 17, 19, },
    { 1, 4, 7, 9,  12, 14, 17, 19, },
    { 1, 4, 7, 10, 12, 14, 17, 19, },
  },

  -- 9-way => all around + some in center
  [9] = {
    { 1, 4, 7, 9,  11, 14, 17, 19, 27, },
    { 2, 5, 8, 11, 14, 17, 19, 22, 26, },
    { 3, 5, 8, 10, 12, 14, 16, 18, 20, },
  },

  -- 10-way => all around, everyone 1 spot apart
  [10] = {
    { 1, 3, 5, 7, 9,  11, 13, 15, 17, 19, },
    { 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, },
  },

  -- 11-way => 8-way + 3-way
  -- center spot east / south east [25] is close to outer spots, so we avoid combinations with it
  [11] = {
    { 1, 4, 7, 9,  11, 14, 17, 19, 21, 23, 26, },
    { 1, 4, 7, 9,  12, 14, 17, 19, 21, 23, 26, },
    { 1, 4, 7, 10, 12, 14, 17, 19, 21, 23, 26, },
  },

  -- 12-way => at this point and up, it starts becoming a big mess but weekday try to minimize unfairness anyway
  [12] = {
    { 1, 3, 6, 8, 11, 13, 15, 17, 19, 21, 23, 25, },
    { 1, 3, 5, 7, 9,  11, 13, 15, 17, 19, 21, 24, },
    { 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 21, 26, },
  },

  -- 13-way =>
  [13] = {
    { 1, 3, 5, 7, 9,  11, 13, 15, 17, 19, 21, 24, 26, },
    { 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 21, 23, 26, },
  },

  -- 14-way =>
  [14] = {
    { 1, 3, 5, 7, 9,  11, 13, 15, 17, 19, 22, 24, 26, 27, },
    { 1, 3, 6, 8, 10, 12, 14, 15, 17, 19, 22, 23, 26, 27, },
  },

  -- 15-way =>
  [15] = {
    { 2, 4, 6, 8, 11, 13, 15, 16, 17, 19, 20, 22, 23, 25, 27, },
    { 2, 4, 6, 8, 11, 13, 15, 16, 17, 19, 20, 21, 22, 23, 25, },
  },

  -- 16-way =>
  [16] = {
    { 2, 4, 6, 8, 11, 13, 14, 16, 17, 19, 20, 21, 22, 23, 25, 27, },
    { 2, 4, 6, 8, 11, 13, 15, 16, 17, 19, 20, 21, 22, 23, 25, 26, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
