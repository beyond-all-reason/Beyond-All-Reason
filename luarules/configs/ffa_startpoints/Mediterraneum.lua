local startPoints = {
  [1] = { x = 5416, z = 8996, },    -- Beljam
  [2] = { x = 13934, z = 9242, },   -- Youkraine
  [3] = { x = 4492, z = 15723, },   -- Moreocho
  [4] = { x = 10808, z = 3287, },   -- Fineland
  [5] = { x = 3204, z = 2699, },    -- Eyesland
  [6] = { x = 10940, z = 11602, },  -- Balkans
  [7] = { x = 15367, z = 15690, },  -- Izreal
  [8] = { x = 881, z = 10237, },    -- Biscay Bay
  [9] = { x = 4761, z = 6130, },    -- North Sea
  [10] = { x = 14814, z = 4168, },  -- Rusha
  [11] = { x = 9609, z = 7273, },   -- Poleland
  [12] = { x = 7845, z = 2298, },   -- Norway
  [13] = { x = 1623, z = 13247, },  -- Spain
  [14] = { x = 5854, z = 12867, },  -- Sardines
  [15] = { x = 9832, z = 15982, },  -- Libiya
  [16] = { x = 15711, z = 571, },   -- Barents Sea
  [17] = { x = 11938, z = 6606, },  -- Belarush
  [18] = { x = 14558, z = 11520, }, -- Black Sea
  [19] = { x = 8092, z = 5251, },   -- Swededen
  [20] = { x = 3299, z = 7014, },   -- Britin
  [21] = { x = 8933, z = 14490, },  -- Mediterranean Sea
  [22] = { x = 9796, z = 9707, },   -- Hungry
  [23] = { x = 1289, z = 1085, },   -- Greenland
  [24] = { x = 6842, z = 11024, },  -- Eataly
  [25] = { x = 13385, z = 13033, }, -- Turky
  [26] = { x = 15872, z = 6990, },  -- Khazakstan
  [27] = { x = 4291, z = 10790, },  -- Franche
  [28] = { x = 5862, z = 784, },    -- Norwegian Sea
  [29] = { x = 7356, z = 8131, },   -- Germoney
  [30] = { x = 995, z = 7099, },    -- Ireland
  [31] = { x = 616, z = 3778, },    -- Faroe Sea
  [32] = { x = 14101, z = 1559, },  -- Murmansk
}

--[[
Mediterraneum is a pain due to having 32 spots: the number of 16-combination
clocks in at 600 million. In order to make layouts for this map, we resorted to
graph theory by defining a graph where each start point is a node and neighbour
status is materialized by an edge, with the intent of bruteforcing all maximal
independent sets in the graph (i.e. sets of start positions such that no 2
start positions are adjacent, which are basically layouts we can use as-is) and
identifying cliques (i.e. sets of start positions which are all adjacent to each
other, which can be used to make variations on each existing layouts or create
new ones).

In order to simplify the search space, we elected to completely axe the 7 water
spots and spot 14 (Sardinia) from the graph. This was decided after discussing
with ~15 "Mediterraneum regulars", with almost unanimous feedback being that
starting in the water does not feel good on the map, even if not necessarily bad
(basically due to the sluggish but safer start, the early to mid game dynamics
do not feel great and result in either a lone water starter taking over the map
or multiple water starters not being able to achieve anything, with little in
between), and that spot 14 is not fun to play due to almost no space to make a
base and being vulnerable from all angles.

This left us with a batch of maximal independent sets ranging from 8 to 12
nodes, which were used for seeding layouts from 8-way to 12-way. From there,
layouts down to 3-way were derived by progressively removing and reshuffling
start points downwards from 8-way, while layouts for 13-way and up were derived
by starting from all 24 land spots (except spot 14) and removing the worst
spots, using 12-way layouts and cliques in the graph as reference.
]]
local byAllyTeamCount = {
  -- 3-way =>
  [3] = {
    { 2,  3,  19, },
    { 6,  10, 20, },
    { 12, 13, 25, },
    { 1,  6,  11, },
  },

  -- 4-way =>
  [4] = {
    { 5,  10, 13, 25, },
    { 13, 17, 20, 25, },
    { 1,  2,  3,  4, },
    { 3,  4,  20, 25, },
  },

  -- 5-way =>
  [5] = {
    { 1,  2,  3,  4,  5, },
    { 3,  12, 20, 25, 26, },
    { 2,  15, 19, 27, 32, },
    { 10, 12, 13, 25, 29, },
  },

  -- 6-way =>
  [6] = {
    { 10, 12, 13, 15, 20, 22, },
    { 2,  13, 15, 19, 20, 32, },
    { 1,  2,  3,  4,  5,  7, },
    { 1,  3,  4,  5,  25, 26, },
  },

  -- 7-way =>
  [7] = {
    { 3, 5,  10, 11, 12, 25, 27, },
    { 1, 4,  5,  6,  13, 15, 26, },
    { 1, 2,  3,  7,  12, 23, 32, },
    { 6, 10, 11, 12, 13, 15, 20, },
  },

  -- 8-way =>
  [8] = {
    { 6,  10, 11, 12, 13, 15, 20, 23, },
    { 15, 17, 19, 22, 23, 27, 30, 32, },
    { 3,  7,  10, 12, 20, 22, 23, 27, },
    { 2,  3,  5,  10, 11, 12, 25, 27, },
  },

  -- 9-way =>
  [9] = {
    { 2,  3,  7,  10, 11, 12, 20, 23, 27, },
    { 6,  12, 13, 15, 23, 26, 29, 30, 32, },
    { 6,  10, 11, 12, 13, 15, 20, 23, 24, },
    { 12, 13, 15, 17, 20, 23, 24, 25, 32, },
    { 3,  17, 19, 22, 23, 25, 27, 30, 32, },
  },

  -- 10-way =>
  [10] = {
    { 1,  6,  7,  11, 12, 13, 23, 26, 30, 32, },
    { 11, 13, 15, 19, 20, 23, 24, 25, 26, 32, },
    { 2,  10, 11, 12, 13, 15, 20, 23, 24, 25, },
    { 3,  6,  7,  12, 17, 23, 27, 29, 30, 32, },
    { 1,  4,  10, 11, 13, 15, 19, 23, 25, 30, },
    { 3,  6,  7,  11, 12, 20, 23, 26, 27, 32, },
  },

  -- 11-way =>
  [11] = {
    { 1, 3,  6,  7,  11, 19, 23, 24, 26, 30, 32, },
    { 1, 11, 13, 15, 19, 23, 24, 25, 26, 30, 32, },
    { 1, 2,  11, 13, 15, 19, 23, 24, 25, 30, 32, },
    { 2, 4,  10, 11, 13, 15, 19, 20, 23, 24, 25, },
    { 1, 2,  4,  10, 11, 13, 15, 19, 23, 25, 30, },
    { 1, 2,  3,  4,  5,  10, 11, 19, 24, 25, 30, },
  },

  -- 12-way =>
  [12] = {
    { 1, 2, 4, 5,  6,  10, 11, 13, 15, 19, 24, 30, },
    { 1, 2, 3, 4,  5,  6,  7,  10, 11, 19, 24, 30, },
    { 1, 2, 4, 10, 11, 13, 15, 19, 23, 24, 25, 30, },
  },

  -- 13-way =>
  [13] = {
    { 2, 3, 4,  6,  7,  17, 19, 23, 26, 27, 29, 30, 32, },
    { 1, 4, 11, 13, 15, 19, 22, 23, 24, 25, 26, 30, 32, },
    { 2, 3, 4,  6,  7,  17, 19, 23, 24, 26, 27, 29, 30, },
    { 1, 2, 3,  4,  6,  7,  10, 11, 13, 19, 23, 24, 30, },
  },

  -- 14-way =>
  [14] = {
    { 2, 3, 4,  6,  7,  17, 19, 23, 24, 26, 27, 29, 30, 32, },
    { 2, 4, 13, 15, 17, 19, 22, 23, 25, 26, 27, 29, 30, 32, },
    { 1, 2, 3,  4,  6,  7,  11, 13, 19, 23, 24, 26, 30, 32, },
  },

  -- 15-way =>
  [15] = {
    { 2, 3, 4,  6,  7,  12, 17, 19, 23, 24, 26, 27, 29, 30, 32, },
    { 2, 3, 4,  6,  7,  13, 17, 19, 23, 24, 26, 27, 29, 30, 32, },
    { 2, 4, 13, 15, 17, 19, 22, 23, 24, 25, 26, 27, 29, 30, 32, },
  },

  -- 16-way =>
  [16] = {
    { 1, 2, 3, 4, 7,  10, 11, 12, 13, 19, 22, 23, 24, 25, 26, 30, },
    { 2, 3, 4, 7, 12, 17, 19, 22, 23, 24, 25, 26, 27, 29, 30, 32, },
  },
}

return {
  startPoints = startPoints,
  byAllyTeamCount = byAllyTeamCount
}
