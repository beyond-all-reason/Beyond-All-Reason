function widget:GetInfo()
    return {
        name = "Command Queue Manager",
        desc = "Skips current command or cancels the last command in command",
        author = "[DE]LSR",
        date = "5 Apr, 2022",
        license = "GNU GPL, v2 or later",
        layer = 1, --  after the normal widgets
        enabled = true --  loaded by default?
    }
end

function widget:Initialize()
    widgetHandler:AddAction("command_skip_current", SkipCurrentCommand)
    widgetHandler:AddAction("command_cancel_last", CancelLastCommand)
end

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetCommandQueue = Spring.GetCommandQueue
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local maxQueueSizeToCheck = 35 -- prevent hax, ram usage

function ProcessSelectedUnits(processCommandFunc)
    local selectedUnits = spGetSelectedUnits()
    for i = 1, #selectedUnits do
        local id = selectedUnits[i]
        processCommandFunc(id)
    end
end

function SkipCurrentCommand()
    ProcessSelectedUnits(function(id)
        local cmdID, _, cmdTag = spGetUnitCurrentCommand(id)
        if cmdID then
            spGiveOrderToUnit(id, CMD.REMOVE, {cmdTag}, 0)
        end
    end)
end

function CancelLastCommand()
    ProcessSelectedUnits(function(id)
        local commandsQueue = spGetCommandQueue(id, maxQueueSizeToCheck)
        if commandsQueue ~= nil and #commandsQueue >= 1 then
            local lastCommand = commandsQueue[#commandsQueue]
            spGiveOrderToUnit(id, CMD.REMOVE, {lastCommand.tag}, 0)
        end            
    end)
end
