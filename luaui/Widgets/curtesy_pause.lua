function widget:GetInfo()
    return {
        name    = "Courtesy Pause",
        desc    = "Client-side courtesy countdown before unpause",
        author  = "26Projects",
        version = "2.0",
        enabled = false,
    }
end

--------------------------------------------------------------------------------
-- SETTINGS
--------------------------------------------------------------------------------

local totalDelaySeconds = 5
local steps = {3, 2, 1}

local framesPerSecond = 30
local totalFrames = totalDelaySeconds * framesPerSecond
local framesPerStep = math.floor(totalFrames / (#steps + 1))

local tickSound = "beep4"
local tickVolume = 0.6

local selfCommandIgnoreFrames = 8

--------------------------------------------------------------------------------
-- SAFETY LIMITS
--------------------------------------------------------------------------------
-- These are hard guards against accidental loops or chat/command flooding.

-- At most one chat countdown message every 20 frames, about 0.67 seconds.
local minChatCommandFrames = 20

-- At most one injected pause command every 10 frames, about 0.33 seconds.
local minPauseCommandFrames = 10

-- If this widget sends more than this many pause commands in the window below,
-- it assumes something is wrong and temporarily shuts itself up.
local maxPauseCommandsPerWindow = 6
local pauseCommandWindowFrames = 90 -- 3 seconds

-- After the safety breaker triggers, the widget will stop sending chat and
-- pause commands for this many frames.
local safetyCooldownFrames = 150 -- 5 seconds

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local countdownActive = false
local currentStep = 1
local stepFrameCounter = 0

local allowNextRealUnpause = false
local lastPausedState = true

local ignoreTextCommandFrames = 0

local lastChatFrame = -99999
local lastPauseCommandFrame = -99999

local pauseCommandWindowStart = 0
local pauseCommandsInWindow = 0
local safetyCooldownUntilFrame = 0

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function GetFrame()
    return Spring.GetGameFrame()
end

local function IsPaused()
    local _, _, paused = Spring.GetGameSpeed()
    return paused
end

local function SafetyCooldownActive()
    return GetFrame() < safetyCooldownUntilFrame
end

local function TriggerSafetyCooldown(reason)
    countdownActive = false
    currentStep = 1
    stepFrameCounter = 0
    allowNextRealUnpause = false

    safetyCooldownUntilFrame = GetFrame() + safetyCooldownFrames

    Spring.Echo("[Courtesy Pause] Safety cooldown triggered: " .. reason)
end

local function SendCountdownChat(text)
    local frame = GetFrame()

    -- Absolute chat throttle. Even if something goes wrong, this prevents
    -- repeated countdown messages from flooding chat.
    if frame - lastChatFrame < minChatCommandFrames then
        return
    end

    if SafetyCooldownActive() then
        return
    end

    lastChatFrame = frame
    Spring.SendCommands("say " .. text)
end

local function PlayTick()
    if SafetyCooldownActive() then
        return
    end

    Spring.PlaySoundFile(tickSound, tickVolume)
end

local function SendPauseCommand(command)
    local frame = GetFrame()

    if SafetyCooldownActive() then
        return
    end

    -- Absolute pause-command throttle. This prevents rapid command injection
    -- even if TextCommand or pause-state updates behave unexpectedly.
    if frame - lastPauseCommandFrame < minPauseCommandFrames then
        return
    end

    -- Rolling-window loop breaker.
    if frame - pauseCommandWindowStart > pauseCommandWindowFrames then
        pauseCommandWindowStart = frame
        pauseCommandsInWindow = 0
    end

    pauseCommandsInWindow = pauseCommandsInWindow + 1

    if pauseCommandsInWindow > maxPauseCommandsPerWindow then
        TriggerSafetyCooldown("too many pause commands")
        return
    end

    lastPauseCommandFrame = frame

    -- Our own pause commands may come back through TextCommand(), so ignore
    -- pause TextCommand handling briefly after sending them.
    ignoreTextCommandFrames = selfCommandIgnoreFrames

    Spring.SendCommands(command)
end

--------------------------------------------------------------------------------
-- COUNTDOWN CONTROL
--------------------------------------------------------------------------------

local function StartCountdown()
    -- Do not start or restart while safety cooldown is active.
    if SafetyCooldownActive() then
        return
    end

    -- Idempotency guard. Repeated unpause attempts cannot restart the countdown
    -- or resend "Unpausing in 3...".
    if countdownActive then
        return
    end

    countdownActive = true
    currentStep = 1
    stepFrameCounter = 0

    SendCountdownChat("Unpausing in " .. steps[currentStep] .. "...")
    PlayTick()
end

local function CancelCountdown()
    countdownActive = false
    currentStep = 1
    stepFrameCounter = 0
    allowNextRealUnpause = false
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------

function widget:Initialize()
    lastPausedState = IsPaused()
    Spring.Echo("[Courtesy Pause] Widget v2.0 loaded")
end

--------------------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------------------

function widget:Update()
    if ignoreTextCommandFrames > 0 then
        ignoreTextCommandFrames = ignoreTextCommandFrames - 1
    end

    local paused = IsPaused()

    --------------------------------------------------------------------------
    -- Detect a real paused -> unpaused transition.
    --
    -- This is the only place where the countdown starts. That preserves BaR's
    -- normal pause-control behavior, where a first /pause while already paused
    -- may simply take pause control rather than actually unpausing.
    --------------------------------------------------------------------------

    if lastPausedState and not paused then
        if allowNextRealUnpause then
            -- This unpause was caused by our own final "pause 0".
            allowNextRealUnpause = false
        else
            -- Someone actually unpaused. Re-pause and begin the courtesy delay.
            SendPauseCommand("pause 1")
            StartCountdown()

            -- Treat this frame as paused so transition tracking stays stable.
            paused = true
        end
    end

    --------------------------------------------------------------------------
    -- Countdown timing.
    --------------------------------------------------------------------------

    if countdownActive then
        stepFrameCounter = stepFrameCounter + 1

        if stepFrameCounter >= framesPerStep then
            stepFrameCounter = 0
            currentStep = currentStep + 1

            if steps[currentStep] then
                SendCountdownChat("Unpausing in " .. steps[currentStep] .. "...")
                PlayTick()
            else
                countdownActive = false

                SendCountdownChat("GO!")

                -- Allow exactly the next real unpause transition through.
                allowNextRealUnpause = true
                SendPauseCommand("pause 0")
            end
        end
    end

    lastPausedState = paused
end

--------------------------------------------------------------------------------
-- TEXT COMMAND HOOK
--------------------------------------------------------------------------------
-- This hook is intentionally defensive.
--
-- It does not start the countdown from /pause text alone. The countdown starts
-- only after the actual game state changes from paused to unpaused.
--
-- During an active countdown, repeated /pause commands are not allowed to
-- restart the countdown or produce extra chat. If the game somehow becomes
-- unpaused during the countdown, the guarded SendPauseCommand() will re-pause,
-- while still respecting the hard safety throttles.
--------------------------------------------------------------------------------

function widget:TextCommand(command)
    local cmd = string.lower(command or "")

    if cmd ~= "pause" and cmd ~= "pause 0" and cmd ~= "pause 1" then
        return
    end

    if ignoreTextCommandFrames > 0 then
        return
    end

    if SafetyCooldownActive() then
        return
    end

    if countdownActive then
        -- Do not send pause commands blindly on every /pause text command.
        -- Only re-pause if the game is actually unpaused.
        if not IsPaused() then
            SendPauseCommand("pause 1")
        end

        return
    end
end
