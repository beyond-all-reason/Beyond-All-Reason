local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name    = "Replay - Game start info",
        desc    = "Logs the info of game start in replay metadata",
        author  = "uBdead",
        date    = "February 2026",
        license = "GNU GPL, v2 or later",
        layer   = 0,
        enabled = true
    }
end

if gadgetHandler:IsSyncedCode() then
    -- SYNCED --
    return
end

-- UNSYNCED --
local data = {}

function gadget:Initialize()
    data.mapName = Game.mapName
    data.gameVersion = Game.gameVersion

    GG.ReplayMetadata.SetReplayMetadata("gameInfo", data)
end

function gadget:GameStart()
    local teamList = Spring.GetTeamList()
    data.teams = {}
    local gaiaTeamID = Spring.GetGaiaTeamID and Spring.GetGaiaTeamID() or 666
    for _, teamID in ipairs(teamList) do
        if teamID ~= gaiaTeamID then
            local x, y, z = Spring.GetTeamStartPosition(teamID)
            local _, _, _, isAI, side = Spring.GetTeamInfo(teamID, false)
            local playerNames = {}
            if isAI then
                local _, _, _, aiName = Spring.GetAIInfo(teamID)
                local niceName = Spring.GetGameRulesParam('ainame_' .. teamID)
                if niceName then
                    aiName = tostring(niceName)
                end
                aiName = aiName or "AI"
                table.insert(playerNames, aiName)
            else
                local players = Spring.GetPlayerList(teamID) or {}
                for _, playerID in ipairs(players) do
                    local name = Spring.GetPlayerInfo(playerID, false)
                    if GG.playernames and GG.playernames.getPlayername then
                        name = GG.playernames.getPlayername(playerID) or name
                    end
                    table.insert(playerNames, name)
                end
            end
            data.teams[teamID] = {
                playerNames = playerNames,
                startPos = { x, y, z },
                isAI = isAI,
                faction = side
            }
        end
    end

    GG.ReplayMetadata.SetReplayMetadata("gameInfo", data)
end
