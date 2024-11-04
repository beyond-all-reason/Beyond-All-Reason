local WIDGET_NAME = "Construction Turrets Range Check"
local WIDGET_VERSION = "1.5"
--[[
### VERSIONS ###
1.0 - initial release, basic
1.1 - added more command types (reclaim, attack)
1.2 - added support for queued commands to be flag_processed
1.3 - fixed a range deviation caused by the game adding model radius
1.4a - optimization, added LRU cache to reduce the number of calls to the engine
1.4b - optimization, changed the flag_listening method to await a command instead of polling x'th frame
1.4c - optimization, added a command limit to prevent the engine from ignoring commands
1.4d - optimization, replaced loop with GiveOrderToUnitArray, renaiming and adding comments
1.4e - changed distance calculation from 3D to 2D
1.4f - removed a Spring.Echo() that was left from debugging.
1.4g - refactored the code, added more comments, better readability.
1.5 - fixed edge case that allows to skip the script the execution of the script by switching selection.
1.5b - main branch integration. Removal of hello Echo.
]]--

function widget:GetInfo()
    return {
        name = WIDGET_NAME,
        desc = "Stops construction turrets from being assigned to constructions out of reach.",
        author = "Nehroz",
        date = "2024.11.01", -- update date.
        license = "GPL v3",
        layer = 0,
        version = WIDGET_VERSION
    }
end

-- SECTION OOP
-- SECTION LRU Cache class
LRUCache = {}
LRUCache.__index = LRUCache

-- Constructor
function LRUCache:new(max_size)
    assert(type(max_size) == "number")
    local cache = {
        max_size = max_size or 10, -- Default max size to 10 if not specified
        cache = {},                -- Key-Value store (uID -> value = radius)
        order = {}                 -- To track the order of use (most recent at the end)
    }
    setmetatable(cache, LRUCache)
    return cache
end

-- Get a value by uID
function LRUCache:get(uID)
    local value = self.cache[uID]
    if value then
        -- Move the accessed uID to the end to mark it as most recently used
        self:moveToEnd(uID)
        return value
    else
        return nil -- uID not found
    end
end

-- Put a uID and value into the cache
function LRUCache:put(uID, value)
    if self.cache[uID] then
        -- If uID already exists, just update and mark it as recently used (should never be the case)
        self.cache[uID] = value
        self:moveToEnd(uID)
    else
        -- Add new uID-value pair
        if #self.order >= self.max_size then
            -- Cache is full, remove the least recently used item
            local lru = table.remove(self.order, 1)
            self.cache[lru] = nil
        end
        table.insert(self.order, uID)
        self.cache[uID] = value
    end
end

-- Helper function to move uID to the end of the order list
function LRUCache:moveToEnd(uID)
    for i, id in ipairs(self.order) do
        if id == uID then
            table.remove(self.order, i)
            break
        end
    end
    table.insert(self.order, uID)
end
-- !SECTION LRU Cache
-- !SECTION OOP

-- SECTION Settings and other variables
-- constants
-- DELAY is the number of frames between a given command and getting flag_processed;
-- Should be bigger than`COMMAND_LIMIT/expected number of nanos`. Default is 15.
-- NOTE: There is no "overflow" protection. Setting DELAY to low will cause stacks to fill up constantly.
local DELAY = 15
-- names of nano turrets names -- TODO Needs Legion nano's too
local TURRETS = {"armnanotc", "cornanotc", "armnanotct2", "cornanotct2"}
-- Maximum number of commands to be flag_processed in a single frame; Game sim blocking if too many commands per frame.
-- Default is 20. But modern hardware could handle more. 20 is sufficient for any game case.
local COMMAND_LIMIT = 20
-- variables
local is_play = false
local counter = 0
local flag_listening = false
local flag_processed = true
local current_towers = {}
local command_budget = 0
local to_be_cleared = {} -- stack of uIDs to be cleared
local new_orders = {} -- stack of {uid = {cmdArr},...} to be flag_processed
local radius_cache = LRUCache:new(10) -- LRU cache to reduce the number of calls for model radius
-- !SECTION Settings and other variables

-- SECTION Helper functions
-- converts a table to a Set()-like
local function tableToSet(t) -- coverts a table to a Set()-like
    for _, key in ipairs(t) do t[key] = true end
end

-- Returns a float from 2 coordinates
-- NOTE equal to Spring.GetUnitSeparation(u1, u2, false, false) Uses 3D distance not 2D
-- This is faster then synch reading from the engine; jumping.
-- 1.4e changed to use 2D distance x and z instead of 3D, as it seems that nanos work in 2D cylinders.
local function calculateDistance2D(x1, y1, x2, y2)
    return math.sqrt((x1 - x2)^2 + (y1 - y2)^2)
end

-- LRU caching of model radius, so we don't have to get it every time
local function getUnitRadius(uID)
    local radius = radius_cache:get(uID)
    if not radius then
        radius = Spring.GetUnitDefDimensions(Spring.GetUnitDefID(uID)).radius
        radius_cache:put(uID, radius)
    end
    return radius
end

-- Checks if a command is valid
local function isValidCommandID(commandID)
    return commandID == CMD.REPAIR or commandID == CMD.GUARD or commandID == CMD.RECLAIM or commandID == CMD.ATTACK
end
-- !SECTION Helper functions

-- SECTION Main functions
local function checkTurretRange(uID)
    local x, y, z = Spring.GetUnitPosition(uID)
    local build_distance = Spring.GetUnitEffectiveBuildRange(uID, nil) -- Same as UnitDef.buildDistance; Not ambiguous
    local is_changed = false
    local is_first_cmd = true
    local cmds = Spring.GetUnitCommands(uID, -1)
    local new_cmds = {}
    for i = #cmds, 1, -1  do
        local cmd = cmds[i]
        if isValidCommandID(cmd.id) then
            local tuID = cmd.params[1]
            local tx, ty, tz = Spring.GetUnitPosition(tuID)
            if tx == nil then break end
            local distance = calculateDistance2D(x, z, tx, tz)
            local radius = getUnitRadius(tuID)
            if distance < build_distance + radius then -- BP uses build_distance + radius (sphereical shape of model)
                cmd.options.shift = not is_first_cmd
                is_first_cmd = false
                table.insert(new_cmds, {cmd.id, cmd.params, cmd.options}) -- building cmdArr
            else
                is_changed = true
            end
        end
    end
    if is_changed then
        if #new_cmds > 0 then
            table.insert(new_orders, {uID, new_cmds}) -- schedule for new order
        else
            table.insert(to_be_cleared, uID) -- schedule for clear
        end
    end
end

-- Applies all stop orders to units in the `to_be_cleared` stack.
local function applyStopOrders()
    if #to_be_cleared > 0 then
        Spring.GiveOrderToUnitArray(to_be_cleared, CMD.STOP, {}, {})
        command_budget = command_budget - #to_be_cleared
        to_be_cleared = {}
    end
end

-- Processes new orders that have been scheduled for execution in the `new_orders` stack.
local function processNewOrders()
    if #new_orders > 0 and #to_be_cleared == 0 then
        for i = #new_orders, 1, -1 do
            if command_budget <= 0 then break end
            Spring.GiveOrderArrayToUnit(new_orders[i][1], new_orders[i][2])
            table.remove(new_orders, i) -- pop
            command_budget = command_budget - 1
        end
    end
end

-- Processes the turret range check after a certain number of frames (controlled by `DELAY`).
-- It iterates over the current list of nano turrets and checks their range to ensure they are not assigned
-- to constructions out of reach.
-- If any changes are detected, it schedules new orders or/and clears existing ones.
local function processTurretRange()
    if counter >= DELAY then
        counter = 0
        for _, tower in ipairs(current_towers) do
            checkTurretRange(tower)
        end
        flag_processed = true
    end
end

-- Handles the flow control. If no command is scheduled, it disables the listener for the gameframe loop,
-- else it keeps calling the `processTurretRange` function, in case anything changed during re-ordering.
local function handleFlowControl()
    if #to_be_cleared == 0 and #new_orders == 0 then
        if flag_processed then
            flag_listening = false
        else
            processTurretRange()
        end
    end
end
-- !SECTION Main functions

-- SECTION Widget functions
function widget:Initialize()
    is_play = Spring.GetSpectatingState()
    -- pre-check set
    for _, name in ipairs(TURRETS) do
        if UnitDefNames[name].buildDistance == nil then
            Spring.Echo("Error: " .. name .. " has no buildDistance")
            widget:Shutdown()
        end
    end
    tableToSet(TURRETS)
end

function widget:GameFrame()
    if flag_listening then -- only as long as turret is selection and one post-frame after selection drop.
        counter = counter + 1
        command_budget = COMMAND_LIMIT

        applyStopOrders()
        processNewOrders()
        handleFlowControl()
    end
end

-- Grabs any nano in selection and stores it in the list
function widget:SelectionChanged(selectedUnits)
    if is_play ~= false then return end
    if flag_processed == true then -- remove old when processing is done, else append.
        current_towers = {}
    end
    for _, unitID in ipairs(selectedUnits) do
        local unitDefID = Spring.GetUnitDefID(unitID)
        if TURRETS[UnitDefs[unitDefID].name] then
            table.insert(current_towers, unitID)
        end
    end
end

-- Listener to when nano receives a command
function widget:UnitCommand(uID, _, _, _, _, _, _)
    if is_play ~= false then return end
    for _, nano in ipairs(current_towers) do
        if uID == nano then
            flag_listening = true
            counter = 0
            flag_processed = false
            break
        end
    end
end
-- !SECTION Widget functions