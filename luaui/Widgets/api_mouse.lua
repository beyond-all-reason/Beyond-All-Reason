local widget = widget --- @type Widget

function widget:GetInfo()
	return {
		name    = "Mouse Input API",
		desc    = "Provides an API for handling mouse input events (clicks, double-clicks and drags)",
		author  = "uBdead",
		date    = "June 2026",
		license = "GPL-v2",
		layer   = -1, -- expose API at init arbitrarily early, hopefully before want to use the API
		enabled = true,
	}
end

local LOG_SECTION = "Mouse Input API"

local abs = math.abs
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local spGetMouseState = Spring.GetMouseState

-- Handler registries -------------------------------------------------------

local immediateClickHandlers = {} -- id -> function(x, y, button); fired on press
local clickHandlers = {}          -- id -> function(x, y, button); fired only for a
                                  --       confirmed click (not a drag, not a double-click)
local doubleClickHandlers = {}    -- id -> function(x, y, button)
local dragHandlers = {}           -- id -> dragSpec

-- Double-click detection state
local lastClickTimer = nil
local lastClickX, lastClickY, lastClickButton = nil, nil, nil
local doubleClickTimeMs = 200    -- refreshed from engine config on Initialize
local doubleClickPosThreshold = 4 -- pixels

-- Drag tracking state (only meaningful while we are the mouse owner)
local dragActive = false          -- between the captured MousePress and MouseRelease
local dragStartX, dragStartY = 0, 0
local dragButton = nil
local activeDrags = {}            -- list of { spec = dragSpec, started = bool }

local DEFAULT_DRAG_THRESHOLD = 6  -- pixels of movement before a drag begins

-- Confirmed-click tracking state.
--
-- A confirmed click is a press+release of the same button that did not move far
-- enough to be a drag and that is not part of a double-click. Because the engine
-- only delivers MouseMove/MouseRelease to the mouse owner, this API stays a
-- passive observer by tracking the press via the MousePress call-in and watching
-- for movement and release by polling Spring.GetMouseState() in Update. Polling
-- only reports the three primary buttons, so confirmed clicks are limited to
-- buttons 1 (left), 2 (middle) and 3 (right).
local heldPresses = {}            -- button -> { x, y, timer, moved = bool }
local suppressConfirm = {}        -- button -> true when the press is the 2nd of a double-click
local pendingClicks = {}          -- list of { x, y, button, timer } awaiting the double-click window
local clickMoveThreshold = DEFAULT_DRAG_THRESHOLD -- pixels of movement that turns a click into a drag

-- Helpers ------------------------------------------------------------------

local function logError(msg)
    Spring.Log(LOG_SECTION, LOG.ERROR, msg)
end

local function registerSimpleHandler(registry, kind, id, handler)
    if id == nil then
        logError("register" .. kind .. ": id must not be nil")
        return false
    end
    if type(handler) ~= "function" then
        logError("register" .. kind .. ": handler must be a function")
        return false
    end
    registry[id] = handler
    return true
end

-- Invoke every handler in a registry. Returns true if at least one handler
-- returned true, signalling that the event was consumed.
local function callSimpleHandlers(registry, kind, x, y, button)
    local consumed = false
    for id, handler in pairs(registry) do
        local ok, ret = pcall(handler, x, y, button)
        if not ok then
            logError("Error in " .. kind .. " handler '" .. tostring(id) .. "': " .. tostring(ret))
            registry[id] = nil
        elseif ret == true then
            consumed = true
        end
    end
    return consumed
end

-- Click handlers -----------------------------------------------------------

-- Immediate click handlers fire on every mouse press, without waiting to find
-- out whether the press becomes a drag or a double-click. A handler may return
-- true to consume the press; if no handler of any kind consumes it, the press is
-- passed on to the engine as normal.
local function registerImmediateClickHandler(id, handler)
    return registerSimpleHandler(immediateClickHandlers, "ImmediateClickHandler", id, handler)
end

local function disposeImmediateClickHandler(id)
    immediateClickHandlers[id] = nil
end

-- Click handlers fire only once a press is confirmed to be a plain click: the
-- button was released without moving far enough to be a drag, and the click was
-- not part of a double-click. This is delivered after the double-click window
-- elapses, so it is slightly delayed compared to the immediate variant.
local function registerClickHandler(id, handler)
    return registerSimpleHandler(clickHandlers, "ClickHandler", id, handler)
end

local function disposeClickHandler(id)
    clickHandlers[id] = nil
end

-- Double-click handlers ----------------------------------------------------

-- Double-click handlers fire on the second press of a double-click. A handler
-- may return true to consume that press.
local function registerDoubleClickHandler(id, handler)
    return registerSimpleHandler(doubleClickHandlers, "DoubleClickHandler", id, handler)
end

local function disposeDoubleClickHandler(id)
    doubleClickHandlers[id] = nil
end

-- Drag handlers ------------------------------------------------------------
--
-- A drag handler is registered with a spec table of optional callbacks:
--   filter(x, y, button) -> boolean
--       Decides whether a given press should be captured as a potential drag.
--       Defaults to capturing any press. Returning true makes this API the
--       mouse owner for the press, which prevents lower-priority widgets from
--       receiving it, so keep filters as specific as possible.
--   threshold (number)
--       Pixels of movement before the drag is considered started. Defaults to
--       DEFAULT_DRAG_THRESHOLD.
--   onStart(startX, startY, button)
--       Fired once movement crosses the threshold.
--   onMove(x, y, dx, dy, startX, startY, button)
--       Fired on every mouse move after the drag has started.
--   onEnd(x, y, startX, startY, button)
--       Fired when the initiating button is released after a drag started.
--   onCancel(x, y, button)
--       Fired when the button is released before the drag ever started
--       (i.e. the press behaved like a click).

local function registerDragHandler(id, spec)
    if id == nil then
        logError("registerDragHandler: id must not be nil")
        return false
    end
    if type(spec) ~= "table" then
        logError("registerDragHandler: spec must be a table of callbacks")
        return false
    end
    spec._id = id
    dragHandlers[id] = spec
    return true
end

local function disposeDragHandler(id)
    dragHandlers[id] = nil
end

-- Safely invoke a drag callback; dispose the handler on error.
local function callDragCallback(spec, name, ...)
    local cb = spec[name]
    if type(cb) ~= "function" then
        return
    end
    local ok, err = pcall(cb, ...)
    if not ok then
        logError("Error in drag handler '" .. tostring(spec._id) .. "' callback '" .. name .. "': " .. tostring(err))
        dragHandlers[spec._id] = nil
        for i = #activeDrags, 1, -1 do
            if activeDrags[i].spec == spec then
                table.remove(activeDrags, i)
            end
        end
    end
end

local function dragWantsPress(spec, x, y, button)
    local filter = spec.filter
    if filter == nil then
        return true
    end
    if type(filter) ~= "function" then
        return false
    end
    local ok, want = pcall(filter, x, y, button)
    if not ok then
        logError("Error in drag handler '" .. tostring(spec._id) .. "' filter: " .. tostring(want))
        dragHandlers[spec._id] = nil
        return false
    end
    return want == true
end

-- Confirmed-click state machine --------------------------------------------
-- Fed from both the call-ins (reliable press, plus move/release while we own
-- the mouse for a drag) and Update polling (move/release for un-captured
-- presses). All transitions are idempotent so the two sources cannot conflict.

local function beginPress(button, x, y)
    if button < 1 or button > 3 then
        return -- only the pollable primary buttons can be confirmed
    end
    heldPresses[button] = { x = x, y = y, timer = spGetTimer(), moved = false }
end

local function updatePressMove(button, x, y)
    local held = heldPresses[button]
    if not held or held.moved then
        return
    end
    local ddx = x - held.x
    local ddy = y - held.y
    if (ddx * ddx + ddy * ddy) >= (clickMoveThreshold * clickMoveThreshold) then
        held.moved = true
    end
end

local function endPress(button, x, y)
    local held = heldPresses[button]
    if not held then
        return
    end
    heldPresses[button] = nil

    local suppressed = suppressConfirm[button]
    suppressConfirm[button] = nil

    if held.moved or suppressed then
        return -- a drag, or the second press of a double-click: never a plain click
    end

    -- Defer until the double-click window has passed so we know it stays single.
    pendingClicks[#pendingClicks + 1] = { x = x, y = y, button = button, timer = held.timer }
end

-- A double-click was detected on this press: cancel the pending confirmation of
-- the first click and make sure the second press never confirms either.
local function cancelConfirmForDoubleClick(button)
    suppressConfirm[button] = true
    for i = #pendingClicks, 1, -1 do
        if pendingClicks[i].button == button then
            table.remove(pendingClicks, i)
        end
    end
end

-- Lifecycle ----------------------------------------------------------------

function widget:Initialize()
    doubleClickTimeMs = Spring.GetConfigInt("DoubleClickTime", 200) or 200

    WG.Mouse = {
        registerImmediateClickHandler = registerImmediateClickHandler,
        disposeImmediateClickHandler = disposeImmediateClickHandler,
        registerClickHandler = registerClickHandler,
        disposeClickHandler = disposeClickHandler,
        registerDoubleClickHandler = registerDoubleClickHandler,
        disposeDoubleClickHandler = disposeDoubleClickHandler,
        registerDragHandler = registerDragHandler,
        disposeDragHandler = disposeDragHandler,
    }
end

function widget:Shutdown()
    WG.Mouse = nil
end

-- Call-ins -----------------------------------------------------------------

function widget:MousePress(x, y, button)
    -- While we own the mouse for an in-progress drag, additional presses are
    -- swallowed so we keep ownership until the initiating button is released.
    if dragActive then
        return true
    end

    -- Tracks whether any handler wants to consume this press. When nothing
    -- consumes it, MousePress returns false so the engine handles it as normal.
    local consumed = false

    -- Immediate click handlers observe every press and may consume it.
    if callSimpleHandlers(immediateClickHandlers, "immediate click", x, y, button) then
        consumed = true
    end

    -- Start tracking this press so a confirmed click can be emitted later.
    beginPress(button, x, y)

    -- Double-click detection.
    local now = spGetTimer()
    if lastClickTimer
        and lastClickButton == button
        and spDiffTimers(now, lastClickTimer, true) <= doubleClickTimeMs
        and abs(x - lastClickX) <= doubleClickPosThreshold
        and abs(y - lastClickY) <= doubleClickPosThreshold
    then
        if callSimpleHandlers(doubleClickHandlers, "double-click", x, y, button) then
            consumed = true
        end
        cancelConfirmForDoubleClick(button)
        lastClickTimer = nil -- reset so a third click does not re-trigger
    else
        lastClickTimer = now
        lastClickX, lastClickY, lastClickButton = x, y, button
    end

    -- Drag handlers: capture the mouse only if at least one wants this press.
    activeDrags = {}
    for _, spec in pairs(dragHandlers) do
        if dragWantsPress(spec, x, y, button) then
            activeDrags[#activeDrags + 1] = { spec = spec, started = false }
        end
    end

    if #activeDrags > 0 then
        dragActive = true
        dragStartX, dragStartY = x, y
        dragButton = button
        return true -- become the mouse owner to receive MouseMove / MouseRelease
    end

    -- No drag captured the press: pass the consumption decision of the click and
    -- double-click handlers through. If none consumed it, the engine handles it.
    return consumed
end

function widget:MouseMove(x, y, dx, dy, button)
    if not dragActive then
        return false
    end

    -- Keep confirmed-click tracking in sync while we own the mouse.
    updatePressMove(button, x, y)

    local totalDx = x - dragStartX
    local totalDy = y - dragStartY
    local distSq = totalDx * totalDx + totalDy * totalDy

    for i = #activeDrags, 1, -1 do
        local entry = activeDrags[i]
        local spec = entry.spec
        if not entry.started then
            local threshold = spec.threshold or DEFAULT_DRAG_THRESHOLD
            if distSq >= threshold * threshold then
                entry.started = true
                callDragCallback(spec, "onStart", dragStartX, dragStartY, dragButton)
            end
        end
        if entry.started then
            callDragCallback(spec, "onMove", x, y, dx, dy, dragStartX, dragStartY, dragButton)
        end
    end

    return false
end

function widget:MouseRelease(x, y, button)
    if not dragActive then
        return false
    end

    -- Keep ownership until the button that started the drag is released.
    if button ~= dragButton then
        return true
    end

    -- Finalise confirmed-click tracking for the captured press.
    endPress(button, x, y)

    for i = #activeDrags, 1, -1 do
        local entry = activeDrags[i]
        if entry.started then
            callDragCallback(entry.spec, "onEnd", x, y, dragStartX, dragStartY, dragButton)
        else
            callDragCallback(entry.spec, "onCancel", x, y, dragButton)
        end
    end

    dragActive = false
    dragButton = nil
    activeDrags = {}

    return false -- release mouse ownership
end

-- Poll the mouse for confirmed-click tracking of un-captured presses, and emit
-- confirmed clicks whose double-click window has elapsed.
function widget:Update()
    if next(heldPresses) ~= nil then
        local mx, my, lmb, mmb, rmb = spGetMouseState()
        local down = { lmb and lmb ~= 0, mmb and mmb ~= 0, rmb and rmb ~= 0 }
        for button = 1, 3 do
            if heldPresses[button] then
                if down[button] then
                    updatePressMove(button, mx, my)
                else
                    endPress(button, mx, my) -- release missed by the call-ins
                end
            end
        end
    end

    if #pendingClicks > 0 then
        local now = spGetTimer()
        for i = #pendingClicks, 1, -1 do
            local pc = pendingClicks[i]
            if spDiffTimers(now, pc.timer, true) > doubleClickTimeMs then
                table.remove(pendingClicks, i)
                callSimpleHandlers(clickHandlers, "click", pc.x, pc.y, pc.button)
            end
        end
    end
end
