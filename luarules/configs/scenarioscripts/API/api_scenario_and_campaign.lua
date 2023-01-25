--[[
name:: API for Scripted scenarios and Campaign missions
author:: wilkubyk
date:: 2022.12.17
version:: 1.0

Each section use function that can be called to initialize special features for each mission.
Each function will specify beforehead which table is required for it to work correctly.
If you find any bugs or better way for optimization feel free to do so.
]]--
if gadgetHandler:IsSyncedCode() then
    isSynced = true
else
    isSynced = false
end
local objectiveUnits = {}

--[[ API_GiveOrderToUnit require those tables in designated *.lua files
    for all the features to load properly: 
    objectiveUnits = {} specifiy initial units, position, team, rotation and 
    additional pos for orders. 
]]--
function gadget:API_GiveOrderToUnit()
    for k , unit in pairs(objectiveUnits) do
        if UnitDefNames[unit.name] then
        local unitID = Spring.CreateUnit(unit.name, unit.x, unit.y, unit.z, unit.rot, unit.teamID)

            for i = 1, #unit.queue do
                local order = unit.queue[i]
                order.position = {order.position["px"], order.position["py"], order.position["pz"]}
                Spring.GiveOrderToUnit(unitID, order.cmdID, order.position, CMD.OPT_SHIFT)
            end
        end
    end
end

--[[ API_Triggers require those tables in designated *.lua files
    for all the features to load properly:
    = {}
]]--
function API_Triggers()

end
