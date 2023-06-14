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

-- Handlers
function widget:Initialize()
    widgetHandler:AddAction("command_skip_current", SkipCurrentCommand)
    widgetHandler:AddAction("command_cancel_last", CancelLastCommand)
end

-- Locals
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetCommandQueueSize = Spring.GetCommandQueue
local spGiveOrderToUnit = Spring.GiveOrderToUnit

-- Main functions
function SkipCurrentCommand()
    ProcessSelectedUnits(function(id)
        RemoveCommand(id, 1)
    end)
end

function CancelLastCommand()
    ProcessSelectedUnits(function(id)
        local commandQueueSize = spGetCommandQueueSize(id, 0)
        if commandQueueSize and commandQueueSize >= 1 then
            RemoveCommand(id, commandQueueSize)
        end            
    end)
end

-- Helper functions
function RemoveCommand(unitID, cmdIndex)
    local cmdID, _, cmdTag = spGetUnitCurrentCommand(unitID, cmdIndex)
    if cmdID then
        spGiveOrderToUnit(unitID, CMD.REMOVE, {cmdTag}, 0)
    end
end

function ProcessSelectedUnits(processCommandFunc)
    local selectedUnits = spGetSelectedUnits()
    for i = 1, #selectedUnits do
        local id = selectedUnits[i]
        processCommandFunc(id)
    end
end