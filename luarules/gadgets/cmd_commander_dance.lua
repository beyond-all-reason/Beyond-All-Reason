local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name = "Commander Dance Command",
        desc = "Handles /dance requests and triggers commander dance animations",
        author = "PtaQ",
        date = "2026",
        license = "GNU GPL v2 or later",
        layer = 0,
        enabled = true,
    }
end

if not gadgetHandler:IsSyncedCode() then
    return
end

local strSub = string.sub
local mathAbs = math.abs

local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetGameFrame = Spring.GetGameFrame
local spSendMessageToPlayer = Spring.SendMessageToPlayer
local spValidUnitID = Spring.ValidUnitID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetCOBScriptID = Spring.GetCOBScriptID
local spCallCOBScript = Spring.CallCOBScript
local spIsCheatingEnabled = Spring.IsCheatingEnabled

local UnitScript = Spring.UnitScript
local usGetScriptEnv = UnitScript.GetScriptEnv
local usCallAsUnit = UnitScript.CallAsUnit

local REQUEST_HEADER = "$dance$"
local HEADER_LEN = #REQUEST_HEADER
local COOLDOWN_FRAMES = 60 -- ~2 seconds at 30fps

local CMD_ATTACK = CMD.ATTACK
local CMD_FIGHT = CMD.FIGHT
local CMD_MANUALFIRE = CMD.MANUALFIRE
local CMD_GUARD = CMD.GUARD
local CMD_REPAIR = CMD.REPAIR
local CMD_RECLAIM = CMD.RECLAIM
local CMD_RESURRECT = CMD.RESURRECT

local lastDanceFrame = {} -- per-player cooldown

local function IsCommander(unitDefID)
    local unitDef = UnitDefs[unitDefID]
    return unitDef and unitDef.customParams and unitDef.customParams.iscommander
end

local function IsUnitBusy(unitID)
    -- Check movement
    local vx, _, vz = spGetUnitVelocity(unitID)
    if vx and (mathAbs(vx) > 0.1 or mathAbs(vz) > 0.1) then
        return true, "moving"
    end

    -- Check building
    if spGetUnitIsBuilding(unitID) then
        return true, "building"
    end

    -- Check current command for combat/assist
    local cmdID = spGetUnitCurrentCommand(unitID)
    if cmdID then
        if cmdID == CMD_ATTACK or cmdID == CMD_FIGHT or cmdID == CMD_MANUALFIRE then
            return true, "attacking"
        end
        if cmdID == CMD_GUARD or cmdID == CMD_REPAIR or cmdID == CMD_RECLAIM or cmdID == CMD_RESURRECT then
            return true, "assisting"
        end
        if cmdID < 0 then
            return true, "building"
        end
    end

    return false, nil
end

local function TriggerCommanderDance(unitID)
    if spGetCOBScriptID(unitID, "TriggerDance") then
        spCallCOBScript(unitID, "TriggerDance", 0)
        return true
    end

    local scriptEnv = usGetScriptEnv(unitID)
    if scriptEnv and scriptEnv.TriggerDance then
        usCallAsUnit(unitID, scriptEnv.TriggerDance)
        return true
    end

    return false
end

function gadget:RecvLuaMsg(msg, playerID)
    if strSub(msg, 1, HEADER_LEN) ~= REQUEST_HEADER then
        return
    end

    local _, _, spec, teamID = spGetPlayerInfo(playerID, false)
    if spec then
        return true
    end

    -- Cooldown check
    local frame = spGetGameFrame()
    if lastDanceFrame[playerID] and (frame - lastDanceFrame[playerID]) < COOLDOWN_FRAMES then
        spSendMessageToPlayer(playerID, "[Dance] Cooldown - wait a moment")
        return true
    end

    local idStr = strSub(msg, HEADER_LEN + 1)
    if idStr == "" then
        return true
    end

    local danced = 0
    local busyReason = nil
    for token in idStr:gmatch("[^,]+") do
        local unitID = tonumber(token)
        if unitID and spValidUnitID(unitID) then
            local unitTeam = spGetUnitTeam(unitID)
            local unitDefID = spGetUnitDefID(unitID)
            if (unitTeam == teamID or spIsCheatingEnabled()) and unitDefID and IsCommander(unitDefID) then
                local busy, reason = IsUnitBusy(unitID)
                if busy then
                    busyReason = reason
                else
                    if TriggerCommanderDance(unitID) then
                        danced = danced + 1
                    end
                end
            end
        end
    end

    if danced > 0 then
        lastDanceFrame[playerID] = frame
    elseif busyReason then
        spSendMessageToPlayer(playerID, "[Dance] Commander is " .. busyReason)
    end

    return true
end

function gadget:Initialize()
    gadgetHandler:RemoveCallIn("RecvLuaMsg")
end

function gadget:GameStart()
    gadgetHandler:UpdateCallIn("RecvLuaMsg")
end
