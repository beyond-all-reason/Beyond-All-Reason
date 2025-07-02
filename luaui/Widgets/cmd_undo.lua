local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Undo",
		desc = "Lets you undo actions.",
		author = "hihoman23",
		date = "Jun 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

local prevSelection = {}   -- current selection except for start of widget:SelectionChanged
local justSelected = false -- should we ignore the next selection change?
local gridCommandCount = 0 -- number of commands in a grid when building grids

local customActionTypes = {}

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spSelectUnitArray = Spring.SelectUnitArray
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitCommands = Spring.GetUnitCommands

local CMD_STOP = CMD.STOP

----- history structure
local History = {}
function History.removeLastAction(history)
    if history.length == 0 or not history.endAction then
        Spring.Echo("History is empty, cannot undo last command.")
        return
    end

    local historyEnd = history.endAction
    history.endAction = historyEnd.prev
    if not history.endAction then
        history.startAction = nil
    end
    history.redoAction = historyEnd

    history.length = history.length - 1
    return historyEnd.data
end

function History.addAction(history, data)
    local newAction = {
        data = data,
        prev = history.endAction
    }

    if history.length == 0 then
        history.startAction = newAction
    else
        history.endAction.next = newAction
    end

    history.endAction = newAction
    history.redoAction = nil
    history.length = history.length + 1

    if history.length > 100 then
        history.startAction = history.startAction.next
        history.length = history.length - 1
    end
end

function History.redoAction(history)
    if not history.redoAction then
        Spring.Echo("No command to redo.")
        return
    end

    local actionToRedo = history.redoAction
    history.redoAction = actionToRedo.next
    history.endAction = actionToRedo

    history.length = history.length + 1
    return actionToRedo.data
end

function History.currentAction(history)
    if history.length == 0 or not history.endAction then
        return nil
    end
    return history.endAction.data
end

function History.newHistory()
    return {length = 0}
end

local actionHistory = History.newHistory()

----- populate history with commands
function widget:CommandNotify(...)
    if gridCommandCount == 0 then
        local prevCommandQueue = {}

        for _, unitID in ipairs(spGetSelectedUnits()) do
            local cmdQueue = {}
            for _, command in ipairs(spGetUnitCommands(unitID, -1) or {}) do
                cmdQueue[#cmdQueue + 1] = {command.id, command.params, command.options}
            end
            prevCommandQueue[unitID] = cmdQueue
        end

        local data = {
            type = "command",
            newCommand = {...},
            prevCommandQueue = prevCommandQueue,
        }

        History.addAction(actionHistory, data)
    elseif gridCommandCount == 1 then
        local prevCommand = History.currentAction(actionHistory)
        if prevCommand then
            prevCommand.type = "commandqueue"
            prevCommand.newCommands = {prevCommand.newCommand, {...}}
            prevCommand.newCommand = nil
        end
    else
        local prevCommand = History.currentAction(actionHistory)
        if prevCommand then
            prevCommand.newCommands[gridCommandCount + 1] = {...}
        end
    end

    gridCommandCount = gridCommandCount + 1
end

function widget:SelectionChanged(newSelection)
    if justSelected then
        prevSelection = newSelection
        justSelected = false
        return
    end

    local data = {
        type = "selection",
        prevSelection = table.copy(prevSelection),
        newSelection = table.copy(newSelection),
    }

    History.addAction(actionHistory, data)
    prevSelection = newSelection
end

----- undo/redo logic
local function undo()
    local data = History.removeLastAction(actionHistory)
    if not data then
        return
    end

    if data.type == "command" or data.type == "commandqueue" then
        for unitID, cmdQueue in pairs(data.prevCommandQueue) do
            spGiveOrderToUnit(unitID, CMD_STOP, {}, 0)
            spGiveOrderArrayToUnit(unitID, cmdQueue)
        end
    elseif data.type == "selection" then
        justSelected = true
        spSelectUnitArray(data.prevSelection)
    end
end

local function redo()
    local data = History.redoAction(actionHistory)
    if not data then
        return
    end
    if data.type == "command" then
        spGiveOrderToUnitArray(spGetSelectedUnits(), data.newCommand[1], data.newCommand[2], data.newCommand[3])
    elseif data.type == "commandqueue" then
        for _, cmd in ipairs(data.newCommands) do
            spGiveOrderToUnitArray(spGetSelectedUnits(), cmd[1], cmd[2], cmd[3])
        end
    elseif data.type == "selection" then
        justSelected = true
        spSelectUnitArray(data.newSelection)
    elseif customActionTypes[data.type] then
        customActionTypes[data.type].redo(data)
    end
end

function widget:UnitCommand() -- reset batchCommandCount when command batch gets through
    gridCommandCount = 0
end

function widget:Initialize()
    widgetHandler:AddAction("undo", undo, nil, "p")
    widgetHandler:AddAction("redo", redo, nil, "p")


    WG.Undo = {}
    WG.Undo.addActionType = function(actionType, undoFunc, redoFunc)
        customActionTypes[actionType] = {
            undo = undoFunc,
            redo = redoFunc,
        }
    end
    WG.Undo.removeActionType = function(actionType)
        customActionTypes[actionType] = nil
    end
    WG.Undo.customAction = function(data)
        History.addAction(actionHistory, data)
    end
end

function widget:Shutdown()
    WG.Undo = nil
end
