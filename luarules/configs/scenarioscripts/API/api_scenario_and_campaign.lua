--[[
name:: API for Scripted scenarios and Campaign missions
author:: wilkubyk
date:: 2022.12.17
version:: 1.0

Each section use function that can be called to initialize special features for each mission.
Each function will specify beforehead which table is required for it to work correctly.
If you find any bugs or better way for optimization feel free to do so.
]]--

--[[ API_GiveOrderToUnit require those tables in designated *.lua files
    for all the features to load properly: 
    objectiveUnits = {} specifiy initial units, position, team, rotation and 
    additional pos for orders. 
]]--
function API_GiveOrderToUnit()

end

--[[ API_Triggers require those tables in designated *.lua files
    for all the features to load properly:
    = {}
]]--
function API_Triggers()

end
