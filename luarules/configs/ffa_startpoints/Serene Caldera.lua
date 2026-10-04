local startPoints = {
  -- outer
  [1] = { x = 2919, z = 2923, },
  [2] = { x = 4660, z = 1488, },
  [3] = { x = 6544, z = 1257, },
  [4] = { x = 8774, z = 1145, },
  [5] = { x = 11054, z = 1746, },
  [6] = { x = 12938, z = 2691, },
  [7] = { x = 13998, z = 4862, },
  [8] = { x = 14494, z = 7098, },
  [9] = { x = 14081, z = 9792, },
  [10] = { x = 12607, z = 12409, },
  [11] = { x = 10984, z = 14069, },
  [12] = { x = 8788, z = 14317, },
  [13] = { x = 6581, z = 14290, },
  [14] = { x = 4028, z = 13899, },
  [15] = { x = 2548, z = 12619, },
  [16] = { x = 1413, z = 10732, },
  [17] = { x = 874, z = 8100, },
  [18] = { x = 1266, z = 5487, },
  -- inner
  [19] = { x = 10012, z = 3338, },
  [20] = { x = 12001, z = 5702, },
  [21] = { x = 12120, z = 8600, },
  [22] = { x = 11713, z = 11093, },
  [23] = { x = 5575, z = 12068, },
  [24] = { x = 3413, z = 9697, },
  [25] = { x = 3352, z = 7013, },
  [26] = { x = 3510, z = 4474, },
}

local byAllyTeamCount = {
  -- 3-way => 1 spot more isolated but farther from metal
  [3] = {
    { 1, 6,  12, },
    { 3, 10, 14, },
  },

  -- 4-way => corners-ish, distributed equally
  [4] = {
    { 1,  5,  10, 14, },
    { 19, 22, 23, 26, },
    { 6,  9,  15, 18, },
  },

  -- 5-way => outer, metal distributed somewhat equally, players closer together get more metal
  [5] = {
    { 1, 5, 8, 11, 15, },
    { 1, 5, 9, 13, 16, },
  },

  -- 6-way => outer all around 2 spots apart
  [6] = {
    { 1, 4, 7, 10, 13, 16, },
  },

  -- 7-way => outer all around 2 spots apart on one side 1 spot apart on the other
  [7] = {
    { 1, 4, 6, 9, 11, 14, 16, },
  },

  -- 8-way =>
  [8] = {
    -- outer, tried to balance north / south spots with more space around due to less metal nearby
    { 1,  4,  6,  8,  10, 13, 15, 17, },
    -- inner
    { 19, 20, 21, 22, 23, 24, 25, 26, },
  },

  -- 9-way => outer all around 1 spot apart
  [9] = {
    { 1, 3, 5, 7, 9,  11, 13, 15, 17, },
    { 2, 4, 6, 8, 10, 12, 14, 16, 18, },
  },

  -- 10-way => tried to balance north / south spots with more space around due to less metal nearby
  [10] = {
    { 3, 12, 19, 20, 21, 22, 23, 24, 25, 26, },
    { 1, 3,  5,  7,  8,  10, 12, 14, 16, 17, },
  },

  -- 11-way => 12-way "2-by-2 and 1 sport apart" but one of the worst spots is removed
  [11] = {
    { 1, 2, 5, 7, 8, 10, 11, 13, 14, 16, 17, },
    { 1, 2, 4, 5, 7, 8,  10, 11, 14, 16, 17, },
    { 1, 2, 4, 5, 7, 8,  10, 13, 14, 16, 17, },
    { 1, 4, 5, 7, 8, 10, 11, 13, 14, 16, 17, },
  },

  -- 12-way =>
  [12] = {
    -- outer all around 2-by-2 and 1 spot apart
    { 1, 2, 4, 5, 7, 8, 10, 11, 13, 14, 16, 17, },
    -- stack 5 on west/east (more metal nearby) then 1 on north/south (less metal nearby but more space)
    { 1, 4, 6, 7, 8, 9, 10, 13, 15, 16, 17, 18, },
  },

  -- 13-way => 12-way but one of the 4 least worst spot (so not north / south) is added
  [13] = {
    { 1, 2, 4, 5, 7, 8, 10, 11, 13, 14, 16, 17, 18, },
    { 1, 2, 4, 5, 7, 8, 10, 11, 13, 14, 15, 16, 17, },
    { 1, 2, 4, 5, 7, 8, 9,  10, 11, 13, 14, 16, 17, },
    { 1, 2, 4, 5, 6, 7, 8,  10, 11, 13, 14, 16, 17, },
  },

  -- 14-way => 16-way but two of the opposite worst spots are removed
  [14] = {
    { 1, 2, 4, 5, 6, 7, 8, 10, 11, 13, 14, 15, 16, 17, },
    { 1, 2, 4, 5, 7, 8, 9, 10, 11, 13, 14, 16, 17, 18, },
  },

  -- 15-way => 16-way but one of the worst spots is removed
  [15] = {
    { 1, 2, 4, 5, 6, 7, 8, 9,  10, 11, 13, 14, 16, 17, 18, },
    { 1, 2, 4, 5, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, },
    { 1, 2, 4, 5, 6, 7, 8, 9,  11, 13, 14, 15, 16, 17, 18, },
    { 1, 2, 4, 5, 6, 7, 8, 9,  10, 11, 13, 14, 15, 16, 17, },
  },

  -- 16-way => all around except worst spots (north / south)
  [16] = {
    { 1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16, 17, 18, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
