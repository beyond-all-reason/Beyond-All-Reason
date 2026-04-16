function gadget:GetInfo()
    return {
        name    = "Courtesy Pause",
        desc    = "Lobby-wide courtesy countdown on resume with synced beeps",
        author  = "26Projects",
        version = "2.4",
        layer   = 0,
        enabled = true,
    }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- SYNCED
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then

local FRAMES_PER_SECOND = 30

-- Total delay for countdown
local TOTAL_DELAY_SECONDS = 5
local TOTAL_DELAY_FRAMES = TOTAL_DELAY_SECONDS * FRAMES_PER_SECOND

-- Countdown steps
local STEPS = {3, 2, 1}

-- Spread timing evenly across steps + GO
local FRAMES_PER_STEP = math.floor(TOTAL_DELAY_FRAMES / (#STEPS + 1))

-- Extra delay AFTER GO before actual unpause
local POST_GO_DELAY_FRAMES = 10  -- about 0.33 seconds

-- STATE
local countdownActive = false
local currentStepIndex = 0
local stepFrameCounter = 0

local postGoDelayActive = false
local postGoFramesLeft = 0

local allowNextRealUnpause = false
local courtesyEnabled = true

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

local function SetCourtesyPauseActive(active)
    Spring.SetGameRulesParam("courtesy_pause_active", active and 1 or 0, {
        public = true,
        allied = true,
    })
end

local function SetCourtesyPauseEnabled(enabled)
    Spring.SetGameRulesParam("courtesy_pause_enabled", enabled and 1 or 0, {
        public = true,
        allied = true,
    })
end

-- Count real human players only:
-- active
-- not spectators
-- not AI teams
local function CountActiveHumanPlayers()
    local count = 0
    local playerList = Spring.GetPlayerList()

    for i = 1, #playerList do
        local playerID = playerList[i]

        -- name, active, spectator, teamID, allyTeamID, pingTime, cpuUsage, country, rank, hasSkirmishAIsInTeam, customKeys, desynced
        local _, active, spectator, teamID = Spring.GetPlayerInfo(playerID, false)

        if active and not spectator and teamID then
            -- teamID, leader, isDead, isAiTeam, side, allyTeam, incomeMultiplier, customTeamKeys
            local _, _, _, isAiTeam = Spring.GetTeamInfo(teamID, false)

            if not isAiTeam then
                count = count + 1
            end
        end
    end

    return count
end

local function CancelCountdown()
    countdownActive = false
    currentStepIndex = 0
    stepFrameCounter = 0

    postGoDelayActive = false
    postGoFramesLeft = 0

    allowNextRealUnpause = false
    SetCourtesyPauseActive(false)
end

local function RefreshCourtesyEnabled()
    courtesyEnabled = CountActiveHumanPlayers() > 1
    SetCourtesyPauseEnabled(courtesyEnabled)

    -- If disabled, make sure all courtesy state is cleared
    if not courtesyEnabled then
        CancelCountdown()
    end
end

local function SayToAll(text)
    Spring.SendMessage(text)
end

local function BroadcastBeep()
    SendToUnsynced("courtesy_pause_beep")
end

local function StartCountdown()
    countdownActive = true
    currentStepIndex = 1
    stepFrameCounter = 0

    SetCourtesyPauseActive(true)

    SayToAll("Unpausing in 3...")
    BroadcastBeep()
end

function gadget:Initialize()
    -- Make sure params start in a clean state
    SetCourtesyPauseActive(false)
    SetCourtesyPauseEnabled(false)
    RefreshCourtesyEnabled()
end

function gadget:PlayerChanged(playerID)
    RefreshCourtesyEnabled()
end

-- Pause / unpause hook
function gadget:GamePaused(playerID, paused)
    -- In single-player / solo load, courtesy pause is disabled
    if not courtesyEnabled then
        return
    end

    --------------------------------------------------------------------------
    -- CASE 1: Someone paused the game
    -- Always allow it immediately
    --------------------------------------------------------------------------
    if paused then
        if countdownActive or postGoDelayActive then
            CancelCountdown()
        end
        return
    end

    --------------------------------------------------------------------------
    -- CASE 2: Someone tried to unpause the game
    --------------------------------------------------------------------------

    -- Let our own final unpause happen
    if allowNextRealUnpause then
        allowNextRealUnpause = false
        return
    end

    -- Ignore extra unpause attempts during countdown/post-GO delay
    if countdownActive or postGoDelayActive then
        Spring.PauseGame(true)
        return
    end

    -- Intercept unpause and start countdown
    Spring.PauseGame(true)
    StartCountdown()
end

function gadget:GameFrame()
    -- If disabled, do nothing
    if not courtesyEnabled then
        return
    end

    --------------------------------------------------------------------------
    -- POST GO DELAY
    --------------------------------------------------------------------------
    if postGoDelayActive then
        postGoFramesLeft = postGoFramesLeft - 1

        if postGoFramesLeft <= 0 then
            postGoDelayActive = false

            -- Clear courtesy flag BEFORE the real unpause happens
            -- so snd_notifications.lua will allow GameUnpaused
            SetCourtesyPauseActive(false)

            allowNextRealUnpause = true
            Spring.PauseGame(false)
        end

        return
    end

    --------------------------------------------------------------------------
    -- COUNTDOWN LOGIC
    --------------------------------------------------------------------------
    if not countdownActive then
        return
    end

    stepFrameCounter = stepFrameCounter + 1

    if stepFrameCounter < FRAMES_PER_STEP then
        return
    end

    stepFrameCounter = 0
    currentStepIndex = currentStepIndex + 1

    if STEPS[currentStepIndex] then
        SayToAll("Unpausing in " .. STEPS[currentStepIndex] .. "...")
        BroadcastBeep()
        return
    end

    --------------------------------------------------------------------------
    -- GO STEP
    --------------------------------------------------------------------------
    countdownActive = false

    SayToAll("GO!")

    -- Start short delay before real unpause
    postGoDelayActive = true
    postGoFramesLeft = POST_GO_DELAY_FRAMES
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- UNSYNCED
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

else

local TICK_SOUND = "beep4"
local TICK_VOLUME = 0.6

local function PlayTick()
    Spring.PlaySoundFile(TICK_SOUND, TICK_VOLUME)
end

local function OnCourtesyPauseBeep()
    PlayTick()
end

function gadget:Initialize()
    gadgetHandler:AddSyncAction("courtesy_pause_beep", OnCourtesyPauseBeep)
end

function gadget:Shutdown()
    gadgetHandler:RemoveSyncAction("courtesy_pause_beep", OnCourtesyPauseBeep)
end

end
