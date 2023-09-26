--[[
Note: this file is meant for Tundra V2, so normally we would have named this
config `Tundra`, but since another map named Tundra Continents exists, we had to
resort to using `Tundra V`.
]]
local startPoints = {
  -- corners
  [1] = { x = 1641, z = 711, },  -- north west
  [2] = { x = 7056, z = 809, },  -- north east
  [3] = { x = 6536, z = 7465, }, -- south east
  [4] = { x = 1137, z = 7383, }, -- south west
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
