function widget:GetInfo()
    return {
        name    = "Curtesy Pause",
        desc    = "Client-side courtesy countdown before your own unpause",
        author  = "26Projects",
        version = "3.0",
        enabled = true,
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
local secondsPerStep = framesPerStep / framesPerSecond

local tickSound = "beep4"
local tickVolume = 0.6

-- How long a local /pause command is allowed to arm the next unpause.
-- This keeps the widget scoped to the local user's own pause/unpause action.
-- Keep this short: a pause command that actually unpauses should be reflected
-- by the game state almost immediately. A long window can accidentally catch
-- another player's later unpause after you only took pause control.
local localPauseCommandValidSeconds = 12 / framesPerSecond

-- Ignore pause-command echoes briefly after this widget sends pause commands.
local selfCommandIgnoreFrames = 8

-- Set this to false if you want the widget to stay completely silent/passive
-- when you are the only active human player in the game.
local enableInSinglePlayer = true

--------------------------------------------------------------------------------
-- SAFETY LIMITS
--------------------------------------------------------------------------------

local minChatCommandSeconds = 20 / framesPerSecond
local maxPauseCommandsPerCycle = 3

local safetyCooldownSeconds = 150 / framesPerSecond

-- Allow Recoil time to apply our single re-pause command before deciding it
-- failed. No additional pause command is sent while confirmation is pending.
local rePauseConfirmTimeoutSeconds = 1
local rePauseStableSeconds = 0.5
local maxRePauseRetries = 1

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local countdownActive = false
local currentStep = 1
local stepTimer = 0

local rePausePending = false
local rePauseDeadline = 0
local rePauseStableSince = nil
local rePauseRetries = 0

local armedForLocalUnpause = false
local localPauseCommandTime = -99999
local localUnpauseEventPending = false

local allowNextRealUnpause = false
local lastPausedState = true

local ignoreTextCommandFrames = 0

local lastChatTime = -99999
local pauseCommandsThisCycle = 0
local safetyCooldownUntilTime = 0

-- Spring.GetGameFrame() does not reliably advance while paused. Recoil/Spring
-- passes wall-clock delta time into widget:Update(dt), including while paused,
-- so this widget uses localTime for countdowns, throttles, and cooldowns.
local localTime = 0

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function GetTime()
    return localTime
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

        if active and not spectator then
            humanCount = humanCount + 1
        end
    end

    return humanCount <= 1
end

local function SafetyCooldownActive()
    return GetTime() < safetyCooldownUntilTime
end

local function LocalUnpauseArmIsFresh()
    return armedForLocalUnpause
        and (GetTime() - localPauseCommandTime <= localPauseCommandValidSeconds)
end

local function ClearLocalUnpauseArm()
    armedForLocalUnpause = false
    localPauseCommandTime = -99999
end

local function CancelCountdown()
    countdownActive = false
    currentStep = 1
    stepTimer = 0
    rePausePending = false
    rePauseDeadline = 0
    rePauseStableSince = nil
    rePauseRetries = 0
    pauseCommandsThisCycle = 0
    localUnpauseEventPending = false
    allowNextRealUnpause = false
end

local function TriggerSafetyCooldown(reason)
    CancelCountdown()
    ClearLocalUnpauseArm()

    safetyCooldownUntilTime = GetTime() + safetyCooldownSeconds

    Spring.Echo("[Courtesy Pause] Safety cooldown triggered: " .. reason)
end

local function NormalizeCommand(command)
    local cmd = string.lower(command or "")
    cmd = string.gsub(cmd, "^%s*/?", "")
    cmd = string.gsub(cmd, "%s+$", "")
    cmd = string.gsub(cmd, "%s+", " ")
    return cmd
end

local function IsPauseUnpauseCommand(command)
    local cmd = NormalizeCommand(command)
    return cmd == "pause" or cmd == "pause 0"
end

local function ArmLocalUnpause(command)
    if not IsPauseUnpauseCommand(command) then
        return
    end

    if ignoreTextCommandFrames > 0 then
        return
    end

    if SafetyCooldownActive()
        or (not enableInSinglePlayer and IsOnlyHumanPlayer())
        or countdownActive then
        return
    end

    armedForLocalUnpause = true
    localPauseCommandTime = GetTime()
end

local function SendCountdownChat(text)
    local time = GetTime()

    if SafetyCooldownActive() then
        return false
    end

    if time - lastChatTime < minChatCommandSeconds then
        return false
    end

    lastChatTime = time

    Spring.SendCommands("say " .. text)

    return true
end

local function PlayTick()
    if not SafetyCooldownActive() then
        Spring.PlaySoundFile(tickSound, tickVolume)
    end
end

local function SendPauseCommand(command)
    if SafetyCooldownActive() then
        return false
    end

    if pauseCommandsThisCycle >= maxPauseCommandsPerCycle then
        TriggerSafetyCooldown("pause command limit reached")
        return false
    end

    pauseCommandsThisCycle = pauseCommandsThisCycle + 1
    ignoreTextCommandFrames = selfCommandIgnoreFrames

    Spring.SendCommands(command)
    return true
end

--------------------------------------------------------------------------------
-- COUNTDOWN CONTROL
--------------------------------------------------------------------------------

local function StartCountdown()
    if countdownActive
        or SafetyCooldownActive()
        or (not enableInSinglePlayer and IsOnlyHumanPlayer()) then
        return false
    end

    countdownActive = true
    currentStep = 1
    stepTimer = 0

    SendCountdownChat("Unpausing in " .. steps[currentStep] .. "...")
    PlayTick()

    return true
end

--------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------

function widget:Initialize()
    lastPausedState = IsPaused()
    Spring.Echo("[Courtesy Pause] Widget v3.0 loaded")
end

--------------------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------------------

function widget:Update(dt)
    localTime = localTime + (dt or (1 / framesPerSecond))

    if ignoreTextCommandFrames > 0 then
        ignoreTextCommandFrames = ignoreTextCommandFrames - 1
    end

    local paused = IsPaused()

    -- Optional solo-game silence. Leave enableInSinglePlayer=true for testing
    -- or personal use; set it false to make the widget passive when alone.
    if not enableInSinglePlayer and IsOnlyHumanPlayer() then
        CancelCountdown()
        ClearLocalUnpauseArm()
        lastPausedState = paused
        return
    end

    -- A pause command is not guaranteed to change the reported state before
    -- the next Update call. Wait for confirmation instead of sending pause 1
    -- repeatedly and tripping our own flood protection.
    if rePausePending then
        if paused then
            if not rePauseStableSince then
                rePauseStableSince = GetTime()
            elseif GetTime() - rePauseStableSince >= rePauseStableSeconds then
                rePausePending = false
                rePauseDeadline = 0
                rePauseStableSince = nil

                if not StartCountdown() then
                    TriggerSafetyCooldown("could not start countdown safely")
                end
            end
        elseif GetTime() >= rePauseDeadline then
            rePauseStableSince = nil

            if rePauseRetries < maxRePauseRetries and SendPauseCommand("pause 1") then
                rePauseRetries = rePauseRetries + 1
                rePauseDeadline = GetTime() + rePauseConfirmTimeoutSeconds
            else
                rePausePending = false
                rePauseDeadline = 0
                TriggerSafetyCooldown("re-pause was not confirmed")
            end
        else
            rePauseStableSince = nil
        end

        lastPausedState = paused
        return
    end

    if lastPausedState and not paused then
        if allowNextRealUnpause then
            -- This was the widget's own final unpause.
            allowNextRealUnpause = false
            pauseCommandsThisCycle = 0
            localUnpauseEventPending = false
        elseif localUnpauseEventPending
            or (enableInSinglePlayer and IsOnlyHumanPlayer())
            or LocalUnpauseArmIsFresh() then
            -- This client recently issued /pause, and that command really
            -- unpaused the game. In single player, the local user is the only
            -- possible unpause source, so the arm hook is not required.
            -- Re-pause once, then run the courtesy timer.
            ClearLocalUnpauseArm()
            localUnpauseEventPending = false
            pauseCommandsThisCycle = 0
            rePauseRetries = 0
            rePauseStableSince = nil

            if SendPauseCommand("pause 1") then
                rePausePending = true
                rePauseDeadline = GetTime() + rePauseConfirmTimeoutSeconds
            else
                TriggerSafetyCooldown("could not re-pause safely")
            end
        else
            -- Another user, the host, or the engine unpaused. Do not fight it.
            CancelCountdown()
            ClearLocalUnpauseArm()
        end
    end

    if countdownActive then
        if not paused then
            -- If the game becomes unpaused before our own final pause 0,
            -- fail open instead of holding the game hostage.
            CancelCountdown()
        else
            stepTimer = stepTimer + (dt or (1 / framesPerSecond))

            if stepTimer >= secondsPerStep then
                stepTimer = stepTimer - secondsPerStep
                currentStep = currentStep + 1

                if steps[currentStep] then
                    SendCountdownChat(steps[currentStep] .. "...")
                    PlayTick()
                else
                    countdownActive = false
                    SendCountdownChat("GO!")

                    if SendPauseCommand("pause 0") then
                        allowNextRealUnpause = true
                    else
                        TriggerSafetyCooldown("could not send final unpause")
                    end
                end
            end
        end
    end

    lastPausedState = paused
end

--------------------------------------------------------------------------------
-- LOCAL COMMAND HOOKS
--------------------------------------------------------------------------------
-- TextCommand catches many local slash commands. GotChatMsg gives us a player
-- ID for UI commands, so it is used as an extra local-user guard when present.
--------------------------------------------------------------------------------

function widget:TextCommand(command)
    ArmLocalUnpause(command)
end

function widget:GotChatMsg(msg, playerID)
    if playerID == Spring.GetMyPlayerID() then
        ArmLocalUnpause(msg)
    end
end

function widget:GamePaused(playerID, paused)
    if not paused
        and playerID == Spring.GetMyPlayerID()
        and not allowNextRealUnpause then
        localUnpauseEventPending = true
    end
end
