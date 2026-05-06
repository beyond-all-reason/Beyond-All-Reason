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

-- Multi-user guard:
-- Only the local client that recently issued /pause should take responsibility
-- for running the countdown after a paused -> unpaused transition.
local localPauseCommandValidFrames = 30 -- about 1 second

--------------------------------------------------------------------------------
-- SAFETY LIMITS
--------------------------------------------------------------------------------

local minChatCommandFrames = 20
local minPauseCommandFrames = 10

local maxPauseCommandsPerWindow = 6
local pauseCommandWindowFrames = 90

local safetyCooldownFrames = 150

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

-- Updated when this local client issues /pause or /pause 0.
-- Remote players' pause commands should not pass through this client's
-- TextCommand(), so this helps avoid every widget-owning player starting
-- their own countdown for someone else's unpause.
local localPauseCommandFrame = -99999

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

local function IsOnlyHumanPlayer()
    local playerList = Spring.GetPlayerList()
    local humanCount = 0

    for i = 1, #playerList do
        local playerID = playerList[i]
        local _, active, spectator = Spring.GetPlayerInfo(playerID)

        -- Count active, non-spectating human players.
        -- AI teams are not returned by GetPlayerList(), so this should only
        -- count real connected players.
        if active and not spectator then
            humanCount = humanCount + 1
        end
    end

    return humanCount <= 1
end

local function SafetyCooldownActive()
    return GetFrame() < safetyCooldownUntilFrame
end

local function LocalPlayerRecentlyRequestedUnpause()
    return GetFrame() - localPauseCommandFrame <= localPauseCommandValidFrames
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

    if SafetyCooldownActive() then
        return
    end

    -- Hard chat throttle.
    if frame - lastChatFrame < minChatCommandFrames then
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
        return false
    end

    -- Hard pause-command throttle.
    if frame - lastPauseCommandFrame < minPauseCommandFrames then
        return false
    end

    -- Rolling-window loop breaker.
    if frame - pauseCommandWindowStart > pauseCommandWindowFrames then
        pauseCommandWindowStart = frame
        pauseCommandsInWindow = 0
    end

    pauseCommandsInWindow = pauseCommandsInWindow + 1

    if pauseCommandsInWindow > maxPauseCommandsPerWindow then
        TriggerSafetyCooldown("too many pause commands")
        return false
    end

    lastPauseCommandFrame = frame
    ignoreTextCommandFrames = selfCommandIgnoreFrames

    Spring.SendCommands(command)
    return true
end

--------------------------------------------------------------------------------
-- COUNTDOWN CONTROL
--------------------------------------------------------------------------------

local function StartCountdown()
    if SafetyCooldownActive() then
        return
    end

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
    -- Hard single-human fail-open gate.
    --
    -- If there is only one active human player, this widget should not send
    -- pause commands, chat, sounds, or continue an existing countdown.
    --------------------------------------------------------------------------

    if IsOnlyHumanPlayer() then
        if countdownActive then
            CancelCountdown()
        end

        lastPausedState = paused
        return
    end

    --------------------------------------------------------------------------
    -- Detect a real paused -> unpaused transition.
    --
    -- The countdown only starts if this local client recently issued /pause.
    -- This prevents every player running the widget from responding to someone
    -- else's unpause attempt.
    --------------------------------------------------------------------------

    if lastPausedState and not paused then
        if allowNextRealUnpause then
            allowNextRealUnpause = false
        elseif LocalPlayerRecentlyRequestedUnpause() then
            -- Only start the countdown if we actually re-paused.
            -- If throttling/safety blocks the pause command, fail quiet.
            if SendPauseCommand("pause 1") then
                StartCountdown()
                paused = true
            else
                TriggerSafetyCooldown("could not re-pause safely")
            end
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

                -- Only allow the next real unpause through if this widget
                -- actually sent the final unpause command.
                if SendPauseCommand("pause 0") then
                    allowNextRealUnpause = true
                end
            end
        end
    end

    lastPausedState = paused
end

--------------------------------------------------------------------------------
-- TEXT COMMAND HOOK
--------------------------------------------------------------------------------
-- TextCommand() catches commands typed by this local client.
--
-- We use it to remember that the local player recently requested an unpause,
-- but we do not start the countdown here. The countdown starts only if the game
-- actually changes from paused to unpaused.
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

    -- In solo games, this widget should be completely passive.
    if IsOnlyHumanPlayer() then
        return
    end

    -- Record only commands that can represent an unpause attempt.
    -- Plain /pause is included because BaR uses it both for taking pause
    -- control and for toggling pause once control is held.
    if cmd == "pause" or cmd == "pause 0" then
        localPauseCommandFrame = GetFrame()
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
