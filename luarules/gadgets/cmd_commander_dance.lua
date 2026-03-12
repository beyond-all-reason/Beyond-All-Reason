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
    local vx, _, vz = Spring.GetUnitVelocity(unitID)
    if vx and (math.abs(vx) > 0.1 or math.abs(vz) > 0.1) then
        return true, "moving"
    end

    -- Check building
    if Spring.GetUnitIsBuilding(unitID) then
        return true, "building"
    end

    -- Check current command for combat/assist
    local cmdID = Spring.GetUnitCurrentCommand(unitID)
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
    if Spring.GetCOBScriptID(unitID, "TriggerDance") then
        Spring.CallCOBScript(unitID, "TriggerDance", 0)
        return true
    end

    local scriptEnv = Spring.UnitScript.GetScriptEnv(unitID)
    if scriptEnv and scriptEnv.TriggerDance then
        Spring.UnitScript.CallAsUnit(unitID, scriptEnv.TriggerDance)
        return true
    end

    return false
end

function gadget:RecvLuaMsg(msg, playerID)
    if msg:sub(1, HEADER_LEN) ~= REQUEST_HEADER then
        return
    end

    local _, _, spec, teamID = Spring.GetPlayerInfo(playerID, false)
    if spec then
        return true
    end

    -- Cooldown check
    local frame = Spring.GetGameFrame()
    if lastDanceFrame[playerID] and (frame - lastDanceFrame[playerID]) < COOLDOWN_FRAMES then
        Spring.SendMessageToPlayer(playerID, "[Dance] Cooldown - wait a moment")
        return true
    end

    local idStr = msg:sub(HEADER_LEN + 1)
    if idStr == "" then
        return true
    end

    local danced = 0
    local busyReason = nil
    for token in idStr:gmatch("[^,]+") do
        local unitID = tonumber(token)
        if unitID and Spring.ValidUnitID(unitID) then
            local unitTeam = Spring.GetUnitTeam(unitID)
            local unitDefID = Spring.GetUnitDefID(unitID)
            if unitTeam == teamID and unitDefID and IsCommander(unitDefID) then
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
        Spring.SendMessageToPlayer(playerID, "[Dance] Commander is " .. busyReason)
    end

    return true
end
