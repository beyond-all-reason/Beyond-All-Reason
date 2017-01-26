-- general ffa_startpoints.lua
-- finds the appropriate ffa startpoints file and calls it

local fileNames = {
    --Dworld
    ["Dworld_V1"]       = "Dworld",
    ["Dworld Acidic"]   = "Dworld",

    --Throne
    ["Throne v1"] = "Throne",
    ["Throne v2"] = "Throne",
    ["Throne v3"] = "Throne",
    ["Throne v4"] = "Throne",
    ["Throne v5"] = "Throne",
    
    --Blindside
    ["Blindside_v2"] = "Blindside",
    
    --Mearth
    ["Mearth_v4"] = "Mearth",
}

local thisMap = Game.mapName

if fileNames[thisMap] then
    local fileName = "luarules/configs/ffa_startpoints/"..fileNames[thisMap]..".lua"
    if VFS.FileExists(fileName) then
        -- this file should create the ffaStartPoints table (which is then accessible to initial_spawn)
        -- format is ffaStartPoints[#allyTeamIDs][startPointNum] = {x,z}
        include(fileName)
        -- initial_spawn will take care of where to place teamIDs about the allyTeamID start point
        -- initial_spawn will count how many allyTeamIDs are going spawn units 
        -- and will randomly assign each allyTeamID to one of the startpoints in ffaStartPoints
    else
        -- debug
        --Spring.Echo("Could not find " .. fileName) 
    end
end